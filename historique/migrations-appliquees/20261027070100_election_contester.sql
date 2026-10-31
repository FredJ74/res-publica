-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027104731.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027104731.
-- Eprouvee avant application en transaction annulee, au role authenticated (fraude revelee, recomptage, elu corrige). Baseline NON reextrait.
-- ============================================================================
-- CONTESTATION DES RESULTATS PAR LE SERVEUR, FERMETURE DE cycles_electoraux (27 octobre 2026)
-- ============================================================================
-- Voir l'en-tete de 20261027070000_elections_fermees_aux_joueurs.sql.
-- Le recomptage reprend calculerScoresBaseCycle / resoudreScrutinSimple / resoudreScrutinDepute
-- (api/cron-minuit.js) sur la photographie `dernierScrutin` : bulletins des joueurs et des PNJ,
-- effet des tracts du tour, fraudes encore non revelees.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.election_recompter_interne(p_cycle_id text, p_pays text, p_poste text, p_city text, p_scrutin jsonb)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_scores jsonb := '{}'::jsonb; v_blancs integer := 0; v_total integer; v_nb integer; v_nom text; r record;
  v_premier text; v_premier_voix integer;
BEGIN
  SELECT count(*) INTO v_nb FROM jsonb_array_elements(coalesce(p_scrutin -> 'candidats', '[]'::jsonb));
  IF v_nb = 0 THEN RETURN NULL; END IF;
  SELECT jsonb_object_agg(c ->> 'nom', 0) INTO v_scores FROM jsonb_array_elements(p_scrutin -> 'candidats') c;
  FOR v_nom IN SELECT value FROM jsonb_each_text(coalesce(p_scrutin -> 'votes', '{}'::jsonb))
               UNION ALL SELECT value FROM jsonb_each_text(coalesce(p_scrutin -> 'votesPNJ', '{}'::jsonb)) LOOP
    IF v_nom = 'BLANC' THEN v_blancs := v_blancs + 1;
    ELSIF v_scores ? v_nom THEN v_scores := jsonb_set(v_scores, ARRAY[v_nom], to_jsonb((v_scores ->> v_nom)::int + 1)); END IF;
  END LOOP;
  FOR r IN SELECT candidat, sum(effet)::int AS e FROM public.elections_tracts_pnj
            WHERE cycle_id = p_cycle_id AND tour = coalesce((p_scrutin ->> 'dateVote')::bigint, 0) GROUP BY candidat LOOP
    IF v_scores ? r.candidat THEN v_scores := jsonb_set(v_scores, ARRAY[r.candidat], to_jsonb(greatest(0, (v_scores ->> r.candidat)::int + r.e))); END IF;
  END LOOP;
  FOR r IN SELECT candidat, delta_voix FROM public.fraudes_electorales
            WHERE country = p_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM p_city
              AND cycle_debut = (p_scrutin ->> 'debut')::bigint AND etat = 'non_revelee' LOOP
    IF v_scores ? r.candidat THEN v_scores := jsonb_set(v_scores, ARRAY[r.candidat], to_jsonb(greatest(0, (v_scores ->> r.candidat)::int + r.delta_voix))); END IF;
  END LOOP;
  SELECT coalesce(sum(value::int), 0) + v_blancs INTO v_total FROM jsonb_each_text(v_scores);
  IF v_total = 0 OR v_blancs > v_total / 2.0 THEN RETURN jsonb_build_object('elu', NULL, 'elus', '[]'::jsonb); END IF;

  IF p_poste = 'depute' THEN
    RETURN jsonb_build_object('elus', (SELECT jsonb_agg(nom) FROM (
      SELECT s.key AS nom FROM jsonb_each_text(v_scores) s
        LEFT JOIN LATERAL (SELECT nullif(c ->> 'dateInscription', '')::numeric AS d
                             FROM jsonb_array_elements(p_scrutin -> 'candidats') c WHERE c ->> 'nom' = s.key LIMIT 1) i ON true
       ORDER BY s.value::int DESC, coalesce(i.d, 'Infinity'::numeric), s.key LIMIT 3) t));
  END IF;
  SELECT key, value::int INTO v_premier, v_premier_voix FROM jsonb_each_text(v_scores) ORDER BY value::int DESC LIMIT 1;
  IF v_nb = 1 THEN
    RETURN jsonb_build_object('elu', CASE WHEN v_premier_voix >= v_blancs THEN v_premier END);
  END IF;
  RETURN jsonb_build_object('elu', CASE WHEN v_premier_voix > v_total / 2.0 THEN v_premier END);
END; $function$;

