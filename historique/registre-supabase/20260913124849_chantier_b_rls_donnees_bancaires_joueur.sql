-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913124849
-- Nom original      : chantier_b_rls_donnees_bancaires_joueur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 12:48:49 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : cbc4df9ad68845a2dbf8775d8ccd02f5
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
-- CHANTIER B — CATEGORIE C : DONNEES BANCAIRES DU JOUEUR
-- 14 septembre 2026. Premiere famille fermee grace a l'identite reelle.
-- ============================================================================
-- ETAT ANTERIEUR : RLS desactive, aucune policy. N'importe quel navigateur
-- pouvait lire -- et modifier -- le compte en banque, les placements et le solde
-- de TOUS les joueurs avec la cle anon publique.
--
-- USAGES REELS VERIFIES fichier par fichier : le jeu ne lit et n'ecrit JAMAIS
-- que le compte de SON propre personnage (sbGetComptesBancaires(state.char.name),
-- sbGetPlacementsBancaires(state.char.name), sbCreerCompteBancaire a la creation,
-- sbMajCompteBancaire sur son propre compte). Aucune lecture croisee.
--
-- Les RPC Helvetia, passees SECURITY DEFINER juste avant, traversent ces policies :
-- depot, retrait, placement, pret et fermeture continuent de fonctionner.
-- Le cron est sous service_role depuis 82b77a2 : il n'est pas concerne.

ALTER TABLE public.comptes_bancaires ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS comptes_bancaires_proprietaire_lecture ON public.comptes_bancaires;
CREATE POLICY comptes_bancaires_proprietaire_lecture ON public.comptes_bancaires
  FOR SELECT TO anon, authenticated
  USING (personnage = public.mon_personnage());

-- La creation du compte de la Banque nationale a lieu cote client, juste apres
-- celle du personnage (creation.js) : on autorise l'insertion, mais pour son
-- propre personnage uniquement.
DROP POLICY IF EXISTS comptes_bancaires_proprietaire_creation ON public.comptes_bancaires;
CREATE POLICY comptes_bancaires_proprietaire_creation ON public.comptes_bancaires
  FOR INSERT TO anon, authenticated
  WITH CHECK (personnage = public.mon_personnage());

-- Depot/retrait a la Banque nationale (plateau-communication.js) : meme regle.
-- NB : cela n'empeche pas un joueur de manipuler SON PROPRE solde -- c'est la
-- limite assumee de ce chantier, qui protege contre AUTRUI, pas contre soi.
DROP POLICY IF EXISTS comptes_bancaires_proprietaire_maj ON public.comptes_bancaires;
CREATE POLICY comptes_bancaires_proprietaire_maj ON public.comptes_bancaires
  FOR UPDATE TO anon, authenticated
  USING (personnage = public.mon_personnage())
  WITH CHECK (personnage = public.mon_personnage());

-- Aucune policy DELETE : un compte ne se supprime que par la RPC de fermeture.

ALTER TABLE public.placements_bancaires ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS placements_bancaires_proprietaire_lecture ON public.placements_bancaires;
CREATE POLICY placements_bancaires_proprietaire_lecture ON public.placements_bancaires
  FOR SELECT TO anon, authenticated
  USING (personnage = public.mon_personnage());
-- Aucune ecriture cliente : creer_placement_* et resoudre_placement_* sont les
-- seules autorites, et elles sont SECURITY DEFINER.