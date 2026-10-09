-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009153746 (UTC ; 17h37 a Paris), nom
-- `mails_routes_banque_et_notariat`. Le registre passe de 578 a 579 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 7ab7400fccef445cc8f19e509b66053a, 7 061 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle route vers le poseur les trois courriers de `resoudre_placement_national` et de
-- `finaliser_achat_bien_helvetia`, ou l'INSERT direct appartenait a la transaction d'un acte
-- d'argent : un courrier qui echoue annulait la liquidation du placement ou la finalisation de la
-- vente. Un acte d'argent ne doit jamais dependre de la bonne arrivee de sa notification.
--
-- AUCUNE MODIFICATION DU DEPOT NE L'ACCOMPAGNE : elle patche des fonctions SQL en place.
-- =============================================================================

-- Routage des courriers bancaires et notariaux vers l'unique ecrivain de public.mails.
--
-- resoudre_placement_national liquide un placement a terme de la Banque nationale : elle recredite
-- le capital et le resultat sur le compte, ajuste la fortune du seul delta net, marque le placement
-- resolu, puis previenait le joueur par un INSERT direct dans public.mails. finaliser_achat_bien_helvetia
-- solde l'achat d'un bien saisi : elle debite le solde, cree l'obligation de quote-part du
-- coproprietaire, impute le reste sur le pret, et posait deux courriers de la meme facon.
--
-- Dans les deux cas l'INSERT direct etait un defaut : il appartenait a la transaction de l'acte
-- financier. Un courrier qui echoue — contrainte violee, colonne non nulle, table indisponible —
-- faisait remonter l'erreur et annulait tout : le placement n'etait pas resolu, la vente n'etait
-- pas finalisee. Un acte d'argent ne doit jamais dependre de la bonne arrivee de sa notification.
--
-- Le routage confie l'ecriture a public.mail_systeme_poser_interne, qui ne leve jamais et consigne
-- son echec dans mails_envois_systeme. Rien ne change au contenu : expediteur, destinataire, sujet,
-- corps et heure sont recopies tels quels. Deux details de forme disparaissent : l'identifiant du
-- courrier, desormais fabrique par le poseur (la variable v_mail_id de resoudre_placement_national
-- reste calculee mais n'est plus utilisee, ce qui ne change aucun resultat), et la colonne archived
-- a false, qui est exactement le DEFAULT de la colonne. Dans resoudre_placement_national, l'heure
-- etait ecrite en passant now() dans une colonne text : elle est donc transmise en (now())::text,
-- ce qui produit la meme valeur exactement.

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.resoudre_placement_national(text,numeric)'::regprocedure);
  v_new := replace(v_def, $ancien$  INSERT INTO mails (
    id,
    to_player,
    from_player,
    subject,
    body,
    time,
    read,
    archived
  )
  VALUES (
    v_mail_id,
    v_placement.personnage,
    'Banque Nationale',
    'Placement Banque nationale arrivé à échéance',
    'Montant placé : ' ||
      v_placement.montant::text || ' FR. ' ||
    'Rendement : ' ||
      CASE WHEN p_rendement_pct >= 0 THEN '+' ELSE '' END ||
      p_rendement_pct::text || ' %. ' ||
    v_libelle_gain || ' : ' ||
      v_signe || v_delta::text || ' FR. ' ||
    'Montant crédité : ' ||
      v_montant_final::text || ' FR.',
    now(),
    false,
    false
  );$ancien$,
                          $nouveau$  PERFORM public.mail_systeme_poser_interne(
    'Banque Nationale',
    v_placement.personnage,
    'Placement Banque nationale arrivé à échéance',
    'Montant placé : ' ||
      v_placement.montant::text || ' FR. ' ||
    'Rendement : ' ||
      CASE WHEN p_rendement_pct >= 0 THEN '+' ELSE '' END ||
      p_rendement_pct::text || ' %. ' ||
    v_libelle_gain || ' : ' ||
      v_signe || v_delta::text || ' FR. ' ||
    'Montant crédité : ' ||
      v_montant_final::text || ' FR.',
    (now())::text
  );$nouveau$);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique sur resoudre_placement_national : le fragment ne correspond pas';
  END IF;
  EXECUTE v_new;
END $mig$;

DO $mig$
DECLARE v_def text; v_new text; v_tmp text;
BEGIN
  v_def := pg_get_functiondef('public.finaliser_achat_bien_helvetia(text,text)'::regprocedure);

  v_new := replace(v_def, $ancien$    INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
      VALUES (v_bien.coproprietaire, 'Banque Privée Helvetia', 'Revente de votre bien en copropriété',
        'Le bien a été revendu. Votre quote-part protégée (' || v_bien.quote_part_coproprietaire || ') vous sera réglée dès que possible.',
        now()::text, false, false);$ancien$,
                          $nouveau$    PERFORM public.mail_systeme_poser_interne(
        'Banque Privée Helvetia', v_bien.coproprietaire, 'Revente de votre bien en copropriété',
        'Le bien a été revendu. Votre quote-part protégée (' || v_bien.quote_part_coproprietaire || ') vous sera réglée dès que possible.',
        now()::text);$nouveau$);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch 1 non applique sur finaliser_achat_bien_helvetia : le fragment ne correspond pas';
  END IF;

  v_tmp := v_new;
  v_new := replace(v_tmp, $ancien$      INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
        VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Revente de votre bien en copropriété',
          'Le bien a été revendu. Après règlement de la quote-part de votre copropriétaire, ' || v_reste_debiteur ||
          ' ont été appliqués à votre dette.', now()::text, false, false);$ancien$,
                          $nouveau$      PERFORM public.mail_systeme_poser_interne(
          'Banque Privée Helvetia', v_pret.emprunteur, 'Revente de votre bien en copropriété',
          'Le bien a été revendu. Après règlement de la quote-part de votre copropriétaire, ' || v_reste_debiteur ||
          ' ont été appliqués à votre dette.', now()::text);$nouveau$);
  IF v_new = v_tmp THEN
    RAISE EXCEPTION 'patch 2 non applique sur finaliser_achat_bien_helvetia : le fragment ne correspond pas';
  END IF;

  EXECUTE v_new;
