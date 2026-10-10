-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010095355 (UTC), nom `plaintes_defense_et_classement_ministeriel_portes`.
-- Le registre passe de 612 a 613 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 287e52987387eef13c14e6cca55af458, 8827 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- LE CYCLE DE VIE D'UNE AFFAIRE N'A PLUS D'ECRITURE CLIENTE -- 2/2
--
-- Suite de la migration precedente, separee pour une raison purement technique : les trois portes
-- et leurs preuves depassent la limite de transport du canal de migration. Celle-ci porte les
-- deux portes restantes -- `plainte_defendre` et `plainte_classer_ministere` -- et les sept
-- preuves structurelles des trois. L'en-tete complet est en tete de `affaire_transmettre`.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE CYCLE DE VIE D'UNE AFFAIRE N'A PLUS D'ECRITURE CLIENTE -- 2/2
-- Chantier 5, les trois `sbSavePlainte` avales (10 octobre 2026).
--
-- SUITE DE LA MIGRATION PRECEDENTE, separee pour une raison PUREMENT TECHNIQUE : les trois
-- portes et leurs preuves depassent la limite de transport du canal de migration (~12 500
-- caracteres de SQL). L'en-tete complet -- ce que l'inspection a mesure sur chacun des trois
-- sites, ce que ces portes ne refont pas, et ce qui reste volontairement dans le navigateur --
-- est en tete de `affaire_transmettre`.
--
-- Cette migration porte les deux portes restantes et les SEPT PREUVES STRUCTURELLES des trois.

