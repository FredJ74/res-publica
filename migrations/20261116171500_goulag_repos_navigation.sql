-- Repos forcé : le fugitif doit rejoindre la maison de la ville d'arrivée.
-- Une fois la première nuit commencée, les déplacements génériques sont bloqués
-- jusqu'au terme des 3 jours et au règlement des deux nuits.
DO $repos_garde$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
 IF strpos(s,'goulag_refuge_acces_20261116')=0 THEN
   a:=E' SELECT * INTO p FROM public.personnages_donnees WHERE name=p_nom;';
   b:=a||E'\n -- goulag_refuge_acces_20261116 : logement d accueil uniquement durant récupération.\n'
     ||E' IF EXISTS(SELECT 1 FROM public.sovarka_goulag_refuges r\n'
     ||E'   WHERE r.nom=p_nom AND NOT r.termine\n'
     ||E'     AND p_batiment IS DISTINCT FROM CASE r.destination\n'
     ||E'       WHEN ''starovka'' THEN ''maison-starovka'' ELSE ''maison-krasnov'' END) THEN\n'
     ||E'   RETURN jsonb_build_object(''ok'',false,''raison'',''repos_chez_habitant_requis''); END IF;';
   IF (length(s)-length(replace(s,a,'')))<>length(a) THEN
     RAISE EXCEPTION 'navigation_interieure_refuge_ancre_absente';END IF;
   EXECUTE replace(s,a,b);
 END IF;
 s:=pg_get_functiondef('public.navigation_disponibilite_interne(text)'::regprocedure);
 IF strpos(s,'goulag_refuge_repos_20261116')=0 THEN
   a:=E' IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE personnage=p_nom AND expires_at>now()) THEN';
   b:=E' -- goulag_refuge_repos_20261116 : dès la première nuit, repos complet.\n'
     ||E' IF EXISTS(SELECT 1 FROM public.sovarka_goulag_refuges r WHERE r.nom=p_nom\n'
     ||E'   AND NOT r.termine AND r.nuits>=1) THEN\n'
     ||E'  RETURN jsonb_build_object(''ok'',false,''raison'',''repos_force_goulag''); END IF;\n'||a;
   IF (length(s)-length(replace(s,a,'')))<>length(a) THEN
     RAISE EXCEPTION 'navigation_disponibilite_refuge_ancre_absente';END IF;
   EXECUTE replace(s,a,b);
 END IF;
END $repos_garde$;
