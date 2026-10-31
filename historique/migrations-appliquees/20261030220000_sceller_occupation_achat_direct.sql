-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261030193535.
-- Archivage documentaire seulement ; ne pas rejouer.
-- Empêche le renouvellement d'occupation pendant un achat direct notarial.
-- Réutilise la fonction en production avec garde d'empreinte pour ne pas écraser un correctif concurrent.
DO $migration$
DECLARE
  d text;
  n text;
BEGIN
  d := pg_get_functiondef('public.terrain_occupation_lire(text)'::regprocedure);
  IF position('achatDirect' IN d) > 0 THEN
    RAISE EXCEPTION 'Contrôle manuel requis : achatDirect déjà présent dans terrain_occupation_lire';
  END IF;
  IF (length(d)-length(replace(d,'AND NOT coalesce((e->>''compromis'')::boolean,false)',''))) /
      length('AND NOT coalesce((e->>''compromis'')::boolean,false)') <> 1 THEN
    RAISE EXCEPTION 'Point de garde introuvable ou multiple';
  END IF;
  n := replace(d,
    'AND NOT coalesce((e->>''compromis'')::boolean,false)',
    'AND NOT coalesce((e->>''compromis'')::boolean,false) AND NOT (jsonb_typeof(e->''achatDirect'') = ''object'' AND coalesce((e->''achatDirect''->>''dateLimite'')::numeric,0) > extract(epoch FROM clock_timestamp())*1000)');
  IF (length(n)-length(replace(n,'IF nullif(e->>''proprietaire'','''') IS NOT NULL OR coalesce((e->>''compromis'')::boolean,false) THEN',''))) /
      length('IF nullif(e->>''proprietaire'','''') IS NOT NULL OR coalesce((e->>''compromis'')::boolean,false) THEN') <> 1 THEN
    RAISE EXCEPTION 'Point de scellement introuvable ou multiple';
  END IF;
  n := replace(n,
    'IF nullif(e->>''proprietaire'','''') IS NOT NULL OR coalesce((e->>''compromis'')::boolean,false) THEN',
    'IF nullif(e->>''proprietaire'','''') IS NOT NULL OR coalesce((e->>''compromis'')::boolean,false) OR (jsonb_typeof(e->''achatDirect'') = ''object'' AND coalesce((e->''achatDirect''->>''dateLimite'')::numeric,0) > extract(epoch FROM clock_timestamp())*1000) THEN');
  EXECUTE n;
END $migration$;
