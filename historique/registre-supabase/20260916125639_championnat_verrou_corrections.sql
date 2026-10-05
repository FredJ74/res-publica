-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916125639
-- Nom original      : championnat_verrou_corrections
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 12:56:39 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e549d75b00e8f72ba61373cf29a2bc34
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
-- DEUX CORRECTIFS AU VERROU POSE PLUS TOT AUJOURD'HUI.
--
-- 1. LA PUBLICATION LEGITIME SE FAISAIT REFUSER PAR SON PROPRE VERROU. championnat_publier_journee
--    s'execute avec les droits du proprietaire, mais le jeton reste celui du joueur : le
--    declencheur du forum la prenait donc pour un client et rejetait le sujet. La RPC pose
--    desormais un indicateur LOCAL a sa transaction, que le declencheur reconnait. Un client ne
--    peut pas le poser lui-meme : il n'a aucun moyen d'appeler set_config a travers l'API.
--
-- 2. LA VERSION DU BLOB ETAIT ANNONCEE PAR LE CLIENT. Le compare-and-swap qui arbitre les
--    ecritures concurrentes compare updated_at ; or aucune regle ne le tenait a jour -- c'est le
--    navigateur qui envoyait sa propre estampille. Un client qui ne la changeait pas laissait donc
--    passer plusieurs revendications de la meme journee. Le serveur l'estampille maintenant
--    lui-meme, a chaque ecriture acceptee : l'arbitrage cesse de dependre de la bonne volonte des
--    clients. Le jeu continue d'envoyer la sienne, simplement elle n'est plus lue.

CREATE OR REPLACE FUNCTION public.forum_verrou_compte_rendu_journee()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF coalesce(current_setting('rp.publication_ligue', true), '') = '1' THEN RETURN NEW; END IF;
  IF NEW.author = 'Ligue Officielle' AND NEW.title LIKE 'Journée %' THEN
    INSERT INTO public.championnat_tentatives (acteur, decision, raison)
    VALUES (auth.uid(), 'refus', 'publication_cliente_compte_rendu');
    RETURN NULL;
  END IF;
  RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION public.forum_verrou_message_ligue()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
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
END; $$;

CREATE OR REPLACE FUNCTION public.championnat_publier_journee(p_journee integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_data jsonb; v_j jsonb; v_saison integer; v_pays text;
  v_total integer; v_joues integer; v_contenu text; v_titre text;
  v_topic text; v_temps text; v_existe boolean;
BEGIN
  IF auth.uid() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appelant_non_authentifie');
  END IF;

  SELECT data INTO v_data FROM public.championnat WHERE id = 2;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data->>'numero')::int, 0);

  SELECT j INTO v_j
    FROM jsonb_array_elements(coalesce(v_data->'calendrier', '[]'::jsonb)) j
   WHERE (j->>'numero')::int = p_journee;
  IF v_j IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'journee_inconnue');
  END IF;

  SELECT count(*), count(*) FILTER (WHERE coalesce((m->>'played')::boolean, false))
    INTO v_total, v_joues
    FROM jsonb_array_elements(coalesce(v_j->'matchs', '[]'::jsonb)) m;
  IF v_total = 0 OR v_joues < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'journee_non_jouee',
                              'joues', v_joues, 'total', v_total);
  END IF;

  v_topic := 'topic-championnat-s' || v_saison || '-j' || p_journee;
  SELECT true INTO v_existe FROM public.forum_topics WHERE id = v_topic;
  IF coalesce(v_existe, false) THEN
    RETURN jsonb_build_object('ok', true, 'deja_publie', true, 'topic_id', v_topic);
  END IF;

  SELECT string_agg(m->>'recit', '<br>') INTO v_contenu
    FROM jsonb_array_elements(v_j->'matchs') m
   WHERE coalesce(m->>'recit', '') <> '';
  IF v_contenu IS NULL OR btrim(v_contenu) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_recit');
  END IF;

  v_titre := 'Journée ' || p_journee || ' — Saison ' || v_saison
             || ' (journée du ' || public.championnat_date_sportive(
                  nullif(v_j->>'resolueLe', '')::timestamptz) || ')';
  v_temps := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY" · "HH24"h"MI');
  v_pays := 'republic';

  -- Laissez-passer LOCAL a cette transaction : c'est ici, et nulle part ailleurs, qu'un compte
  -- rendu de journee peut entrer au forum.
  PERFORM set_config('rp.publication_ligue', '1', true);

  INSERT INTO public.forum_topics
    (id, forum_id, title, author, country, time, views, replies, last_post_author, last_post_time,
     author_is_org, author_secret)
  VALUES (v_topic, 'sport', v_titre, 'Ligue Officielle', v_pays, v_temps, 1, 0,
          'Ligue Officielle', v_temps, false, false)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.forum_posts (id, topic_id, author, content, time)
  VALUES (v_topic || '-post', v_topic, 'Ligue Officielle', v_contenu, v_temps)
  ON CONFLICT (id) DO NOTHING;

  PERFORM set_config('rp.publication_ligue', '0', true);
  RETURN jsonb_build_object('ok', true, 'topic_id', v_topic, 'titre', v_titre);
