-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260925071840
-- Nom original      : militaire_detachement_ici_presence_effective
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-25 07:18:40 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3f3beb5bbbd5d256c70f47c34e157523
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
-- PRESENCE EFFECTIVE D'UN DETACHEMENT (25 septembre 2026, arbitrage GD).
--
-- LA REGLE : dans « Personnes presentes », personne de physiquement present n'est cache. Une
-- unite qui accompagne un personnage est presente LA OU EST CE PERSONNAGE. Pas de furtivite
-- implicite des detachements accompagnants.
--
-- CE QUI N'ALLAIT PAS. Cette fonction n'enumerait que les soldats STATIONNES : elle exigeait
-- `leaderCourant IS NULL` ET l'egalite des trois champs de position. Or militaire_recuperer_soldats
-- pose justement `leaderCourant = <officier>` et met ville/buildingId/roomId a NULL -- un
-- detachement recupere etait donc exclu DEUX FOIS, et restait invisible dans toutes les pieces, y
-- compris celle de son propre officier.
--
-- LA CORRECTION. On resout la position : propre si le soldat est pose, celle de son chef s'il
-- accompagne. Ce n'est pas une invention -- c'est la forme deja employee par
-- militaire_bataille_recruter et mutinerie_camps_presents, et c'est exactement ce que fait
-- agent_position_effective() pour les agents de renseignement (meme famille de defaut, corrigee
-- cote agents le 22 septembre 2026).
--
-- AUCUNE RECOPIE DE POSITION : rien n'est reecrit sur les soldats quand leur chef bouge. Un
-- deplacement d'officier, c'est zero ecriture ; la resolution se fait a la lecture.
--
-- PAS DE DOUBLE COMPTE : les deux branches sont mutuellement exclusives, la premiere exigeant
-- `leaderCourant IS NULL` et la seconde une egalite sur `leaderCourant`.
--
-- LE NIVEAU D'INFORMATION NE CHANGE PAS : troupe etrangere toujours degradee par
-- militaire_degrader, effectif exact et mission reserves a ses propres troupes.
CREATE OR REPLACE FUNCTION public.militaire_detachement_ici()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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
    SELECT c.data->>'pays' AS pays, c.id AS compagnie_id, s->>'id' AS section_id,
           s->>'lieutenantNom' AS lieutenant, s->>'mission' AS mission,
           count(*)::integer AS effectif
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE (
             -- Soldat STATIONNE : sa propre position fait foi.
             (sol->>'leaderCourant') IS NULL
             AND sol->>'ville'      = a.current_city
             AND sol->>'buildingId' = a.current_building
             AND sol->>'roomId'     = a.current_room
           )
        OR (
             -- Soldat ACCOMPAGNANT : il est la ou est son chef.
             (sol->>'leaderCourant') IS NOT NULL
             AND EXISTS (SELECT 1 FROM public.personnages_donnees chef
                          WHERE chef.name             = sol->>'leaderCourant'
                            AND chef.current_city     = a.current_city
                            AND chef.current_building = a.current_building
                            AND chef.current_room     = a.current_room)
           )
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