-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927143135
-- Nom original      : militaire_position_leader_au_socle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 14:31:35 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3af5f767c71d3374dad98abd8f4761e6
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
-- CHECKPOINT A (3/4) — POSITION ET LEADER PASSENT AU SOCLE (27 septembre 2026)
--
-- Les cinq ecrivains ecrivent desormais `pnj_membres`, puis PROJETTENT vers le blob pour que les
-- lectures metier et les dix-huit lectures clientes continuent de dire vrai. Toutes les gardes
-- d'autorite, tous les refus nommes et toutes les formes de reponse sont conserves a l'identique.
--
-- L'ORDRE DE SELECTION. Le blob choisissait les N premiers du TABLEAU. Le socle choisit les N
-- premiers par MATRICULE -- et c'est le meme ensemble : le tableau du blob est construit par
-- matricule croissant depuis la creation de la compagnie. Ce n'est donc pas un choix nouveau,
-- c'est la meme convention, exprimee dans le seul ordre stable dont dispose le socle.
--
-- LE SENTINEL HISTORIQUE `__avec_lieutenant__` disparait de lui-meme : au socle, « avec le
-- Lieutenant » s'ecrit leader_pj = lui, et la contrainte des deux etats interdit d'avoir en meme
-- temps un leader et une piece. Aucun soldat ne le porte aujourd'hui.

