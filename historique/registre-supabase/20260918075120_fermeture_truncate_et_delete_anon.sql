-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918075120
-- Nom original      : fermeture_truncate_et_delete_anon
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-18 07:51:20 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a5487de527253d8fa4441187492c5b3b
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
-- FERMETURE DES VERBES DESTRUCTEURS (18 septembre 2026)
--
-- Constat : les DEFAULT PRIVILEGES du schema public accordent arwdDxtm a anon et authenticated
-- sur toute table creee. 46 tables se sont retrouvees sans RLS ET avec DELETE/TRUNCATE ouverts a
-- anon -- c'est-a-dire a un visiteur NON authentifie. Banc hostile du 18/09, en transaction
-- annulee : anon a pu fixer virementJournalierCaserne a 50000, supprimer le budget de khalija,
-- puis TRUNCATE la table des budgets nationaux entiere. Les trois ont reussi.
--
-- Ce lot ferme UNIQUEMENT les deux verbes purement destructeurs, pas l'ecriture :
--   * TRUNCATE : aucun producteur, ni client ni cron. Revoque partout, sans exception.
--   * DELETE   : revoque sauf sur les tables ou le client supprime reellement (releve exhaustif
--                de sbDelete() et des fetch DELETE bruts). Les 12 tables listees ci-dessous sont
--                donc epargnees, elles feront l'objet d'un lot d'attestation dedie.
--
-- NON TRAITE ICI, volontairement : UPDATE et INSERT restent ouverts. Des dizaines de producteurs
-- clients ecrivent encore directement ces tables ; les fermer avant de les avoir migres vers des
-- RPC attestees casserait le jeu. Doctrine : primitive attestee -> migration des producteurs ->
-- deploiement -> fermeture. Voir [[doctrine-controle-postgresql]].
DO $$
DECLARE
  r record;
  c_delete_legitime constant text[] := ARRAY[
    'actions_tracables','forum_posts','forum_topics','invitations_diner','locations_actives',
    'mails','objets_abandonnes','objets_recus','organisations','plaintes_en_cours',
    'salons_membres','titulaires_pnj','personnages','personnages_donnees','presences',
    'dons_en_attente','votes_electoraux','candidatures'];
BEGIN
  FOR r IN
    SELECT c.relname
      FROM pg_class c
     WHERE c.relnamespace = 'public'::regnamespace
       AND c.relkind = 'r'
  LOOP
    EXECUTE format('REVOKE TRUNCATE ON public.%I FROM anon, authenticated, PUBLIC', r.relname);
    IF NOT (r.relname = ANY (c_delete_legitime)) THEN
      EXECUTE format('REVOKE DELETE ON public.%I FROM anon, authenticated, PUBLIC', r.relname);
    END IF;
  END LOOP;
END $$;

-- La cause systemique elle-meme : que les tables FUTURES ne naissent plus destructibles.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE TRUNCATE, DELETE ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE TRUNCATE ON TABLES FROM authenticated;