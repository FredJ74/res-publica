# Raccordement navigation serveur — Montrouge

Appliquer en production **après fusion** et vérifier les deux entrées. Aucun poste ni action métier créée.

```sql
-- Républia / Montrouge : accès serveur pour deux locaux sans ordre métier.
-- À exécuter une fois lors de la livraison ; idempotent.
-- N'altère pas les autres règles de navigation ni les positions de PJ.
INSERT INTO public.navigation_lieux_regles
  (pays, ville, batiment, pieces, ferme, membership)
VALUES
  ('republic','ville_b','services-sociaux-montrouge','["accueil"]'::jsonb,false,NULL),
  ('republic','ville_b','parking-tribunal-montrouge','["accueil"]'::jsonb,false,NULL)
ON CONFLICT (pays,ville,batiment) DO UPDATE SET
  pieces=EXCLUDED.pieces, ferme=EXCLUDED.ferme, membership=EXCLUDED.membership;
```
