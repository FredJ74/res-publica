-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine sport -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.championnat (
  id bigint NOT NULL,
  data jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.championnat_tentatives (
  id bigserial NOT NULL,
  au timestamp with time zone DEFAULT now() NOT NULL,
  acteur uuid,
  ligne integer,
  journee integer,
  matchs_revendiques integer,
  semaine_precedente text,
  echeance timestamp with time zone,
  decision text NOT NULL,
  raison text
);

CREATE TABLE public.clubs_football (
  id text NOT NULL,
  nom text NOT NULL,
  pays text NOT NULL,
  ville text NOT NULL
);

CREATE TABLE public.clubs_sportifs_regles (
  club_id text NOT NULL,
  nom text NOT NULL,
  country text NOT NULL,
  city text NOT NULL,
  valeur_base integer NOT NULL
);

CREATE TABLE public.entrainements_football (
  id text NOT NULL,
  personnage text NOT NULL,
  jour integer NOT NULL,
  stat text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.football_primes_versees (
  reference text NOT NULL,
  saison integer,
  journee integer,
  affiche text,
  beneficiaire text NOT NULL,
  club text NOT NULL,
  role text NOT NULL,
  montant integer NOT NULL,
  au timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.paris_sportifs (
  id text NOT NULL,
  resolu boolean DEFAULT false,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.presidents_clubs (
  id text NOT NULL,
  data jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.transferts_clubs (
  id text NOT NULL,
  statut text,
  data jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);
