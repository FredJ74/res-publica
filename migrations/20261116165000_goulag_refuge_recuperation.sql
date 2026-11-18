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
  paiements jsonb NOT NULL DEFAULT '[]'::jsonb CHECK(jsonb_typeof(paiements)='array'),
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
    derniere_nuit=NULL,bois_paye=0,paiements='[]'::jsonb,termine=false,actualise_le=now()
    WHERE sovarka_goulag_refuges.termine;
  IF NOT FOUND THEN RAISE EXCEPTION 'goulag_refuge_deja_actif'; END IF;
  RETURN jsonb_build_object('ok',true,'arrivee',p_destination,'repos_jours',3,'pa',1);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_creer_interne(text,text,text)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_cible_interne(p_nuits integer,p_arrivee date,p_derniere date,p_nuit boolean)
RETURNS integer LANGUAGE sql STABLE SET search_path TO 'public','pg_temp' AS $$
 SELECT least(2,greatest(p_nuits,least(2,greatest(0,public.sovarka_jour_paris()-p_arrivee)),
  CASE WHEN p_nuit AND p_derniere IS DISTINCT FROM public.sovarka_jour_paris() THEN p_nuits+1 ELSE p_nuits END))
$$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_cible_interne(integer,date,date,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_r public.sovarka_goulag_refuges%ROWTYPE; v_reglement jsonb;
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
    'termine',v_r.termine,'bois_prochain',CASE WHEN v_r.termine OR v_r.nuits>=2 THEN 0 ELSE
    (CASE WHEN v_r.nuits=0 THEN 5 ELSE 0 END)+
    (CASE WHEN public.sovarka_goulag_refuge_cible_interne(v_r.nuits,v_r.arrivee_le,v_r.derniere_nuit,true)=2 THEN 3 ELSE 0 END) END);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_lire() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_refuge_lire() TO authenticated;

