-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029210309.
-- Archivage documentaire seulement ; ne pas rejouer.
-- A APPLIQUER JUSTE APRES LA LIVRAISON DE LA PR #213, avec 20261028210000.
-- Reactive la garde du contenu de fret suspendue par 20261028210452 : le nouvel ecran passe
-- par fret_objet_agir, l'ancien INSERT direct du navigateur est de nouveau refuse.
ALTER TABLE public.contenu_caisses_fret ENABLE TRIGGER hg_fret_contenu_source;
