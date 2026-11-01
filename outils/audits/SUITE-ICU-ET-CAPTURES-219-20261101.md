# PR #219 — suite contrôlée du 01/11 : ICU et chargement privé exact

**NON TERMINÉ — blocage de transfert privé réduit et préparatifs exécutables.**
Main contrôlé : `ddb72dbd`, déjà ancêtre de la branche ; aucun code de jeu ni
migration modifié dans cette reprise. Premier lot poussé : `96886939`.

## Résultat réellement exécuté

- PostgreSQL **17.6 avec ICU** compilé/installé localement, séparé du précédent
  binaire sans ICU ; mêmes sources officielles, pgcrypto installé, aucun service
  payant, aucun accès en écriture à Supabase.
- Candidat ICU `en-US`, fournisseur `i`, libc `en_US.utf8` : **six racines et tous
  leurs seaux concordent**, avec le collecteur et les références inchangés.
  La locale interne candidate et les versions locales `153.128` sont consignées,
  **pas attribuées à la production** : seul le fournisseur `i` et le nom libc
  ont été transmis par l'intégrateur. La capture complète doit lever ce doute.
- Le garde des référentiels échoue toujours sur les **mêmes cinq tables** ; les
  sept autres concordent. Le catalogue complet reste explicitement **non
  certifié**. Le drapeau de certification complète n'est plus levé par les seules
  racines de schéma.
- **64/64 tests d'outillage**, réellement sur le nouveau PostgreSQL 17.6 ICU
  (version affichée). Sept tests ajoutés à la précédente suite 57, dont refus de
  capture dans le dépôt, configuration ICU incomplète, import exact, six cas de
  refus sans mutation, erreur SQL sans divulgation, conservation de FK, et
  exécution de la requête documentaire sur quatre tables fictives.
- **10/12 contrôles globaux** rejoués : Workflow et les neuf autres conformes ;
  Authority et Referential toujours rouges, causes détaillées dans
  `PORTES-HISTORIQUES-219-20261101.md`. Aucune attente ajustée pour les verdir.
- Composition des **95 migrations** : ordre et empreintes vérifiés, une seule
  transaction, SQL composé SHA256
  `9c1fcc067da5eb6846052bcd564052608cb10679cdb8b47337c645cff5775c58`.
  **Pas d'installation des 95 sur ce clone**, pas de rollback/rejeu ni des
  27 HTTP sur ce clone : la barrière amont interdit de les présenter comme faits.

Les **156 bancs clients, 105 pilote, 379 groupes/combats et trois mutations** de
la passe précédente restent leurs preuves datées, sans nouvelle exécution
inutile de scripts du jeu inchangés. Les 27 HTTP authentifiés et rollback/rejeu
95 antérieurs restent des preuves sur leur décor déclaré, pas sur celui-ci.

Rectification de précision conservée dans la preuve précédente : les premiers
57 tests d'outillage utilisaient le binaire pgserver fourni (16.2), pas le 17.6
natif. La reconstruction intégrée utilisait déjà le vrai 17.6. Les nouveaux
passages sélectionnent explicitement le binaire et impriment sa version.

## Ce qui est désormais prêt à recevoir les données

`--referentiels-capture` charge **uniquement les quatre tables autorisées**, dans
la base jetable démarrée par le pilote. Le JSON brut est typé par PostgreSQL,
sans passer les nombres par une réécriture flottante du navigateur/Python.
Registre, fournisseur de locale externe, locale complète, colonnes, cardinalités
et empreintes doivent concorder. Upsert puis retrait des seules clés absentes,
FK actives ; aucune suppression/recréation d'un parent référencé conservé.
Erreur SQL ou empreinte différente : import entier annulé, pas de valeurs privées
dans les diagnostics. BNE est vidé seulement selon son vide attesté. Le garde
d'origine vérifie ensuite les **douze** tables indépendamment du chargeur.

La capture est interdite dans le dépôt et son contenu ne figure pas dans les
preuves publiques. Le test valide aussi la requête documentaire complète.
Les jeux de données des tests sont entièrement fictifs ; aucune authentification
réelle, aucun inventaire, finance ou personnage existant importé.

## Blocage extérieur établi, transfert unique

Recherche effectuée dans les exports privés, captures/seeds, archives et
répertoires de relais disponibles : seuls les dix anciens seeds et les essais
des générateurs sont présents, pas les 100 lignes exactes des quatre tables.
L'API GitHub **artefacts** refuse `Forbidden`, comme celle des commentaires.
Aucun connecteur Supabase exposé dans cette session. Le précédent refus du proxy
Supabase est conservé, sans le rebaptiser refus RLS et sans boucle de tentatives.

**Action technique unique pour l'intégrateur ayant le connecteur : transmettre
un fichier JSON privé issu de la requête documentaire actualisée**, avec les
100 lignes complètes et les détails de locale ajoutés. Destination et format :
`EXPORT-REFERENTIELS-MANQUANTS-219-20261101.md` ; fichier local prévu
`/tmp/hg219-prives/referentiels-1012.json`. Il peut être joint dans la conversation,
jamais publié dans Git ou un commentaire de PR. Aucune commande demandée à Fred,
aucune création de compte et aucun secret à transmettre.

## Ordre d'intégration encore conditionnel

1. Charger cette capture privée sur le clone 17.6 ICU correspondant exactement
   à sa locale et à sa version, puis exiger six racines, registre et 12 tables.
2. Installer les 95 dans leur transaction existante ; vérifier rollback tardif,
   refus de rejeu, identité des fiches fictives et contrats/ACL.
3. Exécuter les scénarios combinés et les 27 cas GoTrue/PostgREST distincts.
   Les règles des cinq rounds, police/douanes/armée/privé et radio conservent aussi
   les bancs SQL détaillés ; ne pas prétendre que les 27 cas actuels couvrent à
   eux seuls chaque variante de ces domaines.
4. Réexaminer les formes RPC résiduelles classées dans l'audit des portes, dont
   le travail horaire immobilier à coordonner avec Claude, sans rouvrir une
   ancienne autorité. Contrôler les quatre équipements collectifs hors des 95.
5. Résoudre les observations canoniques/mesures de référentiels selon le workflow,
   vérifier les CI sur le SHA final et l'absence de nouveaux changements de main.
   Ne pas produire un faux 12/12 par génération anticipée d'un baseline de
   production qui contiendrait les fonctions non encore livrées.
6. Intégration et prévol production par ChatGPT seulement après ces preuves.
   Pas de fusion, migration de production ou déploiement autorisés par ce rapport.

État PR #219 : branche mise à jour, non certifiée et non fusionnée. API refusée :
les derniers commentaires, statut brouillon et CI du nouveau SHA n'ont pas été
observés. Aucune prétention de validation réelle du jeu en production.
