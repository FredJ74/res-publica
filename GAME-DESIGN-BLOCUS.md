# Blocus syndical — règles décidées

Décisions de Fred. Mécanique d'août 2026 déjà écrite dans le code, à remettre en service et à
passer au serveur (chantier à ouvrir). État au 02/11/2026 : parcours inaccessible
(`getMonSyndicatEtGrade` lit `state.orgas` / `chargerOrgas`, qui n'existent pas) ; dispersion par
la police impossible (elle cherche le blocus dans le commissariat).

## Décisions explicites de Fred (02/11/2026)

1. **Qui organise et renouvelle** : le Secrétaire Général et le Secrétaire Général Adjoint du
   syndicat, et eux seuls. (Le code laissait passer `gradeIdx` 1-2, soit Délégué et Secrétaire
   Adjoint, et bloquait le Secrétaire Général : à corriger.)
2. **Effet sur le bâtiment bloqué** : on peut entrer dans la première pièce, pas dans les autres ;
   les ordres du bâtiment ne sont pas accessibles.
3. **Ordres qui restent possibles** : ils ne sont pas rattachés au bâtiment. « Renouveler le
   blocus » relève du syndicat (menu du personnage) ; « Faire intervenir les forces de l'ordre »
   relève du commissaire. Conséquence technique : depuis son bureau, le commissaire choisit parmi
   les blocus en cours dans sa ville.

## Règles déjà présentes dans le code (août 2026), conservées

- Prérequis : au moins 2 militants PNJ recrutés dans le syndicat.
- Réussite : min(90, 10 + 6 × militants mobilisés + puissance/5) % ; intensité : min(90, 10 + 6 × militants).
- Renouvellement quotidien ; fin automatique après 25 h sans renouvellement (nuit).
- Effet de nuit : le maire de la ville perd max(1, intensité/15) POP.
- Dispersion par la police : max(10, min(90, 55 − intensité/3)) % ; les militants restent employés.
- Répression violente : +1 `repressionsSubies` (puissance +8) ; chaque blocus réussi : +1 `blocusReussis` (puissance +5).
- Interdit pendant une grève d'un syndicat de policiers (répression).

## À faire au serveur (règle « une seule réalité »)

Jet, écriture du blocus sur le bâtiment, palmarès du syndicat, renouvellement, dispersion et
répression par des fonctions serveur ; refus d'entrer au-delà de la première pièce et refus des
ordres du bâtiment tenus par le serveur, pas seulement masqués à l'écran.
