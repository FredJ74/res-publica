-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- parquet_garde(text,text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_garde(p_affaire_id text, p_statuts text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_p record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_site text;
BEGIN
  SELECT * INTO v_p FROM public.parquet_moi();
  IF v_p.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_procureur');
  END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_a := v_brut::jsonb;

  IF v_pays IS DISTINCT FROM v_p.pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF NOT (coalesce(v_a ->> 'status', '') = ANY (p_statuts)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible',
                              'statut', v_a ->> 'status', 'attendus', to_jsonb(p_statuts));
  END IF;

  -- LE DELAI S'OPPOSE ICI, et non seulement a minuit. Entre l'echeance et la passe nocturne, le
  -- dossier est perime : la poursuivre serait poursuivre une procedure eteinte.
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer);
  END IF;

  v_site := public.parquet_site_competent(v_pays, v_ville);
  IF NOT public.acteur_present_sur_site(v_p.nom, v_pays, v_ville, v_site, NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_requise',
                              'ville', v_ville, 'site', v_site);
  END IF;

  RETURN jsonb_build_object('ok', true, 'procureur', v_p.nom, 'pays', v_pays,
                            'ville', v_ville, 'affaire', v_a);
END $function$;

-- parquet_moi() -> TABLE(nom text, pays text) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_moi()
 RETURNS TABLE(nom text, pays text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inc text; v_pays text; v_pnj text;
BEGIN
  -- CHEMIN NORMAL, INCHANGE : le PJ qui porte le poste. Il a toujours la priorite.
  RETURN QUERY
    SELECT d.name, d.country FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'procureur'
     LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  -- INCARNATION ADMINISTRATIVE. La titularite est REVERIFIEE ICI, et pas seulement a la porte :
  -- un PJ qui prend le poste ferme l'incarnation au moment meme de l'acte.
  v_inc := public.incarnation_courante();
  IF v_inc IS NULL THEN RETURN; END IF;
  v_pays := public.incarnation_pays();
  IF v_pays IS NULL THEN RETURN; END IF;
  v_pnj := public.admin_pnj_titulaire(v_pays, 'procureur', NULL);
  IF v_pnj IS NULL OR v_pnj IS DISTINCT FROM v_inc THEN RETURN; END IF;
  RETURN QUERY SELECT v_pnj, v_pays;
END $function$;

-- parquet_non_lieu(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_non_lieu(p_affaire_id text, p_motif text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_g jsonb; v_a jsonb; v_motif text; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['au_parquet', 'enquete']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';
  v_motif := nullif(btrim(coalesce(p_motif, '')), '');

  -- UN NON-LIEU N'EST PAS UN VERDICT SUR LES FAITS. Le serveur enregistre que le parquet a
  -- decide de ne pas poursuivre, et rien de plus : ni que la plainte etait mensongere, ni que la
  -- personne visee est innocente. Le motif, quand il y en a un, est le TEXTE DU PROCUREUR --
  -- une declaration de joueur, pas une conclusion du serveur.
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'non_lieu',
           'non_lieu_par', v_g ->> 'procureur',
           'non_lieu_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'non_lieu_motif_declare', v_motif))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') IN ('au_parquet', 'enquete');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'non_lieu', v_g ->> 'procureur', 'procureur', NULL, NULL,
    CASE WHEN v_motif IS NULL THEN NULL
         ELSE jsonb_build_object('motif_declare', v_motif) END);
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'non_lieu');
END;
$function$;

-- parquet_poursuivre(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_poursuivre(p_affaire_id text, p_infraction text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_g jsonb; v_a jsonb; v_inf text; v_lib text; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['au_parquet', 'enquete']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';

  -- LA QUALIFICATION EST CANONIQUE, OU ELLE N'EST PAS. `infraction_canonique` est fail closed et
  -- refuse aussi un nom de CATEGORIE : on ne poursuit pas quelqu'un pour « crime » en general.
  v_inf := public.infraction_canonique(p_infraction);
  IF v_inf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_inconnue', 'demande', p_infraction);
  END IF;
  SELECT libelle INTO v_lib FROM public.infractions WHERE id = v_inf;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'poursuites',
           'qualification_parquet', v_inf,
           'qualification_parquet_libelle', v_lib,
           'poursuites_par', v_g ->> 'procureur',
           'poursuites_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') IN ('au_parquet', 'enquete');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'poursuites_engagees', v_g ->> 'procureur', 'procureur', NULL, v_inf,
    jsonb_build_object('accuse', v_a ->> 'cible',
                       'categorie_alleguee', v_a ->> 'categorie_alleguee'));
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'poursuites',
                            'qualification', v_inf, 'libelle', v_lib);
END;
$function$;

