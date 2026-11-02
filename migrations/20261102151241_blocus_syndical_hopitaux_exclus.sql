-- BLOCUS SYNDICAL : LES HÔPITAUX NE PEUVENT PAS ÊTRE BLOQUÉS (décision de Fred, 02/11/2026,
-- GAME-DESIGN-BLOCUS.md, décision 7). Seul lieu exclu. Lieux de soins où un PJ est hospitalisé :
-- hôpitaux publics (dispensaires) et clinique privée.

CREATE OR REPLACE FUNCTION public.blocus_lieu_exclu_interne(p_batiment text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_batiment IN ('dispensaire-public', 'dispensaire-public-v', 'clinique-privee');
$function$;
REVOKE ALL ON FUNCTION public.blocus_lieu_exclu_interne(text) FROM PUBLIC, anon, authenticated;

DO $blocus$
DECLARE f text; ancien text; nouveau text;
BEGIN
  f := pg_get_functiondef('public.blocus_syndical_organiser(text,integer,text)'::regprocedure);
  IF position('blocus_lieu_exclu_interne' IN f) = 0 THEN
    ancien := 'RETURN jsonb_build_object(''ok'', false, ''raison'', ''batiment_inconnu''); END IF;';
    nouveau := ancien || E'\n  IF public.blocus_lieu_exclu_interne(p.current_building) THEN\n'
      || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''hopital_exclu''); END IF;';
    IF (length(f) - length(replace(f, ancien, ''))) / length(ancien) <> 1 THEN
      RAISE EXCEPTION 'blocus_organiser_definition_non_examinee'; END IF;
    EXECUTE replace(f, ancien, nouveau);
  END IF;
END $blocus$;

-- Les ordres des hôpitaux ne sont plus jamais refusés pour blocus.
DELETE FROM public.blocus_ordres_batiments WHERE public.blocus_lieu_exclu_interne(batiment);
