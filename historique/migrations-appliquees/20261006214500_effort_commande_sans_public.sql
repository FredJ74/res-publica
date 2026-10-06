-- CHANTIER 4D -- LE RELIQUAT QUE L'INVARIANT 11 A VU
--
-- effort_commande_creer et effort_commande_annuler ont ete creees avec le
-- defaut de PostgreSQL : EXECUTE a PUBLIC. Or PUBLIC couvre TOUS les roles,
-- anon compris. Deux fonctions MUTANTES etaient donc appelables sans aucune
-- identite -- elles auraient refuse sur acteur_non_authentifie, mais la porte
-- etait ouverte, et une porte ouverte qui refuse poliment reste une porte
-- ouverte.
--
-- C'est le piege exact du chantier 3, consigne noir sur blanc apres la
-- migration 4 : « revoquer sur une fonction, c'est TOUJOURS FROM PUBLIC en plus
-- des roles nommes ». L'ALTER DEFAULT PRIVILEGES pose alors ne retire
-- l'EXECUTE qu'a anon, pas le GRANT natif a PUBLIC.
--
-- L'invariant 11 de verifier-autorite.py l'a signale avant le commit.

REVOKE EXECUTE ON FUNCTION public.effort_commande_creer(text, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.effort_commande_annuler(text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.effort_commande_creer(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.effort_commande_annuler(text) TO authenticated;
