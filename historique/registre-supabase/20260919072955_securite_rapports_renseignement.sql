-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919072955
-- Nom original      : securite_rapports_renseignement
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 07:29:55 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4a35f906a300028d029a24c9b102dc53
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
-- LOT B (19/09/2026) — fermeture d'une faille technique constatee pendant l'audit lecture seule
-- de l'ordre « Lancer une operation de renseignement ».
--
-- Constat mesure sur banc hostile en transaction annulee :
--   * relrowsecurity = false sur rapports_renseignement (les 3 policies « publique » etaient donc
--     inertes, elles ne protegeaient rien) ;
--   * anon disposait de SELECT / INSERT / UPDATE : un visiteur NON AUTHENTIFIE pouvait lire tous
--     les rapports de toutes les nations, en forger, et reecrire le contenu de n'importe lequel
--     (H2 ACCEPTE, H3 1 ligne lue, H4 ACCEPTE).
--   * un joueur authentifie lisait les rapports de TOUTES les nations : sbGetRapportsRenseignement-
--     NonRemontes() fait « select=id,data » sans filtre et trie ensuite dans le navigateur.
--
-- Aucune regle de jeu n'est modifiee : la policy de lecture reproduit exactement le filtre que le
-- client applique deja cote navigateur (data->>'lieutenantNom' = mon personnage). La table est
-- vide (0 ligne) au moment de la migration : aucune donnee existante n'est affectee.
-- L'autorite « seul le Ministre de la Defense declenche l'operation » n'est volontairement PAS
-- posee ici : elle releve de la refonte de game design en attente d'arbitrage.

ALTER TABLE public.rapports_renseignement ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ecriture publique rapports renseignement" ON public.rapports_renseignement;
DROP POLICY IF EXISTS "Lecture publique rapports renseignement"  ON public.rapports_renseignement;
DROP POLICY IF EXISTS "Maj publique rapports renseignement"      ON public.rapports_renseignement;

REVOKE ALL ON public.rapports_renseignement FROM PUBLIC;
REVOKE ALL ON public.rapports_renseignement FROM anon;
GRANT SELECT, INSERT, UPDATE ON public.rapports_renseignement TO authenticated;

-- Lecture : le rapport n'existe que pour son destinataire. Meme perimetre que le filtre client.
CREATE POLICY "rens lecture destinataire" ON public.rapports_renseignement
  FOR SELECT TO authenticated
  USING (data ->> 'lieutenantNom' = public.mon_personnage());

-- Creation : reservee a un acteur authentifie porteur d'un personnage. Le rapport est adresse a
-- un TIERS (le lieutenant), la propriete ne peut donc pas etre exigee ici.
CREATE POLICY "rens creation acteur" ON public.rapports_renseignement
  FOR INSERT TO authenticated
  WITH CHECK (public.mon_personnage() IS NOT NULL);

-- Maj : uniquement son propre rapport (sbMarquerRapportRemonte), et il reste le sien apres coup.
CREATE POLICY "rens maj destinataire" ON public.rapports_renseignement
  FOR UPDATE TO authenticated
  USING      (data ->> 'lieutenantNom' = public.mon_personnage())
  WITH CHECK (data ->> 'lieutenantNom' = public.mon_personnage());
