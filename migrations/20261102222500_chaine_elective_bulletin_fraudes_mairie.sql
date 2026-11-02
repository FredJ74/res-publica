-- ============================================================================
-- Chaîne élective — audit du 02/11/2026 (outils/audits/AUDIT-CHAINE-ELECTIVE-20261102.md)
--
-- E1  candidature_publier inscrit enfin le candidat sur le BULLETIN (cycle.candidats),
--     seul lu par election_voter et par le dépouillement ; rattrapage du scrutin ouvert.
-- E2  mairie de Luthécia figée à l'ancien format (resultatsTraites vrai, phase « mandat ») :
--     le scrutin de succession du mandat en cours est ouvert (vote le 15/11).
-- E3  une fraude ne vaut que pour le tour où elle a été commise (décision de Fred,
--     02/11/2026) : fenêtre [debutTour ; finTour[ au recompte, à la contestation et
--     au plafond par type. La passe de nuit pose cycle.debutTour au second tour.
--
-- Patches en place (WORKFLOW-SUPABASE.md) : un fragment inexact fait échouer la migration.
-- Idempotente : un patch déjà appliqué est détecté par son marqueur et sauté.
-- ============================================================================

DO $mig$
DECLARE v_def text; v_new text;
  v_fn_publier CONSTANT text := 'public.candidature_publier(text,text,numeric,text,text)';
BEGIN
  -- ---------------------------------------------------------------- E1 --------
  v_def := pg_get_functiondef(v_fn_publier::regprocedure);
  IF position('AUDIT_E1_BULLETIN' IN v_def) = 0 THEN
    v_new := replace(v_def,
      $a$v_paiement jsonb; v_titre text; v_contenu text;$a$,
      $b$v_paiement jsonb; v_titre text; v_contenu text; v_cycle jsonb; v_cands jsonb;$b$);
    v_new := replace(v_new,
      $a$  v_paiement := public.payer_ordre(v_nom, 'deposer_candidature', 2, 0);$a$,
      $b$  -- AUDIT_E1_BULLETIN (02/11/2026) : LE BULLETIN EST LE CYCLE. La ligne `candidatures` et le
  -- programme ne suffisent pas : election_voter et le depouillement ne lisent que
  -- cycle.candidats. Le cycle est verrouille AVANT le paiement, et le candidat y est ajoute
  -- dans cette meme transaction (comme candidature_deposer).
  SELECT c.data::jsonb INTO v_cycle FROM public.cycles_electoraux c
   WHERE c.id = v_pays || '_' || v_cle FOR UPDATE;
  IF v_cycle IS NULL OR jsonb_typeof(v_cycle) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_introuvable');
  END IF;
  v_cands := CASE WHEN jsonb_typeof(v_cycle -> 'candidats') = 'array' THEN v_cycle -> 'candidats' ELSE '[]'::jsonb END;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_cands) e WHERE e ->> 'nom' = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_candidat');
  END IF;
  v_paiement := public.payer_ordre(v_nom, 'deposer_candidature', 2, 0);$b$);
    v_new := replace(v_new,
      $a$  PERFORM set_config('rp.programme_officiel', '0', true);$a$,
      $b$  PERFORM set_config('rp.programme_officiel', '0', true);

  UPDATE public.cycles_electoraux
     SET data = jsonb_set(v_cycle, '{candidats}', v_cands || jsonb_build_array(jsonb_build_object(
                  'nom', v_nom, 'programme', v_contenu, 'archetype', v_fiche.archetype,
                  'topicId', v_topic, 'posteActuel', v_fiche.poste ->> 'name',
                  'prospectusDistribues', 0,
                  'dateInscription', floor(extract(epoch FROM now()) * 1000))), true)::text,
         updated_at = now()
   WHERE id = v_pays || '_' || v_cle;$b$);
    IF (length(v_new) - length(v_def)) < 1000 OR position('UPDATE public.cycles_electoraux' IN v_new) = 0
       OR position('v_cycle jsonb; v_cands jsonb;' IN v_new) = 0 THEN
      RAISE EXCEPTION 'patch E1 non applique : un fragment de candidature_publier ne correspond pas';
    END IF;
    EXECUTE v_new;
  END IF;

  -- ---------------------------------------------------------------- E3 --------
  v_def := pg_get_functiondef('public.election_recompter_interne(text,text,text,text,jsonb)'::regprocedure);
  IF position('finTour' IN v_def) = 0 THEN
    v_new := replace(v_def,
      $a$              AND cycle_debut = (p_scrutin ->> 'debut')::bigint AND etat = 'non_revelee' LOOP$a$,
      $b$              AND cycle_debut = (p_scrutin ->> 'debut')::bigint AND etat = 'non_revelee'
              -- UNE FRAUDE NE VAUT QUE POUR SON TOUR (decision de Fred, 02/11/2026).
              AND created_at >= to_timestamp(coalesce((p_scrutin ->> 'debutTour')::numeric, 0) / 1000.0)
              AND created_at <  to_timestamp(coalesce((p_scrutin ->> 'finTour')::numeric, 32503680000000) / 1000.0) LOOP$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch E3 non applique : election_recompter_interne'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.election_contester(text,text,integer,integer)'::regprocedure);
  IF position('finTour' IN v_def) = 0 THEN
    v_new := replace(v_def,
      $a$     AND cycle_debut = (v_scrutin ->> 'debut')::bigint AND etat = 'non_revelee'
   ORDER BY random() LIMIT 1;$a$,
      $b$     AND cycle_debut = (v_scrutin ->> 'debut')::bigint AND etat = 'non_revelee'
     AND created_at >= to_timestamp(coalesce((v_scrutin ->> 'debutTour')::numeric, 0) / 1000.0)
     AND created_at <  to_timestamp(coalesce((v_scrutin ->> 'finTour')::numeric, 32503680000000) / 1000.0)
   ORDER BY random() LIMIT 1;$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch E3 non applique : election_contester'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.fraude_electorale_tenter(text,text,text,text,integer)'::regprocedure);
  IF position('debutTour' IN v_def) = 0 THEN
    v_new := replace(v_def,
      $a$       AND cycle_debut = (v_cycle ->> 'dateDebutCandidatures')::bigint AND type = p_type;$a$,
      $b$       AND cycle_debut = (v_cycle ->> 'dateDebutCandidatures')::bigint AND type = p_type
       AND created_at >= to_timestamp(coalesce((v_cycle ->> 'debutTour')::numeric, 0) / 1000.0);$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch E3 non applique : fraude_electorale_tenter'; END IF;
    EXECUTE v_new;
  END IF;
END $mig$;

-- ------------------------------------------------------------------ E1 bis --------
-- Rattrapage : candidatures du scrutin ouvert (meme cle de scrutin, candidatures non gelees)
-- absentes du bulletin. Personnage encore existant seulement.
WITH manquants AS (
  SELECT c.id AS cycle_id, jsonb_agg(jsonb_build_object(
           'nom', k.nom, 'programme', k.programme, 'archetype', k.archetype, 'topicId', k.topic_id,
           'prospectusDistribues', 0, 'dateInscription', floor(extract(epoch FROM k.created_at) * 1000))
           ORDER BY k.created_at) AS ajout
    FROM public.cycles_electoraux c
    JOIN public.candidatures k
      ON k.country = c.country AND k.poste_id = c.poste_id AND k.city IS NOT DISTINCT FROM c.city
     AND k.cle_scrutin = (c.data::jsonb ->> 'dateDebutCandidatures')::numeric::bigint
    JOIN public.personnages_donnees p ON p.name = k.nom
   WHERE coalesce((c.data::jsonb ->> 'resultatsTraites')::boolean, false) = false
     AND floor(extract(epoch FROM now()) * 1000) < (c.data::jsonb ->> 'dateDebutCampagne')::numeric
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(c.data::jsonb -> 'candidats', '[]'::jsonb)) e
                      WHERE e ->> 'nom' = k.nom)
   GROUP BY c.id)
