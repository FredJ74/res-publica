-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919170459
-- Nom original      : contre_espionnage_score_paliers
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:04:59 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : c170dc985f325ad08f5e70c0c096f509
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
-- LOT 3 (socle) du chantier contre-espionnage — le jet unique a paliers.
--
-- ARBITRAGE GD FIXE :
--   score = clamp(0, 100, d100 + 3 x (PER_commissaire - DUP_agent) + (IS_national - 50) / 2)
--   d100 = entier uniforme 1..100, tire EXCLUSIVEMENT cote serveur.
--   Paliers CUMULATIFS : <50 echec | 50-69 faux nom | 70-84 + agent etranger
--                        | 85-91 + vrai nom | 92-100 + pays d'origine.
-- Distribution PLATE assumee : un coup exceptionnel reste possible avec un
-- enqueteur inferieur, et un excellent enqueteur peut echouer.
--
-- Deux fonctions PURES et IMMUTABLE, sans effet de bord, pour que la partie
-- deterministe du calcul soit testable seule. Le tirage du de, lui, vivra dans
-- la RPC d'enquete -- jamais dans le navigateur : aujourd'hui le seul jet
-- d'enquete du jeu est un Math.random() client et plainte_instruire_interne ne
-- tire rien du tout.
--
-- Reutilisation : assemblee_stat_base(stats, cle) lit PER et DUP depuis le jsonb
-- `stats` et rend deja 8 par defaut -- la meme valeur de repli que le client.
-- Aucune caracteristique nouvelle n'est introduite : PER est deja la stat
-- d'enquete du jeu (mener_enquete, controle de caisse, surveillance policiere)
-- et DUP deja la stat de dissimulation.
--
-- Les paliers sont rendus comme un ENTIER CROISSANT 0..4, ce qui rend la regle
-- "une connaissance acquise n'est jamais perdue" triviale a appliquer cote
-- appelant : greatest(niveau_connu, niveau_obtenu).

CREATE OR REPLACE FUNCTION public.contre_espionnage_modificateur(
  p_per_commissaire numeric, p_dup_agent numeric, p_is_national numeric)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $function$
  SELECT round(3 * (coalesce(p_per_commissaire, 8) - coalesce(p_dup_agent, 8))
             + (coalesce(p_is_national, 50) - 50) / 2.0)::integer;
$function$;

-- 0 = echec (rien de nouveau)
-- 1 = le nom public est une fausse identite
-- 2 = + agent etranger
-- 3 = + veritable identite
-- 4 = + pays d'origine
CREATE OR REPLACE FUNCTION public.contre_espionnage_palier(p_score integer)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN p_score IS NULL THEN 0
    WHEN p_score >= 92 THEN 4
    WHEN p_score >= 85 THEN 3
    WHEN p_score >= 70 THEN 2
    WHEN p_score >= 50 THEN 1
    ELSE 0
  END;
$function$;

REVOKE ALL ON FUNCTION public.contre_espionnage_modificateur(numeric,numeric,numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.contre_espionnage_palier(integer)                        FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_modificateur(numeric,numeric,numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_palier(integer)                        TO service_role;