-- Rattrapage des deux nuits écoulées : aucune connexion quotidienne n'est requise.
-- Les dates restent celles des nuits du repos initial, jamais une troisième nuit.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_regler_interne(p_nom text,p_nuit boolean,p_max_bois integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_r public.sovarka_goulag_refuges%ROWTYPE; v_p record;
 v_jour date:=public.sovarka_jour_paris(); v_cible integer; v_requis integer;
 v_bois integer; v_total integer:=0; v_ligne jsonb; v_inv jsonb; v_paiements jsonb:='[]';
BEGIN
 SELECT country,current_city,current_building,current_room,inventory INTO v_p
 FROM public.personnages_donnees WHERE name=p_nom FOR UPDATE;
 IF NOT FOUND OR v_p.country IS DISTINCT FROM 'soviet' THEN
  RETURN jsonb_build_object('ok',false,'raison','hors_sovarka'); END IF;
 SELECT * INTO v_r FROM public.sovarka_goulag_refuges WHERE nom=p_nom FOR UPDATE;
 IF NOT FOUND OR v_r.termine THEN RETURN jsonb_build_object('ok',false,'raison','repos_non_actif'); END IF;
 IF (v_p.current_city,v_p.current_building,v_p.current_room) IS DISTINCT FROM
  (CASE v_r.destination WHEN 'starovka' THEN 'ville_a' ELSE 'ville_b' END,
   CASE v_r.destination WHEN 'starovka' THEN 'maison-starovka' ELSE 'maison-krasnov' END,'piece_maison') THEN
  RETURN jsonb_build_object('ok',false,'raison','habitant_absent'); END IF;
 IF v_jour<v_r.arrivee_le THEN RETURN jsonb_build_object('ok',false,'raison','jour_invalide'); END IF;
 v_cible:=public.sovarka_goulag_refuge_cible_interne(v_r.nuits,v_r.arrivee_le,v_r.derniere_nuit,p_nuit);
 IF v_cible<=v_r.nuits THEN
  RETURN jsonb_build_object('ok',NOT p_nuit,'raison','nuit_deja_prise','nuits',v_r.nuits,'bois_preleves',0); END IF;
 v_requis:=CASE WHEN v_r.nuits=0 THEN 5 ELSE 0 END+CASE WHEN v_cible=2 AND v_r.nuits<2 THEN 3 ELSE 0 END;
 IF p_max_bois IS NULL OR p_max_bois<v_requis THEN
  RETURN jsonb_build_object('ok',false,'raison','bois_a_confirmer','requis',v_requis); END IF;
 v_ligne:=public.sovarka_inventaire_ligne_interne(v_p.inventory,ARRAY['bois']);
 IF coalesce((v_ligne->>'qte')::integer,0)<v_requis THEN
  RETURN jsonb_build_object('ok',false,'raison','bois_insuffisant','requis',v_requis); END IF;
 WHILE v_r.nuits<v_cible LOOP
  v_bois:=CASE WHEN v_r.nuits=0 THEN 5 ELSE 3 END;
  SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name=p_nom;
  v_ligne:=public.sovarka_inventaire_ligne_interne(v_inv,ARRAY['bois']);
  PERFORM public.sovarka_inventaire_retirer_interne(p_nom,v_ligne,v_bois);
  v_paiements:=v_paiements||jsonb_build_array(jsonb_build_object('nuit',v_r.nuits+1,
    'bois',v_bois,'nuit_le',least(v_jour,v_r.arrivee_le+v_r.nuits),'regle_le',v_jour));
  v_r.nuits:=v_r.nuits+1;v_total:=v_total+v_bois;
 END LOOP;
 UPDATE public.sovarka_goulag_refuges SET nuits=v_r.nuits,
  derniere_nuit=least(v_jour,v_r.arrivee_le+v_r.nuits-1),bois_paye=bois_paye+v_total,
  paiements=paiements||v_paiements,actualise_le=now() WHERE nom=p_nom;
 RETURN jsonb_build_object('ok',true,'nuit',v_r.nuits,'nuits',v_r.nuits,
  'bois_preleves',v_total,'bois_total',v_r.bois_paye+v_total,'paiements',v_paiements)
  ||(SELECT jsonb_build_object('inventory',inventory,'revision',inventory_revision)
    FROM public.personnages_donnees WHERE name=p_nom);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_regler_interne(text,boolean,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_nuit(p_max_bois integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage();
BEGIN
 IF auth.uid() IS NULL OR v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid()) THEN
  RETURN jsonb_build_object('ok',false,'raison','sans_personnage'); END IF;
 RETURN public.sovarka_goulag_refuge_regler_interne(v_nom,true,p_max_bois);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_nuit(integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_refuge_nuit(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_terminer(p_max_bois integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_r public.sovarka_goulag_refuges%ROWTYPE; v_reglement jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  SELECT * INTO v_r FROM public.sovarka_goulag_refuges WHERE nom=v_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_refuge'); END IF;
  IF v_r.termine THEN RETURN jsonb_build_object('ok',true,'deja_termine',true); END IF;
  -- Après une déconnexion prolongée, solder les nuits dues au lieu de bloquer le PJ.
  IF public.sovarka_jour_paris()>=v_r.arrivee_le+3 AND v_r.nuits<2 THEN
    v_reglement:=public.sovarka_goulag_refuge_regler_interne(v_nom,false,p_max_bois);
    IF coalesce((v_reglement->>'ok')::boolean,false) IS NOT TRUE THEN RETURN v_reglement; END IF;
    SELECT * INTO v_r FROM public.sovarka_goulag_refuges WHERE nom=v_nom;
  END IF;
  IF public.sovarka_jour_paris() < v_r.arrivee_le+3 OR v_r.nuits<2 THEN
    RETURN jsonb_build_object('ok',false,'raison','recuperation_incomplete',
       'repos_jusqu_au',v_r.arrivee_le+3,'nuits',v_r.nuits); END IF;
  UPDATE public.sovarka_goulag_refuges SET termine=true,actualise_le=now() WHERE nom=v_nom;
  RETURN coalesce(v_reglement,'{}'::jsonb)||jsonb_build_object('ok',true,'termine',true);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_terminer(integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_refuge_terminer(integer) TO authenticated;
