# PR #219 — reprise par Claude (Codex en panne d'environnement), 01/11/2026

Point de départ imposé : `bf06a276b13215662e3964d5b18105875272d224` (tête de #219).
**CHANTIER NON CLOS : blocages extérieurs.** Aucune fusion, aucun déploiement, aucune écriture en production.
Les 380 tests PostgreSQL, 61 étapes et 75 tests d'outillage de Codex n'ont pas été rejoués (aucun code
qu'ils couvrent n'a changé).

## 1. Ce qui est fait

- **Lecture** : `AGENTS.md`, `RELAIS.md`, `REPRISE-1015-219-20261101.md` (dernier rapport Codex).
- **Conflits avec `main` résolus** (branche `claude/integration-219-main-20261101`, commit `94c2d89`,
  `main` = `b69be61b`, base commune `ddb72dbd`). Deux conflits seulement :
  - `outils/generateurs/generer_ordres_couts.py` : moteur commun de #219 conservé ; le repli Node écrit
    en dur par `main` casse quand `JSC` est une liste (repli de `moteur_javascript`). Générateur vérifié.
  - `RELAIS.md` : version la plus récente de `main` + renumérotation #219 des squatteurs.
- **Préparation de #318 (et #324, hospitalisation)** sur cet état, **épreuve non certifiante PostgreSQL 16** :
  pile locale `#219 + main + #318 + #324` (deux conflits d'ajout pur dans `data.js` et
  `GAME-DESIGN-HOSPITALISATION.md`, union des deux côtés, règles d'hospitalisation intactes).
  Base jetable baseline + migrations (dont les 10 nouvelles de `main`) : **#318 14/14**, **hospitalisation 25/25**.

## 2. Défaut réel constaté (non corrigeable sans prévol frais)

La fusion avec `main` fait passer les sources de tarifs de **452 à 457 triples** :
ajouts `service_etage 0/50`, `travailler_jardins 1/0`, `laisser_legumes_jardins 0/0`,
`prendre_legumes_jardins 0/0`, `organiser_manifestation_spontanee 1/0`, `acheter_terrain 2/25200` ;
retrait `acheter_terrain 2/3500`. Tous viennent de décisions de Fred du 01/11 (audit PSM/Montrouge,
jardins ouvriers, manifestation spontanée). Conséquences :
- `preparer-livraison-complete-219.py` refuse : « Sources de tarifs changées : réexaminer le plan » ;
- les étapes CI `test-catalogue-reconstruction.py` et `banc-couts-reconciliation-219-local.py` échoueront ;
- la migration de tarifs du lot 95 compare la production à la capture 438 (avant 1015) : la production a
  changé depuis (migrations de `main` appliquées), elle refuserait en production.
Réexaminer le plan exige un **relevé frais de `ordres_couts` en production** (lignes, md5, sentinelle),
déjà demandé par Codex dans le paquet privé 1015. Pour cette raison, la fusion n'est **pas poussée sur
la branche de #219** (elle y mettrait la CI au rouge pour une cause connue).

## 3. Blocages extérieurs (étapes 2 à 5)

| Exigence du banc `banc-livraison95-catalogue-local.py` | État ici |
|---|---|
| JSON privé `referentiels-prives-hg219-1015.json` + SHA-256 transmis à part | **non reçus** (aucune pièce jointe) |
| PostgreSQL **17.6** (`server_version_num = 170006`), ICU 153.121 | seul PostgreSQL 16.15 ; PyPI non résolu (DNS), téléchargements GitHub refusés (403) : `pgserver` impossible |
| GoTrue et PostgREST (27 cas HTTP) | binaires introuvables, téléchargement refusé |
| `pglast` (composition du lot) | absent, non installable (PyPI) |
| Métadonnées de la coupe : registre, six empreintes, douze référentiels, locale, `ordres_couts` | non fournies |

Non exécutés en conséquence : vérification du SHA-256, clone 17.6 certifié, 95 atomiques + rollback +
rejeu sur clone certifié, 27 HTTP. **Rien de cela n'est présenté comme fait.**

Remarque : la coupe 1015 (dernière version `20261101113411`) est elle-même dépassée, puisque des migrations ont
été appliquées en production après 11 h 34 le 01/11 (jardins ouvriers, églises, salaire religieux…).
L'intégrateur devra relever la coupe **actuelle**, pas 1015.

## 4. Pour reprendre (environnement de Codex ou intégrateur)

1. Paquet privé de la coupe actuelle : JSON des référentiels + son SHA-256 transmis à part, registre,
   six empreintes (`outils/bancs/empreinte-catalogue-racine.sql`), douze référentiels, locale,
   `ordres_couts` (lignes, md5, sentinelle). Destination `/tmp/hg219-prives/` (700/600), jamais dans Git.
2. Réexaminer le plan de tarifs avec ce relevé (les 7 écarts ci-dessus sont tous tracés à des décisions
   de Fred), mettre à jour `LIVRAISON-COUTS-219-20261031.json` et les attentes des deux bancs CI.
3. Pousser `claude/integration-219-main-20261101` sur la branche de #219, obtenir la CI.
4. Banc de livraison complet sur PostgreSQL 17.6 + GoTrue/PostgREST, puis certification.
5. Ensuite seulement : #318, puis #324, placés après les 95 (leurs SQL sont hors de `migrations/`).
