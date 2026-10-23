-- PREPAREE UNIQUEMENT. Enveloppe l'unique moteur existant, sans recopier le déplacement.
-- Le catalogue vivant doit être examiné et son md5(prosrc) fourni par l'agent de déploiement
-- dans hg.prevol.rue_position_md5. Aucun mécanisme de déplacement alternatif.
BEGIN;
DO $g$
DECLARE f record; h text; moteur regprocedure:=to_regprocedure('public.rue_position_enregistrer_moteur_20261021(text)');
BEGIN
 SELECT p.*,r.rolname proprietaire INTO f FROM pg_proc p JOIN pg_roles r ON r.oid=p.proowner
  WHERE p.oid=to_regprocedure('public.rue_position_enregistrer(text)');
 IF NOT FOUND THEN RAISE EXCEPTION 'catalogue_vivant_requis: rue_position_enregistrer'; END IF;
 IF moteur IS NULL THEN
   IF f.prorettype<>'jsonb'::regtype OR NOT f.prosecdef OR f.pronargs<>1
     OR f.proargnames IS DISTINCT FROM ARRAY['p_noeud']::text[] THEN
     RAISE EXCEPTION 'contrat_rue_non_examine';
   END IF;
   IF nullif(current_setting('hg.prevol.rue_position_md5',true),'') IS DISTINCT FROM md5(f.prosrc) THEN
     RAISE EXCEPTION 'prevol_rue_md5_requis';
   END IF;
   ALTER FUNCTION public.rue_position_enregistrer(text) RENAME TO rue_position_enregistrer_moteur_20261021;
 ELSE
   -- Un rejeu ne doit jamais envelopper une fonction remplacée à notre insu.
   IF md5(f.prosrc)<>'2f30ddcd216cbf9355c4fe6d31d8ab83' THEN RAISE EXCEPTION 'garde_rue_modifiee'; END IF;
 END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.rue_position_enregistrer(p_noeud text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE nom text:=public.mon_personnage(); p public.personnages_donnees%rowtype;
BEGIN
 IF nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 -- Même verrou que l'application d'impact : refus avant tout appel du moteur et toute dépense.
 SELECT * INTO p FROM public.personnages_donnees WHERE name=nom FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable'); END IF;
 IF coalesce(p.hp,100)<=0 OR coalesce(p.hospitalisation->>'dateFinParis','')>
   (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN
   RETURN jsonb_build_object('ok',false,'raison','acteur_incapacite');
 END IF;
 RETURN public.rue_position_enregistrer_moteur_20261021(p_noeud);
END;
$function$;
REVOKE ALL ON FUNCTION public.rue_position_enregistrer_moteur_20261021(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.rue_position_enregistrer(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.rue_position_enregistrer(text) TO authenticated;
COMMIT;
