-- Banc d'intégration autonome du Pavillon sur PostgreSQL jetable.
-- Aucune donnée ni secret de production. Les primitives externes sont simulées,
-- le code complet du Pavillon est celui de la migration réellement proposée.
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE anon NOLOGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE public.personnages_donnees (
 name text PRIMARY KEY,country text,current_city text,current_building text,current_room text,
 poste jsonb,poste_depute jsonb,pa integer DEFAULT 5,pa_repos_le date
);
CREATE TABLE public.postes_attribues (
 titulaire text, country text,poste_id text,city text, updated_at timestamptz DEFAULT now()
);
CREATE TABLE public.ambassades_ouvertes (
 pays_hote text,empire text,data jsonb
);
CREATE TABLE public.cycles_electoraux (
 id text,data jsonb
);
CREATE TABLE public.caisses_batiments(id text PRIMARY KEY,data jsonb);
CREATE TABLE public.salaires_caisses(poste_id text,motif text);
CREATE TABLE public.locaux_loyers_referentiel(batiment text,piece text,louable boolean);
INSERT INTO public.locaux_loyers_referentiel(batiment,piece,louable) VALUES
 ('pavillon-ambassadeurs-novomirsk','suite_parti',true),
 ('pavillon-ambassadeurs-novomirsk','suite_privee',true),
 ('pavillon-ambassadeurs-novomirsk','suite_presidentielle',true);

