-- Bloc 5 de la mission « Novomirsk, PNJ, interface et suites des rapports » (Fred, 23/11/2026 ;
-- GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 35). Rejouable.
-- 1. La carte postale de Krasnov en vente prend l'image « Краснов, столица медведя » ; sa description (pluie d'automne) est
--    déjà en place. Les cartes déjà possédées ne sont pas touchées (elles gardent leur description ; l'écran montre la
--    nouvelle illustration d'après leur modèle).
-- 2. La carte postale de Starovka (triptyque « Привет из Старовки! ») entre au catalogue du magasin du kolkhoze, au même
--    prix et aux mêmes matières que celle de Krasnov (1 bois, 16 portions, 2 PSK), avec un stock d'ouverture de 10.

UPDATE public.recettes_commerce
   SET image = 'images/Sovarka/Krasnov/krasnov-carte-postale-capitale-ours.webp'
 WHERE id = 'carte_krasnov_place_ours' AND image IS DISTINCT FROM 'images/Sovarka/Krasnov/krasnov-carte-postale-capitale-ours.webp';

INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, categorie, types_autorises, pays_autorises,
  villes_autorisees, buildings_autorises, icone, image, description, effets, famille_produit_marche, bonus_integration_ville, generique_id) VALUES
 ('carte_starovka_hiver','kolkhoze','Carte postale — Salut de Starovka',1,16,'{"bois":1}','objet','["tabac-presse"]','["soviet"]','["ville_a"]',
  '["magasin-kolkhoze-starovka"]','ti-mail','images/Sovarka/Starovka/starovka-carte-postale-hivernale.webp',
  'Un éleveur en parka de fourrure, un match de football sur la glace devant les rennes, et les derricks sous l''aurore boréale. À écrire et à envoyer.',
  NULL,'carte_postale',NULL,'carte-postale')
ON CONFLICT (id) DO NOTHING;

-- Dotation du commerce (référence des réouvertures) : la carte s'ajoute à la liste, au plafond et au prix.
UPDATE public.commerces_dotations
   SET carte = carte || '["carte_starovka_hiver"]'::jsonb,
       parametres = jsonb_set(jsonb_set(parametres, '{stockMax,carte_starovka_hiver}', '20'), '{prixVente,carte_starovka_hiver}', '2')
 WHERE cle = 'magasin-kolkhoze-starovka@soviet.ville_a' AND NOT carte ? 'carte_starovka_hiver';

-- Commerce ouvert : même ajout, avec un stock d'ouverture de 10 cartes.
UPDATE public.entreprises
   SET data = jsonb_set(jsonb_set(jsonb_set(jsonb_set(data,
         '{carte}', coalesce(data->'carte', '[]'::jsonb) || '["carte_starovka_hiver"]'::jsonb),
         '{parametres,stockMax,carte_starovka_hiver}', '20'),
         '{parametres,prixVente,carte_starovka_hiver}', '2'),
         '{stockProduits,carte_starovka_hiver}', '10'),
       updated_at = now()
 WHERE id = 'tabac-presse-soviet-ville_a-magasin-kolkhoze-starovka' AND NOT coalesce(data->'carte', '[]'::jsonb) ? 'carte_starovka_hiver';

DO $controle$ BEGIN
  IF (SELECT image FROM public.recettes_commerce WHERE id = 'carte_krasnov_place_ours') <> 'images/Sovarka/Krasnov/krasnov-carte-postale-capitale-ours.webp'
     OR NOT EXISTS (SELECT 1 FROM public.recettes_commerce WHERE id = 'carte_starovka_hiver')
     OR NOT EXISTS (SELECT 1 FROM public.entreprises WHERE id = 'tabac-presse-soviet-ville_a-magasin-kolkhoze-starovka' AND data->'carte' ? 'carte_starovka_hiver')
     OR NOT EXISTS (SELECT 1 FROM public.commerces_dotations WHERE cle = 'magasin-kolkhoze-starovka@soviet.ville_a' AND carte ? 'carte_starovka_hiver')
  THEN RAISE EXCEPTION 'bloc 5 : cartes postales incomplètes'; END IF;
END $controle$;
