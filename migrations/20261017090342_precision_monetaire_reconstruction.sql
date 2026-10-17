-- NON DEPLOYEE. Catalogue vivant et audit des donnees obligatoires avant application.
-- Montants en FRANCS, jamais *100 ni /100. Aucun arrondi des donnees historiques.
BEGIN;
DO $garde$
BEGIN
 IF EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtenabled <> 'D') THEN
  RAISE EXCEPTION 'precision: declencheurs DDL actifs a examiner';
 END IF;
 IF to_regtype('public.hg_francs_exacts') IS NOT NULL THEN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_constraint c ON c.contypid=t.oid
   WHERE t.oid='public.hg_francs_exacts'::regtype AND t.typtype='d'
   AND t.typbasetype='numeric'::regtype AND c.conname='hg_francs_centime'
   AND obj_description(t.oid,'pg_type')='HG francs exacts v1') THEN
   RAISE EXCEPTION 'precision: domaine preexistant incompatible';
  END IF;
 ELSE
  CREATE DOMAIN public.hg_francs_exacts AS numeric
   CONSTRAINT hg_francs_centime CHECK (
    VALUE IS NULL OR (VALUE::text NOT IN ('NaN','Infinity','-Infinity') AND VALUE=trunc(VALUE,2)));
  COMMENT ON DOMAIN public.hg_francs_exacts IS 'HG francs exacts v1';
 END IF;
END;
$garde$;

CREATE OR REPLACE FUNCTION public.hg_fr_lire(p_montant jsonb)
RETURNS numeric LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $function$
DECLARE v text;
BEGIN
 IF p_montant IS NULL OR jsonb_typeof(p_montant)<>'string' THEN
  RAISE EXCEPTION 'montant_chaine_requise' USING ERRCODE='22023';
 END IF;
 v:=p_montant#>>'{}';
 IF v !~ '^-?(0|[1-9][0-9]*)(\.[0-9]{1,2})?$' THEN
  RAISE EXCEPTION 'montant_centime_requis' USING ERRCODE='22023';
 END IF;
 RETURN v::public.hg_francs_exacts;
END;
$function$;
-- Le formatteur gere aussi les valeurs negatives entre -1 et 0.
CREATE OR REPLACE FUNCTION public.hg_fr_texte(p_montant numeric)
RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $function$
DECLARE v numeric:=p_montant::public.hg_francs_exacts;
BEGIN
 IF v IS NULL THEN RETURN NULL; END IF;
 RETURN CASE WHEN v<0 THEN '-' ELSE '' END || trunc(abs(v))::text
   || '.' || lpad((abs(v*100)%100)::integer::text,2,'0');
END;
$function$;

-- Memorise les proprietes REELLES de la vue, jamais celles supposees du baseline.
-- DROP RESTRICT : toute dependance non prevue interrompt et annule la migration.
CREATE TEMP TABLE hg_vue_financiere ON COMMIT DROP AS
 SELECT c.oid, c.relname, pg_get_viewdef(c.oid,true) AS definition,
 c.reloptions, c.relowner, c.relacl, obj_description(c.oid,'pg_class') AS commentaire
 FROM pg_class c WHERE c.oid='public.personnages'::regclass AND c.relkind='v';
CREATE TEMP TABLE hg_vue_triggers ON COMMIT DROP AS
 SELECT pg_get_triggerdef(t.oid,true) AS definition, t.tgname, t.tgenabled,
 obj_description(t.oid,'pg_trigger') AS commentaire
 FROM pg_trigger t WHERE t.tgrelid='public.personnages'::regclass AND NOT t.tgisinternal;
CREATE TEMP TABLE hg_vue_colonnes ON COMMIT DROP AS
 SELECT a.attname,a.attacl,col_description(a.attrelid,a.attnum) AS commentaire
 FROM pg_attribute a WHERE a.attrelid='public.personnages'::regclass AND a.attnum>0 AND NOT a.attisdropped;
DO $conversion$
DECLARE r record; v record; a record; n text; droits text; cible text;
BEGIN
 IF (SELECT count(*) FROM hg_vue_financiere)<>1 THEN RAISE EXCEPTION 'personnages doit etre une vue'; END IF;
 IF EXISTS(SELECT 1 FROM hg_vue_triggers WHERE tgenabled<>'O') THEN
  RAISE EXCEPTION 'precision: etat de trigger de vue non standard a examiner';
 END IF;
 -- Les dependances supplementaires devront etre examinees, jamais detruites en CASCADE.
 DROP VIEW public.personnages RESTRICT;
 FOR r IN SELECT * FROM (VALUES
  ('personnages_donnees','arg'),('personnages_donnees','liquide'),('personnages_donnees','banque'),
  ('comptes_bancaires','solde'),('placements_bancaires','montant'),('placements_bancaires','montant_final'),
  ('prets','montant_initial'),('prets','montant_restant'),('prets','mensualite'),
  ('dons_en_attente','montant'),('dons_requetes','montant')) AS t(tab,col)
 LOOP
  -- Le cast refuse une fraction de centime, NaN ou Infinity. Le DDL est transactionnel.
  EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I TYPE public.hg_francs_exacts USING %I::public.hg_francs_exacts',r.tab,r.col,r.col);
 END LOOP;
 SELECT * INTO v FROM hg_vue_financiere;
 EXECUTE 'CREATE VIEW public.personnages AS '||v.definition;
 IF v.reloptions IS NOT NULL THEN
  EXECUTE 'ALTER VIEW public.personnages SET ('||array_to_string(v.reloptions,',')||')';
 END IF;
 EXECUTE format('ALTER VIEW public.personnages OWNER TO %I',pg_get_userbyid(v.relowner));
 REVOKE ALL ON public.personnages FROM PUBLIC;
 FOR a IN SELECT * FROM aclexplode(coalesce(v.relacl,acldefault('r',v.relowner))) LOOP
  cible:=CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(a.grantee)) END;
  EXECUTE 'GRANT '||a.privilege_type||' ON public.personnages TO '||cible||CASE WHEN a.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END;
 END LOOP;
 EXECUTE format('COMMENT ON VIEW public.personnages IS %L',v.commentaire);
 FOR r IN SELECT * FROM hg_vue_colonnes LOOP
  EXECUTE format('COMMENT ON COLUMN public.personnages.%I IS %L',r.attname,r.commentaire);
  FOR a IN SELECT * FROM aclexplode(r.attacl) LOOP
   cible:=CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(a.grantee)) END;
   EXECUTE format('GRANT %s (%I) ON public.personnages TO %s%s',a.privilege_type,r.attname,cible,CASE WHEN a.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
  END LOOP;
 END LOOP;
 FOR r IN SELECT * FROM hg_vue_triggers LOOP
  EXECUTE r.definition;
  EXECUTE format('COMMENT ON TRIGGER %I ON public.personnages IS %L',r.tgname,r.commentaire);
 END LOOP;
END;
$conversion$;
REVOKE ALL ON FUNCTION public.hg_fr_lire(jsonb), public.hg_fr_texte(numeric) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hg_fr_lire(jsonb), public.hg_fr_texte(numeric) TO authenticated,service_role;
COMMIT;
