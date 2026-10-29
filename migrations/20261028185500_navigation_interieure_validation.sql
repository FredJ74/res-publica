-- #219. Préparation interdépendante, aucune activation isolée.
-- Cette garde rejoint le moteur de rue existant : mêmes états bloquants.
CREATE OR REPLACE FUNCTION public.navigation_disponibilite_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE p public.personnages_donnees%ROWTYPE;
BEGIN
 SELECT * INTO p FROM public.personnages_donnees WHERE name=p_nom FOR UPDATE;
 IF NOT FOUND OR (p.est_emprisonne IS NOT NULL AND p.est_emprisonne<>'null'::jsonb) THEN
  RETURN jsonb_build_object('ok',false,'raison','personnage_indisponible'); END IF;
 IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE personnage=p_nom AND expires_at>now()) THEN
  RETURN jsonb_build_object('ok',false,'raison','interception_en_cours'); END IF;
 IF EXISTS(SELECT 1 FROM public.batailles_engagements e JOIN public.batailles b ON b.id=e.bataille_id
  WHERE e.personnage=p_nom AND e.sorti_round IS NULL AND b.statut='en_cours') THEN
  RETURN jsonb_build_object('ok',false,'raison','combat_en_cours'); END IF;
 IF coalesce(p.hp,100)<=0
 OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text
 OR (CASE WHEN coalesce(p.hospitalisation->>'jourFin','')~'^[0-9]+$'
 THEN (p.hospitalisation->>'jourFin')::numeric>coalesce(p.day,1) ELSE false END) THEN
  RETURN jsonb_build_object('ok',false,'raison','acteur_incapacite'); END IF;
 RETURN jsonb_build_object('ok',true);
END $g$;
REVOKE ALL ON FUNCTION public.navigation_disponibilite_interne(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.navigation_interieure_personnage_interne(
 p_nom text,p_batiment text,p_piece text,p_verifier boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE p public.personnages_donnees%ROWTYPE;l public.navigation_lieux_regles%ROWTYPE;r jsonb; total numeric;
BEGIN
 r:=public.navigation_disponibilite_interne(p_nom);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r; END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=p_nom;
 SELECT * INTO l FROM public.navigation_lieux_regles WHERE pays=p.country AND ville=p.current_city AND batiment=p_batiment;
 IF NOT FOUND OR NOT l.pieces ? p_piece THEN RETURN jsonb_build_object('ok',false,'raison','destination_inconnue'); END IF;
 IF l.ferme THEN RETURN jsonb_build_object('ok',false,'raison','acces_restreint'); END IF;
 -- Les restrictions sans porte serveur pour une identité arbitraire restent
 -- fermées, jamais déduites d'un cache ou d'une attestation du navigateur.
 IF l.membership='loge' AND NOT EXISTS(
   SELECT 1 FROM public.organisations o
   WHERE o.data::jsonb->>'type'='loge' AND o.data::jsonb->>'statut'='actif'
   AND EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(o.data::jsonb->'membres')='array'
       THEN o.data::jsonb->'membres' ELSE '[]'::jsonb END) m WHERE m->>'nom'=p_nom)) THEN
  RETURN jsonb_build_object('ok',false,'raison','membre_loge_requis'); END IF;
 IF p_batiment='clinique-privee' AND p_piece~'^chambre_([1-9]|10)$' AND EXISTS(
   SELECT 1 FROM public.locations_actives loc WHERE loc.country=p.country
   AND loc.data->>'buildingId'=p_batiment AND loc.data->>'roomId'=p_piece AND loc.data->>'city'='capitale'
   AND loc.data->>'locataire' IS DISTINCT FROM p_nom AND loc.data->'visitesAutorisees'='false'::jsonb) THEN
  RETURN jsonb_build_object('ok',false,'raison','visite_refusee'); END IF;
 IF (l.membership IS NOT NULL AND l.membership<>'loge') OR p_piece='zone_embarquement'
 OR (p_batiment='quartier-ambassades' AND p_piece IN ('bureau_al_khalija','bureau_sovarka','bureau_el_estado')) THEN
  RETURN jsonb_build_object('ok',false,'raison','acces_collectif_a_raccorder'); END IF;
 IF EXISTS(SELECT 1 FROM public.batiments_fermes f WHERE f.pays=p.country AND f.ville=p.current_city AND f.batiment_id=p_batiment
 AND (f.date_fin_universelle>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date
 OR (f.date_fin_universelle IS NULL AND f.jour_fin>p.day))) THEN
  RETURN jsonb_build_object('ok',false,'raison','batiment_ferme'); END IF;
 IF p.current_building IS DISTINCT FROM p_batiment THEN
  IF p.current_building IS NOT NULL OR NOT EXISTS(SELECT 1 FROM public.rue_sorties_batiments
   WHERE country=p.country AND city=p.current_city AND building=p_batiment AND noeud=p.current_street) THEN
   RETURN jsonb_build_object('ok',false,'raison','entree_non_accessible'); END IF;
  SELECT coalesce(sum(coalesce(nullif(x->>'qty','')::numeric,nullif(x->>'encombrement','')::numeric,1)),0)
   INTO total FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.inventory)='array' THEN p.inventory ELSE '[]'::jsonb END) x;
  IF total>100 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_surcharge'); END IF;
 END IF;
 IF NOT p_verifier AND (p.current_building IS DISTINCT FROM p_batiment OR p.current_room IS DISTINCT FROM p_piece) THEN
  UPDATE public.personnages_donnees SET current_building=p_batiment,current_room=p_piece,current_street=NULL,updated_at=clock_timestamp() WHERE name=p_nom;
 END IF;
 RETURN jsonb_build_object('ok',true,'building',p_batiment,'room',p_piece);
END $g$;
REVOKE ALL ON FUNCTION public.navigation_interieure_personnage_interne(text,text,text,boolean) FROM PUBLIC,anon,authenticated,service_role;

DO $garde$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.rue_position_personnage_interne(text,text,boolean)'::regprocedure);
 IF position('-- navigation_disponibilite_commune_v1' IN s)>0 THEN RETURN; END IF;
 IF md5(s)<>'03020fe045ce82c9a9e7533da696e6ee' THEN RAISE EXCEPTION 'navigation_moteur_rue_non_examine'; END IF;
 a:=substring(s FROM position(' v_nom:=p_nom;' IN s) FOR position(' SELECT * INTO v_noeud' IN s)-position(' v_nom:=p_nom;' IN s));
 IF a IS NULL OR length(a)=0 THEN RAISE EXCEPTION 'navigation_garde_rue_absente'; END IF;
 b:=' -- navigation_disponibilite_commune_v1'||chr(10)||' v_nom:=p_nom;'
 ||chr(10)||' v_refus:=public.navigation_disponibilite_interne(p_nom);'
 ||chr(10)||' IF NOT coalesce((v_refus->>''ok'')::boolean,false) THEN RETURN v_refus; END IF;'
 ||chr(10)||' SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom;'||chr(10);
 s:=replace(s,a,b);s:=replace(s,' v_depart text;',' v_depart text; v_refus jsonb;');
 EXECUTE s;
END $garde$;
