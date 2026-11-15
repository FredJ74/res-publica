-- Krasnov : les maisonnettes en bois des vues de rue deviennent des maisons d'hospitalité (Fred, 14/11/2026 :
-- « un habitant chacune », comme la maison de Stepan, migration 20261110094500). Habitants proposés par Claude,
-- à valider par Fred.
--   maison-krasnov-bureaux  : Antonina Merkoulova (maison bleue en face du centre d'affaires, krasnov-rue-bureaux)
--   maison-krasnov-rouge    : Matveï Rybakov      (maison rouge, krasnov-rue-descendante)
--   maison-krasnov-bleue    : Praskovia Pakhomova (maison bleue, krasnov-rue-descendante)
--   maison-krasnov-eglise   : Kouzma Lapchine     (maison brune près de l'église, krasnov-rue-eglise)
--   maison-krasnov-terrains : Ignat Lykov         (maison au bord des terrains, krasnov-rue-terrains)
-- 1. Bâtiments au référentiel de navigation et sorties de rue.
-- 2. sovarka_maison_interne : les cinq maisons (besoins tirés des matières existantes) ; Stepan inchangé, sauf le
--    libellé des œufs aligné sur la quantité réelle (2, depuis 20261114004000).
-- 3. hotel_nuitee_consommation_interne : toute maison de Sovarka vaut une chambre (patch en place, ancrage vérifié).
BEGIN;  -- enveloppe annulée (15/11/2026) : rien de ce banc ne peut rester écrit

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'ville_b', 'maison-krasnov-bureaux', '["piece_maison"]'::jsonb, false, NULL),
  ('soviet', 'ville_b', 'maison-krasnov-rouge', '["piece_maison"]'::jsonb, false, NULL),
  ('soviet', 'ville_b', 'maison-krasnov-bleue', '["piece_maison"]'::jsonb, false, NULL),
  ('soviet', 'ville_b', 'maison-krasnov-eglise', '["piece_maison"]'::jsonb, false, NULL),
  ('soviet', 'ville_b', 'maison-krasnov-terrains', '["piece_maison"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES
  ('soviet', 'ville_b', 'krasnov-rue-bureaux', 'maison-krasnov-bureaux'),
  ('soviet', 'ville_b', 'krasnov-rue-descendante', 'maison-krasnov-rouge'),
  ('soviet', 'ville_b', 'krasnov-rue-descendante', 'maison-krasnov-bleue'),
  ('soviet', 'ville_b', 'krasnov-rue-eglise', 'maison-krasnov-eglise'),
  ('soviet', 'ville_b', 'krasnov-rue-terrains', 'maison-krasnov-terrains')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.sovarka_maison_interne(p_ville text, p_batiment text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_ville = 'ville_a' AND p_batiment = 'maison-starovka' THEN jsonb_build_object('id', 'maison-starovka', 'habitant', 'Dolgor Tsybikova',
      'besoins', '[{"cle":"bois","qte":3,"label":"3 bois"},{"cle":"poisson","qte":2,"label":"2 poissons"},{"cle":"carburant","qte":1,"label":"1 bidon de carburant"},{"cle":"viande","qte":2,"label":"2 viandes"},{"cle":"vodka","qte":1,"label":"1 bouteille de vodka"}]'::jsonb)
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

DO $maisons$
DECLARE d text; avant text; apres text;
BEGIN
  d := pg_get_functiondef('public.hotel_nuitee_consommation_interne(text)'::regprocedure);
  IF position('sovarka_maison_interne' IN d) = 0 THEN
    avant := 'p.current_building IN (''maison-starovka'',''maison-krasnov'')';
    apres := '(p.country=''soviet'' AND public.sovarka_maison_interne(p.current_city,p.current_building) IS NOT NULL)';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'hotel_nuitee_consommation_interne : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
  IF (SELECT count(*) FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city = 'ville_b' AND building LIKE 'maison-krasnov-%') <> 5
  THEN RAISE EXCEPTION 'Krasnov : sorties des maisonnettes incompletes'; END IF;
END $maisons$;


DO $t$ DECLARE r text := ''; m text;
BEGIN
  FOREACH m IN ARRAY ARRAY['maison-krasnov','maison-krasnov-bureaux','maison-krasnov-rouge','maison-krasnov-bleue','maison-krasnov-eglise','maison-krasnov-terrains'] LOOP
    r := r || m || '=' || coalesce(public.sovarka_maison_service_interne(public.sovarka_maison_interne('ville_b', m), current_date)->>'label','NUL') || '; ';
  END LOOP;
  r := r || 'patch=' || (position('sovarka_maison_interne' IN pg_get_functiondef('public.hotel_nuitee_consommation_interne(text)'::regprocedure))>0)::text;
  r := r || ' nav=' || (SELECT count(*) FROM public.navigation_lieux_regles WHERE batiment LIKE 'maison-krasnov-%')::text;
  RAISE EXCEPTION 'BANC %', r;
END $t$;
ROLLBACK;
