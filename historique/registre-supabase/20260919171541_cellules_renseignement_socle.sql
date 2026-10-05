-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919171541
-- Nom original      : cellules_renseignement_socle
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-19 17:15:41 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 76f1b1344a16b9b116e7a2f39cfad09b
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- SOCLE CANONIQUE DE LA CELLULE DE RENSEIGNEMENT (19 septembre 2026).
--
-- DOCTRINE DE CONFIDENTIALITE : ces deux tables contiennent des SECRETS DE
-- GAMEPLAY (vraie identite d'un agent, pays proprietaire, role reel). Elles
-- suivent donc le patron deja en production sur renseignements_connus,
-- escort_evenements_commerciaux et militaire_detections :
--   RLS ACTIVEE + AUCUNE POLICY = acces refuse par defaut a tout role soumis a
--   RLS, anon et authenticated compris. Seules des fonctions SECURITY DEFINER
--   (et service_role) y accedent. Le client ne recoit JAMAIS la ligne, il
--   recoit une PROJECTION construite par le serveur.
-- C'est la seule protection reelle : encodePnjSafe serialise l'objet PNJ entier
-- dans l'attribut data-enc du DOM, et sbGet part sans `select=`. Tout champ
-- secret pose sur un objet envoye au client serait lisible a l'inspecteur.
--
-- POSITION : aucun second systeme geographique n'est cree. On reprend le
-- CONTRAT a deux etats des soldats PNJ (voir militaire_*) : un agent SUIT un
-- chef (leader_courant renseigne, position vide, position effective derivee du
-- chef) OU il est POSE quelque part (leader_courant vide, position renseignee).
-- Les quatre niveaux de position sont ceux deja canoniques partout ailleurs
-- (pays / ville / building_id / room_id), comme personnages_donnees et
-- objets_abandonnes. Le stockage, lui, reste ici : compagnies_militaires
-- decrit une COMPAGNIE DE L'ARMEE, un agent n'en est pas un.

CREATE TABLE IF NOT EXISTS public.cellules_renseignement (
  id                 text PRIMARY KEY,
  pays_proprietaire  text NOT NULL,
  pays_cible         text NOT NULL,
  ministre           text NOT NULL,          -- le min_def qui a ouvert la cellule
  statut             text NOT NULL DEFAULT 'active'
                       CHECK (statut IN ('active', 'terminee', 'echec')),
  mode_fin           text CHECK (mode_fin IN ('naturelle', 'volontaire', 'echec_agents')),
  cout_fr            numeric NOT NULL,
  caisse             text NOT NULL,          -- caisse institutionnelle reellement debitee
  cree_le            timestamptz NOT NULL DEFAULT now(),
  echeance_le        timestamptz NOT NULL,   -- cree_le + 10 jours REELS
  terminee_le        timestamptz,
  CONSTRAINT cellule_fin_coherente CHECK (
    (statut = 'active'  AND mode_fin IS NULL     AND terminee_le IS NULL) OR
    (statut <> 'active' AND mode_fin IS NOT NULL AND terminee_le IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_cellules_actives
  ON public.cellules_renseignement (pays_proprietaire, echeance_le)
  WHERE statut = 'active';
CREATE INDEX IF NOT EXISTS idx_cellules_echeance
  ON public.cellules_renseignement (echeance_le) WHERE statut = 'active';

CREATE TABLE IF NOT EXISTS public.agents_renseignement (
  id               text PRIMARY KEY,
  cellule_id       text NOT NULL REFERENCES public.cellules_renseignement(id),
  role             text NOT NULL
                     CHECK (role IN ('conseiller', 'traducteur', 'garde', 'coordinateur')),
  vrai_nom         text NOT NULL,            -- SECRET SERVEUR
  dup              integer NOT NULL CHECK (dup BETWEEN 1 AND 20),
  pays_couverture  text NOT NULL,            -- pays ou la couverture est utilisee
  nom_couverture   text NOT NULL,            -- seule identite publique
  statut           text NOT NULL DEFAULT 'actif'
                     CHECK (statut IN ('actif', 'detenu', 'mort', 'disparu')),
  -- Position, contrat a DEUX ETATS (cf. en-tete) :
  leader_courant   text,                     -- suit ce PJ
  ville            text,
  building_id      text,
  room_id          text,
  cree_le          timestamptz NOT NULL DEFAULT now(),
  maj_le           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT agent_position_deux_etats CHECK (
    (leader_courant IS NOT NULL AND ville IS NULL) OR
    (leader_courant IS NULL))
);

-- Exactement quatre agents par cellule, un par role.
CREATE UNIQUE INDEX IF NOT EXISTS idx_agents_role_unique
  ON public.agents_renseignement (cellule_id, role);

-- Une couverture ne peut pas etre portee par deux agents en meme temps dans le
-- meme pays : c'est ce qui fait de nom_couverture une cle de recherche fiable
-- pour l'enquete et pour l'arrestation.
CREATE UNIQUE INDEX IF NOT EXISTS idx_agents_couverture_unique
  ON public.agents_renseignement (pays_couverture, nom_couverture)
  WHERE statut IN ('actif', 'detenu');

CREATE INDEX IF NOT EXISTS idx_agents_cellule   ON public.agents_renseignement (cellule_id);
CREATE INDEX IF NOT EXISTS idx_agents_position  ON public.agents_renseignement (pays_couverture, ville, building_id)
  WHERE statut = 'actif';
CREATE INDEX IF NOT EXISTS idx_agents_leader    ON public.agents_renseignement (leader_courant)
  WHERE leader_courant IS NOT NULL;

-- ---------------------------------------------------------------------------
-- CONTENU DE GAME DESIGN : architecture oui, contenu definitif NON.
--
-- Les vraies identites des trois autres agents ne sont PAS encore definies par
-- le game design, et les pools de noms de couverture non plus. Ces deux tables
-- sont donc creees VIDES (a la seule exception de Raymond Hialiste, validee).
-- La RPC de creation refusera proprement tant qu'elles ne sont pas garnies --
-- elle n'inventera jamais un nom.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.renseignement_identites_reelles (
  role      text PRIMARY KEY
              CHECK (role IN ('conseiller', 'traducteur', 'garde', 'coordinateur')),
  vrai_nom  text NOT NULL,
  dup       integer NOT NULL CHECK (dup BETWEEN 1 AND 20)
);

CREATE TABLE IF NOT EXISTS public.renseignement_couvertures (
  pays  text NOT NULL,
  nom   text NOT NULL,
  PRIMARY KEY (pays, nom)
);

-- Les DUP sont canoniques et arbitrees ; elles vivent cote serveur et ne
-- dependent ni de data.js ni du navigateur.
INSERT INTO public.renseignement_identites_reelles (role, vrai_nom, dup) VALUES
  ('traducteur', 'Raymond Hialiste', 15)
ON CONFLICT (role) DO UPDATE SET vrai_nom = EXCLUDED.vrai_nom, dup = EXCLUDED.dup;

-- RLS + zero policy : rien n'est lisible par le client, jamais.
ALTER TABLE public.cellules_renseignement           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agents_renseignement             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.renseignement_identites_reelles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.renseignement_couvertures        ENABLE ROW LEVEL SECURITY;

-- Ceinture ET bretelles : les DEFAULT PRIVILEGES du schema public accordent
-- arwdDxtm a anon/authenticated sur toute table creee (piege connu du projet).
REVOKE ALL ON public.cellules_renseignement          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.agents_renseignement            FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.renseignement_identites_reelles FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.renseignement_couvertures       FROM PUBLIC, anon, authenticated;
