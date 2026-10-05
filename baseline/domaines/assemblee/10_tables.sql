-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine assemblee -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.assemblee_catalogue_illegal (
  circuit text NOT NULL,
  ref text NOT NULL,
  objet jsonb NOT NULL,
  libelle text NOT NULL
);

CREATE TABLE public.assemblee_categories_interdiction (
  categorie text NOT NULL,
  label text NOT NULL,
  matieres text[] DEFAULT '{}'::text[] NOT NULL,
  types_objet text[] DEFAULT '{}'::text[] NOT NULL,
  sous_types text[] DEFAULT '{}'::text[] NOT NULL
);

CREATE TABLE public.assemblee_indemnites (
  id text NOT NULL,
  personnage text NOT NULL,
  jour date NOT NULL,
  montant integer NOT NULL,
  versee_ts timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.assemblee_intentions (
  id text NOT NULL,
  proposition_id text NOT NULL,
  session_num integer NOT NULL,
  siege_id text NOT NULL,
  intention text NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.assemblee_propositions (
  id text NOT NULL,
  country text DEFAULT 'republic'::text NOT NULL,
  auteur text NOT NULL,
  titre text NOT NULL,
  type text NOT NULL,
  categorie text,
  loi_cible_id text,
  texte_original text NOT NULL,
  amendements jsonb DEFAULT '[]'::jsonb NOT NULL,
  statut text DEFAULT 'debat'::text NOT NULL,
  session_num integer DEFAULT 0 NOT NULL,
  forum_topic_id text,
  depose_ts timestamp with time zone DEFAULT now() NOT NULL,
  eligible_session_ts timestamp with time zone NOT NULL,
  session_ouverte_ts timestamp with time zone,
  cloture_ts timestamp with time zone,
  adoptee_ts timestamp with time zone,
  abrogee_ts timestamp with time zone,
  data jsonb DEFAULT '{}'::jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  appliquee_ts timestamp with time zone,
  appliquee_par text
);

CREATE TABLE public.assemblee_requetes (
  id text NOT NULL,
  personnage text NOT NULL,
  action text NOT NULL,
  resultat jsonb,
  cree_ts timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.assemblee_sanctions_paliers (
  id text NOT NULL,
  proposition_id text NOT NULL,
  country text NOT NULL,
  palier integer NOT NULL,
  echeance_ts timestamp with time zone NOT NULL,
  applique_ts timestamp with time zone DEFAULT now() NOT NULL,
  pop_delta integer NOT NULL,
  titulaires jsonb DEFAULT '[]'::jsonb NOT NULL
);

CREATE TABLE public.assemblee_scrutins (
  id text NOT NULL,
  proposition_id text NOT NULL,
  session_num integer NOT NULL,
  country text DEFAULT 'republic'::text NOT NULL,
  titre text NOT NULL,
  resultat text NOT NULL,
  score_pour integer DEFAULT 0 NOT NULL,
  score_contre integer DEFAULT 0 NOT NULL,
  pour jsonb DEFAULT '[]'::jsonb NOT NULL,
  contre jsonb DEFAULT '[]'::jsonb NOT NULL,
  abstention jsonb DEFAULT '[]'::jsonb NOT NULL,
  non_votants jsonb DEFAULT '[]'::jsonb NOT NULL,
  endormis jsonb DEFAULT '[]'::jsonb NOT NULL,
  cloture_ts timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.assemblee_sieges (
  id text NOT NULL,
  country text DEFAULT 'republic'::text NOT NULL,
  city text NOT NULL,
  rang integer NOT NULL,
  pnj_id text NOT NULL,
  pnj_nom text NOT NULL,
  endormi boolean DEFAULT false NOT NULL,
  endormi_ts timestamp with time zone,
  endormi_par text,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.assemblee_votes (
  id text NOT NULL,
  proposition_id text NOT NULL,
  session_num integer NOT NULL,
  votant text NOT NULL,
  city text NOT NULL,
  choix text NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);
