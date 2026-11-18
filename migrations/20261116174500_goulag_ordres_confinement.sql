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

-- Le repos civil ne peut créditer +12 PA en plus des seuls +3/+6 de survie.
-- Le personnage est déjà verrouillé par pa_repos_nocturne avant cette garde.
DO $goulag_repos$
DECLARE source text; ancre text; garde text;
BEGIN
 source:=pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure);
 IF strpos(source,'goulag_repos_toundra_20261116')>0 THEN RETURN; END IF;
 ancre:=E'  IF v_deja IS NOT NULL AND v_deja >= v_jour THEN';
 garde:=E'  -- goulag_repos_toundra_20261116 : sommeil explicite, aucun crédit civil supplémentaire.\n'
   ||E'  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees t\n'
   ||E'    JOIN public.personnages_donnees d ON d.name=t.nom\n'
   ||E'    WHERE t.nom=p_acteur AND t.en_cours AND d.country=''soviet'') THEN\n'
   ||E'    RETURN jsonb_build_object(''ok'',false,''raison'',''sommeil_toundra_explicit'',''pa'',v_pa); END IF;\n'
   ||ancre;
 IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN
   RAISE EXCEPTION 'pa_repos_nocturne_ancre_absente'; END IF;
 EXECUTE replace(source,ancre,garde);
END $goulag_repos$;
