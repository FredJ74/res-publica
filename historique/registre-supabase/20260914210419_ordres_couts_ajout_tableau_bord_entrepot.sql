-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914210419
-- Nom original      : ordres_couts_ajout_tableau_bord_entrepot
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-14 21:04:19 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : dd74a116f9b8703bc0e0960008650a93
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
-- Regeneration du miroir des couts apres l'ajout de l'ordre tableau_bord_entrepot (0 PA, 0 FR).
-- Miroir genere depuis le VRAI data.js par .scratch/generer_ordres_couts.py, jamais saisi a la
-- main. Nouvelle empreinte : 507cdb2e46923ac6 (etait 30f9642665fca1e0).
INSERT INTO public.ordres_couts (fn, pa, cost)
VALUES ('tableau_bord_entrepot', 0, 0)
ON CONFLICT (fn, pa, cost) DO NOTHING;
SELECT count(*) AS lignes_miroir FROM public.ordres_couts;
