-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012142231 (UTC), nom
-- `tribunal_execution_immediate_et_appel`.
-- Le registre passe de 685 a 686 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 bc5b905831c25037fc88f7b76a6a1f19, 34963 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE TRIBUNAL, CHEMIN CRITIQUE (3/6) -- LA PEINE S'EXECUTE, ET L'APPEL NE L'ARRETE PAS
--
-- TROIS CHOSES QUI N'EXISTAIENT PAS. (1) Le jugement n'etait pas EXECUTOIRE : il fallait qu'un
-- commissaire appelle `justice_executer_condamnation` pour que la detention s'ouvre, donc sans
-- commissaire joueur une condamnation restait une feuille de papier. (2) L'APPEL n'existait
-- nulle part -- le cahier des charges precedent le disait « deja decide », il ne l'etait que sur
-- le papier. (3) Le delai de premiere instance ne s'opposait pas a la sentence : le trou etait
-- nomme dans le rapport de la tranche precedente, il est bouche ici.
--
-- L'APPEL N'EST PAS SUSPENSIF, et c'est tout le sel de la regle : la peine court pendant les deux
-- jours de la fenetre. Si l'appel allege ou relaxe, on compte les jours REELLEMENT PURGES au-dela
-- de la peine definitive. Le premier jugement garde son identifiant au registre ; le second est
-- DEFINITIF. Un dossier regle en procedure simplifiee n'ouvre aucun appel.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LA PEINE S'EXECUTE TOUT DE SUITE, ET L'APPEL NE L'ARRETE PAS
-- 12 octobre 2026 -- §E du cahier des charges
--
-- TROIS CHOSES QUI N'EXISTAIENT PAS.
--
-- 1. LE JUGEMENT N'ETAIT PAS EXECUTOIRE. `justice_rendre_sentence` inscrivait la ligne au
--    registre avec `executee = false`, et il fallait qu'un COMMISSAIRE appelle
--    `justice_executer_condamnation` pour que la detention s'ouvre. Sans commissaire joueur, une
--    condamnation restait une feuille de papier. La sentence ouvre desormais la detention
--    elle-meme. L'ancienne porte du commissaire reste en place et repond `deja_executee` : on ne
--    casse pas un chemin existant, on le rend inutile.
--
-- 2. L'APPEL N'EXISTAIT PAS. Le cahier des charges precedent le disait « deja decide » ; il
--    l'etait sur le papier, aucune ligne de code ne le portait. Il est construit ici : fenetre de
--    DEUX JOURS apres le jugement de premiere instance, UN SEUL appel par affaire, le PREMIER qui
--    le declenche l'ouvre, et il peut etre declenche par le CONDAMNE ou par le PROCUREUR. Le MEME
--    juge le juge -- ce n'est pas une juridiction superieure, c'est un second examen.
--
-- 3. L'APPEL N'EST PAS SUSPENSIF, et c'est tout le sel de la regle : la peine court pendant les
--    deux jours de la fenetre. Si l'appel allege ou relaxe, on compte les jours REELLEMENT
--    PURGES au-dela de la peine definitive -- jamais l'ecart theorique entre les deux jugements.
--    Huit jours prononces, deux purges, relaxe : deux jours indus. Huit prononces, deux purges,
--    quatre en appel : zero indu, et deux jours restent a purger. Le calcul se fait en JOURNEES
--    de jeu, celles que `detentions` compte deja ; aucune proratisation horaire n'est inventee.
--
-- LE PREMIER JUGEMENT N'EST JAMAIS EFFACE. La ligne d'appel porte son propre identifiant
-- (`jug-app-<affaire>`), donc les deux verdicts coexistent au registre et dans la chronologie.
-- Le second est DEFINITIF : aucun appel d'appel.
--
-- ET LA PROCEDURE SIMPLIFIEE N'Y A PAS DROIT. Un dossier marque `procedure_simplifiee` est clos
-- definitivement par son jet : la porte de l'appel le refuse explicitement.
--
-- AU PASSAGE, LE DELAI DE JUGEMENT S'OPPOSE ENFIN A LA SENTENCE. La tranche precedente l'avait
-- pose sur la garde du parquet, sur `justice_relaxer` et sur `juge_suite_apres_abandon`, mais PAS
-- sur `justice_rendre_sentence` -- le trou etait nomme dans son rapport. Il est bouche.
--
-- PREUVES STRUCTURELLES -- 12.

INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES
 ('appel_ouvert', 'Appel interjete', 'accuse',
  'Le condamne ou le Procureur a interjete appel dans la fenetre de deux jours. Un seul appel par affaire : le premier qui le declenche l''ouvre. L''acte nomme QUI l''a declenche, et rien de plus -- ni motif, ni qualite de la demande.'),
 ('jugement_appel', 'Jugement d''appel', 'juge',
  'Le second examen, par le MEME juge, et il est DEFINITIF. Il peut confirmer, alleger, aggraver, relaxer ou requalifier dans les memes bornes que la premiere instance. Le premier jugement reste au registre.'),
 ('indemnisation', 'Indemnisation pour detention executee a tort', 'serveur',
  'Des jours de prison ont ete purges au-dela de la peine devenue definitive. L''acte consigne le NOMBRE de jours indus et le montant du. Ce n''est pas un jugement de valeur sur la premiere decision : c''est une difference arithmetique entre ce qui a ete execute et ce qui etait du.');

-- ============================================================================================
-- 1. LA FENETRE D'APPEL, DECLAREE UNE SEULE FOIS
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_fenetre_appel_jours()
RETURNS integer LANGUAGE sql IMMUTABLE AS $$ SELECT 2 $$;
COMMENT ON FUNCTION public.justice_fenetre_appel_jours() IS
  'La fenetre d''appel, en jours de jeu apres le jugement de premiere instance. Deux. La porte qui ouvre l''appel est la seule a la lire.';
REVOKE ALL ON FUNCTION public.justice_fenetre_appel_jours() FROM PUBLIC;

-- ============================================================================================
-- 2. LES JOURS REELLEMENT PURGES
-- ============================================================================================
-- EN JOURNEES DE JEU, ET SUR LA DETENTION OUVERTE PAR CE JUGEMENT. Si elle est deja close, on
-- compte jusqu'a sa fin effective ; sinon jusqu'au jour courant. Le jour d'ouverture compte zero :
-- `detentions` pose `jour_fin = jour_debut + jours`, donc « purge » et « jour_courant moins
-- jour_debut » sont la meme grandeur, et c'est celle que le reste du systeme utilise deja.
CREATE OR REPLACE FUNCTION public.justice_jours_purges(p_detention_id text, p_pays text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT greatest(0,
           coalesce(d.jour_fin_effective, public.jour_de_jeu_pays(coalesce(p_pays, d.country)))
           - d.jour_debut)
    FROM public.detentions d WHERE d.id = p_detention_id;
$$;
COMMENT ON FUNCTION public.justice_jours_purges(text, text) IS
  'Les jours de prison REELLEMENT PURGES sur une detention, en journees de jeu : jusqu''a sa fin effective si elle est close, jusqu''au jour courant sinon. C''est cette grandeur, et jamais l''ecart entre deux jugements, qui fonde l''indemnisation.';
REVOKE ALL ON FUNCTION public.justice_jours_purges(text, text) FROM PUBLIC;

-- ============================================================================================
-- 3. LA SENTENCE DEVIENT EXECUTOIRE SUR LE CHAMP
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
  v_det record; v_exec jsonb; v_executee boolean := false;
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

  -- LE DELAI DE PREMIERE INSTANCE S'OPPOSE ICI AUSSI (12 octobre 2026). Le trou etait nomme dans
  -- le rapport de la tranche precedente : la garde du parquet et les deux autres portes du juge
  -- lisaient l'echeance, celle-ci non.
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

  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_j.nom;
  v_jour := coalesce(v_jour, 1);
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

  -- IMMEDIATEMENT EXECUTOIRE (12 octobre 2026). La peine ne depend plus d'un commissaire joueur
  -- pour commencer a courir. Une peine sans jours -- amende seule, amenagement -- n'ouvre
  -- evidemment aucune detention, et un accuse DEJA detenu n'en recoit pas une seconde : la
  -- condamnation reste inscrite et non executee, et l'ancienne porte du commissaire pourra la
  -- reprendre. C'est la garde `cible_deja_detenue` d'origine, conservee mot pour mot.
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
           'appel_jusqu_au_jour', v_jour + public.justice_fenetre_appel_jours(),
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
    'appel_jusqu_au_jour', v_jour + public.justice_fenetre_appel_jours());
