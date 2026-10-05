# Baseline Human Gambit

> **État : pilote.** Seul le domaine `communication` est extrait, pour valider la
> méthode. Le baseline complet sera construit au chantier 2E.

Ce dossier contient la définition canonique du schéma PostgreSQL de Human Gambit,
extraite des catalogues de la base de production et destinée à permettre, à terme,
de reconstruire le socle du jeu sur un projet Supabase neuf.

Il **ne contient aucune donnée de jeu**. La question de savoir quelles lignes
doivent exister dans une installation neuve — configuration du moteur, contenu
d'un empire, état initial — relève du chantier 2C et n'est pas tranchée ici.

## Pourquoi un baseline plutôt que l'histoire des migrations

Parce que l'histoire ne suffit pas. 84 des 252 tables de la base n'ont leur
`CREATE TABLE` nulle part : ni dans le registre Supabase, ni dans le dépôt. Elles
datent de la période fondatrice, du 31 mai au 15 août 2026, qui n'a produit aucun
fichier SQL. Rejouer l'histoire échouerait sur la première de ces tables.

L'histoire, elle, est archivée à part dans `historique/registre-supabase/`, en
lecture documentaire. Elle n'est pas rejouable et ne doit jamais l'être.

## La règle d'application : par phase, pas par domaine

Les fichiers sont numérotés par **phase de reconstruction**. Quand le baseline
sera complet, on appliquera la phase 10 de **tous** les domaines, puis la phase 20
de tous, et ainsi de suite — **jamais un domaine entier d'un coup**.

C'est ce qui permet qu'une clé étrangère ou une policy d'un domaine pointe vers un
objet d'un autre sans imposer d'ordre entre les domaines.

| Phase | Fichier | Contenu | Pourquoi là |
|---|---|---|---|
| 10 | `10_tables.sql` | tables, colonnes, défauts, identités | rien ne peut exister avant |
| 20 | `20_fonctions.sql` | fonctions | **créables dans n'importe quel ordre** : le corps d'une fonction `plpgsql` ou `sql` non-`ATOMIC` n'est pas validé à la création. Elles viennent avant les policies, les déclencheurs et les vues, qui exigent leur existence |
| 30 | `30_contraintes.sql` | PK, UNIQUE, CHECK, puis FK | les FK exigent toutes les tables |
| 35 | `35_index.sql` | index **autonomes** uniquement | ceux portés par une contrainte sont recréés par la contrainte |
| 40 | *(vues)* | — | aucune vue dans ce domaine |
| 50 | `50_triggers.sql` | déclencheurs | exigent leur fonction **et** leur table |
| 60 | `60_rls-policies.sql` | activation RLS puis policies | les policies exigent les fonctions qu'elles invoquent |
| 70 | `70_droits.sql` | `GRANT` table, colonne, fonction | exigent tous les objets |
| 80 | `80_commentaires.sql` | `COMMENT ON` | sans dépendance |

Cet ordre n'est pas supposé : il vient de l'observation des catalogues. Le graphe
d'appel des fonctions a été parcouru exhaustivement et **ne contient aucun cycle**
(profondeur maximale 9 pour un plafond de 12, donc l'exploration s'est arrêtée
d'elle-même), et il n'y a aucun cycle de clés étrangères.

## Arborescence

```
baseline/
  README.md                         ce fichier
  domaines/
    communication/
      10_tables.sql       …         les fichiers de phase, générés
      80_commentaires.sql
      MANIFESTE.json                ce qui a été rendu
      CONTROLE.json                 ce que la base disait, au moment du relevé
```

Un dossier par domaine, huit fichiers de phase au plus : assez gros pour être lus
d'une traite, assez séparés pour qu'un `diff` reste parlant. Ni un fichier unique
de 1,7 Mo, ni des centaines de fichiers d'un objet chacun.

Les fichiers `.sql` sont **générés** : ne pas les éditer à la main. Toute
correction passe par une migration appliquée à la base, puis par une nouvelle
extraction.

## Vérifier qu'un domaine est fidèle

    python3 outils/baseline/verifier.py communication

Trois sources sont confrontées et doivent concorder : `CONTROLE.json` (ce que la
base dit), `MANIFESTE.json` (ce qui a été rendu), et les fichiers `.sql`
eux-mêmes. Les contrôles de **sécurité** — `SECURITY DEFINER`, activation RLS,
fermeture au client — sont séparés des contrôles de structure et échouent
indépendamment : une reconstruction peut être structurellement parfaite et
fonctionnellement ouverte.

## Dépendances externes d'un domaine

Elles sont déclarées dans `outils/baseline/domaines.json` et reprises dans le
`MANIFESTE.json` de chaque domaine. Un domaine n'aspire jamais silencieusement les
objets d'un autre : il dit de quoi il a besoin, et l'assemblage global y pourvoit.

Pour `communication`, ce sont quatre fonctions du socle — `mon_personnage()`,
`est_appel_serveur()`, `acteur_poste_courant()`, `rp_transition_active()` — et
cinq tables citées dans des corps `plpgsql`, qui ne bloquent pas la création
puisque ces corps ne sont pas validés à la création.

## Ce que le baseline ne couvrira jamais

Les valeurs courantes des séquences, la mise en forme d'origine du SQL (les
contraintes, index, policies et vues sont réimprimés depuis l'arbre analysé), les
commentaires placés autour des objets dans les migrations, et tout ce qui vit hors
de la base : configuration Auth du projet, buckets Storage, crons Vercel,
variables d'environnement.
