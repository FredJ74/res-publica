-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261019162000_psm_supprimer_autoliaison_carrefour.sql ; aucun changement de règle.
-- Supprime uniquement l'auto-liaison invalide du carrefour de PSM.
UPDATE public.rue_noeuds_serveur
SET voisins=array_remove(voisins,'psm-carrefour-artisanal-scierie')
WHERE country='republic' AND city='ville_a'
  AND noeud='psm-carrefour-artisanal-scierie'
  AND 'psm-carrefour-artisanal-scierie'=ANY(voisins);