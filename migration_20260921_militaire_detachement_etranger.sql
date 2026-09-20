-- =====================================================================================
-- LOT DU 21 SEPTEMBRE 2026 : DETACHEMENT ETRANGER PRESENT DANS UNE PIECE
-- =====================================================================================
-- OBJET DU LOT. Un detachement etranger reellement present dans une piece etait invisible :
-- la lecture des compagnies etait bornee au pays du joueur, et aucune mission ne se
-- declenchait donc a son contact. La RPC militaire_detachement_ici rend desormais une
-- PROJECTION, sous les regles deja en vigueur dans le projet :
--   * troupe de MON pays  -> effectif exact et mission visible ;
--   * troupe ETRANGERE    -> effectif DEGRADE par public.militaire_degrader, comme le font
--     deja militaire_observer et militaire_entree_zone, et mission JAMAIS revelee.
--
-- MIGRATION ABSORBEE :
--   20260920231602  militaire_detachement_present_toutes_forces
--
-- AVERTISSEMENT. Ce fichier est un VERSIONNEMENT a posteriori : la migration ci-dessus a
-- deja ete appliquee en production le 21 septembre 2026. Le fichier reproduit l'enchainement
-- REELLEMENT applique, le bloc etant recopie caractere pour caractere depuis
-- supabase_migrations.schema_migrations. Ne pas le corriger : il doit rester le reflet
-- fidele de ce qui tourne.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- MIGRATION 20260920231602  militaire_detachement_present_toutes_forces
-- -------------------------------------------------------------------------------------
-- =====================================================================
-- DETACHEMENT PRESENT DANS UNE PIECE — toutes forces, pas seulement les siennes
-- =====================================================================
-- BUG D'AUDIT. getAffichageDetachementPiece appelait sbGetCompagnies(pays)
-- avec le pays du JOUEUR : un detachement etranger reellement present dans
-- la piece etait invisible, et ne declenchait donc aucune mission.
--
-- Depuis la fermeture des lectures de compagnies, le client ne PEUT plus
-- voir que les siennes : la correction ne peut plus etre cote navigateur.
-- Cette RPC rend la projection, sous les REGLES EXISTANTES du projet :
--   * detachement de MON pays        -> effectif exact, mission visible ;
--   * detachement ETRANGER           -> effectif DEGRADE par militaire_degrader,
--     exactement comme le font deja militaire_observer et militaire_entree_zone,
--     et sa mission n'est jamais revelee.
-- Aucune regle diplomatique nouvelle : on ne dit pas si l'etranger est hostile,
-- on dit seulement qu'une troupe est la.
CREATE OR REPLACE FUNCTION public.militaire_detachement_ici()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE
  v_moi text; a record; v_out jsonb := '[]'::jsonb; r record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  FOR r IN
    SELECT c.data->>'pays' AS pays, c.id AS compagnie_id, s->>'id' AS section_id,
           s->>'lieutenantNom' AS lieutenant, s->>'mission' AS mission,
           count(*)::integer AS effectif
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE sol->>'ville' = a.current_city
       AND sol->>'buildingId' = a.current_building
       AND sol->>'roomId' = a.current_room
       AND (sol->>'leaderCourant') IS NULL
     GROUP BY 1,2,3,4,5
  LOOP
    IF r.pays = a.country THEN
      -- Mes propres troupes : je les vois telles qu'elles sont.
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'pays', r.pays, 'mien', true, 'compagnie_id', r.compagnie_id,
        'section_id', r.section_id, 'lieutenant', r.lieutenant,
        'mission', r.mission, 'effectif', r.effectif));
    ELSE
      -- Troupe etrangere : meme degradation que la reconnaissance. Ni effectif
      -- exact, ni mission, ni identite d'officier.
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'pays', r.pays, 'mien', false,
        'estime', public.militaire_degrader('proche', r.effectif, r.pays,
                    a.current_city, a.current_building)));
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'detachements', v_out);
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_detachement_ici() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_detachement_ici() TO authenticated, service_role;
