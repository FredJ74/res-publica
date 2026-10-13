-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013121827 (UTC), nom
-- `tribunal_aucun_jugement_complet_sans_audience_ouverte`.
-- Le registre passe de 705 a 706 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 508f814c4c92ff5d8bdbe73fd3552841, 36863 caracteres, 1
-- instruction au registre. Empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE REGISTRE STOCKE LE MEME CORPS SUIVI D'UN SAUT DE LIGNE FINAL : md5
-- 1a7908edb1787d4db43c49a86d091ea5, 36864 caracteres. Les deux ont ete compares : le corps
-- archive ici est, au saut de ligne final pres, OCTET POUR OCTET celui que Supabase a
-- enregistre. L'empreinte declaree ci-dessus est celle du corps tel que le verificateur le
-- mesure, c'est-a-dire debarrasse de ses sauts de ligne de bordure.
--
-- AUCUN JUGEMENT COMPLET SANS AUDIENCE OUVERTE
--
-- L'audience existait depuis le matin -- elle se fixe, elle s'ouvre, elle constate qui est la --
-- mais AUCUNE porte de jugement ne la regardait. Un juge condamnait ou relaxait une affaire
-- saisie sans que le proces ait eu lieu, ni meme ete fixe.
--
-- LE VERROU EST POSE SUR QUATRE PORTES, pas sur un bouton : la condamnation de premiere
-- instance, la relaxe, le jugement d'appel, et -- surtout -- `justice_condamner`, la porte par
-- laquelle la SANCTION tombe avant tout archivage, qui n'exigeait que le poste de juge et
-- acceptait un jsonb libre. La policy dormante `jugements_insertion_juge`, qui decrivait une
-- cinquieme voie, part avec.
--
-- CE QUI RESTE INTACT, ET C'EST EXPLICITE : la PROCEDURE SIMPLIFIEE (`plainte_defendre`), qui
-- juge au statut `au_parquet` et n'emprunte aucune des quatre portes, et le mandat du DESERTEUR
-- (`type` 'militaire'), qui ne juge rien.
--
-- PREUVES STRUCTURELLES -- 9.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- AUCUN JUGEMENT COMPLET N'EST RENDU AVANT L'OUVERTURE DE L'AUDIENCE.
--
-- CE QUI MANQUAIT. L'audience existe depuis le 13 octobre au matin : elle se FIXE
-- (`justice_audience_fixer`, J+3 sauf consentement explicite du prevenu) et elle s'OUVRE
-- (`justice_audience_ouvrir`, le jour venu, le juge PHYSIQUEMENT dans sa salle). Mais aucune des
-- portes de jugement ne la REGARDAIT : `justice_rendre_sentence`, `justice_relaxer` et
-- `justice_appel_juger` passaient du statut `saisie` au barreme sans jamais demander si le proces
-- avait eu lieu. Un juge pouvait condamner une affaire dont l'audience n'etait pas meme fixee.
--
-- LA REGLE POSEE ICI, ET RIEN DE PLUS. Pour une affaire relevant de la procedure judiciaire
-- COMPLETE : l'audience doit avoir ete fixee selon les regles existantes -- ce que la porte
-- d'ouverture verifie deja -- et elle doit avoir ete EFFECTIVEMENT OUVERTE. Tant qu'elle ne l'est
-- pas, ni condamnation ni relaxe. Le predicat est celui qui existait deja,
-- `affaire_audience_ouverte(data)`, et il n'en est pas cree d'autre : l'ouverture se LIT a la
-- presence de la cle `audience_ouverte_le`, que seule `justice_audience_ouvrir` pose.
--
-- CE QUI N'EST PAS CONCERNE, ET C'EST EXPLICITE. La PROCEDURE SIMPLIFIEE (`plainte_defendre`)
-- juge une affaire au statut `au_parquet`, ecrit elle-meme sa ligne au registre et ne passe par
-- aucune des quatre portes touchees ici : elle est, par construction, hors de ce verrou. C'est la
-- petite procedure automatique voulue par le game design, et elle reste intacte -- la preuve P7
-- le mesure.
--
-- LA PORTE DEROBEE, QUI ETAIT LA VRAIE. `justice_condamner(cible, entree)` n'exigeait que le
-- POSTE de juge : ni affaire, ni statut, ni audience, ni barreme. Son entree est un jsonb LIBRE,
-- et le nombre de jours y est la SOMME de ce que le navigateur a ecrit dans `motifs`. Or c'est
-- elle que le chemin judiciaire appelle EN PREMIER (plateau-justice-economie.js,
-- `appliquerSentence`) : la sanction tombe par cette porte, l'archivage par
-- `justice_rendre_sentence` ne vient qu'apres. Verrouiller l'archivage sans verrouiller la
-- sanction n'aurait donc verrouille rien du tout.
--
-- Elle est desormais fermee sur le genre qui la concerne : toute entree de `type` 'condamnation'
-- doit NOMMER son affaire, cette affaire doit etre au statut ou un jugement complet se rend
-- (`saisie`, ou `appel` pour le second examen), son audience doit etre ouverte, et l'appelant doit
-- etre le juge DE LA VILLE de l'affaire -- la meme regle d'autorite que les trois autres portes,
-- qui manquait ici. Le mandat de recherche du DESERTEUR porte `type` 'militaire' : il n'existe
-- dans aucune table de peines, il ne juge rien, et il reste ouvert -- la preuve P6 le mesure.
--
-- LA POLICY DORMANTE PART AVEC. `jugements_insertion_juge` autorisait en WITH CHECK une insertion
-- cliente directe dans `jugements` pour l'autorite de la ville. Elle n'a jamais pu s'appliquer --
-- aucun GRANT INSERT n'existe sur la table pour `authenticated` -- mais elle decrit par ecrit une
-- porte qui contournerait tout : barreme, affaire, audience. Une policy qu'un simple GRANT
-- reveillerait n'est pas une securite, c'est une dette. Plus aucun ecrivain client ne la reclame.
--
-- AUCUNE DONNEE N'EST TOUCHEE. Aucune affaire en cours ne change de statut, aucun jugement rendu
-- n'est relu. Les affaires actuellement `saisie` sans audience ouverte devront ouvrir leur
-- audience avant d'etre jugees -- c'est precisement la regle demandee.

