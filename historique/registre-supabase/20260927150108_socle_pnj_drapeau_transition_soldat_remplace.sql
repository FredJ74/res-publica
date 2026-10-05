-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927150108
-- Nom original      : socle_pnj_drapeau_transition_soldat_remplace
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 15:01:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9b2ada2d285016f3eff350be033aa4b1
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
-- CHECKPOINT A — LE DRAPEAU DE TRANSITION EST REMPLACE, DONC NEUTRALISE
--
-- `soldats_blob_autoritaire` etait un interrupteur unique : tout ou rien pour la famille soldat.
-- Le lot 4 l'a remplace par deux mecanismes que ce drapeau confondait :
--   - `pnj_axes_autorite`        : quel magasin fait autorite, axe par axe. Etat de MIGRATION.
--   - `pnj_mouvement_individuel` : peut-on extraire un membre de son groupe. REGLE DE JEU permanente.
-- Verifie avant neutralisation : AUCUNE fonction du schema ne lit plus ce drapeau (0 occurrence
-- dans pg_proc.prosrc), et aucun fichier client ne le nomme. Les seuls lecteurs actuels sont
-- `pnj_pa_garde` et `pnj_miroir_possessions_si_axe_blob` pour l'axe, et `pnj_prendre`,
-- `pnj_quitter_groupe`, `pnj_transferer` pour la regle de jeu.
--
-- La ligne est conservee, pas supprimee : elle garde la trace de la transition et sa note dit
-- desormais ou regarder. La supprimer ferait disparaitre l'explication avec elle.
UPDATE public.pnj_transitions
   SET actif = false,
       note = 'PERIME le 27 septembre 2026, a la bascule des axes position_leader et pa de la '
           || 'famille soldat. Ne plus lire ce drapeau : il confondait l''etat de migration et la '
           || 'regle de jeu. Pour savoir quel magasin fait autorite, interroger pnj_axes_autorite '
           || '(via pnj_axe_verrouille). Pour savoir si un membre peut etre extrait de son groupe, '
           || 'interroger pnj_mouvement_individuel (via pnj_mouvement_individuel_refus).'
 WHERE cle = 'soldats_blob_autoritaire';