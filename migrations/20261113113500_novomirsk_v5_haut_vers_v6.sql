-- Novomirsk, vue 5 (Centre d'affaires / Grand Hôtel de Sovarka) : la flèche du haut mène au
-- quartier des Ambassades et à l'Armurerie (V6), et non plus à la rue du notaire (V3, toujours
-- accessible depuis la V4) ; retour de V6 vers V5 par la flèche du bas (Fred, 13/11/2026).
-- Le serveur suit l'écran. État visé (voisins symétriques) :
--   V5 : V4, V6   — liens : toutDroit V6, droite V4
--   V6 : V5, V7   — liens : toutDroit V7, arriere V5
--   V3 : sans V5 (V5 ne mène plus à V3)
-- Remplace la migration 20261112120000 (V5 sans rue à gauche), dont la V6 avait déjà retrouvé V5
-- en production sans la réciproque (anomalie retour_absent constatée le 13/11).
BEGIN;
UPDATE public.rue_noeuds_serveur
   SET voisins = ARRAY['novomirsk-vue-4','novomirsk-vue-6'],
       directions = jsonb_set(coalesce(directions,'{}'::jsonb), '{liens}',
         '{"toutDroit":"novomirsk-vue-6","droite":"novomirsk-vue-4"}'::jsonb)
 WHERE country = 'soviet' AND noeud = 'novomirsk-vue-5';
UPDATE public.rue_noeuds_serveur
   SET voisins = ARRAY['novomirsk-vue-5','novomirsk-vue-7'],
       directions = jsonb_set(coalesce(directions,'{}'::jsonb), '{liens}',
         '{"toutDroit":"novomirsk-vue-7","arriere":"novomirsk-vue-5"}'::jsonb)
 WHERE country = 'soviet' AND noeud = 'novomirsk-vue-6';
UPDATE public.rue_noeuds_serveur
   SET voisins = array_remove(voisins, 'novomirsk-vue-5')
 WHERE country = 'soviet' AND noeud = 'novomirsk-vue-3';
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND noeud='novomirsk-vue-5'
                 AND voisins @> ARRAY['novomirsk-vue-4','novomirsk-vue-6'] AND NOT 'novomirsk-vue-3' = ANY(voisins)
                 AND directions->'liens'->>'toutDroit' = 'novomirsk-vue-6')
     OR NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND noeud='novomirsk-vue-6'
                 AND voisins @> ARRAY['novomirsk-vue-5','novomirsk-vue-7'] AND directions->'liens'->>'arriere' = 'novomirsk-vue-5')
     OR EXISTS (SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND noeud='novomirsk-vue-3'
                 AND 'novomirsk-vue-5' = ANY(voisins))
     OR NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND noeud='novomirsk-vue-4'
                 AND 'novomirsk-vue-5' = ANY(voisins))
     OR NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND noeud='novomirsk-vue-7'
                 AND 'novomirsk-vue-6' = ANY(voisins)) THEN
    RAISE EXCEPTION 'novomirsk_v5_haut_vers_v6 : contrôle en échec';
  END IF;
END $$;
COMMIT;
