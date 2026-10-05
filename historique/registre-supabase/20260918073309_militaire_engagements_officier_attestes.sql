-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918073309
-- Nom original      : militaire_engagements_officier_attestes
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 07:33:09 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d213ad5c60986c44689fef5042a27f31
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
-- ==========================================================================================
-- FILIERE OFFICIER : ecritures portees cote serveur, puis fermeture de la table
--
-- CE QUI EXISTAIT. La filiere ecrivait engagements_militaires depuis le client
-- (sbCreerEngagement / sbMajEngagement), et confirmerAffectationSection ecrivait en plus
-- section.lieutenantNom par sbSaveCompagnie ET personnages.poste DU CANDIDAT par sbUpdate.
--
-- CE DERNIER POINT EST UNE PANNE REELLE, pas seulement un trou de securite : depuis la fermeture
-- RLS, un joueur ne peut plus ecrire la fiche d'un autre, et sbUpdate ne leve pas. Le candidat
-- n'obtenait donc JAMAIS son poste de Lieutenant -- exactement la « promotion fantome » que le
-- commentaire du code disait avoir corrigee en aout. Les trois ecritures sont desormais faites
-- dans UNE transaction serveur.
--
-- Les trois transitions legitimes, et elles seules :
--   (creation)            -> 'attente_commandant'
--   Commandant, compagnie -> 'attente_capitaine'
--   Capitaine, section    -> 'affecte'
-- Toute autre transition est refusee : on verifie l'etat PRECEDENT, pas seulement l'autorite.
-- ==========================================================================================

CREATE OR REPLACE FUNCTION public.militaire_engagement_creer()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_moi text; v_pays text; v_poste text; v_id text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic'), coalesce(poste->>'id','')
    INTO v_pays, v_poste FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_poste IN ('lieutenant','capitaine','commandant') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_officier');
  END IF;
  IF EXISTS (SELECT 1 FROM public.engagements_militaires
              WHERE statut IN ('attente_commandant','attente_capitaine')
                AND data->>'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_en_cours');
  END IF;

  v_id := 'eng-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.engagements_militaires (id, statut, data)
  VALUES (v_id, 'attente_commandant',
          jsonb_build_object('pays', v_pays, 'nom', v_moi, 'depuis', to_jsonb(now())));
  RETURN jsonb_build_object('ok', true, 'engagement', v_id, 'pays', v_pays);
END; $fn$;
REVOKE ALL ON FUNCTION public.militaire_engagement_creer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_engagement_creer() TO authenticated, service_role;


CREATE OR REPLACE FUNCTION public.militaire_engagement_affecter_compagnie(
  p_engagement_id text, p_compagnie_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_moi text; v_pays text; v_e record; v_cie jsonb;
BEGIN
  v_moi := public.exiger_poste('commandant');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO v_e FROM public.engagements_militaires WHERE id = p_engagement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'engagement_introuvable'); END IF;
  -- ETAT PRECEDENT verifie : on ne saute pas une etape et on ne rejoue pas.
  IF v_e.statut <> 'attente_commandant' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etape_invalide', 'statut', v_e.statut);
  END IF;
  IF v_e.data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  SELECT data INTO v_cie FROM public.compagnies_militaires WHERE id = p_compagnie_id;
  IF v_cie IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_cie->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  UPDATE public.engagements_militaires
     SET statut = 'attente_capitaine',
         data = data || jsonb_build_object('compagnieId', p_compagnie_id, 'parCommandant', v_moi)
   WHERE id = p_engagement_id;
  RETURN jsonb_build_object('ok', true, 'statut', 'attente_capitaine', 'compagnie', p_compagnie_id);
END; $fn$;
REVOKE ALL ON FUNCTION public.militaire_engagement_affecter_compagnie(text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_engagement_affecter_compagnie(text,text) TO authenticated, service_role;


CREATE OR REPLACE FUNCTION public.militaire_engagement_affecter_section(
  p_engagement_id text, p_section_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  c_places constant integer := 24;
  v_moi text; v_pays text; v_e record; v_data jsonb; v_secs jsonb; v_nom text;
  v_reserve jsonb; v_deja integer; v_tire integer; v_pris jsonb; v_reste jsonb; v_ok boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO v_e FROM public.engagements_militaires WHERE id = p_engagement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'engagement_introuvable'); END IF;
  IF v_e.statut <> 'attente_capitaine' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etape_invalide', 'statut', v_e.statut);
  END IF;
  v_nom := v_e.data->>'nom';

  SELECT data INTO v_data FROM public.compagnies_militaires
   WHERE id = v_e.data->>'compagnieId' FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  -- AUTORITE : le Capitaine de CETTE compagnie, et personne d'autre.
  IF v_data->>'capitaineNom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_capitaine_de_cette_compagnie');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_introuvable');
  END IF;

  -- Meme regle de contingent que militaire_accepter_lieutenant : la section se peuple depuis la
  -- reserve, sans jamais depasser 24, et peut naitre incomplete.
  SELECT count(*) INTO v_deja
    FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE s->>'id' = p_section_id;
  v_reserve := CASE WHEN jsonb_typeof(v_data->'reserve')='array' THEN v_data->'reserve' ELSE '[]'::jsonb END;
  v_tire := least(greatest(0, c_places - v_deja), jsonb_array_length(v_reserve));
  SELECT coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos <= v_tire), '[]'::jsonb),
         coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos > v_tire), '[]'::jsonb)
    INTO v_pris, v_reste FROM jsonb_array_elements(v_reserve) WITH ORDINALITY AS t(sol, pos);

  SELECT coalesce(jsonb_agg(
           CASE WHEN s->>'id' = p_section_id AND coalesce(s->>'lieutenantNom','') = ''
                THEN s || jsonb_build_object('lieutenantNom', v_nom,
                       'soldats', coalesce(s->'soldats','[]'::jsonb) || v_pris)
                ELSE s END ORDER BY ord), '[]'::jsonb)
    INTO v_secs FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);
  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(v_secs) s
                  WHERE s->>'id' = p_section_id AND s->>'lieutenantNom' = v_nom) INTO v_ok;
  IF NOT v_ok THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_indisponible'); END IF;

  UPDATE public.compagnies_militaires
     SET data = v_data || jsonb_build_object('sections', v_secs, 'reserve', v_reste)
   WHERE id = v_e.data->>'compagnieId';
  -- LE POSTE DU CANDIDAT, ecrit ICI. C'est ce que le client ne pouvait plus faire.
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','lieutenant','name','Lieutenant',
                   'compagnieId', v_e.data->>'compagnieId', 'sectionId', p_section_id),
         updated_at = now()
   WHERE name = v_nom;
  UPDATE public.engagements_militaires
     SET statut = 'affecte', data = data || jsonb_build_object('sectionId', p_section_id, 'parCapitaine', v_moi)
   WHERE id = p_engagement_id;

  RETURN jsonb_build_object('ok', true, 'statut', 'affecte', 'nom', v_nom,
    'section', p_section_id, 'hommes', v_tire, 'incomplete', (v_deja + v_tire) < c_places);
END; $fn$;
REVOKE ALL ON FUNCTION public.militaire_engagement_affecter_section(text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_engagement_affecter_section(text,text) TO authenticated, service_role;