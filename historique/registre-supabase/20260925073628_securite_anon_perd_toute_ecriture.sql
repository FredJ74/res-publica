-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260925073628
-- Nom original      : securite_anon_perd_toute_ecriture
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-25 07:36:28 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a01709ba91df10fc569a6773b15d6b3a
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
-- =============================================================================================
-- LE ROLE `anon` PERD TOUTE ECRITURE (25 septembre 2026) — K-1, valide par Fred
-- =============================================================================================
-- `anon`, c'est le visiteur SANS COMPTE, muni de la seule cle publique committee dans supabase.js.
-- Il pouvait ecrire dans 98 tables : creer des personnages, voter, juger, emprisonner, publier,
-- virer de l'argent, et en effacer.
--
-- POURQUOI PLUS AUCUN ECRIVAIN LEGITIME NE SUBSISTE SOUS CE ROLE :
--   - un joueur connecte porte `authenticated`, y compris via l'auth anonyme Supabase ;
--   - la page d'accueil ne touche aucune table (seule la RPC mon_personnage est appelee) ;
--   - les traitements serveur sont passes sous service_role le 24 septembre (commit bd4021d) ;
--   - api/chat.js emploie la cle anon comme `apikey` mais porte le JETON DU JOUEUR en
--     Authorization : le serveur y voit `authenticated`, jamais `anon`.
--
-- CE LOT NE TOUCHE QUE L'ECRITURE. Les lectures de `anon` sont traitees table par table, apres
-- audit de chacune. Aucune policy, aucun droit de `authenticated`, aucune valeur de jeu modifies.
--
-- REFERENCES et TRIGGER sont retires en meme temps : ils venaient du GRANT ALL d'origine et
-- n'ont aucun usage pour un visiteur.
DO $$
DECLARE r record; n int := 0;
BEGIN
  FOR r IN
    SELECT c.relname
      FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
     WHERE ns.nspname = 'public' AND c.relkind IN ('r','v','p')
       AND EXISTS (SELECT 1 FROM information_schema.role_table_grants g
                    WHERE g.table_schema = 'public' AND g.table_name = c.relname
                      AND g.grantee = 'anon'
                      AND g.privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'))
     ORDER BY c.relname
  LOOP
    EXECUTE format('REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.%I FROM anon', r.relname);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'ecriture anonyme retiree sur % relations', n;
END $$;

-- Et pour que le trou ne se rouvre pas au prochain CREATE TABLE.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES FROM anon;