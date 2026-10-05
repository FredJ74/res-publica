-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine renseignement -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.agent_tentatives (
  agent_id text NOT NULL,
  cible text NOT NULL,
  canal text NOT NULL,
  jour_paris date NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.agents_renseignement (
  id text NOT NULL,
  cellule_id text NOT NULL,
  role text NOT NULL,
  vrai_nom text NOT NULL,
  dup integer NOT NULL,
  pays_couverture text NOT NULL,
  nom_couverture text NOT NULL,
  statut text DEFAULT 'actif'::text NOT NULL,
  leader_courant text,
  ville text,
  building_id text,
  room_id text,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  maj_le timestamp with time zone DEFAULT now() NOT NULL,
  detention_id text,
  detenu_depuis timestamp with time zone,
  pays text,
  pnj_id text
);

CREATE TABLE public.cellules_renseignement (
  id text NOT NULL,
  pays_proprietaire text NOT NULL,
  pays_cible text NOT NULL,
  ministre text NOT NULL,
  statut text DEFAULT 'active'::text NOT NULL,
  mode_fin text,
  cout_fr numeric NOT NULL,
  caisse text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  echeance_le timestamp with time zone NOT NULL,
  terminee_le timestamp with time zone
);

CREATE TABLE public.contre_espionnage_tentatives (
  pays text NOT NULL,
  couverture text NOT NULL,
  jour_paris date NOT NULL,
  instructeur text,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.rapports_cellules (
  cellule_id text NOT NULL,
  jour date NOT NULL,
  contenu jsonb NOT NULL,
  nb_faits integer DEFAULT 0 NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.rapports_renseignement (
  id text NOT NULL,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.renseignement_couvertures (
  pays text NOT NULL,
  nom text NOT NULL,
  sexe text
);

CREATE TABLE public.renseignement_identites_reelles (
  role text NOT NULL,
  vrai_nom text NOT NULL,
  dup integer NOT NULL,
  sexe text
);

CREATE TABLE public.renseignements_connus (
  id text NOT NULL,
  titulaire text NOT NULL,
  contenu text NOT NULL,
  cible text,
  categorie text DEFAULT 'autre'::text NOT NULL,
  source text NOT NULL,
  mode_acquisition text NOT NULL,
  fait_objectif_ref text,
  jour_acquisition integer NOT NULL,
  jour_derniere_reactivation integer NOT NULL,
  jour_expiration integer NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  jour_observe date DEFAULT (((now() AT TIME ZONE 'Europe/Paris'::text))::date - 1),
  pays text,
  ville text,
  building_id text,
  room_id text
);
