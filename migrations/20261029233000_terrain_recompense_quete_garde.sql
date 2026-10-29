-- #250 — durcir uniquement le titre recompense_quete de terrain_proprietaire_muter.
-- Ne pas appliquer avant les bancs PostgreSQL jetables et la revue des recompenses historiques.
DO $do$
DECLARE
  v_def text;
  v_ancre text := E'  v_data := v_data || p_patch;\n';
  v_garde text := $guard$
  IF p_titre = 'recompense_quete' THEN
    -- Une quete resolue quelconque ne donne pas droit a n'importe quel terrain.
    IF NOT EXISTS (
      SELECT 1 FROM public.quetes_actives q
      JOIN public.terrains_etat t ON t.id = v_cle
      WHERE q.id = p_reference AND q.statut = 'resolue' AND q.resolu_par = v_moi
        AND q.recompense_type = 'terrain'
        AND q.country = t.country
        AND (q.recompense_detail::jsonb ->> 'buildingId') = t.building_id
    ) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'recompense_terrain_non_autorisee');
    END IF;
    IF nullif(v_data ->> 'proprietaire', '') IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'terrain_deja_attribue');
    END IF;
    IF p_patch ->> 'proprietaire' IS DISTINCT FROM v_moi
       OR EXISTS (SELECT 1 FROM jsonb_object_keys(p_patch) k
                  WHERE k NOT IN ('proprietaire', 'pnj', 'pnjData', 'dateGeneration'))
    THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'patch_recompense_invalide');
    END IF;
  END IF;

$guard$;
BEGIN
  v_def := pg_get_functiondef('public.terrain_proprietaire_muter(text,text,jsonb,text)'::regprocedure);
  IF position('recompense_terrain_non_autorisee' IN v_def) = 0 THEN
    IF position(v_ancre IN v_def) = 0 THEN
      RAISE EXCEPTION 'terrain_proprietaire_muter : ancre de garde absente';
    END IF;
    v_def := replace(v_def, v_ancre, v_garde || v_ancre);
    EXECUTE v_def;
  END IF;
END $do$;
