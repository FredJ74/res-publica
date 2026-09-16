-- CALENDRIER DU CHAMPIONNAT : LE CONTRAT PASSE COTE SERVEUR (16 septembre 2026).
-- DEJA EXECUTEE en production le 16 septembre 2026 (trois migrations MCP :
-- championnat_verrou_calendrier_serveur, championnat_publication_journee_serveur,
-- championnat_verrou_post_compte_rendu, puis championnat_verrou_corrections).
-- Ce fichier est la trace consolidee, a la meme place que migration_championnat_rls.sql.
--
-- L'EVENEMENT
-- -----------
-- Mercredi 16 septembre 2026, 00h38m59s (Europe/Paris) : un compte rendu « Journée 1 — Saison 1 »
-- signe « Ligue Officielle » apparait au forum sportif, avec six resultats complets. Le contrat de
-- jeu est pourtant : une journee par semaine, le dimanche a 20h.
--
-- L'AUTOPSIE
-- ----------
-- La table championnat n'a PAS bouge : derniereSemaineResolue = 2026-W37, derniere resolution le
-- dimanche 13 septembre a 20h25, journee 5 toujours a jouer, ancrage au dimanche 20 septembre 20h.
-- Les six affiches publiees sont bien celles de la journee 1 -- mais leurs SCORES different de
-- ceux de la vraie journee 1 (4-3 / 4-2 / 2-2 / 4-2 / 3-3 / 3-2 publies, contre 4-1 / 3-2 / 2-3 /
-- 2-2 / 2-3 / 2-3 en base). Le calendrier etant genere de facon deterministe (methode du cercle
-- sur la meme liste de clubs), une saison FANTOME regeneree en memoire a exactement la meme
-- journee 1 : c'est la signature d'un onglet qui a fabrique sa propre saison et l'a simulee chez
-- lui. Le titre le confirme -- il lui manque le suffixe « (journée du dimanche ...) », introduit
-- le 1er septembre (fc428e3) et toujours transmis par le code deploye.
--
-- C'est exactement le residu que migration_championnat_rls.sql avait identifie puis ACCEPTE le
-- 5 septembre : « un tres ancien onglet garde en memoire une saison fantome (jamais persistee) et
-- peut encore publier un topic forum ». Il avait ete juge sans consequence parce qu'il ne touche
-- pas l'etat du jeu. Il en a une : il raconte aux joueurs des matchs qui n'ont pas eu lieu.
--
-- POURQUOI AUCUNE GARDE N'A MORDU
-- -------------------------------
-- Le championnat n'a aucun moteur serveur : ce sont les navigateurs qui le font avancer (seul
-- point d'ecriture : ecrireChampionnatCAS, dans plateau-organisations-quetes.js). Tout le
-- calendrier -- dimanche, 20h, une fois par semaine -- n'etait donc verifie qu'en JavaScript.
-- Un onglet ouvert depuis des jours execute le JavaScript de son epoque : aucune correction ne
-- l'atteint. Les gardes etaient bonnes ; elles etaient au mauvais endroit.
--
-- CE QUE LE SERVEUR IMPOSE DESORMAIS
-- ----------------------------------
--   1. Une journee ne peut etre resolue qu'a partir du DIMANCHE 20:00 (Europe/Paris) de SA
--      semaine. Le serveur le calcule seul : la semaine due est celle qui SUIT
--      derniereSemaineResolue, et son echeance est le dimanche 20h de cette semaine ISO. Aucune
--      date fournie par le client n'entre dans ce calcul.
--   2. Une seule fois : apres resolution, le marqueur avance d'une semaine, et il ne recule pas.
--   3. Un match joue est definitif : ni rejoue, ni re-score, ni ramene a l'etat non joue.
--   4. Un compte rendu ne raconte que ce que la base contient : il est compose et publie par le
--      serveur, sous un identifiant derive de (saison, journee), et un client ne peut plus
--      inserer lui-meme un sujet « Journée ... » signe de la Ligue.
--   5. L'estampille de version (updated_at), sur laquelle repose l'arbitrage entre clients
--      concurrents, est posee par le serveur et non plus annoncee par le navigateur.
--
-- COMMENT ON REFUSE : le declencheur renvoie NULL. La ligne n'est pas modifiee, mais la
-- transaction n'est pas annulee, donc la trace du refus survit. Cote client, le PATCH
-- conditionnel voit zero ligne modifiee et conclut a une course perdue -- cas qu'il sait deja
-- traiter : il ne publiera ni compte rendu ni prime.
--
-- service_role (cron, reparations) n'est jamais concerne.
--
-- LIMITE DE CE PREMIER LOT, LEVEE LE SOIR MEME : les publications des PHASES FINALES (tours de
-- playoff, sacre du champion) partaient encore du client. Voir le COMPLEMENT en fin de fichier --
-- elles sont desormais ecrites par le serveur, comme les journees, et les noms de clubs viennent
-- d'un miroir genere plutot que du navigateur.

