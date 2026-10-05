-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918151520
-- Nom original      : combat_actions_application_rapport
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 15:15:20 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ae2cabf3eecbc165b2f9b73534803836
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
-- =========================================================================================
-- CALCUL DES ACTIONS D'UNE PASSE
-- =========================================================================================
-- UN combattant -> UNE cible tiree au sort -> UN jet. Le tirage est independant pour chaque
-- attaquant (LATERAL + ORDER BY random()), donc plusieurs attaquants peuvent viser le meme
-- adversaire et aucun equilibrage des cibles n'est applique. Le leader adverse entre dans le
-- meme tirage que les autres : aucun ciblage volontaire en V1.
--
-- CHOIX DU MODE : arme a feu si le combattant en porte reellement une, sinon corps-a-corps. Tous
-- les combattants d'une bataille sont dans la MEME piece -- il n'y a donc pas de notion de
-- distance tactique a arbitrer, et les deux modes sont implementes.
CREATE OR REPLACE FUNCTION public.militaire_bataille_actions(
  p_bataille_id bigint, p_camp_att text, p_camp_def text, p_round integer)
RETURNS jsonb LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'camp_attaquant', p_camp_att,
    'att_eng', a.eng_id, 'att_pj', a.est_pj, 'att_nom', a.nom, 'att_mat', a.matricule,
    'cib_eng', c.eng_id, 'cib_pj', c.est_pj, 'cib_nom', c.nom, 'cib_mat', c.matricule,
    'cib_cie', c.compagnie_id, 'cib_sec', c.section_id, 'cib_camp', p_camp_def,
    'mode', m.mode, 'taux', m.taux, 'jet', m.jet,
    'degre', public.militaire_degre_combat(m.taux, m.jet),
    'degats', public.militaire_degats_combat(public.militaire_degre_combat(m.taux, m.jet))
  )), '[]'::jsonb)
  FROM public.militaire_bataille_combattants(p_bataille_id, p_camp_att) a
  CROSS JOIN LATERAL (
    SELECT d.* FROM public.militaire_bataille_combattants(p_bataille_id, p_camp_def) d
     ORDER BY random() LIMIT 1) c
  CROSS JOIN LATERAL (
    SELECT CASE WHEN a.arme_feu THEN 'feu' ELSE 'cac' END AS mode,
           public.militaire_taux_combat(
             CASE WHEN a.arme_feu THEN a.comp_tir ELSE a.comp_cac END,
             CASE WHEN a.arme_feu THEN c.def_per ELSE c.def_dup END) AS taux,
           floor(random() * 100)::integer + 1 AS jet) m
  -- Un combattant qui saute ce round reste present, ciblable et vulnerable : il ne produit
  -- simplement aucun jet.
  WHERE a.saute_round IS DISTINCT FROM p_round;
$$;

