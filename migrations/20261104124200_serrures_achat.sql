-- APPLIQUEE le 04/11/2026 par Claude (registre serrures_achat_20261104124200), structure eprouvee en transaction annulee
-- avant application, puis banc annule outils/bancs/banc-serrures.sql joue en production : vert.
-- 4 novembre 2026 -- SERRURES, etape 3 : l'achat au comptoir de l'armurerie (issue #434).
--
-- quincaillerie_acheter : porte d'autorite (le personnage est celui de la session), au comptoir
-- de l'armurerie ou il se trouve. La vente passe par le moteur commun des commerces
-- (commerce_vendre_produit_interne : stock, prix fixe par le commerce, paiement, taxe, caisse,
-- ordre « choisir_arme » de la vitrine) ; l'objet est depose par inventaire_deposer_interne dans
-- la meme transaction. Ni registre de vente d'armes, ni marche noir.
--   * serrure_cle : une serrure par achat. Une ligne serrures (neuve) + le bloc + SA cle ;
--     2 emplacements d'inventaire.
--   * cle_vierge : 1 a 50 par achat, empilees.
-- La variante a cle d'unicite (p_requete) rejoue la reponse d'une requete deja servie, jamais
-- un second paiement (meme forme qu'arme_acheter).

CREATE OR REPLACE FUNCTION public.quincaillerie_acheter(p_entreprise text, p_produit text, p_qte integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_data jsonb; v_pays text; d record; v_qte integer := coalesce(p_qte, 1);
  v_place integer; v_besoin integer; v_r jsonb; v_dep jsonb; v_id uuid;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise;
  IF v_data IS NULL OR v_data->>'type' IS DISTINCT FROM 'armurerie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_pays := coalesce(v_data->>'country', 'republic');
  IF (SELECT q.id FROM public.quincaillerie_recette_interne(p_produit, v_pays) q) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_non_propose'); END IF;
  IF v_qte < 1 OR v_qte > 50 OR (p_produit = 'serrure_cle' AND v_qte <> 1) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;

  SELECT country, current_city, current_building, inventory INTO d
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF d.country IS DISTINCT FROM v_pays OR d.current_city IS DISTINCT FROM coalesce(v_data->>'city', 'capitale')
     OR d.current_building IS DISTINCT FROM coalesce(nullif(v_data->>'buildingId', ''), 'armurerie') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_besoin := CASE WHEN p_produit = 'serrure_cle' THEN 2 ELSE v_qte END;
  v_place := public.inventaire_place_restante(d.inventory);
  IF v_place < v_besoin THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'requis', v_besoin); END IF;

  v_r := public.commerce_vendre_produit_interne(v_moi, p_entreprise,
           jsonb_build_array(jsonb_build_object('produit', p_produit, 'qte', v_qte)),
           'comptoir', 'choisir_arme', 1, 0, NULL, NULL);
  IF coalesce((v_r->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;

  IF p_produit = 'serrure_cle' THEN
    INSERT INTO public.serrures (statut, achetee_par, entreprise) VALUES ('neuve', v_moi, p_entreprise)
    RETURNING id INTO v_id;
    v_dep := public.inventaire_deposer_interne(v_moi, public.serrure_objet_interne(v_id));
    IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'quincaillerie_acheter: bloc refuse %', v_dep; END IF;
    v_dep := public.inventaire_deposer_interne(v_moi, public.serrure_cle_objet_interne(v_id, 1));
    IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'quincaillerie_acheter: cle refusee %', v_dep; END IF;
  ELSE
    v_dep := public.inventaire_deposer_interne(v_moi, public.cle_vierge_objet_interne(v_qte));
    IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE OR (v_dep->>'qte')::integer IS DISTINCT FROM v_qte THEN
      RAISE EXCEPTION 'quincaillerie_acheter: cles vierges refusees %', v_dep; END IF;
  END IF;
  RETURN v_r || (v_dep - 'ok' - 'qte') || jsonb_build_object('produit', p_produit, 'qte', v_qte,
    'serrure', CASE WHEN v_id IS NULL THEN NULL ELSE jsonb_build_object('id', v_id, 'numero', public.serrure_numero_interne(v_id)) END);
END $$;

CREATE OR REPLACE FUNCTION public.quincaillerie_acheter(p_requete uuid, p_entreprise text, p_produit text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d text;
BEGIN
  prm := jsonb_build_object('entreprise', p_entreprise, 'produit', p_produit, 'qte', coalesce(p_qte, 1));
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'quincaillerie_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.quincaillerie_acheter(p_entreprise, p_produit, p_qte);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'quincaillerie_acheter', prm, v);
END $$;

REVOKE ALL ON FUNCTION public.quincaillerie_acheter(text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.quincaillerie_acheter(uuid, text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quincaillerie_acheter(uuid, text, text, integer) TO authenticated;
