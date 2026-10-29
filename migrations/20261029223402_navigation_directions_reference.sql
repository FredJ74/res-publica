-- Généré par outils/generateurs/navigation-directions.cjs. Ne pas modifier à la main.
UPDATE public.rue_noeuds_serveur SET directions='{"liens":{"droite":"psm-bar-imprimerie-commissariat","gauche":"psm-hotel-mairie-place"},"parArrivee":{}}'::jsonb WHERE country='republic' AND noeud='psm-marche-resto-chasse';
UPDATE public.rue_noeuds_serveur SET directions='{"liens":{"droite":"psm-marche-resto-chasse","gauche":"psm-eglise-cimetiere"},"parArrivee":{}}'::jsonb WHERE country='republic' AND noeud='psm-hotel-mairie-place';
UPDATE public.rue_noeuds_serveur SET directions='{"liens":{"droite":"psm-chantier-naval","gauche":"psm-hotel-mairie-place","arriere":"psm-carrefour-musee"},"parArrivee":{}}'::jsonb WHERE country='republic' AND noeud='psm-eglise-cimetiere';
UPDATE public.rue_noeuds_serveur SET directions='{"liens":{"toutDroit":"psm-terrains-vente","arriere":"psm-eglise-cimetiere"},"parArrivee":{}}'::jsonb WHERE country='republic' AND noeud='psm-chantier-naval';
UPDATE public.rue_noeuds_serveur SET directions='{"liens":{"droite":"psm-pole-tabac-entrepot","arriere":"psm-chantier-naval"},"parArrivee":{}}'::jsonb WHERE country='republic' AND noeud='psm-terrains-vente';
UPDATE public.rue_noeuds_serveur SET directions='{"liens":{"gauche":null,"droite":null,"toutDroit":"psm-carrefour-artisanal-scierie","arriere":"psm-terrains-vente"},"parArrivee":{}}'::jsonb WHERE country='republic' AND noeud='psm-pole-tabac-entrepot';
UPDATE public.rue_noeuds_serveur SET directions='{"liens":{"arriere":"psm-terrains-vente"},"parArrivee":{}}'::jsonb WHERE country='republic' AND noeud='psm-terrains-lots';
UPDATE public.rue_noeuds_serveur SET directions='{"liens":{},"parArrivee":{}}'::jsonb WHERE country='republic' AND noeud='caserne-exterieur';
UPDATE public.rue_noeuds_serveur SET directions='{"liens":{},"parArrivee":{}}'::jsonb WHERE country='republic' AND noeud='qhs-exterieur';
UPDATE public.rue_noeuds_serveur SET directions='{"liens":{"gauche":"montrouge-vue-5","toutDroit":"montrouge-vue-6"},"parArrivee":{}}'::jsonb WHERE country='republic' AND noeud='montrouge-vue-1';
UPDATE public.rue_noeuds_serveur SET directions='{"liens":{"toutDroit":"montrouge-vue-5","arriere":"montrouge-vue-3"},"parArrivee":{}}'::jsonb WHERE country='republic' AND noeud='montrouge-vue-2';
UPDATE public.rue_noeuds_serveur SET directions='{"liens":{"gauche":"montrouge-vue-2","droite":"montrouge-vue-4","arriere":"montrouge-vue-13"},"parArrivee":{}}'::jsonb WHERE country='republic' AND noeud='montrouge-vue-3';
