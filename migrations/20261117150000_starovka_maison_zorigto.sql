-- Starovka, vue des maisons et du parc à rennes (Fred, 17/11/2026) : le chalet rustique voisin de celui de Dolgor
-- devient une maison d'hospitalité, celle de Zorigto Badmaev, foreur de la Compagnie Nationale du Pétrole (nom
-- proposé par Claude). Même mécanique que les autres maisons de Sovarka (hospitalité contre service, trinquer,
-- dormir) : sovarka_maison_interne reçoit la maison ; hotel_nuitee_consommation_interne la reconnaît déjà par
-- sovarka_maison_interne (patch du 14/11).
BEGIN;

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'ville_a', 'maison-starovka-ouvrier', '["piece_maison"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES
  ('soviet', 'ville_a', 'starovka-maisons-ferme', 'maison-starovka-ouvrier')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.sovarka_maison_interne(p_ville text, p_batiment text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_ville = 'ville_a' AND p_batiment = 'maison-starovka' THEN jsonb_build_object('id', 'maison-starovka', 'habitant', 'Dolgor Tsybikova',
      'besoins', '[{"cle":"bois","qte":3,"label":"3 bois"},{"cle":"poisson","qte":2,"label":"2 poissons"},{"cle":"carburant","qte":1,"label":"1 bidon de carburant"},{"cle":"viande","qte":2,"label":"2 viandes"},{"cle":"vodka","qte":1,"label":"1 bouteille de vodka"}]'::jsonb)
    WHEN p_ville = 'ville_a' AND p_batiment = 'maison-starovka-ouvrier' THEN jsonb_build_object('id', 'maison-starovka-ouvrier', 'habitant', 'Zorigto Badmaev',
      'besoins', '[{"cle":"carburant","qte":1,"label":"1 bidon de carburant"},{"cle":"bois","qte":3,"label":"3 bois"},{"cle":"poisson","qte":2,"label":"2 poissons"},{"cle":"alcool","qte":1,"label":"1 alcool"}]'::jsonb)
    WHEN p_ville = 'ville_b' AND p_batiment = 'maison-krasnov' THEN jsonb_build_object('id', 'maison-krasnov', 'habitant', 'Stepan Kouznetsov',
      'besoins', '[{"cle":"bois","qte":3,"label":"3 bois"},{"cle":"fruits_legumes","qte":5,"label":"5 fruits et légumes"},{"cle":"oeufs","qte":2,"label":"2 œufs"},{"cle":"vodka","qte":1,"label":"1 bouteille de vodka"}]'::jsonb)
    WHEN p_ville = 'ville_b' AND p_batiment = 'maison-krasnov-bureaux' THEN jsonb_build_object('id', 'maison-krasnov-bureaux', 'habitant', 'Antonina Merkoulova',
      'besoins', '[{"cle":"textile","qte":2,"label":"2 textiles"},{"cle":"fruits_legumes","qte":4,"label":"4 fruits et légumes"},{"cle":"bois","qte":3,"label":"3 bois"},{"cle":"laitages","qte":2,"label":"2 laitages"}]'::jsonb)
    WHEN p_ville = 'ville_b' AND p_batiment = 'maison-krasnov-rouge' THEN jsonb_build_object('id', 'maison-krasnov-rouge', 'habitant', 'Matveï Rybakov',
      'besoins', '[{"cle":"bois","qte":4,"label":"4 bois"},{"cle":"viande","qte":2,"label":"2 viandes"},{"cle":"alcool","qte":1,"label":"1 alcool"},{"cle":"carburant","qte":1,"label":"1 bidon de carburant"}]'::jsonb)
    WHEN p_ville = 'ville_b' AND p_batiment = 'maison-krasnov-bleue' THEN jsonb_build_object('id', 'maison-krasnov-bleue', 'habitant', 'Praskovia Pakhomova',
      'besoins', '[{"cle":"plantes","qte":3,"label":"3 plantes"},{"cle":"cereales","qte":3,"label":"3 céréales"},{"cle":"bois","qte":3,"label":"3 bois"},{"cle":"laitages","qte":2,"label":"2 laitages"}]'::jsonb)
    WHEN p_ville = 'ville_b' AND p_batiment = 'maison-krasnov-eglise' THEN jsonb_build_object('id', 'maison-krasnov-eglise', 'habitant', 'Kouzma Lapchine',
      'besoins', '[{"cle":"bois","qte":3,"label":"3 bois"},{"cle":"cereales","qte":2,"label":"2 céréales"},{"cle":"alcool","qte":1,"label":"1 alcool"},{"cle":"fruits_legumes","qte":4,"label":"4 fruits et légumes"}]'::jsonb)
    WHEN p_ville = 'ville_b' AND p_batiment = 'maison-krasnov-terrains' THEN jsonb_build_object('id', 'maison-krasnov-terrains', 'habitant', 'Ignat Lykov',
      'besoins', '[{"cle":"viande","qte":2,"label":"2 viandes"},{"cle":"bois","qte":3,"label":"3 bois"},{"cle":"carburant","qte":1,"label":"1 bidon de carburant"},{"cle":"poisson","qte":2,"label":"2 poissons"}]'::jsonb)
  END;
$$;

DO $maison$
BEGIN
  IF position('sovarka_maison_interne' IN pg_get_functiondef('public.hotel_nuitee_consommation_interne(text)'::regprocedure)) = 0
  THEN RAISE EXCEPTION 'hotel_nuitee_consommation_interne : maisons de Sovarka non reconnues'; END IF;
  IF public.sovarka_maison_interne('ville_a', 'maison-starovka-ouvrier')->>'habitant' IS DISTINCT FROM 'Zorigto Badmaev'
     OR public.sovarka_maison_interne('ville_a', 'maison-starovka')->>'habitant' IS DISTINCT FROM 'Dolgor Tsybikova'
  THEN RAISE EXCEPTION 'sovarka_maison_interne : maisons de Starovka'; END IF;
  IF (SELECT array_agg(building ORDER BY building) FROM public.rue_sorties_batiments
      WHERE country = 'soviet' AND city = 'ville_a' AND noeud = 'starovka-maisons-ferme')
     IS DISTINCT FROM ARRAY['ferme-starovka', 'maison-starovka', 'maison-starovka-ouvrier']
  THEN RAISE EXCEPTION 'starovka_maisons_ferme_sorties'; END IF;
END $maison$;

COMMIT;
