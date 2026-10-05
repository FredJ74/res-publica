-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920225508
-- Nom original      : militaire_combat_boucle_v2
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 22:55:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : eba3e802103f26403890dfabe40091ac
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
-- BOUCLE DE COMBAT V2 (21 septembre 2026)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. APPLICATION — rend desormais les actions ENRICHIES
-- ---------------------------------------------------------------------
-- Les degats etant proportionnels, la perte reelle n'est connue qu'au
-- moment de l'application. On la renvoie pour que le rapport de round
-- puisse la chiffrer sans la recalculer.
DROP FUNCTION IF EXISTS public.militaire_bataille_appliquer(bigint, jsonb, integer);

CREATE FUNCTION public.militaire_bataille_appliquer(
  p_bataille_id bigint, p_actions jsonb, p_round integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  act jsonb; v_pa integer; v_new integer; v_gilet jsonb; v_degre text; v_abaisse text;
  v_out jsonb := '[]'::jsonb; v_protege boolean;
BEGIN
  FOR act IN SELECT value FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb))
  LOOP
    v_degre := act->>'degre'; v_protege := false;

    IF v_degre = 'echec_critique' THEN
      UPDATE public.batailles_engagements SET saute_round = p_round + 1
       WHERE id = (act->>'att_eng')::bigint AND sorti_round IS NULL;
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0, 'saute_suivant', true));
      CONTINUE;
    END IF;

    IF public.militaire_degats_pct(v_degre) = 0
       OR NOT EXISTS (SELECT 1 FROM public.batailles_engagements
                       WHERE id = (act->>'cib_eng')::bigint AND sorti_round IS NULL) THEN
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0));
      CONTINUE;
    END IF;

    SELECT pa INTO v_pa FROM public.militaire_bataille_combattants(
      p_bataille_id, act->>'cib_camp') WHERE eng_id = (act->>'cib_eng')::bigint;
    IF v_pa IS NULL THEN
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0));
      CONTINUE;
    END IF;

    v_new := public.militaire_pa_restants(v_pa, v_degre);

    -- GILET : feu seulement, et seulement si le tir devait neutraliser.
    IF v_new = 0 AND act->>'mode' = 'feu' THEN
      v_gilet := public.militaire_gilet_absorber(
        (act->>'cib_pj')::boolean, act->>'cib_nom',
        act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      IF coalesce((v_gilet->>'protege')::boolean, false) THEN
        v_protege := true;
        v_abaisse := public.militaire_degre_par_rang(public.militaire_degre_rang(v_degre) - 1);
        v_new := greatest(1, public.militaire_pa_restants(v_pa, v_abaisse));
      END IF;
    END IF;

    IF (act->>'cib_pj')::boolean THEN
      UPDATE public.personnages_donnees SET pa = v_new WHERE name = act->>'cib_nom';
    ELSE
      PERFORM public.militaire_soldat_pa_fixer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat', v_new);
    END IF;

    v_out := v_out || jsonb_build_array(act || jsonb_build_object(
      'pa_avant', v_pa, 'pa_apres', v_new, 'perte', v_pa - v_new,
      'gilet', v_protege, 'degre_applique', coalesce(v_abaisse, v_degre)));

    CONTINUE WHEN v_new > 0;

    IF (act->>'cib_pj')::boolean THEN
      -- PJ : NEUTRALISE, jamais mort. Infirmerie de SA propre caserne.
      UPDATE public.personnages_donnees
         SET current_city = 'caserne', current_building = 'caserne-militaire',
             current_room = 'infirmerie'
       WHERE name = act->>'cib_nom';
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'neutralise'
       WHERE id = (act->>'cib_eng')::bigint;
    ELSE
      -- PNJ : MORT. Suppression reelle : le contingent diminue definitivement.
      PERFORM public.militaire_soldat_supprimer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'mort'
       WHERE id = (act->>'cib_eng')::bigint;
    END IF;
  END LOOP;
  RETURN v_out;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_appliquer(bigint, jsonb, integer) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 2. RAPPORT — la perte reelle remonte de l'application
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_bataille_rapport(
  p_bataille_id bigint, p_camp text, p_camp_adverse text, p_round integer,
  p_actions jsonb, p_reste_moi integer, p_reste_adverse integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  b record; v_pa_perdus integer; v_touches integer; v_morts integer; v_neutralises integer;
  v_tombes_adverse integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id;

  SELECT coalesce(sum(coalesce((a->>'perte')::integer, 0)), 0),
         count(*) FILTER (WHERE coalesce((a->>'perte')::integer, 0) > 0)
    INTO v_pa_perdus, v_touches
    FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb)) a
   WHERE a->>'cib_camp' = p_camp;

  SELECT count(*) FILTER (WHERE etat_final = 'mort'),
         count(*) FILTER (WHERE etat_final = 'neutralise')
    INTO v_morts, v_neutralises
    FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND camp = p_camp AND sorti_round = p_round;

  SELECT count(*) INTO v_tombes_adverse FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND camp <> p_camp AND sorti_round = p_round;

  RETURN jsonb_build_object(
    'round', p_round,
    'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
    'mon_camp', p_camp,
    'mes_combattants_restants', p_reste_moi,
    'mes_pa_perdus', v_pa_perdus,
    'mes_combattants_touches', v_touches,
    'mes_morts_pnj', v_morts,
    'mes_pj_neutralises', v_neutralises,
    'adversaires_tombes', v_tombes_adverse,
    'adversaire_estime', CASE WHEN p_reste_adverse > 0
      THEN public.militaire_degrader('proche', p_reste_adverse, p_camp_adverse, b.ville, b.batiment)
      ELSE jsonb_build_object('libelle', 'plus aucun adversaire debout') END,
    'termine', (p_reste_moi = 0 OR p_reste_adverse = 0));
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_rapport(bigint, text, text, integer, jsonb, integer, integer) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 3. LE ROUND
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_bataille_round(p_bataille_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  b record; v_round integer; v_camps text[]; v_camp text; v_surprise text;
  v_actions jsonb := '[]'::jsonb; v_autres jsonb := '[]'::jsonb;
  v_reste integer; v_debout integer; v_issue text; v_attente integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  v_round := b.round_courant + 1;
  IF v_round > 200 THEN
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(),
           termine_raison = 'borne_technique_atteinte', issue = NULL WHERE id = p_bataille_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'borne_technique_atteinte', 'round', v_round);
  END IF;

  SELECT coalesce(array_agg(DISTINCT camp), '{}') INTO v_camps
    FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND sorti_round IS NULL;

  -- SURPRISE : premier round, et seulement si l'engageant avait l'initiative.
  v_surprise := CASE WHEN v_round = 1 AND b.initiative = 'a' THEN b.camp_a ELSE NULL END;

  IF v_surprise IS NOT NULL THEN
    -- La passe du camp surprenant est calculee ET appliquee avant que les
    -- autres ne soient photographies : c'est cela, l'initiative.
    v_actions := public.militaire_bataille_actions(p_bataille_id, v_surprise, v_round, true);
    v_actions := public.militaire_bataille_appliquer(p_bataille_id, v_actions, v_round);
    FOREACH v_camp IN ARRAY v_camps LOOP
      CONTINUE WHEN v_camp = v_surprise;
      v_autres := v_autres || public.militaire_bataille_actions(p_bataille_id, v_camp, v_round, false);
    END LOOP;
    v_autres  := public.militaire_bataille_appliquer(p_bataille_id, v_autres, v_round);
    v_actions := v_actions || v_autres;
  ELSE
    -- Hors surprise, toutes les passes sont calculees AVANT toute
    -- application : c'est cela, la simultaneite.
    FOREACH v_camp IN ARRAY v_camps LOOP
      v_actions := v_actions || public.militaire_bataille_actions(p_bataille_id, v_camp, v_round, false);
    END LOOP;
    v_actions := public.militaire_bataille_appliquer(p_bataille_id, v_actions, v_round);
  END IF;

  -- Un rapport par camp encore present.
  FOREACH v_camp IN ARRAY v_camps LOOP
    SELECT count(*) INTO v_reste FROM public.batailles_engagements
     WHERE bataille_id = p_bataille_id AND camp = v_camp AND sorti_round IS NULL;
    INSERT INTO public.batailles_rounds (bataille_id, numero, camp, rapport)
    VALUES (p_bataille_id, v_round, v_camp,
            public.militaire_bataille_rapport(p_bataille_id, v_camp,
              coalesce((public.militaire_camps_hostiles(p_bataille_id, v_camp))[1], v_camp),
              v_round, v_actions, v_reste,
              (SELECT count(*)::integer FROM public.batailles_engagements
                WHERE bataille_id = p_bataille_id AND camp <> v_camp AND sorti_round IS NULL)))
    ON CONFLICT (bataille_id, numero, camp) DO NOTHING;
  END LOOP;

  UPDATE public.batailles SET round_courant = v_round WHERE id = p_bataille_id;

  -- Seuil de 50 %, fenetre de 90 s, replis automatiques.
  v_attente := public.militaire_bataille_arbitrer_groupes(p_bataille_id, v_round);

  -- Fin : il ne reste qu'un camp debout, ou aucun.
  SELECT count(DISTINCT camp) INTO v_debout FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND sorti_round IS NULL;
  IF v_debout <= 1 THEN
    SELECT CASE WHEN v_debout = 0 THEN 'aneantissement_mutuel'
                ELSE 'victoire_' || (SELECT DISTINCT camp FROM public.batailles_engagements
                                      WHERE bataille_id = p_bataille_id AND sorti_round IS NULL) END
      INTO v_issue;
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(), issue = v_issue,
           termine_raison = 'camp_hors_combat' WHERE id = p_bataille_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'round', v_round, 'surprise', v_surprise,
    'camps', v_camps, 'camps_debout', v_debout, 'groupes_en_attente', v_attente,
    'issue', v_issue, 'terminee', (v_debout <= 1));
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_round(bigint) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 4. AVANCER — jamais pendant qu'un chef reflechit
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_bataille_avancer(p_bataille_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE b record; v_attente integer; v_debout integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  -- Les fenetres echues se resolvent ici : un chef qui n'a pas repondu dans
  -- les 90 secondes voit son groupe decrocher.
  v_attente := public.militaire_bataille_arbitrer_groupes(p_bataille_id, b.round_courant);

  SELECT count(DISTINCT camp) INTO v_debout FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND sorti_round IS NULL;
  IF v_debout <= 1 THEN
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(),
           termine_raison = 'camp_hors_combat',
           issue = CASE WHEN v_debout = 0 THEN 'aneantissement_mutuel'
                        ELSE 'victoire_' || (SELECT DISTINCT camp FROM public.batailles_engagements
                                              WHERE bataille_id = p_bataille_id AND sorti_round IS NULL) END
     WHERE id = p_bataille_id;
    RETURN jsonb_build_object('ok', true, 'terminee', true, 'camps_debout', v_debout);
  END IF;

  IF v_attente > 0 THEN
    -- AUCUN ROUND NE PART tant qu'un chef a la main : la fenetre de decision
    -- ne se paie pas en morts.
    RETURN jsonb_build_object('ok', true, 'en_attente', v_attente,
      'raison', 'decision_en_attente', 'round', b.round_courant);
  END IF;

  RETURN public.militaire_bataille_round(p_bataille_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_avancer(bigint) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 5. DECIDER — le chef tranche pour SON groupe, et pour lui seul
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_bataille_decider(p_bataille_id bigint, p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE v_moi text; b record; g record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_decision NOT IN ('tenir','replier') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide');
  END IF;

  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  SELECT * INTO g FROM public.batailles_groupes
   WHERE bataille_id = p_bataille_id AND leader = v_moi AND sorti_round IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef_de_groupe');
  END IF;

  UPDATE public.batailles_groupes
     SET decision = p_decision, attente_depuis = NULL
   WHERE bataille_id = p_bataille_id AND groupe_id = g.groupe_id;

  IF p_decision = 'replier' THEN
    PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, b.round_courant);
  END IF;

  RETURN public.militaire_bataille_avancer(p_bataille_id)
         || jsonb_build_object('mon_groupe', g.groupe_id, 'ma_decision', p_decision);
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_decider(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_decider(bigint, text) TO authenticated, service_role;


-- La doctrine de camp n'existe plus : le seuil de 50 % s'applique groupe par
-- groupe, avec fenetre de 90 s pour un chef PJ et repli automatique pour un
-- groupe mene par un PNJ. La fonction est conservee le temps que le client
-- retire son bouton, et refuse proprement.
CREATE OR REPLACE FUNCTION public.militaire_bataille_doctrine(p_bataille_id bigint, p_doctrine text)
RETURNS jsonb LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT jsonb_build_object('ok', false, 'raison', 'doctrine_obsolete',
    'detail', 'Le repli se decide desormais groupe par groupe, a 50 % de pertes.');
$function$;