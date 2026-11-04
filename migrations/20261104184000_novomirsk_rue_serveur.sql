-- Généré par outils/generateurs/rue-ville-serveur.cjs soviet capitale novomirsk-. Ne pas modifier à la main.
-- Couche rue de la ville au serveur : 18 nœuds, 17 entrées de bâtiment (16 bâtiments).
-- Idempotente ; ne déplace aucun personnage.
INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions) VALUES
  ('soviet','capitale','novomirsk-vue-1',ARRAY['novomirsk-vue-2','novomirsk-vue-10','novomirsk-vue-11']::text[],'{"liens":{"arriere":"novomirsk-vue-2","gauche":"novomirsk-vue-10","droite":"novomirsk-vue-11"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-2',ARRAY['novomirsk-vue-1','novomirsk-vue-3']::text[],'{"liens":{"toutDroit":"novomirsk-vue-1","arriere":"novomirsk-vue-3"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-3',ARRAY['novomirsk-vue-2','novomirsk-vue-4']::text[],'{"liens":{"toutDroit":"novomirsk-vue-2","arriere":"novomirsk-vue-4"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-4',ARRAY['novomirsk-vue-5','novomirsk-vue-15']::text[],'{"liens":{"gauche":"novomirsk-vue-5","droite":"novomirsk-vue-15"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-5',ARRAY['novomirsk-vue-4','novomirsk-vue-6']::text[],'{"liens":{"droite":"novomirsk-vue-4","toutDroit":"novomirsk-vue-6"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-6',ARRAY['novomirsk-vue-5','novomirsk-vue-7']::text[],'{"liens":{"arriere":"novomirsk-vue-5","toutDroit":"novomirsk-vue-7"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-7',ARRAY['novomirsk-vue-6','novomirsk-vue-18','novomirsk-vue-8']::text[],'{"liens":{"arriere":"novomirsk-vue-6","gauche":"novomirsk-vue-18","droite":"novomirsk-vue-8"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-8',ARRAY['novomirsk-vue-7','novomirsk-vue-9']::text[],'{"liens":{"droite":"novomirsk-vue-7","toutDroit":"novomirsk-vue-9"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-9',ARRAY['novomirsk-vue-8','novomirsk-vue-10']::text[],'{"liens":{"arriere":"novomirsk-vue-8","droite":"novomirsk-vue-10"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-10',ARRAY['novomirsk-vue-9','novomirsk-vue-1']::text[],'{"liens":{"toutDroit":"novomirsk-vue-9","arriere":"novomirsk-vue-1"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-11',ARRAY['novomirsk-vue-1','novomirsk-vue-12']::text[],'{"liens":{"arriere":"novomirsk-vue-1","toutDroit":"novomirsk-vue-12"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-12',ARRAY['novomirsk-vue-11','novomirsk-vue-13']::text[],'{"liens":{"arriere":"novomirsk-vue-11","droite":"novomirsk-vue-13"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-13',ARRAY['novomirsk-vue-12','novomirsk-vue-14']::text[],'{"liens":{"droite":"novomirsk-vue-12","toutDroit":"novomirsk-vue-14"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-14',ARRAY['novomirsk-vue-13','novomirsk-vue-15','novomirsk-vue-16']::text[],'{"liens":{"arriere":"novomirsk-vue-13","droite":"novomirsk-vue-15","toutDroit":"novomirsk-vue-16"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-15',ARRAY['novomirsk-vue-4','novomirsk-vue-14','novomirsk-vue-16']::text[],'{"liens":{"arriere":"novomirsk-vue-4","gauche":"novomirsk-vue-14","droite":"novomirsk-vue-16"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-16',ARRAY['novomirsk-vue-14','novomirsk-vue-17']::text[],'{"liens":{"arriere":"novomirsk-vue-14","toutDroit":"novomirsk-vue-17"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-17',ARRAY['novomirsk-vue-16','novomirsk-vue-18']::text[],'{"liens":{"arriere":"novomirsk-vue-16","toutDroit":"novomirsk-vue-18"},"parArrivee":{}}'::jsonb),
  ('soviet','capitale','novomirsk-vue-18',ARRAY['novomirsk-vue-17','novomirsk-vue-7']::text[],'{"liens":{"arriere":"novomirsk-vue-17","toutDroit":"novomirsk-vue-7"},"parArrivee":{}}'::jsonb)
ON CONFLICT(country,city,noeud) DO UPDATE SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

INSERT INTO public.rue_sorties_batiments(country,city,noeud,building) VALUES
  ('soviet','capitale','novomirsk-vue-1','palais-gouvernement'),
  ('soviet','capitale','novomirsk-vue-3','office-notarial'),
  ('soviet','capitale','novomirsk-vue-3','commissariat'),
  ('soviet','capitale','novomirsk-vue-4','hotel-republica'),
  ('soviet','capitale','novomirsk-vue-4','centre-commercial'),
  ('soviet','capitale','novomirsk-vue-5','centre-affaires'),
  ('soviet','capitale','novomirsk-vue-5','hotel-republica'),
  ('soviet','capitale','novomirsk-vue-6','armurerie'),
  ('soviet','capitale','novomirsk-vue-7','kolkhoze-spirituel'),
  ('soviet','capitale','novomirsk-vue-9','centre-multinodal-luthecia'),
  ('soviet','capitale','novomirsk-vue-10','tribunal'),
  ('soviet','capitale','novomirsk-vue-13','la-tribune'),
  ('soviet','capitale','novomirsk-vue-15','clinique-privee'),
  ('soviet','capitale','novomirsk-vue-15','dispensaire-public'),
  ('soviet','capitale','novomirsk-vue-16','marche'),
  ('soviet','capitale','novomirsk-vue-17','stade'),
  ('soviet','capitale','novomirsk-vue-17','centre-artisanal')
ON CONFLICT DO NOTHING;

DO $$
DECLARE manquants text;
BEGIN
  SELECT string_agg(b, ', ') INTO manquants FROM unnest(ARRAY['palais-gouvernement','office-notarial','commissariat','hotel-republica','centre-commercial','centre-affaires','armurerie','kolkhoze-spirituel','centre-multinodal-luthecia','tribunal','la-tribune','clinique-privee','dispensaire-public','marche','stade','centre-artisanal']::text[]) b
  WHERE NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles l WHERE l.pays='soviet' AND l.ville='capitale' AND l.batiment=b);
  IF manquants IS NOT NULL THEN RAISE EXCEPTION 'batiments_sans_regle_navigation: %', manquants; END IF;
  IF (SELECT count(*) FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='capitale' AND noeud LIKE 'novomirsk-%') <> 18 THEN
    RAISE EXCEPTION 'noeuds_incomplets'; END IF;
END $$;
