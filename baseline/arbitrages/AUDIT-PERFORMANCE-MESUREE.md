# Performance — ce que la base mesure vraiment

> **Mesures du 9 octobre 2026, lues dans les statistiques de PostgreSQL.** Aucune
> correction n'a été faite à partir d'elles : ce document existe pour qu'un futur
> chantier performance parte de chiffres et non de soupçons.
>
> **Deux fenêtres distinctes, et il ne faut pas les confondre.**
> `pg_stat_user_tables` cumule depuis le **22 mai 2026** (`stats_reset`), soit
> 4,5 mois de bêta réelle — c'est la source fiable. `pg_stat_statements` (1.11,
> installée) a été remise à zéro par le **redémarrage du redimensionnement**, il y
> a 3 h : elle ne couvre qu'une nuit sans joueurs et n'est donc pas citée ici.

## Le fait qui recadre tout : les tables sont minuscules

| Table | Lignes vivantes | Taille totale |
|---|---|---|
| `personnages_donnees` | **8** | 6,0 Mo (dont 64 ko d'index) |
| `mails` | 32 | 192 ko |
| `forum_topics` / `forum_posts` | 8 / 8 | 208 ko |
| `championnat` | 10 | 272 ko |
| `messages_chat` | **0** | 48 ko |
| `historique_deplacements` | 10 562 | 4,1 Mo |

Base entière : **104 Mo**.

## Le suspect « index absents sur `messages_chat` / `mails` / `forum_*` » est INFONDÉ

Les chiffres paraissent alarmants et ne le sont pas :

| Table | `seq_scan` | Lignes lues en séquentiel | `idx_scan` |
|---|---|---|---|
| `invitations_diner` | **458 307** | 2 407 648 | 14 |
| `personnages_donnees` | 236 662 | 1 839 327 | 842 949 |
| `championnat` | **210 029** | 636 380 | 11 481 |
| `forum_topics` | 172 300 | 1 463 240 | 659 |
| `messages_chat` | **150 428** | **5 524 430** | 17 |
| `mails` | 93 317 | 1 843 585 | 70 |
| `forum_posts` | 87 303 | 1 243 004 | 78 |

**Sur une table de 8 lignes, PostgreSQL choisit le balayage séquentiel parce
qu'il est plus rapide qu'un index** — lire une page suffit. Les 1,8 million de
lignes lues sur `mails` sont 93 317 balayages × ~20 lignes : du bruit. Ajouter un
index n'accélérerait rien et coûterait à **chaque écriture**. Le suspect est donc
écarté, et il faut le dire : c'est le genre d'optimisation qui se justifie par un
grand nombre sans jamais vérifier de quoi ce nombre est fait.

## Ce que les chiffres désignent réellement

**1. La fréquence des appels, pas le coût unitaire.** `invitations_diner` est
interrogée **458 307 fois** pour **zéro ligne** ; `messages_chat` 150 428 fois pour
zéro ligne ; `championnat` 210 029 fois pour dix. Ce sont des **sondages
périodiques du navigateur**, et c'est là qu'est la charge : non pas dans ce que
chaque requête coûte, mais dans leur nombre. Réduire une fréquence de sondage
change un comportement observable — ce n'est pas une optimisation triviale, et
ce n'est pas fait ici.

**2. `personnages_donnees` : 81 436 `UPDATE` pour 8 lignes vivantes.** Le suspect
« la sauvegarde périodique écrit beaucoup de colonnes `jsonb` même sans
changement » est **confirmé par ce chiffre**, qui est le plus net du relevé. La
table pèse 6 Mo pour 8 lignes — conséquence des versions mortes que chaque
`UPDATE` laisse derrière. Mesurer *quelles* colonnes changent réellement demande
d'instrumenter l'écriture, ce qui est un chantier à part.

**3. `presences` : 113 873 `UPDATE` pour 12 lignes.** Même famille.

## Les 43 index jamais utilisés : à ne PAS supprimer

`idx_scan = 0` depuis le 22 mai sur 43 index, dont 20 autonomes (les autres
portent une contrainte et ne sont pas supprimables). Ils pèsent **16 à 64 ko
chacun**, soit ~400 ko au total sur une base de 104 Mo : le gain serait nul.

Et surtout, plusieurs attendent une charge qui n'est pas encore venue —
`idx_ventes_snapshots_acheteur`, `idx_pnj_evt_pj`,
`idx_registre_ventes_armes_jour` portent sur des tables vides ou presque, dont le
mécanisme vient d'être livré. Un index inutilisé sur une table vide n'est pas un
déchet : c'est une préparation. Les supprimer serait confondre « jamais servi »
avec « inutile ».

## Ce qu'il faudrait mesurer ensuite, et comment

- **Attendre une fenêtre de `pg_stat_statements` représentative** : plusieurs
  jours avec des joueurs, sans redémarrage. C'est la seule source qui dise quelle
  *requête* coûte, et non quelle table est touchée.
- **Instrumenter la sauvegarde du personnage** pour savoir combien des 81 436
  `UPDATE` ne changent rien. Un `UPDATE` sans changement réel reste un `UPDATE`
  pour PostgreSQL : il écrit une version morte et déclenche les triggers.
- **Compter les sondages côté client** avant de toucher à leur fréquence : le
  chiffre de 458 307 ne dit pas encore si c'est un écran, une boucle, ou une
  poignée de joueurs restés connectés des semaines.

Aucune de ces trois mesures ne se fait en une nuit, et aucune ne justifie une
correction tant qu'elle n'est pas faite.
