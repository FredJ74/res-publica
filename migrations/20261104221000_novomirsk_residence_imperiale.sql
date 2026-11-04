-- Novomirsk, vue 7 : la Résidence impériale est raccordée (Claude, 04/11/2026, décisions de Fred).
-- Logements de prestige louables comme les suites du Pavillon : quatre appartements à 500 par jour
-- (+4 POP +4 INF +4 DIS) et un grand appartement à 1 200 par jour (+15 POP +15 INF +5 DIS).
-- Couches serveur : pièces autorisées, entrée depuis la rue, référentiel des loyers. Idempotente.
INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'residence-imperiale-novomirsk',
   '["hall_residence", "appartement_1", "appartement_2", "appartement_3", "appartement_4", "grand_appartement"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-7', 'residence-imperiale-novomirsk')
ON CONFLICT DO NOTHING;

INSERT INTO public.locaux_loyers_referentiel(batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable) VALUES
  ('residence-imperiale-novomirsk','appartement_1','*',500,4,4,4,'Appartement n°1',true),
  ('residence-imperiale-novomirsk','appartement_2','*',500,4,4,4,'Appartement n°2',true),
  ('residence-imperiale-novomirsk','appartement_3','*',500,4,4,4,'Appartement n°3',true),
  ('residence-imperiale-novomirsk','appartement_4','*',500,4,4,4,'Appartement n°4',true),
  ('residence-imperiale-novomirsk','grand_appartement','*',1200,15,15,5,'Grand Appartement impérial',true)
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF (SELECT jsonb_array_length(pieces) FROM public.navigation_lieux_regles
       WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'residence-imperiale-novomirsk') IS DISTINCT FROM 6
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city = 'capitale'
                      AND noeud = 'novomirsk-vue-7' AND building = 'residence-imperiale-novomirsk')
     OR (SELECT count(*) FROM public.locaux_loyers_referentiel WHERE batiment = 'residence-imperiale-novomirsk') <> 5 THEN
    RAISE EXCEPTION 'novomirsk_residence_incomplete';
  END IF;
END $$;
