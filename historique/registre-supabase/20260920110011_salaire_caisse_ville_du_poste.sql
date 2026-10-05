-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920110011
-- Nom original      : salaire_caisse_ville_du_poste
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 11:00:11 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 434c46d90f01d9a3362fe0b93cd63bc1
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
-- ARBITRAGE GD DU 20/09/2026 : « chaque juge est payé par la caisse du tribunal
-- de sa propre ville ». Principe general deja valide : le titulaire est paye par
-- l'institution dans laquelle il exerce.
--
-- CE QUE J'AI TROUVE EN APPLIQUANT. Le motif du juge etait fige sur
-- « {pays}_tribunal_capitale ». Ce n'etait pas une negligence : le juge est
-- aujourd'hui declare comme un poste NATIONAL (plateau-politique.js, section
-- « national »), au meme titre que les ministres -- seuls maire, commissaire et
-- directeur d'entrepot sont declares par ville. Un juge ne porte donc AUCUNE
-- ville sur sa fiche. La regle arbitree suppose des juges par ville, ce qui est
-- un changement de structure que je ne decide pas ici : le motif est corrige,
-- et la regle s'appliquera d'elle-meme le jour ou le poste portera une ville.
--
-- LE TROU QUE LE CHANGEMENT AURAIT OUVERT. salaire_civil_percevoir resolvait la
-- ville par « coalesce(poste->>'city', current_city) ». current_city, c'est la
-- ville ou le joueur SE TROUVE, pas celle ou il exerce. Avec un motif contenant
-- {ville}, un titulaire sans ville declaree se serait fait payer par le tribunal
-- de la ville ou il passait -- et aurait pu vider les trois en se deplacant.
-- La ville vient desormais du POSTE, jamais de la position. A defaut, elle vient
-- d'un defaut DECLARE par poste ; sans defaut declare, on refuse de payer plutot
-- que de choisir une caisse au hasard.

ALTER TABLE public.salaires_caisses
  ADD COLUMN IF NOT EXISTS ville_defaut text;

-- Le juge est national aujourd'hui : son defaut declare est la capitale, ce qui
-- reproduit trait pour trait le comportement actuel. Le jour ou un juge portera
-- « ville_b », il sera paye par le tribunal de Montrouge sans autre changement.
UPDATE public.salaires_caisses
   SET motif = '{pays}_tribunal_{ville}', ville_defaut = 'capitale'
 WHERE poste_id = 'juge';

-- Maire et commissaire portent TOUJOURS leur ville : pas de defaut, donc refus
-- explicite si elle venait a manquer, au lieu d'un paiement par la mauvaise caisse.
UPDATE public.salaires_caisses
   SET ville_defaut = NULL
 WHERE poste_id IN ('maire', 'maire_adjoint', 'commissaire');

CREATE OR REPLACE FUNCTION public.salaire_ville_du_poste(p_poste_id text, p_ville_fiche text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN coalesce(btrim(p_ville_fiche), '') <> '' THEN p_ville_fiche
    ELSE (SELECT s.ville_defaut FROM public.salaires_caisses s WHERE s.poste_id = p_poste_id)
  END;
$$;
REVOKE ALL ON FUNCTION public.salaire_ville_du_poste(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.salaire_ville_du_poste(text, text) TO authenticated, service_role;