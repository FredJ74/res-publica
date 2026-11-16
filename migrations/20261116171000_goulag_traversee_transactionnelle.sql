-- Goulag Sovarka : départ, survie et arrivée, version préparée sous
-- verrou de configuration. Non activé avant les décisions manquantes.
-- Dépend des quatre migrations de dépôt, Justice, autorisations et refuge.
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
     debut_le=EXCLUDED.debut_le,arrivee_le=NULL,actualise_le=now();
  RETURN jsonb_build_object('ok',true,'en_cours',true,'destination',p_destination,
    'statut',v_statut,'pa',p.pa,'progressions',0,'peine_gelee_secondes',v_rest);
END $$;
REVOKE ALL ON FUNCTION public.goulag_toundra_demarrer(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.goulag_toundra_demarrer(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.goulag_toundra_agir(p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); p public.personnages_donnees%ROWTYPE;
        c public.sovarka_goulag_configuration%ROWTYPE;
        tr public.sovarka_goulag_traversees%ROWTYPE;
        v_jour date:=public.sovarka_jour_paris(); v_total integer;v_pa integer;
        v_gain integer:=0; v_dernier boolean:=false; v_bois jsonb;v_dest text;v_noeud text;
        v_ref jsonb; v_sommeil integer; v_penalite boolean;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  SELECT * INTO c FROM public.sovarka_goulag_configuration WHERE singleton FOR SHARE;
  IF NOT FOUND OR c.active IS DISTINCT FROM true OR c.champignons_malus IS NULL
    OR c.camp_bucherons_noeud IS NULL OR c.formule_arrestation IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR p.country<>'soviet' OR p.current_city<>'qhs' THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_goulag'); END IF;
  SELECT * INTO tr FROM public.sovarka_goulag_traversees WHERE nom=v_nom AND en_cours FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_traversee'); END IF;
  IF p.pa IS NULL OR p.pa<1 THEN RETURN jsonb_build_object('ok',false,'raison','pa_invalides'); END IF;
  v_pa:=p.pa;
  v_total:=CASE tr.destination WHEN 'starovka' THEN 7 ELSE 10 END;
  IF p_action='abri' THEN
    IF tr.jour_abri=v_jour OR tr.jour_sommeil=v_jour THEN
      RETURN jsonb_build_object('ok',false,'raison','abri_deja_fait'); END IF;
    IF v_pa<=1 THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants'); END IF;
    v_pa:=v_pa-1;
    UPDATE public.sovarka_goulag_traversees SET jour_abri=v_jour,actualise_le=now() WHERE nom=v_nom;
  ELSIF p_action='dormir' THEN
    IF tr.jour_sommeil=v_jour THEN
      RETURN jsonb_build_object('ok',false,'raison','sommeil_deja_fait'); END IF;
    v_sommeil:=CASE WHEN tr.jour_abri=v_jour THEN 6 ELSE 3 END;
    IF tr.champignons_penalite_en_attente THEN
      -- Une décision de Fred sera exigée avant activation de la configuration.
      v_sommeil:=least(v_pa+v_sommeil,greatest(7,v_pa+v_sommeil-c.champignons_malus))-v_pa;
    END IF;
    v_pa:=v_pa+v_sommeil;
    UPDATE public.sovarka_goulag_traversees
      SET jour_sommeil=v_jour,champignons_penalite_en_attente=false,actualise_le=now()
      WHERE nom=v_nom;
  ELSIF p_action='progresser' THEN
    IF tr.progressions=5 AND tr.champignons_choix IS NULL THEN
      RETURN jsonb_build_object('ok',false,'raison','champignons_a_decider'); END IF;
    IF tr.jour_progression=v_jour THEN
      RETURN jsonb_build_object('ok',false,'raison','progression_deja_faite'); END IF;
    IF v_pa<=5 THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants'); END IF;
    v_pa:=v_pa-5;
    v_dernier:=tr.progressions+1=v_total;
    v_gain:=CASE WHEN tr.progressions+1=v_total-1 THEN 5
                 WHEN v_dernier THEN 3 ELSE 0 END;
    IF v_gain>0 THEN
      v_bois:=public.inventaire_deposer_interne(v_nom,
        jsonb_build_object('name','Bois','stackKey','bois','stackable',true,'qty',v_gain,
          'desc','Ramassé dans la toundra de Sovarka.'),true);
      IF coalesce((v_bois->>'ok')::boolean,false) IS NOT TRUE OR (v_bois->>'qte')::integer<>v_gain THEN
        RAISE EXCEPTION 'goulag_bois_non_depose'; END IF;
    END IF;
    UPDATE public.sovarka_goulag_traversees SET progressions=progressions+1,
      jour_progression=v_jour,bois_trouve=bois_trouve+v_gain,
      en_cours=NOT v_dernier,arrivee_le=CASE WHEN v_dernier THEN v_jour ELSE arrivee_le END,
      actualise_le=now() WHERE nom=v_nom;
    IF v_dernier THEN
      v_dest:=CASE tr.destination WHEN 'starovka' THEN 'ville_a' ELSE 'ville_b' END;
      v_noeud:=CASE tr.destination WHEN 'starovka' THEN 'starovka-rue-stade'
                   ELSE c.camp_bucherons_noeud END;
      IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
          WHERE country='soviet' AND city=v_dest AND noeud=v_noeud) THEN
        RAISE EXCEPTION 'goulag_arrivee_non_referencee'; END IF;
      v_pa:=1;
      UPDATE public.personnages_donnees SET pa=v_pa,current_city=v_dest,
        current_building=NULL,current_room=NULL,current_street=v_noeud,
        updated_at=clock_timestamp() WHERE name=v_nom;
      v_ref:=public.sovarka_goulag_refuge_creer_interne(v_nom,tr.destination,tr.statut);
      IF coalesce((v_ref->>'ok')::boolean,false) IS NOT TRUE THEN
        RAISE EXCEPTION 'goulag_refuge_non_cree'; END IF;
    END IF;
  ELSIF p_action='champignons_manger' OR p_action='champignons_refuser' THEN
    IF tr.progressions<>5 OR tr.champignons_choix IS NOT NULL THEN
      RETURN jsonb_build_object('ok',false,'raison','champignons_indisponibles'); END IF;
    IF p_action='champignons_manger' THEN
      v_pa:=CASE WHEN v_pa>7 THEN 7 ELSE v_pa+1 END;
    END IF;
    UPDATE public.sovarka_goulag_traversees SET
      champignons_choix=CASE p_action WHEN 'champignons_manger' THEN 'manger' ELSE 'refuser' END,
      champignons_penalite_en_attente=(p_action='champignons_refuser' AND v_pa>7),
      actualise_le=now() WHERE nom=v_nom;
  ELSE
    RETURN jsonb_build_object('ok',false,'raison','ordre_inconnu');
  END IF;
  IF NOT v_dernier THEN
    UPDATE public.personnages_donnees SET pa=v_pa WHERE name=v_nom AND user_id=auth.uid();
  END IF;
  RETURN jsonb_build_object('ok',true,'en_cours',NOT v_dernier,
    'termine',v_dernier,'arrivee',CASE WHEN v_dernier THEN v_dest END,
    'rue',CASE WHEN v_dernier THEN v_noeud END,
    'progressions',tr.progressions+CASE WHEN p_action='progresser' THEN 1 ELSE 0 END,
    'pa',v_pa,'bois_gagne',v_gain,
    'inventory',CASE WHEN v_gain>0 THEN v_bois->'inventory' ELSE NULL END,
    'revision',CASE WHEN v_gain>0 THEN v_bois->'revision' ELSE NULL END,
    'repos_jours',CASE WHEN v_dernier THEN 3 ELSE 0 END,
    'statut',tr.statut,'recherche',v_dernier AND tr.statut='detenu');
END $$;
REVOKE ALL ON FUNCTION public.goulag_toundra_agir(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.goulag_toundra_agir(text) TO authenticated;


CREATE OR REPLACE FUNCTION public.goulag_toundra_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage();tr public.sovarka_goulag_traversees%ROWTYPE;
        p record;v_total integer;v_jour date:=public.sovarka_jour_paris();
BEGIN
 IF auth.uid() IS NULL OR v_nom IS NULL THEN
   RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO tr FROM public.sovarka_goulag_traversees WHERE nom=v_nom AND en_cours;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_traversee');END IF;
 SELECT country,current_city,pa INTO p FROM public.personnages_donnees
    WHERE name=v_nom AND user_id=auth.uid();
 IF NOT FOUND OR (p.country,p.current_city) IS DISTINCT FROM ('soviet','qhs') THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_toundra'); END IF;
 v_total:=CASE WHEN tr.destination='starovka' THEN 7 ELSE 10 END;
 RETURN jsonb_build_object('ok',true,'en_cours',true,'destination',tr.destination,'statut',tr.statut,
   'progressions',tr.progressions,'total',v_total,'pa',p.pa,'bois_trouve',tr.bois_trouve,
   'abri_aujourdhui',coalesce(tr.jour_abri=v_jour,false),
   'dormi_aujourdhui',coalesce(tr.jour_sommeil=v_jour,false),
   'progresse_aujourdhui',coalesce(tr.jour_progression=v_jour,false),
   'champignons_a_decider',tr.progressions=5 AND tr.champignons_choix IS NULL,
   'champignons_choix',tr.champignons_choix,
   'peine_gelee_secondes',tr.peine_gelee_secondes);
END $$;
REVOKE ALL ON FUNCTION public.goulag_toundra_lire() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.goulag_toundra_lire() TO authenticated;

-- Un joueur en pleine traversée ne peut fuir via des actions de déplacement
-- génériques : garde transversale du moteur de navigation existant.
DO $goulag_navigation$
DECLARE olddef text;old text;newtext text;
BEGIN
  olddef:=pg_get_functiondef('public.navigation_disponibilite_interne(text)'::regprocedure);
  IF strpos(olddef,'goulag_navigation_garde_20261116')>0 THEN RETURN; END IF;
  old:=E' IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE personnage=p_nom AND expires_at>now()) THEN';
  newtext:=E' -- goulag_navigation_garde_20261116 : la toundra ne se quitte que par progression serveur.\n'
    ||E' IF EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees t WHERE t.nom=p_nom AND t.en_cours) THEN\n'
    ||E'   RETURN jsonb_build_object(''ok'',false,''raison'',''traversee_irreversible''); END IF;\n'
    ||E' IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE personnage=p_nom AND expires_at>now()) THEN';
  IF (length(olddef)-length(replace(olddef,old,'')))<>length(old) THEN
    RAISE EXCEPTION 'navigation_disponibilite_signature_inattendue'; END IF;
  EXECUTE replace(olddef,old,newtext);
END $goulag_navigation$;
