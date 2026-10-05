-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913230436
-- Nom original      : chantier_c_fermeture_caisses_batiments
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 23:04:36 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3e746ae78aa0b982b64792b25b071e9c
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
-- CHANTIER C — FERMETURE DE `caisses_batiments` (14 septembre 2026).
--
-- 149 caisses institutionnelles (ministeres, mairies, commissariats, stades, marches, hotels...)
-- etaient ecrites par le navigateur en SOLDE ABSOLU : une lecture HTTP, un calcul local, une
-- ecriture HTTP. 42 sites d'appel en dependaient, a travers trois primitives clientes.
--
-- La primitive serveur atomique existait deja depuis le 12 septembre (caisse_institution_mouvement)
-- mais son propre commentaire disait que les primitives historiques n'y etaient « PAS reroutees ».
-- Elles le sont maintenant, et prennent un DELTA sous verrou. Une variante plafonnee a ete ajoutee
-- pour les versements partiels deliberes du jeu (salaires, virements, subventions).
--
-- La lecture reste ouverte : les soldes institutionnels sont affiches a tout visiteur (budget du
-- ministere, caisse du commissariat...). Le cron ecrit en service_role et n'est pas concerne.
ALTER TABLE public.caisses_batiments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Ecriture publique caisses batiments" ON public.caisses_batiments;
DROP POLICY IF EXISTS "Maj publique caisses batiments" ON public.caisses_batiments;
DROP POLICY IF EXISTS "Lecture publique caisses batiments" ON public.caisses_batiments;
CREATE POLICY "caisses_batiments lecture publique" ON public.caisses_batiments
  FOR SELECT USING (true);

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.caisses_batiments FROM anon, authenticated;
GRANT SELECT ON public.caisses_batiments TO anon, authenticated;
