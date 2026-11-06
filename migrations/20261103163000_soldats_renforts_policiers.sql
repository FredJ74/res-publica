-- =============================================================================================
-- SOLDATS POSTÉS = RENFORTS POLICIERS (Claude, 03/11/2026, règle de Fred)
-- =============================================================================================
-- Règle de Fred (03/11/2026, GAME-DESIGN-ARMEE.md) : on ne choisit pas la mission des soldats ;
-- en temps de paix, des soldats postés sont des renforts policiers. Ils n'attaquent personne,
-- sauf en guerre déclarée, contre les soldats, policiers et douaniers du pays adverse.
-- L'ordre « Attribuer une mission » (bloquer, sécuriser, assassiner, arrêter, surveiller) n'avait
-- jamais été demandé : il est retiré.
--
-- Renfort policier = les soldats actifs présents (hors réserve) de l'État où l'on se trouve
-- rejoignent la liste des forces que la police utilise déjà avec les agents de sécurité privée :
-- securite_agents_prives_presents_interne, lue par la détection des PJ recherchés, la fuite, la
-- confrontation (combat) et la dissuasion des actes illégaux (malus min(40, 10 + hommes)).
-- Les soldats qui suivent le PJ visé (son escorte) ne comptent pas contre lui.
-- =============================================================================================

CREATE OR REPLACE FUNCTION public.securite_agents_prives_presents_interne(p_pays text, p_ville text, p_batiment text, p_piece text, p_rue text, p_cible text)
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
 -- soldats_renforts_policiers_v1 : agents de sécurité privée ET soldats postés (renforts policiers).
 SELECT coalesce(jsonb_agg(f.force ORDER BY f.id), '[]'::jsonb) FROM (
  SELECT m.id, jsonb_build_object(
   'pnj_prive_id',m.id, 'matricule','prive:'||m.id,
   'groupeCle',CASE WHEN m.leader_pj IS NOT NULL THEN 'pj:'||coalesce(
     (SELECT g.chef FROM public.groupes_pj_adhesions g WHERE g.membre=m.leader_pj),m.leader_pj)
    ELSE 'pnj:'||coalesce(m.leader_pnj_id,m.id) END,
   'pa',m.pa, 'stats',jsonb_build_object('PER',m.car_per,'VOL',m.car_vol),
   'buildingId',p.building_id,'roomId',p.room_id,'rueNoeudId',p.rue_noeud_id) AS force
  FROM public.pnj_membres m
  CROSS JOIN LATERAL public.pnj_position_effective(m.id) p
  WHERE m.statut='actif' AND m.pa>0 AND m.car_per IS NOT NULL AND m.car_vol IS NOT NULL
    AND m.pays=p_pays AND p.pays=p_pays AND p.ville=p_ville
    AND ( (p_rue IS NOT NULL AND p.rue_noeud_id=p_rue AND p.building_id IS NULL)
       OR (p_rue IS NULL AND p.building_id=p_batiment AND p.room_id=p_piece) )
    AND ( (m.famille='employe' AND m.proprietaire_pj IS NOT NULL AND m.proprietaire_pj IS DISTINCT FROM p_cible
           AND EXISTS (SELECT 1 FROM public.pnj_employes_metier e WHERE e.pnj_id=m.id AND e.job IN ('agent_securite','maitre_chien')))
       OR (m.famille='soldat' AND m.leader_pj IS DISTINCT FROM p_cible
           AND EXISTS (SELECT 1 FROM public.pnj_soldats_metier sm WHERE sm.pnj_id=m.id AND sm.en_reserve=false)) )
 ) f;
$function$;

-- La dissuasion compte désormais les soldats par la liste commune : plus de compte séparé
-- « mission securiser » (qui n'existe plus), pour ne jamais compter deux fois un soldat.
CREATE OR REPLACE FUNCTION public.securite_malus_lieu_interne(p_acteur text)
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d record; v_rue text; v_hommes integer := 0; v_g jsonb;
BEGIN
  SELECT country, current_city, current_building, current_room, current_street INTO d
    FROM public.personnages_donnees WHERE name = p_acteur;
  IF NOT FOUND OR d.country IS NULL OR d.current_city IS NULL THEN RETURN 0; END IF;
  v_rue := CASE WHEN d.current_building IS NULL THEN d.current_street END;
  IF d.current_building IS NULL AND v_rue IS NULL THEN RETURN 0; END IF;
  -- Agents de sécurité privée et soldats postés présents, hors ceux de l'auteur ou qui le suivent.
  v_hommes := jsonb_array_length(coalesce(public.securite_agents_prives_presents_interne(
    d.country, d.current_city, d.current_building, d.current_room, v_rue, p_acteur), '[]'::jsonb));
  IF d.current_building IS NOT NULL THEN
    v_g := public.garde_republicaine_piece(d.country, d.current_building, d.current_room);
    v_hommes := v_hommes + coalesce(CASE WHEN jsonb_typeof(v_g -> 'gardes') = 'number' THEN (v_g ->> 'gardes')::integer END, 0);
  END IF;
  RETURN CASE WHEN v_hommes > 0 THEN least(40, 10 + v_hommes) ELSE 0 END;
END; $function$;

-- Le déplacement ne joue plus de détachement « arrêter » (mission retirée) ; le couvre-feu reste.
CREATE OR REPLACE FUNCTION public.navigation_interieure(p_batiment text, p_piece text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text := public.mon_personnage(); v_avant text; v jsonb; v_arr jsonb;
BEGIN
  SELECT current_building INTO v_avant FROM public.personnages_donnees WHERE name = v_moi;
  v := public.navigation_commander_interne('piece', p_batiment, p_piece);
  -- controles_entree_zone_serveur_v2 : patrouille du couvre-feu à l'entrée d'un bâtiment.
  IF v_moi IS NOT NULL AND p_batiment IS NOT NULL AND coalesce((v ->> 'ok')::boolean, false)
     AND v_avant IS DISTINCT FROM p_batiment THEN
    v_arr := public.controle_couvre_feu_interne(v_moi);
    IF v_arr IS NOT NULL THEN v := v || jsonb_build_object('arrestation', v_arr); END IF;
  END IF;
  RETURN v;
END $$;
REVOKE ALL ON FUNCTION public.navigation_interieure(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.navigation_interieure(text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.controle_detachement_interne(text);
DROP FUNCTION IF EXISTS public.militaire_detachement_arrestation();
REVOKE EXECUTE ON FUNCTION public.militaire_assigner_mission(text, text, text, text) FROM PUBLIC, anon, authenticated;
DELETE FROM public.ordres_couts WHERE fn = 'assigner_mission';

DO $$
BEGIN
  IF has_function_privilege('authenticated', 'public.militaire_assigner_mission(text,text,text,text)', 'execute') THEN
    RAISE EXCEPTION 'militaire_assigner_mission encore ouverte';
  END IF;
  IF position('soldats_renforts_policiers_v1' in pg_get_functiondef('public.securite_agents_prives_presents_interne(text,text,text,text,text,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'renforts policiers absents';
  END IF;
END $$;
