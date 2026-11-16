-- La mécanique soviarkienne ne doit jamais hériter d'un transfert QHS
-- républicain : un transfert vers le goulag doit venir de la sentence
-- atomique du juge de Sovarka, même lorsqu'un appel direct à une ancienne
-- fonction de prolongation de peine est tenté.
DO $goulag_admission$
DECLARE source text; ancre text; garde text;
BEGIN
 source := pg_get_functiondef('public.detention_qhs_poser_interne(text,text,text)'::regprocedure);
 IF strpos(source,'goulag_admission_juge_20261116')>0 THEN RETURN; END IF;
 ancre := E'  IF NOT FOUND THEN RETURN; END IF;';
 garde := ancre
   || E'\n  -- goulag_admission_juge_20261116 : Sovarka uniquement, Républia inchangée.\n'
   || E'  IF v_det.country = ''soviet'' AND\n'
   || E'    (NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration c\n'
   || E'      WHERE c.singleton AND c.active)\n'
   || E'     OR current_setting(''rp.goulag_jugement_interne'',true) IS DISTINCT FROM ''valide'') THEN\n'
   || E'    RAISE EXCEPTION ''goulag_transfert_hors_jugement''; END IF;';
 IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN
  RAISE EXCEPTION 'detention_qhs_poser_interne_ancre_absente';END IF;
 EXECUTE replace(source,ancre,garde);
END $goulag_admission$;
