-- Starovka (Fred, 15/11/2026) : depuis la rue des logements collectifs, le bâtiment de la
-- Compagnie Nationale du Pétrole et les foreuses (à gauche) mènent au champ de pétrole
-- (zone-production). Seulement un accès de plus ; ni bâtiment, ni pièce, ni ordre nouveau.
-- La sortie ramène à la rue d'entrée (rue_sortie_batiment_lire préfère current_street).
BEGIN;

DO $starovka$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-logements-collectifs')
  THEN RAISE EXCEPTION 'starovka_rue_logements_absente'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='ville_a' AND batiment='zone-production')
  THEN RAISE EXCEPTION 'starovka_champ_petrole_sans_pieces'; END IF;
END
$starovka$;

INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
VALUES ('soviet','ville_a','starovka-rue-logements-collectifs','zone-production')
ON CONFLICT DO NOTHING;

DO $starovka$
BEGIN
  IF (SELECT count(*) FROM public.rue_sorties_batiments
      WHERE country='soviet' AND city='ville_a' AND building='zone-production'
        AND noeud IN ('starovka-rue-logements-collectifs','starovka-rue-petrole-ferme')) <> 2
  THEN RAISE EXCEPTION 'starovka_acces_champ_petrole_incomplets'; END IF;
END
$starovka$;
COMMIT;
