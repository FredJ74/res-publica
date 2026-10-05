-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920225544
-- Nom original      : militaire_confidentialite_et_effectifs
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 22:55:44 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f9d528f9b56195922f589c0e913a35d1
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
-- CONFIDENTIALITE MILITAIRE ET INTEGRITE DES EFFECTIFS (21 sept. 2026)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. LE BLOB DES COMPAGNIES N'EST PLUS ECRIVABLE PAR UN NAVIGATEUR
-- ---------------------------------------------------------------------
-- EXPLOIT FERME. La policy « compagnies maj par la chaine de commandement »
-- autorisait tout Commandant du pays -- ou le Capitaine de la compagnie --
-- a faire un PATCH du blob ENTIER depuis son navigateur, sans aucun trigger
-- d'attestation. Il pouvait donc REINSERER DANS sections[].soldats des
-- soldats tues au combat, remettre les PA a 12, reecrire armes, formations,
-- positions, la reserve et contingentInitial.
--
-- Le moteur supprime reellement les morts : l'invariant existait, rien ne
-- le protegeait. On ne le remplace pas par une seconde source d'effectifs --
-- la table reste la source de verite unique. On ferme simplement l'ecriture
-- directe : toutes les mutations legitimes passent deja par des RPC
-- SECURITY DEFINER (proprietaire postgres), qui ne sont pas soumises a ces
-- droits et continuent donc de fonctionner a l'identique.
DROP POLICY IF EXISTS "compagnies creation par le commandant" ON public.compagnies_militaires;
DROP POLICY IF EXISTS "compagnies maj par la chaine de commandement" ON public.compagnies_militaires;
REVOKE INSERT, UPDATE, DELETE ON public.compagnies_militaires FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 2. L'ORDRE DE BATAILLE N'EST PLUS PUBLIC
-- ---------------------------------------------------------------------
-- La policy « compagnies lecture » etait FOR SELECT TO anon, authenticated
-- USING (true) : n'importe quel visiteur anonyme lisait les sections, les
-- matricules, les positions, les armes et les formations des QUATRE empires.
-- Cela court-circuitait entierement reconnaissance, camouflage et jumelles :
-- il suffisait de lire la table.
--
-- Le client telechargeait d'ailleurs TOUTES les compagnies puis filtrait par
-- pays dans le navigateur (sbGetCompagnies). Desormais la base ne lui envoie
-- que les siennes : le filtrage cote client devient redondant, et il n'y a
-- plus rien a filtrer. Les forces ennemies ne s'obtiennent que par les
-- mecanismes de detection prevus (militaire_observer, militaire_entree_zone),
-- qui sont SECURITY DEFINER et rendent une projection degradee.
DROP POLICY IF EXISTS "compagnies lecture" ON public.compagnies_militaires;

CREATE POLICY compagnies_lecture_mon_pays ON public.compagnies_militaires
  FOR SELECT TO authenticated
  USING (data->>'pays' = (SELECT d.country FROM public.personnages_donnees d
                           WHERE d.user_id = auth.uid() LIMIT 1));
REVOKE SELECT ON public.compagnies_militaires FROM anon;


-- ---------------------------------------------------------------------
-- 3. SERVICES ET SOLDES — fermes a anon
-- ---------------------------------------------------------------------
-- Qui sert dans l'armee, dans quelle compagnie et a quel grade est un
-- renseignement militaire. La solde est une donnee personnelle.
DROP POLICY IF EXISTS services_militaires_lecture ON public.services_militaires;
CREATE POLICY services_militaires_lecture ON public.services_militaires
  FOR SELECT TO authenticated
  USING (pays = (SELECT d.country FROM public.personnages_donnees d
                  WHERE d.user_id = auth.uid() LIMIT 1));
REVOKE SELECT ON public.services_militaires FROM anon;

DROP POLICY IF EXISTS soldes_militaires_lecture ON public.soldes_militaires;
CREATE POLICY soldes_militaires_lecture ON public.soldes_militaires
  FOR SELECT TO authenticated
  USING (personnage = public.mon_personnage());
REVOKE SELECT ON public.soldes_militaires FROM anon;