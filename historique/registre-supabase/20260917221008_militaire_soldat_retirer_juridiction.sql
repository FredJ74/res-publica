-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917221008
-- Nom original      : militaire_soldat_retirer_juridiction
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 22:10:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 90646bccba5b383d71bce6b615aa12ac
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
CREATE OR REPLACE FUNCTION public.militaire_soldat_retirer(
  p_compagnie_id text, p_section_id text, p_nom text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_moi text; v_pays_moi text; v_data jsonb; v_sec jsonb; v_sols jsonb;
  v_avant int; v_apres int; v_lieut text; v_par text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(coalesce(p_nom,'')),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_invalide'); END IF;

  SELECT coalesce(country,'republic') INTO v_pays_moi
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  -- MEME GARDE DE JURIDICTION que militaire_section_de_moi : le banc a montre qu'elle manquait
  -- ici, et un officier d'un empire ne doit pas pouvoir toucher aux effectifs d'un autre.
  IF v_data->>'pays' IS DISTINCT FROM v_pays_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
  v_lieut := v_sec->>'lieutenantNom';

  -- DEUX AUTORITES LEGITIMES, et deux seulement : le soldat lui-meme (demission) ou le Lieutenant
  -- de CETTE section (renvoi). Tout autre acteur est refuse.
  IF v_moi = p_nom THEN v_par := 'demission';
  ELSIF v_lieut IS NOT NULL AND v_lieut = v_moi THEN v_par := 'renvoi';
  ELSE RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_avant := jsonb_array_length(v_sols);
  SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
    FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos)
   WHERE NOT (coalesce((sol->>'pj')::boolean, false) AND sol->>'nom' = p_nom);
  v_apres := jsonb_array_length(v_sols);
  IF v_apres = v_avant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_soldat_de_cette_section');
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  -- La periode de service se termine ici : c'est elle, et non le calepin, qui fait foi.
  PERFORM public.militaire_service_fermer(p_nom, 'soldat');

  RETURN jsonb_build_object('ok', true, 'motif', v_par, 'nom', p_nom,
    'effectif', v_apres, 'places_libres', 24 - v_apres);
END; $fn$;