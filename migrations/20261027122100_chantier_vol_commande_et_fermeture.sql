-- PREPAREE #135. Meme commande, memes recus. Aucun paiement dans le DDL.
BEGIN;
DO $patch$ DECLARE s text;n text;ancien text;nouveau text;
BEGIN
 s:=pg_get_functiondef('public.chantier_commande(text,text,text,jsonb)'::regprocedure);
 IF position('chantier_vol_executer_interne' IN s)=0 THEN
 ancien:=$a$ SELECT * INTO t FROM public.terrains_etat WHERE country=a.country AND$a$;
 nouveau:=$b$ IF p_action='voler' THEN
  resultat:=public.chantier_vol_executer_interne(p_terrain_id,p_parametres,p_requete);
  IF NOT coalesce((resultat->>'ok')::boolean,false) THEN RETURN resultat;END IF;
  INSERT INTO public.chantier_commandes_recus(personnage_id,acteur,requete,terrain_id,commande,resultat)
  VALUES(a.id,acteur,p_requete,p_terrain_id,commande,resultat);
  RETURN resultat;
 END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE country=a.country AND$b$;
 IF (length(s)-length(replace(s,ancien,'')))/length(ancien)<>1
 OR position('rec.personnage_id IS DISTINCT FROM a.id' IN s)=0
 OR position('rec.commande<>commande' IN s)=0
 OR position('detention_active(acteur)' IN s)=0 THEN RAISE EXCEPTION 'chantier_commande_definition_non_examinee';END IF;
 n:=replace(s,ancien,nouveau);EXECUTE n;
 END IF;
 s:=pg_get_functiondef('public.terrain_chantier_acte(text,text,text,integer,integer)'::regprocedure);
 IF position('vol_commande_versionnee_requise' IN s)=0 THEN
 ancien:=$a$  v_moi := public.mon_personnage();$a$;
 nouveau:=$b$  IF p_acte='chantier_materiaux_voler' THEN RETURN jsonb_build_object('ok',false,'raison','vol_commande_versionnee_requise');END IF;
  v_moi := public.mon_personnage();$b$;
 IF (length(s)-length(replace(s,ancien,'')))/length(ancien)<>1 THEN RAISE EXCEPTION 'terrain_chantier_acte_definition_non_examinee';END IF;
 EXECUTE replace(s,ancien,nouveau);
 END IF;
END;$patch$;
COMMIT;
