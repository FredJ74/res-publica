-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261008221846 (UTC ; 00h18 a Paris), nom
-- `defaut_des_privileges_de_fonction_ferme`. Registre passe de 560 a 561 entrees.
--
-- LE CORPS CI-DESSOUS EST EXACTEMENT CELUI QUI A TOURNE, relu dans
-- supabase_migrations.schema_migrations apres application : md5
-- a9eb568d05cfe8600007a37f065f3103 pour 6 612 caracteres, en un seul statement.
--
-- -----------------------------------------------------------------------------
-- CE QU'ELLE FERME : LE DEFAUT N'EST PLUS OUVERT
-- -----------------------------------------------------------------------------
-- Jusqu'ici, toute fonction creee dans `public` naissait appelable par les deux roles
-- clients, sans qu'aucun GRANT ne soit ecrit nulle part. Il fallait s'en souvenir a chaque
-- CREATE FUNCTION pour la refermer -- et le depot montre que ce souvenir a manque au moins
-- trois fois, rattrape chaque fois par la relecture du diff du baseline et jamais par un
-- controle. Desormais une fonction neuve n'accorde EXECUTE qu'a `postgres` et
-- `service_role` : une fonction destinee au client doit recevoir son GRANT EXPLICITE dans sa
-- propre migration.
--
-- DECOUVERT PAR LE BANC DU CHANTIER 4G, le 8 octobre. En recreant onze fonctions de
-- l'Assemblee, ce banc a signale SEPT droits `authenticated` APPARUS alors que ZERO etait
-- perdu : les sept fonctions de cron, que seul le serveur doit appeler, revenaient ouvertes.
-- 4G a referme ces sept-la une par une ; cette migration ferme la cause.
--
-- -----------------------------------------------------------------------------
-- LA CAUSE EXACTE : DEUX MECANISMES DISTINCTS, ET IL FALLAIT LES DEUX
-- -----------------------------------------------------------------------------
-- Mesure du 9 octobre sur l'instance, pas deduite du depot. Une fonction temoin creee dans
-- `public` naissait avec `PUBLIC authenticated postgres service_role`. Deux sources :
--
--   1. `authenticated` venait de l'entree de `pg_default_acl` POSEE PAR `postgres` POUR LE
--      SCHEMA `public` : {postgres=X, authenticated=X, service_role=X}. Les 664 fonctions de
--      `public` appartiennent toutes a `postgres` et les migrations tournent sous ce role :
--      c'est donc bien cette entree qui s'appliquait. `anon` n'y figurait pas -- il est
--      revoque par IDEMPOTENCE, pour que la regle reste complete si l'entree change un jour.
--
--   2. `PUBLIC` ne venait PAS de cette entree -- il n'y figurait nulle part. Il venait du
--      DEFAUT NATIF de PostgreSQL, qui accorde EXECUTE a PUBLIC sur toute fonction. Et c'est
--      le piege : une entree de `pg_default_acl` PAR SCHEMA S'AJOUTE a ce defaut natif au
--      lieu de le remplacer. Mesure : `ALTER DEFAULT PRIVILEGES ... IN SCHEMA public REVOKE
--      EXECUTE ON FUNCTIONS FROM PUBLIC` ne modifie meme pas la ligne stockee -- il est
--      INOPERANT. Seule une entree SANS `IN SCHEMA`, donc au niveau du ROLE, retire le
--      PUBLIC natif.
--
-- POURQUOI CELA DECIDE DE TOUT : `PUBLIC` englobe `anon` et `authenticated`. Retirer
-- `authenticated` de l'entree par schema SANS retirer `PUBLIC` n'aurait rien ferme -- la
-- fonction neuve serait restee appelable par les deux roles clients. Le premier banc l'a
-- montre noir sur blanc : apres la seule correction par schema, le temoin portait encore
-- `PUBLIC postgres service_role`. Une correction qui parait juste et ne ferme rien.
--
-- UN TROISIEME PIEGE, MESURE ET EVITE. Si l'on revoque AUSSI `service_role` de l'entree par
-- schema, il ne reste que le proprietaire, PostgreSQL SUPPRIME la ligne, et l'ACL de la
-- fonction neuve repasse a `proacl = NULL` -- c'est-a-dire au defaut natif, PUBLIC compris.
-- Fermer trop rouvre. `service_role` doit rester, et la preuve 2 le verifie.
--
-- -----------------------------------------------------------------------------
-- CE QU'ELLE NE FAIT PAS
-- -----------------------------------------------------------------------------
-- Elle ne retire AUCUN droit a AUCUNE fonction existante, et c'est ce qui la rend sans risque
-- pour la beta en cours : un default privilege ne vaut que pour l'avenir. Les 664 fonctions
-- gardent exactement ce qu'elles avaient -- PUBLIC sur 37, `anon` sur 58, `authenticated` sur
-- 421, `service_role` et `postgres` sur 664 -- et la preuve 5 le verifie compte par compte.
--
-- Elle ne touche pas l'entree de `pg_default_acl` posee par `supabase_admin`, qui accorde
-- aussi `anon`. Mesure : `postgres` n'est pas superuser et n'est pas membre de
-- `supabase_admin` ; la tentative rend `permission denied to change default privileges`.
-- Cette entree ne s'applique qu'aux objets crees PAR `supabase_admin`, donc aux migrations
-- internes de la plateforme, jamais aux notres. Constate, consigne, pas force.
--
-- Elle ne modifie PAS `public.personnages`, dont le SECURITY DEFINER est structurel :
-- `personnages_donnees` porte un REVOKE ALL delibere pour les roles clients, et la vue est ce
-- qui leur donne acces. En invoker, chaque lecture cliente leverait 42501. La preuve 6
-- verifie qu'elle n'a pas bouge, et le banc a verifie qu'un role `authenticated` continue de
-- lire ses 8 lignes.
--
-- -----------------------------------------------------------------------------
-- LA VUE catalogue_generiques_raccordes, DANS LE MEME LOT
-- -----------------------------------------------------------------------------
-- Signalee « Security Definer View » par l'advisor Supabase. Les quatre faits de l'audit
-- statique du 8 octobre ont ete REVALIDES sur l'instance avant d'y toucher : reloptions vide
-- (donc definer) ; AUCUN consommateur -- aucune fonction SQL ne la cite, aucune autre vue ne
-- la cite, aucun .js / .html / .css servi ne la nomme ; ses deux tables sous-jacentes ont la
-- RLS active AVEC, chacune, une policy `FOR SELECT TO {anon, authenticated} USING (true)` et
-- un GRANT SELECT aux deux roles. Aucune autorite ne reposait donc sur son mode definer.
--
-- LA PREUVE QUI COMPTE N'EST PAS L'ABSENCE D'ERREUR, C'EST LE NOMBRE DE LIGNES. En invoker,
-- PostgreSQL evalue les policies pour l'appelant, et une policy absente ne leve pas : elle
-- rend zero ligne. Le banc a donc compte sous SET LOCAL ROLE : 84 lignes pour `postgres`, 84
-- pour `anon`, 84 pour `authenticated` -- AVANT comme APRES la bascule.
--
-- La supprimer restait l'autre option -- elle n'a aucun lecteur -- mais son en-tete la
-- presente comme le remplacant assume du champ `actif` retire du modele, destine a un lot
-- ulterieur. Ce serait un choix produit, pas une correction de securite : il n'a pas ete fait.
--
-- -----------------------------------------------------------------------------
-- CE QUI A ETE PROUVE, ET QUAND
-- -----------------------------------------------------------------------------
-- AVANT L'APPLICATION, en transaction annulee : les quatre epreuves exigees, plus deux. Une
-- fonction temoin heritait bien de `PUBLIC` ET de `authenticated` (contre-epreuve) ; apres
-- correction elle portait exactement `postgres service_role` ; un GRANT explicite a `anon` et
-- `authenticated` fonctionnait toujours ; les cinq comptes de droits existants etaient
-- inchanges ; les DIX-HUIT entrees de `pg_default_acl` des autres schemas etaient inchangees,
-- y compris `storage/postgres/f`, le seul autre pose par `postgres` ; et les trois ALTER
-- rejoues deux fois de suite ne changeaient rien -- l'idempotence eprouvee, pas supposee.
--
-- A L'APPLICATION : les sept preuves ci-dessous ont tourne DANS la transaction de la
-- migration. La preuve 3 cree une fonction temoin, LIT SON ACL REELLE, puis la detruit --
-- c'est la seule facon de prouver un default privilege : il ne se lit pas, il s'observe sur
-- un objet neuf. Si une preuve avait leve, rien n'aurait ete applique et le temoin n'aurait
-- jamais existe.
--
-- APRES L'APPLICATION, en production et en transaction annulee, la question posee a
-- PostgreSQL lui-meme plutot qu'a l'ACL : `has_function_privilege` sur une fonction neuve
-- rend FALSE pour `anon`, FALSE pour `authenticated`, TRUE pour `service_role`, et TRUE pour
-- `authenticated` apres un GRANT explicite. Zero sonde residuelle.
--
-- AUCUNE DONNEE TOUCHEE : six tables porteuses d'argent ou de referentiel verifiees par
-- empreinte md5 avant/apres -- caisses_batiments, comptes_bancaires, budgets_nationaux,
-- budgets_municipaux, entreprises, catalogue_generiques -- toutes identiques. Et le corps
-- enregistre au registre ne contient aucun INSERT, UPDATE, DELETE ni TRUNCATE.
--
-- -----------------------------------------------------------------------------
-- LA LIMITE A CONNAITRE : LE BASELINE NE CAPTURE PAS LES DEFAULT PRIVILEGES
-- -----------------------------------------------------------------------------
-- `pg_default_acl` n'est extrait par aucun des quatre exports du baseline, et
-- `reconstruire.py` ne pose aucun default privilege. Le baseline rend les GRANT objet par
-- objet -- les 664 fonctions y gardent donc leurs droits exacts -- mais un monde RECONSTRUIT
-- de zero depuis le baseline naitrait AVEC LE DEFAUT OUVERT. Ce fichier est, en l'etat, la
-- seule trace reconstructible du durcissement : il est idempotent et peut etre rejoue tel
-- quel. Etendre l'extraction a `pg_default_acl` est un chantier d'outillage, hors du perimetre
-- de ce lot, et il est consigne comme tel.
-- =============================================================================

