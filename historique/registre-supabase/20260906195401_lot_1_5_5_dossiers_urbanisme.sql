-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260906195401
-- Nom original      : lot_1_5_5_dossiers_urbanisme
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-06 19:54:01 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 1e80b9b3633b6de48d4d00541058319d
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
CREATE TABLE IF NOT EXISTS dossiers_urbanisme (
  id             text PRIMARY KEY,
  country        text NOT NULL,
  city           text,
  building_id    text,
  numero_dossier text,
  type_evenement text NOT NULL,
  demandeur      text,
  jour           integer,
  libelle        text,
  data           jsonb NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS dossiers_urbanisme_commune_idx ON dossiers_urbanisme (country, city, created_at);
CREATE INDEX IF NOT EXISTS dossiers_urbanisme_numero_idx  ON dossiers_urbanisme (numero_dossier);
CREATE INDEX IF NOT EXISTS dossiers_urbanisme_terrain_idx ON dossiers_urbanisme (country, building_id);

ALTER TABLE dossiers_urbanisme ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dossiers_urbanisme_lecture ON dossiers_urbanisme;
CREATE POLICY dossiers_urbanisme_lecture ON dossiers_urbanisme
  FOR SELECT USING (true);

DROP POLICY IF EXISTS dossiers_urbanisme_insertion ON dossiers_urbanisme;
CREATE POLICY dossiers_urbanisme_insertion ON dossiers_urbanisme
  FOR INSERT WITH CHECK (true);