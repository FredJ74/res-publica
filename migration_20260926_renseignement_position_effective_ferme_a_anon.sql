-- RESIDU D'AUTORITE SUR LE RENSEIGNEMENT (26 septembre 2026). APPLIQUE EN PRODUCTION.
--
-- Trouve pendant l'audit du moteur generique de groupes de PNJ.
--
-- agent_position_effective(text) est SECURITY DEFINER et contourne donc la RLS de
-- agents_renseignement -- table qui, elle, est fermee comme il faut (RLS activee, ZERO policy,
-- aucun droit table pour anon ni authenticated).
-- Mais elle portait proacl = {=X, anon=X, authenticated=X, service_role=X} : accordee a PUBLIC
-- ET au role anonyme. Un visiteur sans compte pouvait donc l'appeler sur un identifiant d'agent
-- et obtenir la position reelle de cet agent, y compris porte par un ministre.
-- Les identifiants sont de la forme cel-<epoch_ms>-<6 hex>-a<1..4> : l'enumeration a un cout,
-- mais un cout n'est pas une regle d'acces.
--
-- agents_couverture_ici() et agents_couverture_de_mon_groupe() etaient dans le meme cas. Elles
-- resolvent l'acteur par mon_personnage() et ne rendent donc rien d'utile a un appelant anonyme,
-- mais elles n'ont aucune raison de lui etre offertes.
--
-- Les fonctions soeurs correctement fermees (agents_de_mon_groupe, militaire_detachement_ici)
-- sont a authenticated seul : on aligne sur elles.
-- Doctrine appliquee, deja posee le 17 puis le 24 septembre : aucune RPC offerte au role anonyme.
-- Aucun appelant client n'est concerne -- une session de joueur, meme anonyme au sens Supabase,
-- porte le role authenticated.
--
-- BANC (appels REST reels avec la cle anon publique, apres application) :
--   POST /rest/v1/rpc/agent_position_effective  -> 42501 permission denied
--   POST /rest/v1/rpc/agents_couverture_ici     -> 42501 permission denied
--   POST /rest/v1/rpc/agents_de_mon_groupe      -> 42501 (temoin, deja ferme avant)

REVOKE ALL ON FUNCTION public.agent_position_effective(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.agent_position_effective(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.agent_position_effective(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.agents_couverture_ici() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.agents_couverture_ici() FROM anon;
GRANT EXECUTE ON FUNCTION public.agents_couverture_ici() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.agents_couverture_de_mon_groupe() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.agents_couverture_de_mon_groupe() FROM anon;
GRANT EXECUTE ON FUNCTION public.agents_couverture_de_mon_groupe() TO authenticated, service_role;
