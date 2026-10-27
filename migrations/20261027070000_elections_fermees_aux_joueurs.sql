-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027103804.
-- Eprouvee avant application en transaction annulee, au role authenticated (scrutin existant jamais ecrase, ville refusee, calendrier conforme a calendrierPremierTour). Baseline NON reextrait.
-- ============================================================================
-- LES SCRUTINS NE SONT PLUS ECRITS PAR LES JOUEURS (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite » §1.1 (cycles_electoraux). Tout joueur pouvait reecrire le blob d'un
-- scrutin : candidats, bulletins, et surtout `eluId` / `elus`, que poste_est_atteste lit pour
-- reconnaitre un President, un maire, un chef syndical ou un depute. Un joueur pouvait donc
-- s'inscrire elu puis porter le poste : le serveur l'aurait reconnu comme President.
-- Trois ecritures legitimes passaient par la : elles passent desormais par le serveur.
--   1. Engendrer le premier scrutin d'un poste qui n'en a pas : cycle_electoral_initialiser,
--      qui ne fait RIEN si le scrutin existe (l'ancien chemin pouvait ecraser un scrutin existant,
--      titulaire compris, quand le cache du navigateur etait vide). Calendrier identique a
--      calendrierPremierTour (api/cron-minuit.js).
--   2. Dissolution : la relance des scrutins legislatifs est faite par assemblee_dissoudre,
--      dans la meme transaction que la revocation des deputes.
--   3. Contestation des resultats : election_contester. Constat : elle ne pouvait plus rien
--      reveler, parce que la proclamation rouvre aussitot le scrutin suivant (nouvelle cle,
--      bulletins remis a zero) et que l'ecran cherchait les fraudes dans ce scrutin neuf. La
--      passe de nuit garde desormais une photographie du scrutin proclame (`dernierScrutin`),
--      et le serveur y fait la contestation, le recomptage et le changement d'elu eventuel.
--      Regles d'avant : 24 h apres la proclamation, 2 PA et 200 FR, reussite 60 % + 5 par point
--      d'INT au-dessus de 13 (borne 5-95), une fraude non revelee tiree au hasard, detectee selon
--      sa detectabilite, sanction par fraude_electorale_sanctionner (qui n'est plus appelable
--      seule : un joueur pouvait reveler une fraude et toucher la prime sans contester).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.cycle_electoral_frais_interne(p_poste text, p_city text, p_now timestamptz)
 RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jour date := (p_now AT TIME ZONE 'Europe/Paris')::date; v_lundi date; v_camp timestamptz;
BEGIN
  v_lundi := date_trunc('week', v_jour)::date + 7;
  v_camp := (v_lundi + time '00:01') AT TIME ZONE 'Europe/Paris';
  IF v_camp - p_now < interval '6 days' THEN v_lundi := v_lundi + 7; END IF;
  RETURN jsonb_build_object(
    'posteId', p_poste,
    'city', CASE WHEN p_poste IN ('maire', 'depute') THEN p_city END,
    'phase', 'candidatures',
    'dateDebutCandidatures', (extract(epoch FROM p_now) * 1000)::bigint,
    'dateDebutCampagne', (extract(epoch FROM (v_lundi + time '00:01') AT TIME ZONE 'Europe/Paris') * 1000)::bigint,
    'dateVote', (extract(epoch FROM (v_lundi + 6 + time '00:01') AT TIME ZONE 'Europe/Paris') * 1000)::bigint,
    'dateResultats', (extract(epoch FROM (v_lundi + 7 + time '00:00') AT TIME ZONE 'Europe/Paris') * 1000)::bigint,
    'candidats', '[]'::jsonb, 'votes', '{}'::jsonb, 'votesPNJ', '{}'::jsonb,
    'tour', 1, 'eluId', NULL, 'resultatsTraites', false);
END; $function$;

CREATE OR REPLACE FUNCTION public.cycle_electoral_initialiser(p_poste text, p_city text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_city text; v_id text; v_data text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_poste NOT IN ('president', 'chef_syndicat', 'maire', 'depute') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_electif'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_city := CASE WHEN p_poste IN ('maire', 'depute') THEN nullif(p_city, '') END;
  IF p_poste IN ('maire', 'depute') AND (v_city IS NULL OR v_city NOT IN ('capitale', 'ville_a', 'ville_b')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ville_invalide'); END IF;
  v_id := v_pays || '_' || p_poste || coalesce('_' || v_city, '');
  INSERT INTO public.cycles_electoraux (id, country, poste_id, city, data, updated_at)
    VALUES (v_id, v_pays, p_poste, v_city, public.cycle_electoral_frais_interne(p_poste, v_city, now())::text, now())
    ON CONFLICT (id) DO NOTHING;
  SELECT data INTO v_data FROM public.cycles_electoraux WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'cycle', v_data::jsonb);
END; $function$;

-- Dissolution : troisieme vague (relance des scrutins legislatifs) par le serveur.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.assemblee_dissoudre'::regproc);
  IF position('cycle_electoral_frais_interne' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'  RETURN jsonb_build_object(''ok'', true, ''pays'', v_pays, ''revoques'', v_revoques,',
      E'  -- TROISIEME VAGUE (27/10/2026) : chaque circonscription repart sur un scrutin neuf.\n'
      || E'  UPDATE public.cycles_electoraux c\n'
      || E'     SET data = public.cycle_electoral_frais_interne(''depute'', c.city, now())::text, updated_at = now()\n'
      || E'   WHERE c.country = v_pays AND c.poste_id = ''depute'';\n'
      || E'  GET DIAGNOSTICS v_n = ROW_COUNT;\n'
      || E'  RETURN jsonb_build_object(''ok'', true, ''pays'', v_pays, ''revoques'', v_revoques, ''circonscriptions_relancees'', v_n,');
    IF position('cycle_electoral_frais_interne' IN v_def) = 0 THEN
      RAISE EXCEPTION 'assemblee_dissoudre : motif introuvable';
    END IF;
    EXECUTE v_def;
  END IF;
END $do$;
