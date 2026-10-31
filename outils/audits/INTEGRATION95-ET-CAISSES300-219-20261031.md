# #219 — épreuve intégrée des 95 et compatibilité #300

**État final de cette reprise :** main #300 (`586ae9ea`) intégré ; 95 versions installées atomiquement sur le décor privé explicitement daté, 70 scénarios de catalogue combinés réussis et **27/27 vrais scénarios GoTrue/PostgREST locaux**. **46/46 commandes Python, 155/155 bancs clients, 105/105 pilote, 49/49 outillage, 21/21 relais**. Globaux **10/12**, garde immobilière #299 **13/14**, sans neutralisation. Ni catalogue vivant actualisé certifié, ni fusion de #219, ni production modifiée. Les sections suivantes conservent la progression et ses rectifications ; cet encadré et les dernières preuves font foi.


## Rectification du payeur

Le précédent blocage annoncé est retiré. La preuve ChatGPT [6548347589](https://github.com/FredJ74/res-publica/pull/219#issuecomment-6548347589) distingue `md5(prosrc)` = `5cf45c19e4b9559f6b29e2b9207d3969` et `md5(pg_get_functiondef)` = `37eca91d6eb08c2a6ea97cbe717a216a`. Le premier est bien celui de la garde existante. Le test intégré reproduit les DEUX valeurs sur la vraie fonction reconstruite, sans la remplacer. Pas d'élargissement d'empreinte ni de retrait de garde. Le diagnostic initial JSON est conservé comme rétracté, pas effacé.

## Installation réellement exécutée en local

`banc-livraison95-catalogue-local.py` réutilise `epreuve-postgresql.py`, l'assembleur, les quatre exports privés et le générateur existant du paquet. PostgreSQL **17.6**, 10 921 ordres de reconstruction, **1 199 corps recompilés**. Aucune URL de base distante acceptée, aucune donnée de joueur copiée.

**Provenance limitée et explicite :** registre privé 1003 et schéma comparé aux quatre exports de cette coupe ; tarifs 438 de la capture indépendante `346064:346064:`. Ce décor ne vaut PAS un catalogue 1009 reconstitué. Le registre actuel 1009 n'a été fourni que sous forme de compte/dernière version et de quelques métadonnées, pas de ses six entrées supplémentaires et définitions complètes. Aucun faux registre 1009 inventé.

Les **95 migrations sont installées ensemble en une seule transaction**. Le registre local passe de 1003 à 1098. Une panne volontaire après les 95 annule les quatre catalogues, le registre et préserve la fiche fictive préexistante. Au second passage, le paquet refuse dès son prévol et laisse le catalogue inchangé : ce refus est le comportement réel, pas une installation rejouée prétendument réussie.

Après succès, tous les champs préexistants de la fiche témoin restent identiques, notamment argent et inventaire. Le JSON complet de la ligne change seulement parce que la migration 115842 ajoute `current_street_from = NULL` ; ce seul ajout nullable est contrôlé explicitement. Une régression unitaire refuse argent changé, inventaire vidé, ancien champ absent, nouvelle colonne inattendue ou provenance non nulle.

**30/30 scénarios sur catalogue entier**, puis **3/3 commandes d'organisations** réelles, sous rôle authenticated et request.path explicite : administration, invitation et rejeu, adhésion/caisse conservée. JWT SQL fictifs, aucun service GoTrue.

## Compatibilité #300 éprouvée

Les deux sources de #300 sont extraites de sa branche à un SHA explicite et contrôlées par SHA256 dans le décor. Elles ne sont ni copiées dans les migrations #219 ni appliquées en production. Après les 95, les deux migrations #300 s'installent dans ce décor : **30/30 groupes et 3/3 organisations** passent encore sous ses gardes. Le payeur et les moteurs universels ne sont pas remplacés par des doublures.

Simulation `git merge-tree` sans toucher à la branche de Claude : scripts `supabase.js`, `plateau-organisations-quetes.js` et `plateau-politique.js` fusionnés sans conflit textuel. Les quatre bancs clients caisses/activation/commandes/événements passent sur ces fichiers fusionnés dans un répertoire temporaire. Dépendances Acorn explicites conservées ; un premier essai manquait ces dépendances dans le dossier temporaire, puis la configuration a été complétée.

**Conflit restant pour l'intégrateur : `.github/workflows/coherence-client.yml` uniquement.** Conserver les étapes existantes #219 et ajouter les deux étapes #300, sans doublonner le pipeline ni supprimer un test : `banc-caisses-collectives-client.cjs` et `banc-caisses-collectives-local.py --local-jetable`. Aucun faux feu vert de fusion sans cette résolution.

Ordre de livraison #300 inchangé : fonctions de la première migration, interface compatible Vercel READY, fermeture par la seconde. Les contrats #219 n'ont plus de repli général et passent après la fermeture locale ; cela ne prouve pas que le client #300 est déjà en production.

## Écarts et opérations restantes

Le contrôle strict des RPC sur le catalogue installé conserve **9 formes** à examiner (rapport JSON), différentes des 15 absences/signatures de l'ancien baseline : certaines formes sont des appels spread ou des helpers volontairement non appelables, d'autres sont historiques. Ne pas les supprimer globalement du détecteur. Les 3 contrats organisations et les 12 contrats #219 signalés par Authority avant installation sont présents après lot. Le contrôleur global du dépôt demeure à 10/12 contre le baseline de production : ne pas le réécrire à partir du décor ni annoncer 12/12. Referential hors coûts nécessite les contenus vivants demandés.

Pour certifier 1009 : obtenir les JSON de la demande ciblée existante (registre complet, définitions/ACL/RLS/triggers/dépendances actuels et référentiels statiques). Elle inclut désormais les fonctions Helvetia pertinentes et distingue les empreintes de corps. Ne pas réappliquer aveuglément les deux correctifs Claude déjà enregistrés sous leurs versions réelles. Réutiliser ensuite le banc intégré, avec catalogue reconstruit à cette provenance.

Issue #299 relue : les deux préparations immobilières 113610/113631 hors des 95 restent confiées à Claude, sans correction encore publiée dans l'issue lors de la lecture. Ni exclusion de garde ni modification concurrente de ces fichiers.

Recette GoTrue réelle encore absente. Les scénarios SQL isolés utilisent les rôles et les JWT locaux, pas un login. Aucun mot de passe récupéré, aucun compte réel modifié. Une recette authentifiée demande une plateforme isolée autorisée et ses comptes de test ; Arnie reste en consultation seule et n'a pas été utilisé pour payer/combattre.

**Pas de fusion ni déploiement.** Installation intégrée et compatibilité #300 prouvées dans le décor déclaré ; catalogue 1009 fidèle, 12/12 globaux et recette GoTrue restent non certifiés.

## Complément : vraie authentification isolée exécutée, 26/26

Le manque de plateforme locale a été traité : Docker disponible, images GoTrue v2.177.0 et PostgREST v12.2.12 téléchargées, binaires statiques extraits de conteneurs **arrêtés sans réseau**, conteneurs supprimés. Les services natifs ne servent que sur 127.0.0.1 et se connectent par socket Unix au PostgreSQL jetable. Secrets de test générés en mémoire, aucun secret ou identifiant réel lu. Provenance des images et SHA256 binaires enregistrés.

GoTrue utilise son vrai schéma auth et son rôle local dédié (search_path auth,public). Les helpers de plateforme auth.jwt/uid/role sont initialisés par le bootstrap SQL standard déjà utilisé par l'outil ; aucun moteur métier public n'est substitué. Les premières tentatives ont trouvé les préconditions de schéma/search_path de GoTrue, corrigées uniquement dans le bootstrap local.

**Trois inscriptions et logins GoTrue locaux réels**, nouveaux UID fictifs, puis JWT signés vérifiés par PostgREST et changement de rôle authenticated : **26 scénarios HTTP réussis** après installation des 95 et de #300. Identité exacte, anonyme refusé, adhésion et départ, reconnexion même UID/groupe conservé, PNJ réservé à l'employeur, radio absente puis hors ville refusée et rappel/rejeu même ville, combat mixte réel, deux clics HTTP concurrents même bataille et reçu unique, ouverture/round rejoués sans double effet, tiers non engagé refusé, fonds insuffisants nommés sans PA ni mutation, coma et prison refusant la sortie avec le bon motif. L'écrou est créé par le vrai moteur interne SQL local, pas par une simulation de détenu.

Limites conservées : **pas une recette Chromium de l'interface du jeu ni de production** ; réponse d'ouverture ignorée puis rejouée, pas une panne réseau physiquement injectée ; interpellation policière complète couverte par les scénarios SQL, pas par une interface policière HTTP ici. Les scénarios avancés de soldats restent dans le banc SQL 379. Tous les services/processus sont arrêtés et les bases supprimées en finally ; journaux de services privés jamais committés.

Déclenchement technique reproductible : le même banc intégré accepte `--gotrue-bin` et `--postgrest-bin` ensemble, avec ses exports/registre/tarifs privés habituels. Aucun DSN distant accepté. Deux contre-épreuves unitaires refusent une base distante et une origine HTTP extérieure avant tout appel.

Nouvelle passe : **48/48 outillage, 45/45 commandes Python, 154/154 bancs clients, 105/105 pilote Chromium**, six mutations réexécutées et détectées sur 379 cas chacune. Les contrôles globaux restent à **10/12**, et la garde immobilière #299 n'a pas été neutralisée. Le diagnostic strict des neuf formes montre huit chemins sans droit client (dont des helpers délibérément morts) et un spread incomplet (`tournee_creer`), **zéro nom de fonction absent** dans cet inventaire post-95 ; signatures et droits publiés sans supprimer d'écart. Le travail immobilier reste à Claude.

Le blocage réel restant est la fidélité au **catalogue 1009/delta complet et ses référentiels statiques**, non celle du payeur et non l'impossibilité d'un login isolé. Sans ces données, ne pas transformer les 66 scénarios SQL combinés et les 26 HTTP en certification de la production.

## Intégration effective de main #300 et corrections supplémentaires

Main `586ae9ea` (#300) est intégré dans `ba4d0843`, puis caches des trois scripts communs montés dans `9b8140f7`. Le conflit du workflow a été résolu en conservant les étapes des deux branches et **une seule** installation des dépendances. Le relais reprend les statuts réels annoncés par Claude : première migration des caisses déjà appliquée, seconde conditionnée à Vercel READY. Le prochain prévol doit donc viser l'état après #300, et non supposer que le compte vivant reste 1009. Codex n'a appliqué aucune migration distante.

La recette d'organisation a été étendue à l'élection réelle et son PA. Elle a trouvé une incompatibilité locale que les trois premiers cas ne détectaient pas : après le transport, la migration 115831 injecte la garde de recrutement dans le wrapper du payeur. Le corps final est `d5c9f4e8bdbdc2858c8b908fd6c460c5`, pas le wrapper intermédiaire `ca7abc6a…`. **La garde initiale 115805 et le payeur ne sont pas modifiés.** Seule la commande d'événement reconnaît aussi ce wrapper final connu, avec les mêmes deux corps internes attestés et leurs ACL fermées. Un test dérive cette empreinte depuis les deux sources publiques, sans la prendre dans une capture opaque ; le catalogue exécuté confirme la même valeur. Une mutation tierce de ce wrapper est refusée.

Après correction : **30 scénarios de groupes + 5 d'organisations**, avant et après #300, soit 70 succès de scénario au total ; l'élection paie exactement un PA et son rejeu n'en prend pas un second. Puis **26/26 scénarios HTTP GoTrue/PostgREST** réussis. Tous les anciens champs du canari restent identiques et le rollback tardif annule intégralement les 95.

L'autre échec de la première passe combinée n'était pas le banc des caisses (46/46), mais le relais privé (18/19 à ce moment) : des `.git` **vides et en lecture seule** sont apparus aux racines /tmp et /workspace de l'environnement. Ils ne constituent pas des dépôts. La détection refuse toujours fichiers de worktree, liens même cassés, répertoires Git contenant des métadonnées et marqueurs illisibles. Seul un répertoire vide sans métadonnées n'est plus confondu avec un dépôt. **21/21 tests relais** : publication dans le vrai dépôt et dans un worktree toujours refusée avant création de fichier. Aucun export brut publié.

L'outillage passe à **49/49**, les bancs clients à **155/155** après #300. Les 46 commandes Python du workflow combiné sont relancées après réparation ; leur résultat final est à lire dans la preuve dédiée, pas déduit du succès isolé des cas. Les globaux restent 10/12 contre le baseline de production disponible et la garde #299 reste active. Aucune prétention de 12/12 ni de catalogue vivant complet.

### Dernière preuve

La signature JWT falsifiée est rejetée avec HTTP 401 ; le refus anonyme doit être 401/403 ou un refus métier explicite, jamais une simple erreur 500 considérée comme succès. La recette authentifiée finale comporte **27 cas** et utilise le code commité. Les services ont été arrêtés ; aucun processus GoTrue/PostgREST de ce banc ne subsiste.

La passe complète du workflow combiné passe désormais **46/46** (dont le relais réparé), résultats bruts conservés sans modifier un ancien échec. Le manifeste donne le SHA256 actualisé des 95 sources, l'empreinte du paquet et la référence à la preuve finale. #299 reste isolée par une assertion d'absence des deux préparations dans ces 95, tout en gardant le test global qui les signale.

**Action technique restante pour l'intégrateur :** fournir hors Git les résultats complets de `DEMANDE-PREVOL-ACTUALISE-219-20261031.md`, contre l'état vivant **après les opérations #300** (registre complet et définitions/contraintes/ACL/RLS/triggers, plus référentiels statiques). L'accès connecteur et les variables Supabase ne sont pas disponibles dans ce processus ; les seuls quatre exports locaux sont toujours ceux de la coupe 1003. Sans ces résultats, aucune certification de fidélité 1009 ou plus récente, aucun 12/12 fabriqué. La suite sera une comparaison du delta, reconstruction fidèle par les outils existants, nouvelle passe atomique et autorisation de livraison ; pas un nouveau diagnostic du payeur.
