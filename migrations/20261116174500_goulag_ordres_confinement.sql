-- Verrou transversal des ordres facturés pendant une traversée ou un refuge.
-- Empêche de contourner la survie par un ordre de nourriture, d'hébergement
-- ou de transport ancien, même si le navigateur garde un bouton en cache.
DO $goulag_ordre$
DECLARE source text; ancre text; garde text;
BEGIN
 source:=pg_get_functiondef('public.payer_ordre_interne(text,text,integer,integer,integer)'::regprocedure);
 IF strpos(source,'goulag_ordre_isolement_20261116')>0 THEN RETURN; END IF;
 ancre:=E'  PERFORM public.exiger_acteur(p_acteur);';
 garde:=ancre
   ||E'\n  -- goulag_ordre_isolement_20261116 : aucune dépense générique en toundra ou convalescence.\n'
   ||E'  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees t\n'
   ||E'      WHERE t.nom=p_acteur AND t.en_cours) THEN\n'
   ||E'    RETURN jsonb_build_object(''ok'',false,''raison'',''traversee_irreversible''); END IF;\n'
   ||E'  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_refuges r\n'
   ||E'      WHERE r.nom=p_acteur AND NOT r.termine) THEN\n'
   ||E'    RETURN jsonb_build_object(''ok'',false,''raison'',''repos_force_goulag''); END IF;';
 IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN
   RAISE EXCEPTION 'payer_ordre_interne_ancre_absente'; END IF;
 EXECUTE replace(source,ancre,garde);
END $goulag_ordre$;
