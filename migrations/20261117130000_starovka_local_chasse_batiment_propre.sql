-- Starovka, rue du magasin de chasse (correctif demandé par Fred, 17/11/2026) :
-- le local n°2 (voisin de Chasse et Pêche) était une pièce du bâtiment « locaux-starovka », qui s'ouvre
-- sur le local n°1 (face à l'imprimerie) et dont la sortie pouvait ramener rue de l'imprimerie.
-- Il devient un bâtiment propre, « local-starovka-chasse » (pièce local_2 conservée), avec une seule
-- sortie : la rue du magasin de chasse. Le local n°1 reste seul dans « locaux-starovka ».
BEGIN;

DO $starovka$
BEGIN
  IF EXISTS (SELECT 1 FROM public.sovarka_locaux
    WHERE pays='soviet' AND ville='ville_a' AND batiment='locaux-starovka' AND piece='local_2'
      AND (entreprise_id IS NOT NULL OR demande_id IS NOT NULL))
  THEN RAISE EXCEPTION 'starovka_local_2_occupe'; END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_demandes
    WHERE pays='soviet' AND ville='ville_a'
      AND 'locaux-starovka' IN (local_batiment, local_souhaite_batiment))
  THEN RAISE EXCEPTION 'starovka_locaux_demande_en_cours'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-magasin-chasse')
  THEN RAISE EXCEPTION 'starovka_rue_magasin_chasse_absente'; END IF;
END
$starovka$;

UPDATE public.sovarka_locaux SET batiment='local-starovka-chasse'
 WHERE pays='soviet' AND ville='ville_a' AND batiment='locaux-starovka' AND piece='local_2';

UPDATE public.navigation_lieux_regles SET pieces='["local_1"]'::jsonb
 WHERE pays='soviet' AND ville='ville_a' AND batiment='locaux-starovka';
INSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership)
SELECT 'soviet','ville_a','local-starovka-chasse','["local_2"]'::jsonb,false,NULL
 WHERE NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_a' AND batiment='local-starovka-chasse');

DELETE FROM public.rue_sorties_batiments
 WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-magasin-chasse' AND building='locaux-starovka';
INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
VALUES ('soviet','ville_a','starovka-rue-magasin-chasse','local-starovka-chasse')
ON CONFLICT DO NOTHING;

DO $starovka$
BEGIN
  IF (SELECT count(*) FROM public.sovarka_locaux
      WHERE pays='soviet' AND ville='ville_a' AND batiment='local-starovka-chasse' AND piece='local_2') <> 1
     OR EXISTS (SELECT 1 FROM public.sovarka_locaux
      WHERE pays='soviet' AND ville='ville_a' AND batiment='locaux-starovka' AND piece='local_2')
  THEN RAISE EXCEPTION 'starovka_local_2_non_deplace'; END IF;
  IF (SELECT array_agg(noeud ORDER BY noeud) FROM public.rue_sorties_batiments
      WHERE country='soviet' AND city='ville_a' AND building='local-starovka-chasse')
     IS DISTINCT FROM ARRAY['starovka-rue-magasin-chasse']
  THEN RAISE EXCEPTION 'starovka_local_chasse_sortie'; END IF;
  IF (SELECT array_agg(noeud ORDER BY noeud) FROM public.rue_sorties_batiments
      WHERE country='soviet' AND city='ville_a' AND building='locaux-starovka')
     IS DISTINCT FROM ARRAY['starovka-rue-blizzard']
  THEN RAISE EXCEPTION 'starovka_local_1_sortie'; END IF;
END
$starovka$;
COMMIT;
