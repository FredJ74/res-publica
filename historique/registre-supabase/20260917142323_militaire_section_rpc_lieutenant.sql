-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917142323
-- Nom original      : militaire_section_rpc_lieutenant
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 14:23:23 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e5c050cf48638f5daba7b18db67d337d
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
-- LOT A — REGRESSION RLS DE LA PASSE 3 : LES OPERATIONS DU LIEUTENANT
--
-- CONSTAT PROUVE : la politique RLS posee en passe 3 sur compagnies_militaires autorise le
-- Commandant du pays et LE Capitaine de la compagnie, mais PAS le Lieutenant. Toutes ses
-- operations legitimes (gerer_detachement, equiper_section, assigner_mission, entrainer_section)
-- ecrivent pourtant cette table : elles etaient refusees (0 ligne, en silence puisque sbUpdate
-- rend null). Impact reel nul a ce jour -- compagnies_militaires est vide en production -- mais
-- bloquant des la premiere compagnie recrutee.
--
-- POURQUOI PAS UNE POLITIQUE RLS POUR LE LIEUTENANT. La RLS est par LIGNE, pas par colonne ni par
-- sous-document. Autoriser le Lieutenant a UPDATE la ligne lui donnerait le droit d'ecrire tout le
-- blob : capitaineNom, les autres sections, les stocks, la formation de n'importe quel soldat.
-- Ce serait exactement le « droit generique d'ecriture sur toute la compagnie » a eviter.
-- Ses mutations passent donc par des RPC attestees, chacune bornee a SA section.
--
-- AUTORITE COMMUNE : etre le lieutenantNom de LA section visee, dans une compagnie de SON pays.
-- Pendant exact de militaire_proposer_lieutenant, qui exige d'etre LE capitaine de CETTE
-- compagnie. Le rattachement structurel porte l'autorite ; aucun grade nouveau.
--
-- AUCUNE REGLE DE JEU NE CHANGE : memes effets, memes plafonds (12 soldats par session, +3 par
-- stat, plafond 100), memes missions, meme retour de l'arme quittee au stock de la section.
-- Un seul point est renforce : la POSITION du lieutenant est lue sur sa fiche
-- (personnages_donnees.current_building / current_room), plus annoncee par le navigateur.

