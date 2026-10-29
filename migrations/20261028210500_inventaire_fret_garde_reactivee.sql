-- A APPLIQUER JUSTE APRES LA LIVRAISON DE LA PR #213, avec 20261028210000.
-- Reactive la garde du contenu de fret suspendue par 20261028210452 : le nouvel ecran passe
-- par fret_objet_agir, l'ancien INSERT direct du navigateur est de nouveau refuse.
ALTER TABLE public.contenu_caisses_fret ENABLE TRIGGER hg_fret_contenu_source;