-- 2 -- LA DEFENSE DE L'ACCUSE
CREATE OR REPLACE FUNCTION public.plainte_defendre(p_affaire_id text, p_issue text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_nom text; v_brut text; v_data jsonb; v_maj jsonb;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  -- LISTE CLOSE DES QUATRE ISSUES de la formule de defense de `data.js` : reussite eclatante
  -- (classe l'affaire), reussite simple (circonstance attenuante), echec flagrant (aggravation),
  -- echec simple (aucun effet).
  IF p_issue NOT IN ('reussite_critique', 'attenuante', 'aggravation', 'infructueuse') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'issue_inconnue');
  END IF;

  SELECT data INTO v_brut FROM public.plaintes_en_cours WHERE id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_data := v_brut::jsonb;
  -- `affaire_me_concerne` accordait l'ecriture a la cible ET au plaignant, sur le blob entier.
  -- Se defendre est le fait de l'ACCUSE, et de lui seul.
  IF coalesce(v_data ->> 'cible', '') IS DISTINCT FROM v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire');
  END IF;
  -- LA MEME CONDITION QUE LE CLIENT POSAIT DEJA (`p.status === 'deposee'`), mais arretee sous
  -- verrou : un dossier deja juge ou deja classe ne peut plus etre rouvert par une defense
  -- partie d'un ecran perime.
  IF coalesce(v_data ->> 'status', '') IS DISTINCT FROM 'deposee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_defendable',
                              'statut', v_data ->> 'status');
  END IF;

  -- UNE DEFENSE PEUT ETRE RETENTEE, et c'est la regle existante : les trois issues qui ne
  -- classent pas l'affaire la laissent « deposee », et l'ordre est payant a chaque fois (2 PA et
  -- 300 FR, preleves par `deduireCoutOrdre` avant l'appel). On ne la verrouille donc pas.
  v_maj := jsonb_build_object('defendue_par', v_nom, 'defendue_le',
                              to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
  IF p_issue = 'reussite_critique' THEN
    v_maj := v_maj || jsonb_build_object('status', 'jugee', 'resultatDefense', 'reussite_critique');
  ELSIF p_issue = 'attenuante' THEN
    v_maj := v_maj || jsonb_build_object('circonstanceAttenuante', true);
  ELSIF p_issue = 'aggravation' THEN
    v_maj := v_maj || jsonb_build_object('aggravation', true);
  END IF;

  v_data := v_data || v_maj;
  UPDATE public.plaintes_en_cours SET data = v_data::text WHERE id = p_affaire_id;
  RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'affaire', v_data);
END; $fn$;

-- 3 -- LE CLASSEMENT PAR LE MINISTRE DE LA JUSTICE
CREATE OR REPLACE FUNCTION public.plainte_classer_ministere(p_affaire_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_nom text; v_pays text; v_brut text; v_pays_aff text; v_data jsonb;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_nom LIMIT 1;
  -- L'AUTORITE EXISTAIT DEJA EN BASE, a deux endroits : la policy de lecture de cette table
  -- nomme `min_just`, et `caisse_ministere_mouvement` refuse les frais de dossier a qui n'est pas
  -- le ministre en exercice. Elle n'etait simplement appliquee par aucune ecriture.
  IF NOT public.mon_poste_est_dans('min_just', v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee');
  END IF;

  SELECT data, country INTO v_brut, v_pays_aff
    FROM public.plaintes_en_cours WHERE id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_data := v_brut::jsonb;
  IF v_pays_aff IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  -- « Classer une plainte EN COURS AVANT JUGEMENT » -- le libelle de l'ordre `annuler_poursuites`
  -- dit la regle, et elle borne le statut : une affaire jugee, classee ou deja annulee ne se
  -- classe pas.
  IF coalesce(v_data ->> 'status', '') IS DISTINCT FROM 'deposee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_classable',
                              'statut', v_data ->> 'status');
  END IF;

  v_data := v_data || jsonb_build_object('status', 'annulee', 'classee_par', v_nom,
    'classee_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
  UPDATE public.plaintes_en_cours SET data = v_data::text WHERE id = p_affaire_id;
  RETURN jsonb_build_object('ok', true, 'affaire', v_data);
END; $fn$;

-- APPELABLES PAR UN JOUEUR, ET PAR PERSONNE D'AUTRE (meme regle qu'a la migration precedente).
REVOKE ALL ON FUNCTION public.plainte_defendre(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.plainte_classer_ministere(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.plainte_defendre(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.plainte_classer_ministere(text) TO authenticated, service_role;

-- PREUVES STRUCTURELLES. Une migration commite les effets de bord de ses propres preuves : on ne
-- verifie donc ici que des FAITS DE SCHEMA. Le comportement des trois portes est eprouve en
-- transaction annulee, par le banc des plaintes.
DO $p$
DECLARE v integer; v_def text;
BEGIN
  SELECT count(*) INTO v FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('affaire_transmettre', 'plainte_defendre', 'plainte_classer_ministere')
     AND p.prosecdef;
  IF v <> 3 THEN RAISE EXCEPTION 'les trois portes ne sont pas toutes SECURITY DEFINER : %', v; END IF;

  SELECT count(*) INTO v FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('affaire_transmettre', 'plainte_defendre', 'plainte_classer_ministere')
     AND has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v <> 0 THEN RAISE EXCEPTION 'anon peut executer % porte(s) du cycle des plaintes', v; END IF;

  SELECT count(*) INTO v FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('affaire_transmettre', 'plainte_defendre', 'plainte_classer_ministere')
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v <> 3 THEN RAISE EXCEPTION 'un joueur ne peut pas appeler les trois portes : %', v; END IF;

  -- L'IDENTIFIANT NE PEUT PAS VENIR D'UNE HORLOGE : ni `clock_timestamp`, ni `now()` dans la
  -- construction de la cle.
  v_def := pg_get_functiondef('public.affaire_transmettre(text,text,text,jsonb)'::regprocedure);
  IF v_def LIKE '%clock_timestamp%' OR v_def NOT LIKE '%ON CONFLICT (id) DO NOTHING%' THEN
    RAISE EXCEPTION 'la transmission n''est pas idempotente par identifiant derive';
  END IF;
  IF v_def NOT LIKE '%affaire_autorite_de(v_ville)%' THEN
    RAISE EXCEPTION 'la transmission ne verifie pas l''autorite judiciaire de la ville';
  END IF;

  -- LES TROIS PORTES PRENNENT LE VERROU avant de decider.
  FOR v_def IN
    SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('plainte_defendre', 'plainte_classer_ministere')
  LOOP
    IF v_def NOT LIKE '%FOR UPDATE%' THEN
      RAISE EXCEPTION 'une porte du cycle decide sans verrou de ligne';
    END IF;
  END LOOP;

  -- AUCUNE DES TROIS NE POSE « jugee » HORS DE LA REUSSITE ECLATANTE : la sentence a sa porte.
  v_def := pg_get_functiondef('public.plainte_classer_ministere(text)'::regprocedure);
  IF v_def LIKE '%''jugee''%' THEN
    RAISE EXCEPTION 'le classement ministeriel empiete sur la porte de la sentence';
  END IF;

  RAISE NOTICE 'Les 7 preuves structurelles du cycle de vie des plaintes sont vertes.';
END $p$;
