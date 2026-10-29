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

## Mariage — corrigé (décision de Fred : « on ne peut pas être marié contre son gré »)

- `20261029201000_mariage_par_serveur.sql`, **applicable tout de suite** (ajoute des fonctions et une colonne) :
  - `mariage_demander` : 1 PA ; pour un PNJ, le tirage et les 200 FR se font au serveur ;
  - `mariage_repondre` : seul le destinataire répond ;
  - `mariage_officialiser` : il faut une demande acceptée, les deux présents dans la même pièce, aucun des deux déjà marié ; 2 PA + 200 FR ;
  - `mariage_dissoudre` : divorce (1 PA + 200 FR) ou veuvage, seulement si la succession est ouverte.
- `20261029201100_mariage_fermer_ecran.sql`, **après le déploiement de l'écran** : l'écran ne peut plus écrire `mariages` ni `demandes_mariage`.
- Défauts corrigés au passage :
  - le divorce et le veuvage échouaient en silence (colonne `raison_dissolution` absente), alors que le divorce avait déjà été payé ;
  - avec un PNJ, les 200 FR n'étaient retirés que de l'affichage.
- Reste à savoir : la relation allié / ennemi du PNJ n'est connue que du navigateur. Le serveur la reçoit telle quelle ; le tirage, lui, est fait au serveur.
- Répétition (transaction annulée), 12 cas conformes. Refusés : mariage forcé direct, célébration sans consentement, accepter sa propre demande, acceptation écrite directement, conjoint absent. Acceptés : demande, réponse du destinataire, célébration (PA 20→17, FR 5000→4800, demande « celebree »), divorce, rejeu sans double paiement.

## Méthode des gardes (correction du 29/10)

Les gardes sont en `SECURITY INVOKER` et testent `current_user`. Une écriture directe de l'écran
s'exécute sous le rôle `authenticated`. Une fonction serveur `SECURITY DEFINER` (Helvetia, prêt
national, `taux_imposition_fixer`, `mariage_*`) s'exécute sous `postgres`. `est_appel_serveur()`
répond « joueur » dans les deux cas : une garde qui s'y fie bloquerait aussi les commandes serveur
légitimes. La répétition le confirme : une fonction serveur appelée par le joueur écrit bien
prêts et budget, alors qu'une écriture directe est refusée.

## Ordre d'application pour ChatGPT

1. `20261029200000` (prêts, budgets municipaux) et `20261029201000` (fonctions du mariage) : tout de suite.
2. Déploiement de l'écran : `plateau-politique.js` et `plateau-personnage.js` passent en `?v=mariage-20261029`.
3. `20261029201100` (fermeture des écritures de mariage par l'écran).

## Encore ouvert — signalé, non corrigé

| Table | Écriture acceptée | Impact réel | Pourquoi non corrigé ici |
|---|---|---|---|
| `budgets_clubs.caisse` | crédit libre (12 clubs) | réel : lue par cotisations, accessoires, primes de match, redressement fiscal, subventions | 6 flux légitimes de l'écran la créditent ; périmètre clubs et championnat (Codex) |
| `organisations.caisse` | caisse de toute organisation | réel | 5 flux légitimes de l'écran (collecte, dividendes, cotisations, dépôts) ; périmètre organisations (Codex) |
| `budgets_nationaux.data` | blob national réécrivable | à mesurer clé par clé | une dizaine d'écritures légitimes de l'écran (`sbSaveBudgetNational`, couvre-feu, effort de guerre) ; il faut une RPC par clé |
| `quetes_actives.statut` | quête déclarée résolue | récompense non encore vérifiée | à auditer avec le moteur de quêtes |
| `etats_urgence`, `niveaux_prison` | écriture libre | faible : aucune fonction serveur ne les lit aujourd'hui | à fermer dès qu'un moteur serveur les lira |

Refusées ou sans effet à l'attaque : les prêts d'autrui, la suppression de ses `actions_tracables`,
`greves`, `transferts` et `successions` (contrainte).
