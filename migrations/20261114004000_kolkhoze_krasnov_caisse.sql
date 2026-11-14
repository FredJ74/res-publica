-- SOVARKA : KOLKHOZE S. M. KIROV DE KRASNOV (décisions de Fred du 14/11/2026, 00 h 21 – 00 h 31 ; GAME-DESIGN-NOVOMIRSK.md).
-- 1. Travaux, 1 PA chacun, sans limite : œufs 2 unités (2 × 3 œufs) ; traire les vaches 2 laitages (nouveau) ;
--    légumes 5 fruits et légumes ; lapin 1 viande + 1 tissus et peaux ; poulet 2 viandes (passé de 2 à 1 PA ; lapin aussi).
-- 2. Caisse commune du kolkhoze, comme la réserve des jardins ouvriers : toute matière première (matières livrées de
--    ressources_economie, plus les œufs) ; chaque article donné rapporte +2 popularité, au plus +6 par jour et par joueur ;
--    tout PJ présent peut se servir, 5 articles par jour au plus. Jour de Sovarka (sovarka_jour_paris).
BEGIN;

-- 1. Travaux.
CREATE OR REPLACE FUNCTION public.sovarka_ferme_travaux_interne(p_ville text, p_batiment text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_ville = 'ville_a' AND p_batiment = 'ferme-starovka' THEN
      '{"renne":{"fn":"ferme_renne","pa":5,"label":"Abattre et dépecer un renne","produits":[{"cle":"viande","qte":3},{"cle":"textile","qte":2},{"cle":"bois","qte":1}]},
        "traire":{"fn":"ferme_traire","pa":1,"label":"Traire les rennes","produits":[{"cle":"laitages","qte":2}]}}'::jsonb
    WHEN p_ville = 'ville_b' AND p_batiment = 'ferme-krasnov' THEN
      '{"legumes":{"fn":"ferme_legumes","pa":1,"label":"Extraire des légumes","produits":[{"cle":"fruits_legumes","qte":5}]},
        "oeufs":{"fn":"ferme_oeufs","pa":1,"label":"Ramasser les œufs","produits":[{"cle":"oeufs","qte":2}]},
        "vaches":{"fn":"ferme_vaches","pa":1,"label":"Traire les vaches","produits":[{"cle":"laitages","qte":2}]},
        "poulet":{"fn":"ferme_poulet","pa":1,"label":"Abattre un poulet","produits":[{"cle":"viande","qte":2}]},
        "lapin":{"fn":"ferme_lapin","pa":1,"label":"Abattre un lapin","produits":[{"cle":"viande","qte":1},{"cle":"textile","qte":1}]}}'::jsonb
  END;
$$;

UPDATE public.ordres_couts SET pa = 1 WHERE fn IN ('ferme_poulet', 'ferme_lapin') AND cost = 0;
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'ferme_vaches', 1, 0 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'ferme_vaches');

-- 2. Caisse commune.
CREATE TABLE IF NOT EXISTS public.kolkhoze_caisse (
  pays text NOT NULL, ville text NOT NULL, cle text NOT NULL,
  qte integer NOT NULL CHECK (qte >= 0), objet jsonb NOT NULL,
  PRIMARY KEY (pays, ville, cle)
);
CREATE TABLE IF NOT EXISTS public.kolkhoze_caisse_quotas (
  jour date NOT NULL, personnage text NOT NULL,
  pop_gagnee integer NOT NULL DEFAULT 0, pris integer NOT NULL DEFAULT 0,
  PRIMARY KEY (jour, personnage)
);
ALTER TABLE public.kolkhoze_caisse ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kolkhoze_caisse_quotas ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.kolkhoze_caisse, public.kolkhoze_caisse_quotas FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.kolkhoze_matiere_admise_interne(p_cle text)
RETURNS boolean LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p_cle = 'oeufs' OR EXISTS (SELECT 1 FROM public.ressources_economie r WHERE r.cle = p_cle AND r.source = 'livraison');
$$;

