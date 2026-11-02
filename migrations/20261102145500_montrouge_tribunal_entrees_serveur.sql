-- Synchronise les entrees de la nouvelle rue du tribunal de Montrouge (#356).
-- La declaration des pieces et les illustrations existent deja dans data.js.
-- Ne modifie aucune position de joueur.
DELETE FROM public.rue_sorties_batiments
WHERE country='republic' AND city='ville_b'
  AND noeud='montrouge-vue-7' AND building='tribunal-local';

INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
VALUES
('republic','ville_b','montrouge-tribunal-ssm','tribunal-local'),
('republic','ville_b','montrouge-tribunal-ssm','services-sociaux-montrouge'),
('republic','ville_b','montrouge-tribunal-ssm','parking-tribunal-montrouge')
ON CONFLICT(country,city,noeud,building) DO NOTHING;
