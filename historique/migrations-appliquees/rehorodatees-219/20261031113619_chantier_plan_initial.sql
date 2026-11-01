-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261022125942_chantier_plan_initial.sql ; aucun changement de règle.
-- #57 PREPAREE. Meme plan initial, phase serveur et archive dans la transaction de commande.
BEGIN;
DO $g$ DECLARE h text; BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_plan_normaliser_interne(jsonb,text,jsonb)'); IF h IS NOT NULL AND h<>'08d858fea913072fa1c88b3651228c2d' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_plan_normaliser_interne(jsonb,text,jsonb)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_plan_enregistrer_interne(jsonb,jsonb,boolean,text,text,text,text,integer)'); IF h IS NOT NULL AND h<>'463c43d2933cca956023561921eaf6f1' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_plan_enregistrer_interne(jsonb,jsonb,boolean,text,text,text,text,integer)';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.chantier_plan_normaliser_interne(p_etat jsonb,p_niveau text,p_plan jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $f$
DECLARE lot jsonb;sortie jsonb:='[]';vus text[]:=ARRAY[]::text[];idlot text;dest text;s numeric;total numeric:=0;minimum numeric;
BEGIN
 IF jsonb_typeof(p_plan) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'plan_invalide';END IF;
 FOR lot IN SELECT value FROM jsonb_array_elements(p_plan) LOOP
  idlot:=nullif(btrim(lot->>'id'),'');dest:=coalesce(lot->>'destination','commerce');s:=(lot->>'surface')::numeric;
  minimum:=CASE WHEN p_niveau='commerce_premium' AND dest='commerce' THEN 600 WHEN p_niveau='building' AND dest='commerce' THEN 300 WHEN p_niveau='building' AND dest='appartement' THEN 150 END;
  total:=total+s;
  IF idlot IS NULL OR idlot=ANY(vus) OR minimum IS NULL OR s IS NULL OR s<minimum OR nullif(p_etat->>'surface','') IS NULL OR total>(p_etat->>'surface')::numeric THEN RAISE EXCEPTION 'plan_invalide';END IF;
  vus:=array_append(vus,idlot);
  sortie:=sortie||jsonb_build_array(jsonb_build_object('id',idlot,'label',coalesce(nullif(btrim(lot->>'label'),''),'Lot'),'surface',s,'destination',dest,'locataire',NULL,'loyer',0));
 END LOOP;
 RETURN sortie;
END;$f$;
CREATE OR REPLACE FUNCTION public.chantier_plan_enregistrer_interne(p_etat jsonb,p_plan jsonb,p_valider boolean,p_terrain text,p_pays text,p_acteur text,p_requete text,p_jour integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE ch jsonb:=p_etat->'chantier';niveau text;lots jsonb;doc jsonb;ref text;r jsonb;
BEGIN
 IF jsonb_typeof(ch)='object' THEN
  IF coalesce((ch->>'planInitialValide')::boolean,false) THEN RAISE EXCEPTION 'plan_initial_valide';END IF;
  IF NOT coalesce((ch->>'progressionJours')::numeric>=(ch->>'dureeJours')::numeric*2/3 AND (ch->>'dureeJours')::numeric>0,false) THEN RAISE EXCEPTION 'dernier_tiers_requis';END IF;
  niveau:=ch->>'niveau';
 ELSE
  niveau:=p_etat->>'niveau_construction';
  IF niveau IS NULL OR coalesce((p_etat->>'planInitialValide')::boolean,false) OR jsonb_array_length(coalesce(p_etat->'subdivisions','[]'))>0 THEN RAISE EXCEPTION 'reamenagement_payant_requis';END IF;
  IF EXISTS(SELECT 1 FROM public.locations_actives WHERE country=p_pays AND data->>'city'=p_etat->>'city' AND data->>'buildingId'=p_terrain) THEN RAISE EXCEPTION 'local_occupe';END IF;
 END IF;
 IF niveau NOT IN('commerce_premium','building') THEN RAISE EXCEPTION 'batiment_indivisible';END IF;
 lots:=public.chantier_plan_normaliser_interne(p_etat,niveau,p_plan);
 -- Conserver les informations du permis : seul son plan change, aucune autorisation forgeable.
 p_etat:=jsonb_set(p_etat,'{permis}',coalesce(p_etat->'permis','{}')||jsonb_build_object('decoupageInitial',p_plan));
 IF jsonb_typeof(ch)='object' THEN
  p_etat:=jsonb_set(p_etat,'{chantier}',ch||jsonb_build_object('planInitialValide',p_valider));
 ELSE
  p_etat:=p_etat||jsonb_build_object('subdivisions',lots,'planInitialValide',true);
 END IF;
 ref:='urb-plan-'||p_requete;
 doc:=jsonb_build_object('id',ref||'-document','nature','modification_plan','numeroDossier',p_etat->'permis'->>'numeroDossier','jour',p_jour,'demandeur',p_acteur,'pays',p_pays,'ville',p_etat->>'city','buildingId',p_terrain,'batimentLabel',p_terrain,'palier',niveau,'surfaceExploitable',p_etat->'surface','decoupage',p_plan);
 INSERT INTO public.dossiers_urbanisme(id,country,city,building_id,numero_dossier,type_evenement,demandeur,jour,libelle,data)
 VALUES(ref,p_pays,p_etat->>'city',p_terrain,p_etat->'permis'->>'numeroDossier','modification_plan',p_acteur,p_jour,'Modification du plan de decoupage',doc);
 r:=public.objet_sas_deposer('document_urbanisme',p_acteur,jsonb_build_object('id',doc->>'id','type','document_urbanisme_modification_plan','name','Recepisse de modification du plan','icon','ti-file-text','legal',true,'documentUrbanisme',doc),ref);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'document_plan_non_confirme';END IF;
 RETURN p_etat;
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_plan_normaliser_interne(jsonb,text,jsonb),public.chantier_plan_enregistrer_interne(jsonb,jsonb,boolean,text,text,text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
