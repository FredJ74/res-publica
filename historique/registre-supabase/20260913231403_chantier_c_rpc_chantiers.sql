-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913231403
-- Nom original      : chantier_c_rpc_chantiers
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 23:14:03 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6fd856d89615ff336e21f9d10e59f89a
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
-- CHANTIER C — FAMILLE CHANTIERS / CONSTRUCTION (14 septembre 2026).
--
-- Trois ordres etaient REFUSES en production depuis la phase 1, pour la meme raison que l'achat
-- d'arme et la production : ils annoncent a payer_ordre un montant ou des PA qui ne sont pas ceux
-- declares dans data.js (construire_sur_terrain et payer_versement_chantier y valent 0 FR,
-- travailler_chantier 0 PA). Verifie empiriquement : les trois repondent 'cout_non_declare'.
--
--   * l'apport de lancement est choisi par le joueur, au minimum 35 % du cout total ;
--   * le versement suivant est choisi librement, borne par ce qui reste a financer ;
--   * les heures de travail sont choisies, et PAYEES au joueur sur la tresorerie du chantier.
--
-- Aucune de ces valeurs ne peut figurer dans un catalogue statique : ce sont des montants de
-- transaction. Elles passent donc par des RPC metier, qui relisent le terrain sous verrou.
-- Le gabarit du chantier vient du miroir genere, jamais du navigateur.

-- Lecture du blob d'un terrain : terrains_etat.data est une colonne TEXT contenant du JSON.
CREATE OR REPLACE FUNCTION public.terrain_etat_lire(p_data text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  RETURN p_data::jsonb;
EXCEPTION WHEN others THEN RETURN NULL;
END; $$;

-- 1. LANCEMENT. Cree le chantier a partir du gabarit du palier et encaisse l'apport.
CREATE OR REPLACE FUNCTION public.chantier_lancer(
  p_acteur text, p_pays text, p_batiment text, p_palier text, p_apport numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id text; v_data jsonb; v_pal record; v_chantier jsonb; v_jour integer;
  v_palier_permis text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  v_id := p_pays || '_' || p_batiment;

  SELECT * INTO v_pal FROM public.chantiers_paliers WHERE palier = p_palier;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'palier_inconnu'); END IF;

  SELECT public.terrain_etat_lire(data) INTO v_data
    FROM public.terrains_etat WHERE id = v_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;

  -- Regles existantes, relues sur l'etat reel du terrain -- l'ecran n'est qu'une anticipation.
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;
  IF v_data ? 'chantier' AND jsonb_typeof(v_data->'chantier') = 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_en_cours');
  END IF;
  IF COALESCE((v_data->>'constructionAutorisee')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'permis_requis');
  END IF;
  v_palier_permis := v_data->'permis'->>'palierDemande';
  IF v_palier_permis IS NOT NULL AND v_palier_permis <> p_palier THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'permis_non_conforme',
                              'attendu', v_palier_permis);
  END IF;
  IF COALESCE(v_data->>'succession_gel','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;

  -- L'apport minimal vient du miroir, jamais d'un calcul transmis.
  IF p_apport IS NULL OR p_apport < v_pal.apport_minimal THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'apport_insuffisant',
                              'minimum', v_pal.apport_minimal);
  END IF;
  IF p_apport > v_pal.cout_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'apport_excessif',
                              'maximum', v_pal.cout_total);
  END IF;

  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, p_apport) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'apport', p_apport);
  END IF;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_chantier := v_pal.gabarit
                || jsonb_build_object('jourDebut', v_jour,
                                      'totalVerse', p_apport, 'tresorerie', p_apport);

  UPDATE public.terrains_etat
     SET data = (v_data || jsonb_build_object('chantier', v_chantier))::text, updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'chantier', v_chantier, 'apport', p_apport,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur));
END; $$;

-- 2. VERSEMENT. Complete le financement d'un chantier deja lance.
CREATE OR REPLACE FUNCTION public.chantier_verser(
  p_acteur text, p_pays text, p_batiment text, p_montant numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id text; v_data jsonb; v_ch jsonb; v_total numeric; v_verse numeric; v_restant numeric;
  v_montant numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  v_id := p_pays || '_' || p_batiment;

  SELECT public.terrain_etat_lire(data) INTO v_data
    FROM public.terrains_etat WHERE id = v_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;
  IF COALESCE(v_data->>'succession_gel','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;

  v_ch := v_data->'chantier';
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;

  v_total   := GREATEST(0, COALESCE((v_ch->>'coutTotal')::numeric, 0));
  v_verse   := GREATEST(0, COALESCE((v_ch->>'totalVerse')::numeric, 0));
  v_restant := GREATEST(0, v_total - v_verse);
  IF v_restant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_finance');
  END IF;

  -- Un montant absent ou nul vaut « solder » : c'est la regle de l'ecran, conservee telle quelle.
  v_montant := CASE WHEN COALESCE(p_montant, 0) > 0 THEN LEAST(p_montant, v_restant)
                    ELSE v_restant END;

  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'montant', v_montant);
  END IF;

  v_ch := v_ch || jsonb_build_object(
    'totalVerse', v_verse + v_montant,
    'tresorerie', GREATEST(0, COALESCE((v_ch->>'tresorerie')::numeric, 0)) + v_montant);

  UPDATE public.terrains_etat
     SET data = (v_data || jsonb_build_object('chantier', v_ch))::text, updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'montant', v_montant, 'chantier', v_ch,
    'pourcentage', floor((v_verse + v_montant) * 100 / NULLIF(v_total, 0)),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur));
END; $$;

DO $$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS a
             FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public' AND p.proname IN ('chantier_lancer','chantier_verser')
  LOOP
    v := format('public.%I(%s)', r.proname, r.a);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', v);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', v);
  END LOOP;
END $$;
REVOKE EXECUTE ON FUNCTION public.terrain_etat_lire(text) FROM PUBLIC, anon, authenticated;
