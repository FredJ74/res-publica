-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261018232338.
-- Archivage documentaire seulement ; ne pas rejouer.
-- Les ecrans des lots sont des noeuds de rue accessibles dans les deux sens.
-- Leur absence parmi les voisins de la scene amont refusait le trajet.
UPDATE public.rue_noeuds_serveur
SET voisins=array_append(voisins,'luthecia-terrains-lots')
WHERE country='republic' AND city='capitale' AND noeud='luthecia-terrains-artisanal'
  AND NOT ('luthecia-terrains-lots'=ANY(voisins));
UPDATE public.rue_noeuds_serveur
SET voisins=array_append(voisins,'psm-terrains-lots')
WHERE country='republic' AND city='ville_a' AND noeud='psm-terrains-vente'
  AND NOT ('psm-terrains-lots'=ANY(voisins));