-- ---------------------------------------------------------------------------------------------
-- 1. LA CONDAMNATION DE PREMIERE INSTANCE
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.justice_rendre_sentence(p_affaire_id text, p_infraction text, p_genre text, p_jours integer DEFAULT 0, p_amende integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

  -- L'AUDIENCE OBLIGATOIRE (13 octobre 2026). Une affaire qui releve de la procedure complete ne
  -- se juge pas sans proces : l'audience doit avoir ete fixee ET OUVERTE. Le refus est place
  -- APRES le delai pour ne rien changer a l'ordre des refus existants -- une affaire dont le
  -- delai a expire est morte, audience ou pas.
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte',
                              'audience_jour', (v_a ->> 'audience_jour')::integer); END IF;

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
$function$;

-- ---------------------------------------------------------------------------------------------
-- 2. LA RELAXE DE PREMIERE INSTANCE
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.justice_relaxer(p_affaire_id text, p_infraction text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer;
  v_inf text; v_lib text; v_parquet text; v_jug text; v_n integer;
BEGIN
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
  -- ON NE RELAXE QUE SUR UNE AFFAIRE REGULIEREMENT SAISIE. Sans saisine, il n'y a rien a juger.
  IF coalesce(v_a ->> 'status', '') <> 'saisie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie',
                              'statut', v_a ->> 'status');
  END IF;
  -- LE DELAI DE PREMIERE INSTANCE EST OPPOSABLE AU JUGE AUSSI (12 octobre 2026, nuit).
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer);
  END IF;
  -- L'AUDIENCE OBLIGATOIRE (13 octobre 2026). UNE RELAXE EST UN VERDICT, pas une absence de
  -- decision : elle ne se prononce pas plus qu'une condamnation avant que le proces ait eu lieu.
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte',
                              'audience_jour', (v_a ->> 'audience_jour')::integer);
  END IF;

  -- LA RELAXE PORTE SUR UNE QUALIFICATION : on relaxe de QUELQUE CHOSE. Par defaut celle du
  -- parquet ; le juge peut requalifier avant de relaxer, et les deux restent lisibles.
  v_parquet := v_a ->> 'qualification_parquet';
  v_inf := public.infraction_canonique(coalesce(p_infraction, v_parquet));
  IF v_inf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_inconnue',
                              'demande', coalesce(p_infraction, v_parquet));
  END IF;
  SELECT libelle INTO v_lib FROM public.infractions WHERE id = v_inf;
  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_j.nom;

  -- UNE RELAXE EST UN JUGEMENT, et elle a donc sa ligne au registre -- avec `peine` NULL, pas
  -- une peine de zero. C'est la difference entre « relaxe » et « condamne a rien ».
  v_jug := 'jug-' || p_affaire_id;
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_jug, v_pays, coalesce(v_ville, 'capitale'), v_a ->> 'cible', v_lib, NULL,
          v_j.nom, coalesce(v_jour, 1), true,
          jsonb_build_object('verdict', 'relaxe', 'infraction', v_inf,
            'infraction_libelle', v_lib, 'qualification_parquet', v_parquet,
            'motif_allegue', v_a ->> 'motif', 'motifs', '[]'::jsonb))
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_deja_rendu');
  END IF;

  -- REQUALIFICATION AVANT RELAXE : fait distinct, consigne avant le verdict.
  IF v_parquet IS NOT NULL AND v_inf IS DISTINCT FROM v_parquet THEN
    PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville,
      'requalification', v_j.nom, 'juge', v_parquet, v_inf);
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'relaxe',
           'verdict', 'relaxe',
           'juge', v_j.nom,
           'juge_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'qualification_finale', v_inf,
           'qualification_libelle', v_lib))::text
   WHERE id = p_affaire_id;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'relaxe',
    v_j.nom, 'juge', v_parquet, v_inf, jsonb_build_object('accuse', v_a ->> 'cible'));
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'verdict', 'relaxe',
    'jugement_id', v_jug, 'juge', v_j.nom, 'infraction', v_inf, 'libelle', v_lib);
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- 3. LE JUGEMENT D'APPEL
-- ---------------------------------------------------------------------------------------------
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

  -- L'AUDIENCE OBLIGATOIRE (13 octobre 2026). Le second examen est un jugement COMPLET et DEFINITIF :
  -- il tombe sous la meme regle. En pratique le verrou est deja satisfait -- un appel exige un
  -- jugement de premiere instance, qui exige desormais une audience ouverte, et
  -- `justice_appel_ouvrir` refuse la procedure simplifiee -- mais une porte qui ne verifie que
  -- par transitivite n'est pas verrouillee : elle l'est quand un GRANT de plus ou un statut pose
  -- a la main ne suffit pas a la franchir. AUCUNE SECONDE AUDIENCE N'EST INVENTEE : la cle
  -- `audience_ouverte_le` de la premiere instance reste sur le dossier, et c'est elle qui est lue.
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte'); END IF;

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

