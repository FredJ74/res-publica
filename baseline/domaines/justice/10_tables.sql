-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.actions_tracables (
  id text NOT NULL,
  auteur text NOT NULL,
  cible text,
  type_action text NOT NULL,
  country text NOT NULL,
  city text,
  jour integer NOT NULL,
  jour_expiration integer NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  decouvert boolean DEFAULT false
);

CREATE TABLE public.demandes_grace (
  id text NOT NULL,
  statut text DEFAULT 'attente'::text,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.detentions (
  id text NOT NULL,
  country text,
  city text,
  nom text,
  raison text,
  jour_debut integer,
  jour_fin integer,
  qhs boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  motifs jsonb,
  jour_affaire integer,
  issue_judiciaire text,
  autorite text,
  ville_condamnation text,
  jour_fin_effective integer,
  mode_fin text,
  reduction_jours integer,
  detention_precedente_id text,
  reliquat_jours integer,
  date_fin_effective timestamp with time zone,
  provenance text
);

CREATE TABLE public.impacts_indices_attente (
  id text NOT NULL,
  victime text NOT NULL,
  indice text NOT NULL,
  delta integer NOT NULL,
  raison text,
  traite boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  palier text
);

CREATE TABLE public.jugements (
  id text NOT NULL,
  country text,
  city text,
  accuse text,
  motif text,
  peine text,
  juge text,
  jour integer,
  executee boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  data jsonb
);

CREATE TABLE public.niveaux_prison (
  id text NOT NULL,
  data jsonb,
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.plaintes_en_cours (
  id text NOT NULL,
  country text NOT NULL,
  city text,
  data text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.prisonniers_qhs (
  id text NOT NULL,
  statut text DEFAULT 'detenu'::text,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.rumeurs_actives (
  id text NOT NULL,
  resolu boolean DEFAULT false,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.vols_en_attente (
  id text NOT NULL,
  victime text NOT NULL,
  voleur text NOT NULL,
  type_butin text NOT NULL,
  montant integer,
  objet_id text,
  traite boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now()
);
