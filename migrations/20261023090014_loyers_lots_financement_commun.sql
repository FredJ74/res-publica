-- #94 PREPAREE : reutilise prelever_loyer_bail et le debit bancaire existants, lots dynamiques seulement.
BEGIN;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.prelever_loyer_bail(text)');
IF h='3cfefba8f901bffa734baa35e3b68388' THEN
s:=replace(s,$ancien$  v_bail        locations_actives%ROWTYPE;$ancien$,$nouveau$  v_lot_dynamique boolean;
  v_bail        locations_actives%ROWTYPE;$nouveau$);
s:=replace(s,$ancien$  v_data      := v_bail.data;$ancien$,$nouveau$  v_data      := v_bail.data;
  v_lot_dynamique:=left(coalesce(v_data->>'roomId',''),8)='lot_dyn_';$nouveau$);
s:=replace(s,$ancien$  -- Impayé.$ancien$,$nouveau$  IF v_lot_dynamique THEN
    IF v_prix<0 OR v_prix<>trunc(v_prix) OR v_prix::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'loyer_invalide';END IF;
    v_arg:=coalesce(v_liquide_loyer,0)+coalesce(v_disponible_bancaire,0);
  END IF;
  -- Impayé.$nouveau$);
s:=replace(s,$ancien$    -- Organisation propriétaire.
    IF left(v_titulaire, 5) = 'orga:' THEN$ancien$,$nouveau$    IF v_lot_dynamique AND v_titulaire='ville:'||(v_data->>'country')||':'||(v_data->>'city') THEN
      v_rec:=public.recette_municipale(v_data->>'country',v_data->>'city',v_prix,'loyer');
      IF NOT coalesce((v_rec->>'ok')::boolean,false) THEN RAISE EXCEPTION 'destination_introuvable';END IF;
    ELSIF left(v_titulaire, 5) = 'orga:' THEN$nouveau$);
s:=replace(s,$ancien$      SET arg = COALESCE(arg, 0) + v_prix
      WHERE name = v_titulaire;$ancien$,$nouveau$      SET arg = COALESCE(arg, 0) + v_prix,
          liquide=CASE WHEN v_lot_dynamique THEN coalesce(liquide,0)+v_prix ELSE liquide END
      WHERE name = v_titulaire;$nouveau$);
EXECUTE s;ELSIF h='ddd1f687b157f6b88cbd52a033556a2d' THEN
s:=replace(s,$ancien$  v_bail        locations_actives%ROWTYPE;$ancien$,$nouveau$  v_lot_dynamique boolean;v_banque numeric;v_liquide numeric;
  v_bail        locations_actives%ROWTYPE;$nouveau$);
s:=replace(s,$ancien$  v_data      := v_bail.data;$ancien$,$nouveau$  v_data      := v_bail.data;
  v_lot_dynamique:=left(coalesce(v_data->>'roomId',''),8)='lot_dyn_';$nouveau$);
s:=replace(s,$ancien$  -- Impayé.
  IF COALESCE(v_arg, 0) < v_prix THEN$ancien$,$nouveau$  IF v_lot_dynamique THEN
    IF v_prix<0 OR v_prix<>trunc(v_prix) OR v_prix::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'loyer_invalide';END IF;
    SELECT liquide INTO v_liquide FROM public.personnages_donnees WHERE name=v_locataire FOR UPDATE;
    SELECT solde INTO v_banque FROM public.comptes_bancaires WHERE personnage=v_locataire AND banque='nationale' FOR UPDATE;
    v_arg:=coalesce(v_liquide,0)+coalesce(v_banque,0);
  END IF;
  -- Impayé, avec les avertissements existants et aucun prelevement partiel.
  IF COALESCE(v_arg, 0) < v_prix THEN$nouveau$);
s:=replace(s,$ancien$    -- Organisation propriétaire.
    IF left(v_titulaire, 5) = 'orga:' THEN$ancien$,$nouveau$    -- Un lot communal continue de financer sa commune, pas le maire personnellement.
    IF v_lot_dynamique AND v_titulaire='ville:'||(v_data->>'country')||':'||(v_data->>'city') THEN
      v_rec:=public.recette_municipale(v_data->>'country',v_data->>'city',v_prix,'loyer');
      IF NOT coalesce((v_rec->>'ok')::boolean,false) THEN RAISE EXCEPTION 'destination_introuvable';END IF;
    ELSIF left(v_titulaire, 5) = 'orga:' THEN$nouveau$);
s:=replace(s,$ancien$      SET arg = COALESCE(arg, 0) + v_prix
      WHERE name = v_titulaire;$ancien$,$nouveau$      SET arg = COALESCE(arg, 0) + v_prix,
          liquide=CASE WHEN v_lot_dynamique THEN coalesce(liquide,0)+v_prix ELSE liquide END
      WHERE name = v_titulaire;$nouveau$);
s:=replace(s,$ancien$  -- Débit du locataire seulement après crédit valide.
  UPDATE personnages
  SET arg = COALESCE(arg, 0) - v_prix
  WHERE name = v_locataire;$ancien$,$nouveau$  -- Meme moteur financier ordinaire, banque nationale prioritaire, puis liquide.
  IF v_lot_dynamique THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(v_locataire,v_prix,'nationale') THEN RAISE EXCEPTION 'fonds_insuffisants';END IF;
  ELSE
    UPDATE personnages SET arg=coalesce(arg,0)-v_prix WHERE name=v_locataire;
  END IF;$nouveau$);
EXECUTE s;ELSIF h NOT IN ('471271bd1166996f83dc63f00ea99232','6fe694295a52a17a2f50e3d68c6b134c') THEN RAISE EXCEPTION 'definition_non_examinee: prelever_loyer_bail(text)';END IF;
END;$p$;
COMMIT;
