-- Novomirsk, vue 2 : le Musée municipal est raccordé (Claude, 04/11/2026, décision de Fred).
-- Nouveau bâtiment musee-novomirsk, copie du musée de Port-Sainte-Marie (panthéon de la ville) :
-- les figures des salles sont du contenu d'écran (consulter_personnalites_musee, sans serveur).
-- Couches serveur : pièces autorisées et entrée depuis la rue. Idempotente.
INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'musee-novomirsk',
   '["hall", "salle_criminels", "salle_maires", "salle_personnalites", "salle_entrepreneurs", "salle_organisations", "salle_plumes", "salle_honneur_militaire", "salle_unions", "salle_scandales"]'::jsonb,
   false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-2', 'musee-novomirsk')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF (SELECT jsonb_array_length(pieces) FROM public.navigation_lieux_regles
       WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'musee-novomirsk') IS DISTINCT FROM 10
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city = 'capitale'
                      AND noeud = 'novomirsk-vue-2' AND building = 'musee-novomirsk') THEN
    RAISE EXCEPTION 'novomirsk_musee_incomplet';
  END IF;
END $$;
