# Baseline Human Gambit

> **État : complet.** Les 17 domaines sont extraits, et les seeds sont constitués.
> Point de coupe : **8 octobre 2026, 9 h 44 (Paris)**, registre Supabase à 559
> entrées, dernière version `20261008072422`.
>
> Les chiffres de ce fichier avaient vieilli de deux lots — ils décrivaient encore
> le relevé du 5 octobre alors que `CONTROLE-GLOBAL.json`, lui, suivait la base.
> Ils sont réalignés ici, et c'est `CONTROLE-GLOBAL.json` qui fait foi en cas de
> doute : il est produit par une requête du dépôt, relisible et rejouable.

> **Pour faire évoluer la base, voir `../WORKFLOW-SUPABASE.md`.** Ce README-ci
> décrit ce que le baseline *est* ; le processus pour le faire vivre est décrit
> là-bas, et une seule fois.

Ce dossier contient la définition canonique du schéma PostgreSQL de Human Gambit,
extraite des catalogues de la base de production, et le contenu initial avec
lequel un monde doit naître. Il est destiné à permettre de reconstruire le socle
du jeu sur un projet Supabase neuf — ce que fera le chantier 2F.

Deux choses distinctes, qui ne se mélangent jamais :

- **le schéma**, dans `domaines/` : comment le monde est fait ;
- **les seeds**, dans `seeds/` : avec quoi il naît.

## Ce qu'il contient, en chiffres

| | Base | Baseline | Écarté, nommé |
|---|---|---|---|
| tables | 260 | 254 | 6 |
| colonnes | 2 148 | 2 020 | 55 (+ 73 de vues) |
| fonctions | 663 | 663 | 0 |
| contraintes | 440 | 438 | 2 |
| index autonomes | 147 | 147 | 0 |
| vues | 2 | 2 | 0 |
| déclencheurs | 40 | 40 | 0 |
| policies | 285 | 285 | 0 |
| lignes de droits | 2 786 | 2 774 | 12 |
| commentaires | 205 | 201 | 4 |
| seeds | — | 65 tables, 932 lignes | — |

Chaque total du catalogue se décompose **exactement** en « rendu » + « écarté,
nommé et justifié ». Il n'y a pas de troisième colonne : rien n'est perdu en
silence. Les six tables écartées et toutes les autres divergences voulues sont
listées une à une dans `DIFFERENCES-DELIBEREES.json`, que les outils de contrôle
**lisent** — une divergence non déclarée fait échouer les contrôles.

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
| 40 | `40_vues.sql` | vues | exigent leurs tables ; `reloptions` est reproduit tel quel |
| 50 | `50_triggers.sql` | déclencheurs | exigent leur fonction **et** leur table |
| 60 | `60_rls-policies.sql` | activation RLS puis policies | les policies exigent les fonctions qu'elles invoquent |
| 70 | `70_droits.sql` | `GRANT` table, colonne, fonction | exigent tous les objets |
| 80 | `80_commentaires.sql` | `COMMENT ON` | sans dépendance |
| 85 | `85_default-privileges.sql` | `ALTER DEFAULT PRIVILEGES` | **doit venir en dernier**, voir ci-dessous |

