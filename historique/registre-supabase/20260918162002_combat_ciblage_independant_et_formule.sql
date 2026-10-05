-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918162002
-- Nom original      : combat_ciblage_independant_et_formule
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 16:20:02 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f0bcdeb0d8d51dbe158dc90d520ec233
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
-- =========================================================================================
-- 1. CORRECTIF DU TIRAGE DE CIBLE (20 septembre 2026)
-- =========================================================================================
-- L'ancienne version utilisait :
--   CROSS JOIN LATERAL (SELECT d.* FROM militaire_bataille_combattants(...) d
--                        ORDER BY random() LIMIT 1) c
-- Cette sous-requete ne reference PAS la ligne attaquante et porte sur une fonction STABLE :
-- PostgreSQL l'a donc evaluee UNE SEULE FOIS et a reutilise la meme cible pour tous les
-- attaquants de la passe. Mesure sur 25 attaquants : 21 jets distincts mais UNE seule cible.
-- Les des etaient bien independants, la cible ne l'etait pas -- contraire au GD, et enorme
-- gaspillage par surtuage (une bataille 25v25 durait ~45 rounds au lieu de ~30).
--
-- La fonction devient du plpgsql avec une boucle explicite : les defenseurs sont photographies
-- UNE fois dans des tableaux, puis CHAQUE attaquant tire son propre indice. Aucune liberte n'est
-- laissee au planificateur, et un lecteur voit immediatement que le tirage est par attaquant.
-- Les doublons naturels restent possibles -- plusieurs attaquants peuvent tomber sur le meme
-- homme -- mais plus aucun tirage n'est partage.
--
-- Aucun biais de cible : le tableau est construit dans l'ordre du roster, sans distinction PJ /
-- PNJ / leader, et l'indice est uniforme sur tout l'effectif adverse operationnel.

-- =========================================================================================
-- 2. NOUVELLE FORMULE (20 septembre 2026)
-- =========================================================================================
--   T = clamp(25 + competence_offensive x 0,7
--                - competence_defensive_cible x 0,5
--                - PER_ou_DUP_cible x 0,5, 10, 85)
--
-- La competence militaire intervient desormais EN ATTAQUE ET EN DEFENSE : un combattant
-- entraine est a la fois plus dangereux et plus difficile a atteindre. PER/DUP reste une aptitude
-- generale secondaire -- meme coefficient 0,5, mais sur une amplitude cinq fois plus petite
-- (5 a 20 contre 0 a 100), donc la competence domine la defense sans ecraser la caracteristique.
--
-- Calibrage mesure sur banc (simulateur en memoire, tirage de cible independant, 2000 batailles) :
-- 10 elites competence 80 contre 25 recrues competence 20 -> 74,40 % de victoires pour les
-- elites, marge 95 % de +/-1,91 point. Cible GD : 70-75 %.
-- Les coefficients voisins donnaient 60 % (def 0,35), 71,3 % (def 0,45) et 89,5 % (def 0,7).
--
-- INCHANGES : de 1..100, clamp 10-85, cinq degres, degats 3/2/1, echec critique 96-100 teste
-- en premier.
DROP FUNCTION IF EXISTS public.militaire_taux_combat(numeric, numeric);

CREATE OR REPLACE FUNCTION public.militaire_taux_combat(
  p_comp_off numeric, p_comp_def numeric, p_stat_def numeric)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT greatest(10, least(85, round(
    25 + coalesce(p_comp_off, 0) * 0.7
       - coalesce(p_comp_def, 0) * 0.5
       - coalesce(p_stat_def, 0) * 0.5)::integer));
$$;
REVOKE ALL ON FUNCTION public.militaire_taux_combat(numeric, numeric, numeric) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.militaire_bataille_actions(
  p_bataille_id bigint, p_camp_att text, p_camp_def text, p_round integer)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_res jsonb := '[]'::jsonb;
  a record; k integer; n integer;
  d_eng bigint[]; d_pj boolean[]; d_nom text[]; d_cie text[]; d_sec text[]; d_mat text[];
  d_per numeric[]; d_dup numeric[];
  v_mode text; v_taux integer; v_jet integer; v_degre text;
BEGIN
  -- PHOTO DES DEFENSEURS, prise UNE fois. Les jets et les cibles sont ensuite tires par
  -- attaquant, sur cette meme photo : c'est ce qui rend le round simultane.
  SELECT array_agg(c.eng_id ORDER BY c.eng_id), array_agg(c.est_pj ORDER BY c.eng_id),
         array_agg(c.nom ORDER BY c.eng_id), array_agg(c.compagnie_id ORDER BY c.eng_id),
         array_agg(c.section_id ORDER BY c.eng_id), array_agg(c.matricule ORDER BY c.eng_id),
         array_agg(c.def_per ORDER BY c.eng_id), array_agg(c.def_dup ORDER BY c.eng_id)
    INTO d_eng, d_pj, d_nom, d_cie, d_sec, d_mat, d_per, d_dup
    FROM public.militaire_bataille_combattants(p_bataille_id, p_camp_def) c;
  n := coalesce(array_length(d_eng, 1), 0);
  IF n = 0 THEN RETURN v_res; END IF;

  FOR a IN
    SELECT * FROM public.militaire_bataille_combattants(p_bataille_id, p_camp_att)
     WHERE saute_round IS DISTINCT FROM p_round
  LOOP
    -- UN TIRAGE PAR ATTAQUANT. random() est evalue a chaque tour de boucle, dans une instruction
    -- distincte : aucun partage possible, et les doublons naturels restent permis.
    k := 1 + floor(random() * n)::integer;
    v_mode := CASE WHEN a.arme_feu THEN 'feu' ELSE 'cac' END;
    v_taux := public.militaire_taux_combat(
      CASE WHEN a.arme_feu THEN a.comp_tir ELSE a.comp_cac END,
      -- La competence qui DEFEND est celle du meme domaine que l'attaque subie.
      CASE WHEN a.arme_feu THEN (SELECT comp_tir FROM public.militaire_bataille_combattants(p_bataille_id, p_camp_def) WHERE eng_id = d_eng[k])
                           ELSE (SELECT comp_cac FROM public.militaire_bataille_combattants(p_bataille_id, p_camp_def) WHERE eng_id = d_eng[k]) END,
      CASE WHEN a.arme_feu THEN d_per[k] ELSE d_dup[k] END);
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