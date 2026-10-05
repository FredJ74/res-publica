-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913105641
-- Nom original      : prets_jour_dernier_prelevement_journee_partagee
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 10:56:41 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8c8b3e343518a00e07935954c2ebecce
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
-- CHANTIER A / P0-1 (14 septembre 2026).
-- prets.jour_dernier_prelevement sert de MARQUEUR ANTI-REJEU du prelevement nocturne
-- (api/cron-minuit.js, preleverPretsBancairesServeur). Les deux cotes du code y ecrivent
-- deja une journee partagee au format ISO 'YYYY-MM-DD' :
--   - plateau-justice-economie.js:7239  jour_dernier_prelevement: jourPartageISO()
--   - api/cron-minuit.js:1805           jour_dernier_prelevement: jourCourantISO()
-- ... alors que la colonne est restee 'integer' (heritage d'un compteur state.day abandonne).
-- Consequence mesuree : depuis le 8 septembre 2026 (commit 9ab4e73), TOUT nouveau pret
-- national/prive echouait a l'insertion (22P02 invalid input syntax for type integer),
-- silencieusement avale par le .catch(() => {}) de l'appelant -- l'emprunteur etait credite
-- sans qu'aucune ligne de dette n'existe. La colonne est donc alignee sur son usage reel.
--
-- Les deux lignes historiques portent la valeur par defaut '1' (jamais ecrite par le code,
-- simple DEFAULT de colonne) : elle ne designe aucune journee et devient NULL = "jamais
-- preleve". Aucune donnee de jeu n'est modifiee ici : ni montant, ni statut, ni impaye.
ALTER TABLE public.prets ALTER COLUMN jour_dernier_prelevement DROP DEFAULT;
ALTER TABLE public.prets
  ALTER COLUMN jour_dernier_prelevement TYPE text
  USING NULLIF(jour_dernier_prelevement::text, '1');

COMMENT ON COLUMN public.prets.jour_dernier_prelevement IS
  'Journee partagee ISO (YYYY-MM-DD) du dernier prelevement nocturne. Marqueur anti-rejeu du cron. NULL = jamais preleve.';