-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009132222 (UTC ; 15h22 a Paris), nom
-- `notification_ne_casse_plus_l_acte`. Le registre passe de 567 a 568 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 045cef2393a0a12d95f90ee5b783fabd, 8 158 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- ELLE VA PAR PAIRE AVEC UNE MODIFICATION DU DEPOT : `api/cron-minuit.js`,
-- `envoyerMailSysteme`, qui applique la MEME doctrine du cote JavaScript. Les deux sont dans le
-- meme commit.
--
-- -----------------------------------------------------------------------------
-- LA DOCTRINE, EN TROIS REGLES QUI TIENNENT ENSEMBLE
-- -----------------------------------------------------------------------------
-- 1. UNE NOTIFICATION N'EST PAS L'AUTORITE DE L'ACTE. Un courrier qui ne part pas ne doit ni
--    annuler une operation economique correctement acquise, ni la rendre rejouable.
-- 2. MAIS L'ECHEC NE DOIT JAMAIS ETRE AVALE.
-- 3. DONC LA PORTE NE LEVE PLUS, ET ELLE CONSIGNE.
--
-- Les deux premieres regles sont en tension apparente, et c'est tout le sujet : se proteger
-- d'une exception en l'avalant, c'est perdre l'information ; la laisser remonter, c'est perdre
-- l'acte. La sortie est de SEPARER le canal du courrier de celui de l'incident.
--
-- -----------------------------------------------------------------------------
-- CE QUI ETAIT CASSE, DES DEUX COTES
-- -----------------------------------------------------------------------------
-- COTE SQL, l'INSERT du courrier etait nu dans le corps de `mail_systeme_envoyer`. Une RPC
-- etant UNE SEULE transaction, une exception sur ce seul INSERT emportait l'acte metier entier
-- de l'appelant -- debit, saisie, nomination. Ce n'est pas une hypothese : c'est exactement ce
-- qui se passait tant que `mails.id` n'avait pas de valeur par defaut, et la branche
-- « debiteur a sec » des prets Helvetia tuait la passe nocturne entiere en levant 23502.
--
-- COTE JAVASCRIPT, le defaut etait l'inverse : sur dix-huit appels a `envoyerMailSysteme`,
-- SEIZE portaient un `.catch(() => {})` et AUCUN ne lisait le verdict. `sbInsert` rendant
-- `null` sur HTTP non-2xx, un avis de saisie qui ne partait pas ne laissait aucune trace --
-- ni dans les compteurs, ni dans le journal durable du cron, ni dans le code HTTP de la passe.
--
-- -----------------------------------------------------------------------------
-- CE QUE FAIT LA PORTE MAINTENANT
-- -----------------------------------------------------------------------------
-- L'INSERT est enferme dans son propre bloc `BEGIN ... EXCEPTION WHEN others`. Le rattrapage
-- releve le SQLSTATE et le message par `GET STACKED DIAGNOSTICS`, consigne une ligne dans
-- `mails_envois_systeme` avec l'expediteur, le destinataire, le sujet et l'etat, puis rend
-- `{ok:false, raison:'envoi_impossible', sqlstate:...}`.
--
-- POURQUOI `mails_envois_systeme` ET PAS UNE TABLE NEUVE : cette table existait deja et
-- journalisait les tentatives REFUSEES par l'autorite -- un client demandant a ecrire sous un
-- expediteur qui ne lui est pas autorise. Son nom dit « envois systeme », pas « refus » : son
-- objet est l'incident d'envoi. Une colonne `echec` nullable distingue les deux familles, et le
-- commentaire de table l'ecrit noir sur blanc. Une table de plus aurait eparpille la meme
-- question en deux endroits.
--
-- UNE SUBTILITE DE POSTGRESQL QUI REND TOUT CELA POSSIBLE : un bloc `EXCEPTION` en PL/pgSQL
-- ouvre une SOUS-transaction. L'INSERT echoue, la sous-transaction est annulee -- donc aucun
-- courrier a moitie ecrit -- mais la transaction de l'appelant, elle, reste VIVANTE et peut
-- continuer a ecrire. C'est la preuve M4 du banc, et c'est la propriete qui compte.
--
-- -----------------------------------------------------------------------------
-- CE QUI A ETE PROUVE, ET COMMENT
-- -----------------------------------------------------------------------------
-- BANC EN TRANSACTION ANNULEE, 6 preuves. Pour faire ECHOUER VRAIMENT l'insertion, le banc
-- ajoute une contrainte temporaire sur `mails` -- `CHECK (subject <> 'zz-refuse')` -- puis
-- envoie un courrier portant ce sujet. Simuler l'echec par une contrainte reelle, plutot que
-- par un mock, donne un vrai SQLSTATE 23514 et exerce le chemin exact :
--   . envoi nominal : verdict ok, un courrier ecrit, aucun incident consigne ;
--   . envoi refuse : la fonction NE LEVE PAS, verdict `envoi_impossible`, sqlstate 23514 ;
--   . aucun courrier ecrit, MAIS un incident consigne qui nomme expediteur, destinataire et
--     sujet ;
--   . LA TRANSACTION DE L'APPELANT EST INTACTE : une ecriture faite juste apres l'echec
--     aboutit. Avant, l'exception l'avait tuee ;
--   . deux pertes donnent deux incidents -- on ne deduplique pas une perte ;
--   . les refus metier anterieurs sont inchanges.
-- Verifie annule ensuite : la contrainte temporaire n'a pas survecu, aucun incident ne reste.
--
-- PREUVES STRUCTURELLES, 6 : la colonne `echec` existe et est du bon type ; le rattrapage est
-- present, releve le SQLSTATE et consigne ; le bloc entoure bien l'INSERT dans `mails` et pas
-- autre chose ; les quatre refus metier anterieurs et le controle d'autorite de l'expediteur
-- sont intacts -- on n'a rien relache en protegeant ; autorite, `search_path` et droits
-- identiques apres reecriture (`authenticated`, `postgres`, `service_role`) ; AUCUNE DONNEE
-- TOUCHEE -- 28 courriers et 11 envois systeme, comptes exacts, et ni la contrainte ni les
-- incidents du banc n'ont survecu.
--
-- -----------------------------------------------------------------------------
-- CE QUI RESTE : L'ADOPTION
-- -----------------------------------------------------------------------------
-- La porte est protegee ; les NEUF sites qui ecrivent `public.mails` EN DIRECT, sans passer par
-- elle, ne le sont pas -- 7 dans `traiter_prets_helvetia_quotidien`, 2 dans
-- `finaliser_achat_bien_helvetia`, tous deux du domaine `banque`. Leur cause principale est
-- fermee depuis que `mails.id` porte un defaut (migration 20261009003201), mais une autre
-- erreur d'insertion emporterait encore leur transaction. Les router vers la porte est un lot a
-- part : neuf ancres a poser dans deux fonctions, et c'est de la suppression de duplication
-- (priorite 3), pas de la robustesse (priorite 4) -- l'ordre des priorites du projet dit de
-- fermer la robustesse d'abord, ce que ce lot fait.
-- =============================================================================

