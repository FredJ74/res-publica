CREATE TABLE IF NOT EXISTS public.rue_sorties_batiments (
 country text NOT NULL,city text NOT NULL,noeud text NOT NULL,building text NOT NULL,
 PRIMARY KEY(country,city,noeud,building)
);
ALTER TABLE public.rue_sorties_batiments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rue_sorties_batiments FROM PUBLIC,anon,authenticated;
INSERT INTO public.rue_sorties_batiments(country,city,noeud,building) VALUES
('republic','capitale','luthecia-palais-presidentiel','palais-presidentiel'),
('republic','capitale','luthecia-palais-presidentiel','palais-gouvernement'),
('republic','capitale','luthecia-palais-presidentiel','assemblee'),
('republic','capitale','luthecia-palais-presidentiel','tribunal'),
('republic','capitale','luthecia-hotel-de-ville','mairie-capitale'),
('republic','capitale','luthecia-hotel-de-ville','office-notarial'),
('republic','capitale','luthecia-hotel-de-ville','hotel-republica'),
('republic','capitale','luthecia-hotel-de-ville','banque-nationale'),
('republic','capitale','luthecia-loge','banque-privee'),
('republic','capitale','luthecia-loge','clinique-privee'),
('republic','capitale','luthecia-loge','loge-maconnique'),
('republic','capitale','luthecia-loge','commissariat'),
('republic','capitale','luthecia-imprimerie','universite'),
('republic','capitale','luthecia-imprimerie','dispensaire-public'),
('republic','capitale','luthecia-imprimerie','la-tribune'),
('republic','capitale','luthecia-musees','musee-ville-luthecia'),
('republic','capitale','luthecia-musees','parc-botanique-national'),
('republic','capitale','luthecia-musees','musee-national-republia'),
('republic','capitale','luthecia-quartier-ambassades','quartier-ambassades'),
('republic','capitale','luthecia-stade-multimodal','stade'),
('republic','capitale','luthecia-stade-multimodal','place-formulaire-liberte'),
('republic','capitale','luthecia-usine-pharmaceutique','usine-pharmaceutique-luthecia'),
('republic','capitale','luthecia-entrepot-logistique','entrepot-logistique-luthecia'),
('republic','capitale','luthecia-centre-multimodal','centre-multinodal-luthecia'),
('republic','capitale','luthecia-centre-commercial','centre-affaires'),
('republic','capitale','luthecia-centre-commercial','centre-commercial'),
('republic','capitale','luthecia-bureau-emploi','bureau-national-emploi'),
('republic','capitale','luthecia-terrains-artisanal','centre-artisanal'),
('republic','capitale','luthecia-terrains-lots','terrain-a-batir-1'),
('republic','capitale','luthecia-terrains-lots','terrain-a-batir-2'),
('republic','capitale','luthecia-terrains-lots','terrain-a-batir-3'),
('republic','capitale','luthecia-terrains-lots','terrain-a-batir-4'),
('republic','capitale','luthecia-terrains-lots','terrain-a-batir-5'),
('republic','capitale','luthecia-armurerie','armurerie'),
('republic','capitale','luthecia-tabernacle-impots','tabernacle-impots'),
('republic','capitale','luthecia-tabernacle-impots','marche'),
('republic','ville_a','psm-carrefour-musee','musee-port-sainte-marie'),
('republic','ville_a','psm-carrefour-musee','centre-commercial'),
('republic','ville_a','psm-carrefour-musee','centre-affaires'),
('republic','ville_a','psm-carrefour-artisanal-scierie','centre-artisanal'),
('republic','ville_a','psm-carrefour-artisanal-scierie','zone-production'),
('republic','ville_a','psm-centre-multimodal','stade'),
('republic','ville_a','psm-centre-multimodal','centre-multinodal-port-sainte-marie'),
('republic','ville_a','psm-centre-multimodal','port-sainte-marie'),
('republic','ville_a','psm-ecole-phare','ecole-marine'),
('republic','ville_a','psm-ecole-phare','phare-psm'),
('republic','ville_a','psm-dispensaire-port-plaisance','dispensaire-public-v'),
('republic','ville_a','psm-dispensaire-port-plaisance','port-plaisance-psm'),
('republic','ville_a','psm-tribunal-banque','tribunal-local'),
('republic','ville_a','psm-tribunal-banque','banque-locale'),
('republic','ville_a','psm-bar-imprimerie-commissariat','bar-des-pecheurs'),
('republic','ville_a','psm-bar-imprimerie-commissariat','imprimerie-librairie'),
('republic','ville_a','psm-bar-imprimerie-commissariat','commissariat-local'),
('republic','ville_a','psm-marche-resto-chasse','capitaine-sauvage'),
('republic','ville_a','psm-marche-resto-chasse','marche-psm'),
('republic','ville_a','psm-marche-resto-chasse','chasse-peche-psm'),
('republic','ville_a','psm-hotel-mairie-place','place-armes-psm'),
('republic','ville_a','psm-hotel-mairie-place','mairie'),
('republic','ville_a','psm-hotel-mairie-place','hotel-port'),
('republic','ville_a','psm-eglise-cimetiere','notre-dame-mer'),
('republic','ville_a','psm-chantier-naval','chantier-naval'),
('republic','ville_a','psm-pole-tabac-entrepot','pole-tabac-alcools-psm'),
('republic','ville_a','psm-pole-tabac-entrepot','entrepot-logistique-psm'),
('republic','ville_a','psm-terrains-lots','terrain-a-batir-8'),
('republic','ville_a','psm-terrains-lots','terrain-a-batir-9'),
('republic','ville_a','psm-terrains-lots','terrain-a-batir-10'),
('republic','ville_a','psm-terrains-lots','terrain-a-batir-11'),
('republic','ville_a','psm-terrains-lots','caserne-militaire'),
('republic','ville_a','psm-terrains-lots','qhs-prison'),
('republic','ville_b','montrouge-vue-1','hotel-mineur'),
('republic','ville_b','montrouge-vue-1','armurerie'),
('republic','ville_b','montrouge-vue-2','commissariat-local'),
('republic','ville_b','montrouge-vue-2','raffinerie-montrouge'),
('republic','ville_b','montrouge-vue-3','cafe-gare-montrouge'),
('republic','ville_b','montrouge-vue-3','centre-multinodal-montrouge'),
('republic','ville_b','montrouge-vue-3','brasserie-voyageurs-montrouge'),
('republic','ville_b','montrouge-vue-4','entrepot-logistique-montrouge'),
('republic','ville_b','montrouge-vue-4','dispensaire-public-v'),
('republic','ville_b','montrouge-vue-5','stade'),
('republic','ville_b','montrouge-vue-6','centre-commercial'),
('republic','ville_b','montrouge-vue-6','centre-affaires'),
('republic','ville_b','montrouge-vue-7','mairie'),
('republic','ville_b','montrouge-vue-7','place-du-rail-montrouge'),
('republic','ville_b','montrouge-vue-8','musee-histoire-montrouge'),
('republic','ville_b','montrouge-vue-8','banque-locale'),
('republic','ville_b','montrouge-vue-9','loge-maconnique'),
('republic','ville_b','montrouge-vue-9','eglise-montrouge'),
('republic','ville_b','montrouge-vue-10','cinema-montrouge'),
('republic','ville_b','montrouge-vue-10','la-tribune'),
('republic','ville_b','montrouge-vue-11','centre-artisanal'),
('republic','ville_b','montrouge-vue-12','jardins-ouvriers-montrouge'),
('republic','ville_b','montrouge-vue-12','logements-montrouge'),
('republic','ville_b','montrouge-vue-13','marche'),
('republic','ville_b','montrouge-vue-13','cafe-tabac-cheminots-montrouge'),
('republic','ville_b','montrouge-vue-13','...'),
('republic','ville_b','montrouge-vue-13','palais-gouvernement'),
('republic','ville_b','montrouge-vue-13','office-notarial'),
('republic','ville_b','montrouge-vue-13','commissariat'),
('republic','ville_b','montrouge-vue-13','hotel-republica'),
('republic','ville_b','montrouge-vue-13','centre-commercial'),
('republic','ville_b','montrouge-vue-13','centre-affaires'),
('republic','ville_b','montrouge-vue-13','armurerie'),
('republic','ville_b','montrouge-vue-13','kolkhoze-spirituel'),
('republic','ville_b','montrouge-vue-13','centre-multinodal-luthecia'),
('republic','ville_b','montrouge-vue-13','tribunal'),
('republic','ville_b','montrouge-vue-13','la-tribune'),
('republic','ville_b','montrouge-vue-13','clinique-privee'),
('republic','ville_b','montrouge-vue-13','dispensaire-public'),
('republic','ville_b','montrouge-vue-13','stade'),
('republic','ville_b','montrouge-vue-13','centre-artisanal')
ON CONFLICT DO NOTHING;
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
