# Recette immobilière #135 — Chromium et Arnie

25 octobre 2026. Branche `codex/recette-immobilier-135-20261025`, issue de main `40b6fe07b22e64eb76c1210263a5ca53f04f59d8`. Les travaux de virements et de salaire horaire présents dans main sont conservés. Aucun composant privé L09 de l'autre branche n'est importé.

**Recette en jeu non terminée. Aucun test authentifié avec Arnie n'a pu être exécuté.** Les preuves locales ci-dessous ne sont pas une visite du jeu de production.

## Dispositif repris et autorisation

Le pilote existant est `outils/e2e/luthecia.cjs`, protégé par `consultation.cjs`. Son lancement manuel se fait par `.github/workflows/beta-testeur-luthecia.yml`, environnement Actions `luthecia-e2e`, mode `consultation_seule`. Il utilise les trois secrets historiques d'Arnie, sans repli vers un autre personnage. Il contrôle le compte classique confirmé, l'UID attendu et la réponse autoritaire de `mon_personnage` avant toute scène.

Les derniers résultats **accessibles dans le dépôt**, datés du 20 octobre, indiquent zéro visite réelle et un lancement distant bloqué. Les résultats Actions récents ne sont pas consultables depuis cet environnement ; ils ne sont ni déclarés absents ni remplacés par les archives.

L'autorisation reste limitée aux consultations et déplacements sans conséquences démontrées. Le pilote actuel interdit les mouvements : l'entrée dans une pièce appelle une sauvegarde générale, et les effets vivants des déplacements ne sont pas attestés ici. Cette garde n'a pas été supprimée. Aucune commande financière, sauvegarde, réception, création de compte ou modification d'authentification n'a été autorisée par ce lot.

Point important : **`acheter_terrain` engage directement le dépôt de garantie** via `finance135Acquerir(...,'depot',...)`. Ce n'est pas une simple ouverture de fiche. Il n'a jamais été cliqué avec Arnie. Les tests locaux n'appuient pas non plus sur ce bouton ; ils contrôlent son affichage et ouvrent seulement le compromis sans le signer.

## Vérifications réelles tentées

| Vérification | Observation | Conséquence |
| --- | --- | --- |
| Git distant | Lecture de main et sauvegarde de branche possibles | Reprise du code actuel |
| Lecture des campagnes Actions par `gh api` | Refus `Forbidden` vers api.github.com | Derniers résultats et lancement manuel distants inaccessibles |
| HTTPS public du jeu | Tunnel proxy `CONNECT 403`, serveur de refus Envoy | Aucun statut applicatif Vercel obtenu ; cela ne prouve pas une panne du jeu |
| Secrets locaux `HG_E2E_ARNIE_EMAIL/PASSWORD/UID` | Absents ; les secrets Actions ne sont pas récupérables en clair | Aucun identifiant inventé ou emprunté à un autre compte |
| Lancement du pilote existant en consultation | `BLOQUE`, `UID_ARNIE_NON_VERIFIE`, zéro visite et zéro acte | Arrêt avant navigateur et authentification |

Aucune donnée de joueur n'a été lue ou modifiée pour tester. Aucun accès à `auth.users`, aucune création/conversion/réinitialisation de compte, aucune mutation d'Arnie. Aucun secret de connexion n'est inclus dans les preuves.

## Corrections techniques démontrées

### 1. Achat sans permis : accès au dossier existant

Dans le code actuel, un propriétaire qui avait acquis sans clause de permis pouvait cliquer sur « Construire », mais recevait seulement « Permis requis ». Les cinq terrains ne présentent pas d'autre ordre de dépôt dans cet état. Le moteur de demande existe pourtant.

Le test Chromium reproduit cinq échecs sur main, un pour chaque terrain. Le handler commun `ouvrirModalConstruire` rejoint maintenant `doDeposerDemandePermis(1,100)`, sans prélèvement à l'ouverture. Les contrôles de propriété, bâtiment existant, chantier et occupation restent exécutés avant ce raccordement. Le dossier conserve ses règles d'instruction et de carence. Seule sa confirmation passe par la RPC atomique déjà existante.

Aucun changement de tarif, délai, superficie, prix d'achat ou moteur serveur. La version du script dans `plateau.html` est actualisée pour son futur chargement. Le correctif utilise la fonction commune sans branche particulière par numéro de terrain.

### 2. Dépendance du pilote absente de son workflow

`test-consultation.cjs` importait Acorn depuis `outils/vercel/node_modules`, tandis que le workflow du pilote n'installe que `outils/e2e`. Sans installation préalable de Vercel, trois tests d'identité échouaient avec `MODULE_NOT_FOUND`, avant la campagne.

