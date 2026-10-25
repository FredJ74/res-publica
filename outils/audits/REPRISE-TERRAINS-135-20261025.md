# #135 — reprise du parcours terrain, 25 octobre

## Correction de reprise côté client

Après une réponse perdue, `constructionReconcilierCommandes` retrouvait le reçu et relisait les finances, puis effaçait l’intention avant de connaître le terrain courant. La lecture appelée ensuite par `chargerTerrainState` pouvait échouer : l’écran gardait un terrain ancien, sans preuve de reprise en attente. Le test combinant les deux vraies fonctions reproduit ce défaut avec l’ancien code.

La réconciliation attend désormais une lecture distante réussie du terrain, puis des finances et du bail si nécessaire. Elle conserve l’intention en cas d’échec ou de changement de contexte. Elle ne charge pas le snapshot ancien contenu dans le reçu. Une option interne du lecteur existant empêche d’appeler récursivement la réconciliation ; ce n’est ni une nouvelle route de navigation ni un contournement serveur. Aucun débit ni mutation métier client ajouté.

Fichiers : `plateau-construction-commandes.js`, `plateau-justice-economie.js`, versions de cache de ces deux scripts dans `plateau.html`, `banc-construction-commandes.cjs`. Dix tests ciblés réussis, dont cinq nouveaux : reprise avec terrain actuel, panne de lecture, panne financière après lecture, réponse destinée à un ancien personnage, contre-épreuve de l’ancienne perte d’intention. Contrôleur client : 111/111 après intégration de main `6a249a1`.

Aucune migration nécessaire pour **cette correction de reprise seule** : elle emploie les lecteurs de reçu, de terrain et de finances déjà utilisés. Elle ne remplace pas le prévol et l’installation coordonnée des quinze migrations terrain/banque de la livraison précédente. Ne pas fusionner la branche entière pour livrer quelques lignes indépendantes. Les audiences/BNE et leurs arbitrages restent au chantier de Claude.

Aucune fusion, installation Supabase ni vérification authentifiée en jeu par Codex. Les résultats décrivent des tests locaux.

## Parcours terrain complet sur PostgreSQL jetable

Le nouveau `banc-parcours-terrain-construction-135-local.py` raccorde les moteurs dans **une même base**, sans remplacer leurs commandes par des réponses simulées. Il réutilise le décor et les 61 assertions terrain/banque, les corps fournis dans le prévol, PR112 et les migrations de construction déjà préparées. Les 59 assertions de négociation de la fixture restent distinctes ; elles ne sont pas présentées comme de nouveaux parcours.

Cinq parcours sont exécutés :

| Parcelle de Luthécia | Superficie propre | Prix propre | Construction éprouvée |
|---|---:|---:|---|
| terrain-a-batir-1 | 2 150 m² | 25 800 FR | Hangar, 6 jours |
| terrain-a-batir-2 | 2 300 m² | 27 600 FR | Commerce standard, 12 jours |
| terrain-a-batir-3 | 2 300 m² | 27 600 FR | Commerce premium, 18 jours |
| terrain-a-batir-4 | 1 850 m² | 22 200 FR | Building, 24 jours |
| terrain-a-batir-5 | 2 750 m² | 33 000 FR | Hangar, 6 jours |

Ces valeurs sont comparées au générateur des parcelles depuis `data.js`, puis relues après acquisition et réception. Cette répartition des niveaux concerne **uniquement les scénarios de test**, aucune règle particulière n’est créée selon la parcelle. Les prix des matériaux proviennent également de `data.js`, et l’entrepôt est celui du seed existant de Luthécia, pas un autre identifiant inventé pour le test.

Deux parcours commencent par des squatteurs : compromis bloqué sans débit, libération via `terrain_negociation_conclure` et rejeu sans second versement. Le tirage de négociation est forcé à la réussite uniquement dans la fixture pour rendre le parcours reproductible. Le banc de négociation existant éprouve séparément les bornes et refus. Aucun nouveau barème de résistance ni combat ajouté.