-- ---------------------------------------------------------------------------------------------
-- 4. LA PORTE DEROBEE : LA CONDAMNATION SANS AFFAIRE
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.justice_condamner(p_cible text, p_entree jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_juge text; v_id text; v_pays text; v_ville text; v_jours integer;
        v_aff text; v_brut text; v_a jsonb; v_aff_ville text; v_statut text; v_jl record;
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

  -- ===========================================================================================
  -- UNE CONDAMNATION JUDICIAIRE NOMME SON AFFAIRE, ET SON AFFAIRE A EU SON PROCES (13 oct. 2026)
  -- ===========================================================================================
  -- Cette porte est celle par laquelle la SANCTION tombe : `appliquerSentence` l'appelle AVANT
  -- `justice_rendre_sentence`, qui ne fait qu'archiver. Elle n'exigeait que le poste de juge.
  -- Un juge pouvait donc inscrire au registre une peine de n'importe quelle duree, sur
  -- n'importe quelle personne, hors de toute affaire, hors de tout barreme et hors de toute
  -- audience -- et `jugements` non executee EST l'avis de recherche.
  --
  -- CE QUI EST EXIGE MAINTENANT, et uniquement pour le genre qui est un jugement : l'entree de
  -- `type` 'condamnation' doit NOMMER son affaire, l'affaire doit exister, etre au statut ou un
  -- jugement complet se rend, avoir son audience OUVERTE, et l'appelant doit etre le juge DE SA
  -- VILLE -- la regle d'autorite des trois autres portes, qui manquait ici.
  --
  -- CE QUI RESTE OUVERT, EXPRES : le mandat du DESERTEUR (`type` 'militaire'), qui ne juge rien
  -- et n'attache aucune peine, et tout autre genre futur. Le verrou nomme son genre ; il ne
  -- decide pas a la place du game design ce que les autres deviennent.
  IF coalesce(p_entree ->> 'type', '') = 'condamnation' THEN
    v_aff := nullif(btrim(coalesce(p_entree ->> 'affaire_id', '')), '');
    IF v_aff IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'condamnation_sans_affaire');
    END IF;
    SELECT p.data, p.city INTO v_brut, v_aff_ville
      FROM public.plaintes_en_cours p WHERE p.id = v_aff;
    IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente', 'affaire', v_aff);
    END IF;
    v_a := v_brut::jsonb;
    SELECT * INTO v_jl FROM public.juge_de_la_ville(v_aff_ville);
    IF v_jl.nom IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville',
                                'ville', v_aff_ville);
    END IF;
    -- LA CIBLE EST CELLE DE L'AFFAIRE, pas une personne choisie a cote du dossier.
    IF coalesce(v_a ->> 'cible', '') IS DISTINCT FROM p_cible THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_etrangere_a_l_affaire',
                                'affaire', v_aff);
    END IF;
    v_statut := coalesce(v_a ->> 'status', '');
    -- `saisie` : premiere instance. `appel` : le second examen, qui est aussi un jugement complet.
    IF v_statut NOT IN ('saisie', 'appel') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie', 'statut', v_statut);
    END IF;
    IF NOT public.affaire_audience_ouverte(v_a) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte', 'affaire', v_aff);
    END IF;
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

