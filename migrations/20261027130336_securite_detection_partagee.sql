-- PREPAREE #135. Prevol vivant indispensable : patch exact du detecteur commun,
-- pas de remplacement aveugle par sa photographie historique. Aucun acteur deplace.
-- Depend de 20261027121000 et des tables/RPC du socle policier reellement installe.
BEGIN;
CREATE OR REPLACE FUNCTION public.securite_perception_groupe_interne(p_somme numeric,p_effectif integer,p_rue boolean)
RETURNS numeric LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $f$
 SELECT p_somme/nullif(p_effectif,0)+(p_effectif-1)-CASE WHEN p_rue THEN 2 ELSE 0 END;
$f$;
CREATE OR REPLACE FUNCTION public.securite_detection_calcul_interne(p_dis numeric,p_per numeric,p_jet double precision)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $f$
 SELECT p_jet>=greatest(10,least(90,50+5*(p_dis-p_per)));
$f$;
CREATE OR REPLACE FUNCTION public.securite_detection_jet_interne()
RETURNS double precision LANGUAGE sql VOLATILE SET search_path=public,pg_temp AS $f$
 SELECT random()*100;
$f$;
REVOKE ALL ON FUNCTION public.securite_perception_groupe_interne(numeric,integer,boolean),public.securite_detection_calcul_interne(numeric,numeric,double precision),public.securite_detection_jet_interne() FROM PUBLIC,anon,authenticated,service_role;

