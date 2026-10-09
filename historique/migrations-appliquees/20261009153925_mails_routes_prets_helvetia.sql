-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009153925 (UTC ; 17h39 a Paris), nom
-- `mails_routes_prets_helvetia`. Le registre passe de 580 a 581 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 c4b334fe5a3bf256aff973ef9b41b934, 8 390 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle route vers le poseur les sept courriers de `traiter_prets_helvetia_quotidien`. Le defaut y
-- etait le plus couteux du lot : la fonction est UNE transaction qui traite tous les prets d'un pays
-- a la file, de sorte qu'un courrier en echec sur un seul pret annulait la passe entiere --
-- prelevements, saisies et marqueurs anti-rejeu compris. La nuit etait perdue pour tout le monde a
-- cause d'une notification.
--
-- AUCUNE MODIFICATION DU DEPOT NE L'ACCOMPAGNE : elle patche une fonction SQL en place.
-- =============================================================================

-- Routage des sept courriers du recouvrement Helvetia vers l'unique ecrivain de public.mails.
--
-- traiter_prets_helvetia_quotidien est la passe nocturne du recouvrement de la banque privee. Pour
-- chaque pret en cours ou en contentieux, elle gere l'accord amiable et son dernier avertissement,
-- pose le marqueur anti-rejeu du jour, preleve la mensualite, fait passer en contentieux apres deux
-- jours d'impaye, execute l'echelle de saisie financiere (compte Helvetia, compte national,
-- liquide), cible un bien, le saisit, et traite le cas de la copropriete. Elle informait le
-- debiteur et, le cas echeant, son coproprietaire par sept INSERT directs dans public.mails.
--
-- Ces INSERT directs etaient un defaut particulierement couteux ici. La fonction est UNE SEULE
-- transaction qui traite tous les prets d'un pays a la file : un courrier qui echoue sur un seul
-- pret faisait remonter l'erreur et annulait la passe entiere — prelevements, saisies, marqueurs
-- anti-rejeu compris. La nuit etait perdue pour tout le monde a cause d'une notification.
--
-- Le routage confie les sept ecritures a public.mail_systeme_poser_interne, qui ne leve jamais et
-- consigne son echec dans mails_envois_systeme. Aucun courrier ne change : expediteur, destinataire,
-- sujet, corps et heure sont recopies tels quels. L'identifiant du courrier, qui etait laisse au
-- DEFAULT de la colonne, est maintenant fabrique par le poseur, et la colonne archived a false
-- disparait de l'appel — c'est exactement le DEFAULT de cette colonne, donc aucune donnee ne change.

DO $mig$
DECLARE
  v_def text; v_tmp text; i integer;
  v_avant text[]; v_apres text[];
BEGIN
  v_def := pg_get_functiondef('public.traiter_prets_helvetia_quotidien()'::regprocedure);

  v_avant := ARRAY[
$f$        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Dernier délai',
            'Réglez l''intégralité de votre dette avant minuit demain, faute de quoi le recouvrement reprendra.',
            now()::text, false, false);$f$,
$f$        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Mise en demeure',
            'La totalité du capital restant dû est désormais exigible immédiatement.', now()::text, false, false);$f$,
$f$        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Avertissement',
            'Votre échéance n''a pas pu être prélevée.', now()::text, false, false);$f$,
$f$        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Bien ciblé — proposition d''accord',
            'À défaut de règlement, le bien ' || v_bien.id || ' sera saisi. Un accord amiable reste possible.',
            now()::text, false, false);$f$,
$f$        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Proposition d''accord',
            'Un bien pourrait être saisi. Un accord amiable reste possible.', now()::text, false, false);$f$,
$f$        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Bien en copropriété saisi',
            'Le bien est saisi et mis en vente. Sa quote-part protégée sera réglée à votre copropriétaire à la revente.',
            now()::text, false, false);$f$,
