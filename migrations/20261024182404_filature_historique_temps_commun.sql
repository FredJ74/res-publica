-- Dernières 24h réellement horodatées, indépendantes du jour personnel.
BEGIN;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.filature_deplacements(text)');
IF h='bc471fab0e9d5d095c370a085a212fbf' THEN
d:=replace(d,$a$h.jour >= greatest(1, v_jour - 1)$a$,$b$h.created_at >= statement_timestamp()-interval '24 hours' AND h.created_at<=statement_timestamp()$b$);
d:=replace(d,$a$SELECT d.day INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_jour IS NULL THEN$a$,$b$PERFORM 1 FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF NOT FOUND THEN$b$);
d:=replace(d,$a$ORDER BY h.jour, h.heure$a$,$b$ORDER BY h.created_at, h.id$b$);
d:=replace(d,$a$'jour', h.jour, 'heure', h.heure,$a$,$b$'jour', h.jour, 'heure', h.heure, 'date_evenement', h.created_at,$b$);
EXECUTE d;ELSIF h IS DISTINCT FROM 'b93a5077febbf222371e0649f681f694' THEN RAISE EXCEPTION 'definition_non_examinee: filature_deplacements';END IF;END;$g$;
COMMIT;
