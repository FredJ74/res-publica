-- Préserver le format historique : numéro/demandeur absents ne sont pas inventés.
BEGIN;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.terrain_permis_instruction_jour(text)');
IF h='b1770234c48e403f6a2ce5815dc0e9e3' THEN
d:=replace(d,$a$IF coalesce(p->>'numeroDossier','')='' OR coalesce(p->>'demandeur','')='' OR coalesce(e->>'city','')='' THEN$a$,$b$IF e->>'acquisitionVersion'='2' AND (coalesce(p->>'numeroDossier','')='' OR coalesce(p->>'demandeur','')='' OR coalesce(e->>'city','')='') THEN$b$);
d:=replace(d,$a$ref:='urb-tacite-'||t.id||'-'||(p->>'numeroDossier');$a$,$b$ref:='urb-tacite-'||t.id||'-'||coalesce(nullif(p->>'numeroDossier',''),'ancien-'||coalesce(p->>'dateDepot','sans-date'));$b$);
d:=replace(d,$a$jsonb_array_elements(coalesce(p->'decoupageInitial','[]'))$a$,$b$jsonb_array_elements(CASE WHEN jsonb_typeof(p->'decoupageInitial')='array' THEN p->'decoupageInitial' ELSE '[]'::jsonb END)$b$);
d:=replace(d,$a$'Accord tacite au bénéfice de '||(p->>'demandeur')||' pour '||t.building_id||' ('||(p->>'palierDemande')||').'$a$,$b$'Accord tacite au bénéfice de '||coalesce(nullif(p->>'demandeur',''),'un demandeur')||' pour '||coalesce(t.building_id,'un terrain')||coalesce(' ('||(p->>'palierDemande')||')','')||'.'$b$);
d:=replace(d,$a$  reception:=public.objet_sas_deposer$a$,$b$  IF coalesce(p->>'demandeur','')<>'' THEN
  reception:=public.objet_sas_deposer$b$);
d:=replace(d,$a$  p:=p||jsonb_build_object('statut','valide'$a$,$b$  END IF;
  p:=p||jsonb_build_object('statut','valide'$b$);
EXECUTE d;ELSIF h IS DISTINCT FROM '0143427899abed11a40009211d3b7f4e' THEN RAISE EXCEPTION 'definition_non_examinee: terrain_permis_instruction_jour archives';END IF;END;$g$;
COMMIT;
