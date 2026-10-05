-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine militaire -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.armureries_dotations (
  pays text NOT NULL,
  caisse numeric DEFAULT 0 NOT NULL,
  stock_matieres jsonb DEFAULT '{}'::jsonb NOT NULL,
  parametres jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE public.batailles (
  id bigserial NOT NULL,
  pays text NOT NULL,
  ville text,
  batiment text,
  piece text,
  debut_ts timestamp with time zone DEFAULT now() NOT NULL,
  fin_ts timestamp with time zone,
  issue text,
  resume text,
  chronique_id bigint,
  statut text DEFAULT 'en_cours'::text NOT NULL,
  round_courant integer DEFAULT 0 NOT NULL,
  camp_a text,
  camp_b text,
  effectif_initial_a integer,
  effectif_initial_b integer,
  initiative text,
  decision_a text,
  decision_b text,
  doctrine_a text DEFAULT 'tenir'::text NOT NULL,
  doctrine_b text DEFAULT 'tenir'::text NOT NULL,
  leader_a text,
  leader_b text,
  repli_a jsonb,
  repli_b jsonb,
  contact_id bigint,
  termine_raison text
);

CREATE TABLE public.batailles_engagements (
  id bigserial NOT NULL,
  bataille_id bigint NOT NULL,
  camp text NOT NULL,
  personnage text,
  compagnie_id text,
  section_id text,
  matricule text,
  grade text,
  etat_final text,
  pa_initial integer,
  saute_round integer,
  sorti_round integer,
  groupe_id text
);

CREATE TABLE public.batailles_groupes (
  bataille_id bigint NOT NULL,
  groupe_id text NOT NULL,
  camp text NOT NULL,
  compagnie_id text,
  section_id text,
  leader text,
  effectif_initial integer NOT NULL,
  decision text,
  attente_depuis timestamp with time zone,
  repli jsonb,
  sorti_round integer
);

CREATE TABLE public.batailles_rounds (
  id bigserial NOT NULL,
  bataille_id bigint NOT NULL,
  numero integer NOT NULL,
  camp text NOT NULL,
  rapport jsonb NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.camions_destinations (
  pays text NOT NULL,
  cle text NOT NULL,
  ville text NOT NULL,
  building_id text NOT NULL,
  room_id text NOT NULL,
  libelle text NOT NULL,
  rang integer DEFAULT 0 NOT NULL
);

CREATE TABLE public.camions_embarquements (
  camion_id text NOT NULL,
  personnage text NOT NULL,
  monte_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.camions_militaires (
  id text NOT NULL,
  pays text NOT NULL,
  institution text DEFAULT 'militaire'::text NOT NULL,
  perimetre text,
  libelle text NOT NULL,
  capacite integer DEFAULT 25 NOT NULL,
  image_url text,
  caserne_ville text NOT NULL,
  caserne_building text NOT NULL,
  caserne_room text NOT NULL,
  caserne_libelle text NOT NULL,
  ville text NOT NULL,
  building_id text NOT NULL,
  room_id text NOT NULL,
  statut text DEFAULT 'actif'::text NOT NULL,
  maj_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.camions_ordres (
  requete text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  camion_id text NOT NULL,
  acteur text NOT NULL,
  action text NOT NULL,
  destination text,
  resultat jsonb NOT NULL
);

CREATE TABLE public.candidatures_militaires (
  id text NOT NULL,
  pays text NOT NULL,
  candidat text NOT NULL,
  grade_vise text NOT NULL,
  statut text DEFAULT 'active'::text NOT NULL,
  refus jsonb DEFAULT '[]'::jsonb NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  derniere_relance timestamp with time zone,
  accepte_par text,
  accepte_le timestamp with time zone,
  echeance timestamp with time zone,
  compagnie_id text,
  section_id text,
  finalise_le timestamp with time zone
);

CREATE TABLE public.commandes_militaires (
  id text NOT NULL,
  pays text NOT NULL,
  produit text NOT NULL,
  quantite_demandee integer NOT NULL,
  quantite_produite integer DEFAULT 0 NOT NULL,
  statut text DEFAULT 'en_cours'::text NOT NULL,
  ministre text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.compagnies_militaires (
  id text NOT NULL,
  data jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.contacts_militaires (
  id bigserial NOT NULL,
  pays_a text NOT NULL,
  pays_b text NOT NULL,
  ville text,
  batiment text,
  piece text,
  effectif_a integer,
  effectif_b integer,
  etabli_le timestamp with time zone DEFAULT now() NOT NULL,
  consomme_le timestamp with time zone,
  bataille_id bigint
);

CREATE TABLE public.decorations_militaires (
  id bigserial NOT NULL,
  decore text NOT NULL,
  pays text NOT NULL,
  niveau text NOT NULL,
  intitule text NOT NULL,
  citation text,
  decerne_par text NOT NULL,
  poste_decernant text NOT NULL,
  decerne_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.engagements_militaires (
  id text NOT NULL,
  statut text DEFAULT 'attente_commandant'::text,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.guerres (
  id text NOT NULL,
  statut text DEFAULT 'active'::text,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.militaire_armes_bonus (
  cle text NOT NULL,
  mode text NOT NULL,
  bonus integer NOT NULL,
  note text
);

CREATE TABLE public.militaire_detections (
  id text NOT NULL,
  personnage text NOT NULL,
  jour text NOT NULL,
  zone text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.militaire_terminal_requetes (
  requete text NOT NULL,
  acteur text NOT NULL,
  action text NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.mutineries (
  camp text NOT NULL,
  pays text NOT NULL,
  fondateur text NOT NULL,
  compagnie_id text,
  section_id text,
  statut text DEFAULT 'active'::text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.mutineries_membres (
  camp text NOT NULL,
  personnage text NOT NULL,
  role_origine text,
  statut text DEFAULT 'actif'::text NOT NULL,
  rejoint_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.nominations_militaires (
  id text NOT NULL,
  pays text NOT NULL,
  grade text NOT NULL,
  compagnie_id text NOT NULL,
  section_id text,
  destinataire text NOT NULL,
  par text NOT NULL,
  traitee boolean DEFAULT false NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.retraits_materiel_militaire (
  id bigserial NOT NULL,
  pays text NOT NULL,
  materiel text NOT NULL,
  lot text,
  quantite integer NOT NULL,
  lieutenant text NOT NULL,
  section text,
  jour integer,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.services_militaires (
  id bigserial NOT NULL,
  personnage text NOT NULL,
  pays text NOT NULL,
  grade text NOT NULL,
  compagnie_id text,
  section_id text,
  debut_ts timestamp with time zone DEFAULT now() NOT NULL,
  fin_ts timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.soldes_militaires (
  id text NOT NULL,
  personnage text NOT NULL,
  pays text NOT NULL,
  grade text NOT NULL,
  jour date NOT NULL,
  du integer NOT NULL,
  verse integer DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  regle_le timestamp with time zone
);