-- Une seule formule active : police ET agents prives deleguent aux memes primitives.
DO $p$ DECLARE s text;n text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.police_detection_verifier(text,text,text)'::regprocedure);
 IF position('public.securite_detection_calcul_interne' IN s)=0 THEN
 a:=$a$v_per:=v_per/v_count+(v_count-1)-CASE WHEN p_rue IS NOT NULL THEN 2 ELSE 0 END;$a$;
 b:=$b$v_per:=public.securite_perception_groupe_interne(v_per,v_count,p_rue IS NOT NULL);$b$;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'police_detection_perception_definition_non_examinee';END IF;
 n:=replace(s,a,b);
 a:=$a$v_chance:=greatest(10,least(90,50+5*(v_dis-v_per)));
 IF random()*100 < v_chance THEN$a$;
 b:=$b$IF NOT public.securite_detection_calcul_interne(v_dis,v_per,public.securite_detection_jet_interne()) THEN$b$;
 IF (length(n)-length(replace(n,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'police_detection_jet_definition_non_examinee';END IF;
 EXECUTE replace(n,a,b);
 END IF;
 IF has_table_privilege('authenticated','public.police_detection_attempts','SELECT,INSERT,UPDATE,DELETE')
 OR has_table_privilege('anon','public.police_detection_attempts','SELECT,INSERT,UPDATE,DELETE') THEN
 RAISE EXCEPTION 'registre_detection_modifiable';END IF;
 IF EXISTS(SELECT 1 FROM pg_attribute a WHERE a.attrelid='public.police_detection_attempts'::regclass AND a.attnum>0 AND NOT a.attisdropped
 AND (has_column_privilege('authenticated',a.attrelid,a.attname,'SELECT,INSERT,UPDATE') OR has_column_privilege('anon',a.attrelid,a.attname,'SELECT,INSERT,UPDATE'))) THEN
 RAISE EXCEPTION 'registre_detection_colonne_exposee';END IF;
END;$p$;
-- Etendre le registre commun ; aucune rencontre policiere fictive n'est creee.
DO $colonnes$ DECLARE r record;BEGIN
 FOR r IN SELECT * FROM (VALUES('securite_preuve','uuid'),('securite_agents','text[]'),('securite_detecte','boolean'),('securite_mandat','text')) v(nom,ty) LOOP
  IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.police_detection_attempts'::regclass AND attname=r.nom AND NOT attisdropped
    AND (atttypid<>r.ty::regtype OR col_description(attrelid,attnum) IS DISTINCT FROM 'HG securite detection v1')) THEN
   RAISE EXCEPTION 'registre_detection_colonne_inconnue: %',r.nom;END IF;
 END LOOP;
END;$colonnes$;
ALTER TABLE public.police_detection_attempts ADD COLUMN IF NOT EXISTS securite_preuve uuid,
 ADD COLUMN IF NOT EXISTS securite_agents text[],ADD COLUMN IF NOT EXISTS securite_detecte boolean,
 ADD COLUMN IF NOT EXISTS securite_mandat text;
COMMENT ON COLUMN public.police_detection_attempts.securite_preuve IS 'HG securite detection v1';
COMMENT ON COLUMN public.police_detection_attempts.securite_agents IS 'HG securite detection v1';
COMMENT ON COLUMN public.police_detection_attempts.securite_detecte IS 'HG securite detection v1';
COMMENT ON COLUMN public.police_detection_attempts.securite_mandat IS 'HG securite detection v1';

CREATE OR REPLACE FUNCTION public.chantier_vigiles_detecter(p_terrain text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text:=public.mon_personnage();p record;t record;precedent record;ids text[];somme numeric;nb integer;per numeric;dis numeric;detecte boolean;preuve uuid;
BEGIN
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT FOUND OR coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(acteur)) THEN
 RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
 PERFORM 1 FROM public.pnj_membres WHERE id IN(SELECT a.pnj_id FROM public.chantier_vigiles_affectations a JOIN public.terrains_etat tt ON tt.id=a.terrain_id
 WHERE tt.country=p.country AND (tt.id=p_terrain OR tt.building_id=p_terrain AND tt.data::jsonb->>'city'=p.current_city)) ORDER BY id FOR UPDATE;
 SELECT * INTO t FROM public.terrains_etat WHERE country=p.country AND
 (id=p_terrain OR building_id=p_terrain AND data::jsonb->>'city'=p.current_city) ORDER BY (id=p_terrain) DESC LIMIT 1 FOR UPDATE;
 IF NOT FOUND OR p.current_building IS DISTINCT FROM t.building_id OR p.current_room IS DISTINCT FROM 'terrain'
 OR p.current_city IS DISTINCT FROM t.data::jsonb->>'city' THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 -- Memes recherches opposables que le moteur policier, aucune poursuite inventee.
 IF NOT EXISTS(SELECT 1 FROM public.justice_recherches(acteur) j WHERE j.country=p.country) THEN
 RETURN jsonb_build_object('ok',true,'detecte',false,'raison','non_recherche');END IF;
 SELECT array_agg(v.pnj_id ORDER BY v.pnj_id),sum(m.car_per),count(*),count(m.car_per)
 INTO ids,somme,nb,per FROM public.chantier_vigiles_presents_interne(t.id) v JOIN public.pnj_membres m ON m.id=v.pnj_id;
 IF nb=0 THEN RETURN jsonb_build_object('ok',true,'detecte',false,'raison','aucun_agent_present');END IF;
 IF per<>nb THEN RETURN jsonb_build_object('ok',false,'raison','caracteristiques_non_confirmees');END IF;
 SELECT * INTO precedent FROM public.police_detection_attempts WHERE personnage=acteur AND country=p.country AND city=p.current_city
 AND building='@prive:'||t.id AND room='terrain' FOR UPDATE;
 IF FOUND THEN
  IF precedent.securite_detecte AND precedent.securite_agents=ids AND precedent.securite_mandat=t.data::jsonb->>'proprietaire'
  AND precedent.attempted_at>now()-interval '10 minutes' THEN
   RETURN jsonb_build_object('ok',true,'detecte',true,'preuve',precedent.securite_preuve,'rejeu',true);END IF;
  IF precedent.attempted_at>now()-interval '2 minutes' THEN
   RETURN jsonb_build_object('ok',true,'detecte',false,'raison','detection_deja_tentee');END IF;
 END IF;
 per:=public.securite_perception_groupe_interne(somme,nb,false);
 dis:=8+coalesce((p.resources->>'dis')::numeric,0)/10;
 detecte:=public.securite_detection_calcul_interne(dis,per,public.securite_detection_jet_interne());
 preuve:=CASE WHEN detecte THEN gen_random_uuid() END;
 INSERT INTO public.police_detection_attempts(personnage,country,city,building,room,attempted_at,securite_preuve,securite_agents,securite_detecte,securite_mandat)
 VALUES(acteur,p.country,p.current_city,'@prive:'||t.id,'terrain',now(),preuve,ids,detecte,t.data::jsonb->>'proprietaire')
 ON CONFLICT(personnage,country,city,building,room) DO UPDATE SET attempted_at=excluded.attempted_at,securite_preuve=excluded.securite_preuve,
 securite_agents=excluded.securite_agents,securite_detecte=excluded.securite_detecte,securite_mandat=excluded.securite_mandat;
 RETURN jsonb_build_object('ok',true,'detecte',detecte,'preuve',preuve);
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_vigiles_detecter(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.chantier_vigiles_detecter(text) TO authenticated;

-- Porte interne de preuve, reutilisable par l'adaptateur d'intervention commun.
-- Ce n'est PAS une autorisation de detention : aucune peine, fouille ou arrestation ici.
CREATE OR REPLACE FUNCTION public.chantier_vigiles_detection_confirmer_interne(p_terrain text,p_preuve uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text:=public.mon_personnage();p record;t record;d record;ids text[];
BEGIN
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 SELECT * INTO t FROM public.terrains_etat WHERE country=p.country AND
 (id=p_terrain OR building_id=p_terrain AND data::jsonb->>'city'=p.current_city) ORDER BY (id=p_terrain) DESC LIMIT 1;
 IF NOT FOUND OR p.current_building IS DISTINCT FROM t.building_id OR p.current_room IS DISTINCT FROM 'terrain'
 OR p.current_city IS DISTINCT FROM t.data::jsonb->>'city' THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 SELECT * INTO d FROM public.police_detection_attempts WHERE personnage=acteur AND country=p.country AND city=p.current_city
 AND building='@prive:'||t.id AND room='terrain' AND securite_preuve=p_preuve AND securite_detecte
 AND attempted_at>now()-interval '10 minutes' FOR UPDATE;
 IF NOT FOUND OR d.securite_mandat IS DISTINCT FROM t.data::jsonb->>'proprietaire' THEN
 RETURN jsonb_build_object('ok',false,'raison','detection_non_confirmee');END IF;
 SELECT array_agg(v.pnj_id ORDER BY v.pnj_id) INTO ids FROM public.chantier_vigiles_presents_interne(t.id) v;
 IF ids IS NULL OR ids IS DISTINCT FROM d.securite_agents
 OR NOT EXISTS(SELECT 1 FROM public.justice_recherches(acteur) j WHERE j.country=p.country) THEN
 RETURN jsonb_build_object('ok',false,'raison','prerogatives_non_confirmees');END IF;
 RETURN jsonb_build_object('ok',true,'preuve',p_preuve,'agents',ids,'autorite','securite_privee');
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_vigiles_detection_confirmer_interne(text,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
