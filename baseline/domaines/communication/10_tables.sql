-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine communication -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction doit passer par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.chat_piece (
  id text NOT NULL,
  country text NOT NULL,
  city text NOT NULL,
  building_id text NOT NULL,
  room_id text NOT NULL,
  auteur text NOT NULL,
  destinataire text,
  message text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.forum_posts (
  id text NOT NULL,
  topic_id text,
  author text NOT NULL,
  content text NOT NULL,
  time text,
  edited boolean DEFAULT false,
  created_at timestamp without time zone DEFAULT now(),
  author_is_org boolean DEFAULT false,
  author_secret boolean DEFAULT false,
  content_blocks jsonb DEFAULT '[]'::jsonb,
  content_layout jsonb,
  author_real text,
  author_org_id text,
  author_org_icon text
);

CREATE TABLE public.forum_topics (
  id text NOT NULL,
  forum_id text NOT NULL,
  title text NOT NULL,
  author text NOT NULL,
  country text,
  time text,
  views integer DEFAULT 0,
  replies integer DEFAULT 0,
  created_at timestamp without time zone DEFAULT now(),
  last_post_author text,
  last_post_time text,
  author_is_org boolean DEFAULT false,
  author_secret boolean DEFAULT false,
  author_real text,
  author_org_id text,
  author_org_icon text
);

CREATE TABLE public.lectures_chat (
  id text NOT NULL,
  conversation_id text NOT NULL,
  membre text NOT NULL,
  dernier_lu timestamp with time zone NOT NULL
);

CREATE TABLE public.mails (
  id text NOT NULL,
  from_player text NOT NULL,
  to_player text NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  time text,
  read boolean DEFAULT false,
  created_at timestamp without time zone DEFAULT now(),
  archived boolean DEFAULT false,
  from_real text,
  from_org_id text,
  from_org_icon text
);

CREATE TABLE public.mails_envois_systeme (
  id bigserial NOT NULL,
  auteur_reel text,
  expediteur text NOT NULL,
  destinataire text,
  sujet text,
  vu_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.mails_expediteurs_systeme (
  expediteur text NOT NULL,
  note text,
  est_prefixe boolean DEFAULT false NOT NULL,
  postes text[] DEFAULT '{}'::text[] NOT NULL,
  autorise_soi boolean DEFAULT false NOT NULL,
  libre boolean DEFAULT false NOT NULL,
  autorise_vers_titulaire boolean DEFAULT false NOT NULL,
  autorise_vers_conjoint boolean DEFAULT false NOT NULL,
  autorise_vers_destinataire_fret boolean DEFAULT false NOT NULL
);

CREATE TABLE public.messages_chat (
  id text NOT NULL,
  conversation_id text NOT NULL,
  auteur text NOT NULL,
  message text NOT NULL,
  salon boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.salons_chat (
  id text NOT NULL,
  nom text NOT NULL,
  createur text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.salons_membres (
  id text NOT NULL,
  salon_id text NOT NULL,
  membre text NOT NULL
);