END; $$;

REVOKE ALL ON FUNCTION public.championnat_publier_journee(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.championnat_publier_journee(integer) TO authenticated;

-- L'estampille de version est desormais posee par le serveur, jamais par l'appelant.
CREATE OR REPLACE FUNCTION public.championnat_verrou_calendrier()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_figes integer; v_nouveaux integer; v_journee integer;
  v_semaine text; v_echeance timestamptz;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  NEW.updated_at := clock_timestamp();

  v_semaine := OLD.data->>'derniereSemaineResolue';

  SELECT count(*) INTO v_figes
    FROM public.championnat_matchs(OLD.data) o
    JOIN public.championnat_matchs(NEW.data) n USING (journee, home, away)
   WHERE o.joue AND (NOT n.joue
                     OR n.buts_home IS DISTINCT FROM o.buts_home
                     OR n.buts_away IS DISTINCT FROM o.buts_away);
  IF v_figes > 0 THEN
    INSERT INTO public.championnat_tentatives
      (acteur, ligne, matchs_revendiques, semaine_precedente, decision, raison)
    VALUES (auth.uid(), OLD.id, v_figes, v_semaine, 'refus', 'match_deja_joue');
    RETURN NULL;
  END IF;

  SELECT count(*), min(n.journee) INTO v_nouveaux, v_journee
    FROM public.championnat_matchs(NEW.data) n
    LEFT JOIN public.championnat_matchs(OLD.data) o USING (journee, home, away)
   WHERE n.joue AND NOT coalesce(o.joue, false);

  IF coalesce(v_nouveaux, 0) = 0 THEN
    IF v_semaine IS NOT NULL
       AND coalesce(NEW.data->>'derniereSemaineResolue', '') < v_semaine THEN
      INSERT INTO public.championnat_tentatives
        (acteur, ligne, semaine_precedente, decision, raison)
      VALUES (auth.uid(), OLD.id, v_semaine, 'refus', 'recul_semaine_resolue');
      RETURN NULL;
    END IF;
    RETURN NEW;
  END IF;

  v_echeance := public.championnat_echeance(v_semaine);
  IF now() < v_echeance THEN
    INSERT INTO public.championnat_tentatives
      (acteur, ligne, journee, matchs_revendiques, semaine_precedente, echeance, decision, raison)
    VALUES (auth.uid(), OLD.id, v_journee, v_nouveaux, v_semaine, v_echeance,
            'refus', 'hors_creneau');
    RETURN NULL;
  END IF;

  INSERT INTO public.championnat_tentatives
    (acteur, ligne, journee, matchs_revendiques, semaine_precedente, echeance, decision, raison)
  VALUES (auth.uid(), OLD.id, v_journee, v_nouveaux, v_semaine, v_echeance, 'jouer', NULL);
  RETURN NEW;
END; $$;