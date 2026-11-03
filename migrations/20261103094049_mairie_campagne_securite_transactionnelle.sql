-- #379 : campagne existante, 2 PA + 500 FR de la caisse municipale, +10 ISN local, -3 POP.
-- Réutilise la caisse/son autorité et l'ajustement d'indice, aucun argent personnel.
CREATE OR REPLACE FUNCTION public.mairie_campagne_securite_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $f$
DECLARE a public.personnages_donnees;ville text;caisse text;budget jsonb;solde numeric;ancien text;
 refus text;mouvement jsonb;indice jsonb;avant integer;
BEGIN
 IF p_acteur IS DISTINCT FROM public.mon_personnage()THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 SELECT * INTO a FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable');END IF;
 IF a.poste->>'id'IS DISTINCT FROM 'maire'THEN RETURN jsonb_build_object('ok',false,'raison','reserve_au_maire');END IF;
 -- Les autres empires n'ont pas encore d'indices de ville persistants ; ne pas facturer une fiction.
 IF a.country IS DISTINCT FROM 'republic'THEN RETURN jsonb_build_object('ok',false,'raison','indices_territoriaux_non_disponibles');END IF;
 IF to_regprocedure('public.blocus_ordre_refuse_interne(text,text)')IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','ordre_non_raccorde');END IF;
 IF public.blocus_ordre_refuse_interne(p_acteur,'campagne_securite')THEN
  RETURN jsonb_build_object('ok',false,'raison','blocus_syndical');END IF;
 ville:=coalesce(nullif(a.poste->>'city',''),a.current_city);
 IF NOT public.ville_est_reelle(a.country,ville)THEN RETURN jsonb_build_object('ok',false,'raison','territoire_invalide');END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ordres_couts WHERE fn='campagne_securite'AND pa=2 AND cost=500)THEN
  RETURN jsonb_build_object('ok',false,'raison','cout_non_declare');END IF;
 caisse:=public.salaire_caisse_de('maire',a.country,ville);
 IF caisse IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','caisse_mairie_introuvable');END IF;
 refus:=public.caisse_refus_autorite(caisse,a.country);
 IF refus IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison',refus);END IF;
 SELECT data INTO budget FROM public.caisses_batiments WHERE id=caisse FOR UPDATE;
 solde:=CASE WHEN jsonb_typeof(budget->'solde')='number'THEN(budget->>'solde')::numeric ELSE 0 END;
 IF solde<500 THEN RETURN jsonb_build_object('ok',false,'raison','caisse_institution_insuffisante','cost',500,'disponible',solde);END IF;
 IF coalesce(a.pa,0)<2 THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants','requis',2);END IF;
 SELECT data INTO indice FROM public.indices_villes WHERE id=a.country||'_'||ville FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','indices_territoriaux_non_disponibles');END IF;
 avant:=coalesce((indice->>'isn')::integer,50);
 ancien:=current_setting('rp.caisse_interne',true);
 PERFORM set_config('rp.caisse_interne','on',true);
 mouvement:=public.caisse_institution_mouvement(caisse,-500,true);
 PERFORM set_config('rp.caisse_interne',coalesce(ancien,''),true);
 IF NOT coalesce((mouvement->>'ok')::boolean,false)THEN RAISE EXCEPTION 'campagne_securite_debit_non_confirme';END IF;
 -- Même prélèvement de PA que les autres actes institutionnels (permis, communications).
 UPDATE public.personnages_donnees SET pa=pa-2 WHERE name=p_acteur;
 PERFORM public.indice_ville_ajuster_interne(a.country,ville,'isn',10);
 SELECT data INTO indice FROM public.indices_villes WHERE id=a.country||'_'||ville;
 IF (indice->>'isn')::integer IS DISTINCT FROM greatest(0,least(100,avant+10))THEN
  RAISE EXCEPTION 'campagne_securite_indice_non_confirme';END IF;
 RETURN jsonb_build_object('ok',true,'pays',a.country,'ville',ville,'caisse',caisse,
  'solde_caisse',solde-500,'isn_ville',(indice->>'isn')::integer,'isn_delta',(indice->>'isn')::integer-avant,
  'payeParCommune',true,'montant_preleve',500);
END;$f$;
REVOKE ALL ON FUNCTION public.mairie_campagne_securite_interne(text)FROM PUBLIC,anon,authenticated,service_role;