CREATE OR REPLACE FUNCTION public.militaire_deposer_soldats(
  p_compagnie_id text, p_section_id text, p_nb integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE g record; v_ville text; v_bat text; v_room text; v_dispo int;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;

  SELECT current_city, current_building, current_room INTO v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;
  IF COALESCE(v_bat,'') = '' OR COALESCE(v_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue');
  END IF;

  SELECT count(*) INTO v_dispo
    FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND m.statut = 'actif' AND m.leader_pj = g.o_moi;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_assez_avec_vous', 'disponibles', v_dispo);
  END IF;

  UPDATE public.pnj_membres
     SET leader_pj = NULL, leader_pnj_id = NULL,
         ville = v_ville, building_id = v_bat, room_id = v_room, maj_le = now()
   WHERE id IN (SELECT m.id FROM public.pnj_membres m
                  JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
                 WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
                   AND m.statut = 'actif' AND m.leader_pj = g.o_moi
                 ORDER BY sm.matricule LIMIT p_nb);
  PERFORM public.militaire_blob_projeter(p_compagnie_id);

  RETURN jsonb_build_object('ok', true, 'deposes', p_nb,
                            'ville', v_ville, 'batiment', v_bat, 'piece', v_room);
END; $$;

CREATE OR REPLACE FUNCTION public.militaire_recuperer_soldats(
  p_compagnie_id text, p_section_id text, p_nb integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE g record; v_ville text; v_bat text; v_room text; v_dispo int;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;

  SELECT current_city, current_building, current_room INTO v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;
  IF COALESCE(v_bat,'') = '' OR COALESCE(v_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue');
  END IF;

  SELECT count(*) INTO v_dispo
    FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND m.statut = 'actif' AND m.leader_pj IS NULL AND m.leader_pnj_id IS NULL
     AND m.ville = v_ville AND m.building_id = v_bat AND m.room_id = v_room;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'effectif_insuffisant_ici', 'disponibles', v_dispo);
  END IF;

  UPDATE public.pnj_membres
     SET leader_pj = g.o_moi, leader_pnj_id = NULL,
         ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL, maj_le = now()
   WHERE id IN (SELECT m.id FROM public.pnj_membres m
                  JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
                 WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
                   AND m.statut = 'actif' AND m.leader_pj IS NULL AND m.leader_pnj_id IS NULL
                   AND m.ville = v_ville AND m.building_id = v_bat AND m.room_id = v_room
                 ORDER BY sm.matricule LIMIT p_nb);
  PERFORM public.militaire_blob_projeter(p_compagnie_id);

  RETURN jsonb_build_object('ok', true, 'recuperes', p_nb, 'leader', g.o_moi);
END; $$;

CREATE OR REPLACE FUNCTION public.militaire_affecter_leader(
  p_compagnie_id text, p_section_id text, p_nb integer, p_leader text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE g record; v_sec jsonb; v_dispo int;
        v_mv text; v_mb text; v_mr text; v_lv text; v_lb text; v_lr text;
        v_pays_l text; v_pays_m text; v_membre boolean;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;
  IF coalesce(btrim(coalesce(p_leader,'')),'') = '' OR p_leader = g.o_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_invalide');
  END IF;

  SELECT current_city, current_building, current_room, country INTO v_mv, v_mb, v_mr, v_pays_m
    FROM public.personnages_donnees WHERE name = g.o_moi;
  SELECT current_city, current_building, current_room, country INTO v_lv, v_lb, v_lr, v_pays_l
    FROM public.personnages_donnees WHERE name = p_leader;
  IF v_pays_l IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_introuvable'); END IF;
  IF v_pays_l IS DISTINCT FROM v_pays_m THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_hors_juridiction'); END IF;
  IF v_lv IS DISTINCT FROM v_mv OR v_lb IS DISTINCT FROM v_mb OR v_lr IS DISTINCT FROM v_mr THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_absent'); END IF;

  -- La cible doit rester un SOLDAT JOUEUR de cette section : donnee METIER, lue dans le blob.
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  SELECT EXISTS (
    SELECT 1 FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
     WHERE coalesce((s->>'pj')::boolean, false) AND s->>'nom' = p_leader
  ) INTO v_membre;
  IF NOT v_membre THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_hors_section'); END IF;

  SELECT count(*) INTO v_dispo
    FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND m.statut = 'actif' AND m.leader_pj = g.o_moi;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_assez_avec_vous', 'disponibles', v_dispo);
  END IF;

  UPDATE public.pnj_membres SET leader_pj = p_leader, maj_le = now()
   WHERE id IN (SELECT m.id FROM public.pnj_membres m
                  JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
                 WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
                   AND m.statut = 'actif' AND m.leader_pj = g.o_moi
                 ORDER BY sm.matricule LIMIT p_nb);
  PERFORM public.militaire_blob_projeter(p_compagnie_id);

  RETURN jsonb_build_object('ok', true, 'affectes', p_nb, 'leader', p_leader);
END; $$;

CREATE OR REPLACE FUNCTION public.militaire_lien_operationnel_rompre(
  p_leader text, p_ville text, p_bat text, p_room text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_total int := 0; v_cie text;
BEGIN
  IF coalesce(btrim(coalesce(p_leader, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_invalide');
  END IF;

  UPDATE public.pnj_membres
     SET leader_pj = NULL, leader_pnj_id = NULL,
         ville = p_ville, building_id = p_bat, room_id = p_room, maj_le = now()
   WHERE famille = 'soldat' AND statut = 'actif' AND leader_pj = p_leader;
  GET DIAGNOSTICS v_total = ROW_COUNT;

  -- Toutes les compagnies concernees sont reprojetees, pas seulement une.
  FOR v_cie IN SELECT DISTINCT sm.compagnie_id FROM public.pnj_soldats_metier sm
                 WHERE sm.compagnie_id IS NOT NULL LOOP
    PERFORM public.militaire_blob_projeter(v_cie);
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'soldats', v_total,
                            'ville', p_ville, 'batiment', p_bat, 'piece', p_room);
END; $$;

CREATE OR REPLACE FUNCTION public.militaire_bataille_decrocher_groupe(
  p_bataille_id bigint, p_groupe_id text, p_round integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; v_repli jsonb; v_n integer := 0; v_cies text[] := '{}'; v_cie text;
BEGIN
  SELECT g.repli INTO v_repli FROM public.batailles_groupes g
   WHERE g.bataille_id = p_bataille_id AND g.groupe_id = p_groupe_id;
  IF v_repli IS NULL THEN RETURN 0; END IF;   -- sans position de repli, on tient

  FOR r IN SELECT e.* FROM public.batailles_engagements e
            WHERE e.bataille_id = p_bataille_id AND e.groupe_id = p_groupe_id
              AND e.sorti_round IS NULL
  LOOP
    IF r.personnage IS NOT NULL THEN
      UPDATE public.personnages_donnees
         SET current_city = v_repli->>'ville', current_building = v_repli->>'batiment',
             current_room = v_repli->>'piece'
       WHERE name = r.personnage;
    ELSE
      -- Un soldat qui suit un chef ne decroche pas seul : il reste avec lui. Regle inchangee.
      UPDATE public.pnj_membres
         SET ville = v_repli->>'ville', building_id = v_repli->>'batiment',
             room_id = v_repli->>'piece', maj_le = now()
       WHERE id = r.compagnie_id || '-' || r.matricule
         AND leader_pj IS NULL AND leader_pnj_id IS NULL;
      IF NOT (r.compagnie_id = ANY(v_cies)) THEN v_cies := v_cies || r.compagnie_id; END IF;
    END IF;
    UPDATE public.batailles_engagements
       SET sorti_round = p_round, etat_final = 'replie' WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;

  FOREACH v_cie IN ARRAY v_cies LOOP
    PERFORM public.militaire_blob_projeter(v_cie);
  END LOOP;

  UPDATE public.batailles_groupes
     SET sorti_round = p_round, attente_depuis = NULL
   WHERE bataille_id = p_bataille_id AND groupe_id = p_groupe_id;
  RETURN v_n;
END; $$;