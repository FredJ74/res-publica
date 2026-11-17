-- Starovka (décisions de Fred, 17/11/2026, GAME-DESIGN-NOVOMIRSK.md « Tour de Starovka ») :
-- 1. Pas de centre commercial à Starovka (assez de locaux à louer ; les PJ peuvent en construire un
--    sur les terrains à bâtir) : la règle de navigation du bâtiment et ses quatre locaux vides sont
--    retirés. Il n'avait aucune entrée de rue ; aucun local n'était attribué ni demandé (vérifié).
-- 2. Le local vide voisin de Chasse et Pêche (rue du magasin de chasse) est le local n°2 de
--    locaux-starovka : une entrée de plus depuis cette rue. Ni bâtiment, ni pièce, ni ordre nouveau.
BEGIN;

DO $starovka$
BEGIN
  IF EXISTS (SELECT 1 FROM public.sovarka_locaux
    WHERE pays='soviet' AND ville='ville_a' AND batiment='centre-commercial'
      AND (entreprise_id IS NOT NULL OR demande_id IS NOT NULL))
  THEN RAISE EXCEPTION 'starovka_centre_commercial_local_occupe'; END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_demandes
    WHERE pays='soviet' AND ville='ville_a'
      AND 'centre-commercial' IN (local_batiment, local_souhaite_batiment))
  THEN RAISE EXCEPTION 'starovka_centre_commercial_demande_en_cours'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-magasin-chasse')
  THEN RAISE EXCEPTION 'starovka_rue_magasin_chasse_absente'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_a' AND batiment='locaux-starovka')
  THEN RAISE EXCEPTION 'starovka_locaux_sans_pieces'; END IF;
END
$starovka$;

DELETE FROM public.sovarka_locaux
 WHERE pays='soviet' AND ville='ville_a' AND batiment='centre-commercial'
   AND entreprise_id IS NULL AND demande_id IS NULL;
DELETE FROM public.rue_sorties_batiments
 WHERE country='soviet' AND city='ville_a' AND building='centre-commercial';
DELETE FROM public.navigation_lieux_regles
 WHERE pays='soviet' AND ville='ville_a' AND batiment='centre-commercial';

INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
VALUES ('soviet','ville_a','starovka-rue-magasin-chasse','locaux-starovka')
ON CONFLICT DO NOTHING;

DO $starovka$
BEGIN
  IF EXISTS (SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_a' AND batiment='centre-commercial')
     OR EXISTS (SELECT 1 FROM public.sovarka_locaux
    WHERE pays='soviet' AND ville='ville_a' AND batiment='centre-commercial')
  THEN RAISE EXCEPTION 'starovka_centre_commercial_encore_present'; END IF;
  IF (SELECT count(*) FROM public.rue_sorties_batiments
      WHERE country='soviet' AND city='ville_a' AND building='locaux-starovka'
        AND noeud IN ('starovka-rue-blizzard','starovka-rue-locaux-a-louer','starovka-rue-magasin-chasse')) <> 3
  THEN RAISE EXCEPTION 'starovka_acces_locaux_incomplets'; END IF;
END
$starovka$;
COMMIT;
