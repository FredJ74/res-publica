-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine communication -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- chat_est_membre_salon(text) -> boolean | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.chat_est_membre_salon(p_salon text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.salons_membres m
                  WHERE m.salon_id = p_salon AND m.membre = public.mon_personnage());
$function$

-- chat_participe(text,boolean) -> boolean | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.chat_participe(p_conversation text, p_salon boolean)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN public.mon_personnage() IS NULL THEN false
    WHEN coalesce(p_salon, false) THEN public.chat_est_membre_salon(p_conversation)
    ELSE public.mon_personnage() IN (split_part(p_conversation, '__', 1),
                                     split_part(p_conversation, '__', 2))
  END;
$function$

-- forum_verrou_compte_rendu_journee() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.forum_verrou_compte_rendu_journee()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF coalesce(current_setting('rp.publication_ligue', true), '') = '1' THEN RETURN NEW; END IF;
  IF NEW.author = 'Ligue Officielle' THEN
    INSERT INTO public.championnat_tentatives (acteur, decision, raison)
    VALUES (auth.uid(), 'refus', 'publication_cliente_officielle');
    RETURN NULL;
  END IF;
  RETURN NEW;
END; $function$

-- forum_verrou_local_territorial() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.forum_verrou_local_territorial()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_acteur text; v_ville text; v_ville_sujet text;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  -- Les publications institutionnelles passent par une RPC, qui pose ce laissez-passer.
  IF coalesce(current_setting('rp.publication_ligue', true), '') = '1'
     OR coalesce(current_setting('rp.programme_officiel', true), '') = '1' THEN
    RETURN NEW;
  END IF;
  IF NEW.forum_id IS NULL OR NEW.forum_id NOT LIKE 'local\_%' THEN RETURN NEW; END IF;

  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN RETURN NULL; END IF;
  SELECT current_city INTO v_ville FROM public.personnages_donnees WHERE name = v_acteur;
  v_ville_sujet := substring(NEW.forum_id from 7);      -- ce qui suit 'local_'

  -- On ne publie que dans le Local de la ville ou l'on se trouve reellement.
  IF coalesce(v_ville, '') IS DISTINCT FROM coalesce(v_ville_sujet, '') THEN
    RETURN NULL;
  END IF;
  RETURN NEW;
END; $function$

-- forum_verrou_message_ligue() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.forum_verrou_message_ligue()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF coalesce(current_setting('rp.publication_ligue', true), '') = '1' THEN RETURN NEW; END IF;
  IF NEW.author = 'Ligue Officielle'
     AND NOT EXISTS (SELECT 1 FROM public.forum_topics t WHERE t.id = NEW.topic_id) THEN
    INSERT INTO public.championnat_tentatives (acteur, decision, raison)
    VALUES (auth.uid(), 'refus', 'message_ligue_sans_sujet');
    RETURN NULL;
  END IF;
  RETURN NEW;
END; $function$

-- forum_verrou_programme_officiel() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.forum_verrou_programme_officiel()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF coalesce(current_setting('rp.programme_officiel', true), '') = '1' THEN RETURN NEW; END IF;
  IF NEW.id LIKE 'topic-programme-%' THEN RETURN NULL; END IF;
  RETURN NEW;
END; $function$

-- mail_destinataire_est_conjoint(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mail_destinataire_est_conjoint(p_moi text, p_destinataire text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.mariages m
     WHERE coalesce(m.statut, 'actif') <> 'dissous'
       AND m.dissous_at IS NULL
       AND ((m.conjoint1 = p_moi AND m.conjoint2 = p_destinataire)
         OR (m.conjoint2 = p_moi AND m.conjoint1 = p_destinataire))
  );
$function$

-- mail_destinataire_est_fret(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mail_destinataire_est_fret(p_moi text, p_destinataire text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.caisses_fret f
     WHERE f.leader = p_moi
       AND f.destinataire = p_destinataire
       AND f.date_arrivee_reelle IS NULL
  );
$function$

-- mail_destinataire_est_titulaire(text,text[]) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mail_destinataire_est_titulaire(p_destinataire text, p_postes text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.name = p_destinataire
       AND d.poste ->> 'id' = ANY (p_postes)
  );
$function$

-- mail_expediteur_autorise(text,text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mail_expediteur_autorise(p_nom text, p_destinataire text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$

-- mail_expediteur_autorise_strict(text,text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mail_expediteur_autorise_strict(p_nom text, p_destinataire text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_moi text;
BEGIN
  SELECT * INTO r FROM public.mails_expediteurs_systeme m
   WHERE (NOT m.est_prefixe AND m.expediteur = p_nom)
      OR (m.est_prefixe AND p_nom LIKE m.expediteur || '%')
   ORDER BY m.est_prefixe LIMIT 1;
  IF NOT FOUND THEN RETURN false; END IF;     -- identite inventee : jamais
  IF r.libre THEN RETURN true; END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN false; END IF;

  -- 1. A moi-meme.
  IF r.autorise_soi AND p_destinataire = v_moi THEN RETURN true; END IF;

  -- 2. Je detiens le poste : l'identite est la mienne, sans restriction.
  IF array_length(r.postes, 1) IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                  WHERE a.poste_id = ANY (r.postes)) THEN
    RETURN true;
  END IF;

  -- 3..5. SAISINE : le destinataire est impose par un lien verifiable en base.
  --       Dans les trois cas, l'identite institutionnelle ne permet JAMAIS
  --       d'atteindre un tiers librement choisi.
  IF r.autorise_vers_titulaire
     AND array_length(r.postes, 1) IS NOT NULL
     AND public.mail_destinataire_est_titulaire(p_destinataire, r.postes) THEN
    RETURN true;
  END IF;

  IF r.autorise_vers_conjoint
     AND public.mail_destinataire_est_conjoint(v_moi, p_destinataire) THEN
    RETURN true;
  END IF;

  IF r.autorise_vers_destinataire_fret
     AND public.mail_destinataire_est_fret(v_moi, p_destinataire) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$function$

-- mail_expediteur_organisation(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mail_expediteur_organisation(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.organisations o
     WHERE coalesce(o.data::jsonb ->> 'nom', '') = p_nom
  );
$function$

-- mail_expediteur_systeme(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mail_expediteur_systeme(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.mails_expediteurs_systeme m
     WHERE (NOT m.est_prefixe AND m.expediteur = p_nom)
        OR (m.est_prefixe AND p_nom LIKE m.expediteur || '%')
  );
$function$

-- mail_systeme_envoyer(text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mail_systeme_envoyer(p_expediteur text, p_destinataire text, p_sujet text, p_corps text, p_heure text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$

-- mails_journaliser_envoi_systeme() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mails_journaliser_envoi_systeme()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  v_moi := public.mon_personnage();
  IF NEW.from_player IS DISTINCT FROM v_moi THEN
    INSERT INTO public.mails_envois_systeme (auteur_reel, expediteur, destinataire, sujet)
    VALUES (v_moi, NEW.from_player, NEW.to_player, left(coalesce(NEW.subject,''), 200));
  END IF;
  RETURN NEW;
END;
$function$
