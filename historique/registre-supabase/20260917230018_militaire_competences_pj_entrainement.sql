-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917230018
-- Nom original      : militaire_competences_pj_entrainement
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 23:00:18 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6302cc3e962c8f3b7b7574b91bfce5e1
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
-- ==========================================================================================
-- COMPETENCES MILITAIRES DES PJ, et entrainement mixte PJ + PNJ
--
-- Les quatre competences sont desormais COMMUNES aux PJ et aux PNJ. Elles sont DISTINCTES des
-- caracteristiques generales : celles-ci representent des aptitudes naturelles, celles-la un
-- apprentissage technique. Elles sont PERSISTANTES -- quitter l'armee ne les efface pas.
--
-- OU LES STOCKER. Aucune colonne de competences n'existait. Les loger dans `stats` aurait
-- melange apprentissage et aptitude, et `qualifications` est un tableau de diplomes jamais ecrit.
-- Une colonne dediee est donc justifiee. Elle n'est PAS exposee par la vue `personnages` : celle-ci
-- porte le masquage de arg/liquide/banque/inventory et la recreer pour un affichage serait un
-- risque disproportionne. La lecture passe par militaire_competences(), ce dont le futur calepin
-- a de toute facon besoin.
--
-- MEME FORME que la `formation` d'un soldat PNJ (memes quatre cles, meme echelle 0..100) : une
-- seule nomenclature pour les deux populations, donc une seule logique d'entrainement.
ALTER TABLE public.personnages_donnees
  ADD COLUMN IF NOT EXISTS competences_militaires jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Lecture publique des competences : c'est une information de carriere, destinee au calepin.
CREATE OR REPLACE FUNCTION public.militaire_competences(p_nom text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $fn$
  SELECT jsonb_build_object(
           'combat_rapproche', coalesce((competences_militaires->>'combat_rapproche')::numeric, 0),
           'tir',              coalesce((competences_militaires->>'tir')::numeric, 0),
           'reconnaissance',   coalesce((competences_militaires->>'reconnaissance')::numeric, 0),
           'secourisme',       coalesce((competences_militaires->>'secourisme')::numeric, 0))
    FROM public.personnages_donnees WHERE name = p_nom;
$fn$;
REVOKE ALL ON FUNCTION public.militaire_competences(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_competences(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.militaire_competences(text) TO authenticated, service_role;

-- ---- Entrainement mixte : PJ ET PNJ progressent, chacun paye ses 6 PA ----
CREATE OR REPLACE FUNCTION public.militaire_entrainer_section(
  p_compagnie_id text, p_section_id text, p_stat text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  c_max     constant integer := 12;
  c_pa      constant integer := 6;
  c_gain    constant integer := 3;
  c_plafond constant integer := 100;
  g record; v_sec jsonb; v_sols jsonb; v_pa_chef integer;
  v_elus_pnj jsonb; v_elus_pj jsonb; v_n integer; v_nom text;
BEGIN
  IF p_stat NOT IN ('combat_rapproche','tir','reconnaissance','secourisme') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'domaine_invalide', 'domaine', p_stat);
  END IF;

  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  SELECT coalesce(pa, 0) INTO v_pa_chef FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;
  IF v_pa_chef < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_chef_insuffisants',
                              'requis', c_pa, 'pa_reel', v_pa_chef);
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;

  -- SELECTION COMMUNE PJ + PNJ : les moins formes d'abord dans ce domaine, jusqu'a 12 au total.
  -- Ne participent que ceux qui ont REELLEMENT leurs 6 PA -- les PA d'un PNJ vivent dans le blob,
  -- ceux d'un PJ sur sa fiche. Personne n'est debite sans progresser, ni l'inverse.
  CREATE TEMP TABLE IF NOT EXISTS pg_temp_elus (nom text, matricule text, est_pj boolean, niveau numeric) ON COMMIT DROP;
  DELETE FROM pg_temp_elus;

  INSERT INTO pg_temp_elus (nom, matricule, est_pj, niveau)
  SELECT NULL, sol->>'matricule', false, coalesce((sol->'formation'->>p_stat)::numeric, 0)
    FROM jsonb_array_elements(v_sols) sol
   WHERE NOT coalesce((sol->>'pj')::boolean, false)
     AND coalesce((sol->>'pa')::numeric, 0) >= c_pa
     AND coalesce(sol->>'matricule', '') <> ''
  UNION ALL
  SELECT pd.name, NULL, true, coalesce((pd.competences_militaires->>p_stat)::numeric, 0)
    FROM jsonb_array_elements(v_sols) sol
    JOIN public.personnages_donnees pd ON pd.name = sol->>'nom'
   WHERE coalesce((sol->>'pj')::boolean, false) AND coalesce(pd.pa, 0) >= c_pa;

  DELETE FROM pg_temp_elus WHERE ctid NOT IN (
    SELECT ctid FROM pg_temp_elus ORDER BY niveau, coalesce(matricule, nom) LIMIT c_max);

  SELECT count(*) INTO v_n FROM pg_temp_elus;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_soldat_en_etat', 'pa_requis', c_pa);
  END IF;

  SELECT coalesce(jsonb_agg(matricule), '[]'::jsonb) INTO v_elus_pnj FROM pg_temp_elus WHERE NOT est_pj;
  SELECT coalesce(jsonb_agg(nom), '[]'::jsonb)       INTO v_elus_pj  FROM pg_temp_elus WHERE est_pj;

  -- PNJ : debit et gain dans la meme ecriture du blob.
  SELECT coalesce(jsonb_agg(
           CASE WHEN v_elus_pnj ? (sol->>'matricule')
                THEN sol || jsonb_build_object('pa', coalesce((sol->>'pa')::numeric, 0) - c_pa)
                         || jsonb_build_object('formation',
                              coalesce(CASE WHEN jsonb_typeof(sol->'formation') = 'object'
                                            THEN sol->'formation' END, '{}'::jsonb)
                              || jsonb_build_object(p_stat, least(c_plafond,
                                   coalesce((sol->'formation'->>p_stat)::numeric, 0) + c_gain)))
                ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  -- PJ participants : leurs PA sont sur leur fiche, leurs competences dans la colonne dediee.
  FOR v_nom IN SELECT nom FROM pg_temp_elus WHERE est_pj LOOP
    UPDATE public.personnages_donnees
       SET pa = greatest(0, coalesce(pa, 0) - c_pa),
           competences_militaires = coalesce(competences_militaires, '{}'::jsonb)
             || jsonb_build_object(p_stat, least(c_plafond,
                  coalesce((competences_militaires->>p_stat)::numeric, 0) + c_gain))
     WHERE name = v_nom;
  END LOOP;

  -- Le Lieutenant paie sa seance. Un debit, jamais une remise a une valeur pleine.
  UPDATE public.personnages_donnees SET pa = v_pa_chef - c_pa WHERE name = g.o_moi;

  RETURN jsonb_build_object('ok', true, 'domaine', p_stat, 'progresses', v_n,
    'pnj', jsonb_array_length(v_elus_pnj), 'pj', jsonb_array_length(v_elus_pj),
    'gain', c_gain, 'plafond', c_plafond, 'pa_soldat', c_pa, 'pa_chef', c_pa,
    'pa_restants_chef', v_pa_chef - c_pa, 'matricules', v_elus_pnj, 'joueurs', v_elus_pj);
END;
$fn$;