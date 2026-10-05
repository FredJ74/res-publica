-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920091408
-- Nom original      : caisses_autorites_postes_existants
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 09:14:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : cab7fe602c03b12c787d144a53c73f63
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
-- =====================================================================
-- §4 — CAISSES NON MINISTERIELLES : REUTILISER LES POSTES QUI EXISTENT DEJA
-- =====================================================================
-- Avant de demander « qui repond de ces caisses », on regarde ce que le jeu
-- declare deja. postes_nommes_regles contient quatre directions economiques et
-- une capitainerie qui correspondent exactement a des caisses existantes. Les
-- rattacher n'invente aucune mecanique : cela applique l'autorite que le jeu a
-- deja definie, et que personne n'avait reliee a la caisse correspondante.
--
--   capitaine_port          <- nomme par min_fin, scope pays
--   directeur_entrepot      <- nomme par maire_adjoint, scope ville
--   directeur_pharma        <- nomme par min_fin, scope pays
--   directeur_raffinerie    <- nomme par min_fin, scope pays
--   directeur_tabac_alcools <- nomme par min_fin, scope pays
--
-- Le palais du gouvernement est le siege du Premier ministre : sa caisse suit la
-- meme autorite que gouvernement-pm.
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES
  ('port-sainte-marie',    false, '{capitaine_port,min_fin}',        'port industriel — capitainerie'),
  ('palais-gouvernement',  false, '{pm}',                            'siege du Premier ministre'),
  ('entrepot',             true,  '{directeur_entrepot,maire_adjoint}', 'entrepots logistiques'),
  ('usine-pharma',         true,  '{directeur_pharma,min_fin}',      'pharmacie nationale'),
  ('raffinerie',           true,  '{directeur_raffinerie,min_fin}',  'raffinerie'),
  ('pole-tabac-alcools',   true,  '{directeur_tabac_alcools,min_fin}','tabac et alcools')
ON CONFLICT (motif) DO UPDATE
  SET est_prefixe=EXCLUDED.est_prefixe, postes_debit=EXCLUDED.postes_debit, note=EXCLUDED.note;