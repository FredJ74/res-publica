-- Santé — lot « combat » (Fred, 22/11/2026, après-midi : GAME-DESIGN-SANTE-20261122.md, points 1, 2, 3, 15 côté serveur, 19).
-- S'appuie sur le socle 20261122230000_sante_socle.sql (sante_param, sante_perte_combat_interne, sante_perdre_interne),
-- à appliquer AVANT celle-ci. Écrite à partir des définitions de PRODUCTION du 22/11/2026 (pg_get_functiondef, lecture seule ;
-- chaque ancrage compté en production avant écriture). Aucune Santé actuelle n'est modifiée (point 16). Rien du goulag.
--
-- Points 1 et 3 — robustesse et blessures. Toute perte de PA infligée par un adversaire à un PJ passe par
--   sante_combat_coup_pj_interne(nom, PA avant, perte brute, perte max, source) :
--     perte = sante_perte_combat_interne(Santé de la victime au moment du coup, perte brute), bornée aux PA restants ;
--     chaque PA perdu retire sante_param('blessure_sante_par_pa', 1) point de Santé (sante_perdre_interne, plancher 0).
--   Branché dans les deux moteurs de production :
--     • militaire_bataille_appliquer (batailles militaires, PJ contre PJ, faune, squatteurs, gardes : tous les rounds de
--       militaire_bataille_round) — ordre : degré du coup → morsure des loups (foret_morsure_v1, un tiers du coup) →
--       gilet pare-balles → robustesse (le gilet garantit toujours 1 PA restant) ;
--     • police_combat_personnage_interne (combats de police : coups des agents sur les PJ, et coups portés aux agents PJ).
--   Les PNJ n'ont pas de Santé : leur perte reste brute.
-- Point 2 — la Santé à 0 ne bloque plus rien : 21 contrôles « hp <= 0 » retirés (liste ci-dessous, marques sante_zero_libre_*),
--   combat_rapport_lignes_interne ne déclare plus « coma » sur la Santé (coma = PA à 0), et la neutralisation d'un PJ
--   dans un combat civil / faune / squatteurs / garde ne force plus sa Santé à 0 (le coma = PA 0 déclenche l'hospitalisation
--   existante, hospitalisation_pa_epuises_declencheur inchangé).
-- Point 15 — regen_jour et stats_affaiblies n'ont plus d'effet : impact_marquer_traite ne les écrit plus ; les cinq lecteurs
--   (jauges_ordre_executer, militaire_subtiliser_tenter, terrain_negociation_preparer, terrain_occupation_action_preparer,
--   terrain_squatteurs_don) n'affaiblissent plus aucune caractéristique. Colonnes conservées. Aucun texte serveur ne dit « PV »
--   pour la Santé (vérifié : seuls des commentaires, la clé JSON degatsPV et le « PV d'audition » judiciaire).
-- Point 19 — meute : chaque loup garde sa fuite individuelle ; dès que deux loups sont morts (aliments_parametres
--   'foret_meute_fuite_apres_morts'), le dernier s'enfuit dans le même round ; le butin de chaque loup tué va au chef quelle
--   que soit l'issue ; le reste d'une pile que l'inventaire presque plein du chef n'a pas rangée part au sas objets_recus
--   (inventaire_deposer_interne répond « ok » avec qte < qty : foret_butin_sas_v1) ; la dernière ligne du rapport donne l'état « fuite » au loup enfui (le rapport du round était écrit
--   avant l'arbitrage et la fin du combat : il est rafraîchi après).
-- Rejouable (remplacements contrôlés à marque unique, CREATE OR REPLACE, INSERT … ON CONFLICT DO NOTHING).
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- ---------------------------------------------------------------------------------------------------------------
-- 0. Paramètre de la meute (réglable par un MJ)
-- ---------------------------------------------------------------------------------------------------------------
INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('foret_meute_fuite_apres_morts', 2) ON CONFLICT (cle) DO NOTHING;

-- ---------------------------------------------------------------------------------------------------------------
-- 1. Un coup porté à un PJ : robustesse puis blessure (points 1 et 3)
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sante_combat_coup_pj_interne(p_nom text, p_pa_avant integer, p_perte_brute integer,
  p_perte_max integer DEFAULT NULL, p_source text DEFAULT 'combat')
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pa integer := greatest(0, coalesce(p_pa_avant, 0)); v_brute integer := greatest(0, coalesce(p_perte_brute, 0));
        v_hp integer; v_perte integer; v_sante integer; r jsonb;
BEGIN
  -- sante_combat_robustesse_v1 : perte × facteur(Santé au moment du coup), au moins 1 PA, jamais plus que les PA restants
  -- (ni que p_perte_max) ; chaque PA perdu retire blessure_sante_par_pa point(s) de Santé (plancher 0, jamais modulé).
  IF v_brute = 0 OR v_pa = 0 THEN
    RETURN jsonb_build_object('perte_brute', v_brute, 'perte', 0, 'pa_apres', v_pa, 'sante_perdue', 0);
  END IF;
  SELECT hp INTO v_hp FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    v_perte := least(v_pa, v_brute, coalesce(p_perte_max, v_pa));
    RETURN jsonb_build_object('perte_brute', v_brute, 'perte', v_perte, 'pa_apres', v_pa - v_perte, 'sante_perdue', 0);
  END IF;
  v_hp := coalesce(v_hp, public.sante_param('sante_max', 100)::integer);
  v_perte := least(v_pa, greatest(0, coalesce(p_perte_max, v_pa)), public.sante_perte_combat_interne(v_hp, v_brute));
  v_sante := round(v_perte * public.sante_param('blessure_sante_par_pa', 1))::integer;
  IF v_sante > 0 THEN
    r := public.sante_perdre_interne(p_nom, v_sante, coalesce(p_source, 'combat'),
           jsonb_build_object('pa_perdus', v_perte, 'perte_brute', v_brute));
  END IF;
  RETURN jsonb_build_object('perte_brute', v_brute, 'perte', v_perte, 'pa_apres', v_pa - v_perte,
    'facteur', public.sante_facteur_robustesse(v_hp), 'sante_avant', v_hp,
    'sante_apres', coalesce((r->>'apres')::integer, v_hp), 'sante_perdue', v_hp - coalesce((r->>'apres')::integer, v_hp));
END $function$;
REVOKE ALL ON FUNCTION public.sante_combat_coup_pj_interne(text, integer, integer, integer, text) FROM PUBLIC, anon, authenticated;

-- 1a. Moteur des rounds (militaire_bataille_appliquer) : après morsure et gilet, la robustesse.
SELECT pg_temp.rp_remplacer('public.militaire_bataille_appliquer(bigint,jsonb,integer)'::regprocedure,
  $a$  v_pnj text; v_statut text; -- bataille_effets_socle_v1$a$,
  $b$  v_pnj text; v_statut text; -- bataille_effets_socle_v1
  v_sante jsonb; /* sante_combat_declaration_v1 */$b$,
  1, 'sante_combat_declaration_v1');
SELECT pg_temp.rp_remplacer('public.militaire_bataille_appliquer(bigint,jsonb,integer)'::regprocedure,
  $a$    IF (act->>'cib_pj')::boolean THEN
      UPDATE public.personnages_donnees SET pa = v_new WHERE name = act->>'cib_nom';$a$,
  $b$    v_sante := NULL; /* sante_combat_robustesse_v1 : robustesse et blessure d'un PJ (après morsure et gilet) */
    IF (act->>'cib_pj')::boolean AND v_new < v_pa THEN
      v_sante := public.sante_combat_coup_pj_interne(act->>'cib_nom', v_pa, v_pa - v_new,
                   CASE WHEN v_protege THEN v_pa - 1 ELSE v_pa END, 'combat');
      v_new := (v_sante->>'pa_apres')::integer;
    END IF;
    IF (act->>'cib_pj')::boolean THEN
      UPDATE public.personnages_donnees SET pa = v_new WHERE name = act->>'cib_nom';$b$,
  1, 'sante_combat_robustesse_v1');
SELECT pg_temp.rp_remplacer('public.militaire_bataille_appliquer(bigint,jsonb,integer)'::regprocedure,
  $a$'gilet', v_protege, 'degre_applique', coalesce(v_abaisse, v_degre)));$a$,
  $b$'gilet', v_protege, 'degre_applique', coalesce(v_abaisse, v_degre))
      || CASE WHEN v_sante IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('perte_brute', v_sante->'perte_brute',
           'sante_perdue', v_sante->'sante_perdue') END /* sante_combat_rapport_v1 */);$b$,
  1, 'sante_combat_rapport_v1');

