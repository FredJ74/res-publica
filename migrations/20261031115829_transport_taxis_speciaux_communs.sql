-- #219 : taxis déclarés dans data.js, même transport/paiement/reçu collectif.
DO $taxis$
DECLARE s text;a text;b text;debut integer;fin integer;
BEGIN
 s:=pg_get_functiondef('public.transport_effectuer(text,text,text,uuid)'::regprocedure);
 IF position('-- transport_taxis_speciaux_v1' IN s)>0 THEN RETURN;END IF;
 a:='p_mode NOT IN (''train'',''bus'',''avion'',''bateau'')';
 b:='p_mode NOT IN (''train'',''bus'',''avion'',''bateau'',''taxi_caserne'',''taxi_qhs'')';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'taxi_modes_non_examines';END IF;
 s:=replace(s,a,b);
 a:='OR NOT EXISTS(SELECT 1 FROM public.villes WHERE pays=p_pays AND ville=p_ville)';
 b:='OR (p_mode NOT IN (''taxi_caserne'',''taxi_qhs'') AND NOT EXISTS(SELECT 1 FROM public.villes WHERE pays=p_pays AND ville=p_ville))';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'taxi_zone_speciale_non_examinee';END IF;
 s:=replace(s,a,b);
 a:=' -- transport_international_commun_v1';
 b:=' -- transport_taxis_speciaux_v1'||chr(10)
 ||' IF p_mode IN (''taxi_caserne'',''taxi_qhs'') AND NOT coalesce(p.current_building=''centre-multinodal-luthecia'' AND p.current_room=''hall_gare'',false) THEN RETURN jsonb_build_object(''ok'',false,''raison'',''pas_au_terminal'');END IF;'||chr(10)||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'taxi_depart_non_examine';END IF;
 s:=replace(s,a,b);
 a:='ELSE p_pays IS NOT DISTINCT FROM p.country OR p_ville IS DISTINCT FROM ''capitale'' END';
 b:='WHEN p_mode=''taxi_caserne'' THEN p_pays IS DISTINCT FROM p.country OR p_ville IS DISTINCT FROM ''caserne'' '
 ||'WHEN p_mode=''taxi_qhs'' THEN p_pays IS DISTINCT FROM p.country OR p_ville IS DISTINCT FROM ''qhs'' '||a;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'taxi_destination_non_examinee';END IF;
 s:=replace(s,a,b);
 a:='CASE p_mode WHEN ''train'' THEN ''prendre_train'' WHEN ''bus'' THEN ''prendre_bus_taxi'' WHEN ''avion'' THEN ''prendre_avion'' ELSE ''prendre_bateau'' END';
 b:='CASE WHEN p_mode IN (''taxi_caserne'',''taxi_qhs'') THEN p_mode ELSE '||a||' END';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>2 THEN RAISE EXCEPTION 'taxi_tarifs_non_examines';END IF;
 s:=replace(s,a,b);
 debut:=position(' SELECT batiment,pieces->>0 INTO b,piece' IN s);fin:=position(' IF b IS NULL THEN' IN s);
 IF debut=0 OR fin<=debut THEN RAISE EXCEPTION 'taxi_arrivee_non_examinee';END IF;
 a:=substring(s FROM debut FOR fin-debut);
 b:=' IF p_mode IN (''taxi_caserne'',''taxi_qhs'') THEN'
 ||' SELECT batiment,CASE WHEN p_mode=''taxi_caserne'' THEN ''corps_garde'' ELSE ''entree_qhs'' END INTO b,piece FROM public.navigation_lieux_regles'
 ||' WHERE pays=p_pays AND ville=p_ville AND batiment=CASE WHEN p_mode=''taxi_caserne'' THEN ''caserne-militaire'' ELSE ''qhs-prison'' END'
 ||' AND pieces ? CASE WHEN p_mode=''taxi_caserne'' THEN ''corps_garde'' ELSE ''entree_qhs'' END;'
 ||chr(10)||' ELSE'||chr(10)||a||' END IF;'||chr(10);
 EXECUTE overlay(s placing b FROM debut FOR fin-debut);
END $taxis$;

-- Les zones spéciales ne sont PAS des villes municipales : pas de faux noeud
-- de rue ni de ligne dans villes. Entrée/sortie passent par le moteur intérieur.
DO $zones$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
 IF position('-- navigation_zone_speciale_v1' IN s)>0 THEN RETURN;END IF;
 a:=' SELECT * INTO p FROM public.personnages_donnees WHERE name=p_nom;';
 b:=a||chr(10)||' -- navigation_zone_speciale_v1'
 ||chr(10)||' IF p_batiment IS NULL AND p_piece IS NULL AND (p.current_city,p.current_building) IN ((''caserne'',''caserne-militaire''),(''qhs'',''qhs-prison'')) THEN'
 ||' IF NOT p_verifier THEN UPDATE public.personnages_donnees SET current_building=NULL,current_room=NULL,current_street=NULL,updated_at=clock_timestamp() WHERE name=p_nom;END IF;'
 ||' RETURN jsonb_build_object(''ok'',true,''building'',NULL,''room'',NULL);END IF;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'zone_sortie_definition_non_examinee';END IF;
 s:=replace(s,a,b);
 a:='  IF p.current_building IS NOT NULL OR NOT EXISTS(SELECT 1 FROM public.rue_sorties_batiments'
 ||chr(10)||'   WHERE country=p.country AND city=p.current_city AND building=p_batiment AND noeud=p.current_street) THEN';
 b:='  IF p.current_building IS NOT NULL OR (NOT EXISTS(SELECT 1 FROM public.rue_sorties_batiments'
 ||chr(10)||'   WHERE country=p.country AND city=p.current_city AND building=p_batiment AND noeud=p.current_street)'
 ||' AND NOT (p.current_street IS NULL AND (p.current_city,p_batiment,p_piece) IN ((''caserne'',''caserne-militaire'',''corps_garde''),(''qhs'',''qhs-prison'',''entree_qhs'')))) THEN';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'zone_entree_definition_non_examinee';END IF;
 EXECUTE replace(s,a,b);
END $zones$;
