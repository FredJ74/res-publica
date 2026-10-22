-- PREPAREE #69. Comptage en unites valide le 22 octobre 2026.
-- Aucun bail, coffre ou inventaire persistant n'est cree/modifie par ce DDL.
BEGIN;
DO $garde$ DECLARE h text; BEGIN
 SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.inventaire_retirer(jsonb,text,integer)');
 IF h IS NULL OR h NOT IN ('cb73758b95246226745306454388ee51','5fb432d70bde45d53d79488a0e0ee47b') THEN
  RAISE EXCEPTION 'inventaire_retirer_definition_non_examinee';
 END IF;
 SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.inventaire_occupation_unites(jsonb)');
 IF h IS NOT NULL AND h <> 'bb42afb226694ec8f5d46a388fc386dc' THEN
  RAISE EXCEPTION 'occupation_definition_non_examinee';
 END IF;
END;$garde$;
CREATE OR REPLACE FUNCTION public.inventaire_retirer(p_inv jsonb,p_cle text,p_qte integer)
 RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  v_item jsonb; v_resultat jsonb := '[]'::jsonb;
  v_reste integer := p_qte; v_qte numeric; v_pris integer;
BEGIN
  IF jsonb_typeof(p_inv) IS DISTINCT FROM 'array' OR coalesce(p_cle,'') = ''
     OR p_qte IS NULL OR p_qte <= 0 THEN
    RAISE EXCEPTION 'retrait_inventaire_invalide';
  END IF;
  -- Une pile peut etre representee par plusieurs lignes historiques. Valider tout le
  -- stock AVANT le retrait, puis repartir la quantite, sans retirer p_qte par ligne.
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_inv) LOOP
    IF v_item->>'stackKey' = p_cle THEN
      v_qte := coalesce((v_item->>'qty')::numeric,1);
      IF v_qte <= 0 OR v_qte <> trunc(v_qte) OR v_qte::text IN ('NaN','Infinity','-Infinity') THEN
        RAISE EXCEPTION 'quantite_inventaire_invalide';
      END IF;
    END IF;
  END LOOP;
  IF public.inventaire_quantite(p_inv,p_cle) < p_qte THEN
    RAISE EXCEPTION 'quantite_insuffisante';
  END IF;
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_inv) LOOP
    IF v_item->>'stackKey' = p_cle AND v_reste > 0 THEN
      v_qte := coalesce((v_item->>'qty')::numeric,1);
      v_pris := least(v_qte,v_reste)::integer;
      v_reste := v_reste - v_pris;
      IF v_qte > v_pris THEN
        v_resultat := v_resultat || jsonb_build_array(jsonb_set(v_item,'{qty}',to_jsonb(v_qte-v_pris)));
      END IF;
    ELSE
      v_resultat := v_resultat || jsonb_build_array(v_item);
    END IF;
  END LOOP;
  RETURN v_resultat;
END;
$function$;
CREATE OR REPLACE FUNCTION public.inventaire_occupation_unites(p_inventaire jsonb)
 RETURNS integer LANGUAGE plpgsql IMMUTABLE SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_item jsonb; v_qte numeric; v_total numeric := 0; v_regime text;
BEGIN
  IF jsonb_typeof(p_inventaire) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'inventaire_invalide';
  END IF;
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_inventaire) LOOP
    IF jsonb_typeof(v_item) <> 'object' THEN RAISE EXCEPTION 'objet_invalide'; END IF;
    v_regime := v_item->>'regime';
    IF v_regime IS NOT NULL AND v_regime NOT IN ('individuel','empilable') THEN
      RAISE EXCEPTION 'regime_objet_invalide';
    END IF;
    IF v_regime = 'empilable' OR (v_regime IS NULL AND coalesce((v_item->>'stackable')::boolean,false)) THEN
      v_qte := coalesce((v_item->>'qty')::numeric,1);
      IF v_qte <= 0 OR v_qte <> trunc(v_qte) OR v_qte::text IN ('NaN','Infinity','-Infinity') THEN
        RAISE EXCEPTION 'quantite_inventaire_invalide';
      END IF;
    ELSE
      v_qte := 1;
    END IF;
    v_total := v_total + v_qte;
    IF v_total > 2147483647 THEN RAISE EXCEPTION 'occupation_inventaire_excessive'; END IF;
  END LOOP;
  RETURN v_total::integer;
END;
$function$;
-- Primitive privee, aucun nouveau point d'entree metier expose au navigateur.
REVOKE ALL ON FUNCTION public.inventaire_occupation_unites(jsonb) FROM PUBLIC;
COMMIT;
