-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.actions_tracables (
  id text NOT NULL,
  auteur text NOT NULL,
  cible text,
  type_action text NOT NULL,
  country text NOT NULL,
  city text,
  jour integer NOT NULL,
  jour_expiration integer NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  decouvert boolean DEFAULT false
);

CREATE TABLE public.audience_paroles (
  affaire text NOT NULL,
  personne text NOT NULL,
  accordee_le timestamp with time zone DEFAULT now() NOT NULL,
  accordee_par text NOT NULL,
  retiree_le timestamp with time zone
);

CREATE TABLE public.avocats_barreau (
  nom text NOT NULL,
  pays text NOT NULL,
  tarification text NOT NULL,
  maj_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.defenses_demandes (
  rang bigserial NOT NULL,
  affaire text NOT NULL,
  pays text NOT NULL,
  prevenu text NOT NULL,
  avocat text NOT NULL,
  demande_le timestamp with time zone DEFAULT now() NOT NULL,
  etat text DEFAULT 'en_attente'::text NOT NULL,
  repondu_le timestamp with time zone
);

CREATE TABLE public.demandes_grace (
  id text NOT NULL,
  statut text DEFAULT 'attente'::text,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.detentions (
  id text NOT NULL,
  country text,
  city text,
  nom text,
  raison text,
  jour_debut integer,
  jour_fin integer,
  qhs boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  motifs jsonb,
  jour_affaire integer,
  issue_judiciaire text,
  autorite text,
  ville_condamnation text,
  jour_fin_effective integer,
  mode_fin text,
  reduction_jours integer,
  detention_precedente_id text,
  reliquat_jours integer,
  date_fin_effective timestamp with time zone,
  provenance text
);

CREATE TABLE public.dossiers_auditions (
  id text NOT NULL,
  affaire text NOT NULL,
  pays text NOT NULL,
  ville text,
  personne text NOT NULL,
  declaration text,
  refus boolean DEFAULT false NOT NULL,
  jour_pv integer NOT NULL,
  fait_le timestamp with time zone DEFAULT now() NOT NULL,
  qualite text DEFAULT 'prevenu'::text NOT NULL
);

CREATE TABLE public.dossiers_judiciaires_actes (
  id text NOT NULL,
  affaire text NOT NULL,
  pays text NOT NULL,
  ville text,
  rang integer NOT NULL,
  type text NOT NULL,
  acteur text,
  acteur_poste text,
  qualif_avant text,
  qualif_apres text,
  donnees jsonb,
  fait_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.dossiers_judiciaires_actes_types (
  type text NOT NULL,
  libelle text NOT NULL,
  pose_par text NOT NULL,
  note text
);

CREATE TABLE public.impacts_indices_attente (
  id text NOT NULL,
  victime text NOT NULL,
  indice text NOT NULL,
  delta integer NOT NULL,
  raison text,
  traite boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  palier text
);

CREATE TABLE public.infractions (
  id text NOT NULL,
  libelle text NOT NULL,
  categorie text,
  jours_reference integer NOT NULL,
  amende_reference integer NOT NULL,
  detect_rate integer,
  bareme_propre boolean NOT NULL,
  detectable boolean NOT NULL
);

CREATE TABLE public.infractions_alias (
  alias text NOT NULL,
  canonique text NOT NULL,
  note text NOT NULL
);

CREATE TABLE public.infractions_categories (
  id text NOT NULL,
  libelle text NOT NULL,
  jours_reference integer NOT NULL,
  amende_reference integer NOT NULL
);

CREATE TABLE public.infractions_empreinte (
  seul boolean DEFAULT true NOT NULL,
  empreinte text NOT NULL,
  pose_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.jugements (
  id text NOT NULL,
  country text,
  city text,
  accuse text,
  motif text,
  peine text,
  juge text,
  jour integer,
  executee boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  data jsonb
);

CREATE TABLE public.justice_avocats_commis (
  pays text NOT NULL,
  ville text NOT NULL,
  nom text NOT NULL,
  cha integer NOT NULL
);

CREATE TABLE public.justice_barreau_qualifications (
  qualification text NOT NULL,
  note text
);

CREATE TABLE public.justice_indemnites (
  id text NOT NULL,
  pays text NOT NULL,
  beneficiaire text NOT NULL,
  affaire text,
  jugement text,
  jours_indus integer NOT NULL,
  montant_du integer NOT NULL,
  montant_paye integer DEFAULT 0 NOT NULL,
  porteur text NOT NULL,
  etat text DEFAULT 'due'::text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  regle_le timestamp with time zone,
  rang bigserial NOT NULL
);

CREATE TABLE public.niveaux_prison (
  id text NOT NULL,
  data jsonb,
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.plaintes_en_cours (
  id text NOT NULL,
  country text NOT NULL,
  city text,
  data text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.prisonniers_qhs (
  id text NOT NULL,
  statut text DEFAULT 'detenu'::text,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.rumeurs_actives (
  id text NOT NULL,
  resolu boolean DEFAULT false,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.signalements_police (
  id text NOT NULL,
  pays text NOT NULL,
  ville text NOT NULL,
  building_id text NOT NULL,
  room_id text NOT NULL,
  signaleur text NOT NULL,
  cible text NOT NULL,
  pose_le timestamp with time zone DEFAULT now() NOT NULL,
  echeance timestamp with time zone NOT NULL,
  resolu_le timestamp with time zone,
  issue text
);

CREATE TABLE public.temoins_citations (
  rang bigserial NOT NULL,
  affaire text NOT NULL,
  pays text NOT NULL,
  ville text,
  temoin text NOT NULL,
  cite_par text NOT NULL,
  cite_par_qualite text NOT NULL,
  cite_le timestamp with time zone DEFAULT now() NOT NULL,
  convocation_rang integer DEFAULT 1 NOT NULL,
  echeance_jour integer NOT NULL,
  etat text DEFAULT 'convoquee'::text NOT NULL,
  issue text,
  clos_le timestamp with time zone
);

CREATE TABLE public.vols_en_attente (
  id text NOT NULL,
  victime text NOT NULL,
  voleur text NOT NULL,
  type_butin text NOT NULL,
  montant integer,
  objet_id text,
  traite boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now()
);