-- ===================================================================== journal des tentatives
CREATE TABLE IF NOT EXISTS public.championnat_tentatives (
  id                  bigserial PRIMARY KEY,
  au                  timestamptz NOT NULL DEFAULT now(),
  acteur              uuid,
  ligne               integer,
  journee             integer,
  matchs_revendiques  integer,
  semaine_precedente  text,
  echeance            timestamptz,
  decision            text NOT NULL,          -- 'jouer' | 'refus'
  raison              text                    -- hors_creneau | match_deja_joue | recul_semaine_resolue
                                              -- | publication_cliente_compte_rendu | message_ligue_sans_sujet
);
ALTER TABLE public.championnat_tentatives ENABLE ROW LEVEL SECURITY;
-- Aucune policy : invisible et inecrivable pour anon/authenticated. Doctrine du projet.
REVOKE ALL ON public.championnat_tentatives FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.championnat_tentatives_id_seq FROM PUBLIC, anon, authenticated;

-- ===================================================================== outils de calendrier
-- Les matchs d'un blob, a plat, pour comparer l'avant et l'apres d'une ecriture.
CREATE OR REPLACE FUNCTION public.championnat_matchs(p_data jsonb)
RETURNS TABLE (journee integer, home text, away text, joue boolean, buts_home integer, buts_away integer)
LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT (j->>'numero')::int, m->>'home', m->>'away',
         coalesce((m->>'played')::boolean, false),
         nullif(m->>'scoreHome','')::int, nullif(m->>'scoreAway','')::int
    FROM jsonb_array_elements(coalesce(p_data->'calendrier', '[]'::jsonb)) j,
         jsonb_array_elements(coalesce(j->'matchs', '[]'::jsonb)) m
$$;

-- Echeance de la journee due : dimanche 20:00 Europe/Paris de la semaine ISO suivant celle de la
-- derniere resolution. Le dimanche etant le DERNIER jour de sa semaine ISO, la fenetre d'une
-- journee va de son dimanche 20h au dimanche 20h suivant : toute avance est interdite, le
-- rattrapage du lundi reste possible, et deux journees dans la meme semaine sont impossibles.
-- Sans marqueur (saison neuve), c'est le dimanche 20h de la semaine en cours.
CREATE OR REPLACE FUNCTION public.championnat_echeance(p_semaine_precedente text)
RETURNS timestamptz
LANGUAGE plpgsql STABLE
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_lundi date;
BEGIN
  IF p_semaine_precedente IS NULL OR p_semaine_precedente !~ '^\d{4}-W\d{2}$' THEN
    v_lundi := to_date(to_char(now() AT TIME ZONE 'Europe/Paris', 'IYYY-IW'), 'IYYY-IW');
  ELSE
    v_lundi := to_date(replace(p_semaine_precedente, 'W', ''), 'IYYY-IW') + 7;
  END IF;
  RETURN (v_lundi + interval '6 days 20 hours') AT TIME ZONE 'Europe/Paris';
END; $$;

-- Dernier dimanche 20h a la date de resolution : le dimanche THEORIQUE de la journee, qu'elle
-- ait ete jouee a l'heure ou rattrapee le lendemain.
CREATE OR REPLACE FUNCTION public.championnat_date_sportive(p_resolue_le timestamptz)
RETURNS text
LANGUAGE sql STABLE
SET search_path TO 'public', 'pg_temp'
AS $$
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

-- ===================================================================== le verrou
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
  NEW.updated_at := clock_timestamp();   -- la version est arretee par le serveur

  v_semaine := OLD.data->>'derniereSemaineResolue';

  -- 1. UN MATCH JOUE EST DEFINITIF.
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

  -- 2. LES NOUVELLES REVENDICATIONS : des matchs qui passent a « joue » dans cette ecriture.
  SELECT count(*), min(n.journee) INTO v_nouveaux, v_journee
    FROM public.championnat_matchs(NEW.data) n
    LEFT JOIN public.championnat_matchs(OLD.data) o USING (journee, home, away)
   WHERE n.joue AND NOT coalesce(o.joue, false);

  IF coalesce(v_nouveaux, 0) = 0 THEN
    -- Ecriture ordinaire (progression live, compositions, boycott, effets verses, choix des
    -- supporters) : rien a arbitrer -- mais le marqueur de semaine ne recule jamais.
    IF v_semaine IS NOT NULL
       AND coalesce(NEW.data->>'derniereSemaineResolue', '') < v_semaine THEN
      INSERT INTO public.championnat_tentatives
        (acteur, ligne, semaine_precedente, decision, raison)
      VALUES (auth.uid(), OLD.id, v_semaine, 'refus', 'recul_semaine_resolue');
      RETURN NULL;
    END IF;
    RETURN NEW;
  END IF;

  -- 3. L'ECHEANCE. C'est ici que le mercredi 00h38 est arrete.
  v_echeance := public.championnat_echeance(v_semaine);
  IF now() < v_echeance THEN
    INSERT INTO public.championnat_tentatives
      (acteur, ligne, journee, matchs_revendiques, semaine_precedente, echeance, decision, raison)
    VALUES (auth.uid(), OLD.id, v_journee, v_nouveaux, v_semaine, v_echeance, 'refus', 'hors_creneau');
    RETURN NULL;
  END IF;

  INSERT INTO public.championnat_tentatives
    (acteur, ligne, journee, matchs_revendiques, semaine_precedente, echeance, decision, raison)
  VALUES (auth.uid(), OLD.id, v_journee, v_nouveaux, v_semaine, v_echeance, 'jouer', NULL);
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_championnat_verrou_calendrier ON public.championnat;
CREATE TRIGGER trg_championnat_verrou_calendrier
  BEFORE UPDATE ON public.championnat
  FOR EACH ROW EXECUTE FUNCTION public.championnat_verrou_calendrier();

