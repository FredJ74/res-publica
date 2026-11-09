# Navigation, cartographie et accessibilité — constat serveur

**9 novembre 2026, Supabase `res-publica`, lectures SELECT uniquement.** Les graphes et sorties viennent de `public.rue_noeuds_serveur` et `public.rue_sorties_batiments`. Aucun déplacement PJ, aucune écriture de position ni aucune entrée de bâtiment n'a été exécutée.

## Graphes de rues par ville
| Empire | Ville | Nœuds de rue | Arcs déclarés (voisins) | Composantes connexes (non orientées) | Cibles inexistantes | Liens sans arc retour |
|---|---|---:|---:|---:|---:|---:|
| Républia | Luthécia | 17 | 40 | 1 | 0 | 0 |
| Républia | Port-Sainte-Marie | 14 | 40 | 1 | 0 | 0 |
| Républia | Montrouge | 14 | 28 | 1 | 0 | 0 |
| Sovarka | Novomirsk | 18 | 43 | 1 | 0 | **1** |
| Sovarka | Starovka | 15 | 30 | 1 | 0 | 0 |
| Sovarka | Krasnov | 16 | 32 | 1 | 0 | 0 |

Le calcul de connexité ignore le sens des arcs et n'analyse ni affichage des flèches, ni coûts, ni gardes serveur. **Un réseau connexe ne démontre donc pas un déplacement réussi en jeu**. Les arcs sont des entrées de `voisins`, pas nécessairement des rues physiques différentes.

### Asymétrie de Novomirsk, à vérifier
`novomirsk-vue-15` expose un arc **droite → `novomirsk-vue-16`**, alors que `novomirsk-vue-16` propose des arcs **arrière → vue 14** et **tout droit → vue 17**, sans retour direct vers 15. Cela peut relever d'un trajet dirigé voulu, de la direction artistique, ou d'un défaut de raccordement. **Ne pas corriger sans examen de `plateau-navigation.js`, des images et du sens de circulation voulu**. Cette anomalie est un candidat de recette, pas un bug confirmé.

## Sorties de bâtiments enregistrées
| Empire | Ville | Lignes de sortie | Bâtiments distincts | Sorties vers un nœud introuvable |
|---|---|---:|---:|---:|
| Républia | Luthécia | 36 | 36 | 0 |
| Républia | Port-Sainte-Marie | 35 | 35 | 0 |
| Républia | Montrouge | 53 | 47 | 0 |
| Sovarka | Novomirsk | 35 | 34 | 0 |
| Sovarka | Starovka | **3** | **3** | 0 |
| Sovarka | Krasnov | **5** | **5** | 0 |

Les sorties de `rue_sorties_batiments` ne sont **pas nécessairement la totalité des entrées possibles** : les bâtiments peuvent aussi utiliser d'autres références, gabarits ou mécanismes de téléportation. Mais les **3 sorties de Starovka** et **5 de Krasnov** demandent une vérification explicite au regard des bâtiments visibles et de leurs zones cliquables. Ne pas déduire que seules 3 ou 5 structures sont visitables sans lire le routeur et tester.

## Géographie et progrès de contenu
- `public.villes` comporte 12 villes (3 pour chacun des quatre empires) ; seuls Républia et Sovarka ont des **nœuds de rue** dans `rue_noeuds_serveur` au moment de la lecture. Cela **ne démontre pas** que les six villes des autres empires sont impossibles à visiter (d'autres modes de navigation pourraient exister), mais interdit d'affirmer qu'elles ont un graphe comparable.
- `data.js` définit actuellement 110 bâtiments avec 303 clés de pièces dans l'objet `BUILDINGS` ; un bâtiment de modèle ne signifie pas un raccord disponible dans toutes les villes.
- Les parcours internes, accès par poste, bâtiments fermés, transferts et passages douaniers ne sont pas vérifiés par cette lecture.

## Protocole de recette à prévoir
Pour chaque ville jouable et chaque entrée de bâtiment : capturer le SHA publié, le nœud initial, la zone cliquable, la destination attendue/confirmée par le serveur, l'image affichée, la disponibilité des flèches de retour, le comportement après refresh/reconnexion et sur mobile tactile. **Pour le nouvel arrivant**, mesurer s'il peut identifier où il est et revenir sans assistance. Les cartes ne doivent pas seulement être correctes comme graphe : elles doivent être compréhensibles.

## Verdict de l'audit statique
**Vérifié :** connexité non orientée des six graphes connus, absence de destination inexistante dans leurs voisins, sortie→nœud valide pour toutes les lignes répertoriées, une asymétrie Novomirsk. **Non vérifié :** trajet navigateur/serveur sur PJ réel, flèches visibles, disponibilité de chaque entrée et lisibilité des plans. Aucun changement de navigation effectué.
