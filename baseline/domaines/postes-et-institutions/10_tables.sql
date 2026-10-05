-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine postes et institutions -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.nominations_en_attente (
  id text NOT NULL,
  country text NOT NULL,
  poste_id text NOT NULL,
  city text,
  destinataire text NOT NULL,
  par text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  traitee boolean DEFAULT false NOT NULL
);

CREATE TABLE public.nominations_poste_attente (
  id text NOT NULL,
  destinataire text NOT NULL,
  poste_id text NOT NULL,
  poste_name text NOT NULL,
  country text NOT NULL,
  traite boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.postes_attribues (
  id text NOT NULL,
  country text NOT NULL,
  poste_id text NOT NULL,
  city text,
  titulaire text NOT NULL,
  depuis timestamp with time zone DEFAULT now() NOT NULL,
  source text NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.postes_electifs_regles (
  poste_id text NOT NULL,
  nom text NOT NULL,
  scope text NOT NULL,
  niveau text NOT NULL,
  min_inf integer DEFAULT 0 NOT NULL,
  nb_par_ville integer
);

CREATE TABLE public.postes_nommes_regles (
  poste_id text NOT NULL,
  label text NOT NULL,
  nomme_par text,
  scope text NOT NULL,
  autorite_scope text
);

CREATE TABLE public.postes_nommes_regles_empreinte (
  seul boolean DEFAULT true NOT NULL,
  empreinte text NOT NULL,
  pose_le timestamp with time zone DEFAULT now()
);

CREATE TABLE public.titulaires_pnj (
  id text NOT NULL,
  country text,
  poste_id text,
  city text,
  nom_pnj text,
  updated_at timestamp with time zone DEFAULT now()
);
