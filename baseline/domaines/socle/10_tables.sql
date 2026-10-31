-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE SEQUENCE public."inventaire_ecarts_observes_id_seq" AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 NO CYCLE;

CREATE TABLE public.inventaire_actions_recus (
  acteur text NOT NULL,
  requete uuid NOT NULL,
  action text NOT NULL,
  parametres jsonb NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.inventaire_ecarts_observes (
  id bigint DEFAULT nextval('inventaire_ecarts_observes_id_seq'::regclass) NOT NULL,
  acteur text NOT NULL,
  objet jsonb NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.inventaire_livraisons_recues (
  jeton uuid NOT NULL,
  id text NOT NULL,
  destinataire text NOT NULL,
  recue_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.objets_achetables (
  ordre text NOT NULL,
  modele text NOT NULL
);

CREATE TABLE public.objets_modeles (
  id text NOT NULL,
  objet jsonb NOT NULL
);

CREATE TABLE public.objets_trouves_jours (
  acteur text NOT NULL,
  jour date NOT NULL
);

CREATE TABLE public.ordres_generiques (
  fn text NOT NULL,
  taux_reussite integer NOT NULL,
  toujours_reussi boolean DEFAULT false NOT NULL,
  effets jsonb DEFAULT '{}'::jsonb NOT NULL,
  batiments text[] NOT NULL,
  poste_requis text,
  maj_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.rue_noeuds_serveur (
  country text NOT NULL,
  city text NOT NULL,
  noeud text NOT NULL,
  voisins text[] DEFAULT '{}'::text[] NOT NULL
);

CREATE TABLE public.rue_sorties_batiments (
  country text NOT NULL,
  city text NOT NULL,
  noeud text NOT NULL,
  building text NOT NULL
);

ALTER SEQUENCE public."inventaire_ecarts_observes_id_seq" OWNED BY public."inventaire_ecarts_observes"."id";
