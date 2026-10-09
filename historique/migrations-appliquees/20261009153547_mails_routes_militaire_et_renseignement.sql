-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009153547 (UTC ; 17h35 a Paris), nom
-- `mails_routes_militaire_et_renseignement`. Le registre passe de 576 a 577 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 e8ae2b379839c8ce7bc73824f697876b, 8 686 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle route vers le poseur les courriers de quatre fonctions militaires et du renseignement, dont
-- l'INSERT direct appartenait a la transaction de l'acte : une contrainte violee sur la table des
-- courriers emportait l'acte lui-meme -- l'engagement n'etait pas rendu caduc, la candidature pas
-- acceptee, l'alerte ne laissait aucune trace.
--
-- AUCUNE MODIFICATION DU DEPOT NE L'ACCOMPAGNE : elle patche des fonctions SQL en place, par
-- `pg_get_functiondef` + `replace`, et leve si un fragment ne correspond pas.
-- =============================================================================

-- Routage des courriers militaires et du renseignement vers l'unique ecrivain de public.mails.
--
-- Ces quatre fonctions ecrivaient elles-memes dans public.mails. militaire_affectations_expirer
-- rend caduc un engagement non honore dans les 48 heures, militaire_candidatures_relancer relance
-- les candidatures dormantes depuis sept jours, militaire_candidature_accepter retient un candidat
-- et annule ses autres candidatures, cellule_alerter_ministre previent le ministre de la Defense
-- d'un evenement de renseignement. Dans chacune, l'INSERT direct etait un defaut : il faisait
-- partie de la transaction de l'acte, si bien qu'une contrainte violee ou un echec d'ecriture sur
-- la table des courriers remontait et emportait l'acte lui-meme — l'engagement n'etait pas rendu
-- caduc, la candidature n'etait pas acceptee, l'alerte ne laissait aucune trace.
--
-- Le routage confie l'ecriture a public.mail_systeme_poser_interne, qui ne leve jamais et consigne
-- son echec dans mails_envois_systeme. Il ne change rien au contenu : expediteur, destinataire,
-- sujet, corps et heure sont recopies tels quels. Seul l'identifiant du courrier change de
-- fabrique — le poseur fabrique le sien — et la colonne read est desormais ecrite par le poseur.

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.militaire_affectations_expirer()'::regprocedure);
  v_new := replace(v_def, $ancien$    INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
    VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text),1,6),
            'État-major', r.candidat,
            'Engagement caduc — délai dépassé',
            'Vous ne vous êtes pas présenté(e) à la Caserne Militaire dans les 48 heures. ' ||
            'Votre engagement au grade de ' || r.grade_vise || ' est caduc et la place a été rendue. ' ||
            'Vous pouvez déposer une nouvelle candidature à la Caserne.',
            to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);$ancien$,
                          $nouveau$    PERFORM public.mail_systeme_poser_interne(
            'État-major', r.candidat,
            'Engagement caduc — délai dépassé',
            'Vous ne vous êtes pas présenté(e) à la Caserne Militaire dans les 48 heures. ' ||
            'Votre engagement au grade de ' || r.grade_vise || ' est caduc et la place a été rendue. ' ||
            'Vous pouvez déposer une nouvelle candidature à la Caserne.',
            to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));$nouveau$);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique sur militaire_affectations_expirer : le fragment ne correspond pas';
  END IF;
  EXECUTE v_new;
END $mig$;

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.militaire_candidatures_relancer()'::regprocedure);
  v_new := replace(v_def, $ancien$    INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
    VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text),1,6),
            'État-major', r.candidat,
            'Votre candidature est toujours à l''étude',
            'Votre candidature au grade de ' || r.grade_vise || ', déposée le ' ||
            to_char(r.cree_le AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY') ||
            ', reste enregistrée et sera examinée. Vous pouvez la retirer à tout moment à la Caserne Militaire.',
            to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);$ancien$,
                          $nouveau$    PERFORM public.mail_systeme_poser_interne(
            'État-major', r.candidat,
            'Votre candidature est toujours à l''étude',
            'Votre candidature au grade de ' || r.grade_vise || ', déposée le ' ||
            to_char(r.cree_le AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY') ||
            ', reste enregistrée et sera examinée. Vous pouvez la retirer à tout moment à la Caserne Militaire.',
            to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));$nouveau$);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique sur militaire_candidatures_relancer : le fragment ne correspond pas';
  END IF;
  EXECUTE v_new;
