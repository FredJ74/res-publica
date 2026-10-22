-- #69 : branche du reglement commun, sous-transaction et marqueur existants.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_succession_regler_interne(text,jsonb,text)');IF h IS NOT NULL AND h NOT IN('58e4ca34f2a70cddc5673002dfa60721') THEN RAISE EXCEPTION 'definition_non_examinee: coffre_succession_regler_interne(text,jsonb,text)';END IF;
END $g$;
CREATE OR REPLACE FUNCTION public.coffre_succession_regler_interne(p_dossier text,p_disposition jsonb,p_beneficiaire text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE origine public.coffres_sources_successorales;c public.coffres_bancaires;heir public.personnages_donnees;r jsonb;
BEGIN
 SELECT * INTO origine FROM public.coffres_sources_successorales WHERE coffre=(p_disposition->>'id')::uuid AND dossier=p_dossier;
 IF NOT FOUND THEN RAISE EXCEPTION 'coffre_origine_successorale_absente';END IF;
 IF EXISTS(SELECT 1 FROM public.personnages_donnees WHERE id=origine.defunt_id) THEN RAISE EXCEPTION 'defunt_pas_supprime';END IF;
 IF p_beneficiaire IS NOT NULL THEN SELECT * INTO heir FROM public.personnages_donnees WHERE name=p_beneficiaire AND id::text=(SELECT e->>'beneficiaire_id' FROM jsonb_array_elements(p_disposition->'chaine') e WHERE e->>'beneficiaire'=p_beneficiaire AND e->>'reponse'='accepte' ORDER BY e->>'repondu_le' DESC LIMIT 1) FOR UPDATE;END IF;
 SELECT * INTO c FROM public.coffres_bancaires WHERE id=origine.coffre FOR UPDATE;
 IF NOT FOUND OR c.titulaire_id IS DISTINCT FROM origine.defunt_id OR c.succession_id IS DISTINCT FROM p_dossier THEN RAISE EXCEPTION 'coffre_titre_successoral_modifie';END IF;
 PERFORM 1 FROM public.locations_actives WHERE id=c.bail_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'contrat_coffre_absent';END IF;
 IF heir.id IS NOT NULL THEN
  UPDATE public.coffres_bancaires SET titulaire_id=heir.id,succession_id=NULL,revision=revision+1 WHERE id=c.id;
  UPDATE public.locations_actives SET data=data||jsonb_build_object('locataire',heir.name,'locataireRef','pj:'||heir.name) WHERE id=c.bail_id;
 ELSE
  -- Absence d'heritier recevable : destruction expresse validee #69. Aucun passage en inventaire.
  DELETE FROM public.coffres_bancaires WHERE id=c.id;
  r:=public.terminer_bail(c.bail_id,'succession_sans_heritier',origine.defunt_nom,0);
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'bail_coffre_non_termine';END IF;
 END IF;
END $f$;
REVOKE ALL ON FUNCTION public.coffre_succession_regler_interne(text,jsonb,text) FROM PUBLIC,anon,authenticated,service_role;
DO $p$ DECLARE h text;s text;BEGIN
 SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.succession_regler(text)');
 IF h IN('f8c0193cc9618943706b9a3dc03b7434','92eed313b268bfb297526ef516191e94') THEN
  s:=replace(s,$a$'terrain','entreprise','argent'$a$,$b$'terrain','entreprise','argent','coffre'$b$);
  s:=replace(s,$a$      ELSIF (v_d ->> 'type') = 'argent' AND$a$,$b$      ELSIF (v_d ->> 'type') = 'coffre' THEN
        PERFORM public.coffre_succession_regler_interne(s.id,v_d,v_benef);
      ELSIF (v_d ->> 'type') = 'argent' AND$b$);
  EXECUTE s;
 ELSIF h IS DISTINCT FROM 'de6d5ca9783d2dbb4dcd38b34a064881' THEN RAISE EXCEPTION 'succession_definition_non_examinee:%',h;END IF;
END $p$;
COMMIT;
