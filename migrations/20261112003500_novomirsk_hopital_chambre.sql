-- Novomirsk : ajouter uniquement la chambre de l'hôpital public au référentiel serveur.
-- Sans effet sur les règles, les soins, les autres villes ou les autres empires.
UPDATE public.navigation_lieux_regles
SET pieces = pieces || '["chambre"]'::jsonb
WHERE pays = 'soviet'
  AND ville = 'capitale'
  AND batiment = 'dispensaire-public'
  AND pieces @> '["salle_attente","ehpad_tilleuls"]'::jsonb
  AND NOT pieces @> '["chambre"]'::jsonb;
