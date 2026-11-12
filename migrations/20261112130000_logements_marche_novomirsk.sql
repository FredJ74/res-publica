-- Logements du Marché (Novomirsk, vue 16), demande de Fred du 12/11/2026 : les immeubles au-dessus du
-- marché sont des logements sociaux. Même immeuble que la vue 14 (migration 20261106003000) : 4 petits
-- (10 PSK, +3 moral +4 santé au sommeil) et 4 grands (20 PSK, +5 moral +7 santé), mécanique de
-- Montrouge (demande à la mairie, attribution par l'adjoint, loyer à la commune). Appartements
-- numérotés 5 à 8 : la mairie les présente par leur nom.
BEGIN;

INSERT INTO public.logements_sociaux_historiques (pays, ville, batiment, piece, label, type_logement, loyer, bonus_moral, bonus_sante) VALUES
  ('soviet', 'capitale', 'logements-novomirsk-marche', 'petit_appartement_1', 'Petit appartement n°5', 'petit', 10, 3, 4),
  ('soviet', 'capitale', 'logements-novomirsk-marche', 'petit_appartement_2', 'Petit appartement n°6', 'petit', 10, 3, 4),
  ('soviet', 'capitale', 'logements-novomirsk-marche', 'petit_appartement_3', 'Petit appartement n°7', 'petit', 10, 3, 4),
  ('soviet', 'capitale', 'logements-novomirsk-marche', 'petit_appartement_4', 'Petit appartement n°8', 'petit', 10, 3, 4),
  ('soviet', 'capitale', 'logements-novomirsk-marche', 'grand_appartement_1', 'Grand appartement n°5', 'grand', 20, 5, 7),
  ('soviet', 'capitale', 'logements-novomirsk-marche', 'grand_appartement_2', 'Grand appartement n°6', 'grand', 20, 5, 7),
  ('soviet', 'capitale', 'logements-novomirsk-marche', 'grand_appartement_3', 'Grand appartement n°7', 'grand', 20, 5, 7),
  ('soviet', 'capitale', 'logements-novomirsk-marche', 'grand_appartement_4', 'Grand appartement n°8', 'grand', 20, 5, 7)
ON CONFLICT DO NOTHING;

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'logements-novomirsk-marche',
   '["salle","petit_appartement_1","petit_appartement_2","petit_appartement_3","petit_appartement_4","grand_appartement_1","grand_appartement_2","grand_appartement_3","grand_appartement_4"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-16', 'logements-novomirsk-marche')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF (SELECT count(*) FROM public.logements_sociaux_historiques WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'logements-novomirsk-marche') <> 8
     OR (SELECT count(*) FROM public.logements_sociaux_historiques WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'logements-novomirsk') <> 8
     OR NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'logements-novomirsk-marche')
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE noeud = 'novomirsk-vue-16' AND building = 'logements-novomirsk-marche') THEN
    RAISE EXCEPTION 'logements_marche_novomirsk_incomplet';
  END IF;
END $$;

COMMIT;
