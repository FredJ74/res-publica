-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916134329
-- Nom original      : championnat_publication_phases_finales
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 13:43:29 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6d09059c6bd2ec0feb491ab8427d2b1d
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
-- LES COMMUNIQUES DES PHASES FINALES SONT SIGNES PAR LE SERVEUR (16 septembre 2026).
--
-- Meme principe que championnat_publier_journee : le texte n'est pas fourni par l'appelant, il
-- est recompose a partir de ce que la base contient reellement -- recits persistes et noms de
-- clubs du miroir clubs_football. Un onglet ancien, un client modifie ou un appel direct n'ont
-- donc rien a publier qui ne soit deja acquis.
--
-- Les libelles sont repris A L'IDENTIQUE de ceux du jeu (publierTourPlayoffSurForum et
-- publierPhasesFinalesSurForum) : aucun texte, aucun nom, aucune regle ne change.
--
-- IDEMPOTENCE : identifiant derive de (saison, manche). Republier ne fait rien.

CREATE OR REPLACE FUNCTION public.championnat_publier_tour(p_manche text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_data jsonb; v_saison integer; v_res jsonb; v_titre text; v_contenu text;
  v_topic text; v_temps text; v_libelle text; v_chemin text[];
BEGIN
  IF auth.uid() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appelant_non_authentifie');
  END IF;

  v_libelle := CASE p_manche
    WHEN 'quarts_aller'  THEN 'Quarts de finale (aller)'
    WHEN 'quarts_retour' THEN 'Quarts de finale (retour)'
    WHEN 'demies_aller'  THEN 'Demi-finales (aller)'
    WHEN 'demies_retour' THEN 'Demi-finales (retour)' END;
  IF v_libelle IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'manche_inconnue');
  END IF;
  v_chemin := CASE p_manche
    WHEN 'quarts_aller'  THEN ARRAY['playoffs','quarts','aller']
    WHEN 'quarts_retour' THEN ARRAY['playoffs','quarts','retour']
    WHEN 'demies_aller'  THEN ARRAY['playoffs','demies','aller']
    WHEN 'demies_retour' THEN ARRAY['playoffs','demies','retour'] END;

  SELECT data INTO v_data FROM public.championnat WHERE id = 2;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data->>'numero')::int, 0);

  -- La manche doit etre REELLEMENT jouee et persistee.
  v_res := v_data #> v_chemin;
  IF v_res IS NULL OR jsonb_typeof(v_res) <> 'array' OR jsonb_array_length(v_res) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'manche_non_jouee');
  END IF;

  v_topic := 'topic-championnat-s' || v_saison || '-' || p_manche;
  IF EXISTS (SELECT 1 FROM public.forum_topics WHERE id = v_topic) THEN
    RETURN jsonb_build_object('ok', true, 'deja_publie', true, 'topic_id', v_topic);
  END IF;

  SELECT string_agg(r->>'recit', '<br>') INTO v_contenu
    FROM jsonb_array_elements(v_res) r WHERE coalesce(r->>'recit', '') <> '';
  IF v_contenu IS NULL OR btrim(v_contenu) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_recit');
  END IF;

  v_titre := v_libelle || ' — Saison ' || v_saison;
  v_temps := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY" · "HH24"h"MI');

  PERFORM set_config('rp.publication_ligue', '1', true);
  INSERT INTO public.forum_topics
    (id, forum_id, title, author, country, time, views, replies, last_post_author, last_post_time,
     author_is_org, author_secret)
  VALUES (v_topic, 'sport', v_titre, 'Ligue Officielle', 'republic', v_temps, 1, 0,
          'Ligue Officielle', v_temps, false, false)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.forum_posts (id, topic_id, author, content, time)
  VALUES (v_topic || '-post', v_topic, 'Ligue Officielle', v_contenu, v_temps)
  ON CONFLICT (id) DO NOTHING;
  PERFORM set_config('rp.publication_ligue', '0', true);

  RETURN jsonb_build_object('ok', true, 'topic_id', v_topic, 'titre', v_titre);
