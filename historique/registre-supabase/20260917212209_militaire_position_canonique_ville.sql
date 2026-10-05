-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917212209
-- Nom original      : militaire_position_canonique_ville
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 21:22:09 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b8f3702235b9f1f42f16c204beb8d177
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
-- POSITION CANONIQUE D'UN SOLDAT : la VILLE entre dans la position.
--
-- LE DEFAUT. Un soldat n'etait localise que par buildingId + roomId. Or 'caserne-militaire' est
-- LE MEME identifiant de batiment dans les quatre empires (data.js:954, 1197, 1441, 1710), et
-- 'marche', 'armurerie', 'stade', 'la-tribune', 'mairie' sont partages entre plusieurs villes
-- d'un meme empire. La position d'un soldat etait donc structurellement ambigue, et le depot
-- comme la recuperation pouvaient viser des hommes d'une autre ville.
--
-- LA CLE CANONIQUE est desormais (compagnie.pays, soldat.ville, soldat.buildingId,
-- soldat.roomId). Le pays reste porte par la compagnie -- un soldat ne change pas d'empire sans
-- elle -- donc seule la ville est ajoutee sur le soldat. Meme idiome que
-- getEntrepriseIdArmurerie(country, city), introduit precisement parce que Luthecia, Montrouge
-- et PSM partageaient sinon la meme caisse.
--
-- LA POSITION RESTE LUE, JAMAIS CRUE : elle vient de la fiche du Lieutenant
-- (current_city / current_building / current_room), jamais d'un parametre client.
--
-- Un soldat qui suit son Lieutenant n'a pas de position propre : ville = NULL, buildingId = NULL,
-- roomId = '__avec_lieutenant__'. Sa position est celle de son chef.
--
-- compagnies_militaires est VIDE en production : aucune donnee a migrer.

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
  SELECT count(*) INTO v_dispo FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'roomId' = '__avec_lieutenant__';
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_assez_avec_vous', 'disponibles', v_dispo);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN avec AND ord <= p_nb
           THEN sol || jsonb_build_object('ville', v_ville, 'buildingId', v_bat, 'roomId', v_room)
           ELSE sol END
      ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM (SELECT sol, pos, (sol->>'roomId' = '__avec_lieutenant__') AS avec,
                 row_number() OVER (PARTITION BY (sol->>'roomId' = '__avec_lieutenant__') ORDER BY pos) AS ord
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'deposes', p_nb,
                            'ville', v_ville, 'batiment', v_bat, 'piece', v_room);
END;
$fn$;

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

  -- La ville entre dans le predicat : on ne recupere que les hommes reellement ICI, pas ceux
  -- d'un batiment homonyme dans une autre ville.
  SELECT count(*) INTO v_dispo FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'ville' = v_ville AND s->>'buildingId' = v_bat AND s->>'roomId' = v_room;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'effectif_insuffisant_ici', 'disponibles', v_dispo);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN ici AND ord <= p_nb
           THEN sol || jsonb_build_object('ville', NULL, 'buildingId', NULL,
                                          'roomId', '__avec_lieutenant__')
           ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM (SELECT sol, pos,
                 (sol->>'ville' = v_ville AND sol->>'buildingId' = v_bat
                  AND sol->>'roomId' = v_room) AS ici,
                 row_number() OVER (PARTITION BY (sol->>'ville' = v_ville
                                    AND sol->>'buildingId' = v_bat AND sol->>'roomId' = v_room)
                                    ORDER BY pos) AS ord
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'recuperes', p_nb, 'ville', v_ville);
END;
$fn$;

REVOKE ALL ON FUNCTION public.militaire_deposer_soldats(text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_deposer_soldats(text, text, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.militaire_deposer_soldats(text, text, integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.militaire_recuperer_soldats(text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_recuperer_soldats(text, text, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.militaire_recuperer_soldats(text, text, integer) TO authenticated, service_role;