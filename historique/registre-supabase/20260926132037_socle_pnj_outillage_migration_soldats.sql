-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926132037
-- Nom original      : socle_pnj_outillage_migration_soldats
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 13:20:37 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3a61c44732e743a16bb042cb32108eb5
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
-- OUTILLAGE DE MIGRATION DES SOLDATS : copie, comparateur, rollback. 26 septembre 2026.
-- Eprouve en schema jetable contre les 96 soldats reels avant d'etre applique ici.
-- Le blob reste AUTORITAIRE pendant toute la phase miroir : ces fonctions le LISENT, jamais
-- ne l'ecrivent. Il n'existe donc aucun point de non-retour tant que les ecritures n'ont pas
-- basculé leur autorite.

CREATE OR REPLACE FUNCTION public.pnj_copier_soldats(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE
  c record; s jsonb; sol jsonb; v_id text; v_pays text;
  v_sections integer := 0; v_sect integer := 0; v_res integer := 0; v_deja integer := 0;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur'); END IF;
  SELECT * INTO c FROM public.compagnies_militaires WHERE id = p_compagnie;
  IF c.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  v_pays := c.data->>'pays';

  SELECT count(*) INTO v_deja FROM public.pnj_membres m
   WHERE m.famille = 'soldat' AND m.id LIKE p_compagnie || '-%';
  IF v_deja > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_copie', 'deja', v_deja); END IF;

  FOR s IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) LOOP
    v_sections := v_sections + 1;
    FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) LOOP
      CONTINUE WHEN COALESCE((sol->>'pj')::boolean, false) IS TRUE;
      v_id := p_compagnie || '-' || (sol->>'matricule');
      INSERT INTO public.pnj_membres (id, famille, nom, pays, proprietaire_poste,
          proprietaire_poste_ville, leader_pj, ville, building_id, room_id, pa, statut)
      VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'lieutenant', NULL,
          sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
          COALESCE((sol->>'pa')::integer, 12), 'actif');
      INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, section_id, en_reserve, arme, formation)
      VALUES (v_id, sol->>'matricule', s->>'id', false, sol->>'arme',
              COALESCE(sol->'formation','{}'::jsonb));
      v_sect := v_sect + 1;
    END LOOP;
  END LOOP;

  FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) LOOP
    v_id := p_compagnie || '-' || (sol->>'matricule');
    INSERT INTO public.pnj_membres (id, famille, nom, pays, proprietaire_poste,
        leader_pj, ville, building_id, room_id, pa, statut)
    VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'lieutenant',
        sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
        COALESCE((sol->>'pa')::integer, 12), 'actif');
    INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, section_id, en_reserve, arme, formation)
    VALUES (v_id, sol->>'matricule', NULL, true, sol->>'arme',
            COALESCE(sol->'formation','{}'::jsonb));
    v_res := v_res + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'compagnie', p_compagnie, 'pays', v_pays,
    'sections', v_sections, 'copies_section', v_sect, 'copies_reserve', v_res,
    'total', v_sect + v_res);
END; $fn$;

