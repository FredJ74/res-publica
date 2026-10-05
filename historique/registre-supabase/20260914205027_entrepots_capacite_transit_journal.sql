-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914205027
-- Nom original      : entrepots_capacite_transit_journal
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-14 20:50:27 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 7cedeec5995d936c13c5ac141d1362db
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
-- =====================================================================
-- ENTREPOTS DE REPUBLIA — FONDATIONS DU SYSTEME DE GESTION (14 septembre 2026)
-- =====================================================================
-- CAPACITE. Le plafond d'entrepot passe a 5 000 unites par ressource. Il ne remplace PAS
-- ressources_economie.plafond, qui reste la capacite des USINES, le denominateur du prix
-- dynamique de la vente directe, et surtout la base du contrat d'exportation
-- (plafond x equivalentVilles = 225 cereales / 125 viande). Confondre les deux ferait passer
-- l'export a 7 500 et 5 000 unites par nuit. Une fonction dediee, une seule source.
CREATE OR REPLACE FUNCTION public.capacite_entrepot()
RETURNS integer LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$ SELECT 5000; $$;

-- ---------------------------------------------------------------------
-- TRANSIT : marchandises payees, en route, pas encore livrees
-- ---------------------------------------------------------------------
-- Une ligne = une commande ferme. Elle est creee au moment du paiement et supprimee par le
-- cron le jour de l'arrivee. Elle est donc a la fois la trace du transit et la file de
-- livraison -- pas de second registre a tenir synchronise.
CREATE TABLE IF NOT EXISTS public.entrepot_transits (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  destination_id   text NOT NULL,              -- batiments_etat.id de l'entrepot destinataire
  ressource        text NOT NULL,
  quantite         integer NOT NULL CHECK (quantite > 0),
  origine_type     text NOT NULL,              -- 'entrepot' | 'port' | 'etranger'
  origine_id       text,                       -- batiments_etat.id du fournisseur, si interne
  origine_libelle  text NOT NULL,
  prix_unitaire    numeric NOT NULL CHECK (prix_unitaire >= 0),
  fret_unitaire    numeric NOT NULL DEFAULT 0 CHECK (fret_unitaire >= 0),
  montant_total    numeric NOT NULL CHECK (montant_total >= 0),
  arrivee_le       date NOT NULL,              -- jour ou le cron doit livrer
  commande_par     text,
  cree_le          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_transits_destination ON public.entrepot_transits (destination_id, ressource);
CREATE INDEX IF NOT EXISTS idx_transits_arrivee ON public.entrepot_transits (arrivee_le);

-- ---------------------------------------------------------------------
-- JOURNAL : historique commercial de l'etablissement
-- ---------------------------------------------------------------------
-- Appartient au BATIMENT, jamais au directeur : les directeurs successifs lisent le meme
-- registre. Volontairement plat et minimal -- pas de photographie du marche, seulement les
-- operations reelles.
CREATE TABLE IF NOT EXISTS public.entrepot_journal (
  id            bigserial PRIMARY KEY,
  entrepot_id   text NOT NULL,                 -- batiments_etat.id de l'etablissement concerne
  horodatage    timestamptz NOT NULL DEFAULT now(),
  jour          date NOT NULL DEFAULT (now() AT TIME ZONE 'utc')::date,
  operation     text NOT NULL,                 -- commande_directe | approvisionnement_auto | exportation | vente_directeur | vente_comptoir
  sens          text NOT NULL CHECK (sens IN ('entree', 'sortie')),
  contrepartie  text,                          -- fournisseur ou acheteur, libelle affichable
  ressource     text,
  quantite      numeric,
  prix_unitaire numeric,
  fret_unitaire numeric,
  montant       numeric,
  statut        text,                          -- 'en_transit' | 'livre' | 'comptant'
  arrivee_le    date,
  acteur        text                           -- qui a declenche, si une personne l'a fait
);
CREATE INDEX IF NOT EXISTS idx_journal_entrepot ON public.entrepot_journal (entrepot_id, horodatage DESC);

-- ---------------------------------------------------------------------
-- DROITS : lecture ouverte (le marche est public), ecriture serveur uniquement
-- ---------------------------------------------------------------------
-- Piege deja rencontre six fois sur ce chantier : ALTER DEFAULT PRIVILEGES accorde tout a anon.
ALTER TABLE public.entrepot_transits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entrepot_journal  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.entrepot_transits FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.entrepot_journal  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.entrepot_transits TO anon, authenticated;
GRANT SELECT ON public.entrepot_journal  TO anon, authenticated;

DROP POLICY IF EXISTS transits_lecture ON public.entrepot_transits;
CREATE POLICY transits_lecture ON public.entrepot_transits FOR SELECT USING (true);
DROP POLICY IF EXISTS journal_lecture ON public.entrepot_journal;
CREATE POLICY journal_lecture ON public.entrepot_journal FOR SELECT USING (true);

REVOKE ALL ON FUNCTION public.capacite_entrepot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.capacite_entrepot() TO authenticated;
