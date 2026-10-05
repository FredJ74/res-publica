-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918072955
-- Nom original      : militaire_equiper_accessoire_pnj
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 07:29:55 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6742252e71900862d19c6de2dff2e447
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
-- ACCESSOIRES DES SOLDATS PNJ : un objet REEL qui se deplace, jamais un drapeau
--
-- CIRCUIT : inventaire du Lieutenant -> soldat.accessoires, et l'inverse pour desequiper.
-- Aucune creation, aucune destruction, aucune copie. L'objet conserve son identite complete --
-- donc son id, son lot, et tout etat futur comme le « fragilise » du gilet.
--
-- AUTORITE STRUCTURELLE SEULEMENT : le Lieutenant de CETTE section. Un soldat PJ temporairement
-- leader d'un groupe n'acquiert PAS ce droit -- leaderCourant est une autorite operationnelle, et
-- militaire_section_de_moi ne reconnait que le Lieutenant. La juridiction est verifiee au passage.
--
-- GENERIQUE : la fonction ne connait aucun accessoire en particulier. Elle deplace l'objet que le
-- Lieutenant designe. Radio, tente, jumelles, tenue de camouflage, gilet, ration, trousse passent
-- par le meme chemin -- il n'y a pas sept systemes a maintenir.
-- ==========================================================================================
CREATE OR REPLACE FUNCTION public.militaire_equiper_accessoire(
  p_compagnie_id text, p_section_id text, p_matricule text, p_objet_id text, p_sens text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  c_plafond constant integer := 100;
  g record; v_sec jsonb; v_sols jsonb; v_inv jsonb; v_occupe numeric;
  v_objet jsonb; v_pos integer; v_acc jsonb; v_trouve boolean := false;
BEGIN
  IF coalesce(p_sens,'') NOT IN ('equiper','desequiper') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;
  IF coalesce(btrim(coalesce(p_matricule,'')),'') = '' OR coalesce(btrim(coalesce(p_objet_id,'')),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- AUTORITE : Lieutenant structurel de cette section, meme empire. Verrouille la compagnie.
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;

  -- Le soldat vise doit exister, etre un PNJ, et porter ce matricule.
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_sols) sol
                  WHERE NOT coalesce((sol->>'pj')::boolean,false)
                    AND sol->>'matricule' = p_matricule) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable', 'matricule', p_matricule);
  END IF;

  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;

  IF p_sens = 'equiper' THEN
    -- L'objet doit REELLEMENT etre dans l'inventaire du Lieutenant. Pas de drapeau, pas de copie.
    SELECT i, pos INTO v_objet, v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
     WHERE i->>'id' = p_objet_id LIMIT 1;
    IF v_objet IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent_de_l_inventaire');
    END IF;
    -- Il quitte l'inventaire...
    SELECT coalesce(jsonb_agg(i ORDER BY pos), '[]'::jsonb) INTO v_inv
      FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos) WHERE pos <> v_pos;
    -- ...et rejoint le soldat, entier.
    SELECT coalesce(jsonb_agg(
             CASE WHEN NOT coalesce((sol->>'pj')::boolean,false) AND sol->>'matricule' = p_matricule
                  THEN sol || jsonb_build_object('accessoires',
                         (CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                               THEN sol->'accessoires' ELSE '[]'::jsonb END) || jsonb_build_array(v_objet))
                  ELSE sol END ORDER BY pos), '[]'::jsonb)
      INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);
    v_trouve := true;

  ELSE
    -- Desequiper : l'objet doit reellement etre porte par ce soldat.
    SELECT a INTO v_objet
      FROM jsonb_array_elements(v_sols) sol,
           jsonb_array_elements(CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                                     THEN sol->'accessoires' ELSE '[]'::jsonb END) a
     WHERE NOT coalesce((sol->>'pj')::boolean,false) AND sol->>'matricule' = p_matricule
       AND a->>'id' = p_objet_id LIMIT 1;
    IF v_objet IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'objet_non_porte');
    END IF;

    SELECT coalesce(sum(greatest(1, coalesce((i->>'qty')::numeric, (i->>'encombrement')::numeric, 1))), 0)
      INTO v_occupe FROM jsonb_array_elements(v_inv) i;
    IF v_occupe + 1 > c_plafond THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'plafond', c_plafond);
    END IF;

    SELECT coalesce(jsonb_agg(
             CASE WHEN NOT coalesce((sol->>'pj')::boolean,false) AND sol->>'matricule' = p_matricule
                  THEN sol || jsonb_build_object('accessoires', (
                         SELECT coalesce(jsonb_agg(a ORDER BY ap), '[]'::jsonb)
                           FROM jsonb_array_elements(CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                                                          THEN sol->'accessoires' ELSE '[]'::jsonb END)
                                WITH ORDINALITY AS ta(a, ap)
                          WHERE a->>'id' <> p_objet_id))
                  ELSE sol END ORDER BY pos), '[]'::jsonb)
      INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);
    v_inv := v_inv || jsonb_build_array(v_objet);
    v_trouve := true;
  END IF;

  IF NOT v_trouve THEN RETURN jsonb_build_object('ok', false, 'raison', 'operation_impossible'); END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = g.o_moi;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'matricule', p_matricule,
    'objet', v_objet->>'name', 'produit', v_objet->>'produitMilitaire', 'objet_id', p_objet_id);
END;
$fn$;
REVOKE ALL ON FUNCTION public.militaire_equiper_accessoire(text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_equiper_accessoire(text,text,text,text,text) TO authenticated, service_role;