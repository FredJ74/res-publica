# Outillage d'extraction du baseline

> **Le processus à suivre pour faire évoluer la base est dans
> `../../WORKFLOW-SUPABASE.md`.** Ce README-ci décrit les outils et les pièges
> rencontrés ; il ne redit pas le processus.

Un module, une responsabilité.

| Fichier | Rôle |
|---|---|
| `domaines.json` | **le périmètre** : quels objets appartiennent à quel domaine. Relu par un humain, jamais deviné par le code |
| `requetes.py` | **les requêtes d'introspection** des catalogues PostgreSQL. Imprime le SQL exact à exécuter |
| `rendre.py` | **le rendu du schéma** : transforme les exports JSON en fichiers `.sql` lisibles + un `MANIFESTE.json` par domaine |
| `seeds.py` | **le rendu des seeds** : extrait et écrit le contenu initial, table par table |
| `verifier-baseline.py` | **le contrôle global** : quatre familles qui échouent indépendamment |
| `assembler.py` | **le test d'assemblage statique**, sans créer de base |
| `verifier-monde-neuf.py` | **le contrôle du monde neuf** : aucune donnée de bêta, aucun vestige canonisé |
| `reconstruire.py` | **la reconstruction** : assemble le baseline, le soumet à la grammaire réelle de PostgreSQL et simule son application |
| `verifier-workflow.py` | **le garde-fou du processus** : huit invariants qui empêchent la régression du workflow |
| `controler-tout.py` | **le lanceur unique** : enchaîne les **onze** contrôles et rend un verdict d'ensemble |
| `fonctions.json` | **les fonctions recopiées** (chantier 7) : quelle fonction du navigateur fait foi, où `api/` en détient un exemplaire, et sur quelle grille les deux sont confrontés |
| `verifier-fonctions.py` | **le contrôle des fonctions recopiées** : charge les deux côtés pour de vrai — le module serveur dans une portée isolée — et les exécute sur les grilles déclarées |
| `verifier.py` | **le contrôle du domaine pilote** `communication` (chantier 2B) |
| `arbitrages.py` | **les tableaux d'arbitrage** de l'état initial, préparés pour être remplis |
| `verifier-classification.py` | **le contrôle de la classification** 2C |

Il n'y a **qu'un seul** moteur de rendu du schéma. Le pilote 2B avait le sien ;
le chantier 2E l'a remplacé par le moteur complet, qui reproduit le domaine
`communication` à l'identique — vérifié par `verifier.py`, en re-dérivant son
périmètre par règles et non depuis la liste gelée. Deux moteurs écrivant les
mêmes fichiers auraient été un piège : le dernier exécuté aurait gagné.

## Pourquoi l'extraction se fait en deux temps

La machine de développement n'a **ni `pg_dump`, ni `psql`, ni CLI Supabase, ni
docker**. Le seul canal vers la base est l'outil MCP `execute_sql`, qui est appelé
par l'assistant et non par un script. D'où la séquence :

1. `requetes.py` imprime la requête ;
2. l'assistant l'exécute via `execute_sql` ; la sortie JSON est enregistrée ;
3. `rendre.py` lit ces exports et écrit les fichiers du baseline.

C'est volontaire : la requête qui a produit le baseline est **dans le dépôt**,
relisible et rejouable telle quelle. Rien n'est improvisé au moment de l'extraction.

```
python3 outils/baseline/requetes.py --liste
python3 outils/baseline/requetes.py communication inventaire
python3 outils/baseline/requetes.py --controle-global

python3 outils/baseline/rendre.py <repertoire_des_exports>          # le schéma
python3 outils/baseline/seeds.py  --sql    <repertoire_des_exports> # imprime le SQL des seeds
python3 outils/baseline/seeds.py  --rendre <repertoire_des_exports> <resultat>

python3 outils/baseline/arbitrages.py --sql                          # tableaux d'arbitrage
python3 outils/baseline/arbitrages.py --rendre <resultat>

python3 outils/baseline/controler-tout.py        # les huit, en une commande

python3 outils/baseline/verifier-workflow.py     # ou un par un
python3 outils/baseline/verifier-baseline.py
python3 outils/baseline/verifier-monde-neuf.py
python3 outils/baseline/assembler.py
python3 outils/baseline/reconstruire.py                   # grammaire + simulation
python3 outils/baseline/reconstruire.py --ecrire monde-neuf.sql
python3 outils/baseline/verifier.py communication
python3 outils/baseline/verifier-classification.py
```

