-- =============================================================================================
-- RELIQUAT DE DROITS ANONYMES SUR LES RPC MILITAIRES (24 septembre 2026)
-- =============================================================================================
-- CONSTAT. Le releve exhaustif des 105 fonctions militaires deployees a montre que NEUF d'entre
-- elles restaient executables par le role `anon`. Trois ECRIVENT :
--   militaire_mutinerie_declencher  -- cree un camp mutin et rallie des soldats
--   militaire_ration_consommer      -- modifie PA et inventaire
--   militaire_reposer_section       -- modifie les PA de toute une section
-- Les six autres sont en lecture, mais cinq exposent des positions de troupes, et la neuvieme
-- (exiger_poste) est le garde-fou d'autorite lui-meme.
--
-- CE N'ETAIT PAS UNE BRECHE EXPLOITABLE : toutes se protegent en interne par mon_personnage(),
-- qui rend NULL pour un appelant anonyme. Mais le GRANT contredisait une doctrine deja ecrite
-- ici (migration_militaire_revoquer_anon.sql) : aucune RPC militaire ne doit etre offerte au role
-- anonyme. Une protection qui ne tient que par le contenu de la fonction tombe le jour ou
-- quelqu'un la modifie sans y penser.
--
-- DEUX TEMPS, ET C'EST LE PIEGE. Trois de ces fonctions portaient un GRANT nominatif a `anon` :
-- un REVOKE ... FROM anon suffit. Les six autres tenaient leur droit d'un GRANT a PUBLIC, visible
-- dans l'ACL sous la forme `=X/postgres` -- et revoquer « FROM anon » ne retire pas un droit
-- accorde a tout le monde. D'ou le second bloc. Les six portent DEJA un droit nominatif
-- `authenticated=X/postgres`, qui survit ; les GRANT de la fin ne font que le reaffirmer.
--
-- VERIFIE APRES APPLICATION : 0 fonction militaire executable par anon (contre 9), 68 toujours
-- executables par authenticated (inchange), et le repos de section d'un vrai Lieutenant
-- fonctionne toujours -- 24 soldats reposes, en transaction annulee.
-- =============================================================================================

REVOKE EXECUTE ON FUNCTION public.exiger_poste(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.militaire_mutinerie_declencher() FROM anon;
REVOKE EXECUTE ON FUNCTION public.militaire_ration_consommer() FROM anon;
REVOKE EXECUTE ON FUNCTION public.militaire_reposer_section(text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.mutinerie_camp_de(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.mutinerie_camps_presents(text, text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.mutinerie_est_camp(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.mutinerie_pays_du_camp(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.mutinerie_social_national(text) FROM anon;

-- Second temps : les six qui tenaient leur droit de PUBLIC.
REVOKE EXECUTE ON FUNCTION public.exiger_poste(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mutinerie_camp_de(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mutinerie_camps_presents(text, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mutinerie_est_camp(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mutinerie_pays_du_camp(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mutinerie_social_national(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.exiger_poste(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mutinerie_camp_de(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mutinerie_camps_presents(text, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mutinerie_est_camp(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mutinerie_pays_du_camp(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mutinerie_social_national(text) TO authenticated, service_role;
