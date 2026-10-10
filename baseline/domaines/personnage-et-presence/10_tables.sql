-- Tables, colonnes, defauts et identites
-- ============================================================================
-- BASELINE Human Gambit -- domaine personnage et presence -- phase 10 : tables
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

CREATE TABLE public.contacts_organisations (
  joueur text NOT NULL,
  passeur text NOT NULL,
  type_organisation text NOT NULL,
  derniere_demande timestamp with time zone DEFAULT now() NOT NULL,
  organisations_contactees jsonb DEFAULT '[]'::jsonb NOT NULL
);

CREATE TABLE public.contacts_organisations_passeurs (
  passeur text NOT NULL,
  type_organisation text NOT NULL,
  pays text NOT NULL,
  expediteur text NOT NULL
);

CREATE TABLE public.demandes_mariage (
  id text NOT NULL,
  demandeur text NOT NULL,
  destinataire text NOT NULL,
  country text NOT NULL,
  statut text DEFAULT 'en_attente'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.demandes_naturalisation (
  id text NOT NULL,
  demandeur text NOT NULL,
  pays_origine text NOT NULL,
  pays_vise text NOT NULL,
  montant integer NOT NULL,
  date_demande bigint NOT NULL,
  date_traitement_possible bigint NOT NULL,
  statut text DEFAULT 'pending'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.dons_en_attente (
  id bigserial NOT NULL,
  destinataire text NOT NULL,
  montant integer NOT NULL,
  expediteur text,
  traite boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.dons_requetes (
  requete text NOT NULL,
  expediteur text NOT NULL,
  destinataire text NOT NULL,
  montant integer NOT NULL,
  don_id bigint,
  cree_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.escort_evenements_commerciaux (
  id text NOT NULL,
  client text NOT NULL,
  escort text NOT NULL,
  type_evenement text NOT NULL,
  jour integer NOT NULL,
  jour_expiration integer NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.escorts_agences (
  pays text NOT NULL,
  nom text NOT NULL
);

CREATE TABLE public.escorts_catalogue (
  escort_id text NOT NULL,
  pays text NOT NULL,
  nom text NOT NULL,
  genre text NOT NULL,
  portrait text NOT NULL,
  vignette text NOT NULL,
  cadrage text DEFAULT '50% 15%'::text NOT NULL,
  rang integer DEFAULT 0 NOT NULL,
  actif boolean DEFAULT true NOT NULL
);

CREATE TABLE public.etat_civil_deces (
  id text NOT NULL,
  nom text NOT NULL,
  country text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  city text
);

CREATE TABLE public.etat_civil_naissances (
  id text NOT NULL,
  nom text NOT NULL,
  country text NOT NULL,
  city text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.fiche_hausses_observees (
  id bigserial NOT NULL,
  personnage text NOT NULL,
  colonne text NOT NULL,
  ancienne numeric,
  nouvelle numeric,
  delta numeric,
  role_sql text,
  requete text,
  vu_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.fiche_inventaire_observe (
  id bigserial NOT NULL,
  personnage text,
  avant integer,
  apres integer,
  delta integer,
  objets_ajoutes jsonb,
  role_sql text,
  requete text,
  vu_le timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.historique_deplacements (
  id bigserial NOT NULL,
  name text,
  country text,
  city text,
  building_id text,
  room_id text,
  jour integer,
  heure text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.invitations_diner (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  inviteur text NOT NULL,
  invite text NOT NULL,
  country text NOT NULL,
  city text NOT NULL,
  building_id text NOT NULL,
  room_id text NOT NULL,
  statut text DEFAULT 'attente'::text NOT NULL,
  cout integer DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  type text DEFAULT 'diner_affaires'::text NOT NULL,
  message text,
  reponse text,
  tournee_id text
);

CREATE TABLE public.mariages (
  id text NOT NULL,
  conjoint1 text NOT NULL,
  conjoint2 text NOT NULL,
  country text NOT NULL,
  statut text DEFAULT 'actif'::text NOT NULL,
  jour_union integer NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  city text,
  dissous_at timestamp with time zone
);

CREATE TABLE public.objets_abandonnes (
  id text NOT NULL,
  country text NOT NULL,
  city text NOT NULL,
  building_id text NOT NULL,
  room_id text NOT NULL,
  data text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.objets_recus (
  id text NOT NULL,
  destinataire text NOT NULL,
  expediteur text NOT NULL,
  data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.organisations (
  id text NOT NULL,
  country_origine text NOT NULL,
  data text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.personnages_donnees (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name text NOT NULL,
  country text NOT NULL,
  archetype text,
  career text,
  stats jsonb,
  resources jsonb,
  arg integer DEFAULT 0,
  liquide integer DEFAULT 0,
  banque integer DEFAULT 0,
  hp integer DEFAULT 100,
  pa integer DEFAULT 10,
  moral integer DEFAULT 75,
  poste jsonb,
  current_city text DEFAULT 'capitale'::text,
  current_building text,
  inventory jsonb DEFAULT '[]'::jsonb,
  informateurs jsonb DEFAULT '[]'::jsonb,
  poison_actif jsonb,
  day integer DEFAULT 1,
  recherche jsonb DEFAULT '[]'::jsonb,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  photo_url text,
  photo_pos text,
  bio text,
  current_room text,
  contacts jsonb DEFAULT '[]'::jsonb,
  historique_crimes jsonb DEFAULT '[]'::jsonb,
  enquetes_en_cours jsonb DEFAULT '[]'::jsonb,
  domicile jsonb,
  employes jsonb DEFAULT '[]'::jsonb,
  locations_actives jsonb DEFAULT '[]'::jsonb,
  dernier_objet_trouve_jour integer,
  convocations jsonb DEFAULT '[]'::jsonb,
  est_emprisonne jsonb,
  motto text,
  signature_html text,
  signature_blocks jsonb DEFAULT '[]'::jsonb,
  licence_sportive jsonb,
  performance_sportive jsonb,
  blessure_sportive jsonb,
  requisition jsonb,
  detention_qhs jsonb,
  dernier_dormir integer,
  salaire_touche boolean DEFAULT false,
  reputation_criminelle integer DEFAULT 0,
  salutations_du_jour jsonb,
  invitation_sociale_en_attente jsonb,
  poste_depute jsonb,
  escort_active jsonb DEFAULT '[]'::jsonb,
  quete_accueil jsonb,
  enigme1 jsonb,
  maxence jsonb,
  succes_maxence jsonb DEFAULT '{}'::jsonb,
  journal jsonb DEFAULT '[]'::jsonb,
  origin text,
  school text,
  free_pts_restants integer DEFAULT 0,
  carte_postale_moral_jour jsonb,
  excommunie jsonb,
  reservation_hotel jsonb,
  qualifications jsonb DEFAULT '[]'::jsonb NOT NULL,
  effets_actifs jsonb DEFAULT '[]'::jsonb NOT NULL,
  demandeur_emploi boolean DEFAULT false NOT NULL,
  bonus_lobbyiste integer DEFAULT 0 NOT NULL,
  hospitalisation jsonb,
  stats_affaiblies jsonb DEFAULT '{}'::jsonb NOT NULL,
  regen_jour integer,
  user_id uuid NOT NULL,
  quete_carriere jsonb,
  bonus_pa_differe integer DEFAULT 0 NOT NULL,
  pa_repos_le date,
  competences_militaires jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE public.personnages_supprimes (
  archive_id bigserial NOT NULL,
  personnage_id uuid,
  nom text,
  user_id uuid,
  ligne jsonb NOT NULL,
  supprime_le timestamp with time zone DEFAULT now() NOT NULL,
  chemin text NOT NULL,
  origine text,
  role_sql text,
  session_sql text,
  jwt_role text,
  jwt_sub text,
  application text,
  client_addr inet,
  backend_pid integer,
  transaction_id text,
  requete text
);

CREATE TABLE public.presences (
  name text NOT NULL,
  country text NOT NULL,
  city text,
  building_id text,
  room_id text,
  updated_at timestamp with time zone DEFAULT now(),
  groupe_pnj jsonb
);

CREATE TABLE public.quetes_actives (
  id text NOT NULL,
  country text NOT NULL,
  titre text NOT NULL,
  description text NOT NULL,
  etape_actuelle integer DEFAULT 1 NOT NULL,
  nb_etapes_total integer NOT NULL,
  building_id text,
  room_id text,
  pnj_actif text,
  recompense_type text,
  recompense_detail text,
  cible_dossier text,
  statut text DEFAULT 'active'::text NOT NULL,
  resolu_par text,
  jour_creation integer NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.reconciliation_fantomes (
  user_id uuid NOT NULL,
  nom_local text NOT NULL,
  empreinte jsonb NOT NULL,
  vu_le timestamp with time zone DEFAULT now() NOT NULL,
  traite boolean DEFAULT false NOT NULL
);

CREATE TABLE public.souvenirs_accueil (
  id text NOT NULL,
  pj_nom text NOT NULL,
  objet_nom text NOT NULL,
  jour_creation integer NOT NULL,
  jour_expiration integer NOT NULL,
  revele boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  jour_tirage date
);

CREATE TABLE public.successions (
  id text NOT NULL,
  defunt text NOT NULL,
  country text NOT NULL,
  testament_id text,
  statut text DEFAULT 'en_attente'::text NOT NULL,
  conjoint text,
  argent_brut_total integer DEFAULT 0 NOT NULL,
  droits_total integer DEFAULT 0 NOT NULL,
  part_etat integer DEFAULT 0 NOT NULL,
  part_notaire integer DEFAULT 0 NOT NULL,
  argent_net_total integer DEFAULT 0 NOT NULL,
  part_etat_reglee boolean DEFAULT false NOT NULL,
  part_notaire_reglee boolean DEFAULT false NOT NULL,
  dispositions jsonb DEFAULT '[]'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  resolved_at timestamp with time zone
);

CREATE TABLE public.testaments (
  id text NOT NULL,
  testateur text NOT NULL,
  country text NOT NULL,
  contenu jsonb DEFAULT '{}'::jsonb NOT NULL,
  statut text DEFAULT 'actif'::text NOT NULL,
  remplace_id text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.tournees (
  id text NOT NULL,
  country text NOT NULL,
  ville text NOT NULL,
  offreur text NOT NULL,
  building_id text NOT NULL,
  room_id text,
  commerce_type text NOT NULL,
  recette_id text NOT NULL,
  prix_unitaire_reference numeric NOT NULL,
  pnj_resultats jsonb,
  statut text DEFAULT 'en_attente'::text NOT NULL,
  pa_debite boolean DEFAULT false NOT NULL,
  resolution_started_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  expires_at timestamp with time zone NOT NULL
);


-- Sequences autonomes (non possedees par une colonne)

CREATE SEQUENCE public.invitations_diner_id_seq;
