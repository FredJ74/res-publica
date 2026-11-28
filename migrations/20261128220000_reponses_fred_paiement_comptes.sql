-- Réponses de Fred du 28/11/2026 (soir), points 8 et 9 (questions 15 à 29 de la mission de l'après-midi).
-- Point 8 — paiement (déjà conforme sauf la Biélorussie) :
--   prix TTC partout (tax_behavior « inclusive », déjà), codes fiscaux txcd_10201004 / txcd_10000000 confirmés (déjà),
--   Monaco et les DOM comme la France, territoires hors UE par Managed Payments (liste paiement_pays_ue, déjà),
--   remboursement d'erreur fait depuis Stripe sans couper l'abonnement (déjà), nom légal du vendeur : réglage serveur
--   vide tant que Fred ne l'a pas fourni (déjà). Ici : la Biélorussie (BY) rejoint les pays exclus, comme la Russie.
-- Point 9 — comptes :
--   a. Comptes sans adresse e-mail : supprimés eux aussi après 3 ans d'inactivité, sans avertissement possible
--      (comptes_inactifs_lister, compte_inactif_supprimer ; marque comptes_sans_email_v1). Le traitement de nuit
--      (api/_comptes-inactifs.js) parcourt déjà la liste « supprimer » sans passer par l'envoi d'e-mails.
--   b. Une suspension de modération bloque aussi le forum (sujets, réponses, modifications de ses messages), le courrier
--      et le chat : déclencheurs sur forum_topics, forum_posts, mails et messages_chat (erreur « compte_suspendu »,
--      détail = la sanction). Jamais pour le serveur, les administrateurs ni les comptes de test.
--   c. Traces au goulag : elles ne bloquent plus la suppression d'un personnage. Les clés étrangères des tables
--      sovarka_goulag_* vers personnages_donnees sont remplacées par un contrôle à l'écriture (un nom inconnu reste
--      refusé) ; à la suppression du personnage, ses traces sont rendues anonymes (« Ancien détenu » ; « Ancien joueur »
--      quand il y figurait comme interrogateur, juge ou ministre), son séjour en cours est clos, ses lignes d'état
--      personnel (visite, refuge, traversée : une ligne par nom) sont effacées. L'historique (registre, entrées,
--      incidents, tentatives, corruptions, dépôts, interrogatoires, traces révélées, autorisations) reste.
--      Un changement de nom d'un personnage ayant des traces reste refusé, comme avant.
--   d. CGV : la case existante avant chaque paiement suffit (déjà : juridique_textes_a_accepter_interne ne demande que
--      CGU et confidentialité ; premium_achat_consentir_service exige la case CGV à chaque achat).
--   e. Accords gardés après la suppression du compte, rattachés au seul identifiant technique (déjà :
--      compte_effacer_interne n'efface pas juridique_accords, qui ne porte ni nom ni adresse).
--   f. Export : masque l'auteur réel d'un courrier signé par une organisation ou anonyme quand ce n'est pas le joueur ;
--      ne contient ni les signalements reçus, ni les auteurs secrets, ni le journal des incidents du navigateur
--      (indicateurs internes) ; garde toutes les données propres au joueur. Clé « masques » ajoutée (marque export_masques_v1).
-- Textes de la notification de suspension mis à jour dans les 9 langues (marque moderation_suspension_ecrits_v1).
-- Le blocage d'acceptation des CGU (juridique_parametres.blocage_ordres) n'est PAS touché : il reste éteint.
-- Rejouable.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text[], p_apres text[], p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer; i integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  FOR i IN 1 .. array_length(p_avant, 1) LOOP
    n := (length(d) - length(replace(d, p_avant[i], ''))) / length(p_avant[i]);
    IF n <> 1 THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de 1 (%)', p_fn, n, left(p_avant[i], 70); END IF;
    d := replace(d, p_avant[i], p_apres[i]);
  END LOOP;
  EXECUTE d;
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente (%)', p_fn, p_marque; END IF;
END $$;

-- ===================================================================== 8. Biélorussie exclue, comme la Russie
UPDATE public.premium_parametres
   SET valeur = CASE WHEN btrim(valeur) = '' THEN 'BY' ELSE valeur || ',BY' END, maj_le = now()
 WHERE cle = 'paiement_pays_exclus' AND NOT ('BY' = ANY (string_to_array(replace(valeur, ' ', ''), ',')));

-- ===================================================================== 9a. Comptes sans adresse e-mail
SELECT pg_temp.rp_remplacer('public.comptes_inactifs_lister(integer)'::regprocedure,
  ARRAY[$q$          JOIN public.comptes_inactifs_avertissements w ON w.user_id = a.user_id
         WHERE a.activite < now() - interval '3 years'
           AND w.averti_le > a.activite AND w.averti_le <= now() - interval '30 days'$q$],
  ARRAY[$q$          LEFT JOIN public.comptes_inactifs_avertissements w ON w.user_id = a.user_id
         WHERE a.activite < now() - interval '3 years'
           -- comptes_sans_email_v1 (Fred, 28/11/2026 soir) : sans adresse, suppression sans avertissement possible.
           AND ((w.averti_le > a.activite AND w.averti_le <= now() - interval '30 days') OR coalesce(a.email, '') = '')$q$],
  'comptes_sans_email_v1');

SELECT pg_temp.rp_remplacer('public.compte_inactif_supprimer(uuid)'::regprocedure,
  ARRAY[$q$    JOIN public.comptes_inactifs_avertissements w ON w.user_id = x.user_id
   WHERE x.user_id = p_uid AND x.activite < now() - interval '3 years'
     AND w.averti_le > x.activite AND w.averti_le <= now() - interval '30 days';$q$],
  ARRAY[$q$    LEFT JOIN public.comptes_inactifs_avertissements w ON w.user_id = x.user_id
   WHERE x.user_id = p_uid AND x.activite < now() - interval '3 years'
     -- comptes_sans_email_v1 : un compte sans adresse ne peut pas être averti ; il est supprimé quand même.
     AND ((w.averti_le > x.activite AND w.averti_le <= now() - interval '30 days') OR coalesce(x.email, '') = '');$q$],
  'comptes_sans_email_v1');

-- ===================================================================== 9b. Suspension : forum, courrier, chat
CREATE OR REPLACE FUNCTION public.moderation_suspension_active_interne(p_uid uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.moderation_sanction_json_interne(m) FROM public.moderation_sanctions m
   WHERE m.user_id = p_uid AND m.type = 'suspension' AND m.levee_le IS NULL AND m.debut <= now() AND m.fin > now()
   ORDER BY m.fin DESC LIMIT 1;
$$;

-- Écrire au forum, envoyer un courrier ou un message de chat : refusé pendant une suspension (Fred, 28/11/2026 soir).
-- Modification d'un message du forum : refusée seulement si le suspendu en est l'auteur (les compteurs tenus par
-- d'autres restent libres).
CREATE OR REPLACE FUNCTION public.moderation_ecrits_suspension_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_uid uuid := auth.uid(); s jsonb; v_moi text; o jsonb;
BEGIN
  IF v_uid IS NULL OR public.est_appel_serveur() THEN RETURN NEW; END IF;
  s := public.moderation_suspension_active_interne(v_uid);
  IF s IS NULL OR public.est_administrateur() THEN RETURN NEW; END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NOT NULL AND public.est_compte_test(v_moi) THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' THEN
    o := to_jsonb(OLD);
    IF v_moi IS NULL OR NOT (o ->> 'author' IS NOT DISTINCT FROM v_moi OR o ->> 'author_real' IS NOT DISTINCT FROM v_moi) THEN
      RETURN NEW;
    END IF;
  END IF;
  RAISE EXCEPTION 'compte_suspendu' USING ERRCODE = 'P0001', DETAIL = s::text, HINT = 'moderation_suspension';
END $$;
REVOKE ALL ON FUNCTION public.moderation_suspension_active_interne(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.moderation_ecrits_suspension_trg() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_moderation_suspension_ecrits ON public.forum_topics;
CREATE TRIGGER trg_moderation_suspension_ecrits BEFORE INSERT OR UPDATE ON public.forum_topics
  FOR EACH ROW EXECUTE FUNCTION public.moderation_ecrits_suspension_trg();
DROP TRIGGER IF EXISTS trg_moderation_suspension_ecrits ON public.forum_posts;
CREATE TRIGGER trg_moderation_suspension_ecrits BEFORE INSERT OR UPDATE ON public.forum_posts
  FOR EACH ROW EXECUTE FUNCTION public.moderation_ecrits_suspension_trg();
DROP TRIGGER IF EXISTS trg_moderation_suspension_ecrits ON public.mails;
CREATE TRIGGER trg_moderation_suspension_ecrits BEFORE INSERT ON public.mails
  FOR EACH ROW EXECUTE FUNCTION public.moderation_ecrits_suspension_trg();
DROP TRIGGER IF EXISTS trg_moderation_suspension_ecrits ON public.messages_chat;
CREATE TRIGGER trg_moderation_suspension_ecrits BEFORE INSERT ON public.messages_chat
  FOR EACH ROW EXECUTE FUNCTION public.moderation_ecrits_suspension_trg();

-- Notification de la sanction : la suspension bloque aussi le forum, le courrier et le chat (9 langues).
SELECT pg_temp.rp_remplacer('public.moderation_notification_texte_interne(text,public.moderation_sanctions)'::regprocedure,
  ARRAY[
    'vos ordres sont bloqués pendant la durée indiquée.',
    'your orders are blocked for the stated period.',
    'sus órdenes quedan bloqueadas durante el periodo indicado.',
    'Ihre Befehle sind für den angegebenen Zeitraum blockiert.',
    'ваши приказы недоступны в течение указанного срока.',
    '표시된 기간 동안 명령을 내릴 수 없습니다.',
    'أوامرك محظورة طوال المدة المذكورة.',
    'suas ordens ficam bloqueadas durante o período indicado.',
    '在所示期間內無法下達命令。',
    $q$BEGIN
  t := coalesce($q$],
  ARRAY[
    'vos ordres, le forum, le courrier et le chat sont bloqués pendant la durée indiquée.',
    'your orders, forum, mail and chat are blocked for the stated period.',
    'sus órdenes, el foro, el correo y el chat quedan bloqueados durante el periodo indicado.',
    'Ihre Befehle, das Forum, die Post und der Chat sind für den angegebenen Zeitraum blockiert.',
    'ваши приказы, форум, почта и чат недоступны в течение указанного срока.',
    '표시된 기간 동안 명령, 포럼, 우편, 채팅을 이용할 수 없습니다.',
    'أوامرك والمنتدى والبريد والدردشة محظورة طوال المدة المذكورة.',
    'suas ordens, o fórum, o correio e o chat ficam bloqueados durante o período indicado.',
    '在所示期間內無法下達命令，也無法使用論壇、信件與聊天。',
    $q$BEGIN
  -- moderation_suspension_ecrits_v1 (Fred, 28/11/2026 soir) : la suspension bloque aussi forum, courrier et chat.
  t := coalesce($q$],
  'moderation_suspension_ecrits_v1');

-- ===================================================================== 9c. Traces au goulag rendues anonymes
-- Contrôle à l'écriture qui remplace les clés étrangères : le nom doit être celui d'un personnage existant, ou l'une
-- des deux mentions anonymes. Une mise à jour qui ne change pas la colonne n'est pas contrôlée.
CREATE OR REPLACE FUNCTION public.goulag_nom_verifier_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c text; v text; n jsonb := to_jsonb(NEW); o jsonb;
BEGIN
  IF TG_OP = 'UPDATE' THEN o := to_jsonb(OLD); END IF;
  FOREACH c IN ARRAY TG_ARGV LOOP
    v := n ->> c;
    CONTINUE WHEN TG_OP = 'UPDATE' AND v IS NOT DISTINCT FROM (o ->> c);
    CONTINUE WHEN v IS NULL OR v IN ('Ancien détenu', 'Ancien joueur');
    IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = v) THEN
      RAISE EXCEPTION '%.% : personnage inconnu (%)', TG_TABLE_NAME, c, v USING ERRCODE = '23503';
    END IF;
  END LOOP;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.goulag_traces_existent_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.sovarka_goulag_registre WHERE nom = p_nom)
      OR EXISTS (SELECT 1 FROM public.sovarka_goulag_entrees WHERE nom = p_nom)
      OR EXISTS (SELECT 1 FROM public.sovarka_goulag_incidents WHERE nom = p_nom)
      OR EXISTS (SELECT 1 FROM public.sovarka_goulag_tentatives WHERE nom = p_nom)
      OR EXISTS (SELECT 1 FROM public.sovarka_goulag_corruptions WHERE nom = p_nom)
      OR EXISTS (SELECT 1 FROM public.sovarka_goulag_depots WHERE nom = p_nom)
      OR EXISTS (SELECT 1 FROM public.sovarka_goulag_traces_revelees WHERE nom = p_nom)
      OR EXISTS (SELECT 1 FROM public.sovarka_goulag_autorisations WHERE nom = p_nom)
      OR EXISTS (SELECT 1 FROM public.sovarka_goulag_visites WHERE nom = p_nom)
      OR EXISTS (SELECT 1 FROM public.sovarka_goulag_refuges WHERE nom = p_nom)
      OR EXISTS (SELECT 1 FROM public.sovarka_goulag_traversees WHERE nom = p_nom)
      OR EXISTS (SELECT 1 FROM public.sovarka_goulag_interrogatoires WHERE detenu = p_nom OR interrogateur = p_nom);
$$;

-- Anonymisation des traces d'un personnage qui disparaît (appelée par le déclencheur de suppression de la fiche).
CREATE OR REPLACE FUNCTION public.goulag_traces_anonymiser_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c_det constant text := 'Ancien détenu'; c_j constant text := 'Ancien joueur'; n integer := 0; k integer;
BEGIN
  IF coalesce(btrim(p_nom), '') = '' OR p_nom IN (c_det, c_j) THEN RETURN jsonb_build_object('ok', true, 'lignes', 0); END IF;
  -- États personnels (une ligne par nom) : sans objet une fois le personnage disparu.
  DELETE FROM public.sovarka_goulag_visites WHERE nom = p_nom; GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  DELETE FROM public.sovarka_goulag_refuges WHERE nom = p_nom; GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  DELETE FROM public.sovarka_goulag_traversees WHERE nom = p_nom; GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  -- Séjour en cours : clos à la disparition (ni évadé ni réincarcéré).
  UPDATE public.sovarka_goulag_registre SET liberation_le = now()
   WHERE nom = p_nom AND liberation_le IS NULL AND evasion_le IS NULL AND reincarcere_le IS NULL;
  -- Demande ou autorisation de visite encore valable : révoquée.
  UPDATE public.sovarka_goulag_autorisations SET etat = 'revoquee', revoquee_le = coalesce(revoquee_le, now())
   WHERE nom = p_nom AND etat IN ('demandee', 'accordee');
  -- Historique : gardé, rendu anonyme.
  UPDATE public.sovarka_goulag_registre SET nom = c_det WHERE nom = p_nom; GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  UPDATE public.sovarka_goulag_entrees SET nom = c_det WHERE nom = p_nom; GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  UPDATE public.sovarka_goulag_incidents SET nom = c_det WHERE nom = p_nom; GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  UPDATE public.sovarka_goulag_tentatives SET nom = c_det WHERE nom = p_nom; GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  UPDATE public.sovarka_goulag_corruptions SET nom = c_det WHERE nom = p_nom; GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  UPDATE public.sovarka_goulag_depots SET nom = c_det WHERE nom = p_nom; GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  UPDATE public.sovarka_goulag_autorisations SET nom = c_det WHERE nom = p_nom; GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  UPDATE public.sovarka_goulag_traces_revelees t SET nom = c_det
   WHERE t.nom = p_nom AND NOT EXISTS (SELECT 1 FROM public.sovarka_goulag_traces_revelees x
                                        WHERE x.nom = c_det AND x.trace_cle = t.trace_cle);
  GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  DELETE FROM public.sovarka_goulag_traces_revelees WHERE nom = p_nom;   -- doublon exact d'une trace déjà anonyme
  UPDATE public.sovarka_goulag_interrogatoires SET detenu = c_det WHERE detenu = p_nom; GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  UPDATE public.sovarka_goulag_interrogatoires SET interrogateur = c_j WHERE interrogateur = p_nom; GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  UPDATE public.sovarka_goulag_interrogatoires SET juge = c_j WHERE juge = p_nom;
  UPDATE public.sovarka_goulag_registre SET juge = c_j WHERE juge = p_nom;
  UPDATE public.sovarka_goulag_traces_revelees SET juge = c_j WHERE juge = p_nom;
  UPDATE public.sovarka_goulag_autorisations SET ministre = c_j WHERE ministre = p_nom;
  RETURN jsonb_build_object('ok', true, 'lignes', n);
END $$;

CREATE OR REPLACE FUNCTION public.personnages_goulag_traces_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.goulag_traces_anonymiser_interne(OLD.name);   -- goulag_anonymiser_v1
    RETURN OLD;
  END IF;
  IF NEW.name IS DISTINCT FROM OLD.name AND public.goulag_traces_existent_interne(OLD.name) THEN
    RAISE EXCEPTION 'personnage % : traces au goulag, changement de nom refusé', OLD.name USING ERRCODE = '23503';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.goulag_nom_verifier_trg() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.goulag_traces_existent_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.goulag_traces_anonymiser_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.personnages_goulag_traces_trg() FROM PUBLIC, anon, authenticated;

-- Dernier des déclencheurs BEFORE de la fiche (ordre alphabétique) : n'anonymise que si la suppression a bien lieu.
DROP TRIGGER IF EXISTS trg_zz_personnages_goulag_traces ON public.personnages_donnees;
CREATE TRIGGER trg_zz_personnages_goulag_traces BEFORE DELETE OR UPDATE OF name ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_goulag_traces_trg();

ALTER TABLE public.sovarka_goulag_traversees DROP CONSTRAINT IF EXISTS sovarka_goulag_traversees_nom_fkey;
ALTER TABLE public.sovarka_goulag_depots DROP CONSTRAINT IF EXISTS sovarka_goulag_depots_nom_fkey;
ALTER TABLE public.sovarka_goulag_autorisations DROP CONSTRAINT IF EXISTS sovarka_goulag_autorisations_nom_fkey;
ALTER TABLE public.sovarka_goulag_refuges DROP CONSTRAINT IF EXISTS sovarka_goulag_refuges_nom_fkey;
ALTER TABLE public.sovarka_goulag_visites DROP CONSTRAINT IF EXISTS sovarka_goulag_visites_nom_fkey;
ALTER TABLE public.sovarka_goulag_entrees DROP CONSTRAINT IF EXISTS sovarka_goulag_entrees_nom_fkey;
ALTER TABLE public.sovarka_goulag_registre DROP CONSTRAINT IF EXISTS sovarka_goulag_registre_nom_fkey;
ALTER TABLE public.sovarka_goulag_incidents DROP CONSTRAINT IF EXISTS sovarka_goulag_incidents_nom_fkey;
ALTER TABLE public.sovarka_goulag_tentatives DROP CONSTRAINT IF EXISTS sovarka_goulag_tentatives_nom_fkey;
ALTER TABLE public.sovarka_goulag_traces_revelees DROP CONSTRAINT IF EXISTS sovarka_goulag_traces_revelees_nom_fkey;
ALTER TABLE public.sovarka_goulag_corruptions DROP CONSTRAINT IF EXISTS sovarka_goulag_corruptions_nom_fkey;
ALTER TABLE public.sovarka_goulag_interrogatoires DROP CONSTRAINT IF EXISTS sovarka_goulag_interrogatoires_detenu_fkey;
ALTER TABLE public.sovarka_goulag_interrogatoires DROP CONSTRAINT IF EXISTS sovarka_goulag_interrogatoires_interrogateur_fkey;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['traversees', 'depots', 'autorisations', 'refuges', 'visites', 'entrees', 'registre',
                           'incidents', 'tentatives', 'traces_revelees', 'corruptions'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_goulag_nom_verifier ON public.sovarka_goulag_%s', t);
    EXECUTE format('CREATE TRIGGER trg_goulag_nom_verifier BEFORE INSERT OR UPDATE OF nom ON public.sovarka_goulag_%s
                    FOR EACH ROW EXECUTE FUNCTION public.goulag_nom_verifier_trg(%L)', t, 'nom');
  END LOOP;
END $$;
DROP TRIGGER IF EXISTS trg_goulag_nom_verifier ON public.sovarka_goulag_interrogatoires;
CREATE TRIGGER trg_goulag_nom_verifier BEFORE INSERT OR UPDATE OF detenu, interrogateur ON public.sovarka_goulag_interrogatoires
  FOR EACH ROW EXECUTE FUNCTION public.goulag_nom_verifier_trg('detenu', 'interrogateur');

-- ===================================================================== 9f. Export des données
SELECT pg_temp.rp_remplacer('public.mes_donnees_exporter()'::regprocedure,
  ARRAY[$q$'SELECT * FROM public.mails WHERE to_player = $1 OR from_player = $1 OR from_real = $1 ORDER BY created_at DESC'$q$,
        $q$    'personnage', NULL);$q$],
  ARRAY[$q$'SELECT id, from_player, to_player, subject, body, "time", "read", created_at, archived, CASE WHEN from_real = $1 THEN from_real END AS from_real, from_org_id, from_org_icon FROM public.mails WHERE to_player = $1 OR from_player = $1 OR from_real = $1 ORDER BY created_at DESC'$q$,
        $q$    'personnage', NULL,
    -- export_masques_v1 (Fred, 28/11/2026 soir) : secrets d'autres joueurs et indicateurs internes jamais exportés.
    'masques', jsonb_build_array('courrier.from_real_d_un_autre_joueur', 'signalements_recus', 'auteurs_secrets',
                                 'incidents_client'));$q$],
  'export_masques_v1');

COMMIT;
