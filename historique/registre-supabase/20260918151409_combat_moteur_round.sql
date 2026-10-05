-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918151409
-- Nom original      : combat_moteur_round
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 15:14:09 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ab9bdcbc0acae98ea8955554dea41a0e
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
-- RESOLUTION D'UN ROUND (19 septembre 2026)
-- =========================================================================================
-- ATOMICITE : la ligne de bataille est verrouillee FOR UPDATE des la premiere instruction. Deux
-- appels concurrents ne peuvent donc pas resoudre le meme round -- le second trouve round_courant
-- deja incremente. L'index unique (bataille, numero, camp) sur batailles_rounds est la seconde
-- ceinture, celle qui tient meme si le verrou etait contourne.
--
-- SIMULTANEITE : pour un round simultane, les deux camps sont PHOTOGRAPHIES avant tout degat, et
-- toutes les actions sont calculees sur cette photo avant d'etre appliquees. Un combattant
-- operationnel au debut du round tire donc, meme si le meme round le neutralise.
--
-- SURPRISE : au round 1, si l'initiative est a A, la passe de A est calculee ET appliquee avant
-- que B ne soit photographie. Un combattant de B tombe avant la riposte ne riposte pas.
CREATE OR REPLACE FUNCTION public.militaire_bataille_round(p_bataille_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  b record; v_round integer; v_sequentiel boolean;
  v_actions jsonb := '[]'::jsonb; v_act jsonb;
  v_snap_a jsonb; v_snap_b jsonb;
  v_pertes jsonb := '{}'::jsonb;
  v_res_a jsonb; v_res_b jsonb;
  v_reste_a integer; v_reste_b integer;
  v_issue text; v_passe text;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  v_round := b.round_courant + 1;
  -- BORNE TECHNIQUE, pas une regle de jeu : elle n'existe que pour qu'un etat impossible ne
  -- boucle pas indefiniment. Si elle est atteinte, l'etat est CONSERVE et journalise, et aucun
  -- vainqueur n'est invente.
  IF v_round > 200 THEN
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(),
           termine_raison = 'borne_technique_atteinte', issue = NULL
     WHERE id = p_bataille_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'borne_technique_atteinte', 'round', v_round);
  END IF;

  v_sequentiel := (v_round = 1 AND b.initiative = 'a');

  -- ---------------------------------------------------------------------------------------
  -- PHOTOGRAPHIE ET CALCUL DES ACTIONS
  -- ---------------------------------------------------------------------------------------
  IF v_sequentiel THEN
    v_actions := public.militaire_bataille_actions(p_bataille_id, b.camp_a, b.camp_b, v_round);
    PERFORM public.militaire_bataille_appliquer(p_bataille_id, v_actions, v_round);
    v_actions := v_actions || public.militaire_bataille_actions(p_bataille_id, b.camp_b, b.camp_a, v_round);
  ELSE
    -- Les deux passes sont calculees AVANT toute application : c'est cela, la simultaneite.
    v_actions := public.militaire_bataille_actions(p_bataille_id, b.camp_a, b.camp_b, v_round)
              || public.militaire_bataille_actions(p_bataille_id, b.camp_b, b.camp_a, v_round);
  END IF;

  -- En sequentiel seule la passe de B reste a appliquer ; en simultane, les deux.
  IF v_sequentiel THEN
    PERFORM public.militaire_bataille_appliquer(p_bataille_id,
      (SELECT coalesce(jsonb_agg(a), '[]'::jsonb) FROM jsonb_array_elements(v_actions) a
        WHERE a->>'camp_attaquant' = b.camp_b), v_round);
  ELSE
    PERFORM public.militaire_bataille_appliquer(p_bataille_id, v_actions, v_round);
  END IF;

  -- ---------------------------------------------------------------------------------------
  -- BILAN, UNE LIGNE PAR CAMP
  -- ---------------------------------------------------------------------------------------
  SELECT count(*) INTO v_reste_a FROM public.militaire_bataille_combattants(p_bataille_id, b.camp_a);
  SELECT count(*) INTO v_reste_b FROM public.militaire_bataille_combattants(p_bataille_id, b.camp_b);

  v_res_a := public.militaire_bataille_rapport(p_bataille_id, b.camp_a, b.camp_b, v_round, v_actions, v_reste_a, v_reste_b);
  v_res_b := public.militaire_bataille_rapport(p_bataille_id, b.camp_b, b.camp_a, v_round, v_actions, v_reste_b, v_reste_a);

  INSERT INTO public.batailles_rounds (bataille_id, numero, camp, rapport)
  VALUES (p_bataille_id, v_round, b.camp_a, v_res_a),
         (p_bataille_id, v_round, b.camp_b, v_res_b)
  ON CONFLICT (bataille_id, numero, camp) DO NOTHING;

  -- Les decisions sont remises a zero : chaque round se decide a nouveau.
  UPDATE public.batailles
     SET round_courant = v_round, decision_a = NULL, decision_b = NULL
   WHERE id = p_bataille_id;

  IF v_reste_a = 0 OR v_reste_b = 0 THEN
    v_issue := CASE WHEN v_reste_a = 0 AND v_reste_b = 0 THEN 'aneantissement_mutuel'
                    WHEN v_reste_b = 0 THEN 'victoire_' || b.camp_a
                    ELSE 'victoire_' || b.camp_b END;
    UPDATE public.batailles
       SET statut = 'terminee', fin_ts = now(), issue = v_issue, termine_raison = 'camp_hors_combat'
     WHERE id = p_bataille_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'round', v_round, 'simultane', NOT v_sequentiel,
    'restants_a', v_reste_a, 'restants_b', v_reste_b, 'issue', v_issue,
    'terminee', (v_reste_a = 0 OR v_reste_b = 0));
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_bataille_round(bigint) FROM PUBLIC, anon, authenticated;