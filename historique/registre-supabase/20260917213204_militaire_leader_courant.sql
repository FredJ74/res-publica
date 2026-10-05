-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917213204
-- Nom original      : militaire_leader_courant
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 21:32:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 73267c26f1c13d82f45b78067de43f15
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
-- ==========================================================================================
-- LEADER OPERATIONNEL COURANT — remplace le sentinel '__avec_lieutenant__'
--
-- MODELE. Un soldat est dans exactement l'un de deux etats :
--   SUIT UN CHEF  : leaderCourant = '<nom du PJ>', ville/buildingId/roomId = NULL.
--                   Sa position effective est DERIVEE de la position canonique de son chef.
--   SUR PLACE     : leaderCourant = NULL, ville/buildingId/roomId renseignes.
--
-- L'AUTORITE STRUCTURELLE N'EST JAMAIS TRANSFEREE. section.lieutenantNom reste souverain : seul
-- le Lieutenant structurel cree ou modifie les affectations de ses PNJ. Un soldat PJ a qui l'on
-- confie des hommes en est le leader OPERATIONNEL : il les mene physiquement, mais ne peut pas
-- les reprendre lui-meme s'il les laisse quelque part -- seul le Lieutenant peut.
--
-- RUPTURE DU LIEN, generique et non un correctif particulier a militaire_demettre_lieutenant :
-- des qu'un personnage cesse d'etre Lieutenant, les soldats qui le suivaient sont MATERIALISES a
-- sa derniere position canonique connue et leur leaderCourant passe a NULL. Ils ne restent pas
-- attaches a un chef fantome, ne suivent pas le PJ dans sa vie civile, et ne sont pas teleportes
-- a la caserne. Leur autorite structurelle reste celle de leur section.
--
-- Le declencheur est un TRIGGER sur la perte de poste, sur le modele exact de
-- trg_personnages_poste_perdu (AFTER UPDATE OF poste). Il couvre donc d'un seul coup
-- militaire_demettre_lieutenant (qui met poste a NULL) ET toute autre perte de poste --
-- arrestation pour crime notamment, qui retire le poste par la vue personnages.
-- ==========================================================================================