-- 1b. Combats de police : coups des agents sur les PJ interceptés (et coups des PJ sur un agent qui serait un PJ).
SELECT pg_temp.rp_remplacer('public.police_combat_personnage_interne(text,text,text,text,integer,text)'::regprocedure,
  $a$  v_victimes:=jsonb_set(v_victimes,ARRAY[v_vi::text,'pa'],v_jet->'pa_apres');$a$,
  $b$  IF v_victime ? 'pj_nom' THEN v_jet := v_jet || public.sante_combat_coup_pj_interne(v_victime->>'pj_nom',(v_victime->>'pa')::integer,(v_jet->>'perte')::integer,NULL,'combat_police'); END IF; /* sante_police_robustesse_v1 */
  v_victimes:=jsonb_set(v_victimes,ARRAY[v_vi::text,'pa'],v_jet->'pa_apres');$b$,
  1, 'sante_police_robustesse_v1');
SELECT pg_temp.rp_remplacer('public.police_combat_personnage_interne(text,text,text,text,integer,text)'::regprocedure,
  $a$  v_actifs:=jsonb_set(v_actifs,ARRAY[v_cible::text,'pa'],v_jet->'pa_apres');$a$,
  $b$  IF v_agent ? 'pj_nom' THEN v_jet := v_jet || public.sante_combat_coup_pj_interne(v_agent->>'pj_nom',(v_agent->>'pa')::integer,(v_jet->>'perte')::integer,NULL,'combat_police'); END IF; /* sante_police_agent_robustesse_v1 */
  v_actifs:=jsonb_set(v_actifs,ARRAY[v_cible::text,'pa'],v_jet->'pa_apres');$b$,
  1, 'sante_police_agent_robustesse_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- 2. La Santé à 0 ne bloque plus rien (point 2) : coma = PA à 0 seulement
-- ---------------------------------------------------------------------------------------------------------------
-- Neutralisation d'un PJ en combat civil / faune / squatteurs / garde : sa Santé n'est plus forcée à 0.
SELECT pg_temp.rp_remplacer('public.militaire_bataille_neutralisation_terminale_interne(bigint,jsonb,integer)'::regprocedure,
  $a$THEN UPDATE public.personnages_donnees SET hp=least(coalesce(hp,100),0) WHERE name=act->>'cib_nom';RETURN;$a$,
  $b$THEN /* sante_coma_pa_v1 : coma = PA 0, la Santé n'est plus mise à 0 */ RETURN;$b$,
  1, 'sante_coma_pa_v1');

-- Contrôles « Santé <= 0 » retirés (la condition devient constante, le reste de la garde est inchangé).
SELECT pg_temp.rp_remplacer('public.acces_forcer_passage(uuid,text)'::regprocedure,
  $a$coalesce(p.hp, 0) <= 0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.chantier_commande(text,text,text,jsonb)'::regprocedure,
  $a$coalesce(a.hp,0)<=0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.groupe_combattants_interne(text,text,bigint)'::regprocedure,
  $a$coalesce(d.hp,100)>0$a$, $b$true /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.jardins_ouvriers_acteur_interne(text)'::regprocedure,
  $a$coalesce(m.hp, 0) <= 0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.local_louer(uuid,text)'::regprocedure,
  $a$coalesce(p.hp,0) <= 0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.militaire_bataille_arbitrer_groupes(bigint,integer)'::regprocedure,
  $a$AND coalesce(hp,100)>0$a$, $b$AND true /* sante_zero_libre_a_v1 */$b$, 1, 'sante_zero_libre_a_v1');
SELECT pg_temp.rp_remplacer('public.militaire_bataille_arbitrer_groupes(bigint,integer)'::regprocedure,
  $a$AND coalesce(d.hp,100)>0$a$, $b$AND true /* sante_zero_libre_b_v1 */$b$, 1, 'sante_zero_libre_b_v1');
SELECT pg_temp.rp_remplacer('public.militaire_bataille_combattants(bigint,text)'::regprocedure,
  $a$coalesce(pd.hp,100)>0$a$, $b$true /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.militaire_bataille_commande_interne(bigint,text,integer,uuid)'::regprocedure,
  $a$coalesce(d.hp,100)>0$a$, $b$true /* sante_zero_libre_v1 */$b$, 2, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.militaire_bataille_etat(bigint)'::regprocedure,
  $a$coalesce(d.hp,100)>0$a$, $b$true /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.militaire_bataille_recruter_metier_interne(bigint,text,text,text,text)'::regprocedure,
  $a$coalesce(pd.hp,100)>0$a$, $b$true /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.navigation_disponibilite_interne(text)'::regprocedure,
  $a$coalesce(p.hp,100)<=0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.poissonniere_acteur_interne(text)'::regprocedure,
  $a$coalesce(m.hp, 0) <= 0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.police_combat_personnage_interne(text,text,text,text,integer,text)'::regprocedure,
  $a$coalesce(v_pj.hp,100)<=0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.pret_national_contracter_versionne(numeric,integer,text,text,uuid)'::regprocedure,
  $a$coalesce(p.hp,0)<=0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.sovarka_reunion_evenement(uuid,text,text,text)'::regprocedure,
  $a$coalesce(p.hp, 0) > 0$a$, $b$true /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.terrain_acquisition_commande(text,text,jsonb,uuid)'::regprocedure,
  $a$coalesce(p.hp,0)<=0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.terrain_lot_loyer_fixer(text,text,integer)'::regprocedure,
  $a$coalesce(p.hp,0) <= 0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.terrain_lots_acte(text,text,jsonb,text[])'::regprocedure,
  $a$coalesce(p.hp,0)<=0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.terrain_occupation_action_preparer(text,text)'::regprocedure,
  $a$coalesce(p.hp,0)<=0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');
SELECT pg_temp.rp_remplacer('public.vendre_materiaux_chantier(text,text,text,text,integer,integer)'::regprocedure,
  $a$coalesce(v_pj.hp,0)<=0$a$, $b$false /* sante_zero_libre_v1 */$b$, 1, 'sante_zero_libre_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- 3. Rapport de combat : coma = PA 0 ; état de fin de combat repris dans la dernière ligne (points 2 et 19)
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.combat_etat_ligne_interne(p_etat_final text, p_pj boolean)
 RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE p_etat_final WHEN 'mort' THEN 'mort' WHEN 'neutralise' THEN 'coma' WHEN 'replie' THEN 'fuite'
                           WHEN 'rendu' THEN 'rendu' WHEN 'capture' THEN 'capture'
                           ELSE CASE WHEN p_pj THEN 'coma' ELSE 'fuite' END END /* combat_rapport_etats_fin_v1 */
$function$;
REVOKE ALL ON FUNCTION public.combat_etat_ligne_interne(text, boolean) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.combat_rapport_lignes_interne(p_bataille bigint, p_camp text, p_round integer, p_actions jsonb)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE b public.batailles%ROWTYPE; v_lignes jsonb; v_debout text; n integer; v_nom text;
BEGIN
  -- sante_coma_pa_v1 (Fred, 22/11/2026) : le coma n'a plus qu'une définition, PA à 0 ; la Santé ne compte plus.
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille;
  IF NOT FOUND OR coalesce(b.contexte->>'type', '') NOT IN ('civil', 'squatteurs', 'faune', 'garde_acces') THEN RETURN '{}'::jsonb; END IF;
  WITH l AS (
    SELECT e.id, (e.camp = p_camp) AS mien,
           CASE WHEN e.personnage IS NOT NULL THEN
                  CASE WHEN e.camp = p_camp OR b.contexte->>'type' IN ('faune', 'garde_acces') THEN e.personnage
                       ELSE coalesce(public.crim_designation_bataille_interne(b.id, e.personnage), e.personnage) END
                ELSE coalesce(m.nom, 'Adversaire') END AS nom,
           (e.personnage IS NOT NULL AND e.personnage IN (coalesce(b.leader_a, ''), coalesce(b.leader_b, ''), coalesce(b.contexte->>'acteur', ''))) AS chef,
           coalesce((SELECT sum(coalesce((a->>'perte')::integer, 0)) FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb)) a
                      WHERE a->>'cib_eng' = e.id::text), 0)::integer AS perte,
           CASE WHEN e.sorti_round IS NOT NULL AND e.sorti_round <= p_round THEN public.combat_etat_ligne_interne(e.etat_final, e.personnage IS NOT NULL)
                WHEN e.personnage IS NOT NULL AND coalesce(d.pa, 0) <= 0 THEN 'coma'
                WHEN e.personnage IS NULL AND m.statut = 'mort' THEN 'mort' END AS etat,
           CASE WHEN e.camp = p_camp AND e.personnage IS NOT NULL THEN greatest(0, coalesce(d.pa, 0)) END AS pa
      FROM public.batailles_engagements e
      LEFT JOIN public.personnages_donnees d ON d.name = e.personnage
      LEFT JOIN public.pnj_membres m ON m.id = e.pnj_id
     WHERE e.bataille_id = p_bataille
  )
  SELECT jsonb_agg(jsonb_build_object('eng', id, 'mien', mien, 'nom', nom, 'chef', chef, 'perte', perte, 'etat', etat, 'pa', pa)
                   ORDER BY (NOT mien), (NOT chef), id),
         string_agg(nom, ', ' ORDER BY id) FILTER (WHERE NOT mien AND etat IS NULL),
         count(*) FILTER (WHERE NOT mien AND etat IS NULL)
    INTO v_lignes, v_debout, n FROM l;
  v_nom := CASE WHEN b.contexte->>'type' = 'faune'
                THEN public.sovarka_foret_creature_interne((SELECT r.creature FROM public.sovarka_foret_rencontres r WHERE r.pnj_id = b.contexte->>'cible' LIMIT 1))->>'nom' END;
  RETURN jsonb_build_object('lignes', coalesce(v_lignes, '[]'::jsonb), 'adversaire_nom', v_nom,
    'adversaire_estime', CASE WHEN coalesce(n, 0) = 0 THEN jsonb_build_object('libelle', 'plus aucun adversaire debout')
                              ELSE jsonb_build_object('libelle', v_debout, 'effectif_min', n, 'effectif_max', n) END);
END $function$;
REVOKE ALL ON FUNCTION public.combat_rapport_lignes_interne(bigint, text, integer, jsonb) FROM PUBLIC, anon, authenticated;

-- Le rapport d'un round est écrit avant l'arbitrage (fuites) et la fin du combat : on reprend ensuite, dans les lignes de
-- ce round, l'état des combattants sortis pendant ce round (loup enfui : « fuite », affiché « en fuite »).
CREATE OR REPLACE FUNCTION public.combat_rapport_etats_rafraichir_interne(p_bataille bigint, p_round integer)
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_lignes jsonb; v_debout text; n integer; k integer := 0; v_fini boolean;
BEGIN
  -- combat_rapport_etats_fin_v1
  SELECT statut = 'terminee' INTO v_fini FROM public.batailles WHERE id = p_bataille;
  FOR r IN SELECT camp, rapport FROM public.batailles_rounds
            WHERE bataille_id = p_bataille AND numero = p_round AND jsonb_typeof(rapport->'lignes') = 'array'
            ORDER BY camp FOR UPDATE LOOP
    SELECT jsonb_agg(CASE WHEN x.l->>'etat' IS NULL AND e.sorti_round IS NOT NULL AND e.sorti_round <= p_round
                          THEN x.l || jsonb_build_object('etat', public.combat_etat_ligne_interne(e.etat_final, e.personnage IS NOT NULL))
                          ELSE x.l END ORDER BY x.o)
      INTO v_lignes
      FROM jsonb_array_elements(r.rapport->'lignes') WITH ORDINALITY x(l, o)
      LEFT JOIN public.batailles_engagements e ON e.bataille_id = p_bataille AND e.id::text = x.l->>'eng';
    CONTINUE WHEN v_lignes IS NULL OR v_lignes = r.rapport->'lignes';
    SELECT string_agg(l->>'nom', ', ' ORDER BY (l->>'eng')::bigint) FILTER (WHERE NOT coalesce((l->>'mien')::boolean, false) AND l->>'etat' IS NULL),
           count(*) FILTER (WHERE NOT coalesce((l->>'mien')::boolean, false) AND l->>'etat' IS NULL)
      INTO v_debout, n FROM jsonb_array_elements(v_lignes) l;
    UPDATE public.batailles_rounds
       SET rapport = rapport || jsonb_build_object('lignes', v_lignes,
             'adversaire_estime', CASE WHEN coalesce(n, 0) = 0 THEN jsonb_build_object('libelle', 'plus aucun adversaire debout')
                                       ELSE jsonb_build_object('libelle', v_debout, 'effectif_min', n, 'effectif_max', n) END)
           || CASE WHEN v_fini THEN jsonb_build_object('termine', true) ELSE '{}'::jsonb END
     WHERE bataille_id = p_bataille AND numero = p_round AND camp = r.camp;
    k := k + 1;
  END LOOP;
  RETURN k;
END $function$;
REVOKE ALL ON FUNCTION public.combat_rapport_etats_rafraichir_interne(bigint, integer) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 4. Meute : le dernier loup s'enfuit quand deux sont morts ; butin de chaque loup tué au chef (point 19)
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sovarka_foret_meute_derniere_fuite_interne(p_bataille bigint, p_round integer)
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE b public.batailles%ROWTYPE; v_loups integer; v_morts integer; v_debout integer; n integer;
BEGIN
  -- foret_meute_derniere_fuite_v1 (Fred, 22/11/2026) : chaque loup garde sa fuite individuelle (arbitrage commun) ;
  -- dès que 'foret_meute_fuite_apres_morts' loups sont morts, les loups encore debout s'enfuient dans le même round.
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille;
  IF NOT FOUND OR b.statut <> 'en_cours' OR coalesce(b.contexte->>'type', '') <> 'faune' THEN RETURN 0; END IF;
  SELECT coalesce((public.sovarka_foret_creature_interne(r.creature)->>'loups')::integer, 1) INTO v_loups
    FROM public.sovarka_foret_rencontres r WHERE r.pnj_id = b.contexte->>'cible' LIMIT 1;
  IF coalesce(v_loups, 1) <= 1 THEN RETURN 0; END IF;
  SELECT count(*) FILTER (WHERE etat_final = 'mort'), count(*) FILTER (WHERE sorti_round IS NULL) INTO v_morts, v_debout
    FROM public.batailles_engagements WHERE bataille_id = p_bataille AND camp = b.camp_b AND pnj_id IS NOT NULL;
  IF v_debout = 0 OR v_morts < public.aliments_param_interne('foret_meute_fuite_apres_morts', 2) THEN RETURN 0; END IF;
  UPDATE public.batailles_groupes g SET sorti_round = p_round, attente_depuis = NULL
   WHERE g.bataille_id = p_bataille AND g.sorti_round IS NULL
     AND g.groupe_id IN (SELECT e.groupe_id FROM public.batailles_engagements e
                          WHERE e.bataille_id = p_bataille AND e.camp = b.camp_b AND e.pnj_id IS NOT NULL AND e.sorti_round IS NULL);
  UPDATE public.batailles_engagements SET sorti_round = p_round, etat_final = 'replie'
   WHERE bataille_id = p_bataille AND camp = b.camp_b AND pnj_id IS NOT NULL AND sorti_round IS NULL;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_meute_derniere_fuite_interne(bigint, integer) FROM PUBLIC, anon, authenticated;

-- Raccords dans le round commun : après l'arbitrage, la fuite du dernier loup ; après la fin, l'état repris au rapport.
SELECT pg_temp.rp_remplacer('public.militaire_bataille_round(bigint)'::regprocedure,
  $a$  v_attente := public.militaire_bataille_arbitrer_groupes(p_bataille_id, v_round);$a$,
  $b$  v_attente := public.militaire_bataille_arbitrer_groupes(p_bataille_id, v_round);
  PERFORM public.sovarka_foret_meute_derniere_fuite_interne(p_bataille_id, v_round); /* foret_meute_derniere_fuite_v1 */$b$,
  1, 'foret_meute_derniere_fuite_v1');
SELECT pg_temp.rp_remplacer('public.militaire_bataille_round(bigint)'::regprocedure,
  $a$ PERFORM public.combat_finaliser_interne(p_bataille_id);$a$,
  $b$ PERFORM public.combat_finaliser_interne(p_bataille_id);
 PERFORM public.combat_rapport_etats_rafraichir_interne(p_bataille_id, v_round); /* combat_rapport_etats_fin_v1 */$b$,
  1, 'combat_rapport_etats_fin_v1');

-- Issue d'un combat de faune (texte de production + foret_meute_butin_v2) : pour la meute, le butin de CHAQUE loup tué est
-- remis au chef quelle que soit l'issue (victoire, loups enfuis, groupe vaincu) ; le bois de la seconde coupe reste réservé
-- aux issues sans défaite.
CREATE OR REPLACE FUNCTION public.sovarka_foret_issue_combat_interne(p_pnj text, p_leader text, p_issue text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE e record; c jsonb; o jsonb; v_dep jsonb; v_livre jsonb := '[]'::jsonb; k integer := 0; v_b bigint;
        v_total integer; v_abattus integer := 0; v_mult integer;
BEGIN
  -- combat_faune_hostilite_v1
  -- foret_combat_journal_v1 : l'issue s'écrit dans le journal du joueur, plus dans sa boîte mail.
  -- foret_meute_butin_v1 (Fred, 22/11/2026) : tout le butin au chef, une seule fois ; pour la meute, par loup abattu.
  -- foret_meute_butin_v2 (Fred, 22/11/2026, point 19) : le butin de chaque loup tué, même si un loup s'enfuit ou si le groupe tombe.
  SELECT * INTO e FROM public.sovarka_foret_rencontres WHERE pnj_id = p_pnj FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'issue', p_issue); END IF;
  PERFORM public.sovarka_foret_faune_retirer_interne(p_pnj);
  IF e.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'deja', true); END IF;
  c := public.sovarka_foret_creature_interne(e.creature);
  v_total := greatest(1, coalesce((c->>'loups')::integer, 1));
  SELECT b.id INTO v_b FROM public.batailles b WHERE b.contexte->>'type' = 'faune' AND b.contexte->>'cible' = p_pnj ORDER BY b.id DESC LIMIT 1;
  IF v_b IS NOT NULL THEN
    SELECT count(*) INTO v_abattus FROM public.batailles_engagements be JOIN public.batailles b ON b.id = be.bataille_id
     WHERE be.bataille_id = v_b AND be.camp = b.camp_b AND be.pnj_id IS NOT NULL AND be.sorti_round IS NOT NULL
       AND coalesce(be.etat_final, '') NOT IN ('replie', 'indisponible');
  END IF;
  v_mult := CASE WHEN v_total > 1 AND p_issue IN ('tues', 'neutralises') THEN least(v_total, greatest(1, v_abattus))
                 WHEN v_total > 1 THEN least(v_total, v_abattus)
                 WHEN p_issue IN ('tues', 'neutralises') THEN 1 ELSE 0 END;
  IF v_total = 1 THEN v_abattus := CASE WHEN p_issue IN ('tues', 'neutralises') THEN 1 ELSE 0 END; END IF;
  IF p_issue IN ('tues', 'neutralises', 'fuite') OR v_mult > 0 THEN
    FOR o IN SELECT public.sovarka_matiere_objet_interne(b->>'cle', (b->>'qte')::integer * v_mult, 'Butin : ' || lower(c->>'nom') || ' de la forêt de Krasnov.')
               FROM jsonb_array_elements(c->'butin') b WHERE v_mult > 0
             UNION ALL
             SELECT public.sovarka_matiere_objet_interne('bois', (floor(random() * 2)::integer + 1) * 2, 'Seconde coupe dans la forêt profonde de Krasnov.')
              WHERE p_issue IN ('tues', 'neutralises', 'fuite')
             UNION ALL
             SELECT jsonb_build_object('name', 'Dent d''ours', 'icon', 'ti-trophy', 'stackable', true, 'stackKey', 'dent_ours',
                      'qty', (c->>'dents')::integer, 'legal', true, 'desc', 'Trophée de la forêt profonde de Krasnov : la preuve qu''on a vaincu un ours.')
              WHERE c ? 'dents' AND v_mult > 0
             UNION ALL  /* krasnov_graisse_ours_v1 : 10 pots de graisse d'ours par ours tué */
             SELECT public.graisse_objet_interne('graisse_ours', 10) WHERE e.creature = 'ours' AND v_mult > 0 LOOP
      k := k + 1;
      v_dep := public.inventaire_deposer_interne(p_leader, o);
      IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN
        INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
        VALUES ('foret-krasnov-' || e.id || '-' || k, p_leader, 'Forêt de Krasnov', to_jsonb(o::text)) ON CONFLICT (id) DO NOTHING;
      -- foret_butin_sas_v1 : dépôt partiel d'une pile (inventaire presque plein, « ok » avec qte < qty) : le reste part au sas.
      ELSIF coalesce((o->>'stackable')::boolean, false) AND v_dep ? 'qte'
            AND (v_dep->>'qte')::integer < coalesce((o->>'qty')::integer, 1) THEN
        INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
        VALUES ('foret-krasnov-' || e.id || '-' || k || '-reste', p_leader, 'Forêt de Krasnov',
                to_jsonb((o || jsonb_build_object('qty', coalesce((o->>'qty')::integer, 1) - (v_dep->>'qte')::integer))::text))
        ON CONFLICT (id) DO NOTHING;
      END IF;
      v_livre := v_livre || o;
    END LOOP;
  END IF;
  IF p_issue IN ('tues', 'neutralises') THEN
    UPDATE public.sovarka_foret_rencontres SET statut = 'vaincu', clos_le = now() WHERE id = e.id;
  ELSIF p_issue = 'fuite' THEN
    UPDATE public.sovarka_foret_rencontres SET statut = 'fuite', clos_le = now() WHERE id = e.id;
  ELSE
    UPDATE public.sovarka_foret_rencontres SET statut = 'perdu', clos_le = now() WHERE id = e.id;
  END IF;
  DELETE FROM public.sovarka_foret_visites WHERE bucheron = e.bucheron;
  IF v_b IS NOT NULL THEN
    INSERT INTO public.sovarka_foret_journal (destinataire, cle, params, bataille)
    SELECT DISTINCT be.personnage, 'combat', jsonb_build_object('chef', p_leader, 'creature', e.creature, 'nom', c->>'nom', 'issue', p_issue,
             'abattus', v_abattus, 'total', v_total,
             'butin', (SELECT coalesce(jsonb_agg(jsonb_build_object('nom', x->>'name', 'qte', (x->>'qty')::integer)), '[]'::jsonb) FROM jsonb_array_elements(v_livre) x)), v_b
      FROM public.batailles_engagements be
     WHERE be.bataille_id = v_b AND be.personnage IS NOT NULL AND be.personnage <> p_leader;
  END IF;
  RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'creature', e.creature, 'butin', v_livre, 'abattus', v_abattus, 'total', v_total);
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_issue_combat_interne(text, text, text) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 5. Régénération et caractéristiques affaiblies sans effet (point 15)
-- ---------------------------------------------------------------------------------------------------------------
SELECT pg_temp.rp_remplacer('public.impact_marquer_traite(text,integer)'::regprocedure,
  $a$hp=imp.delta,pa=0,regen_jour=day,
     stats_affaiblies=coalesce(stats_affaiblies,'{}'::jsonb)||faibles WHERE name=moi;$a$,
  $b$hp=imp.delta,pa=0 /* sante_sans_regen_v1 : ni regen_jour ni stats_affaiblies */ WHERE name=moi;$b$,
  1, 'sante_sans_regen_v1');