CREATE OR REPLACE FUNCTION public.militaire_section_de_moi(
  p_compagnie_id text, p_section_id text, OUT o_moi text, OUT o_data jsonb, OUT o_raison text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_pays text; v_sec jsonb;
BEGIN
  o_moi := public.mon_personnage();
  IF o_moi IS NULL THEN o_raison := 'acteur_non_authentifie'; RETURN; END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = o_moi;
  SELECT data INTO o_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF o_data IS NULL THEN o_raison := 'compagnie_introuvable'; RETURN; END IF;
  IF o_data->>'pays' IS DISTINCT FROM v_pays THEN o_raison := 'hors_juridiction'; RETURN; END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(COALESCE(o_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id LIMIT 1;
  IF v_sec IS NULL THEN o_raison := 'section_introuvable'; RETURN; END IF;
  IF v_sec->>'lieutenantNom' IS DISTINCT FROM o_moi THEN
    o_raison := 'pas_lieutenant_de_cette_section'; RETURN;
  END IF;
  o_raison := NULL;
END; $fn$;

CREATE OR REPLACE FUNCTION public.militaire_sections_remplacer(p_data jsonb, p_section_id text, p_nouvelle jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $fn$
  SELECT p_data || jsonb_build_object('sections', COALESCE((
    SELECT jsonb_agg(CASE WHEN s->>'id' = p_section_id THEN p_nouvelle ELSE s END ORDER BY ord)
      FROM jsonb_array_elements(COALESCE(p_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord)
  ), '[]'::jsonb));
$fn$;

CREATE OR REPLACE FUNCTION public.militaire_deposer_soldats(
  p_compagnie_id text, p_section_id text, p_nb integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE g record; v_sec jsonb; v_sols jsonb; v_bat text; v_room text; v_dispo int;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;
  SELECT current_building, current_room INTO v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;
  IF COALESCE(v_bat,'') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue'); END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  SELECT count(*) INTO v_dispo FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'roomId' = '__avec_lieutenant__';
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_assez_avec_vous', 'disponibles', v_dispo);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN avec AND ord <= p_nb
           THEN sol || jsonb_build_object('buildingId', v_bat, 'roomId', v_room) ELSE sol END
      ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM (SELECT sol, pos, (sol->>'roomId' = '__avec_lieutenant__') AS avec,
                 row_number() OVER (PARTITION BY (sol->>'roomId' = '__avec_lieutenant__') ORDER BY pos) AS ord
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'deposes', p_nb, 'batiment', v_bat, 'piece', v_room);
END; $fn$;

CREATE OR REPLACE FUNCTION public.militaire_recuperer_soldats(
  p_compagnie_id text, p_section_id text, p_nb integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE g record; v_sec jsonb; v_sols jsonb; v_bat text; v_room text; v_dispo int;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;
  SELECT current_building, current_room INTO v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;

  SELECT count(*) INTO v_dispo FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'buildingId' = v_bat AND s->>'roomId' = v_room;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'effectif_insuffisant_ici', 'disponibles', v_dispo);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN ici AND ord <= p_nb
           THEN sol || jsonb_build_object('buildingId', NULL, 'roomId', '__avec_lieutenant__')
           ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM (SELECT sol, pos,
                 (sol->>'buildingId' = v_bat AND sol->>'roomId' = v_room) AS ici,
                 row_number() OVER (PARTITION BY (sol->>'buildingId' = v_bat AND sol->>'roomId' = v_room)
                                    ORDER BY pos) AS ord
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'recuperes', p_nb);
END; $fn$;

CREATE OR REPLACE FUNCTION public.militaire_assigner_mission(
  p_compagnie_id text, p_section_id text, p_mission text, p_cible text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE g record; v_sec jsonb;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF p_mission NOT IN ('bloquer_acces','securiser','assassiner','arreter','surveiller','escorter') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mission_invalide');
  END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_sec := v_sec || jsonb_build_object('mission', p_mission,
             'cibleEscorte', CASE WHEN p_mission = 'escorter' THEN to_jsonb(p_cible) ELSE 'null'::jsonb END);
  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id, v_sec)
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'mission', p_mission);
END; $fn$;

CREATE OR REPLACE FUNCTION public.militaire_entrainer_section(
  p_compagnie_id text, p_section_id text, p_stat text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE g record; v_sec jsonb; v_sols jsonb; v_n int;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF p_stat NOT IN ('force','endurance','tir') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stat_invalide');
  END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN rang <= 12
           THEN jsonb_set(sol, ARRAY['formation', p_stat],
                  to_jsonb(LEAST(100, COALESCE((sol->'formation'->>p_stat)::int, 0) + 3)))
           ELSE sol END ORDER BY pos), '[]'::jsonb),
         count(*) FILTER (WHERE rang <= 12)
    INTO v_sols, v_n
    FROM (SELECT sol, pos,
                 row_number() OVER (ORDER BY COALESCE((sol->'formation'->>p_stat)::int, 0), pos) AS rang
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'progresses', COALESCE(v_n,0), 'stat', p_stat);
END; $fn$;

CREATE OR REPLACE FUNCTION public.militaire_equiper_soldat(
  p_compagnie_id text, p_section_id text, p_matricule text, p_categorie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE g record; v_sec jsonb; v_stock jsonb; v_sol jsonb; v_anc text; v_dispo int; v_sols jsonb;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF p_categorie NOT IN ('corps_a_corps','arme_de_poing','mitraillette') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'categorie_invalide');
  END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_stock := CASE WHEN jsonb_typeof(v_sec->'stockArmes') = 'object' THEN v_sec->'stockArmes'
                  ELSE jsonb_build_object('arme_de_poing',0,'mitraillette',0) END;
  SELECT s INTO v_sol FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'matricule' = p_matricule LIMIT 1;
  IF v_sol IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable'); END IF;

  v_anc := COALESCE(v_sol->>'arme', 'corps_a_corps');
  IF v_anc = p_categorie THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;

  IF p_categorie <> 'corps_a_corps' THEN
    v_dispo := GREATEST(0, COALESCE((v_stock->>p_categorie)::int, 0));
    IF v_dispo <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_section_insuffisant', 'categorie', p_categorie);
    END IF;
    v_stock := v_stock || jsonb_build_object(p_categorie, v_dispo - 1);
  END IF;
  IF v_anc <> 'corps_a_corps' THEN
    v_stock := v_stock || jsonb_build_object(v_anc, GREATEST(0, COALESCE((v_stock->>v_anc)::int, 0)) + 1);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN sol->>'matricule' = p_matricule THEN sol || jsonb_build_object('arme', p_categorie)
           ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos);

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols, 'stockArmes', v_stock))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'matricule', p_matricule, 'arme', p_categorie,
                            'ancienne', v_anc, 'stock', v_stock);
END; $fn$;

REVOKE EXECUTE ON FUNCTION public.militaire_section_de_moi(text,text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.militaire_deposer_soldats(text,text,integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.militaire_recuperer_soldats(text,text,integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.militaire_assigner_mission(text,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.militaire_entrainer_section(text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.militaire_equiper_soldat(text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_deposer_soldats(text,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_recuperer_soldats(text,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_assigner_mission(text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_entrainer_section(text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_equiper_soldat(text,text,text,text) TO authenticated;