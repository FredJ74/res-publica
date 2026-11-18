-- Aucun visiteur ne doit quitter le goulag de Sovarka en empruntant la
-- sortie QHS générique de Républia, puis un bus sans décision serveur.
-- Le retour se fait exclusivement par sovarka_goulag_visiteur_repartir.
DO $goulag_sortie$
DECLARE source text;ancre text;garde text;
BEGIN
 source:=pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
 IF strpos(source,'goulag_sortie_qhs_20261116')>0 THEN RETURN; END IF;
 ancre:=E' -- navigation_zone_speciale_v1';
 garde:=E' -- goulag_sortie_qhs_20261116 : pas de sortie libre du camp vers le bus du QHS.\n'
   ||E' IF p.country=''soviet'' AND p.current_city=''qhs''\n'
   ||E'    AND p_batiment IS NULL THEN\n'
   ||E'   RETURN jsonb_build_object(''ok'',false,''raison'',''sortie_goulag_reservee''); END IF;\n'
   ||ancre;
 IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN
   RAISE EXCEPTION 'navigation_sortie_qhs_ancre_absente'; END IF;
 EXECUTE replace(source,ancre,garde);
END $goulag_sortie$;
