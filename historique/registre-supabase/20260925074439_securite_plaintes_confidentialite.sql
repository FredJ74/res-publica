-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260925074439
-- Nom original      : securite_plaintes_confidentialite
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-25 07:44:39 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3574d3a1beaac2b5bf871d93f6c98ea0
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
-- CONFIDENTIALITE DES PLAINTES ET AFFAIRES (25 septembre 2026) — arbitrage GD rendu
-- =============================================================================================
-- CE QUI ETAIT OUVERT : policy SELECT `USING(true)` pour anon ET authenticated. N'importe qui,
-- sans compte, lisait toutes les plaintes du pays : nom de l'accuse et motif saisi par le
-- plaignant, des le depot et avant toute decision. L'ecran « Affaires en cours » du tribunal
-- (ordre `plainte`, 1 PA, aucun poste requis) les affichait d'ailleurs a tout joueur.
--
-- LES PHASES, telles qu'arbitrees, et leur correspondance avec les statuts REELS du code :
--   Phase 1  depot            pending, enquete, classee, annulee  -> NON publique
--   Phase 2  prise en charge  transmise, deposee                  -> parties + autorites
--   Phase 3  proces           (aucun statut : le moteur procedural reste a ecrire)
--   Phase 4  archives         jugee                               -> PUBLIQUE, acquittement compris
--
-- CE QUE JE N'INVENTE PAS. Fred a indique qu'un chantier sur le DEROULEMENT DU PROCES reste a
-- faire. Il n'existe aujourd'hui aucun statut « en proces » : `deposee` signifie « transmise au
-- tribunal, en attente de jugement ». Je le traite donc en phase 2 -- parties et autorites --
-- et non comme un dossier deja public. C'est la lecture conservatrice : elle ne revele rien
-- prematurement et n'invente aucune etape. Le jour ou le moteur de proces existera, il suffira
-- d'ajouter son statut a la branche publique.
--
-- QUI VOIT QUOI :
--   - tout le monde      : les affaires JUGEES (archives judiciaires publiques)
--   - le juge / le commissaire de la VILLE de l'affaire : deja porte par affaire_autorite_de()
--   - le Ministre de la Justice  : il peut annuler les poursuites (ordre annuler_poursuites)
--   - le Ministre de l'Interieur : il ouvre les dossiers de plainte (ouvrirDossiersPlaintes)
--   - le plaignant et la personne mise en cause : deja porte par affaire_me_concerne()
--
-- LES RUMEURS NE SONT PAS TOUCHEES. Verifie : le depot de plainte n'ecrit RIEN dans
-- actions_tracables ni rumeurs_actives -- aucun appel a tracerActionPourRumeur dans
-- openPlainteModal, soumettrePlaynte, transmettreAffaireAuTribunal ni deciderDossierPlainte. La
-- couche rumeur vit a cote, alimentee par arrestation_urgence, corruption, rebellion_cellule et
-- torture_qhs. Elle reste entiere : une rumeur peut continuer de dire « il parait que X aurait
-- porte plainte », sans donner acces au dossier.
--
-- L'ECRITURE N'EST PAS TOUCHEE : elle portait deja la bonne regle
-- (affaire_autorite_de(city) OR affaire_me_concerne(data)).

-- Lecture sure du statut : `data` est du TEXTE et peut ne pas etre du JSON.
CREATE OR REPLACE FUNCTION public.affaire_statut(p_data text)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF p_data IS NULL OR left(btrim(p_data), 1) <> '{' THEN RETURN NULL; END IF;
  RETURN (p_data::jsonb ->> 'status');
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;   -- data illisible : aucune publicite accordee
END;
$$;

DROP POLICY IF EXISTS "plaintes_lecture" ON public.plaintes_en_cours;

CREATE POLICY "affaire lue par les parties, l autorite, ou publique une fois jugee"
  ON public.plaintes_en_cours
  FOR SELECT TO authenticated
  USING (
       public.affaire_statut(data) = 'jugee'
    OR public.affaire_autorite_de(city)
    OR public.mon_poste_est_dans('min_just', country)
    OR public.mon_poste_est_dans('min_int',  country)
    OR public.affaire_me_concerne(data)
  );

REVOKE ALL ON public.plaintes_en_cours FROM anon;