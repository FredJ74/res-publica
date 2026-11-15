-- Banc annule du guide des baies (15/11/2026) : migration puis essais sur Arnie, tout est annule.
BEGIN;
-- SOVARKA : GUIDE DES BAIES SAUVAGES DE KRASNOV (decisions de Fred du 15/11/2026, GAME-DESIGN-NOVOMIRSK.md).
-- Le guide etait paye au marche de Krasnov puis « consomme » sans effet ni objet (aucune famille de produit
-- de marche, constat du 14/11). Decisions :
--   * il arrive dans l'inventaire (famille « livre », deposee par commerce_vendre_produit_interne) ;
--   * le lire coute 2 PA et donne +1 INT pendant 24 heures ;
--   * il reste dans l'inventaire et se lit n'importe ou ;
--   * pas de cumul : on ne le relit qu'une fois l'effet dissipe.
-- L'effet est pose dans personnages_donnees.effets_actifs (meme forme que la coupe du salon : cle, deltas,
-- poseA, expireA en millisecondes). Aucune donnee de joueur touchee par la migration. Idempotente.

UPDATE public.recettes_commerce SET famille_produit_marche = 'livre'
 WHERE id = 'guide_baies_krasnov' AND famille_produit_marche IS DISTINCT FROM 'livre';

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'lire_guide_baies', 2, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'lire_guide_baies');

CREATE OR REPLACE FUNCTION public.guide_baies_lire_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_inv jsonb; v_now numeric; v_eff jsonb; v_actif jsonb; v jsonb;
BEGIN
  SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_inv, '[]'::jsonb)) o
                  WHERE jsonb_typeof(o) = 'object' AND o->>'type' = 'guide_baies_krasnov') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_guide');
  END IF;
  v_now := floor(extract(epoch FROM clock_timestamp()) * 1000);
  -- Effets encore actifs (purge des expires a l'ecriture, comme le salon).
  SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_eff
    FROM public.personnages_donnees p, jsonb_array_elements(coalesce(p.effets_actifs, '[]'::jsonb)) e
   WHERE p.name = p_acteur AND jsonb_typeof(e) = 'object' AND coalesce((e->>'expireA')::numeric, 0) > v_now;
  SELECT e INTO v_actif FROM jsonb_array_elements(v_eff) e WHERE e->>'cle' = 'guide_baies_int' LIMIT 1;
  IF v_actif IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'effet_deja_actif', 'expireA', v_actif->'expireA');
  END IF;
  v := public.payer_ordre(p_acteur, 'lire_guide_baies', 2, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  v_eff := v_eff || jsonb_build_array(jsonb_build_object('cle', 'guide_baies_int', 'cible', 'pj',
    'deltas', jsonb_build_object('INT', 1), 'libelle', 'Guide des baies sauvages',
    'poseA', v_now, 'expireA', v_now + 24 * 3600 * 1000));
  UPDATE public.personnages_donnees SET effets_actifs = v_eff, updated_at = now() WHERE name = p_acteur;
  RETURN jsonb_build_object('ok', true, 'bonusInt', 1, 'expireA', v_now + 24 * 3600 * 1000,
                            'effets_actifs', v_eff, 'pa', v->'pa');
END $$;
REVOKE ALL ON FUNCTION public.guide_baies_lire_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.guide_baies_lire(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; d text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'guide_baies_lire', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.guide_baies_lire_interne(a);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'guide_baies_lire', prm, v);
END $$;
REVOKE ALL ON FUNCTION public.guide_baies_lire(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.guide_baies_lire(uuid) TO authenticated;

DO $$ BEGIN
  IF (SELECT famille_produit_marche FROM public.recettes_commerce WHERE id = 'guide_baies_krasnov') IS DISTINCT FROM 'livre'
     OR NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'lire_guide_baies' AND pa = 2 AND cost = 0) THEN
    RAISE EXCEPTION 'guide_baies_lecture : controle structurel en echec';
  END IF;
END $$;
DO $banc$
DECLARE a text; v1 jsonb; v2 jsonb; v0 jsonb; pa0 int; pa1 int;
BEGIN
  SELECT name INTO a FROM public.personnages_donnees WHERE name ILIKE 'Arnie%' LIMIT 1;
  IF a IS NULL THEN RAISE EXCEPTION 'banc : Arnie introuvable'; END IF;
  UPDATE public.personnages_donnees SET pa = greatest(coalesce(pa,0), 10),
    effets_actifs = coalesce((SELECT jsonb_agg(e) FROM jsonb_array_elements(coalesce(effets_actifs,'[]'::jsonb)) e WHERE e->>'cle' <> 'guide_baies_int'), '[]'::jsonb)
   WHERE name = a;
  v0 := public.guide_baies_lire_interne(a);
  IF v0->>'raison' IS DISTINCT FROM 'pas_de_guide' THEN RAISE EXCEPTION 'banc : sans guide attendu pas_de_guide, recu %', v0; END IF;
  UPDATE public.personnages_donnees SET inventory = coalesce(inventory,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'id','guide_baies_krasnov_banc','type','guide_baies_krasnov','name','Guide des baies sauvages de Krasnov','familleProduitMarche','livre')) WHERE name = a;
  SELECT pa INTO pa0 FROM public.personnages_donnees WHERE name = a;
  v1 := public.guide_baies_lire_interne(a);
  SELECT pa INTO pa1 FROM public.personnages_donnees WHERE name = a;
  v2 := public.guide_baies_lire_interne(a);
  RAISE EXCEPTION 'BANC_RESULTAT pa % -> %, lecture1 ok=% bonus=% , lecture2 raison=%, guide garde=%',
    pa0, pa1, v1->>'ok', v1->>'bonusInt', v2->>'raison',
    (SELECT count(*) FROM public.personnages_donnees p, jsonb_array_elements(p.inventory) o WHERE p.name = a AND o->>'type' = 'guide_baies_krasnov');
END $banc$;
