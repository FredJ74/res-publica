# Migrations — les évolutions futures du schéma

Une évolution = **un fichier**, nommé :

```
<AAAAMMJJHHMMSS>_<nom_en_minuscules_avec_soulignes>.sql
```

L'horodatage est celui du moment où la migration est écrite, en UTC. Il donne
l'ordre d'application, et il doit être **postérieur au point de coupe du
baseline** — `baseline/CONTROLE-GLOBAL.json`, clé `releve_le`.

## Aucune migration en attente

**Une ardoise d'impayé ne double plus à chaque rejeu du cron.**
`ardoise_impaye_atomique` est passée le 9 octobre 2026, registre
**20261009005012**, qui porte le registre de 563 à **564** entrées. La branche
« locataire déjà averti et toujours insolvable » de `prelever_loyer_bail` était
**la seule sortie à effet** à ne pas poser son marqueur de journée : un second
passage la même nuit rajoutait un jour et un loyer à la dette. Et poser le
marqueur n'aurait pas suffi — l'appelant réécrivait le blob entier depuis une
lecture **antérieure** à la RPC, et l'aurait effacé dans la foulée. Le calcul de
l'ardoise est donc descendu **dans** la RPC, où revendication et effet sont
atomiques.

> **Deux refus avant l'application, et les deux étaient des preuves qui font
> leur travail.** La preuve 1 interdisait une séquence que le code *neuf*
> contient aussi ; la preuve 3 annonçait quatre poses du marqueur alors qu'il y
> en avait cinq. Chaque refus a laissé la base intacte — registre à 563,
> fonction inchangée, bail inchangé. Une assertion fausse est une assertion qui
> marche.

**Un mail porte son identité.** `mails_portent_leur_identite` est passée le
9 octobre 2026, registre **20261009003201**, qui porte le registre de 562 à
**563** entrées. `mails.id` est clé primaire `text NOT NULL` et n'avait aucune
valeur par défaut : **neuf sites d'écriture, dans deux fonctions**, insèrent sans
le fournir et levaient `23502`. Une RPC étant une seule transaction, la passe
nocturne des prêts Helvetia mourait **entière** au premier emprunteur insolvable.
Le défaut posé est, au caractère près, celui que la porte générique
`mail_systeme_envoyer` produit depuis toujours — et sa preuve 2 lève si les deux
divergent un jour.

> **Première migration écrite sous la règle 3**, et elle montre ce que la règle
> change : ses cinq preuves ne lisent que le catalogue, et les quatre empreintes
> de données relevées **avant et après** l'application sont identiques. L'épreuve
> comportementale — la branche « débiteur à sec » qui traverse enfin — est restée
> au banc, en transaction annulée.

**L'échéancier Helvetia ne s'exécute plus qu'une fois par jour.**
`idempotence_prets_helvetia` est passée le 9 octobre 2026, registre
**20261008235521**, qui porte le registre de 561 à **562** entrées — première
migration du chantier 6. `traiter_prets_helvetia_quotidien` n'avait aucun
marqueur de journée : un second appel le même soir prélevait une **seconde
mensualité entière** et faisait avancer l'escalade du contentieux de deux crans
en une nuit. Elle vit maintenant dans `../historique/migrations-appliquees/`.

> **Elle a coûté un incident de données, et c'est la leçon à retenir d'elle.**
> Ses preuves faisaient tourner la RPC pour de vrai sur un prêt témoin. Or cette
> RPC crédite aussi la caisse de la banque privée à chaque prélèvement : 1 000 FR
> sont restés dans `republic_banque-privee` après la suppression du témoin.
> Détectés par l'empreinte des caisses, restitués dans la minute. **Une
> migration commite, y compris les effets de bord de ses propres preuves** —
> voir la règle 3 ci-dessous.

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

Trois règles, apprises à ces chantiers :

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
3. **Ne prouver que du structurel dans la migration.** Une migration **commite**.
   Si ses contrôles font *tourner* le mécanisme qu'elle corrige, ils en commitent
   aussi les effets — et un mécanisme touche presque toujours plus de tables que
   celles qu'on surveille. Dans la migration : lire le corps d'une fonction,
   compter des droits, vérifier une contrainte, un ordre d'instructions. La
   démonstration **comportementale** — « trois appels ne prélèvent qu'une fois »
   — appartient au banc en transaction annulée, avant application. Cette règle
   est née de `idempotence_prets_helvetia`, qui a laissé 1 000 FR en bêta.

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