CREATE OR REPLACE FUNCTION public.mon_personnage() RETURNS text LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('pavillon.test_acteur',true),'') $$;
CREATE OR REPLACE FUNCTION public.exiger_acteur(p text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF p IS DISTINCT FROM public.mon_personnage() THEN RAISE EXCEPTION 'acteur'; END IF; END $$;
CREATE OR REPLACE FUNCTION public.salaire_caisse_de(p_poste_id text,p_pays text,p_ville text)
RETURNS text LANGUAGE sql STABLE AS $$
 SELECT id FROM public.caisses_batiments
 WHERE id = p_pays||'_gouvernement-'||p_poste_id LIMIT 1 $$;
CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement(
 p_id text,p_delta numeric,p_exiger_existant boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE sol numeric;
BEGIN
 SELECT (data->>'solde')::numeric INTO sol FROM public.caisses_batiments WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','caisse_absente'); END IF;
 IF sol+p_delta<0 THEN RETURN jsonb_build_object('ok',false,'raison','solde_insuffisant'); END IF;
 UPDATE public.caisses_batiments SET data=jsonb_build_object('solde',sol+p_delta) WHERE id=p_id;
 RETURN jsonb_build_object('ok',true);
END $$;
CREATE OR REPLACE FUNCTION public.pa_repos_nocturne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $function$
DECLARE c_pa_max constant integer := 30;
 v_pa integer; v_deja date; v_jour date:=(now() AT TIME ZONE 'Europe/Paris')::date;
 v_nouveau integer; v_gain integer:=12; v_bonus integer:=0;
BEGIN
 PERFORM public.exiger_acteur(p_acteur);
 SELECT pa,pa_repos_le INTO v_pa,v_deja FROM public.personnages_donnees
 WHERE name=p_acteur FOR UPDATE;
 IF v_deja >= v_jour THEN RETURN jsonb_build_object('ok',false,'raison','deja_repose'); END IF;
  IF true THEN
    v_nouveau := least(c_pa_max, greatest(0, v_pa + v_gain + v_bonus));
  END IF;

  UPDATE public.personnages_donnees SET pa=v_nouveau,pa_repos_le=v_jour WHERE name=p_acteur;
 RETURN jsonb_build_object('ok',true,'pa',v_nouveau);
END;
$function$;

\i migrations/20261111205000_pavillon_diplomatique_baux.sql

INSERT INTO public.caisses_batiments VALUES
 ('republic_gouvernement-min_def','{"solde":30000}'),
 ('soviet_palais-gouvernement','{"solde":0}');
INSERT INTO public.personnages_donnees(name,country,current_city,current_building,current_room,poste,pa)
VALUES
 ('ministre','soviet','capitale','pavillon-ambassadeurs-novomirsk','suite_privee',
  '{"id":"min_def"}',5),
 ('visiteur','soviet','capitale','pavillon-ambassadeurs-novomirsk','suite_presidentielle',
  NULL,5);
INSERT INTO public.postes_attribues(titulaire,country,poste_id) VALUES ('ministre','republic','min_def');

GRANT USAGE ON SCHEMA public TO authenticated,anon;
CREATE OR REPLACE FUNCTION public.pavillon_test_solde(p_id text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
AS $solde$ SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id=p_id $solde$;
GRANT EXECUTE ON FUNCTION public.pavillon_test_solde(text) TO authenticated;

GRANT SELECT ON public.personnages_donnees TO authenticated;
SELECT set_config('pavillon.test_acteur','ministre',false);
SET ROLE authenticated;
DO $checks$
DECLARE r jsonb; req uuid:='11111111-1111-4111-8111-111111111111'; a numeric; b numeric;
BEGIN
 r:=public.pavillon_etat();
 IF r->>'ok' <> 'true' OR r->>'autorisation'<>'true' OR (r->>'prix_jour')::int <> 650 THEN
  RAISE EXCEPTION 'lecture de la suite: %',r; END IF;
 r:=public.pavillon_acte(req,'reserver','suite_privee');
 IF r->>'ok'<>'true' OR (r->>'montant')::int<>4550 THEN RAISE EXCEPTION 'location: %',r; END IF;
 r:=public.pavillon_acte(req,'reserver','suite_privee');
 IF r->>'rejeu'<>'true' THEN RAISE EXCEPTION 'rejeu non idempotent: %',r; END IF;
 r:=public.pavillon_acte(gen_random_uuid(),'reserver','suite_privee');
 IF r->>'raison'<>'suite_occupee' THEN RAISE EXCEPTION 'double signature: %',r; END IF;
 a:=public.pavillon_test_solde('republic_gouvernement-min_def');
 b:=public.pavillon_test_solde('soviet_palais-gouvernement');
 IF a<>25450 OR b<>4550 THEN RAISE EXCEPTION 'caisses incoherentes %, %',a,b; END IF;
 r:=public.pa_repos_nocturne('ministre');
 IF r->>'ok'<>'true' OR (r->>'pa')::int<>20 THEN RAISE EXCEPTION 'bonus sommeil: %',r; END IF;
 r:=public.pa_repos_nocturne('ministre');
 IF r->>'raison'<>'deja_repose' THEN RAISE EXCEPTION 'double sommeil: %',r; END IF;
 r:=public.pavillon_acte(gen_random_uuid(),'renouveler','suite_privee');
 IF r->>'ok'<>'true' OR (r->>'montant')::int<>4550 THEN RAISE EXCEPTION 'renouvellement: %',r; END IF;
 r:=public.pavillon_acte(gen_random_uuid(),'resilier','suite_privee');
 IF r->>'ok'<>'true' OR (r->>'montant')::int<>650 THEN RAISE EXCEPTION 'resiliation: %',r; END IF;
 r:=public.pavillon_acte(gen_random_uuid(),'resilier','suite_privee');
 IF r->>'raison'<>'bail_non_titulaire' THEN RAISE EXCEPTION 'menage facture 2 fois: %',r; END IF;
END $checks$;
RESET ROLE;

UPDATE public.personnages_donnees SET current_room='salle_reception' WHERE name='ministre';
SET ROLE authenticated;
DO $checks$
DECLARE r jsonb; a numeric; b numeric;
BEGIN
 r:=public.pavillon_acte(gen_random_uuid(),'reception','salle_reception');
 IF r->>'ok'<>'true' OR r->>'devise'<>'PSK' OR (r->>'montant')::int<>1500 THEN
  RAISE EXCEPTION 'reception: %',r; END IF;
 r:=public.pavillon_acte(gen_random_uuid(),'reception','salle_reception');
 IF r->>'raison'<>'reception_deja_reservee' THEN RAISE EXCEPTION 'double reception: %',r; END IF;
 a:=public.pavillon_test_solde('republic_gouvernement-min_def');
 b:=public.pavillon_test_solde('soviet_palais-gouvernement');
 IF a<>18750 OR b<>11250 THEN RAISE EXCEPTION 'caisses finales incoherentes %, %',a,b; END IF;
END $checks$;
RESET ROLE;

SELECT set_config('pavillon.test_acteur','visiteur',false);
SET ROLE authenticated;
DO $checks$
DECLARE r jsonb;
BEGIN
 r:=public.pavillon_acte(gen_random_uuid(),'reserver','suite_presidentielle');
 IF r->>'raison'<>'dignitaire_etranger_requis' THEN
  RAISE EXCEPTION 'non dignitaire accepte: %',r; END IF;
END $checks$;
RESET ROLE;
DO $checks$
BEGIN
 IF has_table_privilege('authenticated','public.pavillon_baux','INSERT')
    OR has_table_privilege('anon','public.pavillon_baux','SELECT')
    OR has_function_privilege('anon','public.pavillon_acte(uuid,text,text)','EXECUTE') THEN
  RAISE EXCEPTION 'droits trop ouverts'; END IF;
END $checks$;
DO $checks$
BEGIN
 IF EXISTS(SELECT 1 FROM public.locaux_loyers_referentiel
           WHERE batiment='pavillon-ambassadeurs-novomirsk' AND louable) THEN
  RAISE EXCEPTION 'ancien guichet générique encore ouvert'; END IF;
END $checks$;
SELECT 'BANC PAVILLON VERT' AS conclusion;
