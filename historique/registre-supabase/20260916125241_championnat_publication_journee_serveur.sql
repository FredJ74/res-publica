-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916125241
-- Nom original      : championnat_publication_journee_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 12:52:41 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e250ebdeef7a9d1875c56976e8d5f7cb
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
-- LE COMPTE RENDU D'UNE JOURNEE EST PUBLIE PAR LE SERVEUR (16 septembre 2026).
--
-- C'est ce qui a reellement fui le mercredi 16 septembre a 00:38 : un onglet execute un bundle
-- ancien, n'a rien pu ecrire dans championnat (sa cible id=1 est verrouillee depuis le
-- 5 septembre), mais a publie au forum le compte rendu d'une journee 1 qu'il avait simulee dans
-- sa seule memoire. Le residu etait connu et avait ete accepte a l'epoque ; il ne l'est plus.
--
-- Le principe : un compte rendu ne raconte que ce que la BASE contient. Le texte n'est plus
-- fourni par l'appelant -- il est recompose ici a partir des recits reellement persistes. Une
-- journee qui n'est pas entierement jouee n'a pas de compte rendu, et un fantome n'a donc rien
-- a publier.
--
-- IDEMPOTENCE : l'identifiant du sujet est derive de (saison, journee). Deux clients qui
-- publient la meme journee produisent le meme identifiant, et le second ne fait rien. Ni double
-- sujet, ni double message.

CREATE OR REPLACE FUNCTION public.championnat_date_sportive(p_resolue_le timestamptz)
RETURNS text
LANGUAGE sql STABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  -- Dernier dimanche 20:00 Europe/Paris a la date de resolution : le dimanche THEORIQUE de la
  -- journee, qu'elle ait ete jouee a l'heure ou rattrapee le lundi.
  WITH d AS (
    SELECT (date_trunc('week', coalesce(p_resolue_le, now()) AT TIME ZONE 'Europe/Paris')
            + interval '6 days 20 hours') AS dimanche,
           (coalesce(p_resolue_le, now()) AT TIME ZONE 'Europe/Paris') AS local
  ), c AS (
    SELECT CASE WHEN local >= dimanche THEN dimanche ELSE dimanche - interval '7 days' END AS jour FROM d
  )
  SELECT 'dimanche ' || extract(day FROM jour)::int || ' ' ||
         (ARRAY['janvier','février','mars','avril','mai','juin','juillet','août',
                'septembre','octobre','novembre','décembre'])[extract(month FROM jour)::int]
    FROM c;
$$;

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

  -- La journee doit etre REELLEMENT jouee, entierement, en base.
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
  v_temps := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY') || ' · '
             || to_char(now() AT TIME ZONE 'Europe/Paris', 'HH24') || 'h'
             || to_char(now() AT TIME ZONE 'Europe/Paris', 'MI');
  v_pays := 'republic';

  INSERT INTO public.forum_topics
    (id, forum_id, title, author, country, time, views, replies, last_post_author, last_post_time,
     author_is_org, author_secret)
  VALUES (v_topic, 'sport', v_titre, 'Ligue Officielle', v_pays, v_temps, 1, 0,
          'Ligue Officielle', v_temps, false, false)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.forum_posts (id, topic_id, author, content, time)
  VALUES (v_topic || '-post', v_topic, 'Ligue Officielle', v_contenu, v_temps)
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'topic_id', v_topic, 'titre', v_titre);
END; $$;

REVOKE ALL ON FUNCTION public.championnat_publier_journee(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.championnat_publier_journee(integer) TO authenticated;

-- LA PORTE DEROBEE SE FERME : un client ne publie plus lui-meme un compte rendu de journee.
-- Cible etroite et volontaire -- le titre d'une journee de championnat sous la signature de la
-- Ligue. Les autres publications de la Ligue (tours de phase finale, sacre du champion) passent
-- encore par le client et ne sont pas touchees ici : c'est un point ouvert, pas un oubli.
CREATE OR REPLACE FUNCTION public.forum_verrou_compte_rendu_journee()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF NEW.author = 'Ligue Officielle' AND NEW.title LIKE 'Journée %' THEN
    INSERT INTO public.championnat_tentatives (acteur, decision, raison)
    VALUES (auth.uid(), 'refus', 'publication_cliente_compte_rendu');
    RETURN NULL;
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_forum_verrou_compte_rendu ON public.forum_topics;
CREATE TRIGGER trg_forum_verrou_compte_rendu
  BEFORE INSERT ON public.forum_topics
  FOR EACH ROW EXECUTE FUNCTION public.forum_verrou_compte_rendu_journee();