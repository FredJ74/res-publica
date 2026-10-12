-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012144006 (UTC), nom
-- `tribunal_appel_du_condamne_et_le_declencheur_de_verdict`.
-- Le registre passe de 688 a 689 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 9a95827dbda874b80d1482ef3340ec6c, 8434 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE TRIBUNAL, CHEMIN CRITIQUE (6/6) -- L'APPEL DU CONDAMNE ETAIT ENREGISTRE ET SANS EFFET
--
-- TROISIEME FOIS EN DEUX JOURS, ET C'EST LA MEME FAMILLE : « decide au serveur n'est pas
-- applique au serveur ». `plaintes_epingler_verdict` RESTAURE le `status` des que l'auteur de
-- l'ecriture n'est pas une autorite judiciaire -- et celui qui interjette appel est, le plus
-- souvent, LE CONDAMNE. Mesure du banc : `justice_appel_ouvrir` rendait `ok: true`, le dossier
-- recevait `appel_par`, `appel_qualite`, `appel_jour`, `appel_ouvert_le`... et son statut restait
-- `jugee`. Le juge ne voyait donc jamais l'appel.
--
-- LE LAISSEZ-PASSER EXISTAIT DEJA : `rp.verdict_interne`, que `plainte_defendre` emploie depuis
-- le 10 octobre, ouvre le declencheur pour UNE ecriture. Le declencheur n'est PAS elargi aux
-- condamnes -- il protege precisement le dossier contre eux ; la bonne granularite est l'ecriture
-- nommee, pas la categorie d'acteur.
--
-- ET LA PORTE RELIT CE QU'ELLE VIENT D'ECRIRE. Un `ok` qui ne verifie pas son propre effet est la
-- facon la plus silencieuse de mentir, et ce depot l'a appris trois fois.
--
-- SA PREMIERE PREUVE P4 A REFUSE UN PREMIER ENVOI : elle cherchait le mot « appel » dans le
-- declencheur pour verifier qu'il n'avait pas ete elargi, et l'a trouve dans
-- `est_appel_serveur()`. Le piege du mot, quatrieme fois en deux jours.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'APPEL DU CONDAMNE ETAIT ENREGISTRE ET SANS EFFET
-- 12 octobre 2026 -- correctif
--
-- TROISIEME FOIS EN DEUX JOURS, ET C'EST LA MEME FAMILLE : « DECIDE AU SERVEUR N'EST PAS APPLIQUE
-- AU SERVEUR ». `plaintes_epingler_verdict` est un declencheur BEFORE UPDATE sur
-- `plaintes_en_cours` : il RESTAURE `status`, `circonstanceAttenuante` et `aggravation` des que
-- l'auteur de l'ecriture n'est pas une autorite judiciaire. Or celui qui interjette appel est, le
-- plus souvent, LE CONDAMNE -- qui n'est evidemment pas une autorite.
--
-- MESURE DU BANC : `justice_appel_ouvrir` rendait `ok: true`, le dossier recevait `appel_par`,
-- `appel_qualite`, `appel_jour` et `appel_ouvert_le`... et son `status` restait `jugee`. L'appel
-- etait donc interjete ET SANS EFFET : le juge ne le voyait jamais, et `justice_appel_juger`
-- refusait « pas_en_appel ».
--
-- LE LAISSEZ-PASSER EXISTE DEJA, ET C'EST LE BON OUTIL. `plainte_defendre` l'emploie depuis le
-- 10 octobre : `rp.verdict_interne` ouvre le declencheur pour UNE ecriture, et seulement pour
-- elle. La porte a deja verifie l'autorite -- condamne ou Procureur du pays, dans la fenetre --
-- donc le declencheur n'a rien a reverifier ; ce qu'il protege, c'est l'ecriture DIRECTE d'un
-- navigateur, et celle-la n'a pas le laissez-passer.
--
-- POURQUOI PAS ELARGIR LE DECLENCHEUR AUX CONDAMNES. Parce qu'il protege precisement le dossier
-- CONTRE eux : un accuse ne doit pas pouvoir reecrire son statut. Le laissez-passer de portee est
-- la bonne granularite -- une ecriture nommee, pas une categorie d'acteurs. Le declencheur n'est
-- donc PAS touche par cette migration.
--
-- ET LA PORTE RELIT CE QU'ELLE VIENT D'ECRIRE. C'est la lecon des trois defauts de cette famille :
-- un `ok` qui ne verifie pas son propre effet est la facon la plus silencieuse de mentir.
--
-- PREUVES STRUCTURELLES -- 4.

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
$$;
COMMENT ON FUNCTION public.justice_appel_ouvrir(text) IS
  'Interjette appel d''un jugement de premiere instance : le CONDAMNE ou le PROCUREUR du pays, dans les DEUX jours de l''horloge du pays, UNE SEULE fois par affaire. Pose le laissez-passer `rp.verdict_interne` le temps de son ecriture -- sans lui, `plaintes_epingler_verdict` restaure le statut, parce que le condamne n''est pas une autorite judiciaire -- puis RELIT le statut en base : une porte qui rend ok sans avoir rien applique est le defaut recurrent de ce depot.';

DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_appel_ouvrir';

  -- P1 : LE LAISSEZ-PASSER EST POSE PUIS RETIRE. Sans le retrait il durerait toute la transaction.
  IF position('set_config(''rp.verdict_interne'', ''on'', true)' IN v_txt) = 0
     OR position('set_config(''rp.verdict_interne'', '''', true)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le laissez-passer n''est pas pose puis retire'; END IF;

  -- P2 : IL ENTOURE L'ECRITURE, et ne l'ouvre pas apres coup.
  IF position('set_config(''rp.verdict_interne'', ''on'', true)' IN v_txt)
     > position('UPDATE public.plaintes_en_cours' IN v_txt) THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le laissez-passer est pose apres l''ecriture'; END IF;

  -- P3 : L'EFFET EST RELU EN BASE. La porte ne rend pas ok sur une ecriture epinglee.
  IF position('statut_non_applique' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la porte ne relit pas le statut qu''elle vient d''ecrire'; END IF;

  -- P4 : LE DECLENCHEUR HONORE TOUJOURS LE LAISSEZ-PASSER, et il n'a pas ete touche. L'ASSERTION
  -- NE PORTE PAS SUR LE MOT « appel » : la premiere version de cette preuve a echoue dessus,
  -- parce que `est_appel_serveur()` le contient. Le piege du mot, quatrieme fois en deux jours.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plaintes_epingler_verdict';
  IF position('rp.verdict_interne' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le declencheur n''honore plus le laissez-passer'; END IF;
  IF position('''appel''' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le declencheur traite un statut d''appel au lieu de rester intact'; END IF;

  RAISE NOTICE 'LES 4 PREUVES SONT VERTES.';
END $preuves$;