Chaque parcours passe ensuite par le compromis avec permis, le refus de signer avant satisfaction de cette clause, l’instruction réelle sous verrou, l’accord tacite et son archive/SAS, l’acte de vente et l’imputation exacte du dépôt. Puis lancement à 35 %, priorité bancaire, entrepôt et rémunérations des ouvriers par les vrais moteurs, appels complémentaires à 70 % et 100 %, respect de la durée du palier, réception refusée trop tôt, plans validés et lots reçus pour premium/building. Les autres paliers restent indivisibles comme prévu.

Le changement de date est simulé **seulement en datant les marqueurs de la fixture à hier**, sans attendre plusieurs semaines ni changer l’horloge de production. À chaque étape, augmenter le jour personnel ne permet ni un second avancement ni un second paiement dans la même journée commune. Cela ne constitue pas une observation du cron réel pendant 24 jours.

Après achèvement : erreur injectée au moment du reçu de réception → terrain, fonds, stocks, lots, archives et reçus identiques à l’avant-transaction ; deux réceptions concurrentes avec la même requête → une réalisation et un rejeu ; nouvelle connexion → mêmes titre, permis, lots et reçu. **324 assertions intégrées**, pas 324 parcours indépendants.

Le banc compose aussi les gardes des anciennes commandes, le permis PR112, le lecteur de reçus, les plans initiaux et l’interdiction d’accélérer dans les quatre empires. Il applique chaque migration chargée deux fois immédiatement pour vérifier son rejeu ; il ne rejoue pas une ancienne définition après son durcissement. Aucun fichier SQL généré du baseline n’a été retouché.

`contre-epreuves-parcours-terrain-135-local.py` injecte trois défauts **dans la base jetable seulement** : deuxième journée autorisée, superficie/prix uniformisés, tranche de 75 % au lieu de 70 %. Les trois doivent faire échouer l’assertion correspondante ; un simple plantage sans le diagnostic attendu ne compte pas comme preuve.

### Limites et installation

Aucune nouvelle migration métier dans ce lot. La commande de prêt réel et ses refus restent couverts par le banc terrain/banque réutilisé ; ces cinq nouveaux parcours paient leur acquisition sur des fonds fictifs disponibles, sans revendiquer cinq parcours hypothécaires supplémentaires. Le scénario ne teste pas le combat, la police ou les cadavres : leurs bancs dédiés du workflow restent nécessaires. Les notifications et l’identité sont celles de la fixture, pas une authentification Supabase réelle. Les lots sont vérifiés dans les états serveur reçus ; leur exploitation n’est pas présentée comme une visite authentifiée du jeu.

L’ordre et les préconditions de production restent ceux de `LIVRAISON-TERRAIN-BANQUE-135-20261024.md` et des lots construction sélectionnés par l’agent principal. **Ne pas déduire du succès local que ces migrations sont déjà appliquées.** La composition locale testée n’est pas une consigne de rejouer tout le dossier migrations en production. Les 22 fonctions du relevé vivant sont une photographie datée ; les autres corps et dépendances doivent être comparés avant installation sensible.

Les preuves brutes de cette reprise sont rangées dans `luthecia-20261025/`. Les six contrôles globaux restent publiés séparément. Les nouvelles RPC d’ambassades intégrées de main sont signalées par Authority tant que l’extraction n’a pas été actualisée : ne pas modifier le baseline manuellement pour les faire disparaître. L09 global reste à raccorder et n’est pas déclaré terminé par ce lot terrain.

## Vérifications finales de ce lot

- 111/111 bancs client, dont dix tests du pont construction/relecture.
- 39/39 configurations PostgreSQL du workflow, avec le parcours des cinq terrains et les trois contre-épreuves ajoutés à la CI existante.
- 91/91 contre-épreuves historiques.
- 6/12 contrôles globaux : Classification, Baseline, Authority, Referential, Assemblage et Reconstruction restent rouges. Authority signale 42 RPC non extraites après les nouvelles audiences de main, et la signature interne commerce historiquement inconnue. Aucune empreinte ni fichier généré modifié pour masquer ces écarts.

