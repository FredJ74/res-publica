-- Exact pg_get_functiondef en lecture seule 31/10/2026; aucune donnée joueur.
CREATE OR REPLACE FUNCTION public.inventaire_sauver_revision(p_acteur text, p_revision bigint, p_inventory jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v public.personnages_donnees%rowtype;
BEGIN
  PERFORM public.inventaire_reception_etat(p_acteur); -- autorite + verrou personnage d'abord
  SELECT * INTO v FROM public.personnages_donnees WHERE name=p_acteur;
  IF jsonb_typeof(p_inventory) IS DISTINCT FROM 'array' THEN
    RETURN jsonb_build_object('ok',false,'raison','inventaire_invalide');
  END IF;
  -- Aucun rebasage d'un snapshot different. Un etat deja exact ne reecrit rien.
  IF p_inventory IS DISTINCT FROM v.inventory THEN
    IF p_revision IS DISTINCT FROM v.inventory_revision THEN
      RETURN jsonb_build_object('ok',false,'raison','inventaire_perime','revision',v.inventory_revision);
    END IF;
    -- VERROU, ETAPE 1 (observation) : un objet qui n'etait pas deja possede est inscrit.
    INSERT INTO public.inventaire_ecarts_observes (acteur, objet)
    SELECT p_acteur, x FROM jsonb_array_elements(public.inventaire_ajouts_interdits(v.inventory, p_inventory)) x;
    UPDATE public.personnages_donnees SET inventory=p_inventory WHERE name=p_acteur
      RETURNING * INTO v;
    SELECT * INTO v FROM public.personnages_donnees WHERE name=p_acteur;
    IF v.inventory IS DISTINCT FROM p_inventory OR v.inventory_revision IS DISTINCT FROM p_revision+1 THEN
      RAISE EXCEPTION 'inventaire_ecriture_non_appliquee';
    END IF;
  END IF;
  RETURN jsonb_build_object('ok',true,'contrat',1,'inventory',v.inventory,'revision',v.inventory_revision);
END;
$function$;
CREATE OR REPLACE FUNCTION public.inventaire_ajouts_interdits(p_ancien jsonb, p_nouveau jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pris boolean[]; v_anc jsonb[]; n jsonb; i integer; v_trouve boolean; v_hors jsonb := '[]'::jsonb;
BEGIN
  SELECT coalesce(array_agg(e ORDER BY o), ARRAY[]::jsonb[]) INTO v_anc
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_ancien) = 'array' THEN p_ancien ELSE '[]'::jsonb END) WITH ORDINALITY x(e, o);
  v_pris := array_fill(false, ARRAY[greatest(1, coalesce(array_length(v_anc, 1), 0))]);
  FOR n IN SELECT e FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_nouveau) = 'array' THEN p_nouveau ELSE '[]'::jsonb END) e LOOP
    v_trouve := false;
    FOR i IN 1..coalesce(array_length(v_anc, 1), 0) LOOP
      CONTINUE WHEN v_pris[i];
      IF (v_anc[i] - 'qty' - 'quantite') = (n - 'qty' - 'quantite')
         AND (NOT (n ? 'qty') OR (jsonb_typeof(n -> 'qty') = 'number' AND (n ->> 'qty')::numeric > 0
              AND (n ->> 'qty')::numeric <= coalesce(CASE WHEN jsonb_typeof(v_anc[i] -> 'qty') = 'number' THEN (v_anc[i] ->> 'qty')::numeric END, 1)))
         AND (NOT (n ? 'quantite') OR (jsonb_typeof(n -> 'quantite') = 'number' AND (n ->> 'quantite')::numeric > 0
              AND (n ->> 'quantite')::numeric <= coalesce(CASE WHEN jsonb_typeof(v_anc[i] -> 'quantite') = 'number' THEN (v_anc[i] ->> 'quantite')::numeric END, 0)))
      THEN v_pris[i] := true; v_trouve := true; EXIT; END IF;
    END LOOP;
    IF NOT v_trouve THEN v_hors := v_hors || jsonb_build_array(n); END IF;
  END LOOP;
  RETURN v_hors;
END; $function$;
