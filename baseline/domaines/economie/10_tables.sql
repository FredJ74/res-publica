-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine economie -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.apports_matieres (
  requete text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL,
  fonds_id text NOT NULL,
  acteur text NOT NULL,
  matiere text NOT NULL,
  mode text NOT NULL,
  quantite integer NOT NULL,
  prix_unitaire numeric DEFAULT 0 NOT NULL,
  montant numeric DEFAULT 0 NOT NULL
);

CREATE TABLE public.caisses_fret (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  leader text NOT NULL,
  pays_origine text NOT NULL,
  ville_origine text NOT NULL,
  building_origine text NOT NULL,
  destinataire text,
  pays_destination text,
  ville_destination text,
  building_destination text,
  statut text DEFAULT 'ouverte'::text NOT NULL,
  declaration_douaniere text,
  valeur_declaree numeric,
  chargeurs_autorises text[] DEFAULT '{}'::text[] NOT NULL,
  receptionnaires_autorises text[] DEFAULT '{}'::text[] NOT NULL,
  dedouanee boolean DEFAULT false NOT NULL,
  date_dedouanement timestamp with time zone,
  quantite_arrivee integer,
  date_creation timestamp with time zone DEFAULT now() NOT NULL,
  date_fermeture timestamp with time zone,
  date_depart timestamp with time zone,
  date_arrivee_prevue timestamp with time zone,
  date_arrivee_reelle timestamp with time zone,
  date_mise_en_vente timestamp with time zone
);

CREATE TABLE public.catalogue_correspondance_legacy (
  id bigserial NOT NULL,
  motif text NOT NULL,
  valeur text NOT NULL,
  generique_id text NOT NULL,
  variante_id text,
  priorite integer DEFAULT 100 NOT NULL,
  effets_effectifs jsonb,
  source_audit text NOT NULL,
  note text
);

CREATE TABLE public.catalogue_familles (
  id text NOT NULL,
  libelle text NOT NULL
);

CREATE TABLE public.catalogue_generique_type (
  generique_id text NOT NULL,
  type_id text NOT NULL
);

CREATE TABLE public.catalogue_generiques (
  id text NOT NULL,
  libelle text NOT NULL,
  famille_id text NOT NULL,
  regime text DEFAULT 'libre'::text NOT NULL,
  est_service boolean DEFAULT false NOT NULL,
  empilable boolean DEFAULT false NOT NULL,
  individualise boolean DEFAULT false NOT NULL,
  consommable boolean DEFAULT false NOT NULL,
  equipable boolean DEFAULT false NOT NULL,
  encombrement integer,
  effets jsonb,
  capacites jsonb,
  durabilite jsonb,
  conditions jsonb,
  contraintes jsonb,
  note text
);

CREATE TABLE public.catalogue_types (
  id text NOT NULL,
  libelle text NOT NULL,
  ordre integer DEFAULT 0 NOT NULL
);

CREATE TABLE public.catalogue_variantes (
  id text NOT NULL,
  generique_id text NOT NULL,
  cle text NOT NULL,
  libelle text NOT NULL,
  regime text DEFAULT 'reglemente'::text NOT NULL,
  surcharges jsonb,
  capacites jsonb,
  note text
);

CREATE TABLE public.chaines_production_usine (
  produit text NOT NULL,
  ville text NOT NULL,
  building_id text NOT NULL,
  matiere text NOT NULL,
  salaire_pa numeric NOT NULL
);

CREATE TABLE public.chantiers_besoins_jour (
  position_cycle integer NOT NULL,
  bois numeric NOT NULL,
  minerai numeric NOT NULL,
  metal numeric NOT NULL
);

CREATE TABLE public.chantiers_paliers (
  palier text NOT NULL,
  label text DEFAULT ''::text NOT NULL,
  duree_jours numeric NOT NULL,
  cout_total numeric NOT NULL,
  cout_materiaux numeric NOT NULL,
  cout_travail numeric NOT NULL,
  heures_totales numeric NOT NULL,
  apport_minimal numeric NOT NULL,
  gabarit jsonb NOT NULL
);

