-- Novomirsk, vue 2 : le Restaurant La Mère Volga est raccordé (Claude, 04/11/2026, décision de Fred).
-- Copie du Capitaine Sauvage de Port-Sainte-Marie : même bâtiment du gabarit (capitaine-sauvage).
-- Le commerce lui-même n'a rien à semer : commerces_types et commerces_dotations sont indexés par
-- « capitaine-sauvage|salle_principale », sans pays, et entreprise_assurer_existence crée
-- l'entreprise brasserie-soviet-capitale-capitaine-sauvage-salle_principale au premier accès.
-- Couches serveur dupliquées : pièces autorisées et entrée depuis la rue. Ni murs (aucun commerce
-- hors Républia n'a de titre de murs à ce jour), ni ordres de blocus (Républia seulement).
-- Idempotente.
INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'capitaine-sauvage', '["salle_principale"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-2', 'capitaine-sauvage')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'capitaine-sauvage')
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city = 'capitale'
                      AND noeud = 'novomirsk-vue-2' AND building = 'capitaine-sauvage')
     OR NOT EXISTS (SELECT 1 FROM public.commerces_types WHERE cle = 'capitaine-sauvage|salle_principale' AND type = 'brasserie') THEN
    RAISE EXCEPTION 'novomirsk_mere_volga_incomplete';
  END IF;
END $$;
