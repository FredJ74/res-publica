-- Novomirsk, vue 5 (Centre d'affaires / Grand Hôtel de Sovarka) : la flèche gauche vers les
-- ambassades (V6) est retirée (Fred, 12/11/2026 : « elle n'a aucun sens »). Le serveur suit
-- l'écran : V5 n'a plus V6 pour voisin. V5 est un carrefour en T sans rue à gauche : le retour de V6
-- vers V5 disparaît aussi ; V6 reste reliée à V7 dans les deux sens.
BEGIN;
UPDATE public.rue_noeuds_serveur
   SET voisins = array_remove(voisins, 'novomirsk-vue-6'),
       directions = jsonb_set(directions, '{liens}', (directions->'liens') - 'gauche')
 WHERE country = 'soviet' AND noeud = 'novomirsk-vue-5';
UPDATE public.rue_noeuds_serveur
   SET voisins = array_remove(voisins, 'novomirsk-vue-5'),
       directions = jsonb_set(directions, '{liens}', (directions->'liens') - 'arriere')
 WHERE country = 'soviet' AND noeud = 'novomirsk-vue-6';
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.rue_noeuds_serveur WHERE noeud = 'novomirsk-vue-5'
             AND ('novomirsk-vue-6' = ANY(voisins) OR directions->'liens' ? 'gauche'))
     OR EXISTS (SELECT 1 FROM public.rue_noeuds_serveur WHERE noeud = 'novomirsk-vue-6'
             AND ('novomirsk-vue-5' = ANY(voisins) OR NOT 'novomirsk-vue-7' = ANY(voisins)))
     OR NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur WHERE noeud = 'novomirsk-vue-7' AND 'novomirsk-vue-6' = ANY(voisins)) THEN
    RAISE EXCEPTION 'novomirsk_v5_sans_fleche_gauche : contrôle en échec';
  END IF;
END $$;
COMMIT;
