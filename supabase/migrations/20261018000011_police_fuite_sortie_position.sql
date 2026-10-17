CREATE OR REPLACE FUNCTION public.police_fuite_resoudre(p_rencontre text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE v_nom text; v_pj public.personnages_donnees%ROWTYPE;
 v_i public.police_interceptions%ROWTYPE; v_b public.batiments_etat%ROWTYPE;
 v_agents jsonb; v_a jsonb; v_n integer:=0; v_vol numeric:=0; v_chance numeric;
 v_destination text; v_voisins text[];
BEGIN
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom FOR UPDATE;
 SELECT * INTO v_i FROM public.police_interceptions WHERE personnage=v_nom AND rencontre=p_rencontre AND expires_at>now() FOR UPDATE;
 IF NOT FOUND OR v_pj.current_city IS DISTINCT FROM v_i.city OR v_pj.country IS DISTINCT FROM v_i.country
 OR v_pj.current_building IS DISTINCT FROM v_i.building OR v_pj.current_room IS DISTINCT FROM v_i.room
 OR (v_i.street IS NOT NULL AND v_pj.current_street IS DISTINCT FROM v_i.street) THEN RETURN jsonb_build_object('ok',false,'raison','rencontre_invalide'); END IF;
 IF v_i.fuite_tentee THEN RETURN jsonb_build_object('ok',false,'raison','fuite_deja_tentee'); END IF;
 SELECT * INTO v_b FROM public.batiments_etat WHERE country=v_i.country AND city=v_i.city
 AND building_id=CASE WHEN v_i.city='capitale' THEN 'commissariat' ELSE 'commissariat-local' END FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','effectifs_absents'); END IF;
 v_agents:=v_b.data::jsonb->'effectifsPolice'->'policiers';
 IF jsonb_typeof(v_agents) IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('ok',false,'raison','effectifs_invalides'); END IF;
 FOR v_a IN SELECT value FROM jsonb_array_elements(v_agents) LOOP
 IF ((v_i.street IS NOT NULL AND v_a->>'rueNoeudId'=v_i.street)
 OR (v_i.street IS NULL AND v_a->>'buildingId'=v_i.building AND v_a->>'roomId'=v_i.room)) AND coalesce((v_a->>'pa')::integer,12)>0 THEN
 v_n:=v_n+1; v_vol:=v_vol+coalesce((v_a->'stats'->>'VOL')::numeric,12);
 END IF; END LOOP;
 IF v_n=0 THEN RETURN jsonb_build_object('ok',false,'raison','aucun_policier_present'); END IF;
 v_chance:=greatest(10,least(90,50+5*(coalesce((v_pj.stats->>'VOL')::numeric,8)
 +(8+coalesce((v_pj.resources->>'dis')::numeric,0)/10)/2-v_vol/v_n)));
 UPDATE public.police_interceptions SET fuite_tentee=true WHERE personnage=v_nom AND rencontre=p_rencontre;
 IF random()*100 >= v_chance THEN RETURN jsonb_build_object('ok',true,'reussite',false); END IF;
 IF v_i.street IS NOT NULL THEN
 SELECT voisins INTO v_voisins FROM public.rue_noeuds_serveur
 WHERE country=v_i.country AND city=v_i.city AND noeud=v_i.street;
 IF coalesce(array_length(v_voisins,1),0)=0 THEN RAISE EXCEPTION 'fuite_rue_sans_destination'; END IF;
 v_destination:=v_voisins[1+floor(random()*array_length(v_voisins,1))::integer];
 UPDATE public.personnages_donnees SET current_street=v_destination WHERE id=v_pj.id;
 ELSE
 SELECT noeud INTO v_destination FROM public.rue_sorties_batiments
 WHERE country=v_i.country AND city=v_i.city AND building=v_i.building ORDER BY noeud LIMIT 1;
 IF v_destination IS NULL THEN RAISE EXCEPTION 'sortie_batiment_inconnue'; END IF;
 UPDATE public.personnages_donnees SET current_building=NULL,current_room=NULL,current_street=v_destination WHERE id=v_pj.id;
 END IF;
 UPDATE public.police_interceptions SET expires_at=now() WHERE personnage=v_nom AND rencontre=p_rencontre;
 RETURN jsonb_build_object('ok',true,'reussite',true,'destination',v_destination);
END;
$fn$;
REVOKE ALL ON FUNCTION public.police_fuite_resoudre(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.police_fuite_resoudre(text) TO authenticated;
