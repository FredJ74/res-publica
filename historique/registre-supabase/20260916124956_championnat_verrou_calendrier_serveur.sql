-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916124956
-- Nom original      : championnat_verrou_calendrier_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 12:49:56 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 903ba47edf2604c009a09f0a7f2692a3
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
-- LE CALENDRIER DU CHAMPIONNAT DEVIENT UNE REGLE SERVEUR (16 septembre 2026).
--
-- POURQUOI. Le championnat n'a AUCUN moteur serveur : il est resolu par les navigateurs, et le
-- contrat de jeu -- une journee par semaine, le dimanche a 20h -- n'etait verifie qu'en
-- JavaScript. Trois consequences : un onglet qui execute un bundle ancien ne connait pas les
-- gardes ecrites depuis ; l'heure de reference est celle du poste du joueur ; et la table
-- championnat est ouverte en ecriture a anon/authenticated (policy du 5 septembre 2026, qui ne
-- protege que la ligne historique id=1).
--
-- LA REGLE, telle que le game design la verrouille :
--   une journee ne peut etre resolue qu'a partir du DIMANCHE 20:00 (Europe/Paris) de SA semaine,
--   et une seule fois.
-- Le serveur la derive tout seul : la semaine due est celle qui SUIT derniereSemaineResolue, et
-- son echeance est le dimanche 20h de cette semaine ISO. Il ne fait confiance a aucune date
-- fournie par le client -- ni ancrageDimanche, ni kickoffAt, ni l'horloge du navigateur.
--
-- Le dimanche est le DERNIER jour de sa semaine ISO : la fenetre d'une journee va donc de son
-- dimanche 20h au dimanche 20h suivant. Cela interdit toute avance, laisse vivre le rattrapage
-- du lundi ou du mardi qui existe deja, et rend structurellement impossible deux journees dans
-- la meme semaine.
--
-- COMMENT ON REFUSE. Le declencheur renvoie NULL : la ligne n'est pas modifiee, mais la
-- transaction n'est pas annulee -- la trace du refus survit. Cote client, le PATCH conditionnel
-- (compare-and-swap) voit alors zero ligne modifiee et conclut a une course perdue, cas qu'il
-- sait deja traiter : il n'ira ni publier au forum ni payer de primes.
--
-- service_role n'est pas concerne (reparations, cron).

CREATE TABLE IF NOT EXISTS public.championnat_tentatives (
  id                  bigserial PRIMARY KEY,
  au                  timestamptz NOT NULL DEFAULT now(),
  acteur              uuid,
  ligne               integer,
  journee             integer,
  matchs_revendiques  integer,
  semaine_precedente  text,
  echeance            timestamptz,
  decision            text NOT NULL,
  raison              text
);
COMMENT ON TABLE public.championnat_tentatives IS
  'Journal des tentatives de resolution du championnat (chantier du 16 septembre 2026). Ecrit par le declencheur championnat_verrou_calendrier, invisible aux clients. Ne declenche aucun match.';

ALTER TABLE public.championnat_tentatives ENABLE ROW LEVEL SECURITY;
-- Aucune policy : ni lecture ni ecriture pour anon/authenticated. Doctrine du projet.
REVOKE ALL ON public.championnat_tentatives FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.championnat_tentatives_id_seq FROM PUBLIC, anon, authenticated;

-- Les matchs d'un blob, a plat, pour comparer l'avant et l'apres.
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

-- Echeance de la journee due : dimanche 20:00 Europe/Paris de la semaine ISO qui suit celle de
-- la derniere resolution. Sans marqueur (saison neuve), c'est le dimanche 20h de la semaine en
-- cours -- une saison ne peut donc pas plus demarrer un mercredi qu'elle ne peut se poursuivre.
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

  v_semaine := OLD.data->>'derniereSemaineResolue';

  -- 1. UN MATCH JOUE EST DEFINITIF. Ni rejoue, ni re-score, ni ramene a l'etat non joue.
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
    -- Ecriture ordinaire : progression minute par minute, compositions, boycott, effets verses,
    -- choix des supporters. Rien a arbitrer -- mais le marqueur de semaine ne recule jamais.
    IF v_semaine IS NOT NULL
       AND coalesce(NEW.data->>'derniereSemaineResolue', '') < v_semaine THEN
      INSERT INTO public.championnat_tentatives
        (acteur, ligne, semaine_precedente, decision, raison)
      VALUES (auth.uid(), OLD.id, v_semaine, 'refus', 'recul_semaine_resolue');
      RETURN NULL;
    END IF;
    RETURN NEW;
  END IF;

  -- 3. L'ECHEANCE. C'est ici que le mercredi 00:38 est arrete.
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

DROP TRIGGER IF EXISTS trg_championnat_verrou_calendrier ON public.championnat;
CREATE TRIGGER trg_championnat_verrou_calendrier
  BEFORE UPDATE ON public.championnat
  FOR EACH ROW EXECUTE FUNCTION public.championnat_verrou_calendrier();