CREATE OR REPLACE FUNCTION public.pnj_comparer_soldats(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_div jsonb; v_nb_blob integer; v_nb_socle integer;
BEGIN
  WITH blob AS (
    SELECT sol->>'matricule' AS matricule, sol->>'leaderCourant' AS leader,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat, sol->>'roomId' AS room,
           (sol->>'pa')::integer AS pa, sol->>'arme' AS arme,
           COALESCE(sol->'formation','{}'::jsonb) AS formation,
           false AS en_reserve, s->>'id' AS section_id
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) sol
     WHERE c.id = p_compagnie AND COALESCE((sol->>'pj')::boolean, false) = false
    UNION ALL
    SELECT r->>'matricule', r->>'leaderCourant', r->>'ville', r->>'buildingId', r->>'roomId',
           (r->>'pa')::integer, r->>'arme', COALESCE(r->'formation','{}'::jsonb), true, NULL
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) r
     WHERE c.id = p_compagnie
  ), socle AS (
    SELECT sm.matricule, m.leader_pj AS leader, m.ville, m.building_id AS bat,
           m.room_id AS room, m.pa, sm.arme, sm.formation, sm.en_reserve, sm.section_id,
           m.proprietaire_poste, m.statut
      FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.id LIKE p_compagnie || '-%'
  ), compare AS (
    SELECT COALESCE(b.matricule, s.matricule) AS matricule,
      CASE
        WHEN s.matricule IS NULL THEN 'absent_du_socle'
        WHEN b.matricule IS NULL THEN 'surnumeraire_dans_le_socle'
        WHEN b.leader      IS DISTINCT FROM s.leader      THEN 'leader'
        WHEN b.ville       IS DISTINCT FROM s.ville       THEN 'ville'
        WHEN b.bat         IS DISTINCT FROM s.bat         THEN 'batiment'
        WHEN b.room        IS DISTINCT FROM s.room        THEN 'piece'
        WHEN b.pa          IS DISTINCT FROM s.pa          THEN 'pa'
        WHEN b.arme        IS DISTINCT FROM s.arme        THEN 'arme'
        WHEN b.formation   IS DISTINCT FROM s.formation   THEN 'entrainement'
        WHEN b.en_reserve  IS DISTINCT FROM s.en_reserve  THEN 'reserve'
        WHEN b.section_id  IS DISTINCT FROM s.section_id  THEN 'section'
        WHEN s.proprietaire_poste IS DISTINCT FROM 'lieutenant' THEN 'proprietaire'
        WHEN s.statut IS DISTINCT FROM 'actif' THEN 'statut'
        ELSE NULL END AS divergence
      FROM blob b FULL OUTER JOIN socle s ON s.matricule = b.matricule
  )
  SELECT (SELECT count(*) FROM blob), (SELECT count(*) FROM socle),
         COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule, 'divergence', divergence)
                            ORDER BY matricule) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_nb_blob, v_nb_socle, v_div FROM compare;

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb_blob = v_nb_socle,
    'nb_blob', v_nb_blob, 'nb_socle', v_nb_socle,
    'correspondances', v_nb_blob - jsonb_array_length(v_div),
    'nb_divergences', jsonb_array_length(v_div),
    'manquants', (SELECT count(*) FROM jsonb_array_elements(v_div) d
                   WHERE d->>'divergence' = 'absent_du_socle'),
    'surnumeraires', (SELECT count(*) FROM jsonb_array_elements(v_div) d
                   WHERE d->>'divergence' = 'surnumeraire_dans_le_socle'),
    'details', v_div);
END; $fn$;

CREATE OR REPLACE FUNCTION public.pnj_rollback_soldats(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_avant integer; v_apres integer; v_autres_avant integer; v_autres_apres integer;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur'); END IF;
  SELECT count(*) INTO v_avant FROM public.pnj_membres WHERE id LIKE p_compagnie || '-%';
  SELECT count(*) INTO v_autres_avant FROM public.pnj_membres WHERE id NOT LIKE p_compagnie || '-%';
  DELETE FROM public.pnj_membres WHERE id LIKE p_compagnie || '-%';
  SELECT count(*) INTO v_apres FROM public.pnj_membres WHERE id LIKE p_compagnie || '-%';
  SELECT count(*) INTO v_autres_apres FROM public.pnj_membres WHERE id NOT LIKE p_compagnie || '-%';
  RETURN jsonb_build_object('ok', v_apres = 0 AND v_autres_avant = v_autres_apres,
    'supprimes', v_avant - v_apres, 'restants_compagnie', v_apres,
    'autres_familles_avant', v_autres_avant, 'autres_familles_apres', v_autres_apres,
    'metier_orphelin', (SELECT count(*) FROM public.pnj_soldats_metier sm
                         WHERE NOT EXISTS (SELECT 1 FROM public.pnj_membres m WHERE m.id = sm.pnj_id)));
END; $fn$;

REVOKE ALL ON FUNCTION public.pnj_copier_soldats(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_rollback_soldats(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_comparer_soldats(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pnj_copier_soldats(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_rollback_soldats(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_comparer_soldats(text) TO service_role;