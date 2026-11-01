-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine finances publiques -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE SEQUENCE public."caisses_mouvements_clients_id_seq" AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 NO CYCLE;

CREATE SEQUENCE public."contributions_piete_id_seq" AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 NO CYCLE;

CREATE SEQUENCE public."fonds_credits_uniques_id_seq" AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 NO CYCLE;

CREATE SEQUENCE public."fonds_en_transit_id_seq" AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 NO CYCLE;

CREATE TABLE public.budget_national_champs_regles (
  champ text NOT NULL,
  poste_id text NOT NULL,
  ordre_fn text,
  note text,
  sous_champ text,
  valeur_ouverture jsonb
);

CREATE TABLE public.budgets_clubs (
  id text NOT NULL,
  data jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.budgets_municipaux (
  id text NOT NULL,
  data jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.budgets_nationaux (
  id text NOT NULL,
  data jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.caisses_autorites (
  motif text NOT NULL,
  est_prefixe boolean DEFAULT false NOT NULL,
  postes_debit text[] NOT NULL,
  note text
);

CREATE TABLE public.caisses_batiments (
  id text NOT NULL,
  data jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.caisses_collectives_operations (
  requete text NOT NULL,
  acteur text NOT NULL,
  operation text NOT NULL,
  cible text NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.caisses_mouvements_clients (
  id bigint DEFAULT nextval('caisses_mouvements_clients_id_seq'::regclass) NOT NULL,
  acteur text,
  caisse text NOT NULL,
  delta numeric NOT NULL,
  motif text,
  accepte boolean NOT NULL,
  raison text,
  vu_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.contributions_piete (
  id bigint DEFAULT nextval('contributions_piete_id_seq'::regclass) NOT NULL,
  pays text NOT NULL,
  ville text NOT NULL,
  auteur text NOT NULL,
  quantite integer NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.directions_etablissements (
  pays text NOT NULL,
  poste_id text NOT NULL,
  ville text NOT NULL,
  souscle text NOT NULL,
  building_id text NOT NULL,
  salaire_jour integer NOT NULL
);

CREATE TABLE public.dotations_amorcage_caisses (
  caisse_ref text NOT NULL,
  stockage text NOT NULL,
  pays text NOT NULL,
  cle text NOT NULL,
  solde_avant numeric NOT NULL,
  montant_verse numeric NOT NULL,
  solde_apres numeric NOT NULL,
  caisse_creee boolean DEFAULT false NOT NULL,
  applique_ts timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.fiscalite_journal (
  id text NOT NULL,
  personnage text NOT NULL,
  pays text NOT NULL,
  type text NOT NULL,
  jour date NOT NULL,
  assiette numeric,
  montant numeric NOT NULL,
  detail jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.fonds_credits_sources (
  source text NOT NULL,
  montant numeric,
  part numeric DEFAULT 1 NOT NULL,
  libelle text NOT NULL
);

CREATE TABLE public.fonds_credits_uniques (
  id bigint DEFAULT nextval('fonds_credits_uniques_id_seq'::regclass) NOT NULL,
  acteur text NOT NULL,
  source text NOT NULL,
  reference text NOT NULL,
  ordre text,
  montant numeric NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.fonds_debits (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  acteur text NOT NULL,
  montant numeric NOT NULL,
  preleve_liquide numeric DEFAULT 0 NOT NULL,
  preleve_national numeric DEFAULT 0 NOT NULL,
  debite_le timestamp with time zone DEFAULT now() NOT NULL,
  rembourse_le timestamp with time zone,
  montant_rembourse numeric,
  source_remb text
);

CREATE TABLE public.fonds_en_transit (
  id bigint DEFAULT nextval('fonds_en_transit_id_seq'::regclass) NOT NULL,
  acteur text NOT NULL,
  montant numeric NOT NULL,
  origine text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.pa_bonus_differes (
  source text NOT NULL,
  montant integer NOT NULL
);

CREATE TABLE public.pa_bonus_differes_empreinte (
  seul boolean DEFAULT true NOT NULL,
  empreinte text NOT NULL,
  pose_le timestamp with time zone DEFAULT now()
);

CREATE TABLE public.pa_bonus_hotel (
  building_id text NOT NULL,
  montant integer NOT NULL
);

CREATE TABLE public.pa_credits_sources (
  source text NOT NULL,
  montant integer
);

CREATE TABLE public.pa_credits_uniques (
  acteur text NOT NULL,
  source text NOT NULL,
  reference text NOT NULL,
  montant integer NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.recettes_municipales (
  pays text NOT NULL,
  ville text NOT NULL,
  jour date NOT NULL,
  canal text NOT NULL,
  montant numeric NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.repartitions_budgetaires (
  pays text NOT NULL,
  source text NOT NULL,
  beneficiaire text NOT NULL,
  "__baseline_attribut_supprime_4" integer,
  poste_autorite text NOT NULL,
  rang integer NOT NULL,
  libelle text NOT NULL,
  note text,
  part_numerateur numeric,
  part_denominateur numeric
);

ALTER TABLE public."repartitions_budgetaires" DROP COLUMN "__baseline_attribut_supprime_4";

CREATE TABLE public.repartitions_versements (
  pays text NOT NULL,
  source text NOT NULL,
  beneficiaire text NOT NULL,
  jour date NOT NULL,
  base numeric NOT NULL,
  "__baseline_attribut_supprime_6" integer,
  montant numeric NOT NULL,
  transfere boolean DEFAULT true NOT NULL,
  verse_le timestamp with time zone DEFAULT now() NOT NULL,
  part_numerateur numeric,
  part_denominateur numeric
);

ALTER TABLE public."repartitions_versements" DROP COLUMN "__baseline_attribut_supprime_6";

CREATE TABLE public.salaires_caisses (
  poste_id text NOT NULL,
  motif text NOT NULL,
  par_ville boolean DEFAULT false NOT NULL,
  note text,
  ville_defaut text
);

CREATE TABLE public.salaires_civils_declares (
  cle text NOT NULL,
  categorie text NOT NULL,
  montant integer NOT NULL,
  pays text NOT NULL
);

CREATE TABLE public.salaires_civils_verses (
  id text NOT NULL,
  personnage text NOT NULL,
  jour date NOT NULL,
  origine text NOT NULL,
  cle text NOT NULL,
  montant integer NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.salaires_religieux_declares (
  cle text NOT NULL,
  ville text,
  caisse text NOT NULL,
  montant integer NOT NULL,
  libelle text
);

CREATE TABLE public.salaires_religieux_verses (
  id text NOT NULL,
  personnage text NOT NULL,
  cle text NOT NULL,
  jour date NOT NULL,
  montant numeric NOT NULL,
  verse_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.subventions_entreprises_traces (
  requete text NOT NULL,
  acteur text NOT NULL,
  beneficiaire text NOT NULL,
  proprietaire text,
  montant numeric NOT NULL,
  conflit_interets boolean DEFAULT false NOT NULL,
  pays text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.subventions_familles (
  famille text NOT NULL,
  libelle text NOT NULL,
  registre text NOT NULL,
  eligible boolean DEFAULT false NOT NULL,
  arbitrage text NOT NULL,
  note text
);

CREATE TABLE public.subventions_municipales (
  id text NOT NULL,
  pays text NOT NULL,
  ville text NOT NULL,
  maire text NOT NULL,
  famille text NOT NULL,
  beneficiaire text NOT NULL,
  beneficiaire_nom text NOT NULL,
  montant numeric NOT NULL,
  statut text DEFAULT 'proposee'::text NOT NULL,
  jour integer NOT NULL,
  jour_echeance integer NOT NULL,
  clos_par text,
  clos_le timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER SEQUENCE public."caisses_mouvements_clients_id_seq" OWNED BY public."caisses_mouvements_clients"."id";

ALTER SEQUENCE public."contributions_piete_id_seq" OWNED BY public."contributions_piete"."id";

ALTER SEQUENCE public."fonds_credits_uniques_id_seq" OWNED BY public."fonds_credits_uniques"."id";

ALTER SEQUENCE public."fonds_en_transit_id_seq" OWNED BY public."fonds_en_transit"."id";
