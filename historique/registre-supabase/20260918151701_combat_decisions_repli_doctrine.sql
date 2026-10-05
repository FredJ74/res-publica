-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918151701
-- Nom original      : combat_decisions_repli_doctrine
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 15:17:01 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 60c655f161827fbf60eadc78b5f82086
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
-- DECISIONS, REPLI ET DOCTRINE (19 septembre 2026)
-- =========================================================================================
-- LA DECONNEXION NE SUSPEND JAMAIS LE MONDE. `militaire_bataille_avancer` applique la doctrine
-- enregistree a tout camp qui n'a pas explicitement decide. Un chef connecte pose donc sa
-- decision AVANT de faire avancer le round, et c'est ainsi que le choix humain prime : il est
-- deja ecrit quand le serveur regarde. Un chef absent n'a rien ecrit, sa doctrine s'applique, et
-- l'adversaire n'attend pas.
CREATE OR REPLACE FUNCTION public.militaire_bataille_decision_effective(
  p_bataille_id bigint, p_camp text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE b record; v_dec text; v_doc text; v_init integer; v_reste integer; v_repli jsonb;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id;
  IF p_camp = b.camp_a THEN v_dec := b.decision_a; v_doc := b.doctrine_a;
                            v_init := b.effectif_initial_a; v_repli := b.repli_a;
                       ELSE v_dec := b.decision_b; v_doc := b.doctrine_b;
                            v_init := b.effectif_initial_b; v_repli := b.repli_b; END IF;
  IF v_dec IS NULL THEN
    IF v_doc = 'repli_50' THEN
      SELECT count(*) INTO v_reste FROM public.militaire_bataille_combattants(p_bataille_id, p_camp);
      -- SEUIL CALCULE SUR L'EFFECTIF INITIAL DE CETTE BATAILLE, jamais recalcule round par round.
      v_dec := CASE WHEN v_reste * 2 <= coalesce(v_init, 0) THEN 'replier' ELSE 'continuer' END;
    ELSE
      v_dec := 'continuer';
    END IF;
  END IF;
  -- Un camp sans position de repli connue ne peut pas se replier : il tient, et le rapport le dit.
  IF v_dec = 'replier' AND v_repli IS NULL THEN v_dec := 'continuer'; END IF;
  RETURN v_dec;
END;
$$;

CREATE OR REPLACE FUNCTION public.militaire_bataille_avancer(p_bataille_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  b record; v_a text; v_bb text; v_actions jsonb; v_round integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  v_a  := public.militaire_bataille_decision_effective(p_bataille_id, b.camp_a);
  v_bb := public.militaire_bataille_decision_effective(p_bataille_id, b.camp_b);

  IF v_a = 'continuer' AND v_bb = 'continuer' THEN
    RETURN public.militaire_bataille_round(p_bataille_id);
  END IF;

  v_round := b.round_courant + 1;

  IF v_a = 'replier' AND v_bb = 'replier' THEN
    -- Separation : aucun passage supplementaire, chacun rejoint sa position de repli.
    PERFORM public.militaire_bataille_decrocher(p_bataille_id, b.camp_a, b.repli_a, v_round);
    PERFORM public.militaire_bataille_decrocher(p_bataille_id, b.camp_b, b.repli_b, v_round);
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(),
           issue = 'repli_mutuel', termine_raison = 'repli_mutuel', round_courant = v_round
     WHERE id = p_bataille_id;
    RETURN jsonb_build_object('ok', true, 'round', v_round, 'issue', 'repli_mutuel', 'terminee', true);
  END IF;

  -- LE REPLI N'EST PAS GRATUIT : le camp qui reste obtient un dernier passage de decrochage, et
  -- celui qui decroche ne riposte pas.
  IF v_a = 'replier' THEN
    v_actions := public.militaire_bataille_actions(p_bataille_id, b.camp_b, b.camp_a, v_round);
    PERFORM public.militaire_bataille_appliquer(p_bataille_id, v_actions, v_round);
    PERFORM public.militaire_bataille_decrocher(p_bataille_id, b.camp_a, b.repli_a, v_round);
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(),
           issue = 'repli_' || b.camp_a, termine_raison = 'repli', round_courant = v_round
     WHERE id = p_bataille_id;
  ELSE
    v_actions := public.militaire_bataille_actions(p_bataille_id, b.camp_a, b.camp_b, v_round);
    PERFORM public.militaire_bataille_appliquer(p_bataille_id, v_actions, v_round);
    PERFORM public.militaire_bataille_decrocher(p_bataille_id, b.camp_b, b.repli_b, v_round);
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(),
           issue = 'repli_' || b.camp_b, termine_raison = 'repli', round_courant = v_round
     WHERE id = p_bataille_id;
  END IF;

  INSERT INTO public.batailles_rounds (bataille_id, numero, camp, rapport)
  SELECT p_bataille_id, v_round, c.camp,
         public.militaire_bataille_rapport(p_bataille_id, c.camp, c.adv, v_round, v_actions,
           (SELECT count(*)::integer FROM public.militaire_bataille_combattants(p_bataille_id, c.camp)),
           (SELECT count(*)::integer FROM public.militaire_bataille_combattants(p_bataille_id, c.adv)))
    FROM (VALUES (b.camp_a, b.camp_b), (b.camp_b, b.camp_a)) AS c(camp, adv)
  ON CONFLICT (bataille_id, numero, camp) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'round', v_round, 'terminee', true,
    'issue', CASE WHEN v_a = 'replier' THEN 'repli_' || b.camp_a ELSE 'repli_' || b.camp_b END);
END;
$$;

-- Decrochage : les survivants quittent la zone vers la position canonique capturee a l'ouverture.
-- Un PNJ qui SUIT un chef n'a pas de position propre -- il se deplace avec lui par construction,
-- et on ne lui en ecrit surtout pas une.
CREATE OR REPLACE FUNCTION public.militaire_bataille_decrocher(
  p_bataille_id bigint, p_camp text, p_repli jsonb, p_round integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r record; v_data jsonb; v_sec jsonb; v_sols jsonb;
BEGIN
  IF p_repli IS NULL THEN RETURN; END IF;

  FOR r IN SELECT * FROM public.militaire_bataille_combattants(p_bataille_id, p_camp) LOOP
    IF r.est_pj THEN
      UPDATE public.personnages_donnees
         SET current_city = p_repli->>'ville', current_building = p_repli->>'batiment',
             current_room = p_repli->>'piece'
       WHERE name = r.nom;
    ELSE
      SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = r.compagnie_id FOR UPDATE;
      SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
       WHERE s->>'id' = r.section_id;
      CONTINUE WHEN v_sec IS NULL;
      SELECT coalesce(jsonb_agg(
               CASE WHEN sol->>'matricule' = r.matricule AND (sol->>'leaderCourant') IS NULL
                    THEN sol || jsonb_build_object('ville', p_repli->>'ville',
                                 'buildingId', p_repli->>'batiment', 'roomId', p_repli->>'piece')
                    ELSE sol END ORDER BY pos), '[]'::jsonb)
        INTO v_sols FROM jsonb_array_elements(
          CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END)
          WITH ORDINALITY AS t(sol, pos);
      UPDATE public.compagnies_militaires
         SET data = public.militaire_sections_remplacer(v_data, r.section_id,
                      v_sec || jsonb_build_object('soldats', v_sols))
       WHERE id = r.compagnie_id;
    END IF;
    UPDATE public.batailles_engagements
       SET sorti_round = p_round, etat_final = 'replie' WHERE id = r.eng_id;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_bataille_decision_effective(bigint, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_bataille_decrocher(bigint, text, jsonb, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_bataille_avancer(bigint) FROM PUBLIC, anon, authenticated;