-- Chantier 5 -- DOCTRINE DE LA NOTIFICATION. Une notification n'est pas l'autorite de l'acte :
-- l'echec d'un courrier ne doit ni annuler une operation metier correctement acquise, ni la
-- rendre rejouable -- mais il ne doit jamais etre avale. L'INSERT du courrier est donc enferme
-- dans son propre bloc d'exception, et l'incident est consigne dans mails_envois_systeme avec
-- son SQLSTATE. Une RPC etant une seule transaction, une exception non rattrapee emportait
-- l'acte entier : c'est ce qui se passait quand mails.id n'avait pas de defaut.
-- Banc annule : 6 preuves vertes, dont « la transaction de l'appelant est intacte apres la
-- perte », eprouvee en faisant reellement echouer l'insertion par une contrainte temporaire.
ALTER TABLE public.mails_envois_systeme ADD COLUMN IF NOT EXISTS echec text;

COMMENT ON TABLE public.mails_envois_systeme IS
'INCIDENTS D''ENVOI SYSTEME. Deux familles, distinguees par la colonne `echec` :
  . `echec` NULL  -> tentative REFUSEE par l''autorite : un client a demande a mail_systeme_envoyer
    d''ecrire sous un expediteur qui ne lui est pas autorise. La ligne nomme l''auteur reel.
  . `echec` renseigne -> envoi ACCEPTE mais IMPOSSIBLE : l''INSERT dans mails a leve, et la
    doctrine du 9 octobre 2026 veut que cela n''annule pas l''acte metier de l''appelant. La
    ligne porte le SQLSTATE et le message, pour que le courrier perdu reste nommable.
Dans les deux cas : aucune perte silencieuse. C''est la raison d''etre de cette table.';
COMMENT ON COLUMN public.mails_envois_systeme.echec IS
'SQLSTATE et message de l''erreur qui a empeche l''ecriture du courrier, quand il y en a une.
NULL quand la ligne consigne un refus d''autorite et non un echec technique.';

