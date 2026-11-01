-- Jardins ouvriers de Montrouge (Claude, 01/11/2026, recette PJ M-06, décision de Fred du 01/11).
-- Indépendante de l'écran : trois fonctions nouvelles, aucun écran actuel ne les appelle.
--
-- « Travailler aux jardins » : 1 PA, 5 fruits et légumes (référence d'inventaire existante
-- 'fruits_legumes', celle des commerces), une fois par jour (heure de Paris) et par PJ ; compteur
-- propre, sans rapport avec les récoltes ordinaires (recoltes_journalieres non touché).
-- Don volontaire : le PJ laisse aux jardins la quantité qu'il choisit de ses fruits et légumes ;
-- la réserve des jardins est réelle, tout PJ présent peut s'y servir (dans la limite du stock et
-- de sa place). Rien n'est retiré sans action explicite. Présence vérifiée sur la fiche serveur.
BEGIN;

CREATE TABLE IF NOT EXISTS public.jardins_ouvriers_travail (
  nom text NOT NULL, jour date NOT NULL, PRIMARY KEY (nom, jour));
CREATE TABLE IF NOT EXISTS public.jardins_ouvriers_reserve (
  pays text NOT NULL, ville text NOT NULL, qte integer NOT NULL DEFAULT 0 CHECK (qte >= 0),
  PRIMARY KEY (pays, ville));
ALTER TABLE public.jardins_ouvriers_travail ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jardins_ouvriers_reserve ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.jardins_ouvriers_travail FROM anon, authenticated;
REVOKE ALL ON public.jardins_ouvriers_reserve FROM anon, authenticated;
GRANT SELECT ON public.jardins_ouvriers_reserve TO authenticated;
DROP POLICY IF EXISTS "reserve jardins lecture" ON public.jardins_ouvriers_reserve;
CREATE POLICY "reserve jardins lecture" ON public.jardins_ouvriers_reserve FOR SELECT TO authenticated USING (true);
INSERT INTO public.jardins_ouvriers_reserve (pays, ville, qte) VALUES ('republic', 'ville_b', 0)
ON CONFLICT DO NOTHING;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'travailler_jardins', 1, 0
WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'travailler_jardins' AND pa = 1 AND cost = 0);

