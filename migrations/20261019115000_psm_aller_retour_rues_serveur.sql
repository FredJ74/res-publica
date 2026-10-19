-- PSM : le graphe serveur doit autoriser le retour sur chaque liaison de rue.
-- Ajout exclusivement des six liaisons retour identifiees ; aucun raccourci nouveau.
WITH retours(destination,origine) AS (
 VALUES
 ('psm-ecole-phare','psm-carrefour-artisanal-scierie'),
 ('psm-eglise-cimetiere','psm-carrefour-artisanal-scierie'),
 ('psm-tribunal-banque','psm-carrefour-artisanal-scierie'),
 ('psm-carrefour-artisanal-scierie','psm-carrefour-musee'),
 ('psm-carrefour-artisanal-scierie','psm-centre-multimodal'),
 ('psm-carrefour-artisanal-scierie','psm-pole-tabac-entrepot')
), ajouts AS (
 SELECT destination,array_agg(origine ORDER BY origine) AS retours
 FROM retours GROUP BY destination
)
UPDATE public.rue_noeuds_serveur n
SET voisins=(SELECT array_agg(DISTINCT x ORDER BY x)
  FROM unnest(coalesce(n.voisins,ARRAY[]::text[]) || a.retours) AS x)
FROM ajouts a
WHERE n.country='republic' AND n.city='ville_a' AND n.noeud=a.destination
 AND EXISTS (SELECT 1 FROM retours r
  JOIN public.rue_noeuds_serveur s ON s.country=n.country AND s.city=n.city AND s.noeud=r.origine
  WHERE r.destination=n.noeud AND n.noeud=ANY(s.voisins));