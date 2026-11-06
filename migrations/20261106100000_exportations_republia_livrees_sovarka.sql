-- Exportations de Républia vers Sovarka livrées pour de vrai (Claude, 06/11/2026, règle de Fred).
--
-- Jusqu'ici, une exportation (EXPORTATIONS_PORT, passe de minuit) sortait du stock de Républia, payait
-- les entrepôts fournisseurs, puis disparaissait : le moteur avait été écrit pour Al-Khalija, qui n'a ni
-- entrepôt ni caisse. Sovarka en a désormais. Règle de Fred :
--   1. L'entrepôt de Starovka (port d'arrivée) paie la cargaison, au prix encaissé par la Républia.
--   2. Il la répartit aussitôt en trois et envoie une part à Novomirsk et une à Krasnov.
--   3. Ces deux entrepôts municipaux paient leur part à l'entrepôt de Starovka, au même prix.
-- Choix techniques de Claude : parts égales au tiers près, reste d'abord à Novomirsk puis à Krasnov
-- (50 -> 17 / 17 / 16). Starovka ne reçoit que ce que sa caisse peut payer : le reste ne quitte pas la
-- Républia (le moteur lit la quantité acceptée et ne prélève qu'elle). Une part que Novomirsk ou Krasnov
-- ne peut pas payer reste à Starovka. Caisses : caisses_batiments (celle du trading) ; stock :
-- batiments_etat.data.entrepot.stock. Une seule réception par jour et par matière (rejeu sans effet).

CREATE TABLE IF NOT EXISTS public.exportations_recues (
  jour date NOT NULL,
  cle text NOT NULL,
  pays text NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (jour, cle, pays)
);
ALTER TABLE public.exportations_recues ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.exportations_recues FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.exportation_sovarka_recevoir(p_jour date, p_cle text, p_quantite integer, p_prix numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  c_port  constant text := 'soviet_ville_a_entrepot-logistique-starovka';
  c_caisse_port constant text := 'soviet_entrepot_ville_a';
  v_deja jsonb;
  v_solde numeric;
  v_q integer;
  v_parts jsonb := '{}'::jsonb;
  v_base integer; v_reste integer;
  v_dest record;
  v_part integer; v_solde_dest numeric; v_envoye integer;
  v_res jsonb;
BEGIN
  IF p_cle IS NULL OR p_quantite IS NULL OR p_quantite <= 0 OR p_prix IS NULL OR p_prix <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'acceptee', 0, 'raison', 'rien_a_recevoir');
  END IF;
  SELECT resultat INTO v_deja FROM public.exportations_recues WHERE jour = p_jour AND cle = p_cle AND pays = 'soviet';
  IF FOUND THEN RETURN v_deja || jsonb_build_object('rejeu', true); END IF;

  -- 1. Starovka paie ce qu'il peut payer.
  SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde FROM public.caisses_batiments WHERE id = c_caisse_port FOR UPDATE;
  PERFORM 1 FROM public.batiments_etat WHERE id = c_port FOR UPDATE;
  IF v_solde IS NULL OR NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'acceptee', 0, 'raison', 'entrepot_starovka_absent');
  END IF;
  v_q := least(p_quantite, floor(v_solde / p_prix)::integer);
  IF v_q <= 0 THEN
    v_res := jsonb_build_object('ok', true, 'acceptee', 0, 'raison', 'caisse_starovka_insuffisante');
    INSERT INTO public.exportations_recues(jour, cle, pays, resultat) VALUES (p_jour, p_cle, 'soviet', v_res);
    RETURN v_res;
  END IF;
  UPDATE public.caisses_batiments SET data = jsonb_set(data, '{solde}', to_jsonb(round(v_solde - v_q * p_prix, 2))), updated_at = now()
   WHERE id = c_caisse_port;
  UPDATE public.batiments_etat
     SET data = jsonb_set(data, ARRAY['entrepot','stock',p_cle],
                          to_jsonb(coalesce((data #>> ARRAY['entrepot','stock',p_cle])::integer, 0) + v_q), true),
         updated_at = now()
   WHERE id = c_port;

  -- 2. et 3. Répartition en trois, Novomirsk et Krasnov paient leur part à Starovka.
  v_base := v_q / 3; v_reste := v_q - 3 * v_base;
  FOR v_dest IN
    SELECT * FROM (VALUES (1, 'capitale', 'soviet_capitale_entrepot-logistique-novomirsk', 'soviet_entrepot_capitale'),
                          (2, 'ville_b',  'soviet_ville_b_entrepot-logistique-krasnov',    'soviet_entrepot_ville_b')) d(rang, ville, etat_id, caisse_id)
     ORDER BY rang
  LOOP
    v_part := v_base + CASE WHEN v_dest.rang <= v_reste THEN 1 ELSE 0 END;
    v_envoye := 0;
    SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde_dest FROM public.caisses_batiments WHERE id = v_dest.caisse_id FOR UPDATE;
    PERFORM 1 FROM public.batiments_etat WHERE id = v_dest.etat_id FOR UPDATE;
    IF v_part > 0 AND v_solde_dest IS NOT NULL AND FOUND THEN
      v_envoye := least(v_part, floor(v_solde_dest / p_prix)::integer);
    END IF;
    IF v_envoye > 0 THEN
      UPDATE public.caisses_batiments SET data = jsonb_set(data, '{solde}', to_jsonb(round(v_solde_dest - v_envoye * p_prix, 2))), updated_at = now()
       WHERE id = v_dest.caisse_id;
      UPDATE public.caisses_batiments SET data = jsonb_set(data, '{solde}', to_jsonb(round(coalesce((data->>'solde')::numeric, 0) + v_envoye * p_prix, 2))), updated_at = now()
       WHERE id = c_caisse_port;
      UPDATE public.batiments_etat
         SET data = jsonb_set(data, ARRAY['entrepot','stock',p_cle],
                              to_jsonb(coalesce((data #>> ARRAY['entrepot','stock',p_cle])::integer, 0) + v_envoye), true),
             updated_at = now()
       WHERE id = v_dest.etat_id;
      UPDATE public.batiments_etat
         SET data = jsonb_set(data, ARRAY['entrepot','stock',p_cle],
                              to_jsonb(coalesce((data #>> ARRAY['entrepot','stock',p_cle])::integer, 0) - v_envoye), true),
             updated_at = now()
       WHERE id = c_port;
    END IF;
    v_parts := v_parts || jsonb_build_object(v_dest.ville, jsonb_build_object('part', v_part, 'envoye', v_envoye));
  END LOOP;

  v_res := jsonb_build_object('ok', true, 'acceptee', v_q, 'prix', p_prix, 'parts', v_parts);
  INSERT INTO public.exportations_recues(jour, cle, pays, resultat) VALUES (p_jour, p_cle, 'soviet', v_res);
  RETURN v_res;
END;
$$;

REVOKE ALL ON FUNCTION public.exportation_sovarka_recevoir(date, text, integer, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.exportation_sovarka_recevoir(date, text, integer, numeric) TO service_role;
