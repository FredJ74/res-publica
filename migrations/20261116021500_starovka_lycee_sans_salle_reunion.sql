-- Starovka : le lycée conserve uniquement la salle de classe et la bibliothèque.
-- Ne change ni les universités des autres villes ni la mécanique des syndicats.
BEGIN;
DO $pre$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville='ville_a' AND batiment='universite' AND pieces @> '["amphi","bibliotheque"]'::jsonb)
 THEN RAISE EXCEPTION 'Lycée Starovka : salle de classe ou bibliothèque absente'; END IF;
END $pre$;
UPDATE public.navigation_lieux_regles
SET pieces = pieces - 'salle_reunion'
WHERE pays='soviet' AND ville='ville_a' AND batiment='universite';
DO $post$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville='ville_a' AND batiment='universite' AND pieces='["amphi","bibliotheque"]'::jsonb)
 THEN RAISE EXCEPTION 'Lycée Starovka : salles finales incorrectes'; END IF;
END $post$;
COMMIT;