Cet ordre n'est pas supposé : il vient de l'observation des catalogues. Le graphe
d'appel des fonctions a été parcouru exhaustivement et **ne contient aucun cycle**
(profondeur maximale 9 pour un plafond de 12, donc l'exploration s'est arrêtée
d'elle-même), et il n'y a aucun cycle de clés étrangères.

### La phase 85, et les quatre choses qu'il faut savoir à son sujet

Elle ne crée aucun objet : elle règle ce que recevra un objet **qui n'existe pas
encore**. Ajoutée le 9 octobre 2026, parce que sans elle une base reconstruite
depuis ce baseline renaissait avec le défaut PostgreSQL **ouvert à `PUBLIC`** sur
toute fonction neuve — alors que la base vivante, elle, venait d'être fermée.

**1. Pourquoi en dernier.** Un privilège par défaut ne touche aucun objet
existant. Le poser en tête ferait naître les 664 fonctions et les 254 tables avec
ces droits, puis la phase 70 ajouterait leurs `GRANT` exacts **sans retirer les
surnuméraires** : la base reconstruite serait *plus permissive* que la vraie.
Placée en fin, la phase ne change rien au monde qu'on vient de reconstruire et
règle seulement son comportement futur.

**2. Pourquoi « global » et « IN SCHEMA » sont deux choses distinctes.**
PostgreSQL stocke séparément l'entrée de niveau **rôle** (`FOR ROLE x`, sans
`IN SCHEMA`) et l'entrée **par schéma**, et les deux se **combinent**. Mesure :
le `EXECUTE` que PostgreSQL accorde nativement à `PUBLIC` sur toute fonction ne
se retire **que** par l'entrée globale — un `REVOKE … IN SCHEMA public … FROM
PUBLIC` est purement **inopérant**, il ne modifie même pas la ligne stockée. Les
aplatir produirait un rendu qui a l'air juste et qui ne ferme rien. Le rendu écrit
donc `(global)` et jamais la chaîne vide, y compris dans l'empreinte.

**3. Pourquoi `postgres` et `service_role` restent écrits.** Si l'on révoquait
tout jusqu'à ne laisser que le propriétaire, PostgreSQL **supprimerait** la ligne
de `pg_default_acl`, et l'ACL d'un objet neuf repasserait à `proacl = NULL` —
c'est-à-dire au défaut natif, `PUBLIC` compris. **Fermer trop rouvre.** Garder un
bénéficiaire non propriétaire est ce qui maintient l'entrée en vie.

**4. Pourquoi les révocations sont déduites et non lues.** Une ACL stockée
n'exprime que des `GRANT` : elle ne dit jamais « `PUBLIC` n'a rien », elle se
contente de ne pas le mentionner. La requête compare donc l'ACL stockée à
`acldefault()` et rend dans `revoque_du_natif` ce que le natif accorde et que
l'ACL ne contient pas. Un rendu fidèle aux seuls `GRANT` recréerait une base où
`PUBLIC` garde son `EXECUTE`.

**5. Pourquoi le rendu révoque *tout* avant d'accorder.** C'est le défaut que le
banc de reconstruction a attrapé, et il était grave. Un rendu qui se contenterait
d'accorder l'état canonique n'est pas **convergent** : appliqué sur une base dont
le défaut est *déjà* ouvert, il ne retire rien. Et c'est exactement le cas d'une
base Supabase **neuve**, qui porte `authenticated` dans ce même réglage — donc le
cas réel d'une reconstruction. Le banc l'a montré : parti d'un témoin ouvert, le
premier rendu laissait `{postgres, authenticated, service_role}`. Chaque entrée
commence donc par `REVOKE ALL` adressé à l'ensemble des rôles **observés dans
`pg_default_acl`** — un ensemble borné, dérivé de l'état capturé et non inventé,
qui s'élargit de lui-même si la plateforme introduit un rôle — puis accorde
l'état canonique. Éprouvé depuis un témoin ouvert à `PUBLIC`, `anon` *et*
`authenticated` : le résultat est exactement `{postgres, service_role}`.

**Ce qui est rendu, et ce qui est seulement inventorié.** Le rendu ne rejoue que
les entrées **administrables par le rôle de reconstruction** et de portée `public`
ou globale — le périmètre du baseline. Les entrées de `supabase_admin` et
`supabase_auth_admin` sont *observées* pour la fidélité d'inventaire mais jamais
rejouées : `postgres` n'est ni superuser ni membre de ces rôles, et la tentative
rend `permission denied to change default privileges`. Celles du schéma `storage`
sont administrables mais hors du périmètre reconstruit. Les deux cas sont **nommés
en commentaire** dans le fichier rendu, avec leur raison.

**Le contrôle.** `verifier-baseline.py` pose deux questions séparées : le baseline
*décrit*-il l'état du jour (compte et empreinte), et cet état est-il encore
*fail-closed* (`securite.defaut_fonctions_ferme_aux_clients`) ? Un baseline peut
être parfaitement fidèle à un état devenu permissif — le premier contrôle serait
vert et la porte ouverte. L'empreinte ne porte que sur les entrées administrables,
pour ne pas rougir au rythme de la plateforme.

## Arborescence

```
baseline/
  README.md                         ce fichier
  CONTROLE-GLOBAL.json              ce que la base dit, pour tout le schéma
  DIFFERENCES-DELIBEREES.json       toutes les divergences voulues, une par une
  INVENTAIRE.json                   récapitulatif du rendu, par domaine
  classification-donnees.csv        la classification du chantier 2C
  CLASSIFICATION.md                 sa version lisible, avec les arbitrages
  domaines/
    socle/  socle-PNJ/  assemblee/  banque/  communication/  divers-et-technique/
    economie/  finances-publiques/  immobilier-et-territoire/  justice/
    militaire/  personnage-et-presence/  politique-et-elections/
    postes-et-institutions/  presse/  renseignement/  sport/
      10_tables.sql       …         les fichiers de phase, générés
      80_commentaires.sql
      MANIFESTE.json                ce qui a été rendu
      CONTROLE.json                 (communication seulement : le pilote 2B)
  seeds/
    README.md  INVENTAIRE.json
    90_socle/  91_empire/  92_mixte/  95_a-regenerer/  99_a-construire/
  arbitrages/
    README.md
    dotations-initiales-republia.csv  .md    l'argent et les matières premières
    etat-initial-republia.csv         .md    les bâtiments, commerces, terrains
