# Commerce universel et rattachement aux locaux — décision du 16 novembre 2026

**Statut : décision du game designer, applicable à tous les empires.** Cette doctrine prévaut sur les anciennes interprétations d'un commerce figé par son bâtiment. Elle ne remplace ni les contrôles de propriété, ni les transactions serveur.

## Principe
Le **local / bâtiment** est le support physique : adresse, accès depuis la rue, décor, pièces, propriétaire des murs. Le **commerce** est l'activité économique configurable par son exploitant : identité, familles de produits, articles, prix, inventaires, caisse. La présence d'une librairie dans un centre d'affaires ne réserve pas la librairie à ce genre de bâtiment, ni à cette ville. Tous les locaux commerciaux prévus à cet effet utilisent le système de commerce commun ; ne jamais créer de logique de vente par bâtiment ou par ville.

## Choix de l'exploitant
- **Gratuit / freemium : 2 familles d'articles, jusqu'à 4 articles.**
- **Premium : 3 familles d'articles, jusqu'à 10 articles.**
- La reprise ou le rachat d'un commerce existant **permet de réinitialiser le type de commerce** et de choisir une autre activité, dans les mêmes limites de forfait.
- L'enseigne et le décor ne doivent pas verrouiller les catégories. Une presse peut vendre des livres et des tracts et, si l'exploitant le souhaite, d'autres références autorisées par le socle.
- Les exemples d'articles ne sont pas des références automatiquement offertes, ni des dotations fictives.

## Règles de mise en œuvre
1. Ne pas dupliquer le moteur de commerce. Réutiliser les ordres et contrôles serveur communs.
2. Ne pas hériter automatiquement des pièces d'un modèle d'immeuble si la boutique n'a qu'une pièce : lui créer son lieu propre, sans compromettre les éventuels bureaux de l'immeuble voisin.
3. Les politiques et restrictions municipales **ne sont pas définies** ; ne pas en inventer.
4. Distinguer décision, implémentation, tests et mise en production. Vérifier les plafonds réellement imposés côté serveur avant d'annoncer leur efficacité.

## Application à Starovka : presse du journal Metel
Une seule pièce `presse` dans le bâtiment `presse-starovka`. Elle donne sur la rue du Blizzard, utilise l'intérieur de l'imprimerie déjà fourni, et présente le dispositif commun de commerce PJ. **Pas de hall, pas de bureau de location, pas de pièce de rédaction supplémentaire dans ce commerce.** Le centre d'affaires existant, situé dans l'autre rue, conserve ses bureaux propres. Les livres (dont l'exemple « guide des baies sauvages ») et les tracts doivent être des références possibles, sans être imposés au joueur. Le catalogue d'articles et les opérations de location restent des données et décisions serveur.
