-- ============================================================================
-- CHANTIER 3 -- AUTORITE (4/4) : CE QUE LA MIGRATION 1 AVAIT MANQUE
--
-- La migration 1 a revoque EXECUTE sur les 24 fonctions de declencheur
-- « FROM anon, authenticated ». Elle a laisse le GRANT A `PUBLIC`.
--
-- Or un GRANT a PUBLIC vaut pour TOUS les roles. Retirer le droit nominatif de
-- `anon` et de `authenticated` ne leur retire rien tant que PUBLIC le porte
-- encore : les 24 fonctions sont restees appelables par n'importe qui. La
-- revocation etait sincere et sans effet.
--
-- COMMENT ON L'A SU. L'invariant 9 de verifier-autorite.py a rougi apres la
-- reextraction du baseline : il lit les GRANT tels qu'ils sont, pas tels qu'on
-- a cru les ecrire. C'est exactement le defaut qu'un controle doit trouver --
-- et la raison pour laquelle le baseline SUIT la base. Verifie ensuite en base :
-- 24 fonctions de declencheur portent toujours EXECUTE avec grantee = 0, l'OID
-- de PUBLIC.
--
-- La migration 3, elle, avait le bon reflexe : « FROM PUBLIC, anon ». La
-- migration 1 ne l'avait pas. Les deux ont ete ecrites le meme jour ; seule la
-- seconde a ete relue par un controle.
--
-- CE QUE CELA NE CHANGE PAS. Un declencheur legitime ne consomme pas ce
-- privilege : le droit d'executer la fonction est verifie a la CREATION du
-- declencheur, pas a chaque ligne touchee. Les 24 declencheurs attaches
-- continueront de se declencher. Ce qui disparait, c'est la possibilite
-- d'attacher l'une de ces fonctions SECURITY DEFINER a une autre table et de la
-- faire tourner sur un NEW fabrique.
--
-- Boucle plutot que liste, et sans nommer de role : on retire EXECUTE a TOUT
-- beneficiaire autre que postgres et service_role. La regle est « aucune
-- fonction de declencheur n'est appelable depuis l'exterieur », et elle doit
-- rester vraie des 24 d'aujourd'hui comme des suivantes.
--
-- Idempotente : un REVOKE sur un privilege absent ne fait rien.
-- ============================================================================

DO $$
DECLARE
  f record;
  n integer := 0;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS signature,
           coalesce((SELECT rolname::text FROM pg_roles WHERE oid = a.grantee), 'PUBLIC') AS benef
      FROM pg_proc p
      JOIN pg_namespace s ON s.oid = p.pronamespace AND s.nspname = 'public'
      CROSS JOIN LATERAL aclexplode(p.proacl) a
     WHERE p.prorettype = 'pg_catalog.trigger'::regtype
       AND a.privilege_type = 'EXECUTE'
       AND coalesce((SELECT rolname::text FROM pg_roles WHERE oid = a.grantee), 'PUBLIC')
           NOT IN ('postgres', 'service_role')
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM %s',
                   f.signature,
                   CASE WHEN f.benef = 'PUBLIC' THEN 'PUBLIC' ELSE quote_ident(f.benef) END);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'droits EXECUTE retires sur des fonctions de declencheur : %', n;
END $$;
