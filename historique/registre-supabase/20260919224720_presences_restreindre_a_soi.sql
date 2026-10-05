-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919224720
-- Nom original      : presences_restreindre_a_soi
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 22:47:20 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 1d7c617dc761c1df32f0965f06204f68
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
-- LOT P0-A / INCREMENT 3 — ON NE DEPLACE PLUS LES AUTRES
-- =====================================================================
-- L'AUDIT A DEMONTRE : depuis le compte d'Arnie, Phileas Frogg a ete deplace
-- de la rue centrale de Luthecia vers qhs/qhs-prison/cellule. La table portait
-- une policy allow_all FOR ALL USING(true) WITH CHECK(true) a PUBLIC.
--
-- CE QUI RESTE OUVERT, VOLONTAIREMENT : la LECTURE. Voir qui se trouve dans la
-- piece est une mecanique de jeu, pas une fuite -- c'est ce que sert
-- sbGetPresencesInRoom, filtre sur 5 minutes d'activite.
--
-- LE CHEMIN LEGITIME NE CHANGE PAS : sbUpdatePresence fait un upsert sur SA
-- propre ligne (name est la cle primaire). La policy l'autorise a l'identique.
-- Le journal des deplacements passe deja par la RPC deplacement_enregistrer
-- depuis le 19 septembre et n'est pas concerne.

DROP POLICY IF EXISTS allow_all_presences ON public.presences;

CREATE POLICY presences_lecture_publique ON public.presences
  FOR SELECT USING (true);

CREATE POLICY presences_creation_soi ON public.presences
  FOR INSERT TO authenticated
  WITH CHECK (name = public.mon_personnage());

CREATE POLICY presences_maj_soi ON public.presences
  FOR UPDATE TO authenticated
  USING (name = public.mon_personnage())
  WITH CHECK (name = public.mon_personnage());

CREATE POLICY presences_suppression_soi ON public.presences
  FOR DELETE TO authenticated
  USING (name = public.mon_personnage());

-- anon n'a plus aucune ecriture ici : le jeu exige une session nominative
-- depuis le chantier B, et une presence anonyme n'a pas de sens.
REVOKE INSERT, UPDATE, DELETE ON public.presences FROM anon;