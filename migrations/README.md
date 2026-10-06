# Migrations — les évolutions futures du schéma

Une évolution = **un fichier**, nommé :

```
<AAAAMMJJHHMMSS>_<nom_en_minuscules_avec_soulignes>.sql
```

L'horodatage est celui du moment où la migration est écrite, en UTC. Il donne
l'ordre d'application, et il doit être **postérieur au point de coupe du
baseline** — `baseline/CONTROLE-GLOBAL.json`, clé `releve_le`.

## Les trois migrations en attente d'application — chantier 3, autorité

Elles sont **écrites, éprouvées autant que l'environnement le permet, et non
appliquées**. Rien dans le dépôt ne prétend le contraire : le baseline n'a pas
été réextrait, et `verifier-autorite.py` déclare lui-même les sept invariants
qu'elles ferment comme encore en écart (`en_attente_d_application` dans
`../outils/baseline/autorite.json`).

| Fichier | Ce qu'elle fait |
|---|---|
| `20261005214500_autorite_defauts_fermes.sql` | ferme le robinet : `ALTER DEFAULT PRIVILEGES` n'accordera plus l'écriture sur toute table neuve ; retire les 547 privilèges de maintenance et les 24 fonctions de déclencheur ouvertes aux rôles clients |
| `20261005214600_autorite_socle_acteur_identifie.sql` | crée `acteur_identifie()`, met les 25 dernières tables sous RLS, remplace les 28 policies totalement permissives, révoque les 101 droits d'écriture que le navigateur n'exerce pas |
| `20261006013000_autorite_rpc_sans_anon.sql` | retire `EXECUTE` à `anon` sur les 34 fonctions mutantes, et sur les suivantes par défaut |

Aucune ne touche une donnée : ni `INSERT`, ni `UPDATE`, ni `DELETE`, ni
`TRUNCATE`, ni `DROP TABLE`. Uniquement des privilèges, de la RLS, des policies
et une fonction.

**Ordre d'application impératif**, puis réextraction du baseline et commit des
deux ensemble (temps 5 de `../WORKFLOW-SUPABASE.md`).

### Où en est le banc (temps 3)

| Fichier | Banc transactionnel |
|---|---|
| `…_autorite_defauts_fermes.sql` | **passé** le 5 octobre, mesuré puis annulé ; base vérifiée inchangée après |
| `…_autorite_socle_acteur_identifie.sql` | **à rejouer** — sa version corrigée n'a jamais atteint la base. Détail et historique dans l'en-tête du fichier |
| `…_autorite_rpc_sans_anon.sql` | **à jouer** — grammaire validée, banc non tenté |

Les trois passent l'analyseur réel de PostgreSQL 17.7 (`pglast`), et l'invariant
12 de `verifier-autorite.py` vérifie hors ligne que chaque table, signature et
policy qu'elles nomment existe bien. Ce que seul le banc peut établir, c'est le
comportement des boucles sur l'état réel : il reste donc un préalable, pas une
formalité.

## Les trois règles

1. **Idempotente.** `CREATE ... IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`,
   `DROP POLICY IF EXISTS` avant `CREATE POLICY`. Rejouée, elle ne casse rien.
2. **Éprouvée avant d'être appliquée**, par DDL transactionnel ou dans un schéma
   jetable. Voir `../WORKFLOW-SUPABASE.md`, temps 3.
3. **Commitée avec le baseline réextrait**, dans le même commit. Séparés, ils
   laisseraient un instant où le dépôt dit autre chose que la base.

## Ce qui n'a pas sa place ici

Ni brouillon, ni banc d'essai, ni proposition non appliquée : ce répertoire ne
contient que des migrations destinées à être appliquées. Les anciennes
migrations dispersées sont archivées dans `../historique/sql-racine/`, et elles
ne sont pas rejouables.

`../outils/baseline/verifier-workflow.py` vérifie la convention de nommage,
l'absence de doublon d'horodatage, et que chaque migration est bien postérieure
au point de coupe.
