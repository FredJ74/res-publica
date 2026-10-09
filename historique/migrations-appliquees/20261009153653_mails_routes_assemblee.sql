-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009153653 (UTC ; 17h36 a Paris), nom
-- `mails_routes_assemblee`. Le registre passe de 577 a 578 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 d220d1d6c3eae4e45d1119fb8de20617, 7 960 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle route vers le poseur les courriers des deux fonctions de convocation de l'Assemblee. Leur
-- defaut n'etait pas d'emporter l'acte -- elles enveloppaient deja leur INSERT dans un
-- `EXCEPTION WHEN OTHERS THEN NULL` -- mais d'AVALER l'echec sans rien consigner : une convocation
-- pouvait exister sans que personne n'en soit prevenu et sans trace permettant de le savoir. Le bloc
-- devenu inutile est supprime ; la protection du verdict est conservee et l'echec devient visible.
--
-- AUCUNE MODIFICATION DU DEPOT NE L'ACCOMPAGNE : elle patche des fonctions SQL en place.
-- =============================================================================

-- Routage des courriers de l'Assemblee (convocations du commissariat) vers l'unique ecrivain.
--
-- assemblee_detecter_partie fait le jet de detection d'une transaction interdite, inscrit la trace
-- au casier, cree la convocation et fait baisser la discretion ; assemblee_marquer_convocations_echues
-- marque echues les convocations dont le delai de 36 heures est passe. Les deux posaient leur
-- courrier elles-memes, et toutes deux l'avaient enveloppe dans un BEGIN ... EXCEPTION WHEN OTHERS
-- THEN NULL; END; pour que l'echec du courrier n'emporte pas le verdict. L'intention etait juste,
-- le moyen etait un defaut : ce bloc avalait l'echec en silence, sans rien consigner nulle part,
-- de sorte qu'une convocation pouvait exister sans que personne n'en soit jamais prevenu et sans
-- qu'aucune trace ne permette de le savoir.
--
-- Le routage confie l'ecriture a public.mail_systeme_poser_interne, qui ne leve jamais et consigne
-- son echec dans mails_envois_systeme. Le bloc EXCEPTION devenu inutile est donc SUPPRIME : la
-- protection du verdict est conservee et l'echec est desormais visible. Sujets, corps, expediteur,
-- destinataire et heure sont recopies tels quels ; seul l'identifiant du courrier est fabrique par
-- le poseur au lieu d'etre calcule sur place.
--
-- NOTE D'AUTORITE. assemblee_detecter_partie est SECURITY INVOKER, et le poseur n'a EXECUTE que
-- pour postgres. Elle reste atteignable parce que toutes ses entrees reelles sont des fonctions
-- SECURITY DEFINER possedees par postgres (assemblee_achat_illegal et assemblee_tracer_vente_interdite,
-- via assemblee_transaction_interdite_interne) : le poseur y est appele avec postgres pour
-- utilisateur courant. Un appel direct de service_role a assemblee_detecter_partie — qu'aucun
-- appelant du depot ne fait — echouerait desormais sur le droit d'executer le poseur. Les preuves
-- ci-dessous verifient que ces deux entrees sont bien SECURITY DEFINER et possedees par postgres.

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.assemblee_marquer_convocations_echues(text)'::regprocedure);
  v_new := replace(v_def, $ancien$      -- Notification isolee : un echec d'envoi ne doit JAMAIS annuler le verdict (voir la RPC
      -- vendeur ci-dessus pour la meme justification).
      BEGIN
        INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
        VALUES (
          'mail-' || md5(random()::text || clock_timestamp()::text),
          'Commissariat', v_perso.name, 'Non-présentation à convocation',
          'Vous ne vous êtes pas présenté(e) dans le délai de 36 heures qui vous était imparti. '
          || 'Vous serez placé(e) en détention pour deux jours à votre prochaine présence.',
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'), false
        );
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;$ancien$,
                          $nouveau$      -- Notification isolee : un echec d'envoi ne doit JAMAIS annuler le verdict. C'est le
      -- poseur systeme qui le garantit maintenant — il ne leve pas et consigne son echec.
      PERFORM public.mail_systeme_poser_interne(
          'Commissariat', v_perso.name, 'Non-présentation à convocation',
          'Vous ne vous êtes pas présenté(e) dans le délai de 36 heures qui vous était imparti. '
          || 'Vous serez placé(e) en détention pour deux jours à votre prochaine présence.',
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'));$nouveau$);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique sur assemblee_marquer_convocations_echues : le fragment ne correspond pas';
  END IF;
  EXECUTE v_new;
END $mig$;

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.assemblee_detecter_partie(text,text,jsonb,text,integer,boolean)'::regprocedure);
  v_new := replace(v_def, $ancien$    BEGIN
      INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
      VALUES (
        'mail-' || md5(random()::text || clock_timestamp()::text),
        'Commissariat', p_nom, 'Convocation officielle',
        CASE WHEN p_role = 'vente'
          THEN 'Une vente portant sur une marchandise interdite (« ' || (p_loi ->> 'titre') || ' ») a été constatée dans votre commerce. '
          ELSE 'Une transaction portant sur une marchandise interdite (« ' || (p_loi ->> 'titre') || ' ») vous a été imputée. ' END
        || 'Présentez-vous au commissariat sous 36 heures pour vous justifier. '
        || 'Passé ce délai sans vous présenter, vous serez arrêté(e) et détenu(e) deux jours.',
        to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'), false);
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;$ancien$,
                          $nouveau$    PERFORM public.mail_systeme_poser_interne(
        'Commissariat', p_nom, 'Convocation officielle',
        CASE WHEN p_role = 'vente'
          THEN 'Une vente portant sur une marchandise interdite (« ' || (p_loi ->> 'titre') || ' ») a été constatée dans votre commerce. '
          ELSE 'Une transaction portant sur une marchandise interdite (« ' || (p_loi ->> 'titre') || ' ») vous a été imputée. ' END
        || 'Présentez-vous au commissariat sous 36 heures pour vous justifier. '
        || 'Passé ce délai sans vous présenter, vous serez arrêté(e) et détenu(e) deux jours.',
        to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'));$nouveau$);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique sur assemblee_detecter_partie : le fragment ne correspond pas';
  END IF;
  EXECUTE v_new;
END $mig$;

-- Preuves structurelles.
DO $mig$
DECLARE
  v_cibles text[] := ARRAY[
    'public.assemblee_marquer_convocations_echues(text)',
    'public.assemblee_detecter_partie(text,text,jsonb,text,integer,boolean)'];
  v_acls text[] := ARRAY[
    'postgres=X/postgres,service_role=X/postgres',
    'postgres=X/postgres,service_role=X/postgres'];
  v_sujets text[] := ARRAY[
    'Non-présentation à convocation',
    'Convocation officielle'];
  i integer; v_def text; v_acl text; v_oid oid; v_n integer;
BEGIN
  FOR i IN 1 .. array_length(v_cibles, 1) LOOP
    v_oid := v_cibles[i]::regprocedure::oid;
    v_def := pg_get_functiondef(v_oid);
    IF v_def ~ 'INSERT INTO\s+(public\.)?mails\s*\(' THEN
      RAISE EXCEPTION '% ecrit encore mails en direct', v_cibles[i];
    END IF;
    IF (SELECT count(*) FROM regexp_matches(v_def, 'mail_systeme_poser_interne', 'g')) <> 1 THEN
      RAISE EXCEPTION '% n''appelle pas le poseur exactement une fois', v_cibles[i];
    END IF;
    IF v_def ~ 'EXCEPTION WHEN OTHERS' THEN
      RAISE EXCEPTION '% garde un bloc EXCEPTION WHEN OTHERS qui avalerait un echec', v_cibles[i];
    END IF;
    IF strpos(v_def, v_sujets[i]) = 0 THEN
      RAISE EXCEPTION 'le sujet « % » a disparu de %', v_sujets[i], v_cibles[i];
    END IF;
    SELECT array_to_string(ARRAY(SELECT unnest(p.proacl::text[]) ORDER BY 1), ',')
      INTO v_acl FROM pg_proc p WHERE p.oid = v_oid;
    IF v_acl IS DISTINCT FROM v_acls[i] THEN
      RAISE EXCEPTION 'droits modifies sur % : % au lieu de %', v_cibles[i], v_acl, v_acls[i];
    END IF;
  END LOOP;

  -- Les deux seules entrees reelles de assemblee_detecter_partie doivent rester SECURITY DEFINER
  -- possedees par postgres, sinon le poseur devient inatteignable depuis cette chaine.
  SELECT count(*) INTO v_n FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname IN ('assemblee_achat_illegal', 'assemblee_tracer_vente_interdite')
     AND p.prosecdef AND pg_get_userbyid(p.proowner) = 'postgres';
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'les entrees de la chaine de detection ne sont plus SECURITY DEFINER/postgres (%)', v_n;
  END IF;

  IF (SELECT count(*) FROM public.mails) <> 28 THEN
    RAISE EXCEPTION 'la migration a cree ou supprime des courriers : % lignes', (SELECT count(*) FROM public.mails);
  END IF;
END $mig$;