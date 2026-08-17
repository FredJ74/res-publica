-- Migration requise avant tout test/production du Lot A du chantier "Journal du jour".
--
-- Contexte : nouvelle table, aucune colonne existante a reutiliser. Cree la structure
-- persistante d'une edition quotidienne du Journal, une ligne par (country, date_edition),
-- avec une contrainte d'unicite qui sert directement de verrou anti-duplication (Lot B tentera
-- une insertion de reservation avant tout appel IA -- si la ligne existe deja pour ce couple,
-- l'insertion echoue et aucune generation redondante n'a lieu, sans table de verrou separee).
--
-- Champs "une"/"double_page_centrale"/"page_economie_societe" restent nullable et ne sont PAS
-- remplis par le Lot A (qui ne fait aucune generation IA) -- seuls "faits_sources" et les
-- champs d'identite/statut le seront. Ces trois colonnes existent des maintenant pour eviter un
-- ALTER TABLE supplementaire quand le Lot B/C les remplira, conformement a l'architecture deja
-- validee (rapport de conception du chantier Journal du jour).
--
-- "id" est construit cote application au format "<country>_<date_edition>" (ex.
-- "republic_2026-08-17"), redondant avec la contrainte UNIQUE(country, date_edition) mais
-- pratique comme cle primaire lisible pour les requetes directes -- meme convention que
-- d'autres tables du projet (budgets_municipaux.id = "republic_capitale",
-- batiments_etat.id = "republic_capitale_entrepot-...").
--
-- La cle anon (utilisee par le client ET par les fonctions serveur de ce projet, voir
-- api/cron-minuit.js) n'a pas les privileges DDL necessaires pour executer ceci elle-meme --
-- deja le cas pour toutes les migrations precedentes de ce projet, toujours executees
-- manuellement par Fred dans l'editeur SQL Supabase.

CREATE TABLE IF NOT EXISTS journal_editions (
  id text PRIMARY KEY,
  country text NOT NULL,
  date_edition date NOT NULL,
  statut text NOT NULL DEFAULT 'en_cours' CHECK (statut IN ('en_cours', 'publiee', 'echec')),
  une jsonb,
  double_page_centrale jsonb,
  page_economie_societe jsonb,
  faits_sources jsonb,
  prompt_version text,
  nb_regenerations integer NOT NULL DEFAULT 0,
  validation_erreurs jsonb,
  generated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT journal_editions_country_date_unique UNIQUE (country, date_edition)
);
