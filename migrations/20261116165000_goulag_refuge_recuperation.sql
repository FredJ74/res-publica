-- Goulag : récupération après la toundra, préparée sans modifier les
-- interactions des habitants. Règles : 1 PA à l'arrivée, trois jours de repos,
-- deux nuits (5 bois puis 3 bois), aucun troisième paiement.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_refuges (
  nom text PRIMARY KEY REFERENCES public.personnages_donnees(name),
  destination text NOT NULL CHECK(destination IN('starovka','krasnov')),
  statut text NOT NULL CHECK(statut IN('detenu','visiteur')),
  arrivee_le date NOT NULL,
  nuits integer NOT NULL DEFAULT 0 CHECK(nuits BETWEEN 0 AND 2),
  derniere_nuit date,
  bois_paye integer NOT NULL DEFAULT 0 CHECK(bois_paye IN(0,5,8)),
  termine boolean NOT NULL DEFAULT false,
  actualise_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_goulag_refuges ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_refuges FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_creer_interne(
  p_nom text,p_destination text,p_statut text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_ville text;
BEGIN
  v_ville:=CASE p_destination WHEN 'starovka' THEN 'ville_a' WHEN 'krasnov' THEN 'ville_b' END;
  IF v_ville IS NULL OR p_statut NOT IN ('detenu','visiteur') OR p_statut IS NULL
    THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees
      WHERE name=p_nom AND country='soviet' AND current_city=v_ville AND pa=1) THEN
    RETURN jsonb_build_object('ok',false,'raison','arrivee_non_confirmee'); END IF;
  INSERT INTO public.sovarka_goulag_refuges(nom,destination,statut,arrivee_le)
  VALUES(p_nom,p_destination,p_statut,public.sovarka_jour_paris())
  ON CONFLICT(nom) DO UPDATE SET destination=EXCLUDED.destination,
    statut=EXCLUDED.statut,arrivee_le=EXCLUDED.arrivee_le,nuits=0,
    derniere_nuit=NULL,bois_paye=0,termine=false,actualise_le=now()
    WHERE sovarka_goulag_refuges.termine;
  IF NOT FOUND THEN RAISE EXCEPTION 'goulag_refuge_deja_actif'; END IF;
  RETURN jsonb_build_object('ok',true,'arrivee',p_destination,'repos_jours',3,'pa',1);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_creer_interne(text,text,text)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_r public.sovarka_goulag_refuges%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  SELECT r.* INTO v_r FROM public.sovarka_goulag_refuges r
    JOIN public.personnages_donnees p ON p.name=r.nom AND p.user_id=auth.uid()
    WHERE r.nom=v_nom;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_refuge'); END IF;
  RETURN jsonb_build_object('ok',true,'destination',v_r.destination,'statut',v_r.statut,
    'nuits',v_r.nuits,'bois_paye',v_r.bois_paye,'arrivee_le',v_r.arrivee_le,
    'jour',public.sovarka_jour_paris(),'repos_jusqu_au',v_r.arrivee_le+3,
    'termine',v_r.termine);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_lire() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_refuge_lire() TO authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_nuit()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_r public.sovarka_goulag_refuges%ROWTYPE;
        v_p record; v_jour date:=public.sovarka_jour_paris(); v_bois integer;
        v_ligne jsonb; v_inv jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  SELECT country,current_city,current_building,current_room,inventory INTO v_p
    FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR v_p.country<>'soviet' THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_sovarka'); END IF;
  SELECT * INTO v_r FROM public.sovarka_goulag_refuges WHERE nom=v_nom FOR UPDATE;
  IF NOT FOUND OR v_r.termine THEN
    RETURN jsonb_build_object('ok',false,'raison','repos_non_actif'); END IF;
  IF (v_r.destination='starovka' AND (v_p.current_city,v_p.current_building,v_p.current_room)
      IS DISTINCT FROM ('ville_a','maison-starovka','piece_maison'))
     OR (v_r.destination='krasnov' AND (v_p.current_city,v_p.current_building,v_p.current_room)
      IS DISTINCT FROM ('ville_b','maison-krasnov','piece_maison')) THEN
    RETURN jsonb_build_object('ok',false,'raison','habitant_absent'); END IF;
  IF v_jour < v_r.arrivee_le OR v_jour >= v_r.arrivee_le + 3 THEN
    RETURN jsonb_build_object('ok',false,'raison','repos_termine'); END IF;
  IF v_r.nuits>=2 OR v_r.derniere_nuit IS NOT DISTINCT FROM v_jour THEN
    RETURN jsonb_build_object('ok',false,'raison','nuit_deja_prise'); END IF;
  v_bois:=CASE WHEN v_r.nuits=0 THEN 5 ELSE 3 END;
  v_ligne:=public.sovarka_inventaire_ligne_interne(v_p.inventory,ARRAY['bois']);
  IF coalesce((v_ligne->>'qte')::integer,0)<v_bois THEN
    RETURN jsonb_build_object('ok',false,'raison','bois_insuffisant','requis',v_bois); END IF;
  PERFORM public.sovarka_inventaire_retirer_interne(v_nom,v_ligne,v_bois);
  UPDATE public.sovarka_goulag_refuges
    SET nuits=nuits+1,derniere_nuit=v_jour,bois_paye=bois_paye+v_bois,actualise_le=now()
    WHERE nom=v_nom;
  SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name=v_nom;
  RETURN jsonb_build_object('ok',true,'nuit',v_r.nuits+1,'bois_preleves',v_bois,
     'bois_total',v_r.bois_paye+v_bois,'inventory',v_inv,
     'revision',(SELECT inventory_revision FROM public.personnages_donnees WHERE name=v_nom));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_nuit() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_refuge_nuit() TO authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_terminer()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_r public.sovarka_goulag_refuges%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  SELECT * INTO v_r FROM public.sovarka_goulag_refuges WHERE nom=v_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_refuge'); END IF;
  IF v_r.termine THEN RETURN jsonb_build_object('ok',true,'deja_termine',true); END IF;
  IF public.sovarka_jour_paris() < v_r.arrivee_le+3 OR v_r.nuits<2 THEN
    RETURN jsonb_build_object('ok',false,'raison','recuperation_incomplete',
       'repos_jusqu_au',v_r.arrivee_le+3,'nuits',v_r.nuits); END IF;
  UPDATE public.sovarka_goulag_refuges SET termine=true,actualise_le=now() WHERE nom=v_nom;
  RETURN jsonb_build_object('ok',true,'termine',true);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_terminer() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_refuge_terminer() TO authenticated;
