-- #69 PREPAREE. Calendrier annuel dans la RPC de loyer commune ; pas de boucle parallele.
BEGIN;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.prelever_loyer_bail(text)');
IF h='944b4d5929b11b1775eccc532df15eaa' THEN
s:=replace(s,$a0$  v_bail        locations_actives%ROWTYPE;$a0$,$b0$  v_annuel jsonb;
  v_bail        locations_actives%ROWTYPE;$b0$);
s:=replace(s,$a1$BEGIN
  SELECT *$a1$,$b1$BEGIN
  v_annuel:=public.coffre_loyer_preparer_interne(p_bail_id);
  IF v_annuel ? 'statut' THEN RETURN v_annuel->>'statut';END IF;
  SELECT *$b1$);
s:=replace(s,$a2$  -- Anti-rejeu : un seul prélèvement$a2$,$b2$  IF v_annuel IS NOT NULL THEN
    v_locataire:=v_annuel->>'locataire';v_prix:=(v_annuel->>'montant')::numeric;
    v_data:=v_data||jsonb_build_object('prix',(v_annuel->>'tarif')::integer);
  END IF;

  -- Anti-rejeu : un seul prélèvement$b2$);
s:=replace(s,$a3$  IF (v_data ->> 'jourPaiement') = v_jour THEN$a3$,$b3$  IF v_annuel IS NULL AND (v_data ->> 'jourPaiement') = v_jour THEN$b3$);
s:=replace(s,$a4$  -- Impayé.$a4$,$b4$  IF v_annuel IS NOT NULL THEN v_arg:=(v_annuel->>'disponible')::numeric;END IF;

  -- Impayé.$b4$);
s:=replace(s,$a5$'montantDu',  COALESCE((v_imp ->> 'montantDu')::numeric, 0) + v_prix,$a5$,$b5$'montantDu', CASE WHEN v_annuel IS NULL THEN COALESCE((v_imp ->> 'montantDu')::numeric, 0) + v_prix ELSE v_prix END,$b5$);
s:=replace(s,$a6$      IF v_avise THEN$a6$,$b6$      PERFORM public.coffre_loyer_terminer_interne(v_annuel,'expulsion_requise');
      IF v_avise THEN$b6$);
s:=replace(s,$a7$    RETURN 'avertissement';$a7$,$b7$    PERFORM public.coffre_loyer_terminer_interne(v_annuel,'avertissement');
    RETURN 'avertissement';$b7$);
s:=replace(s,$a8$  -- Crédit de la destination.$a8$,$b8$  IF v_annuel IS NOT NULL THEN
    IF NOT public.bail_encaisser_montant_interne(v_data,v_locataire,v_prix::integer) THEN RAISE EXCEPTION 'fonds_modifies';END IF;
  ELSE
  -- Crédit de la destination.$b8$);
s:=replace(s,$a9$  UPDATE locations_actives
  SET data = (v_data - 'avertissement')$a9$,$b9$  END IF;
  IF v_annuel IS NOT NULL THEN v_data:=v_data-'impaye';END IF;
  UPDATE locations_actives
  SET data = (v_data - 'avertissement')$b9$);
s:=replace(s,$a10$  RETURN 'paye';$a10$,$b10$  PERFORM public.coffre_loyer_terminer_interne(v_annuel,'paye');
  RETURN 'paye';$b10$);
EXECUTE s;
ELSIF h IS DISTINCT FROM '2dfcd34ee84fb9a3d8a940befe421edd' THEN RAISE EXCEPTION 'definition_non_examinee: prelever_loyer_bail(text)';END IF;
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.coffre_changer_taille(text,uuid,text,bigint)');
IF h='0bf01a5203ca6f3817eb55526b7810a0' THEN
s:=replace(s,$a0$ IF difference>0 THEN
  -- Memes primitives financieres et meme destination attestee que le loyer commun.
  -- Aucun routage de paiement ou de remboursement fourni par le navigateur.
  d:=public.bail_destination_attestee(b);
  IF d->>'type' IS DISTINCT FROM 'municipal' THEN RAISE EXCEPTION 'destination_non_raccordee';END IF;
  IF NOT public.helvetia_debiter_fonds_ordinaires(n,difference,'nationale') THEN RAISE EXCEPTION 'fonds_insuffisants';END IF;
  ancien_flag:=current_setting('rp.caisse_interne',true);
  r:=public.recette_municipale(d->>'pays',d->>'ville',difference,'loyer');
  PERFORM set_config('rp.caisse_interne',coalesce(ancien_flag,''),true);
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'encaissement_non_confirme';END IF;
 END IF;
$a0$,$b0$ IF difference>0 AND NOT public.bail_encaisser_montant_interne(b,n,difference) THEN RAISE EXCEPTION 'fonds_insuffisants';END IF;
$b0$);
EXECUTE s;
ELSIF h IS DISTINCT FROM 'a79043bed6407647a1749a8fa1740efd' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_changer_taille(text,uuid,text,bigint)';END IF;
END;$p$;
COMMIT;
