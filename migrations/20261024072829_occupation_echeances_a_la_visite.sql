-- Appliquer les echeances lors d'une interaction, sans interrogation periodique.
BEGIN;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.terrain_occupation_lire(text)');
IF h='9ec6d02d9111b77192bfe84f95a4c96d' THEN
 d:=replace(d,$ancien$ SELECT * INTO t FROM public.terrains_etat$ancien$,$nouveau$ PERFORM public.terrain_police_traiter_interne(p.country||'_'||p_terrain);
 SELECT * INTO t FROM public.terrains_etat$nouveau$);EXECUTE d;
ELSIF h IS DISTINCT FROM 'd4a1ae078c019410fde4a3a25db5aaea' THEN RAISE EXCEPTION 'definition_non_examinee: terrain_occupation_lire';END IF;
END;$g$;
COMMIT;
