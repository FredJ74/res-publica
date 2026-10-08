# Le circuit municipal de Républia — flux réel et plan de reprise

> **Audit statique du 8 octobre 2026.** Établi uniquement depuis le dépôt, le
> baseline et Git : l'instance Supabase était inaccessible (`SELECT 1` en
> timeout à ~50 s). **Aucun état live n'a été lu, et aucun n'est déduit du
> dépôt.** Tout chiffre de solde cité ailleurs dans ce document provient d'un
> relevé antérieur daté, et est signalé comme tel.

Ce document sert deux buts : figer le flux **actuel** avant d'y toucher, et
corriger le plan de reprise à la lumière de la règle de game design confirmée le
8 octobre.

---

## 1. La règle confirmée

> Les recettes fiscales municipales ne tombent **pas** progressivement pendant la
> journée. Elles sont calculées et créditées lors de la **MAJ de minuit**, et leur
> redistribution municipale intervient **dans cette même séquence**.
>
> Conséquence : il n'existe pas d'intervalle normal où les recettes du jour sont
> créditées à la mairie mais attendent encore leur redistribution. Donc **aucun
> mécanisme de réservation** n'est à construire.

---

## 2. Le flux réel, aujourd'hui

### 2.1 La séquence de minuit, dans l'ordre d'exécution

`api/cron-minuit.js`, dix-huit tâches sous `tacheQuotidienne()` plus deux appels
nus :

| # | Ligne | Étape | Effet municipal |
|---|---|---|---|
| 1 | 6039 | `souvenirs_accueil` | — |
| 2 | 6042 | **`taxe_fonciere`** | **crédite** `budgets_municipaux.data.caisse` |
| 3 | 6046 | **`preleverLoyersBaux()`** — *appel nu, sans `tacheQuotidienne`* | **crédite** la même clé pour les baux de destination `municipal` |
| 4 | 6052 | `traiterQuotidienNationalServeur('republic')` — *appel nu* | circuit **national** |
| 5–18 | 6083→6247 | blocus, transits, détentions, candidatures, renseignement, paye douane, paye police, livraisons, exportations, criée, production, effort de guerre, préemptions | — |

**La distribution municipale n'apparaît nulle part dans cette séquence.**
`grep -c 'distribuerBudgetMunicipal' api/cron-minuit.js` → **0**.

### 2.2 Où vit la distribution municipale

`plateau-politique.js:9338`, `distribuerBudgetMunicipalVersBatiments(pays, ville)`.
Un seul appelant dans tout le dépôt : `plateau-personnage.js:2310`, dans
`doDormir`.

Conséquences factuelles :

- une ville **sans joueur qui dort** ne distribue rien ; sa caisse s'accumule et
  ses équipements restent à sec ;
- la distribution ne concerne que la ville **où se trouve le joueur** ;
- la garde d'idempotence est un **champ de blob**,
  `data.derniereDistribJour`, perdable si une écriture est avalée. Le commentaire
  du dépôt l'assume : « deux navigateurs qui déclencheraient la distribution dans
  la même seconde passeraient tous deux la garde ».

### 2.3 Les trois canaux de recette municipale

| Canal | Quand | Chemin | Conforme à la règle ? |
|---|---|---|---|
| **Taxe foncière** | **minuit**, tâche 2 | `preleverTaxeFonciere` → `budgets_municipaux.data.caisse` | **oui** |
| **Loyers** `municipal` | **minuit**, étape 3 | `prelever_loyer_bail` (SQL) → même clé | **oui** |
| **Taxe locale sur les transactions** | **au fil de la journée** | `appliquer_taxe_transaction` (SQL), appelée par **cinq** fonctions : `acheter_produit_commerce`, `commerce_vendre_produit`, `recevoir_soin`, `alimenter_caisse_fonds`, `vente_structure_encaisser` | **non — continu** |

### 2.4 Ce qui ne va *pas* à la mairie

`RECETTES_FISCALES_JOUR_SERVEUR` (`api/cron-minuit.js:3786`) :

```js
const RECETTES_FISCALES_JOUR_SERVEUR = { republic: { capitale: 18000, ville_a: 2400, ville_b: 4200 } };
```

