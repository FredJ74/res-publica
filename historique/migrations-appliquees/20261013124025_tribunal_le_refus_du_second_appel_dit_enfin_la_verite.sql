-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013124025 (UTC), nom
-- `tribunal_le_refus_du_second_appel_dit_enfin_la_verite`.
-- Le registre passe de 708 a 709 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 e6424cf8085909285f467ebcb271fc18, 9441 caracteres, 1
-- instruction au registre. Empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE REGISTRE STOCKE LE MEME CORPS SUIVI D'UN SAUT DE LIGNE FINAL : md5
-- 7b3c64cf83b7e4fed8f38125672078b6, 9442 caracteres. Les deux ont ete compares : le corps
-- archive ici est, au saut de ligne final pres, OCTET POUR OCTET celui que Supabase a
-- enregistre.
--
-- LE REFUS DU SECOND APPEL DIT ENFIN LA VERITE
--
-- `justice_appel_ouvrir` controlait le STATUT avant l'unicite : un condamne qui tentait un second
-- appel lisait « aucun jugement de premiere instance n'a ete rendu » alors que le sien avait deja
-- ete reexamine en appel. Deux bancs acceptaient DEUX motifs de refus depuis le 12 octobre et
-- nommaient la dette dans leur commentaire. Elle est payee.
--
-- CE QUI CHANGE : l'ORDRE des gardes -- definitif, puis unicite, puis statut -- et un motif de
-- plus, `jugement_d_appel_definitif`. AUCUNE REGLE DE JEU : un second appel etait impossible
-- par trois chemins, il l'est toujours par les memes trois. Seul le libelle devient vrai.
--
-- PREUVES STRUCTURELLES -- 6, dont une sur l'ORDRE des trois gardes.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- UN SECOND APPEL EST REFUSE PARCE QUE LE PREMIER A EU LIEU, ET LE REFUS LE DIT ENFIN.
--
-- LE DEFAUT, EXACTEMENT. `justice_appel_ouvrir` verifiait le STATUT avant l'unicite. Une fois
-- l'appel interjete, l'affaire porte le statut `appel` ; une fois l'appel juge, `jugee_appel`.
-- Ni l'un ni l'autre n'est dans la liste `('jugee', 'relaxe')`, et la porte repondait donc
-- `pas_de_jugement_de_premiere_instance` -- « aucun jugement de premiere instance n'a ete
-- rendu » -- a un condamne dont le jugement de premiere instance avait non seulement ete rendu,
-- mais deja reexamine en appel. Le refus etait JUSTE et son motif MENSONGER.
--
-- Deux bancs le constataient depuis le 12 octobre en acceptant DEUX motifs de refus et en
-- nommant la dette dans leur commentaire : « le libelle exact est note comme une dette
-- d'ergonomie, pas de securite ». C'est cette dette qui est payee ici.
--
-- CE QUI CHANGE, ET RIEN D'AUTRE : l'ORDRE des gardes, et un motif de refus de plus.
--   1. la procedure simplifiee n'ouvre aucun appel (inchange) ;
--   2. un jugement d'appel DEFINITIF ferme la voie -- motif neuf, `jugement_d_appel_definitif` ;
--   3. un appel DEJA interjete la ferme aussi -- `appel_deja_interjete`, qui existait, remonte
--      simplement AVANT le controle de statut ;
--   4. et faute de jugement de premiere instance, le motif d'origine, desormais rendu dans le
--      seul cas ou il est vrai.
--
-- AUCUNE REGLE DE JEU NE CHANGE. Un second appel etait impossible avant cette migration -- par
-- le statut, par le test de `appel_ouvert_le` et par le compare-and-swap de l'ecriture -- et il
-- reste impossible par les memes trois chemins. Seul le libelle du refus devient vrai. Aucune
-- fenetre, aucun delai, aucune autorite n'est touche.

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

  -- LE SECOND EXAMEN A DEJA EU LIEU, ET IL EST DEFINITIF. Ce refus-ci precede tous les autres :
  -- c'est le seul etat ou l'affaire est DEFINITIVEMENT close du cote judiciaire, et le dire est
  -- plus utile que n'importe quel autre motif.
  IF coalesce(v_a ->> 'status', '') = 'jugee_appel'
     OR coalesce((v_a ->> 'definitif')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_d_appel_definitif',
                              'statut', v_a ->> 'status',
                              'juge_appel', v_a ->> 'juge_appel'); END IF;

  -- L'UNICITE AVANT LE STATUT. C'est l'inversion qui paie la dette : tant que ce test venait
  -- apres celui du statut, il n'etait jamais atteint sur une affaire en appel.
  IF v_a ? 'appel_ouvert_le' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_deja_interjete',
                              'par', v_a ->> 'appel_par',
                              'qualite', v_a ->> 'appel_qualite'); END IF;

  IF coalesce(v_a ->> 'status', '') NOT IN ('jugee', 'relaxe') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jugement_de_premiere_instance',
                              'statut', v_a ->> 'status'); END IF;

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

