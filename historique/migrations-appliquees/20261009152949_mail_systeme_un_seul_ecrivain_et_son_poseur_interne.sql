-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009152949 (UTC ; 17h29 a Paris), nom
-- `mail_systeme_un_seul_ecrivain_et_son_poseur_interne`. Le registre passe de 575 a 576 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 15643a15858512dd55a2f12f27da89eb, 11 323 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle construit l'unique ecrivain de `public.mails` : `mail_systeme_poser_interne`, un moteur sans
-- controle d'expediteur, injoignable depuis le reseau (EXECUTE retire a `anon`, `authenticated` ET
-- `service_role`), qui ne leve jamais et consigne tout echec dans `mails_envois_systeme` avec son
-- SQLSTATE. `mail_systeme_envoyer` devient la porte reseau : elle garde sa liste blanche et son
-- controle d'identite, puis delegue l'ecriture. Ce lot ne route encore personne -- dix fonctions
-- ecrivent toujours en direct, et la preuve P4 le dit tel quel ; les six lots suivants les routent.
--
-- ELLE VA PAR PAIRE AVEC LE DEPOT : `api/cron-minuit.js` (`envoyerMailSysteme`) et
-- `api/_journal-generation.js` (sollicitation d'interview).
-- =============================================================================

-- Chantier 5 -- UN SEUL ECRIVAIN DE public.mails, ET DEUX FACONS DE L'ATTEINDRE.
--
-- Dix fonctions SQL ecrivent encore `public.mails` en direct, seize INSERT au total. Cinq d'entre
-- elles n'ont AUCUN bloc d'exception : une contrainte violee sur la table des courriers emporte
-- l'operation metier de l'appelant. Ce n'est pas une crainte theorique -- la branche « debiteur a
-- sec » de traiter_prets_helvetia_quotidien a tue une passe entiere le jour ou `mails.id` n'avait
-- pas de valeur par defaut. Deux autres font l'inverse et avalent l'echec en silence
-- (`EXCEPTION WHEN OTHERS THEN NULL`), sans rien consigner : le courrier perdu n'est meme pas
-- nommable.
--
-- POURQUOI mail_systeme_envoyer NE PEUT PAS LES RECEVOIR TELLES QUELLES. Elle verifie
-- `mail_expediteur_autorise_strict` des que l'appel n'est PAS un appel serveur. Or ces dix
-- fonctions expedient sous des identites institutionnelles qui ne figurent PAS dans
-- `mails_expediteurs_systeme` -- « Commissariat », « Service de renseignement », « État-major »,
-- « Banque Nationale », l'expediteur propre a chaque passeur -- et plusieurs sont appelees par un
-- NAVIGATEUR (arrestation, acceptation d'engagement, demande de contact). Les y router
-- directement aurait refuse ces courriers en silence. Et inscrire ces identites en « libre »
-- aurait ouvert a n'importe quel joueur le droit d'ecrire « État-major » : un relachement de la
-- liste blanche, pas un chantier de robustesse.
--
-- LE PATRON EST CELUI DE LA DETENTION, ETABLI CE MATIN : un MOTEUR sans controle d'autorite,
-- injoignable depuis le reseau, et des portes qui portent le controle.
--   * mail_systeme_poser_interne -- l'unique INSERT. Ne leve jamais, consigne tout echec dans
--     mails_envois_systeme avec son SQLSTATE, rend un verdict. AUCUN controle d'expediteur :
--     c'est la fonction appelante qui a deja verifie sa propre autorite pour faire son acte.
--   * mail_systeme_envoyer -- la porte du reseau. Garde son controle d'identite ET sa liste
--     blanche d'expediteurs, inchanges, puis delegue l'ecriture au moteur.
--
-- L'ARCHITECTURE N'EST PAS UNE CONVENTION, C'EST UN DROIT QU'ON RETIRE : le moteur n'a EXECUTE
-- pour personne d'autre que son proprietaire -- `service_role` compris, exactement comme
-- acte_nocturne_revendiquer. Les dix fonctions l'atteignent parce qu'elles sont elles-memes
-- SECURITY DEFINER et s'executent donc sous ce proprietaire ; le cron, lui, continue de passer
-- par la porte reseau, qui lui est ouverte.
--
-- CE QUI CHANGE DANS LES COURRIERS : rien de ce qui est lu. Expediteur, destinataire, sujet,
-- corps et heure sont transmis tels quels. Seule la FORME DE L'IDENTIFIANT change pour les
-- fonctions qui en fabriquaient un a elles (`ce-…`, `placement_…`) : il devient `mail-…`, la
-- forme que la colonne porte par defaut. Aucune table, aucun code et aucun affichage ne lit
-- l'identifiant d'un courrier autrement que pour le marquer lu ou supprime.
CREATE OR REPLACE FUNCTION public.mail_systeme_poser_interne(
  p_expediteur text, p_destinataire text, p_sujet text, p_corps text, p_heure text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_id text; v_etat text; v_msg text;
BEGIN
  IF coalesce(btrim(p_expediteur),'') = '' OR coalesce(btrim(p_destinataire),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  v_id := 'mail-' || (extract(epoch from clock_timestamp())*1000)::bigint
                  || '-' || substr(md5(random()::text), 1, 6);

  -- UNE NOTIFICATION N'EST PAS L'AUTORITE DE L'ACTE (doctrine du 9 octobre 2026). Cet INSERT est
  -- enferme dans son propre bloc : une erreur ici ne doit PAS annuler l'operation metier de
  -- l'appelant, qui est peut-etre une arrestation, une saisie ou une nomination deja acquise.
  -- Une RPC etant une seule transaction, une exception non rattrapee emportait tout.
  --
  -- MAIS L'ECHEC N'EST PAS AVALE : il est consigne avec son SQLSTATE et son message. Le courrier
  -- perdu est donc nommable, et le verdict rendu dit ok=false.
  BEGIN
    INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
    VALUES (v_id, p_expediteur, p_destinataire, p_sujet, p_corps,
            coalesce(p_heure, to_char(now() AT TIME ZONE 'Europe/Paris', 'HH24') || 'h'), false);
  EXCEPTION WHEN others THEN
    GET STACKED DIAGNOSTICS v_etat = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    INSERT INTO public.mails_envois_systeme (auteur_reel, expediteur, destinataire, sujet, echec)
    VALUES (public.mon_personnage(), p_expediteur, p_destinataire, left(coalesce(p_sujet,''),200),
            v_etat || ' ' || left(coalesce(v_msg,''), 300));
    RETURN jsonb_build_object('ok', false, 'raison', 'envoi_impossible', 'sqlstate', v_etat);
  END;

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END; $fn$;

REVOKE EXECUTE ON FUNCTION public.mail_systeme_poser_interne(text,text,text,text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mail_systeme_poser_interne(text,text,text,text,text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.mail_systeme_poser_interne(text,text,text,text,text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.mail_systeme_poser_interne(text,text,text,text,text) FROM service_role;

-- La porte du reseau garde EXACTEMENT ses deux controles -- identite, puis liste blanche des
-- expediteurs avec sa journalisation du refus -- et ne duplique plus l'ecriture.
CREATE OR REPLACE FUNCTION public.mail_systeme_envoyer(
  p_expediteur text, p_destinataire text, p_sujet text, p_corps text, p_heure text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF coalesce(btrim(p_expediteur),'') = '' OR coalesce(btrim(p_destinataire),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF NOT public.est_appel_serveur()
     AND NOT public.mail_expediteur_autorise_strict(p_expediteur, p_destinataire) THEN
    INSERT INTO public.mails_envois_systeme (auteur_reel, expediteur, destinataire, sujet)
    VALUES (v_moi, p_expediteur, p_destinataire, left(coalesce(p_sujet,''),200));
    RETURN jsonb_build_object('ok', false, 'raison', 'expediteur_non_autorise');
  END IF;
  RETURN public.mail_systeme_poser_interne(p_expediteur, p_destinataire, p_sujet, p_corps, p_heure);
END; $fn$;

COMMENT ON FUNCTION public.mail_systeme_poser_interne(text,text,text,text,text) IS
'UNIQUE ECRIVAIN de public.mails cote serveur. Ne leve JAMAIS : tout echec est consigne dans
mails_envois_systeme avec son SQLSTATE et rendu en ok=false, pour qu''un courrier impossible
n''annule pas l''acte metier qui l''a declenche. N''a AUCUN controle d''expediteur -- c''est le
role de ses appelants, qui ont deja verifie leur propre autorite. Non appelable depuis le reseau :
les fonctions qui l''atteignent sont SECURITY DEFINER et s''executent sous son proprietaire.';
COMMENT ON FUNCTION public.mail_systeme_envoyer(text,text,text,text,text) IS
'Porte RESEAU des courriers systeme : verifie l''identite de l''appelant puis sa liste blanche
d''expediteurs (mail_expediteur_autorise_strict), et delegue l''ecriture a
mail_systeme_poser_interne. Un appel serveur traverse les deux controles. Verdicts :
acteur_non_authentifie, parametres_invalides, expediteur_non_autorise, envoi_impossible, puis ok
avec l''identifiant du courrier.';

DO $$
DECLARE v_def text; v_droits text; v_n int;
BEGIN
  -- P1 : le moteur existe, n'a aucun controle d'expediteur, et ne leve pas.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='mail_systeme_poser_interne';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- le moteur n''existe pas'; END IF;
  IF position('INSERT INTO public.mails ' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le moteur n''ecrit pas les courriers'; END IF;
  IF position('EXCEPTION WHEN others THEN' in v_def) = 0
     OR position('mails_envois_systeme' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- un echec de courrier emporterait l''acte'; END IF;
  IF position('mail_expediteur_autorise_strict' in v_def) > 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le moteur controle l''expediteur : les identites institutionnelles seraient refusees';
  END IF;

  -- P2 : la porte reseau garde SES DEUX controles et delegue l'ecriture.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='mail_systeme_envoyer';
  IF position('mail_expediteur_autorise_strict' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la porte a perdu sa liste blanche'; END IF;
  IF position('acteur_non_authentifie' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la porte a perdu son controle d''identite'; END IF;
  IF position('mail_systeme_poser_interne' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la porte ne delegue pas au moteur'; END IF;
  IF position('INSERT INTO public.mails ' in v_def) > 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la porte ecrit encore elle-meme les courriers'; END IF;

  -- P3 : les droits. Le moteur n'a EXECUTE pour personne d'autre que son proprietaire.
  SELECT string_agg(coalesce(r.rolname,'PUBLIC'), ',' ORDER BY coalesce(r.rolname,'PUBLIC'))
    INTO v_droits FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
    CROSS JOIN LATERAL aclexplode(p.proacl) ae LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.proname='mail_systeme_poser_interne';
  IF v_droits IS DISTINCT FROM 'postgres' THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- droits du moteur : %', v_droits; END IF;
  IF NOT has_function_privilege('authenticated','public.mail_systeme_envoyer(text,text,text,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la porte reseau n''est plus appelable par un joueur'; END IF;
  IF NOT has_function_privilege('service_role','public.mail_systeme_envoyer(text,text,text,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le cron ne peut plus notifier'; END IF;

  -- P4 : L'INVENTAIRE EST DIT TEL QU'IL EST. Dix fonctions ecrivent encore en direct ; ce lot
  -- construit le moteur, les suivants les y routent. Ce compte TOMBERA quand elles seront
  -- migrees -- et c'est voulu : la preuve suivante devra etre reecrite avec le vrai compte.
  SELECT count(*) INTO v_n FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE pg_get_functiondef(p.oid) ~ 'INSERT INTO\s+(public\.)?mails\s*\('
     AND p.proname NOT IN ('mail_systeme_poser_interne','mail_systeme_envoyer');
  IF v_n <> 10 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- % fonction(s) ecrivent encore mails en direct au lieu de 10', v_n;
  END IF;

  -- P5 : AUCUN COURRIER CREE PAR CE LOT.
  SELECT count(*) INTO v_n FROM public.mails;
  IF v_n <> 28 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % courriers au lieu de 28', v_n; END IF;

  RAISE NOTICE 'CINQ PREUVES STRUCTURELLES VERTES.';
END $$;