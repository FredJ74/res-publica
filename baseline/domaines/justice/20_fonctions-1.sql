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

-- affaire_audience_ouverte(jsonb) -> boolean | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.affaire_audience_ouverte(p_data jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT coalesce(p_data ? 'audience_ouverte_le', false); $function$;

-- affaire_autorite_de(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_autorite_de(p_city text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- LE COMMISSAIRE, ET LE JUGE PJ : la fiche du compte authentifie, comme avant.
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') IN ('juge', 'commissaire')
       -- Juridiction : la ville du POSTE doit etre celle de l'affaire.
       -- coalesce a 'capitale' pour les affaires anterieures sans ville.
       AND (d.poste ->> 'city') IS NOT DISTINCT FROM coalesce(p_city, 'capitale')
  )
  -- LE JUGE, PAR SON RESOLVEUR UNIQUE. Il couvre le juge PJ (deja couvert ci-dessus, et c'est
  -- sans consequence) et le PNJ titulaire incarne par l'administration, dont la titularite est
  -- reverifiee a chaque appel. Sans cette branche, un verdict d'Honore est rendu et defait.
  OR EXISTS (
    SELECT 1 FROM public.juge_moi() j
     WHERE j.ville IS NOT DISTINCT FROM coalesce(p_city, 'capitale')
  );
$function$;

-- affaire_categorie_publique(jsonb) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_categorie_publique(p_data jsonb)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
    (SELECT i.categorie FROM public.infractions i
      WHERE i.id = coalesce(p_data ->> 'qualification_finale',
                            p_data ->> 'qualification_parquet',
                            p_data ->> 'infraction_constatee')),
    p_data ->> 'categorie_alleguee');
$function$;

-- affaire_delai_expire(jsonb,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_delai_expire(p_data jsonb, p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT (p_data ->> 'delai_jugement_jour') IS NOT NULL
     AND coalesce(public.jour_de_jeu_pays(coalesce(p_pays, p_data ->> 'country')), 1)
         > (p_data ->> 'delai_jugement_jour')::integer;
$function$;

-- affaire_infraction_de(jsonb) -> text | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_infraction_de(p_data jsonb)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT nullif(btrim(coalesce(
    p_data ->> 'qualification_finale',
    p_data ->> 'qualification_parquet',
    p_data ->> 'infraction_constatee', '')), '');
$function$;

-- affaire_me_concerne(text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_me_concerne(p_data text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_json jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL OR p_data IS NULL OR left(btrim(p_data), 1) <> '{' THEN
    RETURN false;
  END IF;
  BEGIN
    v_json := p_data::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN false;   -- data illisible : on n'accorde rien
  END;
  RETURN (v_json ->> 'cible') = v_moi OR (v_json ->> 'plaignant') = v_moi;
END;
$function$;

-- affaire_statut(text) -> text | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_statut(p_data text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_data IS NULL OR left(btrim(p_data), 1) <> '{' THEN RETURN NULL; END IF;
  RETURN (p_data::jsonb ->> 'status');
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;   -- data illisible : aucune publicite accordee
END;
$function$;

-- affaire_transmettre(text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_transmettre(p_cible text, p_motif text, p_city text, p_fait jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_pays text; v_jour integer; v_ville text;
  v_cible text; v_motif text; v_id text; v_data jsonb; v_n integer; v_infr text;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_cible := nullif(btrim(coalesce(p_cible, '')), '');
  v_motif := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_cible IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente'); END IF;
  IF v_motif IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'motif_absent'); END IF;
  v_ville := coalesce(nullif(btrim(coalesce(p_city, '')), ''), 'capitale');

  IF NOT public.affaire_autorite_de(v_ville) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee', 'ville', v_ville);
  END IF;

  -- L'INFRACTION CONSTATEE, QUAND LA POLICE LA CONNAIT. Elle passe par `infraction_canonique`,
  -- qui refuse un identifiant inconnu ET un nom de categorie : un motif libre ne devient jamais
  -- une qualification par accident. Une infraction non reconnue n'est pas une erreur -- la
  -- police transmet souvent sur un motif qu'aucun catalogue ne nomme -- elle est simplement
  -- ignoree, et le dossier part sans infraction constatee, comme avant cette migration.
  v_infr := NULL;
  IF p_fait IS NOT NULL AND jsonb_typeof(p_fait) = 'object'
     AND nullif(btrim(coalesce(p_fait ->> 'infraction', '')), '') IS NOT NULL THEN
    v_infr := public.infraction_canonique(p_fait ->> 'infraction');
  END IF;

  SELECT d.country, coalesce(d.day, 1) INTO v_pays, v_jour
    FROM public.personnages_donnees d WHERE d.name = v_nom LIMIT 1;
  v_pays := coalesce(v_pays, 'republic');

  v_id := 'affaire-' || v_pays || '-' || v_ville || '-' || v_jour || '-'
          || substr(md5(v_cible || '|' || v_motif || '|' || coalesce(p_fait ->> 'refId', '')), 1, 12);

  v_data := jsonb_build_object('id', v_id, 'country', v_pays, 'city', v_ville,
                               'cible', v_cible, 'motif', v_motif, 'jour', v_jour,
                               'status', 'au_parquet', 'origine', 'police',
                               'transmise_par', v_nom,
                               'depose_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
  IF v_infr IS NOT NULL THEN
    v_data := v_data || jsonb_build_object('infraction_constatee', v_infr);
  END IF;
  IF p_fait IS NOT NULL AND jsonb_typeof(p_fait) = 'object' THEN
    IF nullif(p_fait ->> 'victime', '') IS NOT NULL THEN v_data := v_data || jsonb_build_object('victime', p_fait ->> 'victime'); END IF;
    IF p_fait ? 'jourFait' AND p_fait ->> 'jourFait' IS NOT NULL THEN v_data := v_data || jsonb_build_object('jourFait', (p_fait ->> 'jourFait')::integer); END IF;
    IF nullif(p_fait ->> 'refType', '') IS NOT NULL THEN v_data := v_data || jsonb_build_object('refType', p_fait ->> 'refType'); END IF;
    IF nullif(p_fait ->> 'refId', '') IS NOT NULL THEN v_data := v_data || jsonb_build_object('refId', p_fait ->> 'refId'); END IF;
  END IF;

  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES (v_id, v_pays, v_ville, v_data::text)
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    SELECT CASE WHEN data IS NULL THEN NULL ELSE data::jsonb END INTO v_data
      FROM public.plaintes_en_cours WHERE id = v_id;
    RETURN jsonb_build_object('ok', true, 'deja_transmise', true, 'affaire', v_data, 'id', v_id);
  END IF;

  PERFORM public.dossier_acte_consigner(v_id, v_pays, v_ville, 'affaire_transmise_police',
    v_nom, 'commissaire', NULL, v_infr,
    jsonb_build_object('cible', v_cible, 'ref_type', p_fait ->> 'refType',
                       'ref_id', p_fait ->> 'refId', 'infraction_constatee', v_infr));
  RETURN jsonb_build_object('ok', true, 'deja_transmise', false, 'affaire', v_data, 'id', v_id);
END;
$function$;

-- arrestation_urgence(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.arrestation_urgence(p_cible text, p_motif text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_poste text; v_poste_city text; v_pays text;
  v_cible_pays text; v_cible_ville text;
  v_ville text; v_res jsonb; v_motifs jsonb; v_pnj record;
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_nom, v_poste, v_poste_city, v_pays
    FROM public.acteur_poste_courant() a;

  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS NULL OR v_poste NOT IN ('president', 'min_int', 'min_just', 'commissaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_cible IS NULL OR btrim(p_cible) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente');
  END IF;
  IF p_cible = v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_est_l_acteur');
  END IF;
  IF p_motif IS NULL OR btrim(p_motif) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_absent');
  END IF;

  SELECT d.country, d.current_city INTO v_cible_pays, v_cible_ville
    FROM public.personnages_donnees d WHERE d.name = p_cible;

  IF v_cible_pays IS NULL THEN
    -- Pas de fiche : l'adaptateur repond, ou la cible reste introuvable.
    SELECT * INTO v_pnj FROM public.detention_cible_pnj(p_cible, v_pays);
    IF v_pnj.systeme IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
    END IF;
    IF NOT v_pnj.arretable THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_arretable',
                                'niveau_connu', v_pnj.niveau_connu, 'niveau_requis', 2);
    END IF;
    v_cible_pays  := v_pnj.pays;
    v_cible_ville := v_pnj.ville;
  END IF;

  IF v_cible_pays IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF v_poste = 'commissaire' THEN
    IF v_poste_city IS NULL OR v_cible_ville IS DISTINCT FROM v_poste_city THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction_ville');
    END IF;
    v_ville := v_poste_city;
  ELSE
    v_ville := coalesce(v_cible_ville, 'capitale');
  END IF;

  v_motifs := jsonb_build_array(jsonb_build_object(
    'type', 'Arrestation d''urgence : ' || p_motif,
    'jour_fait', coalesce((SELECT d.day FROM public.personnages_donnees d WHERE d.name = p_cible),
                          public.jour_de_jeu_pays(v_pays)),
    'city', v_ville, 'jours', 1, 'source', 'arrestation_urgence',
    'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

  v_res := public.detention_ouvrir_interne(
    p_cible, 'Arrestation d''urgence (' || p_motif || ')', 1, v_ville, v_pays,
    v_motifs, v_nom || ' (' || v_poste || ')', 'arrestation_urgence');

  IF (v_res ->> 'ok') IS DISTINCT FROM 'true' THEN
    RETURN v_res;
  END IF;

  PERFORM public.indice_ville_ajuster_interne(v_pays, v_ville, 'isn', 1);
  PERFORM public.indice_ville_ajuster_interne(v_pays, v_ville, 'social', -1);

  RETURN v_res || jsonb_build_object('cible', p_cible, 'ville', v_ville,
                                     'autorite', v_nom, 'poste', v_poste,
                                     'securite', 1, 'social', -1);
END;
$function$;

-- audience_messages_append_only() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.audience_messages_append_only()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RAISE EXCEPTION 'audience_messages est en ajout seul : ni modification ni suppression';
END $function$;

-- audience_peut_ecrire(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.audience_peut_ecrire(p_affaire_id text, p_personne text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.audience_paroles a
                  WHERE a.affaire = p_affaire_id AND a.personne = p_personne
                    AND a.retiree_le IS NULL);
$function$;

-- audience_role_de(text,text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.audience_role_de(p_affaire_id text, p_personne text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_brut text; v_a jsonb; v_ville text; v_pays text; v_j record; v_p record;
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN RETURN NULL; END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom = p_personne THEN RETURN 'juge'; END IF;
  SELECT * INTO v_p FROM public.parquet_moi();
  IF v_p.nom = p_personne AND v_p.pays IS NOT DISTINCT FROM v_pays THEN RETURN 'procureur'; END IF;
  IF coalesce(v_a ->> 'cible', '') = p_personne THEN RETURN 'prevenu'; END IF;
  IF public.defense_avocat_de(p_affaire_id) = p_personne THEN RETURN 'avocat'; END IF;
  IF EXISTS (SELECT 1 FROM public.temoins_citations c
              WHERE c.affaire = p_affaire_id AND c.temoin = p_personne) THEN RETURN 'temoin'; END IF;
  RETURN 'spectateur';
END $function$;

-- audition_consigner_interne(text,text,text,text,text,text,boolean,integer,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.audition_consigner_interne(p_affaire text, p_pays text, p_ville text, p_personne text, p_qualite text, p_declaration text, p_refus boolean, p_jour integer, p_exiger_presence boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_decl text; v_refus boolean; v_id text; v_c record;
BEGIN
  IF p_qualite NOT IN ('prevenu', 'temoin') THEN
    RAISE EXCEPTION 'audition : qualite inconnue (%)', p_qualite;
  END IF;

  v_refus := coalesce(p_refus, false);
  v_decl  := nullif(btrim(coalesce(p_declaration, '')), '');
  -- UNE REPONSE EST EXIGEE, ET LE REFUS EN EST UNE. Ce qui est refuse ici, c'est la reponse VIDE :
  -- ni declaration, ni refus explicite. Le silence n'est pas une reponse procedurale, et ce n'est
  -- pas le serveur qui doit le choisir a la place du joueur.
  IF NOT v_refus AND v_decl IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reponse_absente');
  END IF;
  -- Un refus EXPLICITE efface le texte : on n'enregistre pas deux reponses contradictoires.
  IF v_refus THEN v_decl := NULL; END IF;

  -- LA PRESENCE PHYSIQUE, QUAND L'APPELANT L'EXIGE. Le commissariat de la ville du tribunal
  -- competent, et aucun autre -- une deposition ne se fait pas depuis l'etranger ni de chez soi.
  IF coalesce(p_exiger_presence, false) THEN
    SELECT * INTO v_c FROM public.temoin_commissariat_competent(p_pays, p_ville);
    IF v_c.batiment IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'commissariat_indetermine', 'ville', p_ville);
    END IF;
    IF NOT public.acteur_present_sur_site(p_personne, p_pays, p_ville, v_c.batiment, v_c.piece) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_commissariat_requise',
                                'ville', p_ville, 'site', v_c.batiment, 'piece', v_c.piece);
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM public.dossiers_auditions a
              WHERE a.affaire = p_affaire AND a.personne = p_personne) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audition_deja_realisee');
  END IF;

  v_id := CASE WHEN p_qualite = 'temoin' THEN 'dep-' ELSE 'pv-' END
          || substr(md5(p_affaire || '|' || p_personne), 1, 16);
  INSERT INTO public.dossiers_auditions
    (id, affaire, pays, ville, personne, declaration, refus, jour_pv, qualite)
  VALUES (v_id, p_affaire, p_pays, p_ville, p_personne, v_decl, v_refus, p_jour, p_qualite);

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'qualite', p_qualite,
                            'refus', v_refus, 'declaration', v_decl, 'jour', p_jour);
END $function$;

-- avocat_dossier(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.avocat_dossier(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_g record; v_quals text[];
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF public.defense_avocat_de(p_affaire_id) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_dossier'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_ville); END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
                              'ville', v_ville, 'site', v_g.batiment, 'piece', v_g.piece); END IF;

  -- LES QUALIFICATIONS REELLEMENT RETENUES DANS CE DOSSIER, et elles seules. Une trace qui
  -- porterait sur un acte dont ce dossier ne parle pas n'est une preuve de rien ici.
  v_quals := ARRAY(SELECT DISTINCT x FROM unnest(ARRAY[
      v_a ->> 'infraction_constatee', v_a ->> 'qualification_parquet',
      v_a ->> 'qualification_finale']) AS x WHERE x IS NOT NULL);

  RETURN jsonb_build_object('ok', true,
    'affaire', p_affaire_id, 'ville', v_ville, 'pays', v_pays,
    'prevenu', v_a ->> 'cible',
    'plaignant', coalesce(v_a ->> 'plaignant', v_a ->> 'auteur'),
    'motif', v_a ->> 'motif',
    'categorie_alleguee', v_a ->> 'categorie_alleguee',
    'statut', v_a ->> 'status',
    'jour_depot', v_a ->> 'jour',
    'qualification_constatee', v_a ->> 'infraction_constatee',
    'qualification_parquet', v_a ->> 'qualification_parquet',
    'qualification_finale', v_a ->> 'qualification_finale',
    'delai_jugement_jour', v_a ->> 'delai_jugement_jour',
    'audience_ouverte', public.affaire_audience_ouverte(v_a),
    'audience_jour', v_a ->> 'audience_jour',
    'audition', (SELECT jsonb_build_object(
                   'personne', a.personne, 'refus', a.refus,
                   'declaration', a.declaration, 'jour', a.jour_pv, 'fait_le', a.fait_le,
                   'pv_a_libere_une_detention', (
                      SELECT coalesce((x.donnees ->> 'libere')::boolean, false)
                        FROM public.dossiers_judiciaires_actes x
                       WHERE x.affaire = p_affaire_id AND x.type = 'pv_audition'
                       ORDER BY x.rang DESC LIMIT 1))
                  FROM public.dossiers_auditions a
                 WHERE a.affaire = p_affaire_id AND a.personne = (v_a ->> 'cible')
                   AND a.qualite = 'prevenu'),
    -- LES TEMOINS CITES, QUI LES A CITES, ET OU ILS EN SONT.
    'temoins', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'temoin', c.temoin, 'cite_par', c.cite_par, 'qualite', c.cite_par_qualite,
                  'convocation', c.convocation_rang, 'echeance_jour', c.echeance_jour,
                  'etat', c.etat, 'issue', c.issue) ORDER BY c.rang), '[]'::jsonb)
                 FROM public.temoins_citations c WHERE c.affaire = p_affaire_id),
    -- LEURS DEPOSITIONS, VERBATIM, REFUS COMPRIS. Aucune interpretation, aucune note.
    'temoignages', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                      'personne', a.personne, 'refus', a.refus, 'declaration', a.declaration,
                      'jour', a.jour_pv, 'fait_le', a.fait_le) ORDER BY a.fait_le), '[]'::jsonb)
                     FROM public.dossiers_auditions a
                    WHERE a.affaire = p_affaire_id AND a.qualite = 'temoin'),
    -- LES PREUVES REELLES, ET RIEN QUI LEUR RESSEMBLE. Une trace objective d'`actions_tracables`,
    -- non expiree, liant le prevenu a une qualification retenue dans CE dossier -- la meme notion
    -- que `justice_preuve_reelle`. Aucun texte libre, aucune rumeur, aucune declaration n'entre
    -- ici, et si la base n'en porte aucune le tableau est VIDE.
    'preuves', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'id', t.id, 'acte', t.type_action, 'jour', t.jour, 'ville', t.city,
                  'jour_expiration', t.jour_expiration) ORDER BY t.jour, t.id), '[]'::jsonb)
                 FROM public.actions_tracables t
                WHERE t.country IS NOT DISTINCT FROM v_pays
                  AND t.auteur = (v_a ->> 'cible')
                  AND t.type_action = ANY (v_quals)
                  AND coalesce(t.jour_expiration, 0) >= coalesce(
                        (SELECT d.day FROM public.personnages_donnees d
                          WHERE d.name = (v_a ->> 'cible')), 1)),
    'actes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                 'rang', x.rang, 'type', x.type, 'libelle', t.libelle,
                 'acteur', x.acteur, 'poste', x.acteur_poste,
                 'qualif_avant', x.qualif_avant, 'qualif_apres', x.qualif_apres,
                 'donnees', x.donnees, 'fait_le', x.fait_le) ORDER BY x.rang), '[]'::jsonb)
                FROM public.dossiers_judiciaires_actes x
                JOIN public.dossiers_judiciaires_actes_types t ON t.type = x.type
               WHERE x.affaire = p_affaire_id),
    'greffe', jsonb_build_object('batiment', v_g.batiment, 'piece', v_g.piece));
