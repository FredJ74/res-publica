-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine politique et elections -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.candidatures (
  id text NOT NULL,
  country text,
  poste_id text,
  nom text,
  programme text,
  archetype text,
  created_at timestamp with time zone DEFAULT now(),
  city text,
  topic_id text
);

CREATE TABLE public.cycles_electoraux (
  id text NOT NULL,
  country text,
  poste_id text,
  data text,
  updated_at timestamp with time zone DEFAULT now(),
  city text
);

CREATE TABLE public.demandes_manifestation (
  id text NOT NULL,
  statut text DEFAULT 'attente'::text,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.elections_tracts_pnj (
  id bigserial NOT NULL,
  cycle_id text NOT NULL,
  tour bigint NOT NULL,
  pnj_cle text NOT NULL,
  pnj_nom text NOT NULL,
  candidat text NOT NULL,
  sens smallint NOT NULL,
  effet smallint NOT NULL,
  joueur text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  canal text DEFAULT 'tract'::text NOT NULL
);

CREATE TABLE public.fraudes_electorales (
  id text NOT NULL,
  country text NOT NULL,
  poste_id text NOT NULL,
  city text,
  cycle_debut bigint NOT NULL,
  type text NOT NULL,
  auteur text NOT NULL,
  candidat text NOT NULL,
  delta_voix integer NOT NULL,
  etat text DEFAULT 'non_revelee'::text NOT NULL,
  detectabilite_pct integer NOT NULL,
  revelee_par text,
  revelee_le timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.greves_generales (
  id text NOT NULL,
  country text NOT NULL,
  statut text DEFAULT 'consultation'::text NOT NULL,
  initiateur text NOT NULL,
  syndicat_initiateur_id text NOT NULL,
  revendications text NOT NULL,
  forum_topic_id text,
  participants jsonb DEFAULT '[]'::jsonb NOT NULL,
  date_lancement timestamp with time zone DEFAULT now() NOT NULL,
  date_entree_vigueur timestamp with time zone,
  jours_actifs integer DEFAULT 0 NOT NULL,
  derniere_application_jour text,
  puissance_niveau integer,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.indices_villes (
  id text NOT NULL,
  data jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.mandats_maires_archives (
  id text NOT NULL,
  country text NOT NULL,
  city text NOT NULL,
  maire text NOT NULL,
  est_pj boolean DEFAULT true NOT NULL,
  debut_ts timestamp with time zone NOT NULL,
  fin_ts timestamp with time zone NOT NULL,
  indicateurs_debut jsonb,
  indicateurs_fin jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.militants_recrutes (
  id text NOT NULL,
  country text NOT NULL,
  recruteur text NOT NULL,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.rp_epoques (
  pays text NOT NULL,
  jour_un date NOT NULL,
  note text
);

CREATE TABLE public.rp_transitions (
  cle text NOT NULL,
  actif boolean DEFAULT true NOT NULL,
  note text,
  pose_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.votes_confiance (
  id text NOT NULL,
  country text NOT NULL,
  pm_nom text NOT NULL,
  jour_lancement integer,
  jour_cloture integer,
  statut text DEFAULT 'en_cours'::text NOT NULL,
  resultat text,
  created_at timestamp with time zone DEFAULT now(),
  cloture_ts timestamp with time zone,
  bulletins jsonb DEFAULT '{}'::jsonb NOT NULL,
  demission_limite_ts timestamp with time zone,
  demission_ts timestamp with time zone,
  consequence_appliquee boolean DEFAULT false NOT NULL
);

CREATE TABLE public.votes_confiance_bulletins (
  id text NOT NULL,
  vote_id text NOT NULL,
  votant text NOT NULL,
  choix text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.votes_electoraux (
  id text NOT NULL,
  country text,
  poste_id text,
  votant text,
  candidat text,
  created_at timestamp with time zone DEFAULT now(),
  city text
);
