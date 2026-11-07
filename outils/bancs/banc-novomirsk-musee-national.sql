-- Banc annulé de la migration 20261106194500 (Musée de la République de Sovarka). Attendu : erreur 'banc_ok'.
BEGIN;
INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'musee-national-republia',
   '["hall","salle_presidents","expositions_temporaires","salle_honneur_militaire_nationale","salle_politiques","salle_civils_intellectuels","salle_organisations","salle_artistes_sportifs","salle_tresor_national","salle_reussites_economiques","salle_grandes_villes","salle_criminels_pays"]'::jsonb,
   false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-18', 'musee-national-republia')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF (SELECT pieces FROM public.navigation_lieux_regles
       WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'musee-national-republia')
     IS DISTINCT FROM (SELECT pieces FROM public.navigation_lieux_regles
       WHERE pays = 'republic' AND ville = 'capitale' AND batiment = 'musee-national-republia')
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city = 'capitale'
                      AND noeud = 'novomirsk-vue-18' AND building = 'musee-national-republia') THEN
    RAISE EXCEPTION 'novomirsk_musee_national_incomplet';
  END IF;
END $$;
DO $$ BEGIN RAISE EXCEPTION 'banc_ok'; END $$;
ROLLBACK;
