-- #94 PREPAREE : dimensionnement serveur du reamenagement, pour le moteur commun.
BEGIN;
DO $garde$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_reamenagement_preparer_interne(jsonb,jsonb,text,text,integer)');IF h IS NOT NULL AND h NOT IN('1bdc5828999099391a4c16b5e7f19369') THEN RAISE EXCEPTION 'definition_non_examinee: chantier_reamenagement_preparer_interne(jsonb,jsonb,text,text,integer)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_besoin_jour_interne(jsonb,integer)');IF h IS NOT NULL AND h NOT IN('db2ff57c512261055adc54042a857c79') THEN RAISE EXCEPTION 'definition_non_examinee: chantier_besoin_jour_interne(jsonb,integer)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_reamenagement_livrer_plan_interne(jsonb,text,text)');IF h IS NOT NULL AND h NOT IN('0cabb657d9de1cf9f35307c282af27e4') THEN RAISE EXCEPTION 'definition_non_examinee: chantier_reamenagement_livrer_plan_interne(jsonb,text,text)';END IF;
END;$garde$;
CREATE OR REPLACE FUNCTION public.chantier_reamenagement_preparer_interne(p_etat jsonb,p_plan jsonb,p_pays text,p_batiment text,p_jour integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE cible jsonb;source jsonb:=coalesce(p_etat->'subdivisions','[]');a jsonb;b jsonb;plan jsonb:='[]';touches jsonb:='[]';operations jsonb:='[]';s numeric:=0;ecart numeric;total numeric;d numeric;prix jsonb;
BEGIN
 IF jsonb_typeof(p_etat->'chantier')='object' OR jsonb_typeof(p_etat->'chantierReamenagement')='object' OR coalesce(p_etat->>'niveau_construction','') NOT IN('commerce_premium','building') THEN RAISE EXCEPTION 'reamenagement_indisponible';END IF;
 cible:=public.chantier_plan_normaliser_interne(p_etat,p_etat->>'niveau_construction',p_plan);
 -- Meme difference de plans que le moteur navigateur : aucune facturation des simples libelles.
 FOR a IN SELECT value FROM jsonb_array_elements(source) LOOP
  SELECT value INTO b FROM jsonb_array_elements(cible) WHERE value->>'id'=a->>'id';
  ecart:=CASE WHEN b IS NULL THEN (a->>'surface')::numeric WHEN a->>'destination' IS DISTINCT FROM b->>'destination' THEN greatest((a->>'surface')::numeric,(b->>'surface')::numeric) ELSE abs((a->>'surface')::numeric-(b->>'surface')::numeric) END;
  IF ecart>0 THEN
   IF nullif(a->>'proprietaire','') IS NOT NULL AND a->>'proprietaire' IS DISTINCT FROM p_etat->>'proprietaire' THEN RAISE EXCEPTION 'lot_vendu';END IF;
   IF nullif(a->>'locataire','') IS NOT NULL OR EXISTS(SELECT 1 FROM public.locations_actives WHERE country=p_pays AND data->>'city'=p_etat->>'city' AND data->>'buildingId'=p_batiment AND (data->>'lotId'=a->>'id' OR data->>'roomId'='lot_dyn_'||regexp_replace(a->>'id','[^A-Za-z0-9_-]','_','g'))) THEN RAISE EXCEPTION 'local_occupe';END IF;
   s:=s+ecart;touches:=touches||jsonb_build_array(a->>'id');
   operations:=operations||jsonb_build_array(jsonb_build_object('id',a->>'id','surface',ecart,'operation',CASE WHEN b IS NULL THEN 'suppression' WHEN a->>'destination' IS DISTINCT FROM b->>'destination' THEN 'destination' WHEN (b->>'surface')::numeric>(a->>'surface')::numeric THEN 'agrandissement' ELSE 'reduction' END));
  END IF;
 END LOOP;
 FOR b IN SELECT value FROM jsonb_array_elements(cible) LOOP
  SELECT value INTO a FROM jsonb_array_elements(source) WHERE value->>'id'=b->>'id';
  IF a IS NULL THEN
   s:=s+(b->>'surface')::numeric;operations:=operations||jsonb_build_array(jsonb_build_object('id',b->>'id','surface',(b->>'surface')::numeric,'operation','creation'));plan:=plan||jsonb_build_array(b);
  ELSE
   -- Preserver l'identite et les metadonnees, surtout des lots non touches et loues.
   plan:=plan||jsonb_build_array(a||jsonb_build_object('surface',b->'surface','destination',b->'destination','label',b->'label'));
  END IF;
 END LOOP;
 IF s IS NULL OR s<=0 OR s::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'aucun_changement';END IF;
 total:=s*10;
 IF total<>trunc(total) THEN RAISE EXCEPTION 'francs_entiers_requis';END IF;
 d:=greatest(1,ceil(s/300));
 SELECT jsonb_object_agg(cle,ceil(prix_base*1.1)) INTO prix FROM public.ressources_economie WHERE cle IN('bois','minerai','metal') AND prix_base>=0;
 IF prix IS NULL OR (SELECT count(*) FROM jsonb_object_keys(prix))<>3 THEN RAISE EXCEPTION 'prix_indisponibles';END IF;
 RETURN jsonb_build_object('type','reamenagement','niveau',NULL,'jourDebut',p_jour,'planSource',source,'planCible',plan,'surfaceConcernee',s,'lotsConcernes',touches,'operations',operations,'surfaceLibreImmobilisee',s,'dureeJours',d,'coutTotal',total,'coutMateriaux',total*.3,'coutTravail',total*.7,'heuresTotales',total*.7/70,'totalVerse',total,'tresorerie',total,'stockMateriaux',jsonb_build_object('bois',0,'minerai',0,'metal',0),'prixAchatPJ',prix,'progressionJours',0,'heuresFaites',0,'jourTraite',(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text,'arrete',NULL,'evenements',jsonb_build_array(jsonb_build_object('cle','lancement','surfaceConcernee',s,'coutTotal',total,'dureeJours',d)),'travauxPJ','[]'::jsonb,'ventesMateriauxPJ','[]'::jsonb);
END;$f$;
CREATE OR REPLACE FUNCTION public.chantier_besoin_jour_interne(p_ch jsonb,p_num integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=public,pg_temp AS $f$
DECLARE r jsonb;BEGIN
 IF p_ch->>'type'='construction' THEN
  SELECT jsonb_build_object('bois',bois,'minerai',minerai,'metal',metal) INTO r FROM public.chantiers_besoins_jour WHERE position_cycle=((p_num-1)%(SELECT count(*) FROM public.chantiers_besoins_jour))+1;
 ELSIF p_ch->>'type'='reamenagement' THEN
  SELECT jsonb_object_agg(cle,floor(((p_ch->>'coutMateriaux')::numeric/(p_ch->>'dureeJours')::numeric/3/prix_base)+.5)) INTO r FROM public.ressources_economie WHERE cle IN('bois','minerai','metal') AND prix_base>0;
 END IF;
 IF r IS NULL OR (SELECT count(*) FROM jsonb_object_keys(r))<>3 THEN RAISE EXCEPTION 'besoin_chantier_absent';END IF;
 RETURN r;
END;$f$;
CREATE OR REPLACE FUNCTION public.chantier_reamenagement_livrer_plan_interne(p_etat jsonb,p_pays text,p_batiment text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE ch jsonb:=p_etat->'chantierReamenagement';cible jsonb;source jsonb;a jsonb;b jsonb;sortie jsonb:='[]';
BEGIN
 IF jsonb_typeof(ch) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'chantier_non_acheve';END IF;
 -- Le chantier n'efface jamais une ecriture immobiliere concurrente.
 FOR a IN SELECT value FROM jsonb_array_elements(ch->'planSource') LOOP
  SELECT value INTO source FROM jsonb_array_elements(coalesce(p_etat->'subdivisions','[]')) WHERE value->>'id'=a->>'id';
  IF source IS NULL OR source->'surface' IS DISTINCT FROM a->'surface' OR source->>'destination' IS DISTINCT FROM a->>'destination' THEN RAISE EXCEPTION 'lots_modifies_pendant_travaux';END IF;
  IF ch->'lotsConcernes' ? (a->>'id') THEN
   IF nullif(source->>'locataire','') IS NOT NULL OR EXISTS(SELECT 1 FROM public.locations_actives WHERE country=p_pays AND data->>'city'=p_etat->>'city' AND data->>'buildingId'=p_batiment AND (data->>'lotId'=a->>'id' OR data->>'roomId'='lot_dyn_'||regexp_replace(a->>'id','[^A-Za-z0-9_-]','_','g'))) THEN RAISE EXCEPTION 'local_occupe';END IF;
   IF source->>'proprietaire' IS DISTINCT FROM a->>'proprietaire' THEN RAISE EXCEPTION 'lot_vendu';END IF;
  END IF;
 END LOOP;
 IF jsonb_array_length(coalesce(p_etat->'subdivisions','[]'))<>jsonb_array_length(ch->'planSource') THEN RAISE EXCEPTION 'lots_modifies_pendant_travaux';END IF;
 cible:=public.chantier_plan_normaliser_interne(p_etat,p_etat->>'niveau_construction',ch->'planCible');
 FOR b IN SELECT value FROM jsonb_array_elements(cible) LOOP
  SELECT value INTO a FROM jsonb_array_elements(coalesce(p_etat->'subdivisions','[]')) WHERE value->>'id'=b->>'id';
  sortie:=sortie||jsonb_build_array(CASE WHEN a IS NULL THEN b ELSE a||jsonb_build_object('surface',b->'surface','destination',b->'destination','label',b->'label') END);
 END LOOP;
 RETURN sortie;
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_reamenagement_livrer_plan_interne(jsonb,text,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.chantier_reamenagement_preparer_interne(jsonb,jsonb,text,text,integer),public.chantier_besoin_jour_interne(jsonb,integer) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
