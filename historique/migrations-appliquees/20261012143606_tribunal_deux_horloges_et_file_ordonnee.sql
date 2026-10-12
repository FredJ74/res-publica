-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012143606 (UTC), nom
-- `tribunal_deux_horloges_et_file_ordonnee`.
-- Le registre passe de 687 a 688 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 bde813a5d7fddd88fdf3f81e0e8d32e6, 31197 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE TRIBUNAL, CHEMIN CRITIQUE (5/6) -- DEUX HORLOGES, ET UNE FILE QUI NE TIENT PAS SUR now()
--
-- TROIS DEFAUTS TROUVES PAR LE BANC, ET AUCUN VISIBLE PAR UNE PREUVE STRUCTURELLE.
--
-- 1. LE SYSTEME A DEUX HORLOGES, ET LA PREMIERE VERSION LES MELANGEAIT. `jour_de_jeu_pays()` est
--    l'horloge PARTAGEE -- celle du PV et du delai de jugement. Mais `detentions` ne l'utilise
--    pas : `detention_ouvrir_interne` pose `jour_debut` depuis le `day` DE LA FICHE DU DETENU, et
--    `detention_clore_purgee` libere quand ce MEME compteur atteint `jour_fin`. C'est donc lui
--    qui compte les journees de peine. Mesure du banc : avec l'horloge du pays, une detention
--    ouverte le jour 1 affichait 31 jours purges le jour 30.
--
-- 2. LA FENETRE D'APPEL VIVAIT SUR LE `day` DU JUGE. Une echeance OPPOSABLE ne peut pas vivre sur
--    le compteur personnel d'un acteur, parce que celui qui interjette en est un AUTRE. Mesure :
--    jugement « jour 1 », fenetre jusqu'au « jour 3 », appel refuse parce que le pays etait au
--    jour 30. `jugements.jour` n'est pas touche : c'est une date d'affichage.
--
-- 3. LA FILE FIFO NE PEUT PAS S'ORDONNER SUR `cree_le`. now() est CONSTANT dans une transaction :
--    le banc a vu le cadet paye avant l'aine. Meme piege et meme reponse que
--    `dossiers_judiciaires_actes.rang` -- une SEQUENCE.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- DEUX HORLOGES, ET UNE FILE QUI NE TIENT PAS SUR now()
-- 12 octobre 2026 -- correctif de l'appel et des indemnites
--
-- TROIS DEFAUTS, TROUVES PAR LE BANC, ET AUCUN N'ETAIT VISIBLE PAR UNE PREUVE STRUCTURELLE.
--
-- 1. LE SYSTEME A DEUX HORLOGES, ET J'EN AI MELANGE LES DEUX. `jour_de_jeu_pays()` derive le jour
--    du pays de `rp_epoques` -- c'est l'horloge PARTAGEE, celle du PV et du delai de jugement.
--    Mais `detentions` ne l'utilise PAS : `detention_ouvrir_interne` pose `jour_debut` depuis le
--    `day` DE LA FICHE DU DETENU, et `detention_clore_purgee` libere quand ce MEME `day` atteint
--    `jour_fin`. C'est donc le compteur personnel du detenu qui compte ses journees de peine, et
--    c'est lui -- et lui seul -- qui doit servir a compter les jours PURGES. Mesure du banc :
--    avec l'horloge du pays, une detention ouverte le jour 1 affichait 31 jours purges le jour 30.
--    `justice_jours_purges` change donc d'horloge, et de signature.
--
-- 2. LA FENETRE D'APPEL ETAIT CALCULEE SUR LE `day` DU JUGE. `jugements.jour` l'a toujours ete, et
--    ce n'est pas grave pour un affichage ; mais une ECHEANCE OPPOSABLE ne peut pas vivre sur le
--    compteur personnel d'un acteur, parce que celui qui interjette est un AUTRE acteur -- le
--    condamne, ou le Procureur. Mesure du banc : jugement « jour 1 », fenetre jusqu'au « jour 3 »,
--    et l'appel refuse immediatement parce que le pays etait au jour 30. L'echeance passe donc sur
--    l'horloge PARTAGEE, la seule que les deux parties lisent de la meme facon. `jugements.jour`
--    n'est pas touche : c'est une date d'affichage, et la changer reecrirait l'histoire.
--
-- 3. LA FILE FIFO NE PEUT PAS S'ORDONNER SUR `cree_le`. `now()` est CONSTANT dans une
--    transaction : deux creances nees dans la meme transaction portent le MEME horodatage, et
--    l'ordre devient indecidable -- le banc a vu le cadet paye avant l'aine. C'est exactement le
--    piege resolu par `dossiers_judiciaires_actes.rang` le 12 octobre au matin, et la meme reponse
--    s'applique : une SEQUENCE. `cree_le` reste, pour l'affichage.
--
-- PREUVES STRUCTURELLES -- 7.

