-- ======================================================================
-- CONFIDENTIALITE MILITAIRE ET INTEGRITE DES EFFECTIFS — LOT COMPLET
-- 21 septembre 2026
-- ======================================================================
--
-- Securite : fermeture de l'ecriture directe du blob des compagnies,
-- confidentialite de l'ordre de bataille, des services et des soldes, puis
-- correction des policies qui lisaient personnages_donnees sans droits.
--
-- AVERTISSEMENT — FICHIER DE VERSIONNEMENT, PAS DE DEVELOPPEMENT.
-- Ce fichier ne fait que reproduire, a l'identique et DANS L'ORDRE
-- CHRONOLOGIQUE REELLEMENT APPLIQUE, les migrations deja passees en
-- production. Le SQL n'a ete ni corrige, ni reformate, ni consolide :
-- certaines migrations REDEFINISSENT un objet pose par une migration
-- anterieure du meme lot (avec DROP et changement de signature), et un
-- rejeu sequentiel fidele est plus sur qu'un etat final reconstruit.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES, dans cet ordre :
--   20260920225544  militaire_confidentialite_et_effectifs
--   20260920225942  militaire_mon_pays_pour_policies
--
-- REDEFINITIONS EN COURS DE FICHIER (attendues) :
--   compagnies_lecture_mon_pays et services_militaires_lecture : creees par
--     20260920225544, puis REDEFINIES par 20260920225942 (DROP POLICY puis
--     CREATE POLICY, en passant par public.militaire_mon_pays()).
-- ======================================================================


-- ######################################################################
-- MIGRATION 20260920225544  militaire_confidentialite_et_effectifs
-- ######################################################################

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


-- ######################################################################
-- MIGRATION 20260920225942  militaire_mon_pays_pour_policies
-- ######################################################################

-- Les policies de confidentialite militaire lisaient personnages_donnees
-- directement. Or une policy s'evalue avec les droits du ROLE APPELANT, et
-- `authenticated` n'a aucun droit sur cette table (seule la vue lui est
-- accordee) : toute lecture levait « permission denied for table
-- personnages_donnees ». Meme piege que celui deja resolu par mon_personnage().
CREATE OR REPLACE FUNCTION public.militaire_mon_pays()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $function$
  SELECT d.country FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION public.militaire_mon_pays() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_mon_pays() TO authenticated, service_role;

DROP POLICY IF EXISTS compagnies_lecture_mon_pays ON public.compagnies_militaires;
CREATE POLICY compagnies_lecture_mon_pays ON public.compagnies_militaires
  FOR SELECT TO authenticated
  USING (data->>'pays' = public.militaire_mon_pays());

DROP POLICY IF EXISTS services_militaires_lecture ON public.services_militaires;
CREATE POLICY services_militaires_lecture ON public.services_militaires
  FOR SELECT TO authenticated
  USING (pays = public.militaire_mon_pays());
