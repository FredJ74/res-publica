-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine immobilier et territoire -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.batiments_etat (
  id text NOT NULL,
  country text NOT NULL,
  city text NOT NULL,
  building_id text NOT NULL,
  data jsonb DEFAULT '{}'::jsonb,
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.batiments_fermes (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  pays text NOT NULL,
  ville text NOT NULL,
  batiment_id text NOT NULL,
  jour_fin integer NOT NULL,
  motif text NOT NULL,
  auteur text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.dossiers_urbanisme (
  id text NOT NULL,
  country text NOT NULL,
  city text,
  building_id text,
  numero_dossier text,
  type_evenement text NOT NULL,
  demandeur text,
  jour integer,
  libelle text,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.locations_actives (
  id text NOT NULL,
  country text NOT NULL,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.locations_archives (
  id text NOT NULL,
  bail_id text,
  country text,
  city text,
  building_id text,
  room_id text,
  lot_id text,
  locataire text,
  proprietaire_murs text,
  loyer integer DEFAULT 0 NOT NULL,
  debut integer,
  fin_cause text NOT NULL,
  fonds_id text,
  indemnite integer DEFAULT 0 NOT NULL,
  data jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.logements_attributions_historique (
  id text NOT NULL,
  country text NOT NULL,
  ville text NOT NULL,
  room_id text NOT NULL,
  beneficiaire text NOT NULL,
  autorite text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.logements_demandes (
  id text NOT NULL,
  country text NOT NULL,
  ville text NOT NULL,
  demandeur text NOT NULL,
  type_souhaite text,
  statut text DEFAULT 'en_attente'::text NOT NULL,
  room_id_attribue text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.reservations_salle_reception (
  id text NOT NULL,
  pays_hote text NOT NULL,
  jour integer NOT NULL,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.terrains_etat (
  id text NOT NULL,
  country text NOT NULL,
  building_id text NOT NULL,
  proprietaire text,
  data text NOT NULL,
  updated_at timestamp with time zone DEFAULT now(),
  niveau_construction text,
  valeur_totale integer,
  coproprietaire text
);

CREATE TABLE public.terrains_historique_ventes (
  id text NOT NULL,
  country text NOT NULL,
  building_id text NOT NULL,
  proprietaire text NOT NULL,
  prix numeric,
  created_at timestamp with time zone DEFAULT now()
);


-- Sequences autonomes (non possedees par une colonne)

CREATE SEQUENCE public.batiments_fermes_id_seq;
