-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920225218
-- Nom original      : militaire_combat_moteur_v2
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 22:52:18 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 159c5a39bafe2e30c38b8b539c7466b4
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =====================================================================
-- MOTEUR DE COMBAT V2 — COMBATTANTS, CIBLAGE, APPLICATION (21 sept. 2026)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. LES COMBATTANTS — avec leur arme reelle
-- ---------------------------------------------------------------------
-- CORRECTION DU BUG D'AUDIT : l'ancienne detection testait
-- `sousType IN ('poing','carabine')`, or militaire_retrait pose
-- `sousType = 'militaire'`. Un PJ arme d'une mitraillette de sa propre
-- caserne basculait donc en corps-a-corps. On ne teste plus le sousType :
-- l'arme est resolue par le MIROIR, avec `produitMilitaire` (ecrit par le
-- serveur, donc infalsifiable) en priorite et le nom du catalogue civil
-- sinon. Le type reel est conserve : la cle rendue distingue +8 de +15.
--
-- Un combattant qui porte plusieurs armes se bat avec la MEILLEURE. S'il a
-- une arme a feu il tire ; sinon il va au corps-a-corps, avec ou sans lame.
DROP FUNCTION IF EXISTS public.militaire_bataille_combattants(bigint, text);

CREATE FUNCTION public.militaire_bataille_combattants(p_bataille_id bigint, p_camp text)
RETURNS TABLE(eng_id bigint, est_pj boolean, nom text, compagnie_id text, section_id text,
              matricule text, pa integer, comp_tir numeric, comp_cac numeric,
              arme_feu boolean, arme_cle text, bonus_arme integer,
              def_per numeric, def_dup numeric, saute_round integer, groupe_id text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT e.id, true, e.personnage, e.compagnie_id, e.section_id, NULL::text,
         greatest(0, coalesce(pd.pa, 0)),
         coalesce((pd.competences_militaires->>'tir')::numeric, 0),
         coalesce((pd.competences_militaires->>'combat_rapproche')::numeric, 0),
         (af.cle IS NOT NULL),
         coalesce(af.cle, ac.cle),
         coalesce(af.bonus, ac.bonus, 0),
         public.assemblee_stat_base(pd.stats, 'PER'),
         public.assemblee_stat_base(pd.stats, 'DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.personnages_donnees pd ON pd.name = e.personnage
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'feu'
       ORDER BY b.bonus DESC LIMIT 1) af ON true
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'cac'
       ORDER BY b.bonus DESC LIMIT 1) ac ON true
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.personnage IS NOT NULL AND e.sorti_round IS NULL

  UNION ALL

  SELECT e.id, false, sol->>'nom', e.compagnie_id, e.section_id, e.matricule,
         greatest(0, coalesce((sol->>'pa')::integer, 0)),
         coalesce((sol->'formation'->>'tir')::numeric, 0),
         coalesce((sol->'formation'->>'combat_rapproche')::numeric, 0),
         coalesce(sol->>'arme','corps_a_corps') IN ('arme_de_poing','mitraillette'),
         coalesce(sol->>'arme','corps_a_corps'),
         public.militaire_bonus_arme(coalesce(sol->>'arme','corps_a_corps'),
           CASE WHEN coalesce(sol->>'arme','corps_a_corps') IN ('arme_de_poing','mitraillette')
                THEN 'feu' ELSE 'cac' END),
         public.militaire_defense_pnj('PER'),
         public.militaire_defense_pnj('DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.compagnies_militaires c ON c.id = e.compagnie_id
    CROSS JOIN LATERAL jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s
    CROSS JOIN LATERAL jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.matricule IS NOT NULL AND e.sorti_round IS NULL
     AND s->>'id' = e.section_id AND sol->>'matricule' = e.matricule;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_combattants(bigint, text) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 2. LES CAMPS HOSTILES — une bataille peut en compter plus de deux
-- ---------------------------------------------------------------------
-- L'hostilite est lue PAIRE PAR PAIRE dans `guerres`. On n'en deduit jamais
-- que l'ennemi de mon ennemi est mon allie : la seule question posee est
-- « ce camp-la est-il en guerre avec le mien ? ».
CREATE OR REPLACE FUNCTION public.militaire_camps_hostiles(p_bataille_id bigint, p_camp text)
RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public' AS $function$
  SELECT coalesce(array_agg(DISTINCT e.camp), '{}')
    FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id
     AND e.sorti_round IS NULL
     AND e.camp IS DISTINCT FROM p_camp
     AND EXISTS (SELECT 1 FROM public.guerres g
                  WHERE g.statut = 'active'
                    AND ((g.data->>'attaquant' = p_camp AND g.data->>'attaque'  = e.camp)
                      OR (g.data->>'attaque'  = p_camp AND g.data->>'attaquant' = e.camp)));
$function$;

REVOKE ALL ON FUNCTION public.militaire_camps_hostiles(bigint, text) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 3. LE PASSAGE D'UN CAMP
-- ---------------------------------------------------------------------
-- CIBLAGE : le pool ennemi rassemble TOUS les combattants des camps
-- hostiles presents, sans repartition imposee entre eux, et le tirage reste
-- aleatoire.
--
-- CIBLE PRIVILEGIEE — modalite technique retenue : un combattant qui engage
-- le corps-a-corps (il n'a pas d'arme a feu) entre DEUX FOIS dans l'urne des
-- tireurs ennemis, une seule fois dans celle des combattants au corps-a-corps.
-- C'est une ponderation du meme tirage aleatoire : aucune grille, aucune
-- distance, aucun ordre de charge.
--
-- SURPRISE : au premier echange du camp surprenant seulement, le degre monte
-- d'un cran. Le 1 NATUREL reste un echec critique -- le plancher
-- incompressible n'est pas annulable par la surprise.
DROP FUNCTION IF EXISTS public.militaire_bataille_actions(bigint, text, text, integer);

CREATE FUNCTION public.militaire_bataille_actions(
  p_bataille_id bigint, p_camp_att text, p_round integer, p_surprise boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_res jsonb := '[]'::jsonb;
  a record; k integer; n integer; v_hostiles text[];
  d_eng bigint[]; d_pj boolean[]; d_nom text[]; d_cie text[]; d_sec text[]; d_mat text[];
  d_camp text[]; d_per numeric[]; d_dup numeric[]; d_tir numeric[]; d_cac numeric[];
  d_feu boolean[]; u_tir integer[]; u_cac integer[]; v_urne integer[];
  v_mode text; v_taux integer; v_jet integer; v_degre text;
BEGIN
  v_hostiles := public.militaire_camps_hostiles(p_bataille_id, p_camp_att);
  IF coalesce(array_length(v_hostiles, 1), 0) = 0 THEN RETURN v_res; END IF;

  SELECT array_agg(c.eng_id ORDER BY c.eng_id), array_agg(c.est_pj ORDER BY c.eng_id),
         array_agg(c.nom ORDER BY c.eng_id), array_agg(c.compagnie_id ORDER BY c.eng_id),
         array_agg(c.section_id ORDER BY c.eng_id), array_agg(c.matricule ORDER BY c.eng_id),
         array_agg(c.camp ORDER BY c.eng_id), array_agg(c.def_per ORDER BY c.eng_id),
         array_agg(c.def_dup ORDER BY c.eng_id), array_agg(c.comp_tir ORDER BY c.eng_id),
         array_agg(c.comp_cac ORDER BY c.eng_id), array_agg(c.arme_feu ORDER BY c.eng_id)
    INTO d_eng, d_pj, d_nom, d_cie, d_sec, d_mat, d_camp, d_per, d_dup, d_tir, d_cac, d_feu
    FROM (SELECT x.*, h.camp
            FROM unnest(v_hostiles) AS h(camp)
            CROSS JOIN LATERAL public.militaire_bataille_combattants(p_bataille_id, h.camp) x) c;
  n := coalesce(array_length(d_eng, 1), 0);
  IF n = 0 THEN RETURN v_res; END IF;

  -- Urne de base : un jeton par ennemi.
  SELECT coalesce(array_agg(i ORDER BY i), '{}') INTO u_cac FROM generate_series(1, n) AS g(i);
  -- Urne des tireurs : un second jeton pour chaque ennemi au corps-a-corps.
  SELECT u_cac || coalesce(array_agg(i ORDER BY i), '{}') INTO u_tir
    FROM generate_series(1, n) AS g(i) WHERE NOT coalesce(d_feu[g.i], false);

  FOR a IN
    SELECT * FROM public.militaire_bataille_combattants(p_bataille_id, p_camp_att)
     WHERE saute_round IS DISTINCT FROM p_round
  LOOP
    v_mode := CASE WHEN a.arme_feu THEN 'feu' ELSE 'cac' END;
    v_urne := CASE WHEN a.arme_feu THEN u_tir ELSE u_cac END;
    k := v_urne[1 + floor(random() * array_length(v_urne, 1))::integer];

    -- La competence qui DEFEND est celle du meme domaine que l'attaque subie.
    v_taux := public.militaire_taux_combat(
      CASE WHEN a.arme_feu THEN a.comp_tir ELSE a.comp_cac END,
      CASE WHEN a.arme_feu THEN d_tir[k]   ELSE d_cac[k]   END,
      CASE WHEN a.arme_feu THEN d_per[k]   ELSE d_dup[k]   END,
      a.bonus_arme);
    v_jet   := floor(random() * 100)::integer + 1;
    v_degre := public.militaire_degre_combat(v_taux, v_jet);

    IF coalesce(p_surprise, false) AND v_jet <> 1 THEN
      v_degre := public.militaire_degre_par_rang(public.militaire_degre_rang(v_degre) + 1);
    END IF;

    v_res := v_res || jsonb_build_array(jsonb_build_object(
      'camp_attaquant', p_camp_att,
      'att_eng', a.eng_id, 'att_pj', a.est_pj, 'att_nom', a.nom, 'att_mat', a.matricule,
      'att_arme', a.arme_cle, 'att_bonus', a.bonus_arme, 'att_groupe', a.groupe_id,
      'cib_eng', d_eng[k], 'cib_pj', d_pj[k], 'cib_nom', d_nom[k], 'cib_mat', d_mat[k],
      'cib_cie', d_cie[k], 'cib_sec', d_sec[k], 'cib_camp', d_camp[k],
      'mode', v_mode, 'taux', v_taux, 'jet', v_jet, 'degre', v_degre,
      'surprise', coalesce(p_surprise, false)));
  END LOOP;
  RETURN v_res;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_actions(bigint, text, integer, boolean) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 4. APPLICATION — pertes proportionnelles et gilet
-- ---------------------------------------------------------------------
-- Les PA restants sont arrondis a l'entier INFERIEUR.
--
-- GILET : feu uniquement, jamais corps-a-corps, et SEULEMENT si le tir
-- devait faire tomber la cible a 0 PA. Un gilet intact donne 50 % de
-- protection ; en cas de succes le degre est ABAISSE D'UN CRAN et la cible
-- conserve au minimum 1 PA. En cas d'echec, le resultat initial s'applique
-- et le gilet reste intact.
CREATE OR REPLACE FUNCTION public.militaire_bataille_appliquer(
  p_bataille_id bigint, p_actions jsonb, p_round integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  act jsonb; v_pa integer; v_new integer; v_gilet jsonb; v_degre text; v_abaisse text;
BEGIN
  FOR act IN SELECT value FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb))
  LOOP
    v_degre := act->>'degre';

    IF v_degre = 'echec_critique' THEN
      UPDATE public.batailles_engagements SET saute_round = p_round + 1
       WHERE id = (act->>'att_eng')::bigint AND sorti_round IS NULL;
      CONTINUE;
    END IF;
    CONTINUE WHEN public.militaire_degats_pct(v_degre) = 0;

    CONTINUE WHEN NOT EXISTS (SELECT 1 FROM public.batailles_engagements
                               WHERE id = (act->>'cib_eng')::bigint AND sorti_round IS NULL);

    SELECT pa INTO v_pa FROM public.militaire_bataille_combattants(
      p_bataille_id, act->>'cib_camp') WHERE eng_id = (act->>'cib_eng')::bigint;
    CONTINUE WHEN v_pa IS NULL;

    v_new := public.militaire_pa_restants(v_pa, v_degre);

    IF v_new = 0 AND act->>'mode' = 'feu' THEN
      v_gilet := public.militaire_gilet_absorber(
        (act->>'cib_pj')::boolean, act->>'cib_nom',
        act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      IF coalesce((v_gilet->>'protege')::boolean, false) THEN
        v_abaisse := public.militaire_degre_par_rang(public.militaire_degre_rang(v_degre) - 1);
        v_new := greatest(1, public.militaire_pa_restants(v_pa, v_abaisse));
      END IF;
    END IF;

    IF (act->>'cib_pj')::boolean THEN
      UPDATE public.personnages_donnees SET pa = v_new WHERE name = act->>'cib_nom';
    ELSE
      PERFORM public.militaire_soldat_pa_fixer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat', v_new);
    END IF;

    CONTINUE WHEN v_new > 0;

    IF (act->>'cib_pj')::boolean THEN
      UPDATE public.personnages_donnees
         SET current_city = 'caserne', current_building = 'caserne-militaire',
             current_room = 'infirmerie'
       WHERE name = act->>'cib_nom';
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'neutralise'
       WHERE id = (act->>'cib_eng')::bigint;
    ELSE
      PERFORM public.militaire_soldat_supprimer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'mort'
       WHERE id = (act->>'cib_eng')::bigint;
    END IF;
  END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_appliquer(bigint, jsonb, integer) FROM PUBLIC, anon, authenticated;