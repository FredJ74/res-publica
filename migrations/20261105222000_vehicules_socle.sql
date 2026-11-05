-- 5 novembre 2026 -- VEHICULES PERSONNELS, etape 1 : le socle (GAME-DESIGN-VEHICULES.md, decisions de Fred).
--
-- Socle commun a tous les empires ; seuls le garage de Novomirsk et la station-service de Krasnov
-- existent en PNJ, comme exemples (les PJ ouvriront les autres). Ce fichier pose, sans aucun acte
-- de joueur :
--   * vehicules_modeles : les trois modeles decides par Fred (places, chargement, reservoir, prix) ;
--   * routes_vehicules  : le reseau routier declare par empire (Republia : toutes les villes reliees ;
--     Sovarka : Novomirsk <-> Krasnov seulement, Starovka inaccessible). Aucun repli : un empire
--     sans route declaree n'a pas de trajet ;
--   * vehicules : un vehicule = un bien localise (pays, ville), jamais un objet d'inventaire ; son
--     carburant, sa cargaison, ses trajets depuis la derniere revision, son etat (pret / en panne) ;
--   * la cle : une ligne serrures de cible 'vehicule' (socle des serrures : cle transmissible,
--     doubles illimites par cle_dupliquer) ; serrure_valide_interne l'admet ;
--   * les recettes de commerce (source 'garage' et 'station') et les deux commerces PNJ, avec un
--     stock de depart ;
--   * les lieux (pieces autorisees et entree depuis la rue).
-- Idempotente.

CREATE TABLE IF NOT EXISTS public.vehicules_modeles (
  modele     text PRIMARY KEY,
  label      text NOT NULL,
  places     integer NOT NULL CHECK (places > 0),
  chargement integer NOT NULL CHECK (chargement > 0),
  reservoir  integer NOT NULL CHECK (reservoir > 0)
);
INSERT INTO public.vehicules_modeles (modele, label, places, chargement, reservoir) VALUES
  ('voiture', 'Voiture', 4, 150, 18),
  ('deux-roues', 'Deux-roues', 2, 50, 12),
  ('vehicule-utilitaire', 'Utilitaire', 3, 500, 25)
ON CONFLICT (modele) DO UPDATE SET label = EXCLUDED.label, places = EXCLUDED.places,
  chargement = EXCLUDED.chargement, reservoir = EXCLUDED.reservoir;
ALTER TABLE public.vehicules_modeles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.vehicules_modeles FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.routes_vehicules (
  pays text NOT NULL, ville_a text NOT NULL, ville_b text NOT NULL,
  PRIMARY KEY (pays, ville_a, ville_b),
  CHECK (ville_a < ville_b)
);
INSERT INTO public.routes_vehicules (pays, ville_a, ville_b) VALUES
  ('republic', 'capitale', 'ville_a'), ('republic', 'capitale', 'ville_b'), ('republic', 'ville_a', 'ville_b'),
  ('soviet', 'capitale', 'ville_b')