-- Acteur présent au kolkhoze, libre ; rend la ville.
CREATE OR REPLACE FUNCTION public.kolkhoze_acteur_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record;
BEGIN
  SELECT country, current_city, current_building INTO p FROM public.personnages_donnees WHERE name = p_acteur;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p.country IS DISTINCT FROM 'soviet' OR p.current_city IS DISTINCT FROM 'ville_b' OR p.current_building IS DISTINCT FROM 'ferme-krasnov' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF EXISTS (SELECT 1 FROM public.detention_active(p_acteur)) THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_indisponible'); END IF;
  RETURN jsonb_build_object('ok', true, 'pays', 'soviet', 'ville', 'ville_b');
END $$;

CREATE OR REPLACE FUNCTION public.kolkhoze_caisse_etat_interne(p_acteur text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', true,
    'caisse', coalesce((SELECT jsonb_agg(jsonb_build_object('cle', c.cle, 'nom', c.objet->>'name', 'icon', c.objet->>'icon', 'qte', c.qte) ORDER BY c.objet->>'name')
                          FROM public.kolkhoze_caisse c WHERE c.pays = 'soviet' AND c.ville = 'ville_b' AND c.qte > 0), '[]'::jsonb),
    'pop_restante', 6 - coalesce((SELECT q.pop_gagnee FROM public.kolkhoze_caisse_quotas q WHERE q.jour = public.sovarka_jour_paris() AND q.personnage = p_acteur), 0),
    'pris_restant', 5 - coalesce((SELECT q.pris FROM public.kolkhoze_caisse_quotas q WHERE q.jour = public.sovarka_jour_paris() AND q.personnage = p_acteur), 0));
$$;

CREATE OR REPLACE FUNCTION public.kolkhoze_caisse_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb;
BEGIN
  v := public.kolkhoze_acteur_interne(a);
  IF (v->>'ok')::boolean IS NOT TRUE THEN RETURN v; END IF;
  RETURN public.kolkhoze_caisse_etat_interne(a);
END $$;

CREATE OR REPLACE FUNCTION public.kolkhoze_caisse_donner_interne(p_acteur text, p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v jsonb; l jsonb; v_inv jsonb; v_objet jsonb; v_jour date := public.sovarka_jour_paris(); v_deja integer; v_gain integer; j jsonb;
BEGIN
  IF coalesce(p_qte, 0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  IF NOT public.kolkhoze_matiere_admise_interne(p_cle) THEN RETURN jsonb_build_object('ok', false, 'raison', 'matiere_refusee'); END IF;
  v := public.kolkhoze_acteur_interne(p_acteur);
  IF (v->>'ok')::boolean IS NOT TRUE THEN RETURN v; END IF;
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  l := public.sovarka_inventaire_ligne_interne(v_inv, ARRAY[p_cle]);
  IF (l->>'i')::integer < 0 OR (l->>'qte')::integer < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'possede', l->'qte'); END IF;
  v_objet := (v_inv -> (l->>'i')::integer) - 'qty' - 'id' - 'uid';
  PERFORM public.sovarka_inventaire_retirer_interne(p_acteur, l, p_qte);
  INSERT INTO public.kolkhoze_caisse AS c (pays, ville, cle, qte, objet) VALUES ('soviet', 'ville_b', p_cle, p_qte, v_objet)
  ON CONFLICT (pays, ville, cle) DO UPDATE SET qte = c.qte + EXCLUDED.qte;
  INSERT INTO public.kolkhoze_caisse_quotas (jour, personnage) VALUES (v_jour, p_acteur) ON CONFLICT DO NOTHING;
  SELECT pop_gagnee INTO v_deja FROM public.kolkhoze_caisse_quotas WHERE jour = v_jour AND personnage = p_acteur FOR UPDATE;
  v_gain := least(2 * p_qte, greatest(0, 6 - v_deja));
  IF v_gain > 0 THEN
    UPDATE public.kolkhoze_caisse_quotas SET pop_gagnee = pop_gagnee + v_gain WHERE jour = v_jour AND personnage = p_acteur;
    j := public.jauges_effet_appliquer_interne(p_acteur, v_gain, 0, 0);
  END IF;
  RETURN public.kolkhoze_caisse_etat_interne(p_acteur)
    || jsonb_build_object('action', 'donner', 'cle', p_cle, 'nom', v_objet->>'name', 'quantite', p_qte, 'gain_pop', v_gain, 'jauges', j->'jauges')
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_acteur);
END $$;