Ces 24 600 FR/jour sont la recette fiscale **déclarée** des trois villes, et elles
partent **intégralement au circuit national** (`budget_cascade_quotidienne`). Elles
ne touchent aucune caisse municipale. C'est une distinction qu'il faut avoir en
tête pour lire la règle : « les recettes fiscales municipales » ne désigne pas
cette constante.

### 2.5 Les deux magasins financiers

Rappel du diagnostic validé : `budgets_municipaux.data.caisse` est le **seul** à
encaisser, mais il est écrit en REST brut sur le blob entier depuis le
navigateur, sous la seule garde `acteur_identifie()` — ni poste, ni ville.
`caisses_batiments.<pays>_mairie_*` n'a **plus aucune recette** depuis que la clé
nationale a quitté les mairies, mais porte la seule dépense réelle : les salaires
des élus (maire 800 FR/jour, adjoint 500).

Arbitré : **`caisses_batiments` devient la trésorerie canonique.**

---

## 3. Confrontation : ce que la règle change au plan précédent

### 3.1 `recettesJour` n'est plus nécessaire sous la forme envisagée

Le plan préparé le 7 octobre introduisait `budgets_municipaux.data.recettesJour`
comme **compteur persistant** : chaque recette l'incrémentait pendant la journée,
et la cascade de minuit le lisait puis le remettait à zéro. C'était la seule façon
de distinguer « ce qui est arrivé aujourd'hui » de « la trésorerie accumulée »,
**dans l'hypothèse de recettes continues**.

La règle confirmée retire cette hypothèse pour les deux canaux de minuit. Si les
recettes municipales sont calculées *dans* la séquence de minuit, alors le cron
**connaît déjà le montant** qu'il vient de collecter : il peut le passer
directement à `budget_repartir` sans jamais le stocker.

**Conséquence : pas de compteur persistant, pas de remise à zéro, pas de
réservation.** L'assiette devient une variable locale de la passe de minuit, et
c'est tout. C'est plus simple et plus sûr : un compteur persistant est une donnée
de plus à maintenir cohérente, et un champ de blob perdable.

### 3.2 Ce que cela simplifie dans la migration préparée

| Section préparée le 7 octobre | Sort |
|---|---|
| **1–2** — entrepôts reçoivent une vraie caisse ; ancienne trésorerie municipale rejoint la caisse mairie | **conservée telle quelle** — indépendante de la règle |
| **3** — `recette_municipale(pays, ville, montant)` créditant la caisse **et** incrémentant `recettesJour` | **à refondre** : garder le crédit de la caisse mairie, **retirer** le compteur |
| **4** — déclaration 40/40/20 × 3 villes | **conservée telle quelle** |
| **5** — autorité territoriale dans `budget_repartition_fixer` | **conservée telle quelle** |
| `caisse` → `recettesJour` dans le blob | **abandonné** : la clé `caisse` est simplement **supprimée**, sans remplaçante |

Le renommage décidé le 7 octobre devient donc sans objet : il n'y a plus de clé
à nommer. La trésorerie part vers `caisses_batiments`, et `budgets_municipaux` ne
garde que de la **configuration** — `tauxLocal`, `tauxFoncier`, `indices`,
`allocation` (cette dernière devenant elle-même inutile, la répartition vivant
désormais dans `repartitions_budgetaires`).

### 3.3 L'idempotence devient gratuite

La distribution municipale passant par `budget_repartir`, elle hérite de la clé
primaire `repartitions_versements(pays, source, beneficiaire, jour)` : **un
second passage le même jour lève une violation d'unicité et ne verse rien.** Le
champ `derniereDistribJour`, marqueur de blob perdable, disparaît.

C'est exactement la forme que le projet a retenue au chantier 4F : la clé
primaire porte le jour, plutôt qu'un marqueur qu'une écriture avalée peut perdre.

---

## 4. Plan de reprise, quand Supabase revient

Dans cet ordre. Les étapes 0 à 2 sont des **lectures** ; rien n'est écrit avant
l'étape 4.

**0. Stabilité.** Les quatre sondes (`SELECT 1`, `list_migrations`,
`list_tables`, `SELECT 1`). Si une seule échoue ou ralentit : arrêt.

