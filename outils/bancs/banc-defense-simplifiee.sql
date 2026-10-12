-- BANC DE LA PROCEDURE SIMPLIFIEE (12 octobre 2026) -- 22 epreuves
--
-- CE BANC NE COMMITE RIEN. Il ouvre des dossiers, fait plaider Ben, et se termine par un
-- RAISE EXCEPTION INCONDITIONNEL qui annule tout.
--
-- CE QU'IL VERIFIE QUE LES PREUVES NE PEUVENT PAS VERIFIER. Les 12 preuves de la migration sont
-- STRUCTURELLES : elles lisent `prosrc` et des catalogues. Aucune ne peut dire qu'un jugement est
-- REELLEMENT cree, qu'une detention s'ouvre, qu'un appel est REELLEMENT refuse, ni que le taux
-- calcule est celui de la formule arbitree.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc defense : LES 22 EPREUVES SONT VERTES. -- rien ne doit rester
--
-- PIEGE DE DECOR : Ben doit etre LIBRE au depart. Une peine en cours empeche d'en ouvrir une
-- seconde (garde de `detention_ouvrir_interne`) et l'epreuve de l'execution immediate echouerait
-- pour une raison qui n'a rien a voir avec la defense.

BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.je_suis_le_serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', '', true);
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis_le_serveur() TO PUBLIC;

