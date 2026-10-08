-- Privileges par defaut des objets a venir
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle -- phase 85 : default-privileges
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- postgres / FUNCTIONS / NIVEAU GLOBAL (sans IN SCHEMA)
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON FUNCTIONS FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON FUNCTIONS FROM authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON FUNCTIONS FROM dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON FUNCTIONS FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON FUNCTIONS FROM service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON FUNCTIONS FROM supabase_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON FUNCTIONS FROM supabase_auth_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO postgres;

-- postgres / FUNCTIONS / schema public
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM supabase_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM supabase_auth_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO service_role;

-- postgres / SEQUENCES / schema public
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM supabase_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM supabase_auth_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, UPDATE, USAGE ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, UPDATE, USAGE ON SEQUENCES TO service_role;

-- postgres / TABLES / schema public
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM supabase_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM supabase_auth_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO service_role;

-- ECARTES DU RENDU, ET NOMMES PLUTOT QUE TUS :
--   postgres / storage / SEQUENCES -- schema storage, hors du perimetre reconstruit par ce baseline
--   postgres / storage / FUNCTIONS -- schema storage, hors du perimetre reconstruit par ce baseline
--   postgres / storage / TABLES -- schema storage, hors du perimetre reconstruit par ce baseline
--   supabase_admin / extensions / SEQUENCES -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / extensions / FUNCTIONS -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / extensions / TABLES -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / graphql / SEQUENCES -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / graphql / FUNCTIONS -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / graphql / TABLES -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / graphql_public / SEQUENCES -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / graphql_public / FUNCTIONS -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / graphql_public / TABLES -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / public / SEQUENCES -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / public / FUNCTIONS -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / public / TABLES -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / realtime / SEQUENCES -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / realtime / FUNCTIONS -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_admin / realtime / TABLES -- appartient a supabase_admin, que notre role de reconstruction n'administre pas
--   supabase_auth_admin / auth / SEQUENCES -- appartient a supabase_auth_admin, que notre role de reconstruction n'administre pas
--   supabase_auth_admin / auth / FUNCTIONS -- appartient a supabase_auth_admin, que notre role de reconstruction n'administre pas
--   supabase_auth_admin / auth / TABLES -- appartient a supabase_auth_admin, que notre role de reconstruction n'administre pas
--
-- DEUX SORTS DIFFERENTS, et il ne faut pas les confondre. Les entrees
-- ADMINISTRABLES mais hors perimetre -- celles de storage -- sont inventoriees
-- dans MANIFESTE.json avec rendu=false, et comptees au controle global : le
-- baseline en repond. Celles des AUTRES ROLES ne sont ni au manifeste ni au
-- compte, et c'est voulu : elles ne sont pas a nous, elles changent au rythme
-- de la plateforme, et les compter ferait rougir le controle pour une cause
-- sur laquelle nous n'avons aucune prise. Elles sont nommees ICI, et nulle
-- part ailleurs -- observees, jamais rejouees.