CREATE OR REPLACE FUNCTION public.kolkhoze_caisse_prendre_interne(p_acteur text, p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v jsonb; c record; v_jour date := public.sovarka_jour_paris(); v_pris integer; v_dep jsonb;
BEGIN
  IF coalesce(p_qte, 0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  v := public.kolkhoze_acteur_interne(p_acteur);
  IF (v->>'ok')::boolean IS NOT TRUE THEN RETURN v; END IF;
  INSERT INTO public.kolkhoze_caisse_quotas (jour, personnage) VALUES (v_jour, p_acteur) ON CONFLICT DO NOTHING;
  SELECT pris INTO v_pris FROM public.kolkhoze_caisse_quotas WHERE jour = v_jour AND personnage = p_acteur FOR UPDATE;
  IF v_pris + p_qte > 5 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quota_caisse', 'pris_restant', 5 - v_pris); END IF;
  SELECT * INTO c FROM public.kolkhoze_caisse WHERE pays = 'soviet' AND ville = 'ville_b' AND cle = p_cle FOR UPDATE;
  IF NOT FOUND OR c.qte < p_qte THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_insuffisante', 'reserve', coalesce(c.qte, 0)); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = p_acteur) < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  UPDATE public.kolkhoze_caisse SET qte = qte - p_qte WHERE pays = 'soviet' AND ville = 'ville_b' AND cle = p_cle;
  UPDATE public.kolkhoze_caisse_quotas SET pris = pris + p_qte WHERE jour = v_jour AND personnage = p_acteur;
  v_dep := public.inventaire_deposer_interne(p_acteur, c.objet || jsonb_build_object('qty', p_qte, 'stackable', true, 'stackKey', p_cle,
    'desc', 'De la caisse commune du kolkhoze de Krasnov.'));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'kolkhoze_prendre: depot refuse %', v_dep; END IF;
  RETURN public.kolkhoze_caisse_etat_interne(p_acteur)
    || jsonb_build_object('action', 'prendre', 'cle', p_cle, 'nom', c.objet->>'name', 'quantite', p_qte)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_acteur);
END $$;

-- RPC publiques, idempotentes par requête (comme les jardins ouvriers).
CREATE OR REPLACE FUNCTION public.kolkhoze_caisse_agir(p_requete uuid, p_action text, p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('action', p_action, 'cle', p_cle, 'qte', p_qte); v jsonb; d text;
BEGIN
  IF p_action NOT IN ('donner', 'prendre') THEN RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'kolkhoze_caisse_agir', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := CASE p_action WHEN 'donner' THEN public.kolkhoze_caisse_donner_interne(a, p_cle, p_qte)
                       ELSE public.kolkhoze_caisse_prendre_interne(a, p_cle, p_qte) END;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'kolkhoze_caisse_agir', prm, v);
END $$;

REVOKE ALL ON FUNCTION public.kolkhoze_matiere_admise_interne(text), public.kolkhoze_acteur_interne(text),
  public.kolkhoze_caisse_etat_interne(text), public.kolkhoze_caisse_donner_interne(text, text, integer),
  public.kolkhoze_caisse_prendre_interne(text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kolkhoze_caisse_lire(), public.kolkhoze_caisse_agir(uuid, text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kolkhoze_caisse_lire(), public.kolkhoze_caisse_agir(uuid, text, text, integer) TO authenticated;

COMMIT;