-- parquet_site_competent(text,text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_site_competent(p_pays text, p_ville text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN v.est_capitale THEN 'tribunal' ELSE 'tribunal-local' END
    FROM public.villes v WHERE v.pays = p_pays AND v.ville = p_ville;
$function$;

-- parquet_transmettre_juge(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_transmettre_juge(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_g jsonb; v_a jsonb; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['poursuites']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'saisie',
           'saisine_par', v_g ->> 'procureur',
           'saisine_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'poursuites';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'juge_saisi', v_g ->> 'procureur', 'procureur', NULL, v_a ->> 'qualification_parquet');
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'saisie');
END;
$function$;

-- plainte_defendre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plainte_defendre(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_brut text; v_data jsonb; v_maj jsonb;
  v_inf text; v_i record; v_seuil integer; v_pays text; v_ville text;
  v_av record; v_cha integer; v_preuve boolean; v_taux integer; v_jet integer;
  v_reussi boolean; v_relaxe boolean; v_b jsonb; v_juge text;
  v_jours integer; v_amende integer; v_lib text; v_peine text; v_motifs jsonb;
  v_jug text; v_n integer; v_det record; v_exec jsonb; v_executee boolean := false;
  v_statut text; v_verdict text; v_statut_relu text;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.country, p.city INTO v_brut, v_pays, v_ville
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_data := v_brut::jsonb;
  IF coalesce(v_data ->> 'cible', '') IS DISTINCT FROM v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire');
  END IF;
  IF coalesce(v_data ->> 'status', '') IS DISTINCT FROM 'au_parquet' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_defendable',
                              'statut', v_data ->> 'status');
  END IF;
  IF v_data ? 'defense_le' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'defense_deja_plaidee',
                              'issue_precedente', v_data ->> 'defense_issue');
  END IF;

  v_inf := public.affaire_infraction_de(v_data);
  IF v_inf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_non_determinee');
  END IF;
  v_inf := coalesce(public.infraction_canonique(v_inf), v_inf);
  SELECT i.jours_reference, i.categorie INTO v_i
    FROM public.infractions i WHERE i.id = v_inf;
  IF v_i.jours_reference IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_hors_catalogue',
                              'infraction', v_inf);
  END IF;

  -- PREMIER CRITERE : LA DUREE DE REFERENCE. Inchange.
  v_seuil := public.justice_seuil_procedure_simplifiee_jours();
  IF v_i.jours_reference > v_seuil THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'procedure_simplifiee_reservee_aux_peines_courtes',
                              'infraction', v_inf, 'jours_reference', v_i.jours_reference,
                              'seuil', v_seuil);
  END IF;

  -- SECOND CRITERE : LA CATEGORIE. Un crime ne passe JAMAIS par la procedure simplifiee, et une
  -- categorie ABSENTE ferme aussi la porte -- on ne peut pas affirmer qu'une infraction sans
  -- categorie n'est pas un crime. Inchange.
  IF v_i.categorie IS NULL OR v_i.categorie = 'crime' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'procedure_simplifiee_exclut_les_crimes',
                              'infraction', v_inf, 'categorie', v_i.categorie,
                              'jours_reference', v_i.jours_reference);
  END IF;

  -- L'AVOCAT COMMIS D'OFFICE DE LA VILLE. Sans lui, personne ne plaide.
  SELECT * INTO v_av FROM public.justice_avocat_commis(v_pays, v_ville);
  IF v_av.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_d_avocat_commis_d_office',
                              'ville', v_ville);
  END IF;

  -- LE TRIBUNAL QUI PRONONCERA.
  v_juge := public.justice_juge_titulaire(v_pays, v_ville);
  IF v_juge IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_tribunal', 'ville', v_ville);
  END IF;

  v_b := public.infraction_peine_bornes(v_inf);
  IF coalesce((v_b ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_b; END IF;
  v_lib := v_b ->> 'libelle';

  -- LE JET EST ICI, ET NULLE PART AILLEURS.
  v_cha    := public.justice_cha_personnel(v_nom);
  v_preuve := public.justice_preuve_reelle(v_pays, v_nom, v_inf);
  v_taux   := public.justice_defense_taux(v_av.cha, v_cha, v_preuve);
  v_jet    := floor(random() * 100)::integer + 1;
  v_reussi := (v_jet <= v_taux);
  v_relaxe := v_reussi
              AND (floor(random() * 100)::integer + 1) <= public.justice_defense_part_relaxe();

  IF NOT v_reussi THEN
    -- ECHEC : LA PEINE NORMALE, celle du catalogue, sans attenuation.
    v_jours  := (v_b ->> 'jours_reference')::integer;
    v_amende := (v_b ->> 'amende_reference')::integer;
  ELSIF v_relaxe THEN
    v_jours := 0; v_amende := 0;
  ELSE
    -- REUSSITE SANS RELAXE : les bornes basses du catalogue. `jours_min` porte deja le plancher
    -- carceral incompressible d'un jour ; `amende_min` n'en a aucun.
    v_jours  := (v_b ->> 'jours_min')::integer;
    v_amende := (v_b ->> 'amende_min')::integer;
  END IF;

  v_verdict := CASE WHEN v_relaxe THEN 'relaxe' ELSE 'condamnation' END;
  v_statut  := CASE WHEN v_relaxe THEN 'relaxe' ELSE 'jugee' END;
  v_peine   := CASE
    WHEN v_relaxe THEN NULL
    WHEN v_jours > 0 AND v_amende > 0 THEN
      'Prison ' || v_jours || ' jour' || CASE WHEN v_jours > 1 THEN 's' ELSE '' END
      || ' + amende de ' || v_amende || ' FR'
    WHEN v_jours > 0 THEN
      'Prison ' || v_jours || ' jour' || CASE WHEN v_jours > 1 THEN 's' ELSE '' END
    ELSE 'Amende de ' || v_amende || ' FR'
  END;

  v_motifs := CASE WHEN v_jours > 0 THEN jsonb_build_array(jsonb_build_object(
      'type', v_lib, 'infraction', v_inf, 'jours', v_jours, 'city', v_ville,
      'source', 'procedure_simplifiee',
      'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')))
    ELSE '[]'::jsonb END;

  -- UNE RELAXE EST UN JUGEMENT, avec `peine` NULL -- pas une peine de zero, et surtout pas un
  -- statut pose sans trace. C'est la meme forme que `justice_relaxer`.
  v_jug := 'jug-' || p_affaire_id;
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_jug, v_pays, coalesce(v_ville, 'capitale'), v_nom, v_lib, v_peine, v_juge,
          coalesce((SELECT d.day FROM public.personnages_donnees d WHERE d.name = v_juge), 1),
          v_relaxe,
          jsonb_build_object(
            'verdict', v_verdict, 'instance', 'simplifiee',
            'procedure', 'simplifiee',
            'infraction', v_inf, 'infraction_libelle', v_lib,
            'jours', v_jours, 'amende', v_amende,
            'jours_reference', (v_b ->> 'jours_reference')::integer,
            'jours_min', (v_b ->> 'jours_min')::integer,
            'amende_reference', (v_b ->> 'amende_reference')::integer,
            'amende_min', (v_b ->> 'amende_min')::integer,
            'avocat', v_av.nom, 'avocat_cha', v_av.cha,
            'prevenu_cha', v_cha, 'preuve_reelle', v_preuve,
            'taux', v_taux, 'jet', v_jet, 'reussie', v_reussi,
            'appel_exclu', true,
            'motif_allegue', v_data ->> 'motif',
            'qualification_parquet', v_data ->> 'qualification_parquet',
            'motifs', v_motifs,
            'issue_judiciaire', coalesce(v_peine, 'relaxe')))
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_deja_rendu');
  END IF;

  -- IMMEDIATEMENT EXECUTOIRE : la detention s'ouvre ICI, comme pour une sentence de premiere
  -- instance. Une peine deja en cours interdit d'en ouvrir une seconde -- c'est la garde de
  -- `detention_ouvrir_interne`, et on la laisse en place.
  IF v_jours > 0 THEN
    SELECT * INTO v_det FROM public.detention_active(v_nom);
    IF v_det.id IS NULL THEN
      v_exec := public.detention_ouvrir_interne(
                  v_nom, v_lib, v_jours, coalesce(v_ville, 'capitale'), v_pays,
                  v_motifs, v_juge, coalesce(v_peine, 'condamnation_executee'));
      IF coalesce((v_exec ->> 'ok')::boolean, false) THEN v_executee := true; END IF;
    END IF;
  END IF;
  UPDATE public.jugements SET executee = (v_relaxe OR v_executee) WHERE id = v_jug;

  v_maj := jsonb_build_object(
    'status', v_statut,
    'verdict', v_verdict,
    'juge', v_juge,
    'juge_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'procedure_simplifiee', true,
    'defendue_par', v_nom,
    'defense_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'defense_issue', CASE WHEN v_relaxe THEN 'relaxe'
                          WHEN v_reussi THEN 'peine_reduite'
                          ELSE 'peine_normale' END,
    'defense_infraction', v_inf,
    'defense_avocat', v_av.nom,
    'defense_taux', v_taux,
    'defense_jet', v_jet,
    'qualification_finale', v_inf,
    'qualification_libelle', v_lib,
    'peine_jours', v_jours,
    'peine_amende', v_amende,
    'peine_libelle', v_peine,
    'detention_id', v_exec ->> 'detention_id',
    'appel_exclu', true);

  -- LE LAISSEZ-PASSER, ET IL NE DURE QUE CETTE ECRITURE. `plaintes_epingler_verdict` restaurerait
  -- `status`, `juge` et `peine` : l'accuse n'est pas une autorite judiciaire.
  PERFORM set_config('rp.verdict_interne', 'on', true);
  UPDATE public.plaintes_en_cours SET data = (v_data || v_maj)::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'au_parquet';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  PERFORM set_config('rp.verdict_interne', '', true);
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  -- ET L'EFFET EST RELU EN BASE, PAS SUPPOSE. « Decide au serveur » n'est pas « applique au
  -- serveur » : trois fois en deux jours un declencheur a defait une ecriture qui se croyait faite.
  SELECT p.data::jsonb ->> 'status' INTO v_statut_relu
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_statut_relu IS DISTINCT FROM v_statut THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_non_applique',
                              'statut', v_statut_relu, 'attendu', v_statut);
  END IF;

  -- LA CHRONOLOGIE PORTE LA PLAIDOIRIE **ET** LE VERDICT, dans cet ordre.
  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'defense_simplifiee',
    v_nom, 'accuse', NULL, v_inf,
    jsonb_build_object('avocat', v_av.nom, 'avocat_cha', v_av.cha, 'prevenu_cha', v_cha,
                       'preuve_reelle', v_preuve, 'taux', v_taux, 'jet', v_jet,
                       'reussie', v_reussi, 'jours_reference', v_i.jours_reference,
                       'categorie', v_i.categorie, 'seuil', v_seuil));
  IF v_relaxe THEN
    PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'relaxe',
      v_juge, 'juge', v_data ->> 'qualification_parquet', v_inf,
      jsonb_build_object('accuse', v_nom, 'procedure', 'simplifiee'));
  ELSE
    PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'condamnation',
      v_juge, 'juge', v_data ->> 'qualification_parquet', v_inf,
      jsonb_build_object('accuse', v_nom, 'jours', v_jours, 'amende', v_amende,
                         'jours_reference', (v_b ->> 'jours_reference')::integer,
                         'executee', v_executee, 'instance', 'simplifiee',
                         'procedure', 'simplifiee'));
  END IF;

  SELECT p.data::jsonb INTO v_data FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  RETURN jsonb_build_object('ok', true,
    'affaire', v_data, 'affaire_id', p_affaire_id,
    'infraction', v_inf, 'libelle', v_lib,
    'avocat', v_av.nom, 'avocat_cha', v_av.cha,
    'prevenu_cha', v_cha, 'preuve_reelle', v_preuve,
    'taux', v_taux, 'jet', v_jet, 'reussie', v_reussi,
    'verdict', v_verdict, 'statut', v_statut,
    'jours', v_jours, 'amende', v_amende, 'peine', v_peine,
    'jugement_id', v_jug, 'juge', v_juge, 'executee', (v_relaxe OR v_executee),
    'detention_id', v_exec ->> 'detention_id',
    'appel_exclu', true);
