-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913213209
-- Nom original      : chantier_c_phase3_fermeture_entreprises
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 21:32:09 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : c9306769293c506684e340aa250413db
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
-- CHANTIER C / PHASE 3 — FERMETURE DE `entreprises`.
--
-- Etat de depart, identique a celui de batiments_etat avant la phase 2 : RLS desactivee, anon
-- detenteur d'INSERT/UPDATE/DELETE, et 23 sites clients qui reecrivaient le blob COMPLET --
-- caisse, stocks, prix, proprietaire, compromis. Les 23 sont migres vers des RPC metier.
--
-- La lecture reste ouverte (11 sites de lecture clients, et rien de prive dans ce blob :
-- l'enseigne, la carte et les prix sont affiches a tout visiteur). L'ecriture directe disparait.
--
-- Il n'y a PAS de chemin generique conserve ici, contrairement a batiments_etat : aucune
-- sous-cle d'entreprise n'est non economique. Toute ecriture passe par l'une des RPC dediees --
-- entreprise_assurer_existence, commerce_fixer_parametres, commerce_acheter_matiere,
-- commerce_vendre_produit, commerce_produire, entreprise_signer_compromis,
-- entreprise_acte_rachat, entreprise_preempter, entreprise_acte_preemption,
-- entreprise_mouvement_fiscal, entreprise_succession_geler,
-- entreprise_succession_annuler_compromis -- plus les briques "fonds de commerce" v2 deja
-- existantes (creer_fonds_commerce, acheter_produit_commerce, employer_fonds,
-- alimenter_caisse_fonds, retirer_caisse_fonds).
--
-- Le cron ecrit en service_role et n'est pas concerne.
ALTER TABLE public.entreprises ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Ecriture publique entreprises" ON public.entreprises;
DROP POLICY IF EXISTS "Maj publique entreprises" ON public.entreprises;
DROP POLICY IF EXISTS "Lecture publique entreprises" ON public.entreprises;
CREATE POLICY "entreprises lecture publique" ON public.entreprises FOR SELECT USING (true);

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.entreprises FROM anon, authenticated;
GRANT SELECT ON public.entreprises TO anon, authenticated;
