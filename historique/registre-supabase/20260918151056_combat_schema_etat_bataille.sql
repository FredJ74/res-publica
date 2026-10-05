-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918151056
-- Nom original      : combat_schema_etat_bataille
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 15:10:56 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2b377e3ca574e2569893a0bc155cfde5
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
-- =========================================================================================
-- MOTEUR PHYSIQUE DE COMBAT V1 -- ETAT CANONIQUE D'UNE BATAILLE (19 septembre 2026)
-- =========================================================================================
-- On ETEND les tables posees en phase 2 plutot que d'en creer de nouvelles : `batailles` portait
-- deja le fait, `batailles_engagements` portait deja le roster avec la contrainte « PJ (nom) OU
-- PNJ (matricule), jamais les deux ». C'est exactement le roster dont le moteur a besoin -- en
-- creer un second aurait produit un deuxieme systeme de groupes, ce que le cahier des charges
-- interdit.
--
-- CE QUI N'EST PAS DUPLIQUE, et c'est l'essentiel : les PA restent CANONIQUES. Pour un PJ ils
-- vivent dans personnages_donnees.pa ; pour un PNJ dans sections[].soldats[].pa. Le moteur les
-- lit et les ecrit la, jamais dans une copie de bataille. Idem pour la position, l'inventaire,
-- les accessoires et l'appartenance au groupe (leaderCourant).
ALTER TABLE public.batailles
  ADD COLUMN IF NOT EXISTS statut              text    NOT NULL DEFAULT 'en_cours',
  ADD COLUMN IF NOT EXISTS round_courant       integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS camp_a              text,
  ADD COLUMN IF NOT EXISTS camp_b              text,
  ADD COLUMN IF NOT EXISTS effectif_initial_a  integer,
  ADD COLUMN IF NOT EXISTS effectif_initial_b  integer,
  -- 'a' = A a surpris B (premier round sequentiel) ; 'simultane' = contact mutuel.
  ADD COLUMN IF NOT EXISTS initiative          text,
  ADD COLUMN IF NOT EXISTS decision_a          text,
  ADD COLUMN IF NOT EXISTS decision_b          text,
  -- Doctrine appliquee quand le leader du camp n'est pas la pour decider.
  ADD COLUMN IF NOT EXISTS doctrine_a          text    NOT NULL DEFAULT 'tenir',
  ADD COLUMN IF NOT EXISTS doctrine_b          text    NOT NULL DEFAULT 'tenir',
  ADD COLUMN IF NOT EXISTS leader_a            text,
  ADD COLUMN IF NOT EXISTS leader_b            text,
  -- Position canonique de repli, CAPTUREE A LA CREATION depuis historique_deplacements. NULL
  -- signifie « ce camp ne peut pas se replier » -- on ne lui invente pas une destination.
  ADD COLUMN IF NOT EXISTS repli_a             jsonb,
  ADD COLUMN IF NOT EXISTS repli_b             jsonb,
  ADD COLUMN IF NOT EXISTS contact_id          bigint,
  ADD COLUMN IF NOT EXISTS termine_raison      text;

ALTER TABLE public.batailles
  DROP CONSTRAINT IF EXISTS batailles_statut_valide;
ALTER TABLE public.batailles
  ADD CONSTRAINT batailles_statut_valide CHECK (statut IN ('en_cours', 'terminee'));

-- UNE SEULE BATAILLE EN COURS PAR ZONE. C'est la garde d'idempotence a la creation : deux clics
-- simultanes sur « engager » ne peuvent pas ouvrir deux batailles au meme endroit.
CREATE UNIQUE INDEX IF NOT EXISTS batailles_zone_en_cours_idx
  ON public.batailles (pays, ville, batiment, piece)
  WHERE statut = 'en_cours';

ALTER TABLE public.batailles_engagements
  ADD COLUMN IF NOT EXISTS pa_initial   integer,
  -- Numero du round que ce combattant doit SAUTER (echec critique au round precedent).
  ADD COLUMN IF NOT EXISTS saute_round  integer,
  -- Round auquel il a quitte le combat (mort, neutralise ou replie). NULL = encore dedans.
  ADD COLUMN IF NOT EXISTS sorti_round  integer;

-- Un combattant n'apparait qu'une fois dans une bataille.
CREATE UNIQUE INDEX IF NOT EXISTS batailles_engagements_unicite_pj_idx
  ON public.batailles_engagements (bataille_id, personnage) WHERE personnage IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS batailles_engagements_unicite_pnj_idx
  ON public.batailles_engagements (bataille_id, compagnie_id, section_id, matricule)
  WHERE matricule IS NOT NULL;

-- =========================================================================================
-- RAPPORTS DE ROUND, UNE LIGNE PAR CAMP
-- =========================================================================================
-- Deux lignes par round, une par camp, et chaque camp ne lit QUE la sienne. C'est ce qui garantit
-- structurellement la confidentialite demandee : les pertes adverses sont deja degradees au
-- moment de l'ecriture, et la donnee exacte de l'autre camp n'entre jamais dans la ligne qu'un
-- joueur peut lire. On n'envoie donc rien au navigateur pour le masquer ensuite.
--
-- La cle unique (bataille, numero, camp) est AUSSI la garde d'idempotence du round : deux appels
-- concurrents ne peuvent pas resoudre deux fois le meme round.
CREATE TABLE IF NOT EXISTS public.batailles_rounds (
  id          bigserial PRIMARY KEY,
  bataille_id bigint NOT NULL REFERENCES public.batailles(id) ON DELETE CASCADE,
  numero      integer NOT NULL,
  camp        text NOT NULL,
  rapport     jsonb NOT NULL,
  cree_le     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS batailles_rounds_unicite_idx
  ON public.batailles_rounds (bataille_id, numero, camp);

ALTER TABLE public.batailles_rounds ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.batailles_rounds FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.batailles_rounds_id_seq FROM PUBLIC, anon, authenticated;
-- Lecture par RPC uniquement : la politique de camp est trop fine pour une policy RLS, et la RPC
-- sait quel camp est le lecteur.