-- =============================================================================================
-- PREUVES STRUCTURELLES
-- =============================================================================================
DO $$
DECLARE v_src text; v_n integer; v_i1 integer; v_i2 integer; v_i3 integer;
BEGIN
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_appel_ouvrir';

  -- P1. LE MOTIF NEUF EXISTE, et il nomme le jugement d appel.
  IF v_src !~ 'jugement_d_appel_definitif' OR v_src !~ 'jugee_appel' THEN
    RAISE EXCEPTION 'P1 ECHOUEE : le refus du second appel ne nomme pas le jugement d appel';
  END IF;

  -- P2. LES TROIS AUTRES MOTIFS SURVIVENT : aucun n est perdu au passage.
  IF v_src !~ 'appel_exclu_procedure_simplifiee'
     OR v_src !~ 'appel_deja_interjete'
     OR v_src !~ 'pas_de_jugement_de_premiere_instance'
     OR v_src !~ 'fenetre_appel_fermee'
     OR v_src !~ 'autorite_refusee' THEN
    RAISE EXCEPTION 'P2 ECHOUEE : un motif de refus a disparu';
  END IF;

  -- P3. L ORDRE EST LE BON, ET C EST TOUT LE CORRECTIF : definitif, puis unicite, puis statut.
  v_i1 := position('jugement_d_appel_definitif' in v_src);
  v_i2 := position('appel_deja_interjete' in v_src);
  v_i3 := position('pas_de_jugement_de_premiere_instance' in v_src);
  IF NOT (v_i1 > 0 AND v_i1 < v_i2 AND v_i2 < v_i3) THEN
    RAISE EXCEPTION 'P3 ECHOUEE : l ordre des gardes est % / % / %', v_i1, v_i2, v_i3;
  END IF;

  -- P4. LES TROIS VERROUS D UNICITE SONT TOUJOURS LA : le test de la cle, la garde de statut du
  -- compare-and-swap, et le NOT de la cle dans le WHERE. Le libelle change, la securite non.
  IF v_src !~ 'NOT \(data::jsonb \? ''appel_ouvert_le''\)'
     OR v_src !~ '\(data::jsonb ->> ''status''\) = \(v_a ->> ''status''\)' THEN
    RAISE EXCEPTION 'P4 ECHOUEE : un verrou d unicite de l ecriture a disparu';
  END IF;

  -- P5. LA PORTE RESTE DEFINER a search_path fige, sans surcharge.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_appel_ouvrir'
     AND p.prosecdef AND array_to_string(p.proconfig, ',') LIKE '%search_path=public, pg_temp%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 ECHOUEE : % porte(s) conforme(s), 1 attendue', v_n; END IF;

  -- P6. LA FENETRE D APPEL N A PAS BOUGE : deux jours, et c est le fait declare qui le dit.
  IF public.justice_fenetre_appel_jours() <> 2 THEN
    RAISE EXCEPTION 'P6 ECHOUEE : la fenetre d appel vaut % jour(s)', public.justice_fenetre_appel_jours();
  END IF;

  RAISE NOTICE 'LES 6 PREUVES STRUCTURELLES SONT VERTES.';
END $$;
