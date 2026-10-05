-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260929212600
-- Nom original      : t2_terminal_manger_dormir_rejoindre
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-29 21:26:00 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : bad8483cbbb6827c1fb5e3edbbdf2a2c
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
create or replace function public.militaire_terminal_manger(p_requete text, p_matricules text[])
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  c_gain constant integer := 1;
  c_pa_max constant integer := 12;
  c_max_jour constant integer := 2;
  g record; v_deja record; v_jour text; r record; v_res jsonb;
  v_avec integer := 0; v_sans integer := 0; v_refus jsonb := '[]'::jsonb;
  v_ids text[] := '{}'; v_mats text[] := '{}'; v_id bigint; v_u integer; v_objet jsonb;
  v_data jsonb; v_sec jsonb;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^mil-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF p_matricules IS NULL OR array_length(p_matricules, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_selection'); END IF;

  SELECT * INTO v_deja FROM public.militaire_terminal_requetes WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(g.o_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = g.o_section;

  FOR r IN
    SELECT sm.pnj_id, sm.matricule, m.pa,
           CASE WHEN coalesce(b.sol->>'dernier_ration','') = v_jour
                THEN coalesce((b.sol->>'nb_ration')::integer, 1) ELSE 0 END AS nb
      FROM public.pnj_soldats_metier sm
      JOIN public.pnj_membres m ON m.id = sm.pnj_id
      LEFT JOIN LATERAL (
        SELECT s AS sol FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
         WHERE s->>'matricule' = sm.matricule LIMIT 1) b ON true
     WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
       AND m.statut = 'actif' AND coalesce(sm.en_reserve,false) = false
       AND sm.matricule = ANY(p_matricules)
     ORDER BY sm.matricule
  LOOP
    IF NOT public.militaire_terminal_liaison(g.o_moi, r.pnj_id) THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'hors_liaison');
      CONTINUE;
    END IF;

    v_id := NULL; v_objet := NULL;
    SELECT p.id, p.objet INTO v_id, v_objet FROM public.pnj_possessions p
     WHERE p.pnj_id = r.pnj_id AND p.objet->>'produitMilitaire' = 'ration_combat'
     ORDER BY p.id LIMIT 1 FOR UPDATE;

    IF v_id IS NULL OR r.pa >= c_pa_max OR r.nb >= c_max_jour THEN
      v_sans := v_sans + 1;
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison',
        CASE WHEN v_id IS NULL THEN 'sans_ration'
             WHEN r.pa >= c_pa_max THEN 'pa_au_maximum'
             ELSE 'maximum_quotidien' END, 'execute', true);
      CONTINUE;
    END IF;

    v_u := public.militaire_unites_objet(v_objet);
    IF v_u <= 1 THEN DELETE FROM public.pnj_possessions WHERE id = v_id;
    ELSE UPDATE public.pnj_possessions
            SET objet = v_objet || jsonb_build_object('qty', v_u - 1) WHERE id = v_id; END IF;

    v_ids  := v_ids  || r.pnj_id;
    v_mats := v_mats || r.matricule;
    v_avec := v_avec + 1;
  END LOOP;

  IF v_avec > 0 THEN
    PERFORM public.pnj_pa_crediter(v_ids, c_gain);
    SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = g.o_compagnie FOR UPDATE;
    UPDATE public.compagnies_militaires
       SET data = jsonb_set(v_data, '{sections}', (
             SELECT coalesce(jsonb_agg(
               CASE WHEN s->>'id' = g.o_section
                    THEN jsonb_set(s, '{soldats}', (
                           SELECT coalesce(jsonb_agg(
                             CASE WHEN (so->>'matricule') = ANY(v_mats)
                                  THEN so || jsonb_build_object('dernier_ration', v_jour,
                                         'nb_ration', (CASE WHEN coalesce(so->>'dernier_ration','') = v_jour
                                                            THEN coalesce((so->>'nb_ration')::integer,1)
                                                            ELSE 0 END) + 1)
                                  ELSE so END ORDER BY o2), '[]'::jsonb)
                             FROM jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb))
                                  WITH ORDINALITY AS t2(so, o2)))
                    ELSE s END ORDER BY o1), '[]'::jsonb)
               FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb))
                    WITH ORDINALITY AS t1(s, o1))),
           updated_at = now()
     WHERE id = g.o_compagnie;
    PERFORM public.militaire_blob_projeter(g.o_compagnie);
  END IF;

  v_res := jsonb_build_object('ok', true, 'action', 'manger',
    'avec_ration', v_avec, 'sans_ration', v_sans, 'gain_pa', c_gain, 'details', v_refus);
  INSERT INTO public.militaire_terminal_requetes (requete, acteur, action, resultat)
  VALUES (p_requete, g.o_moi, 'manger', v_res);
  RETURN v_res;
