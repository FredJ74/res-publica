-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine banque -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.biens_saisis_helvetia (
  id text NOT NULL,
  terrain_id text NOT NULL,
  pret_id text NOT NULL,
  country text NOT NULL,
  city text,
  valeur_objective numeric NOT NULL,
  coproprietaire text,
  quote_part_coproprietaire numeric,
  prix_notaire numeric NOT NULL,
  prix_vente_reel numeric,
  statut text DEFAULT 'en_vente'::text NOT NULL,
  date_mise_en_vente timestamp with time zone DEFAULT now() NOT NULL,
  date_vente timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.bnr_refinancements_helvetia (
  id text NOT NULL,
  country text NOT NULL,
  motif text NOT NULL,
  montant numeric NOT NULL,
  taux_courant numeric NOT NULL,
  interets_cumules numeric DEFAULT 0 NOT NULL,
  nb_tranches integer DEFAULT 1 NOT NULL,
  jour_creation timestamp with time zone DEFAULT now() NOT NULL,
  jour_echeance timestamp with time zone NOT NULL,
  statut text DEFAULT 'actif'::text NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.compromis_historique (
  id text NOT NULL,
  country text NOT NULL,
  building_id text NOT NULL,
  demandeur text NOT NULL,
  resultat text NOT NULL,
  detail text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.comptes_bancaires (
  id text NOT NULL,
  personnage text NOT NULL,
  pays text NOT NULL,
  banque text NOT NULL,
  solde numeric DEFAULT 0 NOT NULL,
  ouvert_le timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.obligations_helvetia (
  id text NOT NULL,
  country text NOT NULL,
  beneficiaire text NOT NULL,
  montant_du numeric NOT NULL,
  motif text NOT NULL,
  bien_id text,
  pret_id text,
  destination_type text DEFAULT 'liquide'::text NOT NULL,
  statut text DEFAULT 'due'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.placements_bancaires (
  id text NOT NULL,
  personnage text NOT NULL,
  pays text NOT NULL,
  banque text DEFAULT 'helvetia'::text NOT NULL,
  type text NOT NULL,
  libelle text,
  montant numeric NOT NULL,
  visible_fiscalement boolean DEFAULT true NOT NULL,
  date_placement timestamp with time zone DEFAULT now() NOT NULL,
  prochaine_echeance timestamp with time zone,
  statut text DEFAULT 'actif'::text NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  int_snapshot integer,
  rendement_pct numeric,
  montant_final numeric,
  date_resolution timestamp with time zone,
  ville text
);

CREATE TABLE public.prets (
  id text NOT NULL,
  emprunteur text NOT NULL,
  country text NOT NULL,
  building_id text,
  type_banque text DEFAULT 'nationale'::text,
  type_pret text DEFAULT 'travaux'::text,
  montant_initial numeric NOT NULL,
  montant_restant numeric NOT NULL,
  duree_jours integer NOT NULL,
  mensualite numeric NOT NULL,
  jours_impayes integer DEFAULT 0,
  jour_dernier_prelevement text,
  statut text DEFAULT 'en_cours'::text,
  created_at timestamp with time zone DEFAULT now(),
  bien_cible_id text,
  accord_actif boolean DEFAULT false NOT NULL,
  accord_fin_le timestamp with time zone,
  accord_avertissement_envoye boolean DEFAULT false NOT NULL,
  proposition_en_attente boolean DEFAULT false NOT NULL,
  saisie_financiere_faite boolean DEFAULT false NOT NULL,
  fraude_affaire_id text
);

CREATE TABLE public.prets_bancaires (
  id text NOT NULL,
  emprunteur text NOT NULL,
  country text NOT NULL,
  building_id text NOT NULL,
  montant_initial integer NOT NULL,
  montant_restant integer NOT NULL,
  duree_jours integer NOT NULL,
  mensualite integer NOT NULL,
  jours_impayes integer DEFAULT 0 NOT NULL,
  jour_dernier_prelevement integer,
  statut text DEFAULT 'en_cours'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  type_banque text DEFAULT 'nationale'::text NOT NULL
);
