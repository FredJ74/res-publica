-- Banc annulé : six terrains de PSM (migration 20261104191500). Rien ne reste.
BEGIN;
INSERT INTO public.terrains_referentiel(pays,ville,batiment,surface,prix_achat) VALUES
  ('republic','ville_a','terrain-a-batir-9',1650,19800),
  ('republic','ville_a','terrain-a-batir-10',2200,26400),
  ('republic','ville_a','terrain-a-batir-11',3100,37200),
  ('republic','ville_a','terrain-a-batir-psm-12',4200,50400),
  ('republic','ville_a','terrain-a-batir-psm-13',5500,66000)
ON CONFLICT(pays,ville,batiment) DO UPDATE SET surface=EXCLUDED.surface,prix_achat=EXCLUDED.prix_achat;

-- État des lots sans propriétaire : surface et valeur alignées (un lot déjà vendu n'est pas touché).
UPDATE public.terrains_etat e SET
  data=(e.data::jsonb || jsonb_build_object('surface',r.surface,'valeur_totale',r.prix_achat))::text,
  updated_at=now()
FROM public.terrains_referentiel r
WHERE r.pays='republic' AND r.ville='ville_a' AND r.batiment=e.building_id AND e.country='republic'
  AND e.building_id IN ('terrain-a-batir-9','terrain-a-batir-10','terrain-a-batir-11')
  AND e.proprietaire IS NULL;

INSERT INTO public.terrains_etat(id,country,building_id,proprietaire,data) VALUES
  ('republic_terrain-a-batir-psm-12','republic','terrain-a-batir-psm-12',NULL,'{"city": "ville_a", "surface": 4200, "valeur_totale": 50400, "constructionAutorisee": false}'),
  ('republic_terrain-a-batir-psm-13','republic','terrain-a-batir-psm-13',NULL,'{"city": "ville_a", "surface": 5500, "valeur_totale": 66000, "constructionAutorisee": false}')
ON CONFLICT(id) DO NOTHING;

INSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership) VALUES
  ('republic','ville_a','terrain-a-batir-psm-12','["terrain"]'::jsonb,false,NULL),
  ('republic','ville_a','terrain-a-batir-psm-13','["terrain"]'::jsonb,false,NULL)
ON CONFLICT(pays,ville,batiment) DO UPDATE SET pieces=EXCLUDED.pieces,ferme=EXCLUDED.ferme,membership=EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country,city,noeud,building) VALUES
  ('republic','ville_a','psm-terrains-vente','terrain-a-batir-psm-12'),
  ('republic','ville_a','psm-terrains-vente','terrain-a-batir-psm-13')
ON CONFLICT DO NOTHING;

INSERT INTO public.blocus_ordres_batiments(pays,ville,batiment,fn)
SELECT b.pays,b.ville,n.id,b.fn FROM public.blocus_ordres_batiments b
CROSS JOIN (VALUES ('terrain-a-batir-psm-12'),('terrain-a-batir-psm-13')) n(id)
WHERE b.pays='republic' AND b.ville='ville_a' AND b.batiment='terrain-a-batir-8'
  AND NOT EXISTS (SELECT 1 FROM public.blocus_ordres_batiments x WHERE x.pays=b.pays AND x.ville=b.ville AND x.batiment=n.id AND x.fn=b.fn);

-- Tarifs déclarés des nouveaux prix d'achat (payer_ordre refuse un triplet absent ; 26 400 existe déjà).
INSERT INTO public.ordres_couts(fn,pa,cost)
SELECT 'acheter_terrain',2,c FROM (VALUES (19800),(37200),(50400),(66000)) v(c)
WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn='acheter_terrain' AND o.pa=2 AND o.cost=v.c);

DO $$
DECLARE n8 int;
BEGIN
  SELECT count(*) INTO n8 FROM public.blocus_ordres_batiments WHERE pays='republic' AND ville='ville_a' AND batiment='terrain-a-batir-8';
  IF (SELECT count(*) FROM public.terrains_referentiel WHERE pays='republic' AND ville='ville_a' AND batiment LIKE 'terrain-a-batir-%') <> 6
     OR (SELECT count(*) FROM public.terrains_etat WHERE building_id IN ('terrain-a-batir-psm-12','terrain-a-batir-psm-13')) <> 2
     OR (SELECT count(*) FROM public.navigation_lieux_regles WHERE pays='republic' AND ville='ville_a' AND batiment LIKE 'terrain-a-batir-psm-%') <> 2
     OR (SELECT count(*) FROM public.rue_sorties_batiments WHERE country='republic' AND city='ville_a' AND noeud='psm-terrains-vente' AND building LIKE 'terrain-a-batir-%') <> 6
     OR (SELECT count(*) FROM public.ordres_couts WHERE fn='acheter_terrain' AND pa=2 AND cost IN (19800,26400,37200,50400,66000)) <> 5
     OR (SELECT count(*) FROM public.blocus_ordres_batiments WHERE pays='republic' AND ville='ville_a' AND batiment LIKE 'terrain-a-batir-psm-%') <> 2*n8 THEN
    RAISE EXCEPTION 'psm_six_terrains_incomplet';
  END IF;
END $$;
DO $$ BEGIN RAISE EXCEPTION 'BANC_VERT'; END $$;
ROLLBACK;
