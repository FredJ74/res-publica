-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027110207.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027110207.
-- Eprouvee avant application en transaction annulee, au role authenticated (cout, vote unique, PM refuse au vote, double bulletin refuse). Baseline NON reextrait.
-- ============================================================================
-- LE VOTE DE CONFIANCE PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite » §1.1 (votes_confiance). Tout joueur pouvait creer et modifier
-- n'importe quel vote de confiance : bulletins, date de cloture, et meme son statut et son
-- resultat -- or la passe de nuit, lisant un vote « censure » non suivi de demission, met a zero
-- la popularite du Premier Ministre, des ministres et du President.
--   * vote_confiance_declencher(pa, cost) : Premier Ministre en poste, aucun vote deja en cours,
--     paiement, vote ouvert 48 h, deputes joueurs prevenus par un mail de l'Assemblee (memes
--     boutons Pour / Contre qu'avant).
--   * vote_confiance_voter(vote, choix) : depute en poste du meme pays, vote ouvert, un seul
--     bulletin par depute.
--   * La resolution (vote_confiance_resoudre) et la consequence differee restent a la passe de nuit.
-- Les joueurs n'ecrivent plus votes_confiance. Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.vote_confiance_declencher(p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_poste text; v_paie jsonb; v_id text; v_cloture timestamptz := now() + interval '48 hours';
  v_dep record; v_n integer := 0;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, poste ->> 'id' INTO v_pays, v_poste FROM public.personnages_donnees WHERE name = v_moi;
  IF v_poste IS DISTINCT FROM 'pm' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_pm'); END IF;
  PERFORM pg_advisory_xact_lock(hashtext('vote_confiance_' || v_pays));
  IF EXISTS (SELECT 1 FROM public.votes_confiance WHERE country = v_pays AND statut = 'en_cours') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vote_deja_en_cours'); END IF;
  v_paie := public.payer_ordre(v_moi, 'declencher_vote_confiance', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_id := 'voteconf-' || (extract(epoch FROM now()) * 1000)::bigint;
  INSERT INTO public.votes_confiance (id, country, pm_nom, cloture_ts, statut, resultat, bulletins,
                                      demission_limite_ts, demission_ts, consequence_appliquee, created_at)
  VALUES (v_id, v_pays, v_moi, v_cloture, 'en_cours', NULL, '{}'::jsonb, NULL, NULL, false, now());
  FOR v_dep IN SELECT name FROM public.personnages_donnees WHERE country = v_pays AND (poste_depute ->> 'id') = 'depute' LOOP
    PERFORM public.mail_systeme_poser_interne('Assemblée Nationale', v_dep.name, 'Vote de confiance — Assemblée Nationale',
      'Le Premier Ministre ' || v_moi || ' engage la responsabilité de son gouvernement. Votez avant 48h.<br><br>'
      || '[[act:confiance_pour|' || v_id || ']][[act:confiance_contre|' || v_id || ']]',
      to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
    v_n := v_n + 1;
  END LOOP;
  PERFORM public.annonce_publique_interne(v_pays, '🏛 Le Premier Ministre ' || v_moi
    || ' engage la responsabilité de son gouvernement devant l''Assemblée Nationale.');
  RETURN jsonb_build_object('ok', true, 'vote_id', v_id, 'cloture_ts', v_cloture, 'deputes_prevenus', v_n)
    || jsonb_build_object('paie', v_paie);
END; $function$;

CREATE OR REPLACE FUNCTION public.vote_confiance_voter(p_vote_id text, p_choix text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_depute text; v_vote record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_choix NOT IN ('pour', 'contre') THEN RETURN jsonb_build_object('ok', false, 'raison', 'choix_invalide'); END IF;
  SELECT country, poste_depute ->> 'id' INTO v_pays, v_depute FROM public.personnages_donnees WHERE name = v_moi;
  IF v_depute IS DISTINCT FROM 'depute' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_deputes'); END IF;
  SELECT * INTO v_vote FROM public.votes_confiance WHERE id = p_vote_id FOR UPDATE;
  IF NOT FOUND OR v_vote.country IS DISTINCT FROM v_pays OR v_vote.statut <> 'en_cours' OR now() >= v_vote.cloture_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vote_ferme'); END IF;
  IF coalesce(v_vote.bulletins, '{}'::jsonb) ? v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_vote'); END IF;
  UPDATE public.votes_confiance SET bulletins = coalesce(bulletins, '{}'::jsonb) || jsonb_build_object(v_moi, p_choix)
   WHERE id = p_vote_id;
  RETURN jsonb_build_object('ok', true, 'choix', p_choix);
END; $function$;

REVOKE ALL ON FUNCTION public.vote_confiance_declencher(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vote_confiance_declencher(integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.vote_confiance_voter(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vote_confiance_voter(text, text) TO authenticated;

DROP POLICY IF EXISTS votes_confiance_ecriture_acteur ON public.votes_confiance;
DROP POLICY IF EXISTS votes_confiance_maj_acteur ON public.votes_confiance;
REVOKE INSERT, UPDATE, DELETE ON public.votes_confiance FROM anon, authenticated;