END $mig$;

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.militaire_candidature_accepter(text,text,text)'::regprocedure);
  v_new := replace(v_def, $ancien$  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text),1,6),
          'État-major', v.candidat,
          'Votre engagement est accepté',
          'Votre candidature au grade de ' || v.grade_vise || ' a été retenue. ' ||
          'Présentez-vous à la Caserne Militaire dans les 48 heures pour découvrir votre affectation. ' ||
          'Passé ce délai, votre engagement sera caduc et la place rendue.',
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);$ancien$,
                          $nouveau$  PERFORM public.mail_systeme_poser_interne(
          'État-major', v.candidat,
          'Votre engagement est accepté',
          'Votre candidature au grade de ' || v.grade_vise || ' a été retenue. ' ||
          'Présentez-vous à la Caserne Militaire dans les 48 heures pour découvrir votre affectation. ' ||
          'Passé ce délai, votre engagement sera caduc et la place rendue.',
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));$nouveau$);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique sur militaire_candidature_accepter : le fragment ne correspond pas';
  END IF;
  EXECUTE v_new;
END $mig$;

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.cellule_alerter_ministre(text,text,text,text)'::regprocedure);
  v_new := replace(v_def, $ancien$  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
          substr(md5(random()::text), 1, 6),
          'Service de renseignement', v_destinataire, p_sujet, p_corps,
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);$ancien$,
                          $nouveau$  PERFORM public.mail_systeme_poser_interne(
          'Service de renseignement', v_destinataire, p_sujet, p_corps,
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));$nouveau$);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique sur cellule_alerter_ministre : le fragment ne correspond pas';
  END IF;
  EXECUTE v_new;
END $mig$;

-- Preuves structurelles.
DO $mig$
DECLARE
  v_cibles text[] := ARRAY[
    'public.militaire_affectations_expirer()',
    'public.militaire_candidatures_relancer()',
    'public.militaire_candidature_accepter(text,text,text)',
    'public.cellule_alerter_ministre(text,text,text,text)'];
  v_acls text[] := ARRAY[
    'postgres=X/postgres,service_role=X/postgres',
    'postgres=X/postgres,service_role=X/postgres',
    'authenticated=X/postgres,postgres=X/postgres,service_role=X/postgres',
    'postgres=X/postgres,service_role=X/postgres'];
  v_sujets text[] := ARRAY[
    'Engagement caduc — délai dépassé',
    'Votre candidature est toujours à l''''étude',
    'Votre engagement est accepté',
    'Service de renseignement'];
  i integer; v_def text; v_acl text; v_oid oid;
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
    IF strpos(v_def, v_sujets[i]) = 0 THEN
      RAISE EXCEPTION 'le libelle « % » a disparu de %', v_sujets[i], v_cibles[i];
    END IF;
    SELECT array_to_string(ARRAY(SELECT unnest(p.proacl::text[]) ORDER BY 1), ',')
      INTO v_acl FROM pg_proc p WHERE p.oid = v_oid;
    IF v_acl IS DISTINCT FROM v_acls[i] THEN
      RAISE EXCEPTION 'droits modifies sur % : % au lieu de %', v_cibles[i], v_acl, v_acls[i];
    END IF;
  END LOOP;

  IF (SELECT count(*) FROM public.mails) <> 28 THEN
    RAISE EXCEPTION 'la migration a cree ou supprime des courriers : % lignes', (SELECT count(*) FROM public.mails);
  END IF;
END $mig$;