END $function$;

-- plainte_deposer(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plainte_deposer(p_cible text, p_motif text, p_categorie text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_pays text; v_ville text; v_jour integer;
  v_id text; v_data jsonb; v_cible text; v_cat text;
  v_pa integer; v_cost integer; v_n integer; v_paye jsonb;
BEGIN
  SELECT d.name, d.country, coalesce(d.current_city, 'capitale'), coalesce(d.day, 1)
    INTO v_nom, v_pays, v_ville, v_jour
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_motif IS NULL OR btrim(p_motif) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_absent');
  END IF;
  v_cible := coalesce(nullif(btrim(p_cible), ''), 'X');

  -- LA CATEGORIE ALLEGUEE EST LE PREMIER DES TROIS NIVEAUX DE QUALIFICATION, et c'est une
  -- DECLARATION du plaignant, pas une charge. Elle est validee contre les quatre categories
  -- generiques du code penal -- pour qu'elle veuille dire quelque chose -- mais elle n'engage
  -- rien : le parquet qualifiera ce qu'il veut, et le juge aussi.
  v_cat := nullif(btrim(coalesce(p_categorie, '')), '');
  IF v_cat IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.infractions_categories c WHERE c.id = v_cat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'categorie_inconnue', 'demande', v_cat);
  END IF;

  -- ANTI-SPAM : une seule plainte EN COURS DE TRAITEMENT par plaignant et par cible. Les statuts
  -- vivants sont ceux du parquet et du juge ; un dossier clos (non-lieu, arret, relaxe, jugee,
  -- abandonnee) n'empeche plus de deposer. VERIFIE AVANT LE PAIEMENT : un refus ne coute rien.
  IF EXISTS (SELECT 1 FROM public.plaintes_en_cours p
              WHERE p.country = v_pays
                AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
                AND (p.data::jsonb) ->> 'auteur' = v_nom
                AND (p.data::jsonb) ->> 'cible'  = v_cible
                AND (p.data::jsonb) ->> 'status' IN
                    ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande',
                     'deposee', 'enquete_ouverte')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plainte_deja_en_cours');
  END IF;

  -- LE COUT EST LU AU MIROIR, jamais ecrit ici. Fail closed.
  SELECT count(*) INTO v_n FROM public.ordres_couts o WHERE o.fn = 'plainte_police';
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_indetermine',
                              'fn', 'plainte_police', 'declarations', v_n);
  END IF;
  SELECT o.pa, o.cost INTO v_pa, v_cost FROM public.ordres_couts o WHERE o.fn = 'plainte_police';

  -- LE PAIEMENT PRECEDE LA CREATION, DANS LA MEME TRANSACTION (12 octobre 2026, inchange).
  v_paye := public.payer_ordre(v_nom, 'plainte_police', v_pa, v_cost);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paye ->> 'raison', 'paiement_refuse'),
                              'paiement', v_paye);
  END IF;

  v_id := 'plainte-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
          substr(md5(random()::text), 1, 6);

  -- LA PLAINTE EST UNE DECLARATION. Le serveur enregistre « v_nom affirme ceci contre v_cible »,
  -- et jamais « ceci est vrai ». Aucune instruction, aucune enquete, aucune garde a vue : le
  -- dossier arrive au parquet et attend.
  v_data := jsonb_build_object(
    'id', v_id, 'auteur', v_nom, 'cible', v_cible, 'motif', p_motif,
    'categorie_alleguee', v_cat,
    'jour', v_jour, 'city', v_ville, 'country', v_pays, 'status', 'au_parquet',
    'origine', 'plainte',
    'depose_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));

  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES (v_id, v_pays, v_ville, v_data::text);

  PERFORM public.dossier_acte_consigner(v_id, v_pays, v_ville, 'plainte_deposee',
    v_nom, NULL, NULL, NULL,
    jsonb_build_object('cible', v_cible, 'categorie_alleguee', v_cat));

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'ville', v_ville,
                            'statut', 'au_parquet', 'paiement', v_paye);
END;
$function$;

