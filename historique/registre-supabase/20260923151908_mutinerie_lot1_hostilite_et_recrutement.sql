-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260923151908
-- Nom original      : mutinerie_lot1_hostilite_et_recrutement
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-23 15:19:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : c1217e03fd979b42e61bf5de58850584
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
CREATE OR REPLACE FUNCTION public.militaire_camps_hostiles(p_bataille_id bigint, p_camp text)
RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT coalesce(array_agg(DISTINCT e.camp), '{}')
    FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id
     AND e.sorti_round IS NULL
     AND e.camp IS DISTINCT FROM p_camp
     AND ( EXISTS (SELECT 1 FROM public.guerres g
                    WHERE g.statut = 'active'
                      AND ((g.data->>'attaquant' = p_camp AND g.data->>'attaque'  = e.camp)
                        OR (g.data->>'attaque'  = p_camp AND g.data->>'attaquant' = e.camp)))
        OR ( public.mutinerie_pays_du_camp(p_camp) = public.mutinerie_pays_du_camp(e.camp)
             AND (public.mutinerie_est_camp(p_camp) OR public.mutinerie_est_camp(e.camp)) ) );
$function$;

CREATE OR REPLACE FUNCTION public.militaire_bataille_recruter(
  p_bataille_id bigint, p_camp text, p_ville text, p_bat text, p_piece text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE v_mutin boolean; v_pays text;
BEGIN
  v_mutin := public.mutinerie_est_camp(p_camp);
  v_pays  := public.mutinerie_pays_du_camp(p_camp);

  INSERT INTO public.batailles_engagements
    (bataille_id, camp, personnage, compagnie_id, section_id, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, pd.name, sm.compagnie_id, sm.section_id, sm.grade, pd.pa,
         p_camp || '|' || coalesce(sm.compagnie_id, 'solo') || ':' || coalesce(sm.section_id, pd.name)
    FROM public.personnages_donnees pd
    JOIN public.services_militaires sm ON sm.personnage = pd.name AND sm.fin_ts IS NULL
   WHERE pd.current_city = p_ville AND pd.current_building = p_bat AND pd.current_room = p_piece
     AND coalesce(pd.pa, 0) > 0
     AND pd.country = v_pays
     AND CASE WHEN v_mutin THEN public.mutinerie_camp_de(pd.name) = p_camp
                           ELSE public.mutinerie_camp_de(pd.name) IS NULL END
  ON CONFLICT DO NOTHING;

  INSERT INTO public.batailles_engagements
    (bataille_id, camp, compagnie_id, section_id, matricule, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, c.id, s->>'id', sol->>'matricule', 'soldat',
         (sol->>'pa')::integer, p_camp || '|' || c.id || ':' || (s->>'id')
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE c.data->>'pays' = v_pays
     AND NOT coalesce((sol->>'pj')::boolean, false)
     AND coalesce((sol->>'pa')::integer, 0) > 0
     AND CASE WHEN v_mutin THEN sol->>'mutin' = p_camp ELSE (sol->>'mutin') IS NULL END
     AND ((sol->>'ville' = p_ville AND sol->>'buildingId' = p_bat AND sol->>'roomId' = p_piece
           AND (sol->>'leaderCourant') IS NULL)
       OR EXISTS (SELECT 1 FROM public.personnages_donnees chef
                   WHERE chef.name = sol->>'leaderCourant' AND chef.current_city = p_ville
                     AND chef.current_building = p_bat AND chef.current_room = p_piece))
  ON CONFLICT DO NOTHING;
END;
$function$;