SELECT pg_temp.rp_remplacer('public.impact_marquer_traite(text,integer)'::regprocedure,
  $a$'poisonType',imp.details->>'poisonType'),
     stats_affaiblies=coalesce(stats_affaiblies,'{}'::jsonb)||faibles WHERE name=moi;$a$,
  $b$'poisonType',imp.details->>'poisonType') /* sante_sans_affaiblies_poison_v1 */ WHERE name=moi;$b$,
  1, 'sante_sans_affaiblies_poison_v1');
SELECT pg_temp.rp_remplacer('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure,
  $a$a.stats_affaiblies ? 'INT'$a$, $b$false /* sante_sans_affaiblies_v1 */$b$, 1, 'sante_sans_affaiblies_v1');
SELECT pg_temp.rp_remplacer('public.militaire_subtiliser_tenter(text)'::regprocedure,
  $a$v_pj.stats_affaiblies ? 'DUP'$a$, $b$false /* sante_sans_affaiblies_v1 */$b$, 1, 'sante_sans_affaiblies_v1');
SELECT pg_temp.rp_remplacer('public.terrain_negociation_preparer(text)'::regprocedure,
  $a$p.stats_affaiblies ? 'CHA'$a$, $b$false /* sante_sans_affaiblies_v1 */$b$, 1, 'sante_sans_affaiblies_v1');
SELECT pg_temp.rp_remplacer('public.terrain_occupation_action_preparer(text,text)'::regprocedure,
  $a$p.stats_affaiblies ? 'CHA'$a$, $b$false /* sante_sans_affaiblies_cha_v1 */$b$, 1, 'sante_sans_affaiblies_cha_v1');
SELECT pg_temp.rp_remplacer('public.terrain_occupation_action_preparer(text,text)'::regprocedure,
  $a$p.stats_affaiblies ? 'DUP'$a$, $b$false /* sante_sans_affaiblies_dup_v1 */$b$, 1, 'sante_sans_affaiblies_dup_v1');
SELECT pg_temp.rp_remplacer('public.terrain_squatteurs_don(text,integer,text,uuid)'::regprocedure,
  $a$p.stats_affaiblies ? 'CHA'$a$, $b$false /* sante_sans_affaiblies_v1 */$b$, 1, 'sante_sans_affaiblies_v1');

COMMIT;
