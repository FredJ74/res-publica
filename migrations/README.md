# Migrations — les évolutions futures du schéma

Une évolution = **un fichier**, nommé :

```
<AAAAMMJJHHMMSS>_<nom_en_minuscules_avec_soulignes>.sql
```

L'horodatage est celui du moment où la migration est écrite, en UTC. Il donne
l'ordre d'application, et il doit être **postérieur au point de coupe du
baseline** — `baseline/CONTROLE-GLOBAL.json`, clé `releve_le`.

## Aucune migration en attente

Ce répertoire ne contient que ce fichier et `PLAN-APPLICATION.md`. Les sept
migrations des chantiers 4E et 4F ont toutes été appliquées et vivent dans
`../historique/migrations-appliquees/`, chacune avec, en tête, **la version du
registre Supabase** et **ce qui a été vérifié après coup**.

> **Les noms de fichiers gardent leur horodatage de rédaction.** Cinq d'entre
> eux commencent par `20261008`, alors que l'horloge du projet et le registre
> disent le 7 octobre 2026. Ce sont les noms sous lesquels ces migrations ont été
> **réellement appliquées** : les renommer réécrirait l'historique pour corriger
> une faute de date, et un historique qui se corrige ne prouve plus rien. La
> prose du dépôt, elle, a été alignée sur le 7 octobre — c'est purement
> documentaire. Et les textes déjà **en base** (un `COMMENT`, une `note` de
> référentiel) gardent le 8 octobre, parce que c'est ce que la base contient :
> les fichiers générés de `baseline/` doivent dire la vérité sur elle, pas sur
> nos intentions.

### Ce que la prochaine migration doit respecter

Deux règles, apprises à ce chantier :

1. **Être postérieure au point de coupe du baseline**
   (`../baseline/CONTROLE-GLOBAL.json`, clé `releve_le`). L'invariant 4 du
   garde-fou refuse l'inverse, à raison : l'effet d'une migration antérieure est
   censé être déjà dans le baseline. Si une réextraction a lieu entre l'écriture
   et l'application, **redater le fichier** est la seule réponse juste.
2. **Porter ses propres contrôles dans sa transaction.** Un bloc `DO` qui lève
   plutôt que de laisser croire que la migration a fait ce qu'elle annonce.
   C'est ce qui a sauvé le chantier de la Justice : la première version sommait
   trois tiers par division et obtenait `0,99999999999999999999` ; son assertion
   l'a refusée, et **rien n'a été appliqué**.

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
