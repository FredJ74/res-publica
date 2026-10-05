-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918151747
-- Nom original      : combat_rpc_client
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 15:17:47 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d6e98771ddb8f446a2d8eda293fe271f
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
-- SURFACE CLIENTE (19 septembre 2026)
-- =========================================================================================
-- Ce sont les SEULES fonctions de combat accordees a `authenticated`. Toutes les autres --
-- calcul des actions, application, rapports, gilet, suppression de soldat -- sont revoquees de
-- tout le monde : un client ne peut donc ni tirer le de, ni declarer une cible, ni appliquer un
-- degat, ni resoudre un round hors sequence.
--
-- Le camp du lecteur est DEDUIT de son engagement dans la bataille, jamais accepte en parametre,
-- et il ne recoit que la ligne de rapport de SON camp.
CREATE OR REPLACE FUNCTION public.militaire_bataille_mon_camp(p_bataille_id bigint, p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT e.camp FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id AND e.personnage = p_nom LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.militaire_bataille_etat(p_bataille_id bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_moi text; v_id bigint; b record; v_camp text; v_adv text; v_reste integer; v_rounds jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF p_bataille_id IS NULL THEN
    -- Bataille en cours a laquelle je participe, s'il y en a une.
    SELECT e.bataille_id INTO v_id FROM public.batailles_engagements e
      JOIN public.batailles bb ON bb.id = e.bataille_id
     WHERE e.personnage = v_moi AND bb.statut = 'en_cours'
     ORDER BY bb.debut_ts DESC LIMIT 1;
    IF v_id IS NULL THEN RETURN jsonb_build_object('ok', true, 'bataille', NULL); END IF;
  ELSE
    v_id := p_bataille_id;
  END IF;

  SELECT * INTO b FROM public.batailles WHERE id = v_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;

  v_camp := public.militaire_bataille_mon_camp(v_id, v_moi);
  IF v_camp IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_engage'); END IF;
  v_adv := CASE WHEN v_camp = b.camp_a THEN b.camp_b ELSE b.camp_a END;

  SELECT count(*) INTO v_reste FROM public.militaire_bataille_combattants(v_id, v_camp);
  SELECT coalesce(jsonb_agg(r.rapport ORDER BY r.numero), '[]'::jsonb) INTO v_rounds
    FROM public.batailles_rounds r WHERE r.bataille_id = v_id AND r.camp = v_camp;

  RETURN jsonb_build_object('ok', true, 'bataille', jsonb_build_object(
    'id', b.id, 'statut', b.statut, 'round_courant', b.round_courant,
    'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
    'mon_camp', v_camp, 'camp_adverse', v_adv,
    'mon_effectif_initial', CASE WHEN v_camp = b.camp_a THEN b.effectif_initial_a ELSE b.effectif_initial_b END,
    'mon_effectif_actuel', v_reste,
    'je_suis_leader', (v_moi = CASE WHEN v_camp = b.camp_a THEN b.leader_a ELSE b.leader_b END),
    'ma_doctrine', CASE WHEN v_camp = b.camp_a THEN b.doctrine_a ELSE b.doctrine_b END,
    'ma_decision', CASE WHEN v_camp = b.camp_a THEN b.decision_a ELSE b.decision_b END,
    'issue', b.issue, 'rounds', v_rounds));
END;
$$;

CREATE OR REPLACE FUNCTION public.militaire_bataille_decider(p_bataille_id bigint, p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_moi text; b record; v_camp text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_decision NOT IN ('continuer','replier') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide');
  END IF;

  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  v_camp := public.militaire_bataille_mon_camp(p_bataille_id, v_moi);
  IF v_camp IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_engage'); END IF;
  -- Seul le leader du camp decide. Les autres suivent -- ou la doctrine s'applique.
  IF v_moi IS DISTINCT FROM (CASE WHEN v_camp = b.camp_a THEN b.leader_a ELSE b.leader_b END) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_leader_de_ce_camp');
  END IF;

  IF v_camp = b.camp_a THEN UPDATE public.batailles SET decision_a = p_decision WHERE id = p_bataille_id;
                       ELSE UPDATE public.batailles SET decision_b = p_decision WHERE id = p_bataille_id; END IF;

  -- La decision humaine est ECRITE avant que le serveur ne regarde : c'est ainsi qu'elle prime
  -- sur la doctrine, sans avoir besoin de savoir qui est « connecte ».
  RETURN public.militaire_bataille_avancer(p_bataille_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.militaire_bataille_doctrine(p_bataille_id bigint, p_doctrine text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_moi text; b record; v_camp text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_doctrine NOT IN ('tenir','repli_50') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'doctrine_invalide');
  END IF;
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  v_camp := public.militaire_bataille_mon_camp(p_bataille_id, v_moi);
  IF v_camp IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_engage'); END IF;
  IF v_moi IS DISTINCT FROM (CASE WHEN v_camp = b.camp_a THEN b.leader_a ELSE b.leader_b END) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_leader_de_ce_camp');
  END IF;
  IF v_camp = b.camp_a THEN UPDATE public.batailles SET doctrine_a = p_doctrine WHERE id = p_bataille_id;
                       ELSE UPDATE public.batailles SET doctrine_b = p_doctrine WHERE id = p_bataille_id; END IF;
  RETURN jsonb_build_object('ok', true, 'doctrine', p_doctrine);
END;
$$;

-- Historique : les batailles auxquelles j'ai participe, avec MES rapports de round. Un joueur
-- revenant apres une bataille resolue en son absence la relit ici.
CREATE OR REPLACE FUNCTION public.militaire_mes_batailles(p_limite integer DEFAULT 10)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_moi text; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(jsonb_agg(x ORDER BY x->>'debut' DESC), '[]'::jsonb) INTO v_res FROM (
    SELECT jsonb_build_object(
      'id', b.id, 'debut', b.debut_ts, 'fin', b.fin_ts, 'statut', b.statut, 'issue', b.issue,
      'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
      'mon_camp', e.camp, 'mon_etat', e.etat_final, 'sorti_round', e.sorti_round,
      'rounds', (SELECT coalesce(jsonb_agg(r.rapport ORDER BY r.numero), '[]'::jsonb)
                   FROM public.batailles_rounds r
                  WHERE r.bataille_id = b.id AND r.camp = e.camp)) AS x
      FROM public.batailles_engagements e
      JOIN public.batailles b ON b.id = e.bataille_id
     WHERE e.personnage = v_moi
     ORDER BY b.debut_ts DESC LIMIT greatest(1, least(50, coalesce(p_limite, 10)))) t;
  RETURN jsonb_build_object('ok', true, 'batailles', v_res);
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_bataille_mon_camp(bigint, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_bataille_etat(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_bataille_decider(bigint, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_bataille_doctrine(bigint, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_mes_batailles(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_etat(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_decider(bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_doctrine(bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_mes_batailles(integer) TO authenticated;