DO $banc$
DECLARE
  BEN_U text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5'; BEN text := 'Ben';
  MARS  text := 'Marsault';
  v jsonb; n integer := 0; ko integer := 0; e text := '';
  v_cha integer; v_stats jsonb; v_jour integer; v_n integer; v_s text;
  i integer; v_relaxes integer := 0; v_reductions integer := 0;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- DECOR. Ben est libre, non excommunie, CHA 13 pour que la formule soit lisible : avec un
  -- avocat a 16, le taux doit valoir exactement 65.
  UPDATE public.personnages_donnees SET est_emprisonne = NULL, excommunie = NULL,
         stats = coalesce(stats, '{}'::jsonb) || jsonb_build_object('CHA', 13)
   WHERE name = BEN;
  DELETE FROM public.detentions WHERE nom = BEN;
  SELECT coalesce(day, 1) INTO v_jour FROM public.personnages_donnees WHERE name = BEN;

  -- ------------------------------------------------------------------ T1 : LE CHA EST PERSONNEL
  n := n + 1;
  v_cha := public.justice_cha_personnel(BEN);
  IF v_cha <> 13 THEN ko := ko + 1; e := e || E'\nT1 : CHA personnel = ' || v_cha || ', 13 attendu'; END IF;

  -- ------------------------------------------- T2 : L'EXCOMMUNICATION PESE, LE GROUPE JAMAIS
  n := n + 1;
  UPDATE public.personnages_donnees SET excommunie = jsonb_build_object('depuis', 'banc') WHERE name = BEN;
  IF public.justice_cha_personnel(BEN) <> 11 THEN
    ko := ko + 1; e := e || E'\nT2 : l''excommunication ne retire pas 2 CHA'; END IF;
  UPDATE public.personnages_donnees SET excommunie = NULL WHERE name = BEN;

  -- ------------------------------- T3 : LES PV N'AFFAIBLISSENT PAS LE CHA DE LA DEFENSE
  -- Le navigateur multipliait la caracteristique par hp/100. Le serveur ne connait pas cette
  -- notion, et ne doit pas la reinventer : un blesse plaide avec le meme CHA.
  n := n + 1;
  UPDATE public.personnages_donnees SET hp = 1 WHERE name = BEN;
  IF public.justice_cha_personnel(BEN) <> 13 THEN
    ko := ko + 1; e := e || E'\nT3 : les PV pesent sur le CHA de la defense'; END IF;
  UPDATE public.personnages_donnees SET hp = 100 WHERE name = BEN;

  -- --------------------------------------------------- T4 : LES TROIS AVOCATS, MEME EFFICACITE
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.justice_avocats_commis
   WHERE pays = 'republic' AND cha = 16 AND ville IN ('capitale', 'ville_a', 'ville_b');
  IF v_n <> 3 THEN ko := ko + 1; e := e || E'\nT4 : ' || v_n || ' avocat(s) a CHA 16, 3 attendus'; END IF;

  -- ------------------------------------------------------------- T5 : LA FORMULE, SANS PREUVE
  n := n + 1;
  IF public.justice_defense_taux(16, 13, false) <> 65 THEN
    ko := ko + 1; e := e || E'\nT5 : taux(16,13) = ' || public.justice_defense_taux(16, 13, false); END IF;

  -- -------------------------------------------------------------- T6 : LE MALUS DE PREUVE : 35
  n := n + 1;
  IF public.justice_defense_taux(16, 13, true) <> 30 THEN
    ko := ko + 1; e := e || E'\nT6 : le malus de preuve reelle ne vaut pas 35 points'; END IF;

  -- --------------------------------------------------------------------- T7 : LES DEUX BORNES
  n := n + 1;
  IF public.justice_defense_taux(1, 1, true) <> 5 OR public.justice_defense_taux(20, 20, false) <> 80 THEN
    ko := ko + 1; e := e || E'\nT7 : les bornes 5 / 80 ne tiennent pas'; END IF;

  -- ------------------------------------------- T8 : LA PREUVE REELLE EST UNE TRACE, PAS UN MOT
  n := n + 1;
  DELETE FROM public.actions_tracables WHERE id = 'act-banc-def';
  IF public.justice_preuve_reelle('republic', BEN, 'vol') THEN
    ko := ko + 1; e := e || E'\nT8 : une preuve existe sans aucune trace'; END IF;
  INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
  VALUES ('act-banc-def', BEN, MARS, 'vol', 'republic', 'capitale', v_jour, v_jour + 7);
  IF NOT public.justice_preuve_reelle('republic', BEN, 'vol') THEN
    ko := ko + 1; e := e || E'\nT8 : la trace objective ne fait pas preuve'; END IF;

  -- ------------------------------- T9 : UNE TRACE D'UNE AUTRE INFRACTION NE PROUVE RIEN
  n := n + 1;
  IF public.justice_preuve_reelle('republic', BEN, 'fausse_rumeur') THEN
    ko := ko + 1; e := e || E'\nT9 : une trace de vol prouve une fausse rumeur'; END IF;

  -- ------------------------------------------------- T10 : UNE TRACE EXPIREE NE PROUVE PLUS RIEN
  n := n + 1;
  UPDATE public.actions_tracables SET jour_expiration = v_jour - 1 WHERE id = 'act-banc-def';
  IF public.justice_preuve_reelle('republic', BEN, 'vol') THEN
    ko := ko + 1; e := e || E'\nT10 : une trace expiree fait encore preuve'; END IF;
  DELETE FROM public.actions_tracables WHERE id = 'act-banc-def';

  -- ------------------------------------- T11 : LE TAUX ANNONCE EST CELUI DE LA FORMULE
  n := n + 1;
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES ('banc-def-1', 'republic', 'capitale',
    jsonb_build_object('status', 'au_parquet', 'cible', BEN, 'plaignant', MARS, 'motif', 'Vol',
      'infraction_constatee', 'vol', 'country', 'republic', 'city', 'capitale')::text);
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.plainte_defendre('banc-def-1');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT11 : la defense a echoue -- ' || coalesce(v ->> 'raison', '?');
  ELSIF (v ->> 'taux')::integer <> 65 OR (v ->> 'avocat_cha')::integer <> 16
     OR (v ->> 'prevenu_cha')::integer <> 13 THEN
    ko := ko + 1; e := e || E'\nT11 : taux/CHA annonces = ' || v::text;
  END IF;

  -- ---------------------------------- T12 : LE JET EST DANS 1..100 ET DECIDE DE L'ISSUE
  n := n + 1;
  IF (v ->> 'jet')::integer < 1 OR (v ->> 'jet')::integer > 100
     OR ((v ->> 'jet')::integer <= 65) IS DISTINCT FROM (v ->> 'reussie')::boolean THEN
    ko := ko + 1; e := e || E'\nT12 : le jet et l''issue ne concordent pas -- ' || v::text; END IF;

  -- ------------------------------------------------ T13 : UN VRAI JUGEMENT, DANS TOUS LES CAS
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.jugements j WHERE j.id = 'jug-banc-def-1';
  IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nT13 : aucune ligne de jugement'; END IF;
  SELECT j.peine INTO v_s FROM public.jugements j WHERE j.id = 'jug-banc-def-1';
  IF (v ->> 'verdict') = 'relaxe' AND v_s IS NOT NULL THEN
    ko := ko + 1; e := e || E'\nT13 : une relaxe porte une peine'; END IF;
  IF (v ->> 'verdict') = 'condamnation' AND v_s IS NULL THEN
    ko := ko + 1; e := e || E'\nT13 : une condamnation n''a pas de peine'; END IF;

  -- ------------------------------------- T14 : LE JUGEMENT EST SIGNE PAR LE TRIBUNAL
  n := n + 1;
  SELECT j.juge INTO v_s FROM public.jugements j WHERE j.id = 'jug-banc-def-1';
  IF v_s IS DISTINCT FROM public.justice_juge_titulaire('republic', 'capitale') THEN
    ko := ko + 1; e := e || E'\nT14 : le jugement n''est pas signe par le juge titulaire (' || coalesce(v_s,'-') || ')'; END IF;

  -- --------------------------- T15 : LA CHRONOLOGIE PORTE LA PLAIDOIRIE ET LE VERDICT
  n := n + 1;
  SELECT string_agg(a.type, ',' ORDER BY a.rang) INTO v_s
    FROM public.dossiers_judiciaires_actes a WHERE a.affaire = 'banc-def-1';
  IF v_s NOT IN ('defense_simplifiee,relaxe', 'defense_simplifiee,condamnation') THEN
    ko := ko + 1; e := e || E'\nT15 : chronologie = ' || coalesce(v_s, '(vide)'); END IF;

  -- ------------------------------ T16 : LE PLANCHER CARCERAL ET L'AMENDE REDUITE
  -- `vol` vaut 1 jour / 500 FR de reference. Hors relaxe, la peine ne peut pas descendre sous un
  -- jour -- mais l'amende, elle, descend bien a 250 en cas de reussite.
  n := n + 1;
  IF (v ->> 'verdict') = 'condamnation' THEN
    IF (v ->> 'jours')::integer < 1 THEN
      ko := ko + 1; e := e || E'\nT16 : le plancher carceral d''un jour est perce'; END IF;
    IF (v ->> 'reussie')::boolean AND (v ->> 'amende')::integer <> 250 THEN
      ko := ko + 1; e := e || E'\nT16 : amende reduite = ' || (v ->> 'amende'); END IF;
    IF NOT (v ->> 'reussie')::boolean AND (v ->> 'amende')::integer <> 500 THEN
      ko := ko + 1; e := e || E'\nT16 : amende de reference = ' || (v ->> 'amende'); END IF;
  END IF;

  -- ------------------------------------------- T17 : LA PEINE EST IMMEDIATEMENT EXECUTOIRE
  n := n + 1;
  IF (v ->> 'verdict') = 'condamnation' THEN
    SELECT count(*) INTO v_n FROM public.detentions d
     WHERE d.nom = BEN AND d.autorite = public.justice_juge_titulaire('republic', 'capitale');
    IF v_n < 1 OR coalesce((v ->> 'executee')::boolean, false) IS NOT TRUE THEN
      ko := ko + 1; e := e || E'\nT17 : la peine n''est pas executee'; END IF;
  ELSE
    SELECT count(*) INTO v_n FROM public.detentions d WHERE d.nom = BEN;
    IF v_n <> 0 THEN ko := ko + 1; e := e || E'\nT17 : une relaxe a ouvert une detention'; END IF;
  END IF;

  -- --------------------------------------------- T18 : LA DEFENSE EST DEFINITIVE
  n := n + 1;
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.plainte_defendre('banc-def-1');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, true) IS NOT FALSE
     OR (v ->> 'raison') NOT IN ('affaire_non_defendable', 'defense_deja_plaidee') THEN
    ko := ko + 1; e := e || E'\nT18 : on peut plaider deux fois -- ' || v::text; END IF;

  -- ------------------------------------------------- T19 : AUCUN APPEL N'EST POSSIBLE
  n := n + 1;
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.justice_appel_ouvrir('banc-def-1');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'appel_exclu_procedure_simplifiee' THEN
    ko := ko + 1; e := e || E'\nT19 : refus d''appel = ' || coalesce(v ->> 'raison', '?'); END IF;

  -- --------------------------------------------------- T20 : UN CRIME NE SE PLAIDE JAMAIS
  n := n + 1;
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES ('banc-def-2', 'republic', 'capitale',
    jsonb_build_object('status', 'au_parquet', 'cible', BEN, 'plaignant', MARS, 'motif', 'Incendie',
      'infraction_constatee', 'incendier', 'country', 'republic', 'city', 'capitale')::text);
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.plainte_defendre('banc-def-2');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'procedure_simplifiee_exclut_les_crimes' THEN
    ko := ko + 1; e := e || E'\nT20 : un crime passe en procedure simplifiee -- ' || v::text; END IF;

  -- ----------------------------------------- T21 : AU-DELA DE DEUX JOURS, LE TRIBUNAL JUGE
  n := n + 1;
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES ('banc-def-3', 'republic', 'capitale',
    jsonb_build_object('status', 'au_parquet', 'cible', BEN, 'plaignant', MARS, 'motif', 'Blanchiment',
      'infraction_constatee', 'blanchiment', 'country', 'republic', 'city', 'capitale')::text);
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.plainte_defendre('banc-def-3');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'procedure_simplifiee_reservee_aux_peines_courtes' THEN
    ko := ko + 1; e := e || E'\nT21 : une peine longue passe en procedure simplifiee -- ' || v::text; END IF;

  -- ------------------- T22 : LES DEUX ISSUES D'UNE REUSSITE SORTENT TOUTES LES DEUX
  -- Deux cents tirages de la part de relaxe : ni 0 ni 200, sinon une des deux issues est morte.
  n := n + 1;
  FOR i IN 1..200 LOOP
    IF (floor(random() * 100)::integer + 1) <= public.justice_defense_part_relaxe()
      THEN v_relaxes := v_relaxes + 1; ELSE v_reductions := v_reductions + 1; END IF;
  END LOOP;
  IF v_relaxes = 0 OR v_reductions = 0 THEN
    ko := ko + 1; e := e || E'\nT22 : une issue est inatteignable (relaxe=' || v_relaxes
                           || ' reduction=' || v_reductions || ')'; END IF;

  IF ko > 0 THEN RAISE EXCEPTION 'banc defense : % EPREUVE(S) ROUGE(S) sur % --%', ko, n, e; END IF;
  RAISE EXCEPTION 'banc defense : LES % EPREUVES SONT VERTES.', n;
END $banc$;
ROLLBACK;
