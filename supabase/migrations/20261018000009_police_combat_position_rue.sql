CREATE OR REPLACE FUNCTION public.police_combat_resoudre(
 p_rencontre text,
 p_rue text DEFAULT NULL,
 p_batiment text DEFAULT NULL,
 p_piece text DEFAULT NULL,
 p_round integer DEFAULT 1
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
 v_nom text; v_pj public.personnages_donnees%ROWTYPE;
 v_bat public.batiments_etat%ROWTYPE; v_etat jsonb; v_police jsonb;
 v_agents jsonb; v_agent jsonb; v_modifie jsonb := '[]'::jsonb;
 v_actifs jsonb := '[]'::jsonb; v_recherches integer;
 v_pj_pa integer; v_pa integer; v_avant integer;
 v_vol integer; v_per integer; v_jet jsonb; v_ret jsonb;
 v_cible integer; v_idx integer; v_rebellion jsonb;
 v_id text; v_batiment_id text; v_comp numeric;
 v_jugement text; v_detention jsonb;
 v_interception public.police_interceptions%ROWTYPE;
BEGIN
 v_nom := public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 IF p_rencontre IS NULL OR length(p_rencontre) NOT BETWEEN 8 AND 120
    OR p_round IS NULL OR p_round NOT BETWEEN 1 AND 100
    OR (p_rue IS NULL AND (p_batiment IS NULL OR p_piece IS NULL))
    OR (p_rue IS NOT NULL AND (p_batiment IS NOT NULL OR p_piece IS NOT NULL)) THEN
   RETURN jsonb_build_object('ok',false,'raison','rencontre_invalide');
 END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom FOR UPDATE;
 IF NOT FOUND OR v_pj.country <> 'republic' OR v_pj.current_city IS NULL
    OR v_pj.est_emprisonne IS NOT NULL AND v_pj.est_emprisonne <> 'null'::jsonb THEN
   RETURN jsonb_build_object('ok',false,'raison','joueur_indisponible');
 END IF;
 SELECT * INTO v_interception FROM public.police_interceptions
 WHERE personnage=v_nom AND rencontre=p_rencontre AND expires_at>now() FOR UPDATE;
 IF NOT FOUND OR v_interception.country IS DISTINCT FROM v_pj.country
    OR v_interception.city IS DISTINCT FROM v_pj.current_city
    OR v_interception.building IS DISTINCT FROM p_batiment
    OR v_interception.room IS DISTINCT FROM p_piece
    OR v_interception.street IS DISTINCT FROM p_rue THEN
   RETURN jsonb_build_object('ok',false,'raison','detection_non_confirmee');
 END IF;
 IF p_rue IS NULL AND (v_pj.current_building IS DISTINCT FROM p_batiment
    OR v_pj.current_room IS DISTINCT FROM p_piece) THEN
   RETURN jsonb_build_object('ok',false,'raison','position_invalide');
 END IF;
 IF p_rue IS NOT NULL AND (v_pj.current_building IS NOT NULL OR v_pj.current_street IS DISTINCT FROM p_rue) THEN
   RETURN jsonb_build_object('ok',false,'raison','pas_en_rue');
 END IF;
 SELECT count(*) INTO v_recherches FROM public.justice_recherches(v_nom) r
  WHERE r.country=v_pj.country;
 IF v_recherches=0 THEN RETURN jsonb_build_object('ok',false,'raison','non_recherche'); END IF;
 v_batiment_id := CASE WHEN v_pj.current_city='capitale' THEN 'commissariat'
    ELSE 'commissariat-local' END;
 SELECT * INTO v_bat FROM public.batiments_etat
 WHERE country=v_pj.country AND city=v_pj.current_city
   AND building_id=v_batiment_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','effectifs_absents'); END IF;
 BEGIN v_etat := v_bat.data::jsonb;
 EXCEPTION WHEN others THEN RETURN jsonb_build_object('ok',false,'raison','effectifs_invalides'); END;
 v_police := coalesce(v_etat->'effectifsPolice','{}'::jsonb);
 v_agents := v_police->'policiers';
 IF jsonb_typeof(v_agents) IS DISTINCT FROM 'array' THEN
   RETURN jsonb_build_object('ok',false,'raison','effectifs_invalides');
 END IF;
 FOR v_agent IN SELECT value FROM jsonb_array_elements(v_agents) LOOP
   IF coalesce((v_agent->>'pa')::integer,12)>0 AND
      ((p_rue IS NOT NULL AND v_agent->>'rueNoeudId'=p_rue)
       OR (p_rue IS NULL AND v_agent->>'buildingId'=p_batiment
           AND v_agent->>'roomId'=p_piece)) THEN
      v_actifs := v_actifs || jsonb_build_array(v_agent);
   END IF;
 END LOOP;
 IF jsonb_array_length(v_actifs)=0 THEN
   RETURN jsonb_build_object('ok',false,'raison','aucun_policier_present');
 END IF;
 v_pj_pa := greatest(0,coalesce(v_pj.pa,0));
 IF v_pj_pa=0 THEN RETURN jsonb_build_object('ok',false,'raison','joueur_sans_pa'); END IF;
 INSERT INTO public.police_combat_rounds(personnage,rencontre,round_key)
 VALUES(v_nom,p_rencontre,p_round);
 -- Le serveur inscrit la rébellion avant le premier coup. Identifiant stable
 -- pour éviter plusieurs délits lors des rounds d'une même rencontre.
 v_id := 'rebellion-police:' || p_rencontre;
 v_rebellion := public.recherche_inscrire(jsonb_build_object(
   'id',v_id,'acte','rebellion','type','delit_grave','country',v_pj.country,
   'ville',v_pj.current_city,'jour',v_pj.day));
 IF coalesce((v_rebellion->>'ok')::boolean,false)=false THEN
   RETURN jsonb_build_object('ok',false,'raison','rebellion_non_inscrite');
 END IF;
 v_cible := floor(random()*jsonb_array_length(v_actifs))::integer;
 v_agent := v_actifs->v_cible;
 v_vol := greatest(0,coalesce((v_agent->'stats'->>'VOL')::integer,12));
 v_per := greatest(0,coalesce((v_agent->'stats'->>'PER')::integer,12));
 v_comp := greatest(0,coalesce((v_pj.stats->>'VOL')::numeric,8));
 v_pa := greatest(0,coalesce((v_agent->>'pa')::integer,12));
 v_jet := public.combat_coup_resoudre(v_comp,v_vol,v_per,0,v_pa);
 v_pa := (v_jet->>'pa_apres')::integer;
 v_agent := jsonb_set(v_agent,'{pa}',to_jsonb(v_pa),true);
 v_actifs := jsonb_set(v_actifs,ARRAY[v_cible::text],v_agent,false);
 -- Les policiers présents et encore capables de combattre ripostent ensemble.
 FOR v_idx IN 0..jsonb_array_length(v_actifs)-1 LOOP
   v_agent := v_actifs->v_idx;
   v_pa := greatest(0,coalesce((v_agent->>'pa')::integer,12));
   IF v_pa>0 AND v_pj_pa>0 THEN
     v_jet := public.combat_coup_resoudre(
       greatest(0,coalesce((v_agent->'stats'->>'VOL')::numeric,12)),
       v_comp,greatest(0,coalesce((v_pj.stats->>'PER')::numeric,8)),0,v_pj_pa);
     v_pj_pa := (v_jet->>'pa_apres')::integer;
   END IF;
 END LOOP;
 -- Réécriture par matricule ; les policiers absents ne sont jamais touchés.
 FOR v_agent IN SELECT value FROM jsonb_array_elements(v_agents) LOOP
   FOR v_idx IN 0..jsonb_array_length(v_actifs)-1 LOOP
     IF v_agent->>'matricule' IS NOT NULL AND
        v_agent->>'matricule'=v_actifs->v_idx->>'matricule' THEN
       v_agent := v_actifs->v_idx;
       EXIT;
     END IF;
   END LOOP;
   v_modifie := v_modifie || jsonb_build_array(v_agent);
 END LOOP;
 v_police := jsonb_set(v_police,'{policiers}',v_modifie,true);
 v_etat := jsonb_set(v_etat,'{effectifsPolice}',v_police,true);
 UPDATE public.batiments_etat SET data=v_etat,updated_at=now()
 WHERE id=v_bat.id;
 UPDATE public.personnages_donnees SET pa=v_pj_pa WHERE id=v_pj.id;
 SELECT count(*) INTO v_recherches FROM jsonb_array_elements(v_actifs) x
 WHERE coalesce((x->>'pa')::integer,12)>0;
 IF v_pj_pa=0 THEN
   UPDATE public.police_interceptions SET expires_at=now() WHERE personnage=v_nom AND rencontre=p_rencontre;
   SELECT r.id::text INTO v_jugement FROM public.justice_recherches(v_nom) r
     WHERE r.country=v_pj.country ORDER BY r.id::text LIMIT 1;
   IF v_jugement IS NULL THEN RAISE EXCEPTION 'condamnation_absente_pendant_arrestation'; END IF;
   v_detention := public.justice_executer_condamnation_soi(v_jugement);
   IF NOT coalesce((v_detention->>'ok')::boolean,false) OR v_detention->>'detention_id' IS NULL THEN
     RAISE EXCEPTION 'detention_non_confirmee';
   END IF;
 END IF;
 IF v_recherches=0 THEN
   UPDATE public.police_interceptions SET expires_at=now() WHERE personnage=v_nom AND rencontre=p_rencontre;
 END IF;
 RETURN jsonb_build_object('ok',true,'pa',v_pj_pa,
   'policiers_restants',v_recherches,'arrestation',v_pj_pa=0,
   'detention_id',CASE WHEN v_pj_pa=0 THEN v_detention->>'detention_id' ELSE NULL END,
   'jours',CASE WHEN v_pj_pa=0 THEN v_detention->>'jours' ELSE NULL END,
   'motif',CASE WHEN v_pj_pa=0 THEN v_detention->>'motif' ELSE NULL END,
   'police_neutralisee',v_recherches=0);
END;
$fn$;
REVOKE ALL ON FUNCTION public.police_combat_resoudre(text,text,text,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.police_combat_resoudre(text,text,text,text,integer) TO authenticated;