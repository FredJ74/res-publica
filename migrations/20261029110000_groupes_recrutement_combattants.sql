-- #219/#230 : composition de combat issue du groupe universel existant.
-- Porte interne uniquement. Ne décide ni d'une guerre ni d'un pouvoir policier.
-- Les moteurs appelants gardent l'engagement, les coups et leurs conséquences.
CREATE OR REPLACE FUNCTION public.groupe_combattants_interne(
 p_nom text,p_rencontre text DEFAULT NULL,p_bataille bigint DEFAULT NULL)
RETURNS TABLE(cle text,est_pj boolean,identifiant text,nom text,chef text,
 famille text,pa integer,per numeric,vol numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE ids text[];pnjs text[];lieu public.personnages_donnees%ROWTYPE;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT array_agg(g.identifiant ORDER BY g.identifiant) FILTER(WHERE g.est_pj),
 coalesce(array_agg(g.identifiant ORDER BY g.identifiant) FILTER(WHERE NOT g.est_pj),'{}'::text[])
 INTO ids,pnjs FROM public.groupe_participants_interne(p_nom) g;
 PERFORM public.pnj_groupes_verrouiller_projections_interne(pnjs);
 PERFORM d.name FROM public.personnages_donnees d WHERE d.name=ANY(ids) ORDER BY d.name FOR UPDATE;
 PERFORM m.id FROM public.pnj_membres m WHERE m.id=ANY(pnjs) ORDER BY m.id FOR UPDATE;
 SELECT * INTO lieu FROM public.personnages_donnees WHERE name=p_nom;
 IF NOT FOUND OR lieu.country IS NULL OR lieu.current_city IS NULL
 OR (lieu.current_building IS NULL AND lieu.current_street IS NULL) THEN RETURN;END IF;
 RETURN QUERY
 SELECT g.cle,g.est_pj,g.identifiant,g.nom,g.chef,
 CASE WHEN g.est_pj THEN 'pj' ELSE m.famille END,
 CASE WHEN g.est_pj THEN d.pa ELSE m.pa END,
 CASE WHEN g.est_pj THEN coalesce((d.stats->>'PER')::numeric,8) ELSE m.car_per END,
 CASE WHEN g.est_pj THEN coalesce((d.stats->>'VOL')::numeric,8) ELSE m.car_vol END
 FROM public.groupe_participants_interne(p_nom) g
 LEFT JOIN public.personnages_donnees d ON g.est_pj AND d.name=g.identifiant
 LEFT JOIN public.pnj_membres m ON NOT g.est_pj AND m.id=g.identifiant
 WHERE g.pays=lieu.country AND g.ville=lieu.current_city
 AND g.batiment IS NOT DISTINCT FROM lieu.current_building
 AND CASE WHEN lieu.current_building IS NULL THEN g.rue=lieu.current_street
     ELSE g.piece IS NOT DISTINCT FROM lieu.current_room END
 AND CASE WHEN g.est_pj THEN
  d.pa>0 AND coalesce(d.hp,100)>0
  AND (d.est_emprisonne IS NULL OR d.est_emprisonne='null'::jsonb)
  AND coalesce(d.hospitalisation->>'dateFinParis','')<=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text
  AND NOT CASE WHEN coalesce(d.hospitalisation->>'jourFin','')~'^[0-9]+$'
      THEN (d.hospitalisation->>'jourFin')::numeric>coalesce(d.day,1) ELSE false END
  AND NOT EXISTS(SELECT 1 FROM public.police_interceptions i WHERE i.personnage=d.name
       AND i.expires_at>now() AND i.rencontre IS DISTINCT FROM p_rencontre)
 ELSE m.statut='actif' AND m.pa>0 END
 AND NOT EXISTS(SELECT 1 FROM public.batailles_engagements e
 JOIN public.batailles b ON b.id=e.bataille_id
 LEFT JOIN public.pnj_soldats_metier sm ON sm.compagnie_id=e.compagnie_id
  AND sm.section_id=e.section_id AND sm.matricule=e.matricule
 WHERE b.statut='en_cours' AND e.sorti_round IS NULL
 AND e.bataille_id IS DISTINCT FROM p_bataille
 AND ((g.est_pj AND e.personnage=g.identifiant) OR (NOT g.est_pj AND sm.pnj_id=g.identifiant)))
 ORDER BY g.cle;
END $g$;
REVOKE ALL ON FUNCTION public.groupe_combattants_interne(text,text,bigint) FROM PUBLIC,anon,authenticated,service_role;
