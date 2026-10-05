-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917094520
-- Nom original      : militaire_nominations_rpc
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 09:45:20 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 558075f281f26713b2e3eefaa928ed5e
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
-- CHAINE MILITAIRE (suite) — LES QUATRE RPC DE NOMINATION.
-- Hierarchie appliquee : le Commandant nomme les Capitaines ; un Capitaine nomme les Lieutenants
-- de SA compagnie, et d'aucune autre ; une compagnie compte au plus 4 sections et un Lieutenant
-- commande une section vacante de cette compagnie.

-- 1. LE COMMANDANT PROPOSE UN CAPITAINE.
CREATE OR REPLACE FUNCTION public.militaire_proposer_capitaine(
  p_compagnie_id text, p_destinataire text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_acteur text; v_pays text; v_data jsonb; v_id text;
BEGIN
  v_acteur := public.exiger_poste('commandant');           -- leve si ce n'est pas le Commandant
  IF v_acteur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;

  SELECT data::jsonb INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF COALESCE(v_data->>'capitaineNom','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_deja_commandee', 'capitaine', v_data->>'capitaineNom');
  END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = p_destinataire AND country = v_pays;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;

  DELETE FROM public.nominations_militaires
   WHERE compagnie_id = p_compagnie_id AND grade = 'capitaine' AND traitee = false;
  v_id := 'nomil-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.nominations_militaires (id, pays, grade, compagnie_id, section_id, destinataire, par)
  VALUES (v_id, v_pays, 'capitaine', p_compagnie_id, NULL, p_destinataire, v_acteur);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'destinataire', p_destinataire);
END; $fn$;

-- 2. LE DESTINATAIRE ACCEPTE. C'est la nomination enregistree qui fait autorite, pas sa parole.
CREATE OR REPLACE FUNCTION public.militaire_accepter_capitaine(p_nomination_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_moi text; v_n record; v_data jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_n FROM public.nominations_militaires WHERE id = p_nomination_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'nomination_introuvable'); END IF;
  IF v_n.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire');
  END IF;
  IF v_n.traitee THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  IF v_n.grade <> 'capitaine' THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_invalide'); END IF;

  SELECT data::jsonb INTO v_data FROM public.compagnies_militaires WHERE id = v_n.compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF COALESCE(v_data->>'capitaineNom','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_deja_commandee');
  END IF;

  UPDATE public.compagnies_militaires
     SET data = (v_data || jsonb_build_object('capitaineNom', v_moi))::text
   WHERE id = v_n.compagnie_id;
  -- Le poste peut maintenant etre pose : poste_est_atteste le verifiera dans compagnies_militaires.
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','capitaine','compagnieId', v_n.compagnie_id), updated_at = now()
   WHERE name = v_moi;
  UPDATE public.nominations_militaires SET traitee = true WHERE id = p_nomination_id;

  RETURN jsonb_build_object('ok', true, 'compagnie', v_n.compagnie_id, 'capitaine', v_moi);
END; $fn$;

-- 3. LE CAPITAINE PROPOSE UN LIEUTENANT — dans SA compagnie, sur une section vacante.
CREATE OR REPLACE FUNCTION public.militaire_proposer_lieutenant(
  p_compagnie_id text, p_section_id text, p_destinataire text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_moi text; v_pays text; v_data jsonb; v_sec jsonb; v_id text; v_nb int;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  SELECT data::jsonb INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  -- AUTORITE STRUCTURELLE : etre LE capitaine de CETTE compagnie. Un capitaine d'une autre
  -- compagnie est refuse ici, et c'est tout l'interet de garder le rattachement dans la donnee.
  IF v_data->>'capitaineNom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_capitaine_de_cette_compagnie');
  END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  v_nb := COALESCE(jsonb_array_length(v_data->'sections'), 0);
  IF v_nb > 4 THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_incoherente', 'sections', v_nb); END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id LIMIT 1;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
  IF COALESCE(v_sec->>'lieutenantNom','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_deja_commandee');
  END IF;
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

