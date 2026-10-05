# Archive du registre de migrations Supabase

> **Ces fichiers ne constituent pas une chaîne de migrations.**
> Ils documentent le passé. Ils ne doivent jamais être exécutés, ni à la main, ni
> automatiquement, ni comme étape d'installation d'une base neuve.

## 1. Pourquoi ce dossier existe

Jusqu'au 5 octobre 2026, l'intégralité de l'histoire des migrations du projet vivait
dans une seule table du projet Supabase hébergé : `supabase_migrations.schema_migrations`.
Elle n'était **pas** dans Git. Le dépôt ne contenait de fichier correspondant que pour
une partie de ces entrées — 355 des 539 n'en avaient aucun.

Cette table était donc la seule source complète de l'histoire du schéma depuis le
6 septembre 2026, et un incident de projet, une migration de compte ou une fausse
manœuvre l'aurait fait disparaître sans recours.

Ce dossier met cette histoire à l'abri dans Git. C'est son seul objet.

## 2. Ce que ces fichiers sont

Une **archive documentaire** : une copie fidèle, fichier par fichier, du SQL
réellement appliqué à la base de production, dans l'ordre où il l'a été.

Chaque fichier porte en tête un en-tête généré qui indique sa version Supabase, son
nom d'origine, sa catégorie, sa date déduite, l'empreinte MD5 de son SQL, et un
avertissement de non-rejouabilité. Sous l'en-tête, le SQL historique est conservé
**intégralement et sans aucune modification** : ni correction, ni mise en forme, ni
séparation des parties DDL et DML, ni ajout d'idempotence. On archive ce qui s'est
réellement passé, pas ce qu'on aurait voulu qu'il se passe.

## 3. Ce que ces fichiers ne sont pas

Ce n'est pas une chaîne de reconstruction, et ils ne pourront jamais en devenir une.
Trois raisons, chacune suffisante :

1. **L'histoire ne commence pas ici.** Le registre s'ouvre le 6 septembre 2026, alors
   que le projet a démarré le 31 mai. 84 des 252 tables de la base — le noyau du jeu :
   `personnages_donnees`, `organisations`, `entreprises`, `forum_*`, `mails`,
   `presences`, `terrains_etat` — n'ont leur `CREATE TABLE` ni ici ni dans le dépôt.
   Rejouer cette archive sur une base vierge échouerait sur la première table absente.

2. **Une partie de ces migrations mute des données vivantes.** 114 entrées mêlent
   structure et données, 32 ne font que muter des données. On y trouve nommément
   `sauvegarde_integrale_avant_reset_beta`, `reset_beta_identites_joueurs`,
   `socle_pnj_snapshot_militaire_avant_bascule`, `dotation_initiale_reliquat`.
   Les rejouer ne reconstruirait pas un schéma : cela rejouerait la réinitialisation
   d'une bêta.

3. **Certaines dépendent de l'état de la base au moment où elles ont tourné.**
   Trois entrées lisent les définitions de fonctions dans le catalogue
   (`pg_get_functiondef`), les transforment par expression régulière, puis exécutent
   le résultat. Leur effet dépend entièrement de ce que contenait la base ce jour-là.
   Les rejouer ailleurs ne produirait pas le même schéma — ou rien du tout.

La chaîne de migrations **active** sera un dossier distinct, créé lors d'un chantier
ultérieur, et partira d'un baseline canonique extrait de la base vivante. Ce dossier-ci
restera en lecture, à côté, pour répondre à la question « quelle migration a introduit
cet objet, et pourquoi ? » — à laquelle personne ne pouvait répondre avant.

## 4. Période et volume couverts

| | |
|---|---|
| Entrées archivées | **539** |
| Première version | `20260906195401` — `lot_1_5_5_dossiers_urbanisme` (6 septembre 2026) |
| Dernière version | `20261004214621` — `grobras_metiers_agent_securite_et_maitre_chien` (4 octobre 2026) |
| Période | 6 septembre → 4 octobre 2026, 26 jours d'activité effective |
| SQL historique archivé | 3 424 877 octets |
| Plus petite entrée | 198 octets |
| Plus grosse entrée | 70 721 octets |

Les versions sont strictement croissantes et uniques, les noms tous distincts, et
aucune entrée n'est vide.

## 5. Répartition par catégorie

| Catégorie | Entrées | Signification |
|---|---|---|
| **DDL** | 393 | structure, droits, commentaires seulement |
| **MIXTE** | 114 | structure **et** mutation de données dans la même entrée |
| **DML** | 32 | mutation de données seulement |
| **AUTRE** | 0 | ni l'un ni l'autre |
| **Total** | **539** | |

### Comment la classification est obtenue

La règle est automatisée et reproductible. Elle s'applique au SQL de chaque entrée,
dans cet ordre :

1. **Les corps de fonction sont neutralisés.** Un `INSERT` écrit *à l'intérieur* d'une
   RPC n'est pas une mutation de données : c'est une définition de fonction. 921 corps
   dollar-quotés ont été ainsi écartés.
2. **Les blocs `DO` sont conservés.** Eux s'exécutent réellement, donc leur contenu
   compte. 48 blocs `DO` ont été conservés.
