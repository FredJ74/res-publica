-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913123446
-- Nom original      : chantier_b_fermeture_tables_serveur_seul
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 12:34:46 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 618f1449010e51f199d75dc133ae69e1
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
-- ============================================================================
-- CHANTIER B — CATEGORIE E : TABLES STRICTEMENT SERVEUR
-- 14 septembre 2026. PREMIERE FERMETURE REELLE, volontairement la plus sure.
-- ============================================================================
-- CRITERE D'INCLUSION, verifie fichier par fichier : le client de jeu n'ecrit
-- JAMAIS dans ces tables, et les seules fonctions qui les touchent sont
-- SECURITY DEFINER (elles s'executent sous le proprietaire et traversent donc
-- RLS). Le cron, lui, est passe sous service_role au commit 82b77a2 : il n'est
-- pas concerne non plus.
--
-- RAPPEL DE L'ETAT ANTERIEUR : ces tables avaient RLS DESACTIVE. Leurs eventuelles
-- policies etaient donc purement decoratives -- Postgres ne les evalue pas quand
-- RLS est off. N'importe quel navigateur pouvait y ecrire avec la cle anon
-- publique. Activer RLS suffit a les fermer : sans policy, anon n'a plus rien.

-- 1) Fermeture complete : ni lecture ni ecriture pour le client.
--    Registres internes de la Banque Helvetia, historique des compromis,
--    fiscalite du Journal (table vide, jamais branchee) et la table de prets
--    legacy, remplacee depuis longtemps par 'prets' (0 ligne, 0 reference).
ALTER TABLE public.biens_saisis_helvetia        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bnr_refinancements_helvetia  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.obligations_helvetia         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compromis_historique         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fiscalite_journal            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prets_bancaires              ENABLE ROW LEVEL SECURITY;

-- prets_bancaires portait une policy 'ALL / true / true' devenue active avec
-- RLS : on la retire, sinon activer RLS n'aurait strictement rien ferme.
DROP POLICY IF EXISTS allow_all_prets_bancaires ON public.prets_bancaires;

-- 2) Lecture publique conservee, ecriture serveur seule. Le jeu LIT ces deux
--    tables (archives de mandat affichees a l'Hotel de Ville, placements
--    hérités) mais ne les ecrit jamais.
ALTER TABLE public.mandats_maires_archives ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS mandats_maires_archives_lecture ON public.mandats_maires_archives;
CREATE POLICY mandats_maires_archives_lecture ON public.mandats_maires_archives
  FOR SELECT TO anon, authenticated USING (true);

ALTER TABLE public.investissements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS investissements_lecture ON public.investissements;
CREATE POLICY investissements_lecture ON public.investissements
  FOR SELECT TO anon, authenticated USING (true);

-- 3) locations_archives avait deja RLS, mais avec une policy d'INSERTION
--    publique dont aucun appelant client n'existe : seul terminer_bail
--    (SECURITY DEFINER) y ecrit. On retire l'ecriture, on garde la lecture.
DROP POLICY IF EXISTS locations_archives_insert ON public.locations_archives;

-- 4) nominations_poste_attente : aucune reference cote client ni cote cron.
--    On retire la policy 'ALL' et on conserve une lecture publique, au cas ou
--    un ecran l'afficherait par un chemin non detecte.
DROP POLICY IF EXISTS allow_all_nominations_poste_attente ON public.nominations_poste_attente;
DROP POLICY IF EXISTS nominations_poste_attente_lecture ON public.nominations_poste_attente;
CREATE POLICY nominations_poste_attente_lecture ON public.nominations_poste_attente
  FOR SELECT TO anon, authenticated USING (true);