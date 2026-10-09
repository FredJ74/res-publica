-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine divers et technique -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.actes_nocturnes (
  pays text NOT NULL,
  mecanisme text NOT NULL,
  sujet text NOT NULL,
  jour date NOT NULL,
  acquis_le timestamp with time zone DEFAULT now() NOT NULL,
  details jsonb
);

CREATE TABLE public.actes_nocturnes_mecanismes (
  mecanisme text NOT NULL,
  sujet_singleton boolean DEFAULT false NOT NULL,
  note text NOT NULL
);

CREATE TABLE public.ambassades_ouvertes (
  id text NOT NULL,
  pays_hote text NOT NULL,
  empire text NOT NULL,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.cron_journal (
  id text NOT NULL,
  tache text NOT NULL,
  jour date NOT NULL,
  statut text NOT NULL,
  debut timestamp with time zone DEFAULT now() NOT NULL,
  fin timestamp with time zone,
  duree_ms integer,
  erreur text,
  contexte jsonb,
  tentatives integer DEFAULT 1 NOT NULL
);

CREATE TABLE public.etats_urgence (
  country text NOT NULL,
  actif boolean DEFAULT false,
  active_par text,
  jour_debut integer
);

CREATE TABLE public.evenements_globaux (
  id bigserial NOT NULL,
  country text NOT NULL,
  city text,
  texte text NOT NULL,
  jour integer,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.propositions_diplomatiques (
  id text NOT NULL,
  statut text DEFAULT 'en_attente'::text,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.registre_ventes_armes (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  joueur text NOT NULL,
  arme text NOT NULL,
  prix integer NOT NULL,
  pays text NOT NULL,
  jour integer NOT NULL,
  heure integer NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  city text
);


-- Sequences autonomes (non possedees par une colonne)

CREATE SEQUENCE public.registre_ventes_armes_id_seq;
