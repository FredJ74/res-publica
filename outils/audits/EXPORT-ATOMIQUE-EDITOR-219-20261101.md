# #219 — dispositif SQL Editor livré, certification encore conditionnée au CSV privé

## Livraison exécutable

SQL exact : `outils/bancs/COLLECTE-ATOMIQUE-219.sql`. Généré par `outils/livraison/export-sql-editor-219.py --generer-sql`, jamais retouché à la main. Les sept requêtes du manifeste existant sont conservées, chacune dans un CTE MATERIALIZED du même SELECT. Un seul statement = un seul instantané PostgreSQL, alternative explicitement autorisée par la mission à une transaction multi-statements. Il termine par le tableau des fragments pour permettre l'export CSV du SQL Editor, sans ROLLBACK final masquant le résultat ni transaction laissée ouverte. Aucune commande d'écriture, de schéma ou d'authentification ; les contenus extraits sont les listes blanches des outils existants.

L'enveloppe REPEATABLE READ READ ONLY est conservée dans la **session du banc natif** : le vrai SELECT réussit sous cette protection. Une première tentative de retirer l'enveloppe du fichier avait été refusée par la revue automatique ; les tests natifs, la vérification AST et l'autorisation explicite du SELECT atomique ont ensuite été fournis et la variante a été autorisée. Aucune protection n'est contournée.

Résultats : sept fichiers JSON + manifeste privé de transport, chacun découpé en fragments d'au plus8192 octets puis base64 (UTF8 jamais tronqué au milieu d'un décodage). Par fragment : numéro, total, longueur, SHA256 ; par fichier : longueur et SHA256 ; pour tous : SHA du manifeste, snapshot et annuaire exhaustif. Un fichier entier absent, une limite100 lignes, une cellule coupée, un doublon ou une seconde campagne mélangée provoque un refus. Les fichiers sont réassemblés dans l'ordre numérique, leurs octets d'origine restent identiques.

Le script d'assemblage accepte CSV/JSON, vérifie la provenance, les formats, les registres, les contenus dupliqués, les contrôles tarifaires et la locale ; il matérialise les formats d'import existants et l'archive `exports-certification-219.tar.gz` hors Git, sans arrondir les décimaux. Dossiers700/fichiers600. Pas de sortie partielle au moindre échec. Les douze empreintes PostgreSQL et les six racines restent à comparer sur le clone ; le transport n'est jamais présenté comme certification. Une empreinte de manifeste transmise indépendamment peut être exigée ; le rapport distingue ce contrôle de l'intégrité interne.

Mode d'emploi très court : `outils/livraison/COLLECTE-SQL-EDITOR-219.md`. Fred n'a aucun script local ni secret à manipuler : une exécution SQL Editor, téléchargement CSV complet et pièce jointe privée.

## Corrections nécessaires mises en évidence

- Le relais échouait si toutes ses graines étaient vides : l'agrégat SQL produisait un **JSON null**, que COALESCE ne remplaçait pas par une liste. Traitement explicite nullif(...,'null'::jsonb), essai réel avec toutes les graines vides ; résultat [] validé. SQL canonique régénéré via son générateur, jamais baseline édité à la main.
- Workflow refusait même un SELECT pur sans enveloppe rollback. Il reconnaît désormais un SELECT d'introspection par AST et liste fermée d'appels de lecture (dont les cinq fonctions de mesure existantes), sans exemption par nom de fichier. Il refuse toujours CTE DELETE/UPDATE, SELECT INTO, verrou, set_config, fonctions inconnues ou homonymes publics. Les anciens tests de refus restent conservés. Documentation du processus mise à jour. Aucun ordre métier n'est admis par cette règle.

## Préparation de l'intégration

Résolution Claude `16093f4d` réutilisée. Dernier main récupéré `df612780` (#327) intégré : seul conflit dans RELAIS, résolu en conservant les deux transmissions. Le fichier des459 tarifs, les deux migrations complémentaires et plateau-personnage.js sont identiques à l'intégration Claude. Aucune règle d'hospitalisation changée, aucune image retouchée.

`preparer-recette97-219.py` vérifie les95 sources par leurs empreintes et l'ordre exact, puis #318 `20261101170000`, puis #324 `20261101171000`. Préparation publique sans données reçues : `PLAN-97-EDITOR-219-20261101.json`. Avec le paquet privé, l'outil produira le delta complet contre les459 sources, hors Git. Il n'autorise et n'exécute aucune migration. L'ancien plan438→452 n'est ni appliqué ni remplacé sans les lignes réelles de la coupe actuelle.

Sources459 : MD5 canonique `1e69581b8020f7375f95d7cdf5dd6c39`. La garde SQL des95, l'intégrité des migrations, les comparaisons de racines/référentiels et le refus du rejeu ne sont pas neutralisés. Après réception : générer les artefacts depuis le réel, réconcilier les tarifs, certifier le clone17.6/ICUen-US153.121, panne+rollback95, installation95, rejeu refusé sans mutation, recettes puis deux compléments, et27HTTP sur l'état final. L'installation des compléments n'est pas déclarée testée sur un clone actuel absent.

## Vérifications réelles de cette intervention

| Vérification | Résultat |
|---|---|
| Collecte/CSV/JSON/archive sur PostgreSQL17.6/ICU153.121 | **11/11** |
| Relais/imports, même PostgreSQL17.6 | **22/22** |
| Workflow avec contre-épreuves | **13/13** |
| Ordre97, source459, refus omission/inversion/empreinte altérée | **2/2** |
| Manifeste existant | **2/2** |
| Services natifs GoTrue/PostgREST, UID/JWT/ACL/reconnexion fictifs | **10/10** |
| Contrôleur client final, main327 et Claude intégrés | **161/161 bancs** |
| Outillage principal sur17.6 | **74/75**, refus du plan périmé |
| Globaux | **9/12**, Baseline/Authority/Referential rouges |

Les161 bancs ne sont pas une recette authentifiée de production ; leurs éventuels cas internes déclarés en attente ne sont pas promus en preuves réelles. Le test de services est indépendant des27 scénarios métier.

En plus, **61 autres étapes exécutables du workflow** ont été lancées localement, installations/setup/upload GitHub exclus, contrôleur client compté séparément. Première passe58/61 : deux refus du plan tarifaire périmé, plus Workflow avant sa correction. Workflow corrigé puis rejoué13/13 et le contrôleur complet rerun161/161. Tous les autres succès conservés, y compris commerce, finances, réception, combats civils mixtes, douanes, organisations et parcours immobilier isolés ; pas de réécriture de leurs résultats. Aucun résultat local n'est présenté comme GitHub Actions distant. Les journaux ne sont pas publiés s'ils peuvent contenir des valeurs ; le JSON joint ne contient que métadonnées et états des tests fictifs.

## État restant

Aucun export réel de la coupe actuelle reçu. Aucun compte Supabase, objet joueur, solde, schéma de production ou secret modifié/lu. Aucune nouvelle tentative PostgreSQL direct, MCP externe ou modification proxy. Aucune fusion #219/main ni déploiement.

Seul prérequis extérieur désormais : recevoir le CSV complet du SQL livré via le canal privé. Les six racines/douze tables,95/rollback/rejeu et27HTTP sur la coupe actuelle ne sont **pas certifiés**. Les nombres1021/1022 précédemment transmis ne sont jamais assignés à la nouvelle observation : le SELECT relève le registre réellement présent.
