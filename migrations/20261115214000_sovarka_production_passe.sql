-- Production de Sovarka, passe de nuit (décisions de Fred, 15/11/2026 au soir ; GAME-DESIGN-NOVOMIRSK.md,
-- « Production et logistique de Sovarka »).
-- 1. Chaque ville produit chaque nuit un volume FIXE de ses matières, livré directement dans l'entrepôt
--    de la ville ; la production s'arrête quand l'entrepôt atteint sa capacité (5 000 par matière).
-- 2. Les trois usines d'État (distillerie, raffinerie, Pharmanov) se servent EN PREMIER dans l'entrepôt
--    de leur ville (priorité sur les contrats d'État et le marché), puis transforment 25 matières en
--    50 produits par chaîne ; 75 % aux trois entrepôts (part réglable par un directeur PJ), le reste en
--    vente directe (50 au plus). Les échanges entre entrepôts et les exportations passent ensuite.
-- Les PJ produisent davantage en travaillant (fermes, forêt, pétrole, usines).

CREATE TABLE IF NOT EXISTS public.sovarka_productions_villes (
  ville text NOT NULL, cle text NOT NULL, quantite integer NOT NULL CHECK (quantite >= 0),
  PRIMARY KEY (ville, cle));
ALTER TABLE public.sovarka_productions_villes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sovarka_productions_villes_lecture ON public.sovarka_productions_villes;
CREATE POLICY sovarka_productions_villes_lecture ON public.sovarka_productions_villes FOR SELECT TO anon, authenticated USING (true);
REVOKE ALL ON public.sovarka_productions_villes FROM anon, authenticated;
GRANT SELECT ON public.sovarka_productions_villes TO anon, authenticated;

-- Volumes de départ proposés par Claude, consignés pour relecture par Fred : contrats d'État + usines
-- + 20 % des cibles des trois entrepôts par nuit.
INSERT INTO public.sovarka_productions_villes (ville, cle, quantite) VALUES
  ('ville_a', 'petrole', 370), ('ville_a', 'charbon', 240), ('ville_a', 'viande', 69),
  ('ville_a', 'poisson', 38), ('ville_a', 'laitages', 45),
  ('ville_b', 'bois', 450), ('ville_b', 'cereales', 165), ('ville_b', 'fruits_legumes', 115),
  ('ville_b', 'viande', 69), ('ville_b', 'laitages', 45), ('ville_b', 'poisson', 37),
  ('capitale', 'metal', 220), ('capitale', 'minerai', 550), ('capitale', 'textile', 75)
ON CONFLICT (ville, cle) DO UPDATE SET quantite = EXCLUDED.quantite;

CREATE TABLE IF NOT EXISTS public.sovarka_production_passes (
  jour date PRIMARY KEY, resultat jsonb NOT NULL, cree_le timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.sovarka_production_passes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_production_passes FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_production_passe(p_jour date, p_interdites text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE
  c_capacite constant integer := 5000;
  c_volume   constant integer := 25;
  c_part     constant numeric := 0.75;
  c_vd_max   constant integer := 50;
  c_ids    constant text[] := ARRAY['soviet_capitale_entrepot-logistique-novomirsk', 'soviet_ville_a_entrepot-logistique-starovka', 'soviet_ville_b_entrepot-logistique-krasnov'];
  c_villes constant text[] := ARRAY['capitale', 'ville_a', 'ville_b'];
  c_noms   constant text[] := ARRAY['Novomirsk', 'Starovka', 'Krasnov'];
  v_deja jsonb; r record; v_i integer; v_k integer; v_stock integer; v_add integer;
  v_prod jsonb := '[]'::jsonb; v_usines jsonb := '[]'::jsonb; v_res jsonb;
  v_uid text; v_nom text; v_etat jsonb; v_usine jsonb; v_sm jsonb; v_vd jsonb;
  v_mat integer; v_pris integer; v_dispo integer; v_vers integer; v_base integer; v_reste integer;
  v_q integer; v_vdq integer; v_livre jsonb;
BEGIN
  IF p_jour IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'jour_absent'); END IF;
  IF p_interdites IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'legalite_non_verifiable'); END IF;
  SELECT resultat INTO v_deja FROM public.sovarka_production_passes WHERE jour = p_jour;
  IF FOUND THEN RETURN v_deja || jsonb_build_object('rejeu', true); END IF;
  PERFORM pg_advisory_xact_lock(hashtext('sovarka_production_passe'));
  SELECT resultat INTO v_deja FROM public.sovarka_production_passes WHERE jour = p_jour;
  IF FOUND THEN RETURN v_deja || jsonb_build_object('rejeu', true); END IF;

  FOR r IN SELECT ville, cle, quantite FROM public.sovarka_productions_villes
            WHERE quantite > 0 AND NOT (cle = ANY (p_interdites)) ORDER BY ville, cle LOOP
    v_i := array_position(c_villes, r.ville);
    IF v_i IS NULL THEN CONTINUE; END IF;
    v_stock := public.exportation_stock_interne(c_ids[v_i], r.cle, 0);
    IF v_stock IS NULL THEN
      v_prod := v_prod || jsonb_build_object('ville', r.ville, 'cle', r.cle, 'issue', 'entrepot_absent'); CONTINUE;
    END IF;
    v_add := least(r.quantite, greatest(0, c_capacite - v_stock));
    IF v_add > 0 THEN
      PERFORM public.exportation_stock_interne(c_ids[v_i], r.cle, v_add);
      INSERT INTO public.entrepot_journal(entrepot_id, jour, operation, sens, contrepartie, ressource, quantite, prix_unitaire, fret_unitaire, montant, statut)
      VALUES (c_ids[v_i], p_jour, 'production_locale', 'entree', 'Production de ' || c_noms[v_i], r.cle, v_add, 0, 0, 0, 'livre');
    END IF;
    v_prod := v_prod || jsonb_build_object('ville', r.ville, 'cle', r.cle, 'produit', v_add,
                                           'issue', CASE WHEN v_add > 0 THEN 'livre' ELSE 'entrepot_plein' END);
  END LOOP;

  FOR r IN SELECT produit, ville, building_id, matiere FROM public.chaines_production_pays
            WHERE pays = 'soviet' ORDER BY rang, produit LOOP
    IF r.produit = ANY (p_interdites) OR r.matiere = ANY (p_interdites) THEN
      v_usines := v_usines || jsonb_build_object('produit', r.produit, 'issue', 'interdit'); CONTINUE;
    END IF;
    v_uid := 'soviet_' || r.ville || '_' || r.building_id;
    v_nom := CASE r.building_id WHEN 'distillerie-krasnov' THEN 'Distillerie de Krasnov'
                                WHEN 'usine-principale' THEN 'Raffinerie d''État du Grand Nord'
                                ELSE 'Usine Pharmanov' END;
    SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_uid FOR UPDATE;
    IF v_etat IS NULL THEN
      v_usines := v_usines || jsonb_build_object('produit', r.produit, 'issue', 'usine_absente'); CONTINUE;
    END IF;
    v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
    v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
    v_vd := coalesce(v_usine->'venteDirecte', '{}'::jsonb);
    v_mat := coalesce((v_sm->>r.matiere)::numeric, 0)::integer;
    v_pris := 0;
    v_i := array_position(c_villes, r.ville);
    IF v_mat < c_volume AND v_i IS NOT NULL THEN
      v_dispo := coalesce(public.exportation_stock_interne(c_ids[v_i], r.matiere, 0), 0);
      v_pris := least(c_volume - v_mat, v_dispo);
      IF v_pris > 0 THEN
        PERFORM public.exportation_stock_interne(c_ids[v_i], r.matiere, -v_pris);
        INSERT INTO public.entrepot_journal(entrepot_id, jour, operation, sens, contrepartie, ressource, quantite, prix_unitaire, fret_unitaire, montant, statut)
        VALUES (c_ids[v_i], p_jour, 'livraison_usine', 'sortie', v_nom, r.matiere, v_pris, 0, 0, 0, 'livre');
        v_mat := v_mat + v_pris;
      END IF;
    END IF;
    IF v_mat < c_volume THEN
      v_usine := v_usine || jsonb_build_object('stockMatieres', jsonb_set(v_sm, ARRAY[r.matiere], to_jsonb(v_mat)));
      UPDATE public.batiments_etat SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine))::text), updated_at = now()
       WHERE id = v_uid;
      v_usines := v_usines || jsonb_build_object('produit', r.produit, 'issue', 'matiere_insuffisante', 'matiere_prise', v_pris, 'stock_matiere', v_mat);
      CONTINUE;
    END IF;
    v_sm := jsonb_set(v_sm, ARRAY[r.matiere], to_jsonb(v_mat - c_volume));
    v_vers := round(2 * c_volume * least(1, greatest(0, coalesce((v_usine->>'repartitionEntrepots')::numeric, c_part))))::integer;
    v_base := v_vers / 3; v_reste := v_vers - 3 * v_base; v_livre := '{}'::jsonb;
    FOR v_k IN 1..3 LOOP
      v_q := v_base + CASE WHEN v_k <= v_reste THEN 1 ELSE 0 END;
      v_stock := coalesce(public.exportation_stock_interne(c_ids[v_k], r.produit, 0), 0);
      v_q := least(v_q, greatest(0, c_capacite - v_stock));
      IF v_q > 0 THEN
        PERFORM public.exportation_stock_interne(c_ids[v_k], r.produit, v_q);
        INSERT INTO public.entrepot_journal(entrepot_id, jour, operation, sens, contrepartie, ressource, quantite, prix_unitaire, fret_unitaire, montant, statut)
        VALUES (c_ids[v_k], p_jour, 'production_usine', 'entree', v_nom, r.produit, v_q, 0, 0, 0, 'livre');
      END IF;
      v_livre := v_livre || jsonb_build_object(c_villes[v_k], v_q);
    END LOOP;
    v_vdq := least(2 * c_volume - v_vers, greatest(0, c_vd_max - coalesce((v_vd->>r.produit)::numeric, 0)::integer));
    v_vd := jsonb_set(v_vd, ARRAY[r.produit], to_jsonb(coalesce((v_vd->>r.produit)::numeric, 0) + v_vdq));
    v_usine := v_usine || jsonb_build_object('stockMatieres', v_sm, 'venteDirecte', v_vd);
    UPDATE public.batiments_etat SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine))::text), updated_at = now()
     WHERE id = v_uid;
    v_usines := v_usines || jsonb_build_object('produit', r.produit, 'issue', 'produit', 'matiere_prise', v_pris,
                                               'entrepots', v_livre, 'vente_directe', v_vdq);
  END LOOP;

  v_res := jsonb_build_object('ok', true, 'productions', v_prod, 'usines', v_usines);
  INSERT INTO public.sovarka_production_passes(jour, resultat) VALUES (p_jour, v_res);
  RETURN v_res;
END $f$;
REVOKE ALL ON FUNCTION public.sovarka_production_passe(date, text[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_production_passe(date, text[]) TO service_role;
