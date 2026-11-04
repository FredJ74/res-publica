-- Siège du renseignement militaire (socle) raccordé à Novomirsk, vue 8 (Claude, 05/11/2026, décisions de Fred).
-- Bâtiment commun à tous les empires (BUILDINGS['siege-renseignement']), listé seulement par ceux qui
-- l'utilisent : Sovarka l'a (« Direction du Renseignement de Sovarka »), la Républia non.
-- Trois pièces : accueil (Sergent Viktor Muetov), salle des écoutes (« Renseignement militaire », déjà
-- tenu par cellule_renseignement_creer, rien à semer), salle d'interrogatoire (copie de « Interroger un
-- détenu » du QHS : 2 PA, 75 %, +5 INF, réservée au ministre de la Défense).
-- Couches serveur : pièces autorisées, entrée depuis la rue, ordre générique et son coût. Idempotente.
INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'siege-renseignement',
   '["accueil_renseignement", "salle_ecoutes", "salle_interrogatoire_renseignement"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-8', 'siege-renseignement')
ON CONFLICT DO NOTHING;

-- Même jet et mêmes effets que la ligne `interroger` du QHS (lue en production le 05/11 : 75 %, {"inf": 5}).
INSERT INTO public.ordres_generiques(fn, taux_reussite, toujours_reussi, effets, batiments, poste_requis) VALUES
  ('interroger_renseignement', 75, false, '{"inf": 5}'::jsonb, ARRAY['siege-renseignement'], 'min_def')
ON CONFLICT (fn) DO UPDATE SET taux_reussite = EXCLUDED.taux_reussite, toujours_reussi = EXCLUDED.toujours_reussi,
  effets = EXCLUDED.effets, batiments = EXCLUDED.batiments, poste_requis = EXCLUDED.poste_requis, maj_le = now();

INSERT INTO public.ordres_couts(fn, pa, cost) VALUES ('interroger_renseignement', 2, 0)
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF (SELECT jsonb_array_length(pieces) FROM public.navigation_lieux_regles
       WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'siege-renseignement') IS DISTINCT FROM 3
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city = 'capitale'
                      AND noeud = 'novomirsk-vue-8' AND building = 'siege-renseignement')
     OR NOT EXISTS (SELECT 1 FROM public.ordres_generiques WHERE fn = 'interroger_renseignement' AND poste_requis = 'min_def')
     OR NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'interroger_renseignement' AND pa = 2 AND cost = 0) THEN
    RAISE EXCEPTION 'siege_renseignement_incomplet';
  END IF;
END $$;
