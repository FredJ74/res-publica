-- Migration requise avant tout test/production du chantier "Hotel de Ville / elections"
-- (arbitrages de game design du 4 septembre 2026, implementation le meme jour).
--
-- Trois tables nouvelles, independantes les unes des autres :
--
-- 1. fraudes_electorales -- une ligne PAR ACTE DE FRAUDE (jamais agregee), pour les 3 mecaniques
--    "Falsifier les listes electorales" / "Bourrer les urnes" / "Truquer le depouillement".
--    cycle_debut (= cycles_electoraux.data.dateDebutCandidatures, un timestamp epoch-ms, au
--    moment de la fraude) est la cle stable qui identifie CE scrutin precis a travers les
--    renouvellements de cycles_electoraux (qui ecrase la meme ligne a chaque nouveau cycle) --
--    d'ou le type bigint plutot qu'une reference a une ligne cycles_electoraux qui n'existe plus
--    forcement telle quelle apres coup. detectabilite_pct est fixee UNE FOIS a la commission de
--    la fraude (rang de cette fraude parmi celles du meme type sur ce scrutin), jamais recalculee.
--
-- 2. votes_confiance -- la persistance du vote de confiance N'EXISTAIT NULLE PART AVANT CE
--    CHANTIER (sbCreerVoteConfiance/sbGetVoteConfianceEnCours/sbDeposerBulletinConfiance/
--    sbClorVoteConfiance etaient appelees partout via des gardes "typeof X === 'function'",
--    toujours fausses en l'absence de definition -- la mecanique entiere etait un no-op
--    silencieux). cloture_ts et demission_limite_ts sont des timestamps REELS (jamais state.day,
--    deja documente ailleurs dans ce projet comme un compteur personnel par joueur, inutilisable
--    pour une echeance partagee) : 48h reelles pour le vote, puis 48h reelles de delai de grace
--    avant la consequence POP=0 en cas de censure si le PM reste en poste.
--
-- 3. mandats_maires_archives -- bilan d'un mandat de maire acheve, ecrit uniquement par le cron
--    (api/cron-minuit.js, archiverMandatMaireTermine) au renouvellement naturel d'un mandat
--    echu -- jamais par le client, un bilan de mandat n'etant pas cense etre falsifiable par le
--    joueur qu'il concerne (limite de couverture assumee : une demission anticipee ou une autre
--    sortie de poste hors echeance normale n'est pas archivee par ce lot). indicateurs_debut/fin
--    ne contiennent QUE des indicateurs reellement persistes server-side (taux_impots_locaux et
--    caisse_municipale, lus depuis budgets_municipaux) -- jamais les indices sociaux/economiques
--    locaux, confirmes ailleurs comme un etat ephemere purement client (state.indicesLocaux),
--    jamais partage ni persiste.
--
-- Pas de RLS ici : convention par defaut de ce projet pour les tables de gameplay normales
-- (cycles_electoraux, budgets_municipaux, greves_generales...), la RLS verrouillee etant
-- l'exception reservee aux cas ou une faille d'identite/falsification concrete a ete demontree
-- (voir migration_renseignements_connus.sql, migration_interviews_jodie.sql) -- une RLS
-- verrouillee ici casserait aussi les ecritures/lectures legitimes du CLIENT sur ces trois
-- tables (sbEnregistrerFraudeElectorale, sbCreerVoteConfiance, sbDeposerBulletinConfiance,
-- sbGetArchivesMandatsMaires...), qui utilisent toutes la cle anon partagee -- migrer ces flux
-- vers des endpoints service_role dedies serait un refactor hors perimetre de ce chantier.
--
-- La cle anon n'a pas les privileges DDL necessaires pour executer ceci elle-meme -- a executer
-- manuellement par Fred dans l'editeur SQL Supabase, comme toutes les migrations precedentes.

CREATE TABLE IF NOT EXISTS fraudes_electorales (
  id text PRIMARY KEY,
  country text NOT NULL,
  poste_id text NOT NULL,
  city text,
  cycle_debut bigint NOT NULL,
  type text NOT NULL CHECK (type IN ('falsification_listes', 'bourrage_urnes', 'trucage_depouillement')),
  auteur text NOT NULL,
  candidat text NOT NULL,
  delta_voix integer NOT NULL,
  etat text NOT NULL DEFAULT 'non_revelee' CHECK (etat IN ('non_revelee', 'revelee')),
  detectabilite_pct integer NOT NULL,
  revelee_par text,
  revelee_le timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Filtre exact utilise par sbCompterFraudesParType/sbGetFraudesNonRevelees/chargerFraudesActivesServer.
CREATE INDEX IF NOT EXISTS fraudes_electorales_scrutin_idx
  ON fraudes_electorales (country, poste_id, city, cycle_debut, type);

CREATE TABLE IF NOT EXISTS votes_confiance (
  id text PRIMARY KEY,
  country text NOT NULL,
  pm_nom text NOT NULL,
  cloture_ts timestamptz NOT NULL,
  statut text NOT NULL DEFAULT 'en_cours' CHECK (statut IN ('en_cours', 'termine')),
  resultat text CHECK (resultat IS NULL OR resultat IN ('confiance', 'censure')),
  bulletins jsonb NOT NULL DEFAULT '{}'::jsonb,
  demission_limite_ts timestamptz,
  demission_ts timestamptz,
  consequence_appliquee boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- sbGetVoteConfianceEnCours (client) filtre sur country+statut ; resoudreVotesConfianceEchusServeur
-- et appliquerConsequencesCensureEchues (cron) filtrent sur statut seul (+ resultat/consequence).
CREATE INDEX IF NOT EXISTS votes_confiance_country_statut_idx ON votes_confiance (country, statut);
CREATE INDEX IF NOT EXISTS votes_confiance_statut_idx ON votes_confiance (statut);

CREATE TABLE IF NOT EXISTS mandats_maires_archives (
  id text PRIMARY KEY,
  country text NOT NULL,
  city text NOT NULL,
  maire text NOT NULL,
  est_pj boolean NOT NULL DEFAULT true,
  debut_ts timestamptz NOT NULL,
  fin_ts timestamptz NOT NULL,
  indicateurs_debut jsonb,
  indicateurs_fin jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Ordre de lecture exact de sbGetArchivesMandatsMaires (le plus recent mandat en tete).
CREATE INDEX IF NOT EXISTS mandats_maires_archives_ville_idx
  ON mandats_maires_archives (country, city, debut_ts DESC);