-- =========================================================================================
-- APPLICATION DES CONSEQUENCES
-- =========================================================================================
-- Les degats se cumulent dans l'ordre du lot : la simultaneite porte sur le fait que chacun AGIT,
-- pas sur le fait que les degats s'ignoreraient entre eux.
CREATE OR REPLACE FUNCTION public.militaire_bataille_appliquer(
  p_bataille_id bigint, p_actions jsonb, p_round integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  act jsonb; v_pa integer; v_new integer; v_gilet jsonb; v_pays text;
BEGIN
  FOR act IN SELECT value FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb))
  LOOP
    IF act->>'degre' = 'echec_critique' THEN
      UPDATE public.batailles_engagements SET saute_round = p_round + 1
       WHERE id = (act->>'att_eng')::bigint AND sorti_round IS NULL;
      CONTINUE;
    END IF;
    CONTINUE WHEN coalesce((act->>'degats')::integer, 0) = 0;

    -- La cible peut etre deja sortie a cause d'une action precedente du meme lot.
    CONTINUE WHEN NOT EXISTS (SELECT 1 FROM public.batailles_engagements
                               WHERE id = (act->>'cib_eng')::bigint AND sorti_round IS NULL);

    SELECT pa INTO v_pa FROM public.militaire_bataille_combattants(
      p_bataille_id, act->>'cib_camp') WHERE eng_id = (act->>'cib_eng')::bigint;
    CONTINUE WHEN v_pa IS NULL;
    v_new := greatest(0, v_pa - (act->>'degats')::integer);

    -- GILET : uniquement contre une ARME A FEU, uniquement quand le coup ferait tomber la cible
    -- hors de combat. Une reussite laisse le combattant EN JEU -- donc a 1 PA, puisque 0 PA est
    -- precisement la definition de « hors de combat » dans ce moteur.
    IF v_new = 0 AND act->>'mode' = 'feu' THEN
      v_gilet := public.militaire_gilet_absorber(
        (act->>'cib_pj')::boolean, act->>'cib_nom',
        act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      IF coalesce((v_gilet->>'protege')::boolean, false) THEN v_new := 1; END IF;
    END IF;

    IF (act->>'cib_pj')::boolean THEN
      UPDATE public.personnages_donnees SET pa = v_new WHERE name = act->>'cib_nom';
    ELSE
      PERFORM public.militaire_soldat_pa_fixer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat', v_new);
    END IF;

    CONTINUE WHEN v_new > 0;

    -- ---- HORS DE COMBAT ----
    IF (act->>'cib_pj')::boolean THEN
      -- PJ : NEUTRALISE, jamais mort. Transfere a l'Infirmerie de SA propre caserne -- son pays
      -- ne change pas, et 'caserne' est la meme zone speciale dans les quatre empires.
      UPDATE public.personnages_donnees
         SET current_city = 'caserne', current_building = 'caserne-militaire',
             current_room = 'infirmerie'
       WHERE name = act->>'cib_nom';
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'neutralise'
       WHERE id = (act->>'cib_eng')::bigint;
    ELSE
      -- PNJ : MORT. Suppression reelle du soldat, donc diminution definitive du contingent.
      -- Aucun retour en reserve, aucune resurrection : l'invariant « PNJ vivants + reserve <=
      -- contingentInitial » reste vrai et devient strictement plus petit.
      PERFORM public.militaire_soldat_supprimer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'mort'
       WHERE id = (act->>'cib_eng')::bigint;
    END IF;
  END LOOP;
END;
$$;

-- Ecriture des PA d'un soldat PNJ a sa source canonique, dans la compagnie.
CREATE OR REPLACE FUNCTION public.militaire_soldat_pa_fixer(
  p_compagnie_id text, p_section_id text, p_matricule text, p_pa integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_data jsonb; v_sec jsonb; v_sols jsonb;
BEGIN
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN; END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN; END IF;
  SELECT coalesce(jsonb_agg(CASE WHEN sol->>'matricule' = p_matricule
           THEN sol || jsonb_build_object('pa', greatest(0, p_pa)) ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END)
      WITH ORDINALITY AS t(sol, pos);
  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.militaire_soldat_supprimer(
  p_compagnie_id text, p_section_id text, p_matricule text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_data jsonb; v_sec jsonb; v_sols jsonb;
BEGIN
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN; END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN; END IF;
  SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
    FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END)
      WITH ORDINALITY AS t(sol, pos)
   WHERE sol->>'matricule' IS DISTINCT FROM p_matricule;
  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
END;
$$;

-- =========================================================================================
-- RAPPORT D'UN ROUND, DU POINT DE VUE D'UN CAMP
-- =========================================================================================
-- Ce que le camp connait exactement : SES combattants, SES pertes de PA, SES morts, SES
-- neutralises. Ce qu'il ne connait pas : la fatigue adverse, la composition adverse, les jets.
-- Ce qu'il observe raisonnablement : les adversaires qui TOMBENT devant lui, et un ordre de
-- grandeur de ce qui reste debout -- rendu par militaire_degrader, la meme degradation que la
-- reconnaissance. Ni taux, ni de, ni formule ne figurent dans le rapport.
CREATE OR REPLACE FUNCTION public.militaire_bataille_rapport(
  p_bataille_id bigint, p_camp text, p_camp_adverse text, p_round integer,
  p_actions jsonb, p_reste_moi integer, p_reste_adverse integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  b record; v_pa_perdus integer; v_touches integer; v_morts integer; v_neutralises integer;
  v_tombes_adverse integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id;

  SELECT coalesce(sum((a->>'degats')::integer), 0),
         count(*) FILTER (WHERE (a->>'degats')::integer > 0)
    INTO v_pa_perdus, v_touches
    FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb)) a
   WHERE a->>'cib_camp' = p_camp;

  SELECT count(*) FILTER (WHERE etat_final = 'mort'),
         count(*) FILTER (WHERE etat_final = 'neutralise')
    INTO v_morts, v_neutralises
    FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND camp = p_camp AND sorti_round = p_round;

  SELECT count(*) INTO v_tombes_adverse FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND camp = p_camp_adverse AND sorti_round = p_round;

  RETURN jsonb_build_object(
    'round', p_round,
    'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
    'mon_camp', p_camp,
    'mes_combattants_restants', p_reste_moi,
    'mes_pa_perdus', v_pa_perdus,
    'mes_combattants_touches', v_touches,
    'mes_morts_pnj', v_morts,
    'mes_pj_neutralises', v_neutralises,
    -- Observable : on voit tomber des adversaires. On ne voit ni leur fatigue ni leur registre.
    'adversaires_tombes', v_tombes_adverse,
    'adversaire_estime', CASE WHEN p_reste_adverse > 0
      THEN public.militaire_degrader('proche', p_reste_adverse, p_camp_adverse, b.ville, b.batiment)
      ELSE jsonb_build_object('libelle', 'plus aucun adversaire debout') END,
    'termine', (p_reste_moi = 0 OR p_reste_adverse = 0));
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_bataille_actions(bigint, text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_bataille_appliquer(bigint, jsonb, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_soldat_pa_fixer(text, text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_soldat_supprimer(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_bataille_rapport(bigint, text, text, integer, jsonb, integer, integer) FROM PUBLIC, anon, authenticated;