-- ---- 1. La primitive de rupture, generique par NOM DE LEADER ----
-- Volontairement NON accordee au client : elle n'est appelable que par le trigger et par d'autres
-- fonctions SECURITY DEFINER. Rompre un lien n'est pas une action de joueur.
CREATE OR REPLACE FUNCTION public.militaire_lien_operationnel_rompre(
  p_leader text, p_ville text, p_bat text, p_room text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE v_cie record; v_sections jsonb; v_n int; v_total int := 0;
BEGIN
  IF coalesce(btrim(coalesce(p_leader, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_invalide');
  END IF;

  FOR v_cie IN SELECT id, data FROM public.compagnies_militaires FOR UPDATE LOOP
    SELECT count(*) INTO v_n
      FROM jsonb_array_elements(coalesce(v_cie.data->'sections', '[]'::jsonb)) sec,
           jsonb_array_elements(coalesce(sec->'soldats', '[]'::jsonb)) sol
     WHERE sol->>'leaderCourant' = p_leader;
    CONTINUE WHEN v_n = 0;

    SELECT coalesce(jsonb_agg(
             sec || jsonb_build_object('soldats', (
               SELECT coalesce(jsonb_agg(
                        CASE WHEN sol->>'leaderCourant' = p_leader
                             THEN sol || jsonb_build_object('leaderCourant', NULL,
                                    'ville', p_ville, 'buildingId', p_bat, 'roomId', p_room)
                             ELSE sol END ORDER BY spos), '[]'::jsonb)
                 FROM jsonb_array_elements(coalesce(sec->'soldats', '[]'::jsonb))
                      WITH ORDINALITY AS ts(sol, spos)))
             ORDER BY pos), '[]'::jsonb)
      INTO v_sections
      FROM jsonb_array_elements(coalesce(v_cie.data->'sections', '[]'::jsonb))
           WITH ORDINALITY AS t(sec, pos);

    UPDATE public.compagnies_militaires
       SET data = v_cie.data || jsonb_build_object('sections', v_sections)
     WHERE id = v_cie.id;
    v_total := v_total + v_n;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'soldats', v_total,
                            'ville', p_ville, 'batiment', p_bat, 'piece', p_room);
END;
$fn$;
REVOKE ALL ON FUNCTION public.militaire_lien_operationnel_rompre(text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_lien_operationnel_rompre(text, text, text, text) FROM anon, authenticated;

-- ---- 2. Le declencheur generique : perte du poste de Lieutenant ----
CREATE OR REPLACE FUNCTION public.personnages_lien_militaire_rompu() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
BEGIN
  IF coalesce(OLD.poste->>'id', '') = 'lieutenant'
     AND coalesce(NEW.poste->>'id', '') IS DISTINCT FROM 'lieutenant' THEN
    -- OLD porte la DERNIERE position canonique connue du chef : c'est la que ses hommes restent.
    PERFORM public.militaire_lien_operationnel_rompre(
      OLD.name, OLD.current_city, OLD.current_building, OLD.current_room);
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_personnages_lien_militaire_rompu ON public.personnages_donnees;
CREATE TRIGGER trg_personnages_lien_militaire_rompu
  AFTER UPDATE OF poste ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_lien_militaire_rompu();

-- Un personnage supprime ne doit pas laisser de leaderCourant orphelin.
CREATE OR REPLACE FUNCTION public.personnages_lien_militaire_supprime() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
BEGIN
  PERFORM public.militaire_lien_operationnel_rompre(
    OLD.name, OLD.current_city, OLD.current_building, OLD.current_room);
  RETURN OLD;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_personnages_lien_militaire_supprime ON public.personnages_donnees;
CREATE TRIGGER trg_personnages_lien_militaire_supprime
  BEFORE DELETE ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_lien_militaire_supprime();

-- ---- 3. Recuperer : le soldat suit desormais un LEADER NOMME, plus un roomId sentinelle ----
CREATE OR REPLACE FUNCTION public.militaire_recuperer_soldats(
  p_compagnie_id text, p_section_id text, p_nb integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE g record; v_sec jsonb; v_sols jsonb; v_ville text; v_bat text; v_room text; v_dispo int;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;

  SELECT current_city, current_building, current_room INTO v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;
  IF COALESCE(v_bat,'') = '' OR COALESCE(v_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;

  SELECT count(*) INTO v_dispo FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'ville' = v_ville AND s->>'buildingId' = v_bat AND s->>'roomId' = v_room
     AND s->>'leaderCourant' IS NULL;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'effectif_insuffisant_ici', 'disponibles', v_dispo);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN ici AND ord <= p_nb
           THEN sol || jsonb_build_object('leaderCourant', g.o_moi,
                         'ville', NULL, 'buildingId', NULL, 'roomId', NULL)
           ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM (SELECT sol, pos,
                 (sol->>'ville' = v_ville AND sol->>'buildingId' = v_bat
                  AND sol->>'roomId' = v_room AND sol->>'leaderCourant' IS NULL) AS ici,
                 row_number() OVER (PARTITION BY (sol->>'ville' = v_ville
                                    AND sol->>'buildingId' = v_bat AND sol->>'roomId' = v_room
                                    AND sol->>'leaderCourant' IS NULL) ORDER BY pos) AS ord
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'recuperes', p_nb, 'leader', g.o_moi);
END;
$fn$;

-- ---- 4. Deposer : materialise la position et coupe le lien ----
CREATE OR REPLACE FUNCTION public.militaire_deposer_soldats(
  p_compagnie_id text, p_section_id text, p_nb integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE g record; v_sec jsonb; v_sols jsonb; v_ville text; v_bat text; v_room text; v_dispo int;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;

  SELECT current_city, current_building, current_room INTO v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;
  IF COALESCE(v_bat,'') = '' OR COALESCE(v_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;

  -- TRANSITION : le sentinel historique '__avec_lieutenant__' est encore ACCEPTE en lecture, pour
  -- qu'aucun soldat ne reste bloque s'il en portait un. Il n'est plus jamais ECRIT.
  SELECT count(*) INTO v_dispo FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'leaderCourant' = g.o_moi OR s->>'roomId' = '__avec_lieutenant__';
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_assez_avec_vous', 'disponibles', v_dispo);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN avec AND ord <= p_nb
           THEN sol || jsonb_build_object('leaderCourant', NULL,
                         'ville', v_ville, 'buildingId', v_bat, 'roomId', v_room)
           ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM (SELECT sol, pos,
                 (sol->>'leaderCourant' = g.o_moi
                  OR sol->>'roomId' = '__avec_lieutenant__') AS avec,
                 row_number() OVER (PARTITION BY (sol->>'leaderCourant' = g.o_moi
                                    OR sol->>'roomId' = '__avec_lieutenant__') ORDER BY pos) AS ord
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'deposes', p_nb,
                            'ville', v_ville, 'batiment', v_bat, 'piece', v_room);
END;
$fn$;

-- ---- 5. Confier des hommes a un leader operationnel (soldat PJ) ----
-- Reserve au LIEUTENANT STRUCTUREL de la section. Le leader designe doit etre physiquement
-- present aupres de lui -- meme principe de presence reelle que militaire_retrait,
-- refectoire_repas et inventaire_donner. Aucune autorite structurelle n'est transferee.
CREATE OR REPLACE FUNCTION public.militaire_affecter_leader(
  p_compagnie_id text, p_section_id text, p_nb integer, p_leader text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE g record; v_sec jsonb; v_sols jsonb; v_dispo int;
        v_mv text; v_mb text; v_mr text; v_lv text; v_lb text; v_lr text; v_pays_l text; v_pays_m text;
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
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_introuvable');
  END IF;
  IF v_pays_l IS DISTINCT FROM v_pays_m THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_hors_juridiction');
  END IF;
  IF v_lv IS DISTINCT FROM v_mv OR v_lb IS DISTINCT FROM v_mb OR v_lr IS DISTINCT FROM v_mr THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_absent');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  SELECT count(*) INTO v_dispo FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'leaderCourant' = g.o_moi;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_assez_avec_vous', 'disponibles', v_dispo);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN avec AND ord <= p_nb
           THEN sol || jsonb_build_object('leaderCourant', p_leader) ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM (SELECT sol, pos, (sol->>'leaderCourant' = g.o_moi) AS avec,
                 row_number() OVER (PARTITION BY (sol->>'leaderCourant' = g.o_moi) ORDER BY pos) AS ord
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'affectes', p_nb, 'leader', p_leader);
END;
$fn$;

REVOKE ALL ON FUNCTION public.militaire_affecter_leader(text, text, integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_affecter_leader(text, text, integer, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.militaire_affecter_leader(text, text, integer, text) TO authenticated, service_role;