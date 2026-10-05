-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913131523
-- Nom original      : chantier_b_rls_detentions
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 13:15:23 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : bd71aa1287d5f0695d2a12753869b691
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
-- CHANTIER B — REGISTRE DES DETENTIONS
-- 13 septembre 2026.
-- ============================================================================
-- ETAT ANTERIEUR : RLS desactive, aucune policy. N'importe quel navigateur
-- pouvait clore la detention de n'importe qui -- ou en inventer une.
--
-- CE QUE LE JEU FAIT REELLEMENT, site par site : la plupart des ecritures
-- concernent SA PROPRE detention -- le flagrant delit s'auto-enregistre
-- (procederArrestation), l'evasion, la requete d'avocat, la rebellion matee et
-- la liberation portent toutes sur le detenu lui-meme. Deux seulement relevent
-- d'un pouvoir sur autrui : la prolongation prononcee par un juge et la grace
-- presidentielle. Les policies suivent exactement ce partage.
--
-- Les deux ecritures institutionnelles passeront par des RPC verifiant le poste
-- de l'appelant ; en attendant, elles echouent proprement plutot que de laisser
-- la porte ouverte a tout le monde. Le cron (service_role) traverse tout : c'est
-- lui qui libere desormais les peines echues (chantier A).
ALTER TABLE public.detentions ENABLE ROW LEVEL SECURITY;

-- Lecture publique : les archives du commissariat, les geoles et la presse s'en
-- servent, et une detention est un fait public.
DROP POLICY IF EXISTS detentions_lecture ON public.detentions;
CREATE POLICY detentions_lecture ON public.detentions
  FOR SELECT TO anon, authenticated USING (true);

-- On ne s'inscrit au registre que pour soi.
DROP POLICY IF EXISTS detentions_ecriture_soi ON public.detentions;
CREATE POLICY detentions_ecriture_soi ON public.detentions
  FOR INSERT TO authenticated WITH CHECK (nom = public.mon_personnage());

-- On ne modifie que SA PROPRE detention (evasion, avocat, transfert, liberation).
DROP POLICY IF EXISTS detentions_maj_soi ON public.detentions;
CREATE POLICY detentions_maj_soi ON public.detentions
  FOR UPDATE TO authenticated
  USING (nom = public.mon_personnage())
  WITH CHECK (nom = public.mon_personnage());

-- Aucune suppression : un registre judiciaire ne s'efface pas.