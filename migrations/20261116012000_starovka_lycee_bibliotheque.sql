-- Ajoute uniquement la pièce bibliothèque au lycée de Starovka.
-- Pas de changement des ordres, des restrictions d'autres villes ou des mécaniques.
BEGIN;
DO $pre$
BEGIN
 IF NOT EXISTS (
   SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_a' AND batiment='universite'
     AND pieces @> '["amphi","salle_reunion"]'::jsonb
 ) THEN RAISE EXCEPTION 'Règle de navigation du lycée de Starovka introuvable'; END IF;
END $pre$;
UPDATE public.navigation_lieux_regles
SET pieces=pieces || '["bibliotheque"]'::jsonb
WHERE pays='soviet' AND ville='ville_a' AND batiment='universite'
  AND NOT pieces @> '["bibliotheque"]'::jsonb;
DO $post$
BEGIN
 IF NOT EXISTS (
  SELECT 1 FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville='ville_a'
   AND batiment='universite' AND pieces @> '["amphi","salle_reunion","bibliotheque"]'::jsonb
 ) THEN RAISE EXCEPTION 'Bibliothèque de Starovka non enregistrée'; END IF;
END $post$;
COMMIT;
