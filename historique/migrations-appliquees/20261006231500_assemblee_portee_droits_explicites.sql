-- CHANTIER 4D -- LE PUBLIC IMPLICITE, VERIFIE AVANT QU'IL NE DORME
--
-- assemblee_objet_vise a ete recreee (sa signature change) et
-- assemblee_sous_types_connus est neuve : toutes deux sont donc nees avec le
-- defaut de PostgreSQL, EXECUTE a PUBLIC. Aucune des deux n'est mutante -- elles
-- sont STABLE et ne lisent que des catalogues publics -- mais PUBLIC contourne
-- l'ALTER DEFAULT PRIVILEGES du chantier 3, qui ne retire l'EXECUTE qu'a anon.
-- On ne laisse pas un droit implicite la ou tout le reste est explicite.
--
-- CE QUI RESTE OUVERT, ET POURQUOI. assemblee_objet_vise garde anon et
-- authenticated : elle est appelee DANS assemblee_loi_en_vigueur, qui est
-- SECURITY INVOKER et dont anon a besoin pour savoir si une matiere est
-- interdite avant d'afficher un prix. Lui retirer le droit casserait l'affichage
-- sans rien proteger.
--
-- assemblee_sous_types_connus, elle, n'est appelee que par
-- assemblee_catalogue_legislatif, qui est SECURITY DEFINER : aucun role client
-- n'a besoin de l'appeler directement.

REVOKE EXECUTE ON FUNCTION public.assemblee_objet_vise(text, jsonb, jsonb) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.assemblee_objet_vise(text, jsonb, jsonb) TO anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.assemblee_sous_types_connus(text) FROM PUBLIC, anon, authenticated;
