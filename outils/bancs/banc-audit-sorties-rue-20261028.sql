-- Contrôle de raccordement des sorties au socle de rue : lecture seule.
-- Aucun état de personnage n'est modifié. Aucun nouveau moteur.
DO $t$
DECLARE n_invalides integer; n_ordinaires integer; n_special integer;
BEGIN
 SELECT count(*) INTO n_invalides
 FROM public.rue_sorties_batiments s
 LEFT JOIN public.rue_noeuds_serveur n
 ON n.country=s.country AND n.city=s.city AND n.noeud=s.noeud
 WHERE n.noeud IS NULL;
 IF n_invalides<>0 THEN RAISE EXCEPTION 'sorties_pointant_vers_noeud_absent: %',n_invalides; END IF;

 SELECT count(*) INTO n_ordinaires FROM public.personnages_donnees p
 WHERE p.country='republic' AND p.current_city IN ('capitale','ville_a','ville_b')
 AND p.current_building IS NOT NULL
 AND NOT EXISTS (
 SELECT 1 FROM public.rue_sorties_batiments s WHERE s.country=p.country
 AND s.city=p.current_city AND s.building=p.current_building
 );
 IF n_ordinaires<>0 THEN RAISE EXCEPTION 'pj_dans_batiment_ordinaire_sans_sortie: %',n_ordinaires; END IF;

 SELECT count(*) INTO n_special FROM public.personnages_donnees p
 WHERE p.country='republic' AND p.current_city IN ('caserne','qhs')
 AND p.current_building IS NOT NULL
 AND NOT EXISTS (
 SELECT 1 FROM public.rue_sorties_batiments s WHERE s.country=p.country
 AND s.city=p.current_city AND s.building=p.current_building
 );
 RAISE NOTICE 'sorties_referencees_valides; occupants_ordinaires_ok; zones_speciales_sans_sortie=% (a examiner via transport)',n_special;
END $t$;
