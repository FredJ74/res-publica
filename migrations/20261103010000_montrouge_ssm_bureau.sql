-- Montrouge : ouverture du bureau d'Edwige Jacquard dans les Services sociaux.
-- Le serveur de navigation fait foi ; aucune position de PJ ni aucun droit métier modifié.
-- Extension idempotente, sans supprimer les pièces existantes.
UPDATE public.navigation_lieux_regles
SET pieces = CASE
  WHEN pieces @> '["bureau_assistante_sociale"]'::jsonb THEN pieces
  ELSE pieces || '["bureau_assistante_sociale"]'::jsonb
END
WHERE pays='republic'
  AND ville='ville_b'
  AND batiment='services-sociaux-montrouge'
  AND NOT ferme;

-- Si la règle n'était pas encore installée (environnement neuf), créer le lieu.
INSERT INTO public.navigation_lieux_regles
  (pays, ville, batiment, pieces, ferme, membership)
VALUES
  ('republic','ville_b','services-sociaux-montrouge',
   '["accueil","bureau_assistante_sociale"]'::jsonb,false,NULL)
ON CONFLICT (pays,ville,batiment) DO NOTHING;
