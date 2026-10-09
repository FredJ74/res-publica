-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009155036 (UTC ; 17h50 a Paris), nom
-- `detention_reduction_avocat_et_evasion_atomiques`. Le registre passe de 582 a 583 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 6cb94b69bdb2becdac3d44cdfaa1fc84, 13 207 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle ferme les deux chaines de detention que l'inventaire avait manquees, et qui portaient
-- exactement le defaut de la chaine 11 -- une liberation qui ne se persiste pas : la reduction
-- obtenue par l'avocat et l'evasion patchaient `detentions` dans un `.catch(() => {})` puis se
-- contentaient de `state.estEmprisonne = null` EN MEMOIRE. Le drapeau `avocatUtilise` n'etait pas non
-- plus une garde : pose en memoire, il ne touchait la base qu'a la sauvegarde suivante, et un
-- rechargement bien place rendait une seconde requete possible -- c'est le serveur qui la refuse.
--
-- ELLE VA PAR PAIRE AVEC LE DEPOT : `plateau-justice-economie.js` (`confirmerRequeteAvocat`,
-- `doTentativeEvasion`).
-- =============================================================================

-- Chantier 5 -- DEUX CHAINES DE DETENTION QUE L'INVENTAIRE AVAIT MANQUEES.
--
-- L'audit des ecritures de `plateau-*.js` avait nomme cinq chaines judiciaires (9 a 13). En les
-- fermant, deux AUTRES sont apparues dans le meme fichier, portant EXACTEMENT le defaut de la
-- chaine 11 -- une liberation qui ne se persiste pas :
--
--   * `confirmerRequeteAvocat` (~1656) : la reduction de peine obtenue par l'avocat patchait
--     `detentions` dans un `.catch(() => {})`, puis, si la peine tombait a zero, se contentait de
--     `state.estEmprisonne = null` EN MEMOIRE. Un joueur libere par son avocat qui fermait son
--     onglet restait incarcere en base.
--   * `tenterEvasion` (~1806) : `mode_fin = 'evasion'` avale, puis la meme liberation purement
--     locale -- alors que l'evasion est precisement le moment ou la fiche doit cesser de dire
--     « detenu » et commencer a dire « recherche ».
--
-- ET LE DRAPEAU DE L'AVOCAT N'ETAIT PAS NON PLUS UNE GARDE. `avocatUtilise` etait pose dans
-- `state.estEmprisonne` et ne touchait la base qu'a la sauvegarde SUIVANTE : un rechargement bien
-- place rendait une seconde requete possible. Il est desormais ecrit immediatement, et c'est le
-- serveur qui refuse la seconde.
--
-- LE TIRAGE DE LA PLAIDOIRIE RESTE AU NAVIGATEUR, et c'est assume. Il lit la DUP effective du
-- joueur et consomme un bonus de benediction, deux valeurs qui vivent dans l'etat client ; le
-- descendre exigerait d'en recopier le calcul cote serveur, donc de creer la divergence qu'on
-- passe la journee a supprimer. Ce que la porte reprend, c'est le MONTANT de la reduction --
-- moitie du reliquat arrondie au superieur, plancher d'un jour -- que le navigateur ne dicte
-- plus. Et l'avocat est consomme dans les DEUX cas, requete acceptee ou refusee : c'est la regle
-- d'origine, rendue fiable.
--
-- RIEN D'AUTRE NE CHANGE : memes nombres (11 jours restants donnent -6 et il en reste 5), meme
-- mode de fin `anticipee_avocat`, et pour l'evasion `jour_fin` n'est JAMAIS reecrit -- la peine
-- d'origine reste identifiable telle quelle, le reliquat etant rendu a part.
--
-- Bancs en transaction annulee : 6 epreuves sur les deux portes, puis 4 de plus sur la nouvelle
-- signature de la reduction.
CREATE OR REPLACE FUNCTION public.detention_reduire_peine(p_requete_acceptee boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_moi text; v_jour integer; v_peine jsonb; v_det record;
        v_fin integer; v_restants integer; v_reduction integer; v_nouveau integer;
        v_jours integer; v_libere boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT coalesce(day,1), est_emprisonne INTO v_jour, v_peine
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  IF coalesce((v_peine->>'avocatUtilise')::boolean,false) THEN
    RETURN jsonb_build_object('ok',false,'raison','avocat_deja_utilise'); END IF;

  -- L'AVOCAT EST CONSOMME MEME QUAND LE JUGE REFUSE. Regle d'origine ; elle etait posee en
  -- memoire puis persistee seulement a la sauvegarde suivante.
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

  -- La reduction ne reecrit JAMAIS motifs[].jours : la peine d'origine par motif reste
  -- historiquement identifiable, et la reduction vit a part dans reduction_jours.
  IF v_det.id IS NOT NULL THEN
    UPDATE public.detentions
       SET reduction_jours = v_reduction, jour_fin = v_nouveau,
           mode_fin = CASE WHEN v_libere THEN 'anticipee_avocat' ELSE mode_fin END,
           jour_fin_effective = CASE WHEN v_libere THEN v_jour ELSE jour_fin_effective END,
           date_fin_effective = CASE WHEN v_libere THEN now() ELSE date_fin_effective END
     WHERE id = v_det.id AND mode_fin IS NULL;
  END IF;
  UPDATE public.personnages_donnees
     SET est_emprisonne = CASE WHEN v_libere THEN NULL
           ELSE v_peine || jsonb_build_object('jourFin', v_nouveau, 'jours', v_jours,
                                              'avocatUtilise', true) END,
         detention_qhs = CASE WHEN v_libere AND (coalesce((v_peine->>'qhs')::boolean,false)
                                                 OR coalesce(v_det.qhs,false))
                              THEN jsonb_build_object('enQHS', false, 'paLimite1Jour', false)
                              ELSE detention_qhs END
   WHERE name = v_moi;
  IF v_libere AND (coalesce((v_peine->>'qhs')::boolean,false) OR coalesce(v_det.qhs,false)) THEN
    UPDATE public.prisonniers_qhs SET statut='libere'
     WHERE data ->> 'nom' = v_moi AND coalesce(statut,'') = 'detenu';
  END IF;
  RETURN jsonb_build_object('ok',true,'acceptee',true,'reduction',v_reduction,
                            'jour_fin',v_nouveau,'jours',v_jours,'libere',v_libere,
                            'detention_id',v_det.id);
END; $fn$;

CREATE OR REPLACE FUNCTION public.detention_clore_evasion()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_moi text; v_jour integer; v_peine jsonb; v_det record;
        v_fin integer; v_reliquat integer; v_motifs jsonb; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT coalesce(day,1), est_emprisonne, country INTO v_jour, v_peine, v_pays
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  v_fin := coalesce((v_peine->>'jourFin')::integer, v_jour);
  v_reliquat := greatest(0, v_fin - v_jour);
  IF v_det.id IS NOT NULL THEN
    SELECT coalesce(motifs,'[]'::jsonb), coalesce(country, v_pays) INTO v_motifs, v_pays
      FROM public.detentions WHERE id = v_det.id FOR UPDATE;
    -- EVASION REUSSIE N'EST PAS UNE LIBERATION : la peine n'est pas purgee, et jour_fin n'est
    -- JAMAIS reecrit. Le reliquat est rendu a part, pour l'avis de recherche.
    UPDATE public.detentions
       SET mode_fin='evasion', jour_fin_effective=v_jour, date_fin_effective=now()
     WHERE id = v_det.id AND mode_fin IS NULL;
  ELSE
    v_motifs := '[]'::jsonb;
  END IF;
  UPDATE public.personnages_donnees
     SET est_emprisonne = NULL,
         detention_qhs = CASE WHEN coalesce((v_peine->>'qhs')::boolean,false) OR coalesce(v_det.qhs,false)
                              THEN jsonb_build_object('enQHS', false, 'paLimite1Jour', false)
                              ELSE detention_qhs END
   WHERE name = v_moi;
  IF coalesce((v_peine->>'qhs')::boolean,false) OR coalesce(v_det.qhs,false) THEN
    UPDATE public.prisonniers_qhs SET statut='libere'
     WHERE data ->> 'nom' = v_moi AND coalesce(statut,'') = 'detenu';
  END IF;
  RETURN jsonb_build_object('ok',true,'detention_id',v_det.id,'reliquat_jours',v_reliquat,
                            'motifs',v_motifs,'country',v_pays,'jour',v_jour);
END; $fn$;

GRANT EXECUTE ON FUNCTION public.detention_reduire_peine(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.detention_clore_evasion() TO authenticated;

COMMENT ON FUNCTION public.detention_reduire_peine(boolean) IS
'Applique la requete de l''avocat sur SA PROPRE peine, en une transaction : consomme l''avocat
(dans les deux cas, requete acceptee ou refusee), et si elle est acceptee reduit la peine de la
moitie du reliquat arrondie au superieur, en cloturant par anticipee_avocat si le terme est
atteint. Le MONTANT de la reduction est calcule ici, pas recu ; seul le resultat de la plaidoirie
vient de l''appelant, parce qu''il depend de valeurs qui vivent dans l''etat client. Verdicts :
acteur_non_authentifie, non_detenu, avocat_deja_utilise, peine_sans_terme, puis ok.';
COMMENT ON FUNCTION public.detention_clore_evasion() IS
'Clot SA PROPRE detention par evasion : mode_fin = evasion, est_emprisonne vide, drapeau QHS
abaisse et ligne du registre du QHS liberee -- en une transaction. jour_fin n''est JAMAIS reecrit :
une evasion n''est pas une liberation. Rend les motifs d''origine, le pays et le reliquat, pour que
l''appelant construise l''avis de recherche. Verdicts : acteur_non_authentifie, non_detenu, puis ok.';

DO $$
DECLARE v_def text; v_droits text; v_n int;
BEGIN
  -- P1 : la reduction calcule son montant, ne le recoit pas, et consomme l'avocat dans les deux cas.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='detention_reduire_peine';
  IF position('ceil(v_restants / 2.0)' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le montant de la reduction n''est pas calcule ici'; END IF;
  IF position('avocat_deja_utilise' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- la garde de l''avocat a disparu'; END IF;
  SELECT count(*) INTO v_n FROM regexp_matches(v_def, '''avocatUtilise'', true', 'g');
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- l''avocat est consomme % fois au lieu de 2 (refus et acceptation)', v_n; END IF;
  IF pg_get_function_arguments((SELECT p.oid FROM pg_proc p
       JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
      WHERE p.proname='detention_reduire_peine')) <> 'p_requete_acceptee boolean' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- signature inattendue'; END IF;

  -- P2 : l'evasion ne reecrit PAS jour_fin, et vide la fiche en base.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='detention_clore_evasion';
  IF v_def ~ 'SET\s+jour_fin\s*=' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- l''evasion reecrit jour_fin'; END IF;
  IF position('est_emprisonne = NULL' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la fiche n''est pas videe en base'; END IF;
  IF position('''reliquat_jours'',v_reliquat' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le reliquat n''est pas rendu'; END IF;

  -- P3 : les deux portes lisent leur identite, aucune ne nomme sa cible.
  FOR v_def IN SELECT pg_get_functiondef(p.oid) FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname IN ('detention_reduire_peine','detention_clore_evasion') LOOP
    IF position('public.mon_personnage()' in v_def) = 0 THEN
      RAISE EXCEPTION 'P3 ECHOUEE -- une porte ne lit pas son identite'; END IF;
    IF v_def ~ 'p_nom|p_cible' THEN
      RAISE EXCEPTION 'P3 ECHOUEE -- une porte nomme sa cible'; END IF;
  END LOOP;

  -- P4 : les droits.
  SELECT string_agg(p.proname || '=' || coalesce(r.rolname,'PUBLIC'), ', '
                    ORDER BY p.proname, coalesce(r.rolname,'PUBLIC'))
    INTO v_droits FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
    CROSS JOIN LATERAL aclexplode(p.proacl) ae LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.proname IN ('detention_reduire_peine','detention_clore_evasion');
  IF v_droits IS DISTINCT FROM
     'detention_clore_evasion=authenticated, detention_clore_evasion=postgres, detention_clore_evasion=service_role, detention_reduire_peine=authenticated, detention_reduire_peine=postgres, detention_reduire_peine=service_role' THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- droits : %', v_droits; END IF;

  -- P5 : AUCUNE DONNEE TOUCHEE.
  SELECT count(*) INTO v_n FROM public.detentions;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % detention(s)', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.prisonniers_qhs;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % ligne(s) QHS au lieu de 1', v_n; END IF;
  IF (SELECT day FROM public.personnages_donnees WHERE name='Ben') <> 1 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le jour du personnage du banc a bouge'; END IF;
  IF (SELECT md5(string_agg(name||':'||coalesce(arg::text,'~')||':'||coalesce(liquide::text,'~'),'|' ORDER BY name COLLATE "C"))
        FROM public.personnages_donnees) IS DISTINCT FROM 'db4a44dee1b87f6ccd06610120f305ed' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- les personnages ont bouge'; END IF;

  RAISE NOTICE 'CINQ PREUVES STRUCTURELLES VERTES.';
END $$;