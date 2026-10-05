-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920091147
-- Nom original      : mails_rpc_systeme_et_transition
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 09:11:47 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 1d5213c7368786b81811f5564f0ef7af
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =====================================================================
-- MAILS : LA PORTE SERVEUR, ET UNE TOLERANCE TRANSITOIRE EXPLICITE
-- =====================================================================
-- LA FENETRE, CONSTATEE FACTUELLEMENT. Le bundle servi en production insere les
-- mails EN DIRECT (sbInsert('mails')). La policy posee au lot precedent exige un
-- poste pour 13 identites institutionnelles : les parcours correspondants du
-- client deploye echoueraient. C'est une vraie incompatibilite, et la laisser
-- ouverte en s'appuyant sur « aucun PJ n'a de poste aujourd'hui » n'est pas une
-- garantie.
--
-- DEUX PIECES, POSEES ENSEMBLE :
--
-- 1. LA PORTE DEFINITIVE — mail_systeme_envoyer(). Le navigateur ne choisit plus
--    son identite : il demande un envoi, le serveur verifie l'autorite puis
--    ecrit. C'est cette RPC que le client migre utilisera.
--
-- 2. UNE TOLERANCE TRANSITOIRE, NOMMEE, JOURNALISEE ET REVERSIBLE D'UNE LIGNE.
--    Tant qu'elle est active, un envoi direct sous une identite DECLAREE reste
--    accepte -- mais il est enregistre dans mails_envois_systeme avec son
--    veritable auteur. Ce n'est pas un fail-open generique : une identite
--    INVENTEE reste refusee, et une identite reservee a « soi » ne peut toujours
--    pas viser un tiers. Au push :
--        UPDATE public.rp_transitions SET actif = false
--         WHERE cle = 'mails_expediteurs_tolerance';
--    et le durcissement complet prend effet, sans migration ni redeploiement.

CREATE TABLE IF NOT EXISTS public.rp_transitions (
  cle        text PRIMARY KEY,
  actif      boolean NOT NULL DEFAULT true,
  note       text,
  pose_le    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.rp_transitions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rp_transitions FROM PUBLIC, anon, authenticated;

INSERT INTO public.rp_transitions (cle, actif, note) VALUES
  ('mails_expediteurs_tolerance', true,
   'A DESACTIVER AU PUSH. Tolere l''envoi direct sous une identite institutionnelle DECLAREE, pour le client deploye qui ne connait pas encore mail_systeme_envoyer. Chaque envoi est journalise dans mails_envois_systeme.')
ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.rp_transition_active(p_cle text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
  SELECT coalesce((SELECT t.actif FROM public.rp_transitions t WHERE t.cle = p_cle), false);
$$;
REVOKE ALL ON FUNCTION public.rp_transition_active(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rp_transition_active(text) TO authenticated, service_role;

-- Verdict STRICT, sans tolerance : c'est lui que la RPC serveur utilise.
CREATE OR REPLACE FUNCTION public.mail_expediteur_autorise_strict(p_nom text, p_destinataire text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE r record; v_moi text;
BEGIN
  SELECT * INTO r FROM public.mails_expediteurs_systeme m
   WHERE (NOT m.est_prefixe AND m.expediteur = p_nom)
      OR (m.est_prefixe AND p_nom LIKE m.expediteur || '%')
   ORDER BY m.est_prefixe LIMIT 1;
  IF NOT FOUND THEN RETURN false; END IF;
  IF r.libre THEN RETURN true; END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN false; END IF;
  IF r.autorise_soi AND p_destinataire = v_moi THEN RETURN true; END IF;
  IF array_length(r.postes, 1) IS NOT NULL THEN
    RETURN EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                    WHERE a.poste_id = ANY (r.postes));
  END IF;
  RETURN false;
END;
$fn$;
REVOKE ALL ON FUNCTION public.mail_expediteur_autorise_strict(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise_strict(text, text) TO authenticated, service_role;

-- Verdict utilise par la POLICY : strict, plus la tolerance transitoire.
CREATE OR REPLACE FUNCTION public.mail_expediteur_autorise(p_nom text, p_destinataire text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE r record;
BEGIN
  IF public.mail_expediteur_autorise_strict(p_nom, p_destinataire) THEN RETURN true; END IF;

  IF public.rp_transition_active('mails_expediteurs_tolerance') THEN
    SELECT * INTO r FROM public.mails_expediteurs_systeme m
     WHERE (NOT m.est_prefixe AND m.expediteur = p_nom)
        OR (m.est_prefixe AND p_nom LIKE m.expediteur || '%')
     ORDER BY m.est_prefixe LIMIT 1;
    -- Une identite DECLAREE reste acceptee le temps de la transition.
    -- Une identite inventee, jamais.
    IF FOUND THEN RETURN true; END IF;
  END IF;

  RETURN false;
END;
$fn$;

-- LA PORTE DEFINITIVE : le navigateur demande, le serveur decide et ecrit.
CREATE OR REPLACE FUNCTION public.mail_systeme_envoyer(
  p_expediteur text, p_destinataire text, p_sujet text, p_corps text, p_heure text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_moi text; v_id text;
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
  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES (v_id, p_expediteur, p_destinataire, p_sujet, p_corps,
          coalesce(p_heure, to_char(now() AT TIME ZONE 'Europe/Paris', 'HH24') || 'h'), false);
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$fn$;
REVOKE ALL ON FUNCTION public.mail_systeme_envoyer(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mail_systeme_envoyer(text, text, text, text, text) TO authenticated, service_role;