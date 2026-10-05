-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927015851
-- Nom original      : socle_pnj_rls_sur_les_deux_tables_restantes
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 01:58:51 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 11801d018f16cca8e65f323d1168b690
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
-- RLS SUR LES DEUX TABLES DU SOCLE QUI N'EN AVAIENT PAS (27 septembre 2026)
--
-- Trouve par le mini-audit. `pnj_institutions` (le registre que je viens de creer) et
-- `pnj_transitions` n'avaient pas la RLS activee. L'acces etait DEJA ferme -- l'acces effectif
-- est GRANT et (pas de RLS ou policy permissive), et aucun droit n'a jamais ete accorde a anon
-- ni a authenticated sur ces tables. Il n'y avait donc pas de faille ouverte.
--
-- Mais la doctrine du projet est ceinture ET bretelles, pour une raison precise : le jour ou
-- quelqu'un accordera un GRANT par commodite, la RLS sera la seconde serrure. Sans elle, un seul
-- GRANT distrait ouvrirait la table en grand. Zero policy, donc rien ne passe -- sauf les
-- fonctions SECURITY DEFINER, qui s'executent avec le proprietaire de la table et la contournent
-- comme pour les autres tables du socle.
ALTER TABLE public.pnj_institutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_transitions  ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pnj_institutions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.pnj_transitions  FROM PUBLIC, anon, authenticated;

-- Le vocabulaire des evenements est ramene a ce qui existe reellement : la fonction de trace
-- `disparition_sans_cycle` a ete remplacee par une garde qui REFUSE, donc ce type n'est jamais
-- ecrit. Un mot de vocabulaire sans emetteur finit par etre pris pour un cas gere.
ALTER TABLE public.pnj_evenements DROP CONSTRAINT IF EXISTS pnj_evt_type;
ALTER TABLE public.pnj_evenements ADD CONSTRAINT pnj_evt_type CHECK (type = 'mort');