END $function$;

-- avocat_est_qualifie(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.avocat_est_qualifie(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- L'ARBITRAGE EST RENDU : exercer comme avocat exige la carriere JUSTICE, initiale ou acquise
  -- a l'Universite comme seconde carriere. Il n'y a plus de registre vide, donc plus de porte
  -- fermee faute de decision.
  SELECT public.habilitation_ouverte(p_nom, 'avocat');
$function$;

-- avocat_ma_tarification() -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.avocat_ma_tarification()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('ok', true,
    'qualifie', public.avocat_est_qualifie(public.mon_personnage()),
    'tarification', (SELECT a.tarification FROM public.avocats_barreau a
                      WHERE a.nom = public.mon_personnage()));
$function$;

-- avocat_publier_tarification(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.avocat_publier_tarification(p_tarification text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_t text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.avocat_est_qualifie(v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'qualification_avocat_requise'); END IF;
  v_t := nullif(btrim(coalesce(p_tarification, '')), '');
  IF v_t IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tarification_absente'); END IF;
  IF length(v_t) > 200 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tarification_trop_longue'); END IF;

  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi;
  INSERT INTO public.avocats_barreau (nom, pays, tarification)
  VALUES (v_moi, coalesce(v_pays, 'republic'), v_t)
  ON CONFLICT (nom) DO UPDATE
    SET tarification = EXCLUDED.tarification, pays = EXCLUDED.pays, maj_le = now();
  RETURN jsonb_build_object('ok', true, 'tarification', v_t);
END $function$;

-- avocat_retirer_tarification() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.avocat_retirer_tarification()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  DELETE FROM public.avocats_barreau WHERE nom = v_moi;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'retire', v_n = 1);
END $function$;

-- commissaire_enqueter(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.commissaire_enqueter(p_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_poste_city text; v_pays text;
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_nom, v_poste, v_poste_city, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'commissaire' OR v_poste_city IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_cible IS NULL OR btrim(p_cible) = '' OR p_cible = v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;

  RETURN public.plainte_instruire_interne(v_pays, v_poste_city, p_cible, 'enquete', v_nom);
END;
$function$;

-- defense_avocat_de(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.defense_avocat_de(p_affaire_id text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT d.avocat FROM public.defenses_demandes d
   WHERE d.affaire = p_affaire_id AND d.etat = 'acceptee' LIMIT 1;
$function$;

-- defense_demander(text,text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.defense_demander(p_affaire_id text, p_avocats text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_brut text; v_a jsonb; v_pays text; v_av text;
  v_envoyees text[] := '{}'; v_refusees jsonb := '[]'::jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_avocats IS NULL OR array_length(p_avocats, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_avocat_designe'); END IF;

  SELECT p.data, p.country INTO v_brut, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;
  IF coalesce(v_a ->> 'cible', '') IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire'); END IF;

  -- ON NE CONSTITUE SA DEFENSE QUE QUAND ON EST POURSUIVI. Avant les poursuites il n'y a pas
  -- encore d'accusation a defendre, et le dossier n'existe pas comme tel.
  IF coalesce(v_a ->> 'status', '') NOT IN ('poursuites', 'saisie', 'abandon_demande') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poursuites_non_engagees',
                              'statut', v_a ->> 'status'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;
  IF public.defense_avocat_de(p_affaire_id) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'avocat_deja_retenu',
                              'avocat', public.defense_avocat_de(p_affaire_id)); END IF;

  FOREACH v_av IN ARRAY p_avocats LOOP
    v_av := nullif(btrim(coalesce(v_av, '')), '');
    CONTINUE WHEN v_av IS NULL OR v_av = v_moi;
    -- SOLLICITER, C'EST SOLLICITER UN AVOCAT INSCRIT : qualifie, et ayant publie sa tarification.
    IF NOT EXISTS (SELECT 1 FROM public.avocats_barreau b
                    WHERE b.nom = v_av AND b.pays = v_pays AND public.avocat_est_qualifie(b.nom)) THEN
      v_refusees := v_refusees || jsonb_build_object('avocat', v_av, 'raison', 'avocat_non_inscrit');
      CONTINUE;
    END IF;
    BEGIN
      INSERT INTO public.defenses_demandes (affaire, pays, prevenu, avocat)
      VALUES (p_affaire_id, v_pays, v_moi, v_av);
      v_envoyees := v_envoyees || v_av;
    EXCEPTION WHEN unique_violation THEN
      -- L'INDEX PARTIEL A PARLE : une demande est deja en attente pour ce couple. Ce n'est pas
      -- une erreur, c'est un doublon, et on le dit.
      v_refusees := v_refusees || jsonb_build_object('avocat', v_av, 'raison', 'demande_deja_en_attente');
    END;
  END LOOP;

  RETURN jsonb_build_object('ok', array_length(v_envoyees, 1) IS NOT NULL,
    'raison', CASE WHEN array_length(v_envoyees, 1) IS NULL THEN 'aucune_demande_envoyee' END,
    'affaire', p_affaire_id, 'envoyees', to_jsonb(v_envoyees), 'ecartees', v_refusees);
END $function$;

-- defense_mes_demandes() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.defense_mes_demandes()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  RETURN jsonb_build_object('ok', true, 'avocat', v_moi,
    'qualifie', public.avocat_est_qualifie(v_moi),
    -- AVANT ACCEPTATION, RIEN DU DOSSIER. Le nom du prevenu, la ville et la date : de quoi
    -- decider d'accepter, pas de quoi plaider.
    'demandes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'rang', d.rang, 'affaire', d.affaire, 'prevenu', d.prevenu,
                   'ville', p.city, 'demande_le', d.demande_le) ORDER BY d.rang DESC), '[]'::jsonb)
                  FROM public.defenses_demandes d
                  LEFT JOIN public.plaintes_en_cours p ON p.id = d.affaire
                 WHERE d.avocat = v_moi AND d.etat = 'en_attente'),
    'defenses', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'affaire', d.affaire, 'prevenu', d.prevenu, 'ville', p.city,
                   'site', (SELECT g.batiment FROM public.justice_greffe_competent(p.country, p.city) g),
                   'piece', (SELECT g.piece FROM public.justice_greffe_competent(p.country, p.city) g),
                   'audience_ouverte', public.affaire_audience_ouverte(
                      CASE WHEN left(btrim(coalesce(p.data, '')), 1) = '{'
                           THEN p.data::jsonb ELSE '{}'::jsonb END)
                   ) ORDER BY d.rang DESC), '[]'::jsonb)
                  FROM public.defenses_demandes d
                  JOIN public.plaintes_en_cours p ON p.id = d.affaire
                 WHERE d.avocat = v_moi AND d.etat = 'acceptee'));
END $function$;

-- defense_repondre(bigint,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.defense_repondre(p_rang bigint, p_accepte boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_d record; v_a jsonb; v_n integer; v_caduques integer := 0;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_d FROM public.defenses_demandes WHERE rang = p_rang FOR UPDATE;
  IF v_d.rang IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_absente'); END IF;
  IF v_d.avocat IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_ma_demande'); END IF;
  IF v_d.etat <> 'en_attente' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_close', 'etat', v_d.etat); END IF;

  SELECT p.data::jsonb INTO v_a FROM public.plaintes_en_cours p WHERE p.id = v_d.affaire;
  IF v_a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;

  IF NOT coalesce(p_accepte, false) THEN
    UPDATE public.defenses_demandes SET etat = 'refusee', repondu_le = now()
     WHERE rang = p_rang AND etat = 'en_attente';
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_close'); END IF;
    RETURN jsonb_build_object('ok', true, 'accepte', false, 'affaire', v_d.affaire);
  END IF;

  -- L'ACCEPTATION EST LA COURSE, ET C'EST L'INDEX QUI L'ARBITRE. Deux onglets, deux avocats, la
  -- meme milliseconde : une seule ligne peut porter `acceptee` sur cette affaire.
  BEGIN
    UPDATE public.defenses_demandes SET etat = 'acceptee', repondu_le = now()
     WHERE rang = p_rang AND etat = 'en_attente';
    GET DIAGNOSTICS v_n = ROW_COUNT;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'avocat_deja_retenu',
                              'avocat', public.defense_avocat_de(v_d.affaire));
  END;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_close'); END IF;

  -- TOUTES LES AUTRES DEMANDES DEVIENNENT CADUQUES, et ne pourront plus etre acceptees : leur
  -- etat n'est plus `en_attente`, et la porte garde dessus.
  UPDATE public.defenses_demandes SET etat = 'caduque', repondu_le = now()
   WHERE affaire = v_d.affaire AND etat = 'en_attente';
  GET DIAGNOSTICS v_caduques = ROW_COUNT;

  PERFORM public.dossier_acte_consigner(v_d.affaire, v_d.pays,
    (SELECT p.city FROM public.plaintes_en_cours p WHERE p.id = v_d.affaire),
    'defense_constituee', v_moi, 'avocat', NULL, NULL,
    jsonb_build_object('prevenu', v_d.prevenu, 'avocat', v_moi));

  RETURN jsonb_build_object('ok', true, 'accepte', true, 'affaire', v_d.affaire,
                            'prevenu', v_d.prevenu, 'demandes_caduques', v_caduques);
END $function$;

-- defense_rompre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.defense_rompre(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_d record; v_a jsonb; v_ville text; v_qui text; v_etat text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_d FROM public.defenses_demandes
   WHERE affaire = p_affaire_id AND etat = 'acceptee' FOR UPDATE;
  IF v_d.rang IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_defense_constituee'); END IF;

  SELECT p.data::jsonb, p.city INTO v_a, v_ville FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  -- LE VERROU DE L'AUDIENCE. Une fois ouverte, la defense ne change plus jusqu'au jugement.
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;

  IF v_moi = v_d.prevenu THEN v_qui := 'prevenu'; v_etat := 'revoquee';
  ELSIF v_moi = v_d.avocat THEN v_qui := 'avocat'; v_etat := 'abandonnee';
  ELSE RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee'); END IF;

  UPDATE public.defenses_demandes SET etat = v_etat, repondu_le = now()
   WHERE rang = v_d.rang AND etat = 'acceptee';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'defense_deja_rompue'); END IF;

  -- L'ACCES FUTUR TOMBE IMMEDIATEMENT : `defense_avocat_de` ne le nomme plus, et toutes les
  -- portes de l'avocat passent par elle. CE QU'IL A DEJA LU, IL LE SAIT -- on n'efface pas la
  -- memoire d'un joueur, et on ne tente pas de le faire.
  PERFORM public.dossier_acte_consigner(p_affaire_id, v_d.pays, v_ville,
    'defense_rompue', v_moi, CASE WHEN v_qui = 'avocat' THEN 'avocat' ELSE 'accuse' END, NULL, NULL,
    jsonb_build_object('par', v_qui, 'prevenu', v_d.prevenu, 'avocat', v_d.avocat));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'par', v_qui,
                            'etat', v_etat, 'avocat', v_d.avocat);
END $function$;

-- detention_active(text) -> TABLE(id text, country text, city text, jour_debut integer, jour_fin integer, qhs boolean) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_active(p_nom text)
 RETURNS TABLE(id text, country text, city text, jour_debut integer, jour_fin integer, qhs boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT d.id, d.country, d.city, d.jour_debut, d.jour_fin, coalesce(d.qhs, false)
    FROM public.detentions d
   WHERE d.nom = p_nom
     AND d.mode_fin IS NULL
     AND d.jour_fin_effective IS NULL
   ORDER BY d.created_at DESC
   LIMIT 1;
$function$;

-- detention_cible_pnj(text,text) -> TABLE(systeme text, pays text, ville text, building_id text, room_id text, agent_id text, statut text, niveau_connu integer, arretable boolean) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_cible_pnj(p_nom text, p_pays_autorite text)
 RETURNS TABLE(systeme text, pays text, ville text, building_id text, room_id text, agent_id text, statut text, niveau_connu integer, arretable boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT 'agent_renseignement'::text,
         pe.pays, pe.ville, pe.building_id, pe.room_id,
         ag.id, ag.statut,
         public.contre_espionnage_niveau_connu(p_pays_autorite, ag.nom_couverture),
         (    ag.statut = 'actif'
          AND ag.leader_courant IS NULL
          AND pe.ville IS NOT NULL
          AND pe.pays = p_pays_autorite
          AND public.contre_espionnage_niveau_connu(p_pays_autorite, ag.nom_couverture) >= 2)
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE ag.nom_couverture = p_nom
     AND pe.pays IS NOT DISTINCT FROM p_pays_autorite
     AND c.statut = 'active'
   LIMIT 1;
$function$;

-- detention_clore_evasion() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_clore_evasion()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_det record; v_jour integer; v_peine jsonb;
        v_fin integer; v_reliquat integer; v_motifs jsonb; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT coalesce(day,1), est_emprisonne, country INTO v_jour, v_peine, v_pays
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  -- EVASION REUSSIE N'EST PAS UNE LIBERATION : la peine n'est pas purgee, et `jour_fin` n'est
  -- JAMAIS reecrit. Le reliquat et les motifs d'origine sont rendus, pour l'avis de recherche.
  v_fin := coalesce((v_peine->>'jourFin')::integer, v_jour);
  v_reliquat := greatest(0, v_fin - v_jour);
  IF v_det.id IS NOT NULL THEN
    SELECT coalesce(motifs,'[]'::jsonb), coalesce(country, v_pays) INTO v_motifs, v_pays
      FROM public.detentions WHERE id = v_det.id FOR UPDATE;
  ELSE
    v_motifs := '[]'::jsonb;
  END IF;
  RETURN public.detention_clore_interne(v_moi, 'evasion')
         || jsonb_build_object('ok',true,'reliquat_jours',v_reliquat,'motifs',v_motifs,'country',v_pays);
END; $function$;

-- detention_clore_interne(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_clore_interne(p_nom text, p_mode text, p_jour integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jour integer; v_peine jsonb; v_det record; v_qhs boolean;
BEGIN
  IF coalesce(btrim(p_mode),'') = '' THEN
    RAISE EXCEPTION 'detention_clore_interne : le mode de fin est obligatoire';
  END IF;
  SELECT coalesce(day,1), est_emprisonne INTO v_jour, v_peine
    FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  SELECT * INTO v_det FROM public.detention_active(p_nom);
  -- Le caractere QHS se lit des DEUX cotes : la fiche peut le porter sans la ligne, et l'inverse.
  v_qhs := coalesce((v_peine->>'qhs')::boolean,false) OR coalesce(v_det.qhs,false);
  -- 1. La ligne. `AND mode_fin IS NULL` : une ligne deja close n'est pas reecrite.
  IF v_det.id IS NOT NULL THEN
    UPDATE public.detentions
       SET mode_fin = p_mode, jour_fin_effective = coalesce(p_jour, v_jour),
           date_fin_effective = now()
     WHERE id = v_det.id AND mode_fin IS NULL;
  END IF;
  -- 2. et 3. La fiche, et le drapeau en OBJET -- la forme que pa_repos_nocturne sait lire.
  UPDATE public.personnages_donnees
     SET est_emprisonne = NULL,
         detention_qhs = CASE WHEN v_qhs
           THEN jsonb_build_object('enQHS', false, 'paLimite1Jour', false) ELSE detention_qhs END
   WHERE name = p_nom;
  -- 4. Le registre du QHS, sans quoi le Ministere voit un detenu libre.
  IF v_qhs THEN
    UPDATE public.prisonniers_qhs SET statut='libere'
     WHERE data ->> 'nom' = p_nom AND coalesce(statut,'') = 'detenu';
  END IF;
  RETURN jsonb_build_object('detention_id', v_det.id, 'sortait_du_qhs', v_qhs,
                            'jour', coalesce(p_jour, v_jour),
                            'retour_ville', v_peine ->> 'retourVille');
END; $function$;

-- detention_clore_motif_eteint(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_clore_motif_eteint(p_mode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_peine jsonb; v_r jsonb;
BEGIN
  -- LISTE FERMEE : la porte ne sert que ces deux actes administratifs.
  IF p_mode NOT IN ('poursuites_eteintes','incorporation') THEN
    RAISE EXCEPTION 'detention_clore_motif_eteint : mode inconnu « % »', p_mode;
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  IF coalesce((v_peine->>'motifDesertionSeul')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_pas_seulement_desertion'); END IF;
  v_r := public.detention_clore_interne(v_moi, p_mode);
  RETURN v_r || jsonb_build_object('ok', true, 'mode', p_mode);
END; $function$;

-- detention_clore_purgee() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_clore_purgee()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_det record; v_jour integer; v_peine jsonb; v_fin integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT coalesce(day,1), est_emprisonne INTO v_jour, v_peine
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  -- LE JOUR DE REFERENCE EST CELUI DE LA FICHE, jamais un parametre : sinon la liberation serait
  -- a la main du navigateur. C'est exactement la condition du client (state.day >= jourFin).
  v_fin := coalesce((v_peine ->> 'jourFin')::integer, v_det.jour_fin);
  IF v_fin IS NULL OR v_jour < v_fin THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_non_purgee','jour',v_jour,'jour_fin',v_fin);
  END IF;
  RETURN public.detention_clore_interne(v_moi, 'purgee') || jsonb_build_object('ok', true);
END; $function$;

-- detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_ouvrir_interne(p_nom text, p_raison text, p_jours integer, p_city text, p_country text, p_motifs jsonb, p_autorite text, p_issue text, p_extras jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := 'det-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text),1,6);
  v_jour_cible integer; v_deja jsonb; v_pnj record; v_cellule text;
  v_x jsonb := CASE WHEN jsonb_typeof(p_extras)='object' THEN p_extras ELSE '{}'::jsonb END;
  v_ville_cond text; v_jour_aff integer; v_prec text; v_reliquat integer; v_retour text;
BEGIN
  -- Chacune de ces cinq valeurs vaut NULL quand p_extras l'ignore : un appel a huit arguments
  -- produit donc exactement la ligne qu'il produisait avant ce lot.
  v_ville_cond := coalesce(nullif(v_x->>'ville_condamnation',''), p_city);
  v_jour_aff   := nullif(v_x->>'jour_affaire','')::integer;
  v_prec       := nullif(v_x->>'detention_precedente_id','');
  v_reliquat   := nullif(v_x->>'reliquat_jours','')::integer;
  v_retour     := nullif(v_x->>'retour_ville','');
  SELECT coalesce(d.day,1), d.est_emprisonne INTO v_jour_cible, v_deja
    FROM public.personnages_donnees d WHERE d.name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    SELECT * INTO v_pnj FROM public.detention_cible_pnj(p_nom, p_country);
    IF v_pnj.systeme IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','cible_introuvable'); END IF;
    IF v_pnj.statut = 'detenu' THEN RETURN jsonb_build_object('ok',false,'raison','cible_deja_detenue'); END IF;
    IF NOT v_pnj.arretable THEN
      RETURN jsonb_build_object('ok',false,'raison','cible_non_arretable','niveau_connu',v_pnj.niveau_connu,'niveau_requis',2);
    END IF;
    v_jour_cible := public.jour_de_jeu_pays(p_country);
    INSERT INTO public.detentions (id,country,city,nom,raison,jour_debut,jour_fin,qhs,motifs,
             autorite,issue_judiciaire,ville_condamnation,provenance,jour_affaire,detention_precedente_id,reliquat_jours)
    VALUES (v_id,p_country,p_city,p_nom,p_raison,v_jour_cible,v_jour_cible+p_jours,false,p_motifs,
             p_autorite,p_issue,v_ville_cond,v_pnj.systeme,v_jour_aff,v_prec,v_reliquat);
    UPDATE public.agents_renseignement
       SET statut='detenu', detention_id=v_id, detenu_depuis=now(), leader_courant=NULL, maj_le=now()
     WHERE id = v_pnj.agent_id RETURNING cellule_id INTO v_cellule;
    PERFORM public.cellule_alerter_ministre(v_cellule, p_nom, 'Agent arrete — ' || p_nom,
      'Votre agent operant sous l''identite de couverture « ' || p_nom ||
      ' » a ete arrete par les autorites de ' || p_country || ' a ' || p_city ||
      '. Il ne peut plus collecter ni etre deplace.');
    RETURN jsonb_build_object('ok',true,'detention_id',v_id,'jour_debut',v_jour_cible,
                              'jour_fin',v_jour_cible+p_jours,'provenance',v_pnj.systeme);
  END IF;
  -- LA GARDE DE REJEU : une peine en cours interdit d'en ouvrir une seconde. C'est elle qui rend
  -- un double appel inoffensif, et elle existait avant ce lot.
  IF v_deja IS NOT NULL AND jsonb_typeof(v_deja)='object' THEN
    RETURN jsonb_build_object('ok',false,'raison','cible_deja_detenue');
  END IF;
  INSERT INTO public.detentions (id,country,city,nom,raison,jour_debut,jour_fin,qhs,motifs,
           autorite,issue_judiciaire,ville_condamnation,jour_affaire,detention_precedente_id,reliquat_jours)
  VALUES (v_id,p_country,p_city,p_nom,p_raison,v_jour_cible,v_jour_cible+p_jours,false,p_motifs,
           p_autorite,p_issue,v_ville_cond,v_jour_aff,v_prec,v_reliquat);
  UPDATE public.personnages_donnees
     SET est_emprisonne = jsonb_build_object('jours',p_jours,'jourFin',v_jour_cible+p_jours,
           'raison',p_raison,'detentionId',v_id,'qhs',false,'city',p_city,'country',p_country,
           'debutTs',(extract(epoch from clock_timestamp())*1000)::bigint)
         || CASE WHEN v_retour IS NOT NULL THEN jsonb_build_object('retourVille',v_retour) ELSE '{}'::jsonb END
   WHERE name = p_nom;
  RETURN jsonb_build_object('ok',true,'detention_id',v_id,'jour_debut',v_jour_cible,'jour_fin',v_jour_cible+p_jours);
END; $function$;

-- detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_ouvrir_soi(p_raison text, p_jours integer, p_city text DEFAULT NULL::text, p_motifs jsonb DEFAULT NULL::jsonb, p_qhs boolean DEFAULT false, p_extras jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_jour integer; v_r jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_jours IS NULL OR p_jours < 0 OR p_jours > 3650 THEN
    RETURN jsonb_build_object('ok',false,'raison','duree_invalide'); END IF;
  -- Le pays et le JOUR viennent de la fiche, jamais de l'appelant : jour_fin se calcule donc sur
  -- le compteur que le serveur detient, exactement comme pour une arrestation par un tiers.
  SELECT country, coalesce(nullif(btrim(p_city),''), current_city, 'capitale'), coalesce(day,1)
    INTO v_pays, v_ville, v_jour FROM public.personnages_donnees WHERE name = v_moi;
  v_r := public.detention_ouvrir_interne(v_moi, p_raison, p_jours, v_ville, v_pays,
           CASE WHEN jsonb_typeof(p_motifs)='array' AND jsonb_array_length(p_motifs) > 0 THEN p_motifs
                ELSE jsonb_build_array(jsonb_build_object('type',coalesce(p_raison,'Detention'),
                       'jour_fait',v_jour,'city',v_ville,'jours',p_jours,
                       'source','detention_ouvrir_soi','date_evenement',to_char(now() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))) END,
           nullif(p_extras->>'autorite',''), nullif(p_extras->>'issue_judiciaire',''), p_extras);
  IF NOT coalesce((v_r->>'ok')::boolean,false) THEN RETURN v_r; END IF;
  IF p_qhs THEN
    PERFORM public.detention_qhs_poser_interne(v_moi, v_r->>'detention_id', p_raison);
    RETURN v_r || jsonb_build_object('qhs', true);
  END IF;
  RETURN v_r;
END; $function$;

-- detention_prolonger_interne(text,jsonb,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_prolonger_interne(p_nom text, p_motifs jsonb, p_forcer_qhs boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_peine jsonb; v_det record; v_jours_supp int; v_nouveau int; v_motifs jsonb;
BEGIN
  IF p_motifs IS NULL OR jsonb_typeof(p_motifs) <> 'array' OR jsonb_array_length(p_motifs) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motifs_absents');
  END IF;
  SELECT * INTO v_det FROM public.detention_active(p_nom);
  IF v_det.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_detenue');
  END IF;
  SELECT coalesce(sum((m ->> 'jours')::int), 0) INTO v_jours_supp
    FROM jsonb_array_elements(p_motifs) m;
  v_nouveau := coalesce(v_det.jour_fin, 0) + v_jours_supp;
  -- Les motifs sont relus SOUS VERROU puis concatenes. La branche cliente, elle, les lisait
  -- avec `.catch(() => [])` : un echec de lecture ECRASAIT tous les motifs existants.
  SELECT coalesce(motifs, '[]'::jsonb) INTO v_motifs
    FROM public.detentions WHERE id = v_det.id FOR UPDATE;
  UPDATE public.detentions
     SET motifs = v_motifs || p_motifs, jour_fin = v_nouveau
   WHERE id = v_det.id;
  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees
   WHERE name = p_nom FOR UPDATE;
  IF v_peine IS NOT NULL AND jsonb_typeof(v_peine) = 'object' THEN
    UPDATE public.personnages_donnees
       SET est_emprisonne = v_peine
             || jsonb_build_object('jours', coalesce((v_peine ->> 'jours')::int, 0) + v_jours_supp)
             || jsonb_build_object('jourFin', v_nouveau)
     WHERE name = p_nom;
  END IF;
  IF p_forcer_qhs THEN
    PERFORM public.detention_qhs_poser_interne(p_nom, v_det.id,
              coalesce(p_motifs -> 0 ->> 'type', 'Sentence'));
  END IF;
  RETURN jsonb_build_object('ok', true, 'cible', p_nom, 'detention_id', v_det.id,
                            'jours_ajoutes', v_jours_supp, 'jour_fin', v_nouveau);
END; $function$;

-- detention_prolonger_soi(jsonb,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_prolonger_soi(p_motifs jsonb, p_forcer_qhs boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  RETURN public.detention_prolonger_interne(v_moi, p_motifs, p_forcer_qhs);
END; $function$;

-- detention_qhs_poser_interne(text,text,text) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_qhs_poser_interne(p_nom text, p_detention_id text, p_raison text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_det record; v_peine jsonb; v_photo text;
BEGIN
  SELECT country, city, jour_debut, jour_fin INTO v_det
    FROM public.detentions WHERE id = p_detention_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  UPDATE public.detentions SET qhs = true WHERE id = p_detention_id;
  SELECT est_emprisonne, photo_url INTO v_peine, v_photo
    FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  UPDATE public.personnages_donnees
     SET est_emprisonne = CASE
           WHEN v_peine IS NOT NULL AND jsonb_typeof(v_peine) = 'object'
           THEN v_peine || jsonb_build_object('qhs', true) ELSE v_peine END,
         -- OBJET, jamais une chaine : c'est la forme que pa_repos_nocturne sait lire.
         detention_qhs = jsonb_build_object('enQHS', true, 'paLimite1Jour', false)
   WHERE name = p_nom;
  IF NOT EXISTS (SELECT 1 FROM public.prisonniers_qhs
                  WHERE data ->> 'nom' = p_nom AND coalesce(statut,'') <> 'transfere') THEN
    INSERT INTO public.prisonniers_qhs (id, statut, data)
    VALUES ('qhs-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
              || substr(md5(random()::text),1,6), 'detenu',
            jsonb_build_object('pays', v_det.country, 'nom', p_nom,
                               'raison', coalesce(nullif(btrim(p_raison),''),'Sentence'),
                               'photoUrl', v_photo,
                               'jourDebut', v_det.jour_debut, 'jourFin', v_det.jour_fin));
  END IF;
END; $function$;

-- detention_reduire_peine(boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_reduire_peine(p_requete_acceptee boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_jour integer; v_peine jsonb; v_det record;
        v_fin integer; v_restants integer; v_reduction integer; v_nouveau integer;
        v_jours integer; v_libere boolean; v_r jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT coalesce(day,1), est_emprisonne INTO v_jour, v_peine
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  IF coalesce((v_peine->>'avocatUtilise')::boolean,false) THEN
    RETURN jsonb_build_object('ok',false,'raison','avocat_deja_utilise'); END IF;
  -- L'AVOCAT EST CONSOMME MEME QUAND LE JUGE REFUSE. Regle d'origine, rendue fiable.
  IF NOT coalesce(p_requete_acceptee, false) THEN
    UPDATE public.personnages_donnees
       SET est_emprisonne = v_peine || jsonb_build_object('avocatUtilise', true)
     WHERE name = v_moi;
    RETURN jsonb_build_object('ok',true,'acceptee',false,'reduction',0,'libere',false);
  END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  v_fin := coalesce((v_peine->>'jourFin')::integer, v_det.jour_fin);
  IF v_fin IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','peine_sans_terme'); END IF;
  -- Transcription exacte du calcul du navigateur, aux memes bornes.
  v_restants  := greatest(1, v_fin - v_jour);
  v_reduction := greatest(1, ceil(v_restants / 2.0)::integer);
  v_nouveau   := greatest(v_jour, v_fin - v_reduction);
  v_jours     := greatest(0, v_restants - v_reduction);
  v_libere    := v_jours <= 0 OR v_jour >= v_nouveau;
  -- La reduction ne reecrit JAMAIS motifs[].jours : elle vit a part, dans reduction_jours.
  IF v_det.id IS NOT NULL THEN
    UPDATE public.detentions SET reduction_jours = v_reduction, jour_fin = v_nouveau
     WHERE id = v_det.id AND mode_fin IS NULL;
  END IF;
  IF v_libere THEN
    v_r := public.detention_clore_interne(v_moi, 'anticipee_avocat');
  ELSE
    UPDATE public.personnages_donnees
       SET est_emprisonne = v_peine || jsonb_build_object('jourFin', v_nouveau, 'jours', v_jours,
                                                          'avocatUtilise', true)
     WHERE name = v_moi;
    v_r := jsonb_build_object('detention_id', v_det.id);
  END IF;
  RETURN v_r || jsonb_build_object('ok',true,'acceptee',true,'reduction',v_reduction,
                                   'jour_fin',v_nouveau,'jours',v_jours,'libere',v_libere);
END; $function$;

-- detention_transferer_qhs(text,integer,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_transferer_qhs(p_raison text, p_jours integer, p_city text DEFAULT NULL::text, p_motifs jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_det record; v_jour integer; v_peine jsonb; v_r jsonb; v_prec text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_jours IS NULL OR p_jours <= 0 OR p_jours > 3650 THEN
    RETURN jsonb_build_object('ok',false,'raison','duree_invalide'); END IF;
  SELECT coalesce(day,1), est_emprisonne INTO v_jour, v_peine
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  v_prec := v_det.id;
  -- 1. L'ANCIENNE LIGNE EST CLOSE EXPLICITEMENT. La laisser a NULL la ferait apparaitre comme
  --    encore en cours dans le registre, ce qui est faux : elle est terminee, juste pas par une
  --    liberation. Commentaire d'origine du client, conserve parce qu'il dit le vrai.
  IF v_prec IS NOT NULL THEN
    UPDATE public.detentions
       SET mode_fin='transfert_qhs', jour_fin_effective=v_jour, date_fin_effective=now()
     WHERE id = v_prec;
  END IF;
  -- 2. est_emprisonne est vide AVANT la reouverture : la primitive refuse une cible deja detenue.
  UPDATE public.personnages_donnees SET est_emprisonne = NULL WHERE name = v_moi;
  -- 3. La nouvelle peine passe par la primitive canonique, qui la chaine a la precedente.
  v_r := public.detention_ouvrir_interne(v_moi, p_raison, p_jours,
           coalesce(nullif(btrim(p_city),''), v_det.city, 'qhs'),
           coalesce(v_det.country, (SELECT country FROM public.personnages_donnees WHERE name=v_moi)),
           CASE WHEN jsonb_typeof(p_motifs)='array' AND jsonb_array_length(p_motifs) > 0 THEN p_motifs
                ELSE jsonb_build_array(jsonb_build_object('type',coalesce(p_raison,'Transfert QHS'),
                       'jour_fait',v_jour,'jours',p_jours,'source','detention_transferer_qhs')) END,
           NULL, NULL,
           jsonb_build_object('detention_precedente_id', v_prec,
                              'retour_ville', v_peine ->> 'retourVille'));
  -- 4. SI LA REOUVERTURE ECHOUE, RIEN NE RESTE : on LEVE, et la transaction de la RPC emporte la
  --    cloture de l'etape 1. Rendre un verdict ici laisserait un detenu sans peine en cours.
  IF NOT coalesce((v_r->>'ok')::boolean,false) THEN
    RAISE EXCEPTION 'detention_transferer_qhs : reouverture impossible (%)', v_r ->> 'raison';
  END IF;
  PERFORM public.detention_qhs_poser_interne(v_moi, v_r ->> 'detention_id', p_raison);
  RETURN v_r || jsonb_build_object('qhs', true, 'detention_precedente', v_prec);
END; $function$;

-- detentions_pnj_liberer_echues() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detentions_pnj_liberer_echues()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_n integer := 0;
BEGIN
  FOR r IN
    SELECT d.id, d.country, a.id AS agent_id
      FROM public.detentions d
      JOIN public.agents_renseignement a ON a.detention_id = d.id
     WHERE d.provenance = 'agent_renseignement'
       AND d.mode_fin IS NULL
       AND d.jour_fin_effective IS NULL
       AND a.statut = 'detenu'
       AND a.detenu_depuis IS NOT NULL
       AND now() >= a.detenu_depuis + ((d.jour_fin - d.jour_debut) * interval '1 day')
  LOOP
    UPDATE public.detentions
       SET mode_fin = 'purgee', jour_fin_effective = public.jour_de_jeu_pays(r.country),
           date_fin_effective = now()
     WHERE id = r.id;
    UPDATE public.agents_renseignement
       SET statut = 'actif', detention_id = NULL, detenu_depuis = NULL, maj_le = now()
     WHERE id = r.agent_id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'liberations', v_n);
END;
$function$;

-- dossier_acte_consigner(text,text,text,text,text,text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.dossier_acte_consigner(p_affaire text, p_pays text, p_ville text, p_type text, p_acteur text DEFAULT NULL::text, p_acteur_poste text DEFAULT NULL::text, p_qualif_avant text DEFAULT NULL::text, p_qualif_apres text DEFAULT NULL::text, p_donnees jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_rang integer; v_id text;
BEGIN
  -- ELLE LEVE, ELLE NE REFUSE PAS. Tous ses appelants sont internes et l'invoquent par PERFORM,
  -- qui jette la valeur rendue : un refus propre serait un trou silencieux dans la chronologie.
  -- En levant, elle annule la transaction entiere -- l'acte judiciaire ET sa trace, ou ni l'un ni
  -- l'autre.
  IF NOT EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes_types t WHERE t.type = p_type) THEN
    RAISE EXCEPTION 'chronologie judiciaire : type d''acte inconnu (%)', p_type;
  END IF;
  IF coalesce(btrim(coalesce(p_affaire, '')), '') = '' THEN
    RAISE EXCEPTION 'chronologie judiciaire : acte sans affaire';
  END IF;
  IF coalesce(btrim(coalesce(p_pays, '')), '') = '' THEN
    RAISE EXCEPTION 'chronologie judiciaire : acte sans pays (affaire %)', p_affaire;
  END IF;

  -- LE RANG EST CALCULE PAR LE SERVEUR. La contrainte UNIQUE (affaire, rang) fait le reste :
  -- deux actes simultanes sur la meme affaire ne peuvent pas partager un rang.
  SELECT coalesce(max(a.rang), 0) + 1 INTO v_rang
    FROM public.dossiers_judiciaires_actes a WHERE a.affaire = p_affaire;
  v_id := 'acte-' || p_affaire || '-' || v_rang;
  INSERT INTO public.dossiers_judiciaires_actes
    (id, affaire, pays, ville, rang, type, acteur, acteur_poste,
     qualif_avant, qualif_apres, donnees)
  VALUES (v_id, p_affaire, p_pays, p_ville, v_rang, p_type, p_acteur, p_acteur_poste,
          p_qualif_avant, p_qualif_apres, p_donnees);
  RETURN jsonb_build_object('ok', true, 'acte', v_id, 'rang', v_rang);
END;
$function$;

-- dossiers_actes_append_only() -> trigger | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.dossiers_actes_append_only()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RAISE EXCEPTION 'dossiers_judiciaires_actes est append-only : % refuse', TG_OP;
END;
$function$;

-- dossiers_actes_publier_au_journal() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.dossiers_actes_publier_au_journal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_f record; v_prevenu text; v_libelle text; v_data jsonb;
BEGIN
  SELECT * INTO v_f FROM public.justice_faits_publics WHERE type_acte = NEW.type;
  IF NOT FOUND THEN RETURN NEW; END IF;

  SELECT (p.data::jsonb) ->> 'cible' INTO v_prevenu
    FROM public.plaintes_en_cours p WHERE p.id = NEW.affaire;
  IF v_prevenu IS NULL THEN RETURN NEW; END IF;

  v_libelle := format(v_f.phrase, v_prevenu);

  IF NEW.type = 'audience_ouverte'
     AND coalesce((NEW.donnees ->> 'procureur_present')::boolean, true) IS FALSE THEN
    v_libelle := v_libelle || ', en l''absence du Procureur';
  END IF;

  v_data := jsonb_build_object(
    'affaire', NEW.affaire, 'acte', NEW.type,
    'categorie', (SELECT public.affaire_categorie_publique(p.data::jsonb)
                    FROM public.plaintes_en_cours p WHERE p.id = NEW.affaire));
  IF NEW.type = 'audience_ouverte' THEN
    v_data := v_data || jsonb_build_object(
      'procureur_present', coalesce((NEW.donnees ->> 'procureur_present')::boolean, true),
      'prevenu_present', coalesce((NEW.donnees ->> 'prevenu_present')::boolean, true));
  END IF;

  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref, created_at)
  VALUES ('chronique-' || v_f.chronique_type || '-' || NEW.rang::text,
          NEW.pays, v_f.chronique_type, NEW.ville,
          jsonb_build_array(v_prevenu), v_libelle, v_data, NEW.affaire, now())
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END $function$;

-- dossiers_auditions_append_only() -> trigger | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.dossiers_auditions_append_only()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RAISE EXCEPTION 'dossiers_auditions est append-only : un proces-verbal ne se reecrit pas (% refuse)', TG_OP;
END;
$function$;

-- enquete_garde_a_vue(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.enquete_garde_a_vue(p_cible text, p_motif text, p_ville text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acteur text; v_enquetes jsonb; v_jour integer; v_pays text; v_ok boolean := false;
  v_e jsonb; v_res jsonb; v_jours integer := 2;
BEGIN
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT enquetes_en_cours, coalesce(day, 1), country
    INTO v_enquetes, v_jour, v_pays
    FROM public.personnages_donnees WHERE name = v_acteur;

  -- L'enquete doit exister SUR LA FICHE DE L'APPELANT, viser cette cible, et etre arrivee a terme.
  FOR v_e IN SELECT e FROM jsonb_array_elements(coalesce(v_enquetes, '[]'::jsonb)) e LOOP
    IF v_e->>'cible' = p_cible AND coalesce((v_e->>'day')::int, 999999) <= v_jour THEN
      v_ok := true;
      EXIT;
    END IF;
  END LOOP;
  IF NOT v_ok THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_enquete_arrivee_a_terme');
  END IF;

  v_res := public.detention_ouvrir_interne(
             p_cible,
             coalesce(nullif(p_motif, ''), 'Garde a vue suite a enquete'),
             v_jours,
             coalesce(nullif(p_ville, ''), 'capitale'),
             coalesce(v_e->>'country', v_pays, 'republic'),
             jsonb_build_array(jsonb_build_object(
               'type', coalesce(nullif(p_motif, ''), 'Garde a vue suite a enquete'),
               'jour_fait', coalesce((v_e->>'day')::int, v_jour),
               'city', coalesce(nullif(p_ville, ''), 'capitale'),
               'jours', v_jours,
               'source', 'garde_a_vue',
               'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
             v_acteur,
             'garde_a_vue');
  RETURN v_res;
END; $function$;

-- fraude_electorale_sanctionner(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fraude_electorale_sanctionner(p_fraude_id text, p_ville text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_contestataire text; v_f record; v_res jsonb; v_arg_contest numeric;
  v_amende integer := 500; v_recompense integer := 200; v_jours integer := 2;
  v_raison text; v_ville text;
BEGIN
  v_contestataire := public.mon_personnage();
  IF v_contestataire IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- 1. LA FRAUDE, dans la table canonique, verrouillee avant tout effet.
  SELECT * INTO v_f FROM public.fraudes_electorales WHERE id = p_fraude_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fraude_introuvable');
  END IF;
  IF coalesce(v_f.etat, '') = 'revelee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fraude_deja_revelee');
  END IF;
  IF coalesce(v_f.auteur, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'auteur_inconnu');
  END IF;

  -- 2. LA REVELATION EST LE VERROU : rejeu et concurrence butent ici.
  UPDATE public.fraudes_electorales
     SET etat = 'revelee', revelee_par = v_contestataire, revelee_le = now()
   WHERE id = p_fraude_id;

  v_ville := coalesce(nullif(p_ville, ''), v_f.city, 'capitale');
  v_raison := 'Fraude électorale (' || replace(coalesce(v_f.type, 'fraude'), '_', ' ')
              || ') révélée par contestation';

  -- 3. L'AMENDE. Le montant vient d'ici, jamais de l'appelant.
  UPDATE public.personnages_donnees
     SET arg = greatest(0, coalesce(arg, 0) - v_amende)
   WHERE name = v_f.auteur;

  -- 4. LA DETENTION, par la primitive canonique -- 2 jours, la peine de ce chemin.
  v_res := public.detention_ouvrir_interne(
             v_f.auteur, v_raison, v_jours, v_ville, v_f.country,
             jsonb_build_array(jsonb_build_object(
               'type', v_raison, 'jours', v_jours, 'city', v_ville,
               'source', 'fraude_revelee_contestation',
               'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
             v_contestataire, 'fraude_revelee');

  -- 5. LA RECOMPENSE du contestataire, dans la meme transaction.
  UPDATE public.personnages_donnees
     SET arg = coalesce(arg, 0) + v_recompense
   WHERE name = v_contestataire
   RETURNING arg INTO v_arg_contest;

  RETURN jsonb_build_object(
    'ok', true, 'fraudeur', v_f.auteur, 'type', v_f.type, 'amende', v_amende,
    'jours', v_jours, 'recompense', v_recompense, 'arg_contestataire', v_arg_contest,
    'detention_id', v_res->>'detention_id',
    'detention_ouverte', coalesce((v_res->>'ok')::boolean, false),
    'detention_raison', v_res->>'raison');
END; $function$;

-- geoles_detenus(text,text) -> TABLE(nom text, photo_url text, qhs boolean) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.geoles_detenus(p_pays text, p_ville text)
 RETURNS TABLE(nom text, photo_url text, qhs boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_bat text; v_salle text;
BEGIN
  IF public.est_appel_serveur() THEN
    RETURN QUERY
      SELECT d.nom, (SELECT p.photo_url FROM public.personnages_donnees p WHERE p.name = d.nom),
             coalesce(d.qhs, false)
        FROM public.detentions d
       WHERE d.country = p_pays AND d.city = p_ville
         AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL
       ORDER BY d.created_at DESC;
    RETURN;
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN; END IF;

  SELECT country, current_city, current_building, current_room
    INTO v_pays, v_ville, v_bat, v_salle
    FROM public.personnages_donnees WHERE name = v_moi;

  IF v_pays IS DISTINCT FROM p_pays OR v_ville IS DISTINCT FROM p_ville
     OR NOT ( (v_bat = 'commissariat'       AND v_salle = 'prison')
           OR (v_bat = 'commissariat-local' AND v_salle = 'geoles') ) THEN
    RETURN;
  END IF;

  RETURN QUERY
    SELECT d.nom, (SELECT p.photo_url FROM public.personnages_donnees p WHERE p.name = d.nom),
           -- SECRET DU QHS : jamais revele a un joueur, quel que soit l'endroit ou il se tient.
           false
      FROM public.detentions d
     WHERE d.country = p_pays AND d.city = p_ville
       AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL
     ORDER BY d.created_at DESC;
END;
$function$;

-- impact_deposer(text,text,text,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.impact_deposer(p_id text, p_victime text, p_indice text, p_delta integer, p_palier text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; a record; c record; v_delta integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(coalesce(p_id,'')),'') = '' OR length(p_id) > 120 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_invalide');
  END IF;

  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  SELECT name, country, current_city, current_building, current_room INTO c
    FROM public.personnages_donnees WHERE name = btrim(coalesce(p_victime,''));
  IF c.name IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'victime_introuvable'); END IF;
  IF c.name = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'auto_impact_refuse'); END IF;

  IF p_indice = 'hp_set' THEN
    -- LA CO-PRESENCE EST LA GARDE ESSENTIELLE. Elle ne remplace pas un jet serveur, mais elle
    -- supprime a elle seule l'attaque a distance sur une victime quelconque, qui etait le vrai
    -- danger : frapper sans etre la, sans arme et sans PA.
    IF a.country IS DISTINCT FROM c.country
       OR a.current_city IS DISTINCT FROM c.current_city
       OR a.current_building IS DISTINCT FROM c.current_building
       OR a.current_room IS DISTINCT FROM c.current_room THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
    END IF;
    v_delta := greatest(0, least(100, coalesce(p_delta, 0)));

  ELSIF p_indice = 'moral_carte_postale' THEN
    -- Une carte postale est distante par nature : aucune co-presence exigee. Le montant n'est pas
    -- negociable et le plafond quotidien reste pose cote lecteur, la ou il l'a toujours ete.
    v_delta := 10;

  ELSIF p_indice = 'poison_start' THEN
    -- REFUS EXPLICITE, ET C'EST UN CONSTAT, PAS UNE DECISION. Le producteur envoie `poisonType` et
    -- `statsTouchees`, DEUX COLONNES QUI N'EXISTENT PAS dans cette table, et omet `delta` qui est
    -- NOT NULL sans defaut. Cet INSERT a donc toujours ete rejete par PostgREST, silencieusement
    -- (sbInsert journalise et rend null, l'appelant avale le null) : l'empoisonnement n'a jamais
    -- atteint sa victime. On refuse desormais VISIBLEMENT au lieu d'echouer en silence. Reparer
    -- l'empoisonnement est un lot a part : il demande un schema, pas un correctif de canal.
    RETURN jsonb_build_object('ok', false, 'raison', 'schema_incomplet',
      'detail', 'poison_start exige des colonnes absentes de la table');

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'indice_non_autorise', 'indice', p_indice);
  END IF;

  -- Idempotence : un retry apres un accuse de reception perdu ne cree pas de seconde ligne.
  INSERT INTO public.impacts_indices_attente (id, victime, indice, delta, palier, traite)
  VALUES (p_id, c.name, p_indice, v_delta, nullif(btrim(coalesce(p_palier,'')),''), false)
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'id', p_id, 'victime', c.name,
    'indice', p_indice, 'delta', v_delta);
END;
$function$;

-- impact_marquer_traite(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.impact_marquer_traite(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  UPDATE public.impacts_indices_attente SET traite = true
   WHERE id = p_id AND victime = v_moi AND traite IS NOT TRUE;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'marques', v_n);
END;
$function$;

-- infraction_canonique(text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.infraction_canonique(p_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text; v_canon text;
BEGIN
  v_id := nullif(btrim(coalesce(p_id, '')), '');
  IF v_id IS NULL THEN RETURN NULL; END IF;
  SELECT a.canonique INTO v_canon FROM public.infractions_alias a WHERE a.alias = v_id;
  IF v_canon IS NOT NULL THEN v_id := v_canon; END IF;
  IF EXISTS (SELECT 1 FROM public.infractions i WHERE i.id = v_id) THEN RETURN v_id; END IF;
  RETURN NULL;
END;
$function$;

-- infraction_peine_bornes(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.infraction_peine_bornes(p_infraction text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text; v_i record; v_jmin integer; v_jmax integer; v_amin integer; v_amax integer;
BEGIN
  v_id := public.infraction_canonique(p_infraction);
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_inconnue',
                              'demande', p_infraction);
  END IF;
  SELECT * INTO v_i FROM public.infractions WHERE id = v_id;

  -- round() de PostgreSQL arrondit au plus proche, les demis vers le haut : round(0.5) = 1 et
  -- round(1.5) = 2. C'est la meme convention que Math.round cote navigateur.
  v_jmin := greatest(1, round(v_i.jours_reference * 0.5)::integer);
  v_jmax := round(v_i.jours_reference * 1.5)::integer;
  v_amin := greatest(0, round(v_i.amende_reference * 0.5)::integer);
  v_amax := round(v_i.amende_reference * 1.5)::integer;

  RETURN jsonb_build_object('ok', true,
    'infraction', v_i.id, 'libelle', v_i.libelle, 'categorie', v_i.categorie,
    'bareme_propre', v_i.bareme_propre, 'detectable', v_i.detectable,
    'jours_reference', v_i.jours_reference, 'jours_min', v_jmin, 'jours_max', v_jmax,
    'amende_reference', v_i.amende_reference, 'amende_min', v_amin, 'amende_max', v_amax,
    -- VRAI quand la borne basse EGALE la reference : l'attenuation est alors inexprimable, le
    -- juge ne peut qu'aggraver. Les huit infractions a 1 jour sont dans ce cas.
    'plancher_technique', (v_jmin >= v_i.jours_reference));
END;
$function$;

-- infractions_empreinte_reelle() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.infractions_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(
      id || '|' || libelle || '|' || coalesce(categorie, '')
         || '|' || jours_reference::text || '|' || amende_reference::text
         || '|' || coalesce(detect_rate::text, '')
         || '|' || CASE WHEN bareme_propre THEN '1' ELSE '0' END,
      E'\n' ORDER BY id COLLATE "C")), 16)
  FROM public.infractions;
$function$;

-- juge_de_la_ville(text) -> TABLE(nom text, pays text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.juge_de_la_ville(p_ville text)
 RETURNS TABLE(nom text, pays text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT j.nom, j.pays FROM public.juge_moi() j
   WHERE j.ville IS NOT DISTINCT FROM coalesce(p_ville, 'capitale');
$function$;

-- juge_dossiers() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.juge_dossiers()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record;
BEGIN
  SELECT * INTO v_j FROM public.juge_moi();
  IF v_j.nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge'); END IF;

  RETURN jsonb_build_object('ok', true, 'juge', v_j.nom, 'ville', coalesce(v_j.ville, 'capitale'),
    'dossiers', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'ville', p.city, 'dossier', p.data::jsonb,
        'actes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                     'rang', a.rang, 'type', a.type, 'libelle', t.libelle,
                     'acteur', a.acteur, 'poste', a.acteur_poste,
                     'qualif_avant', a.qualif_avant, 'qualif_apres', a.qualif_apres,
                     'donnees', a.donnees, 'fait_le', a.fait_le) ORDER BY a.rang), '[]'::jsonb)
                    FROM public.dossiers_judiciaires_actes a
                    JOIN public.dossiers_judiciaires_actes_types t ON t.type = a.type
                   WHERE a.affaire = p.id)
      ) ORDER BY p.created_at), '[]'::jsonb)
      FROM public.plaintes_en_cours p
     WHERE p.country = v_j.pays AND p.city IS NOT DISTINCT FROM coalesce(v_j.ville, 'capitale')
       AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
       AND (p.data::jsonb ->> 'status') IN ('saisie', 'abandon_demande', 'appel')));
END $function$;

-- juge_moi() -> TABLE(nom text, pays text, ville text) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.juge_moi()
 RETURNS TABLE(nom text, pays text, ville text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inc text; v_pays text; v_ville text; v_pnj text;
BEGIN
  RETURN QUERY
    SELECT d.name, d.country, coalesce(d.poste ->> 'city', 'capitale')
      FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'juge'
     LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  v_inc := public.incarnation_courante();
  IF v_inc IS NULL THEN RETURN; END IF;
  v_pays  := public.incarnation_pays();
  v_ville := public.incarnation_siege();
  IF v_pays IS NULL OR v_ville IS NULL THEN RETURN; END IF;
  v_pnj := public.admin_pnj_titulaire(v_pays, 'juge', v_ville);
  IF v_pnj IS NULL OR v_pnj IS DISTINCT FROM v_inc THEN RETURN; END IF;
  RETURN QUERY SELECT v_pnj, v_pays, v_ville;
END $function$;

-- juge_suite_apres_abandon(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.juge_suite_apres_abandon(p_affaire_id text, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text;
        v_statut text; v_type text; v_n integer;
BEGIN
  IF p_decision NOT IN ('arret', 'poursuivre') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide', 'decision', p_decision);
  END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville);
  END IF;
  IF coalesce(v_a ->> 'status', '') <> 'abandon_demande' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible',
                              'statut', v_a ->> 'status');
  END IF;
  -- LE DELAI EST OPPOSABLE ICI AUSSI. Maintenir des poursuites sur un dossier eteint le
  -- ressusciterait ; le juge peut encore accepter l'arret, mais plus relancer la procedure.
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer);
  END IF;

  v_statut := CASE WHEN p_decision = 'arret' THEN 'arret' ELSE 'saisie' END;
  v_type := CASE WHEN p_decision = 'arret' THEN 'juge_arret_accepte'
                 ELSE 'juge_poursuite_maintenue' END;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', v_statut,
           'suite_abandon_par', v_j.nom,
           'suite_abandon_decision', p_decision,
           'suite_abandon_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'abandon_demande';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, v_type, v_j.nom, 'juge');
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id,
                            'decision', p_decision, 'statut', v_statut);
END;
$function$;

-- justice_affaires_publiques() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_affaires_publiques()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_g record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT d.country, coalesce(d.current_city, 'capitale') INTO v_pays, v_ville
    FROM public.personnages_donnees d WHERE d.name = v_moi;

  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_ville); END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
      'ville', v_ville, 'site', v_g.batiment, 'piece', v_g.piece); END IF;

  RETURN jsonb_build_object('ok', true, 'ville', v_ville, 'pays', v_pays,
    'affaires', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'affaire', p.id,
        'prevenu', (p.data::jsonb) ->> 'cible',
        'categorie', public.affaire_categorie_publique(p.data::jsonb),
        'statut', (p.data::jsonb) ->> 'status',
        'audience_jour', (p.data::jsonb) ->> 'audience_jour',
        'temoins', (SELECT coalesce(jsonb_agg(c.temoin ORDER BY c.rang), '[]'::jsonb)
                      FROM public.temoins_citations c WHERE c.affaire = p.id)
      ) ORDER BY p.id), '[]'::jsonb)
      FROM public.plaintes_en_cours p
     WHERE p.country = v_pays AND p.city = v_ville
       AND left(btrim(p.data), 1) = '{'
       AND (p.data::jsonb) ->> 'status' IN
           ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande')),
    'greffe', jsonb_build_object('batiment', v_g.batiment, 'piece', v_g.piece));
END $function$;

-- justice_affaires_vivantes_avec_pv(text) -> TABLE(affaire text, pays text, infraction text, echeance integer) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_affaires_vivantes_avec_pv(p_nom text)
 RETURNS TABLE(affaire text, pays text, infraction text, echeance integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p.id, p.country,
         public.affaire_infraction_de(p.data::jsonb),
         ((p.data::jsonb) ->> 'delai_jugement_jour')::integer
    FROM public.plaintes_en_cours p
    JOIN public.dossiers_auditions a ON a.affaire = p.id AND a.personne = p_nom
   WHERE p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
     AND ((p.data::jsonb) ->> 'cible') = p_nom
     AND ((p.data::jsonb) ->> 'status') IN
         ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande')
     AND NOT public.affaire_delai_expire(p.data::jsonb, p.country);
$function$;

-- justice_appel_juger(text,text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_appel_juger(p_affaire_id text, p_verdict text, p_infraction text DEFAULT NULL::text, p_genre text DEFAULT NULL::text, p_jours integer DEFAULT 0, p_amende integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer;
  v_calc jsonb; v_jours integer; v_amende integer; v_libelle text; v_peine text;
  v_inf text; v_jug text; v_n integer; v_motifs jsonb;
  v_det record; v_det_id text; v_purges integer; v_indus integer; v_ind jsonb;
  v_libere boolean := false;
BEGIN
  IF p_verdict NOT IN ('condamnation', 'relaxe') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'verdict_invalide', 'verdict', p_verdict); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville); END IF;
  IF coalesce(v_a ->> 'status', '') <> 'appel' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_appel', 'statut', v_a ->> 'status'); END IF;

  v_inf := public.infraction_canonique(
             coalesce(p_infraction, v_a ->> 'qualification_finale', v_a ->> 'qualification_parquet'));
  IF v_inf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_inconnue',
      'demande', coalesce(p_infraction, v_a ->> 'qualification_finale')); END IF;

  v_jours := 0; v_amende := 0;
  IF p_verdict = 'condamnation' THEN
    IF coalesce(btrim(coalesce(p_genre, '')), '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'genre_absent'); END IF;
    v_calc := public.justice_peine_calcul(v_inf, p_genre, v_a ->> 'cible', v_pays);
    IF coalesce((v_calc ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_calc; END IF;
    v_jours  := coalesce(p_jours, 0);
    v_amende := coalesce(p_amende, 0);
    IF v_jours < (v_calc ->> 'jours_min')::integer
       OR v_jours > (v_calc ->> 'jours_max')::integer THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'peine_hors_bornes',
        'demande_jours', v_jours, 'jours_min', (v_calc ->> 'jours_min')::integer,
        'jours_max', (v_calc ->> 'jours_max')::integer); END IF;
    IF v_amende < (v_calc ->> 'amende_min')::integer
       OR v_amende > (v_calc ->> 'amende_max')::integer THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'amende_hors_bornes',
        'demande_amende', v_amende, 'amende_min', (v_calc ->> 'amende_min')::integer,
        'amende_max', (v_calc ->> 'amende_max')::integer); END IF;
    v_libelle := v_calc ->> 'libelle';
    v_peine := CASE p_genre
      WHEN 'prison'      THEN 'Prison ' || v_jours || ' jour' || CASE WHEN v_jours > 1 THEN 's' ELSE '' END
      WHEN 'amende'      THEN 'Amende de ' || v_amende || ' FR'
      WHEN 'amenagement' THEN 'Amenagement : pointage quotidien au commissariat'
      WHEN 'qhs'         THEN 'Envoi au QHS (' || v_jours || ' jours)'
      ELSE                    'Prison ' || v_jours || ' jours + popularite a zero'
    END;
  ELSE
    SELECT i.libelle INTO v_libelle FROM public.infractions i WHERE i.id = v_inf;
    v_peine := NULL;
  END IF;

  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_j.nom;
  v_jour := coalesce(v_jour, 1);
  v_motifs := CASE WHEN v_jours > 0 THEN jsonb_build_array(jsonb_build_object(
      'type', v_libelle, 'infraction', v_inf, 'jours', v_jours, 'city', v_ville,
      'source', 'jugement_appel',
      'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')))
    ELSE '[]'::jsonb END;

  v_jug := 'jug-app-' || p_affaire_id;
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_jug, v_pays, coalesce(v_ville, 'capitale'), v_a ->> 'cible', v_libelle, v_peine,
          v_j.nom, v_jour, true,
          jsonb_build_object('verdict', p_verdict, 'instance', 'appel', 'definitif', true,
            'infraction', v_inf, 'infraction_libelle', v_libelle, 'genre', p_genre,
            'jours', v_jours, 'amende', v_amende,
            'jugement_premiere_instance', 'jug-' || p_affaire_id,
            'peine_premiere_instance', v_a ->> 'peine_libelle',
            'motif_allegue', v_a ->> 'motif',
            'qualification_parquet', v_a ->> 'qualification_parquet',
            'qualification_premiere_instance', v_a ->> 'qualification_finale',
            'motifs', v_motifs))
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_deja_juge'); END IF;

  -- LES JOURS PURGES SE COMPTENT SUR L'HORLOGE DU DETENU (voir justice_jours_purges).
  v_det_id := nullif(v_a ->> 'detention_id', '');
  SELECT * INTO v_det FROM public.detention_active(v_a ->> 'cible');
  IF v_det.id IS NOT NULL AND (v_det_id IS NULL OR v_det.id = v_det_id) THEN
    v_det_id := v_det.id;
    v_purges := public.justice_jours_purges(v_det_id);
    IF v_purges >= v_jours THEN
      PERFORM public.detention_clore_interne(v_a ->> 'cible', 'jugement_appel', NULL);
      v_libere := true;
    ELSE
      UPDATE public.detentions SET jour_fin = jour_debut + v_jours WHERE id = v_det_id;
    END IF;
  ELSIF v_det_id IS NOT NULL THEN
    v_purges := public.justice_jours_purges(v_det_id);
  ELSE
    v_purges := 0;
  END IF;

  v_indus := greatest(0, coalesce(v_purges, 0) - v_jours);
  IF v_indus > 0 THEN
    v_ind := public.justice_indemnite_naitre(v_pays, v_a ->> 'cible', p_affaire_id, v_jug, v_indus);
    PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'indemnisation',
      NULL, NULL, NULL, NULL,
      jsonb_build_object('jours_indus', v_indus, 'jours_purges', v_purges,
                         'peine_definitive_jours', v_jours,
                         'montant', v_indus * public.justice_indemnite_par_jour(),
                         'creance', v_ind ->> 'id', 'porteur', v_ind ->> 'porteur'));
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'jugee_appel',
           'verdict', p_verdict,
           'juge_appel', v_j.nom,
           'juge_appel_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'qualification_finale', v_inf,
           'qualification_libelle', v_libelle,
           'peine_genre', p_genre,
           'peine_jours', v_jours,
           'peine_amende', v_amende,
           'peine_libelle', v_peine,
           'jours_purges', coalesce(v_purges, 0),
           'jours_indus', v_indus,
           'definitif', true))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'appel';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'jugement_appel',
    v_j.nom, 'juge', v_a ->> 'qualification_finale', v_inf,
    jsonb_build_object('verdict', p_verdict, 'genre', p_genre, 'jours', v_jours,
                       'amende', v_amende, 'jours_purges', coalesce(v_purges, 0),
                       'jours_indus', v_indus, 'libere', v_libere, 'definitif', true));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'jugement_id', v_jug,
    'verdict', p_verdict, 'definitif', true, 'juge', v_j.nom, 'infraction', v_inf,
    'genre', p_genre, 'jours', v_jours, 'amende', v_amende,
    'jours_purges', coalesce(v_purges, 0), 'jours_indus', v_indus,
    'libere', v_libere, 'indemnite', v_ind);
END;
$function$;

-- justice_appel_ouvrir(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_appel_ouvrir(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_p record; v_brut text; v_a jsonb; v_ville text; v_pays text;
  v_jour integer; v_limite integer; v_qui text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  IF coalesce((v_a ->> 'procedure_simplifiee')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_exclu_procedure_simplifiee'); END IF;
  IF coalesce(v_a ->> 'status', '') NOT IN ('jugee', 'relaxe') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jugement_de_premiere_instance',
                              'statut', v_a ->> 'status'); END IF;
  IF v_a ? 'appel_ouvert_le' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_deja_interjete',
                              'par', v_a ->> 'appel_par'); END IF;

  v_qui := NULL;
  IF coalesce(v_a ->> 'cible', '') = v_moi THEN
    v_qui := 'condamne';
  ELSE
    SELECT * INTO v_p FROM public.parquet_moi();
    IF v_p.nom IS NOT NULL AND v_p.pays IS NOT DISTINCT FROM v_pays THEN
      v_qui := 'parquet';
    END IF;
  END IF;
  IF v_qui IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee'); END IF;

  v_limite := nullif(v_a ->> 'appel_jusqu_au_jour', '')::integer;
  IF v_limite IS NULL THEN
    SELECT coalesce((j.data ->> 'appel_jusqu_au_jour_pays')::integer,
                    (j.data ->> 'jour_pays')::integer + public.justice_fenetre_appel_jours(),
                    j.jour + public.justice_fenetre_appel_jours())
      INTO v_limite FROM public.jugements j WHERE j.id = 'jug-' || p_affaire_id;
  END IF;
  IF v_limite IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_introuvable'); END IF;
  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  IF v_jour > v_limite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fenetre_appel_fermee',
                              'jour', v_jour, 'limite', v_limite); END IF;

  -- LE LAISSEZ-PASSER, ET IL NE DURE QUE CETTE ECRITURE. Sans lui, `plaintes_epingler_verdict`
  -- restaure le `status` que cette porte vient d'ecrire -- l'appel serait interjete et sans
  -- effet. Voir l'en-tete.
  PERFORM set_config('rp.verdict_interne', 'on', true);
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'appel',
           'appel_par', v_moi,
           'appel_qualite', v_qui,
           'appel_jour', v_jour,
           'appel_ouvert_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id
     AND (data::jsonb ->> 'status') = (v_a ->> 'status')
     AND NOT (data::jsonb ? 'appel_ouvert_le');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  PERFORM set_config('rp.verdict_interne', '', true);
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_deja_interjete'); END IF;

  -- ET L'EFFET EST RELU EN BASE, pas suppose.
  SELECT p.data::jsonb ->> 'status' INTO v_brut
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS DISTINCT FROM 'appel' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_non_applique', 'statut', v_brut); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'appel_ouvert',
    v_moi, CASE WHEN v_qui = 'parquet' THEN 'procureur' ELSE NULL END, NULL, NULL,
    jsonb_build_object('qualite', v_qui, 'jour', v_jour, 'limite', v_limite));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'par', v_moi,
                            'qualite', v_qui, 'jour', v_jour, 'limite', v_limite);
END;
$function$;

-- justice_archives_greffe(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_archives_greffe(p_affaire_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_g record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT d.country, coalesce(d.current_city, 'capitale') INTO v_pays, v_ville
    FROM public.personnages_donnees d WHERE d.name = v_moi;
  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine'); END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
      'site', v_g.batiment, 'piece', v_g.piece); END IF;

  RETURN jsonb_build_object('ok', true, 'ville', v_ville,
    'affaires', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'affaire', p.id,
        'prevenu', (p.data::jsonb) ->> 'cible',
        'categorie', public.affaire_categorie_publique(p.data::jsonb),
        'statut', (p.data::jsonb) ->> 'status',
        'verdict', (p.data::jsonb) ->> 'verdict',
        'peine', (SELECT j.peine FROM public.jugements j WHERE j.id = 'jug-' || p.id),
        'chronologie', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                          'rang', x.rang, 'type', x.type, 'libelle', t.libelle,
                          'poste', x.acteur_poste, 'fait_le', x.fait_le) ORDER BY x.rang), '[]'::jsonb)
                         FROM public.dossiers_judiciaires_actes x
                         JOIN public.dossiers_judiciaires_actes_types t ON t.type = x.type
                        WHERE x.affaire = p.id)
      ) ORDER BY p.id DESC), '[]'::jsonb)
      FROM public.plaintes_en_cours p
     WHERE p.country = v_pays AND p.city = v_ville
       AND left(btrim(p.data), 1) = '{'
       AND (p_affaire_id IS NULL OR p.id = p_affaire_id)
       AND (p.data::jsonb) ->> 'status' IN
           ('non_lieu', 'abandonnee', 'arret', 'relaxe', 'jugee', 'jugee_appel', 'delai_expire')));
