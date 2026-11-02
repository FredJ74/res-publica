-- #379 : même commande d'acquittement, désormais responsable de l'effet atomique.
-- Le contrat explicite évite qu'un nouveau client acquitte sans effet sur l'ancien serveur.
-- Aucun rattrapage ni acte PJ à l'installation. Aucune table privée lue par le prévol.
DO $prevol$ BEGIN
 IF to_regprocedure('public.impact_marquer_traite(text)') IS NULL OR (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.impact_marquer_traite(text)')) NOT IN ('da9be1d37343d17b4b5c1ec5bae250e6','47ce1255304f287b3d22a6903e253f11') THEN RAISE EXCEPTION '379_definition_non_examinee: public.impact_marquer_traite(text)'; END IF;
 IF to_regprocedure('public.hospitalisation_pa_epuises_declencheur()') IS NULL THEN RAISE EXCEPTION '379_hospitalisation_pa0_absente'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.personnages_donnees'::regclass AND tgname='trg_hospitalisation_pa_epuises' AND tgenabled IN ('O','A')) THEN RAISE EXCEPTION '379_declencheur_pa0_absent'; END IF;
 IF to_regprocedure('public.impact_marquer_traite(text,integer)') IS NOT NULL AND (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.impact_marquer_traite(text,integer)'))<>'23639320731ab7fbce8d33f686084061' THEN RAISE EXCEPTION '379_impact_versionne_deja_different'; END IF;
END $prevol$;

CREATE OR REPLACE FUNCTION public.impact_marquer_traite(p_id text,p_contrat integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $impact$
DECLARE
 -- hg379_impact_consommation_v1 : une file, un verrou de fiche, un effet et son acquittement.
 moi text; pj public.personnages_donnees%ROWTYPE; imp public.impacts_indices_attente%ROWTYPE;
 jauges jsonb; faibles jsonb; stats jsonb; jour text; applique boolean := true; n numeric;
BEGIN
 IF p_contrat IS DISTINCT FROM 1 THEN RETURN jsonb_build_object('ok',false,'raison','contrat_invalide'); END IF;
 moi := public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 SELECT * INTO pj FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent'); END IF;
 SELECT * INTO imp FROM public.impacts_indices_attente WHERE id=p_id AND victime=moi FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','impact_introuvable'); END IF;
 IF imp.traite IS TRUE THEN RETURN jsonb_build_object('ok',true,'contrat',1,'marques',0,'applique',false,'indice',imp.indice); END IF;
 IF imp.indice IN ('pop','inf','dis') THEN
   jauges := CASE WHEN jsonb_typeof(pj.resources)='object' THEN pj.resources ELSE '{}'::jsonb END;
   n := greatest(0,least(100,coalesce((jauges->>imp.indice)::numeric,CASE WHEN imp.indice='dis' THEN 50 ELSE 0 END)+imp.delta));
   UPDATE public.personnages_donnees SET resources=jsonb_set(jauges,ARRAY[imp.indice],to_jsonb(n)) WHERE name=moi;
 ELSIF imp.indice='moral_carte_postale' THEN
   -- Plafond expéditeur à la réception, jour réel Paris, distinct du plafond lecteur.
   IF imp.delta<>10 THEN RETURN jsonb_build_object('ok',false,'raison','impact_invalide'); END IF;
   jour := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;
   jauges := CASE WHEN jsonb_typeof(pj.carte_postale_moral_jour)='object' THEN pj.carte_postale_moral_jour ELSE '{}'::jsonb END;
   applique := jauges->>'expediteur' IS DISTINCT FROM jour;
   IF applique THEN
     UPDATE public.personnages_donnees SET moral=least(100,greatest(0,coalesce(moral,0)+10)),
       carte_postale_moral_jour=jsonb_set(jauges,'{expediteur}',to_jsonb(jour)) WHERE name=moi;
   END IF;
 ELSIF imp.indice='hp_set' THEN
   IF imp.delta NOT BETWEEN 0 AND 100 THEN RETURN jsonb_build_object('ok',false,'raison','impact_invalide'); END IF;
   -- Reprise de l'effet historique : deux caractéristiques, une seule fois au serveur.
   SELECT jsonb_object_agg(s,true) INTO faibles FROM (
     SELECT s FROM unnest(ARRAY['INT','CHA','VOL','PER','DUP','ENT']) s ORDER BY random() LIMIT 2) x;
   UPDATE public.personnages_donnees SET hp=imp.delta,pa=0,regen_jour=day,
     stats_affaiblies=coalesce(stats_affaiblies,'{}'::jsonb)||faibles WHERE name=moi;
   -- Le déclencheur pa0 déjà livré assure l'hospitalisation ; aucune téléportation parallèle.
 ELSIF imp.indice='poison_start' THEN
   IF imp.details IS NOT NULL AND jsonb_typeof(imp.details)<>'object' THEN RETURN jsonb_build_object('ok',false,'raison','impact_invalide'); END IF;
   stats := coalesce(imp.details->'statsTouchees','[]'::jsonb);
   IF jsonb_typeof(stats)<>'array' OR EXISTS(SELECT 1 FROM jsonb_array_elements(stats) s
       WHERE jsonb_typeof(s)<>'string' OR s#>>'{}' NOT IN ('INT','CHA','VOL','PER','DUP','ENT')) THEN
     RETURN jsonb_build_object('ok',false,'raison','impact_invalide'); END IF;
   SELECT coalesce(jsonb_object_agg(s#>>'{}',true),'{}'::jsonb) INTO faibles FROM jsonb_array_elements(stats) s;
   UPDATE public.personnages_donnees SET poison_actif=jsonb_build_object('actif',true,'palier',imp.palier,'poisonType',imp.details->>'poisonType'),
     stats_affaiblies=coalesce(stats_affaiblies,'{}'::jsonb)||faibles WHERE name=moi;
 ELSE
   -- Ne jamais consommer un type inconnu sans en avoir appliqué l'effet.
   RETURN jsonb_build_object('ok',false,'raison','indice_non_pris_en_charge');
 END IF;
 UPDATE public.impacts_indices_attente SET traite=true WHERE id=imp.id;
 RETURN jsonb_build_object('ok',true,'contrat',1,'marques',1,'applique',applique,'indice',imp.indice);
END;
$impact$;

CREATE OR REPLACE FUNCTION public.impact_marquer_traite(p_id text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $ancien$
 SELECT jsonb_build_object('ok',false,'raison','client_obsolete','contrat_requis',1);
$ancien$;

REVOKE ALL ON FUNCTION public.impact_marquer_traite(text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.impact_marquer_traite(text,integer) TO authenticated;
