-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913213021
-- Nom original      : chantier_c_phase3_succession_entreprises
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 21:30:21 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : bca27343d753ad92bc68e7596f0ff2ac
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
-- CHANTIER C / PHASE 3 — FAMILLE 8 : SUCCESSION.
--
-- Les deux sites reecrivaient le blob complet d'une entreprise a l'ouverture d'une succession :
-- pose du gel, puis annulation des compromis ou le defunt etait acheteur. Aucun controle : il
-- suffisait d'appeler sbSaveEntreprise avec un succession_gel invente pour geler l'entreprise
-- d'autrui, ou d'effacer un compromis qui n'etait pas celui du defunt.
--
-- La preuve du deces existe deja cote serveur : la ligne 'successions' est creee AVANT ces
-- ecritures, avec un index unique partiel sur defunt tant qu'elle est en attente. Les deux RPC
-- l'exigent, et verifient que l'entreprise est reellement concernee -- proprietaire pour le gel,
-- acheteur du compromis pour le nettoyage.
CREATE OR REPLACE FUNCTION public.entreprise_succession_geler(
  p_acteur text, p_entreprise text, p_succession text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_data jsonb; v_defunt text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT defunt INTO v_defunt FROM public.successions
   WHERE id = p_succession AND statut = 'en_attente';
  IF v_defunt IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_inconnue');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM v_defunt THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_du_defunt');
  END IF;

  -- Rejouable sans risque : reposer le meme gel est un no-op, c'est ce que fait deja le client
  -- en cas de reprise apres echec partiel.
  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{succession_gel}', to_jsonb(p_succession), true),
         updated_at = now()
   WHERE id = p_entreprise;
  RETURN jsonb_build_object('ok', true, 'gel', p_succession);
END; $$;

CREATE OR REPLACE FUNCTION public.entreprise_succession_annuler_compromis(
  p_acteur text, p_entreprise text, p_succession text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_data jsonb; v_defunt text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT defunt INTO v_defunt FROM public.successions
   WHERE id = p_succession AND statut = 'en_attente';
  IF v_defunt IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_inconnue');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  -- Seul un compromis dont le DEFUNT est l'acheteur peut etre annule ici. Un compromis deja
  -- nettoye n'apparait plus dans le scan du client : on repond ok sans rien ecrire.
  IF (v_data->>'compromisPar') IS DISTINCT FROM v_defunt THEN
    IF v_data ? 'compromisPar' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_compromis_du_defunt');
    END IF;
    RETURN jsonb_build_object('ok', true, 'deja_nettoye', true);
  END IF;

  v_data := v_data || jsonb_build_object(
    'compromis', NULL, 'compromisPar', NULL, 'acompte', NULL,
    'compromisAt', NULL, 'compromisExpireAt', NULL, 'pretDemande', NULL);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;
  RETURN jsonb_build_object('ok', true);
END; $$;

DO $$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS a
             FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public' AND p.proname IN
              ('entreprise_succession_geler','entreprise_succession_annuler_compromis')
  LOOP
    v := format('public.%I(%s)', r.proname, r.a);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', v);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', v);
  END LOOP;
END $$;
