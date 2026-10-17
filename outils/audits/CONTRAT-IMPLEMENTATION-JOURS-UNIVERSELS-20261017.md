# Contrat exécutable du calendrier universel — 17 octobre 2026

## Règles imposées
- Un seul calendrier civil pour tous les empires : Europe/Paris. Minuit ouvre la journée suivante pour tous les personnages.
- Obligations automatiques à chaque journée civile : loyers, échéances de prêts, fin de peines, fermetures, blessures, indisponibilités. Le nombre de jours se mesure en frontières de dates, jamais en 24 heures glissantes.
- Bénéfices volontaires : **un seul** ordre Dormir valide par PJ et par date ; PA, revenu universel et salaires liés aux fonctions/postes sont attribués seulement à cette occasion. Aucune récupération rétroactive des journées sans sommeil.
- Les transactions financières doivent être isolées de la refonte en cours sur `codex/reconstruction-finances-atomiques`.

## Constats prouvés dans la base de production (lecture seule)
1. `pa_repos_nocturne` verrouille `personnages_donnees` et compare `pa_repos_le` à la date Paris. Le quota de repos est correctement protégé.
2. `salaire_civil_percevoir` verrouille le versement par `personnage:date`, **mais n'exige pas** `pa_repos_le = date Paris`. Il faut verrouiller l'accès au versement par un sommeil effectif ; le simple ordre d'appel JS ne constitue pas une autorisation serveur.
3. `detention_clore_purgee` lit `personnages_donnees.day` et le compare à `jourFin` : la peine dépend encore du compteur hérité du PJ.
4. Le filet de secours `api/cron-minuit.js` compte `debutTs + jours × 24h` : incompatible avec un nombre de jours civils.
5. `plateau-personnage.js` fait `state.day = today + 1` après Dormir. Cela ne doit pas déterminer la date universelle, mais supprimer cette écriture sans convertir les lecteurs de `state.day` casserait les durées historiques.
6. La RPC salaire est appelée après la RPC PA. Un sommeil proche de minuit peut théoriquement ouvrir une incohérence de date entre les deux RPC. Le traitement final devra avoir une **date de référence transactionnelle unique**.

## Ordre d'implémentation obligatoire
1. Établir les schémas et toutes les voies d'écriture des peines, des fermetures, des loyers et prêts, et des salaires ; relever les données historiques qui portent des indices de jours individuels.
2. Concevoir la conversion des échéances historiques vers la date civile universelle, avec contrôle des valeurs ambigües. Ne pas convertir naïvement `jourFin` ou `jusquauJour` en timestamp.
3. Rendre la libération et la réouverture indépendantes de la connexion, idempotentes et comptées par dates civiles.
4. Réserver le bénéfice quotidien au repos attesté côté serveur, avec date transactionnelle commune ; travailler les RPC financières **avec** la branche Codex, jamais en concurrence.
5. Corriger les lecteurs de `state.day` puis retirer l'incrément au sommeil ; garder un affichage correct après F5, double onglet et changement d'appareil.
6. Tester les cas : dimanche 23:59 puis lundi 00:01 ; dimanche sommeil, lundi absence, mardi sommeil ; passage à l'heure d'été et à l'heure d'hiver ; absence de PJ ; double requête ; panne/reprise du cron ; ancienne peine et ancienne fermeture.

## Décision de sûreté
**Aucune migration de production n'est appliquée avant le traitement des données héritées et la validation de l'atomicité financière.** La présente branche constitue une préparation technique isolée, pas un déploiement fonctionnel.