END $mig$;

-- Preuves structurelles.
DO $mig$
DECLARE
  v_cibles text[] := ARRAY[
    'public.resoudre_placement_national(text,numeric)',
    'public.finaliser_achat_bien_helvetia(text,text)'];
  v_attendus integer[] := ARRAY[1, 2];
  v_acls text[] := ARRAY[
    'postgres=X/postgres,service_role=X/postgres',
    'authenticated=X/postgres,postgres=X/postgres,service_role=X/postgres'];
  v_sujets text[] := ARRAY[
    'Placement Banque nationale arrivé à échéance',
    'Revente de votre bien en copropriété'];
  i integer; v_def text; v_acl text; v_oid oid;
BEGIN
  FOR i IN 1 .. array_length(v_cibles, 1) LOOP
    v_oid := v_cibles[i]::regprocedure::oid;
    v_def := pg_get_functiondef(v_oid);
    IF v_def ~ 'INSERT INTO\s+(public\.)?mails\s*\(' THEN
      RAISE EXCEPTION '% ecrit encore mails en direct', v_cibles[i];
    END IF;
    IF (SELECT count(*) FROM regexp_matches(v_def, 'mail_systeme_poser_interne', 'g')) <> v_attendus[i] THEN
      RAISE EXCEPTION '% n''appelle pas le poseur % fois', v_cibles[i], v_attendus[i];
    END IF;
    IF (SELECT count(*) FROM regexp_matches(v_def, v_sujets[i], 'g')) <> v_attendus[i] THEN
      RAISE EXCEPTION 'le sujet « % » n''apparait plus % fois dans %', v_sujets[i], v_attendus[i], v_cibles[i];
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