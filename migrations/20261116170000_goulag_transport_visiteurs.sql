-- Goulag Sovarka : décisions de Fred du 16/11, commentaires 6924193788 et 6924385758.
-- Aucun trajet n'est ouvert avant la configuration complète et active.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_configuration (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 active boolean NOT NULL DEFAULT false,
 autorisation_usage text NOT NULL DEFAULT 'permanente' CHECK(autorisation_usage='permanente'),
 retour_visiteur text NOT NULL DEFAULT 'choix_ville' CHECK(retour_visiteur='choix_ville'),
 champignons_malus integer NOT NULL DEFAULT 2 CHECK(champignons_malus=2),
 formule_arrestation text NOT NULL DEFAULT '30_par_entree' CHECK(formule_arrestation='30_par_entree'),
 camp_bucherons_noeud text,
 actualise_le timestamptz NOT NULL DEFAULT now()
);
-- La configuration n'est PAS suffisante pour rendre l'évasion sûre :
-- mise en service soumise à contrôle final et autorisation explicite.
-- Même un changement manuel de active=true est interdit par cette garde.
DO $goulag_activation_figee$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='sovarka_goulag_activation_figee') THEN
    ALTER TABLE public.sovarka_goulag_configuration
      ADD CONSTRAINT sovarka_goulag_activation_figee CHECK(active IS FALSE);
  END IF;
END $goulag_activation_figee$;

