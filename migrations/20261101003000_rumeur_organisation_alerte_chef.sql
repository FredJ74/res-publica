-- Avertissement neutre au chef, apres publication. Aucun nom d'auteur dans le mail.
-- Definition source relevee sur le serveur reel, avant modification.
BEGIN;
CREATE OR REPLACE FUNCTION public.rumeur_lancer(p_type text, p_cible text, p_texte text, p_cible_trace text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_paie jsonb; v_reussi boolean; v_perte integer := 0; v_membres text[] := ARRAY[]::text[];
  v_repere boolean; v_effet text; v_ville text; v_retour integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_type NOT IN ('pj', 'organisation', 'local', 'gouvernement', 'pays') OR coalesce(btrim(p_cible), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF coalesce(btrim(p_texte), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'texte_requis'); END IF;
  IF p_type = 'pj' AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  v_paie := public.payer_ordre(v_moi, 'lancer_rumeur_cible', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_reussi := random() < 0.75;
  IF v_reussi THEN
    IF p_type = 'pj' THEN
      v_perte := floor(random() * 16)::integer + 5;
      PERFORM public.rumeur_pop_retirer_interne(p_cible, v_perte);
    ELSIF p_type = 'organisation' THEN
      v_perte := floor(random() * 10)::integer + 1;
    ELSIF p_type = 'gouvernement' THEN
      v_perte := floor(random() * 5)::integer + 1;
      SELECT coalesce(array_agg(name), ARRAY[]::text[]) INTO v_membres FROM public.personnages_donnees
       WHERE country = p_cible AND poste ->> 'id' IN ('pm', 'min_int', 'min_fin', 'min_just', 'min_def', 'min_info', 'min_ae');
      PERFORM public.rumeur_pop_retirer_interne(n, v_perte) FROM unnest(v_membres) n;
    ELSIF p_type = 'pays' THEN
      v_perte := floor(random() * 5)::integer + 1;
      IF p_cible = 'republic' THEN
        FOREACH v_ville IN ARRAY ARRAY['capitale', 'ville_a', 'ville_b'] LOOP
          UPDATE public.indices_villes
             SET data = jsonb_set(data, '{social}', to_jsonb(greatest(0, least(100,
                          coalesce(CASE WHEN jsonb_typeof(data -> 'social') = 'number' THEN (data ->> 'social')::numeric END, 50) - v_perte))))
           WHERE id = 'republic_' || v_ville;
        END LOOP;
      END IF;
    END IF;
    PERFORM public.annonce_publique_interne('global', '🗯 ' || left(p_texte, 600));
    -- Alerte sans auteur, uniquement apres publication reussie.
    IF p_type = 'organisation' THEN
      BEGIN
        PERFORM public.mail_systeme_poser_interne(
          'Information officielle',
          (SELECT nullif(btrim(data::jsonb ->> 'chef'), '')
             FROM public.organisations WHERE id = p_cible),
          'Une rumeur vise votre organisation',
          'Une rumeur circule au sujet de votre organisation. Consultez les annonces publiques pour en prendre connaissance.'
        )
        WHERE EXISTS (SELECT 1 FROM public.organisations
                      WHERE id = p_cible AND nullif(btrim(data::jsonb ->> 'chef'), '') IS NOT NULL);
      EXCEPTION WHEN others THEN
        RAISE WARNING 'alerte_rumeur_organisation_indisponible: %', SQLSTATE;
      END;
    END IF;
    PERFORM public.crime_trace_rumeur_interne(v_moi, 'fausse_rumeur', left(coalesce(nullif(btrim(p_cible_trace), ''), p_cible), 200));
  ELSE
    v_retour := floor(random() * 11)::integer;
    v_perte := CASE WHEN v_retour < 5 THEN 0 WHEN v_retour < 10 THEN 1 ELSE 2 END;
    IF v_perte > 0 THEN
      PERFORM public.rumeur_pop_retirer_interne(v_moi, v_perte);
      PERFORM public.crime_dis_ajuster_interne(v_moi, -v_perte);
    END IF;
  END IF;
  v_repere := public.crime_detecter_interne(v_moi, 'fausse_rumeur', true);
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'perte', v_perte, 'membres', coalesce(array_length(v_membres, 1), 0),
    'repere', v_repere)
    || (SELECT jsonb_build_object('pa', pa, 'pop', (resources ->> 'pop')::numeric, 'dis', resources -> 'dis', 'recherche', recherche)
          FROM public.personnages_donnees WHERE name = v_moi);
END; $function$

COMMIT;
