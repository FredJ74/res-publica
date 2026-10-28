-- #219 : prise/dépose/prêt/radio des soldats par les portes communes.
-- Préparation NON APPLIQUÉE. Décision Fred : groupes universels, 28/10/2026.
-- La position soldat est déjà au socle : projeter vers le blob, jamais l'inverse.
CREATE OR REPLACE FUNCTION public.pnj_groupes_verrouiller_projections_interne(p_ids text[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
BEGIN
 -- Les ordres historiques verrouillent compagnie puis soldats. Garder cet ordre
 -- AVANT les verrous PJ/PNJ des portes communes, y compris sur une liste mixte.
 PERFORM c.id FROM public.compagnies_militaires c WHERE c.id IN (
  SELECT sm.compagnie_id FROM public.pnj_soldats_metier sm
  JOIN public.pnj_membres m ON m.id=sm.pnj_id
  WHERE m.id=ANY(p_ids) AND m.famille='soldat') ORDER BY c.id FOR UPDATE;
END $g$;
REVOKE ALL ON FUNCTION public.pnj_groupes_verrouiller_projections_interne(text[]) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.pnj_groupes_projeter_interne(p_ids text[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE c record; verdict jsonb;
BEGIN
 IF EXISTS(SELECT 1 FROM public.pnj_membres m
  LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id=m.id
  LEFT JOIN public.compagnies_militaires cm ON cm.id=sm.compagnie_id
  WHERE m.id=ANY(p_ids) AND m.famille='soldat' AND cm.id IS NULL) THEN
  RAISE EXCEPTION 'soldat_projection_compagnie_absente'; END IF;
 FOR c IN SELECT DISTINCT sm.compagnie_id FROM public.pnj_soldats_metier sm
  JOIN public.pnj_membres m ON m.id=sm.pnj_id
  WHERE m.id=ANY(p_ids) AND m.famille='soldat' ORDER BY sm.compagnie_id LOOP
  verdict:=public.militaire_blob_projeter(c.compagnie_id);
  IF NOT coalesce((verdict->>'ok')::boolean,false) THEN
   RAISE EXCEPTION 'soldat_projection_refusee: %',verdict; END IF;
 END LOOP;
END $g$;
REVOKE ALL ON FUNCTION public.pnj_groupes_projeter_interne(text[]) FROM PUBLIC,anon,authenticated,service_role;

-- Le projecteur historique doit refléter la position commune de l'ancre et la rue.
-- La valeur projetée n'est pas une nouvelle autorité ; les miroirs socle la conservent.
DO $projection$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.militaire_blob_projeter(text)'::regprocedure);
 a:='''ville'', m.ville, ''buildingId'', m.building_id,';
 b:='''ville'', CASE WHEN m.leader_pj IS NULL THEN pe.ville END, ''buildingId'', CASE WHEN m.leader_pj IS NULL THEN pe.building_id END,';
 IF position('-- groupes_position_effective_v1' IN s)=0 THEN
  IF (length(s)-length(replace(s,a,'')))/length(a)<>2
   OR (length(s)-length(replace(s,'''roomId'', m.room_id, ''pa'', m.pa','')))/length('''roomId'', m.room_id, ''pa'', m.pa')<>2 THEN
   RAISE EXCEPTION 'projecteur_militaire_definition_non_examinee'; END IF;
  s:=replace(s,a,b);
  s:=replace(s,'''roomId'', m.room_id, ''pa'', m.pa',
    '''roomId'', CASE WHEN m.leader_pj IS NULL THEN pe.room_id END, ''rueNoeudId'', CASE WHEN m.leader_pj IS NULL THEN pe.rue_noeud_id END, ''pa'', m.pa');
  a:='ON m.id = p_compagnie || ''-'' || (sol->>''matricule''))';
  b:='ON m.id = p_compagnie || ''-'' || (sol->>''matricule'')'
   ||chr(10)||'               LEFT JOIN LATERAL public.pnj_position_effective(m.id) pe ON true)';
  IF position(a IN s)=0 THEN RAISE EXCEPTION 'projecteur_soldats_ancre_absente'; END IF;
  s:=replace(s,a,b);
  a:='ON m.id = p_compagnie || ''-'' || (r->>''matricule'');';
  b:='ON m.id = p_compagnie || ''-'' || (r->>''matricule'')'
   ||chr(10)||'    LEFT JOIN LATERAL public.pnj_position_effective(m.id) pe ON true;';
  IF position(a IN s)=0 THEN RAISE EXCEPTION 'projecteur_reserve_ancre_absente'; END IF;
  s:=replace(s,a,b);
  s:=replace(s,'BEGIN','BEGIN'||chr(10)||'  -- groupes_position_effective_v1');
  EXECUTE s;
 END IF;
END $projection$;

DO $portes$
DECLARE r record; s text; a text; b text; i integer; pos_fin integer;
BEGIN
 FOR r IN SELECT t.*,CASE WHEN signature='pnj_rappeler_radio(text)' THEN 'ids' WHEN signature='pnj_transferer(text[],text,boolean)' THEN 'p_ids' ELSE selection END AS projection FROM (VALUES
 ('pnj_prendre(text[])','p_ids','  PERFORM name FROM public.personnages_donnees WHERE name=v_moi FOR UPDATE;'),
 ('pnj_quitter_groupe(text[])','p_ids',' -- Même ordre de verrous que la prise/transmission : PJ puis PNJ triés.'),
 ('pnj_transferer(text[],text,boolean)','p_ids || CASE WHEN p_dest_est_pnj THEN ARRAY[p_dest] ELSE ARRAY[]::text[] END',' PERFORM name FROM public.personnages_donnees WHERE name=moi'),
 ('pnj_deployer_unite(text[],boolean)','p_pnj_ids',' SELECT * INTO v_lieu FROM public.personnages_donnees WHERE name=v_chef FOR UPDATE;'),
 ('pnj_rappeler_radio(text)','ARRAY(SELECT id FROM public.pnj_membres WHERE id=p_ancre OR leader_pnj_id=p_ancre)',
  ' SELECT * INTO lieu FROM public.personnages_donnees WHERE name=moi FOR UPDATE;')
 ) AS t(signature,selection,ancre) LOOP
  s:=pg_get_functiondef(('public.'||r.signature)::regprocedure);
  IF position('-- groupes_projection_portes_v1' IN s)>0 THEN CONTINUE; END IF;
  IF (length(s)-length(replace(s,r.ancre,'')))/length(r.ancre)<>1 THEN
   RAISE EXCEPTION 'porte_projection_ancre_inattendue: %',r.signature; END IF;
  b:=' -- groupes_projection_portes_v1'||chr(10)
   ||' PERFORM public.pnj_groupes_verrouiller_projections_interne('||r.selection||');'
   ||chr(10)||r.ancre;
  s:=replace(s,r.ancre,b);
  -- Uniquement le dernier verdict réussi, après toutes les mutations.
  SELECT max(x) INTO pos_fin FROM generate_series(1,length(s)) x
   WHERE substring(s from x) ~ '^RETURN jsonb_build_object\(''ok'',\s*true';
  IF pos_fin IS NULL THEN RAISE EXCEPTION 'porte_projection_verdict_absent: %',r.signature; END IF;
  a:='PERFORM public.pnj_groupes_projeter_interne('||r.projection||');'||chr(10)||' ';
  s:=overlay(s placing a from pos_fin for 0);
  EXECUTE s;
 END LOOP;
END $portes$;
-- Nouvelle règle universelle : seule la restriction métier contredite change.
-- Aucun axe ni autorité n'est détourné, aucune autre famille n'est ouverte.
UPDATE public.pnj_mouvement_individuel SET autorise=true,
 raison='groupes_universels_soldat',
 note='Fred 28/10/2026 : le soldat rejoint, se prête et se dépose par les portes communes ; autorité de section et projection militaire conservées.'
 WHERE famille='soldat';
