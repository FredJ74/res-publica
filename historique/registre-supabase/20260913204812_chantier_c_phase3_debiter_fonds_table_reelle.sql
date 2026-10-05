-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913204812
-- Nom original      : chantier_c_phase3_debiter_fonds_table_reelle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 20:48:12 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 43976a231b0344db0643dda7b89e1231
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
-- Meme defaut que mouvement_titulaire, trouve en preparant la famille "vente au comptoir" :
-- cette primitive lit et ecrit la VUE public.personnages. 'liquide' y est masque pour autrui et
-- le declencheur INSTEAD OF refuse toute ligne non possedee. Elle ne fonctionnait donc que pour
-- le personnage de l'appelant, et par accident. On l'aligne sur personnages_donnees, comme toutes
-- les RPC ecrites depuis le chantier B. Semantique et signature inchangees : liquide d'abord,
-- puis le compte national, et 'arg' suit le total.
CREATE OR REPLACE FUNCTION public.helvetia_debiter_fonds_ordinaires(
  p_personnage text, p_montant numeric)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_liquide numeric; v_arg numeric; v_solde numeric;
  v_preleve_liquide numeric; v_preleve_national numeric;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 THEN RETURN true; END IF;

  SELECT COALESCE(liquide,0), COALESCE(arg,0) INTO v_liquide, v_arg
    FROM public.personnages_donnees WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;

  SELECT COALESCE(solde,0) INTO v_solde FROM public.comptes_bancaires
   WHERE personnage = p_personnage AND banque = 'nationale' FOR UPDATE;

  IF (v_liquide + COALESCE(v_solde,0)) < p_montant THEN RETURN false; END IF;

  v_preleve_liquide  := LEAST(v_liquide, p_montant);
  v_preleve_national := p_montant - v_preleve_liquide;

  UPDATE public.personnages_donnees
     SET liquide = v_liquide - v_preleve_liquide,
         arg = GREATEST(0, v_arg - p_montant),
         updated_at = now()
   WHERE name = p_personnage;

  IF v_preleve_national > 0 THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_preleve_national, updated_at = now()
     WHERE personnage = p_personnage AND banque = 'nationale';
  END IF;

  RETURN true;
END; $$;
