-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260915220201
-- Nom original      : titulaires_pnj_policy_insert_qualifiee
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-15 22:02:01 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ea42dbc41ed3042a7e32263ac9c98bb8
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
-- CORRECTIF. Dans la policy INSERT precedente, le `poste_id` non qualifie du sous-select se
-- resolvait sur la table interne (r.poste_id = r.poste_id, toujours vrai) : NOT EXISTS etait donc
-- toujours faux et TOUTE insertion cliente etait refusee, y compris pour les postes religieux
-- qu'il s'agissait justement d'epargner. On qualifie explicitement la colonne de la ligne entrante.
DROP POLICY IF EXISTS titulaires_pnj_ecriture_non_politique ON public.titulaires_pnj;
CREATE POLICY titulaires_pnj_ecriture_non_politique ON public.titulaires_pnj
  FOR INSERT TO authenticated
  WITH CHECK (NOT EXISTS (SELECT 1 FROM public.postes_nommes_regles r
                           WHERE r.poste_id = titulaires_pnj.poste_id));