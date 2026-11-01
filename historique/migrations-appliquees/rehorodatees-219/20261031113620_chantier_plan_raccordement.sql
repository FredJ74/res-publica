-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261022125943_chantier_plan_raccordement.sql ; aucun changement de règle.
-- #57 PREPAREE : raccordement du plan a la commande commune, patch garde.
BEGIN;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_commande(text,text,text,jsonb)');
IF h='2a7f00f8cb89712411867063f13977f8' THEN
IF position($a0$ ELSIF p_action='receptionner' THEN$a0$ in s)=0 THEN RAISE EXCEPTION 'patch_plan_absent_0';END IF;
s:=replace(s,$a0$ ELSIF p_action='receptionner' THEN$a0$,$b0$ ELSIF p_action='plan' THEN
  IF p_parametres-ARRAY['lots','valider']<>'{}' OR jsonb_typeof(p_parametres->'lots') IS DISTINCT FROM 'array' OR jsonb_typeof(p_parametres->'valider') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'plan_invalide';END IF;
  etat:=public.chantier_plan_enregistrer_interne(etat,p_parametres->'lots',(p_parametres->>'valider')::boolean,t.building_id,t.country,acteur,p_requete,a.day);
 ELSIF p_action='receptionner' THEN$b0$);
IF position($a1$  -- Les minima proviennent de SURFACES_MIN_LOT (plateau-immobilier.js) ; comparaison locale obligatoire.
  FOR lot IN SELECT value FROM jsonb_array_elements(plan) LOOP
   idlot:=nullif(btrim(lot->>'id'),'');dest:=coalesce(lot->>'destination','commerce');
   minimum:=CASE WHEN ch->>'niveau'='commerce_premium' AND dest='commerce' THEN 600 WHEN ch->>'niveau'='building' AND dest='commerce' THEN 300 WHEN ch->>'niveau'='building' AND dest='appartement' THEN 150 END;
   s:=(lot->>'surface')::numeric;total:=total+s;
   IF idlot IS NULL OR idlot=ANY(vus) OR minimum IS NULL OR s IS NULL OR s<minimum OR nullif(etat->>'surface','') IS NULL OR total>(etat->>'surface')::numeric THEN RAISE EXCEPTION 'plan_invalide';END IF;
   vus:=array_append(vus,idlot);
   lots:=lots||jsonb_build_array(jsonb_build_object('id',idlot,'label',coalesce(nullif(btrim(lot->>'label'),''),'Lot'),'surface',s,'destination',dest,'locataire',NULL,'loyer',0));
  END LOOP;
$a1$ in s)=0 THEN RAISE EXCEPTION 'patch_plan_absent_1';END IF;
s:=replace(s,$a1$  -- Les minima proviennent de SURFACES_MIN_LOT (plateau-immobilier.js) ; comparaison locale obligatoire.
  FOR lot IN SELECT value FROM jsonb_array_elements(plan) LOOP
   idlot:=nullif(btrim(lot->>'id'),'');dest:=coalesce(lot->>'destination','commerce');
   minimum:=CASE WHEN ch->>'niveau'='commerce_premium' AND dest='commerce' THEN 600 WHEN ch->>'niveau'='building' AND dest='commerce' THEN 300 WHEN ch->>'niveau'='building' AND dest='appartement' THEN 150 END;
   s:=(lot->>'surface')::numeric;total:=total+s;
   IF idlot IS NULL OR idlot=ANY(vus) OR minimum IS NULL OR s IS NULL OR s<minimum OR nullif(etat->>'surface','') IS NULL OR total>(etat->>'surface')::numeric THEN RAISE EXCEPTION 'plan_invalide';END IF;
   vus:=array_append(vus,idlot);
   lots:=lots||jsonb_build_array(jsonb_build_object('id',idlot,'label',coalesce(nullif(btrim(lot->>'label'),''),'Lot'),'surface',s,'destination',dest,'locataire',NULL,'loyer',0));
  END LOOP;
$a1$,$b1$  lots:=public.chantier_plan_normaliser_interne(etat,ch->>'niveau',plan);
$b1$);
IF position($a2$coalesce((ch->>'planInitialValide')::boolean,false)$a2$ in s)=0 THEN RAISE EXCEPTION 'patch_plan_absent_2';END IF;
s:=replace(s,$a2$coalesce((ch->>'planInitialValide')::boolean,false)$a2$,$b2$(coalesce((ch->>'planInitialValide')::boolean,false) OR jsonb_array_length(lots)>0)$b2$);
IF position($a3$IF SQLERRM=ANY(ARRAY[$a3$ in s)=0 THEN RAISE EXCEPTION 'patch_plan_absent_3';END IF;
s:=replace(s,$a3$IF SQLERRM=ANY(ARRAY[$a3$,$b3$IF SQLERRM=ANY(ARRAY['plan_initial_valide','dernier_tiers_requis','reamenagement_payant_requis','local_occupe','batiment_indivisible','document_plan_non_confirme',$b3$);
EXECUTE s;
ELSIF h IS DISTINCT FROM '6ff8d15bf8ac1f6aad509a57bea1c6f6' THEN RAISE EXCEPTION 'commande_plan_definition_non_examinee';END IF;
END;$p$;
COMMIT;
