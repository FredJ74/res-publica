# Écritures de l'écran encore actives — bilan du 29/10/2026 (Claude)

Méthode : attaque jouée au rôle `authenticated` (Jean Jaaj) dans une transaction annulée, sur la
cinquantaine de tables qu'un joueur connecté peut écrire. Chaque écriture acceptée a ensuite été
confrontée à ses **lecteurs serveur réels**. Une table qui ne sert qu'à l'affichage n'est pas comptée comme une faille.
Aucune donnée de joueur n'a été modifiée.

## Corrigé (migration préparée, non appliquée)

`migrations/20261029200000_prets_budgets_municipaux_gardes.sql`. Elle est compatible avec l'écran en ligne et
peut être appliquée tout de suite par ChatGPT. Banc : `outils/bancs/banc-ecritures-ecran.cjs` (13 tests,
contre-épreuve par mutation faite).

| Table | Défaut démontré | Après la garde |
|---|---|---|
| `prets` | un joueur soldait ses propres prêts (2 lignes) | seule l'écriture légitime passe : mettre ses propres prêts en `succession`. Le reste reste aux fonctions serveur |
| `budgets_municipaux` | tout joueur réécrivait le budget de n'importe quelle ville, dont `tauxFoncier` (taxe foncière nocturne) et les taux de taxe sur les ventes | l'écran peut seulement créer le budget neuf d'une ville (`key`, `tauxFoncier` 0,05) et poser ou lever `manifestationInterdite`, réservé au ministre de l'Intérieur. Le maire passe par `taux_imposition_fixer`, déjà en place |

Répétition serveur, par upsert comme le fait l'écran :

| Cas | Résultat |
|---|---|
| solder un prêt | refusé |
| créer un prêt | refusé |
| prêt en succession | accepté |
| taux foncier à 9 | refusé |
| ville neuve par défaut | acceptée |
| ville neuve forgée | refusée |
| interdire une manifestation sans être ministre | refusé |
| interdire une manifestation en étant ministre | accepté |

## Encore ouvert — signalé, non corrigé

| Table | Écriture acceptée | Impact réel | Pourquoi non corrigé ici |
|---|---|---|---|
| `budgets_clubs.caisse` | crédit libre (12 clubs) | réel : lue par cotisations, accessoires, primes de match, redressement fiscal, subventions | 6 flux légitimes de l'écran la créditent ; périmètre clubs et championnat (Codex) |
| `organisations.caisse` | caisse de toute organisation | réel | 5 flux légitimes de l'écran (collecte, dividendes, cotisations, dépôts) ; périmètre organisations (Codex) |
| `budgets_nationaux.data` | blob national réécrivable | à mesurer clé par clé | une dizaine d'écritures légitimes de l'écran (`sbSaveBudgetNational`, couvre-feu, effort de guerre) ; il faut une RPC par clé |
| `mariages` | mariage forcé avec un autre joueur | réel : copropriété au terrain, courrier au conjoint, état civil | aucune fonction serveur de mariage ; question de conception posée à Fred (consentement) |
| `quetes_actives.statut` | quête déclarée résolue | récompense non encore vérifiée | à auditer avec le moteur de quêtes |
| `etats_urgence`, `niveaux_prison` | écriture libre | faible : aucune fonction serveur ne les lit aujourd'hui | à fermer dès qu'un moteur serveur les lira |

Refusées ou sans effet à l'attaque : les prêts d'autrui, la suppression de ses `actions_tracables`,
`greves`, `transferts` et `successions` (contrainte).
