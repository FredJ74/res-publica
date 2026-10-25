-- Même instruction quotidienne ; les acquisitions versionnées ne reçoivent plus un blob de cron périmé.
BEGIN;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='terrain_permis_instruction_jour' AND (p.oid IS DISTINCT FROM to_regprocedure('public.terrain_permis_instruction_jour(text)') OR md5(p.prosrc)<>'b1770234c48e403f6a2ce5815dc0e9e3')) THEN RAISE EXCEPTION 'definition_non_examinee: terrain_permis_instruction_jour';END IF;END;$g$;
CREATE OR REPLACE FUNCTION public.terrain_permis_instruction_jour(p_terrain text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE t record;e jsonb;p jsonb;doc jsonb;reception jsonb;courrier jsonb;jour text:=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;n integer;d integer;ref text;plan jsonb;accord boolean:=false;instruits integer:=0;suspendu boolean;
BEGIN
 IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','serveur_requis');END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE id=p_terrain FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable');END IF;
 e:=t.data::jsonb;p:=e->'permis';
 IF coalesce(p->>'statut','') NOT IN('instruction','attente_validation') THEN RETURN jsonb_build_object('ok',true,'ignore',true);END IF;
 IF p->>'jourInstruction'=jour THEN RETURN jsonb_build_object('ok',true,'rejeu',true);END IF;
 d:=coalesce((p->>'dureeInstruction')::integer,0);
 IF d<=0 THEN RETURN jsonb_build_object('ok',false,'raison','duree_instruction_absente');END IF;
 n:=coalesce((p->>'joursInstructionFaits')::integer,CASE WHEN p->>'statut'='attente_validation' THEN d ELSE 0 END);
 suspendu:=e->>'pnj'='cadavre' OR coalesce(e->>'succession_gel','') NOT IN('','null','false');
 p:=p||jsonb_build_object('jourInstruction',jour);
 IF NOT coalesce(suspendu,false) THEN
  IF n<d THEN n:=n+1;instruits:=1;END IF;p:=p||jsonb_build_object('joursInstructionFaits',n);accord:=n>=d;
 END IF;
 IF accord THEN
  IF coalesce(p->>'numeroDossier','')='' OR coalesce(p->>'demandeur','')='' OR coalesce(e->>'city','')='' THEN RETURN jsonb_build_object('ok',false,'raison','dossier_incomplet');END IF;
  ref:='urb-tacite-'||t.id||'-'||(p->>'numeroDossier');
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',x->'id','label',x->'label','surface',(x->>'surface')::numeric,'destination',CASE WHEN x->>'destination'='appartement' THEN 'appartement' ELSE 'commerce' END)),'[]') INTO plan FROM jsonb_array_elements(coalesce(p->'decoupageInitial','[]')) x;
  doc:=jsonb_build_object('id',ref,'nature','accord_tacite','numeroDossier',p->'numeroDossier','jour',NULL,'jourDepot',p->'dateDepot','demandeur',p->'demandeur','pays',t.country,'ville',e->'city','buildingId',t.building_id,'batimentLabel',t.building_id,'palier',p->'palierDemande','palierLabel',p->'palierDemande','surfaceExploitable',e->'surface','decoupage',plan,'motifRefus',NULL);
  INSERT INTO public.dossiers_urbanisme(id,country,city,building_id,numero_dossier,type_evenement,demandeur,jour,libelle,data)
  VALUES(ref,t.country,e->>'city',t.building_id,p->>'numeroDossier','accord_tacite',p->>'demandeur',NULL,'Accord tacite au bénéfice de '||(p->>'demandeur')||' pour '||t.building_id||' ('||(p->>'palierDemande')||').',doc);
  reception:=public.objet_sas_deposer('document_urbanisme',p->>'demandeur',jsonb_build_object('id',ref,'type','document_urbanisme_accord_tacite','name','Attestation d’accord tacite — '||t.building_id,'icon','ti-file-certificate','legal',true,'desc','Le délai d’instruction s’est écoulé sans décision. Votre permis de construire est accordé tacitement.','documentUrbanisme',doc),ref);
  IF reception->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'document_accord_non_confirme';END IF;
  courrier:=public.mail_systeme_poser_interne('Services d’urbanisme',p->>'demandeur','Permis accorde tacitement','Le délai d’instruction s’est écoulé sans décision. Votre permis est accordé tacitement ; retrouvez l’attestation dans vos objets à recevoir.',NULL);
  p:=p||jsonb_build_object('statut','valide','accordTacite',true,'jourDecision',jour);e:=e||'{"constructionAutorisee":true}';
 END IF;
 e:=e||jsonb_build_object('permis',p);
 UPDATE public.terrains_etat SET data=e::text,updated_at=clock_timestamp() WHERE id=t.id;
 RETURN jsonb_build_object('ok',true,'instruits',instruits,'suspendus',CASE WHEN coalesce(suspendu,false) THEN 1 ELSE 0 END,'accords_tacites',CASE WHEN accord THEN 1 ELSE 0 END,'courrier',courrier);
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_permis_instruction_jour(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.terrain_permis_instruction_jour(text) TO service_role;
COMMIT;