-- Une fonction neuve n'est plus ouverte aux clients : le defaut devient fail-closed.
-- Le raisonnement complet, les trois pieges mesures et le detail des bancs sont dans
-- migrations/20261009001500_defaut_des_privileges_de_fonction_ferme.sql, dont ce texte est le
-- code executable (meme arbre syntaxique, 5 instructions, commentaires retires pour la taille
-- du transport). Banc en transaction annulee : 7 preuves vertes avant application.

ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon;

ALTER VIEW public.catalogue_generiques_raccordes SET (security_invoker = true);

DO $$
DECLARE
  v_acl text; v_ligne text; v_n integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_default_acl
                  WHERE defaclnamespace = 0 AND defaclobjtype = 'f'
                    AND pg_get_userbyid(defaclrole) = 'postgres') THEN
    RAISE EXCEPTION 'PREUVE 1 ECHOUEE -- aucune entree de default ACL au niveau du role pour les fonctions';
  END IF;

  SELECT d.defaclacl::text INTO v_ligne
    FROM pg_default_acl d JOIN pg_namespace n ON n.oid = d.defaclnamespace
   WHERE n.nspname = 'public' AND d.defaclobjtype = 'f'
     AND pg_get_userbyid(d.defaclrole) = 'postgres';
  IF v_ligne IS NULL THEN
    RAISE EXCEPTION 'PREUVE 2 ECHOUEE -- l''entree par schema a disparu : le defaut natif, PUBLIC compris, reviendrait';
  END IF;
  IF v_ligne NOT LIKE '%service_role=X%' THEN
    RAISE EXCEPTION 'PREUVE 2 ECHOUEE -- service_role a quitte l''entree par schema : %', v_ligne;
  END IF;
  IF v_ligne LIKE '%authenticated=X%' OR v_ligne LIKE '%anon=X%' THEN
    RAISE EXCEPTION 'PREUVE 2 ECHOUEE -- un role client subsiste dans l''entree par schema : %', v_ligne;
  END IF;

  CREATE FUNCTION public.zz_sonde_defaut_privileges() RETURNS int LANGUAGE sql AS 'SELECT 1';
  SELECT coalesce(string_agg(coalesce(ro.rolname, 'PUBLIC'), ' ' ORDER BY coalesce(ro.rolname, 'PUBLIC')),
                  '(aucun)')
    INTO v_acl
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    CROSS JOIN aclexplode(p.proacl) ae
    LEFT JOIN pg_roles ro ON ro.oid = ae.grantee
   WHERE p.proname = 'zz_sonde_defaut_privileges' AND ae.privilege_type = 'EXECUTE';

  IF (SELECT p.proacl FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = 'zz_sonde_defaut_privileges') IS NULL THEN
    RAISE EXCEPTION 'PREUVE 3 ECHOUEE -- proacl NULL : la fonction neuve retombe sur le defaut natif, PUBLIC compris';
  END IF;
  IF v_acl <> 'postgres service_role' THEN
    RAISE EXCEPTION 'PREUVE 3 ECHOUEE -- une fonction neuve porte « % », « postgres service_role » attendu', v_acl;
  END IF;

  GRANT EXECUTE ON FUNCTION public.zz_sonde_defaut_privileges() TO authenticated;
  SELECT count(*) INTO v_n
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    CROSS JOIN aclexplode(p.proacl) ae
    LEFT JOIN pg_roles ro ON ro.oid = ae.grantee
   WHERE p.proname = 'zz_sonde_defaut_privileges'
     AND ro.rolname = 'authenticated' AND ae.privilege_type = 'EXECUTE';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'PREUVE 4 ECHOUEE -- un GRANT explicite a authenticated ne prend plus';
  END IF;

  DROP FUNCTION public.zz_sonde_defaut_privileges();
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND p.proname = 'zz_sonde_defaut_privileges') THEN
    RAISE EXCEPTION 'PREUVE 4 ECHOUEE -- la sonde n''a pas ete retiree';
  END IF;

  SELECT count(DISTINCT p.oid) INTO v_n
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    CROSS JOIN aclexplode(p.proacl) ae
   WHERE ae.grantee = 0 AND ae.privilege_type = 'EXECUTE';
  IF v_n <> 37 THEN RAISE EXCEPTION 'PREUVE 5 ECHOUEE -- PUBLIC sur % fonctions, 37 attendues', v_n; END IF;

  SELECT count(DISTINCT p.oid) INTO v_n
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    CROSS JOIN aclexplode(p.proacl) ae JOIN pg_roles ro ON ro.oid = ae.grantee
   WHERE ro.rolname = 'anon' AND ae.privilege_type = 'EXECUTE';
  IF v_n <> 58 THEN RAISE EXCEPTION 'PREUVE 5 ECHOUEE -- anon sur % fonctions, 58 attendues', v_n; END IF;

  SELECT count(DISTINCT p.oid) INTO v_n
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    CROSS JOIN aclexplode(p.proacl) ae JOIN pg_roles ro ON ro.oid = ae.grantee
   WHERE ro.rolname = 'authenticated' AND ae.privilege_type = 'EXECUTE';
  IF v_n <> 421 THEN RAISE EXCEPTION 'PREUVE 5 ECHOUEE -- authenticated sur % fonctions, 421 attendues', v_n; END IF;

  SELECT count(DISTINCT p.oid) INTO v_n
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    CROSS JOIN aclexplode(p.proacl) ae JOIN pg_roles ro ON ro.oid = ae.grantee
   WHERE ro.rolname = 'service_role' AND ae.privilege_type = 'EXECUTE';
  IF v_n <> 664 THEN RAISE EXCEPTION 'PREUVE 5 ECHOUEE -- service_role sur % fonctions, 664 attendues', v_n; END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                  WHERE n.nspname = 'public' AND c.relname = 'catalogue_generiques_raccordes'
                    AND 'security_invoker=true' = ANY(c.reloptions)) THEN
    RAISE EXCEPTION 'PREUVE 6 ECHOUEE -- catalogue_generiques_raccordes n''est pas passee en invoker';
  END IF;
  IF (SELECT c.reloptions FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relname = 'personnages') IS NOT NULL THEN
    RAISE EXCEPTION 'PREUVE 6 ECHOUEE -- public.personnages a ete modifiee, ce qui est interdit';
  END IF;

  SELECT count(*) INTO v_n FROM public.catalogue_generiques_raccordes;
  IF v_n <> 84 THEN
    RAISE EXCEPTION 'PREUVE 7 ECHOUEE -- la vue rend % lignes, 84 attendues', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename IN ('catalogue_generiques', 'catalogue_correspondance_legacy')
     AND cmd = 'SELECT' AND roles::text LIKE '%anon%' AND roles::text LIKE '%authenticated%';
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'PREUVE 7 ECHOUEE -- % policies de lecture cliente sur les tables de la vue, 2 attendues', v_n;
  END IF;

  RAISE NOTICE 'SEPT PREUVES VERTES. Une fonction neuve porte desormais exactement « postgres service_role ».';
END $$;
