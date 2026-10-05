-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917210147
-- Nom original      : objets_recus_fermeture_rls
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-17 21:01:47 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3b67a327d7e0b1c0e0f04e0a9e9e9920
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
-- Fermeture du sas objets_recus. Les producteurs legitimes ont ete migres vers
-- objet_sas_deposer au commit precedent et deployes : aucun flux ne depend plus d'un INSERT client.
--
-- La table et toutes les fonctions productrices appartiennent a postgres, et
-- relforcerowsecurity = false : le proprietaire contourne donc la RLS, et les RPC SECURITY DEFINER
-- (objet_sas_deposer, inventaire_donner, acheter_produit_commerce, tracts_donner_joueur,
-- tracts_reclamer_don, restituer_reliquats_chantier) continuent d'inserer normalement.
ALTER TABLE public.objets_recus ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS objets_recus_lire_le_sien ON public.objets_recus;
DROP POLICY IF EXISTS objets_recus_reclamer_le_sien ON public.objets_recus;

-- Un joueur ne voit que ce qui lui est adresse. mon_personnage() est SECURITY DEFINER : une
-- politique ne doit jamais interroger personnages_donnees directement, sur laquelle le role
-- authenticated n'a aucun droit (elle refuserait alors tout le monde en silence).
CREATE POLICY objets_recus_lire_le_sien ON public.objets_recus
  FOR SELECT TO authenticated
  USING (destinataire = public.mon_personnage());

-- La reclamation (verifierObjetsRecus -> sbSupprimerObjetRecu) ne peut porter que sur sa propre
-- ligne : supprimer celle d'un autre faisait disparaitre un objet en transit.
CREATE POLICY objets_recus_reclamer_le_sien ON public.objets_recus
  FOR DELETE TO authenticated
  USING (destinataire = public.mon_personnage());

-- AUCUNE policy INSERT ni UPDATE : plus aucun client ne depose ni ne modifie directement.

-- Les DEFAULT PRIVILEGES du schema public accordent arwdDxtm a anon/authenticated sur toute
-- nouvelle table -- c'est la cause systemique de cette faille, pas une erreur propre a cette
-- table. On retire donc explicitement ce que la RLS n'a pas a compenser.
REVOKE ALL ON TABLE public.objets_recus FROM anon;
REVOKE INSERT, UPDATE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.objets_recus FROM authenticated;
GRANT SELECT, DELETE ON TABLE public.objets_recus TO authenticated;