`rendre.py` reconnaît les quatre exports **à leur clé discriminante**
(`export_structure`, `export_fonctions`, `export_logique`, `export_droits`), pas
à leur nom de fichier : on lui donne un répertoire, il trouve.

## Affectation des objets à un domaine

Une **table** tient son domaine de `baseline/classification-donnees.csv`, produit
au chantier 2C. Source unique : la liste n'est pas recopiée dans le code.

Une **fonction** tient le sien de `_regles_fonctions` dans `domaines.json` :
quinze règles de préfixe **ordonnées**, la première qui correspond gagne, plus
cinq surcharges explicites pour les cinq fonctions qu'aucun préfixe n'attrape.
Vérifié sur les 641 signatures : 636 par règle, 5 par surcharge, 0 orpheline.

Les objets dépendants — contraintes, index, policies, déclencheurs, droits,
commentaires, RLS — suivent le domaine de leur table. Une séquence suit le
domaine de la table qui la **possède** ; une séquence autonome va au socle.

**Une fonction ou une table qui n'entrerait dans aucune règle fait ÉCHOUER le
rendu.** Elle ne disparaît jamais en silence : c'est la seule garantie qui tienne.

## Pagination

`execute_sql` ne refuse pas les gros résultats : au-delà d'environ 100 000
caractères, il **dévie la sortie complète vers un fichier**, sans perte. Vérifié
sur 1 267 605 caractères extraits en une requête, intégrité recoupée par comptage.

La pagination n'est donc nécessaire que si l'on veut les définitions dans le
contexte plutôt que sur disque. Dans ce cas, la seule stratégie fiable est un
**budget d'octets à somme glissante sur un tri stable**, jamais « N objets par
lot » : une fonction peut faire 200 caractères, une autre 15 000.

```sql
with d as (select p.oid::regprocedure::text as sig,
                  length(pg_get_functiondef(p.oid)) as len from …),
     num as (select sig, len, sum(len) over (order by sig collate "C"
                      rows between unbounded preceding and current row) as cumul from d)
select (cumul-1)/60000 as lot, count(*), sum(len) from num group by 1 order by 1;
```

Pour le baseline complet, aucun lot n'a été nécessaire : les quatre exports
pèsent 2,7 Mo au total et sont tous partis sur disque sans traverser le contexte.
Le plus gros — les 641 définitions de fonction — fait 1 524 022 caractères.

## Pièges rencontrés, et ce qu'ils ont coûté

**1. `COLLATE "C"` sur toute empreinte qui dépend d'un tri.** Sans lui, Postgres
trie avec la collation de la base, qui ignore la ponctuation au premier rang :
`mail_expediteur_autorise_strict(...)` passe **avant** `mail_expediteur_autorise(...)`.
Python trie par point de code, où `(` précède `_`. Les deux empreintes divergent
alors que les définitions sont rigoureusement identiques. Le contrôle a été rouge
une première fois pour cette seule raison.

**2. `LIKE '%chat%'` attrape « ra-chat ».** Deux tables d'économie,
`entreprises_prix_rachat` et `usines_rachat_config`, sont entrées dans le
périmètre de la communication par ce motif. Elles sont consignées comme faux
positifs dans `domaines.json`, pour que personne ne repose le piège.

**3. `pol.polcmd` est de type `"char"`**, pas `text` : toute concaténation exige
un `::text` explicite, sinon « operator is not unique ».

**4. Un `GROUP BY` par position ne fonctionne pas** à travers un
`jsonb_build_object` : il faut répéter l'expression.

**5. Les droits au niveau colonne (`attacl`) sont invisibles dans `relacl`.**
Le domaine pilote n'en a aucun, mais `detentions` en porte 20 ailleurs dans ce
schéma, et c'est là que vit le `SELECT` d'`authenticated` sur cette table. La
requête `droits_colonnes` existe pour cette raison.

