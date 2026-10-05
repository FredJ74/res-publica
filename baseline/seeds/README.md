# Seeds du baseline — le contenu avec lequel un monde naît

Le schéma dit **comment** le monde est fait ; les seeds disent **avec quoi** il
naît. Les deux ne se mélangent jamais : la structure vit dans
`baseline/domaines/`, le contenu initial vit ici.

Tout ce qui est rangé dans ce répertoire vient de la classification du chantier
2C (`baseline/classification-donnees.csv`). Ce répertoire **applique** cette
classification, il ne la refait pas.

## Deux principes qui ne se négocient pas

**1. Aucune donnée inventée.** Un TODO explicite vaut mieux qu'un faux état
initial reconstruit depuis la bêta. Quinze tables sur soixante-seize portent
donc un fichier sans la moindre ligne de données : ce n'est pas un travail
inachevé, c'est le refus d'écrire quelque chose de faux.

**2. Aucun artefact de bêta.** Les lignes de test, les identifiants engendrés
en cours de partie et les horodatages de la bêta ne traversent pas. Chaque
exclusion est nommée dans `baseline/DIFFERENCES-DELIBEREES.json` et vérifiée
par `outils/baseline/verifier-baseline.py`.

## Les cinq répertoires

| Répertoire | Catégorie 2C | Tables | Lignes | Ce que c'est |
|---|---|---|---|---|
| `90_socle/` | A | 28 | 321 | Socle générique. Identique pour tout empire, présent ou à venir. |
| `91_empire/` | B | 21 | 170 | Contenu initial d'empire. Le casting, pas la mécanique. |
| `92_mixte/` | D | 12 | 362 | Une part socle, une part empire. L'en-tête de chaque fichier dit laquelle est laquelle. |
| `95_a-regenerer/` | — | 4 | 0 | Miroirs d'une source du dépôt. Leur seed se **régénère** depuis `data.js` ; il ne se copie jamais depuis la base. |
| `99_a-construire/` | — | 11 | 0 | L'état initial voulu n'existe nulle part. Le fichier dit précisément ce qu'il faut décider, et ce qu'il ne faut surtout pas faire. |

76 tables au total : c'est exactement la surface de seed de la classification.
Les 170 tables classées `structure_seule` n'ont, et ne doivent avoir, aucun
fichier ici — un seed sur une table d'état vivant ferait naître un monde avec
de la bêta dedans. Les 6 tables `hors_baseline` non plus.

Les arbitrages du 5 octobre 2026 ont fait sortir quatre tables de cette surface
— `pnj_membres`, `pnj_soldats_metier`, `pnj_possessions`,
`compagnies_militaires` — parce que leur contenu est **engendré par les
mécanismes du jeu**, pas posé par un seed. Et ils y ont fait entrer
`indices_villes`, dont les valeurs sont désormais décidées.

## Les montants et les états initiaux restants

Onze tables de `99_a-construire/` attendent des valeurs, pas une méthode. Ces
valeurs se remplissent dans deux tableaux préparés pour cela :

- `../arbitrages/dotations-initiales-republia.csv` — l'argent et les matières
  premières, 106 lignes ;
- `../arbitrages/etat-initial-republia.csv` — les bâtiments, commerces et
  terrains, 80 lignes.

Une seule valeur y est déjà inscrite, parce qu'elle est arbitrée : la caisse du
ministère de la Défense de Républia, 35 000 FR.

## Onze miroirs seedés par copie — à arbitrer

Onze tables de `90_socle/`, `91_empire/` et `92_mixte/` sont en réalité des
**miroirs de `data.js`**, et un générateur existe déjà dans le dépôt pour
chacune. Leur seed a été produit **par copie de la base**, conformément à la
stratégie `seed_complet` validée au chantier 2C : 2E applique la
classification, il ne la refait pas de son propre chef.

Mais copier un miroir fige sa dérive, et l'un d'eux a déjà dérivé : le miroir
des coûts d'ordre portait 24 lignes mortes et 19 ordres gratuits non déclarés au
5 octobre 2026. Chaque fichier concerné porte donc un avertissement en en-tête.

La liste et les générateurs sont dans `../DIFFERENCES-DELIBEREES.json`. La
recommandation est de faire écrire ces onze fichiers par leurs générateurs et de
les déplacer dans `95_a-regenerer/` — et au passage de sortir ces générateurs de
`.scratch/`, qui n'est pas un endroit pour un outil dont le projet dépend.

## Ordre d'application

Les seeds s'appliquent **après** toutes les phases de structure (10 à 80), et
dans l'ordre des répertoires : `90`, puis `91`, puis `92`. Les répertoires `95`
et `99` ne contiennent rien à appliquer aujourd'hui.

Deux points relevés par le test d'assemblage statique
(`outils/baseline/assembler.py`), tous deux vérifiés :

- `journaux.cree_par` est une clé étrangère vers `personnages_donnees`, qui
  n'est jamais seedée. Les 4 lignes seedées portent `NULL` dans cette colonne :
  le seed passe. C'est vérifié, pas supposé.
- une seule table porte une clé étrangère sur elle-même ; l'ordre des lignes à
  l'intérieur de son fichier compte, et il est déterministe (tri par clé
  primaire).

## Comment les fichiers sont produits

```
python3 outils/baseline/seeds.py --sql    <repertoire_des_exports>   # imprime le SQL
python3 outils/baseline/seeds.py --rendre <repertoire_des_exports> <resultat>
```

C'est **PostgreSQL** qui écrit les littéraux, via `quote_nullable`. Aucune règle
d'échappement n'est réimplémentée en Python : c'est la seule façon d'être sûr
qu'un apostrophe dans « L'Autruche Entravée » ou un `jsonb` imbriqué ressortent
intacts.

Chaque valeur est émise comme un littéral texte, que PostgreSQL convertit au
type de la colonne à l'insertion. `NULL` reste `NULL`, non quoté.

### Les règles appliquées, et pourquoi

**Colonnes d'horodatage omises.** Une colonne `timestamp` dont le défaut est
`now()` n'est pas écrite. La date de création d'une ligne n'est pas du contenu
écrit par un auteur : c'est le jour où le monde est né. L'omettre laisse le
défaut jouer. Les sept colonnes concernées sont listées dans
`DIFFERENCES-DELIBEREES.json`. Une colonne d'horodatage **sans** défaut
apparaîtrait dans le rendu et exigerait une décision explicite.

**Séquences recalées.** Une table dont la clé est sérielle reçoit, à la fin de
son fichier, un `setval`. Sans lui, le premier `INSERT` applicatif entrerait en
collision avec un identifiant seedé.

**État vivant remis à l'état initial.** Un seul cas aujourd'hui :
`assemblee_sieges`, dont les colonnes `endormi` / `endormi_ts` / `endormi_par`
décrivent un PJ ayant neutralisé le député Gamma. La justification complète est
dans l'en-tête du fichier.

## Ce que le contrôle vérifie

`python3 outils/baseline/verifier-baseline.py`, famille 4 :

1. les 76 tables de la surface de seed ont toutes un fichier ;
2. aucune table hors de cette surface n'en a un ;
3. les fichiers `95` et `99` ne contiennent aucune donnée ;
4. le nombre de lignes seedées par table égale le nombre de lignes en base,
   **moins les exclusions déclarées** — une ligne qui disparaît sans être
   déclarée fait échouer le contrôle ;
5. chaque fichier est conforme à son empreinte.
