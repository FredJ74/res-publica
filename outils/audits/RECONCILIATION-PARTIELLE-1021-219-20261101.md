# #219 — tarifs : observations partielles et collecte unique

Suite de `64c8f037`, même branche. Aucun changement du moteur des groupes.

## Ce que les observations permettent de conclure

Le relevé de l'intégrateur annonce 1021 / `20261101134313`, 439 tarifs. Le MD5 `777f813481c6b690a9579d2471e69c4d` emploie `:` et `,` ; il ne remplace pas le MD5 canonique avec `|`, saut de ligne et tri C. Il n'est pas enregistré comme empreinte attendue du pilote.

| Triple | Relevé intégrateur | Sources intégrées | Interprétation démontrable |
|---|---|---|---|
| service_etage 0/50 | présent | présent, data.js hôtels de province | ne pas réinsérer comme tarif manquant |
| service_etage 0/150 | présent | présent, data.js hôtel capitale | conserver, aucun remplacement par 50 |
| acheter_terrain 2/25200 | présent | présent, data.js terrain6 Montrouge | nouveau prix déjà installé selon le relevé |
| acheter_terrain 2/3500 | absent | absent | ancienne valeur à ne jamais réinjecter |
| travailler_jardins 1/0 | présent | data.js et migration jardins | concordance partielle confirmée par l'intégrateur |
| laisser_legumes_jardins 0/0 | absent | présent dans data.js | entrée de présentation attendue par le générateur ; la RPC jardins_laisser_legumes utilise le verrou d'acteur et l'inventaire, pas payer_ordre : absence de triple n'établit pas une action cassée |
| prendre_legumes_jardins 0/0 | absent | présent dans data.js | même distinction : jardins_prendre_interne ne passe pas par payer_ordre ; ne pas créer un paiement parallèle |
| organiser_manifestation_spontanee 1/0 | absent | data.js + migration 20261101121000 | migration ajoute explicitement le triple et appelle payer_ordre ; lot déclaré dépendant de #219 dans RELAIS, ne pas en déduire qu'il est déployé |

Le générateur actuel rend **457** triples, l'ancien plan en attend **452** (six ajouts, retrait du prix3500). Les deux entrées jardins gratuites peuvent légitimement apparaître dans le miroir complet : leur origine est l'ordre d'interface, pas une consommation de PA inexistante. Aucune suppression arbitraire du générateur pour rejoindre 439.

Avec seulement huit présences/absences et un total, les 439 lignes ne sont pas reconstructibles. On ne peut pas déduire les autres ajouts/retraits ni réécrire la garde de la migration. L'ancien plan 438->452, son SQL et sa sentinelle restent explicitement **périmés et bloquants**, jamais transformés en plan1021 par simple changement d'empreinte. Seeds et références générés non modifiés sans observations de leur coupe.

## Manifeste unique prêt pour l'intégrateur

`outils/livraison/manifeste-collecte-certification-219.py` émet le manifeste JSON complet de collecte (requêtes incluses, empreintes de requêtes, formats d'import, protocole privé) :

1. relais canonique existant : quatre exports, contrôle global, registre, graines autorisées ;
2. six familles/racines/seaux depuis la requête canonique existante ;
3. registre complet et catalogue ciblé depuis le prévol existant ;
4. douze contenus complets et tarifs complets/contrôle/sentinelle ;
5. profils exacts référentiels et locale du pilote ;
6. capture des quatre tables au format exact du chargeur privé.

Ce sont sept SELECT (registre/catalogue/contenus séparés), un seul manifeste. Exécuter sous une même transaction REPEATABLE READ READ ONLY terminée par ROLLBACK. Si le connecteur ne préserve pas la transaction, arrêter la certification d'une coupe mélangée : collecter via une voie autorisée garantissant le snapshot, ne pas déclarer la cohérence sur le seul compte des versions. Aucune récupération de données de PJ ni d'auth.users. Aucun outil de production appelé ici.

Les sorties restent en dehors de Git, répertoire700/fichiers600, SHA-256 des octets d'origine transmis indépendamment. Aucun fichier privé réel n'est publié. Le format des profils et les clés de capture sont explicités dans le manifeste ; le relais existant matérialise les exports. La conversion des formats ne constitue pas une mesure de production et ne doit jamais renuméroter le registre.

## Tests de cette intervention

Deux tests nouveaux réussis : composition des sept requêtes, contrats, SHA des requêtes, douze tables, absence auth.users ; contre-épreuves DELETE dans CTE, UPDATE, SELECT INTO, transactions/multi-instructions refusées. Le test est raccordé au workflow existant, sans pipeline supplémentaire. Le manifeste n'exécute rien et ne produit aucun DDL.

État conservé : outillage principal **74/75** (plan tarifaire périmé), globaux **9/12**, Baseline/Authority/Referential rouges. Leurs causes précédemment documentées ne sont pas effacées par ce manifeste. Le test de collecte **2/2** est distinct des75. Aucun 95/rollback/rejeu/27 HTTP sur un clone1021 certifié. Aucune migration, fusion ni livraison de production.

## Suite indispensable

L'intégrateur disposant du connecteur doit transmettre le paquet privé courant via le manifeste. Fred n'a aucune commande SQL ni aucun secret à manipuler. Après réception réelle : vérifier SHA/coupe/locale, établir le delta tarifaire complet, rendre les seeds via les générateurs, traiter les définitions/policies observées, six racines/douze tables puis95/rollback/rejeu/27HTTP. La dépendance #318/#324 et l'arbitrage d'hospitalisation restent à Claude.

**Certification non terminée : blocage extérieur de capture complète, pas indisponibilité de PostgreSQL.**
