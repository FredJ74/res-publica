-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927141603
-- Nom original      : socle_pnj_separer_regle_de_jeu_et_etat_de_migration
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 14:16:03 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 322862585d9fc47d813fa33eb90ef426
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
-- LOT 4b — LES QUATRE CONSOMMATEURS APPRENNENT LA DIFFERENCE (27 septembre 2026)
--
-- Les trois verbes de mouvement refusent desormais au nom de la REGLE DE JEU, pas de l'etat de
-- migration : un soldat se deplace par ordre militaire, un agent de la force publique est affecte
-- par son service. Ces refus survivront a la bascule des axes -- ils n'ont jamais decrit ou vivait
-- la donnee.
-- Seul `pnj_pa_debiter` consulte l'AXE, parce que « qui fait autorite sur les PA » est bien une
-- question de migration.
--
-- DEFAUT FERME AU PASSAGE, introduit par le lot 2. Depuis que les douaniers ont une ligne au
-- socle, un Chef des Douanes co-present au port les voyait dans le popup de groupe et pouvait les
-- PRENDRE : il en est l'administrateur, donc `pnj_peut_conduire` disait oui. Rien dans le jeu
-- n'a jamais permis d'embarquer un douanier dans son groupe. L'ancien verrou ne couvrait que la
-- famille soldat et ne pouvait pas l'attraper. La regle de jeu, elle, couvre les trois familles.

CREATE OR REPLACE FUNCTION public.pnj_prendre(p_ids text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; r record; v_n integer := 0; v_refus jsonb;
BEGIN
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

-- Seul consommateur qui lise reellement un AXE : la question « qui fait autorite sur les PA »
-- est une question de migration, pas une regle de jeu.
CREATE OR REPLACE FUNCTION public.pnj_pa_debiter(p_ids text[], p_cout integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; v_morts integer := 0; v_touches integer := 0; v_reste integer;
        v_hors text; v_classe text; v_bloque text;
BEGIN
  v_bloque := public.pnj_axe_verrouille(p_ids, 'pa');
  IF v_bloque IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'axe_pa_hors_socle', 'pnj', v_bloque,
      'explication', 'Les PA de cette famille vivent encore dans son magasin historique : ils y '
                  || 'sont ecrits par les RPC metier et le declencheur met le socle a jour.');
  END IF;
  IF p_cout IS NULL OR p_cout < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_invalide'); END IF;

  SELECT m.id, public.pnj_classe_de(m.id) INTO v_hors, v_classe
    FROM public.pnj_membres m
   WHERE m.id = ANY(p_ids)
     AND COALESCE(public.pnj_classe_de(m.id), '') <> 'alpha'
   LIMIT 1;
  IF v_hors IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'classe_sans_consommation_de_pa',
      'pnj', v_hors, 'classe', COALESCE(v_classe, 'non_declaree'),
      'explication', 'Seule la classe alpha depense ses PA pour agir.');
  END IF;

  FOR r IN SELECT id, pa FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    v_reste := greatest(0, r.pa - p_cout);
    UPDATE public.pnj_membres SET pa = v_reste WHERE id = r.id;
    v_touches := v_touches + 1;
    IF v_reste = 0 THEN PERFORM public.pnj_mourir(r.id); v_morts := v_morts + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'touches', v_touches, 'morts', v_morts);
END; $$;

-- L'ancien verrou n'a plus d'appelant. On le retire plutot que de le laisser dormir : une garde
-- fausse laissee en place finit toujours par etre rappelee par quelqu'un.
DROP FUNCTION IF EXISTS public.pnj_axe_partage_verrouille(text[]);