-- ============================================================================================
-- 1. LES JOURS PURGES SE COMPTENT SUR L'HORLOGE DU DETENU
-- ============================================================================================
DROP FUNCTION IF EXISTS public.justice_jours_purges(text, text);
CREATE OR REPLACE FUNCTION public.justice_jours_purges(p_detention_id text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT greatest(0,
           coalesce(d.jour_fin_effective, coalesce(c.day, 1)) - d.jour_debut)
    FROM public.detentions d
    LEFT JOIN public.personnages_donnees c ON c.name = d.nom
   WHERE d.id = p_detention_id;
$$;
COMMENT ON FUNCTION public.justice_jours_purges(text) IS
  'Les jours de prison REELLEMENT PURGES sur une detention, sur L''HORLOGE QUI COMPTE CETTE PEINE : le `day` de la fiche du detenu. Ce n''est pas l''horloge du pays, et le choix n''est pas libre -- `detention_ouvrir_interne` pose `jour_debut` depuis ce compteur, et `detention_clore_purgee` libere quand il atteint `jour_fin`. Compter avec une autre horloge donnerait des jours purges qui ne correspondent a aucune journee de detention. Si la detention est close, on s''arrete a sa fin effective.';
REVOKE ALL ON FUNCTION public.justice_jours_purges(text) FROM PUBLIC;

-- ============================================================================================
-- 2. LA FENETRE D'APPEL VIT SUR L'HORLOGE PARTAGEE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_rendre_sentence(
  p_affaire_id text, p_infraction text, p_genre text,
  p_jours integer DEFAULT 0, p_amende integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer;
  v_calc jsonb; v_jours integer; v_amende integer; v_libelle text; v_peine text;
  v_jug text; v_n integer; v_motifs jsonb; v_parquet text;
  v_det record; v_exec jsonb; v_executee boolean := false; v_jour_pays integer;
BEGIN
  IF coalesce(btrim(coalesce(p_affaire_id, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_invalide'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF NOT FOUND OR v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville); END IF;

  IF coalesce(v_a ->> 'status', '') <> 'saisie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie',
                              'statut', v_a ->> 'status'); END IF;

  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer); END IF;

  v_calc := public.justice_peine_calcul(p_infraction, p_genre, v_a ->> 'cible', v_pays);
  IF coalesce((v_calc ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_calc; END IF;

  v_jours  := coalesce(p_jours, 0);
  v_amende := coalesce(p_amende, 0);

  IF v_jours < (v_calc ->> 'jours_min')::integer
     OR v_jours > (v_calc ->> 'jours_max')::integer THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'peine_hors_bornes',
      'demande_jours', v_jours,
      'jours_min', (v_calc ->> 'jours_min')::integer,
      'jours_max', (v_calc ->> 'jours_max')::integer,
      'jours_reference', (v_calc ->> 'jours_reference')::integer);
  END IF;
  IF v_amende < (v_calc ->> 'amende_min')::integer
     OR v_amende > (v_calc ->> 'amende_max')::integer THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'amende_hors_bornes',
      'demande_amende', v_amende,
      'amende_min', (v_calc ->> 'amende_min')::integer,
      'amende_max', (v_calc ->> 'amende_max')::integer,
      'amende_reference', (v_calc ->> 'amende_reference')::integer);
  END IF;

  -- DEUX HORLOGES, ET CHACUNE A SA PLACE. `v_jour` est le compteur personnel du juge : il datait
  -- deja `jugements.jour` avant cette tranche, et le changer reecrirait l'histoire. `v_jour_pays`
  -- est l'horloge PARTAGEE, et c'est la seule sur laquelle une echeance OPPOSABLE puisse vivre --
  -- celui qui interjette appel n'est pas le juge.
  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_j.nom;
  v_jour := coalesce(v_jour, 1);
  v_jour_pays := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_libelle := v_calc ->> 'libelle';
  v_parquet := v_a ->> 'qualification_parquet';

  v_peine := CASE p_genre
    WHEN 'prison'      THEN 'Prison ' || v_jours || ' jour' || CASE WHEN v_jours > 1 THEN 's' ELSE '' END
    WHEN 'amende'      THEN 'Amende de ' || v_amende || ' FR'
    WHEN 'amenagement' THEN 'Amenagement : pointage quotidien au commissariat'
    WHEN 'qhs'         THEN 'Envoi au QHS (' || v_jours || ' jours)'
    ELSE                    'Prison ' || v_jours || ' jours + popularite a zero'
  END;

  v_motifs := CASE WHEN v_jours > 0 THEN jsonb_build_array(jsonb_build_object(
      'type', v_libelle, 'infraction', v_calc ->> 'infraction', 'jours', v_jours,
      'city', v_ville, 'source', 'jugement',
      'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')))
    ELSE '[]'::jsonb END;

  v_jug := 'jug-' || p_affaire_id;
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_jug, v_pays, coalesce(v_ville, 'capitale'), v_a ->> 'cible',
          v_libelle, v_peine, v_j.nom, v_jour, false,
          jsonb_build_object(
            'verdict', 'condamnation', 'instance', 'premiere',
            'infraction', v_calc ->> 'infraction',
            'infraction_libelle', v_libelle,
            'genre', p_genre,
            'jours', v_jours, 'amende', v_amende,
            'jours_reference', (v_calc ->> 'jours_reference')::integer,
            'jours_min', (v_calc ->> 'jours_min')::integer,
            'jours_max', (v_calc ->> 'jours_max')::integer,
            'amende_reference', (v_calc ->> 'amende_reference')::integer,
            'jour_pays', v_jour_pays,
            'appel_jusqu_au_jour_pays', v_jour_pays + public.justice_fenetre_appel_jours(),
            'categorie_alleguee', v_a ->> 'categorie_alleguee',
            'motif_allegue', v_a ->> 'motif',
            'qualification_parquet', v_parquet,
            'motifs', v_motifs,
            'issue_judiciaire', v_peine))
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_deja_rendu');
  END IF;

  IF v_parquet IS NOT NULL AND (v_calc ->> 'infraction') IS DISTINCT FROM v_parquet THEN
    PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville,
      'requalification', v_j.nom, 'juge', v_parquet, v_calc ->> 'infraction');
  END IF;

  IF v_jours > 0 THEN
    SELECT * INTO v_det FROM public.detention_active(v_a ->> 'cible');
    IF v_det.id IS NULL THEN
      v_exec := public.detention_ouvrir_interne(
                  v_a ->> 'cible', v_libelle, v_jours, coalesce(v_ville, 'capitale'), v_pays,
                  v_motifs, v_j.nom, coalesce(v_peine, 'condamnation_executee'));
      IF coalesce((v_exec ->> 'ok')::boolean, false) THEN
        UPDATE public.jugements SET executee = true WHERE id = v_jug;
        v_executee := true;
      END IF;
    END IF;
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'jugee',
           'verdict', 'condamnation',
           'juge', v_j.nom,
           'juge_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'jugement_jour', v_jour,
           'jugement_jour_pays', v_jour_pays,
           'appel_jusqu_au_jour', v_jour_pays + public.justice_fenetre_appel_jours(),
           'qualification_finale', v_calc ->> 'infraction',
           'qualification_libelle', v_libelle,
           'peine_genre', p_genre,
           'peine_jours', v_jours,
           'peine_amende', v_amende,
           'peine_libelle', v_peine,
           'detention_id', v_exec ->> 'detention_id'))::text
   WHERE id = p_affaire_id;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'condamnation',
    v_j.nom, 'juge', v_parquet, v_calc ->> 'infraction',
    jsonb_build_object('accuse', v_a ->> 'cible', 'genre', p_genre,
                       'jours', v_jours, 'amende', v_amende,
                       'jours_reference', (v_calc ->> 'jours_reference')::integer,
                       'executee', v_executee, 'instance', 'premiere'));

  RETURN jsonb_build_object('ok', true, 'jugement_id', v_jug, 'affaire', p_affaire_id,
    'juge', v_j.nom, 'jour', v_jour, 'jugement_cree', true,
    'infraction', v_calc ->> 'infraction', 'infraction_libelle', v_libelle,
    'qualification_parquet', v_parquet,
    'requalifiee', (v_parquet IS NOT NULL AND (v_calc ->> 'infraction') IS DISTINCT FROM v_parquet),
    'genre', p_genre, 'jours', v_jours, 'amende', v_amende, 'peine', v_peine,
    'motifs', v_motifs, 'executee', v_executee,
    'detention_id', v_exec ->> 'detention_id',
    'appel_jusqu_au_jour', v_jour_pays + public.justice_fenetre_appel_jours());