ON CONFLICT DO NOTHING;
ALTER TABLE public.routes_vehicules ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.routes_vehicules FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.vehicules (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  modele        text NOT NULL REFERENCES public.vehicules_modeles(modele),
  proprietaire  text NOT NULL,
  serrure       uuid NOT NULL UNIQUE REFERENCES public.serrures(id),
  pays          text NOT NULL,
  ville         text NOT NULL,
  carburant     integer NOT NULL DEFAULT 0 CHECK (carburant >= 0),
  cargaison     jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(cargaison) = 'array'),
  trajets_depuis_revision integer NOT NULL DEFAULT 0 CHECK (trajets_depuis_revision >= 0),
  statut        text NOT NULL DEFAULT 'pret' CHECK (statut IN ('pret', 'en_panne')),
  panne         jsonb,
  entreprise    text,
  achete_le     timestamptz NOT NULL DEFAULT now(),
  modifie_le    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT vehicules_panne_decrite CHECK (statut <> 'en_panne' OR panne IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS vehicules_lieu ON public.vehicules (pays, ville);
ALTER TABLE public.vehicules ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.vehicules FROM anon, authenticated;

-- La cle du vehicule est une serrure de cible 'vehicule', posee des l'achat.
ALTER TABLE public.serrures DROP CONSTRAINT IF EXISTS serrures_cible_check;
ALTER TABLE public.serrures ADD CONSTRAINT serrures_cible_check
  CHECK (cible = ANY (ARRAY['lieu'::text, 'armoire'::text, 'batiment'::text, 'vehicule'::text]));

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.serrure_valide_interne(public.serrures)'::regprocedure);
  IF strpos(v_def, 'vehicules_socle_v1') = 0 THEN
    v_new := replace(v_def, $a$SELECT s.statut = 'posee' AND (s.cible = 'armoire'$a$,
      $b$SELECT s.statut = 'posee' AND (s.cible = 'armoire'
    OR (s.cible = 'vehicule' AND EXISTS (SELECT 1 FROM public.vehicules v WHERE v.serrure = s.id)) -- vehicules_socle_v1$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch serrure_valide_interne non applique'; END IF;
    EXECUTE v_new;
  END IF;
END $mig$;

-- Recettes (miroir de VEHICULES_PRODUITS dans data.js). PA = regle des commerces PNJ :
-- prix = 2 x cout de revient, 1 PA = 50 FR, matieres au prix de reference.
INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, prix_fixe, categorie,
  effets, stack_key, sous_type, icone, image, description, famille_produit_marche, bonus_integration_ville,
  types_autorises, pays_autorises, villes_autorisees, buildings_autorises) VALUES
  ('voiture', 'garage', 'Voiture', 190, 1, '{"metal": 300, "textile": 200, "derives_petrochimiques": 300}'::jsonb, NULL, 'vehicule',
   NULL, NULL, NULL, 'ti-car', NULL, '4 places, 150 unités de chargement, réservoir de 18. Vendue avec sa clé.',
   NULL, NULL, '["garage"]'::jsonb, NULL, NULL, NULL),
  ('deux-roues', 'garage', 'Deux-roues', 95, 1, '{"metal": 150, "textile": 100, "derives_petrochimiques": 150}'::jsonb, NULL, 'vehicule',
   NULL, NULL, NULL, 'ti-motorbike', NULL, '2 places, 50 unités de chargement, réservoir de 12. Vendu avec sa clé.',
   NULL, NULL, '["garage"]'::jsonb, NULL, NULL, NULL),
  ('vehicule-utilitaire', 'garage', 'Utilitaire', 255, 1, '{"metal": 450, "textile": 100, "derives_petrochimiques": 250}'::jsonb, NULL, 'vehicule',
   NULL, NULL, NULL, 'ti-truck', NULL, '3 places, 500 unités de chargement, réservoir de 25. Vendu avec sa clé.',
   NULL, NULL, '["garage"]'::jsonb, NULL, NULL, NULL),
  ('bidon_carburant', 'station', 'Bidon de carburant', 0, 10, '{"carburant": 10}'::jsonb, NULL, 'carburant',
   NULL, 'carburant', NULL, 'ti-gas-station', NULL, '1 bidon = 1 unité de carburant. Se verse dans le réservoir d''un véhicule.',
   NULL, NULL, '["station-service"]'::jsonb, NULL, NULL, NULL)
ON CONFLICT (id) DO UPDATE SET source = EXCLUDED.source, label = EXCLUDED.label, pa = EXCLUDED.pa,
  portions = EXCLUDED.portions, materiaux = EXCLUDED.materiaux, categorie = EXCLUDED.categorie,
  stack_key = EXCLUDED.stack_key, icone = EXCLUDED.icone, description = EXCLUDED.description,
  types_autorises = EXCLUDED.types_autorises;

-- Les deux commerces PNJ d'exemple. Stock de depart ; un etat deja vivant n'est jamais ecrase.
INSERT INTO public.entreprises (id, data, updated_at) VALUES
  ('garage-soviet-capitale', jsonb_build_object(
     'id', 'garage-soviet-capitale', 'type', 'garage', 'country', 'soviet', 'city', 'capitale',
     'buildingId', 'garage-novomirsk', 'proprietaire', 'PNJ', 'caisse', 20000, 'historique', '[]'::jsonb,
     'carte', '["voiture", "deux-roues", "vehicule-utilitaire"]'::jsonb,
     'stockProduits', '{"voiture": 3, "deux-roues": 3, "vehicule-utilitaire": 2}'::jsonb,
     'stockMatieres', '{"metal": 0, "textile": 0, "derives_petrochimiques": 100}'::jsonb,
     'parametres', jsonb_build_object(
       'prixVente', '{"voiture": 42000, "deux-roues": 21000, "vehicule-utilitaire": 50000}'::jsonb,
       'stockMax', '{"voiture": 5, "deux-roues": 5, "vehicule-utilitaire": 3}'::jsonb,
       'prixAchatMatiere', '{"metal": 15, "textile": 5, "derives_petrochimiques": 20}'::jsonb)), now()),
  ('station-soviet-ville_b', jsonb_build_object(
     'id', 'station-soviet-ville_b', 'type', 'station-service', 'country', 'soviet', 'city', 'ville_b',
     'buildingId', 'station-service-krasnov', 'proprietaire', 'PNJ', 'caisse', 5000, 'historique', '[]'::jsonb,
     'carte', '["bidon_carburant"]'::jsonb,
     'stockProduits', '{"bidon_carburant": 200}'::jsonb,
     'stockMatieres', '{"carburant": 0}'::jsonb,
     'parametres', jsonb_build_object(
       'prixVente', '{"bidon_carburant": 20}'::jsonb,
       'stockMax', '{"bidon_carburant": 300}'::jsonb,
       'prixAchatMatiere', '{"carburant": 10}'::jsonb)), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'garage-novomirsk', '["atelier_garage"]'::jsonb, false, NULL),
  ('soviet', 'ville_b', 'station-service-krasnov', '["boutique_station"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;
INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-11', 'garage-novomirsk'),
  ('soviet', 'ville_b', 'krasnov-rue-station-musee', 'station-service-krasnov')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF (SELECT count(*) FROM public.vehicules_modeles) <> 3
     OR (SELECT count(*) FROM public.recettes_commerce WHERE source IN ('garage', 'station')) <> 4
     OR NOT EXISTS (SELECT 1 FROM public.entreprises WHERE id = 'garage-soviet-capitale' AND data->>'type' = 'garage')
     OR NOT EXISTS (SELECT 1 FROM public.entreprises WHERE id = 'station-soviet-ville_b' AND data->>'type' = 'station-service')
     OR (SELECT count(*) FROM public.rue_sorties_batiments WHERE building IN ('garage-novomirsk', 'station-service-krasnov')) <> 2 THEN
    RAISE EXCEPTION 'vehicules_socle_incomplet';
  END IF;
END $$;
