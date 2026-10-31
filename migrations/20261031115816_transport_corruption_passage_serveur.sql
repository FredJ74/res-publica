-- #219 : même tentative de corruption, avec reçu et passage serveur individuel.
-- L'ancien appel sans identifiant est refusé avant paiement : il ne peut pas
-- distinguer une nouvelle tentative d'une répétition après perte de réponse.
DO $prevol$
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.crime_corrompre_douanier(integer,integer)'::regprocedure)
 NOT IN ('038b507ca508f48c25bcaed9221b7bbd','c40e5306c572db1fe1cf9a12de571774') THEN RAISE EXCEPTION 'corruption_douaniere_vivante_non_examinee';END IF;
 IF to_regprocedure('public.douane_corruption_executer_interne(integer,integer)') IS NOT NULL
 AND (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.douane_corruption_executer_interne(integer,integer)'))<>'4011906f8f031ab9b1a91952cd770c5d'
 THEN RAISE EXCEPTION 'corruption_douaniere_interne_non_examinee';END IF;
END $prevol$;
CREATE OR REPLACE FUNCTION public.douane_corruption_executer_interne(p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_repere boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees d JOIN public.navigation_lieux_regles l
    ON l.pays=d.country AND l.ville=d.current_city AND l.batiment=d.current_building
    WHERE d.name=v_moi AND d.current_building LIKE 'centre-multinodal-%'
    AND d.current_room='hall_douanes' AND l.pieces ? d.current_room) THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_au_controle');END IF;
  v_paie := public.payer_ordre(v_moi, 'corrompre_douanier', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT stats, resources INTO m FROM public.personnages_donnees WHERE name = v_moi;
  v_taux := greatest(5, 55 + floor(coalesce((m.stats ->> 'DUP')::numeric, 8) / 10)::integer
            + floor(coalesce(CASE WHEN jsonb_typeof(m.resources -> 'inf') = 'number' THEN (m.resources ->> 'inf')::numeric END, 0) / 10)::integer + 20);
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux THEN
    INSERT INTO public.navigation_passages_douaniers(personnage,pays,ville,batiment,mode,corruption)
    SELECT name,country,current_city,current_building,'avion',true FROM public.personnages_donnees WHERE name=v_moi
    ON CONFLICT(personnage) DO UPDATE SET pays=EXCLUDED.pays,ville=EXCLUDED.ville,batiment=EXCLUDED.batiment,mode=EXCLUDED.mode,corruption=true,controle_le=now();
    PERFORM public.crime_dis_ajuster_interne(v_moi, -5);
    v_repere := public.crime_detecter_interne(v_moi, 'corrompre_douanier', true);
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_roll <= v_taux, 'repere', v_repere, 'taux', v_taux, 'jet', v_roll)
    || public.crime_etat_acteur_interne(v_moi);
END; $function$;
REVOKE ALL ON FUNCTION public.douane_corruption_executer_interne(integer,integer) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.crime_corrompre_douanier(p_pa integer,p_cost integer)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $function$
 SELECT jsonb_build_object('ok',false,'raison','requete_absente','actualiser_client',true);
$function$;

CREATE OR REPLACE FUNCTION public.crime_corrompre_douanier(p_pa integer,p_cost integer,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text;v jsonb;a jsonb;
BEGIN
 moi:=public.mon_personnage();
 IF moi IS NULL OR p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide');END IF;
 a:=jsonb_build_object('corruption_douane',true,'pa',p_pa,'cost',p_cost);
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT verdict INTO v FROM public.navigation_requetes WHERE acteur=moi AND requete=p_requete AND arguments=a;
 IF NOT FOUND THEN
  IF EXISTS(SELECT 1 FROM public.navigation_requetes WHERE acteur=moi AND requete=p_requete) THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  v:=public.navigation_disponibilite_interne(moi);
  IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;
  v:=public.douane_corruption_executer_interne(p_pa,p_cost);
  INSERT INTO public.navigation_requetes(acteur,requete,arguments,verdict) VALUES(moi,p_requete,a,v);
 END IF;
 RETURN v||public.crime_etat_acteur_interne(moi);
END $g$;
REVOKE ALL ON FUNCTION public.crime_corrompre_douanier(integer,integer,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.crime_corrompre_douanier(integer,integer,uuid) TO authenticated;
