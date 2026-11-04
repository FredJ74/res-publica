-- Banc annulé de la migration 20261104213000 (Palais des Ambassades de Novomirsk). Attendu : erreur 'banc_ok'.
BEGIN;
INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'palais-ambassades-novomirsk',
   '["accueil_ambassades_novomirsk", "salle_reception", "bureau_republia_novomirsk", "bureau_khalija_novomirsk", "bureau_estado_novomirsk"]'::jsonb,
   false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-6', 'palais-ambassades-novomirsk')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF (SELECT jsonb_array_length(pieces) FROM public.navigation_lieux_regles
       WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'palais-ambassades-novomirsk') IS DISTINCT FROM 5
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city = 'capitale'
                      AND noeud = 'novomirsk-vue-6' AND building = 'palais-ambassades-novomirsk') THEN
    RAISE EXCEPTION 'novomirsk_ambassades_incomplet';
  END IF;
END $$;
DO $$ BEGIN RAISE EXCEPTION 'banc_ok'; END $$;
ROLLBACK;
