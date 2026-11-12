-- PostgreSQL jetable UNIQUEMENT. Crée les substituts des dépendances publiques
-- pour exécuter la migration réelle sans aucune donnée de production.
DO $$ BEGIN
 IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
 IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role; END IF;
END $$;
CREATE TABLE public.personnages_donnees (
 name text PRIMARY KEY, country text, current_city text, current_building text,
 current_room text, pa_repos_le date, hospitalisation jsonb, est_emprisonne jsonb,
 liquide integer DEFAULT 500, arg integer DEFAULT 500,
 pa integer DEFAULT 10, hp integer DEFAULT 50, moral integer DEFAULT 50,
 updated_at timestamptz DEFAULT now()
);
CREATE TABLE public.locations_actives(id text PRIMARY KEY,country text,data jsonb);
CREATE OR REPLACE FUNCTION public.mon_personnage()
 RETURNS text LANGUAGE sql STABLE AS $$
 SELECT NULLIF(current_setting('banc.clinique_acteur',true),'');
 $$;
CREATE OR REPLACE FUNCTION public.helvetia_debiter_fonds_ordinaires(p_personnage text,p_montant numeric,p_priorite text)
 RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE v_liq integer;
BEGIN
 SELECT liquide INTO v_liq FROM public.personnages_donnees WHERE name=p_personnage FOR UPDATE;
 IF v_liq IS NULL OR v_liq<p_montant THEN RETURN false; END IF;
 UPDATE public.personnages_donnees SET liquide=liquide-p_montant,arg=arg-p_montant WHERE name=p_personnage;
 RETURN true;
END;$$;
INSERT INTO public.personnages_donnees(name,country,current_city,current_building,current_room,liquide,hp,moral,pa)
VALUES ('A','republic','capitale','clinique-privee','reception_clinique',500,40,30,10),
 ('B','republic','capitale','clinique-privee','reception_clinique',500,40,30,10),
 ('C','soviet','capitale','clinique-privee','reception_clinique',500,40,30,10),
 ('D','republic','capitale','clinique-privee','reception_clinique',500,40,30,10),
 ('E','republic','capitale','clinique-privee','reception_clinique',20,40,30,10),
 ('F','republic','capitale','clinique-privee','reception_clinique',500,40,30,10);
UPDATE public.personnages_donnees
 SET hospitalisation=jsonb_build_object('dateFinParis',(now() AT TIME ZONE 'Europe/Paris')::date + 3)
 WHERE name='D';