$f$        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_coprop, 'Banque Privée Helvetia', 'Bien en copropriété saisi',
            'Un bien que vous détenez en copropriété avec ' || v_pret.emprunteur || ' a été saisi au titre d''une dette qui ne vous concerne pas. Votre quote-part (' || v_quote_part || ') est protégée et vous sera réglée à la revente.',
            now()::text, false, false);$f$];

  v_apres := ARRAY[
$f$        PERFORM public.mail_systeme_poser_interne(
            'Banque Privée Helvetia', v_pret.emprunteur, 'Dernier délai',
            'Réglez l''intégralité de votre dette avant minuit demain, faute de quoi le recouvrement reprendra.',
            now()::text);$f$,
$f$        PERFORM public.mail_systeme_poser_interne(
            'Banque Privée Helvetia', v_pret.emprunteur, 'Mise en demeure',
            'La totalité du capital restant dû est désormais exigible immédiatement.', now()::text);$f$,
$f$        PERFORM public.mail_systeme_poser_interne(
            'Banque Privée Helvetia', v_pret.emprunteur, 'Avertissement',
            'Votre échéance n''a pas pu être prélevée.', now()::text);$f$,
$f$        PERFORM public.mail_systeme_poser_interne(
            'Banque Privée Helvetia', v_pret.emprunteur, 'Bien ciblé — proposition d''accord',
            'À défaut de règlement, le bien ' || v_bien.id || ' sera saisi. Un accord amiable reste possible.',
            now()::text);$f$,
$f$        PERFORM public.mail_systeme_poser_interne(
            'Banque Privée Helvetia', v_pret.emprunteur, 'Proposition d''accord',
            'Un bien pourrait être saisi. Un accord amiable reste possible.', now()::text);$f$,
$f$        PERFORM public.mail_systeme_poser_interne(
            'Banque Privée Helvetia', v_pret.emprunteur, 'Bien en copropriété saisi',
            'Le bien est saisi et mis en vente. Sa quote-part protégée sera réglée à votre copropriétaire à la revente.',
            now()::text);$f$,
$f$        PERFORM public.mail_systeme_poser_interne(
            'Banque Privée Helvetia', v_coprop, 'Bien en copropriété saisi',
            'Un bien que vous détenez en copropriété avec ' || v_pret.emprunteur || ' a été saisi au titre d''une dette qui ne vous concerne pas. Votre quote-part (' || v_quote_part || ') est protégée et vous sera réglée à la revente.',
            now()::text);$f$];

  FOR i IN 1 .. array_length(v_avant, 1) LOOP
    v_tmp := replace(v_def, v_avant[i], v_apres[i]);
    IF v_tmp = v_def THEN
      RAISE EXCEPTION 'patch % non applique sur traiter_prets_helvetia_quotidien : le fragment ne correspond pas', i;
    END IF;
    v_def := v_tmp;
  END LOOP;

  IF v_def ~ 'INSERT INTO\s+(public\.)?mails\s*\(' THEN
    RAISE EXCEPTION 'traiter_prets_helvetia_quotidien ecrit encore mails en direct';
  END IF;
  EXECUTE v_def;
END $mig$;

-- Preuves structurelles.
DO $mig$
DECLARE v_def text; v_acl text; v_oid oid; v_sujets text[]; i integer;
BEGIN
  v_oid := 'public.traiter_prets_helvetia_quotidien()'::regprocedure::oid;
  v_def := pg_get_functiondef(v_oid);

  IF v_def ~ 'INSERT INTO\s+(public\.)?mails\s*\(' THEN
    RAISE EXCEPTION 'traiter_prets_helvetia_quotidien ecrit encore mails en direct';
  END IF;
  IF (SELECT count(*) FROM regexp_matches(v_def, 'mail_systeme_poser_interne', 'g')) <> 7 THEN
    RAISE EXCEPTION 'traiter_prets_helvetia_quotidien n''appelle pas le poseur 7 fois';
  END IF;

  v_sujets := ARRAY[
    'Dernier délai',
    'Mise en demeure',
    'Avertissement',
    'Bien ciblé — proposition d''''accord',
    'Proposition d''''accord',
    'Bien en copropriété saisi'];
  FOR i IN 1 .. array_length(v_sujets, 1) LOOP
    IF strpos(v_def, v_sujets[i]) = 0 THEN
      RAISE EXCEPTION 'le sujet « % » a disparu de traiter_prets_helvetia_quotidien', v_sujets[i];
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM regexp_matches(v_def, 'Bien en copropriété saisi', 'g')) <> 2 THEN
    RAISE EXCEPTION 'les deux courriers de copropriete ne sont plus tous les deux presents';
  END IF;
  IF strpos(v_def, 'v_coprop, ''Bien en copropriété saisi''') = 0 THEN
    RAISE EXCEPTION 'le courrier au coproprietaire ne lui est plus adresse';
  END IF;

  SELECT array_to_string(ARRAY(SELECT unnest(p.proacl::text[]) ORDER BY 1), ',')
    INTO v_acl FROM pg_proc p WHERE p.oid = v_oid;
  IF v_acl IS DISTINCT FROM 'postgres=X/postgres,service_role=X/postgres' THEN
    RAISE EXCEPTION 'droits modifies sur traiter_prets_helvetia_quotidien : %', v_acl;
  END IF;

  IF (SELECT count(*) FROM public.mails) <> 28 THEN
    RAISE EXCEPTION 'la migration a cree ou supprime des courriers : % lignes', (SELECT count(*) FROM public.mails);
  END IF;
END $mig$;