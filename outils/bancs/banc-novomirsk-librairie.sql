-- Banc annulé de la migration 20261104203000 (Librairie du Peuple de Novomirsk). Attendu : erreur 'banc_ok'.
BEGIN;
-- Novomirsk, vue 1 (Place du Peuple) : la Librairie du Peuple est raccordée (Claude, 04/11/2026,
-- décision de Fred). Copie de l'Imprimerie-Librairie Gutenberg de Port-Sainte-Marie : même
-- bâtiment du gabarit (imprimerie-librairie), mêmes pièces, mêmes ordres et mêmes fonctions
-- serveur (tracts_imprimer, imprimerie_produire_tracts, imprimerie_acheter_bois), qui lisent
-- l'atelier dans batiments_etat par l'identifiant <pays>_<ville>_<bâtiment>.
-- Couches serveur dupliquées : état de l'atelier (caisse initiale de PSM, 200 FR), pièces
-- autorisées, entrée depuis la rue. Pas d'ordres de blocus : la table ne couvre que Républia.
-- Idempotente.
INSERT INTO public.batiments_etat(id, country, city, building_id, data, updated_at)
VALUES ('soviet_capitale_imprimerie-librairie', 'soviet', 'capitale', 'imprimerie-librairie', to_jsonb('{"imprimerie": {"caisse": 200}}'::text), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'imprimerie-librairie', '["accueil_imprimerie", "atelier"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-1', 'imprimerie-librairie')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF (SELECT public.batiment_etat_lire(data) -> 'imprimerie' ->> 'caisse' FROM public.batiments_etat
       WHERE id = 'soviet_capitale_imprimerie-librairie') IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'imprimerie-librairie')
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city = 'capitale'
                      AND noeud = 'novomirsk-vue-1' AND building = 'imprimerie-librairie') THEN
    RAISE EXCEPTION 'novomirsk_librairie_incomplete';
  END IF;
END $$;
DO $$ BEGIN RAISE EXCEPTION 'banc_ok'; END $$;
ROLLBACK;