END;
$$;

-- `justice_appel_ouvrir` lit deja `appel_jusqu_au_jour` du dossier et le compare a
-- `jour_de_jeu_pays` : les deux cotes sont desormais sur la MEME horloge. Seul son repli -- pour
-- les dossiers juges avant cette tranche -- lisait `jugements.jour`, le compteur du juge. Il lit
-- maintenant l'echeance que la sentence inscrit dans `data`, et ne retombe sur le registre que si
-- elle y est absente.
CREATE OR REPLACE FUNCTION public.justice_appel_ouvrir(p_affaire_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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

  -- L'ECHEANCE EST SUR L'HORLOGE DU PAYS, DES DEUX COTES. Le repli ne lit le registre que pour un
  -- dossier juge avant cette tranche, et il y prend `jour_pays` quand il existe.
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
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_deja_interjete'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'appel_ouvert',
    v_moi, CASE WHEN v_qui = 'parquet' THEN 'procureur' ELSE NULL END, NULL, NULL,
    jsonb_build_object('qualite', v_qui, 'jour', v_jour, 'limite', v_limite));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'par', v_moi,
                            'qualite', v_qui, 'jour', v_jour, 'limite', v_limite);
END;
$$;

-- `justice_appel_juger` appelait `justice_jours_purges(id, pays)`. La signature a change.
CREATE OR REPLACE FUNCTION public.justice_appel_juger(
  p_affaire_id text, p_verdict text, p_infraction text DEFAULT NULL,
  p_genre text DEFAULT NULL, p_jours integer DEFAULT 0, p_amende integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;

-- ============================================================================================
-- 3. LA FILE S'ORDONNE SUR UNE SEQUENCE, PAS SUR now()
-- ============================================================================================
ALTER TABLE public.justice_indemnites ADD COLUMN IF NOT EXISTS rang bigserial;
COMMENT ON COLUMN public.justice_indemnites.rang IS
  'L''ORDRE REEL DE LA FILE FIFO. `cree_le` ne peut pas l''etablir : now() est CONSTANT dans une transaction, donc deux creances nees dans la meme transaction portent le meme horodatage et l''ordre devient indecidable -- le banc a vu le cadet paye avant l''aine. Meme piege et meme reponse que `dossiers_judiciaires_actes.rang`. `cree_le` reste, pour l''affichage.';
DROP INDEX IF EXISTS public.justice_indemnites_file_fifo;
CREATE INDEX IF NOT EXISTS justice_indemnites_file_fifo
  ON public.justice_indemnites (pays, etat, rang);

CREATE OR REPLACE FUNCTION public.justice_indemnites_payer_depuis_finances(
  p_pays text, p_partiel boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.justice_mes_indemnites()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;

DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : `justice_jours_purges` N'A PLUS QU'UNE SIGNATURE, ET ELLE N'A PLUS DE PAYS. L'ancienne
  -- aurait continue d'exister a cote : un CREATE OR REPLACE a parametres differents CREE.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_jours_purges';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- % signature(s) de justice_jours_purges au lieu d''une', v_n; END IF;

  -- P2 : ELLE COMPTE SUR L'HORLOGE DU DETENU, et non sur celle du pays.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_jours_purges';
  IF position('coalesce(c.day, 1)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- les jours purges ne se comptent pas sur la fiche du detenu'; END IF;
  IF position('jour_de_jeu_pays' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- les jours purges melangent encore les deux horloges'; END IF;

  -- P3 : LA FENETRE D'APPEL EST SUR L'HORLOGE PARTAGEE, DES DEUX COTES.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_rendre_sentence';
  IF position('v_jour_pays := coalesce(public.jour_de_jeu_pays(v_pays), 1)' IN v_txt) = 0
     OR position('''appel_jusqu_au_jour'', v_jour_pays + public.justice_fenetre_appel_jours()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- l''echeance d''appel vit encore sur le compteur du juge'; END IF;

  -- P4 : `jugements.jour` N'A PAS CHANGE D'HORLOGE -- c'est une date d'affichage, et la reecrire
  -- aurait reecrit l'histoire des jugements deja rendus.
  IF position('SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_j.nom' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la date du jugement a change d''horloge'; END IF;

  -- P5 : LE REPLI DE L'APPEL LIT L'ECHEANCE DU PAYS quand le registre la porte.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_appel_ouvrir';
  IF position('appel_jusqu_au_jour_pays' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le repli de l''appel lit la mauvaise horloge'; END IF;

  -- P6 : LA FILE S'ORDONNE SUR LA SEQUENCE, PLUS SUR `cree_le`.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_indemnites_payer_depuis_finances';
  IF position('ORDER BY i.rang' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- la file ne s''ordonne pas sur la sequence'; END IF;
  IF position('ORDER BY i.cree_le' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- la file s''ordonne encore sur un horodatage constant'; END IF;

  -- P7 : LA COLONNE EXISTE, NOT NULL, ADOSSEE A UNE SEQUENCE.
  SELECT count(*) INTO v_n FROM pg_attribute a
   WHERE a.attrelid = 'public.justice_indemnites'::regclass AND a.attname = 'rang'
     AND a.attnotnull;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7 ECHOUEE -- la colonne rang manque ou est nullable'; END IF;
  SELECT count(*) INTO v_n FROM pg_attrdef d
   JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
   WHERE d.adrelid = 'public.justice_indemnites'::regclass AND a.attname = 'rang'
     AND pg_get_expr(d.adbin, d.adrelid) LIKE 'nextval%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7 ECHOUEE -- rang n''est pas adossee a une sequence'; END IF;

  RAISE NOTICE 'LES 7 PREUVES SONT VERTES.';
END $preuves$;
