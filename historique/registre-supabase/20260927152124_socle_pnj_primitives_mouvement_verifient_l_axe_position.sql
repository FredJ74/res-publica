-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927152124
-- Nom original      : socle_pnj_primitives_mouvement_verifient_l_axe_position
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 15:21:24 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 82daeb7d8337e01e9560bf1491538cf2
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
-- CLOTURE — LES TROIS PRIMITIVES DE MOUVEMENT VERIFIENT DESORMAIS L'AXE, PAS SEULEMENT LA REGLE
--
-- LA FUITE, exposee par la migration elle-meme. `pnj_prendre`, `pnj_quitter_groupe` et
-- `pnj_transferer` ecrivent leader_pj, ville, building_id et room_id : c'est exactement l'axe
-- `position_leader`. Or elles ne consultaient QUE `pnj_mouvement_individuel_refus`, c'est-a-dire la
-- REGLE DE JEU -- et cette regle est fail-OPEN : elle joint sur la table, donc une famille SANS
-- ligne ne refuse rien. Une famille entrant au socle avec position_leader = 'blob' ou 'institution'
-- et sans ligne de regle aurait donc vu sa position ecrite par le socle alors que le socle n'en est
-- pas autoritaire : une divergence silencieuse, precisement ce que l'architecture par axes existe
-- pour empecher.
--
-- LES DEUX GARDES SONT DISTINCTES ET TOUTES DEUX NECESSAIRES :
--   - l'AXE dit QUI DECIDE. Si ce n'est pas le socle, le socle n'ecrit pas. Etat de migration.
--   - la REGLE DE JEU dit SI C'EST PERMIS. Un soldat ne s'extrait pas de sa section, meme si le
--     socle fait autorite sur sa position. Regle permanente.
-- Les confondre a deja coute un drapeau perime (`soldats_blob_autoritaire`) ; on ne les refond pas.
--
-- AUCUN COMPORTEMENT ACTUEL NE CHANGE : soldat a l'axe au socle, la garde s'ouvre ; douanier et
-- policier sont deja refuses par la regle de jeu, et le sont maintenant aussi par l'axe.
CREATE OR REPLACE FUNCTION public.pnj_axe_position_refus(p_ids text[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_bloque text;
BEGIN
  v_bloque := public.pnj_axe_verrouille(p_ids, 'position_leader');
  IF v_bloque IS NULL THEN RETURN NULL; END IF;
  RETURN jsonb_build_object('raison', 'axe_position_hors_socle', 'pnj', v_bloque,
    'explication', 'La position de cette famille est decidee ailleurs que dans le socle. '
                || 'L''ecrire ici creerait deux verites.');
END; $$;

CREATE OR REPLACE FUNCTION public.pnj_prendre(p_ids text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; r record; v_n integer := 0; v_refus jsonb;
BEGIN
  v_refus := public.pnj_axe_position_refus(p_ids);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false) || v_refus; END IF;
  v_refus := public.pnj_mouvement_individuel_refus(p_ids);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false) || v_refus; END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  FOR r IN SELECT id FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    IF NOT public.pnj_peut_conduire(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'pnj', r.id); END IF;
    IF NOT public.pnj_co_present(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents', 'pnj', r.id); END IF;
    UPDATE public.pnj_membres SET leader_pj = v_moi, leader_pnj_id = NULL,
      ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'pris', v_n);
END; $$;

CREATE OR REPLACE FUNCTION public.pnj_quitter_groupe(p_ids text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; r record; pe record; v_n integer := 0; v_refus jsonb;
BEGIN
  v_refus := public.pnj_axe_position_refus(p_ids);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false) || v_refus; END IF;
  v_refus := public.pnj_mouvement_individuel_refus(p_ids);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false) || v_refus; END IF;
  v_moi := CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
  IF NOT public.est_appel_serveur() AND v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  FOR r IN SELECT id FROM public.pnj_membres WHERE id = ANY(p_ids) FOR UPDATE LOOP
    IF v_moi IS NOT NULL AND NOT public.pnj_peut_conduire(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'pnj', r.id); END IF;
    SELECT * INTO pe FROM public.pnj_position_effective(r.id);
    UPDATE public.pnj_membres
       SET leader_pj = NULL, leader_pnj_id = NULL,
           ville = pe.ville, building_id = pe.building_id, room_id = pe.room_id
     WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'detaches', v_n);
END; $$;

CREATE OR REPLACE FUNCTION public.pnj_transferer(
  p_ids text[], p_dest text, p_dest_est_pnj boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; r record; dv text; db text; dr text; pm record; v_n integer := 0; v_refus jsonb;
BEGIN
  v_refus := public.pnj_axe_position_refus(p_ids);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false) || v_refus; END IF;
  v_refus := public.pnj_mouvement_individuel_refus(p_ids);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false) || v_refus; END IF;
  v_moi := CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
  IF NOT public.est_appel_serveur() AND v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF p_dest_est_pnj THEN
    SELECT ville, building_id, room_id INTO dv, db, dr
      FROM public.pnj_position_effective(p_dest);
    IF NOT EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = p_dest AND statut = 'actif') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;
  ELSE
    SELECT current_city, current_building, current_room INTO dv, db, dr
      FROM public.personnages_donnees WHERE name = p_dest;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;
  END IF;

  FOR r IN SELECT id FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    IF v_moi IS NOT NULL AND NOT public.pnj_peut_conduire(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'pnj', r.id); END IF;
    SELECT * INTO pm FROM public.pnj_position_effective(r.id);
    IF pm.ville IS DISTINCT FROM dv OR pm.building_id IS DISTINCT FROM db
       OR pm.room_id IS DISTINCT FROM dr THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents', 'pnj', r.id); END IF;
    IF p_dest_est_pnj THEN
      UPDATE public.pnj_membres SET leader_pj = NULL, leader_pnj_id = p_dest,
        ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL WHERE id = r.id;
    ELSE
      UPDATE public.pnj_membres SET leader_pnj_id = NULL, leader_pj = p_dest,
        ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL WHERE id = r.id;
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'transferes', v_n, 'nouveau_leader', p_dest);
END; $$;

REVOKE ALL ON FUNCTION public.pnj_axe_position_refus(text[]) FROM authenticated, anon;