-- Navigation, culs-de-sac de Sovarka (Fred, 22/11/2026, nuit, point 9) : quand on entre par la gauche ou la droite,
-- on revient par le côté opposé. Place de l'Ours (entrée par la gauche depuis krasnov-rue-mairie-place) : retour à droite.
-- Même règle, contrôle de tout Sovarka : rue de l'hôpital de Krasnov (entrée par la droite) : retour à gauche.
-- Le camp des bûcherons (même cas) appartient à l'ouverture du goulag : laissé tel quel. Les voisins ne changent pas.
UPDATE public.rue_noeuds_serveur SET directions = jsonb_set(coalesce(directions, '{}'::jsonb), '{liens}', '{"droite": "krasnov-rue-mairie-place"}'::jsonb)
 WHERE country = 'soviet' AND city = 'ville_b' AND noeud = 'krasnov-place-ours';
UPDATE public.rue_noeuds_serveur SET directions = jsonb_set(coalesce(directions, '{}'::jsonb), '{liens}', '{"gauche": "krasnov-rue-bureaux"}'::jsonb)
 WHERE country = 'soviet' AND city = 'ville_b' AND noeud = 'krasnov-rue-hopital';
