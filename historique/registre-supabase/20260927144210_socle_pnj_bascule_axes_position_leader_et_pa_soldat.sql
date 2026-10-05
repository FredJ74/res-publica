-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927144210
-- Nom original      : socle_pnj_bascule_axes_position_leader_et_pa_soldat
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 14:42:10 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : fa4b7ac5df7246c9baa51a9e5f2a3207
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
-- CHECKPOINT A — BASCULE DES AXES POSITION/LEADER ET PA POUR LA FAMILLE SOLDAT
--
-- Les neuf ecrivains ont ete reecrits pour ecrire le socle puis projeter. Les quatre fonctions qui
-- DEPLACENT un PNJ entier entre section et reserve (accepter_lieutenant, affectation_decouvrir,
-- candidature_traiter, engagement_affecter_section) n'ecrivent ni leader ni PA : elles transportent
-- l'objet tel quel, le miroir continue d'importer les axes METIER (section, reserve), et les deux
-- cotes restent donc d'accord sans intervention. Verifie fonction par fonction avant cette bascule.
UPDATE public.pnj_axes_autorite SET autorite = 'socle',
       note = 'Bascule checkpoint A : 5 ecrivains de position/leader passent par pnj_membres puis militaire_blob_projeter.'
 WHERE famille = 'soldat' AND axe = 'position_leader';

UPDATE public.pnj_axes_autorite SET autorite = 'socle',
       note = 'Bascule checkpoint A : consommation Alpha generique via pnj_pa_debiter/crediter/fixer ; le metier ne fixe que les couts.'
 WHERE famille = 'soldat' AND axe = 'pa';