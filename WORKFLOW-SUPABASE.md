# Faire évoluer Supabase — le processus

> **À lire avant de toucher à la base.** Ce fichier est la seule description du
> processus ; les autres `README` y renvoient plutôt que de le répéter.

Jusqu'au 5 octobre 2026, le schéma n'était plus reproductible : 84 des 252
tables n'avaient leur `CREATE TABLE` nulle part, ni dans le registre Supabase ni
dans le dépôt. On ne pouvait donc pas reconstruire le jeu, et chaque évolution
creusait l'écart. Le chantier 2E a remplacé l'histoire perdue par un **état
canonique**, et ce fichier dit comment ne plus le reperdre.

## Les quatre choses, et une seule règle pour les distinguer

| | Rôle | Qui l'écrit |
|---|---|---|
| **`baseline/`** | l'**état canonique** du schéma et du contenu initial, extrait des catalogues PostgreSQL | **personne** — il est *généré* |
| **`migrations/`** | les **évolutions futures**, une par fichier, dans l'ordre | un agent, à la main |
| **`baseline/seeds/`** | le **contenu avec lequel un monde naît** | généré par `seeds.py` |
| **`historique/`** | l'**archive**, documentaire, non rejouable | personne — c'est clos |

**La règle qui les sépare : le baseline SUIT la base, il ne la précède jamais.**
On applique une migration, *puis* on réextrait le baseline. Jamais l'inverse. Un
baseline en avance sur la base est un mensonge, et un baseline en retard est une
dette silencieuse.

## Le processus, en cinq temps

### 1. Partir du baseline, en lecture

```
baseline/domaines/<domaine>/<phase>_<catégorie>.sql
```

Les fichiers `.sql` du baseline sont **générés**. Ne jamais les éditer à la
main : `verifier-baseline.py` réhache chaque définition et le verrait.

### 2. Écrire la migration

```
migrations/<AAAAMMJJHHMMSS>_<nom_en_minuscules>.sql
```

L'horodatage est celui du moment où on l'écrit, en UTC. Il donne l'ordre
d'application, et il doit être **postérieur au point de coupe du baseline**
(`baseline/CONTROLE-GLOBAL.json`, clé `releve_le`).

Une migration doit être **idempotente** : `CREATE ... IF NOT EXISTS`,
`CREATE OR REPLACE FUNCTION`, `DROP POLICY IF EXISTS` avant `CREATE POLICY`. Une
migration rejouée ne doit rien casser.

### 3. L'éprouver SANS l'appliquer

PostgreSQL sait faire du DDL transactionnel. On ouvre une transaction, on joue la
migration, on lève une exception, et tout disparaît — mais les erreurs de
syntaxe, de type et de dépendance, elles, se sont déjà manifestées :

```sql
BEGIN;
  -- la migration, telle quelle
  RAISE EXCEPTION 'banc : rien ne doit rester';
ROLLBACK;
```

Pour une bascule lourde, le banc va plus loin : monter l'ensemble dans un
**schéma jetable** et jouer les cas dessus. `historique/sql-racine/non-appliquees/`
en garde trois exemples écrits de cette façon.

### 4. L'appliquer

**L'agent applique, jamais le game designer.** Fred n'exécute pas de SQL : lui
demander de lancer une migration à la main est hors processus.

L'application passe par le canal technique (MCP `apply_migration`), et **jamais
par une écriture directe** : une migration appliquée hors registre creuse
exactement le trou que ce chantier a rebouché. Le registre Supabase est la seule
trace d'application qui compte.

### 5. Réextraire le baseline, et commiter les deux ensemble

```
python3 outils/baseline/requetes.py --controle-global     # imprime la requête
python3 outils/baseline/rendre.py <répertoire_des_exports>
python3 outils/baseline/seeds.py  --rendre <répertoire> <résultat>
python3 outils/baseline/controler-tout.py                 # les 8 contrôles
```

La migration **et** le baseline réextrait vont dans le **même commit**. Séparés,
ils laisseraient un instant où le dépôt dit autre chose que la base.

Le détail de l'extraction en deux temps — pourquoi l'outil imprime le SQL au
lieu de l'exécuter, et les douze pièges rencontrés — est dans
`outils/baseline/README.md`.

## Où vivent les outils

| | |
|---|---|
| `outils/baseline/` | l'outillage du baseline : extraction, rendu, contrôles, reconstruction |
| `outils/generateurs/` | les 8 générateurs des tables miroir de `data.js` — une table miroir se **régénère**, elle ne se recopie pas |
| `outils/` | les outils transverses (conversion WebP, vérifications ponctuelles) |
| `historique/patchs-ponctuels/` | 342 correctifs à usage unique, archivés — ils ne sont pas des outils |

