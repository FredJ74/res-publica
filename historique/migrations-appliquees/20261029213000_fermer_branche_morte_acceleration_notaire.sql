-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029192243.
-- Archivage documentaire seulement ; ne pas rejouer.
-- Retire la branche morte d'acceleration notariale restee apres 20261029160000.
-- L'acte est deja exclu de la liste blanche, mais son ancien code subsistait.
DO $migration$
DECLARE
  v_def text := pg_get_functiondef('public.terrain_compromis_acte(text,text,jsonb)'::regprocedure);
  v_debut integer;
  v_fin integer;
  v_nouvelle text;
BEGIN
  IF position('achat_direct_accelerer' IN v_def) = 0 THEN RETURN; END IF;
  IF position($$'achat_direct_accelerer'$$ IN split_part(v_def, $tag$  ELSIF p_acte = 'achat_direct_accelerer' THEN$tag$, 1)) > 0 THEN
    RAISE EXCEPTION 'Acte encore autorise en amont : arret de securite';
  END IF;
  v_debut := position($tag$  ELSIF p_acte = 'achat_direct_accelerer' THEN$tag$ IN v_def);
  v_fin := position(E'  END IF;\n\n  v_final' IN v_def);
  IF v_debut = 0 OR v_fin <= v_debut THEN
    RAISE EXCEPTION 'Structure inattendue de terrain_compromis_acte';
  END IF;
  v_nouvelle := left(v_def, v_debut - 1) || substring(v_def FROM v_fin);
  EXECUTE v_nouvelle;
  IF position('achat_direct_accelerer' IN pg_get_functiondef('public.terrain_compromis_acte(text,text,jsonb)'::regprocedure)) > 0 THEN
    RAISE EXCEPTION 'Ancien acte toujours present';
  END IF;
END $migration$;