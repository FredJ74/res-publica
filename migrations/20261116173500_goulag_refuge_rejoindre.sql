-- Refuge du goulag : rejoindre la maison d'accueil depuis le point d'arrivée,
-- sans inventer de sortie de rue générale ni autoriser un téléporteur libre.
-- Le fugitif arrive réellement sur le noeud de rue prévu, puis frappe à la
-- porte de l'habitant qui l'accueille toujours pendant sa convalescence.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_rejoindre()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage();
        v_p public.personnages_donnees%ROWTYPE;
        v_r public.sovarka_goulag_refuges%ROWTYPE;
        v_c public.sovarka_goulag_configuration%ROWTYPE;
        v_ville text; v_noeud text; v_maison text;
BEGIN
 IF auth.uid() IS NULL OR v_nom IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_p FROM public.personnages_donnees
  WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_r FROM public.sovarka_goulag_refuges WHERE nom=v_nom FOR UPDATE;
 IF NOT FOUND OR v_r.termine THEN
  RETURN jsonb_build_object('ok',false,'raison','refuge_non_actif'); END IF;
 IF v_r.destination='starovka' THEN
  v_ville:='ville_a';v_noeud:='starovka-rue-stade';v_maison:='maison-starovka';
 ELSIF v_r.destination='krasnov' THEN
  SELECT * INTO v_c FROM public.sovarka_goulag_configuration WHERE singleton;
  IF v_c.camp_bucherons_noeud IS NULL THEN
   RETURN jsonb_build_object('ok',false,'raison','camp_bucherons_non_reference'); END IF;
  v_ville:='ville_b';v_noeud:=v_c.camp_bucherons_noeud;v_maison:='maison-krasnov';
 ELSE
  RETURN jsonb_build_object('ok',false,'raison','destination_inconnue');
 END IF;
 IF (v_p.country,v_p.current_city,v_p.current_building,v_p.current_room)
   IS NOT DISTINCT FROM ('soviet',v_ville,v_maison,'piece_maison') THEN
  RETURN jsonb_build_object('ok',true,'deja_arrive',true,
   'batiment',v_maison,'piece','piece_maison');
 END IF;
 IF (v_p.country,v_p.current_city,v_p.current_building,v_p.current_room,v_p.current_street)
   IS DISTINCT FROM ('soviet',v_ville,NULL,NULL,v_noeud) THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_au_point_arrivee'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles n
   WHERE n.pays='soviet' AND n.ville=v_ville AND n.batiment=v_maison
     AND n.pieces ? 'piece_maison') THEN
  RETURN jsonb_build_object('ok',false,'raison','maison_non_referencee'); END IF;
 UPDATE public.personnages_donnees SET current_building=v_maison,
   current_room='piece_maison',current_street=NULL,updated_at=clock_timestamp()
 WHERE name=v_nom AND user_id=auth.uid();
 RETURN jsonb_build_object('ok',true,'batiment',v_maison,'piece','piece_maison');
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_rejoindre() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_refuge_rejoindre() TO authenticated;