**Aucun script technique à la racine.** 342 `patch_*.py` et `fix_*.py` y
vivaient ; ils sont archivés, et l'invariant 8 du garde-fou refuse qu'ils
reviennent. Les générateurs, eux, vivaient dans `.scratch/` alors que le projet
en dépend : un outil dont le projet dépend n'a pas sa place dans un brouillon.

## Ce qu'on ne fait plus

**Plus aucun `.sql` à la racine du dépôt.** C'est là que vivaient les 184
migrations dispersées, et c'est ce qui a rendu l'histoire illisible : des
fichiers sans ordre, sans garantie d'application, impossibles à distinguer des
brouillons. Ils sont archivés dans `historique/sql-racine/`, et
`verifier-workflow.py` refuse qu'un `.sql` réapparaisse à la racine.

**Plus de rejeu de l'histoire.** `historique/` est documentaire. Les 539 entrées
du registre et les 184 fichiers racine ne sont **pas rejouables** et ne doivent
jamais l'être : 162 des 184 dépendent d'une table qu'aucun d'eux ne crée.

**Plus de baseline édité à la main.** Une correction passe par une migration,
puis par une réextraction. Jamais par un `.sql` du baseline retouché.

## Les neuf contrôles

Une seule commande les enchaîne :

```
python3 outils/baseline/controler-tout.py
```

| Outil | Ce qu'il vérifie |
|---|---|
| `verifier-workflow.py` | les **huit invariants** du processus : rien à la racine, archives intactes, migrations bien nommées, outils à leur place |
| `verifier-baseline.py` | la fidélité au catalogue, en quatre familles séparées |
| `verifier-autorite.py` | les **onze invariants** d'autorité : qui peut écrire quoi depuis un navigateur |
| `verifier-monde-neuf.py` | ni donnée de bêta, ni vestige, dans les seeds |
| `assembler.py` | les dépendances, à vide |
| `reconstruire.py` | la grammaire réelle de PostgreSQL, et la simulation d'application |
| `verifier-classification.py` | la classification des 252 tables |
| `verifier.py communication` | non-régression du domaine pilote 2B |
| `verifier-archive-registre.py` | non-régression de l'archive 2D |

Aucun n'accède à la base. Ils sont tous rejouables hors ligne, et c'est voulu :
un contrôle qui a besoin de la production n'est pas un contrôle, c'est une
dépendance.

## Écrire depuis le navigateur : une déclaration, pas un réflexe

Le chantier 3 a ajouté une règle au processus. Toute mutation qu'un fichier
chargé par `index.html` adresse directement à PostgREST — `sbInsert`,
`sbUpdate`, `sbDelete`, ou un `fetch` brut — doit être déclarée dans
`outils/baseline/autorite.json`, clé `surface_cliente`. Sinon
`verifier-autorite.py` refuse.

**La bonne réaction à ce refus n'est presque jamais d'ajouter la ligne.** Une
écriture cliente directe signifie que le serveur n'a pas de porte pour cette
action ; la porte manquante est le vrai sujet. Le socle en a déjà :
`mon_personnage()` dit qui parle, `exiger_acteur()` le vérifie,
`est_appel_serveur()` distingue le cron du joueur, `acteur_identifie()` exige
simplement qu'il y ait quelqu'un, et 316 fonctions `SECURITY DEFINER` font le
travail. La liste des écritures directes ne doit que **rétrécir**.

Pourquoi ce fichier vit dans `outils/` et non dans `baseline/` : il est écrit à
la main, et `baseline/` est généré. La déclaration précède la base ; le baseline
la suit. Quand une migration d'autorité attend son application, les invariants
qu'elle ferme sont listés dans `en_attente_d_application` — le contrôle les
rapporte sans échouer, et refuse qu'on y laisse un invariant déjà satisfait.

## Ce qui reste à faire une fois

Appliquer le baseline sur un **vrai moteur PostgreSQL neuf**. Aucun n'est
joignable depuis la machine de développement — ni serveur local, ni conteneur,
ni second projet — et la production est interdite en écriture. Le script est
prêt :

```
python3 outils/baseline/reconstruire.py --ecrire monde-neuf.sql
```

C'est un verrou d'environnement, pas de baseline : il se lèvera le jour où un
projet jetable sera disponible.