**6. Un `UNION ALL` dont la première branche renvoie du `name` tronque tout le
reste à 63 caractères, en silence.** `pg_class.relname` est de type `name`, long
de 63 octets au plus (`NAMEDATALEN - 1`). Le type de la colonne de l'union est
résolu sur la **première** branche ; les suivantes y sont converties sans un mot.
Trois signatures de fonction étaient ainsi amputées dans le contrôle des
commentaires — et le contrôle aurait validé une identité tronquée, confondant
deux fonctions partageant leurs 63 premiers caractères. Correction : un `::text`
explicite sur **chaque** branche. C'est le piège le plus sérieux rencontré
jusqu'ici, parce qu'il ne produit aucune erreur.

**7. `pg_get_triggerdef(oid)` et `pg_get_triggerdef(oid, true)` ne donnent pas le
même texte.** Le baseline écrit la forme « pretty ». Un contrôle qui compare
l'autre forme rougit alors que rien ne diverge. La leçon vaut pour toutes les
fonctions `pg_get_*def` : le contrôle doit comparer **la forme écrite**, pas une
autre.

**8. La requête des droits oubliait les séquences.** Elle ne couvrait que les
tables et les fonctions. Les 31 séquences du schéma portent pourtant 102 lignes de
droits. Sans elles, une base reconstruite refuse tout `nextval()` aux rôles
clients — donc tout `INSERT` sur une table à clé sérielle. C'est le contrôle
global qui l'a attrapé : 927 lignes en base contre 825 extraites. Un contrôle qui
ne compare que ce qu'il a extrait ne vérifie rien.

**9. Un résultat qui ne dévie pas doit porter son propre contrôle.** Au-delà
d'environ 100 000 caractères, `execute_sql` écrit la sortie dans un fichier, sans
perte. En dessous, elle revient dans la conversation — et tout **recopiage** d'un
gros JSON peut en perdre un élément sans casser la syntaxe. C'est arrivé le
5 octobre 2026 : une extraction de 29 Ko a perdu **une caisse sur 55**, le JSON
restait valide, et le tableau d'arbitrage se serait construit sur 54 caisses sans
que rien ne le signale. La correction n'est pas « faire plus attention » : la
requête compte désormais elle-même ses lignes dans un bloc `controle`, et le
rendu **refuse d'écrire** si les compteurs ne correspondent pas aux tableaux
reçus. Un contrôle que la donnée transporte avec elle est le seul qui survive au
transport.

**10. Un guillemet-dollar ne s'imbrique pas avec la même étiquette.** Pour qu'un
seed porte une valeur **écrite par arbitrage** plutôt que copiée, `seeds.py` émet
une expression SQL dans l'`INSERT`, enveloppée dans un `$x$…$x$`. L'expression
contenait déjà, elle, un `$x$` autour de son blob JSON : le délimiteur extérieur
refermait donc le premier, le JSON sortait de la chaîne, et PostgreSQL répondait
`syntax error at or near "{"`. Le délimiteur extérieur est désormais **choisi
parmi plusieurs étiquettes, en vérifiant qu'il n'apparaît pas dans l'expression**.
La leçon vaut partout où du SQL est généré : un délimiteur se vérifie contre son
contenu, il ne se suppose pas.

**11. `pg_get_functiondef()` ne termine pas par un point-virgule.** Aucune des
641 définitions de ce schéma n'en portait. Écrites l'une après l'autre, elles se
collaient : PostgreSQL lisait `$function$ CREATE OR REPLACE FUNCTION` comme un
seul ordre malformé, et refusait les 18 fichiers de fonctions. **Le baseline
était fidèle et inapplicable** — un défaut qu'aucun contrôle de fidélité ne peut
voir, puisque la fidélité était intacte. Il a fallu la grammaire réelle de
PostgreSQL pour le trouver. Le rendu ajoute désormais le point-virgule, et les
deux vérificateurs le retirent avant de recalculer l'empreinte.

**12. La découpe d'un gros fichier ne doit jamais se faire sur le texte.** La
première version coupait sur les lignes vides ; comme un corps de fonction en
contient, deux fonctions ont été coupées en deux. Le contrôle l'a vu — 639
définitions relues sur 641 — et la découpe se fait désormais sur les **blocs**,
un bloc valant un objet entier.

