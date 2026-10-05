-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918162024
-- Nom original      : combat_actions_photo_complete
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 16:20:24 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 49df0fa3faf58ae184279e01b6f2b343
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
-- La version precedente rappelait militaire_bataille_combattants DEUX FOIS par attaquant pour
-- relire la competence defensive de la cible -- soit 50 relectures du document de compagnie par
-- passe de 25 hommes. La photo embarque desormais aussi les deux competences : un seul appel par
-- passe, et la cible est lue exactement dans l'etat photographie, ce qui est la definition meme
-- de la simultaneite.
CREATE OR REPLACE FUNCTION public.militaire_bataille_actions(
  p_bataille_id bigint, p_camp_att text, p_camp_def text, p_round integer)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_res jsonb := '[]'::jsonb;
  a record; k integer; n integer;
  d_eng bigint[]; d_pj boolean[]; d_nom text[]; d_cie text[]; d_sec text[]; d_mat text[];
  d_per numeric[]; d_dup numeric[]; d_tir numeric[]; d_cac numeric[];
  v_mode text; v_taux integer; v_jet integer; v_degre text;
BEGIN
  SELECT array_agg(c.eng_id ORDER BY c.eng_id), array_agg(c.est_pj ORDER BY c.eng_id),
         array_agg(c.nom ORDER BY c.eng_id), array_agg(c.compagnie_id ORDER BY c.eng_id),
         array_agg(c.section_id ORDER BY c.eng_id), array_agg(c.matricule ORDER BY c.eng_id),
         array_agg(c.def_per ORDER BY c.eng_id), array_agg(c.def_dup ORDER BY c.eng_id),
         array_agg(c.comp_tir ORDER BY c.eng_id), array_agg(c.comp_cac ORDER BY c.eng_id)
    INTO d_eng, d_pj, d_nom, d_cie, d_sec, d_mat, d_per, d_dup, d_tir, d_cac
    FROM public.militaire_bataille_combattants(p_bataille_id, p_camp_def) c;
  n := coalesce(array_length(d_eng, 1), 0);
  IF n = 0 THEN RETURN v_res; END IF;

  FOR a IN
    SELECT * FROM public.militaire_bataille_combattants(p_bataille_id, p_camp_att)
     WHERE saute_round IS DISTINCT FROM p_round
  LOOP
    -- UN TIRAGE PAR ATTAQUANT, evalue a chaque tour de boucle.
    k := 1 + floor(random() * n)::integer;
    v_mode := CASE WHEN a.arme_feu THEN 'feu' ELSE 'cac' END;
    -- La competence qui DEFEND est celle du meme domaine que l'attaque subie : on ne se protege
    -- pas d'une balle avec son corps-a-corps.
    v_taux := public.militaire_taux_combat(
      CASE WHEN a.arme_feu THEN a.comp_tir ELSE a.comp_cac END,
      CASE WHEN a.arme_feu THEN d_tir[k]   ELSE d_cac[k]   END,
      CASE WHEN a.arme_feu THEN d_per[k]   ELSE d_dup[k]   END);
    v_jet := floor(random() * 100)::integer + 1;
    v_degre := public.militaire_degre_combat(v_taux, v_jet);

    v_res := v_res || jsonb_build_array(jsonb_build_object(
      'camp_attaquant', p_camp_att,
      'att_eng', a.eng_id, 'att_pj', a.est_pj, 'att_nom', a.nom, 'att_mat', a.matricule,
      'cib_eng', d_eng[k], 'cib_pj', d_pj[k], 'cib_nom', d_nom[k], 'cib_mat', d_mat[k],
      'cib_cie', d_cie[k], 'cib_sec', d_sec[k], 'cib_camp', p_camp_def,
      'mode', v_mode, 'taux', v_taux, 'jet', v_jet, 'degre', v_degre,
      'degats', public.militaire_degats_combat(v_degre)));
  END LOOP;
  RETURN v_res;
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_bataille_actions(bigint, text, text, integer) FROM PUBLIC, anon, authenticated;