**1. Établir l'état réel.** Les trois entrepôts (forme du blob et montant de
`entrepot.caisse` via `batiment_etat_lire`), les quatre lignes de
`budgets_municipaux`, les trois caisses mairie, les trois caisses commissariat.
**Ne rien déduire : relever.**

**2. Empreintes financières d'avant.** La masse totale en trois postes —
`caisses_batiments`, `budgets_municipaux.data.caisse`, les blobs d'entrepôt — plus
une empreinte md5 de l'ensemble des soldes, pour comparaison après.

**3. Assertions préalables.** Vérifier que l'unique ligne hors ville
(`republic_caserne`) ne porte pas d'argent, et que les trois caisses mairie
existent.

**4. La migration groupée**, avec ses assertions internes :
 - les entrepôts reçoivent `<pays>_entrepot_<ville>` ;
 - la trésorerie de `budgets_municipaux` rejoint la caisse mairie, **une fois** ;
 - la clé `caisse` est supprimée ;
 - les cinq fonctions d'entrepôt pointent vers la caisse canonique ;
 - la déclaration 40/40/20 × 3 villes ;
 - l'autorité territoriale dans `budget_repartition_fixer` ;
 - la cascade municipale, appelée par le cron **après** la taxe foncière et les
   loyers, avec pour base ce que ces deux passes viennent de collecter ;
 - le versement partiel des salaires d'élus.

**5. Relecture immédiate** et comparaison des empreintes.

**6. Preuve de conservation** : la masse d'avant doit se retrouver exactement,
répartie autrement.

**7. Les trente preuves** du brief, puis les dix contrôles et les treize
invariants.

### Point d'insertion dans le cron

Après l'étape 3 (`preleverLoyersBaux`), avant ou après l'étape 4 (cascade
nationale) — indifférent, les deux circuits ne partagent aucune caisse. La
cascade municipale doit être enveloppée dans `tacheQuotidienne()` comme les
dix-huit autres.

**À corriger au passage** : `preleverLoyersBaux()` et
`traiterQuotidienNationalServeur()` sont appelées **nues**, sans
`tacheQuotidienne()`. C'est à vérifier avec l'audit du chantier 6 — elles portent
peut-être leur propre idempotence, mais elles échappent au marqueur commun.

---

## 5. Questions de GAME DESIGN à trancher — pour Fred

### Q1. La taxe locale sur les transactions entre-t-elle dans l'assiette redistribuée ?

C'est **la** question qui reste, et elle est structurante.

La taxe locale est créditée **au moment de chaque vente**, par cinq fonctions SQL.
Elle est donc, aujourd'hui, la seule recette municipale continue.

Deux lectures possibles :

**(a) Elle n'entre pas dans l'assiette.** Elle tombe dans la trésorerie de la
mairie et y reste ; seules la taxe foncière et les loyers, collectés à minuit,
sont redistribués en 40/40/20. Aucun mécanisme nouveau, aucune réservation,
aucune accumulation. **Cette lecture est cohérente avec la prémisse de la règle**
— « il n'existe pas d'intervalle où les recettes attendent leur redistribution » —
qui ne tient que si la taxe continue est hors assiette.

**(b) Elle entre dans l'assiette.** Il faut alors l'accumuler pendant la journée
pour la redistribuer à minuit — donc rétablir un compteur du type
`recettesJour`, et l'intervalle d'attente existe bel et bien (une vente à 14 h
attend minuit).

Je ne tranche pas : cela change ce que reçoivent le commissariat et l'entrepôt,
donc l'équilibre économique. Un mot de confirmation suffit — et si c'est **(a)**,
le plan ci-dessus s'applique tel quel.

### Q2. `allocation` dans `budgets_municipaux` : à supprimer ?

La clé `data.allocation` porte encore l'ancienne répartition à six catégories
(commissariat 20, multimodal 15, stade 15, marché 15, dispensaire 20, tribunal
15). Avec la répartition déclarée dans `repartitions_budgetaires`, elle devient
une seconde règle concurrente — exactement ce que les arbitrages précédents
interdisent.