END;
$$;
COMMENT ON FUNCTION public.justice_rendre_sentence(text, text, text, integer, integer) IS
  'Le jugement de PREMIERE INSTANCE, et il est IMMEDIATEMENT EXECUTOIRE : la detention s''ouvre dans la meme transaction, sans dependre d''un commissaire joueur. Une peine sans jours n''ouvre rien, et un accuse deja detenu n''en recoit pas une seconde. Le dossier porte desormais la date de son jugement et le dernier jour utile pour interjeter appel.';

-- ============================================================================================
-- 4. OUVRIR L'APPEL
-- ============================================================================================
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

  -- LA PROCEDURE SIMPLIFIEE N'OUVRE AUCUN APPEL : son jet est definitif, c'est la regle.
  IF coalesce((v_a ->> 'procedure_simplifiee')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_exclu_procedure_simplifiee'); END IF;
  IF coalesce(v_a ->> 'status', '') NOT IN ('jugee', 'relaxe') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jugement_de_premiere_instance',
                              'statut', v_a ->> 'status'); END IF;
  IF v_a ? 'appel_ouvert_le' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_deja_interjete',
                              'par', v_a ->> 'appel_par'); END IF;

  -- QUI PEUT : LE CONDAMNE, OU LE PROCUREUR DU PAYS. Le PREMIER qui le declenche l'ouvre.
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

  -- LA FENETRE : DEUX JOURS APRES LE JUGEMENT. L'echeance est inscrite au dossier par la
  -- sentence ; le repli relit le registre pour les dossiers juges avant cette migration.
  v_limite := nullif(v_a ->> 'appel_jusqu_au_jour', '')::integer;
  IF v_limite IS NULL THEN
    SELECT j.jour + public.justice_fenetre_appel_jours() INTO v_limite
      FROM public.jugements j WHERE j.id = 'jug-' || p_affaire_id;
  END IF;
  IF v_limite IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_introuvable'); END IF;
  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  IF v_jour > v_limite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fenetre_appel_fermee',
                              'jour', v_jour, 'limite', v_limite); END IF;

  -- COMPARE-AND-SWAP : deux appels simultanes se serialisent, et un seul gagne.
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
                            'qualite', v_qui, 'jour', v_jour);
END;
$$;
COMMENT ON FUNCTION public.justice_appel_ouvrir(text) IS
  'Interjette appel d''un jugement de premiere instance : le CONDAMNE ou le PROCUREUR du pays, dans les DEUX jours, UNE SEULE fois par affaire -- le premier qui le declenche l''ouvre. Un dossier regle par la procedure simplifiee est exclu : son jet est definitif. L''appel n''est PAS suspensif : la peine continue de courir.';
