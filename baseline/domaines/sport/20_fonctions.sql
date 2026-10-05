-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine sport -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- championnat_date_sportive(timestamp with time zone) -> text | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.championnat_date_sportive(p_resolue_le timestamp with time zone)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$

-- championnat_echeance(text) -> timestamp with time zone | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.championnat_echeance(p_semaine_precedente text)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_lundi date;
BEGIN
  IF p_semaine_precedente IS NULL OR p_semaine_precedente !~ '^\d{4}-W\d{2}$' THEN
    v_lundi := to_date(to_char(now() AT TIME ZONE 'Europe/Paris', 'IYYY-IW'), 'IYYY-IW');
  ELSE
    v_lundi := to_date(replace(p_semaine_precedente, 'W', ''), 'IYYY-IW') + 7;
  END IF;
  RETURN (v_lundi + interval '6 days 20 hours') AT TIME ZONE 'Europe/Paris';
END; $function$

-- championnat_matchs(jsonb) -> TABLE(journee integer, home text, away text, joue boolean, buts_home integer, buts_away integer) | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.championnat_matchs(p_data jsonb)
 RETURNS TABLE(journee integer, home text, away text, joue boolean, buts_home integer, buts_away integer)
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT (j->>'numero')::int, m->>'home', m->>'away',
         coalesce((m->>'played')::boolean, false),
         nullif(m->>'scoreHome','')::int, nullif(m->>'scoreAway','')::int
    FROM jsonb_array_elements(coalesce(p_data->'calendrier', '[]'::jsonb)) j,
         jsonb_array_elements(coalesce(j->'matchs', '[]'::jsonb)) m
$function$

