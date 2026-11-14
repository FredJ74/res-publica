-- Musée municipal de Krasnov : salles documentaires exclusivement pour ville_b.
-- Aucun changement au musée de Novomirsk, ni aux fonctions des quêtes du trésor des Tsars.
BEGIN;
DO $$
DECLARE initial jsonb;
BEGIN
 SELECT pieces INTO initial FROM public.navigation_lieux_regles
 WHERE pays='soviet' AND ville='ville_b' AND batiment='musee-novomirsk' FOR UPDATE;
 IF initial IS DISTINCT FROM '["hall","salle_criminels","salle_maires","salle_personnalites","salle_entrepreneurs","salle_organisations","salle_plumes","salle_honneur_militaire","salle_unions","salle_scandales"]'::jsonb
 THEN RAISE EXCEPTION 'Le parcours du musée de Krasnov a changé : migration arrêtée'; END IF;
END $$;
UPDATE public.navigation_lieux_regles
SET pieces='["hall","faune_sauvage","flore_sauvage","exploitation_bois","kolkhozes","ecoute_spatiale"]'::jsonb
WHERE pays='soviet' AND ville='ville_b' AND batiment='musee-novomirsk';
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
 WHERE pays='soviet' AND ville='ville_b' AND batiment='musee-novomirsk'
 AND jsonb_array_length(pieces)=6 AND pieces ? 'hall' AND pieces ? 'ecoute_spatiale' AND NOT ferme)
 OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-station-musee' AND building='musee-novomirsk')
 THEN RAISE EXCEPTION 'Musée de Krasnov : salles ou accès mal raccordés'; END IF;
END $$;
COMMIT;