Mais sa suppression retire du jeu le financement du **centre multimodal**, du
**stade**, du **marché** et du **dispensaire**, qui ne figurent pas dans le
40/40/20. Ces quatre équipements perdraient toute recette.

**Ce n'est pas une décision technique.** Soit ils rejoignent la répartition
déclarée comme bénéficiaires supplémentaires — et le 40/40/20 doit alors être
rebattu —, soit ils sont financés autrement, soit ils ne le sont plus. Je ne
choisis pas.

En attendant, la clé reste en place et inerte : elle ne sera plus lue dès que la
distribution passera par la brique générique.

---

## 6. Ce que cet audit n'a pas pu établir

- l'état réel des trois entrepôts (forme du blob et montant) — relevé interdit ;
- la masse financière actuelle — les chiffres du 7 octobre (1 218 FR côté
  `budgets_municipaux`, 118 849 FR côté caisses mairie) sont **datés** et doivent
  être remesurés avant toute migration ;
- si `preleverLoyersBaux` et `traiterQuotidienNationalServeur` portent leur propre
  idempotence — l'audit du chantier 6 le dira.

---

## 7. Réponses obtenues la nuit du 7 au 8 octobre, sans toucher à Supabase

### 7a. Oui, les deux appels hors registre portent leur idempotence — inégalement

Question laissée ouverte au §6, tranchée par
[`AUDIT-CHANTIER-6-IDEMPOTENCE.md`](AUDIT-CHANTIER-6-IDEMPOTENCE.md) :

- **`traiterQuotidienNationalServeur`** est le **meilleur** cas du cron. Son
  idempotence vit dans la clé primaire `repartitions_versements(pays, source,
  beneficiaire, jour)` : un second passage lève une violation d'unicité et ne
  verse rien. **C'est le patron que la distribution municipale doit copier**, et
  cela confirme le choix déjà fait au §4 — l'idempotence municipale vient
  gratuitement de la même clé, sans aucun marqueur à poser.
- **`preleverLoyersBaux`** est protégé **pour le débit** (verrou sur le bail,
  verrou sur le locataire, `jourPaiement` posé dans la transaction) mais **pas
  pour l'ardoise d'impayé** : la branche `expulsion_requise` est la seule des
  cinq sorties de la RPC qui ne pose pas le marqueur, et le JavaScript recalcule
  alors `jours + 1` et `montantDu + prix` à chaque passe. **La dette double.**

Conséquence directe pour ce chantier : **les loyers sont l'un des trois canaux de
recette municipale**, et le canal est sûr côté encaissement. Il n'y a rien à
corriger ici pour le circuit municipal ; l'ardoise relève du chantier 6.

### 7b. Corrigé cette nuit — l'écran de virement communal détruisait de l'argent

`plateau-justice-economie.js`, `confirmerFinancementCommunal` : le Maire Adjoint
débitait la caisse municipale, créditait le bâtiment **sans lire le verdict**, et
voyait « Virement effectué » dans tous les cas. Un crédit refusé — caisse
inconnue, autorité refusée, réseau coupé — faisait donc disparaître l'argent de
la commune sans qu'il arrive nulle part, en annonçant une réussite.

