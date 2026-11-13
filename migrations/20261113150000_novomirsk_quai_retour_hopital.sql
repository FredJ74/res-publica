-- Novomirsk, quai du marché (V16) : flèche de droite vers la rue de l'hôpital (V15) (Fred, 13/11/2026).
-- Le serveur suit l'écran ; corrige l'anomalie retour_absent V15→V16 constatée le 13/11.
--   V16 : voisins V14, V17, V15 — liens : arriere V14, toutDroit V17, droite V15
BEGIN;
UPDATE public.rue_noeuds_serveur
   SET voisins = CASE WHEN 'novomirsk-vue-15' = ANY(voisins) THEN voisins ELSE voisins || 'novomirsk-vue-15'::text END,
       directions = jsonb_set(coalesce(directions,'{}'::jsonb), '{liens}',
         coalesce(directions->'liens','{}'::jsonb) || '{"droite":"novomirsk-vue-15"}'::jsonb)
 WHERE country = 'soviet' AND noeud = 'novomirsk-vue-16';
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND noeud='novomirsk-vue-16'
                 AND voisins @> ARRAY['novomirsk-vue-14','novomirsk-vue-15','novomirsk-vue-17']
                 AND directions->'liens'->>'droite' = 'novomirsk-vue-15')
     OR NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND noeud='novomirsk-vue-15'
                 AND 'novomirsk-vue-16' = ANY(voisins)) THEN
    RAISE EXCEPTION 'novomirsk_quai_retour_hopital : contrôle en échec';
  END IF;
END $$;
COMMIT;
