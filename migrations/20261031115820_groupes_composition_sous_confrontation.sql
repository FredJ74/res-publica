-- #219 : changer de groupe/rappeler un PNJ n'est pas une porte de fuite.
-- Ni détection nouvelle ni sentence : seulement les confrontations existantes.
CREATE OR REPLACE FUNCTION public.groupe_confrontation_refus_interne(p_nom text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT jsonb_build_object('raison',x.raison) FROM (
  SELECT 'interception_en_cours'::text AS raison,0 AS priorite
  FROM public.groupe_participants_interne(p_nom) g
  JOIN public.police_interceptions i ON g.est_pj AND i.personnage=g.identifiant
  WHERE i.expires_at>now()
  UNION ALL
  SELECT 'combat_en_cours',1 FROM public.groupe_participants_interne(p_nom) g
  JOIN public.batailles_engagements e ON (g.est_pj AND e.personnage=g.identifiant)
   OR (NOT g.est_pj AND EXISTS(SELECT 1 FROM public.pnj_soldats_metier sm
       WHERE sm.pnj_id=g.identifiant AND (sm.compagnie_id,sm.section_id,sm.matricule)
       =(e.compagnie_id,e.section_id,e.matricule)))
  JOIN public.batailles b ON b.id=e.bataille_id
  WHERE b.statut='en_cours' AND e.sorti_round IS NULL
 ) x ORDER BY x.priorite LIMIT 1;
$g$;
REVOKE ALL ON FUNCTION public.groupe_confrontation_refus_interne(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.pnj_confrontation_refus_interne(p_ids text[])
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT jsonb_build_object('raison',x.raison) FROM (
  SELECT public.groupe_confrontation_refus_interne(m.leader_pj)->>'raison' AS raison
  FROM public.pnj_membres m WHERE m.id=ANY(p_ids) AND m.leader_pj IS NOT NULL
  UNION ALL
  SELECT 'interception_en_cours' FROM public.police_interceptions i
  CROSS JOIN LATERAL jsonb_array_elements_text(CASE WHEN jsonb_typeof(i.intervenants)='array' THEN i.intervenants ELSE '[]'::jsonb END) a(cle)
  WHERE i.expires_at>now() AND (substring(a.cle FROM 7)=ANY(p_ids) AND a.cle LIKE 'prive:%'
    OR public.police_pnj_id(i.country,i.city,a.cle)=ANY(p_ids))
  UNION ALL
  SELECT 'combat_en_cours' FROM public.batailles_engagements e
  JOIN public.batailles b ON b.id=e.bataille_id
  JOIN public.pnj_soldats_metier sm ON (sm.compagnie_id,sm.section_id,sm.matricule)
    =(e.compagnie_id,e.section_id,e.matricule)
  WHERE sm.pnj_id=ANY(p_ids) AND b.statut='en_cours' AND e.sorti_round IS NULL
 ) x WHERE x.raison IS NOT NULL LIMIT 1;
$g$;
REVOKE ALL ON FUNCTION public.pnj_confrontation_refus_interne(text[]) FROM PUBLIC,anon,authenticated,service_role;

DO $portes$
DECLARE f record;s text;a text;b text;
BEGIN
 FOR f IN SELECT * FROM (VALUES
 ('groupe_pj_rejoindre(text)','public.mon_personnage()','p_chef'),
 ('groupe_pj_quitter()','public.mon_personnage()','NULL::text'),
 ('pnj_prendre(text[])','public.mon_personnage()','NULL::text'),
 ('pnj_quitter_groupe(text[])','public.mon_personnage()','NULL::text'),
 ('pnj_transferer(text[],text,boolean)','public.mon_personnage()','CASE WHEN coalesce(p_dest_est_pnj,false) THEN NULL::text ELSE p_dest END'),
 ('pnj_deployer_unite(text[],boolean)','public.mon_personnage()','NULL::text'),
 ('pnj_rappeler_radio(text)','public.mon_personnage()','NULL::text')
 ) t(signature,acteur,destination) LOOP
  s:=pg_get_functiondef(('public.'||f.signature)::regprocedure);
  IF position('-- groupe_confrontation_composition_v1' IN s)>0 THEN CONTINUE;END IF;
  -- Le verrou est le premier acte : même ordre graphe/institutions/PJ/PNJ
  -- que déplacements, transports et sélection des combattants.
  IF position('BEGIN' IN s)=0 THEN RAISE EXCEPTION 'composition_corps_non_examine: %',f.signature;END IF;
  b:=E'BEGIN\n -- groupe_confrontation_composition_v1\n PERFORM pg_advisory_xact_lock(hashtextextended(''groupe_pj:graphe'',0));'
    ||chr(10)||' IF public.groupe_confrontation_refus_interne('||f.acteur||') IS NOT NULL'
    ||' OR public.groupe_confrontation_refus_interne('||f.destination||') IS NOT NULL THEN'
    ||' RETURN jsonb_build_object(''ok'',false)||coalesce(public.groupe_confrontation_refus_interne('||f.acteur||'),public.groupe_confrontation_refus_interne('||f.destination||'));END IF;';
  IF f.signature LIKE 'pnj_%' THEN
   a:=CASE WHEN f.signature LIKE 'pnj_deployer_%' THEN 'p_pnj_ids'
      WHEN f.signature LIKE 'pnj_rappeler_%' THEN 'ARRAY(SELECT id FROM public.pnj_membres WHERE id=p_ancre OR leader_pnj_id=p_ancre)'
      ELSE 'p_ids' END;
   b:=b||chr(10)||' IF public.pnj_confrontation_refus_interne('||a||') IS NOT NULL THEN RETURN jsonb_build_object(''ok'',false)||public.pnj_confrontation_refus_interne('||a||');END IF;';
  END IF;
  s:=overlay(s placing b FROM position('BEGIN' IN s) FOR 5);
  EXECUTE s;
 END LOOP;
END $portes$;
