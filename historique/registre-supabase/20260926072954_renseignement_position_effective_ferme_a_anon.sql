-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926072954
-- Nom original      : renseignement_position_effective_ferme_a_anon
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 07:29:54 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a10cafffb29ae108dfe5b6a3453c0761
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
-- RESIDU D'AUTORITE SUR LE RENSEIGNEMENT (26 septembre 2026).
--
-- agent_position_effective(text) est SECURITY DEFINER et contourne donc la RLS de
-- agents_renseignement -- table qui, elle, est fermee comme il faut (RLS activee, ZERO policy,
-- aucun droit pour anon ni authenticated).
-- Mais elle portait proacl = {=X, anon=X, authenticated=X, service_role=X} : accordee a PUBLIC
-- ET au role anonyme. Un visiteur sans compte pouvait donc l'appeler sur un identifiant d'agent
-- et obtenir la position reelle de cet agent, y compris porte par un ministre.
-- Les identifiants sont de la forme cel-<epoch_ms>-<6 hex>-a<1..4> : l'enumeration a un cout,
-- mais un cout n'est pas une regle d'acces.
--
-- agents_couverture_ici() et agents_couverture_de_mon_groupe() sont dans le meme cas. Elles
-- resolvent l'acteur par mon_personnage() et ne rendent donc rien d'utile a un appelant anonyme,
-- mais elles n'ont aucune raison de lui etre offertes.
--
-- Les fonctions soeurs correctement fermees (agents_de_mon_groupe, militaire_detachement_ici)
-- sont a authenticated seul : on aligne sur elles.
-- Doctrine appliquee, deja posee le 17 puis le 24 septembre : aucune RPC offerte au role anonyme.
-- Aucun appelant client n'est concerne -- une session de joueur, meme anonyme au sens Supabase,
-- porte le role authenticated.

REVOKE ALL ON FUNCTION public.agent_position_effective(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.agent_position_effective(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.agent_position_effective(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.agents_couverture_ici() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.agents_couverture_ici() FROM anon;
GRANT EXECUTE ON FUNCTION public.agents_couverture_ici() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.agents_couverture_de_mon_groupe() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.agents_couverture_de_mon_groupe() FROM anon;
GRANT EXECUTE ON FUNCTION public.agents_couverture_de_mon_groupe() TO authenticated, service_role;