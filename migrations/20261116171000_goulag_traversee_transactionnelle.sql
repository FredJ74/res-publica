-- Goulag Sovarka : départ, survie et arrivée, version préparée sous
-- verrou de configuration. Non activé avant les décisions manquantes.
-- Dépend des quatre migrations de dépôt, Justice, autorisations et refuge.
-- Ancrage du camp dans la géographie existante : une cour, sans mécanique locale.
DO $camp$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet'
    AND city='ville_b' AND noeud='krasnov-rue-ecole-foret') THEN
    RAISE EXCEPTION 'krasnov_acces_foret_absent'; END IF;
  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES('soviet','ville_b','krasnov-camp-bucherons',ARRAY['krasnov-rue-ecole-foret'],
    '{"liens":{"arriere":"krasnov-rue-ecole-foret"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO NOTHING;
  UPDATE public.rue_noeuds_serveur SET
    voisins=CASE WHEN 'krasnov-camp-bucherons'=ANY(voisins) THEN voisins
      ELSE array_append(voisins,'krasnov-camp-bucherons') END,
    directions=jsonb_set(coalesce(directions,'{}'::jsonb),'{liens}',
      coalesce(directions->'liens','{}'::jsonb)||'{"droite":"krasnov-camp-bucherons"}'::jsonb)
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-ecole-foret';
  UPDATE public.sovarka_goulag_configuration SET camp_bucherons_noeud='krasnov-camp-bucherons'
    WHERE singleton AND camp_bucherons_noeud IS NULL;
END $camp$;

ALTER TABLE public.sovarka_goulag_traversees
  ADD COLUMN IF NOT EXISTS champignons_choix text
    CHECK(champignons_choix IN ('manger','refuser')),
  ADD COLUMN IF NOT EXISTS champignons_penalite_en_attente boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS peine_gelee_secondes bigint,
  ADD COLUMN IF NOT EXISTS recherche_id text;

CREATE OR REPLACE FUNCTION public.goulag_toundra_demarrer(p_destination text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); p public.personnages_donnees%ROWTYPE;
        c public.sovarka_goulag_configuration%ROWTYPE;
        v_det record; v_statut text; v_total integer; v_dep text; v_rest bigint;
        v_rech jsonb; v_rech_id text; v_fin numeric; v_debut numeric; v_duree numeric;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF p_destination NOT IN ('starovka','krasnov') OR p_destination IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','destination_invalide'); END IF;
  SELECT * INTO c FROM public.sovarka_goulag_configuration WHERE singleton FOR SHARE;
  IF NOT FOUND OR c.active IS DISTINCT FROM true
    OR c.champignons_malus IS NULL OR c.formule_arrestation IS NULL
    OR c.camp_bucherons_noeud IS NULL
    OR c.retour_visiteur IS NULL OR c.autorisation_usage IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  -- Prérequis géographique strict : ne jamais inventer un camp ni retourner à la gare.
  IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-stade')
    OR NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud=c.camp_bucherons_noeud)
    THEN RETURN jsonb_build_object('ok',false,'raison','arrivees_non_referencees'); END IF;
  SELECT * INTO p FROM public.personnages_donnees
    WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR (p.country,p.current_city,p.current_building,p.current_room)
    IS DISTINCT FROM ('soviet','qhs','qhs-prison','entree_qhs')
    THEN RETURN jsonb_build_object('ok',false,'raison','pas_entree_goulag'); END IF;
  v_total:=CASE p_destination WHEN 'starovka' THEN 7 ELSE 10 END;
  IF p.pa IS NULL OR p.pa<v_total THEN
    RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants_depart','minimum',v_total); END IF;
  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees WHERE nom=v_nom AND en_cours) THEN
    RETURN jsonb_build_object('ok',false,'raison','traversee_deja_commencee'); END IF;
  -- Une seconde marche ne doit jamais effacer une peine encore gelée.
  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees WHERE nom=v_nom
    AND peine_gelee_secondes>0 AND peine_reprise_le IS NULL) THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_gelee_non_reprise'); END IF;
  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_refuges WHERE nom=v_nom AND NOT termine) THEN
    RETURN jsonb_build_object('ok',false,'raison','refuge_encore_actif'); END IF;
  SELECT * INTO v_det FROM public.detention_active(v_nom);
  IF v_det.id IS NOT NULL THEN
    IF v_det.country <> 'soviet' OR NOT v_det.qhs THEN
      RETURN jsonb_build_object('ok',false,'raison','detention_hors_goulag'); END IF;
    IF NOT EXISTS (SELECT 1 FROM public.sovarka_goulag_depots
          WHERE detention_id=v_det.id AND nom=v_nom AND etat='confisque') THEN
      RETURN jsonb_build_object('ok',false,'raison','inventaire_non_confisque'); END IF;
    v_statut:='detenu';
    -- Peine restante à l'instant exact : pas de comparaison avec la durée de marche.
    -- Les peines historiques portent debutTs en millisecondes et jours en numérique.
    IF coalesce(p.est_emprisonne->>'debutTs','') !~ '^[0-9]+(\.[0-9]+)?$'
       OR coalesce(p.est_emprisonne->>'jours','') !~ '^[0-9]+(\.[0-9]+)?$' THEN
      RETURN jsonb_build_object('ok',false,'raison','peine_calendaire_invalide'); END IF;
    v_debut:=(p.est_emprisonne->>'debutTs')::numeric;
    v_duree:=(p.est_emprisonne->>'jours')::numeric;
    v_fin:=v_debut+v_duree*86400000;
    v_rest:=greatest(0,ceil((v_fin-extract(epoch from statement_timestamp())*1000)/1000))::bigint;
    IF v_rest<1 THEN
      RETURN jsonb_build_object('ok',false,'raison','peine_deja_purgee'); END IF;
    -- Clore avec mode "evasion" (jamais "purgee") pour figer le reliquat.
    PERFORM public.detention_clore_interne(v_nom,'evasion');
    UPDATE public.detentions SET reliquat_jours=ceil(v_rest/86400.0)::integer
      WHERE id=v_det.id;
    UPDATE public.prisonniers_qhs SET statut='evade'
      WHERE data->>'nom'=v_nom AND data->>'pays'='soviet' AND statut='libere';
    IF coalesce((public.sovarka_goulag_depot_clore_interne(v_nom,v_det.id,'evasion')->>'ok')::boolean,false) IS NOT TRUE THEN
      RAISE EXCEPTION 'goulag_perte_inventaire_impossible'; END IF;
    v_rech_id:='goulag-evasion-'||v_det.id;
    v_rech:=public.recherche_inscrire(jsonb_build_object(
      'id',v_rech_id,'type','condamnation','country','soviet',
      'motifs',jsonb_build_array(jsonb_build_object(
        'type','Évasion du goulag','source','goulag','jours',0,
        'detention_id',v_det.id,'reste_secondes',v_rest,
        'date_evenement',to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
      'detention_precedente_id',v_det.id,'reliquat_jours',ceil(v_rest/86400.0)::integer));
    IF coalesce((v_rech->>'ok')::boolean,false) IS NOT TRUE THEN
      RAISE EXCEPTION 'goulag_recherche_impossible'; END IF;
  ELSE
    IF NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_visites
       WHERE nom=v_nom AND present) THEN
      RETURN jsonb_build_object('ok',false,'raison','visite_non_validee'); END IF;
    v_statut:='visiteur';
    v_rest:=NULL;v_rech_id:=NULL;
    UPDATE public.sovarka_goulag_visites SET present=false,sorti_le=now() WHERE nom=v_nom;
  END IF;
  INSERT INTO public.sovarka_goulag_traversees(nom,destination,statut,
     progressions,en_cours,detention_id,peine_gelee_jours,peine_gelee_secondes,recherche_id,
     jour_abri,jour_sommeil,jour_progression,bois_trouve,
     champignons_choix,champignons_penalite_en_attente,debut_le,arrivee_le)
  VALUES(v_nom,p_destination,v_statut,0,true,v_det.id,
     CASE WHEN v_rest IS NOT NULL THEN ceil(v_rest/86400.0)::integer END,
     v_rest,v_rech_id,NULL,NULL,NULL,0,NULL,false,public.sovarka_jour_paris(),NULL)
  ON CONFLICT(nom) DO UPDATE SET destination=EXCLUDED.destination,
     statut=EXCLUDED.statut,progressions=0,en_cours=true,
     detention_id=EXCLUDED.detention_id,peine_gelee_jours=EXCLUDED.peine_gelee_jours,
     peine_gelee_secondes=EXCLUDED.peine_gelee_secondes,recherche_id=EXCLUDED.recherche_id,
     jour_abri=NULL,jour_sommeil=NULL,jour_progression=NULL,bois_trouve=0,
     champignons_choix=NULL,champignons_penalite_en_attente=false,
     debut_le=EXCLUDED.debut_le,arrivee_le=NULL,
     peine_reprise_le=NULL,nouvelle_detention_id=NULL,actualise_le=now();
  RETURN jsonb_build_object('ok',true,'en_cours',true,'destination',p_destination,
    'statut',v_statut,'pa',p.pa,'progressions',0,'peine_gelee_secondes',v_rest);
END $$;
REVOKE ALL ON FUNCTION public.goulag_toundra_demarrer(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.goulag_toundra_demarrer(text) TO authenticated;
