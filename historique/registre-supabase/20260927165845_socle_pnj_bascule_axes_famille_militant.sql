-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927165845
-- Nom original      : socle_pnj_bascule_axes_famille_militant
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 16:58:45 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 0a91bdc1839de5a4d7a01a13141c3160
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
-- CHECKPOINT B (suite) — LES AXES DE LA FAMILLE `militant` PASSENT AU SOCLE
-- `militant_recruter` est desormais son seul createur et ecrit pnj_membres. Meme raisonnement que
-- pour la famille employe : le socle decide, donc l'axe doit le dire, sinon le refus de PA est
-- attribue a l'axe alors que le vrai motif est la CLASSE -- un Beta ne consomme pas ses PA.
-- Aucune donnee a migrer : militants_recrutes etait vide (la famille n'avait jamais servi).
UPDATE public.pnj_axes_autorite SET autorite = 'socle',
       note = 'Bascule du 27/09/2026 : militant_recruter ecrit pnj_membres, et militants_recrutes '
           || 'etait vide -- rien a migrer. Le registre historique reste alimente car '
           || 'sbGetMesMilitants le lit encore. La position du militant est PROPRE (il ne suit '
           || 'personne) et son affichage a l''universite reste pilote par enterRoom.'
 WHERE famille = 'militant';