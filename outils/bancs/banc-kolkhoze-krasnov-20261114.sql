-- Banc annulé (exception finale) du kolkhoze de Krasnov : jouer dans une transaction après la migration 20261114004000.
-- Attendu : don de 4 = +6 (plafond), don suivant +0, prise de 3 puis refus quota_caisse, légumes 5, vaches 2 laitages, œufs 2, alcool refusé.
BEGIN;

DO $banc$
DECLARE a text; r1 jsonb; r2 jsonb; r3 jsonb; r4 jsonb; t1 jsonb; t2 jsonb; t3 jsonb; pop0 numeric; pop1 numeric;
BEGIN
  SELECT name INTO a FROM public.personnages_donnees WHERE country = 'soviet' ORDER BY updated_at DESC NULLS LAST LIMIT 1;
  IF a IS NULL THEN SELECT name INTO a FROM public.personnages_donnees ORDER BY updated_at DESC NULLS LAST LIMIT 1; END IF;
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'ville_b', current_building = 'ferme-krasnov', current_room = 'cour_ferme',
    inventory = '[{"name":"Bois","icon":"ti-trees","stackable":true,"stackKey":"bois","qty":10,"desc":"banc"}]'::jsonb, pa = 20,
    resources = jsonb_set(coalesce(resources,'{}'::jsonb) - 'popBase', '{pop}', '50') WHERE name = a;
  r1 := public.kolkhoze_caisse_donner_interne(a, 'bois', 4);
  r2 := public.kolkhoze_caisse_donner_interne(a, 'bois', 1);
  r3 := public.kolkhoze_caisse_prendre_interne(a, 'bois', 3);
  r4 := public.kolkhoze_caisse_prendre_interne(a, 'bois', 3);
  t1 := public.sovarka_ferme_travailler_interne(a, 'legumes');
  t2 := public.sovarka_ferme_travailler_interne(a, 'vaches');
  t3 := public.sovarka_ferme_travailler_interne(a, 'oeufs');
  SELECT (resources->>'pop')::numeric INTO pop1 FROM public.personnages_donnees WHERE name = a;
  RAISE EXCEPTION 'BANC acteur=% | don4 ok=% gain=% | don1 gain=% | prendre3 ok=% restant=% | prendre3 bis=% | legumes=% pa=% | vaches=% | oeufs=% | pop=% | refus_matiere=%',
    a, r1->>'ok', r1->>'gain_pop', r2->>'gain_pop', r3->>'ok', r3->>'pris_restant', r4->>'raison',
    t1->'produits', t1->>'pa', t2->'produits', t3->'produits', pop1, public.kolkhoze_caisse_donner_interne(a, 'alcool', 1)->>'raison';
END $banc$;
ROLLBACK;