END $function$;

-- justice_audience_consentir(text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_audience_consentir(p_affaire_id text, p_jour integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  -- LE CONSENTEMENT APPARTIENT AU PREVENU, ET A LUI SEUL. Ni son avocat, ni le juge, ni le
  -- parquet ne peuvent le donner a sa place.
  IF coalesce(v_a ->> 'cible', '') IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  IF p_jour IS NOT NULL AND p_jour < v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_invalide', 'jour_courant', v_jour); END IF;

  UPDATE public.plaintes_en_cours
     SET data = CASE WHEN p_jour IS NULL
                THEN (v_a - 'audience_consentie_jour' - 'audience_consentie_le')::text
                ELSE (v_a || jsonb_build_object(
                        'audience_consentie_jour', p_jour,
                        'audience_consentie_le',
                        to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text END
   WHERE id = p_affaire_id AND NOT (data::jsonb ? 'audience_ouverte_le');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville,
    CASE WHEN p_jour IS NULL THEN 'audience_consentement_retire' ELSE 'audience_consentement' END,
    v_moi, 'accuse', NULL, NULL, jsonb_build_object('jour', p_jour));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id,
                            'consenti_jour', p_jour, 'retire', (p_jour IS NULL));
END $function$;

-- justice_audience_ecrire(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_audience_ecrire(p_affaire_id text, p_texte text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text;
        v_s record; v_role text; v_txt text; v_rang bigint;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_txt := coalesce(p_texte, '');
  IF btrim(v_txt) = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'message_vide'); END IF;
  IF length(v_txt) > 4000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'message_trop_long'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte'); END IF;

  -- ON PARLE DANS LA SALLE, PAS DEPUIS CHEZ SOI.
  SELECT * INTO v_s FROM public.justice_salle_audience_competente(v_pays, v_ville);
  IF v_s.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_indeterminee'); END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_s.batiment, v_s.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_en_salle_requise',
      'site', v_s.batiment, 'piece', v_s.piece); END IF;

  -- LE ROLE EST RECALCULE ICI, A PARTIR DE LA BASE. Le navigateur n'en dit rien et n'est pas cru.
  v_role := public.audience_role_de(p_affaire_id, v_moi);
  IF v_role = 'spectateur' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'spectateur_sans_parole'); END IF;
  -- UN TEMOIN N'A AUCUN DROIT AUTOMATIQUE D'ECRIRE : il lui faut la parole du juge, et le juge
  -- peut la retirer.
  IF v_role = 'temoin' AND NOT public.audience_peut_ecrire(p_affaire_id, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parole_non_accordee'); END IF;

  INSERT INTO public.audience_messages (affaire, pays, ville, auteur, qualite, texte)
  VALUES (p_affaire_id, v_pays, v_ville, v_moi, v_role, v_txt)
  RETURNING rang INTO v_rang;

  RETURN jsonb_build_object('ok', true, 'rang', v_rang, 'affaire', p_affaire_id,
                            'qualite', v_role, 'auteur', v_moi);
END $function$;

-- justice_audience_fixer(text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_audience_fixer(p_affaire_id text, p_jour integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text;
        v_jour integer; v_min integer; v_n integer; v_prev text;
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville); END IF;
  IF coalesce(v_a ->> 'status', '') <> 'saisie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie', 'statut', v_a ->> 'status'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_ouverte'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_min  := v_jour + public.justice_delai_audience_jours();
  v_prev := v_a ->> 'cible';

  IF p_jour IS NULL OR p_jour < v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_invalide',
                              'jour_courant', v_jour, 'minimum', v_min); END IF;

  -- PLUS TOT QUE J+3 N'EST POSSIBLE QUE SI LE PREVENU A CONSENTI A CE JOUR-LA. Le consentement
  -- porte sur UN jour precis : s'il a consenti au jour 12 et que le juge fixe le 11, il faut un
  -- consentement neuf. Rien n'est deduit du silence.
  IF p_jour < v_min
     AND coalesce((v_a ->> 'audience_consentie_jour')::integer, -1) IS DISTINCT FROM p_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'consentement_du_prevenu_requis',
      'minimum', v_min, 'demande', p_jour, 'prevenu', v_prev);
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'audience_jour', p_jour,
           'audience_fixee_par', v_j.nom,
           'audience_fixee_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'saisie'
     AND NOT (data::jsonb ? 'audience_ouverte_le');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  -- ET L'EFFET EST RELU EN BASE, jamais suppose.
  SELECT p.data::jsonb INTO v_a FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF (v_a ->> 'audience_jour')::integer IS DISTINCT FROM p_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'date_non_appliquee'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'audience_fixee',
    v_j.nom, 'juge', NULL, NULL,
    jsonb_build_object('jour', p_jour, 'minimum', v_min,
                       'consentement_du_prevenu', p_jour < v_min));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'jour', p_jour,
                            'minimum', v_min, 'juge', v_j.nom);
