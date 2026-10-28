-- Ne jamais remplacer une porte métier vivante différente du corps archivé examiné.
-- Empreintes de prosrc calculées depuis ces corps, pas le relevé global du baseline.
DO $prevol$
DECLARE r record; p record;
BEGIN
 FOR r IN SELECT * FROM (VALUES
 ('militaire_deposer_soldats(text,text,integer)','e4a5d169a3b0360c87434c58a97452d6','0f0625a217e96c312a1f94bdfe25d056'),
 ('militaire_recuperer_soldats(text,text,integer)','b6fc2e40db24547f23c603938469b44d','75ae0d3956076c294e09c5e796cbba56'),
 ('militaire_affecter_leader(text,text,integer,text)','31e7d4ecac7681f26e68be1c22eea016','2a0662cc1c638afd7161eaf8c4184ae8')
 ) t(signature,ancienne,nouvelle) LOOP
  SELECT prosrc,prosecdef,prorettype INTO p FROM pg_proc
   WHERE oid=('public.'||r.signature)::regprocedure;
  IF NOT p.prosecdef OR p.prorettype<>'jsonb'::regtype
   OR md5(p.prosrc) NOT IN (r.ancienne,r.nouvelle) THEN
   RAISE EXCEPTION 'ordre_militaire_definition_non_examinee: %',r.signature; END IF;
 END LOOP;
END $prevol$;

-- #219 : conserver les interfaces historiques par nombre, déléguer les actes
-- aux portes universelles. Aucune écriture de position dans ces trois adaptateurs.
CREATE OR REPLACE FUNCTION public.militaire_deposer_soldats(p_compagnie_id text,p_section_id text,p_nb integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE g record; ids text[]; r jsonb; lieu record;
BEGIN
 SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id,p_section_id);
 IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison',g.o_raison); END IF;
 IF coalesce(p_nb,0)<=0 THEN RETURN jsonb_build_object('ok',false,'raison','nombre_invalide'); END IF;
 SELECT array_agg(t.id ORDER BY t.id) INTO ids FROM (
  SELECT m.id FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id=m.id
  WHERE sm.compagnie_id=p_compagnie_id AND sm.section_id=p_section_id
   AND m.statut='actif' AND m.leader_pj=g.o_moi ORDER BY m.id LIMIT p_nb FOR UPDATE OF m) t;
 IF coalesce(cardinality(ids),0)<>p_nb THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_assez_avec_vous','disponibles',coalesce(cardinality(ids),0)); END IF;
 r:=public.pnj_deployer_unite(ids,false);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r; END IF;
 SELECT current_city,current_building,current_room INTO lieu FROM public.personnages_donnees WHERE name=g.o_moi;
 RETURN r||jsonb_build_object('deposes',p_nb,'ville',lieu.current_city,'batiment',lieu.current_building,'piece',lieu.current_room);
END $g$;

CREATE OR REPLACE FUNCTION public.militaire_recuperer_soldats(p_compagnie_id text,p_section_id text,p_nb integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE g record; ids text[]; r jsonb;
BEGIN
 SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id,p_section_id);
 IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison',g.o_raison); END IF;
 IF coalesce(p_nb,0)<=0 THEN RETURN jsonb_build_object('ok',false,'raison','nombre_invalide'); END IF;
 SELECT array_agg(t.id ORDER BY t.id) INTO ids FROM (
  SELECT m.id FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id=m.id
  WHERE sm.compagnie_id=p_compagnie_id AND sm.section_id=p_section_id
   AND m.statut='actif' AND m.leader_pj IS NULL AND public.pnj_co_present(g.o_moi,m.id)
   ORDER BY m.id LIMIT p_nb FOR UPDATE OF m) t;
 IF coalesce(cardinality(ids),0)<>p_nb THEN
  RETURN jsonb_build_object('ok',false,'raison','effectif_insuffisant_ici','disponibles',coalesce(cardinality(ids),0)); END IF;
 r:=public.pnj_prendre(ids);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r; END IF;
 RETURN r||jsonb_build_object('recuperes',p_nb,'leader',g.o_moi);
END $g$;

CREATE OR REPLACE FUNCTION public.militaire_affecter_leader(p_compagnie_id text,p_section_id text,p_nb integer,p_leader text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE g record; ids text[]; r jsonb;
BEGIN
 SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id,p_section_id);
 IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison',g.o_raison); END IF;
 IF coalesce(p_nb,0)<=0 THEN RETURN jsonb_build_object('ok',false,'raison','nombre_invalide'); END IF;
 IF nullif(btrim(p_leader),'') IS NULL OR p_leader=g.o_moi THEN
  RETURN jsonb_build_object('ok',false,'raison','leader_invalide'); END IF;
 SELECT array_agg(t.id ORDER BY t.id) INTO ids FROM (
  SELECT m.id FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id=m.id
  WHERE sm.compagnie_id=p_compagnie_id AND sm.section_id=p_section_id
   AND m.statut='actif' AND m.leader_pj=g.o_moi ORDER BY m.id LIMIT p_nb FOR UPDATE OF m) t;
 IF coalesce(cardinality(ids),0)<>p_nb THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_assez_avec_vous','disponibles',coalesce(cardinality(ids),0)); END IF;
 -- La nouvelle décision autorise un chef non militaire : l'autorité sur les
 -- soldats reste celle du lieutenant ; pays et co-présence sont revérifiés.
 r:=public.pnj_transferer(ids,p_leader,false);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r; END IF;
 RETURN r||jsonb_build_object('affectes',p_nb,'leader',p_leader);
END $g$;
-- Ne plus produire une exception de contrainte en sélectionnant une ancre seule.
DO $unite$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.pnj_prendre(text[])'::regprocedure);
 a:='  FOR r IN SELECT id FROM public.pnj_membres';
 b:=$b$  -- groupes_selection_ancre_v1
  IF EXISTS(SELECT 1 FROM public.pnj_membres WHERE leader_pnj_id=ANY(p_ids) AND NOT id=ANY(p_ids)) THEN
   RETURN jsonb_build_object('ok',false,'raison','unite_incomplete'); END IF;
$b$||a;
 IF position('-- groupes_selection_ancre_v1' IN s)>0 THEN RETURN; END IF;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>2 THEN RAISE EXCEPTION 'prise_groupe_ancre_inconnue'; END IF;
 s:=overlay(s placing b from position(a IN s) for length(a));
 EXECUTE s;
END $unite$;
