# Starovka — intérieurs de la raffinerie (15 novembre 2026)

## Décision de Fred

Trois scènes au même bâtiment `usine-principale`, situé entre les terrains constructibles et les logements collectifs :
- **Salle des ventes** : vente de carburant et de dérivés pétrochimiques (notamment plastique), intérieur impeccablement entretenu, vue vers les entrepôts et l'usine.
- **Bureau du directeur** : au-dessus de la salle des ventes, vue plongeante depuis l'étage sur les entrepôts et l'usine, atmosphère hivernale et lumineuse cohérente.
- **Intérieur de la raffinerie** : site pétrochimique industriel propre et opérationnel.

Aucune faucille ni aucun marteau dans les générations visuelles. Identité du monde **Sovarka**, pas de symbolique soviétique historique.

## Implémentation

Images fournies par Fred en PNG, converties en WebP VP8 avec perte (qualité 85) avec conservation de la résolution et suppression des originaux.

| Pièce | ID | Illustration |
|---|---|---|
| Salle des ventes | `salle_ventes_raffinerie` | `Starovka_raffinerie_salle_ventes.webp` |
| Bureau du directeur | `direction_usine` | `Starovka_raffinerie_bureau_directeur.webp` |
| Intérieur de l'usine | `interieur_raffinerie` | `Starovka_raffinerie_interieur_usine.webp` |

Ces pièces sont **propres à Starovka**. La `direction_usine` héritée est habillée sans toucher aux ordres du gabarit global. Les deux pièces supplémentaires n'ont **aucun nouvel ordre**, conformément à la demande d'illustration. Le PNJ Directeur Fabre du décor de Montrouge est supprimé par `personsVides: true` dans la surcharge locale.

L'accès serveur est ajouté par migration de `navigation_lieux_regles` ; aucune mécanique ni donnée PJ nouvelle.