END $function$;

-- justice_audience_lire(text,bigint) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_audience_lire(p_affaire_id text, p_apres bigint DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_s record; v_role text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_s FROM public.justice_salle_audience_competente(v_pays, v_ville);
  IF v_s.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_indeterminee'); END IF;
  -- LIRE EXIGE D'ETRE LA. Une audience publique l'est pour qui s'y rend, pas pour le monde entier.
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_s.batiment, v_s.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_en_salle_requise',
      'site', v_s.batiment, 'piece', v_s.piece); END IF;

  v_role := public.audience_role_de(p_affaire_id, v_moi);
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id,
    'ouverte', public.affaire_audience_ouverte(v_a),
    'mon_role', v_role,
    'je_peux_ecrire', public.affaire_audience_ouverte(v_a)
       AND v_role <> 'spectateur'
       AND (v_role <> 'temoin' OR public.audience_peut_ecrire(p_affaire_id, v_moi)),
    'paroles', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'personne', x.personne, 'accordee_le', x.accordee_le,
                  'retiree_le', x.retiree_le) ORDER BY x.accordee_le), '[]'::jsonb)
                 FROM public.audience_paroles x WHERE x.affaire = p_affaire_id),
    'messages', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'rang', m.rang, 'auteur', m.auteur, 'qualite', m.qualite,
                   'texte', m.texte, 'dit_le', m.dit_le) ORDER BY m.rang), '[]'::jsonb)
                  FROM (SELECT * FROM public.audience_messages
                         WHERE affaire = p_affaire_id AND rang > coalesce(p_apres, 0)
                         ORDER BY rang LIMIT 200) m));