END; $$;

CREATE OR REPLACE FUNCTION public.championnat_publier_sacre()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_data jsonb; v_saison integer; v_rf jsonb; v_titre text; v_contenu text;
  v_topic text; v_temps text; v_champion text; v_stade text; v_recit text;
BEGIN
  IF auth.uid() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appelant_non_authentifie');
  END IF;

  SELECT data INTO v_data FROM public.championnat WHERE id = 2;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data->>'numero')::int, 0);
  v_rf := v_data->'resultatsFinales';

  -- Le sacre n'existe que si la finale est jouee ET le champion inscrit en base.
  IF v_rf IS NULL OR jsonb_typeof(v_rf) <> 'object'
     OR coalesce(v_rf->>'champion', '') = ''
     OR coalesce(v_rf #>> '{finale,recit}', '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sacre_non_acquis');
  END IF;

  v_topic := 'topic-championnat-s' || v_saison || '-sacre';
  IF EXISTS (SELECT 1 FROM public.forum_topics WHERE id = v_topic) THEN
    RETURN jsonb_build_object('ok', true, 'deja_publie', true, 'topic_id', v_topic);
  END IF;

  -- Les noms viennent du miroir serveur, jamais de l'appelant.
  SELECT nom INTO v_champion FROM public.clubs_football WHERE id = v_rf->>'champion';
  SELECT nom INTO v_stade    FROM public.clubs_football WHERE id = v_rf->>'stadeClubId';
  IF v_champion IS NULL OR v_stade IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'club_inconnu');
  END IF;
  v_recit := v_rf #>> '{finale,recit}';

  v_titre := '🏆 Sacre du champion — Saison ' || v_saison;
  v_contenu := '<b>Finale</b> (au ' || v_stade || ')<br>' || v_recit
               || '<br><br><b>' || v_champion || ' est sacré champion de la saison '
               || v_saison || ' !</b>';
  v_temps := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY" · "HH24"h"MI');

  PERFORM set_config('rp.publication_ligue', '1', true);
  INSERT INTO public.forum_topics
    (id, forum_id, title, author, country, time, views, replies, last_post_author, last_post_time,
     author_is_org, author_secret)
  VALUES (v_topic, 'sport', v_titre, 'Ligue Officielle', 'republic', v_temps, 1, 0,
          'Ligue Officielle', v_temps, false, false)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.forum_posts (id, topic_id, author, content, time)
  VALUES (v_topic || '-post', v_topic, 'Ligue Officielle', v_contenu, v_temps)
  ON CONFLICT (id) DO NOTHING;
  PERFORM set_config('rp.publication_ligue', '0', true);

  RETURN jsonb_build_object('ok', true, 'topic_id', v_topic, 'champion', v_champion);
END; $$;

REVOKE ALL ON FUNCTION public.championnat_publier_tour(text)  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.championnat_publier_sacre()     FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.championnat_publier_tour(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.championnat_publier_sacre()    TO authenticated;

-- LA SIGNATURE DE LA LIGUE N'APPARTIENT PLUS AUX CLIENTS. Les trois communiques officiels
-- (journee, tour, sacre) passent desormais par une RPC ; plus aucun sujet signe « Ligue
-- Officielle » ne peut etre insere depuis un navigateur, quel que soit son titre.
CREATE OR REPLACE FUNCTION public.forum_verrou_compte_rendu_journee()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF coalesce(current_setting('rp.publication_ligue', true), '') = '1' THEN RETURN NEW; END IF;
  IF NEW.author = 'Ligue Officielle' THEN
    INSERT INTO public.championnat_tentatives (acteur, decision, raison)
    VALUES (auth.uid(), 'refus', 'publication_cliente_officielle');
    RETURN NULL;
  END IF;
  RETURN NEW;
END; $$;