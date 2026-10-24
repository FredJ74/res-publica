-- Fixture fictive, annulee si executee seule ; decor extrait uniquement par le banc PostgreSQL jetable.
BEGIN;
-- HG_FIXTURE_DEBUT
-- Identites et monde exclusivement fictifs. Helpers d'identite simules ; moteurs charges a part.
CREATE ROLE anon; CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$
 SELECT nullif(current_setting('hg.uid',true),'')::uuid $$;
CREATE TABLE personnages_donnees(id uuid DEFAULT gen_random_uuid() PRIMARY KEY,name text UNIQUE,
 user_id uuid,country text,current_city text,current_building text,current_room text,
 day integer,pa integer,liquide integer,arg integer,inventory jsonb DEFAULT '[]',
 inventory_revision bigint DEFAULT 0,updated_at timestamptz);
CREATE TABLE comptes_bancaires(id text PRIMARY KEY,personnage text,banque text,solde numeric,updated_at timestamptz);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$
 SELECT name FROM public.personnages_donnees WHERE user_id=auth.uid() LIMIT 1 $$;
CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
 IF $1 IS DISTINCT FROM mon_personnage() THEN RAISE EXCEPTION 'identite'; END IF; END $$;
CREATE TABLE actions_tracables(id text PRIMARY KEY,auteur text,cible text,type_action text,country text,
 city text,jour integer,jour_expiration integer,created_at timestamptz DEFAULT now(),decouvert boolean DEFAULT false);
CREATE TABLE entrainements_football(id text PRIMARY KEY,personnage text,jour integer,stat text,cree_le timestamptz DEFAULT now());
CREATE TABLE rp_epoques(pays text,jour_un date);
CREATE TABLE ordres_couts(fn text,pa integer,cost integer);
CREATE TABLE ordres_couts_inconnus(fn text PRIMARY KEY,pa integer,cost integer,occurrences integer DEFAULT 1);
CREATE TABLE ordres_couts_ecarts(fn text,pa integer,cost integer,occurrences integer DEFAULT 1,vu_le timestamptz,UNIQUE(fn,pa,cost));
CREATE TABLE presidence_memoire_ordres(fn text,pa integer,cost integer,sujet text);
CREATE FUNCTION presidence_memoire_noter(text,text,text,text,jsonb,text) RETURNS void LANGUAGE sql AS $$ SELECT $$;
INSERT INTO personnages_donnees(name,user_id,country,current_city,current_building,current_room,day,pa,liquide,arg)
 VALUES('Fixture','00000000-0000-4000-8000-000000000001','republic','capitale','centre-artisanal','travees',1,30,70,270),
 ('Autre','00000000-0000-4000-8000-000000000002','republic','capitale','centre-artisanal','travees',1,30,70,270);
INSERT INTO comptes_bancaires VALUES('c1','Fixture','nationale',200,now()),('c2','Autre','nationale',200,now());
INSERT INTO ordres_couts VALUES('tenue_entrainement',2,0);
SET hg.uid='00000000-0000-4000-8000-000000000001';
SET request.path='/rpc/pnj_ced_acheter';

-- HG_FIXTURE_FIN
ROLLBACK;
