-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260915195136
-- Nom original      : ordres_couts_commissariat_refonte
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-15 19:51:36 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ec59939b0efda574d4751a31956039a4
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
-- MIROIR DES COUTS D'ORDRE — aligne sur data.js apres la refonte du commissariat.
-- Le miroir n'est jamais saisi a la main : il est regenere par .scratch/generer_ordres_couts.py,
-- qui charge le VRAI data.js dans JavaScriptCore. Verification faite avant d'ecrire : le contenu
-- en base est deja identique au miroir regenere a deux lignes pres (md5 du corpus trie, 396 vs
-- 398 triples). Seuls ces deux ordres neufs manquaient, on n'ecrit donc qu'eux.
--   arreter : passe a 3 PA / 0 FR       -- deja aligne
--   cambrioler_caisse_commissariat      -- deja retire (ordre supprime du jeu)
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('dossiers_plaintes', 0, 0),
  ('subvention_min_int', 0, 0);

UPDATE public.ordres_couts_empreinte SET empreinte = '1407c550172b1a88', pose_le = now();