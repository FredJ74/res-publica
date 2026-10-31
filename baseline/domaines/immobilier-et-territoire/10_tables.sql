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

CREATE SEQUENCE public."logements_loyers_historique_id_seq" AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 NO CYCLE;

CREATE TABLE public.acquisitions_transactions_internes (
  transaction_id bigint NOT NULL,
  acteur text NOT NULL,
  terrain text,
  ordre text,
  pa integer,
  montant integer
);

CREATE TABLE public.batiments_etat (
  id text NOT NULL,
  country text NOT NULL,
  city text NOT NULL,
  building_id text NOT NULL,
  data jsonb DEFAULT '{}'::jsonb,
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.batiments_fermes (
  id bigint GENERATED ALWAYS AS IDENTITY (SEQUENCE NAME public."batiments_fermes_id_seq" START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 NO CYCLE) NOT NULL,
  pays text NOT NULL,
  ville text NOT NULL,
  batiment_id text NOT NULL,
  jour_fin integer NOT NULL,
  motif text NOT NULL,
  auteur text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  date_fin_universelle date,
  duree_jours integer
);

CREATE TABLE public.bne_annonces (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  pays text NOT NULL,
  auteur text NOT NULL,
  intitule text NOT NULL,
  descriptif text NOT NULL,
  lieu text NOT NULL,
  salaire text NOT NULL,
  presse boolean DEFAULT false NOT NULL,
  statut text DEFAULT 'active'::text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  expire_le timestamp with time zone NOT NULL
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

CREATE TABLE public.locations_recus (
  acteur text NOT NULL,
  requete uuid NOT NULL,
  bail_id text NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.locaux_loyers_referentiel (
  batiment text NOT NULL,
  piece text NOT NULL,
  ville text DEFAULT '*'::text NOT NULL,
  prix integer NOT NULL,
  bonus_pop integer DEFAULT 0 NOT NULL,
  bonus_inf integer DEFAULT 0 NOT NULL,
  bonus_dis integer DEFAULT 0 NOT NULL,
  label text NOT NULL,
  louable boolean DEFAULT true NOT NULL,
  signature_serveur boolean DEFAULT true NOT NULL
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

CREATE TABLE public.logements_loyers_historique (
  id bigint DEFAULT nextval('logements_loyers_historique_id_seq'::regclass) NOT NULL,
  pays text NOT NULL,
  ville text NOT NULL,
  batiment text NOT NULL,
  piece text NOT NULL,
  ancien integer,
  nouveau integer NOT NULL,
  autorite text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.logements_sociaux_historiques (
  pays text NOT NULL,
  ville text NOT NULL,
  batiment text NOT NULL,
  piece text NOT NULL,
  label text NOT NULL,
  type_logement text NOT NULL,
  loyer integer NOT NULL,
  bonus_moral integer DEFAULT 0 NOT NULL,
  bonus_sante integer DEFAULT 0 NOT NULL
);

CREATE TABLE public.logements_sociaux_internes (
  transaction_id bigint NOT NULL,
  bail_id text NOT NULL
);

CREATE TABLE public.permis_depots_recus (
  acteur uuid NOT NULL,
  requete uuid NOT NULL,
  archive text NOT NULL
);

CREATE TABLE public.permis_transactions_internes (
  transaction_id bigint NOT NULL,
  acteur uuid NOT NULL
);

CREATE TABLE public.reservations_salle_reception (
  id text NOT NULL,
  pays_hote text NOT NULL,
  jour integer NOT NULL,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.terrain_acquisitions_recus (
  acteur text NOT NULL,
  requete uuid NOT NULL,
  terrain text,
  action text,
  parametres jsonb,
  resultat jsonb
);

CREATE TABLE public.terrain_actions_recus (
  acteur uuid NOT NULL,
  requete uuid NOT NULL,
  terrain text NOT NULL,
  occupation text NOT NULL,
  action text NOT NULL,
  resultat jsonb NOT NULL
);

CREATE TABLE public.terrain_actions_regles (
  id boolean DEFAULT true NOT NULL,
  data jsonb NOT NULL
);

CREATE TABLE public.terrain_negociations_recus (
  acteur uuid NOT NULL,
  requete uuid NOT NULL,
  terrain text NOT NULL,
  occupation text NOT NULL,
  montant integer NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.terrain_negociations_refus (
  acteur uuid NOT NULL,
  terrain text NOT NULL,
  occupation text NOT NULL,
  montant integer NOT NULL
);

CREATE TABLE public.terrain_visites_actives (
  personnage_id uuid NOT NULL,
  terrain_id text NOT NULL
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

CREATE TABLE public.terrains_referentiel (
  pays text NOT NULL,
  ville text NOT NULL,
  batiment text NOT NULL,
  surface numeric,
  prix_achat numeric
);

CREATE TABLE public.villes (
  pays text NOT NULL,
  ville text NOT NULL,
  nom text NOT NULL,
  est_capitale boolean DEFAULT false NOT NULL,
  rang integer NOT NULL
);

CREATE TABLE public.villes_empreinte (
  seul boolean DEFAULT true NOT NULL,
  empreinte text NOT NULL,
  pose_le timestamp with time zone DEFAULT now() NOT NULL
);

ALTER SEQUENCE public."logements_loyers_historique_id_seq" OWNED BY public."logements_loyers_historique"."id";