END $function$;

-- justice_audience_ouvrir(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_audience_ouvrir(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_n integer;
        v_jour integer; v_s record; v_prev text; v_proc text;
        v_prev_la boolean; v_proc_la boolean;
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville); END IF;
  IF coalesce(v_a ->> 'status', '') <> 'saisie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie',
                              'statut', v_a ->> 'status'); END IF;
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_ouverte'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);

  -- LE JOUR DOIT AVOIR ETE FIXE, ET IL DOIT ETRE ARRIVE.
  IF (v_a ->> 'audience_jour') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_d_audience_non_fixe'); END IF;
  IF v_jour < (v_a ->> 'audience_jour')::integer THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_d_audience_non_venu',
      'jour_courant', v_jour, 'audience_jour', (v_a ->> 'audience_jour')::integer); END IF;

  -- LE JUGE TIENT SON AUDIENCE DANS SON TRIBUNAL. Pas depuis chez lui, pas depuis une autre ville.
  SELECT * INTO v_s FROM public.justice_salle_audience_competente(v_pays, v_ville);
  IF v_s.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_indeterminee', 'ville', v_ville); END IF;
  IF NOT public.acteur_present_sur_site(v_j.nom, v_pays, v_ville, v_s.batiment, v_s.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_du_juge_requise',
      'ville', v_ville, 'site', v_s.batiment, 'piece', v_s.piece); END IF;

  -- QUI EST LA, ET QUI N'Y EST PAS. C'est un CONSTAT, pas un reproche : ni l'absence du prevenu
  -- ni celle du procureur ne bloquent quoi que ce soit, et aucune consequence mecanique n'en
  -- decoule. Le fait est consigne ; son interpretation appartient aux joueurs.
  v_prev := v_a ->> 'cible';
  SELECT t.nom_pnj INTO v_proc FROM public.titulaires_pnj t
   WHERE t.country = v_pays AND t.poste_id = 'procureur' AND t.city IS NULL;
  IF v_proc IS NULL THEN
    SELECT a2.titulaire INTO v_proc FROM public.postes_attribues a2
     WHERE a2.country = v_pays AND a2.poste_id = 'procureur';
  END IF;
  v_prev_la := v_prev IS NOT NULL
               AND public.acteur_present_sur_site(v_prev, v_pays, v_ville, v_s.batiment, v_s.piece);
  v_proc_la := v_proc IS NOT NULL
               AND public.acteur_present_sur_site(v_proc, v_pays, v_ville, v_s.batiment, v_s.piece);

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'audience_ouverte_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'audience_ouverte_jour', v_jour,
           'audience_ouverte_par', v_j.nom,
           'audience_prevenu_present', v_prev_la,
           'audience_procureur_present', v_proc_la))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'saisie'
     AND NOT (data::jsonb ? 'audience_ouverte_le');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_ouverte'); END IF;

  SELECT p.data::jsonb INTO v_a FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ouverture_non_appliquee'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'audience_ouverte',
    v_j.nom, 'juge', NULL, NULL,
    jsonb_build_object('jour', v_jour, 'prevenu_present', v_prev_la,
                       'procureur_present', v_proc_la, 'procureur', v_proc));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'juge', v_j.nom, 'jour', v_jour,
    'prevenu_present', v_prev_la, 'procureur_present', v_proc_la,
    'salle', jsonb_build_object('batiment', v_s.batiment, 'piece', v_s.piece));
