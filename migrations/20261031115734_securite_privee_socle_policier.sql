-- Garde de reprise : aucun effacement ni conversion implicite d'un ancien déploiement.
DO $prevol$
BEGIN
 IF EXISTS(SELECT 1 FROM pg_attribute
   WHERE attrelid=to_regclass('public.pnj_membres') AND attname='groupe_deploiement_id'
     AND attnum>0 AND NOT attisdropped) THEN
  RAISE EXCEPTION 'audit135_ancien_deploiement_a_reconcilier';
 END IF;
 IF to_regclass('public.chantier_vigiles_affectations') IS NOT NULL THEN
  RAISE EXCEPTION 'audit135_ancien_socle_196_a_auditer';
 END IF;
END $prevol$;

-- #135 : adaptateur commun de présence et de déploiement.
-- Aucun identifiant parallèle : les liens leader_pnj_id existants portent l'unité.

-- Corriger la position commune au lieu de la recomposer dans l'adaptateur privé.
DO $position$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.pnj_position_effective(text)'::regprocedure);
 a:='CASE WHEN m.leader_pj IS NOT NULL THEN NULL';
 b:='CASE WHEN m.leader_pj IS NOT NULL THEN d.current_street';
 IF position(b in s)=0 THEN
  IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'position_pnj_definition_non_examinee'; END IF;
  EXECUTE replace(s,a,b);
 END IF;
 s:=pg_get_functiondef('public.pnj_co_present(text,text)'::regprocedure);
 a:='SELECT country, current_city, current_building, current_room INTO a';
 b:='SELECT country, current_city, current_building, current_room, current_street INTO a';
 IF position(b in s)=0 THEN
  IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'copresence_pnj_definition_non_examinee'; END IF;
  s:=replace(s,a,b);
 END IF;
 a:='  IF pe.ville IS NULL THEN RETURN false; END IF;';
 b:=a||chr(10)||'  IF a.current_building IS NULL AND pe.building_id IS NULL AND pe.rue_noeud_id IS NOT NULL THEN'
  ||chr(10)||'    RETURN coalesce(pe.pays=a.country AND pe.ville=a.current_city AND pe.rue_noeud_id=a.current_street,false);'
  ||chr(10)||'  END IF;';
 IF position(b in s)=0 THEN
  IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'copresence_rue_definition_non_examinee'; END IF;
  s:=replace(s,a,b);
 END IF;
 EXECUTE s;
END $position$;

-- Les policiers et les agents privés sont arbitrés par les mêmes RPC police_*.
CREATE OR REPLACE FUNCTION public.securite_agents_prives_presents_interne(
  p_pays text, p_ville text, p_batiment text, p_piece text, p_rue text, p_cible text
) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $hg$
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'pnj_prive_id',m.id, 'matricule','prive:'||m.id,
   'groupeCle',coalesce(m.leader_pnj_id,m.id),
   'pa',m.pa, 'stats',jsonb_build_object('PER',m.car_per,'VOL',m.car_vol),
   'buildingId',p.building_id,'roomId',p.room_id,'rueNoeudId',p.rue_noeud_id
 ) ORDER BY m.id),'[]'::jsonb)
 FROM public.pnj_membres m
 JOIN public.pnj_employes_metier e ON e.pnj_id=m.id
 CROSS JOIN LATERAL public.pnj_position_effective(m.id) p
 WHERE e.job IN ('agent_securite','maitre_chien')
   AND m.famille='employe' AND m.statut='actif'
   AND m.proprietaire_pj IS NOT NULL AND m.proprietaire_pj IS DISTINCT FROM p_cible
   AND m.pa>0 AND m.car_per IS NOT NULL AND m.car_vol IS NOT NULL
   AND m.pays=p_pays AND p.pays=p_pays AND p.ville=p_ville
   AND ( (p_rue IS NOT NULL AND p.rue_noeud_id=p_rue AND p.building_id IS NULL)
      OR (p_rue IS NULL AND p.building_id=p_batiment AND p.room_id=p_piece) );
$hg$;
REVOKE ALL ON FUNCTION public.securite_agents_prives_presents_interne(text,text,text,text,text,text)
 FROM PUBLIC,anon,authenticated,service_role;

-- La reprise d'un groupe lié doit valider toutes les positions AVANT de déplacer l'ancre.
DO $reprise$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.pnj_prendre(text[])'::regprocedure);
 a:='    UPDATE public.pnj_membres SET leader_pj = v_moi, leader_pnj_id = NULL,';
 b:='  END LOOP;'
  ||chr(10)||'  v_refus:=public.pnj_quitter_groupe(p_ids);'
  ||chr(10)||'  IF NOT coalesce((v_refus->>''ok'')::boolean,false) THEN RAISE EXCEPTION ''reprise_pnj_depose_refusee: %'',v_refus; END IF;'
  ||chr(10)||'  FOR r IN SELECT id FROM public.pnj_membres'
  ||chr(10)||'    WHERE id = ANY(p_ids) AND statut = ''actif'' ORDER BY id FOR UPDATE LOOP'
  ||chr(10)||a;
 IF position(b in s)>0 THEN RETURN; END IF;
 IF (length(s)-length(replace(s,b,'')))/length(b)=1 THEN NULL;
 ELSIF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'reprise_pnj_definition_non_examinee';
 ELSE s:=replace(s,a,b); END IF;
 EXECUTE s;
END $reprise$;

