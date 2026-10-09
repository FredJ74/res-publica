# Arbitrages et audits

Ce répertoire porte deux genres de documents qu'il ne faut pas confondre : des
**tableaux d'arbitrage**, qui attendent des valeurs de game design, et des
**audits**, qui établissent ce que le code fait réellement avant qu'on le
change.

## Les audits — ce que le code fait aujourd'hui

À lire **avant** de toucher au domaine correspondant. Chacun sépare
explicitement ce qui est une décision technique (prise dans le document) de ce
qui est une décision de game design (posée en question, jamais inventée).

| Fichier | Domaine | Ce qu'il établit |
|---|---|---|
| `AUDIT-FISCAL.md` | fiscalité | **le circuit fiscal réellement exécuté**, et les verdicts techniques sur chaque doublon de caisse. À lire avant de chiffrer |
| `AUDIT-MUNICIPAL.md` | budgets municipaux | le circuit municipal réel, la séquence de minuit, les trois canaux de recette, et le plan de reprise du chantier |
| `AUDIT-CRON-MINUIT.md` | chantier 6 | cartographie de la passe de minuit et découpage proposé. **Trois affirmations corrigées le 8 octobre** |
| `AUDIT-CHANTIER-6-IDEMPOTENCE.md` | chantier 6 | ce qui rejoue, par **coût d'un rejeu** ; la brique `actes_nocturnes` ; ce qu'il ne faut **pas** toucher |
| `AUDIT-CHANTIER-5-FAIL-SILENT.md` | chantier 5 | 1 335 avaleurs d'erreur, dont **813** pertinents et **19** interventions qui couvrent tout l'argent |
| `AUDIT-CHANTIER-5-ECRITURES-PLATEAU.md` | chantier 5 | les **396 écritures** de `plateau-*.js`, croisées sensibilité × traitement de l'échec : **156 sensibles avalées**, 20 chaînes sur plusieurs tables sans atomicité, et l'ordre d'attaque. **À lire avant de toucher un `plateau-*.js`** |
| `AUDIT-DISK-IO.md` | performance | suspects classés A/B/C, avec **la requête de mesure** de chacun. Aucune optimisation avant mesure |
| `AUDIT-EMPIRES-4G.md` | chantier 4G | ce qui est déjà fail-closed hors Républia, et les trois questions de game design qui bloquent le reste |
| `AUDIT-FALLBACKS-REPUBLIC.md` | chantier 4G | les **287 replis implicites** vers Républia, classés A–E — et pourquoi 253 d'entre eux se corrigent par **deux gardes à la racine** |
| `AUDIT-PERFORMANCE-MESUREE.md` | performance | ce que la base mesure, sur 4,5 mois : le suspect « index absents » est **infondé** (tables de 8 lignes), le vrai sujet est la **fréquence des sondages** et les 81 436 `UPDATE` de `personnages_donnees` |
| `AUDIT-PAYLOAD-VERCEL.md` | infrastructure | ce qu'un déploiement transporte vraiment : **400,2 → 310,0 Mo**, les assets classés A–F, et les 75,9 Mo de PNG que **la base** empêche de récupérer |

## Les tableaux d'arbitrage de l'état initial

Onze tables du baseline attendent des **valeurs**, pas une méthode. Ces tableaux
existent pour qu'elles se remplissent une fois, à plat, sans avoir à comprendre
le schéma SQL.

| Fichier | Lignes | Ce qu'on y décide |
|---|---|---|
| `dotations-financieres-republia` | 80 | **les caisses et budgets, aucune matière** |
| `dotations-initiales-republia` | 98 | l'argent **et** les matières premières — le tableau complet |
| `etat-initial-republia` | 80 | les bâtiments, les commerces, les terrains |

Chacun existe en `.csv` (séparateur `;`, à ouvrir dans un tableur) et en `.md`
(à lire).

Le **sous-tableau financier** est le tableau de travail : il extrait du tableau
complet les seules caisses et budgets, regroupés par famille, avec pour chaque
ligne un verdict sur l'opportunité même de la doter. Le tableau complet reste la
référence exhaustive.

## La frontière, posée exprès

Pour que rien ne tombe entre les tableaux :

- **tableau 1** : `caisses_batiments`, `budgets_nationaux`, `budgets_municipaux`,
  `budgets_clubs`, et les stocks de matières premières — entrepôts de ville,
  caserne, armurerie nationale ;
- **tableau 2** : `batiments_etat`, `entreprises`, `terrains_etat`, **y compris
  les caisses qui vivent dans leur blob**, parce qu'elles font partie de l'état
  initial du lieu et non d'une dotation institutionnelle.

## Ce que ces tableaux ne font jamais

- proposer un montant déduit d'un **solde de bêta** ;
- proposer un montant déduit du journal `dotations_amorcage_caisses`, qui dit ce
  qui *a été* versé et non ce qui *doit* l'être ;
- inventer une catégorie qui n'existe pas dans le modèle réel — un identifiant
  que la nomenclature ne reconnaît pas sort en « à qualifier » plutôt qu'en
  catégorie fausse.

La colonne de valeur actuelle est **informative** : elle sert à reconnaître le
lieu, pas à suggérer une réponse.

## Ce qui est déjà prérempli

**Les 17 dotations de matières premières**, arbitrées le 5 octobre 2026,
identiques dans chacune des trois villes : bois 750, minerai 500, charbon 400,
plantes 300, métal 200, pétrole 200, fruits et légumes 150, poisson 125,
textile 125, produits exotiques 125, alcool 100, viande 85, céréales 75,
désinfectant 32, tabac 30, médicaments 25, carburant 17.

