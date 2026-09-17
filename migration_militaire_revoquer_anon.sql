-- =====================================================================================
-- militaire_retrait / militaire_subtiliser : retrait du role anon
-- Res Publica, 17 septembre 2026. Prerequis isole du chantier militaire.
--
-- Doctrine etablie : le role anon n'a AUCUN usage legitime sur une RPC mutante. Un client en
-- role anon ne peut pas sauvegarder de personnage (personnages_donnees n'accorde
-- INSERT/UPDATE/DELETE qu'a authenticated), donc ne peut pas jouer. Les comptes anonymes du jeu
-- portent une session JWT et le role authenticated, pas anon. Tout EXECUTE accorde a anon est de
-- la surface heritee du piege ALTER DEFAULT PRIVILEGES.
--
-- Ces deux fonctions etaient deja protegees par exiger_acteur (qui echoue sans auth.uid()) : le
-- retrait ne change aucun comportement legitime, il supprime une surface.
--
-- BANC 4/4 : anon -> « permission denied » sur les deux ; authenticated atteint sa logique metier
-- (« pas_sur_place ») sur les deux, donc aucun appelant legitime n'est casse.
--
-- CONSTAT DU BALAYAGE, non traite ici : 42 fonctions mutantes du schema public sont encore
-- accordees a anon, dont 7 fonctions de trigger (inoffensives : un appel direct echoue).
-- Il reste donc ~35 RPC mutantes reellement atteignables par anon. Aucune n'a d'ACL nulle
-- (le piege PUBLIC par defaut a deja ete traite). A faire dans un lot dedie, avec banc.
--
-- NOTE : militaire_sections_remplacer(jsonb,text,jsonb) est accordee a anon et n'est PAS
-- SECURITY DEFINER -- c'est CORRECT : c'est une fonction PURE (remplacement d'un element dans un
-- tableau jsonb), sans aucun acces a une table. Ce n'est pas une faille, ne pas la « corriger ».
-- =====================================================================================
REVOKE ALL ON FUNCTION public.militaire_retrait(text, text, integer, text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_retrait(text, text, integer, text, text, integer) FROM anon;

REVOKE ALL ON FUNCTION public.militaire_subtiliser(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_subtiliser(text, text) FROM anon;
