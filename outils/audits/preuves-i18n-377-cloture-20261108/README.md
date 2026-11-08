# Certification indépendante du HEAD ddc72445 — 8 novembre 2026

Tout est local. Aucun service payant, joueur réel ou accès de production.
Le rapport de référence est `../CLOTURE-TECHNIQUE-I18N-377-20261108.md`.

## Reproductions et correctif proposé

Depuis la racine du dépôt, avec Acorn dans outils/vercel/node_modules et
Playwright dans outils/e2e/node_modules :

1. `python3 outils/audits/preuves-i18n-377-cloture-20261108/preparer-correctif.py`
   crée le patch et un fichier de sources dans /tmp ; aucun fichier de jeu changé.
2. `node outils/audits/preuves-i18n-377-cloture-20261108/parcours-session.cjs`
   reproduit les deux défauts (son succès signifie « reproduction réussie »).
3. Même commande avec `--correctif` : sources corrigées chargées uniquement en
   mémoire Chromium, cas corrigés et saisies/handlers conservés.
4. Avec `--correctif --contre-catalogue` ou `--correctif --contre-salle` : échec
   d’assertion attendu, preuve que les contrôles détectent les régressions.

Le fichier `correctif-reference.patch` n’est PAS appliqué à la PR. Il a été
éprouvé sur une copie locale détachée de l’intégration avec main. Il reste à
intégrer, compléter aux fragments non annotés, majorer les versions de cache,
puis faire passer la CI du nouveau SHA. Les assertions existantes restent intactes.

## PostgreSQL 17.6

`HG_I18N_PG_BIN=/chemin/vers/bin python3 outils/audits/preuves-i18n-377-cloture-20261108/stockage-pg17.py`

Par défaut le répertoire utilisé ici est /workspace/hg-postgresql-17/bin.
Python requiert psycopg2. Le script ignore toute variable PG héritée, crée son
cluster dans un répertoire temporaire, ne l’écoute que sur son socket privé,
puis le détruit. Il joue le banc SQL de stockage existant, sa concurrence,
les 14 refus clients et le module Node `chaines-rls.mjs` contre les vraies RLS SQL.
L’authentification et le fournisseur restent des fixtures. Les tables/fonctions
nécessaires proviennent du baseline et du socle forums préparé, pas d’un export
actuel de production ; les policies utilisent les prédicats du prévol i18n.
Le script Node refuse un PGHOST hors du répertoire de fixture.

Le banc existant des forums a également été exécuté avec :
`HG219_POSTGRES_BIN=/workspace/hg-postgresql-17/bin python3 outils/bancs/banc-forums-territoires-local.py`
et ses options `--contre`, `--contre-publication` (échecs attendus et vérifiés).

## Autres contrôles

Contrôleur client existant : `python3 outils/bancs/controler-client.py`.
Le banc Chromium existant des neuf langues est servi sur localhost ; ses sorties
réseau sont bloquées. Les inventaires éditoriaux/ordres utilisent les outils
existants. Aucun de ces succès ne constitue un essai sur téléphone physique ni
une validation linguistique. Les résultats détaillés sont dans les JSON voisins. Les essais initiaux de
81b219e4 sont distingués des essais finaux ddc72445 ; le main a évolué et activé
le client pendant la mission, sans action de cet audit.
