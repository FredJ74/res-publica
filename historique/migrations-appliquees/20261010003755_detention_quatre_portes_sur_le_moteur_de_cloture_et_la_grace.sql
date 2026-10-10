-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010003755 (UTC), nom `detention_quatre_portes_sur_le_moteur_de_cloture_et_la_grace`.
-- Le registre passe de 585 a 586 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 d342cc1e468e5ede59747d721911659c, 12 431 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- QUATRE PORTES SUR LE MOTEUR DE CLOTURE, ET LA GRACE
--
-- `presidence_gracier`, `detention_clore_purgee`, `detention_clore_evasion` et
`detention_reduire_peine` sont reecrites pour DELEGUER au moteur commun : cinq clotures, une
seule implementation. La grace presidentielle etait la troisieme instance du defaut des
liberations de desertion -- elle oubliait le drapeau QHS. `exiger_poste('president')`, la
signature et le passage de `p_jour` sont conserves a l'identique.
--
-- ELLE VA PAR PAIRE AVEC : aucun fichier du depot -- les quatre portes gardent leur contrat.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- Chantier 5 -- LES QUATRE AUTRES PORTES PASSENT PAR LE MOTEUR, ET LA GRACE CESSE D'OUBLIER.
--
-- detention_clore_interne existe depuis la migration precedente. Les trois clotures ecrites le
-- 9 octobre -- peine purgee, evasion, reduction liberatrice de l'avocat -- portaient chacune leur
-- copie de la meme sequence. Elles delegent maintenant, et ne gardent que ce qui leur est propre :
-- leur precondition et ce qu'elles rendent.
--
-- SECONDE INSTANCE DU DEFAUT, ET ELLE ETAIT DEJA UNE PORTE SERVEUR. `presidence_gracier`
-- cloturait la ligne et vidait la fiche, mais ne touchait NI le drapeau QHS NI le registre du
-- QHS : un gracie sortant du quartier de haute securite gardait son plafond de 3 PA
-- indefiniment, et restait affiche comme detenu au Ministere de la Justice. Son
-- exiger_poste('president'), sa signature et son verdict sont INCHANGES -- y compris `p_jour`,
-- que le President transmet et que le moteur respecte plutot que de lire le jour du condamne.
--
-- Et le mode `grace_presidentielle` n'etait pas affichable : `modeFinLabels`
-- (plateau-communication.js) n'en connaissait que quatre, donc une detention graciee s'affichait
-- « En cours » au registre -- l'autre moitie de « le registre ne doit pas declarer detenu un
-- personnage libre ». Les trois modes manquants sont ajoutes dans le meme commit.
--
-- RIEN NE CHANGE DANS CE QUE CES QUATRE PORTES DECIDENT : memes preconditions, memes nombres,
-- memes verdicts. La reduction de l'avocat garde son calcul (moitie du reliquat arrondie au
-- superieur, plancher d'un jour) et l'evasion ne reecrit toujours JAMAIS `jour_fin`.
--
-- Bancs en transaction annulee : 10 epreuves de non-regression sur ces quatre portes, dont le
-- QHS qui tombe desormais aussi a la grace et a la reduction liberatrice.
CREATE TEMP TABLE zz_etat_avant AS
SELECT md5(string_agg(name||':'||coalesce(arg::text,'~')||':'||coalesce(est_emprisonne::text,'~'),
                      '|' ORDER BY name COLLATE "C")) AS empreinte_personnages,
       (SELECT count(*) FROM public.detentions) AS detentions
  FROM public.personnages_donnees;

CREATE OR REPLACE FUNCTION public.presidence_gracier(p_condamne text, p_jour integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
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
END; $fn$;

CREATE OR REPLACE FUNCTION public.detention_clore_purgee()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
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
END; $fn$;

CREATE OR REPLACE FUNCTION public.detention_clore_evasion()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
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
END; $fn$;

CREATE OR REPLACE FUNCTION public.detention_reduire_peine(p_requete_acceptee boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
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
END; $fn$;

DO $$
DECLARE v_def text; v_nom text; v_av record; v_emp text; v_n int; v_moteurs int := 0;
BEGIN
  -- P1 : LES CINQ PORTES DELEGUENT, ET AUCUNE N'ECRIT PLUS LA CLOTURE ELLE-MEME.
  FOR v_nom IN SELECT unnest(ARRAY['detention_clore_purgee','detention_clore_evasion',
        'detention_reduire_peine','detention_clore_motif_eteint','presidence_gracier']) LOOP
    SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
      JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public' WHERE p.proname = v_nom;
    IF v_def IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- % absente', v_nom; END IF;
    IF position('public.detention_clore_interne' in v_def) = 0 THEN
      RAISE EXCEPTION 'P1 ECHOUEE -- % ne delegue pas au moteur', v_nom; END IF;
    IF v_def ~ 'SET\s+mode_fin' OR v_def ~ 'est_emprisonne\s*=\s*NULL'
       OR v_def ~ 'prisonniers_qhs\s+SET' THEN
      RAISE EXCEPTION 'P1 ECHOUEE -- % ecrit encore la cloture elle-meme', v_nom; END IF;
    v_moteurs := v_moteurs + 1;
  END LOOP;
  IF v_moteurs <> 5 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % porte(s) au lieu de 5', v_moteurs; END IF;

  -- P2 : LA GRACE GARDE SON AUTORITE, SA SIGNATURE ET LE JOUR DU PRESIDENT.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='presidence_gracier';
  IF position('exiger_poste(''president'')' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la grace a perdu son controle d''autorite'; END IF;
  IF position('''grace_presidentielle'', p_jour' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le jour transmis par le President n''est plus respecte'; END IF;
  IF pg_get_function_arguments((SELECT p.oid FROM pg_proc p
       JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
      WHERE p.proname='presidence_gracier')) <> 'p_condamne text, p_jour integer DEFAULT NULL::integer' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la signature de la grace a change'; END IF;

  -- P3 : LES PRECONDITIONS DES TROIS CLOTURES D'HIER SONT INTACTES.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='detention_clore_purgee';
  IF position('peine_non_purgee' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la cloture purgee a perdu sa precondition'; END IF;
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='detention_clore_evasion';
  IF v_def ~ 'SET\s+jour_fin\s*=' THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- l''evasion reecrit jour_fin'; END IF;
  IF position('''reliquat_jours'',v_reliquat' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le reliquat n''est plus rendu'; END IF;
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='detention_reduire_peine';
  IF position('ceil(v_restants / 2.0)' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le calcul de la reduction a change'; END IF;
  SELECT count(*) INTO v_n FROM regexp_matches(v_def, '''avocatUtilise'', true', 'g');
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- l''avocat est consomme % fois au lieu de 2', v_n; END IF;

  -- P4 : AUCUNE DONNEE TOUCHEE -- compare a l'etat releve avant, pas a une constante.
  SELECT * INTO v_av FROM zz_etat_avant;
  SELECT md5(string_agg(name||':'||coalesce(arg::text,'~')||':'||coalesce(est_emprisonne::text,'~'),
                        '|' ORDER BY name COLLATE "C")) INTO v_emp FROM public.personnages_donnees;
  IF v_emp IS DISTINCT FROM v_av.empreinte_personnages THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- les personnages ont bouge pendant cette migration'; END IF;
  SELECT count(*) INTO v_n FROM public.detentions;
  IF v_n <> v_av.detentions THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- detentions % -> %', v_av.detentions, v_n; END IF;

  RAISE NOTICE 'QUATRE PREUVES STRUCTURELLES VERTES.';
END $$;

DROP TABLE zz_etat_avant;