CREATE OR REPLACE FUNCTION public.election_contester(p_poste text, p_city text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_int numeric; v_city text; v_row record; v_cycle jsonb; v_scrutin jsonb;
  v_paie jsonb; v_taux integer; v_roll integer; v_f record; v_sanction jsonb; v_recompte jsonb;
  v_ancien jsonb; v_nouveau jsonb; v_change boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, coalesce(CASE WHEN jsonb_typeof(stats -> 'INT') = 'number' THEN (stats ->> 'INT')::numeric END, 8)
    INTO v_pays, v_int FROM public.personnages_donnees WHERE name = v_moi;
  v_city := CASE WHEN p_poste IN ('maire', 'depute') THEN nullif(p_city, '') END;
  SELECT * INTO v_row FROM public.cycles_electoraux
   WHERE country = v_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM v_city FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'); END IF;
  v_cycle := v_row.data::jsonb;
  IF (v_cycle ->> 'dernierResultatTs') IS NULL
     OR (extract(epoch FROM now()) * 1000) - (v_cycle ->> 'dernierResultatTs')::numeric NOT BETWEEN 0 AND 86400000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_delai'); END IF;
  v_scrutin := v_cycle -> 'dernierScrutin';
  IF jsonb_typeof(v_scrutin) <> 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_non_consultable'); END IF;

  v_paie := public.payer_ordre(v_moi, 'contester_resultats', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_taux := greatest(5, least(95, round(60 + 5 * (v_int - 13))::integer));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll > v_taux THEN
    RETURN jsonb_build_object('ok', true, 'issue', 'rejetee', 'jet', v_roll, 'taux', v_taux) || jsonb_build_object('paie', v_paie);
  END IF;

  SELECT * INTO v_f FROM public.fraudes_electorales
   WHERE country = v_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM v_city
     AND cycle_debut = (v_scrutin ->> 'debut')::bigint AND etat = 'non_revelee'
   ORDER BY random() LIMIT 1;
  IF NOT FOUND OR random() * 100 >= coalesce(v_f.detectabilite_pct, 0) THEN
    RETURN jsonb_build_object('ok', true, 'issue', 'aucune_fraude') || jsonb_build_object('paie', v_paie);
  END IF;

  v_sanction := public.fraude_electorale_sanctionner(v_f.id, v_city);
  IF coalesce((v_sanction ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'issue', 'sans_suite', 'raison', v_sanction ->> 'raison') || jsonb_build_object('paie', v_paie);
  END IF;

  -- Recomptage sans la fraude revelee ; l'elu ne change que si le recomptage designe quelqu'un.
  v_recompte := public.election_recompter_interne(v_row.id, v_pays, p_poste, v_city, v_scrutin);
  IF p_poste = 'depute' THEN
    v_ancien := coalesce(v_cycle -> 'elus', '[]'::jsonb);
    v_nouveau := v_recompte -> 'elus';
    IF jsonb_typeof(v_nouveau) = 'array' AND jsonb_array_length(v_nouveau) = 3
       AND (SELECT array_agg(x ORDER BY x) FROM jsonb_array_elements_text(v_nouveau) x)
           IS DISTINCT FROM (SELECT array_agg(x ORDER BY x) FROM jsonb_array_elements_text(v_ancien) x) THEN
      v_cycle := jsonb_set(v_cycle, '{elus}', v_nouveau); v_change := true;
    END IF;
  ELSE
    v_ancien := v_cycle -> 'eluId';
    v_nouveau := v_recompte -> 'elu';
    IF jsonb_typeof(v_nouveau) = 'string' AND v_nouveau IS DISTINCT FROM v_ancien THEN
      v_cycle := jsonb_set(v_cycle, '{eluId}', v_nouveau); v_change := true;
    END IF;
  END IF;
  IF v_change THEN
    UPDATE public.cycles_electoraux SET data = v_cycle::text, updated_at = now() WHERE id = v_row.id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'issue', 'fraude_revelee', 'fraudeur', v_sanction ->> 'fraudeur',
    'type', v_sanction ->> 'type', 'recompense', v_sanction -> 'recompense', 'arg', v_sanction -> 'arg_contestataire',
    'issue_changee', v_change, 'ancienne_issue', v_ancien, 'nouvelle_issue', CASE WHEN v_change THEN v_nouveau END)
    || jsonb_build_object('paie', v_paie);
END; $function$;

REVOKE ALL ON FUNCTION public.cycle_electoral_frais_interne(text, text, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.election_recompter_interne(text, text, text, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cycle_electoral_initialiser(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cycle_electoral_initialiser(text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.election_contester(text, text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.election_contester(text, text, integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.fraude_electorale_sanctionner(text, text) FROM PUBLIC, anon, authenticated;

-- Les joueurs n'ecrivent plus les scrutins.
DO $do$
DECLARE p record;
BEGIN
  FOR p IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'cycles_electoraux' AND cmd <> 'SELECT' LOOP
    EXECUTE format('DROP POLICY %I ON public.cycles_electoraux', p.policyname);
  END LOOP;
END $do$;
REVOKE INSERT, UPDATE, DELETE ON public.cycles_electoraux FROM anon, authenticated;
