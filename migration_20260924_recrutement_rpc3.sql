-- =============================================================================================
-- RECRUTEMENT MILITAIRE : LA PRESENTATION ET LE TEMPS QUI PASSE (24 septembre 2026)
-- =============================================================================================
-- LA DECOUVERTE EST LE SEUL MOMENT OU LE BLOB DE LA COMPAGNIE EST ECRIT. Jusque-la, une
-- acceptation n'etait qu'une reservation calculee. C'est ce qui garantit qu'une expiration ne
-- laisse jamais une compagnie a demi ecrite : il n'y a rien a defaire.
-- =============================================================================================

CREATE OR REPLACE FUNCTION public.militaire_affectation_decouvrir()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  c_places constant integer := 24;
  v_moi text; v_bat text; v_pays text; v_c record; v_data jsonb; v_sec jsonb;
  v_sols jsonb; v_total integer; v_pnj_pos integer; v_pnj jsonb; v_reserve jsonb;
  v_deja integer; v_tire integer; v_pris jsonb; v_reste jsonb; v_secs jsonb;
  v_chef text; v_effectif integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(current_building,''), coalesce(country,'republic') INTO v_bat, v_pays
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_bat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_bat <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- L'ECHEANCE EST UN FAIT, PAS UN ETAT. On exige echeance > now() ici meme : un joueur qui
  -- arrive avec deux minutes de retard est refuse par cette ligne, que le cron soit deja passe
  -- ou non. Le cron ne fait ensuite que ranger la ligne et prevenir le joueur.
  SELECT * INTO v_c FROM public.candidatures_militaires
   WHERE candidat = v_moi AND statut = 'acceptee' AND echeance > now()
   ORDER BY accepte_le LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_affectation'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_c.compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;

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
    -- Meme peuplement depuis la reserve que militaire_accepter_lieutenant, plafonne a 24.
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

  ELSE -- soldat : insertion, avec eviction d'un PNJ si la section est pleine.
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
      -- Le PNJ retourne INTACT en reserve : matricule et entrainement compris.
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
    'section_id', v_c.section_id, 'recruteur', v_c.accepte_par,
    'chef', v_chef, 'effectif', v_effectif,
    'pnj_rendu_reserve', (v_pnj IS NOT NULL), 'matricule_rendu', v_pnj->>'matricule');
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- CRON — LA RELANCE DE MAINTIEN, tous les 7 jours, tant que la candidature vit.
-- Appelee une fois par jour : `derniere_relance` fait office de compteur, si bien qu'un cron
-- saute ne produit jamais deux relances, et qu'un cron double n'en produit aucune de trop.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_candidatures_relancer()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_n integer := 0; r record;
BEGIN
  FOR r IN SELECT * FROM public.candidatures_militaires
            WHERE statut = 'active'
              AND coalesce(derniere_relance, cree_le) <= now() - interval '7 days'
            FOR UPDATE
  LOOP
    INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
    VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text),1,6),
            'Armée de Républia', r.candidat,
            'Votre candidature est toujours à l''étude',
            'Votre candidature au grade de ' || r.grade_vise || ', déposée le ' ||
            to_char(r.cree_le AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY') ||
            ', reste enregistrée et sera examinée. Vous pouvez la retirer à tout moment à la Caserne Militaire.',
            to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);
    UPDATE public.candidatures_militaires SET derniere_relance = now() WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'relancees', v_n);
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- CRON — LES 48 HEURES ECOULEES. La place etait deja rendue (le calcul de capacite ignore une
-- echeance passee) : ce passage ne fait que ranger la ligne et prevenir le joueur.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_affectations_expirer()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_n integer := 0; r record;
BEGIN
  FOR r IN SELECT * FROM public.candidatures_militaires
            WHERE statut = 'acceptee' AND echeance <= now() FOR UPDATE
  LOOP
    UPDATE public.candidatures_militaires SET statut = 'expiree' WHERE id = r.id;
    INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
    VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text),1,6),
            'Armée de Républia', r.candidat,
            'Engagement caduc — délai dépassé',
            'Vous ne vous êtes pas présenté(e) à la Caserne Militaire dans les 48 heures. ' ||
            'Votre engagement au grade de ' || r.grade_vise || ' est caduc et la place a été rendue. ' ||
            'Vous pouvez déposer une nouvelle candidature à la Caserne.',
            to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'expirees', v_n);
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_affectation_decouvrir() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_candidatures_relancer() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_affectations_expirer() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_affectation_decouvrir() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.militaire_candidatures_relancer() TO service_role;
GRANT EXECUTE ON FUNCTION public.militaire_affectations_expirer() TO service_role;
