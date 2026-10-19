-- Supprime uniquement l'auto-liaison invalide du carrefour de PSM.
UPDATE public.rue_noeuds_serveur
SET voisins=array_remove(voisins,'psm-carrefour-artisanal-scierie')
WHERE country='republic' AND city='ville_a'
  AND noeud='psm-carrefour-artisanal-scierie'
  AND 'psm-carrefour-artisanal-scierie'=ANY(voisins);