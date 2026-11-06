-- Banc annulé de la migration 20261104205000 (La Mère Volga). Attendu : erreur 'banc_ok'.
-- Vérifie aussi que le serveur crée l'entreprise de Novomirsk au premier accès (appel serveur simulé).
BEGIN;
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
SET LOCAL ROLE postgres;
DO $$
DECLARE v jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', '', true);
  v := public.entreprise_assurer_existence('brasserie-soviet-capitale-capitaine-sauvage-salle_principale', 'brasserie',
         'soviet', 'capitale', 'capitaine-sauvage', 'salle_principale');
  IF NOT coalesce((v->>'ok')::boolean, false) OR (v->'data'->>'caisse')::numeric <> 3000 THEN
    RAISE EXCEPTION 'entreprise_non_creee : %', v;
  END IF;
  RAISE EXCEPTION 'banc_ok';
END $$;
ROLLBACK;
