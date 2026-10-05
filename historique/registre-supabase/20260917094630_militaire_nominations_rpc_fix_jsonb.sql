-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917094630
-- Nom original      : militaire_nominations_rpc_fix_jsonb
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 09:46:30 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3c20a6f6a3caf2558f0fe38f21064065
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
-- Correctif de type : compagnies_militaires.data est en JSONB (et non en texte comme
-- batiments_etat/terrains_etat). Les trois ecritures sont corrigees en consequence ; aucune
-- autre logique ne change.
CREATE OR REPLACE FUNCTION public.militaire_accepter_capitaine(p_nomination_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_moi text; v_n record; v_data jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_n FROM public.nominations_militaires WHERE id = p_nomination_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'nomination_introuvable'); END IF;
  IF v_n.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire'); END IF;
  IF v_n.traitee THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  IF v_n.grade <> 'capitaine' THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_invalide'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_n.compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF COALESCE(v_data->>'capitaineNom','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_deja_commandee'); END IF;

  UPDATE public.compagnies_militaires
     SET data = v_data || jsonb_build_object('capitaineNom', v_moi)
   WHERE id = v_n.compagnie_id;
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','capitaine','compagnieId', v_n.compagnie_id), updated_at = now()
   WHERE name = v_moi;
  UPDATE public.nominations_militaires SET traitee = true WHERE id = p_nomination_id;
  RETURN jsonb_build_object('ok', true, 'compagnie', v_n.compagnie_id, 'capitaine', v_moi);
END; $fn$;

CREATE OR REPLACE FUNCTION public.militaire_proposer_lieutenant(
  p_compagnie_id text, p_section_id text, p_destinataire text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_moi text; v_pays text; v_data jsonb; v_sec jsonb; v_id text; v_nb int;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'capitaineNom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_capitaine_de_cette_compagnie'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;
  v_nb := COALESCE(jsonb_array_length(v_data->'sections'), 0);
  IF v_nb > 4 THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_incoherente', 'sections', v_nb); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id LIMIT 1;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
  IF COALESCE(v_sec->>'lieutenantNom','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_deja_commandee'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = p_destinataire AND country = v_pays;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;

  DELETE FROM public.nominations_militaires
   WHERE compagnie_id = p_compagnie_id AND section_id = p_section_id
     AND grade = 'lieutenant' AND traitee = false;
  v_id := 'nomil-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.nominations_militaires (id, pays, grade, compagnie_id, section_id, destinataire, par)
  VALUES (v_id, v_pays, 'lieutenant', p_compagnie_id, p_section_id, p_destinataire, v_moi);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'destinataire', p_destinataire);
END; $fn$;

CREATE OR REPLACE FUNCTION public.militaire_accepter_lieutenant(p_nomination_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_moi text; v_n record; v_data jsonb; v_secs jsonb; v_trouve boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_n FROM public.nominations_militaires WHERE id = p_nomination_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'nomination_introuvable'); END IF;
  IF v_n.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire'); END IF;
  IF v_n.traitee THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  IF v_n.grade <> 'lieutenant' THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_invalide'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_n.compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;

  SELECT COALESCE(jsonb_agg(
           CASE WHEN s->>'id' = v_n.section_id AND COALESCE(s->>'lieutenantNom','') = ''
                THEN s || jsonb_build_object('lieutenantNom', v_moi) ELSE s END ORDER BY ord), '[]'::jsonb)
    INTO v_secs
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);
  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(v_secs) s
                  WHERE s->>'id' = v_n.section_id AND s->>'lieutenantNom' = v_moi) INTO v_trouve;
  IF NOT v_trouve THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_indisponible'); END IF;

  UPDATE public.compagnies_militaires SET data = v_data || jsonb_build_object('sections', v_secs)
   WHERE id = v_n.compagnie_id;
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','lieutenant','compagnieId', v_n.compagnie_id,
                                    'sectionId', v_n.section_id), updated_at = now()
   WHERE name = v_moi;
  UPDATE public.nominations_militaires SET traitee = true WHERE id = p_nomination_id;
  RETURN jsonb_build_object('ok', true, 'compagnie', v_n.compagnie_id, 'section', v_n.section_id);
END; $fn$;

CREATE OR REPLACE FUNCTION public.militaire_demettre_lieutenant(
  p_compagnie_id text, p_section_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_moi text; v_data jsonb; v_secs jsonb; v_ancien text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'capitaineNom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_capitaine_de_cette_compagnie'); END IF;

  SELECT s->>'lieutenantNom' INTO v_ancien
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id LIMIT 1;
  IF v_ancien IS NULL OR v_ancien = '' THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'section_deja_vacante'); END IF;

  SELECT COALESCE(jsonb_agg(
           CASE WHEN s->>'id' = p_section_id THEN s - 'lieutenantNom' ELSE s END ORDER BY ord), '[]'::jsonb)
    INTO v_secs
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);

  UPDATE public.compagnies_militaires SET data = v_data || jsonb_build_object('sections', v_secs)
   WHERE id = p_compagnie_id;
  UPDATE public.personnages_donnees SET poste = NULL, updated_at = now()
   WHERE name = v_ancien AND poste->>'id' = 'lieutenant'
     AND poste->>'compagnieId' = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'ancien_lieutenant', v_ancien, 'section', p_section_id);
END; $fn$;