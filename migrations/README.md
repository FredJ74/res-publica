# Migrations — les évolutions futures du schéma

Une évolution = **un fichier**, nommé :

```
<AAAAMMJJHHMMSS>_<nom_en_minuscules_avec_soulignes>.sql
```

L'horodatage est celui du moment où la migration est écrite, en UTC. Il donne
l'ordre d'application, et il doit être **postérieur au point de coupe du
baseline** — `baseline/CONTROLE-GLOBAL.json`, clé `releve_le`.

## Aucune migration en attente

**Le défaut des privilèges de fonction est fermé.**
`defaut_des_privileges_de_fonction_ferme` est passée le 9 octobre 2026, registre
**20261008221846**, qui porte le registre de 560 à **561** entrées. Une fonction
créée dans `public` n'accorde plus `EXECUTE` qu'à `postgres` et `service_role` :
celle qui doit être appelable par un client reçoit désormais son `GRANT`
**explicite** dans sa propre migration.

> **Deux mécanismes, et il fallait les deux.** `authenticated` venait de
> l'entrée `pg_default_acl` posée par `postgres` **pour le schéma** `public`.
> Mais `PUBLIC` venait du **défaut natif de PostgreSQL** — et une entrée par
> schéma **s'ajoute** à ce défaut au lieu de le remplacer, si bien qu'un
> `REVOKE … IN SCHEMA public … FROM PUBLIC` est purement **inopérant** : il ne
> modifie même pas la ligne stockée. Seule une entrée **sans `IN SCHEMA`**, au
> niveau du rôle, retire le `PUBLIC` natif. Et comme `PUBLIC` englobe `anon` et
> `authenticated`, la correction par schéma seule n'aurait rien fermé du tout.
>
> **Troisième piège : fermer trop rouvre.** Révoquer aussi `service_role` ne
> laisse que le propriétaire, PostgreSQL **supprime** la ligne, et l'ACL d'une
> fonction neuve repasse à `proacl = NULL` — donc au défaut natif, `PUBLIC`
> compris.
>
> **Un default privilege ne se lit pas, il s'observe.** La preuve crée une
> fonction témoin, lit son ACL réelle, puis la détruit — dans la transaction de
> la migration.

**Le chantier 4G est appliqué.** `pays_declare_et_retrait_des_defauts_republic`
est passée le 8 octobre 2026 au soir, registre **20261008214206**, qui porte le
registre de 559 à **560** entrées. Elle vit maintenant dans
`../historique/migrations-appliquees/`, et son en-tête y dit ce qui a été prouvé.

> **Ce que son banc a attrapé, et qui valait le détour.** Sa première version
> retirait les onze défauts par `CREATE OR REPLACE FUNCTION`. PostgreSQL le
> refuse : *cannot remove parameter defaults from existing function*. `CREATE OR
> REPLACE` peut **ajouter** un défaut et le **changer** ; il ne peut pas le
> **retirer**. La migration reposait sur une hypothèse jamais éprouvée contre une
> vraie base — et c'est précisément ce qu'un banc sert à attraper.
>
> Le détour par `DROP FUNCTION` a révélé deux pertes silencieuses qu'il fallait
> payer explicitement : le schéma `public` porte un **privilège par défaut** qui
> ouvre à `authenticated` toute fonction neuve (sept fonctions de cron
> concernées), et un `DROP` **perd le commentaire** de la fonction (trois des
> onze en portaient un). Aucun `REVOKE ... FROM PUBLIC` n'aurait suffi : ce sont
> les rôles **nommés** qui s'ajoutent.
>
> **Leçon de méthode, à ne pas réapprendre :** `pglast` valide la grammaire SQL
> de l'**enveloppe**, pas l'intérieur d'un bloc `DO $$ ... $$`. Une grammaire
> validée localement ne dit donc rien du PL/pgSQL qu'elle contient — seul un banc
> en transaction annulée le dit.

Les dix migrations des chantiers 4E, 4F, 4G et des budgets municipaux ont toutes
été appliquées et vivent dans `../historique/migrations-appliquees/`, chacune
avec, en tête, **la version du registre Supabase** et **ce qui a été vérifié
après coup**.

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
