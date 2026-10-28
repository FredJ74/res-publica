# Intégration Luthécia — lot unique sans déploiement intermédiaire

Base : `main`, après publication du centre multimodal (`77d94363`).

## Sources (non fusionnées)

- Inventaire : PR #213, tête `ec79e5b13af18e7d9a7edba7d051d129c6fecfc7` (25 commits d'avance sur main, 1 de retard).
- Groupes et sécurité : PR #219, tête `d44665a5d418f7de6e17f2fbd1efa23c37839855` (104 commits d'avance, 1 de retard). **Encore brouillon : ne pas intégrer à la production avant clôture.**
- Synchronisation : PR #225 **exclue** (CAS/updated_at non universel).
- Optimisation Vercel #220 : `git.deploymentEnabled` déjà dans `main` ; pas de changement fonctionnel à reprendre.

## Conflits #213 × #219 (7 chemins)

1. `.github/workflows/coherence-client.yml` : conserver **tous** les nouveaux bancs des deux PR.
2. `RELAIS.md` : joindre les deux suivis sans perdre leurs états ni leurs réserves.
3. `plateau-justice-economie.js` : vérifier enchaînement des actions d'inventaire et de sécurité.
4. `plateau-multijoueur.js` : préserver les deux socles universels ; aucun doublon d'autorité.
5. `plateau-politique.js` : conserver les transactions serveur, y compris objets/tracts.
6. `plateau.html` : conserver les deux raccordements et leur ordre de chargement.
7. `supabase.js` : préserver l'inventaire versionné et les appels de groupes sans restaurer de PATCH aveugle.

## Conditions de publication

- Intégrer les fichiers disjoints, **réconcilier les 7 fichiers communs explicitement**, pas de stratégie « ours/theirs » aveugle.
- Vérifier que les migrations SQL des deux PR ne s'annulent pas et que leur application est ordonnée, notamment les RPC d'inventaire / position.
- Exécuter la totalité des tests client, les pilotes, et les bancs PostgreSQL jetables de chaque PR **sur le commit combiné**.
- Vérifier absence de nouvelles écritures client arbitraires ; réévaluer les risques de fiches périmées avec PR #225.
- Faire valider la fin fonctionnelle de #219 avant toute livraison.
- Fusionner **une seule** PR validée vers `main`, puis **un seul déploiement** Vercel production ; contrôler SHA/READY et recette en jeu.

## État réel

Cette branche est actuellement **une branche de préparation**, pas encore le code combiné. Aucune fusion dans `main`, migration ou déploiement Vercel n'a été exécuté par ce lot.
