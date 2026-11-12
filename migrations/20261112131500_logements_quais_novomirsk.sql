-- Logements des Quais de Sovarka (Novomirsk, vue 16), décision de Fred du 12/11/2026 : deux immeubles
-- au-dessus du marché et non un. Tout à droite, les Logements du Marché (n°5 à 8, migration
-- 20261112130000) ; à gauche, celui à la fresque, Logements des Quais de Sovarka (nom du fleuve),
-- même nombre de logements : 4 petits (10 PSK) et 4 grands (20 PSK), numérotés 9 à 12.
BEGIN;

INSERT INTO public.logements_sociaux_historiques (pays, ville, batiment, piece, label, type_logement, loyer, bonus_moral, bonus_sante) VALUES
  ('soviet', 'capitale', 'logements-novomirsk-quais', 'petit_appartement_1', 'Petit appartement n°9', 'petit', 10, 3, 4),
  ('soviet', 'capitale', 'logements-novomirsk-quais', 'petit_appartement_2', 'Petit appartement n°10', 'petit', 10, 3, 4),
  ('soviet', 'capitale', 'logements-novomirsk-quais', 'petit_appartement_3', 'Petit appartement n°11', 'petit', 10, 3, 4),
  ('soviet', 'capitale', 'logements-novomirsk-quais', 'petit_appartement_4', 'Petit appartement n°12', 'petit', 10, 3, 4),
  ('soviet', 'capitale', 'logements-novomirsk-quais', 'grand_appartement_1', 'Grand appartement n°9', 'grand', 20, 5, 7),
  ('soviet', 'capitale', 'logements-novomirsk-quais', 'grand_appartement_2', 'Grand appartement n°10', 'grand', 20, 5, 7),
  ('soviet', 'capitale', 'logements-novomirsk-quais', 'grand_appartement_3', 'Grand appartement n°11', 'grand', 20, 5, 7),
  ('soviet', 'capitale', 'logements-novomirsk-quais', 'grand_appartement_4', 'Grand appartement n°12', 'grand', 20, 5, 7)
ON CONFLICT DO NOTHING;

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'logements-novomirsk-quais',
   '["salle","petit_appartement_1","petit_appartement_2","petit_appartement_3","petit_appartement_4","grand_appartement_1","grand_appartement_2","grand_appartement_3","grand_appartement_4"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-16', 'logements-novomirsk-quais')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF (SELECT count(*) FROM public.logements_sociaux_historiques WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'logements-novomirsk-quais') <> 8
     OR (SELECT count(*) FROM public.logements_sociaux_historiques WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'logements-novomirsk') <> 8
     OR NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'logements-novomirsk-quais')
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE noeud = 'novomirsk-vue-16' AND building = 'logements-novomirsk-quais') THEN
    RAISE EXCEPTION 'logements_quais_novomirsk_incomplet';
  END IF;
END $$;

COMMIT;
