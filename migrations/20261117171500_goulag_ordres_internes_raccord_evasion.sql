-- Goulag de Sovarka — ordres internes, lot 4/4 : raccord avec le départ « S'enfuir à pied »
-- préparé par Codex (PR #1020, goulag_toundra_demarrer). INTÉGRATION ISOLÉE : la fonction de
-- Codex est complétée par remplacement d'ancres exactes, sans réécrire ses autres règles ni
-- toucher à la marche, l'abri, les champignons, le bois, le refuge ou l'arrivée.
--
-- Décisions de Fred du 17/11/2026 :
--  * Jet de SORTIE DU CAMP, distinct de la survie : 80 % sans corruption, 95 % après corruption
--    d'un gardien ; une seule tentative par jour ; jet serveur non rejouable.
--  * Échec : aucun départ, deux nuits de cachot, peine principale conservée, incident enregistré.
--  * Réussite : la traversée existante démarre (7 PA/7 jours Starovka, 10 PA/10 jours Krasnov).
--  * Le reliquat figé est le compteur de jours que seul le sommeil fait baisser.
-- Le visiteur libre n'est pas concerné par le jet : ce n'est pas une évasion.
DO $goulag_ordres_prerequis$
BEGIN
  IF to_regprocedure('public.sovarka_goulag_cachot_placer_interne(text,text,integer,text)') IS NULL THEN
    RAISE EXCEPTION 'goulag_ordres_lot2_requis'; END IF;
END $goulag_ordres_prerequis$;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_sortie_jet_interne(p_nom text, p_detention_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE r public.sovarka_goulag_registre%ROWTYPE; v_jour date := public.sovarka_goulag_jour_interne();
        v_taux integer; v_jet integer; v_ok boolean; v_cachot jsonb; v_n integer;
BEGIN
  SELECT * INTO r FROM public.sovarka_goulag_registre
   WHERE detention_id = p_detention_id AND nom = p_nom FOR UPDATE;
  IF NOT FOUND OR r.liberation_le IS NOT NULL OR r.evasion_le IS NOT NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','registre_goulag_absent'); END IF;
  IF r.jours_restants <= 0 THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_deja_purgee'); END IF;
  IF r.cachot_nuits > 0 THEN
    RETURN jsonb_build_object('ok',false,'raison','sanction_cachot_en_cours'); END IF;
  IF r.derniere_tentative IS NOT NULL AND r.derniere_tentative >= v_jour THEN
    RETURN jsonb_build_object('ok',false,'raison','tentative_deja_faite_aujourdhui'); END IF;
  v_taux := CASE WHEN r.corruption_bonus THEN 95 ELSE 80 END;
  v_jet := floor(random() * 100)::integer + 1;
  v_ok := v_jet <= v_taux;
  -- La clé (détention, jour) interdit physiquement une seconde tentative le même jour.
  INSERT INTO public.sovarka_goulag_tentatives(detention_id,jour,nom,taux,jet,reussi,corruption)
  VALUES (r.detention_id, v_jour, p_nom, v_taux, v_jet, v_ok, r.corruption_bonus)
  ON CONFLICT (detention_id, jour) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok',false,'raison','tentative_deja_faite_aujourdhui'); END IF;
  -- Le bonus de corruption vaut pour LA prochaine tentative, réussie ou non.
  UPDATE public.sovarka_goulag_registre SET derniere_tentative = v_jour, corruption_bonus = false,
    evasion_le = CASE WHEN v_ok THEN now() ELSE NULL END
   WHERE detention_id = r.detention_id;
  IF v_ok THEN
    PERFORM public.sovarka_goulag_incident_interne('evasion:' || r.detention_id || ':' || v_jour,
      'evasion_reussie', p_nom, r.detention_id,
      jsonb_build_object('taux',v_taux,'corruption',r.corruption_bonus,'jours_restants',r.jours_restants));
    RETURN jsonb_build_object('ok',true,'reussi',true,'taux',v_taux,'jet',v_jet);
  END IF;
  v_cachot := public.sovarka_goulag_cachot_placer_interne(p_nom, r.detention_id, 2, 'evasion_echouee');
  IF coalesce((v_cachot->>'ok')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'goulag_cachot_impossible'; END IF;
  PERFORM public.sovarka_goulag_incident_interne('evasion:' || r.detention_id || ':' || v_jour,
    'evasion_echouee', p_nom, r.detention_id,
    jsonb_build_object('taux',v_taux,'corruption',r.corruption_bonus,'nuits',2));
  RETURN jsonb_build_object('ok',false,'raison','evasion_echouee','reussi',false,'taux',v_taux,
    'jet',v_jet,'cachot_nuits',(v_cachot->>'cachot_nuits')::integer,'room','cachot_disciplinaire',
    'jours_restants',r.jours_restants);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_sortie_jet_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;

DO $goulag_raccord_depart$
DECLARE source text; a_jet text; n_jet text; a_rest text; n_rest text;
BEGIN
  source := pg_get_functiondef('public.goulag_toundra_demarrer(text)'::regprocedure);
  IF strpos(source,'goulag_sortie_jet_20261117') > 0 THEN RETURN; END IF;
  -- 1. Jet de sortie, pour le seul détenu, avant tout gel de peine ou perte du dépôt.
  a_jet := E'    v_statut:=''detenu'';\n';
  n_jet := a_jet
    || E'    -- goulag_sortie_jet_20261117 : sortie du camp à 80 % (95 % après corruption), une fois par jour.\n'
    || E'    DECLARE v_sortie jsonb;\n'
    || E'    BEGIN\n'
    || E'      v_sortie := public.sovarka_goulag_sortie_jet_interne(v_nom, v_det.id);\n'
    || E'      IF coalesce((v_sortie->>''reussi'')::boolean,false) IS NOT TRUE THEN RETURN v_sortie; END IF;\n'
    || E'    END;\n';
  -- 2. Reliquat figé = jours que seul le sommeil purge (plus aucun décompte calendaire).
  a_rest := E'    -- Peine restante à l''instant exact : pas de comparaison avec la durée de marche.\n'
    || E'    -- Les peines historiques portent debutTs en millisecondes et jours en numérique.\n'
    || E'    IF coalesce(p.est_emprisonne->>''debutTs'','''') !~ ''^[0-9]+(\\.[0-9]+)?$''\n'
    || E'       OR coalesce(p.est_emprisonne->>''jours'','''') !~ ''^[0-9]+(\\.[0-9]+)?$'' THEN\n'
    || E'      RETURN jsonb_build_object(''ok'',false,''raison'',''peine_calendaire_invalide''); END IF;\n'
    || E'    v_debut:=(p.est_emprisonne->>''debutTs'')::numeric;\n'
    || E'    v_duree:=(p.est_emprisonne->>''jours'')::numeric;\n'
    || E'    v_fin:=v_debut+v_duree*86400000;\n'
    || E'    v_rest:=greatest(0,(v_fin-extract(epoch from clock_timestamp())*1000)/1000);\n';
  n_rest := E'    -- goulag_reliquat_sommeil_20261117 : seul le sommeil valide purge la peine du goulag.\n'
    || E'    SELECT r.jours_restants::numeric*86400 INTO v_rest FROM public.sovarka_goulag_registre r\n'
    || E'      WHERE r.detention_id=v_det.id;\n'
    || E'    v_rest:=coalesce(v_rest,0);\n';
  IF (length(source) - length(replace(source, a_jet, ''))) <> length(a_jet) THEN
    RAISE EXCEPTION 'goulag_depart_ancre_statut_absente'; END IF;
  IF (length(source) - length(replace(source, a_rest, ''))) <> length(a_rest) THEN
    RAISE EXCEPTION 'goulag_depart_ancre_reliquat_absente'; END IF;
  EXECUTE replace(replace(source, a_jet, n_jet), a_rest, n_rest);
  IF strpos(pg_get_functiondef('public.goulag_toundra_demarrer(text)'::regprocedure),
            'goulag_reliquat_sommeil_20261117') = 0 THEN
    RAISE EXCEPTION 'goulag_raccord_depart_non_applique'; END IF;
END $goulag_raccord_depart$;
