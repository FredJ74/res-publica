-- Sovarka : operations de renseignement uniquement depuis les bureaux des ministres
-- de la Defense et de la Securite du Peuple, plus depuis la salle d'ecoutes.
-- Les autres empires conservent les droits et lieux historiques du ministre de la Defense.
CREATE OR REPLACE FUNCTION public.renseignement_lieu_refus_interne(p_nom text, p_pays text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
DECLARE
  v_ici_pays text; v_ici_bat text; v_ici_piece text;
  v_lieu text; v_poste text;
BEGIN
  SELECT country, current_building, current_room
    INTO v_ici_pays,v_ici_bat,v_ici_piece
    FROM public.personnages_donnees WHERE name=p_nom;
  IF v_ici_pays IS DISTINCT FROM p_pays THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_de_son_pays','pays_poste',p_pays);
  END IF;
  IF p_pays='soviet' THEN
    SELECT a.poste_id INTO v_poste FROM public.acteur_poste_courant() a WHERE a.nom=p_nom;
    IF v_ici_bat IS DISTINCT FROM 'palais-gouvernement'
       OR NOT ((v_poste='min_def' AND v_ici_piece='bureau_min_def')
            OR (v_poste='min_int' AND v_ici_piece='bureau_min_int')) THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_sur_place','lieu','palais-gouvernement');
    END IF;
    RETURN NULL;
  END IF;
  v_lieu := CASE WHEN EXISTS (SELECT 1 FROM public.navigation_lieux_regles
                        WHERE pays=p_pays AND batiment='siege-renseignement')
    THEN 'siege-renseignement' ELSE 'palais-gouvernement' END;
  IF v_ici_bat IS DISTINCT FROM v_lieu THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_sur_place','lieu',v_lieu);
  END IF;
  RETURN NULL;
END; $$;

-- Gardes ministérielles sur toutes les fonctions de la chaîne ;
-- la ministre de l'Intérieur n'obtient aucun droit dans un autre empire.
DO $migration$
DECLARE f text; nom text; noms text[] := ARRAY[
  'renseignement_agents_disponibles()',
  'cellule_renseignement_creer(text)',
  'cellule_renseignement_mes_cellules()',
  'cellule_renseignement_terminer(text)',
  'cellule_rapports_mes_cellules(integer)'
];
  ancien text := 'IF v_poste IS DISTINCT FROM ''min_def'' THEN';
  nouveau text := 'IF NOT (v_poste = ''min_def'' OR (v_pays = ''soviet'' AND v_poste = ''min_int'')) THEN';
BEGIN
  FOREACH nom IN ARRAY noms LOOP
    SELECT pg_get_functiondef(('public.'||nom)::regprocedure) INTO f;
    IF position(nouveau IN f)>0 THEN CONTINUE; END IF;
    IF position(ancien IN f)=0 THEN RAISE EXCEPTION 'Garde non trouvee dans %',nom; END IF;
    f:=replace(f,ancien,nouveau);
    IF nom='cellule_renseignement_creer(text)' THEN
      IF position('v_caisse := v_pays || ''_gouvernement-min_def'';' IN f)=0
        THEN RAISE EXCEPTION 'Caisse source inattendue'; END IF;
      f:=replace(f,
        'v_caisse := v_pays || ''_gouvernement-min_def'';',
        'v_caisse := v_pays || ''_gouvernement-'' || v_poste;');
    END IF;
    EXECUTE f;
  END LOOP;
END $migration$;
