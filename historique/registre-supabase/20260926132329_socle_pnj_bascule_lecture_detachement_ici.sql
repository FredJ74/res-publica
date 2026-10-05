-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926132329
-- Nom original      : socle_pnj_bascule_lecture_detachement_ici
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 13:23:29 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : afcbecac5ed42427bb9c92ff3baf7958
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
-- BASCULE DE LECTURE n°1 : militaire_detachement_ici lit desormais le SOCLE.
-- 26 septembre 2026. Aucune regle militaire changee.
--
-- CE QUI DISPARAIT : la duplication OR/EXISTS qui resolvait la presence a la main --
--   soldat stationne  -> sa triade propre comparee a celle de l'acteur
--   soldat accompagnant -> EXISTS sur personnages_donnees du chef
-- Cette logique etait recopiee dans cinq fonctions SQL et deux predicats clients. Elle est
-- remplacee par une jointure laterale sur pnj_position_effective(), primitive unique.
--
-- CE QUI EST PRESERVE A L'IDENTIQUE, et verifie :
--  1) LES RESERVISTES RESTENT INVISIBLES. L'ancienne version ne balayait que data->'sections',
--     jamais data->'reserve'. Le socle, lui, contient les 96. Sans le filtre
--     sm.en_reserve = false, les 72 reservistes de la caserne apparaitraient soudain dans
--     « Personnes presentes » -- une regression majeure et silencieuse. Le filtre est donc
--     explicite, et c'est le point le plus important de cette bascule.
--  2) le regroupement par (pays, compagnie, section, lieutenant, mission) ;
--  3) la degradation pour les detachements etrangers via militaire_degrader ;
--  4) la forme exacte du jsonb rendu, cle par cle.
--
-- LE PARTAGE SOCLE / METIER : le socle repond « qui est ici » ; le blob garde ce qui est
-- purement militaire -- le nom du Lieutenant de la section et sa mission. Ces deux valeurs
-- sont donc toujours lues dans compagnies_militaires, et c'est correct : elles ne sont pas
-- generiques et n'ont rien a faire dans pnj_membres.

CREATE OR REPLACE FUNCTION public.militaire_detachement_ici()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; a record; v_out jsonb := '[]'::jsonb; r record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  FOR r IN
    SELECT m.pays,
           c.id AS compagnie_id,
           sm.section_id,
           sec->>'lieutenantNom' AS lieutenant,
           sec->>'mission'       AS mission,
           count(*)::integer     AS effectif
      FROM public.pnj_membres m
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
      JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
      -- La compagnie et sa section : metier militaire, toujours lu dans le blob.
      JOIN public.compagnies_militaires c
        ON m.id LIKE c.id || '-%'
      LEFT JOIN LATERAL (
        SELECT s FROM jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s
         WHERE s->>'id' = sm.section_id LIMIT 1) j(sec) ON true
     WHERE m.famille = 'soldat'
       AND m.statut  = 'actif'
       AND sm.en_reserve = false          -- <<< les reservistes ne sont pas un detachement
       AND pe.ville       = a.current_city
       AND pe.building_id = a.current_building
       AND pe.room_id     = a.current_room
     GROUP BY 1,2,3,4,5
  LOOP
    IF r.pays = a.country THEN
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'pays', r.pays, 'mien', true, 'compagnie_id', r.compagnie_id,
        'section_id', r.section_id, 'lieutenant', r.lieutenant,
        'mission', r.mission, 'effectif', r.effectif));
    ELSE
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'pays', r.pays, 'mien', false,
        'estime', public.militaire_degrader('proche', r.effectif, r.pays,
                    a.current_city, a.current_building)));
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'detachements', v_out);
END;
$function$;