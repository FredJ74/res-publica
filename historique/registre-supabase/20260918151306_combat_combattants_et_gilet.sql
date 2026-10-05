-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918151306
-- Nom original      : combat_combattants_et_gilet
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 15:13:06 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4addb1d4c3910b1f0fcb4f75c1076b8e
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
-- LECTURE DES COMBATTANTS D'UN CAMP (19 septembre 2026)
-- =========================================================================================
-- Tout est relu A LA SOURCE CANONIQUE a chaque appel : les PA d'un PJ dans personnages_donnees,
-- ceux d'un PNJ dans sections[].soldats[]. Le roster de bataille (batailles_engagements) ne dit
-- QUE qui participe et qui est sorti -- jamais combien de PA il lui reste. Aucune copie d'etat.
CREATE OR REPLACE FUNCTION public.militaire_bataille_combattants(p_bataille_id bigint, p_camp text)
RETURNS TABLE (
  eng_id bigint, est_pj boolean, nom text,
  compagnie_id text, section_id text, matricule text,
  pa integer, comp_tir numeric, comp_cac numeric, arme_feu boolean,
  def_per numeric, def_dup numeric, saute_round integer
) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  -- PJ : competences militaires, PA et defense lus sur sa fiche ; arme a feu lue dans son
  -- inventaire reel (aucun equipement abstrait de combat n'est cree).
  SELECT e.id, true, e.personnage, e.compagnie_id, e.section_id, NULL::text,
         greatest(0, coalesce(pd.pa, 0)),
         coalesce((pd.competences_militaires->>'tir')::numeric, 0),
         coalesce((pd.competences_militaires->>'combat_rapproche')::numeric, 0),
         EXISTS (SELECT 1 FROM jsonb_array_elements(
                   CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
                  WHERE i->>'type' = 'arme' AND i->>'sousType' IN ('poing','carabine')),
         public.assemblee_stat_base(pd.stats, 'PER'),
         public.assemblee_stat_base(pd.stats, 'DUP'),
         e.saute_round
    FROM public.batailles_engagements e
    JOIN public.personnages_donnees pd ON pd.name = e.personnage
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.personnage IS NOT NULL AND e.sorti_round IS NULL

  UNION ALL

  -- PNJ : PA et formation lus dans la compagnie ; categorie d'arme reelle (militaire_equiper_soldat).
  -- La defense passe par militaire_defense_pnj, seul endroit ou ces deux valeurs sont fixees.
  SELECT e.id, false, sol->>'nom', e.compagnie_id, e.section_id, e.matricule,
         greatest(0, coalesce((sol->>'pa')::integer, 0)),
         coalesce((sol->'formation'->>'tir')::numeric, 0),
         coalesce((sol->'formation'->>'combat_rapproche')::numeric, 0),
         coalesce(sol->>'arme','corps_a_corps') IN ('arme_de_poing','mitraillette'),
         public.militaire_defense_pnj('PER'),
         public.militaire_defense_pnj('DUP'),
         e.saute_round
    FROM public.batailles_engagements e
    JOIN public.compagnies_militaires c ON c.id = e.compagnie_id
    CROSS JOIN LATERAL jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s
    CROSS JOIN LATERAL jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.matricule IS NOT NULL AND e.sorti_round IS NULL
     AND s->>'id' = e.section_id AND sol->>'matricule' = e.matricule;
$$;

-- =========================================================================================
-- GILET PARE-BALLES -- PRIMITIVE UNIQUE PJ ET PNJ
-- =========================================================================================
-- militaire_gilet_encaisser(text) ne savait traiter qu'un PJ et n'avait AUCUN appelant (constat de
-- l'audit). La remplacer par une primitive qui couvre les deux cas evite de faire vivre deux
-- moteurs de protection en parallele. L'ancienne est supprimee plus bas, pas laissee en surcharge.
--
-- REGLE GD INCHANGEE : uniquement contre une consequence d'ARME A FEU, uniquement quand le coup
-- ferait tomber la cible hors de combat, jet serveur 50 %. Reussite -> la neutralisation est
-- evitee et le gilet devient `fragilise` ; echec -> neutralisation normale et le gilet reste
-- INTACT. Un gilet deja fragilise ne protege plus.
CREATE OR REPLACE FUNCTION public.militaire_gilet_absorber(
  p_est_pj boolean, p_nom text, p_compagnie_id text, p_section_id text, p_matricule text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_inv jsonb; v_pos integer; v_protege boolean; v_data jsonb; v_sec jsonb; v_sols jsonb;
        v_trouve boolean := false;
BEGIN
  IF p_est_pj THEN
    SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
      INTO v_inv FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
    IF v_inv IS NULL THEN RETURN jsonb_build_object('protege', false, 'raison', 'porteur_introuvable'); END IF;
    SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
     WHERE i->>'produitMilitaire' = 'gilet_pare_balles'
       AND coalesce((i->>'fragilise')::boolean, false) = false ORDER BY pos LIMIT 1;
    IF v_pos IS NULL THEN RETURN jsonb_build_object('protege', false, 'raison', 'aucun_gilet_intact'); END IF;

    -- Le jet a lieu AVANT l'ecriture : le gilet ne se fragilise que s'il a servi de rempart, et
    -- sur un echec il reste intact -- exactement la regle validee.
    v_protege := (random() < 0.5);
    IF v_protege THEN
      SELECT coalesce(jsonb_agg(CASE WHEN pos = v_pos
               THEN i || jsonb_build_object('fragilise', true,
                      'desc', coalesce(i->>'desc','') || ' Fragilisé : a déjà encaissé un impact.')
               ELSE i END ORDER BY pos), '[]'::jsonb)
        INTO v_inv FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos);
      UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_nom;
    END IF;
    RETURN jsonb_build_object('protege', v_protege, 'gilet_fragilise', v_protege);
  END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('protege', false, 'raison', 'compagnie_introuvable'); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('protege', false, 'raison', 'section_introuvable'); END IF;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;

  SELECT true INTO v_trouve FROM jsonb_array_elements(v_sols) sol,
         jsonb_array_elements(CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                                   THEN sol->'accessoires' ELSE '[]'::jsonb END) a
   WHERE sol->>'matricule' = p_matricule
     AND a->>'produitMilitaire' = 'gilet_pare_balles'
     AND coalesce((a->>'fragilise')::boolean, false) = false LIMIT 1;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('protege', false, 'raison', 'aucun_gilet_intact');
  END IF;

  v_protege := (random() < 0.5);
  IF v_protege THEN
    SELECT coalesce(jsonb_agg(
             CASE WHEN sol->>'matricule' = p_matricule
                  THEN sol || jsonb_build_object('accessoires', (
                         SELECT coalesce(jsonb_agg(
                                  CASE WHEN a->>'produitMilitaire' = 'gilet_pare_balles'
                                        AND coalesce((a->>'fragilise')::boolean,false) = false
                                        AND ap = (SELECT min(ap2) FROM jsonb_array_elements(sol->'accessoires')
                                                   WITH ORDINALITY AS t2(a2, ap2)
                                                  WHERE a2->>'produitMilitaire' = 'gilet_pare_balles'
                                                    AND coalesce((a2->>'fragilise')::boolean,false) = false)
                                       THEN a || jsonb_build_object('fragilise', true)
                                       ELSE a END ORDER BY ap), '[]'::jsonb)
                           FROM jsonb_array_elements(CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                                                          THEN sol->'accessoires' ELSE '[]'::jsonb END)
                                WITH ORDINALITY AS ta(a, ap)))
                  ELSE sol END ORDER BY pos), '[]'::jsonb)
      INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);
    UPDATE public.compagnies_militaires
       SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                    v_sec || jsonb_build_object('soldats', v_sols))
     WHERE id = p_compagnie_id;
  END IF;
  RETURN jsonb_build_object('protege', v_protege, 'gilet_fragilise', v_protege);
END;
$$;

-- L'ancienne primitive PJ-seule disparait : aucun appelant, et la laisser en place ferait vivre
-- deux moteurs de protection concurrents. Aucune surcharge ne subsiste.
DROP FUNCTION IF EXISTS public.militaire_gilet_encaisser(text);

REVOKE ALL ON FUNCTION public.militaire_bataille_combattants(bigint, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_gilet_absorber(boolean, text, text, text, text) FROM PUBLIC, anon, authenticated;