REVOKE ALL ON FUNCTION public.justice_appel_ouvrir(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.justice_appel_ouvrir(text) TO authenticated;

-- ============================================================================================
-- 5. JUGER L'APPEL
-- ============================================================================================
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

  -- LE MEME JUGE. Ce n'est pas une juridiction superieure : c'est un second examen par celui qui
  -- a deja juge, et c'est la regle arretee.
  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville); END IF;
  IF coalesce(v_a ->> 'status', '') <> 'appel' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_appel', 'statut', v_a ->> 'status'); END IF;

  -- LA QUALIFICATION : celle du premier jugement par defaut, requalifiable dans les deux cas.
  v_inf := public.infraction_canonique(
             coalesce(p_infraction, v_a ->> 'qualification_finale', v_a ->> 'qualification_parquet'));
  IF v_inf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_inconnue',
      'demande', coalesce(p_infraction, v_a ->> 'qualification_finale')); END IF;

  v_jours := 0; v_amende := 0;
  IF p_verdict = 'condamnation' THEN
    IF coalesce(btrim(coalesce(p_genre, '')), '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'genre_absent'); END IF;
    -- LES MEMES BORNES QU'EN PREMIERE INSTANCE : le juge d'appel n'a pas plus de latitude que
    -- lui-meme la veille, et c'est la meule formule qui les calcule.
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

  -- LE PREMIER JUGEMENT N'EST PAS EFFACE : la ligne d'appel a son propre identifiant.
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

  -- LA DETENTION EN COURS EST RE-BASEE SUR LA PEINE DEVENUE DEFINITIVE.
  --   . deja purge autant ou plus que le definitif -> liberation immediate ;
  --   . purge moins -> la fin est ramenee (ou repoussee) a jour_debut + definitif.
  -- ET L'INDEMNITE NE PORTE QUE SUR L'EXCEDENT REELLEMENT EXECUTE, jamais sur l'ecart entre les
  -- deux jugements.
  v_det_id := nullif(v_a ->> 'detention_id', '');
  SELECT * INTO v_det FROM public.detention_active(v_a ->> 'cible');
  IF v_det.id IS NOT NULL AND (v_det_id IS NULL OR v_det.id = v_det_id) THEN
    v_det_id := v_det.id;
    v_purges := public.justice_jours_purges(v_det_id, v_pays);
    IF v_purges >= v_jours THEN
      PERFORM public.detention_clore_interne(v_a ->> 'cible', 'jugement_appel', v_jour);
      v_libere := true;
    ELSE
      UPDATE public.detentions SET jour_fin = jour_debut + v_jours WHERE id = v_det_id;
    END IF;
  ELSIF v_det_id IS NOT NULL THEN
    v_purges := public.justice_jours_purges(v_det_id, v_pays);
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
COMMENT ON FUNCTION public.justice_appel_juger(text, text, text, text, integer, integer) IS
  'Le jugement d''APPEL, par le MEME juge, et il est DEFINITIF. Il confirme, allege, aggrave, relaxe ou requalifie dans les MEMES bornes qu''en premiere instance. Le premier jugement reste au registre sous son identifiant. La detention en cours est re-basee sur la peine devenue definitive -- liberation immediate si elle est deja purgee -- et l''indemnite ne porte que sur les jours REELLEMENT EXECUTES en excedent : jamais sur l''ecart theorique entre les deux decisions.';
REVOKE ALL ON FUNCTION public.justice_appel_juger(text, text, text, text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.justice_appel_juger(text, text, text, text, integer, integer) TO authenticated;

-- ============================================================================================
-- 6. LE JUGE VOIT LES DOSSIERS EN APPEL
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.juge_dossiers()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_nom text; v_pays text; v_ville text;
BEGIN
  SELECT d.name, d.country, d.poste ->> 'city' INTO v_nom, v_pays, v_ville
    FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'juge' LIMIT 1;
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge'); END IF;
  v_ville := coalesce(v_ville, 'capitale');

  RETURN jsonb_build_object('ok', true, 'juge', v_nom, 'ville', v_ville,
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
     WHERE p.country = v_pays AND p.city IS NOT DISTINCT FROM v_ville
       AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
       AND (p.data::jsonb ->> 'status') IN ('saisie', 'abandon_demande', 'appel')));
END;
$$;
COMMENT ON FUNCTION public.juge_dossiers() IS
  'Les dossiers du tribunal du juge, avec leur chronologie complete : ceux dont il est regulierement SAISI, ceux ou le parquet a demande l''abandon, et depuis le 12 octobre 2026 ceux qui sont EN APPEL. Un dossier au parquet n''y figure pas.';

DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : LES TROIS TYPES D'ACTES SONT AU REGISTRE.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes_types
   WHERE type IN ('appel_ouvert', 'jugement_appel', 'indemnisation');
  IF v_n <> 3 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % type(s) neufs au lieu de 3', v_n; END IF;

  -- P2 : LA FENETRE EST DECLAREE UNE FOIS, ET ELLE VAUT DEUX JOURS.
  IF public.justice_fenetre_appel_jours() <> 2 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la fenetre d''appel ne vaut pas 2 jours'; END IF;

  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_rendre_sentence';

  -- P3 : LA SENTENCE OUVRE LA DETENTION ELLE-MEME.
  IF position('public.detention_ouvrir_interne(' IN v_txt) = 0
     OR position('UPDATE public.jugements SET executee = true' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la sentence n''est pas executoire'; END IF;

  -- P4 : ELLE N'OUVRE RIEN SANS JOURS, ET RIEN SUR UN DEJA-DETENU.
  IF position('IF v_jours > 0 THEN' IN v_txt) = 0
     OR position('IF v_det.id IS NULL THEN' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la sentence ouvre une detention sans condition'; END IF;

  -- P5 : LE DELAI DE PREMIERE INSTANCE S'OPPOSE ENFIN A LA SENTENCE -- le trou nomme dans le
  -- rapport precedent.
  IF position('public.affaire_delai_expire(v_a, v_pays)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la sentence n''oppose pas le delai'; END IF;

  -- P6 : ELLE INSCRIT LA FENETRE D'APPEL AU DOSSIER, et la lit au lieu de la recopier.
  IF position('public.justice_fenetre_appel_jours()' IN v_txt) = 0
     OR position('''appel_jusqu_au_jour''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- la fenetre d''appel n''est pas inscrite au dossier'; END IF;

  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_appel_ouvrir';

  -- P7 : LES DEUX QUALITES, ET ELLES SEULES.
  IF position('''condamne''' IN v_txt) = 0 OR position('public.parquet_moi()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- le condamne ou le parquet ne peuvent pas interjeter'; END IF;

  -- P8 : UN SEUL APPEL, PAR COMPARE-AND-SWAP -- deux clics simultanes n'en ouvrent pas deux.
  IF position('NOT (data::jsonb ? ''appel_ouvert_le'')' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- l''unicite de l''appel n''est pas en compare-and-swap'; END IF;

  -- P9 : LA PROCEDURE SIMPLIFIEE EST EXCLUE DE L'APPEL.
  IF position('appel_exclu_procedure_simplifiee' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- un dossier de procedure simplifiee peut faire appel'; END IF;

  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_appel_juger';

  -- P10 : L'INDEMNITE PORTE SUR LES JOURS PURGES, PAS SUR L'ECART DES JUGEMENTS.
  IF position('greatest(0, coalesce(v_purges, 0) - v_jours)' IN v_txt) = 0
     OR position('public.justice_jours_purges(' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- l''indemnite ne se calcule pas sur l''execution reelle'; END IF;
  IF position('peine_premiere_instance' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- le premier jugement n''est pas conserve a cote du second'; END IF;

  -- P11 : LES BORNES DE L'APPEL SONT CELLES DE LA PREMIERE INSTANCE, par la MEME formule.
  IF position('public.justice_peine_calcul(v_inf, p_genre' IN v_txt) = 0
     OR position('peine_hors_bornes' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- le juge d''appel n''est pas borne'; END IF;

  -- P12 : LE JUGEMENT D'APPEL A SON PROPRE IDENTIFIANT, donc il n'ecrase pas le premier.
  IF position('''jug-app-'' || p_affaire_id' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- le jugement d''appel ecraserait le premier'; END IF;
  -- Et le juge voit les dossiers en appel.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'juge_dossiers';
  IF position('''saisie'', ''abandon_demande'', ''appel''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- le juge ne voit pas les dossiers en appel'; END IF;

  RAISE NOTICE 'LES 12 PREUVES SONT VERTES.';
END $preuves$;
