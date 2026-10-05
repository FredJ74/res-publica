-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917231454
-- Nom original      : militaire_reconnaissance_detection
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 23:14:54 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6ad8c72c92759bbdd46900efaaf7268f
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
-- ==========================================================================================
-- RECONNAISSANCE, CAMOUFLAGE ET DETECTION — moteur serveur
--
-- FORMULE GD, appliquee telle quelle :
--   chance = 50 + Reconnaissance(observateur) - Camouflage(cible) + modificateur_distance
--   bornee a [5, 95]. Jet EXCLUSIVEMENT serveur.
--
-- ATTENTION AU SIGNE, et c'est le piege que le GD signale explicitement. Le bareme de taille est
-- un MALUS DE DISCRETION de la cible : il est donc NEGATIF et vient REDUIRE son camouflage, ce qui
-- AUGMENTE la chance de la detecter. Un groupe de 25 est bien plus facile a reperer qu'un
-- eclaireur isole. La fonction est ecrite pour que ce sens soit lisible et testable.
--
-- EN CAS D'ECHEC : AUCUNE information. On ne revele jamais, meme implicitement, qu'une force
-- etait presente -- pas de « vous n'avez pas repere 12 Sovarkiens ».
--
-- DEGRADATION FAITE SERVEUR. Les effectifs et positions exacts ne quittent JAMAIS la base : la
-- fonction ne renvoie que le renseignement deja degrade. Masquer graphiquement une donnee exacte
-- envoyee au client serait recuperable par triche.
--
-- L'imprecision ELARGIT, REGROUPE, RETIRE ou REND INCERTAIN un renseignement reel. Elle ne
-- fabrique jamais de fausse donnee precise : 12 Sovarkiens ne deviennent jamais 40 Republiens.
-- ==========================================================================================

-- ---- Malus de discretion lie a la taille du groupe (NEGATIF : un gros groupe se cache mal) ----
CREATE OR REPLACE FUNCTION public.militaire_malus_taille(p_effectif integer)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path = public AS $fn$
  SELECT CASE
    WHEN coalesce(p_effectif,0) <= 1  THEN 0
    WHEN p_effectif <= 4   THEN -5
    WHEN p_effectif <= 9   THEN -10
    WHEN p_effectif <= 15  THEN -20
    WHEN p_effectif <= 25  THEN -30
    WHEN p_effectif <= 50  THEN -40
    ELSE -50 END;
$fn$;

-- ---- Bande de distance, DERIVEE de la topologie reelle du jeu ----
-- Le jeu n'a aucune mesure metrique : sa topologie est pays > ville > batiment > piece. La
-- traduction retenue en decoule directement, sans inventer d'echelle :
--   proche  : meme ville ET meme batiment
--   moyenne : meme ville, batiment different
--   longue  : meme pays, ville differente
--   hors    : pays different -- aucune detection passive
CREATE OR REPLACE FUNCTION public.militaire_bande_distance(
  p_pays_a text, p_ville_a text, p_bat_a text,
  p_pays_b text, p_ville_b text, p_bat_b text
) RETURNS text LANGUAGE sql IMMUTABLE SET search_path = public AS $fn$
  SELECT CASE
    WHEN p_pays_a IS DISTINCT FROM p_pays_b THEN 'hors'
    WHEN p_ville_a IS NOT DISTINCT FROM p_ville_b
     AND p_bat_a  IS NOT DISTINCT FROM p_bat_b  THEN 'proche'
    WHEN p_ville_a IS NOT DISTINCT FROM p_ville_b THEN 'moyenne'
    ELSE 'longue' END;
$fn$;

CREATE OR REPLACE FUNCTION public.militaire_modif_distance(p_bande text)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path = public AS $fn$
  SELECT CASE p_bande WHEN 'proche' THEN 0 WHEN 'moyenne' THEN -20
                      WHEN 'longue' THEN -40 ELSE NULL END;
$fn$;

