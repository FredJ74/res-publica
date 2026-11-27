-- Ciudad Roja : premier tronçon, autorité serveur. Aucun changement de personnage.
INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions) VALUES
 ('narco','capitale','ciudad-roja-centre-multimodal',ARRAY['ciudad-roja-hotel'],'{"liens":{"arriere":"ciudad-roja-hotel"},"parArrivee":{}}'::jsonb),
 ('narco','capitale','ciudad-roja-hotel',ARRAY['ciudad-roja-centre-multimodal'],'{"liens":{"toutDroit":"ciudad-roja-centre-multimodal"},"parArrivee":{}}'::jsonb)
ON CONFLICT(country,city,noeud) DO UPDATE SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;
INSERT INTO public.rue_sorties_batiments(country,city,noeud,building) VALUES
 ('narco','capitale','ciudad-roja-centre-multimodal','centre-multinodal-luthecia'),
 ('narco','capitale','ciudad-roja-hotel','hotel-republica')
ON CONFLICT DO NOTHING;
UPDATE public.navigation_lieux_regles SET pieces=pieces || '["piscine"]'::jsonb
 WHERE pays='narco' AND ville='capitale' AND batiment='hotel-republica' AND NOT pieces ? 'piscine';
DO $patch$
DECLARE s text; a text;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays='narco' AND ville='capitale' AND batiment='hotel-republica' AND pieces ? 'piscine') THEN RAISE EXCEPTION 'piscine absente'; END IF;
 s:=pg_get_functiondef('public.navigation_rue_trajet_interne(text,text,text,text,text)'::regprocedure);
 IF strpos(s,'ciudad_roja_depart_v1')=0 THEN
 a:='v_depart := CASE p_pays';
 IF strpos(s,a)=0 THEN RAISE EXCEPTION 'ancre depart absente'; END IF;
 s:=replace(s,a,a||E'\n     WHEN ''narco'' THEN CASE p_ville WHEN ''capitale'' THEN ''ciudad-roja-centre-multimodal'' END /* ciudad_roja_depart_v1 */');
 EXECUTE s;
 END IF;
 s:=pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
 IF strpos(s,'ciudad_roja_bar_v1')=0 THEN
 a:=' IF p_batiment=''quartier-ambassades'' AND p_piece IN';
 IF strpos(s,a)=0 THEN RAISE EXCEPTION 'ancre interieur absente'; END IF;
 s:=replace(s,a,$guard$
 -- ciudad_roja_bar_v1 : accès par la piscine uniquement ; sorties piscine ou restaurant.
 IF p.country='narco' AND p.current_city='capitale' AND p_batiment='hotel-republica' THEN
   IF p_piece='bar' AND (p.current_building IS DISTINCT FROM p_batiment OR p.current_room NOT IN ('piscine','bar') OR p.current_room IS NULL) THEN
     RETURN jsonb_build_object('ok',false,'raison','entree_non_accessible'); END IF;
   IF p.current_building=p_batiment AND p.current_room='bar' AND p_piece NOT IN ('piscine','restaurant','bar') THEN
     RETURN jsonb_build_object('ok',false,'raison','entree_non_accessible'); END IF;
 END IF;
$guard$||a);
 EXECUTE s;
 END IF;
END $patch$;
