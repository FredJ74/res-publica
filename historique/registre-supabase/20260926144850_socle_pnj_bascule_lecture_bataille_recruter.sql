-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926144850
-- Nom original      : socle_pnj_bascule_lecture_bataille_recruter
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 14:48:50 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 69879f558e662bbd140f03bbc7de7536
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
-- BASCULE DE LECTURE : militaire_bataille_recruter lit le socle. 26 septembre 2026.
--
-- SEMANTIQUE CONSERVEE : « inscrire dans une bataille tous les combattants d'un camp presents
-- dans cette piece ». Deux INSERT distincts, celui des PJ en service (inchange, il lit
-- personnages_donnees) et celui des SOLDATS PNJ (bascule ici).
--
-- Cette fonction ECRIT batailles_engagements, jamais le blob : basculer sa source de lecture
-- ne peut donc creer aucune divergence blob/socle.
--
-- FILTRES METIER CONSERVES :
--   * SECTIONS SEULEMENT -- `en_reserve = false`. Sans lui, les 72 reservistes de la caserne
--     seraient enroles dans toute bataille livree a la caserne. Verifie : 24 avec le filtre,
--     96 sans.
--   * NOT pj -- structurel dans le socle, qui ne contient que des PNJ.
--   * pa > 0 -- un mort ne combat pas.
--   * appartenance au camp : si le camp est un camp mutin, le soldat doit porter EXACTEMENT ce
--     camp dans mutin ; sinon mutin doit etre NULL (il est loyal). Conserve tel quel, d'ou
--     l'ajout de mutin a la table metier.
--   * presence : stationne ici, ou accompagnant un chef qui est ici.
--   * groupe_id, grade 'soldat', pa_initial : forme de l'engagement inchangee.

CREATE OR REPLACE FUNCTION public.militaire_bataille_recruter(
  p_bataille_id bigint, p_camp text, p_ville text, p_bat text, p_piece text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_mutin boolean; v_pays text;
BEGIN
  v_mutin := public.mutinerie_est_camp(p_camp);
  v_pays  := public.mutinerie_pays_du_camp(p_camp);

  -- Branche PJ : inchangee.
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

  -- Branche SOLDATS PNJ : lit desormais le socle.
  INSERT INTO public.batailles_engagements
    (bataille_id, camp, compagnie_id, section_id, matricule, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, cm.id, sm.section_id, sm.matricule, 'soldat',
         m.pa, p_camp || '|' || cm.id || ':' || sm.section_id
    FROM public.pnj_membres m
    JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
    JOIN public.compagnies_militaires cm ON m.id LIKE cm.id || '-%'
    JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
   WHERE m.famille = 'soldat'
     AND m.statut  = 'actif'
     AND sm.en_reserve = false
     AND m.pays = v_pays
     AND coalesce(m.pa, 0) > 0
     AND CASE WHEN v_mutin THEN sm.mutin = p_camp ELSE sm.mutin IS NULL END
     AND pe.ville = p_ville AND pe.building_id = p_bat AND pe.room_id = p_piece
  ON CONFLICT DO NOTHING;
END;
$function$;