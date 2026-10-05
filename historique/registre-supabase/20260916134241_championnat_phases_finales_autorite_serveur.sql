-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916134241
-- Nom original      : championnat_phases_finales_autorite_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 13:42:41 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : fba879c124e06728d71997956449a0ec
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
-- PHASES FINALES : MEME AUTORITE QUE LA SAISON REGULIERE (16 septembre 2026).
--
-- Le verrou pose ce matin ne regardait que data->'calendrier' : les playoffs vivent ailleurs,
-- dans data->'playoffs', et passaient donc par la branche « ecriture ordinaire », sans controle
-- d'echeance. Un client pouvait encore faire tomber des quarts un mercredi, et publier lui-meme
-- le sacre d'un champion. On etend le MEME declencheur -- pas un second moteur.
--
-- CE QUI RESTE AU CLIENT, VOLONTAIREMENT : la simulation des rencontres, exactement comme pour
-- la saison reguliere. Le serveur ne tire pas les scores ; il decide QUAND un tour peut tomber,
-- refuse qu'on le rejoue, et signe seul les communiques. Aucune regle de jeu ne change : ni
-- structure du tableau, ni qualification a l'aggregat, ni primes, ni classement, ni sacre.
--
-- ORDRE DES TOURS, tel que le jeu le definit (progresserPlayoffs) :
--   quarts_aller -> quarts_retour -> demies_aller -> demies_retour -> finale -> termine
-- Une etape ne peut qu'avancer d'un cran, jamais sauter ni revenir.

CREATE OR REPLACE FUNCTION public.championnat_rang_etape(p_etape text)
RETURNS integer
LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT CASE p_etape
           WHEN 'quarts_aller'  THEN 1 WHEN 'quarts_retour' THEN 2
           WHEN 'demies_aller'  THEN 3 WHEN 'demies_retour' THEN 4
           WHEN 'finale'        THEN 5 WHEN 'termine'       THEN 6
           ELSE NULL END;
$$;

CREATE OR REPLACE FUNCTION public.championnat_verrou_calendrier()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
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
END; $$;