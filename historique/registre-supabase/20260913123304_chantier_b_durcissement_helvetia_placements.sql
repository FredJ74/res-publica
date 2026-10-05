-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913123304
-- Nom original      : chantier_b_durcissement_helvetia_placements
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 12:33:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : fb5cd20914d8a3841176da31d853ced0
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
-- ============================================================================
-- CHANTIER B — DURCISSEMENT DES RPC HELVETIA / PLACEMENTS
-- 14 septembre 2026.
-- ============================================================================
-- POURQUOI. Les 24 fonctions Helvetia et placements sont SECURITY INVOKER : elles
-- s'executent sous le role appelant et ne vivent que des GRANT de 'anon' sur les
-- tables. Activer RLS sur comptes_bancaires, prets ou placements_bancaires les
-- casserait donc toutes. Elles doivent devenir SECURITY DEFINER AVANT toute
-- fermeture -- c'est l'ordre impose par l'arbitrage, et il est respecte ici :
-- cette migration ne ferme AUCUNE table, elle ne fait que rendre les RPC
-- compatibles avec une fermeture ulterieure.
--
-- AUCUNE ELEVATION ARBITRAIRE. Le corps de ces fonctions n'est pas touche : ni
-- SQL dynamique, ni EXECUTE de chaine construite, ni parametre servant de nom
-- d'objet. search_path est fige a 'public, pg_temp' sur chacune, pour qu'un
-- schema pose par un tiers ne puisse pas detourner un appel de table.
--
-- L'IDENTITE DE L'ACTEUR N'EST PAS ENCORE VERIFIEE ICI : ces RPC prennent
-- toujours p_personnage en parametre. Le controle exiger_acteur() sera pose
-- quand l'authentification sera reellement active -- l'imposer maintenant, alors
-- qu'aucun joueur n'a de session, refuserait tout le monde.

DO $$
DECLARE r record;
BEGIN
  -- 1) Les RPC reellement appelees depuis le jeu : SECURITY DEFINER + search_path.
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    WHERE p.proname IN (
      'ouvrir_compte_helvetia', 'deposer_helvetia', 'retirer_helvetia',
      'creer_placement_helvetia', 'fermer_compte_helvetia', 'creer_pret_helvetia',
      'rembourser_pret_helvetia_integral', 'accepter_accord_helvetia',
      'signer_compromis_bien_helvetia', 'finaliser_achat_bien_helvetia',
      'creer_placement_national')
  LOOP
    EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER', r.sig);
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp', r.sig);
  END LOOP;

  -- 2) Les auxiliaires internes et les routines nocturnes : le jeu ne les appelle
  --    JAMAIS (verifie fichier par fichier -- elles n'apparaissent cote client que
  --    dans des commentaires). Les laisser ouvertes a anon, c'est offrir a
  --    n'importe quel navigateur de crediter une destination, de debiter une
  --    source ou de declencher le contentieux nocturne a volonte.
  --    L'ordre compte : les appelants publics viennent de passer DEFINER, ils les
  --    invoquent donc desormais sous l'identite du proprietaire, et continuent de
  --    fonctionner apres cette revocation.
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    WHERE p.proname IN (
      'helvetia_assurer_liquidite', 'helvetia_crediter_destination',
      'helvetia_debiter_fonds_ordinaires', 'helvetia_debiter_source',
      'helvetia_ie_national', 'helvetia_taux_refinancement_bnr',
      'traiter_prets_helvetia_quotidien', 'regler_creances_helvetia_quotidien',
      'resoudre_placement_helvetia', 'resoudre_compromis_helvetia_expire',
      'resoudre_placement_national')
  LOOP
    EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER', r.sig);
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp', r.sig);
    -- PIEGE SUPABASE deja rencontre sur l'Effort de guerre : ALTER DEFAULT
    -- PRIVILEGES accorde EXECUTE a anon sur toute nouvelle fonction publique.
    -- REVOKE ... FROM PUBLIC ne suffit donc pas : il faut nommer anon et
    -- authenticated explicitement.
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.sig);
  END LOOP;
END $$;