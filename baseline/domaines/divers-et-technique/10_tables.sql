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

CREATE SEQUENCE public."admin_journal_rang_seq" AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 NO CYCLE;

CREATE SEQUENCE public."evenements_globaux_id_seq" AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 NO CYCLE;

CREATE SEQUENCE public."purges_residus_bancs_id_seq" AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 NO CYCLE;

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

CREATE TABLE public.admin_actions_tribunal (
  poste text NOT NULL,
  action text NOT NULL,
  fonction text NOT NULL,
  statuts text[] NOT NULL,
  garde_texte text NOT NULL,
  libelle text NOT NULL,
  ordre integer NOT NULL
);

CREATE TABLE public.admin_journal (
  rang bigint DEFAULT nextval('admin_journal_rang_seq'::regclass) NOT NULL,
  admin_user_id uuid NOT NULL,
  admin_libelle text,
  pnj text,
  poste text,
  affaire text,
  action text NOT NULL,
  parametres jsonb,
  resultat jsonb,
  ok boolean,
  fait_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.administrateurs (
  user_id uuid NOT NULL,
  libelle text NOT NULL,
  actif boolean DEFAULT true NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.administrateurs_invitations (
  email text NOT NULL,
  note text,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  consommee_le timestamp with time zone,
  consommee_par uuid
);

CREATE TABLE public.ambassades_ouvertes (
  id text NOT NULL,
  pays_hote text NOT NULL,
  empire text NOT NULL,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.carrieres (
  id text NOT NULL,
  libelle text NOT NULL,
  ordre integer NOT NULL
);

CREATE TABLE public.carrieres_acquises (
  personnage text NOT NULL,
  carriere text NOT NULL,
  source text DEFAULT 'universite'::text NOT NULL,
  acquise_le timestamp with time zone DEFAULT now() NOT NULL,
  inscription_id text
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
  id bigint DEFAULT nextval('evenements_globaux_id_seq'::regclass) NOT NULL,
  country text NOT NULL,
  city text,
  texte text NOT NULL,
  jour integer,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.habilitations (
  id text NOT NULL,
  libelle text NOT NULL,
  note text
);

CREATE TABLE public.habilitations_carrieres (
  habilitation text NOT NULL,
  carriere text NOT NULL
);

CREATE TABLE public.habilitations_postes (
  poste_id text NOT NULL,
  habilitation text NOT NULL
);

CREATE TABLE public.propositions_diplomatiques (
  id text NOT NULL,
  statut text DEFAULT 'en_attente'::text,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.purges_residus_bancs (
  id bigint DEFAULT nextval('purges_residus_bancs_id_seq'::regclass) NOT NULL,
  table_source text NOT NULL,
  cle text,
  contenu jsonb NOT NULL,
  motif text NOT NULL,
  purge_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.registre_ventes_armes (
  id bigint GENERATED ALWAYS AS IDENTITY (SEQUENCE NAME public."registre_ventes_armes_id_seq" START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 NO CYCLE) NOT NULL,
  joueur text NOT NULL,
  arme text NOT NULL,
  prix integer NOT NULL,
  pays text NOT NULL,
  jour integer NOT NULL,
  heure integer NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  city text
);

CREATE TABLE public.visuels_moderation (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  type_visuel text NOT NULL,
  objet_id text NOT NULL,
  chemin_original text NOT NULL,
  chemin_archive text,
  motif text NOT NULL,
  administrateur_user_id uuid NOT NULL,
  retire_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.visuels_versions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  type_visuel text NOT NULL,
  objet_id text NOT NULL,
  image_path text NOT NULL,
  auteur_user_id uuid,
  action text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

ALTER SEQUENCE public."admin_journal_rang_seq" OWNED BY public."admin_journal"."rang";

ALTER SEQUENCE public."evenements_globaux_id_seq" OWNED BY public."evenements_globaux"."id";

ALTER SEQUENCE public."purges_residus_bancs_id_seq" OWNED BY public."purges_residus_bancs"."id";
