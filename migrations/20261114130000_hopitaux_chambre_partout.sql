-- Chambre d'hôpital dans tous les hôpitaux publics de Républia et de Sovarka (Fred, 14/11/2026).
-- Montrouge (20261114090000) et les trois villes de Sovarka (20261113020000) l'avaient déjà ; on ajoute
-- Luthécia et Port-Sainte-Marie. hospitalisation_lieu_rejoindre_interne conduit alors automatiquement
-- tout personnage tombé à 0 PA dans la pièce 'chambre' de l'hôpital de sa ville.
UPDATE public.navigation_lieux_regles
   SET pieces = pieces || '["chambre"]'::jsonb
 WHERE pays = 'republic'
   AND ((ville = 'capitale' AND batiment = 'dispensaire-public') OR (ville = 'ville_a' AND batiment = 'dispensaire-public-v'))
   AND NOT pieces ? 'chambre';

DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.navigation_lieux_regles
   WHERE pays IN ('republic', 'soviet') AND batiment LIKE 'dispensaire-public%' AND pieces ? 'chambre';
  IF n <> 6 THEN RAISE EXCEPTION 'chambres d''hôpital : 6 hôpitaux publics attendus en Républia et Sovarka, % trouvés', n; END IF;
END $$;
