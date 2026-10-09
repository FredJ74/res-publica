-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009153817 (UTC ; 17h38 a Paris), nom
-- `mails_routes_contact_organisation`. Le registre passe de 579 a 580 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 608aa4abaf7b5277ccbebab31a319fa4, 3 590 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle route vers le poseur le courrier du passeur dans `contact_organisation_demander`. L'INSERT
-- direct etait pose AVANT l'enregistrement de la demande : un echec du courrier annulait tout, y
-- compris la consommation du delai de trois jours, et un echec plus loin faisait disparaitre un
-- message deja « parti ». La demande est desormais enregistree meme si le courrier ne part pas.
--
-- AUCUNE MODIFICATION DU DEPOT NE L'ACCOMPAGNE : elle patche une fonction SQL en place.
-- =============================================================================

-- Routage du courrier du passeur vers l'unique ecrivain de public.mails.
--
-- contact_organisation_demander est l'acte par lequel un joueur demande a un passeur de le mettre
-- en relation avec une organisation criminelle. Elle verrouille la ligne d'etat pour qu'un double
-- clic ne sollicite pas deux organisations, choisit l'organisation, fabrique le corps du message
-- avec son marqueur d'action inerte, puis — et c'est la le point sensible — ecrivait le courrier
-- au chef de l'organisation par un INSERT direct avant d'enregistrer la demande dans
-- contacts_organisations. L'INSERT direct etait un defaut : il faisait partie de la transaction de
-- la demande. Un echec d'ecriture du courrier remontait et annulait tout, y compris la
-- consommation du delai de trois jours, alors que l'inverse est aussi vrai — le courrier etant pose
-- avant l'enregistrement, un echec plus loin faisait disparaitre un message deja « parti ».
--
-- Le routage confie l'ecriture a public.mail_systeme_poser_interne, qui ne leve jamais et consigne
-- son echec dans mails_envois_systeme : la demande est desormais enregistree meme si le courrier
-- ne part pas, et l'echec est visible. Expediteur, destinataire, sujet, corps et heure sont
-- recopies tels quels. Seul l'identifiant change de fabrique ; la variable v_id reste calculee mais
-- n'est plus utilisee, ce qui ne change aucun resultat.

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.contact_organisation_demander(text,text)'::regprocedure);
  v_new := replace(v_def, $ancien$  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES (v_id, v_passeur.expediteur, (v_orga->>'chef'), 'Quelqu''un à contacter', v_corps,
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);$ancien$,
                          $nouveau$  PERFORM public.mail_systeme_poser_interne(
          v_passeur.expediteur, (v_orga->>'chef'), 'Quelqu''un à contacter', v_corps,
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));$nouveau$);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique sur contact_organisation_demander : le fragment ne correspond pas';
  END IF;
  EXECUTE v_new;
END $mig$;

-- Preuves structurelles.
DO $mig$
DECLARE v_def text; v_acl text; v_oid oid;
BEGIN
  v_oid := 'public.contact_organisation_demander(text,text)'::regprocedure::oid;
  v_def := pg_get_functiondef(v_oid);

  IF v_def ~ 'INSERT INTO\s+(public\.)?mails\s*\(' THEN
    RAISE EXCEPTION 'contact_organisation_demander ecrit encore mails en direct';
  END IF;
  IF (SELECT count(*) FROM regexp_matches(v_def, 'mail_systeme_poser_interne', 'g')) <> 1 THEN
    RAISE EXCEPTION 'contact_organisation_demander n''appelle pas le poseur exactement une fois';
  END IF;
  IF strpos(v_def, 'Quelqu''''un à contacter') = 0 THEN
    RAISE EXCEPTION 'le sujet du courrier du passeur a disparu';
  END IF;
  IF strpos(v_def, '[[act:ecrire_a|') = 0 THEN
    RAISE EXCEPTION 'le marqueur d''action du corps a disparu';
  END IF;

  SELECT array_to_string(ARRAY(SELECT unnest(p.proacl::text[]) ORDER BY 1), ',')
    INTO v_acl FROM pg_proc p WHERE p.oid = v_oid;
  IF v_acl IS DISTINCT FROM 'authenticated=X/postgres,postgres=X/postgres,service_role=X/postgres' THEN
    RAISE EXCEPTION 'droits modifies sur contact_organisation_demander : %', v_acl;
  END IF;

  IF (SELECT count(*) FROM public.mails) <> 28 THEN
    RAISE EXCEPTION 'la migration a cree ou supprime des courriers : % lignes', (SELECT count(*) FROM public.mails);
  END IF;
END $mig$;