3. Commentaires et littéraux texte sont retirés, puis les mots-clés DDL
   (`CREATE`/`ALTER`/`DROP` de table, fonction, vue, déclencheur, policy, index,
   séquence, schéma, type ; `GRANT` ; `REVOKE` ; `COMMENT ON`) et DML
   (`INSERT INTO`, `DELETE FROM`, `TRUNCATE`, `COPY … FROM`,
   `UPDATE <table> [alias] SET`) sont recherchés.
4. **Le DDL et le DML dynamiques sont détectés** en réexaminant le texte littéraux
   compris, mais uniquement lorsque `EXECUTE` est présent — pour attraper les
   `EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER', …)`.
5. **La réécriture pilotée par le catalogue est détectée** par un couple de signaux :
   `EXECUTE` combiné à une référence à `pg_get_functiondef`, `pg_proc` ou
   `::regprocedure`. Dans ces trois entrées, le mot-clé DDL n'apparaît nulle part dans
   le texte : la définition est lue dans la base à l'exécution, transformée, puis
   exécutée. Aucune analyse textuelle ne peut les voir autrement.

### Écart avec les chiffres annoncés par le chantier 2A

Le chantier 2A avait estimé 129 DDL / 32 DML / 376 MIXTE / 2 AUTRE. La classification
définitive donne 393 / 32 / 114 / 0, soit **266 entrées classées différemment**, dont
**260 passent de MIXTE à DDL**.

La cause est entièrement dans la méthode, pas dans les données. La mesure de 2A était
un `ILIKE` sur le texte entier de chaque entrée : elle comptait donc comme « mutation
de données » tout `INSERT INTO` apparaissant dans le **corps d'une fonction** créée par
la migration. Or une migration qui crée une RPC d'achat contient forcément un
`INSERT INTO` — dans le code de la RPC, pas dans la migration.

**Conséquence sur une conclusion de 2A.** Le rapport 2A s'appuyait notamment sur
« 70 % des entrées mêlent DDL et DML » pour écarter la stratégie du rejeu de
l'histoire. Ce chiffre était faux : la proportion réelle est de **21 %** (114 sur 539),
et 27 % si l'on y ajoute les 32 entrées de DML pur. L'argument reste valable mais il
est plus faible qu'annoncé. Les raisons décisives d'écarter le rejeu sont les deux
autres, inchangées : les 84 tables sans aucun `CREATE TABLE`, et la période fondatrice
du 31 mai au 15 août 2026 qui n'a produit aucun fichier SQL.

## 6. Convention de nommage

`<version>_<nom>.sql`, où `version` est la version Supabase à 14 chiffres et `nom` le
nom original de la migration, **repris tel quel**.

Aucune normalisation n'a été nécessaire : les 539 noms sont déjà en `snake_case` pur
(vérifié : zéro nom contient un caractère hors `[a-z0-9_]`), les 539 versions sont au
format 14 chiffres, et il n'existe aucune collision — 539 versions distinctes pour
539 noms distincts.

## 7. Vérifier que cette archive est intacte

    python3 outils/verifier-archive-registre.py

L'outil ne touche pas à la base et n'écrit rien. Il contrôle le nombre de fichiers,
la concordance entre chaque nom de fichier et son en-tête, l'absence de doublon ou de
version manquante, puis recalcule l'empreinte MD5 du SQL de chaque fichier et la
compare à celle que son en-tête déclare.

Il recalcule enfin une **empreinte globale** sur les 539 couples `version:md5` et la
compare à celle relevée dans le registre au moment de l'export, conservée dans
`empreintes.json` :

    9e74c0eb5adbddc8b61de2b1532cbef0

Cette seule valeur atteste que l'ensemble des versions et l'intégralité des SQL
archivés sont conformes au registre vivant.

## 8. Anomalies historiques constatées pendant l'archivage

Relevées, non corrigées — ce chantier n'avait pas vocation à toucher au passé.

- **Trois entrées réécrivent des fonctions par expression régulière** :
  `chantier_b_exiger_acteur_rpc_publiques`,
  `chantier_b_exiger_acteur_rpc_begin_minuscule` et `caisse_marqueur_appel_interne`
  lisent `pg_get_functiondef`, insèrent une ligne dans le corps par
  `regexp_replace`, puis exécutent le résultat. Elles ont fonctionné, mais leur effet
  n'est pas reproductible hors du contexte exact de leur exécution.
- **Une entrée pose puis retire la même valeur** : `dotation_initiale_reliquat` et
  d'autres entrées de la même famille portent des opérations de rattrapage sur des
  données de production, identifiées par valeur littérale.
- **Le registre ne couvre pas tout ce qui a été appliqué.** Les fichiers
  `migration_20261005_grobras_*.sql` du dépôt ont créé des tables et des fonctions qui
  existent en base, et le registre ne les mentionne nulle part : du DDL a donc été
  appliqué par un troisième canal, hors de l'outil qui alimente ce registre. L'archive
  ci-présente est donc complète par rapport au registre, mais le registre lui-même
  n'est pas complet par rapport à la base.

## 9. Ce que ce dossier ne couvre pas

Les 184 fichiers `migration_*.sql` qui vivent encore à la racine du dépôt n'ont **pas**
été déplacés ni modifiés par ce chantier. Leur sort sera traité plus tard, lors de la
mise en place de la chaîne active.
