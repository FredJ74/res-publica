-- Usine pharmaceutique Pharmanov de Novomirsk (vue 18), decision de Fred du 06/11/2026 : l'usine
-- pharmaceutique du pays, rien de special ; son directeur est nomme par le ministre de l'Economie
-- collective (min_fin). C'est l'usine du socle (usine-pharmaceutique-luthecia) : memes pieces, memes
-- ordres, memes fonctions serveur, qui lisent deja le pays (produire_en_usine, vente directe,
-- virement vers le ministere, poste directeur_pharma de portee pays). Etat propre a Sovarka.
-- Independante de l'ecran ; aucune donnee de joueur touchee ; un etat deja vivant n'est jamais ecrase.
BEGIN;

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'usine-pharmaceutique-luthecia', '["salle_ventes", "bureau_direction", "salle_production"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;
INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-18', 'usine-pharmaceutique-luthecia')
ON CONFLICT DO NOTHING;

INSERT INTO public.batiments_etat (id, country, city, building_id, data, updated_at) VALUES
  ('soviet_capitale_usine-pharmaceutique-luthecia', 'soviet', 'capitale', 'usine-pharmaceutique-luthecia',
   '{"usine": {"caisse": 200, "venteDirecte": {"medicaments": 0, "desinfectant": 0}, "stockMatieres": {"plantes": 0, "alcool": 0}}}'::jsonb, now())
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.batiments_etat WHERE id = 'soviet_capitale_usine-pharmaceutique-luthecia')
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country = 'soviet' AND building = 'usine-pharmaceutique-luthecia')
     OR NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND batiment = 'usine-pharmaceutique-luthecia') THEN
    RAISE EXCEPTION 'usine_pharmanov_incomplete';
  END IF;
END $$;

COMMIT;