```

Un dossier par domaine, neuf fichiers de phase au plus : assez gros pour être lus
d'une traite, assez séparés pour qu'un `diff` reste parlant. Ni un fichier unique
de 2,7 Mo, ni des centaines de fichiers d'un objet chacun.

Un fichier de phase dépassant 150 000 caractères est découpé — `20_fonctions-1.sql`,
`-2.sql`… La découpe se fait sur les **blocs**, jamais sur le texte : un fichier ne
peut donc pas être coupé au milieu d'une fonction.

L'ordre de ces morceaux est **déclaré** dans `MANIFESTE.json`, clé `ordre`, et c'est
celui-là que lisent les outils. Jamais le tri des noms : au dixième morceau, `-10`
se trierait avant `-2` et la concaténation mélangerait le fichier.

Le domaine `socle` ne contient **aucune table** et c'est voulu : il porte les 42
fonctions primitives dont tous les autres domaines dépendent (`mon_personnage()`,
`est_appel_serveur()`, `acteur_present_sur_site()`…). Comme l'application se fait
par phase et non par domaine, la phase 20 du socle est appliquée avant la phase 60
de tous les autres.

Les fichiers `.sql` sont **générés** : ne pas les éditer à la main. Toute
correction passe par une migration appliquée à la base, puis par une nouvelle
extraction.

## Vérifier que le baseline est fidèle

    python3 outils/baseline/verifier-baseline.py     # tout le baseline
    python3 outils/baseline/verifier-monde-neuf.py   # ni bêta, ni vestige
    python3 outils/baseline/assembler.py             # l'assemblage, à vide
    python3 outils/baseline/verifier.py communication    # le domaine pilote 2B

Le contrôle global confronte trois sources, qui doivent concorder :
`CONTROLE-GLOBAL.json` (ce que la base dit), les `MANIFESTE.json` (ce qui a été
rendu), et les fichiers `.sql` eux-mêmes.

Il est découpé en **quatre familles qui échouent indépendamment** — structure,
logique serveur, sécurité, seeds. Les mélanger permettrait à une régression de
sécurité de passer derrière un total juste : une reconstruction peut être
structurellement parfaite et fonctionnellement ouverte.

Le contrôle le plus fort n'est pas un comptage : chaque définition de fonction est
**relue dans le fichier `.sql`**, réhachée, et confrontée à l'empreinte que la
base avait calculée sur `pg_get_functiondef`. Les corps de table le sont aussi.
C'est ce contrôle-là qui attrape une retouche à la main.

`assembler.py` rejoue l'assemblage **sans créer de base** : il vérifie que chaque
ordre trouverait, à sa phase, tout ce dont il dépend — clés étrangères, fonctions
de déclencheur, fonctions appelées par les policies, séquences des défauts — et
qu'aucun fichier ne référence un artefact hors baseline. Un objet qui échoue n'est
jamais supprimé pour faire passer le test.

## Dépendances externes d'un domaine

Elles sont déclarées dans `outils/baseline/domaines.json` et reprises dans le
`MANIFESTE.json` de chaque domaine. Un domaine n'aspire jamais silencieusement les
objets d'un autre : il dit de quoi il a besoin, et l'assemblage global y pourvoit.

Pour `communication`, ce sont quatre fonctions du socle — `mon_personnage()`,
`est_appel_serveur()`, `acteur_poste_courant()`, `rp_transition_active()` — et
cinq tables citées dans des corps `plpgsql`, qui ne bloquent pas la création
puisque ces corps ne sont pas validés à la création.

Hors du schéma `public`, le baseline dépend de deux objets seulement, tous deux
fournis par Supabase et donc jamais recréés : `auth.uid()` et `auth.users`. Ils
sont déclarés, pas absorbés.

## Ce que le baseline ne couvrira jamais

Les valeurs courantes des séquences, la mise en forme d'origine du SQL (les
contraintes, index, policies et vues sont réimprimés depuis l'arbre analysé), les
commentaires placés autour des objets dans les migrations, et tout ce qui vit hors
de la base : configuration Auth du projet, buckets Storage, crons Vercel,
variables d'environnement.