Treize d'entre elles étaient déjà identiques sur les trois entrepôts et sont
confirmées telles quelles ; quatre — tabac, viande, céréales, médicaments —
avaient dérivé différemment selon la ville et reçoivent une valeur de référence.
**Aucune n'est déduite d'un stock de bêta.**

**La caisse du ministère de la Défense** : `republic_gouvernement-min_def` =
**35 000 FR**. Le ministre transfère ensuite lui-même vers la caserne ; la
création d'une compagnie coûte 20 000 FR.

## Ce que le verdict de chaque ligne financière veut dire

| | Lignes | Sens |
|---|---|---|
| **chiffrées** | **53** | dotation décidée — 147 400 FR au total |
| **à 0, délibérément** | **24** | vestige daté, compte de transit, contrepartie, caisse inerte, caisse alimentée par une autre, ou taux |
| **isolées** | **3** | les clubs de football : conséquence de jeu réellement différente, aucun montant proposé |

**Plus aucune ligne « à clarifier ».** La première version du tableau en comptait
36 ; l'audit du circuit fiscal les a toutes tranchées par lecture du code. Chaque
verdict « ne pas doter » cite la fonction, le commentaire de correctif ou la
ligne de cron qui l'établit.

## La règle canonique des dotations

Trois niveaux, et une seule exception.

| Montant | Caisses | Pourquoi |
|---|---|---|
| **35 000 FR** | Défense | un monde neuf n'a ni compagnie ni section ; créer une compagnie coûte 20 000 FR |
| **10 000 FR** | les 6 autres ministères, le Premier ministre, la Présidence | dotations politiques d'amorçage |
| **5 000 FR** | Assemblée, les 3 mairies, les 3 entrepôts | les mairies financent désormais les équipements municipaux et doivent amorcer leur première distribution ; les entrepôts amorcent la chaîne économique |
| **200 FR** | les 37 caisses d'équipement | **plancher d'amorçage** |
| **0 FR** | Grobras Sécurité | ne vend que de la prestation : aucun stock à financer |

Le **plancher de 200 FR** n'est pas un chiffre inventé : c'est exactement celui
que le projet s'est donné le 11 septembre 2026, quand le journal d'amorçage a
porté 103 caisses à 200 FR. Une caisse d'équipement n'a pas besoin d'une
réserve — il lui faut exister et ne pas être à zéro le premier jour. Son circuit
l'alimente ensuite : répartition nocturne, distribution municipale, ou sa propre
activité.

> **Arbitrage du 8 octobre 2026 — quatre équipements n'ont que la première.** Le
> centre multimodal, le stade, le marché et le dispensaire reçoivent cette
> dotation de départ, puis **aucun financement municipal récurrent** : ils
> doivent s'autofinancer par leurs propres recettes. La répartition municipale
> automatique ne connaît que trois bénéficiaires — commissariat 40 %, entrepôt
> municipal 40 %, mairie 20 % — et le maire n'a aucune obligation envers eux. Un
> virement ponctuel reste possible, et reste **distinct** de leur financement
> structurel.

**Les trois clubs sont isolés, et c'est volontaire.** 200 FR y seraient
trompeurs : un club paie 100 FR par titulaire, 50 par remplaçant et 150 de prime
de victoire — 200 FR ne couvrent pas une rencontre. Et l'audit a établi que la
subvention municipale aux clubs lit une clé qui n'existe pas, donc vaut toujours
0 : un club n'a **aucune** recette automatique aujourd'hui. Appliquer le plancher
créerait trois clubs insolvables dès la première journée de championnat.

> **Au 8 octobre 2026, cette clé n'existe plus du tout** : `allocation` a été
> supprimée avec le chantier des budgets municipaux, et le montant est désormais
> explicitement nul dans le code, avec sa raison écrite. Subventionner les clubs
> serait une ligne de `repartitions_budgetaires` décidée par le maire — donc un
> arbitrage, pas un correctif. Le constat sur leur insolvabilité tient inchangé.

## Ce que l'observation apporte à la décision

Deux signaux sont inscrits dans les remarques, parce qu'ils font gagner du temps :

**Une valeur identique sur les trois villes est un indice fort qu'elle est
d'origine.** Treize des dix-sept matières premières étaient encore au même niveau
dans les trois entrepôts — c'est ce qui a permis de les confirmer directement. Les
quatre autres (`tabac`, `viande`, `cereales`, `medicaments`) avaient divergé : leur
valeur d'origine n'y était plus lisible, et elle a donc été fixée par décision.

**Une valeur authored clairement identifiable est proposée, pas imposée.** La
surface d'un terrain, son autorisation de construire, le prix de vente directe
d'une usine : ces valeurs ressemblent à du contenu écrit, elles sont donc
reportées dans la colonne de proposition — à confirmer, pas à redéfinir.

## Correction de périmètre

Le rapport 2E annonçait « 38 bâtiments, 20 commerces, 5 terrains ». C'étaient des
**comptes de lignes**, tous empires et lignes techniques confondus. Le périmètre
réel de Républia est :

- **14 bâtiments** porteurs d'un état dans les trois villes ;
- **14 commerces** authored ;
- **4 terrains**, tous à Luthécia.

Les lignes écartées sont **nommées** en fin de chaque tableau, avec leur raison.
Elles existent toujours en base : il n'y a rien à arbitrer pour elles, mais rien
n'est écarté en silence.

## Reproduire ces tableaux

```
python3 outils/baseline/arbitrages.py --sql              # imprime la requête
python3 outils/baseline/arbitrages.py --rendre <resultat>
```

La requête d'extraction est dans le dépôt, relisible et rejouable. Elle ne
contient que des `SELECT`.
