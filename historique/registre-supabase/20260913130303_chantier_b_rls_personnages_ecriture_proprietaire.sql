-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913130303
-- Nom original      : chantier_b_rls_personnages_ecriture_proprietaire
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 13:03:03 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 782ca77d38b2e9ef94848651cf03590e
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
-- CHANTIER B — FERMETURE DE personnages EN ECRITURE
-- 13 septembre 2026, juste apres la reinitialisation : zero joueur en base,
-- donc aucune partie en cours ne peut etre interrompue par cette bascule.
-- ============================================================================
-- ETAT ANTERIEUR : une seule policy, allow_all_personnages, FOR ALL, USING(true),
-- WITH CHECK(true), sans restriction de role. Autrement dit : n'importe quel
-- navigateur pouvait, avec la cle anon publique, reecrire la fiche de n'importe
-- quel joueur -- argent, poste, inventaire, detention.
--
-- CE QUE CETTE MIGRATION ETABLIT :
--   * un joueur n'ecrit QUE sur sa propre ligne, identifiee par user_id = auth.uid() ;
--   * l'insertion n'est possible que pour soi (le declencheur pose user_id,
--     la policy verifie qu'il correspond bien au compte connecte) ;
--   * la lecture reste ouverte pour l'instant : le jeu affiche partout des
--     informations d'autres personnages (repertoire, salles, elections, forum).
--     La restriction des colonnes PRIVEES fera l'objet d'une etape dediee.
--
-- CE QU'ELLE N'ETABLIT PAS, ET QU'IL FAUT DIRE : un joueur peut toujours
-- falsifier SA PROPRE ligne depuis son client (arg, inventaire, stats). Ce
-- chantier protege contre AUTRUI, pas contre soi -- l'economie cote serveur est
-- un chantier distinct, deja identifie.
--
-- LES ECRITURES LEGITIMES SUR AUTRUI (arrestation, nomination, sanction, salaire)
-- passeront par des RPC SECURITY DEFINER, qui traversent ces policies apres avoir
-- verifie l'autorite reelle de l'appelant.

DROP POLICY IF EXISTS allow_all_personnages ON public.personnages;

-- Lecture : inchangee a ce stade (voir ci-dessus).
DROP POLICY IF EXISTS personnages_lecture ON public.personnages;
CREATE POLICY personnages_lecture ON public.personnages
  FOR SELECT TO anon, authenticated USING (true);

-- Creation : uniquement pour son propre compte.
DROP POLICY IF EXISTS personnages_creation_soi ON public.personnages;
CREATE POLICY personnages_creation_soi ON public.personnages
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Modification : uniquement sa propre ligne, et on ne peut pas la faire changer
-- de proprietaire (le declencheur l'interdit deja ; la policy le redit).
DROP POLICY IF EXISTS personnages_maj_soi ON public.personnages;
CREATE POLICY personnages_maj_soi ON public.personnages
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Suppression : un joueur ne peut detruire que son propre personnage
-- (« Detruire mon personnage », plateau-personnage.js).
DROP POLICY IF EXISTS personnages_suppression_soi ON public.personnages;
CREATE POLICY personnages_suppression_soi ON public.personnages
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());