-- Santé — « Suites » (décisions de Fred du 22/11/2026 au soir, GAME-DESIGN-SANTE-20261122.md, section « Suites »,
-- points 1, 2, 3, 7, 9, 11, 13 ; les points 10 et 13 ont aussi leur part dans le navigateur).
-- ÉCRITE, NON APPLIQUÉE. Écrite à partir des définitions de PRODUCTION du 22/11/2026 au soir (pg_get_functiondef, lecture seule,
-- projet jxpwoosmmhohoihxpbuc) ; chaque ancrage compté sur la copie de production (doublure PGlite à md5 identique).
-- Suppose appliquées les migrations Santé 20261122230000 à 20261122234000 (déjà en production). Rien du goulag.
-- Aucune Santé, aucun PA, aucun inventaire de joueur n'est modifié par la migration elle-même.
--
-- Point 1  — « snack » n'est jamais lu par un joueur : la clé interne reste ; libellés MJ « En-cas (zakouski) » ; texte de
--            l'effet des fruits et légumes du marché de Krasnov : « un zakouski » (Sovarka).
-- Point 2  — palier « produit de joueur ≥ 15 » = menu (+5 Santé / +3 PA) : catégorie 'joueur_p15' (contrainte CHECK de
--            sante_repas_categories élargie), sante_repas_joueur_categorie_interne réécrite, réglages repas_joueur_p15_*.
-- Point 3  — repas du président (sovarka_repas_presidentiel ; aucun équivalent républicain en production) : +5 Santé / +3 PA
--            différés pour chacun, par sante_repas_appliquer_interne (catégorie 'president') ; repas de l'hôpital public
--            +4 Santé / +2 PA, gratuit, réservé aux hospitalisés (contrôle existant conservé) ; repas de la clinique +5 Santé,
--            +4 PA, 30 FR (tarif ordres_couts inchangé). Valeurs : sante_parametres repas_president_*, repas_hopital_*,
--            repas_clinique_*.
-- Point 7  — robustesse : « se laisser faire » face à une bête (sovarka_foret_rencontre, choix subir) passe par
--            sante_combat_coup_pj_interne (perte de PA × facteur de robustesse, 1 Santé par PA perdu) ; la répression
--            (manifestation_reprimer) et la rébellion (detention_se_rebeller) ne retirent pas de PA en production : leur perte
--            de Santé (10 / 10 / 25, désormais réglable) est multipliée par le facteur de robustesse
--            (sante_perte_combat_interne), plancher 1 conservé. crime_neutraliser et le poison : inchangés.
-- Point 9  — tracts_donner_joueur soumis au plafond commun (inventaire_place_destinataire_interne, refus destinataire_plein
--            avec la place) ; seul don entre joueurs qui y échappait (inventaire_donner l'appliquait déjà).
-- Point 11 — règle commune de rachat des marchés : rachat = round(prix × marches_rachat_taux), au plus prix − marches_rachat_ecart_min
--            (aliments_parametres, 0,7 et 1, réglables par le MJ : admin_aliment_modifier élargi) ; seul marché avec rachat en
--            production : marche_krasnov_produits (déclencheurs : le rachat suit toujours le prix et la règle). Prix des
--            transformés recalculés par la règle commune de fabrication ((matières au prix du marché + salaire × PA) / unités × 2,
--            arrondi) : chemise 18 → 17. Confiture du kolkhoze de Starovka 5 → 10 PSK (prix fixe). Caisse du marché de Krasnov :
--            dotation 1 000 PSK (solde vérifié à 1 000 le 22/11, non touché). « marche_krasnov_decote_rachat_pct » (25, « pour
--            mémoire », lu par aucune fonction) supprimé.
-- Point 13 — obj_informateur = « Acheter 5 informations à des informateurs différents » : compté sur informateurs_achats
--            (crim_parametres.objectif_informateurs_distincts = 5).
-- Rejouable : remplacements contrôlés à marque unique (pg_temp.rp_remplacer), CREATE OR REPLACE, ON CONFLICT DO NOTHING.

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
-- 0. Réglages (MJ : page « Santé — paramètres » ; marchés : réglages des aliments ; objectif : crim_parametres)
-- ---------------------------------------------------------------------------------------------------------------
INSERT INTO public.sante_parametres (cle, valeur, groupe, libelle) VALUES
  ('repas_joueur_p15_prix_min', 15, 'repas', 'Produit de joueur : prix de vente à partir duquel le palier 15 s''applique'),
  ('repas_joueur_p15_sante', 5, 'repas', 'Produit de joueur, palier 15 et plus : Santé'),
  ('repas_joueur_p15_pa', 3, 'repas', 'Produit de joueur, palier 15 et plus : PA différés'),
  ('repas_president_sante', 5, 'repas', 'Repas du Président : Santé'),
  ('repas_president_pa', 3, 'repas', 'Repas du Président : PA différés'),
  ('repas_hopital_sante', 4, 'repas', 'Repas de l''hôpital public (patients hospitalisés) : Santé'),
  ('repas_hopital_pa', 2, 'repas', 'Repas de l''hôpital public : PA au prochain sommeil'),
  ('repas_clinique_sante', 5, 'repas', 'Repas de la clinique privée : Santé'),
  ('repas_clinique_pa', 4, 'repas', 'Repas de la clinique privée : PA au prochain sommeil'),
  ('repression_perte_sante', 10, 'combat', 'Répression d''une manifestation : Santé perdue (avant robustesse)'),
  ('rebellion_reussie_perte_sante', 10, 'combat', 'Rébellion en cellule réussie : Santé perdue (avant robustesse)'),
  ('rebellion_matee_perte_sante', 25, 'combat', 'Rébellion en cellule matée : Santé perdue (avant robustesse)')
ON CONFLICT (cle) DO NOTHING;
-- Point 1 : la page du MJ ne dit plus « Snack ».
UPDATE public.sante_parametres SET libelle = 'En-cas (zakouski en Sovarka) : Santé' WHERE cle = 'repas_snack_sante' AND libelle = 'Snack : Santé';
UPDATE public.sante_parametres SET libelle = 'En-cas (zakouski en Sovarka) : PA différés' WHERE cle = 'repas_snack_pa' AND libelle = 'Snack : PA différés';

INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('marches_rachat_taux', 0.7), ('marches_rachat_ecart_min', 1),
  ('marche_krasnov_dotation', 1000)
ON CONFLICT (cle) DO NOTHING;
DELETE FROM public.aliments_parametres WHERE cle = 'marche_krasnov_decote_rachat_pct';
INSERT INTO public.crim_parametres (cle, valeur) VALUES ('objectif_informateurs_distincts', 5) ON CONFLICT (cle) DO NOTHING;

-- ---------------------------------------------------------------------------------------------------------------
-- 1. Point 2 — palier « produit de joueur ≥ 15 »
-- ---------------------------------------------------------------------------------------------------------------
ALTER TABLE public.sante_repas_categories DROP CONSTRAINT IF EXISTS sante_repas_categories_categorie_check;
ALTER TABLE public.sante_repas_categories ADD CONSTRAINT sante_repas_categories_categorie_check
  CHECK (categorie = ANY (ARRAY['menu', 'plat', 'sandwich', 'petitdej', 'snack', 'boisson', 'joueur_p5', 'joueur_p10', 'joueur_p15', 'aucun']));

CREATE OR REPLACE FUNCTION public.sante_repas_joueur_categorie_interne(p_prix numeric)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN coalesce(p_prix, 0) >= public.sante_param('repas_joueur_p15_prix_min', 15) THEN 'joueur_p15'
              WHEN coalesce(p_prix, 0) >= public.sante_param('repas_joueur_p10_prix_min', 10) THEN 'joueur_p10'
              WHEN coalesce(p_prix, 0) >= public.sante_param('repas_joueur_p5_prix_min', 5) THEN 'joueur_p5'
              ELSE 'aucun' END /* sante_suites_p15_v1 */
$function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 2. Point 3 — repas de l'hôpital et de la clinique
-- ---------------------------------------------------------------------------------------------------------------
SELECT pg_temp.rp_remplacer('public.hospitalisation_repas_prendre()'::regprocedure,
$a$ v_nuit public.clinique_nuitees%ROWTYPE;
BEGIN$a$,
$b$ v_nuit public.clinique_nuitees%ROWTYPE; v_s jsonb; /* sante_suites_repas_decl_v1 */
BEGIN$b$, 1, 'sante_suites_repas_decl_v1');

-- Client d'une nuitée à la clinique : +repas_clinique_sante Santé (modulée par le Moral) et +repas_clinique_pa PA différés.
SELECT pg_temp.rp_remplacer('public.hospitalisation_repas_prendre()'::regprocedure,
$a$   UPDATE public.personnages_donnees
      SET bonus_pa_differe=coalesce(bonus_pa_differe,0)+4
    WHERE name=moi RETURNING pa INTO v_pa;
   RETURN jsonb_build_object('ok',true,'mode','nuitee','pa',v_pa,
     'cout',v_cost,'bonus_lendemain',4,$a$,
$b$   v_s := public.sante_repas_appliquer_interne(moi, 'clinique', 'repas_clinique', jsonb_build_object('mode', 'nuitee')); /* sante_suites_repas_clinique_v1 */
   SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name=moi;
   RETURN jsonb_build_object('ok',true,'mode','nuitee','pa',v_pa,
     'cout',v_cost,'bonus_lendemain',coalesce((v_s->>'pa_differe')::integer,0),
     'sante_gain',coalesce((v_s->>'gain')::integer,0),'hp',(v_s->>'apres')::integer,$b$, 1, 'sante_suites_repas_clinique_v1');

-- Patient hospitalisé : PA au prochain sommeil (repasBonus, mécanisme existant) lus dans les réglages.
SELECT pg_temp.rp_remplacer('public.hospitalisation_repas_prendre()'::regprocedure,
$a$ IF p.current_building = 'clinique-privee' THEN v_fn := 'repas_clinique'; v_bonus := 4;
 ELSIF coalesce(p.current_building,'') LIKE 'dispensaire-public%' THEN v_fn := 'repas_hopital'; v_bonus := 2;$a$,
$b$ IF p.current_building = 'clinique-privee' THEN v_fn := 'repas_clinique'; v_bonus := public.sante_param('repas_clinique_pa', 4)::integer; /* sante_suites_repas_pa_v1 */
 ELSIF coalesce(p.current_building,'') LIKE 'dispensaire-public%' THEN v_fn := 'repas_hopital'; v_bonus := public.sante_param('repas_hopital_pa', 2)::integer;$b$,
 1, 'sante_suites_repas_pa_v1');

-- Patient hospitalisé : la Santé du repas (hôpital +4, clinique +5), modulée par le Moral.
SELECT pg_temp.rp_remplacer('public.hospitalisation_repas_prendre()'::regprocedure,
$a$  WHERE name = moi RETURNING pa INTO v_pa;
 RETURN jsonb_build_object('ok',true,'pa',v_pa,'cout',v_cost,'bonus_lendemain',v_bonus,'jour',v_j,$a$,
$b$  WHERE name = moi RETURNING pa INTO v_pa;
 v_s := public.sante_gagner_interne(moi, public.sante_param(v_fn || '_sante', 0)::integer, v_fn,
   jsonb_build_object('mode', 'hospitalisation')); /* sante_suites_repas_hopital_v1 */
 RETURN jsonb_build_object('ok',true,'pa',v_pa,'cout',v_cost,'bonus_lendemain',v_bonus,'jour',v_j,
   'sante_gain',coalesce((v_s->>'gain')::integer,0),'hp',(v_s->>'apres')::integer,$b$, 1, 'sante_suites_repas_hopital_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- 3. Point 3 — repas du Président (Sovarka)
-- ---------------------------------------------------------------------------------------------------------------
SELECT pg_temp.rp_remplacer('public.sovarka_repas_presidentiel(text,text[])'::regprocedure,
$a$  SELECT montant INTO v_bonus FROM public.pa_bonus_differes WHERE source = 'diner_affaires';
  IF v_bonus IS DISTINCT FROM 3 THEN RAISE EXCEPTION 'bonus_diner_incompatible'; END IF;
  UPDATE public.personnages_donnees
     SET hp = least(100, coalesce(hp, 100) + 10), moral = least(100, coalesce(moral, 75) + 2),$a$,
$b$  -- sante_suites_president_v1 : Santé (modulée par le Moral) et PA différés de chacun, par le barème commun des repas.
  FOREACH v_i IN ARRAY (ARRAY[v_moi] || v_invites) LOOP
    PERFORM public.sante_repas_appliquer_interne(v_i, 'president', 'repas_presidentiel', '{}'::jsonb);
  END LOOP;
  v_bonus := public.sante_param('repas_president_pa', 3)::integer;
  UPDATE public.personnages_donnees
     SET moral = least(100, coalesce(moral, 75) + 2),$b$, 1, 'sante_suites_president_v1');

SELECT pg_temp.rp_remplacer('public.sovarka_repas_presidentiel(text,text[])'::regprocedure,
$a$         bonus_pa_differe = least(30, coalesce(bonus_pa_differe, 0) + v_bonus), updated_at = now()$a$,
$b$         updated_at = now() /* sante_suites_president_pa_v1 */$b$, 1, 'sante_suites_president_pa_v1');

SELECT pg_temp.rp_remplacer('public.sovarka_repas_presidentiel(text,text[])'::regprocedure,
$a$      || '(+10 Santé, +2 Moral, +5 INF, +3 PA au prochain Dormir).');$a$,
$b$      || '(+' || public.sante_param('repas_president_sante', 5)::integer::text || ' Santé selon votre Moral, +2 Moral, +5 INF, +'
      || v_bonus::text || ' PA au prochain Dormir).'); /* sante_suites_president_mail_v1 */$b$, 1, 'sante_suites_president_mail_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- 4. Point 7 — robustesse : se laisser faire face à une bête, répression, rébellion
-- ---------------------------------------------------------------------------------------------------------------
SELECT pg_temp.rp_remplacer('public.sovarka_foret_rencontre(uuid,text)'::regprocedure,
$a$    WITH g AS (
      SELECT d.name FROM public.personnages_donnees d
       WHERE (d.name = a OR d.name IN (SELECT membre FROM public.groupes_pj_adhesions WHERE chef = a))
         AND d.country = 'soviet' AND d.current_city = 'ville_b' AND d.current_building = 'zone-production' AND d.current_room = 'foret_vue_' || e.vue /* foret_rencontre_vue_v1 */
    ), u AS (
      UPDATE public.personnages_donnees d SET pa = 0, updated_at = now() FROM g WHERE d.name = g.name AND coalesce(d.pa, 0) > 0 RETURNING d.name)
    SELECT coalesce(jsonb_agg(name ORDER BY name), '[]'::jsonb) INTO v_victimes FROM u;
    r := jsonb_build_object('ok', true, 'choix', 'subir', 'victimes', v_victimes, 'pa', 0);$a$,
$b$    -- sante_suites_subir_v1 : la bête frappe chacun de toute sa réserve de PA (perte brute), multipliée par la robustesse
    -- (Santé au moment du coup), bornée aux PA restants ; chaque PA perdu retire blessure_sante_par_pa point(s) de Santé.
    v_victimes := '[]'::jsonb; l := '[]'::jsonb;
    FOR s IN SELECT d.name, coalesce(d.pa, 0) AS pa FROM public.personnages_donnees d
       WHERE (d.name = a OR d.name IN (SELECT membre FROM public.groupes_pj_adhesions WHERE chef = a))
         AND d.country = 'soviet' AND d.current_city = 'ville_b' AND d.current_building = 'zone-production' AND d.current_room = 'foret_vue_' || e.vue /* foret_rencontre_vue_v1 */
         AND coalesce(d.pa, 0) > 0 ORDER BY d.name FOR UPDATE
    LOOP
      v := public.sante_combat_coup_pj_interne(s.name, s.pa, s.pa, s.pa, 'foret_subir');
      UPDATE public.personnages_donnees SET pa = greatest(0, coalesce((v->>'pa_apres')::integer, 0)), updated_at = now() WHERE name = s.name;
      v_victimes := v_victimes || to_jsonb(s.name);
      l := l || jsonb_build_object('nom', s.name, 'pa_perdus', coalesce((v->>'perte')::integer, 0),
                                   'pa', coalesce((v->>'pa_apres')::integer, 0), 'sante_perdue', coalesce((v->>'sante_perdue')::integer, 0));
    END LOOP;
    r := jsonb_build_object('ok', true, 'choix', 'subir', 'victimes', v_victimes, 'pertes', l,
      'pa', (SELECT coalesce(pa, 0) FROM public.personnages_donnees WHERE name = a));$b$, 1, 'sante_suites_subir_v1');

SELECT pg_temp.rp_remplacer('public.manifestation_reprimer(text,text)'::regprocedure,
$a$       SET hp = greatest(1, coalesce(hp, 100) - 10),$a$,
$b$       SET hp = greatest(1, coalesce(hp, 100) - public.sante_perte_combat_interne(coalesce(hp, 100),
                 public.sante_param('repression_perte_sante', 10)::integer)), /* sante_suites_repression_v1 */$b$, 1, 'sante_suites_repression_v1');

SELECT pg_temp.rp_remplacer('public.detention_se_rebeller(integer,integer)'::regprocedure,
$a$    v_hp := greatest(1, coalesce(p.hp, 100) - 10);$a$,
$b$    v_hp := greatest(1, coalesce(p.hp, 100) - public.sante_perte_combat_interne(coalesce(p.hp, 100),
              public.sante_param('rebellion_reussie_perte_sante', 10)::integer)); /* sante_suites_rebellion_a_v1 */$b$, 1, 'sante_suites_rebellion_a_v1');
SELECT pg_temp.rp_remplacer('public.detention_se_rebeller(integer,integer)'::regprocedure,
$a$  v_hp := greatest(1, coalesce(p.hp, 100) - 25);$a$,
$b$  v_hp := greatest(1, coalesce(p.hp, 100) - public.sante_perte_combat_interne(coalesce(p.hp, 100),
            public.sante_param('rebellion_matee_perte_sante', 25)::integer)); /* sante_suites_rebellion_b_v1 */$b$, 1, 'sante_suites_rebellion_b_v1');
SELECT pg_temp.rp_remplacer('public.detention_se_rebeller(integer,integer)'::regprocedure,
$a$      'grilles', v_grilles, 'hp', v_hp, 'dis', least(100, v_dis + 6),$a$,
$b$      'grilles', v_grilles, 'hp', v_hp, 'sante_perdue', coalesce(p.hp, 100) - v_hp, 'dis', least(100, v_dis + 6), /* sante_suites_rebellion_c_v1 */$b$,
 1, 'sante_suites_rebellion_c_v1');
SELECT pg_temp.rp_remplacer('public.detention_se_rebeller(integer,integer)'::regprocedure,
$a$    'grilles', NULL, 'hp', v_hp, 'dis', greatest(0, v_dis - 15), 'qhs', false,$a$,
$b$    'grilles', NULL, 'hp', v_hp, 'sante_perdue', coalesce(p.hp, 100) - v_hp, 'dis', greatest(0, v_dis - 15), 'qhs', false, /* sante_suites_rebellion_d_v1 */$b$,
 1, 'sante_suites_rebellion_d_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- 5. Point 9 — dons de tracts : plafond commun du destinataire
-- ---------------------------------------------------------------------------------------------------------------
SELECT pg_temp.rp_remplacer('public.tracts_donner_joueur(uuid,integer,bigint,text,integer)'::regprocedure,
$a$ UPDATE public.personnages_donnees SET inventory=CASE WHEN total=p_quantite THEN inventory-p_index$a$,
$b$ IF greatest(1, public.inventaire_unites_interne(jsonb_build_array(o||jsonb_build_object('quantite',p_quantite))))
    > coalesce(public.inventaire_place_destinataire_interne(d.name),0) THEN /* sante_suites_tracts_plafond_v1 */
  RETURN jsonb_build_object('ok',false,'raison','destinataire_plein','place',coalesce(public.inventaire_place_destinataire_interne(d.name),0),
    'destinataire',d.name,'demande',greatest(1, public.inventaire_unites_interne(jsonb_build_array(o||jsonb_build_object('quantite',p_quantite)))));
 END IF;
 UPDATE public.personnages_donnees SET inventory=CASE WHEN total=p_quantite THEN inventory-p_index$b$, 1, 'sante_suites_tracts_plafond_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- 6. Point 11 — marchés : règle commune de rachat, prix de fabrication, confiture du kolkhoze
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.marches_prix_rachat_interne(p_prix numeric)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Règle commune de TOUS les marchés (Fred, 22/11/2026 au soir) : 30 % sous le prix de vente, arrondi à l'unité,
  -- et au moins marches_rachat_ecart_min d'écart. /* sante_suites_rachat_v1 */
  SELECT greatest(0, least(round(coalesce(p_prix, 0) * public.aliments_param_interne('marches_rachat_taux', 0.7)),
                           coalesce(p_prix, 0) - public.aliments_param_interne('marches_rachat_ecart_min', 1)))::integer
$function$;
REVOKE ALL ON FUNCTION public.marches_prix_rachat_interne(numeric) FROM PUBLIC, anon, authenticated;

-- Le rachat suit toujours le prix de vente et la règle commune (aucune saisie possible d'un rachat hors règle).
CREATE OR REPLACE FUNCTION public.marche_krasnov_produits_rachat_trg()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  NEW.prix_rachat := public.marches_prix_rachat_interne(NEW.prix_vente); /* sante_suites_rachat_v1 */
  RETURN NEW;
END $function$;
DROP TRIGGER IF EXISTS marche_krasnov_produits_rachat ON public.marche_krasnov_produits;
CREATE TRIGGER marche_krasnov_produits_rachat BEFORE INSERT OR UPDATE ON public.marche_krasnov_produits
  FOR EACH ROW EXECUTE FUNCTION public.marche_krasnov_produits_rachat_trg();

-- Le MJ change le taux ou l'écart : tous les rachats sont réalignés aussitôt.
CREATE OR REPLACE FUNCTION public.marches_rachat_realigner_trg()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.cle IN ('marches_rachat_taux', 'marches_rachat_ecart_min') THEN
    UPDATE public.marche_krasnov_produits SET prix_rachat = prix_rachat; /* déclencheur ligne : règle commune */
  END IF;
  RETURN NULL; /* sante_suites_rachat_v1 */
END $function$;
DROP TRIGGER IF EXISTS marches_rachat_realigner ON public.aliments_parametres;
CREATE TRIGGER marches_rachat_realigner AFTER INSERT OR UPDATE ON public.aliments_parametres
  FOR EACH ROW EXECUTE FUNCTION public.marches_rachat_realigner_trg();

-- Règle commune de fabrication (GAME-DESIGN-KRASNOV-LOT-20261120.md, point 2) : (matières au prix du marché + salaire de
-- production × PA) / unités × 2, arrondi à l'unité. Confiture 10, pain noir 8, goulash 13 (inchangés), chemise 18 → 17.
UPDATE public.marche_krasnov_produits p
   SET prix_vente = round(((SELECT coalesce(sum(m.prix_vente * (r.value #>> '{}')::numeric), 0)
                              FROM jsonb_each(p.recette) r JOIN public.marche_krasnov_produits m ON m.cle = r.key)
                           + public.aliments_param_interne('marche_krasnov_salaire_pa', 15) * p.pa) / p.unites * 2)::integer
 WHERE p.genre = 'transforme' AND p.recette IS NOT NULL AND p.unites > 0;
-- Tous les produits : rachat selon la règle commune (le déclencheur le recalcule).
UPDATE public.marche_krasnov_produits SET prix_rachat = prix_rachat;

-- Point 1 : en Sovarka, l'en-cas s'appelle « zakouski ».
UPDATE public.marche_krasnov_produits
   SET effet = 'Se mangent crus : un zakouski (Santé, selon le barème des repas ; un seul repas brut par nuit).'
 WHERE cle = 'fruits_legumes' AND effet = 'Se mangent crus : un en-cas (Santé, selon le barème des repas ; un seul repas brut par nuit).';

-- Kolkhoze de Starovka : la confiture à 10 PSK, prix fixe (commerce_produire ne la recalcule plus).
UPDATE public.recettes_commerce SET prix_fixe = 10 WHERE id = 'kolkhoze_confiture_airelles' AND prix_fixe IS DISTINCT FROM 10;
UPDATE public.entreprises
   SET data = jsonb_set(data, '{parametres,prixVente,kolkhoze_confiture_airelles}', '10'::jsonb, true), updated_at = now()
 WHERE id = 'tabac-presse-soviet-ville_a-magasin-kolkhoze-starovka'
   AND (data #>> '{parametres,prixVente,kolkhoze_confiture_airelles}') IS DISTINCT FROM '10';
UPDATE public.commerces_dotations
   SET parametres = jsonb_set(parametres, '{prixVente,kolkhoze_confiture_airelles}', '10'::jsonb, true)
 WHERE cle = 'magasin-kolkhoze-starovka@soviet.ville_a'
   AND (parametres #>> '{prixVente,kolkhoze_confiture_airelles}') IS DISTINCT FROM '10';

-- Réglage MJ des deux paramètres de la règle (taux entre 0 et 1, écart entier ≥ 0) et de la dotation du marché.
SELECT pg_temp.rp_remplacer('public.admin_aliment_modifier(text,numeric)'::regprocedure,
$a$  IF p_cle NOT IN ('peremption_jours', 'detection_base', 'detection_bandelette', 'prix_bandelette') OR p_valeur IS NULL OR p_valeur < 0$a$,
$b$  IF p_cle NOT IN ('peremption_jours', 'detection_base', 'detection_bandelette', 'prix_bandelette',
                   'marches_rachat_taux', 'marches_rachat_ecart_min', 'marche_krasnov_dotation') OR p_valeur IS NULL OR p_valeur < 0
     OR (p_cle = 'marches_rachat_taux' AND p_valeur > 1) OR (p_cle = 'marches_rachat_ecart_min' AND p_valeur <> trunc(p_valeur)) /* sante_suites_rachat_mj_v1 */$b$,
 1, 'sante_suites_rachat_mj_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- 7. Point 13 — objectif secret du criminel : 5 informations achetées à des informateurs différents
-- ---------------------------------------------------------------------------------------------------------------
SELECT pg_temp.rp_remplacer('public.objectifs_secrets_eligibles_interne(text)'::regprocedure,
$a$ CASE WHEN a.archetype='criminel'AND CASE WHEN jsonb_typeof(a.informateurs)='array'THEN jsonb_array_length(a.informateurs)ELSE 0 END>=2 THEN 'obj_informateur'END,$a$,
$b$ CASE WHEN a.archetype='criminel'AND (SELECT count(DISTINCT i.informateur) FROM public.informateurs_achats i WHERE i.acteur=a.name)
   >=public.crim_param_interne('objectif_informateurs_distincts',5) THEN 'obj_informateur'END, /* sante_suites_obj_informateur_v1 */$b$,
 1, 'sante_suites_obj_informateur_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- 8. Contrôles
-- ---------------------------------------------------------------------------------------------------------------
DO $$
BEGIN
  IF public.sante_repas_joueur_categorie_interne(15) <> 'joueur_p15' OR public.sante_repas_joueur_categorie_interne(14.99) <> 'joueur_p10' THEN
    RAISE EXCEPTION 'sante_suites : palier 15'; END IF;
  IF EXISTS (SELECT 1 FROM public.marche_krasnov_produits
              WHERE prix_rachat <> public.marches_prix_rachat_interne(prix_vente) OR prix_rachat > prix_vente - 1) THEN
    RAISE EXCEPTION 'sante_suites : rachat hors règle'; END IF;
  IF (SELECT prix_vente FROM public.marche_krasnov_produits WHERE cle = 'chemise') IS DISTINCT FROM 17 THEN
    RAISE EXCEPTION 'sante_suites : chemise'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'repas_hopital' AND cost = 0)
     OR NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'repas_clinique' AND cost = 30) THEN
    RAISE EXCEPTION 'sante_suites : tarifs des repas de l''hôpital et de la clinique'; END IF;
END $$;