UPDATE public.cycles_electoraux c
   SET data = jsonb_set(c.data::jsonb, '{candidats}',
                coalesce(c.data::jsonb -> 'candidats', '[]'::jsonb) || m.ajout, true)::text,
       updated_at = now()
  FROM manquants m WHERE c.id = m.cycle_id;

-- ------------------------------------------------------------------ E2 --------
-- Mandat en cours du Maire (PNJ) de Luthecia : du lundi 12/10 00:00 au lundi 16/11 00:00
-- (dateResultats et dateFinMandat deja en base). Meme calendrier que ouvrirSuccessionSurCycle
-- (api/cron-minuit.js) : candidatures ouvertes des le debut du mandat, gel le lundi 00:01 de
-- la derniere semaine, vote le dernier dimanche 00:01. Le titulaire n'est pas touche.
UPDATE public.cycles_electoraux c
   SET data = ((c.data::jsonb - 'relancePossibleApres' - 'egalite3eSiege' - 'realigneDimancheTs' - 'debutTour')
        || jsonb_build_object(
             'phase', 'candidatures', 'tour', 1, 'resultatsTraites', false,
             'candidats', '[]'::jsonb, 'votes', '{}'::jsonb, 'votesPNJ', '{}'::jsonb,
             'dateDebutCandidatures', (c.data::jsonb ->> 'dateResultats')::bigint,
             'dateDebutCampagne', floor(extract(epoch FROM (((to_timestamp((c.data::jsonb ->> 'dateFinMandat')::numeric / 1000)
                                   AT TIME ZONE 'Europe/Paris') - interval '7 days' + interval '1 minute') AT TIME ZONE 'Europe/Paris')) * 1000)::bigint,
             'dateVote', floor(extract(epoch FROM (((to_timestamp((c.data::jsonb ->> 'dateFinMandat')::numeric / 1000)
                                   AT TIME ZONE 'Europe/Paris') - interval '1 day' + interval '1 minute') AT TIME ZONE 'Europe/Paris')) * 1000)::bigint,
             'dateResultats', (c.data::jsonb ->> 'dateFinMandat')::bigint))::text,
       updated_at = now()
 WHERE c.id = 'republic_maire_capitale'
   AND coalesce((c.data::jsonb ->> 'resultatsTraites')::boolean, false) = true
   AND c.data::jsonb ->> 'phase' = 'mandat'
   AND (c.data::jsonb ->> 'dateFinMandat')::numeric > floor(extract(epoch FROM now()) * 1000);
