-- PREPAREE #135. Meme commande, memes recus. Aucun paiement dans le DDL.
BEGIN;
DO $patch$ DECLARE s text;n text;ancien text;nouveau text;
BEGIN
 s:=pg_get_functiondef('public.chantier_commande(text,text,text,jsonb)'::regprocedure);
 IF position('chantier_vol_executer_interne' IN s)=0 THEN
 ancien:=$a$ SELECT * INTO t FROM public.terrains_etat WHERE country=a.country AND$a$;
 nouveau:=$b$ IF p_action='voler' THEN
  resultat:=public.chantier_vol_executer_interne(p_terrain_id,p_parametres,p_requete);
  -- Une intention valide garde aussi son refus metier : le meme identifiant
  -- ne peut pas devenir une autre tentative lorsque le stock ou les PA changent.
  -- Un payload mal forme n'entre pas dans le registre.
  IF p_parametres-ARRAY['matiere']='{}' AND jsonb_typeof(p_parametres->'matiere')='string'
  AND p_parametres->>'matiere' IN('bois','minerai','metal') THEN
   INSERT INTO public.chantier_commandes_recus(personnage_id,acteur,requete,terrain_id,commande,resultat)
   VALUES(a.id,acteur,p_requete,p_terrain_id,commande,resultat);
  END IF;
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