END; $fn$;

comment on function public.militaire_terminal_manger(text,text[]) is
  'Ordre collectif de manger. Chaque soldat selectionne consomme SA propre ration et gagne 1 PA (plafond 12, deux par jour) ; celui qui n''en a pas execute l''ordre sans bonus et ne fait pas echouer l''ordre. La ration du Lieutenant n''est JAMAIS prelevee pour un PNJ. Idempotente par cle de requete.';

revoke all on function public.militaire_terminal_manger(text,text[]) from public, anon, authenticated;
grant execute on function public.militaire_terminal_manger(text,text[]) to authenticated, service_role;

create or replace function public.militaire_terminal_dormir(
  p_requete text, p_matricules text[], p_tentes text[])
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  c_pa_max constant integer := 12;
  c_gain_terrain constant integer := 8;
  c_bonus_tente constant integer := 2;
  g record; v_deja record; v_jour text; r record; v_res jsonb; v_etat jsonb;
  v_tentes text[] := coalesce(p_tentes, '{}'::text[]);
  v_libres integer; v_caserne text[] := '{}'; v_sous_tente text[] := '{}';
  v_terrain text[] := '{}'; v_mats text[] := '{}'; v_refus jsonb := '[]'::jsonb;
  v_data jsonb; v_sec jsonb;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^mil-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF p_matricules IS NULL OR array_length(p_matricules, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_selection'); END IF;
  IF EXISTS (SELECT 1 FROM unnest(v_tentes) t WHERE t <> ALL(p_matricules)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tente_hors_selection'); END IF;

  SELECT * INTO v_deja FROM public.militaire_terminal_requetes WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  v_etat := public.militaire_terminal_section();
  v_libres := coalesce((v_etat->>'places_tente_libres')::integer, 0);
  IF coalesce(array_length(v_tentes,1), 0) > v_libres THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_tente_depassee',
      'demande', coalesce(array_length(v_tentes,1),0), 'places_libres', v_libres,
      'tentes', v_etat->'tentes', 'par_tente', v_etat->'par_tente',
      'places_pj', v_etat->'places_pj'); END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(g.o_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = g.o_section;

  FOR r IN
    SELECT sm.pnj_id, sm.matricule, m.pa, coalesce(sm.dernier_sommeil,'') AS marqueur,
           coalesce(pd.current_building, m.building_id) AS batiment
      FROM public.pnj_soldats_metier sm
      JOIN public.pnj_membres m ON m.id = sm.pnj_id
      LEFT JOIN public.personnages_donnees pd ON pd.name = m.leader_pj
     WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
       AND m.statut = 'actif' AND coalesce(sm.en_reserve,false) = false
       AND sm.matricule = ANY(p_matricules)
     ORDER BY sm.matricule
  LOOP
    IF NOT public.militaire_terminal_liaison(g.o_moi, r.pnj_id) THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'hors_liaison');
      CONTINUE;
    END IF;
    IF r.pa <= 0 THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'epuise');
      CONTINUE;
    END IF;
    IF r.marqueur = v_jour THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'deja_repose');
      CONTINUE;
    END IF;

    v_mats := v_mats || r.matricule;
    IF coalesce(r.batiment,'') = 'caserne-militaire' THEN v_caserne := v_caserne || r.pnj_id;
    ELSIF r.matricule = ANY(v_tentes)                THEN v_sous_tente := v_sous_tente || r.pnj_id;
    ELSE                                                  v_terrain := v_terrain || r.pnj_id;
    END IF;
  END LOOP;

  IF array_length(v_caserne,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_fixer(v_caserne, c_pa_max); END IF;
  IF array_length(v_sous_tente,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_crediter(v_sous_tente, c_gain_terrain + c_bonus_tente); END IF;
  IF array_length(v_terrain,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_crediter(v_terrain, c_gain_terrain); END IF;

  IF array_length(v_mats,1) IS NOT NULL THEN
    SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = g.o_compagnie FOR UPDATE;
    UPDATE public.compagnies_militaires
       SET data = jsonb_set(v_data, '{sections}', (
             SELECT coalesce(jsonb_agg(
               CASE WHEN s->>'id' = g.o_section
                    THEN jsonb_set(s, '{soldats}', (
                           SELECT coalesce(jsonb_agg(
                             CASE WHEN (so->>'matricule') = ANY(v_mats)
                                  THEN so || jsonb_build_object('dernier_sommeil', v_jour)
                                  ELSE so END ORDER BY o2), '[]'::jsonb)
                             FROM jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb))
                                  WITH ORDINALITY AS t2(so, o2)))
                    ELSE s END ORDER BY o1), '[]'::jsonb)
               FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb))
                    WITH ORDINALITY AS t1(s, o1))),
           updated_at = now()
     WHERE id = g.o_compagnie;
    PERFORM public.militaire_blob_projeter(g.o_compagnie);
  END IF;

  v_res := jsonb_build_object('ok', true, 'action', 'dormir',
    'caserne', coalesce(array_length(v_caserne,1),0),
    'tente', coalesce(array_length(v_sous_tente,1),0),
    'terrain', coalesce(array_length(v_terrain,1),0),
    'reposes', coalesce(array_length(v_mats,1),0),
    'details', v_refus);
  INSERT INTO public.militaire_terminal_requetes (requete, acteur, action, resultat)
  VALUES (p_requete, g.o_moi, 'dormir', v_res);
  RETURN v_res;
