-- PREPAREE : garde du debit commun, sans changement des prix ou de la repartition.
-- Aucun solde ni donnee existante modifie par l'installation. Catalogue vivant requis.
BEGIN;
DO $g$ DECLARE h text; BEGIN
 SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.payer_ordre(text,text,integer,integer)');
 IF h IS NULL OR h NOT IN ('92234a6b14ff176d2c2c2236f705683e','484babaafa7271f5e4dc4040711d5db8') THEN RAISE EXCEPTION 'definition_non_examinee: payer_ordre'; END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.payer_ordre(p_acteur text, p_fn text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_fn text := coalesce(nullif(btrim(coalesce(p_fn,'')), ''), '(non transmis)');
  v_connu boolean; v_valide boolean;
  v_hp integer; v_batiment text; v_pa integer; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0;
  v_pris_liquide numeric; v_pris_national numeric;
  v_memorable record; v_pays text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
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

  SELECT pa, liquide, arg, hp, current_building INTO v_pa, v_liquide, v_arg, v_hp, v_batiment
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- La lecture et le refus sont dans la transaction qui debite, sous le verrou du PJ.
  -- Les soins deja declares restent accessibles au patient sur place, sans deuxieme debit.
  IF coalesce(v_hp,100)<=0 AND (coalesce(p_pa,0)>0 OR coalesce(p_cost,0)>0)
    AND NOT ((v_fn IN ('soin_public','centre_anti_poison','transfert_clinique_privee')
      AND v_batiment IN ('dispensaire-public','dispensaire-public-v'))
      OR (v_fn='soins' AND v_batiment='clinique-privee')) THEN
    RETURN jsonb_build_object('ok',false,'raison','acteur_incapacite');
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
COMMIT;