INSERT INTO public.sovarka_goulag_configuration(singleton,active) VALUES(true,false)
ON CONFLICT(singleton) DO NOTHING;
ALTER TABLE public.sovarka_goulag_configuration ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_configuration FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE IF NOT EXISTS public.sovarka_goulag_visites (
 nom text PRIMARY KEY REFERENCES public.personnages_donnees(name),
 origine text NOT NULL CHECK(origine IN ('capitale','ville_a','ville_b')),
 autorisation uuid REFERENCES public.sovarka_goulag_autorisations(id),
 present boolean NOT NULL DEFAULT true,
 entre_le timestamptz NOT NULL DEFAULT now(),
 sorti_le timestamptz
);
ALTER TABLE public.sovarka_goulag_visites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_visites FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_voyager(p_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_p record;
        v_conf public.sovarka_goulag_configuration%ROWTYPE;
        v_role text; v_aut public.sovarka_goulag_autorisations%ROWTYPE;
        v_tarif record; v_paiement jsonb; v_dispo jsonb; v_fn text;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF p_mode NOT IN ('train','bus') OR p_mode IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','mode_invalide'); END IF;
  SELECT * INTO v_conf FROM public.sovarka_goulag_configuration WHERE singleton FOR SHARE;
  IF NOT FOUND OR NOT v_conf.active OR v_conf.retour_visiteur IS NULL
    OR v_conf.autorisation_usage IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  SELECT country,current_city,current_building,current_room INTO v_p
    FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR v_p.country IS DISTINCT FROM 'soviet'
    OR v_p.current_city NOT IN ('capitale','ville_a','ville_b') THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_sovarka'); END IF;
  IF coalesce(v_p.current_building,'') NOT LIKE 'centre-multinodal-%'
    OR NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles
          WHERE pays='soviet' AND ville=v_p.current_city AND batiment=v_p.current_building
          AND pieces ? v_p.current_room) THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_au_terminal'); END IF;
  IF EXISTS(SELECT 1 FROM public.detention_active(v_nom)) THEN
    RETURN jsonb_build_object('ok',false,'raison','detenu_transport_interdit'); END IF;
  IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=v_nom OR chef=v_nom)
    THEN RETURN jsonb_build_object('ok',false,'raison','groupe_a_verifier'); END IF;
  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_visites WHERE nom=v_nom AND present)
    THEN RETURN jsonb_build_object('ok',false,'raison','visite_deja_ouverte'); END IF;
  v_role:=public.sovarka_goulag_role_interne(v_nom);
  IF v_role IS NULL THEN
    SELECT * INTO v_aut FROM public.sovarka_goulag_autorisations
      WHERE nom=v_nom AND etat='accordee' ORDER BY decidee_le DESC LIMIT 1 FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok',false,'raison','autorisation_goulag_requise'); END IF;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles
       WHERE pays='soviet' AND ville='qhs' AND batiment='qhs-prison' AND pieces ? 'entree_qhs')
    THEN RETURN jsonb_build_object('ok',false,'raison','goulag_entree_absente'); END IF;
  v_dispo:=public.navigation_disponibilite_interne(v_nom);
  IF NOT coalesce((v_dispo->>'ok')::boolean,false) THEN RETURN v_dispo; END IF;
  v_fn:=CASE p_mode WHEN 'train' THEN 'prendre_train' ELSE 'prendre_bus_taxi' END;
  -- Même tarif national que payer_ordre_interne, aucun montant nouveau.
  SELECT fn,pa,cost INTO v_tarif FROM public.ordres_couts_pays
    WHERE fn=v_fn AND pays='soviet';
  IF NOT FOUND THEN
    SELECT fn,pa,cost INTO v_tarif FROM public.ordres_couts WHERE fn=v_fn;
  END IF;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','tarif_absent'); END IF;
  v_paiement:=public.payer_ordre_interne(v_nom,v_fn,v_tarif.pa,v_tarif.cost,1);
  IF NOT coalesce((v_paiement->>'ok')::boolean,false) THEN RETURN v_paiement; END IF;
  UPDATE public.personnages_donnees SET current_city='qhs',current_building='qhs-prison',
    current_room='entree_qhs',current_street=NULL,updated_at=clock_timestamp()
    WHERE name=v_nom AND user_id=auth.uid();
  INSERT INTO public.sovarka_goulag_visites(nom,origine,autorisation,present,entre_le,sorti_le)
    VALUES(v_nom,v_p.current_city,v_aut.id,true,now(),NULL)
  ON CONFLICT(nom) DO UPDATE SET origine=EXCLUDED.origine,autorisation=EXCLUDED.autorisation,
    present=true,entre_le=now(),sorti_le=NULL;
  -- Autorisation permanente : ne jamais consommer le droit au voyage.
  RETURN jsonb_build_object('ok',true,'ville','qhs','building','qhs-prison',
    'room','entree_qhs','tarif',v_paiement,'statut','visiteur');
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_voyager(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_voyager(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_visiteur_repartir(p_mode text,p_destination text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_p record; v_v public.sovarka_goulag_visites%ROWTYPE;
        v_c public.sovarka_goulag_configuration%ROWTYPE; v_dest text;
        v_bat text; v_piece text; v_paiement jsonb; v_t record; v_fn text;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF p_mode NOT IN ('train','bus') OR p_mode IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','mode_invalide'); END IF;
  SELECT * INTO v_p FROM public.personnages_donnees WHERE name=v_nom
    AND user_id=auth.uid() FOR UPDATE;
  SELECT * INTO v_v FROM public.sovarka_goulag_visites WHERE nom=v_nom FOR UPDATE;
  SELECT * INTO v_c FROM public.sovarka_goulag_configuration WHERE singleton FOR SHARE;
  IF coalesce(v_c.active,false) IS DISTINCT FROM true OR v_c.retour_visiteur IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  IF coalesce(v_v.present,false) IS DISTINCT FROM true OR v_p.country IS DISTINCT FROM 'soviet'
    OR (v_p.current_city,v_p.current_building,v_p.current_room)
       IS DISTINCT FROM ('qhs','qhs-prison','entree_qhs') THEN
    RETURN jsonb_build_object('ok',false,'raison','visiteur_non_present'); END IF;
  IF EXISTS(SELECT 1 FROM public.detention_active(v_nom)) OR EXISTS(
     SELECT 1 FROM public.sovarka_goulag_traversees WHERE nom=v_nom AND en_cours) THEN
    RETURN jsonb_build_object('ok',false,'raison','retour_interdit'); END IF;
  v_dest:=p_destination; -- Libre choix explicite, jamais une ville déduite du client.
  IF v_dest NOT IN ('capitale','ville_a','ville_b') OR v_dest IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','destination_invalide'); END IF;
  SELECT batiment,pieces->>0 INTO v_bat,v_piece
    FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville=v_dest
      AND batiment LIKE 'centre-multinodal-%' ORDER BY batiment LIMIT 1;
  IF v_bat IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','arrivee_non_referencee'); END IF;
  v_fn:=CASE p_mode WHEN 'train' THEN 'prendre_train' ELSE 'prendre_bus_taxi' END;
  -- Même tarif national que payer_ordre_interne, aucun montant nouveau.
  SELECT fn,pa,cost INTO v_t FROM public.ordres_couts_pays
    WHERE fn=v_fn AND pays='soviet';
  IF NOT FOUND THEN
    SELECT fn,pa,cost INTO v_t FROM public.ordres_couts WHERE fn=v_fn;
  END IF;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','tarif_absent'); END IF;
  v_paiement:=public.payer_ordre_interne(v_nom,v_fn,v_t.pa,v_t.cost,1);
  IF NOT coalesce((v_paiement->>'ok')::boolean,false) THEN RETURN v_paiement; END IF;
  UPDATE public.personnages_donnees SET current_city=v_dest,current_building=v_bat,
    current_room=v_piece,current_street=NULL,updated_at=clock_timestamp()
    WHERE name=v_nom AND user_id=auth.uid();
  UPDATE public.sovarka_goulag_visites SET present=false,sorti_le=now() WHERE nom=v_nom;
  RETURN jsonb_build_object('ok',true,'ville',v_dest,'building',v_bat,'room',v_piece,'tarif',v_paiement);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_visiteur_repartir(text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_visiteur_repartir(text,text) TO authenticated;
