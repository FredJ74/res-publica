-- Krasnov : place de l'Ours et immeuble à écriteaux face à la mairie.
-- L'immeuble possède uniquement un hall tant que ses appartements ne sont pas illustrés.
-- Aucune création de bail ni de logement social à cette étape.
BEGIN;
DO $$
DECLARE v jsonb;
BEGIN
 SELECT directions->'liens' INTO v FROM public.rue_noeuds_serveur
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-mairie-place' FOR UPDATE;
 IF v IS NULL THEN RAISE EXCEPTION 'Rue de la mairie de Krasnov absente'; END IF;
 IF coalesce(v->>'gauche','') NOT IN ('','krasnov-place-ours') THEN
   RAISE EXCEPTION 'La flèche gauche est déjà affectée'; END IF;
 IF v->>'arriere'<>'krasnov-rue-immeubles-centre-commercial'
    OR v->>'toutDroit'<>'krasnov-rue-tabac-bar'
 THEN RAISE EXCEPTION 'Les sorties historiques de Krasnov ont changé'; END IF;

 INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
 VALUES ('soviet','ville_b','krasnov-place-ours',
 ARRAY['krasnov-rue-mairie-place']::text[],
 '{"liens":{"arriere":"krasnov-rue-mairie-place"},"parArrivee":{}}'::jsonb)
 ON CONFLICT (country,city,noeud) DO NOTHING;

 UPDATE public.rue_noeuds_serveur
 SET voisins=CASE WHEN voisins @> ARRAY['krasnov-place-ours']::text[] THEN voisins
                  ELSE array_append(voisins,'krasnov-place-ours') END,
     directions=jsonb_set(directions,'{liens,gauche}','"krasnov-place-ours"'::jsonb,true)
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-mairie-place';

 INSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership)
 VALUES ('soviet','ville_b','logements-krasnov-place-ours','["hall"]'::jsonb,false,NULL)
 ON CONFLICT(pays,ville,batiment) DO NOTHING;

 INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
 VALUES ('soviet','ville_b','krasnov-rue-mairie-place','logements-krasnov-place-ours'),
        ('soviet','ville_b','krasnov-place-ours','mairie')
 ON CONFLICT DO NOTHING;

 IF NOT EXISTS (
   SELECT 1 FROM public.rue_noeuds_serveur
   WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-mairie-place'
      AND voisins @> ARRAY['krasnov-place-ours']::text[]
      AND directions->'liens'->>'gauche'='krasnov-place-ours'
 ) OR NOT EXISTS (
   SELECT 1 FROM public.rue_noeuds_serveur
   WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-place-ours'
      AND voisins=ARRAY['krasnov-rue-mairie-place']::text[]
      AND directions->'liens'->>'arriere'='krasnov-rue-mairie-place'
 ) OR NOT EXISTS (
   SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_b' AND batiment='logements-krasnov-place-ours'
      AND pieces='["hall"]'::jsonb AND NOT ferme
 ) OR NOT EXISTS (
   SELECT 1 FROM public.rue_sorties_batiments
   WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-mairie-place'
      AND building='logements-krasnov-place-ours'
 ) OR NOT EXISTS (
   SELECT 1 FROM public.rue_sorties_batiments
   WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-place-ours'
      AND building='mairie'
 ) THEN RAISE EXCEPTION 'Raccordement place de l’Ours ou immeuble incomplet'; END IF;
END $$;
COMMIT;