-- ===================================================================== la publication
-- Le texte n'est plus fourni par l'appelant : il est recompose a partir des recits reellement
-- persistes. Identifiant derive de (saison, journee) -> republier n'a aucun effet.
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

-- ===================================================================== la porte derobee
-- Cible etroite et volontaire : un sujet « Journée ... » signe de la Ligue, insere par un client.
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

DROP TRIGGER IF EXISTS trg_forum_verrou_compte_rendu ON public.forum_topics;
CREATE TRIGGER trg_forum_verrou_compte_rendu
  BEFORE INSERT ON public.forum_topics
  FOR EACH ROW EXECUTE FUNCTION public.forum_verrou_compte_rendu_journee();

-- Le sujet refuse, son message ne doit pas rester orphelin : sans cela le compte rendu
-- s'afficherait quand meme la ou le forum liste les messages, et le verrou serait decoratif.
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

DROP TRIGGER IF EXISTS trg_forum_verrou_message_ligue ON public.forum_posts;
CREATE TRIGGER trg_forum_verrou_message_ligue
  BEFORE INSERT ON public.forum_posts
  FOR EACH ROW EXECUTE FUNCTION public.forum_verrou_message_ligue();

-- Banc de verification : .scratch/banc_championnat_calendrier.py (18 controles, attaque le
-- serveur comme un client avec la cle anon publique).

-- =====================================================================================
-- COMPLEMENT DU 16 septembre 2026 (soir) : LES PHASES FINALES
-- =====================================================================================
-- DEJA EXECUTE en production (migrations MCP : clubs_football_miroir_serveur,
-- championnat_phases_finales_autorite_serveur, championnat_publication_phases_finales).
--
-- Le verrou du matin ne regardait que data->'calendrier'. Les playoffs vivent dans
-- data->'playoffs' : ils passaient donc par la branche « ecriture ordinaire », sans controle
-- d'echeance. Un client pouvait encore faire tomber des quarts un mercredi et publier lui-meme
-- le sacre d'un champion. Le MEME declencheur est etendu -- pas un second moteur.
--
-- CE QUI RESTE AU CLIENT, VOLONTAIREMENT : la simulation des rencontres, exactement comme pour
-- la saison reguliere. Le serveur ne tire pas les scores ; il decide QUAND un tour peut tomber,
-- refuse qu'on le rejoue, et signe seul les communiques.
--
-- Ajouts :
--   * public.clubs_football -- miroir serveur des 12 clubs, GENERE par
--     .scratch/generer_clubs_football.py depuis le vrai data.js (empreinte 2c2f8d0fe578a8bb).
--     Necessaire pour que le serveur ecrive « X est sacre champion » sans croire le navigateur
--     sur parole. Lecture publique, ecriture a personne.
--   * public.championnat_rang_etape -- ordre des tours : quarts_aller(1) -> quarts_retour(2)
--     -> demies_aller(3) -> demies_retour(4) -> finale(5) -> termine(6).
--   * championnat_verrou_calendrier etendu : une etape ne peut avancer que d'un cran et pas
--     avant l'echeance ; une manche jouee, un champion proclame et le palmares sont definitifs.
--     L'entree en playoffs (etape absente -> quarts_aller) est la mise en place du tableau :
--     elle ne consomme pas de semaine.
--   * championnat_publier_tour(manche) et championnat_publier_sacre() -- memes principes que
--     championnat_publier_journee : texte recompose depuis l'etat persiste, identifiant derive
--     de (saison, manche), republier ne fait rien. Libelles repris A L'IDENTIQUE du jeu.
--   * forum_verrou_compte_rendu_journee elargi : plus AUCUN sujet signe « Ligue Officielle »
--     ne peut etre insere depuis un navigateur, quel que soit son titre. Les trois communiques
--     officiels passent par les RPC.
--
-- Le SQL exact de ces objets est celui applique en base ; voir les migrations nommees ci-dessus.
-- Banc : .scratch/banc_championnat_calendrier.py (33 controles).
--
-- CONSTAT REMONTE, NON CORRIGE ICI : sbAppliquerSalaire (supabase.js) verse les primes de match
-- par un UPDATE direct sur le personnage d'AUTRUI. Depuis le chantier B, la vue personnages
-- refuse cette ecriture (personnage_non_possede) -- ce qui ferme le vecteur d'abus, mais
-- signifie aussi que les primes ne sont probablement plus versees. Relevé du game design, pas
-- tranche seul.
