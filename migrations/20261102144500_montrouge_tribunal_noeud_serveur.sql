-- Ajout du nouveau nœud de rue de Montrouge après #356.
-- Synchronisation du serveur avec plateau-rue-centrale.js.
-- Pas de mouvement forcé ni modification des positions des joueurs.
INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
VALUES (
  'republic','ville_b','montrouge-tribunal-ssm',
  ARRAY['montrouge-vue-13']::text[],
  '{"liens":{"arriere":"montrouge-vue-13"},"parArrivee":{}}'::jsonb
)
ON CONFLICT(country,city,noeud) DO UPDATE
SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

UPDATE public.rue_noeuds_serveur
SET voisins=ARRAY['montrouge-vue-3','montrouge-tribunal-ssm']::text[],
    directions='{"liens":{"toutDroit":"montrouge-vue-3","arriere":"montrouge-tribunal-ssm"},"parArrivee":{}}'::jsonb
WHERE country='republic' AND city='ville_b' AND noeud='montrouge-vue-13';