Corrigé en inversant l'ordre pour adopter celui du jumeau déjà corrigé
(`distribuerBudgetMunicipalVersBatiments`) : **crédit d'abord, sous verdict**,
puis débit de l'assiette, également vérifié. Trois états distincts sont désormais
dits : lecture impossible, crédit refusé (rien n'a bougé), et sauvegarde de
l'assiette refusée (annoncée, chiffrée, journalisée en anomalie).

Au passage, deux autres défauts du même écran : le `pays` ne traversait pas la
résolution du hub multimodal, et une catégorie absente devenait
`<option value="null">`, créditant `<pays>_null`. Détail dans
[`AUDIT-EMPIRES-4G.md`](AUDIT-EMPIRES-4G.md).

**Ce qui reste ouvert, et appartient à ce chantier :** la non-atomicité
elle-même. Elle ne se ferme pas côté navigateur. Elle se fermera **toute seule**
quand la trésorerie de la mairie sera une vraie caisse de `caisses_batiments` :
les deux écritures deviendront un seul mouvement transactionnel. C'est une raison
de plus de faire le chantier, pas une correction à inventer avant.

### 7c. (dépassée — voir §8c) Une question de game design nouvelle

`RECETTES_FISCALES_JOUR_SERVEUR` déclare pour Républia 24 600 FR/jour
(18 000 / 2 400 / 4 200), alors que la population déclarée conduirait à
**52 200 FR/jour** — et que la ventilation 18 000 / 2 400 / 4 200 **est celle
d'El Estado**. Le chiffre semble recopié d'un empire à l'autre.

**Cela concerne directement ce chantier** : la redistribution municipale va
s'asseoir sur les recettes du jour. Une assiette fausse donnerait trois caisses
municipales fausses, proprement réparties — ce qui est le pire des cas, parce que
rien ne le signalerait. Question posée en Q2 de
[`AUDIT-EMPIRES-4G.md`](AUDIT-EMPIRES-4G.md).

---

## 8. CHANTIER CLOS — 8 octobre 2026

Deux migrations appliquées, registre Supabase **20261008071350** et
**20261008072422**. Les dix contrôles du baseline sont verts.

### 8a. Le circuit, tel qu'il tourne maintenant

```
recette perçue  ─┬─► caisses_batiments.<pays>_mairie_<ville>   (L'ARGENT, immédiatement)
                 └─► recettes_municipales(pays, ville, jour, canal)   (LA MESURE, un compteur)

minuit, séquence serveur :
   taxe foncière ─┐
   loyers        ─┼─► recette_municipale()  ─► compteur du jour
   (taxe sur les transactions l'a alimenté en continu pendant la journée)
                  │
                  └─► budget_municipal_cascade('republic')
                        base = somme des lignes du jour
                        budget_repartir() ─► commissariat 40 % · entrepôt 40 %
                                           · mairie 20 % (journalisée, non transférée)
```

**La distinction qui porte tout le lot : une bourse n'est pas un compteur.**
`budgets_municipaux.data.caisse` était les deux à la fois — la trésorerie de la
commune *et* l'accumulateur de ce qui était arrivé depuis la dernière
distribution. C'est cette confusion qui avait produit la panne de septembre.
L'argent va désormais dans la trésorerie à l'instant où il est perçu ; ce qui
attend minuit est une **mesure**, qui ne porte pas un franc et dont le
`CHECK montant > 0` interdit structurellement qu'elle serve de bourse. Il
n'existe donc aucun intervalle où une recette municipale patiente quelque part.

**Il n'y a plus de navigateur dans la boucle.** `distribuerBudgetMunicipalVersBatiments`
et son déclenchement depuis `doDormir` sont supprimés. Une commune dont aucun
habitant ne dormait n'était jamais financée — six caisses de Port-Sainte-Marie et
de Montrouge ont porté le 19 septembre comme dernière écriture pendant dix-huit
jours. L'idempotence ne repose plus sur un champ de blob qu'une écriture avalée
peut perdre, mais sur la clé primaire de `repartitions_versements`.

### 8b. La conservation, mesurée avant et après

| | avant | après |
|---|---|---|
| masse des caisses | 1 223 164 | **1 239 635,5** |
| ancienne trésorerie municipale | 1 218 | 0 |
| trésorerie des 3 entrepôts réels (blob) | 15 253,5 | 0 |
| nombre de caisses | 147 | 150 |
| argent des personnages | 23 403 | 23 403 |

1 223 164 + 1 218 + 15 253,5 = **1 239 635,5 : écart 0,0 FR**, mesuré d'abord
dans une transaction annulée, puis constaté hors transaction après application.

Le demi-franc de Montrouge (4 927,5 FR) a traversé : **aucun arrondi n'a été
pratiqué**, parce qu'un `floor()` à la perception détruirait des centimes à
chaque recette et que la preuve de conservation ne serait plus exacte.

Les entrepôts de **test** (zzville-a, zzville-b, pays zztest) gardent leurs
99 706 FR dans leur blob, intacts. Ce ne sont pas des villes : on ne leur crée
pas de caisse, et surtout on ne leur retire pas la clé — retirer sans migrer
aurait détruit cet argent. C'est le piège que le join naïf sur
`entrepots_par_ville` tendait, cette table contenant deux villes de test.

### 8c. Deux défauts trouvés en chemin, qu'aucun contrôle ne voyait

**`entrepot_reverser` n'avait jamais pu fonctionner hors de la capitale.** Elle
dérivait la ville par `split_part(id, '_', 2)`, ce qui rend « ville » et non
« ville_a » — deux villes sur trois portent un souligné. La mairie destinataire
était donc introuvable depuis la création de la fonction, le 20 septembre 2026.
Personne ne l'avait vu parce qu'**aucun appelant ne l'invoquait** : le défaut
dormait derrière l'absence d'interface, laquelle est posée dans ce même lot. La
règle de nommage vit désormais dans `entrepot_caisse_id()`, qui lit les colonnes
`country` et `city` — elles font autorité, et aucune heuristique de chaîne ne
peut les contredire.

**Un second moteur de taxe vivait dans le navigateur.** `appliquerTaxeTransaction`
(client) lisait les deux taux, calculait les deux parts, et écrivait elle-même
`budgets_municipaux.data.caisse` et `budgets_nationaux.data.reserveJour`. Depuis
la suppression de la clé `caisse`, elle l'aurait **recréée avec la taxe locale
dedans** : de la création monétaire, à chaque vente. Elle est supprimée, et ses
deux derniers appelants — chambre d'hôtel et buvette — ne l'atteignaient que par
un chemin de repli qui refuse désormais l'opération au lieu de prélever.

Même famille, côté cron : l'approvisionnement de chantier écrivait
`caisse: (blob.caisse || 0) + depense`, donc aurait recréé la clé avec la dépense
dedans ; et la passe de livraisons repliait sur `{ caisse: 8500 }`, c'est-à-dire
**fabriquait 8 500 FR** chaque fois que le blob n'avait pas la clé. Les deux
passent par `entrepot_caisse_mouvement`, en delta et non en valeur absolue.

### 8d. Ce que les quatre équipements perdent, et où ils le retrouvent

L'ancienne clé `allocation` finançait six bénéficiaires : commissariat 20,
multimodal 15, stade 15, marché 15, dispensaire 20, tribunal 15. Le tribunal
était un **doublon** — le Ministère de la Justice le finance depuis le chantier
4F, à un tiers chacun. Les quatre autres passent d'un financement **récurrent
automatique** à un financement **discrétionnaire par le maire**, depuis les 20 %
qu'il conserve : l'écran « Financer un bâtiment communal » existe déjà et propose
exactement ces catégories, et il est devenu atomique dans ce lot
(`mairie_virement_batiment`). Ce n'est donc pas une suppression de financement,
c'est un déplacement de la décision vers l'élu.

Le **soutien municipal ad hoc** de l'entrepôt par sa ville est supprimé pour la
même raison : c'était une seconde règle de financement, décidée par le cron et
invisible du maire, concurrente des 40 % déclarés.

### 8e. Aucun arbitrage de game design n'a été nécessaire

La question « la taxe sur les transactions appartient-elle à l'assiette
municipale ? » s'est tranchée **par les faits** : son taux s'appelle `tauxLocal`,
il est stocké dans le budget municipal, il est fixé par le maire, son produit
allait à la bourse municipale, et cette bourse était intégralement redistribuée.
La symétrie avec `tauxNational` → `reserveJour` → cascade nationale est complète
et délibérée — la migration du 16 septembre 2026 l'écrit noir sur blanc. Ce lot
**conserve** ce fait au lieu de le trancher à nouveau.

Les trois caisses `*_centre-multinodal-luthecia` des autres empires sont
diagnostiquées et **laissées intactes** : créées par la dotation d'amorçage du
11 septembre 2026 à 15 h 57 (même horodatage que toutes les autres caisses à
200 FR), jamais touchées depuis, 200 FR chacune, et sans rapport avec le circuit
municipal — `getBuildingIdCentreMultimodal('capitale')` rend
`centre-multinodal-luthecia` pour tous les empires, le commentaire du code
qualifiant ce hub de « partagé ». Elles ne bloquent rien.
