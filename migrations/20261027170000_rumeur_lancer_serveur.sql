-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027190521.
-- Eprouvee au role authenticated : cause directe refusee, rumeurs PJ / gouvernement / pays, faux cout refuse.
-- ============================================================================
-- LANCER UNE RUMEUR : PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite ». « Lancer une rumeur » (1 PA, 75 %) etait decide par l'ecran : jet,
-- perte de popularite de la cible, retour de baton, detection. Et la perte de popularite passait
-- par personnage_ajuster_pop_inf, causes « rumeur_pj » (-5 a -20) et « rumeur_gouvernement »
-- (-1 a -5) : N'IMPORTE QUEL joueur pouvait donc retirer 20 points de popularite a n'importe qui,
-- autant de fois qu'il le voulait, sans PA et sans jet. Desormais rumeur_lancer fait tout :
--   * PA preleves, jet 75 % ;
--   * reussite : PJ -5 a -20 POP ; gouvernement -1 a -5 POP a chaque ministre PJ en poste dans le
--     pays vise ; pays (Republia) -1 a -5 d'indice social dans chacune de ses trois villes ;
--     organisation : la perte (1 a 10) est rendue a l'ecran, qui l'applique (la table
--     organisations releve du chantier de Codex) ; local : aucun effet ;
--     annonce mondiale, trace « fausse_rumeur » ;
--   * echec : retour de baton 0 / -1 / -2 POP et DIS (tirage 0-10) ;
--   * detection « fausse_rumeur » dans les deux cas (comme l'ecran).
-- Les deux causes du registre sont fermees aux joueurs.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rumeur_pop_retirer_interne(p_nom text, p_perte integer)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ UPDATE public.personnages_donnees
         SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{pop}',
               to_jsonb(greatest(0, coalesce(CASE WHEN jsonb_typeof(resources -> 'pop') = 'number'
                                                  THEN (resources ->> 'pop')::numeric END, 50) - p_perte)))
       WHERE name = p_nom $$;

CREATE OR REPLACE FUNCTION public.rumeur_lancer(p_type text, p_cible text, p_texte text, p_cible_trace text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
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
END; $function$;

-- Les deux causes du registre ne sont plus ouvertes aux joueurs.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.personnage_ajuster_pop_inf(text,text,integer,integer,text)'::regprocedure);
  IF position('cause_par_le_serveur' IN v_def) = 0 THEN
    v_def := replace(v_def, E'    v_min := -20; v_max := -5;\n',
      E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''cause_par_le_serveur'', ''cause'', p_cause); -- rumeur_lancer (27/10/2026)\n');
    v_def := replace(v_def, E'    v_min := -5; v_max := -1;\n',
      E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''cause_par_le_serveur'', ''cause'', p_cause); -- rumeur_lancer (27/10/2026)\n');
    IF (length(v_def) - length(replace(v_def, 'cause_par_le_serveur', ''))) / 20 <> 2 THEN
      RAISE EXCEPTION 'personnage_ajuster_pop_inf : motifs introuvables'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;

REVOKE ALL ON FUNCTION public.rumeur_pop_retirer_interne(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rumeur_lancer(text, text, text, text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rumeur_lancer(text, text, text, text, integer, integer) TO authenticated;
