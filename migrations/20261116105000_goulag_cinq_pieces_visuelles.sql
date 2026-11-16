-- Goulag de Sovarka : cinq pièces graphiques (aucun nouvel ordre).
-- Conserver entree_qhs et cellules_qhs, références du système de détention.
-- Ne modifier ni le QHS de Républia ni celui des autres empires.
BEGIN;
DO $pre$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='qhs' AND batiment='qhs-prison'
      AND pieces @> '["entree_qhs","cellules_qhs"]'::jsonb
  ) THEN RAISE EXCEPTION 'Goulag : portes et cellules canoniques absentes'; END IF;
END $pre$;
UPDATE public.navigation_lieux_regles
SET pieces='["entree_qhs","cellules_qhs","cachot_disciplinaire","bureau_chef","mirador"]'::jsonb
WHERE pays='soviet' AND ville='qhs' AND batiment='qhs-prison'
  AND pieces IS DISTINCT FROM '["entree_qhs","cellules_qhs","cachot_disciplinaire","bureau_chef","mirador"]'::jsonb;
DO $post$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='qhs' AND batiment='qhs-prison'
      AND pieces='["entree_qhs","cellules_qhs","cachot_disciplinaire","bureau_chef","mirador"]'::jsonb
  ) THEN RAISE EXCEPTION 'Goulag : ordre des cinq pièces incorrect'; END IF;
END $post$;
COMMIT;