-- Présence et disponibilité communes aux trois actions. Verrouille la fiche.
CREATE OR REPLACE FUNCTION public.jardins_ouvriers_acteur_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE m record;
BEGIN
  IF p_acteur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, hp, hospitalisation INTO m
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(m.hp, 0) <= 0
     OR coalesce(m.hospitalisation->>'dateFinParis', '') > (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text
     OR EXISTS (SELECT 1 FROM public.detention_active(p_acteur)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_indisponible'); END IF;
  IF m.country IS DISTINCT FROM 'republic' OR m.current_city IS DISTINCT FROM 'ville_b'
     OR m.current_building IS DISTINCT FROM 'jardins-ouvriers-montrouge' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  RETURN jsonb_build_object('ok', true);
END; $$;

-- Ligne de fruits et légumes de l'inventaire : index et quantité (-1, 0 si aucune).
CREATE OR REPLACE FUNCTION public.jardins_ouvriers_ligne_legumes(p_inv jsonb)
RETURNS integer[] LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE i integer;
BEGIN
  IF jsonb_typeof(p_inv) = 'array' THEN
    FOR i IN 0 .. jsonb_array_length(p_inv) - 1 LOOP
      IF (p_inv -> i ->> 'stackKey') = 'fruits_legumes' AND coalesce((p_inv -> i ->> 'stackable')::boolean, false) THEN
        RETURN ARRAY[i, greatest(0, floor(coalesce((p_inv -> i ->> 'qty')::numeric, 0))::integer)];
      END IF;
    END LOOP;
  END IF;
  RETURN ARRAY[-1, 0];
END; $$;

CREATE OR REPLACE FUNCTION public.jardins_travailler_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v jsonb; v_jour date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date; v_dep jsonb;
BEGIN
  v := public.jardins_ouvriers_acteur_interne(p_acteur);
  IF (v->>'ok')::boolean IS NOT TRUE THEN RETURN v; END IF;
  IF EXISTS (SELECT 1 FROM public.jardins_ouvriers_travail WHERE nom = p_acteur AND jour = v_jour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_fait_aujourdhui'); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = p_acteur) < 5 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v := public.payer_ordre(p_acteur, 'travailler_jardins', 1, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  INSERT INTO public.jardins_ouvriers_travail (nom, jour) VALUES (p_acteur, v_jour);
  v_dep := public.inventaire_deposer_interne(p_acteur, jsonb_build_object('name', 'Fruits & légumes',
    'icon', 'ti-apple', 'stackable', true, 'stackKey', 'fruits_legumes', 'qty', 5,
    'desc', 'Cultivés aux jardins ouvriers de Montrouge.'));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'jardins_travailler: depot refuse %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'quantite', 5, 'pa', v->'pa');
END; $$;

CREATE OR REPLACE FUNCTION public.jardins_laisser_interne(p_acteur text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v jsonb; v_inv jsonb; l integer[]; v_reste integer;
BEGIN
  IF coalesce(p_qte, 0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  v := public.jardins_ouvriers_acteur_interne(p_acteur);
  IF (v->>'ok')::boolean IS NOT TRUE THEN RETURN v; END IF;
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = p_acteur;
  l := public.jardins_ouvriers_ligne_legumes(v_inv);
  IF l[1] < 0 OR l[2] < p_qte THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'possede', l[2]); END IF;
  IF l[2] = p_qte THEN v_inv := v_inv - l[1];
  ELSE v_inv := jsonb_set(v_inv, ARRAY[l[1]::text, 'qty'], to_jsonb(l[2] - p_qte)); END IF;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_acteur;
  IF (SELECT inventory FROM public.personnages_donnees WHERE name = p_acteur) IS DISTINCT FROM v_inv THEN
    RAISE EXCEPTION 'inventaire_non_applique'; END IF;
  INSERT INTO public.jardins_ouvriers_reserve AS r (pays, ville, qte) VALUES ('republic', 'ville_b', p_qte)
  ON CONFLICT (pays, ville) DO UPDATE SET qte = r.qte + EXCLUDED.qte RETURNING qte INTO v_reste;
  RETURN jsonb_build_object('ok', true, 'quantite', p_qte, 'reserve', v_reste);
END; $$;

CREATE OR REPLACE FUNCTION public.jardins_prendre_interne(p_acteur text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v jsonb; v_stock integer; v_dep jsonb;
BEGIN
  IF coalesce(p_qte, 0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  v := public.jardins_ouvriers_acteur_interne(p_acteur);
  IF (v->>'ok')::boolean IS NOT TRUE THEN RETURN v; END IF;
  SELECT qte INTO v_stock FROM public.jardins_ouvriers_reserve WHERE pays = 'republic' AND ville = 'ville_b' FOR UPDATE;
  IF coalesce(v_stock, 0) < p_qte THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_insuffisante', 'reserve', coalesce(v_stock, 0)); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = p_acteur) < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  UPDATE public.jardins_ouvriers_reserve SET qte = qte - p_qte WHERE pays = 'republic' AND ville = 'ville_b';
  v_dep := public.inventaire_deposer_interne(p_acteur, jsonb_build_object('name', 'Fruits & légumes',
    'icon', 'ti-apple', 'stackable', true, 'stackKey', 'fruits_legumes', 'qty', p_qte,
    'desc', 'Laissés aux jardins ouvriers de Montrouge pour qui en a besoin.'));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'jardins_prendre: depot refuse %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'quantite', p_qte, 'reserve', v_stock - p_qte);
END; $$;

-- Enveloppes appelables : clé d'unicité (une réponse perdue se rejoue sans double effet),
-- refus porté hors de la sous-transaction, état d'inventaire relu à la réussite.
CREATE OR REPLACE FUNCTION public.jardins_travailler(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; d text;
BEGIN
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'jardins_travailler', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.jardins_travailler_interne(a);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'jardins_travailler', prm, v);
END; $$;

CREATE OR REPLACE FUNCTION public.jardins_laisser_legumes(p_requete uuid, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('qte', p_qte); v jsonb; d text;
BEGIN
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'jardins_laisser_legumes', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.jardins_laisser_interne(a, p_qte);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'jardins_laisser_legumes', prm, v);
END; $$;

CREATE OR REPLACE FUNCTION public.jardins_prendre_legumes(p_requete uuid, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('qte', p_qte); v jsonb; d text;
BEGIN
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'jardins_prendre_legumes', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.jardins_prendre_interne(a, p_qte);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'jardins_prendre_legumes', prm, v);
END; $$;

REVOKE ALL ON FUNCTION public.jardins_ouvriers_acteur_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.jardins_ouvriers_ligne_legumes(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.jardins_travailler_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.jardins_laisser_interne(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.jardins_prendre_interne(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.jardins_travailler(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.jardins_laisser_legumes(uuid, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.jardins_prendre_legumes(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.jardins_travailler(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.jardins_laisser_legumes(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.jardins_prendre_legumes(uuid, integer) TO authenticated;

COMMIT;
