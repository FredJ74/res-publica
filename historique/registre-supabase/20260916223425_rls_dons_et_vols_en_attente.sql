-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916223425
-- Nom original      : rls_dons_et_vols_en_attente
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 22:34:25 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : edc789a5261e63c31c935e3321692599
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
-- LOT 2 (suite) — RLS DE dons_en_attente ET vols_en_attente
-- Les deux tables portaient « allow_all » (role public, ALL, USING true, WITH CHECK true) :
-- n'importe qui, y compris sans session, pouvait inserer une ligne arbitraire, lire les files
-- des autres joueurs, ou marquer traite=true celles d'autrui. Prouve pour dons_en_attente.
--
-- Regle appliquee : chacun ne voit et ne consomme QUE sa propre file ; l'ecriture n'est plus
-- cliente. Les RPC SECURITY DEFINER (don_argent_deposer, naturalisation_traiter) ecrivent en tant
-- que proprietaire de la table et ne sont pas soumises a ces politiques ; le cron passe en
-- service_role et les contourne de meme.

-- ---------- dons_en_attente : plus AUCUNE ecriture cliente ----------
DROP POLICY IF EXISTS "allow_all_dons_en_attente" ON public.dons_en_attente;

CREATE POLICY "dons lecture destinataire" ON public.dons_en_attente
  FOR SELECT TO authenticated
  USING (destinataire = public.mon_personnage());

-- Le destinataire marque son propre don comme traite (sbMarquerDonTraite) ; il ne peut pas
-- changer de destinataire ni de montant au passage (WITH CHECK identique au USING).
CREATE POLICY "dons consommation destinataire" ON public.dons_en_attente
  FOR UPDATE TO authenticated
  USING (destinataire = public.mon_personnage())
  WITH CHECK (destinataire = public.mon_personnage());

-- ---------- vols_en_attente : ecriture attribuable, lecture et consommation par la victime ----
DROP POLICY IF EXISTS "allow_all_vols_en_attente" ON public.vols_en_attente;

CREATE POLICY "vols lecture victime" ON public.vols_en_attente
  FOR SELECT TO authenticated
  USING (victime = public.mon_personnage());

CREATE POLICY "vols consommation victime" ON public.vols_en_attente
  FOR UPDATE TO authenticated
  USING (victime = public.mon_personnage())
  WITH CHECK (victime = public.mon_personnage());

-- Le voleur depose le butin chez la victime : c'est la doctrine existante (le transfert est
-- resolu par le client de la VICTIME, jamais par une ecriture sur sa fiche). On impose seulement
-- que le voleur declare soit bien le personnage du compte connecte : plus de vol anonyme, plus
-- de vol impute a quelqu'un d'autre.
-- RESTE OUVERT ET DOCUMENTE : le MONTANT du butin est encore decide par le navigateur du voleur
-- (jet de des client). Le fermer suppose de porter la resolution du vol cote serveur -- meme
-- famille que les rumeurs et personnage_ajuster_pop_inf.
CREATE POLICY "vols depot par le voleur" ON public.vols_en_attente
  FOR INSERT TO authenticated
  WITH CHECK (voleur = public.mon_personnage());