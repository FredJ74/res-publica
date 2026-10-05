-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine presse -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.calomnies_actes (
  id bigserial NOT NULL,
  auteur text NOT NULL,
  cible text NOT NULL,
  pnj_cle text NOT NULL,
  pnj_nom text NOT NULL,
  jour_paris date NOT NULL,
  resultat text NOT NULL,
  pays_faits text,
  ville_faits text,
  pays_competent text NOT NULL,
  jet smallint,
  taux smallint,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.chronique_nationale (
  id text NOT NULL,
  country text NOT NULL,
  type text NOT NULL,
  city text,
  personnages jsonb,
  libelle text NOT NULL,
  data jsonb,
  source_ref text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.corruptions_presse (
  id bigserial NOT NULL,
  affaire_ref text NOT NULL,
  affaire_type text NOT NULL,
  affaire_pj text NOT NULL,
  corrupteur text NOT NULL,
  option text NOT NULL,
  reussite boolean NOT NULL,
  jet smallint,
  taux smallint,
  pays text,
  jour_paris date NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.fuites_journalistiques (
  id bigserial NOT NULL,
  trace_cle text NOT NULL,
  source text NOT NULL,
  cible text NOT NULL,
  auteur text NOT NULL,
  faits jsonb NOT NULL,
  pays text,
  ville text,
  contenu text,
  chronique_id text,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.groupes_presse (
  id text NOT NULL,
  pays text NOT NULL,
  nom text,
  organisation_id text,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.interviews_jodie (
  id text NOT NULL,
  personnage text NOT NULL,
  country text NOT NULL,
  transcript jsonb DEFAULT '[]'::jsonb NOT NULL,
  publie boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  article_titre text,
  article_texte text,
  article_ville text,
  publie_le timestamp with time zone
);

CREATE TABLE public.journal_articles_en_attente (
  id text NOT NULL,
  country text NOT NULL,
  rubrique text DEFAULT 'Portraits'::text NOT NULL,
  titre text NOT NULL,
  texte text NOT NULL,
  image_url text,
  ville text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  integree_le timestamp with time zone,
  dedup_key text,
  priorite text DEFAULT 'normale'::text,
  expire_le timestamp with time zone,
  statut text DEFAULT 'attente'::text NOT NULL,
  origine text DEFAULT 'ia'::text,
  fait_json jsonb
);

CREATE TABLE public.journal_editions (
  id text NOT NULL,
  country text NOT NULL,
  date_edition date NOT NULL,
  statut text DEFAULT 'en_cours'::text NOT NULL,
  une jsonb,
  double_page_centrale jsonb,
  page_economie_societe jsonb,
  faits_sources jsonb,
  prompt_version text,
  nb_regenerations integer DEFAULT 0 NOT NULL,
  validation_erreurs jsonb,
  generated_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  journal_id text NOT NULL
);

CREATE TABLE public.journaux (
  id text NOT NULL,
  groupe_id text NOT NULL,
  pays text NOT NULL,
  nom text NOT NULL,
  slug text NOT NULL,
  garanti_automatique boolean DEFAULT false NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  cree_par text
);

CREATE TABLE public.journaux_redacteurs (
  journal_id text NOT NULL,
  personnage text NOT NULL,
  accorde_le timestamp with time zone DEFAULT now() NOT NULL,
  accorde_par text
);

CREATE TABLE public.petites_annonces (
  id text NOT NULL,
  country text NOT NULL,
  ville_depot text NOT NULL,
  auteur text NOT NULL,
  categorie text,
  texte text NOT NULL,
  cout_paye numeric DEFAULT 0 NOT NULL,
  duree_jours integer NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  expire_at timestamp with time zone NOT NULL,
  statut text DEFAULT 'active'::text NOT NULL
);

CREATE TABLE public.presse_membres (
  groupe_id text NOT NULL,
  personnage text NOT NULL,
  grade text NOT NULL,
  entre_le timestamp with time zone DEFAULT now() NOT NULL,
  grade_depuis timestamp with time zone DEFAULT now() NOT NULL,
  rang bigserial NOT NULL,
  nomme_par text
);

CREATE TABLE public.scandales_presse (
  id bigserial NOT NULL,
  auteur text NOT NULL,
  cible text NOT NULL,
  pays text,
  ville text,
  accusation text NOT NULL,
  article text,
  chronique_id text,
  type_contenu text DEFAULT 'kompromat'::text NOT NULL,
  statut text DEFAULT 'accepte'::text NOT NULL,
  plainte_ref text,
  effet_applique boolean DEFAULT false NOT NULL,
  jour_paris date NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.scandales_tentatives (
  auteur text NOT NULL,
  jour_paris date NOT NULL,
  cible text,
  accepte boolean DEFAULT false NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.tribune_articles_etouffes (
  id text NOT NULL,
  cible_type text NOT NULL,
  cible_value text NOT NULL,
  cible_label text,
  country text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  expire_le timestamp with time zone NOT NULL
);
