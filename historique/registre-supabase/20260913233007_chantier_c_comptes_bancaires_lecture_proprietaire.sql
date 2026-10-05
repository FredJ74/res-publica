-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913233007
-- Nom original      : chantier_c_comptes_bancaires_lecture_proprietaire
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 23:30:07 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6e438fab5f1fe20c36349f4668e06c61
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
-- CORRECTIF IMMEDIAT. En fermant l'ECRITURE de comptes_bancaires, j'ai remplace les policies
-- existantes par une lecture publique -- ce qui a rouvert un verrou du chantier B : le solde
-- bancaire d'autrui redevenait lisible (harnais Auth/RLS tombe a 16/17, detecte par le banc).
-- Un solde bancaire est une donnee PRIVEE, au meme titre que arg, liquide, banque et inventory
-- sur la vue personnages. La lecture est donc rendue a son titulaire -- et au serveur, qui n'a
-- pas d'auth.uid() et doit continuer a traverser (cron, RPC en SECURITY DEFINER).
DROP POLICY IF EXISTS "comptes_bancaires lecture" ON public.comptes_bancaires;
CREATE POLICY "comptes_bancaires lecture proprietaire" ON public.comptes_bancaires
  FOR SELECT USING (
    public.est_appel_serveur()
    OR EXISTS (SELECT 1 FROM public.personnages_donnees p
                WHERE p.name = comptes_bancaires.personnage
                  AND p.user_id = auth.uid())
  );