-- plainte_instruire_interne(text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plainte_instruire_interne(p_pays text, p_ville text, p_cible text, p_motif text, p_instructeur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acte   public.actions_tracables%ROWTYPE;
  v_jour   integer;
  v_det    jsonb;
  v_motifs jsonb;
  v_ce     jsonb;
BEGIN
  SELECT * INTO v_acte FROM public.actions_tracables a
   WHERE a.country = p_pays AND a.city = p_ville AND a.auteur = p_cible
     AND a.decouvert IS NOT TRUE
   ORDER BY a.jour DESC
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'decision', 'classee',
                              'motif_decision', 'aucun_element_a_charge');
  END IF;

  UPDATE public.actions_tracables SET decouvert = true WHERE id = v_acte.id;

  -- BRANCHE CONTRE-ESPIONNAGE. L'auteur de la trace est-il la couverture d'un
  -- agent reel ? Si oui, l'instruction produit un DEMASQUAGE, pas une garde a
  -- vue : detention_ouvrir_interne refuserait de toute facon (pas de fiche).
  v_ce := public.contre_espionnage_resoudre(p_pays, p_cible, p_instructeur,
            'actions_tracables:' || v_acte.id);
  IF coalesce((v_ce ->> 'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', true, 'decision', 'contre_espionnage',
      'acte', coalesce(v_acte.type_action, 'acte illegal'),
      'couverture', p_cible, 'enquete', v_ce);
  END IF;

  -- ---- A partir d'ici, comportement historique STRICTEMENT inchange ----
  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = p_cible;
  v_motifs := jsonb_build_array(jsonb_build_object(
    'type', coalesce(v_acte.type_action, 'Acte illegal decouvert par enquete'),
    'cible', v_acte.cible,
    'jour_fait', v_acte.jour,
    'city', p_ville,
    'ref_type', 'action_tracee',
    'ref_id', v_acte.id,
    'jours', 2,
    'source', 'garde_a_vue',
    'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

  v_det := public.detention_ouvrir_interne(
    p_cible, coalesce(v_acte.type_action, 'Acte illegal decouvert par enquete'), 2,
    p_ville, p_pays, v_motifs, p_instructeur, 'garde_a_vue_enquete');

  RETURN jsonb_build_object('ok', true, 'decision', 'enquete_ouverte',
                            'acte', coalesce(v_acte.type_action, 'acte illegal'),
                            'detention', v_det);
END;
$function$;

-- plainte_traiter(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plainte_traiter(p_id text, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_poste text; v_poste_city text; v_pays text;
  v_brut text; v_data jsonb; v_ville text; v_pays_plainte text; v_res jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_nom, v_poste, v_poste_city, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'commissaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  -- `classer` A DISPARU DE LA LISTE, et c'est le coeur du transfert d'autorite : l'opportunite
  -- des poursuites appartient au parquet. Un appel avec l'ancienne decision est refuse
  -- explicitement, pour que le defaut se voie au lieu d'etre avale.
  IF p_decision = 'classer' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'classement_reserve_au_parquet');
  END IF;
  IF p_decision <> 'enqueter' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide');
  END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays_plainte
    FROM public.plaintes_en_cours p WHERE p.id = p_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'dossier_introuvable');
  END IF;
  v_data := v_brut::jsonb;

  IF v_pays_plainte IS DISTINCT FROM v_pays OR v_ville IS DISTINCT FROM v_poste_city THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  -- L'ENQUETE N'EST POSSIBLE QUE SI LE PARQUET L'A ORDONNEE. C'est la regle : le Procureur
  -- dirige l'enquete, la police l'accomplit.
  IF coalesce(v_data ->> 'status', '') <> 'enquete' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'enquete_non_diligentee',
                              'statut', v_data ->> 'status');
  END IF;
  IF coalesce((v_data ->> 'enquete_accomplie')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'enquete_deja_accomplie');
  END IF;

  -- L'ACTE LUI-MEME EST INCHANGE : il cherche une trace non decouverte de la personne visee,
  -- la marque decouverte, traite la branche contre-espionnage, et ouvre une garde a vue.
  v_res := public.plainte_instruire_interne(v_pays, v_ville, v_data ->> 'cible',
                                            v_data ->> 'motif', v_nom);

  -- LE STATUT NE BOUGE PAS : le dossier reste `enquete`, donc au parquet. L'acte de police ne
  -- decide de rien -- il rapporte. C'est le Procureur qui en tirera un non-lieu ou des
  -- poursuites.
  UPDATE public.plaintes_en_cours
     SET data = (v_data || jsonb_build_object(
           'enquete_accomplie', true,
           'enquete_par_police', v_nom,
           'enquete_resultat', v_res ->> 'decision',
           'enquete_acte_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_id;

  PERFORM public.dossier_acte_consigner(p_id, v_pays, v_ville, 'enquete_acte_police',
    v_nom, 'commissaire', NULL, NULL,
    jsonb_build_object('resultat', v_res ->> 'decision', 'acte', v_res ->> 'acte'));

  RETURN v_res || jsonb_build_object('id', p_id, 'statut', 'enquete');
END;
$function$;

-- plaintes_epingler_verdict() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plaintes_epingler_verdict()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_old jsonb; v_new jsonb; v_cle text; v_proc record;
  -- Champs qui disent l'issue judiciaire. Tout le reste (defense, pieces, circonstances) reste
  -- librement modifiable par les parties.
  v_verdict constant text[] := ARRAY['status','sentence','peine','jugement','juge',
                                     'circonstanceAttenuante','aggravation'];
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  -- LAISSEZ-PASSER DES PORTES DU CYCLE (10 octobre 2026). Il reste utilise par la defense de
  -- l'accuse, qui ecrit un champ de verdict pour le compte de quelqu'un qui n'est PAS une
  -- autorite. Le classement ministeriel, qui l'employait aussi, a disparu avec la porte.
  IF coalesce(current_setting('rp.verdict_interne', true), '') = 'on' THEN RETURN NEW; END IF;
  -- L'AUTORITE JUDICIAIRE DE LA VILLE : le juge, et le commissaire.
  IF public.affaire_autorite_de(NEW.city) THEN RETURN NEW; END IF;

  -- ET LE PARQUET (12 octobre 2026). Le Procureur est NATIONAL : son poste n'a pas de ville,
  -- donc `affaire_autorite_de` le refusait, et ce declencheur restaurait le `status` qu'il venait
  -- d'ecrire -- ses poursuites etaient engagees et sans effet. Il n'est pas une PARTIE a
  -- l'affaire, il est l'autorite qui conduit la procedure : la protection ne le vise pas. Le pays
  -- est verifie, parce qu'un procureur n'a d'autorite que sur les affaires du sien.
  SELECT * INTO v_proc FROM public.parquet_moi();
  IF v_proc.nom IS NOT NULL AND v_proc.pays IS NOT DISTINCT FROM NEW.country THEN
    RETURN NEW;
  END IF;

  -- L'auteur n'est ni l'autorite judiciaire, ni le parquet : on restaure les champs de verdict
  -- tels qu'ils etaient. Si l'un d'eux est illisible, on ne prend aucun risque.
  IF OLD.data IS NULL OR left(btrim(OLD.data), 1) <> '{'
     OR NEW.data IS NULL OR left(btrim(NEW.data), 1) <> '{' THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_old := OLD.data::jsonb;
    v_new := NEW.data::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
  END;

  FOREACH v_cle IN ARRAY v_verdict LOOP
    IF (v_new -> v_cle) IS DISTINCT FROM (v_old -> v_cle) THEN
      IF (v_old ? v_cle) THEN
        v_new := jsonb_set(v_new, ARRAY[v_cle], v_old -> v_cle);
      ELSE
        v_new := v_new - v_cle;   -- le champ n'existait pas : il n'apparait pas
      END IF;
    END IF;
  END LOOP;

  NEW.data := v_new::text;
  RETURN NEW;
END;
$function$;

-- plaintes_temoins_sur_cloture() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plaintes_temoins_sur_cloture()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_avant text; v_apres text;
BEGIN
  IF NEW.data IS NULL OR left(btrim(NEW.data), 1) <> '{' THEN RETURN NULL; END IF;
  BEGIN
    v_apres := NEW.data::jsonb ->> 'status';
    v_avant := CASE WHEN OLD.data IS NOT NULL AND left(btrim(OLD.data), 1) = '{'
                    THEN OLD.data::jsonb ->> 'status' END;
  EXCEPTION WHEN OTHERS THEN RETURN NULL;
  END;
  IF v_apres IS NOT DISTINCT FROM v_avant THEN RETURN NULL; END IF;
  -- LA LISTE DES CLOTURES, ET ELLE REGARDE LE STATUT -- JAMAIS L'APPELANT. Une neuvieme porte de
  -- cloture heritera donc de cette extinction sans qu'on y pense.
  IF v_apres NOT IN ('non_lieu', 'abandonnee', 'arret', 'relaxe', 'jugee',
                     'jugee_appel', 'delai_expire') THEN RETURN NULL; END IF;
  PERFORM public.temoins_citations_eteindre_interne(NEW.id);
  RETURN NULL;
END $function$;

-- police_autorite_de_perimetre(text,text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.police_autorite_de_perimetre(p_pays text, p_perimetre text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ville text; v_bat text; v_nom text;
BEGIN
  IF p_perimetre IS NULL OR position(':' in p_perimetre) = 0 THEN RETURN NULL; END IF;
  v_ville := split_part(p_perimetre, ':', 1);
  v_bat   := split_part(p_perimetre, ':', 2);
  IF v_bat NOT IN ('commissariat','commissariat-local') THEN RETURN NULL; END IF;
  SELECT pd.name INTO v_nom
    FROM public.personnages_donnees pd
   WHERE COALESCE(pd.country, 'republic') = p_pays
     AND pd.poste->>'id' = 'commissaire'
     AND pd.poste->>'city' = v_ville
   ORDER BY pd.name
   LIMIT 1;
  RETURN v_nom;
END; $function$;

-- police_caracteristiques_metier() -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.police_caracteristiques_metier()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.pnj_metier_profil('policier');
$function$;

-- police_delai_intervention_secondes() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.police_delai_intervention_secondes()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 10 $function$;

-- police_payer_effectifs(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.police_payer_effectifs(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_standard  constant integer := 50;
  c_cynophile constant integer := 100;
  v_serveur boolean; v_moi text; v_poste text;
  v_jour date; r record; v_etat jsonb; v_eff jsonb; v_liste jsonb;
  v_du numeric; v_verse numeric; v_rep jsonb; v_n integer; v_gardes integer;
  v_cumul numeric; v_el jsonb; v_caisse text;
  v_villes jsonb := '[]'::jsonb; v_total_verse numeric := 0; v_total_partis integer := 0;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  v_serveur := public.est_appel_serveur();
  IF NOT v_serveur THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
    SELECT (poste->>'id') INTO v_poste FROM public.personnages_donnees WHERE name = v_moi;
    IF v_poste IS DISTINCT FROM 'min_int' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
    IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees
                    WHERE name = v_moi AND COALESCE(country,'republic') = p_pays) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_hors_autorite'); END IF;
  END IF;

  v_jour := ((now() AT TIME ZONE 'Europe/Paris')::date - 1);

  FOR r IN SELECT b.id, b.city, b.building_id, b.data
             FROM public.batiments_etat b
            WHERE b.country = p_pays
              AND b.building_id IN ('commissariat','commissariat-local')
            ORDER BY b.city
            FOR UPDATE
  LOOP
    v_etat := COALESCE(public.batiment_etat_lire(r.data), '{}'::jsonb);
    v_eff  := v_etat -> 'effectifsPolice';
    CONTINUE WHEN v_eff IS NULL OR jsonb_typeof(v_eff) <> 'object';
    CONTINUE WHEN COALESCE(v_eff ->> 'dernierPaiementJour', '') = v_jour::text;

    v_liste := COALESCE(v_eff -> 'policiers', '[]'::jsonb);
    IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;
    v_n := jsonb_array_length(v_liste);

    IF v_n = 0 THEN
      v_etat := jsonb_set(v_etat, ARRAY['effectifsPolice','dernierPaiementJour'],
                          to_jsonb(v_jour::text), true);
      UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
       WHERE id = r.id;
      v_villes := v_villes || jsonb_build_array(jsonb_build_object(
        'ville', r.city, 'effectif_avant', 0, 'verse', 0, 'partis', 0));
      CONTINUE;
    END IF;

    v_du := 0;
    FOR v_el IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
      v_du := v_du + CASE WHEN COALESCE(v_el->>'type','standard') = 'cynophile'
                          THEN c_cynophile ELSE c_standard END;
    END LOOP;

    -- La caisse est celle du commissariat DE CETTE VILLE. L'autorite propre a l'operation vient
    -- d'etre verifiee : on ouvre la porte interne pour cette transaction seulement.
    v_caisse := p_pays || '_commissariat_' || r.city;
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_rep := public.caisse_institution_mouvement_plafonne(v_caisse, v_du);
    PERFORM set_config('rp.caisse_interne', '', true);
    IF NOT COALESCE((v_rep->>'ok')::boolean, false) THEN
      v_villes := v_villes || jsonb_build_array(jsonb_build_object(
        'ville', r.city, 'refus', COALESCE(v_rep->>'raison','debit_refuse')));
      CONTINUE;
    END IF;
    v_verse := COALESCE((v_rep->>'verse')::numeric, 0);

    v_cumul := 0; v_gardes := 0;
    FOR v_el IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
      v_cumul := v_cumul + CASE WHEN COALESCE(v_el->>'type','standard') = 'cynophile'
                                THEN c_cynophile ELSE c_standard END;
      EXIT WHEN v_cumul > v_verse;
      v_gardes := v_gardes + 1;
    END LOOP;

    IF v_gardes < v_n THEN
      SELECT COALESCE(jsonb_agg(e ORDER BY o), '[]'::jsonb) INTO v_liste
        FROM jsonb_array_elements(v_liste) WITH ORDINALITY AS t(e, o)
       WHERE o <= v_gardes;
      v_etat := jsonb_set(v_etat, ARRAY['effectifsPolice','policiers'], v_liste, true);
    END IF;
    v_etat := jsonb_set(v_etat, ARRAY['effectifsPolice','dernierPaiementJour'],
                        to_jsonb(v_jour::text), true);
    UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
     WHERE id = r.id;

    v_total_verse  := v_total_verse + v_verse;
    v_total_partis := v_total_partis + (v_n - v_gardes);
    v_villes := v_villes || jsonb_build_array(jsonb_build_object(
      'ville', r.city, 'caisse', v_caisse, 'du', v_du, 'verse', v_verse,
      'effectif_avant', v_n, 'effectif_apres', v_gardes, 'partis', v_n - v_gardes));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'jour', v_jour, 'pays', p_pays,
    'verse_total', v_total_verse, 'partis_total', v_total_partis, 'villes', v_villes);
END; $function$;

-- police_pnj_id(text,text,text) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.police_pnj_id(p_pays text, p_ville text, p_matricule text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT 'police-' || p_pays || '-' || p_ville || '-' || p_matricule;
$function$;

-- police_signalement_resoudre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.police_signalement_resoudre(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_s record; v_c record; v_n integer; v_res jsonb;
  v_issue text; v_motifs jsonb; v_jour integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_s FROM public.signalements_police WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'signalement_absent'); END IF;
  -- SEUL LE SIGNALEUR RESOUT SON APPEL. Personne d'autre n'en connait l'identifiant, mais la
  -- garde ne repose pas sur ce secret.
  IF v_s.signaleur IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_signalement'); END IF;
  IF v_s.resolu_le IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'deja_resolu', true, 'issue', v_s.issue); END IF;
  -- LE DELAI EST UNE CONDITION SERVEUR. Un compte a rebours trafique arrive trop tot et se fait
  -- refuser : il ne peut pas avancer l'intervention.
  IF now() < v_s.echeance THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_non_ecoule',
      'echeance', to_char(v_s.echeance AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')); END IF;

  -- LA REVALIDATION : LA CIBLE EST-ELLE ENCORE DANS EXACTEMENT CETTE PIECE ?
  SELECT pr.country, pr.city, pr.building_id, pr.room_id INTO v_c
    FROM public.presences pr WHERE pr.name = v_s.cible;
  v_issue := CASE
    WHEN v_c IS NOT NULL
     AND v_c.country     IS NOT DISTINCT FROM v_s.pays
     AND v_c.city        IS NOT DISTINCT FROM v_s.ville
     AND v_c.building_id IS NOT DISTINCT FROM v_s.building_id
     AND v_c.room_id     IS NOT DISTINCT FROM v_s.room_id
    THEN 'arrestation' ELSE 'cible_partie' END;

  -- COMPARE-AND-SWAP : deux onglets arrivant ensemble a l'echeance n'arretent qu'une fois.
  UPDATE public.signalements_police
     SET resolu_le = now(), issue = v_issue
   WHERE id = p_id AND resolu_le IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', true, 'deja_resolu', true); END IF;

  IF v_issue = 'cible_partie' THEN
    -- AUCUNE POURSUITE AILLEURS, ET LE STATUT EST CONSERVE : la police s'est deplacee pour rien.
    RETURN jsonb_build_object('ok', true, 'issue', 'cible_partie', 'cible', v_s.cible,
      'arrestation', false); END IF;

  -- L'ARRESTATION PASSE PAR LA CHAINE EXISTANTE, et pour la meme duree qu'une arrestation
  -- d'urgence : un jour. Le PV d'audition est ce qui l'ouvrira ensuite.
  v_jour := coalesce(public.jour_de_jeu_pays(v_s.pays), 1);
  v_motifs := jsonb_build_array(jsonb_build_object(
    'type', 'Interpellation sur signalement', 'jour_fait', v_jour,
    'city', v_s.ville, 'jours', 1, 'source', 'signalement_police',
    'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

  v_res := public.detention_ouvrir_interne(
             v_s.cible, 'Interpellation sur signalement', 1, v_s.ville, v_s.pays,
             v_motifs, 'Police de ' || v_s.ville, 'arrestation_sur_signalement');
  IF coalesce((v_res ->> 'ok')::boolean, false) IS NOT TRUE THEN
    -- La detention n'a pas pu s'ouvrir -- deja detenu, par exemple. Le signalement reste resolu :
    -- la police est venue, et on ne raconte pas une arrestation qui n'a pas eu lieu.
    RETURN jsonb_build_object('ok', true, 'issue', 'arrestation', 'arrestation', false,
      'cible', v_s.cible, 'raison_detention', v_res ->> 'raison'); END IF;

  RETURN jsonb_build_object('ok', true, 'issue', 'arrestation', 'arrestation', true,
    'cible', v_s.cible, 'detention_id', v_res ->> 'detention_id', 'ville', v_s.ville);
END;
$function$;

-- police_signaler(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.police_signaler(p_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_m record; v_c record; v_id text; v_ech timestamptz; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(coalesce(p_cible, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente'); END IF;
  IF p_cible = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_est_l_acteur'); END IF;

  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi;
  -- BORNE A REPUBLIA, et c'est explicite : ailleurs, la question de l'arrestation citoyenne n'est
  -- pas tranchee, et une porte ouverte « au cas ou » serait une decision prise en passant.
  IF v_pays IS DISTINCT FROM 'republic' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'signalement_reserve_a_republia',
                              'pays', v_pays); END IF;

  SELECT pr.country, pr.city, pr.building_id, pr.room_id INTO v_m
    FROM public.presences pr WHERE pr.name = v_moi;
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_inconnue'); END IF;

  -- LA CIBLE DOIT ETRE DANS LA MEME PIECE AU DECLENCHEMENT. Quatre coordonnees, pas trois : un
  -- filtre sans `room_id` aurait permis de signaler quelqu'un a l'autre bout du batiment.
  SELECT pr.country, pr.city, pr.building_id, pr.room_id INTO v_c
    FROM public.presences pr WHERE pr.name = p_cible;
  IF v_c IS NULL
     OR v_c.country IS DISTINCT FROM v_m.country OR v_c.city IS DISTINCT FROM v_m.city
     OR v_c.building_id IS DISTINCT FROM v_m.building_id
     OR v_c.room_id IS DISTINCT FROM v_m.room_id THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente_de_la_piece'); END IF;

  IF NOT public.justice_est_recherche(p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_recherchee'); END IF;

  -- RAMASSAGE DES SIGNALEMENTS OUBLIES. Un navigateur ferme avant l'echeance laisserait sa cible
  -- protegee a vie par l'index unique partiel : on clot ceux dont l'echeance est passee d'une
  -- minute, et eux seuls -- jamais un signalement encore en cours.
  UPDATE public.signalements_police
     SET resolu_le = now(), issue = 'abandonne'
   WHERE resolu_le IS NULL AND echeance < now() - interval '1 minute';

  v_ech := now() + make_interval(secs => public.police_delai_intervention_secondes());
  v_id := 'sig-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
          || substr(md5(v_moi || '|' || p_cible), 1, 6);

  BEGIN
    INSERT INTO public.signalements_police
      (id, pays, ville, building_id, room_id, signaleur, cible, echeance)
    VALUES (v_id, v_m.country, v_m.city, v_m.building_id, v_m.room_id, v_moi, p_cible, v_ech);
  EXCEPTION WHEN unique_violation THEN
    -- L'INDEX UNIQUE PARTIEL A MORDU : une intervention est deja en route sur cette personne.
    RETURN jsonb_build_object('ok', false, 'raison', 'intervention_deja_en_route');
  END;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'cible', p_cible,
    'delai_secondes', public.police_delai_intervention_secondes(),
    'echeance', to_char(v_ech AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
END;
$function$;

-- presidence_gracier(text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presidence_gracier(p_condamne text, p_jour integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_president text; v_peine jsonb; v_r jsonb;
BEGIN
  v_president := public.exiger_poste('president');
  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees
   WHERE name = p_condamne FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok', true, 'libere', false, 'raison', 'non_detenu');
  END IF;
  v_r := public.detention_clore_interne(p_condamne, 'grace_presidentielle', p_jour);
  RETURN jsonb_build_object('ok', true, 'libere', true,
                            'president', v_president, 'condamne', p_condamne) || v_r;
END; $function$;

-- pv_audition_realiser(text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pv_audition_realiser(p_affaire_id text, p_declaration text DEFAULT NULL::text, p_refus boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer;
  v_det record; v_libere boolean := false; v_echeance integer; v_n integer; v_r jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_a := v_brut::jsonb;

  -- L'AUDITION EST CELLE DE LA PERSONNE MISE EN CAUSE, ET D'ELLE SEULE.
  IF coalesce(v_a ->> 'cible', '') IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire');
  END IF;
  IF coalesce(v_a ->> 'status', '') NOT IN
     ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_close',
                              'statut', v_a ->> 'status');
  END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_echeance := v_jour + public.justice_delai_jugement_jours();

  -- LA RACINE COMMUNE. `p_exiger_presence` vaut FALSE : le PV du prevenu n'a jamais exige sa
  -- presence au commissariat, et cette tranche ne change pas une mecanique validee. Voir
  -- l'en-tete : c'est la seule valeur a confirmer.
  v_r := public.audition_consigner_interne(p_affaire_id, v_pays, v_ville, v_moi, 'prevenu',
           p_declaration, p_refus, v_jour, false);
  IF coalesce((v_r ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;

  -- LE DOSSIER PORTE DESORMAIS SON ECHEANCE, et c'est ce qui rend le delai OPPOSABLE sans
  -- qu'aucune autorite n'ait a y penser. Compare-and-swap sur le statut : une transition
  -- concurrente du parquet ne se fait pas ecraser.
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'pv_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'pv_jour', v_jour,
           'pv_refus', coalesce((v_r ->> 'refus')::boolean, false),
           'inculpe_depuis_jour', v_jour,
           'delai_jugement_jour', v_echeance))::text
   WHERE id = p_affaire_id
     AND (data::jsonb ->> 'status') = (v_a ->> 'status');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  -- LA LIBERATION NE CONCERNE QUE LA DETENTION D'AVANT JUGEMENT. Une peine en cours d'execution
  -- pour une AUTRE affaire n'est pas touchee : ce PV ne purge rien.
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  IF v_det.id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.detentions d
                  WHERE d.id = v_det.id
                    AND coalesce(d.issue_judiciaire, '') IN ('arrestation_urgence', 'garde_a_vue')) THEN
    PERFORM public.detention_clore_interne(v_moi, 'pv_audition_realise', v_jour);
    v_libere := true;
  END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'pv_audition',
    v_moi, NULL, NULL, NULL,
    jsonb_build_object('refus', coalesce((v_r ->> 'refus')::boolean, false),
                       'declaration', v_r ->> 'declaration',
                       'jour_pv', v_jour, 'delai_jugement_jour', v_echeance,
                       'libere', v_libere));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id,
                            'refus', coalesce((v_r ->> 'refus')::boolean, false),
                            'jour_pv', v_jour, 'delai_jugement_jour', v_echeance,
                            'libere', v_libere);
END $function$;

-- qhs_pouvoir(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.qhs_pouvoir(p_prisonnier_id text, p_acte text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acteur text; v_pays text; v_data jsonb; v_nom text; v_det record;
  v_caisse text; v_solde numeric; v_cout integer := 500; v_res jsonb; v_moral integer;
BEGIN
  -- 1. AUTORITE : le poste est relu sur la ligne de l'appelant, jamais annonce par lui.
  v_acteur := public.exiger_poste('min_just');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_acte NOT IN ('transferer', 'ameliorer', 'torturer') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;

  -- 2. LE PRISONNIER DU REGISTRE QHS.
  SELECT data INTO v_data FROM public.prisonniers_qhs
   WHERE id = p_prisonnier_id AND coalesce(statut, '') <> 'transfere' FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prisonnier_introuvable');
  END IF;
  v_nom := v_data->>'nom';

  -- 3. LA DETENTION CANONIQUE. Sans elle, aucun pouvoir QHS ne s'exerce.
  SELECT * INTO v_det FROM public.detention_active(v_nom);
  IF v_det.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_detenue');
  END IF;

  -- 4. L'ACTE.
  IF p_acte = 'transferer' THEN
    UPDATE public.detentions SET qhs = false WHERE id = v_det.id;
    UPDATE public.prisonniers_qhs SET statut = 'transfere' WHERE id = p_prisonnier_id;
    UPDATE public.personnages_donnees
       SET detention_qhs = jsonb_build_object('enQHS', false, 'eligibleBonusAvocat', true)
     WHERE name = v_nom;
    RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'cible', v_nom);
  END IF;

  IF p_acte = 'ameliorer' THEN
    -- Debit et effet dans la MEME transaction : plus jamais 500 FR sortis pour rien.
    v_caisse := v_pays || '_qhs-prison';
    SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde
      FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    IF v_solde IS NULL OR v_solde < v_cout THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'cout', v_cout);
    END IF;
    UPDATE public.caisses_batiments
       SET data = data || jsonb_build_object('solde', v_solde - v_cout), updated_at = now()
     WHERE id = v_caisse;

    SELECT coalesce(moral, 50) INTO v_moral FROM public.personnages_donnees WHERE name = v_nom;
    UPDATE public.personnages_donnees
       SET moral = least(100, v_moral + 15),
           detention_qhs = jsonb_build_object('enQHS', true, 'paLimite1Jour', false,
                                              'conditionsAmeliorees', true)
     WHERE name = v_nom;
    RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'cible', v_nom, 'cout', v_cout);
  END IF;

  -- torture : indices et moral a zero, PA plafonnes a 1 le lendemain.
  -- inf/pop/dis sont des CLES DE `resources`, pas des colonnes -- l'ancien code l'ignorait.
  SELECT CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END
    INTO v_res FROM public.personnages_donnees WHERE name = v_nom;
  UPDATE public.personnages_donnees
     SET resources = v_res || jsonb_build_object('inf', 0, 'pop', 0, 'dis', 0),
         moral = 0,
         detention_qhs = jsonb_build_object('enQHS', true, 'paLimite1Jour', true)
   WHERE name = v_nom;
  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'cible', v_nom);
END; $function$;

-- recherche_inscrire(jsonb,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.recherche_inscrire(p_entree jsonb, p_cible text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_cible text; v_id text; v_apres jsonb; v_n integer;
BEGIN
  IF p_entree IS NULL OR jsonb_typeof(p_entree) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entree_invalide');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NOT NULL THEN
    -- UN JOUEUR N'INSCRIT QUE SUR SA PROPRE FICHE. Condamner autrui est un pouvoir, et il a sa
    -- porte : justice_condamner, qui relit le poste de l'appelant.
    IF p_cible IS NOT NULL AND p_cible <> v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_ma_fiche');
    END IF;
    v_cible := v_moi;
  ELSE
    IF coalesce(btrim(coalesce(p_cible, '')), '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_manquante');
    END IF;
    v_cible := p_cible;
  END IF;

  PERFORM set_config('rp.recherche_interne', 'on', true);

  -- IDEMPOTENCE PAR IDENTIFIANT, quand l'entree en porte un. C'est le cas du mandat d'arret des
  -- tracts calomnieux, dont le client verifiait deja l'absence avant de le refleter. Un crime
  -- ordinaire, lui, n'a pas d'identifiant : il peut etre commis deux fois, et doit s'inscrire
  -- deux fois.
  v_id := nullif(p_entree ->> 'id', '');
  IF v_id IS NOT NULL THEN
    SELECT count(*) INTO v_n FROM public.personnages_donnees d,
           jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche)='array'
                                     THEN d.recherche ELSE '[]'::jsonb END) e
     WHERE d.name = v_cible AND e ->> 'id' = v_id;
    IF v_n > 0 THEN
      SELECT coalesce(recherche, '[]'::jsonb) INTO v_apres
        FROM public.personnages_donnees WHERE name = v_cible;
      RETURN jsonb_build_object('ok', true, 'action', 'deja_inscrite',
                                'recherche', coalesce(v_apres, '[]'::jsonb));
    END IF;
  END IF;

  -- L'AJOUT EST ATOMIQUE : aucune relecture, donc aucune fenetre de perte.
  UPDATE public.personnages_donnees
     SET recherche = (CASE WHEN jsonb_typeof(recherche) = 'array'
                           THEN recherche ELSE '[]'::jsonb END) || jsonb_build_array(p_entree)
   WHERE name = v_cible
  RETURNING recherche INTO v_apres;
  PERFORM set_config('rp.recherche_interne', '', true);   -- la portee s'arrete ici
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  RETURN jsonb_build_object('ok', true, 'action', 'inscrite',
                            'recherche', coalesce(v_apres, '[]'::jsonb));
END; $function$;

-- recherche_retirer(text[],text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.recherche_retirer(p_actes text[], p_pays text DEFAULT NULL::text, p_cible text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_cible text; v_avant jsonb; v_apres jsonb;
BEGIN
  IF p_actes IS NULL OR array_length(p_actes, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'actes_manquants');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NOT NULL THEN
    IF p_cible IS NOT NULL AND p_cible <> v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_ma_fiche');
    END IF;
    v_cible := v_moi;
  ELSE
    IF coalesce(btrim(coalesce(p_cible, '')), '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_manquante');
    END IF;
    v_cible := p_cible;
  END IF;

  SELECT CASE WHEN jsonb_typeof(recherche)='array' THEN recherche ELSE '[]'::jsonb END
    INTO v_avant FROM public.personnages_donnees WHERE name = v_cible FOR UPDATE;
  IF v_avant IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  PERFORM set_config('rp.recherche_interne', 'on', true);

  -- LE FILTRE EST EXACTEMENT `estMienne` DU CLIENT : l'acte, et le pays quand l'entree en porte
  -- un. UN MOTIF N'EN EFFACE JAMAIS UN AUTRE -- ni celui d'un autre acte, ni celui d'un autre
  -- empire. C'est la regle posee le 13 septembre 2026, reprise ici sans un mot de plus.
  SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_apres
    FROM jsonb_array_elements(v_avant) e
   WHERE NOT ( (e ->> 'acte') = ANY (p_actes)
               AND ( p_pays IS NULL
                     OR coalesce(nullif(e ->> 'country', ''), p_pays) = p_pays ) );

  UPDATE public.personnages_donnees SET recherche = v_apres WHERE name = v_cible;
  PERFORM set_config('rp.recherche_interne', '', true);   -- la portee s'arrete ici

  RETURN jsonb_build_object('ok', true, 'action', 'retires',
    'retires', jsonb_array_length(v_avant) - jsonb_array_length(v_apres),
    'recherche', v_apres);
END; $function$;

-- recherche_retirer_par_id(text,text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.recherche_retirer_par_id(p_cible text, p_id text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_avant jsonb; v_apres jsonb;
BEGIN
  IF coalesce(btrim(coalesce(p_cible, '')), '') = ''
     OR coalesce(btrim(coalesce(p_id, '')), '') = '' THEN RETURN 0; END IF;

  SELECT CASE WHEN jsonb_typeof(recherche) = 'array' THEN recherche ELSE '[]'::jsonb END
    INTO v_avant FROM public.personnages_donnees WHERE name = p_cible FOR UPDATE;
  IF v_avant IS NULL THEN RETURN 0; END IF;

  SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_apres
    FROM jsonb_array_elements(v_avant) e WHERE (e ->> 'id') IS DISTINCT FROM p_id;

  IF jsonb_array_length(v_apres) = jsonb_array_length(v_avant) THEN RETURN 0; END IF;
  PERFORM set_config('rp.recherche_interne', 'on', true);
  UPDATE public.personnages_donnees SET recherche = v_apres WHERE name = p_cible;
  PERFORM set_config('rp.recherche_interne', '', true);
  RETURN jsonb_array_length(v_avant) - jsonb_array_length(v_apres);
END $function$;

-- temoin_citer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoin_citer(p_affaire_id text, p_temoin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_t text;
  v_qualite text; v_p record; v_j record; v_jour integer; v_ech integer; v_rang bigint;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_t := nullif(btrim(coalesce(p_temoin, '')), '');
  IF v_t IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'temoin_manquant'); END IF;
  IF v_t = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_soi_meme'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;
  IF coalesce(v_a ->> 'status', '') NOT IN
     ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_close', 'statut', v_a ->> 'status'); END IF;
  IF v_t = coalesce(v_a ->> 'cible', '') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'le_prevenu_n_est_pas_temoin'); END IF;

  -- LES QUATRE AUTORITES, DANS L'ORDRE OU ELLES SE RECONNAISSENT.
  v_qualite := NULL;
  IF public.defense_avocat_de(p_affaire_id) = v_moi THEN
    -- L'AVOCAT PERD CE POUVOIR A L'OUVERTURE DE L'AUDIENCE, et lui seul : le cahier des charges
    -- ne retire rien au juge ni au parquet, et on ne leur retire donc rien.
    IF public.affaire_audience_ouverte(v_a) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;
    v_qualite := 'avocat';
  ELSE
    SELECT * INTO v_p FROM public.parquet_moi();
    IF v_p.nom = v_moi AND v_p.pays IS NOT DISTINCT FROM v_pays THEN
      v_qualite := 'parquet';
    ELSE
      SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
      IF v_j.nom = v_moi THEN
        v_qualite := 'juge';
      ELSIF coalesce(v_a ->> 'plaignant', v_a ->> 'auteur') = v_moi
            AND coalesce(v_a ->> 'status', '') = 'au_parquet' THEN
        -- LE PLAIGNANT CITE SES TEMOINS AU MOMENT DU DEPOT, et c'est rendu par la fenetre ou son
        -- dossier n'a encore ete touche par personne : `au_parquet`. Des que le parquet agit, ce
        -- n'est plus le moment du depot.
        v_qualite := 'plaignant';
      END IF;
    END IF;
  END IF;
  IF v_qualite IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee'); END IF;

  -- AUCUN FILTRE SUR LE TEMOIN, ET C'EST LA REGLE. N'importe quel PJ, de n'importe quel empire :
  -- le serveur ne sait pas ce qu'un humain a vu, et il ne doit pas en decider.
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = v_t) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'temoin_introuvable'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_ech := v_jour + public.justice_delai_convocation_temoin_jours();
  BEGIN
    INSERT INTO public.temoins_citations
      (affaire, pays, ville, temoin, cite_par, cite_par_qualite, echeance_jour)
    VALUES (p_affaire_id, v_pays, v_ville, v_t, v_moi, v_qualite, v_ech)
    RETURNING rang INTO v_rang;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'temoin_deja_cite');
  END;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'temoin_cite',
    v_moi, v_qualite, NULL, NULL,
    jsonb_build_object('temoin', v_t, 'convocation', 1, 'echeance_jour', v_ech,
                       'commissariat', (SELECT c.batiment FROM public.temoin_commissariat_competent(v_pays, v_ville) c)));

  RETURN jsonb_build_object('ok', true, 'citation', v_rang, 'affaire', p_affaire_id,
    'temoin', v_t, 'par', v_moi, 'qualite', v_qualite,
    'convocation', 1, 'echeance_jour', v_ech,
    'commissariat', (SELECT c.batiment FROM public.temoin_commissariat_competent(v_pays, v_ville) c),
    'piece', (SELECT c.piece FROM public.temoin_commissariat_competent(v_pays, v_ville) c));
END $function$;

-- temoin_commissariat_competent(text,text) -> TABLE(batiment text, piece text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoin_commissariat_competent(p_pays text, p_ville text)
 RETURNS TABLE(batiment text, piece text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- LA VILLE EST CELLE DU TRIBUNAL COMPETENT POUR L'AFFAIRE, pas celle du temoin : une affaire
  -- de Montrouge se depose au commissariat de Montrouge, meme si le temoin habite Luthecia.
  SELECT CASE WHEN v.est_capitale THEN 'commissariat' ELSE 'commissariat-local' END,
         CASE WHEN v.est_capitale THEN 'accueil_police' ELSE 'accueil_loc' END
    FROM public.villes v WHERE v.pays = p_pays AND v.ville = p_ville;
$function$;

-- temoin_deposer(text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoin_deposer(p_affaire_id text, p_declaration text DEFAULT NULL::text, p_refus boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_c record; v_jour integer; v_r jsonb; v_n integer;
  v_det record; v_libere boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_c FROM public.temoins_citations
   WHERE affaire = p_affaire_id AND temoin = v_moi AND etat <> 'close' FOR UPDATE;
  IF v_c.rang IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_citation_vivante'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_c.pays), 1);
  -- LA RACINE COMMUNE, AVEC LA PRESENCE EXIGEE. C'est elle qui refuse la reponse vide, efface le
  -- texte d'un refus explicite, et verifie le commissariat.
  v_r := public.audition_consigner_interne(p_affaire_id, v_c.pays, v_c.ville, v_moi, 'temoin',
           p_declaration, p_refus, v_jour, true);
  IF coalesce((v_r ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;

  -- L'OBLIGATION EST SATISFAITE. Compare-and-swap : deux onglets ne closent pas deux fois.
  UPDATE public.temoins_citations
     SET etat = 'close',
         issue = CASE WHEN coalesce((v_r ->> 'refus')::boolean, false) THEN 'refus' ELSE 'deposition' END,
         clos_le = now()
   WHERE rang = v_c.rang AND etat <> 'close';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'citation_deja_close'); END IF;

  -- LA RECHERCHE POUR NON-PRESENTATION DISPARAIT, ET ELLE SEULE. Les autres causes subsistent.
  PERFORM public.recherche_retirer_par_id(v_moi, 'temoin-' || v_c.rang);

  -- ET UNE DETENTION QUI N'EXISTAIT QUE POUR CETTE NON-PRESENTATION CESSE. La mesure est
  -- precise : apres retrait de l'entree, ce joueur n'est plus recherche du tout. S'il l'est
  -- encore pour autre chose, sa detention n'existait pas « que pour cela » et elle reste.
  IF NOT public.justice_est_recherche(v_moi) THEN
    SELECT * INTO v_det FROM public.detention_active(v_moi);
    IF v_det.id IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.detentions d
                    WHERE d.id = v_det.id
                      AND coalesce(d.issue_judiciaire, '') = 'arrestation_sur_signalement') THEN
      PERFORM public.detention_clore_interne(v_moi, 'deposition_de_temoin_realisee', v_jour);
      v_libere := true;
    END IF;
  END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_c.pays, v_c.ville, 'temoin_deposition',
    v_moi, 'temoin', NULL, NULL,
    jsonb_build_object('refus', coalesce((v_r ->> 'refus')::boolean, false),
                       'declaration', v_r ->> 'declaration',
                       'citation', v_c.rang, 'jour', v_jour, 'libere', v_libere));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'citation', v_c.rang,
    'refus', coalesce((v_r ->> 'refus')::boolean, false), 'jour', v_jour, 'libere', v_libere);
END $function$;

-- temoin_mes_convocations() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoin_mes_convocations()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  RETURN jsonb_build_object('ok', true, 'temoin', v_moi,
    'convocations', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'citation', c.rang, 'affaire', c.affaire, 'pays', c.pays, 'ville', c.ville,
        'convocation', c.convocation_rang, 'echeance_jour', c.echeance_jour,
        'etat', c.etat,
        'jour_courant', public.jour_de_jeu_pays(c.pays),
        'site', (SELECT k.batiment FROM public.temoin_commissariat_competent(c.pays, c.ville) k),
        'piece', (SELECT k.piece FROM public.temoin_commissariat_competent(c.pays, c.ville) k),
        'sur_place', public.acteur_present_sur_site(v_moi, c.pays, c.ville,
                       (SELECT k.batiment FROM public.temoin_commissariat_competent(c.pays, c.ville) k),
                       (SELECT k.piece FROM public.temoin_commissariat_competent(c.pays, c.ville) k))
        ) ORDER BY c.rang), '[]'::jsonb)
      FROM public.temoins_citations c
     WHERE c.temoin = v_moi AND c.etat <> 'close'));
END $function$;

-- temoins_citations_eteindre_interne(text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoins_citations_eteindre_interne(p_affaire text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_c record; v_n integer := 0;
BEGIN
  FOR v_c IN SELECT * FROM public.temoins_citations
              WHERE affaire = p_affaire AND etat <> 'close' LOOP
    UPDATE public.temoins_citations
       SET etat = 'close', issue = 'affaire_close', clos_le = now()
     WHERE rang = v_c.rang AND etat <> 'close';
    IF NOT FOUND THEN CONTINUE; END IF;
    v_n := v_n + 1;
    -- ON NE RETIRE QUE L'ENTREE DE CETTE CITATION. Une autre affaire, une autre citation, une
    -- infraction : rien de tout cela n'est touche.
    PERFORM public.recherche_retirer_par_id(v_c.temoin, 'temoin-' || v_c.rang);
    PERFORM public.dossier_acte_consigner(v_c.affaire, v_c.pays, v_c.ville,
      'temoin_citation_eteinte', 'Greffe', 'serveur', NULL, NULL,
      jsonb_build_object('temoin', v_c.temoin, 'citation', v_c.rang));
  END LOOP;
  RETURN v_n;
END $function$;

-- temoins_convocations_echues() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoins_convocations_echues()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_c record; v_jour integer; v_relances integer := 0; v_recherches integer := 0; v_ech integer;
BEGIN
  FOR v_c IN SELECT * FROM public.temoins_citations
              WHERE etat = 'convoquee' ORDER BY rang LOOP
    v_jour := coalesce(public.jour_de_jeu_pays(v_c.pays), 1);
    -- AU JOUR DE L'ECHEANCE, RIEN N'EST ECHU. Le deuxieme jour est encore a lui -- meme
    -- convention que le delai de jugement.
    CONTINUE WHEN v_jour <= v_c.echeance_jour;

    IF v_c.convocation_rang = 1 THEN
      v_ech := v_jour + public.justice_delai_convocation_temoin_jours();
      UPDATE public.temoins_citations
         SET convocation_rang = 2, echeance_jour = v_ech
       WHERE rang = v_c.rang AND etat = 'convoquee' AND convocation_rang = 1;
      IF FOUND THEN
        v_relances := v_relances + 1;
        PERFORM public.dossier_acte_consigner(v_c.affaire, v_c.pays, v_c.ville,
          'temoin_convocation_renouvelee', 'Greffe', 'serveur', NULL, NULL,
          jsonb_build_object('temoin', v_c.temoin, 'convocation', 2,
                             'echeance_jour', v_ech, 'citation', v_c.rang));
      END IF;
    ELSE
      -- SECONDE ABSENCE : LA RECHERCHE, ET RIEN D'AUTRE. Aucune autre consequence automatique --
      -- la preuve P11 le mesure sur les identifiants de code.
      UPDATE public.temoins_citations SET etat = 'recherche'
       WHERE rang = v_c.rang AND etat = 'convoquee' AND convocation_rang = 2;
      IF FOUND THEN
        v_recherches := v_recherches + 1;
        PERFORM public.recherche_inscrire(jsonb_build_object(
          'id', 'temoin-' || v_c.rang,
          'acte', 'non_presentation_temoin',
          'type', 'temoin',
          'affaire', v_c.affaire,
          'citation', v_c.rang,
          'country', v_c.pays,
          'ville', v_c.ville,
          'jour', v_jour), v_c.temoin);
        PERFORM public.dossier_acte_consigner(v_c.affaire, v_c.pays, v_c.ville,
          'temoin_recherche', 'Greffe', 'serveur', NULL, NULL,
          jsonb_build_object('temoin', v_c.temoin, 'citation', v_c.rang, 'jour', v_jour));
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'secondes_convocations', v_relances,
                            'recherches_ouvertes', v_recherches);
END $function$;