-- ---- Camouflage effectif d'un groupe ----
-- Une tenue protege CELUI QUI LA PORTE : le bonus est donc PROPORTIONNEL a la part reellement
-- equipee. Une seule tenue ne camoufle jamais 24 hommes.
--   camouflage = moyenne(reconnaissance des membres) + 20 * (equipes / effectif) + malus_taille
CREATE OR REPLACE FUNCTION public.militaire_camouflage_groupe(
  p_reco_moyenne numeric, p_effectif integer, p_equipes integer
) RETURNS numeric LANGUAGE sql IMMUTABLE SET search_path = public AS $fn$
  SELECT coalesce(p_reco_moyenne, 0)
       + CASE WHEN coalesce(p_effectif,0) > 0
              THEN 20.0 * least(1.0, greatest(0, coalesce(p_equipes,0))::numeric / p_effectif)
              ELSE 0 END
       + public.militaire_malus_taille(p_effectif);
$fn$;

-- ---- Chance de detection, bornee [5, 95] ----
CREATE OR REPLACE FUNCTION public.militaire_chance_detection(
  p_reco_observateur numeric, p_camouflage_cible numeric,
  p_modif_distance integer, p_bonus_jumelles integer DEFAULT 0
) RETURNS integer LANGUAGE sql IMMUTABLE SET search_path = public AS $fn$
  SELECT greatest(5, least(95, round(
    50 + coalesce(p_reco_observateur,0) - coalesce(p_camouflage_cible,0)
       + coalesce(p_modif_distance,0) + coalesce(p_bonus_jumelles,0))::integer));
$fn$;

-- ---- Degradation du renseignement, faite SERVEUR ----
-- L'imprecision elargit, regroupe, retire ou rend incertain. Elle n'invente jamais.
CREATE OR REPLACE FUNCTION public.militaire_degrader(
  p_bande text, p_effectif integer, p_pays text, p_ville text, p_batiment text
) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path = public AS $fn$
  SELECT CASE p_bande
    -- Proche : lieu au batiment, nationalite sure, petite fourchette autour du reel.
    WHEN 'proche' THEN jsonb_build_object(
      'precision', 'proche', 'ville', p_ville, 'batiment', p_batiment,
      'nationalite', p_pays, 'nationalite_sure', true,
      'effectif_min', greatest(1, p_effectif - 1), 'effectif_max', p_effectif + 1,
      'libelle', (greatest(1, p_effectif - 1))::text || ' à ' || (p_effectif + 1)::text || ' soldats')
    -- Moyenne : lieu a la ville, nationalite sure, tranche de 5.
    WHEN 'moyenne' THEN jsonb_build_object(
      'precision', 'moyenne', 'ville', p_ville, 'batiment', NULL,
      'nationalite', p_pays, 'nationalite_sure', true,
      'effectif_min', greatest(1, (p_effectif / 5) * 5),
      'effectif_max', ((p_effectif / 5) + 1) * 5,
      'libelle', greatest(1, (p_effectif / 5) * 5)::text || ' à ' || (((p_effectif / 5) + 1) * 5)::text || ' hommes')
    -- Longue : lieu a la ville, nationalite INCERTAINE, effectif tres approximatif.
    WHEN 'longue' THEN jsonb_build_object(
      'precision', 'longue', 'ville', p_ville, 'batiment', NULL,
      'nationalite', p_pays, 'nationalite_sure', false,
      'effectif_min', NULL, 'effectif_max', NULL,
      'libelle', CASE WHEN p_effectif < 10 THEN 'moins de 10 hommes'
                      WHEN p_effectif < 30 THEN 'une dizaine d''hommes, peut-être plus'
                      ELSE 'plusieurs dizaines d''hommes' END)
    -- Au-dela : rien d'autre qu'un signe de vie. Ni effectif, ni nationalite.
    ELSE jsonb_build_object(
      'precision', 'limite', 'ville', p_ville, 'batiment', NULL,
      'nationalite', NULL, 'nationalite_sure', false,
      'effectif_min', NULL, 'effectif_max', NULL,
      'libelle', 'Mouvement de troupes possible dans ce secteur')
  END;
$fn$;

REVOKE ALL ON FUNCTION public.militaire_malus_taille(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_bande_distance(text,text,text,text,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_modif_distance(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_camouflage_groupe(numeric,integer,integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_chance_detection(numeric,numeric,integer,integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_degrader(text,integer,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_malus_taille(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.militaire_bande_distance(text,text,text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.militaire_modif_distance(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.militaire_camouflage_groupe(numeric,integer,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.militaire_chance_detection(numeric,numeric,integer,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.militaire_degrader(text,integer,text,text,text) TO service_role;