-- championnat_publier_journee(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.championnat_publier_journee(p_journee integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
END; $function$

-- championnat_publier_sacre() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.championnat_publier_sacre()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
END; $function$

-- championnat_publier_tour(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.championnat_publier_tour(p_manche text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
END; $function$

-- championnat_rang_etape(text) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.championnat_rang_etape(p_etape text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE p_etape
           WHEN 'quarts_aller'  THEN 1 WHEN 'quarts_retour' THEN 2
           WHEN 'demies_aller'  THEN 3 WHEN 'demies_retour' THEN 4
           WHEN 'finale'        THEN 5 WHEN 'termine'       THEN 6
           ELSE NULL END;
$function$

-- championnat_verrou_calendrier() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.championnat_verrou_calendrier()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_figes integer; v_nouveaux integer; v_journee integer;
  v_semaine text; v_echeance timestamptz;
  v_av text; v_ap text; v_rav integer; v_rap integer;
  v_progression boolean := false;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  NEW.updated_at := clock_timestamp();

  v_semaine := OLD.data->>'derniereSemaineResolue';

  -- ============ 1. UN MATCH JOUE EST DEFINITIF (saison reguliere) ============
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

  -- ============ 2. UN TOUR JOUE EST DEFINITIF (phases finales) ============
  -- Une manche, une fois ecrite, ne se reecrit pas ; le palmares ne se raccourcit pas ; un
  -- champion proclame ne change pas de nom.
  IF (OLD.data #> '{playoffs,quarts,aller}')  IS NOT NULL AND (OLD.data #> '{playoffs,quarts,aller}')  <> 'null'::jsonb
       AND (NEW.data #> '{playoffs,quarts,aller}')  IS DISTINCT FROM (OLD.data #> '{playoffs,quarts,aller}')
   OR (OLD.data #> '{playoffs,quarts,retour}') IS NOT NULL AND (OLD.data #> '{playoffs,quarts,retour}') <> 'null'::jsonb
       AND (NEW.data #> '{playoffs,quarts,retour}') IS DISTINCT FROM (OLD.data #> '{playoffs,quarts,retour}')
   OR (OLD.data #> '{playoffs,demies,aller}')  IS NOT NULL AND (OLD.data #> '{playoffs,demies,aller}')  <> 'null'::jsonb
       AND (NEW.data #> '{playoffs,demies,aller}')  IS DISTINCT FROM (OLD.data #> '{playoffs,demies,aller}')
   OR (OLD.data #> '{playoffs,demies,retour}') IS NOT NULL AND (OLD.data #> '{playoffs,demies,retour}') <> 'null'::jsonb
       AND (NEW.data #> '{playoffs,demies,retour}') IS DISTINCT FROM (OLD.data #> '{playoffs,demies,retour}')
   OR (OLD.data #> '{playoffs,finale,resultat}') IS NOT NULL AND (OLD.data #> '{playoffs,finale,resultat}') <> 'null'::jsonb
       AND (NEW.data #> '{playoffs,finale,resultat}') IS DISTINCT FROM (OLD.data #> '{playoffs,finale,resultat}')
   OR (OLD.data #>> '{resultatsFinales,champion}') IS NOT NULL
       AND (NEW.data #>> '{resultatsFinales,champion}') IS DISTINCT FROM (OLD.data #>> '{resultatsFinales,champion}')
   OR jsonb_array_length(coalesce(NEW.data->'palmares', '[]'::jsonb))
        < jsonb_array_length(coalesce(OLD.data->'palmares', '[]'::jsonb))
  THEN
    INSERT INTO public.championnat_tentatives
      (acteur, ligne, semaine_precedente, decision, raison)
    VALUES (auth.uid(), OLD.id, v_semaine, 'refus', 'resultat_final_deja_acquis');
    RETURN NULL;
  END IF;

  -- ============ 3. PROGRESSION D'UN TOUR : UN CRAN, ET PAS AVANT L'HEURE ============
  v_av := OLD.data #>> '{playoffs,etape}';
  v_ap := NEW.data #>> '{playoffs,etape}';
  IF v_av IS DISTINCT FROM v_ap AND v_ap IS NOT NULL THEN
    v_rav := public.championnat_rang_etape(v_av);
    v_rap := public.championnat_rang_etape(v_ap);
    IF v_av IS NOT NULL AND (v_rav IS NULL OR v_rap IS NULL OR v_rap <> v_rav + 1) THEN
      INSERT INTO public.championnat_tentatives
        (acteur, ligne, semaine_precedente, decision, raison)
      VALUES (auth.uid(), OLD.id, v_semaine, 'refus', 'etape_playoff_illegitime');
      RETURN NULL;
    END IF;
    -- L'entree en playoffs (v_av NULL) n'est pas un tour joue : c'est la mise en place du
    -- tableau, elle ne consomme pas de semaine et n'a donc pas d'echeance propre.
    IF v_av IS NOT NULL THEN v_progression := true; END IF;
  END IF;

  -- ============ 4. LES NOUVELLES REVENDICATIONS (saison reguliere) ============
  SELECT count(*), min(n.journee) INTO v_nouveaux, v_journee
    FROM public.championnat_matchs(NEW.data) n
    LEFT JOIN public.championnat_matchs(OLD.data) o USING (journee, home, away)
   WHERE n.joue AND NOT coalesce(o.joue, false);

  IF coalesce(v_nouveaux, 0) = 0 AND NOT v_progression THEN
    -- Ecriture ordinaire : progression live, compositions, boycott, effets verses, choix des
    -- supporters, mise en place du tableau. Rien a arbitrer -- mais la semaine ne recule jamais.
    IF v_semaine IS NOT NULL
       AND coalesce(NEW.data->>'derniereSemaineResolue', '') < v_semaine THEN
      INSERT INTO public.championnat_tentatives
        (acteur, ligne, semaine_precedente, decision, raison)
      VALUES (auth.uid(), OLD.id, v_semaine, 'refus', 'recul_semaine_resolue');
      RETURN NULL;
    END IF;
    RETURN NEW;
  END IF;

  -- ============ 5. L'ECHEANCE, LA MEME POUR LES DEUX PHASES ============
  v_echeance := public.championnat_echeance(v_semaine);
  IF now() < v_echeance THEN
    INSERT INTO public.championnat_tentatives
      (acteur, ligne, journee, matchs_revendiques, semaine_precedente, echeance, decision, raison)
    VALUES (auth.uid(), OLD.id, v_journee, v_nouveaux, v_semaine, v_echeance, 'refus',
            CASE WHEN v_progression THEN 'hors_creneau_playoff' ELSE 'hors_creneau' END);
    RETURN NULL;
  END IF;

  INSERT INTO public.championnat_tentatives
    (acteur, ligne, journee, matchs_revendiques, semaine_precedente, echeance, decision, raison)
  VALUES (auth.uid(), OLD.id, v_journee, v_nouveaux, v_semaine, v_echeance, 'jouer',
          CASE WHEN v_progression THEN 'playoff:' || v_ap ELSE NULL END);
  RETURN NEW;
END; $function$

-- club_capitaine(text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.club_capitaine(p_club text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_valeur integer; v_jour integer; v_nom text;
BEGIN
  SELECT valeur_base INTO v_valeur FROM public.clubs_sportifs_regles WHERE club_id = p_club;
  IF v_valeur IS NULL THEN RETURN NULL; END IF;
  v_jour := public.jour_de_jeu_pays((SELECT country FROM public.clubs_sportifs_regles WHERE club_id = p_club));

  SELECT nom INTO v_nom FROM (
    SELECT d.name AS nom,
           coalesce((d.performance_sportive ->> 'defense')::numeric, 0)
         + coalesce((d.performance_sportive ->> 'technique')::numeric, 0)
         + coalesce((d.performance_sportive ->> 'endurance')::numeric, 0) AS total,
           coalesce((d.blessure_sportive ->> 'jusquauJour')::int, -1) > v_jour AS blesse
      FROM public.personnages_donnees d
     WHERE (d.licence_sportive ->> 'clubId') = p_club
  ) t
   WHERE NOT t.blesse AND t.total > v_valeur * 0.5
   ORDER BY t.total DESC
   LIMIT 1;

  RETURN v_nom;   -- NULL => capitaine PNJ par defaut, comme cote client
END;
$function$

-- club_electeurs(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.club_electeurs(p_club text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c record; v_chef text; v_maire text; v_cap text;
BEGIN
  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE club_id = p_club;
  IF NOT FOUND THEN RETURN NULL; END IF;

  -- Chef de l'organisation de supporters de la ville du club.
  SELECT (o.data::jsonb ->> 'chef') INTO v_chef
    FROM public.organisations o
   WHERE (o.data::jsonb ->> 'type') = 'supporters'
     AND (o.data::jsonb ->> 'country') = c.country
     AND (o.data::jsonb ->> 'city') = c.city
   LIMIT 1;

  -- Maire de la ville -- un PJ seulement, comme cote client (maireInfo.estPJ).
  SELECT d.name INTO v_maire
    FROM public.personnages_donnees d
   WHERE (d.poste ->> 'id') = 'maire'
     AND (d.poste ->> 'city') = c.city
     AND coalesce(d.country, 'republic') = c.country
   LIMIT 1;

  v_cap := public.club_capitaine(p_club);

  RETURN jsonb_build_object('chefSupporters', v_chef, 'maire', v_maire, 'capitaine', v_cap);
END;
$function$

-- club_president_cloturer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.club_president_cloturer(p_club text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data jsonb; v_cand jsonb; v_elect jsonb; v_votes jsonb;
  v_jour integer; c record; v_nom text; v_pour int := 0; v_total int := 0;
  v_valide boolean; v_tous boolean := true;
  v_noms text[];
BEGIN
  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE club_id = p_club;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'club_inconnu');
  END IF;
  v_jour := public.jour_de_jeu_pays(c.country);

  SELECT coalesce(data, '{}'::jsonb) INTO v_data
    FROM public.presidents_clubs WHERE id = p_club FOR UPDATE;
  IF v_data IS NULL OR jsonb_typeof(v_data -> 'candidature') <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_candidature');
  END IF;
  v_cand  := v_data -> 'candidature';
  v_elect := v_cand -> 'electeurs';
  v_votes := coalesce(v_cand -> 'votes', '{}'::jsonb);

  v_noms := ARRAY(SELECT x FROM unnest(ARRAY[
      v_elect ->> 'chefSupporters', v_elect ->> 'maire', v_elect ->> 'capitaine']) x
     WHERE x IS NOT NULL AND btrim(x) <> '');

  FOREACH v_nom IN ARRAY v_noms LOOP
    v_total := v_total + 1;
    IF NOT (v_votes ? v_nom) THEN v_tous := false; END IF;
  END LOOP;

  -- Depouillement des que tous ont vote OU a l'echeance. Pas avant.
  IF NOT v_tous AND v_jour < (v_cand ->> 'dateLimite')::int THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_en_cours',
                              'votes', jsonb_array_length(
                                 coalesce(jsonb_path_query_array(v_votes, '$.keyvalue().key'), '[]'::jsonb)),
                              'attendus', v_total, 'dateLimite', (v_cand ->> 'dateLimite')::int);
  END IF;

  -- SILENCE = ACCORD : les votes manquants comptent pour « oui ».
  FOREACH v_nom IN ARRAY v_noms LOOP
    IF NOT (v_votes ? v_nom) THEN
      v_pour := v_pour + 1;
    ELSIF coalesce((v_votes ->> v_nom)::boolean, false) THEN
      v_pour := v_pour + 1;
    END IF;
  END LOOP;

  v_valide := (v_pour >= 2);

  IF v_valide THEN
    v_data := v_data || jsonb_build_object(
      'president',    v_cand ->> 'candidat',
      'dateElection', v_jour);
  END IF;
  v_data := v_data || jsonb_build_object('candidature', 'null'::jsonb);

  UPDATE public.presidents_clubs SET data = v_data, updated_at = now() WHERE id = p_club;

  RETURN jsonb_build_object('ok', true, 'elu', v_valide,
                            'candidat', v_cand ->> 'candidat',
                            'pour', v_pour, 'electeurs', v_total);
END;
$function$

-- club_president_postuler(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.club_president_postuler(p_club text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; c record; v_data jsonb; v_jour integer; v_elect jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE club_id = p_club;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'club_inconnu');
  END IF;
  v_jour := public.jour_de_jeu_pays(c.country);

  SELECT coalesce(data, '{}'::jsonb) INTO v_data
    FROM public.presidents_clubs WHERE id = p_club FOR UPDATE;
  v_data := coalesce(v_data, '{}'::jsonb);

  IF (v_data -> 'candidature') IS NOT NULL AND jsonb_typeof(v_data -> 'candidature') = 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_en_cours');
  END IF;

  -- Protection du president en poste : 8 jours, regle existante.
  IF (v_data ->> 'president') IS NOT NULL
     AND (v_data ->> 'president') <> v_moi
     AND (v_data ->> 'dateElection') IS NOT NULL
     AND (v_jour - (v_data ->> 'dateElection')::int) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_protege',
                              'jours_restants', 8 - (v_jour - (v_data ->> 'dateElection')::int));
  END IF;

  -- LES ELECTEURS SONT RESOLUS ICI, PAR LE SERVEUR. Aucune identite transmise.
  v_elect := public.club_electeurs(p_club);

  v_data := v_data || jsonb_build_object('candidature', jsonb_build_object(
    'candidat',   v_moi,
    'dateDebut',  v_jour,
    'dateLimite', v_jour + 2,
    'votes',      '{}'::jsonb,
    'electeurs',  v_elect));

  INSERT INTO public.presidents_clubs (id, data, updated_at)
  VALUES (p_club, v_data, now())
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = now();

  RETURN jsonb_build_object('ok', true, 'candidat', v_moi,
                            'dateLimite', v_jour + 2, 'electeurs', v_elect);
END;
$function$

-- club_president_voter(text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.club_president_voter(p_club text, p_vote boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_data jsonb; v_cand jsonb; v_elect jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(data, '{}'::jsonb) INTO v_data
    FROM public.presidents_clubs WHERE id = p_club FOR UPDATE;
  IF v_data IS NULL OR jsonb_typeof(v_data -> 'candidature') <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_candidature');
  END IF;
  v_cand  := v_data -> 'candidature';
  v_elect := v_cand -> 'electeurs';

  -- Seul un des trois electeurs vote. L'instantane est celui du SERVEUR.
  IF v_moi IS DISTINCT FROM (v_elect ->> 'chefSupporters')
     AND v_moi IS DISTINCT FROM (v_elect ->> 'maire')
     AND v_moi IS DISTINCT FROM (v_elect ->> 'capitaine') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_electeur');
  END IF;

  -- Un seul vote par electeur.
  IF (v_cand -> 'votes') ? v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_vote');
  END IF;

  v_cand := jsonb_set(v_cand, ARRAY['votes', v_moi], to_jsonb(coalesce(p_vote, false)), true);
  UPDATE public.presidents_clubs
     SET data = v_data || jsonb_build_object('candidature', v_cand), updated_at = now()
   WHERE id = p_club;

  RETURN jsonb_build_object('ok', true, 'vote', coalesce(p_vote, false));
END;
$function$

-- football_entrainement_consommer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.football_entrainement_consommer(p_stat text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE c_max constant integer := 2;
        v_moi text; v_jour integer; v_nb integer; v_paie jsonb; v_id text;
BEGIN
  IF p_stat NOT IN ('defense','technique','endurance') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stat_invalide');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- DOUBLE CLIC : le second appel attend ici, puis constate la limite.
  PERFORM pg_advisory_xact_lock(hashtext('football_entrainement|' || v_moi));

  SELECT d.day INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT count(*) INTO v_nb
    FROM public.entrainements_football e
   WHERE e.personnage = v_moi AND e.jour = v_jour;

  IF v_nb >= c_max THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'limite_quotidienne_atteinte',
                              'nb', v_nb, 'max', c_max, 'jour', v_jour);
  END IF;

  -- LE PAIEMENT EN DERNIER, ET PAR L'AUTORITE HABITUELLE (miroir des couts + verrou).
  v_paie := public.payer_ordre(v_moi, 'tenue_entrainement', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'));
  END IF;

  v_id := 'ef-' || (extract(epoch from clock_timestamp())*1000)::bigint
               || '-' || substr(md5(random()::text), 1, 6);
  INSERT INTO public.entrainements_football (id, personnage, jour, stat)
  VALUES (v_id, v_moi, v_jour, p_stat);

  RETURN jsonb_build_object('ok', true, 'nb', v_nb + 1, 'max', c_max,
                            'jour', v_jour, 'pa', v_paie->'pa');
END;
$function$

-- football_entrainements_du_jour() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.football_entrainements_du_jour()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE c_max constant integer := 2; v_moi text; v_jour integer; v_nb integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT d.day INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  SELECT count(*) INTO v_nb
    FROM public.entrainements_football e
   WHERE e.personnage = v_moi AND e.jour = v_jour;
  RETURN jsonb_build_object('ok', true, 'nb', v_nb, 'max', c_max, 'jour', v_jour);
END;
$function$

-- football_noms_composition(jsonb) -> TABLE(nom text) | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.football_noms_composition(p_liste jsonb)
 RETURNS TABLE(nom text)
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN jsonb_typeof(e) = 'string' THEN e #>> '{}' ELSE e ->> 'nom' END
    FROM jsonb_array_elements(coalesce(p_liste, '[]'::jsonb)) e
   WHERE coalesce(CASE WHEN jsonb_typeof(e) = 'string' THEN e #>> '{}' ELSE e ->> 'nom' END, '') <> ''
$function$

-- football_pari_engager(text,text,integer,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.football_pari_engager(p_home text, p_away text, p_journee integer, p_choix text, p_mise integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_data jsonb; v_saison integer; v_j jsonb; v_m jsonb;
  v_id text; v_arg numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  IF p_choix IS NULL OR p_choix NOT IN ('domicile', 'nul', 'adversaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'choix_invalide');
  END IF;
  -- Minimum repris de l'ecran existant. Plafond de securite : une mise ne peut
  -- pas etre un nombre arbitraire, meme si le joueur avait les fonds.
  IF p_mise IS NULL OR p_mise < 10 OR p_mise > 1000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mise_invalide');
  END IF;

  SELECT data INTO v_data FROM public.championnat WHERE id = 2;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data ->> 'numero')::int, 0);

  SELECT j INTO v_j FROM jsonb_array_elements(coalesce(v_data -> 'calendrier', '[]'::jsonb)) j
   WHERE (j ->> 'numero')::int = p_journee;
  IF v_j IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'journee_inconnue');
  END IF;

  SELECT m INTO v_m FROM jsonb_array_elements(coalesce(v_j -> 'matchs', '[]'::jsonb)) m
   WHERE m ->> 'home' = p_home AND m ->> 'away' = p_away;
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'match_inconnu');
  END IF;
  -- LE POINT CENTRAL : on ne parie pas sur un resultat connu.
  IF coalesce((v_m ->> 'played')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'match_deja_joue');
  END IF;

  v_id := 'pari:' || v_moi || ':' || v_saison || ':' || p_journee || ':' || p_home || ':' || p_away;

  -- La mise EST prelevee, et elle l'est AVANT toute inscription. Verrou sur la
  -- fiche : deux paris simultanes ne peuvent pas depenser le meme argent.
  SELECT coalesce(arg, 0) INTO v_arg
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_introuvable');
  END IF;
  IF v_arg < p_mise THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'arg', v_arg, 'mise', p_mise);
  END IF;

  BEGIN
    INSERT INTO public.paris_sportifs (id, resolu, data)
    VALUES (v_id, false, jsonb_build_object(
      'joueur', v_moi, 'homeId', p_home, 'awayId', p_away, 'choix', p_choix,
      'mise', p_mise, 'journeeNumero', p_journee, 'saisonNumero', v_saison));
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pari_deja_engage');
  END;

  UPDATE public.personnages_donnees
     SET arg = coalesce(arg, 0) - p_mise, updated_at = now()
   WHERE name = v_moi
   RETURNING arg INTO v_arg;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'mise', p_mise,
                            'saison', v_saison, 'arg', v_arg);
END;
$function$

-- football_paris_resoudre(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.football_paris_resoudre(p_journee integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data jsonb; v_saison integer; v_j jsonb; v_p record; v_m jsonb;
  v_reel text; v_cote numeric; v_gain integer; v_gagne boolean;
  v_regles integer := 0; v_payes integer := 0; v_total integer := 0;
  v_detail jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appelant_non_authentifie');
  END IF;

  SELECT data INTO v_data FROM public.championnat WHERE id = 2;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data->>'numero')::int, 0);

  SELECT j INTO v_j FROM jsonb_array_elements(coalesce(v_data->'calendrier', '[]'::jsonb)) j
   WHERE (j->>'numero')::int = p_journee;
  IF v_j IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'journee_inconnue');
  END IF;

  FOR v_p IN
    SELECT id, data FROM public.paris_sportifs
     WHERE resolu = false
       AND (data->>'journeeNumero')::int = p_journee
       AND (data->>'saisonNumero')::int = v_saison
     FOR UPDATE SKIP LOCKED
  LOOP
    -- Le match doit exister ET etre joue : un pari sur une rencontre non disputee reste ouvert.
    SELECT m INTO v_m FROM jsonb_array_elements(coalesce(v_j->'matchs', '[]'::jsonb)) m
     WHERE m->>'home' = v_p.data->>'homeId' AND m->>'away' = v_p.data->>'awayId';
    CONTINUE WHEN v_m IS NULL OR NOT coalesce((v_m->>'played')::boolean, false);

    v_reel := CASE
      WHEN coalesce((v_m->>'scoreHome')::int, 0) > coalesce((v_m->>'scoreAway')::int, 0) THEN 'domicile'
      WHEN coalesce((v_m->>'scoreHome')::int, 0) < coalesce((v_m->>'scoreAway')::int, 0) THEN 'adversaire'
      ELSE 'nul' END;
    v_gagne := (v_reel = (v_p.data->>'choix'));
    v_cote  := CASE v_p.data->>'choix'
                 WHEN 'domicile' THEN 2.5 WHEN 'nul' THEN 3.5 WHEN 'adversaire' THEN 3
                 ELSE NULL END;
    IF v_cote IS NULL THEN CONTINUE; END IF;   -- choix inconnu : on ne touche a rien
    v_gain := CASE WHEN v_gagne
                   THEN round(coalesce((v_p.data->>'mise')::numeric, 0) * v_cote)::int
                   ELSE 0 END;

    -- LES DEUX ENSEMBLE : resolution et paiement.
    UPDATE public.paris_sportifs SET resolu = true WHERE id = v_p.id;
    IF v_gain > 0 THEN
      UPDATE public.personnages_donnees
         SET arg = coalesce(arg, 0) + v_gain
       WHERE name = v_p.data->>'joueur';
      IF FOUND THEN
        v_payes := v_payes + 1; v_total := v_total + v_gain;
      END IF;
    END IF;

    v_regles := v_regles + 1;
    v_detail := v_detail || jsonb_build_object(
      'id', v_p.id, 'joueur', v_p.data->>'joueur', 'gagne', v_gagne, 'gain', v_gain,
      'homeId', v_p.data->>'homeId', 'awayId', v_p.data->>'awayId');
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'journee', p_journee, 'regles', v_regles,
                            'payes', v_payes, 'total', v_total, 'detail', v_detail);
END; $function$

-- football_primes_journee(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.football_primes_journee(p_journee integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data jsonb; v_saison integer; v_j jsonb; v_m jsonb; v_r jsonb;
  v_verses integer := 0; v_somme integer := 0; v_ignores integer := 0; v_detail jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appelant_non_authentifie');
  END IF;

  SELECT data INTO v_data FROM public.championnat WHERE id = 2 FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data->>'numero')::int, 0);

  SELECT j INTO v_j FROM jsonb_array_elements(coalesce(v_data->'calendrier', '[]'::jsonb)) j
   WHERE (j->>'numero')::int = p_journee;
  IF v_j IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'journee_inconnue');
  END IF;

  FOR v_m IN SELECT m FROM jsonb_array_elements(coalesce(v_j->'matchs', '[]'::jsonb)) m LOOP
    v_r := public.football_primes_match(v_saison, 'j' || p_journee, v_m);
    v_verses := v_verses + (v_r->>'verses')::int;
    v_somme  := v_somme  + (v_r->>'total')::int;
    v_ignores:= v_ignores+ (v_r->>'deja_versees')::int;
    v_detail := v_detail || (v_r->'detail');
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'journee', p_journee, 'verses', v_verses,
                            'total', v_somme, 'deja_versees', v_ignores, 'detail', v_detail);
END; $function$

-- football_primes_match(integer,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.football_primes_match(p_saison integer, p_cle text, p_m jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cote text; v_club text; v_role text; v_nom text;
  v_sal jsonb; v_montant integer; v_victoire boolean; v_ref text; v_affiche text;
  v_total integer; v_verses integer := 0; v_somme integer := 0; v_ignores integer := 0;
  v_detail jsonb := '[]'::jsonb;
BEGIN
  IF NOT coalesce((p_m->>'played')::boolean, true) THEN
    RETURN jsonb_build_object('verses', 0, 'total', 0, 'deja_versees', 0, 'detail', '[]'::jsonb);
  END IF;
  v_affiche := (p_m->>'home') || '-' || (p_m->>'away');

  FOREACH v_cote IN ARRAY ARRAY['home', 'away'] LOOP
    v_club := p_m->>v_cote;
    CONTINUE WHEN coalesce(v_club, '') = '';
    v_total := 0;
    v_victoire := CASE WHEN v_cote = 'home'
                       THEN coalesce((p_m->>'scoreHome')::int, 0) > coalesce((p_m->>'scoreAway')::int, 0)
                       ELSE coalesce((p_m->>'scoreAway')::int, 0) > coalesce((p_m->>'scoreHome')::int, 0) END;

    SELECT coalesce(data->'salaires', '{}'::jsonb) INTO v_sal
      FROM public.budgets_clubs WHERE id = v_club;
    v_sal := jsonb_build_object(
      'titulaire',     coalesce((v_sal->>'titulaire')::int, 100),
      'remplacant',    coalesce((v_sal->>'remplacant')::int, 50),
      'primeVictoire', coalesce((v_sal->>'primeVictoire')::int, 150));

    FOREACH v_role IN ARRAY ARRAY['titulaires', 'remplacants'] LOOP
      FOR v_nom IN
        SELECT n FROM public.football_noms_composition(
          coalesce(p_m #> ARRAY['compositions', v_cote, v_role],
                   p_m #> ARRAY['live', 'compositionFigee', v_cote, v_role])) n
      LOOP
        CONTINUE WHEN NOT EXISTS (
          SELECT 1 FROM public.personnages_donnees d
           WHERE d.name = v_nom
             AND d.licence_sportive ->> 'clubId' = v_club
             AND coalesce(d.licence_sportive ->> 'statut', '') = 'active');

        v_montant := CASE WHEN v_role = 'titulaires'
                          THEN (v_sal->>'titulaire')::int
                               + CASE WHEN v_victoire THEN (v_sal->>'primeVictoire')::int ELSE 0 END
                          ELSE (v_sal->>'remplacant')::int END;
        CONTINUE WHEN coalesce(v_montant, 0) <= 0;

        v_ref := 's' || p_saison || '-' || p_cle || '-' || v_affiche || '-' || v_nom || '-' || v_role;
        BEGIN
          INSERT INTO public.football_primes_versees
            (reference, saison, journee, affiche, beneficiaire, club, role, montant)
          VALUES (v_ref, p_saison, nullif(regexp_replace(p_cle, '\D', '', 'g'), '')::int,
                  v_affiche, v_nom, v_club, v_role, v_montant);
        EXCEPTION WHEN unique_violation THEN
          v_ignores := v_ignores + 1;
          CONTINUE;
        END;

        UPDATE public.personnages_donnees
           SET arg = coalesce(arg, 0) + v_montant
         WHERE name = v_nom;

        v_verses := v_verses + 1; v_somme := v_somme + v_montant; v_total := v_total + v_montant;
        v_detail := v_detail || jsonb_build_object('nom', v_nom, 'club', v_club,
                                                   'role', v_role, 'montant', v_montant);
      END LOOP;
    END LOOP;

    IF v_total > 0 THEN
      UPDATE public.budgets_clubs
         SET data = jsonb_set(data, '{caisse}',
                      to_jsonb(greatest(0, coalesce((data->>'caisse')::int, 0) - v_total)))
       WHERE id = v_club;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('verses', v_verses, 'total', v_somme,
                            'deja_versees', v_ignores, 'detail', v_detail);
END; $function$

-- football_primes_tour(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.football_primes_tour(p_manche text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data jsonb; v_saison integer; v_liste jsonb; v_m jsonb; v_r jsonb; v_chemin text[];
  v_verses integer := 0; v_somme integer := 0; v_ignores integer := 0; v_detail jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appelant_non_authentifie');
  END IF;

  v_chemin := CASE p_manche
    WHEN 'quarts_aller'  THEN ARRAY['playoffs','quarts','aller']
    WHEN 'quarts_retour' THEN ARRAY['playoffs','quarts','retour']
    WHEN 'demies_aller'  THEN ARRAY['playoffs','demies','aller']
    WHEN 'demies_retour' THEN ARRAY['playoffs','demies','retour']
    WHEN 'finale'        THEN ARRAY['playoffs','finale','resultat'] END;
  IF v_chemin IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'manche_inconnue');
  END IF;

  SELECT data INTO v_data FROM public.championnat WHERE id = 2 FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data->>'numero')::int, 0);

  v_liste := v_data #> v_chemin;
  IF v_liste IS NULL OR jsonb_typeof(v_liste) = 'null' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'manche_non_jouee');
  END IF;
  IF jsonb_typeof(v_liste) = 'object' THEN v_liste := jsonb_build_array(v_liste); END IF;

  FOR v_m IN SELECT m FROM jsonb_array_elements(v_liste) m LOOP
    v_r := public.football_primes_match(v_saison, p_manche, v_m);
    v_verses := v_verses + (v_r->>'verses')::int;
    v_somme  := v_somme  + (v_r->>'total')::int;
    v_ignores:= v_ignores+ (v_r->>'deja_versees')::int;
    v_detail := v_detail || (v_r->'detail');
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'manche', p_manche, 'verses', v_verses,
                            'total', v_somme, 'deja_versees', v_ignores, 'detail', v_detail);
END; $function$