CREATE OR REPLACE FUNCTION public.mail_systeme_envoyer(p_expediteur text, p_destinataire text, p_sujet text, p_corps text, p_heure text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_id text; v_etat text; v_msg text;
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

  v_id := 'mail-' || (extract(epoch from clock_timestamp())*1000)::bigint
                  || '-' || substr(md5(random()::text), 1, 6);

  -- UNE NOTIFICATION N'EST PAS L'AUTORITE DE L'ACTE (doctrine du 9 octobre 2026). Cet INSERT
  -- est enferme dans son propre bloc : une erreur ici ne doit PAS annuler l'operation metier
  -- de l'appelant, qui est peut-etre un debit, une saisie ou une nomination deja acquise. Une
  -- RPC etant une seule transaction, une exception non rattrapee emportait tout -- c'est
  -- exactement ce qui se passait quand mails.id n'avait pas de valeur par defaut : la branche
  -- « debiteur a sec » des prets Helvetia levait 23502 et tuait la passe entiere.
  --
  -- MAIS L'ECHEC N'EST PAS AVALE : il est consigne dans mails_envois_systeme, avec son SQLSTATE
  -- et son message. Le courrier perdu est donc nommable, et le verdict rendu dit ok=false.
  BEGIN
    INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
    VALUES (v_id, p_expediteur, p_destinataire, p_sujet, p_corps,
            coalesce(p_heure, to_char(now() AT TIME ZONE 'Europe/Paris', 'HH24') || 'h'), false);
  EXCEPTION WHEN others THEN
    GET STACKED DIAGNOSTICS v_etat = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    INSERT INTO public.mails_envois_systeme (auteur_reel, expediteur, destinataire, sujet, echec)
    VALUES (v_moi, p_expediteur, p_destinataire, left(coalesce(p_sujet,''),200),
            v_etat || ' ' || left(coalesce(v_msg,''), 300));
    RETURN jsonb_build_object('ok', false, 'raison', 'envoi_impossible', 'sqlstate', v_etat);
  END;

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$function$;

DO $$
DECLARE v_def text; v_n int; v_droits text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'mail_systeme_envoyer';

  -- P1 : la colonne d'incident existe, et elle est du bon type.
  IF (SELECT format_type(atttypid, atttypmod) FROM pg_attribute
       WHERE attrelid = 'public.mails_envois_systeme'::regclass AND attname = 'echec'
         AND NOT attisdropped) <> 'text' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- la colonne echec est absente ou mal typee';
  END IF;

  -- P2 : l'INSERT du courrier est bien enferme dans un bloc d'exception, et le bloc consigne.
  IF v_def !~ 'EXCEPTION WHEN others THEN' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- aucun rattrapage autour de l''insertion du courrier';
  END IF;
  IF position('GET STACKED DIAGNOSTICS v_etat = RETURNED_SQLSTATE' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le SQLSTATE n''est pas releve';
  END IF;
  IF position('INSERT INTO public.mails_envois_systeme (auteur_reel, expediteur, destinataire, sujet, echec)' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- l''incident n''est pas consigne';
  END IF;
  IF v_def !~ 'envoi_impossible' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le verdict d''echec n''est pas nomme';
  END IF;

  -- P3 : le rattrapage entoure l'INSERT dans mails, et pas autre chose.
  IF position('BEGIN
    INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le bloc ne protege pas l''insertion du courrier';
  END IF;

  -- P4 : les refus metier anterieurs sont intacts -- on n'a rien relache en protegeant.
  IF v_def !~ 'acteur_non_authentifie' OR v_def !~ 'parametres_invalides'
     OR v_def !~ 'expediteur_non_autorise' THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- un refus metier a disparu de la porte';
  END IF;
  IF v_def !~ 'mail_expediteur_autorise_strict' THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le controle d''autorite de l''expediteur a disparu';
  END IF;

  -- P5 : autorite, search_path et droits identiques apres reecriture.
  IF v_def !~ 'SECURITY DEFINER' OR v_def !~ 'search_path TO ''public'', ''pg_temp''' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- autorite ou search_path modifies';
  END IF;
  SELECT string_agg(coalesce(r.rolname,'PUBLIC')||':'||ae.privilege_type, ', '
                    ORDER BY coalesce(r.rolname,'PUBLIC'))
    INTO v_droits
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    CROSS JOIN LATERAL aclexplode(p.proacl) ae LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.proname = 'mail_systeme_envoyer';
  IF v_droits IS DISTINCT FROM 'authenticated:EXECUTE, postgres:EXECUTE, service_role:EXECUTE' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- les droits sont « % »', v_droits;
  END IF;

  -- P6 : AUCUNE DONNEE TOUCHEE, et la contrainte temporaire du banc n'a pas survecu.
  SELECT count(*) INTO v_n FROM public.mails;
  IF v_n <> 28 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % mails au lieu de 28', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.mails_envois_systeme;
  IF v_n <> 11 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % envois systeme au lieu de 11', v_n; END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.mails'::regclass
              AND conname = 'zz_banc_refuse') THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- la contrainte temporaire du banc a survecu';
  END IF;
  IF EXISTS (SELECT 1 FROM public.mails_envois_systeme WHERE echec IS NOT NULL) THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- un incident du banc a survecu';
  END IF;

  RAISE NOTICE 'SIX PREUVES STRUCTURELLES VERTES.';
END $$;