Les preuves sont dans `luthecia-20261025/RESULTATS.json` et ses journaux associés. Aucun succès local n’est présenté comme une observation en jeu ou une migration appliquée.

## Suite en cours — vol de matériaux, hôte serveur privé

`20261025000429_chantier_vol_transactionnel.sql` réunit désormais la tentative de vol dans une transaction : identité/présence réelles, état du chantier, coût du catalogue existant (2 PA), jet et bonus, retrait par `terrain_chantier_acte`, livraison transitoire dans `objets_recus`, réception immédiate par **la véritable `inventaire_reclamer_livraison`**, effets sociaux, trace ou recherche et reçu complet. La livraison intermédiaire ne peut pas être observée comme un dépôt séparé après commit : réception et retrait sont annulés ensemble sur panne. Aucun deuxième moteur d’inventaire ou de combat.

Le bonus est consommé par le service privé de L09, seulement dans cette transaction. La formule existante est comparée aux fonctions pures réelles de `plateau-chantiers.js` sur douze cas : seuils 19/20 et 49/50, réputation, DUP, ISN, vigiles, séquence de métal 6/7/7. Les seuils ne deviennent pas des règles de combat nouvelles. Les deux requêtes distinctes concurrentes reçoivent 5 puis 0, jamais deux fois le même bonus.

Le reçu porte l’identifiant immuable du personnage, sa requête et la clé canonique pays/terrain : un rejeu ne peut pas changer d’empire ou de matière. Il rend le résultat historique avec les états actuels d’inventaire, de PA, de bénédiction et de terrain. Les refus ne créent ni objet ni paiement. Une ancienne révision et une sauvegarde REST sous rôle authenticated ne peuvent effacer le butin. Le moteur de réception conserve identifiants et métadonnées et enrichit seulement le premier lot correspondant, même si un ancien inventaire contient plusieurs piles de bois.

**45 assertions natives** couvrent également coma/hospitalisation, gel, chantier achevé, PA insuffisants, jet NULL, réponse perdue, double requête, panne au reçu final et écritures silencieusement ignorées. Les postconditions vérifient PA, retrait réel du stock, réception, indice social, trace et inscription judiciaire ; une réponse positive d’un ancien helper ne suffit pas. Trois contre-épreuves détectent un butin doublé, un bonus réutilisé et un reçu oublié. Les preuves ajoutées sont `VOL-CHANTIER-SERVEUR.txt` et `VOL-CHANTIER-CONTRE-EPREUVES.txt`.

**État d’activation : privé, pas encore raccordé au navigateur.** Cette avancée ne vaut pas activation complète de L09. Ne pas exposer l’attribution générale ni ce seul acte tant que les cinq autres actes et leur interface ne sont pas raccordés et que les anciens chemins ne sont pas fermés. Le client historique de vol n’est pas changé par cette migration préparée ; aucun déploiement partiel. La filature et le vol chantier ont maintenant leurs hôtes privés, les cinq autres restent à terminer.

### Dépendances et prévol du vol

Après le lot terrain/banque, le socle privé de bénédiction (et son refus des tirages NULL), le catalogue `ordres_jets_sites` et les helpers de statistiques/indices du lot filature. Réception atomique existante requise avec `inventory_revision`, `reception_token`, le trigger de révision et les trois RPC ; **ne pas la rejouer aveuglément**, elle est chargée seulement dans la base jetable pour les preuves. Tables de besoins quotidiens, traces, indices, inventaires, détentions et recherche requis.

La nouvelle migration vérifie la présence de ses fonctions et colonnes clés, refuse un registre préexistant inconnu et un homonyme de commande différent de son propre corps. Elle n’exécute aucun vol de démonstration. Les fonctions appelées doivent encore être comparées à leurs corps vivants par l’agent principal ; le prévol complémentaire a été enrichi. Le corps de la nouvelle commande attendu est `f74a0fba9ee0d31a81b337f6955f0e37`. La table des reçus a RLS et aucun accès applicatif ; la commande est révoquée pour PUBLIC, anon, authenticated et service_role. Ne pas activer avant vérification des chemins d’écriture historiques et de leurs fermetures coordonnées.
