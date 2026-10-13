# Correctif du catalogue alimentaire — 13 octobre 2026

Incident : SLAVA Chocolaterie de luxe (Angie Porcelana), fonds `fonds-republic-1791927686314-921164`, type `commerce-alimentaire`. Les portes `fonds_generiques_accessibles` et `fonds_matieres_accessibles` renvoyaient zéro ligne : les quatre génériques alimentaires existaient dans `catalogue_generique_type`, mais aucune recette n'avait de `generique_id` correspondant.

## Correction exécutée dans Supabase (données, pas DDL)

Seules dix recettes préexistantes avec `generique_id IS NULL` ont été reliées au catalogue. Aucun bail, fonds, prix, stock ni recette matérielle n'a été modifié.

```sql
UPDATE public.recettes_commerce SET generique_id = CASE
WHEN id IN ('cafe_boisson','jus_de_fruits','boisson_sans_alcool') THEN 'boisson'
WHEN id IN ('sandwich','sandwich_cheminots','snack_buvette','croque_monsieur_luthecia') THEN 'encas-a-emporter'
WHEN id IN ('plat_de_poisson','saucisse_puree','boeuf_bourguignon') THEN 'aliment-prepare'
ELSE generique_id END
WHERE generique_id IS NULL AND id IN ('cafe_boisson','jus_de_fruits','boisson_sans_alcool','sandwich','sandwich_cheminots','snack_buvette','croque_monsieur_luthecia','plat_de_poisson','saucisse_puree','boeuf_bourguignon');
```

## Vérifications serveur après correction

`fonds_generiques_accessibles('fonds-republic-1791927686314-921164')` renvoie **Boisson, Aliment préparé, Encas à emporter**.

`fonds_matieres_accessibles('fonds-republic-1791927686314-921164')` renvoie **cereales, fruits_legumes, poisson, produits_exotiques, viande**, maximum 2 chacune.

La catégorie `aliment-brut` n'a pas de recette validée et reste indisponible ; ne pas inventer de recette. Les recettes existantes sont des modèles système, pas une nouvelle gamme de chocolat créée automatiquement. Vérification visuelle côté Angie encore à faire (rechargement du panneau de gestion).

Note : cette opération a été appliquée directement en base, puis consignée ici pour traçabilité ; elle ne figure pas dans le registre des migrations de schéma.
