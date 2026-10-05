-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260912153503
-- Nom original      : cession_imprimerie
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-12 15:35:03 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 730aa0a26ca74ee8b6205b56d84d72c6
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
CREATE OR REPLACE FUNCTION public.imprimerie_cession_finaliser(
  p_requete       text,
  p_acheteur      text,
  p_imprimerie_id text,
  p_prix          numeric,
  p_jour          integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_prix     constant numeric := 180000;
  v_rej      jsonb;
  v_data     jsonb;
  v_pays     text;
  v_caisse   text;
  v_acompte  numeric;
  v_expire   numeric;
  v_mvt      jsonb;
  v_hist     jsonb;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_acheteur, 'cession_imprimerie');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_imprimerie_id), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'imprimerie_invalide'));
  END IF;
  IF p_prix IS DISTINCT FROM c_prix THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'prix_invalide', 'prix', c_prix));
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_imprimerie_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'imprimerie_introuvable'));
  END IF;
  IF v_data ->> 'type' IS DISTINCT FROM 'imprimerie' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'bien_non_imprimerie'));
  END IF;
  IF v_data ->> 'proprietaire' IS DISTINCT FROM 'PNJ' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_vendue',
                                                                        'proprietaire', v_data ->> 'proprietaire'));
  END IF;
  IF COALESCE((v_data -> 'compromis')::text, 'false') <> 'true'
     OR v_data ->> 'compromisPar' IS DISTINCT FROM p_acheteur THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'compromis_invalide'));
  END IF;
  v_expire := CASE WHEN jsonb_typeof(v_data -> 'compromisExpireAt') = 'number'
                   THEN (v_data ->> 'compromisExpireAt')::numeric ELSE NULL END;
  IF v_expire IS NOT NULL AND v_expire < extract(epoch FROM now()) * 1000 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'compromis_expire'));
  END IF;

  v_pays := COALESCE(NULLIF(btrim(v_data ->> 'country'), ''), 'republic');
  v_caisse := v_pays || '_gouvernement-min_fin';
  v_acompte := CASE WHEN jsonb_typeof(v_data -> 'acompte') = 'number'
                    THEN (v_data ->> 'acompte')::numeric ELSE 0 END;

  v_mvt := public.caisse_institution_mouvement(v_caisse, c_prix, true);
  IF COALESCE((v_mvt -> 'ok')::text, 'false') <> 'true' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', false, 'raison', 'caisse_etat_indisponible', 'detail', v_mvt -> 'raison'));
  END IF;

  v_hist := CASE WHEN jsonb_typeof(v_data -> 'historique') = 'array' THEN v_data -> 'historique' ELSE '[]'::jsonb END;
  v_hist := v_hist || jsonb_build_array(jsonb_build_object(
    'jour', COALESCE(p_jour, 1), 'montant', 0,
    'motif', 'Rachat de l''entreprise par ' || p_acheteur || ' (acte notarié)'));
  IF jsonb_array_length(v_hist) > 50 THEN
    v_hist := (SELECT jsonb_agg(e) FROM (
      SELECT e FROM jsonb_array_elements(v_hist) WITH ORDINALITY t(e, n)
       ORDER BY n OFFSET jsonb_array_length(v_hist) - 50) s);
  END IF;

  UPDATE public.entreprises
     SET data = (v_data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt' - 'compromisExpireAt')
                || jsonb_build_object('proprietaire', p_acheteur, 'historique', v_hist),
         updated_at = now()
   WHERE id = p_imprimerie_id;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'prix', c_prix, 'acompte', v_acompte, 'solde', c_prix - v_acompte,
    'caisse_id', v_caisse, 'caisse_solde', v_mvt -> 'solde', 'proprietaire', p_acheteur));
END;
$$;

REVOKE ALL ON FUNCTION public.imprimerie_cession_finaliser(text, text, text, numeric, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.imprimerie_cession_finaliser(text, text, text, numeric, integer) TO anon, authenticated, service_role;