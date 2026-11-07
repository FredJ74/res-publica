-- Appliquée le 07/11/2026 par Claude (registre effort_ravitaillement_caisse_canonique_20261107081631) ; ne régularise aucun solde.
-- Complément du patch d'achat déjà livré par Claude (#565), pas un second moteur.
DO $patch$
DECLARE d text; ancien text; nouveau text;
 signature constant text := 'public.effort_ravitailler(text,jsonb,jsonb,jsonb)';
BEGIN
 IF to_regprocedure(signature) IS NULL THEN RAISE EXCEPTION 'effort_ravitailler_absent'; END IF;
 IF to_regprocedure('public.entrepot_caisse_id(text)') IS NULL
 OR to_regprocedure('public.caisse_institution_mouvement(text,numeric,boolean)') IS NULL THEN
  RAISE EXCEPTION 'effort_caisse_dependance_absente'; END IF;
 SELECT pg_get_functiondef(to_regprocedure(signature)) INTO d;
 IF position('effort_ravitaillement_caisse_unique_v1' IN d)>0 THEN RETURN; END IF;
 ancien := $old$  v_achats jsonb := '{}'::jsonb; v_data jsonb; v_commun jsonb;$old$;
 nouveau := $new$  v_achats jsonb := '{}'::jsonb; v_data jsonb; v_commun jsonb;
  v_caisse_ent text; v_mouvement_ent jsonb; v_caisse_flag text;$new$;
 IF (length(d)-length(replace(d,ancien,'')))/length(ancien)<>1 THEN
  RAISE EXCEPTION 'effort_caisse_declaration_incompatible'; END IF;
 d:=replace(d,ancien,nouveau);
 ancien := $old$      v_ent   := v_ent || jsonb_build_object('stock', v_stock,
                   'caisse', COALESCE((v_ent ->> 'caisse')::numeric, 0) + v_cout);$old$;
 nouveau := $new$      -- effort_ravitaillement_caisse_unique_v1 : recette réelle de l'entrepôt.
      v_caisse_ent := public.entrepot_caisse_id(v_id);
      IF v_caisse_ent IS NULL THEN RAISE EXCEPTION 'effort_caisse_non_declaree'; END IF;
      v_caisse_flag := current_setting('rp.caisse_interne',true);
      PERFORM set_config('rp.caisse_interne','on',true);
      v_mouvement_ent := public.caisse_institution_mouvement(v_caisse_ent,v_cout,true);
      PERFORM set_config('rp.caisse_interne',coalesce(v_caisse_flag,''),true);
      IF (v_mouvement_ent->>'ok')::boolean IS DISTINCT FROM true THEN
        -- Exception : annule TOUS les crédits antérieurs, le ravitaillement et son débit.
        RAISE EXCEPTION 'effort_caisse_credit_refuse: %',v_mouvement_ent;
      END IF;
      -- Champ historique inchangé pour investigation ; plus aucun mouvement dedans.
      v_ent := v_ent || jsonb_build_object('stock', v_stock);$new$;
 IF (length(d)-length(replace(d,ancien,'')))/length(ancien)<>1 THEN
  RAISE EXCEPTION 'effort_caisse_credit_incompatible'; END IF;
 d:=replace(d,ancien,nouveau);
 EXECUTE d;
END;
$patch$;