-- ---------------------------------------------------------------------------------------------
-- 5. LA POLICY DORMANTE D'INSERTION DIRECTE AU REGISTRE DES JUGEMENTS
-- ---------------------------------------------------------------------------------------------
-- Elle n'a jamais pu s'appliquer (aucun GRANT INSERT sur `jugements` pour `authenticated`) et
-- plus aucun ecrivain client ne l'invoque. Ce qu'elle decrit -- une insertion directe au registre
-- par l'autorite de la ville -- contournerait le barreme, l'affaire et l'audience a la fois.
DROP POLICY IF EXISTS jugements_insertion_juge ON public.jugements;

-- =============================================================================================
-- PREUVES STRUCTURELLES
-- =============================================================================================
DO $$
DECLARE v_n integer; v_src text;
BEGIN
  -- P1. Les trois portes de jugement d'affaire portent le verrou, commentaires retires.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('justice_rendre_sentence', 'justice_relaxer', 'justice_appel_juger')
     AND public.sans_commentaires(p.prosrc) ~ 'affaire_audience_ouverte'
     AND public.sans_commentaires(p.prosrc) ~ 'audience_non_ouverte';
  IF v_n <> 3 THEN
    RAISE EXCEPTION 'P1 ECHOUEE : % portes de jugement sur 3 portent le verrou d audience', v_n;
  END IF;

  -- P2. La porte derobee porte le verrou ET la regle d autorite de ville qui lui manquait.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_condamner';
  IF v_src !~ 'affaire_audience_ouverte' OR v_src !~ 'audience_non_ouverte'
     OR v_src !~ 'condamnation_sans_affaire' OR v_src !~ 'juge_de_la_ville'
     OR v_src !~ 'cible_etrangere_a_l_affaire' THEN
    RAISE EXCEPTION 'P2 ECHOUEE : justice_condamner ne porte pas les cinq elements du verrou';
  END IF;

  -- P3. Les quatre portes restent SECURITY DEFINER a search_path fige.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('justice_rendre_sentence', 'justice_relaxer', 'justice_appel_juger',
                       'justice_condamner')
     AND p.prosecdef
     AND array_to_string(p.proconfig, ',') LIKE '%search_path=public, pg_temp%';
  IF v_n <> 4 THEN
    RAISE EXCEPTION 'P3 ECHOUEE : % portes sur 4 sont DEFINER a search_path fige', v_n;
  END IF;

  -- P4. Aucune surcharge n a ete creee : une signature par nom, exactement.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('justice_rendre_sentence', 'justice_relaxer', 'justice_appel_juger',
                       'justice_condamner');
  IF v_n <> 4 THEN
    RAISE EXCEPTION 'P4 ECHOUEE : % fonctions pour 4 noms -- une surcharge a ete creee', v_n;
  END IF;

  -- P5. La policy dormante d insertion directe au registre n existe plus.
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'jugements'
     AND policyname = 'jugements_insertion_juge';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE : la policy jugements_insertion_juge subsiste';
  END IF;
  -- Et aucun GRANT d ecriture cliente n a ete ouvert sur la table au passage.
  SELECT count(*) INTO v_n FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'jugements'
     AND grantee IN ('anon', 'authenticated')
     AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P5b ECHOUEE : % droits d ecriture client sur jugements', v_n;
  END IF;

  -- P6. LE MANDAT DU DESERTEUR RESTE OUVERT : le verrou ne se declenche que sur le genre
  -- 'condamnation'. La garde est nommee dans la source, et elle n est pas inconditionnelle.
  IF v_src !~ '=\s*''condamnation''\s*THEN' THEN
    RAISE EXCEPTION 'P6 ECHOUEE : la garde de justice_condamner n est pas conditionnee au genre';
  END IF;

  -- P7. LA PROCEDURE SIMPLIFIEE EST INTACTE. Elle juge au statut `au_parquet`, ecrit elle-meme
  -- sa ligne au registre et ne porte AUCUN verrou d audience -- c est la petite procedure
  -- automatique voulue par le game design.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plainte_defendre';
  IF v_src ~ 'audience_non_ouverte' THEN
    RAISE EXCEPTION 'P7 ECHOUEE : la procedure simplifiee a recu un verrou d audience';
  END IF;
  IF v_src !~ 'au_parquet' OR v_src !~ 'INSERT INTO public.jugements' THEN
    RAISE EXCEPTION 'P7b ECHOUEE : plainte_defendre ne juge plus au parquet par sa propre ecriture';
  END IF;

  -- P8. LES DEUX PORTES D AUDIENCE SONT INTOUCHEES et restent les seules a poser la cle.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND public.sans_commentaires(p.prosrc) ~ '''audience_ouverte_le''\s*,'
     AND p.proname <> 'affaire_audience_ouverte';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P8 ECHOUEE : % fonctions posent la cle audience_ouverte_le (1 attendue)', v_n;
  END IF;

  -- P9. AUCUNE AFFAIRE N A ETE TOUCHEE : le verrou est une regle de lecture, pas une migration
  -- de donnees. Aucun jugement n a ete relu, aucun statut reecrit.
  SELECT count(*) INTO v_n FROM public.plaintes_en_cours p
   WHERE (p.data::jsonb ->> 'status') = 'saisie';
  RAISE NOTICE 'P9 : % affaire(s) au statut saisie devront ouvrir leur audience avant jugement.', v_n;

  RAISE NOTICE 'LES 9 PREUVES STRUCTURELLES SONT VERTES.';
END $$;