CREATE TABLE public.commerces_dotations (
  cle text NOT NULL,
  type text NOT NULL,
  caisse numeric DEFAULT 0 NOT NULL,
  stock_matieres jsonb DEFAULT '{}'::jsonb NOT NULL,
  cout_moyen_matieres jsonb DEFAULT '{}'::jsonb NOT NULL,
  carte jsonb DEFAULT '[]'::jsonb NOT NULL,
  parametres jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE public.commerces_types (
  cle text NOT NULL,
  type text NOT NULL
);

CREATE TABLE public.confiscations_douanieres (
  id text NOT NULL,
  personne text NOT NULL,
  objet_nom text NOT NULL,
  objet_type text,
  quantite integer,
  pays text,
  ville text,
  building_id text,
  room_id text,
  reference text NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.contenu_caisses_fret (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  caisse_id uuid NOT NULL,
  deposant text NOT NULL,
  objet jsonb NOT NULL,
  quantite integer NOT NULL,
  date_depot timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.directeurs_usine (
  poste_id text NOT NULL,
  ville text NOT NULL,
  building_id text NOT NULL,
  produits jsonb NOT NULL
);

CREATE TABLE public.entrepot_journal (
  id bigserial NOT NULL,
  entrepot_id text NOT NULL,
  horodatage timestamp with time zone DEFAULT now() NOT NULL,
  jour date DEFAULT ((now() AT TIME ZONE 'utc'::text))::date NOT NULL,
  operation text NOT NULL,
  sens text NOT NULL,
  contrepartie text,
  ressource text,
  quantite numeric,
  prix_unitaire numeric,
  fret_unitaire numeric,
  montant numeric,
  statut text,
  arrivee_le date,
  acteur text
);

CREATE TABLE public.entrepot_transits (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  destination_id text NOT NULL,
  ressource text NOT NULL,
  quantite integer NOT NULL,
  origine_type text NOT NULL,
  origine_id text,
  origine_libelle text NOT NULL,
  prix_unitaire numeric NOT NULL,
  fret_unitaire numeric DEFAULT 0 NOT NULL,
  montant_total numeric NOT NULL,
  arrivee_le date NOT NULL,
  commande_par text,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.entrepots_par_ville (
  ville text NOT NULL,
  building_id text NOT NULL
);

CREATE TABLE public.entrepots_reversements (
  id text NOT NULL,
  entrepot_id text NOT NULL,
  mairie_id text NOT NULL,
  jour date NOT NULL,
  montant numeric NOT NULL,
  mode text NOT NULL,
  acteur text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.entreprises (
  id text NOT NULL,
  data jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.entreprises_constantes (
  cle text NOT NULL,
  valeur numeric NOT NULL
);

CREATE TABLE public.entreprises_prix_rachat (
  batiment text NOT NULL,
  prix numeric NOT NULL
);

CREATE TABLE public.imprimeries_declarees (
  pays text NOT NULL,
  ville text NOT NULL,
  batiment text NOT NULL
);

CREATE TABLE public.investissements (
  id text NOT NULL,
  joueur text NOT NULL,
  pays text,
  ville text,
  montant_initial numeric NOT NULL,
  int_snapshot numeric NOT NULL,
  jour_placement_at timestamp with time zone NOT NULL,
  jour_resolution_at timestamp with time zone NOT NULL,
  statut text DEFAULT 'en_cours'::text NOT NULL,
  rendement_pct numeric,
  montant_final numeric,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.oeuvres (
  id text NOT NULL,
  type text NOT NULL,
  titre text NOT NULL,
  auteur text,
  country text,
  jour integer,
  contenu text,
  data jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.offres (
  id text NOT NULL,
  type text NOT NULL,
  emetteur text NOT NULL,
  destinataire text NOT NULL,
  actif text,
  montant integer DEFAULT 0 NOT NULL,
  statut text DEFAULT 'ouverte'::text NOT NULL,
  data jsonb DEFAULT '{}'::jsonb NOT NULL,
  expire_a timestamp with time zone NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  resolu_a timestamp with time zone
);

CREATE TABLE public.offres_emploi_bne (
  id text NOT NULL,
  job text NOT NULL,
  portee text NOT NULL,
  ville text,
  salaire integer NOT NULL,
  places integer NOT NULL
);

CREATE TABLE public.ordres_couts (
  fn text NOT NULL,
  pa integer NOT NULL,
  cost integer NOT NULL
);

CREATE TABLE public.ordres_couts_ecarts (
  fn text NOT NULL,
  pa integer NOT NULL,
  cost integer NOT NULL,
  occurrences integer DEFAULT 1 NOT NULL,
  vu_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.ordres_couts_empreinte (
  seul boolean DEFAULT true NOT NULL,
  empreinte text NOT NULL,
  pose_le timestamp with time zone DEFAULT now()
);

CREATE TABLE public.ordres_couts_inconnus (
  fn text NOT NULL,
  pa integer,
  cost integer,
  vu_le timestamp with time zone DEFAULT now(),
  occurrences bigint DEFAULT 1
);

CREATE TABLE public.productions_references (
  requete text NOT NULL,
  fonds_id text NOT NULL,
  reference_id text NOT NULL,
  generique_id text NOT NULL,
  recette_id text NOT NULL,
  acteur text NOT NULL,
  quantite integer NOT NULL,
  pa integer NOT NULL,
  matieres jsonb NOT NULL,
  cout_matieres numeric NOT NULL,
  cout_lot numeric NOT NULL,
  cout_unitaire numeric NOT NULL,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.produits_manufactures (
  produit text NOT NULL,
  ville text NOT NULL,
  building_id text NOT NULL,
  recette jsonb NOT NULL,
  pa integer NOT NULL,
  prix_vente numeric NOT NULL,
  encombrement integer NOT NULL,
  generique_id text
);

CREATE TABLE public.recettes_commerce (
  id text NOT NULL,
  source text NOT NULL,
  label text DEFAULT ''::text NOT NULL,
  pa integer DEFAULT 0 NOT NULL,
  portions integer DEFAULT 1 NOT NULL,
  materiaux jsonb DEFAULT '{}'::jsonb NOT NULL,
  prix_fixe numeric,
  categorie text,
  types_autorises jsonb,
  pays_autorises jsonb,
  villes_autorisees jsonb,
  buildings_autorises jsonb,
  effets jsonb,
  stack_key text,
  sous_type text,
  icone text,
  image text,
  description text,
  famille_produit_marche text,
  bonus_integration_ville text,
  generique_id text,
  label_forme text
);

CREATE TABLE public.recettes_production (
  id text NOT NULL,
  ut integer NOT NULL,
  label text DEFAULT ''::text NOT NULL,
  pays text DEFAULT ''::text NOT NULL,
  materiaux jsonb DEFAULT '{}'::jsonb NOT NULL,
  generique_id text
);

CREATE TABLE public.ressources_economie (
  cle text NOT NULL,
  prix_base numeric NOT NULL,
  prix_achat_fournisseur numeric,
  plafond integer,
  source text
);

CREATE TABLE public.ressources_economie_empreinte (
  seul boolean DEFAULT true NOT NULL,
  empreinte text NOT NULL,
  pose_le timestamp with time zone DEFAULT now()
);

CREATE TABLE public.structures_medicales (
  building_id text NOT NULL,
  ressources jsonb NOT NULL,
  financement text NOT NULL,
  categorie_caisse text
);

CREATE TABLE public.usines_rachat_config (
  cle text NOT NULL,
  prix_detail boolean DEFAULT false NOT NULL,
  matieres_hors_chaine jsonb DEFAULT '[]'::jsonb NOT NULL
);

CREATE TABLE public.ventes_snapshots (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  requete text NOT NULL,
  vendu_le timestamp with time zone DEFAULT now() NOT NULL,
  jour_paris text NOT NULL,
  acheteur text NOT NULL,
  vendeur text NOT NULL,
  fonds_id text NOT NULL,
  pays text,
  reference_id text NOT NULL,
  nom_commercial text NOT NULL,
  description_commerciale text,
  generique_id text NOT NULL,
  recette_id text,
  variante_id text,
  famille text,
  types jsonb,
  quantite integer NOT NULL,
  prix_unitaire integer NOT NULL,
  montant_total integer NOT NULL,
  fiche_officielle jsonb NOT NULL
);
