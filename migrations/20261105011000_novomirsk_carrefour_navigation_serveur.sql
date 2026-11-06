-- Novomirsk : remettre la géographie serveur en accord avec les flèches du carrefour V5.
-- Correctif ciblé : ni PJ, ni caisses, ni autres villes modifiés.
DO $novomirsk$
BEGIN
  IF (SELECT count(*) FROM public.rue_noeuds_serveur
      WHERE country='soviet' AND city='capitale'
        AND noeud IN ('novomirsk-vue-3','novomirsk-vue-4','novomirsk-vue-5','novomirsk-vue-6')) <> 4
  THEN RAISE EXCEPTION 'novomirsk_noeuds_manquants'; END IF;
  -- Le serveur applique les voisins à la validation transactionnelle du déplacement.
  UPDATE public.rue_noeuds_serveur
     SET voisins = ARRAY['novomirsk-vue-3','novomirsk-vue-5','novomirsk-vue-15']::text[],
         directions = jsonb_build_object(
           'liens',jsonb_build_object('toutDroit','novomirsk-vue-3','gauche','novomirsk-vue-5','droite','novomirsk-vue-15'),
           'parArrivee','{}'::jsonb)
   WHERE country='soviet' AND city='capitale' AND noeud='novomirsk-vue-4';

  UPDATE public.rue_noeuds_serveur
     SET voisins = ARRAY['novomirsk-vue-3','novomirsk-vue-4','novomirsk-vue-6']::text[],
         directions = jsonb_build_object(
           'liens',jsonb_build_object('toutDroit','novomirsk-vue-3','gauche','novomirsk-vue-6','droite','novomirsk-vue-4'),
           'parArrivee','{}'::jsonb)
   WHERE country='soviet' AND city='capitale' AND noeud='novomirsk-vue-5';

  -- V3 connaît les deux carrefours qui y mènent, tout en conservant ses deux flèches visibles.
  UPDATE public.rue_noeuds_serveur
     SET voisins = ARRAY['novomirsk-vue-2','novomirsk-vue-4','novomirsk-vue-5']::text[]
   WHERE country='soviet' AND city='capitale' AND noeud='novomirsk-vue-3';

  IF NOT EXISTS (
    SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='capitale' AND noeud='novomirsk-vue-5'
      AND 'novomirsk-vue-3'=ANY(voisins)
      AND directions->'liens'->>'toutDroit'='novomirsk-vue-3'
      AND directions->'liens'->>'gauche'='novomirsk-vue-6'
      AND directions->'liens'->>'droite'='novomirsk-vue-4'
  ) THEN RAISE EXCEPTION 'novomirsk_carrefour_non_raccorde'; END IF;
END $novomirsk$;