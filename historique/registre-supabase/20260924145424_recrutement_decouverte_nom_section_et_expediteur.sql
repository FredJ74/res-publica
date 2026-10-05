-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924145424
-- Nom original      : recrutement_decouverte_nom_section_et_expediteur
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-24 14:54:24 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d8fef290d11f048815250263cf3249e2
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
-- CORRECTIFS ISSUS DE LA RECETTE NAVIGATEUR (24 septembre 2026).
--
-- 1. LA SCENE DE DECOUVERTE MONTRAIT UN IDENTIFIANT TECHNIQUE. La RPC ne rendait que
--    `section_id`, et l'ecran affichait donc « section zztest-sov-s2 » au joueur. On renvoie
--    desormais aussi le NOM de la section tel qu'il est ecrit dans le blob de la compagnie ;
--    l'identifiant reste transmis, mais il ne sert plus a l'affichage.
-- 2. LES COURRIERS ETAIENT SIGNES « Armee de Republia » POUR TOUT LE MONDE. Un engage de
--    Novomirsk recevait donc une lettre de l'armee d'un autre pays. L'expediteur devient
--    neutre : « Etat-major » vaut dans les quatre pays.
CREATE OR REPLACE FUNCTION public.militaire_affectation_decouvrir()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  c_places constant integer := 24;
  v_moi text; v_bat text; v_pays text; v_c record; v_data jsonb; v_sec jsonb;
  v_sols jsonb; v_total integer; v_pnj_pos integer; v_pnj jsonb; v_reserve jsonb;
  v_deja integer; v_tire integer; v_pris jsonb; v_reste jsonb; v_secs jsonb;
  v_chef text; v_effectif integer; v_sec_nom text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(current_building,''), coalesce(country,'republic') INTO v_bat, v_pays
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_bat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_bat <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  SELECT * INTO v_c FROM public.candidatures_militaires
   WHERE candidat = v_moi AND statut = 'acceptee' AND echeance > now()
   ORDER BY accepte_le LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_affectation'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_c.compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;

  -- Le nom lisible de la section, lu AVANT toute reecriture du blob.
  IF v_c.section_id IS NOT NULL THEN
    SELECT coalesce(s->>'nom', 'section ' || coalesce(s->>'numero', s->>'id'))
      INTO v_sec_nom
      FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
     WHERE s->>'id' = v_c.section_id;
  END IF;

  IF v_c.grade_vise = 'capitaine' THEN
    IF coalesce(v_data->>'capitaineNom','') <> '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_deja_commandee');
    END IF;
    UPDATE public.compagnies_militaires
       SET data = v_data || jsonb_build_object('capitaineNom', v_moi) WHERE id = v_c.compagnie_id;
    UPDATE public.personnages_donnees
       SET poste = jsonb_build_object('id','capitaine','compagnieId', v_c.compagnie_id),
           updated_at = now() WHERE name = v_moi;
    SELECT count(*) INTO v_effectif
      FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol;

  ELSIF v_c.grade_vise = 'lieutenant' THEN
    SELECT count(*) INTO v_deja
      FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE s->>'id' = v_c.section_id;
    v_reserve := CASE WHEN jsonb_typeof(v_data->'reserve') = 'array' THEN v_data->'reserve' ELSE '[]'::jsonb END;
    v_tire := least(greatest(0, c_places - v_deja), jsonb_array_length(v_reserve));
    SELECT coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos <= v_tire), '[]'::jsonb),
           coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos > v_tire), '[]'::jsonb)
      INTO v_pris, v_reste
      FROM jsonb_array_elements(v_reserve) WITH ORDINALITY AS t(sol, pos);

    SELECT coalesce(jsonb_agg(
             CASE WHEN s->>'id' = v_c.section_id AND coalesce(s->>'lieutenantNom','') = ''
                  THEN s || jsonb_build_object('lieutenantNom', v_moi,
                         'soldats', coalesce(s->'soldats','[]'::jsonb) || v_pris)
                  ELSE s END ORDER BY ord), '[]'::jsonb) INTO v_secs
      FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_secs) s
                    WHERE s->>'id' = v_c.section_id AND s->>'lieutenantNom' = v_moi) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'section_indisponible');
    END IF;
    UPDATE public.compagnies_militaires
       SET data = v_data || jsonb_build_object('sections', v_secs, 'reserve', v_reste)
     WHERE id = v_c.compagnie_id;
    UPDATE public.personnages_donnees
       SET poste = jsonb_build_object('id','lieutenant','compagnieId', v_c.compagnie_id,
                                      'sectionId', v_c.section_id), updated_at = now()
     WHERE name = v_moi;
    v_chef := v_data->>'capitaineNom';
    v_effectif := v_deja + v_tire;

  ELSE
    SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
     WHERE s->>'id' = v_c.section_id;
    IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
    v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
    v_total := jsonb_array_length(v_sols);
    v_reserve := CASE WHEN jsonb_typeof(v_data->'reserve') = 'array' THEN v_data->'reserve' ELSE '[]'::jsonb END;

    IF v_total < c_places THEN
      v_sols := v_sols || jsonb_build_array(jsonb_build_object('pj', true, 'nom', v_moi));
    ELSE
      SELECT pos, sol INTO v_pnj_pos, v_pnj
        FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos)
       WHERE NOT coalesce((sol->>'pj')::boolean, false) ORDER BY pos LIMIT 1;
      IF v_pnj IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'section_pleine');
      END IF;
      SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
        FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos) WHERE pos <> v_pnj_pos;
      v_sols := v_sols || jsonb_build_array(jsonb_build_object('pj', true, 'nom', v_moi));
      v_reserve := v_reserve || jsonb_build_array(v_pnj);
    END IF;

    UPDATE public.compagnies_militaires
       SET data = public.militaire_sections_remplacer(v_data, v_c.section_id,
                    v_sec || jsonb_build_object('soldats', v_sols))
                  || jsonb_build_object('reserve', v_reserve)
     WHERE id = v_c.compagnie_id;
    PERFORM public.militaire_service_ouvrir(v_moi, v_pays, 'soldat', v_c.compagnie_id, v_c.section_id);
    v_chef := v_sec->>'lieutenantNom';
    v_effectif := jsonb_array_length(v_sols);
  END IF;

  UPDATE public.candidatures_militaires
     SET statut = 'finalisee', finalise_le = now() WHERE id = v_c.id;

  RETURN jsonb_build_object('ok', true, 'grade', v_c.grade_vise,
    'compagnie_id', v_c.compagnie_id, 'compagnie_nom', coalesce(v_data->>'nom', v_c.compagnie_id),
    'section_id', v_c.section_id, 'section_nom', v_sec_nom, 'recruteur', v_c.accepte_par,
    'chef', v_chef, 'effectif', v_effectif,
    'pnj_rendu_reserve', (v_pnj IS NOT NULL), 'matricule_rendu', v_pnj->>'matricule');
END;
$function$;

-- Expediteur neutre dans les trois courriers.
UPDATE public.mails SET from_player = 'État-major' WHERE from_player = 'Armée de Républia';