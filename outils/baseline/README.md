# Outillage d'extraction du baseline

Trois modules, une responsabilité chacun.

| Fichier | Rôle |
|---|---|
| `domaines.json` | **le périmètre** : quels objets appartiennent à quel domaine. Relu par un humain, jamais deviné par le code |
| `requetes.py` | **les requêtes d'introspection** des catalogues PostgreSQL. Imprime le SQL exact à exécuter |
| `rendre.py` | **le rendu** : transforme un export JSON en fichiers `.sql` lisibles + `MANIFESTE.json` |
| `verifier.py` | **le contrôle** : confronte la base, le manifeste et les fichiers |

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
python3 outils/baseline/rendre.py   communication <repertoire_des_exports>
python3 outils/baseline/verifier.py communication
```

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

Pour le domaine pilote, aucun lot n'a été nécessaire : 25 Ko au total.

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

## Règle du serial

Quand le défaut d'une colonne est `nextval()` sur une séquence **possédée** par
cette colonne (`pg_depend.deptype = 'a'`) et que le type est entier, le rendu
écrit `bigserial` plutôt que `bigint DEFAULT nextval(...)`. C'est strictement
équivalent — PostgreSQL recrée la séquence, le défaut et le lien de propriété —
et c'est lisible. Une séquence autonome, elle, serait émise séparément.
