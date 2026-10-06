# Migrations — les évolutions futures du schéma

Une évolution = **un fichier**, nommé :

```
<AAAAMMJJHHMMSS>_<nom_en_minuscules_avec_soulignes>.sql
```

L'horodatage est celui du moment où la migration est écrite, en UTC. Il donne
l'ordre d'application, et il doit être **postérieur au point de coupe du
baseline** — `baseline/CONTROLE-GLOBAL.json`, clé `releve_le`.

## La migration en attente d'application — chantier 4E, villes et caisses

`20261007003000_villes_referentiel_et_caisses_fail_closed.sql` est **écrite,
éprouvée autant que l'environnement le permet, et non appliquée**. Rien dans le
dépôt ne prétend le contraire : le baseline n'a pas été réextrait, et le miroir
`villes` est déclaré en attente dans `../outils/baseline/referentiels.json`
(`posee` et `reelle` à `null`, `fonction_reelle_en_base` à `false`).

Les trois migrations du chantier 3, qui occupaient cette section, **ont été
appliquées** ; elles vivent dans `../historique/migrations-appliquees/`.

### Ce qu'elle fait

| Partie | Effet |
|---|---|
| référentiel | crée `villes` (12 lignes, semées par `generer_villes.py`) et `villes_empreinte` + `villes_empreinte_reelle()`, cinquième miroir surveillé |
| résolveurs | `ville_est_reelle()`, `caisse_territoire()` (portée `national` / `ville` / `indetermine`), et `caisse_ville_de()` réécrite pour déléguer |
| autorité | ferme le *fail-open* des trois primitives de caisse : absence de règle d'autorité = **refus**, et le contrôle de ville est ajouté aux deux qui n'en avaient pas |
| vestiges | supprime 5 lignes de `caisses_batiments` à solde 0 et sans aucun mouvement, dont `republic_mairie_caserne` |

C'est la **seule** partie du chantier 4E qui touche la base. Tout le reste —
référentiel `VILLES` et résolveur unique côté navigateur, suppression de cinq
tables de noms concurrentes, générateur, contrôles — est livré et ne dépend pas
d'elle.

### Où en est l'épreuve (temps 3)

| Épreuve | État |
|---|---|
| grammaire PostgreSQL 17.7 (`pglast`) | **passée** — 44 instructions analysées |
| invariant 12 de `verifier-autorite.py` | **passé** — chaque table, signature et policy nommée existe, ou est créée par la migration elle-même |
| table de décision de `caisse_territoire()` | **passée en lecture seule sur les 151 caisses réelles** : 48 nationales, 36 de ville (contre 34 avant, les 4 `mairie-capitale` étant récupérées), 61 sans règle, 6 indéterminées |
| effet du resserrement sur les postes réellement pourvus | **mesuré** : les deux seuls postes tenus dans la bêta (`min_def`, `lieutenant`) sont nationaux, donc **zéro** chemin légitime fermé ; ce qui se ferme, ce sont 25 caisses sans règle par acteur |
| banc transactionnel sur la base | **non tenté** — il aurait coûté une seconde confirmation humaine, et les mesures en lecture ci-dessus établissent la même chose |

Ce que seule l'application peut établir, c'est que le DDL passe sur l'état réel.
Le reste est mesuré.

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