-- 4. LE DESTINATAIRE ACCEPTE LA SECTION.
CREATE OR REPLACE FUNCTION public.militaire_accepter_lieutenant(p_nomination_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_moi text; v_n record; v_data jsonb; v_secs jsonb; v_maj jsonb; v_trouve boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_n FROM public.nominations_militaires WHERE id = p_nomination_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'nomination_introuvable'); END IF;
  IF v_n.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire');
  END IF;
  IF v_n.traitee THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  IF v_n.grade <> 'lieutenant' THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_invalide'); END IF;

  SELECT data::jsonb INTO v_data FROM public.compagnies_militaires WHERE id = v_n.compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;

  SELECT COALESCE(jsonb_agg(
           CASE WHEN s->>'id' = v_n.section_id AND COALESCE(s->>'lieutenantNom','') = ''
                THEN s || jsonb_build_object('lieutenantNom', v_moi) ELSE s END
           ORDER BY ord), '[]'::jsonb)
    INTO v_secs
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);

  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(v_secs) s
                  WHERE s->>'id' = v_n.section_id AND s->>'lieutenantNom' = v_moi) INTO v_trouve;
  IF NOT v_trouve THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_indisponible');
  END IF;

  UPDATE public.compagnies_militaires
     SET data = (v_data || jsonb_build_object('sections', v_secs))::text
   WHERE id = v_n.compagnie_id;
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','lieutenant','compagnieId', v_n.compagnie_id,
                                    'sectionId', v_n.section_id), updated_at = now()
   WHERE name = v_moi;
  UPDATE public.nominations_militaires SET traitee = true WHERE id = p_nomination_id;

  RETURN jsonb_build_object('ok', true, 'compagnie', v_n.compagnie_id, 'section', v_n.section_id);
END; $fn$;

-- 5. DEMETTRE UN LIEUTENANT — corrige au passage le « lieutenant fantome » documente dans le code :
-- l'ancien chemin client effacait section.lieutenantNom mais JAMAIS personnages.poste, si bien que
-- le demis gardait l'autorite serveur de retirer des armes (militaire_retrait lit la colonne poste).
CREATE OR REPLACE FUNCTION public.militaire_demettre_lieutenant(
  p_compagnie_id text, p_section_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_moi text; v_data jsonb; v_secs jsonb; v_ancien text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT data::jsonb INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'capitaineNom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_capitaine_de_cette_compagnie');
  END IF;

  SELECT s->>'lieutenantNom' INTO v_ancien
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id LIMIT 1;
  IF v_ancien IS NULL OR v_ancien = '' THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'section_deja_vacante');
  END IF;

  SELECT COALESCE(jsonb_agg(
           CASE WHEN s->>'id' = p_section_id THEN s - 'lieutenantNom' ELSE s END ORDER BY ord), '[]'::jsonb)
    INTO v_secs
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);

  UPDATE public.compagnies_militaires
     SET data = (v_data || jsonb_build_object('sections', v_secs))::text
   WHERE id = p_compagnie_id;
  -- Le poste tombe EN MEME TEMPS que la fonction : plus de lieutenant fantome.
  UPDATE public.personnages_donnees SET poste = NULL, updated_at = now()
   WHERE name = v_ancien AND poste->>'id' = 'lieutenant'
     AND poste->>'compagnieId' = p_compagnie_id;

  RETURN jsonb_build_object('ok', true, 'ancien_lieutenant', v_ancien, 'section', p_section_id);
END; $fn$;

REVOKE EXECUTE ON FUNCTION public.militaire_proposer_capitaine(text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.militaire_accepter_capitaine(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.militaire_proposer_lieutenant(text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.militaire_accepter_lieutenant(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.militaire_demettre_lieutenant(text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_proposer_capitaine(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_accepter_capitaine(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_proposer_lieutenant(text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_accepter_lieutenant(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_demettre_lieutenant(text,text) TO authenticated;