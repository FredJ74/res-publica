-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918151126
-- Nom original      : combat_primitives_jet
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 15:11:26 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : c368843927f7040ae3e26d87773cdb87
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
-- =========================================================================================
-- PRIMITIVES DU JET INDIVIDUEL (19 septembre 2026)
-- =========================================================================================
-- Fonctions PURES, sans acces aux tables : elles sont testables isolement et le moteur ne peut
-- pas les contourner. Les coefficients sont ceux du GD, a la lettre, et NE SONT PAS ajustes.
--
-- ARRONDI DETERMINISTE, documente ici une fois pour toutes :
--   * le taux T est arrondi UNE SEULE FOIS, a la fin, par round() (arrondi au plus proche,
--     .5 s'ecartant de zero en PostgreSQL pour le type numeric) ;
--   * le clamp est applique APRES l'arrondi, donc T est toujours un entier de 10 a 85 ;
--   * les seuils T/4 et 3T/4 ne sont PAS arrondis : la comparaison se fait en numerique exact
--     contre le jet entier. Arrondir les seuils deplacerait des probabilites sans raison.
CREATE OR REPLACE FUNCTION public.militaire_taux_combat(
  p_competence numeric, p_defense numeric)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT greatest(10, least(85,
    round(20 + coalesce(p_competence, 0) * 0.7 - coalesce(p_defense, 0) * 2)::integer));
$$;

-- Cinq degres. L'ECHEC CRITIQUE EST TESTE EN PREMIER, et c'est volontaire : il est defini par une
-- plage absolue du de (96-100), pas par une fraction de T. Comme T est plafonne a 85, les deux ne
-- peuvent pas se chevaucher aujourd'hui -- mais tester le de d'abord rend la regle vraie meme si
-- le plafond changeait un jour, et supprime toute ambiguite d'interpretation.
CREATE OR REPLACE FUNCTION public.militaire_degre_combat(p_taux integer, p_jet integer)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_jet >= 96                       THEN 'echec_critique'
    WHEN p_jet <= p_taux / 4.0             THEN 'critique'
    WHEN p_jet <= p_taux * 3.0 / 4.0       THEN 'reussite'
    WHEN p_jet <= p_taux                   THEN 'partielle'
    ELSE                                        'echec'
  END;
$$;

-- Degats en PA par degre. Aucun degat n'est inflige par un echec.
CREATE OR REPLACE FUNCTION public.militaire_degats_combat(p_degre text)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_degre WHEN 'critique' THEN 3 WHEN 'reussite' THEN 2
                      WHEN 'partielle' THEN 1 ELSE 0 END;
$$;

-- =========================================================================================
-- DEFENSE D'UN SOLDAT PNJ -- POINT A ARBITRER, ISOLE ICI EXPRES
-- =========================================================================================
-- Un soldat PNJ d'une compagnie (sections[].soldats[]) ne porte AUCUNE caracteristique
-- defensive : il n'a que matricule, pa, formation (les 4 domaines) et accessoires. Ni PER ni DUP
-- n'existent sur lui, nulle part.
--
-- Les deux valeurs ci-dessous ne sont donc PAS inventees, elles sont reprises de l'existant :
--   * DUP = 3  -- valeur reellement declaree pour PNJ_STATS_PAR_JOB.soldat (data.js), et
--                 identique pour .militaire ;
--   * PER = 10 -- la « valeur neutre deja retenue ailleurs dans le projet », celle que
--                 neutraliserPerCible rend pour toute cible dont la PER n'est pas renseignee.
--
-- Elles sont rassemblees dans UNE fonction pour que le GD puisse les arbitrer en un seul endroit
-- sans toucher au moteur. Voir le rapport : c'est le seul chiffre du moteur qui ne vient pas
-- directement du cahier des charges.
CREATE OR REPLACE FUNCTION public.militaire_defense_pnj(p_cle text)
RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_cle WHEN 'PER' THEN 10 WHEN 'DUP' THEN 3 ELSE 8 END;
$$;

REVOKE ALL ON FUNCTION public.militaire_taux_combat(numeric, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_degre_combat(integer, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_degats_combat(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_defense_pnj(text) FROM PUBLIC, anon, authenticated;