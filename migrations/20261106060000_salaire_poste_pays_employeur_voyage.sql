-- Salaries of offices follow the sovereign employer, not the current travel country.
-- In particular, a Republian minister still receives the Republian ministry salary
-- when sleeping in Sovarka. Keep the original RPC and daily idempotence unchanged.
DO $patch$
DECLARE
  v_source text;
  v_before_declare text := $old_decl$  v_arg numeric; v_liquide numeric; v_paye numeric;$old_decl$;
  v_after_declare text := $new_decl$  v_arg numeric; v_liquide numeric; v_paye numeric;
  v_poste_pays text; v_poste_pays_count integer;$new_decl$;
  v_before_logic text := $old_logic$  v_grade := public.militaire_grade_effectif(v_moi);$old_logic$;
  v_after_logic text := $new_logic$  -- Le pays de presence (country) ne doit pas déterminer l'employeur du poste.
  -- Pour un poste avec barème unique, le pays payeur vient du registre serveur.
  -- S'il existe plusieurs pays possibles pour une même clé, refuser plutôt
  -- que choisir arbitrairement une trésorerie étrangère.
  IF v_poste IS NOT NULL THEN
    SELECT count(DISTINCT s.pays), min(s.pays)
      INTO v_poste_pays_count, v_poste_pays
      FROM public.salaires_civils_declares s
     WHERE s.categorie = 'poste' AND s.cle = v_poste;
    IF v_poste_pays_count > 1 THEN
      RETURN jsonb_build_object('ok',false,'raison','pays_employeur_ambigu','poste',v_poste);
    ELSIF v_poste_pays_count = 1 THEN
      v_pays := v_poste_pays;
    END IF;
  END IF;
  v_grade := public.militaire_grade_effectif(v_moi);$new_logic$;
BEGIN
  SELECT pg_get_functiondef('public.salaire_civil_percevoir()'::regprocedure) INTO v_source;
  IF v_source IS NULL
    OR strpos(v_source, v_before_declare) = 0
    OR strpos(v_source, v_before_logic) = 0
    OR strpos(v_source, 'v_poste_pays_count') > 0
  THEN RAISE EXCEPTION 'salaire_civil_percevoir_version_inattendue'; END IF;
  v_source := replace(v_source, v_before_declare, v_after_declare);
  v_source := replace(v_source, v_before_logic, v_after_logic);
  EXECUTE v_source;
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE oid='public.salaire_civil_percevoir()'::regprocedure
      AND pg_get_functiondef(oid) LIKE '%pays_employeur_ambigu%'
  ) THEN RAISE EXCEPTION 'salaire_pays_employeur_correction_absente'; END IF;
END $patch$;
