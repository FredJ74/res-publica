-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle PNJ -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.pnj_axes_autorite (
  famille text NOT NULL,
  axe text NOT NULL,
  autorite text NOT NULL,
  note text
);

CREATE TABLE public.pnj_candidats_catalogue (
  candidat_id text NOT NULL,
  employeur_id text NOT NULL,
  metier text NOT NULL,
  nom text NOT NULL,
  genre text,
  accroche text,
  portrait text,
  vignette text,
  cadrage text,
  rang integer DEFAULT 0 NOT NULL,
  actif boolean DEFAULT true NOT NULL
);

CREATE TABLE public.pnj_employes_metier (
  pnj_id text NOT NULL,
  job text NOT NULL,
  role_libelle text NOT NULL,
  cout_jour integer DEFAULT 0 NOT NULL,
  genre text,
  photo_url text,
  photo_pos text,
  loyaute integer,
  depuis_jour integer,
  escort_id text,
  candidat_id text
);

CREATE TABLE public.pnj_employeurs (
  employeur_id text NOT NULL,
  pays text NOT NULL,
  nom text NOT NULL,
  caisse_id text,
  proprietaire_pj text,
  actif boolean DEFAULT true NOT NULL,
  note text,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.pnj_evenements (
  id bigserial NOT NULL,
  pnj_id text NOT NULL,
  pnj_nom text NOT NULL,
  famille text NOT NULL,
  type text NOT NULL,
  pays text NOT NULL,
  proprietaire_pj text,
  ville text,
  building_id text,
  room_id text,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  lu_le timestamp with time zone,
  lu_par text,
  proprietaire_institution text,
  proprietaire_perimetre text,
  objets_deposes integer DEFAULT 0 NOT NULL,
  argent_du_defunt numeric DEFAULT 0 NOT NULL
);

CREATE TABLE public.pnj_familles_classes (
  famille text NOT NULL,
  classe text NOT NULL,
  note text
);

CREATE TABLE public.pnj_fonctions (
  fonction text NOT NULL,
  classe_decor text NOT NULL,
  metier_beta boolean DEFAULT false NOT NULL,
  recrutable boolean DEFAULT false NOT NULL,
  role_fonctionnel text NOT NULL,
  note text
);

CREATE TABLE public.pnj_force_publique_metier (
  pnj_id text NOT NULL,
  matricule text NOT NULL,
  type_unite text DEFAULT 'standard'::text NOT NULL,
  maitre_nom text,
  chien_nom text,
  recrute_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.pnj_institutions (
  institution text NOT NULL,
  resolveur text NOT NULL,
  note text
);

CREATE TABLE public.pnj_membres (
  id text NOT NULL,
  famille text NOT NULL,
  nom text NOT NULL,
  pays text NOT NULL,
  proprietaire_pj text,
  leader_pj text,
  leader_pnj_id text,
  ville text,
  building_id text,
  room_id text,
  rue_noeud_id text,
  pa integer DEFAULT 12 NOT NULL,
  liquide numeric DEFAULT 0 NOT NULL,
  statut text DEFAULT 'actif'::text NOT NULL,
  car_ent integer,
  car_cha integer,
  car_dup integer,
  car_int integer,
  car_per integer,
  car_vol integer,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  maj_le timestamp with time zone DEFAULT now() NOT NULL,
  proprietaire_institution text,
  proprietaire_perimetre text,
  classe text
);

CREATE TABLE public.pnj_metiers_profils (
  metier text NOT NULL,
  car_int integer NOT NULL,
  car_cha integer NOT NULL,
  car_vol integer NOT NULL,
  car_per integer NOT NULL,
  car_dup integer NOT NULL,
  car_ent integer NOT NULL,
  note text,
  pa_initial integer,
  cout_initial integer,
  cout_jour integer,
  quota_note text,
  classe text,
  role_libelle text,
  recrutable boolean DEFAULT false NOT NULL,
  quota_par_joueur integer,
  ordre_fn text
);

CREATE TABLE public.pnj_militants_metier (
  pnj_id text NOT NULL,
  organisation_id text NOT NULL,
  grade text DEFAULT 'Militant (PNJ)'::text NOT NULL,
  rejoint_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.pnj_mouvement_individuel (
  famille text NOT NULL,
  autorise boolean NOT NULL,
  raison text NOT NULL,
  note text
);

CREATE TABLE public.pnj_possessions (
  id bigserial NOT NULL,
  pnj_id text NOT NULL,
  objet jsonb NOT NULL,
  exemplaire_unique boolean DEFAULT false NOT NULL,
  depuis timestamp with time zone DEFAULT now() NOT NULL,
  origine text DEFAULT 'socle'::text NOT NULL
);

CREATE TABLE public.pnj_referents (
  referent_id text NOT NULL,
  domaine text NOT NULL,
  pays text NOT NULL
);

CREATE TABLE public.pnj_referents_pedagogie (
  referent_id text NOT NULL,
  joueur text NOT NULL,
  consultations integer DEFAULT 0 NOT NULL,
  premiere_le timestamp with time zone DEFAULT now() NOT NULL,
  derniere_le timestamp with time zone DEFAULT now() NOT NULL,
  sujets jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE public.pnj_referents_sujets_connus (
  referent_id text NOT NULL,
  sujet text NOT NULL,
  libelle text NOT NULL
);

CREATE TABLE public.pnj_social_escort_choisi (
  joueur text NOT NULL,
  escort_id text NOT NULL,
  choisi_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.pnj_social_jalons_regles (
  pnj_id text NOT NULL,
  jalon text NOT NULL,
  min_rencontres integer DEFAULT 1 NOT NULL,
  max_conversations integer,
  rang integer DEFAULT 0 NOT NULL
);

CREATE TABLE public.pnj_social_relations (
  pnj_id text NOT NULL,
  joueur text NOT NULL,
  rencontres integer DEFAULT 0 NOT NULL,
  conversations integer DEFAULT 0 NOT NULL,
  premiere_le timestamp with time zone DEFAULT now() NOT NULL,
  derniere_le timestamp with time zone DEFAULT now() NOT NULL,
  familiarite integer DEFAULT 0 NOT NULL,
  confiance integer DEFAULT 0 NOT NULL,
  jalons jsonb DEFAULT '{}'::jsonb NOT NULL,
  memoire jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE public.pnj_soldats_metier (
  pnj_id text NOT NULL,
  matricule text NOT NULL,
  section_id text,
  en_reserve boolean NOT NULL,
  arme text,
  formation jsonb DEFAULT '{}'::jsonb NOT NULL,
  mutin text,
  dernier_ration text,
  nb_ration integer,
  dernier_bivouac text,
  dernier_sommeil text,
  compagnie_id text
);

CREATE TABLE public.pnj_transitions (
  cle text NOT NULL,
  actif boolean NOT NULL,
  note text
);
