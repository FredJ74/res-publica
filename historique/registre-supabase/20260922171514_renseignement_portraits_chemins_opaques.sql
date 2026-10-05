-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260922171514
-- Nom original      : renseignement_portraits_chemins_opaques
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-22 17:15:14 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : c9cbf073bb5c285076155be15bee19ae
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
-- LE CHEMIN DU PORTRAIT NE DOIT RIEN LAISSER DEDUIRE (22 septembre 2026, 2e passe).
-- Premiere passe : le fichier etait nomme d'apres le VRAI NOM -- corrige en le nommant par
-- ROLE. Mais « images/renseignement/traducteur-soviet.png » dit encore deux choses interdites
-- a un transporteur ordinaire : que la personne releve du RENSEIGNEMENT (le dossier), et
-- quelle est sa SPECIALITE (le fichier). Les deux figurent noir sur blanc dans l'URL que son
-- navigateur recoit.
--
-- Desormais : dossier neutre « images/personnages/ », nom opaque « p-<10 hex>.png ». La
-- correspondance role x couverture -> fichier vit ICI et nulle part ailleurs ; le navigateur
-- ne recoit que l'URL finale, dont on ne peut rien tirer. Les seize images sont les memes,
-- simplement deplacees : aucune retouche graphique.
--
-- Les identifiants sont STABLES (derives d'un sel fixe hors ligne) : les regenerer a
-- l'identique est possible, mais il n'y a aucune raison de le faire -- ils sont figes ici.
CREATE OR REPLACE FUNCTION public.agent_portrait_chemin(p_role text, p_pays text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT 'images/personnages/' || CASE coalesce(p_role,'') || '|' || coalesce(p_pays,'republic')
    WHEN 'garde|republic'         THEN 'p-67740f3df7'
    WHEN 'garde|narco'            THEN 'p-1f148ae9f5'
    WHEN 'garde|soviet'           THEN 'p-221564b95c'
    WHEN 'garde|khalija'          THEN 'p-a085743493'
    WHEN 'traducteur|republic'    THEN 'p-9e88f09ad6'
    WHEN 'traducteur|narco'       THEN 'p-dd5ad03955'
    WHEN 'traducteur|soviet'      THEN 'p-98e6627171'
    WHEN 'traducteur|khalija'     THEN 'p-643e623f47'
    WHEN 'conseiller|republic'    THEN 'p-5669ed962a'
    WHEN 'conseiller|narco'       THEN 'p-3ff97a66be'
    WHEN 'conseiller|soviet'      THEN 'p-94c4b18cd9'
    WHEN 'conseiller|khalija'     THEN 'p-bf4a001945'
    WHEN 'coordinateur|republic'  THEN 'p-84f967d6cd'
    WHEN 'coordinateur|narco'     THEN 'p-3ce0e49fa3'
    WHEN 'coordinateur|soviet'    THEN 'p-6ec78181dc'
    WHEN 'coordinateur|khalija'   THEN 'p-9e17eaed14'
    ELSE 'p-inconnu'
  END || '.png';
$$;

GRANT EXECUTE ON FUNCTION public.agent_portrait_chemin(text, text) TO authenticated, service_role;