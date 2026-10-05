-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924084318
-- Nom original      : militaire_revoquer_public_reliquat
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-24 08:43:18 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 0104353561d5155297d08f284b3e057e
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
-- =============================================================================================
-- SUITE : SIX FONCTIONS RESTAIENT OUVERTES *A PUBLIC* (24 septembre 2026)
-- =============================================================================================
-- La revocation precedente a ferme trois fonctions sur neuf. Les six autres resistaient parce que
-- leur droit ne venait pas d'un GRANT nominatif a `anon`, mais d'un GRANT a PUBLIC -- visible dans
-- l'ACL sous la forme `=X/postgres`. Revoquer « FROM anon » ne retire pas un droit accorde a tout
-- le monde : il faut le retirer a PUBLIC.
--
-- C'EST SANS RISQUE POUR LES JOUEURS : chacune de ces six fonctions porte DEJA un droit nominatif
-- `authenticated=X/postgres`, qui survit a la revocation de PUBLIC. Les appels internes des
-- fonctions SECURITY DEFINER ne dependent d'aucun de ces droits.
--
-- Les cinq helpers mutinerie_* sont en lecture mais exposent des positions et des appartenances de
-- camp ; exiger_poste est le garde-fou d'autorite lui-meme. Ni les uns ni l'autre n'ont de raison
-- d'etre offerts a un visiteur anonyme.
-- =============================================================================================

REVOKE EXECUTE ON FUNCTION public.exiger_poste(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mutinerie_camp_de(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mutinerie_camps_presents(text, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mutinerie_est_camp(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mutinerie_pays_du_camp(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mutinerie_social_national(text) FROM PUBLIC;

-- Ceinture et bretelles : on reaffirme explicitement le droit des deux roles legitimes.
GRANT EXECUTE ON FUNCTION public.exiger_poste(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mutinerie_camp_de(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mutinerie_camps_presents(text, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mutinerie_est_camp(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mutinerie_pays_du_camp(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mutinerie_social_national(text) TO authenticated, service_role;