## Trois questions différentes, trois outils

Elles ne se déduisent pas l'une de l'autre, et c'est pourquoi il y a trois
outils plutôt qu'un gros.

**`verifier-baseline.py` — est-ce fidèle ?** Le baseline dit-il la même chose que
le catalogue ? C'est la question du contenu.

**`verifier-monde-neuf.py` — est-ce propre ?** Le monde qui naîtra traîne-t-il des
artefacts de bêta ou des vestiges ? Un baseline parfaitement fidèle peut faire
naître un monde pollué.

**`verifier-workflow.py` — le processus tient-il ?** Le dépôt est-il encore rangé
comme le workflow l'exige ? Un baseline parfait peut coexister avec un processus
déjà reparti de travers : un `.sql` posé à la racine, une migration sans
horodatage, un second moteur de rendu. Rien de cela ne se voit dans un contrôle
de contenu.

Le garde-fou n'est pas décoratif : vérifié en lui soumettant **six** régressions
réelles — un `migration_*.sql` à la racine, un nom de migration non conforme, une
migration antérieure au point de coupe, un `patch_*.py` à la racine, un
générateur laissé dans `.scratch/`, et un fichier citant encore un chemin
historique. Il refuse les six.

Les outils eux-mêmes sont rangés : `outils/baseline/` pour le baseline,
`outils/generateurs/` pour les 8 miroirs de `data.js`, `outils/` pour le
transverse. Voir `../generateurs/README.md`.

## Fidèle n'est pas propre

`verifier-baseline.py` vérifie que le baseline est **fidèle** au catalogue.
`verifier-monde-neuf.py` vérifie quelque chose qui ne s'en déduit pas : que le
monde qui naîtra de ces seeds ne traîne **ni les artefacts de la bêta, ni les
objets que l'audit a déclarés vestiges**.

Un baseline peut être parfaitement fidèle *et* faire naître un monde pollué. La
fidélité dit « c'est bien ce que la base contient » ; ce contrôle-ci dit « c'est
bien ce qu'un monde neuf doit contenir ». Il lit les 856 lignes de données des
seeds, cherche 6 motifs d'artefact et 13 vestiges nommés, et n'admet que les
faux positifs **déclarés** — un seul aujourd'hui, le nom de couverture « Nabil
Ben Azzouz ».

## Les quatre familles de contrôle, et pourquoi elles sont séparées

Un baseline peut être structurellement parfait et fonctionnellement ouvert. Si
les contrôles étaient mélangés, une régression de sécurité passerait derrière un
total juste. D'où quatre familles qui échouent **indépendamment** : structure,
logique serveur, sécurité, seeds — plus l'intégrité des fichiers.

Le principe des empreintes est unique : la base calcule l'empreinte du **texte
exact** que le dépôt contiendra, et le vérificateur la recompose depuis les
`MANIFESTE.json`, qui portent l'empreinte de chaque objet. Aucun des deux côtés
ne reparse du SQL.

Les **colonnes** font exception, et c'est assumé : le fichier `CREATE TABLE`
n'est pas le texte brut de la base, à cause de la règle du serial ci-dessous.
Leur empreinte porte donc sur les **faits du catalogue**, à deux niveaux pour
rester décomposable par table. La règle du serial ne vit ainsi qu'à un seul
endroit, `rendre.py`, et n'est pas réécrite en SQL.

Deux empreintes coexistent pour les policies. Celle héritée du chantier 2B
ignore le rôle visé par le `TO` : un « `TO anon` » devenu « `TO authenticated` »
y passerait inaperçu. La seconde porte sur l'ordre `CREATE POLICY` complet. Les
deux sont contrôlées.

## Règle du serial

Quand le défaut d'une colonne est `nextval()` sur une séquence **possédée** par
cette colonne (`pg_depend.deptype = 'a'`) et que le type est entier, le rendu
écrit `bigserial` plutôt que `bigint DEFAULT nextval(...)`. C'est strictement
équivalent — PostgreSQL recrée la séquence, le défaut et le lien de propriété —
et c'est lisible. Une séquence autonome, elle, serait émise séparément.
