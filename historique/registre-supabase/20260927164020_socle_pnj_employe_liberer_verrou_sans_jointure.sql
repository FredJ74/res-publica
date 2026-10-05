-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927164020
-- Nom original      : socle_pnj_employe_liberer_verrou_sans_jointure
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 16:40:20 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e0749b2404ba49f550306e29807bd9d0
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
-- Correctif : `FOR UPDATE` ne s'applique pas au cote nullable d'un LEFT JOIN (0A000). Le verrou
-- porte donc sur pnj_membres seul, et le metier se lit ensuite, sans verrou -- il n'en a pas besoin,
-- il ne sert qu'a renseigner le retour.
CREATE OR REPLACE FUNCTION public.employe_liberer(p_pnj_id text, p_motif text DEFAULT 'licenciement')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_m record; v_job text;
BEGIN
  v_moi := CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
  IF NOT public.est_appel_serveur() AND v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_m FROM public.pnj_membres WHERE id = p_pnj_id FOR UPDATE;
  IF v_m.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'employe_introuvable'); END IF;
  IF v_m.famille IS DISTINCT FROM 'employe' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_employe', 'famille', v_m.famille); END IF;
  IF v_moi IS NOT NULL AND v_m.proprietaire_pj IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_votre_employe'); END IF;

  SELECT e.job INTO v_job FROM public.pnj_employes_metier e WHERE e.pnj_id = p_pnj_id;

  IF v_m.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', true, 'deja_parti', true,
      'pnj_id', p_pnj_id, 'metier', v_job); END IF;

  UPDATE public.pnj_membres
     SET statut = 'disparu', leader_pj = NULL, leader_pnj_id = NULL,
         ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL, maj_le = now()
   WHERE id = p_pnj_id;
  RETURN jsonb_build_object('ok', true, 'pnj_id', p_pnj_id, 'metier', v_job, 'motif', p_motif);
END; $$;