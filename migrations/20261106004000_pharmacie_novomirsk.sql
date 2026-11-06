-- Pharmacie officielle de Novomirsk (vue 14), decisions de Fred du 06/11/2026 : un commerce comme
-- tous les commerces (2 familles et 4 articles en gratuit, 3 familles et 10 articles en premium),
-- qui vend des medicaments ; types de medicaments et effets a definir plus tard (vente « Bientot
-- disponible »). Tenue par un PNJ, Valentina Pilioulkina (nom valide par Fred) ; le commerce pourra
-- etre rachete par un PJ (prix de rachat a decider). Independante de l'ecran ; aucune donnee de
-- joueur touchee. Un etat deja vivant n'est jamais ecrase.
BEGIN;

INSERT INTO public.entreprises (id, data, updated_at) VALUES
  ('pharmacie-soviet-capitale', jsonb_build_object(
     'id', 'pharmacie-soviet-capitale', 'type', 'pharmacie', 'country', 'soviet', 'city', 'capitale',
     'buildingId', 'pharmacie-officielle-novomirsk', 'proprietaire', 'PNJ', 'caisse', 2000,
     'historique', '[]'::jsonb, 'typesAutorises', '["pharmacie"]'::jsonb), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'pharmacie-officielle-novomirsk', '["comptoir_pharmacie"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;
INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-14', 'pharmacie-officielle-novomirsk')
ON CONFLICT DO NOTHING;

-- Ordre d'ecran (grise tant que les medicaments ne sont pas definis) : connu du miroir des couts.
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'pharmacie_medicaments', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = 'pharmacie_medicaments' AND o.pa = 0 AND o.cost = 0);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.entreprises WHERE id = 'pharmacie-soviet-capitale' AND data->>'proprietaire' = 'PNJ')
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE building = 'pharmacie-officielle-novomirsk')
     OR NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'pharmacie_medicaments') THEN
    RAISE EXCEPTION 'pharmacie_novomirsk_incomplete';
  END IF;
END $$;

COMMIT;
