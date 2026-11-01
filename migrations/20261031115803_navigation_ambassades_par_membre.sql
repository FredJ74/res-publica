-- #219 : factoriser la porte de Claude sans changer audience, asile ou identité.
-- Source examinée : 20261025020100 ; refuse tout autre corps vivant au prévol.
DO $prevol$
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.ambassade_acces_bureau(text)'::regprocedure)
 NOT IN ('14570faf0fea2f7ec37177f9fcd0db52','13cd745954f05b293ae7117390e24506') THEN
  RAISE EXCEPTION 'ambassade_acces_vivant_non_examine'; END IF;
 IF to_regprocedure('public.ambassade_acces_bureau_interne(text,text)') IS NOT NULL AND
 (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.ambassade_acces_bureau_interne(text,text)'))<>'6b633368af4b0eb95a0dcf83238c1ed9' THEN
  RAISE EXCEPTION 'ambassade_acces_interne_non_examine'; END IF;
END $prevol$;
CREATE OR REPLACE FUNCTION public.ambassade_acces_bureau_interne(p_empire text, p_nom text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_expire timestamptz;
BEGIN
  v_moi := p_nom;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF public.ambassade_identite(p_empire) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
              WHERE a.pays_hote = v_pays AND a.empire = p_empire
                AND a.data ->> 'ambassadeur' = v_moi) THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'ambassadeur');
  END IF;
  PERFORM public.ambassades_asiles_echoir(v_moi);
  IF public.ambassade_refuge_de(v_moi) = p_empire THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'refugie');
  END IF;
  PERFORM public.ambassades_audiences_echoir(v_moi);
  SELECT expire_le INTO v_expire FROM public.ambassades_audiences
   WHERE demandeur = v_moi AND empire = p_empire AND statut = 'accordee' AND expire_le > now();
  IF v_expire IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'audience', 'expire_le', v_expire);
  END IF;
  RETURN jsonb_build_object('ok', false, 'raison', 'sur_audience');
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_acces_bureau_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.ambassade_acces_bureau(p_empire text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT public.ambassade_acces_bureau_interne(p_empire,public.mon_personnage());
$g$;
-- ACL de la porte publique préservées par CREATE OR REPLACE.
DO $navigation$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
 a:=' OR (p_batiment=''quartier-ambassades'' AND p_piece IN (''bureau_al_khalija'',''bureau_sovarka'',''bureau_el_estado''))';
 b:=' /* navigation_acces_ambassade_par_membre_v1 */';
 IF position(b IN s)>0 THEN RETURN; END IF;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'navigation_acces_ambassade_ancre_absente'; END IF;
 s:=replace(s,a,b);
 a:=' IF l.ferme THEN';
 b:=' IF p_batiment=''quartier-ambassades'' AND p_piece IN (''bureau_al_khalija'',''bureau_sovarka'',''bureau_el_estado'') THEN'
 ||chr(10)||'  r:=public.ambassade_acces_bureau_interne(CASE p_piece WHEN ''bureau_al_khalija'' THEN ''khalija'' WHEN ''bureau_sovarka'' THEN ''soviet'' ELSE ''narco'' END,p_nom);'
 ||chr(10)||'  IF NOT coalesce((r->>''ok'')::boolean,false) THEN RETURN r; END IF;'
 ||chr(10)||' END IF;'||chr(10)||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'navigation_acces_ambassade_verdict_absent'; END IF;
 EXECUTE replace(s,a,b);
END $navigation$;
