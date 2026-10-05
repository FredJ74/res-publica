-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918080645
-- Nom original      : militaire_calepin_decorations
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 08:06:45 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 5468f69c949fb487b640ae6f783976b1
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
-- Le calepin porte aussi les decorations recues. Toujours une PROJECTION : rien n'y est stocke.
CREATE OR REPLACE FUNCTION public.militaire_calepin()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_moi text; v_periodes jsonb; v_total integer; v_comp jsonb;
  v_grade text; v_du integer; v_pays text; v_deco jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'),
         CASE WHEN jsonb_typeof(competences_militaires)='object' THEN competences_militaires ELSE '{}'::jsonb END
    INTO v_pays, v_comp FROM public.personnages_donnees WHERE name = v_moi;

  SELECT coalesce(jsonb_agg(p ORDER BY p_debut DESC), '[]'::jsonb), coalesce(sum(p_jours), 0)
    INTO v_periodes, v_total
    FROM (
      SELECT sm.debut_ts AS p_debut,
             greatest(1, (coalesce(sm.fin_ts, now())::date - sm.debut_ts::date) + 1) AS p_jours,
             jsonb_build_object(
               'grade', sm.grade, 'pays', sm.pays,
               'compagnie', sm.compagnie_id, 'section', sm.section_id,
               'debut', sm.debut_ts::date, 'fin', sm.fin_ts::date,
               'en_cours', sm.fin_ts IS NULL,
               'jours', greatest(1, (coalesce(sm.fin_ts, now())::date - sm.debut_ts::date) + 1)) AS p
        FROM public.services_militaires sm
       WHERE sm.personnage = v_moi) t;

  SELECT sm.grade INTO v_grade FROM public.services_militaires sm
   WHERE sm.personnage = v_moi AND sm.fin_ts IS NULL ORDER BY sm.debut_ts DESC LIMIT 1;

  SELECT coalesce(sum(greatest(0, coalesce(s.du,0) - coalesce(s.verse,0))), 0)::integer INTO v_du
    FROM public.soldes_militaires s WHERE s.personnage = v_moi;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'niveau', d.niveau, 'intitule', d.intitule, 'citation', d.citation,
           'decerne_par', d.decerne_par, 'poste', d.poste_decernant,
           'le', d.decerne_le::date) ORDER BY d.decerne_le DESC), '[]'::jsonb)
    INTO v_deco FROM public.decorations_militaires d WHERE d.decore = v_moi;

  RETURN jsonb_build_object('ok', true, 'nom', v_moi, 'pays', v_pays,
    'grade_courant', v_grade, 'en_service', v_grade IS NOT NULL,
    'jours_total', v_total, 'periodes', v_periodes, 'decorations', v_deco,
    'competences', jsonb_build_object(
      'combat_rapproche', coalesce((v_comp->>'combat_rapproche')::integer, 0),
      'tir',             coalesce((v_comp->>'tir')::integer, 0),
      'reconnaissance',  coalesce((v_comp->>'reconnaissance')::integer, 0),
      'secourisme',      coalesce((v_comp->>'secourisme')::integer, 0)),
    'arrieres_dus', v_du);
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_calepin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_calepin() TO authenticated;