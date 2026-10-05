-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913212923
-- Nom original      : chantier_c_phase3_entreprise_mouvement_fiscal
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 21:29:23 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e74109677f6d5d428280eb22c496288d
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
-- CHANTIER C / PHASE 3 — FAMILLE 7 : REDRESSEMENT FISCAL ET SUBVENTION SUR UNE ENTREPRISE.
--
-- ajusterSoldeCibleFiscale relisait la caisse, calculait le montant reellement applicable et
-- reecrivait le blob entier -- sans aucun controle de poste dans la fonction elle-meme (il
-- n'existait qu'a l'ouverture du formulaire). N'importe quel appel direct pouvait donc vider ou
-- gonfler la caisse de n'importe quelle entreprise.
--
-- La regle metier est conservee a l'identique : un prelevement est PLAFONNE par le solde reel
-- (jamais de decouvert), un versement est integral. La fonction rend le montant REELLEMENT
-- applique, comme avant, car l'appelant s'en sert pour crediter le Tresor.
CREATE OR REPLACE FUNCTION public.entreprise_mouvement_fiscal(
  p_acteur text, p_entreprise text, p_delta numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_data jsonb; v_caisse numeric; v_reel numeric; v_jour integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  PERFORM public.exiger_poste('min_fin');

  IF p_delta IS NULL OR p_delta = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;

  v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
  -- Regle existante : un prelevement ne peut pas depasser le solde ; un versement est integral.
  v_reel := CASE WHEN p_delta >= 0 THEN p_delta ELSE -LEAST(v_caisse, -p_delta) END;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse + v_reel), true);
  v_data := public.entreprise_ajouter_historique(v_data, v_reel,
              CASE WHEN v_reel >= 0 THEN 'Subvention ministérielle' ELSE 'Redressement fiscal' END
              || ' — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'montantReel', v_reel, 'caisse', v_caisse + v_reel);
END; $$;

REVOKE EXECUTE ON FUNCTION public.entreprise_mouvement_fiscal(text,text,numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.entreprise_mouvement_fiscal(text,text,numeric) TO authenticated, service_role;
