-- #94 PREPAREE : calendrier existant, une transaction par dossier et par jour Paris.
BEGIN;
DO $definitions$ BEGIN
 IF to_regprocedure('public.terrain_permis_instruction_jour(text)') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.terrain_permis_instruction_jour(text)') AND md5(prosrc)='2e10075f16de05a12c1369d2349ee57d') THEN RAISE EXCEPTION 'definition_non_examinee: terrain_permis_instruction_jour(text)';END IF;
END;$definitions$;
CREATE OR REPLACE FUNCTION public.terrain_permis_instruction_jour(p_terrain_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE t record;e jsonb;p jsonb;jour text:=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;
 duree integer;faits integer;suspendu boolean;accord boolean:=false;ref text;doc jsonb;r jsonb;
BEGIN
 IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','reserve_serveur');END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE id=p_terrain_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable');END IF;
 e:=t.data::jsonb;p:=e->'permis';
 IF coalesce(p->>'statut','') NOT IN('instruction','attente_validation') THEN RETURN jsonb_build_object('ok',true,'ignore',true);END IF;
 IF p->>'jourInstruction'=jour THEN RETURN jsonb_build_object('ok',true,'rejeu',true);END IF;
 duree:=floor(coalesce((p->>'dureeInstruction')::numeric,0));
 IF duree<=0 THEN RETURN jsonb_build_object('ok',false,'raison','instruction_invalide');END IF;
 faits:=CASE WHEN p ? 'joursInstructionFaits' THEN greatest(0,floor(coalesce((p->>'joursInstructionFaits')::numeric,0)))
  WHEN p->>'statut'='attente_validation' THEN duree ELSE 0 END;
 suspendu:=coalesce(e->>'pnj','')='cadavre' OR coalesce(e->>'succession_gel','')<>'';
 p:=p||jsonb_build_object('jourInstruction',jour);
 IF NOT suspendu AND faits<duree THEN faits:=faits+1;p:=p||jsonb_build_object('joursInstructionFaits',faits);END IF;
 accord:=NOT suspendu AND faits>=duree;
 IF accord THEN p:=p||jsonb_build_object('statut','valide','accordTacite',true,'jourDecision',jour);END IF;
 PERFORM public.terrain_etat_fusionner_interne(t.id,jsonb_build_object('permis',p)||CASE WHEN accord THEN '{"constructionAutorisee":true}'::jsonb ELSE '{}'::jsonb END,t.country);
 IF accord THEN
  ref:='urb-tacite-'||md5(jsonb_build_array(t.id,p->>'numeroDossier',p->'dateDepot')::text);
  INSERT INTO public.dossiers_urbanisme(id,country,city,building_id,type_evenement,data)
   VALUES(ref,t.country,e->>'city',t.building_id,'accord_tacite','{}');
  SELECT data INTO doc FROM public.dossiers_urbanisme WHERE id=ref;
  r:=public.objet_sas_deposer('document_urbanisme',p->>'demandeur','{}',ref);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'document_non_confirme';END IF;
  PERFORM public.mail_systeme_poser_interne('Services d''urbanisme',p->>'demandeur','Permis accorde tacitement',
   'Le delai d instruction est ecoule sans decision. Votre permis est accorde tacitement.',NULL);
 END IF;
 RETURN jsonb_build_object('ok',true,'accord_tacite',accord,'suspendu',suspendu,'instruit',NOT suspendu,'jour',jour);
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_permis_instruction_jour(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.terrain_permis_instruction_jour(text) TO service_role;
COMMIT;
