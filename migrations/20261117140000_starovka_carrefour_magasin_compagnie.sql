-- Starovka, carrefour pétrole/ferme (décisions de Fred, 17/11/2026, GAME-DESIGN-NOVOMIRSK.md « Tour de Starovka ») :
-- 1. À droite, le magasin du kolkhoze (magasin-kolkhoze-starovka, pièce « magasin », décor sans ordre).
-- 2. À gauche, le chalet-bureau de la Compagnie Nationale du Pétrole (compagnie-petrole-starovka, pièce
--    « bureau », décor sans ordre). La récolte se fait au champ de la vue précédente (champ-petrole-starovka)
--    ou depuis les foreuses des logements collectifs (zone-production, inchangé) ; recolte_effectuer ne
--    dépend que de la ville.
-- 3. La cour de la ferme (ferme-starovka, ordres inchangés) passe à la vue suivante (starovka-maisons-ferme).
BEGIN;

DO $starovka$
BEGIN
  IF (SELECT count(*) FROM public.rue_noeuds_serveur
      WHERE country='soviet' AND city='ville_a' AND noeud IN ('starovka-rue-petrole-ferme','starovka-maisons-ferme')) <> 2
  THEN RAISE EXCEPTION 'starovka_vues_carrefour_absentes'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments
    WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-logements-collectifs' AND building='zone-production')
  THEN RAISE EXCEPTION 'starovka_champ_logements_absent'; END IF;
END
$starovka$;

INSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership)
SELECT 'soviet','ville_a', b, p, false, NULL
  FROM (VALUES ('magasin-kolkhoze-starovka','["magasin"]'::jsonb),
               ('compagnie-petrole-starovka','["bureau"]'::jsonb)) AS v(b,p)
 WHERE NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles r
   WHERE r.pays='soviet' AND r.ville='ville_a' AND r.batiment=v.b);

DELETE FROM public.rue_sorties_batiments
 WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-petrole-ferme'
   AND building IN ('ferme-starovka','zone-production');
INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
VALUES ('soviet','ville_a','starovka-rue-petrole-ferme','magasin-kolkhoze-starovka'),
       ('soviet','ville_a','starovka-rue-petrole-ferme','compagnie-petrole-starovka'),
       ('soviet','ville_a','starovka-maisons-ferme','ferme-starovka')
ON CONFLICT DO NOTHING;

DO $starovka$
BEGIN
  IF (SELECT array_agg(building ORDER BY building) FROM public.rue_sorties_batiments
      WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-petrole-ferme')
     IS DISTINCT FROM ARRAY['compagnie-petrole-starovka','magasin-kolkhoze-starovka']
  THEN RAISE EXCEPTION 'starovka_carrefour_sorties'; END IF;
  IF (SELECT array_agg(noeud ORDER BY noeud) FROM public.rue_sorties_batiments
      WHERE country='soviet' AND city='ville_a' AND building='ferme-starovka')
     IS DISTINCT FROM ARRAY['starovka-maisons-ferme']
  THEN RAISE EXCEPTION 'starovka_ferme_sortie'; END IF;
  IF (SELECT array_agg(noeud ORDER BY noeud) FROM public.rue_sorties_batiments
      WHERE country='soviet' AND city='ville_a' AND building='zone-production')
     IS DISTINCT FROM ARRAY['starovka-rue-logements-collectifs']
  THEN RAISE EXCEPTION 'starovka_champ_compagnie_sortie'; END IF;
  IF (SELECT count(*) FROM public.navigation_lieux_regles
      WHERE pays='soviet' AND ville='ville_a' AND batiment IN ('magasin-kolkhoze-starovka','compagnie-petrole-starovka')) <> 2
  THEN RAISE EXCEPTION 'starovka_carrefour_regles'; END IF;
END
$starovka$;
COMMIT;
