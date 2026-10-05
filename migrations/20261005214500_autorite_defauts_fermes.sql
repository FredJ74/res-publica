-- ============================================================================
-- CHANTIER 3 -- AUTORITE (1/2) : FERMER LA SOURCE, PAS SEULEMENT SES EFFETS
--
-- Le 5 octobre 2026, le role `authenticated` detenait INSERT sur 109 tables,
-- UPDATE sur 108, TRIGGER sur 138 et REFERENCES sur 138. Aucun de ces droits
-- n'a jamais ete decide : ils viennent des PRIVILEGES PAR DEFAUT du schema
-- public, qui accordaient a `authenticated` DELETE, INSERT, UPDATE, TRIGGER,
-- REFERENCES et MAINTAIN sur TOUTE table nouvellement creee.
--
-- Fermer les droits un par un sans toucher au defaut, c'est vider une baignoire
-- sans fermer le robinet : la table suivante reouvre tout. Cette migration
-- ferme le robinet, puis retire ce qu'il avait deja laisse passer.
--
-- CE QUI RESTE OUVERT, ET POURQUOI
--   . SELECT par defaut : le jeu est un monde public, la lecture l'est aussi.
--     Fermer la lecture par defaut casserait la centaine de tables que le
--     navigateur lit legitimement, et c'est un autre sujet.
--   . EXECUTE par defaut sur les fonctions : le retirer rendrait toute RPC
--     future injoignable SANS message d'erreur comprehensible (un 404
--     PostgREST). Le risque reel -- une fonction interne devenue appelable --
--     est traite ici par la revocation nominative des fonctions de declencheur,
--     et durablement par l'invariant 9 de verifier-autorite.py.
--   . Les privileges par defaut de `supabase_admin` : inchangeables depuis
--     `postgres`, qui n'est pas membre de ce role. Sans consequence : les 252
--     tables de public appartiennent toutes a `postgres`, aucune a
--     `supabase_admin`.
--
-- Idempotente : REVOKE sur un privilege absent ne fait rien.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. LE ROBINET : ce qu'une table neuve accordera desormais
--    Apres cette instruction, une table creee dans public est LISIBLE par les
--    deux roles clients, et rien de plus. Toute ecriture cliente devra etre
--    accordee explicitement, par une migration qui la nomme.
-- ----------------------------------------------------------------------------

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN
  ON TABLES FROM anon, authenticated;

-- Une sequence : USAGE et SELECT suffisent a `nextval()`, donc a tout INSERT.
-- UPDATE, lui, autorise `setval()` -- reecrire le compteur d'une table.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE UPDATE ON SEQUENCES FROM anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2. LES PRIVILEGES DE MAINTENANCE DEJA DISTRIBUES : 547 au total
--    MAINTAIN (VACUUM, ANALYZE, REINDEX, CLUSTER), REFERENCES (poser une
--    cle etrangere), TRIGGER (attacher un declencheur), TRUNCATE (vider une
--    table). Aucun n'a de sens pour un client REST ; TRIGGER est en outre une
--    voie d'escalade : attacher a une table qu'on peut ecrire une fonction
--    SECURITY DEFINER qu'on peut appeler.
--
--    ON ALL TABLES couvre aussi les vues : c'est par la que part le TRUNCATE
--    detenu sur la vue `personnages`.
-- ----------------------------------------------------------------------------

REVOKE MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON ALL TABLES IN SCHEMA public
  FROM anon, authenticated;

REVOKE UPDATE ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3. LES FONCTIONS DE DECLENCHEUR : 24 etaient appelables par le client
--    Une fonction qui rend `trigger` n'est jamais une RPC. PostgREST ne sait
--    pas l'appeler, mais le privilege EXECUTE, combine a TRIGGER sur une table,
--    permettait de l'attacher ailleurs et de la faire tourner sur un NEW
--    fabrique. Le declencheur legitime, lui, n'a pas besoin de ce privilege :
--    il est verifie a la creation du declencheur, pas a chaque execution.
--
--    Boucle plutot que liste : la regle est « aucune fonction de declencheur
--    n'est appelable par un role client », et elle doit rester vraie des 24
--    d'aujourd'hui comme des suivantes.
-- ----------------------------------------------------------------------------

DO $$
DECLARE f record; n integer := 0;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS signature
      FROM pg_proc p
      JOIN pg_namespace s ON s.oid = p.pronamespace AND s.nspname = 'public'
     WHERE p.prorettype = 'pg_catalog.trigger'::regtype
       AND EXISTS (SELECT 1 FROM aclexplode(p.proacl) a
                     JOIN pg_roles r ON r.oid = a.grantee
                    WHERE r.rolname IN ('anon', 'authenticated')
                      AND a.privilege_type = 'EXECUTE')
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, authenticated', f.signature);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'fonctions de declencheur fermees aux roles clients : %', n;
END $$;
