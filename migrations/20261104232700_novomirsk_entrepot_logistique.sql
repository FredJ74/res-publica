-- Novomirsk, vue 8 : l'Entrepôt Logistique est raccordé (Claude, 05/11/2026, décision de Fred).
-- Interface copiée de Luthécia, tous les ordres « Bientôt disponible » (grisés, aucun appel serveur)
-- jusqu'à l'économie de Sovarka. Directeur PNJ : Boris Stockov (nom choisi par Fred).
-- Couches serveur : pièces autorisées et entrée depuis la rue. Volontairement PAS de ligne dans
-- entrepots_par_ville ni d'état dans batiments_etat : sans approvisionnement, l'entrepôt serait
-- proposé au trading avec un stock vide. Idempotente.
INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'entrepot-logistique-novomirsk', '["salle_ventes", "bureau_direction"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-8', 'entrepot-logistique-novomirsk')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF (SELECT jsonb_array_length(pieces) FROM public.navigation_lieux_regles
       WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'entrepot-logistique-novomirsk') IS DISTINCT FROM 2
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city = 'capitale'
                      AND noeud = 'novomirsk-vue-8' AND building = 'entrepot-logistique-novomirsk') THEN
    RAISE EXCEPTION 'novomirsk_entrepot_incomplet';
  END IF;
END $$;
