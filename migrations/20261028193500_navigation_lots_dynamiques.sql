-- #219 : consulter les subdivisions réelles, ne jamais recopier les lots dans un catalogue.
CREATE OR REPLACE FUNCTION public.navigation_piece_referencee_interne(p_pays text,p_ville text,p_batiment text,p_piece text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT EXISTS(SELECT 1 FROM public.navigation_lieux_regles WHERE pays=p_pays AND ville=p_ville AND batiment=p_batiment AND pieces ? p_piece)
 OR (SELECT count(*)=1 FROM public.terrains_etat t
 CROSS JOIN LATERAL public.terrain_etat_lire(t.data) e
 CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(e->'subdivisions')='array' THEN e->'subdivisions' ELSE '[]'::jsonb END) lot
 WHERE t.country=p_pays AND t.building_id=p_batiment AND e->>'city'=p_ville
 AND nullif(btrim(lot->>'id'),'') IS NOT NULL
 AND 'lot_dyn_'||regexp_replace(btrim(lot->>'id'),'[^A-Za-z0-9_-]','_','g')=p_piece);
$g$;
REVOKE ALL ON FUNCTION public.navigation_piece_referencee_interne(text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
DO $navigation$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
 a:='IF NOT FOUND OR NOT l.pieces ? p_piece THEN';
 b:='IF NOT public.navigation_piece_referencee_interne(p.country,p.current_city,p_batiment,p_piece) THEN';
 IF position(b IN s)>0 THEN RETURN; END IF;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'navigation_reference_piece_non_examinee'; END IF;
 -- l peut être NULL pour un immeuble dynamique ; seules les restrictions connues
 -- sont lues ensuite. Les droits métier restent dans les portes des lots/baux/fonds.
 EXECUTE replace(s,a,b);
END $navigation$;
-- La subdivision ne doit pas disparaître entre sa lecture et le déplacement.
-- Même ordre que le moteur de lots existant : terrain avant personnages.
DO $verrou$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.navigation_commander_interne(text,text,text)'::regprocedure);
 IF position('navigation_terrain_partage_v1' IN s)>0 THEN RETURN;END IF;
 a:=' PERFORM public.pnj_groupes_verrouiller_projections_interne(pnjs);';
 b:=' -- navigation_terrain_partage_v1'||chr(10)||' IF p_mode=''piece'' THEN'
 ||chr(10)||' PERFORM t.id FROM public.terrains_etat t WHERE t.country=(SELECT country FROM public.personnages_donnees WHERE name=moi)'
 ||chr(10)||' AND t.building_id=p_destination ORDER BY t.id FOR SHARE;'
 ||chr(10)||' END IF;'||chr(10)||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'navigation_verrou_terrain_ancre_absente';END IF;
 EXECUTE replace(s,a,b);
END $verrou$;
