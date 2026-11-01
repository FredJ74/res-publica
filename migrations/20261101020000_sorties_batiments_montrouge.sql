-- Sorties de bâtiment de Montrouge (Claude, 01/11/2026). Indépendante de l'écran.
--
-- Constat (visite PJ du 01/11, PR #304) : un PJ ne pouvait pas sortir d'un terrain de Montrouge,
-- rue_sortie_batiment_lire répondant « sortie_non_referencee ». ChatGPT a inséré en urgence les six
-- terrains en production (vers montrouge-vue-11) ; cette migration les pérennise (sans effet s'ils
-- sont déjà là). Comparaison de WORLD.republic.ville_b.buildings avec rue_sorties_batiments : quatre
-- autres bâtiments sans sortie, absents des vues de rue, donc même blocage s'ils sont atteints par le
-- plan. Rattachés à la vue la plus proche (choix technique) : siège syndical, usine principale et zone
-- de production à montrouge-vue-2 (voisins du commissariat sur le plan, quartier de la raffinerie) ;
-- tribunal municipal à montrouge-vue-7 (Hôtel de Ville). PSM : aucun bâtiment sans sortie.
BEGIN;

INSERT INTO public.rue_sorties_batiments (country, city, building, noeud) VALUES
  ('republic','ville_b','terrain-a-batir-6','montrouge-vue-11'),
  ('republic','ville_b','terrain-a-batir-montrouge-3','montrouge-vue-11'),
  ('republic','ville_b','terrain-a-batir-montrouge-7','montrouge-vue-11'),
  ('republic','ville_b','terrain-a-batir-montrouge-8','montrouge-vue-11'),
  ('republic','ville_b','terrain-a-batir-montrouge-9','montrouge-vue-11'),
  ('republic','ville_b','terrain-a-batir-montrouge-12','montrouge-vue-11'),
  ('republic','ville_b','siege-syndical','montrouge-vue-2'),
  ('republic','ville_b','usine-principale','montrouge-vue-2'),
  ('republic','ville_b','zone-production','montrouge-vue-2'),
  ('republic','ville_b','tribunal-local','montrouge-vue-7')
ON CONFLICT DO NOTHING;

DO $$
DECLARE manquants text;
BEGIN
  SELECT string_agg(b, ', ') INTO manquants
  FROM unnest(ARRAY['terrain-a-batir-6','terrain-a-batir-montrouge-3','terrain-a-batir-montrouge-7',
    'terrain-a-batir-montrouge-8','terrain-a-batir-montrouge-9','terrain-a-batir-montrouge-12',
    'siege-syndical','usine-principale','zone-production','tribunal-local']) b
  WHERE NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments s
    JOIN public.rue_noeuds_serveur n ON n.country=s.country AND n.city=s.city AND n.noeud=s.noeud
    WHERE s.country='republic' AND s.city='ville_b' AND s.building=b);
  IF manquants IS NOT NULL THEN RAISE EXCEPTION 'sorties_montrouge_manquantes: %', manquants; END IF;
END $$;

COMMIT;
