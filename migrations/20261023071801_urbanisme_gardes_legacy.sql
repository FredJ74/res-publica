BEGIN;
-- Gardes des commandes historiques
DO $g$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.payer_ordre(text,text,integer,integer)') AND md5(prosrc) IN ('9a461bfc3c33f04f342ce6f5586393a7','c3098e80ece8a156c8ad393284a816de')) THEN RAISE EXCEPTION 'definition_non_examinee: payer_ordre'; END IF;END;$g$;
CREATE OR REPLACE FUNCTION public.payer_ordre(p_acteur text, p_fn text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
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
  IF v_fn = 'deposer_demande_permis' AND NOT EXISTS (
    SELECT 1 FROM public.permis_transactions_internes WHERE transaction_id=txid_current() AND acteur=auth.uid()
  ) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise'); END IF;
  IF v_fn='traiter_demandes_permis' AND NOT EXISTS(SELECT 1 FROM public.urbanisme_decisions_internes WHERE transaction_id=txid_current() AND acteur=auth.uid()) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;
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
DO $g$ DECLARE h text;d text;BEGIN
 SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.terrain_permis_acte(text,text,jsonb)');
 IF h IN ('e52c2c7a16a7c13588e7dba99b39a513','ca7506a6493af9c95baa99489b252313') THEN
 d:=replace(d,$ancre$  v_moi := public.mon_personnage();
$ancre$,$ajout$  IF p_acte='permis_decider' AND NOT EXISTS(SELECT 1 FROM public.urbanisme_decisions_internes WHERE transaction_id=txid_current() AND acteur=auth.uid() AND terrain=p_terrain_id) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;
  v_moi := public.mon_personnage();
$ajout$);
 d:=replace(d,$ancre$  ELSIF p_acte = 'permis_plan_modifier' THEN
$ancre$,$ajout$    -- L'acceleration ne peut reecrire ni statut, ni titulaire, ni numero du dossier.
    v_patch:=jsonb_build_object('permis',v_permis||jsonb_build_object('dureeInstruction',greatest(1,floor((v_permis->>'dureeInstruction')::numeric/2)),
      'dateInstructionTerminee',coalesce((v_permis->>'dateDepot')::integer,0)+greatest(1,floor((v_permis->>'dureeInstruction')::numeric/2))));
  ELSIF p_acte = 'permis_plan_modifier' THEN
$ajout$);
 d:=replace(d,$ancre$  END IF;

  v_final := public.terrain_etat_fusionner_interne(p_terrain_id, v_patch, v_pays);
$ancre$,$ajout$    -- Le plan n'est pas une porte de decision du permis.
    v_patch:=jsonb_build_object('permis',v_permis||jsonb_build_object('decoupageInitial',coalesce(v_patch->'permis'->'decoupageInitial','[]'::jsonb)));
  END IF;

  v_final := public.terrain_etat_fusionner_interne(p_terrain_id, v_patch, v_pays);
$ajout$);
 EXECUTE d;
 ELSIF h IS NULL OR h NOT IN ('f18b64b6f231501a530d8978b93a7395','067e435a47007ebf301b0d52922f1164') THEN RAISE EXCEPTION 'definition_non_examinee: terrain_permis_acte';END IF;
END;$g$;
COMMIT;
