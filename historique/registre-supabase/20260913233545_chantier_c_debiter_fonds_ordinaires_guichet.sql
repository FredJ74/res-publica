-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913233545
-- Nom original      : chantier_c_debiter_fonds_ordinaires_guichet
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 23:35:45 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 34050d43bdd52c200c7729465dd8fe09
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
-- CORRECTIF IMMEDIAT, trouve par le banc de parcours joueur.
--
-- En reroutant debiterFondsOrdinaires (23 appelants) vers helvetia_debiter_fonds_ordinaires,
-- j'ai fait appeler par le NAVIGATEUR une primitive INTERNE : elle n'est pas accordee a
-- authenticated (toute depense partait en 42501), et surtout elle prend un p_personnage SANS
-- aucun controle d'acteur -- l'accorder telle quelle aurait permis de debiter n'importe qui.
--
-- Le guichet manquant : meme regle, mais l'identite est prouvee avant tout mouvement.
CREATE OR REPLACE FUNCTION public.debiter_fonds_ordinaires(p_acteur text, p_montant numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ok boolean;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'montant', 0);
  END IF;
  IF p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  v_ok := public.helvetia_debiter_fonds_ordinaires(p_acteur, p_montant);
  IF NOT v_ok THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;

  RETURN jsonb_build_object('ok', true, 'montant', p_montant,
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'solde_national', COALESCE((SELECT solde FROM public.comptes_bancaires
                                 WHERE personnage = p_acteur AND banque = 'nationale'), 0));
END; $$;

-- La primitive interne reste fermee au navigateur : elle ne prouve aucune identite.
REVOKE EXECUTE ON FUNCTION public.helvetia_debiter_fonds_ordinaires(text, numeric)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.debiter_fonds_ordinaires(text, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.debiter_fonds_ordinaires(text, numeric)
  TO authenticated, service_role;
