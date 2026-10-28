-- #219 : encaissement existant, tarif unitaire contrôlé, quantité interne.
-- Fred 28/10 : le leader paie pour tous, PA de l'ordre inchangés.
DO $prevol$
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.payer_ordre(text,text,integer,integer)'::regprocedure)
 NOT IN ('92234a6b14ff176d2c2c2236f705683e','ca7abc6ac27e864f723b25e73dacd665') THEN
 RAISE EXCEPTION 'payer_ordre_vivant_non_examine';END IF;
 IF to_regprocedure('public.payer_ordre_interne(text,text,integer,integer)') IS NOT NULL AND
 (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.payer_ordre_interne(text,text,integer,integer)'))
 NOT IN ('f9cbbdfce4b37082483b496298419df6','f315b77059d65b1ccd1879e800d18c22') THEN
 RAISE EXCEPTION 'payer_ordre_interne_non_examine';END IF;
 IF to_regprocedure('public.payer_ordre_interne(text,text,integer,integer,integer)') IS NOT NULL AND
 (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.payer_ordre_interne(text,text,integer,integer,integer)'))<>'2e69447a8e911756d2223414327db42b' THEN
 RAISE EXCEPTION 'payer_quantite_interne_non_examine';END IF;
END $prevol$;
CREATE OR REPLACE FUNCTION public.payer_ordre_interne(p_acteur text, p_fn text, p_pa integer, p_cost integer, p_quantite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_fn text := coalesce(nullif(btrim(coalesce(p_fn,'')), ''), '(non transmis)');
  v_connu boolean; v_valide boolean;
  v_pa integer; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0;
  v_pris_liquide numeric; v_pris_national numeric;
  v_memorable record; v_pays text;
BEGIN
  IF coalesce(p_pa, 0) < 0 OR coalesce(p_cost, 0) < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_negatif');
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = v_fn) INTO v_connu;

  IF NOT v_connu THEN
    INSERT INTO public.ordres_couts_inconnus (fn, pa, cost)
    VALUES (v_fn, coalesce(p_pa,0), coalesce(p_cost,0))
    ON CONFLICT (fn) DO UPDATE SET occurrences = public.ordres_couts_inconnus.occurrences + 1;
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_inconnu', 'fn', v_fn);
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o
                 WHERE o.fn = v_fn AND o.pa = coalesce(p_pa,0) AND o.cost = coalesce(p_cost,0))
    INTO v_valide;
  IF NOT v_valide THEN
    INSERT INTO public.ordres_couts_ecarts (fn, pa, cost)
    VALUES (v_fn, coalesce(p_pa,0), coalesce(p_cost,0))
    ON CONFLICT (fn, pa, cost)
      DO UPDATE SET occurrences = public.ordres_couts_ecarts.occurrences + 1, vu_le = now();
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare',
                              'fn', v_fn, 'pa', p_pa, 'cost', p_cost);
  END IF;

  -- Quantité résolue par la porte métier, après validation du tarif unitaire.
  IF p_quantite IS NULL OR p_quantite<1 OR coalesce(p_cost,0)::bigint*p_quantite>2147483647 THEN
    RETURN jsonb_build_object('ok',false,'raison','quantite_de_paiement_invalide'); END IF;
  p_cost:=coalesce(p_cost,0)*p_quantite;
  SELECT pa, liquide, arg INTO v_pa, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);

  IF v_pa < coalesce(p_pa, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa);
  END IF;
  IF coalesce(v_liquide,0) + v_solde < coalesce(p_cost, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'disponible', coalesce(v_liquide,0) + v_solde);
  END IF;

  v_pris_liquide := least(coalesce(v_liquide,0), coalesce(p_cost,0));
  v_pris_national := coalesce(p_cost,0) - v_pris_liquide;

  UPDATE public.personnages_donnees
     SET pa = v_pa - coalesce(p_pa,0),
         liquide = coalesce(v_liquide,0) - v_pris_liquide,
         arg = coalesce(v_arg,0) - coalesce(p_cost,0)
   WHERE name = p_acteur;

  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national,
           updated_at = now() WHERE id = v_compte_id;
  END IF;

  -- LA MEMOIRE DES MANDATS (11 octobre 2026). Apres le prelevement, donc sur un fait accompli, et
  -- seulement si le triplet figure au registre des actes memorables. `presidence_memoire_noter`
  -- verifie elle-meme que l'acteur est bien le President en exercice : si c'est un ministre qui
  -- tient la conference de presse, rien n'est ecrit. Le registre ne contient AUCUN panneau a
  -- (0 PA, 0 FR) -- ouvrir une fenetre n'est pas un acte.
  SELECT * INTO v_memorable FROM public.presidence_memoire_ordres
   WHERE fn = v_fn AND pa = coalesce(p_pa,0) AND cost = coalesce(p_cost,0);
  IF FOUND THEN
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_acteur;
    PERFORM public.presidence_memoire_noter(
      v_pays, 'reaction', 'ordre_presidentiel', v_memorable.sujet,
      jsonb_build_object('ordre', v_fn, 'pa', coalesce(p_pa,0), 'cout', coalesce(p_cost,0)),
      p_acteur);
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'pa', v_pa - coalesce(p_pa,0),
    'liquide', coalesce(v_liquide,0) - v_pris_liquide,
    'arg', coalesce(v_arg,0) - coalesce(p_cost,0),
    'solde_national', v_solde - v_pris_national,
    'pa_preleves', coalesce(p_pa,0), 'montant_preleve', coalesce(p_cost,0));
END;
$function$;
REVOKE ALL ON FUNCTION public.payer_ordre_interne(text,text,integer,integer,integer) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.payer_ordre_interne(p_acteur text,p_fn text,p_pa integer,p_cost integer)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT public.payer_ordre_interne(p_acteur,p_fn,p_pa,p_cost,1);
$g$;
REVOKE ALL ON FUNCTION public.payer_ordre_interne(text,text,integer,integer) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.payer_ordre(p_acteur text,p_fn text DEFAULT NULL,p_pa integer DEFAULT 0,p_cost integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
BEGIN
 PERFORM public.exiger_acteur(p_acteur);
 RETURN public.payer_ordre_interne(p_acteur,p_fn,p_pa,p_cost);
END;
$g$;