END $function$;

-- justice_audience_parole(text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_audience_parole(p_affaire_id text, p_personne text, p_donner boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_qui text;
BEGIN
  v_qui := nullif(btrim(coalesce(p_personne, '')), '');
  IF v_qui IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personne_manquante'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville'); END IF;
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte'); END IF;

  IF coalesce(p_donner, true) THEN
    INSERT INTO public.audience_paroles (affaire, personne, accordee_par)
    VALUES (p_affaire_id, v_qui, v_j.nom)
    ON CONFLICT (affaire, personne) DO UPDATE
      SET accordee_le = now(), accordee_par = v_j.nom, retiree_le = NULL;
  ELSE
    UPDATE public.audience_paroles SET retiree_le = now()
     WHERE affaire = p_affaire_id AND personne = v_qui AND retiree_le IS NULL;
  END IF;

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'personne', v_qui,
    'peut_ecrire', public.audience_peut_ecrire(p_affaire_id, v_qui), 'juge', v_j.nom);
END $function$;

-- justice_avocat_commis(text,text) -> TABLE(nom text, cha integer) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_avocat_commis(p_pays text, p_ville text)
 RETURNS TABLE(nom text, cha integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT a.nom, a.cha FROM public.justice_avocats_commis a
   WHERE a.pays = p_pays AND a.ville = p_ville;
$function$;

-- justice_avocats_disponibles(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_avocats_disponibles(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_brut text; v_a jsonb; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.country INTO v_brut, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;
  IF coalesce(v_a ->> 'cible', '') IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire'); END IF;

  RETURN jsonb_build_object('ok', true,
    'affaire', p_affaire_id,
    'avocat_retenu', public.defense_avocat_de(p_affaire_id),
    'audience_ouverte', public.affaire_audience_ouverte(v_a),
    -- DEUX INFORMATIONS, ET DEUX SEULEMENT : l'identite et la tarification publiee. Rien de
    -- mecanique n'entre ici -- cette lecture ne joint aucune table de caracteristiques.
    'avocats', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'nom', b.nom, 'tarification', b.tarification) ORDER BY b.nom), '[]'::jsonb)
                 FROM public.avocats_barreau b
                WHERE b.pays = v_pays AND b.nom <> v_moi
                  AND public.avocat_est_qualifie(b.nom)),
    'demandes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'rang', d.rang, 'avocat', d.avocat, 'etat', d.etat,
                   'demande_le', d.demande_le) ORDER BY d.rang DESC), '[]'::jsonb)
                  FROM public.defenses_demandes d
                 WHERE d.affaire = p_affaire_id AND d.prevenu = v_moi));