Cette panne est reproduite dans un répertoire sans constructeur Vercel. Acorn est maintenant une dépendance de développement explicite, épinglée à la version déjà utilisée et verrouillée dans le pilote. Le même extrait passe ensuite ses trois tests. `auth.js` et les protections de compte restent inchangés. Il n'est pas nécessaire d'installer tout le constructeur Vercel pour faire tourner le pilote.

## Résultats isolés exécutés

| Banc | Résultat et portée |
| --- | --- |
| Pilote existant, complété par la recette immobilière Chromium | **88/88 tests**, aucun ignoré ; 69 préexistants et 19 comptés par Node pour le nouveau banc, dont son test parent |
| Contrôleur client complet de cette version de main | **105/105 bancs** |
| Clients ciblés terrain, permis, banque et construction | **25/25 tests** |
| Banque/acquisition sur PostgreSQL jetable | **61 assertions** |
| Parcours des cinq terrains sur la même base jetable | **324 assertions** |
| Dépôt de permis atomique sur PostgreSQL jetable | **56 assertions** |
| Trois contre-épreuves du parcours SQL | Prix/superficies uniformisés, jour rejoué et tranche financière altérée : les trois sont détectés par les assertions attendues |
| Contrôles globaux | **5/12** ; les sept rouges sont déjà présents sur main `40b6fe0` |

Les résultats globaux ont aussi été obtenus sur un worktree intact de main : mêmes lignes de verdict et mêmes écarts, seul l'ordre d'énumération de deux chemins de fixtures diffère. Les rouges sont Workflow (cinq fichiers SQL de fixtures hors des emplacements reconnus), Classification, Baseline, Authority, Referential, Assemblage et Reconstruction. Aucun baseline, empreinte ou test n'a été ajusté pour les masquer. Ce lot de recette ne répare pas ces chantiers indépendants.

La première tentative de contre-épreuve « prix » a rencontré une dépendance absente après le test volontaire sans Vercel : elle **ne compte pas** comme détection métier. Après rétablissement des dépendances du générateur, le mutant échoue bien sur `superficie et prix propres a terrain-a-batir-2`. Les sorties conservées des trois mutants correspondent aux assertions métier attendues.

### Ce que contrôle le nouveau Chromium local

Les sources réelles sont extraites par analyse syntaxique, sans réécrire le routeur ni les fonctions métier. Le navigateur charge les déclarations actuelles, le rendu et les formulaires existants. Seules la scène, les identités, les lectures et les autorisations sont des fixtures locales.

- Cinq terrains, menus réels, ordres et clauses prêt/permis du compromis.
- Superficies distinctes : 2 150, 2 300, 2 300, 1 850 et 2 750 m² ; prix respectifs 25 800, 27 600, 27 600, 22 200 et 33 000 FR.
- Accès au permis après achat sans permis, sans signature ni lancement.
- Construction autorisée et approvisionnement affichant 6/11/17 FR.
- Prêt travaux refusé sur le terrain avec renvoi au guichet, puis formulaire national consultable dans la fixture bancaire.
- Refus de tiers, dossier en instruction, carence après refus, chantier/bâtiment existants, cadavre et squatteurs.
- Ancienne impasse rétablie par contre-épreuve ; aucune demande n'apparaît alors.
- Aucune mutation ni requête de backend émise par cette recette de formulaires.

Les 324 assertions SQL parcourent les commandes réelles sur les cinq terrains fictifs : compromis, négociation selon occupation, permis et accord tacite, acquisition, appels 35/35/30, matériaux et progression, réception, lots, relecture depuis une nouvelle session, concurrence et rollback. Les horloges et identités sont simulées ; aucun délai de production n'est raccourci. Ce banc ne prouve ni les droits JWT vivants ni les appels d'un navigateur de production.

## Encore non vérifié en production

Visite des cinq scènes avec Arnie, positions et retours réels, images et cadrage déployés, ordres effectivement servis par Vercel, requêtes authentifiées de prêt/permis/matériaux/construction et compatibilité du catalogue vivant. Les transactions, signatures, paiements, livraisons et réceptions restent hors de l'autorisation d'Arnie ; leur preuve actuelle est isolée.

Le correctif ne nécessite aucune migration. Les migrations déjà présentes ne sont ni rejouées ni déclarées installées à partir des seuls commits. Aucun déploiement n'est attesté par cette session. La recette exige un runner autorisé ayant accès au jeu et aux secrets Actions existants ; les effets de navigation doivent rester contrôlés avant tout mouvement du personnage. Aucune manipulation SQL ni transmission d'identifiants n'est demandée au game designer.

Les preuves sont archivées sous `outils/audits/recette-immobilier-135-20261025/` ; les résultats authentifiés restent explicitement à zéro. **La recette en jeu n'est pas close.**
