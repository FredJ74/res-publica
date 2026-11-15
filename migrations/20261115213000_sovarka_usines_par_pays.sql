-- Usines d'État de Sovarka par pays (décisions de Fred, 15/11/2026 au soir ; GAME-DESIGN-NOVOMIRSK.md,
-- « Production et logistique de Sovarka »). Chaque pays a trois usines, une par ville : en Sovarka,
-- Pharmanov (Novomirsk), la distillerie (Krasnov) et la Raffinerie d'État du Grand Nord (Starovka).
-- Les chaînes et les directeurs de la Républia étaient indexés sans pays : une raffinerie de Sovarka
-- aurait écrit dans l'état de Montrouge. Deux tables par pays, lues avant les tables historiques
-- (la Républia ne change pas : elle n'a aucune ligne dans ces tables).

CREATE TABLE IF NOT EXISTS public.chaines_production_pays (
  pays text NOT NULL, produit text NOT NULL, ville text NOT NULL, building_id text NOT NULL,
  matiere text NOT NULL, salaire_pa numeric NOT NULL, rang integer NOT NULL DEFAULT 0,
  PRIMARY KEY (pays, produit));
CREATE TABLE IF NOT EXISTS public.directeurs_usine_pays (
  pays text NOT NULL, poste_id text NOT NULL, ville text NOT NULL, building_id text NOT NULL,
  produits jsonb NOT NULL, PRIMARY KEY (pays, poste_id));
ALTER TABLE public.chaines_production_pays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.directeurs_usine_pays ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS chaines_production_pays_lecture ON public.chaines_production_pays;
CREATE POLICY chaines_production_pays_lecture ON public.chaines_production_pays FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS directeurs_usine_pays_lecture ON public.directeurs_usine_pays;
CREATE POLICY directeurs_usine_pays_lecture ON public.directeurs_usine_pays FOR SELECT TO anon, authenticated USING (true);
REVOKE ALL ON public.chaines_production_pays, public.directeurs_usine_pays FROM anon, authenticated;
GRANT SELECT ON public.chaines_production_pays, public.directeurs_usine_pays TO anon, authenticated;

-- Distillerie : alcool tiré des fruits et légumes (décision du 10/11/2026). Salaires : fourchette de
-- Fred 15-20 PSK par PA (06/11) ; même proportion que la Républia, plancher 15.
INSERT INTO public.chaines_production_pays (pays, produit, ville, building_id, matiere, salaire_pa, rang) VALUES
  ('soviet', 'alcool',                 'ville_b',  'distillerie-krasnov',           'fruits_legumes', 15, 1),
  ('soviet', 'carburant',              'ville_a',  'usine-principale',              'petrole',        15, 2),
  ('soviet', 'derives_petrochimiques', 'ville_a',  'usine-principale',              'petrole',        15, 3),
  ('soviet', 'medicaments',            'capitale', 'usine-pharmaceutique-luthecia', 'plantes',        18, 4),
  ('soviet', 'desinfectant',           'capitale', 'usine-pharmaceutique-luthecia', 'alcool',         15, 5)
ON CONFLICT (pays, produit) DO UPDATE SET ville = EXCLUDED.ville, building_id = EXCLUDED.building_id,
  matiere = EXCLUDED.matiere, salaire_pa = EXCLUDED.salaire_pa, rang = EXCLUDED.rang;
INSERT INTO public.salaires_production_pays (pays, produit, salaire_pa) VALUES
  ('soviet', 'alcool', 15), ('soviet', 'carburant', 15), ('soviet', 'derives_petrochimiques', 15)
ON CONFLICT DO NOTHING;
INSERT INTO public.directeurs_usine_pays (pays, poste_id, ville, building_id, produits) VALUES
  ('soviet', 'directeur_pharma',        'capitale', 'usine-pharmaceutique-luthecia', '["medicaments","desinfectant"]'),
  ('soviet', 'directeur_tabac_alcools', 'ville_b',  'distillerie-krasnov',           '["alcool"]'),
  ('soviet', 'directeur_raffinerie',    'ville_a',  'usine-principale',              '["carburant","derives_petrochimiques"]')
ON CONFLICT (pays, poste_id) DO UPDATE SET ville = EXCLUDED.ville, building_id = EXCLUDED.building_id, produits = EXCLUDED.produits;

-- Usine d'un poste de directeur, dans le pays donné ; repli sur la table historique (Républia).
CREATE OR REPLACE FUNCTION public.usine_du_directeur_pays_interne(p_pays text, p_poste text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $f$
  SELECT coalesce(
    (SELECT jsonb_build_object('ville', ville, 'batiment', building_id, 'produits', produits)
       FROM public.directeurs_usine_pays WHERE pays = p_pays AND poste_id = p_poste),
    (SELECT jsonb_build_object('ville', ville, 'batiment', building_id, 'produits', produits)
       FROM public.directeurs_usine WHERE poste_id = p_poste AND coalesce(p_pays, 'republic') = 'republic'));
$f$;
REVOKE ALL ON FUNCTION public.usine_du_directeur_pays_interne(text, text) FROM PUBLIC, anon, authenticated;

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  -- produire_en_usine : chaîne du pays d'abord ; pour une chaîne de pays, il faut être sur place.
  v_def := pg_get_functiondef('public.produire_en_usine(text,text,text)'::regprocedure);
  IF position('chaines_production_pays' in v_def) = 0 THEN
    v_new := replace(v_def,
$a$  SELECT ville, building_id, matiere, salaire_pa INTO v_ville, v_bat, v_matiere, v_salaire
  FROM public.chaines_production_usine WHERE produit = p_produit;$a$,
$b$  SELECT ville, building_id, matiere, salaire_pa INTO v_ville, v_bat, v_matiere, v_salaire
  FROM public.chaines_production_pays WHERE pays = p_pays AND produit = p_produit;
  IF v_ville IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees
       WHERE name = p_acteur AND current_building = v_bat AND current_city = v_ville) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  IF v_ville IS NULL THEN
  SELECT ville, building_id, matiere, salaire_pa INTO v_ville, v_bat, v_matiere, v_salaire
  FROM public.chaines_production_usine WHERE produit = p_produit;
  END IF;$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch produire_en_usine non applique'; END IF;
    EXECUTE v_new;
  END IF;

  -- vendre_matiere_a_usine : matières acceptées par les chaînes du pays aussi.
  v_def := pg_get_functiondef('public.vendre_matiere_a_usine(text,text,text,text,text,integer)'::regprocedure);
  IF position('chaines_production_pays' in v_def) = 0 THEN
    v_new := replace(v_def, $a$FROM public.chaines_production_usine c$a$,
      $b$FROM (SELECT building_id, matiere FROM public.chaines_production_usine
                 UNION ALL SELECT building_id, matiere FROM public.chaines_production_pays WHERE pays = p_pays) c$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch vendre_matiere_a_usine non applique'; END IF;
    EXECUTE v_new;
  END IF;

  -- Directeurs : usine du poste dans le pays du personnage, et état de l'usine de son pays.
  v_def := pg_get_functiondef('public.fixer_prix_vente_directe(text,text,jsonb)'::regprocedure);
  IF position('usine_du_directeur_pays_interne' in v_def) = 0 THEN
    v_new := replace(replace(v_def,
$a$  SELECT ville, building_id, produits INTO v_ville, v_bat, v_produits
  FROM public.directeurs_usine WHERE poste_id = v_poste;$a$,
$b$  SELECT u->>'ville', u->>'batiment', u->'produits' INTO v_ville, v_bat, v_produits
  FROM (SELECT public.usine_du_directeur_pays_interne((SELECT coalesce(country, 'republic')
          FROM public.personnages_donnees WHERE name = p_acteur), v_poste) AS u) s;$b$),
$a$  v_id := p_pays || '_' || v_ville || '_' || v_bat;$a$,
$b$  v_id := (SELECT coalesce(country, 'republic') FROM public.personnages_donnees WHERE name = p_acteur) || '_' || v_ville || '_' || v_bat;$b$);
    IF v_new = v_def OR position('usine_du_directeur_pays_interne' in v_new) = 0 OR position('p_pays ||' in v_new) > 0 THEN
      RAISE EXCEPTION 'patch fixer_prix_vente_directe non applique'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.fixer_repartition_production(text,text,numeric)'::regprocedure);
  IF position('usine_du_directeur_pays_interne' in v_def) = 0 THEN
    v_new := replace(replace(v_def,
$a$  SELECT ville, building_id INTO v_ville, v_bat FROM public.directeurs_usine WHERE poste_id = v_poste;$a$,
$b$  SELECT u->>'ville', u->>'batiment' INTO v_ville, v_bat
  FROM (SELECT public.usine_du_directeur_pays_interne((SELECT coalesce(country, 'republic')
          FROM public.personnages_donnees WHERE name = p_acteur), v_poste) AS u) s;$b$),
$a$  v_id := p_pays || '_' || v_ville || '_' || v_bat;$a$,
$b$  v_id := (SELECT coalesce(country, 'republic') FROM public.personnages_donnees WHERE name = p_acteur) || '_' || v_ville || '_' || v_bat;$b$);
    IF v_new = v_def OR position('usine_du_directeur_pays_interne' in v_new) = 0 OR position('p_pays ||' in v_new) > 0 THEN
      RAISE EXCEPTION 'patch fixer_repartition_production non applique'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.usine_virer_vers_ministere(numeric)'::regprocedure);
  IF position('usine_du_directeur_pays_interne' in v_def) = 0 THEN
    v_new := replace(v_def, $a$u := public.usine_du_directeur_interne(v_poste);$a$,
                            $b$u := public.usine_du_directeur_pays_interne(v_pays, v_poste);$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch usine_virer_vers_ministere non applique'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.ministere_virer_vers_usine(text,numeric)'::regprocedure);
  IF position('usine_du_directeur_pays_interne' in v_def) = 0 THEN
    v_new := replace(v_def, $a$u := public.usine_du_directeur_interne(p_poste_usine);$a$,
                            $b$u := public.usine_du_directeur_pays_interne(v_pays, p_poste_usine);$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch ministere_virer_vers_usine non applique'; END IF;
    EXECUTE v_new;
  END IF;
END $mig$;

-- États de départ des deux nouvelles usines (Pharmanov existe déjà). Caisse de 1 000 PSK pour payer
-- les premiers salaires ; la vente directe la renfloue ensuite.
INSERT INTO public.batiments_etat (id, country, city, building_id, data, updated_at) VALUES
  ('soviet_ville_a_usine-principale', 'soviet', 'ville_a', 'usine-principale',
   '{"usine":{"caisse":1000,"venteDirecte":{"carburant":0,"derives_petrochimiques":0},"stockMatieres":{"petrole":0}}}', now()),
  ('soviet_ville_b_distillerie-krasnov', 'soviet', 'ville_b', 'distillerie-krasnov',
   '{"usine":{"caisse":1000,"venteDirecte":{"alcool":0},"stockMatieres":{"fruits_legumes":0}}}', now())
ON CONFLICT (id) DO NOTHING;