END $function$;

-- justice_cha_personnel(text) -> integer | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_cha_personnel(p_nom text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(1,
           coalesce((d.stats ->> 'CHA')::integer, 8)
           -- Excommunication : -2 CHA, reversible, deja ecrite au serveur
           -- (`personnages_donnees.excommunie`, JSONB nullable). Elle n'est PAS une notion
           -- cliente : elle est posee et levee par la carriere religieuse.
           + CASE WHEN d.excommunie IS NOT NULL
                   AND jsonb_typeof(d.excommunie) <> 'null' THEN -2 ELSE 0 END)
    FROM public.personnages_donnees d WHERE d.name = p_nom;
$function$;

-- justice_condamner(text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_condamner(p_cible text, p_entree jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_juge text; v_id text; v_pays text; v_ville text; v_jours integer;
BEGIN
  v_juge := public.exiger_poste('juge');
  IF v_juge IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_entree IS NULL OR jsonb_typeof(p_entree) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entree_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  SELECT coalesce(p_entree->>'country', country), coalesce(p_entree->>'ville_condamnation', current_city)
    INTO v_pays, v_ville FROM public.personnages_donnees WHERE name = v_juge;
  SELECT coalesce(sum((m->>'jours')::int), 0) INTO v_jours
    FROM jsonb_array_elements(coalesce(p_entree->'motifs', '[]'::jsonb)) m;

  v_id := coalesce(nullif(p_entree->>'id', ''),
                   'rech-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
                     || substr(md5(random()::text), 1, 6));

  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_id, v_pays, v_ville, p_cible,
          coalesce(p_entree #>> '{motifs,0,type}', 'Condamnation'),
          v_jours::text || ' jours', v_juge,
          coalesce((p_entree->>'jour_affaire')::int, 0), false,
          p_entree || jsonb_build_object('id', v_id))
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'accuse', p_cible, 'jours', v_jours);
END; $function$;

-- justice_defense_part_relaxe() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_defense_part_relaxe()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 50 $function$;

-- justice_defense_taux(integer,integer,boolean) -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_defense_taux(p_cha_avocat integer, p_cha_prevenu integer, p_preuve_reelle boolean)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT greatest(5, least(80,
    50 + (coalesce(p_cha_avocat, 13) - 13) * 5
       + (coalesce(p_cha_prevenu, 13) - 13) * 3
       - CASE WHEN coalesce(p_preuve_reelle, false) THEN 35 ELSE 0 END));
$function$;

-- justice_delai_audience_jours() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_delai_audience_jours()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 3; $function$;

-- justice_delai_convocation_temoin_jours() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_delai_convocation_temoin_jours()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 2 $function$;

-- justice_delai_jugement_jours() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_delai_jugement_jours()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 15 $function$;

-- justice_delais_echus() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_delais_echus()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_d record; v_n integer := 0; v_infr text; v_clos jsonb := '[]'::jsonb;
BEGIN
  -- PORTE DE SERVEUR. Aucun joueur ne declenche l'expiration d'un dossier : elle est l'effet du
  -- temps, pas d'une decision.
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;

  FOR v_d IN
    SELECT p.id, p.country, p.city, p.data::jsonb AS a
      FROM public.plaintes_en_cours p
     WHERE p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
       AND ((p.data::jsonb) ->> 'status') IN
           ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande')
       AND public.affaire_delai_expire(p.data::jsonb, p.country)
     ORDER BY p.created_at
     FOR UPDATE
  LOOP
    -- Compare-and-swap : une decision rendue dans la meme seconde gagne, et la passe ne l'ecrase
    -- pas. Un jugement arrive a l'heure n'est pas annule par une expiration de la nuit.
    UPDATE public.plaintes_en_cours
       SET data = (v_d.a || jsonb_build_object(
             'status', 'delai_expire',
             'delai_expire_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
     WHERE id = v_d.id AND (data::jsonb ->> 'status') = (v_d.a ->> 'status');
    IF NOT FOUND THEN CONTINUE; END IF;

    PERFORM public.dossier_acte_consigner(v_d.id, v_d.country, v_d.city,
      'charges_abandonnees_delai', NULL, NULL, NULL, NULL,
      jsonb_build_object('echeance', (v_d.a ->> 'delai_jugement_jour')::integer,
                         'statut_precedent', v_d.a ->> 'status'));

    -- LA RECHERCHE EST RESOLUE CONFORMEMENT A LA CLOTURE. Les charges sont abandonnees : la
    -- personne n'est plus recherchee POUR CET ACTE. Les autres entrees ne sont pas touchees --
    -- `recherche_retirer` filtre sur l'acte, et un motif n'en efface jamais un autre.
    v_infr := public.affaire_infraction_de(v_d.a);
    IF v_infr IS NOT NULL AND nullif(v_d.a ->> 'cible', '') IS NOT NULL THEN
      PERFORM public.recherche_retirer(ARRAY[v_infr], v_d.country, v_d.a ->> 'cible');
    END IF;

    v_n := v_n + 1;
    v_clos := v_clos || jsonb_build_array(jsonb_build_object(
      'affaire', v_d.id, 'cible', v_d.a ->> 'cible', 'infraction', v_infr));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'closes', v_n, 'dossiers', v_clos);
END;
$function$;

-- justice_est_recherche(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_est_recherche(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d,
           jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche) = 'array'
                                     THEN d.recherche ELSE '[]'::jsonb END) e
     WHERE d.name = p_nom
       AND NOT EXISTS (SELECT 1 FROM public.justice_affaires_vivantes_avec_pv(p_nom) v
                        WHERE v.infraction IS NOT NULL AND v.infraction = (e ->> 'acte')));
$function$;

-- justice_executer_condamnation(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_executer_condamnation(p_jugement_id text, p_ville text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acteur text; v_j record; v_jours integer; v_motif text; v_res jsonb; v_det record;
BEGIN
  v_acteur := public.exiger_poste('commissaire');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- Verrou : deux executions simultanees de la meme condamnation ne peuvent pas coexister.
  SELECT * INTO v_j FROM public.jugements WHERE id = p_jugement_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'condamnation_introuvable');
  END IF;
  IF v_j.executee THEN
    RETURN jsonb_build_object('ok', true, 'deja_executee', true, 'accuse', v_j.accuse);
  END IF;

  -- Deja detenu : la peine s'ajoute a la detention en cours plutot que d'en ouvrir une seconde.
  SELECT * INTO v_det FROM public.detention_active(v_j.accuse);
  IF v_det.id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_deja_detenue');
  END IF;

  v_jours := coalesce((SELECT sum((m->>'jours')::int)
                         FROM jsonb_array_elements(coalesce(v_j.data->'motifs', '[]'::jsonb)) m), 0);
  IF v_jours <= 0 THEN v_jours := 3; END IF;   -- meme repli que le flagrant delit du client
  v_motif := coalesce(v_j.motif, 'Avis de recherche');

  v_res := public.detention_ouvrir_interne(
             v_j.accuse, v_motif, v_jours, coalesce(p_ville, v_j.city), v_j.country,
             coalesce(v_j.data->'motifs', '[]'::jsonb), v_acteur,
             coalesce(v_j.data->>'issue_judiciaire', 'condamnation_executee'));
  IF NOT coalesce((v_res->>'ok')::boolean, false) THEN
    RETURN v_res;
  END IF;

  UPDATE public.jugements SET executee = true WHERE id = p_jugement_id;

  RETURN jsonb_build_object('ok', true, 'accuse', v_j.accuse, 'jours', v_jours,
                            'detention_id', v_res->>'detention_id', 'motif', v_motif);
END; $function$;

-- justice_fenetre_appel_jours() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_fenetre_appel_jours()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 2 $function$;

-- justice_greffe_competent(text,text) -> TABLE(batiment text, piece text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_greffe_competent(p_pays text, p_ville text)
 RETURNS TABLE(batiment text, piece text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Le BATIMENT est celui que `parquet_site_competent` designe deja -- une seule regle pour le
  -- tribunal competent. La PIECE est le greffe, et elle porte le meme nom dans les deux gabarits.
  SELECT public.parquet_site_competent(p_pays, p_ville), 'greffe'
   WHERE public.parquet_site_competent(p_pays, p_ville) IS NOT NULL;
$function$;

-- justice_indemnite_naitre(text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_indemnite_naitre(p_pays text, p_beneficiaire text, p_affaire text, p_jugement text, p_jours integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_montant integer; v_id text; v_caisse text; v_data jsonb; v_solde numeric;
  v_porteur text; v_paye integer := 0; v_r jsonb;
BEGIN
  IF coalesce(p_jours, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'indemnite', false, 'raison', 'aucun_jour_indu');
  END IF;
  v_montant := p_jours * public.justice_indemnite_par_jour();
  v_id := 'ind-' || substr(md5(coalesce(p_affaire, '') || '|' || p_beneficiaire || '|'
                               || coalesce(p_jugement, '')), 1, 16);
  -- IDEMPOTENCE PAR IDENTIFIANT DERIVE : un jugement d'appel rejoue ne cree pas deux creances.
  IF EXISTS (SELECT 1 FROM public.justice_indemnites WHERE id = v_id) THEN
    RETURN jsonb_build_object('ok', true, 'indemnite', true, 'deja_nee', true, 'id', v_id);
  END IF;

  -- PREMIER ETAGE : LA JUSTICE PAIE TOUT, OU NE PAIE RIEN. Pas de paiement composite -- c'est
  -- une regle explicite, et elle evite qu'une creance soit a cheval sur deux budgets.
  v_caisse := p_pays || '_gouvernement-min_just';
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  v_solde := CASE WHEN v_data IS NOT NULL AND jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;

  IF v_solde >= v_montant THEN
    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_montant),
           updated_at = now()
     WHERE id = v_caisse;
    UPDATE public.personnages_donnees
       SET arg = coalesce(arg, 0) + v_montant
     WHERE name = p_beneficiaire;
    v_porteur := 'min_just'; v_paye := v_montant;
  ELSE
    -- RIEN N'EST PRELEVE CHEZ LA JUSTICE. La creance change de porteur, definitivement.
    v_porteur := 'min_fin'; v_paye := 0;
  END IF;

  INSERT INTO public.justice_indemnites
    (id, pays, beneficiaire, affaire, jugement, jours_indus, montant_du, montant_paye,
     porteur, etat, regle_le)
  VALUES (v_id, p_pays, p_beneficiaire, p_affaire, p_jugement, p_jours, v_montant, v_paye,
          v_porteur, CASE WHEN v_paye = v_montant THEN 'reglee' ELSE 'due' END,
          CASE WHEN v_paye = v_montant THEN now() ELSE NULL END);

  -- SECOND ETAGE : LES FINANCES PAIENT L'INTEGRALITE, OU LA DETTE RESTE. Le partiel n'est permis
  -- qu'aux alimentations ulterieures de leur caisse -- d'ou `p_partiel => false` ici.
  IF v_porteur = 'min_fin' THEN
    v_r := public.justice_indemnites_payer_depuis_finances(p_pays, false);
  END IF;

  RETURN jsonb_build_object('ok', true, 'indemnite', true, 'id', v_id,
    'jours_indus', p_jours, 'montant', v_montant, 'porteur', v_porteur,
    'paye', (SELECT montant_paye FROM public.justice_indemnites WHERE id = v_id),
    'etat', (SELECT etat FROM public.justice_indemnites WHERE id = v_id));
END;
$function$;

-- justice_indemnite_par_jour() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_indemnite_par_jour()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 1000 $function$;

-- justice_indemnites_payer_depuis_finances(text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_indemnites_payer_depuis_finances(p_pays text, p_partiel boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caisse text; v_data jsonb; v_solde numeric; v_c record;
  v_reste integer; v_verse integer; v_total integer := 0; v_n integer := 0;
BEGIN
  v_caisse := p_pays || '_gouvernement-min_fin';

  FOR v_c IN
    SELECT i.* FROM public.justice_indemnites i
     WHERE i.pays = p_pays AND i.etat = 'due' AND i.porteur = 'min_fin'
     ORDER BY i.rang
     FOR UPDATE
  LOOP
    SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    v_solde := CASE WHEN v_data IS NOT NULL AND jsonb_typeof(v_data -> 'solde') = 'number'
                    THEN (v_data ->> 'solde')::numeric ELSE 0 END;
    IF v_solde <= 0 THEN EXIT; END IF;

    v_reste := v_c.montant_du - v_c.montant_paye;
    v_verse := least(v_reste, floor(v_solde)::integer);
    IF v_verse <= 0 THEN EXIT; END IF;
    IF v_verse < v_reste AND NOT coalesce(p_partiel, true) THEN EXIT; END IF;

    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
           updated_at = now()
     WHERE id = v_caisse;

    UPDATE public.personnages_donnees
       SET arg = coalesce(arg, 0) + v_verse
     WHERE name = v_c.beneficiaire;

    UPDATE public.justice_indemnites
       SET montant_paye = v_c.montant_paye + v_verse,
           etat = CASE WHEN v_c.montant_paye + v_verse = v_c.montant_du THEN 'reglee' ELSE 'due' END,
           regle_le = CASE WHEN v_c.montant_paye + v_verse = v_c.montant_du THEN now() ELSE NULL END
     WHERE id = v_c.id;

    v_total := v_total + v_verse;
    v_n := v_n + 1;
    IF v_c.montant_paye + v_verse < v_c.montant_du THEN EXIT; END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'verse', v_total, 'creances_touchees', v_n);
END;
$function$;

-- justice_indemnites_sur_alimentation() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_indemnites_sur_alimentation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_av numeric; v_ap numeric; v_pays text;
BEGIN
  -- RECURSION : le paiement DEBITE cette meme caisse, donc ce declencheur se rappelle. Le garde
  -- est double -- un verrou de portee, et le fait qu'une BAISSE ne declenche rien.
  IF coalesce(current_setting('rp.indemnites_en_cours', true), '') = 'on' THEN
    RETURN NEW;
  END IF;
  IF NEW.id NOT LIKE '%\_gouvernement-min\_fin' THEN RETURN NEW; END IF;

  v_av := CASE WHEN jsonb_typeof(OLD.data -> 'solde') = 'number'
               THEN (OLD.data ->> 'solde')::numeric ELSE 0 END;
  v_ap := CASE WHEN jsonb_typeof(NEW.data -> 'solde') = 'number'
               THEN (NEW.data ->> 'solde')::numeric ELSE 0 END;
  IF v_ap <= v_av THEN RETURN NEW; END IF;

  v_pays := split_part(NEW.id, '_gouvernement-min_fin', 1);
  IF coalesce(v_pays, '') = '' THEN RETURN NEW; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.justice_indemnites
                  WHERE pays = v_pays AND etat = 'due' AND porteur = 'min_fin') THEN
    RETURN NEW;
  END IF;

  PERFORM set_config('rp.indemnites_en_cours', 'on', true);
  PERFORM public.justice_indemnites_payer_depuis_finances(v_pays, true);
  PERFORM set_config('rp.indemnites_en_cours', '', true);
  RETURN NEW;
END;
$function$;

-- justice_jours_purges(text) -> integer | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_jours_purges(p_detention_id text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(0,
           coalesce(d.jour_fin_effective, coalesce(c.day, 1)) - d.jour_debut)
    FROM public.detentions d
    LEFT JOIN public.personnages_donnees c ON c.name = d.nom
   WHERE d.id = p_detention_id;
$function$;

-- justice_juge_titulaire(text,text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_juge_titulaire(p_pays text, p_ville text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
    (SELECT d.name FROM public.personnages_donnees d
      WHERE d.country = p_pays AND (d.poste ->> 'id') = 'juge'
        AND (d.poste ->> 'city') IS NOT DISTINCT FROM p_ville LIMIT 1),
    (SELECT t.nom_pnj FROM public.titulaires_pnj t
      WHERE t.country = p_pays AND t.poste_id = 'juge'
        AND t.city IS NOT DISTINCT FROM p_ville LIMIT 1));
$function$;

-- justice_mes_indemnites() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_mes_indemnites()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  RETURN jsonb_build_object('ok', true, 'indemnites', coalesce((
    SELECT jsonb_agg(jsonb_build_object(
             'id', i.id, 'affaire', i.affaire, 'jours_indus', i.jours_indus,
             'du', i.montant_du, 'paye', i.montant_paye,
             'reste', i.montant_du - i.montant_paye,
             'porteur', i.porteur, 'etat', i.etat,
             'cree_le', i.cree_le, 'regle_le', i.regle_le) ORDER BY i.rang)
      FROM public.justice_indemnites i WHERE i.beneficiaire = v_moi), '[]'::jsonb));
END;
$function$;

-- justice_peine_calcul(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_peine_calcul(p_infraction text, p_genre text, p_cible text, p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_b jsonb; v_n integer; v_jmin integer; v_jmax integer;
        v_amin integer; v_amax integer; v_impose boolean := false;
BEGIN
  IF p_genre NOT IN ('prison', 'amende', 'amenagement', 'qhs', 'torture') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'genre_inconnu', 'genre', p_genre);
  END IF;

  v_b := public.infraction_peine_bornes(p_infraction);
  IF coalesce((v_b ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_b;   -- infraction_inconnue : le refus porte deja sa raison
  END IF;

  v_jmin := (v_b ->> 'jours_min')::integer;  v_jmax := (v_b ->> 'jours_max')::integer;
  v_amin := (v_b ->> 'amende_min')::integer; v_amax := (v_b ->> 'amende_max')::integer;

  IF p_genre = 'prison' THEN
    -- La modulation du juge porte sur les JOURS, dans la plage du catalogue. Aucune amende : le
    -- jeu n'en preleve aucune aujourd'hui (voir le genre `amende` ci-dessous).
    v_amin := 0; v_amax := 0;

  ELSIF p_genre = 'amende' THEN
    -- La modulation porte sur le MONTANT. Aucun jour de detention.
    -- DETTE NOMMEE, NON TRAITEE ICI : l'amende n'est PRELEVEE nulle part. `appliquerSentence`
    -- composait « Amende de 500 FR » -- un 500 en dur, sans rapport avec le bareme -- et
    -- n'appelait aucune porte de debit. Le montant devient au moins REEL (celui du catalogue,
    -- modulable) et verifie ; le prelevement reste a construire.
    v_jmin := 0; v_jmax := 0;

  ELSIF p_genre = 'amenagement' THEN
    -- Mention au registre, sans consequence mecanique -- c'etait deja le cas.
    v_jmin := 0; v_jmax := 0; v_amin := 0; v_amax := 0; v_impose := true;

  ELSIF p_genre = 'qhs' THEN
    -- TRENTE JOURS, RECOPIES DE LA REGLE VALIDEE, pas derives du catalogue : le QHS n'est pas une
    -- peine du code penal, c'est une mecanique a part, arbitree le 26 aout 2026 et inchangee ici.
    -- Le serveur l'IMPOSE desormais, au lieu de recevoir du navigateur une duree qu'il n'a jamais
    -- verifiee.
    v_jmin := 30; v_jmax := 30; v_amin := 0; v_amax := 0; v_impose := true;

  ELSE   -- torture
    -- TROIS JOURS PAR CONDAMNATION, CUMULES, RECOPIES DE LA REGLE VALIDEE. Le cumul se comptait
    -- cote navigateur (`sbGetActionsTracablesParAuteur`) : il se compte ici, sur la meme trace
    -- `condamnation_torture`, qui est ecrite avec une expiration a +36500 jours et ne s'eteint
    -- donc jamais. C'est la meme formule, deplacee la ou elle ne peut plus etre reecrite.
    SELECT count(*) INTO v_n FROM public.actions_tracables a
     WHERE a.auteur = p_cible AND a.type_action = 'condamnation_torture'
       AND a.country IS NOT DISTINCT FROM p_pays;
    v_jmin := 3 * (v_n + 1); v_jmax := v_jmin; v_amin := 0; v_amax := 0; v_impose := true;
  END IF;

  RETURN v_b || jsonb_build_object(
    'genre', p_genre,
    'jours_min', v_jmin, 'jours_max', v_jmax,
    'amende_min', v_amin, 'amende_max', v_amax,
    -- `impose` dit a l'ecran qu'il n'y a RIEN a moduler : la valeur est celle-la et pas une autre.
    'impose', v_impose,
    -- La valeur par defaut proposee au juge : la reference du catalogue pour les genres
    -- modulables, la valeur imposee sinon. Toujours dans la plage, par construction.
    'jours_defaut', CASE WHEN v_impose THEN v_jmin
                         WHEN p_genre = 'prison' THEN (v_b ->> 'jours_reference')::integer
                         ELSE 0 END,
    'amende_defaut', CASE WHEN p_genre = 'amende' THEN (v_b ->> 'amende_reference')::integer
                          ELSE 0 END);
END;
$function$;
