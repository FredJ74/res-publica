# Bancs — éprouver une fonction réelle, hors ligne

Un banc charge le **vrai fichier du dépôt**, en extrait la fonction à tester, et
l'exécute dans JavaScriptCore avec des dépendances simulées. Il ne teste jamais
une copie : le texte évalué est celui qui part en production.

```bash
JSC=/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc
$JSC outils/bancs/banc-transport-rest.js
```

| Banc | Ce qu'il établit |
|---|---|
| `banc-transport-rest.js` | Les cinq états de `sbTransportRest` (supabase.js) sont nommés et distincts ; un **vide réel** (2xx avec `[]`) n'est plus confondu avec une **panne** ; le contrat historique des quatre primitives `sbGet`/`sbInsert`/`sbUpdate`/`sbDelete` est intact, rejet réseau compris ; `sbUpsert` ne fait plus de lecture de contrôle. 24 cas. |

## Les deux pièges de JavaScriptCore

1. **Il n'a pas de `console`.** Une fonction qui journalise une erreur lèvera au
   lieu de rendre son résultat, et le banc testera le banc. Poser un
   `var console = { error(){}, warn(){}, log(){} };`.
2. **Les promesses ne se résolvent pas toutes seules.** Un banc synchrone doit
   appeler `drainMicrotasks()` en boucle, jamais une boucle d'attente vide.

## Ce qu'un banc doit refuser de faire

Passer alors que le correctif est absent. Un banc qui reste vert sans la
correction qu'il prétend vérifier ne prouve rien — c'est la leçon du banc de
mise en page de Chrome.

Vérifié pour `banc-transport-rest.js` le 7 octobre 2026 : exécuté contre le
`supabase.js` du commit précédent, il **ne se charge même pas**
(`Error: introuvable : sbTransportRest`). La manière de refaire ce contrôle :

```bash
git show HEAD~1:supabase.js > /tmp/avant.js
sed 's#.*/supabase.js#/tmp/avant.js#' outils/bancs/banc-transport-rest.js > /tmp/banc-avant.js
$JSC /tmp/banc-avant.js    # doit échouer
```