-- Adaptateur de l'ordre existant de dépose, pas un second moteur de mouvement.
-- Le premier PNJ est l'ancre de position ; les autres suivent son lien existant.
CREATE OR REPLACE FUNCTION public.pnj_deployer_unite(
 p_pnj_ids text[], p_groupe boolean DEFAULT true
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $hg$
DECLARE v_chef text; v_lieu public.personnages_donnees%ROWTYPE;
 v_ids text[]; v_r jsonb; v_nb integer;
BEGIN
 v_chef:=public.mon_personnage();
 IF v_chef IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT array_agg(DISTINCT z ORDER BY z) INTO v_ids FROM unnest(p_pnj_ids) z
 WHERE z IS NOT NULL AND length(z)>0;
 IF v_ids IS NULL OR cardinality(v_ids)<>cardinality(p_pnj_ids)
 THEN RETURN jsonb_build_object('ok',false,'raison','identifiants_invalides'); END IF;
 SELECT * INTO v_lieu FROM public.personnages_donnees WHERE name=v_chef FOR UPDATE;
 IF NOT FOUND OR v_lieu.current_city IS NULL OR
  (v_lieu.current_building IS NULL AND v_lieu.current_street IS NULL)
 THEN RETURN jsonb_build_object('ok',false,'raison','position_invalide'); END IF;
 -- Verrouiller avant de vérifier : aucune mutation d'autorité entre garde et dépose.
 PERFORM m.id FROM public.pnj_membres m WHERE m.id=ANY(v_ids) ORDER BY m.id FOR UPDATE;
 SELECT count(*) INTO v_nb FROM public.pnj_membres m
 WHERE m.id=ANY(v_ids) AND m.statut='actif' AND m.leader_pj=v_chef
   AND m.leader_pnj_id IS NULL AND m.pays=v_lieu.country;
 IF v_nb<>cardinality(v_ids) THEN
  RETURN jsonb_build_object('ok',false,'raison','groupe_non_commande'); END IF;
 BEGIN
  -- Conserver les contrôles de famille/métier et l'autorité de l'ordre commun.
  v_r:=public.pnj_quitter_groupe(v_ids);
  IF NOT coalesce((v_r->>'ok')::boolean,false) THEN
   RAISE EXCEPTION USING ERRCODE='P1350',MESSAGE='depose_refusee'; END IF;
  UPDATE public.pnj_membres SET rue_noeud_id=v_lieu.current_street,maj_le=now()
   WHERE id=ANY(v_ids);
  IF coalesce(p_groupe,true) AND cardinality(v_ids)>1 THEN
   UPDATE public.pnj_membres SET leader_pnj_id=v_ids[1],
    ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL
   WHERE id=ANY(v_ids) AND id<>v_ids[1];
  END IF;
 EXCEPTION WHEN SQLSTATE 'P1350' THEN RETURN v_r;
 END;
 RETURN jsonb_build_object('ok',true,'deployes',cardinality(v_ids),
   'ensemble',coalesce(p_groupe,true),'groupe',
   CASE WHEN coalesce(p_groupe,true) AND cardinality(v_ids)>1 THEN v_ids[1] ELSE NULL END);
END $hg$;
REVOKE ALL ON FUNCTION public.pnj_deployer_unite(text[],boolean) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.pnj_deployer_unite(text[],boolean) TO authenticated;

-- #135 : les groupes constitués et les patrouilles isolées sont différents.
-- Les policiers du catalogue actuel n'ont pas de chef de groupe : chaque matricule
-- constitue donc une unité isolée, sauf si un regroupement explicite est déjà indiqué (`groupe_id` militaire).
-- Les PNJ privés réutilisent leader_pnj_id (socle de déplacement/embauche).
CREATE OR REPLACE FUNCTION public.securite_ordre_detection_interne(
 p_agents jsonb,p_batiment text,p_piece text,p_rue text
) RETURNS jsonb LANGUAGE sql VOLATILE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $hg$
 WITH presents AS (
  SELECT x AS agent,
    CASE WHEN x ? 'pnj_prive_id' THEN 1 ELSE 0 END AS categorie,
    CASE WHEN x ? 'pnj_prive_id'
      THEN 'prive:'||coalesce(x->>'groupeCle',x->>'pnj_prive_id')
      ELSE 'police:'||coalesce(nullif(x->>'groupe_id',''),nullif(x->>'groupeId',''),x->>'matricule')
    END AS groupe
  FROM jsonb_array_elements(coalesce(p_agents,'[]'::jsonb)) AS x
  WHERE nullif(x->>'matricule','') IS NOT NULL
    AND coalesce((x->>'pa')::integer,12)>0
    AND ((p_rue IS NOT NULL AND x->>'rueNoeudId'=p_rue)
      OR (p_rue IS NULL AND x->>'buildingId'=p_batiment AND x->>'roomId'=p_piece))
 ), groupes AS (
  SELECT categorie,groupe,count(*)::integer AS effectif,
    avg(coalesce((agent->'stats'->>'PER')::numeric,12))+(count(*)-1)
      -CASE WHEN p_rue IS NOT NULL THEN 2 ELSE 0 END AS perception,
    jsonb_agg(agent->>'matricule') AS matricules
  FROM presents GROUP BY categorie,groupe
 ), ordonnes AS (
  SELECT *,random() AS tirage FROM groupes
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'categorie',categorie,'groupe',groupe,'effectif',effectif,
   'perception',perception,'matricules',matricules
 ) ORDER BY categorie,effectif DESC,tirage),'[]'::jsonb)
 FROM ordonnes;
$hg$;
REVOKE ALL ON FUNCTION public.securite_ordre_detection_interne(jsonb,text,text,text)
 FROM PUBLIC,anon,authenticated,service_role;

-- L'identité des seuls intervenants retenus est jointe à la rencontre policière
-- existante : ni registre d'affectation ni nouveau moteur d'arrestation.
ALTER TABLE public.police_interceptions
 ADD COLUMN IF NOT EXISTS intervenants jsonb;

-- Suite technique scindée : détection puis fuite/combat, sans activation isolée.
