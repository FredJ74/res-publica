-- Starovka (Fred, 15/11/2026) : après lycée/commissariat, hôpital,
-- puis tribunal + centre artisanal, puis poste de vigilance/centre d'affaires.
-- Uniquement des rues et des accès existants ; ni bâtiments ni ordres nouveaux.
BEGIN;

DO $starovka$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
      AND noeud='starovka-rue-lycee-commissariat'
      AND directions->'liens'->>'gauche' IN ('starovka-rue-bureaux-caserne','starovka-rue-hopital')
  ) THEN RAISE EXCEPTION 'starovka_lycee_lien_initial_inattendu'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a'
      AND noeud='starovka-rue-bureaux-caserne'
      AND directions->'liens'->>'droite' IN ('starovka-rue-lycee-commissariat','starovka-rue-tribunal-artisanal')
      AND directions->'liens'->>'toutDroit'='starovka-rue-magasin-chasse'
  ) THEN RAISE EXCEPTION 'starovka_bureaux_lien_initial_inattendu'; END IF;
  IF (SELECT count(*) FROM public.navigation_lieux_regles
      WHERE pays='soviet' AND ville='ville_a'
        AND batiment IN ('dispensaire-public-v','tribunal-local','centre-artisanal')) <> 3
  THEN RAISE EXCEPTION 'starovka_batiment_sans_pieces'; END IF;
END
$starovka$;

INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
VALUES
 ('soviet','ville_a','starovka-rue-hopital',
  ARRAY['starovka-rue-lycee-commissariat','starovka-rue-tribunal-artisanal']::text[],
  '{"liens":{"droite":"starovka-rue-lycee-commissariat","gauche":"starovka-rue-tribunal-artisanal"},"parArrivee":{}}'::jsonb),
 ('soviet','ville_a','starovka-rue-tribunal-artisanal',
  ARRAY['starovka-rue-hopital','starovka-rue-bureaux-caserne']::text[],
  '{"liens":{"droite":"starovka-rue-hopital","gauche":"starovka-rue-bureaux-caserne"},"parArrivee":{}}'::jsonb)
ON CONFLICT(country,city,noeud) DO UPDATE
 SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

UPDATE public.rue_noeuds_serveur
SET voisins=array_replace(voisins,'starovka-rue-bureaux-caserne','starovka-rue-hopital'),
    directions=jsonb_set(directions,'{liens,gauche}','"starovka-rue-hopital"'::jsonb)
WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-lycee-commissariat';

UPDATE public.rue_noeuds_serveur
SET voisins=array_replace(voisins,'starovka-rue-lycee-commissariat','starovka-rue-tribunal-artisanal'),
    directions=jsonb_set(directions,'{liens,droite}','"starovka-rue-tribunal-artisanal"'::jsonb)
WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-bureaux-caserne';

INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
VALUES
 ('soviet','ville_a','starovka-rue-hopital','dispensaire-public-v'),
 ('soviet','ville_a','starovka-rue-tribunal-artisanal','tribunal-local'),
 ('soviet','ville_a','starovka-rue-tribunal-artisanal','centre-artisanal')
ON CONFLICT DO NOTHING;

DO $starovka$
BEGIN
 IF (SELECT count(*) FROM public.rue_noeuds_serveur
     WHERE country='soviet' AND city='ville_a'
       AND noeud IN ('starovka-rue-lycee-commissariat','starovka-rue-hopital',
        'starovka-rue-tribunal-artisanal','starovka-rue-bureaux-caserne')
       AND (noeud='starovka-rue-lycee-commissariat' AND directions->'liens'->>'gauche'='starovka-rue-hopital'
        OR noeud='starovka-rue-hopital' AND directions->'liens'->>'gauche'='starovka-rue-tribunal-artisanal'
        OR noeud='starovka-rue-tribunal-artisanal' AND directions->'liens'->>'gauche'='starovka-rue-bureaux-caserne'
        OR noeud='starovka-rue-bureaux-caserne' AND directions->'liens'->>'droite'='starovka-rue-tribunal-artisanal')) <> 4
 THEN RAISE EXCEPTION 'starovka_parcours_incomplet'; END IF;
 IF (SELECT count(*) FROM public.rue_sorties_batiments
     WHERE country='soviet' AND city='ville_a'
       AND (noeud='starovka-rue-hopital' AND building='dispensaire-public-v'
        OR noeud='starovka-rue-tribunal-artisanal' AND building IN ('tribunal-local','centre-artisanal'))) <> 3
 THEN RAISE EXCEPTION 'starovka_acces_batiments_incomplets'; END IF;
END $starovka$;
COMMIT;
