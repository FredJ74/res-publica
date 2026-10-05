-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919174528
-- Nom original      : bande_distance_positionnelle_et_identites
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-19 17:45:28 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 54ce4f9fde145bd8d656bf603f122c9e
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
-- (1) Les quatre identites reelles sont desormais arbitrees par le GD.
INSERT INTO public.renseignement_identites_reelles (role, vrai_nom, dup) VALUES
  ('conseiller',   'Gladys Crête',     13),
  ('traducteur',   'Raymond Hialiste', 15),
  ('garde',        'Boris Ketou',      10),
  ('coordinateur', 'Yannick Helle',    12)
ON CONFLICT (role) DO UPDATE SET vrai_nom = EXCLUDED.vrai_nom, dup = EXCLUDED.dup;

-- (2) militaire_bande_distance devient REELLEMENT POSITIONNELLE.
--
-- DEFAUT CORRIGE : la fonction renvoyait 'hors' des que les deux pays
-- differaient, MEME AU MEME ENDROIT -- verifie avant correctif :
--   (republic/capitale/marche) vs (soviet/capitale/marche) -> 'hors'
-- La distance doit dependre des POSITIONS PHYSIQUES, pas de la nationalite :
-- un agent depose a Novomirsk doit voir ce qui se passe a Novomirsk.
--
-- AUCUNE REGRESSION POSSIBLE SUR L'EXISTANT. Les deux seuls appelants,
-- militaire_observer et militaire_entree_zone, passent deja `v_pays` DES DEUX
-- COTES (contournement historique de ce meme defaut) : la branche des pays
-- differents ne s'est donc jamais declenchee pour eux. Verifie avant migration.
--
-- Le pays ne sert plus qu'a departager les deux bandes LOINTAINES, ce qui
-- conserve l'echelle existante : proche (meme batiment) < moyenne (meme ville)
-- < longue (meme pays, autre ville) < hors (autre pays, autre ville).
CREATE OR REPLACE FUNCTION public.militaire_bande_distance(
  p_pays_a text, p_ville_a text, p_bat_a text,
  p_pays_b text, p_ville_b text, p_bat_b text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN p_ville_a IS NOT DISTINCT FROM p_ville_b
     AND p_bat_a   IS NOT DISTINCT FROM p_bat_b   THEN 'proche'
    WHEN p_ville_a IS NOT DISTINCT FROM p_ville_b THEN 'moyenne'
    WHEN p_pays_a  IS NOT DISTINCT FROM p_pays_b  THEN 'longue'
    ELSE 'hors' END;
$function$;
