CREATE OR REPLACE FUNCTION public.rue_position_enregistrer(p_noeud text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE v_nom text; v_pj public.personnages_donnees%ROWTYPE; v_noeud public.rue_noeuds_serveur%ROWTYPE;
 v_depart text;
BEGIN
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom FOR UPDATE;
 IF NOT FOUND OR v_pj.est_emprisonne IS NOT NULL AND v_pj.est_emprisonne<>'null'::jsonb THEN
 RETURN jsonb_build_object('ok',false,'raison','personnage_indisponible'); END IF;
 IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE personnage=v_nom AND expires_at>now()) THEN
 RETURN jsonb_build_object('ok',false,'raison','interception_en_cours'); END IF;
 SELECT * INTO v_noeud FROM public.rue_noeuds_serveur WHERE country=v_pj.country AND city=v_pj.current_city AND noeud=p_noeud;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','noeud_inconnu'); END IF;
 IF v_pj.current_building IS NOT NULL THEN
 IF NOT EXISTS(SELECT 1 FROM public.rue_sorties_batiments
 WHERE country=v_pj.country AND city=v_pj.current_city AND building=v_pj.current_building AND noeud=p_noeud) THEN
 RETURN jsonb_build_object('ok',false,'raison','sortie_invalide'); END IF;
 ELSIF v_pj.current_street IS NOT NULL AND v_pj.current_street<>p_noeud THEN
 IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
 WHERE country=v_pj.country AND city=v_pj.current_city AND noeud=v_pj.current_street
 AND p_noeud=ANY(voisins)) THEN RETURN jsonb_build_object('ok',false,'raison','trajet_invalide'); END IF;
 ELSIF v_pj.current_street IS NULL THEN
 v_depart:=CASE v_pj.current_city WHEN 'capitale' THEN 'luthecia-palais-presidentiel'
 WHEN 'ville_a' THEN 'psm-centre-multimodal' WHEN 'ville_b' THEN 'montrouge-vue-3' ELSE NULL END;
 IF p_noeud IS DISTINCT FROM v_depart THEN RETURN jsonb_build_object('ok',false,'raison','position_initiale_invalide'); END IF;
 END IF;
 UPDATE public.personnages_donnees SET current_building=NULL,current_room=NULL,current_street=p_noeud WHERE id=v_pj.id;
 UPDATE public.police_interceptions SET expires_at=now() WHERE personnage=v_nom AND expires_at>now();
 RETURN jsonb_build_object('ok',true,'noeud',p_noeud);
END;
$fn$;
REVOKE ALL ON FUNCTION public.rue_position_enregistrer(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.rue_position_enregistrer(text) TO authenticated;
