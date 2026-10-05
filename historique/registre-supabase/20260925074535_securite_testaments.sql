-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260925074535
-- Nom original      : securite_testaments
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-25 07:45:35 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8eb13e57de86e278b82d4b8bb00b7f2d
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
-- LE TESTAMENT EST CONFIDENTIEL (25 septembre 2026)
-- =============================================================================================
-- CE QUI ETAIT OUVERT : `testaments` sans RLS, avec INSERT/SELECT/UPDATE pour anon. Le contenu --
-- beneficiaires, repartition, legs -- etait lisible par n'importe qui, sans compte.
--
-- CE QUE LE JEU PERMET REELLEMENT (audit). Deux seuls ecrans lisent un testament, et les deux ne
-- lisent que CELUI DU JOUEUR : doGererTestament et ouvrirFormulaireTestament (sur state.char.name),
-- plus ouvrirSuccession qui lit celui du defunt -- or le defunt est toujours le joueur connecte
-- lui-meme, confirmerDestructionPersonnage etant le seul appelant. AUCUN ecran ne montre le
-- testament d'autrui. `sbGetTousLesTestaments` existe et accepte un nom arbitraire, mais n'est
-- appelee nulle part : capacite presente dans le code, sans aucune interface.
--
-- LE NOTAIRE N'A AUCUN TITULAIRE JOUEUR. Verifie : `notaire` n'apparait ni dans POSTES_ELECTIFS,
-- ni dans POSTES_NOMMES_EXCLUSIFS, ni dans les offres du BNE. C'est un `job:` de PNJ (Notaire
-- Fontenelle), et son role dans la succession est fiscal -- 10 % des droits verses a la caisse de
-- l'office notarial -- jamais procedural. L'arbitrage « le notaire peut savoir que X a depose un
-- testament, sans en connaitre le contenu » est donc note mais SANS PORTEUR A CE JOUR : il n'y a
-- personne a qui accorder ce droit. Le jour ou le poste existera, la branche s'ajoutera ici, et
-- elle devra porter sur l'EXISTENCE seule -- jamais un SELECT brut sur `contenu`.
--
-- REGLE RENDUE AUTORITAIRE : un testament n'appartient qu'a son testateur.
ALTER TABLE public.testaments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "testament lu par son seul testateur" ON public.testaments
  FOR SELECT TO authenticated
  USING (testateur = (SELECT public.mon_personnage()));

CREATE POLICY "testament redige en son propre nom" ON public.testaments
  FOR INSERT TO authenticated
  WITH CHECK (testateur = (SELECT public.mon_personnage()));

-- Modification = nouveau testament + ancien passe a `remplace` ; revocation = passage a `revoque`.
-- Les deux sont des changements de statut sur SON propre testament.
CREATE POLICY "testament revoque ou remplace par son testateur" ON public.testaments
  FOR UPDATE TO authenticated
  USING (testateur = (SELECT public.mon_personnage()))
  WITH CHECK (testateur = (SELECT public.mon_personnage()));

-- Aucune policy DELETE : un testament n'est jamais supprime, son statut change.

REVOKE ALL ON public.testaments FROM anon;

-- ---------------------------------------------------------------------------------------------
-- SUCCESSIONS : seul l'acces sans compte est ferme dans cette passe.
-- ---------------------------------------------------------------------------------------------
-- La fuite cote joueur est reelle et documentee : sbGetSuccessionsEnAttente rapatrie au navigateur
-- TOUTES les successions en cours du pays, dispositions completes comprises (noms des heritiers
-- convoques, parts en FR, echeances), et le filtrage par beneficiaire est purement client. Idem
-- pour sbGetToutesLesSuccessions, qui ramene tous les statuts alors que les Archives Notariales
-- ne montrent que les successions `resolue`.
--
-- JE NE LA REFERME PAS CETTE NUIT, DELIBEREMENT. Le predicat correct doit suivre la chaine de
-- convocation (principal -> remplacant -> legal_conjoint), qui vit dans `dispositions`. Se
-- tromper, c'est empecher un heritier de reclamer son heritage dans le delai de 10 jours, sur une
-- mecanique que la consigne demande expressement de ne pas modifier encore. Le point est
-- documente dans le rapport avec le predicat a ecrire.
--
-- Ce qui est certain en revanche : un visiteur SANS COMPTE n'a aucun acces IG a une succession.
REVOKE ALL ON public.successions FROM anon;