-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920145208
-- Nom original      : budget_regime_exception_serveur
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 14:52:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 19597bb23549cbc888dffeb7cd1f2224
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
-- §6.3 — budgets_nationaux : le regime d'exception est serveur-seul
-- ---------------------------------------------------------------------------
-- CONSTAT. Mon inventaire de champs precedent etait INCOMPLET : je les avais
-- trouves par un grep sur « budgetNat.X = », ce qui rate tout champ ecrit via
-- une autre variable. Quatre cles supplementaires sont apparues au banc.
--
--   regimeException  -- AUCUN ecrivain client (verifie) : seul le cron le
--                       manipule, pour en constater l'expiration. On l'epingle
--                       donc au serveur, exactement comme les deux marqueurs
--                       de journee.
--   effortGuerre     -- ISOLE. Quatre ecrivains clients (declenchement,
--                       renouvellement, cloture, curseurs) et DEUX autorites
--                       declarees sur le meme champ : l'ordre 'effort_national'
--                       est requiresPost:'president', l'ordre
--                       'tableau_effort_guerre' est requiresPost:'min_def'.
--                       Epingler sur l'un casserait l'autre. Arbitrage requis.
--   reserveJour      -- ISOLE, deja documente : accumulateur fiscal, ecrit par
--                       la taxe sur transaction de tout joueur.
--   couvreFeuEcheance -- n'existe pas : c'est mon banc qui l'avait invente.
--                       Aucune action.
--
-- Rappel : deux triggers ANTERIEURS a ce chantier protegent deja
-- stockArmurerieMilitaire, lotsMilitaires et virementJournalierCaserne, avec la
-- meme doctrine d'epinglage. L'inventaire demande sur stockArmurerieMilitaire
-- est donc clos : aucun chemin client ne l'ecrit, et le verrou existe deja.

INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note) VALUES
  ('regimeException', '(serveur)', NULL,
   'Regime d''exception : aucun ecrivain client, seul le cron constate son expiration')
ON CONFLICT (champ) DO UPDATE
  SET poste_id = EXCLUDED.poste_id, ordre_fn = EXCLUDED.ordre_fn, note = EXCLUDED.note;