END; $fn$;

comment on function public.militaire_terminal_dormir(text,text[],text[]) is
  'Ordre collectif de dormir, avec designation explicite de qui a une place sous la tente. Valeurs reprises de militaire_reposer_section : caserne 12, terrain +8, tente +8+2, une fois par jour, jamais a 0 PA. Capacite de 13 personnes par tente PJ COMPRIS ; une selection qui la depasse refuse l''ordre ENTIER. Idempotente par cle de requete.';

revoke all on function public.militaire_terminal_dormir(text,text[],text[]) from public, anon, authenticated;
grant execute on function public.militaire_terminal_dormir(text,text[],text[]) to authenticated, service_role;

create or replace function public.militaire_terminal_rejoindre(p_requete text, p_matricules text[])
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  g record; v_deja record; r record; v_res jsonb; v_ville text;
  v_ids text[] := '{}'; v_refus jsonb := '[]'::jsonb;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^mil-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF p_matricules IS NULL OR array_length(p_matricules, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_selection'); END IF;

  SELECT * INTO v_deja FROM public.militaire_terminal_requetes WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  SELECT current_city INTO v_ville FROM public.personnages_donnees WHERE name = g.o_moi;
  IF coalesce(v_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue'); END IF;

  FOR r IN
    SELECT sm.pnj_id, sm.matricule, m.leader_pj, pe.ville AS ville_reelle
      FROM public.pnj_soldats_metier sm
      JOIN public.pnj_membres m ON m.id = sm.pnj_id
      LEFT JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
     WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
       AND m.statut = 'actif' AND coalesce(sm.en_reserve,false) = false
       AND sm.matricule = ANY(p_matricules)
     ORDER BY sm.matricule
  LOOP
    IF r.leader_pj = g.o_moi THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'deja_avec_vous');
      CONTINUE;
    END IF;
    IF NOT public.militaire_terminal_liaison(g.o_moi, r.pnj_id) THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'hors_liaison');
      CONTINUE;
    END IF;
    IF r.ville_reelle IS DISTINCT FROM v_ville THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule,
        'raison', 'autre_ville_transport_requis', 'ville', r.ville_reelle);
      CONTINUE;
    END IF;
    v_ids := v_ids || r.pnj_id;
  END LOOP;

  IF array_length(v_ids,1) IS NOT NULL THEN
    UPDATE public.pnj_membres
       SET leader_pj = g.o_moi, leader_pnj_id = NULL,
           ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL, maj_le = now()
     WHERE id = ANY(v_ids);
    PERFORM public.militaire_blob_projeter(g.o_compagnie);
  END IF;

  v_res := jsonb_build_object('ok', true, 'action', 'rejoindre',
    'rejoints', coalesce(array_length(v_ids,1),0), 'details', v_refus);
  INSERT INTO public.militaire_terminal_requetes (requete, acteur, action, resultat)
  VALUES (p_requete, g.o_moi, 'rejoindre', v_res);
  RETURN v_res;
END; $fn$;

comment on function public.militaire_terminal_rejoindre(text,text[]) is
  'Rappelle des soldats aupres du Lieutenant : leader_pj = lui, position propre effacee. Le perimetre est la VILLE et non la piece, et une liaison de commandement est exigee a distance. Une autre ville est refusee nommement (autre_ville_transport_requis) : aucun soldat n''est teleporte, le transport reste le camion militaire existant.';

revoke all on function public.militaire_terminal_rejoindre(text,text[]) from public, anon, authenticated;
grant execute on function public.militaire_terminal_rejoindre(text,text[]) to authenticated, service_role;