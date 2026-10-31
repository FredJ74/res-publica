# #219 — épreuve intégrée des 95 et compatibilité #300

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
