# Chantier 7 — les fonctions recopiées

> **Lot 1, 10 octobre 2026.** Aucune migration : ce chantier ne touche pas la
> base. Le baseline est donc inchangé, et c'est normal — il décrit un schéma, et
> le sujet d'ici vit entièrement dans le dépôt.
>
> **Les 11 contrôles sont verts** (c'était 10 : celui des fonctions est né dans ce
> lot) et **les 13 invariants d'autorité tiennent**.

## Pourquoi ce chantier, et pourquoi c'est lui qui vient après les 5 et 6

Il n'a pas été choisi : il était **écrit**. Le chantier 4B a fermé l'axe des
données — les constantes que `api/` ressaisissait à la main sont générées depuis
leur canon — et il a nommé lui-même ce qu'il laissait ouvert, à trois endroits de
`api/cron-minuit.js`, mot pour mot :

> AUCUN TEST NE LE VERIFIE AUJOURD'HUI -- constate le 6 octobre 2026 : le test
> annonce n'existe nulle part dans le depot. **La duplication de FONCTIONS est
> inventoriee et reportee au chantier 7** ; le 4B n'a traite que les donnees.

Et `outils/generateurs/referentiels-serveur.json` déclare la même chose dans sa
clé `_etiquettes_de_lot` : « *« chantier 7 » pour les fonctions recopiées* ».
C'est la seule étiquette de lot numérotée qui n'était pas encore ouverte.

**Le défaut, dit en une phrase.** Quarante-deux formules de jeu existent en deux
exemplaires — une au navigateur, qui est le canon, une dans un module de `api/`,
parce qu'un module serverless ne peut pas charger un script de navigateur. Deux
implémentations d'une même règle divergent toujours un jour. Et quand c'est celle
du cron qui dérive, elle dérive **la nuit, toute seule, sur de l'argent**, sans
que personne regarde.

## Méthode, pour qu'elle soit rejouable

```
python3 outils/baseline/verifier-fonctions.py          # le verdict
python3 outils/baseline/verifier-fonctions.py --poser  # les empreintes
python3 outils/bancs/lancer-banc.py outils/bancs/banc-urbanisme-nature-refusee.js
```

L'inventaire n'est pas une liste relue à l'œil : il est **mesuré**. Toute fonction
déclarée au premier niveau d'un module de `api/` dont le nom de base existe aussi
dans un fichier du navigateur est une copie candidate, et le contrôle refait ce
relevé **à chaque passage**. Une copie neuve non déclarée le fait échouer le jour
de sa naissance.

Ce relevé automatique ne suffit pas, et il faut le savoir : **neuf copies ont un
canon qui ne porte pas le même nom** — `capaciteHeuresJourServeur` répond à
`capaciteHeuresJourChantier`, `terrainSuspenduServeur` à
`terrainSuspenduAdministrativement`, `traiterDesertionsServeur` à
`verifierDesertionsQuotidien`. Celles-là sont déclarées à la main, après lecture
des commentaires qui les avouent. Le relevé automatique garantit qu'aucune copie
**homonyme** n'échappe à la déclaration ; il ne peut pas garantir qu'aucune copie
**renommée** n'y échappe, et ce fichier le dit plutôt que de le laisser croire.

### Ce qui a rendu la mesure possible, et qui la bloquait depuis le début

Les deux côtés **ne peuvent pas être chargés ensemble tels quels**. `data.js` et
`api/cron-minuit.js` déclarent tous deux `const RESSOURCES_ECONOMIE`,
`plateau-politique.js` et le cron tous deux `const FUSEAU_ELECTORAL`,
`supabase.js` et le cron tous deux `const SUPABASE_URL` — et JavaScript refuse la
redéclaration d'un `const`. Le chargement échoue sur la première, avant la
première comparaison. C'est probablement ce qui a fait reporter ce test cinq fois.

La réponse est une **portée isolée** : le module serveur est chargé *dans une
fonction* qui n'expose que les symboles déclarés. Il n'est ni transformé, ni
réécrit, ni recopié — c'est le fichier que Vercel déploie, exécuté à côté du vrai
code du jeu. Même doctrine que `banc-chantier-progression-serveur.js` au
chantier 5, étendue à tout l'inventaire.

Un décor minimal remplace ce que `jsc` ne fournit pas (`document` inerte,
`process.env` vide, `state` au minimum). **Il est volontairement pauvre** : une
fonction qui aurait besoin de davantage pour calculer n'est pas une fonction pure,
et sa place est dans les épinglées.

## 1. L'inventaire, en chiffres

| | Copies |
|---|---|
| détectées automatiquement (nom de base commun aux deux côtés) | **67** |
| écartées, nommées une par une — la couche d'accès PostgREST | 21 |
| détectées et déclarées | 46 |
| déclarées **à la main**, parce que leur canon porte un autre nom | 9 |
| détectées, ni déclarées ni écartées | **0** |
| **déclarées et surveillées** | **55** |
| dont **comparées** : exécutées des deux côtés | **42** |
| dont **divergence déclarée** : écart voulu, étendue surveillée | 3 |
| dont **homonymes** : même nom, question différente | 3 |
| dont **épinglées** : font des entrées-sorties, surveillées par empreinte | 7 |
| **cas exécutés des deux côtés** | **1 870** |

Les 21 écartées sont `sbGet` / `sbInsert` / `sbUpdate` / `sbRpc` et leurs
variantes, redéclarées dans cinq modules de `api/`. **Elles ne calculent rien,
elles transportent** : les comparer n'apprendrait rien. Leur mutualisation a déjà
commencé ailleurs — `api/_supabase.js` a absorbé la configuration qui était
recopiée neuf fois — et c'est un chantier d'architecture, pas de concordance.
Elles sont nommées **une par une**, et le contrôle échoue si l'une disparaît : une
liste d'exclusions qui pourrit est pire que pas de liste.

## 2. Le résultat principal : les formules ne divergent pas

**Sur 42 copies exécutées des deux côtés et 1 870 cas, aucune divergence.** Y
compris sur tout ce qui porte de l'argent ou du temps :

| Famille | Ce qui est prouvé identique |
|---|---|
| chantiers | la progression maximale financée, le reliquat payé aux ouvriers PNJ, le panier de matériaux du jour, l'approvisionnement, le verrou des deux tiers, la livraison des lots |
| urbanisme | le délai d'instruction, l'achèvement, le verdict d'accord tacite, le document archivé |
| élections | le calendrier du dimanche, les scores de base, **le dépouillement** (un siège et plusieurs), le départage, l'effet des tracts, la construction d'un cycle |
| militaire | les PA d'un lot, **le coût de revient facturé au Ministère de la Défense** |
| économie | le prix de vente directe d'une usine, le palier d'une grève |
| gouvernement | le plafond absolu d'un régime d'exception |

Les grilles encadrent les seuils **à la case près** : des durées de 6 jours (tiers
exacts) *et* de 7 (tiers non représentables en binaire), des fractions de
financement à 0,34 / 0,35 / 0,70 / 0,71, des permis échus d'un jour ou pas encore,
des stocks juste au-dessus et juste au-dessous du besoin, les deux heures de
changement d'heure qui n'existent pas ou existent deux fois, un 29 février.
C'est là que deux implémentations d'une même règle se séparent.

> **Ce résultat ne dit pas que la duplication était inoffensive.** Il dit qu'elle
> n'avait pas encore nui, et que **personne ne le savait** — c'est très
> exactement ce que les trois aveux du cron disaient. Ces trois aveux sont
> maintenant faux : les formules qu'ils désignaient sont comparées à chaque
> passage du contrôle.

### Quatre affirmations du dépôt vérifiées par la mesure, dont trois tenaient

- `POSTES_ELECTIFS_LOCAUX = ['maire','depute']` est écrit en dur au serveur là où
  le canon déduit la liste de `POSTES_ELECTIFS` par `niveau === 'ville'`. Mesuré :
  le canon rend `["depute","maire"]`, même ensemble. L'ordre diffère et il est
  sans effet — le seul lecteur fait un `indexOf`.
- `coutRevientLotMilitaireServeur` lit le prix de base du référentiel quand son
  canon appelle `getPrixRessourceEntrepot`. **J'ai d'abord cru à une divergence
  sur de l'argent** : le prix de marché varie de ±40 % avec le stock. Lecture
  faite, `getPrixRessourceEntrepot` rend `Math.round(prixBase * 100) / 100` — donc
  exactement le prix de base. Il n'y a pas de divergence, et l'hypothèse était
  fausse.
- le blob d'indices par défaut du serveur est écrit en littéral dans le cron ;
  comparé valeur par valeur à `INDICE_VILLE_DEFAUT`, il est identique.
- `DELAI_CONVOCATION_MS` et `DELAI_CONVOCATION_MS_SUCCESSION` : deux noms, dix
  jours des deux côtés.

## 3. Ce que ce lot a trouvé et fermé

### 3.1 Deux chemins d'argent non atomiques, sans aucun appelant — supprimés

`crediterCaisseBatimentServeur` et `debiterCaisseBatimentPlafonneServeur`
faisaient chacune une **lecture-modification-écriture d'une caisse de bâtiment**
depuis le cron, sans transaction. Leurs équivalents clients, eux, passent par une
RPC (`sbCaisseInstitutionMouvement`). Elles étaient les auxiliaires de la
répartition territoriale au prorata fiscal, **retirée au chantier 4F le 7 octobre**
— et restées là après elle.

Vérifié avant de supprimer : `grep -rn` sur tout le dépôt, `.git` et
`node_modules` exclus, rend **une seule occurrence chacune — leur propre
déclaration**. Zéro appelant.

> Un chemin d'argent non atomique sans appelant est **un piège en attente d'un
> appelant** — c'est le mot que le dépôt emploie déjà pour la table des niveaux de
> construction, et il vaut ici.

### 3.2 Un commentaire qui affirmait un usage inexistant — rectifié

Les lignes qui précédaient ces deux fonctions disaient :

> Ce qui subsiste de cette nuit-la : villesDeServeur **et caisseTerritorialeServeur,
> employes par les greves et les armureries**.

C'est faux. `caisseTerritorialeServeur` **n'a aucun appelant** dans le dépôt. Un
commentaire qui affirme un usage inexistant est plus trompeur qu'une absence de
commentaire : il décourage exactement la vérification qui l'aurait démenti. Le
commentaire est rectifié, et la fonction **n'est pas supprimée** — elle est le seul
lecteur du référentiel généré `CAISSES_LEGACY_SERVEUR`, et la retirer demande de
retirer aussi sa génération, ce qui relève du chantier des référentiels.

### 3.3 Un miroir volontairement resserré qui aurait écrit un libellé faux — fermé

`libelleAccordTaciteServeur` rend « *Accord tacite au bénéfice de …* » **pour
toute nature** de dossier, là où son canon distingue dépôt, refus et acceptation.
Mesuré : 3 des 4 natures de la grille produisent un libellé mensonger.

Aujourd'hui rien n'est faux en base — le seul appelant passe `'accord_tacite'`, et
c'est vérifié : un unique site d'appel. Mais la table `dossiers_urbanisme` est
**append-only** : une ligne fausse ne se corrige pas après coup. La garde posée
refuse donc toute nature autre qu'`accord_tacite`, **avant toute écriture**, et
signale l'échec comme le fait déjà la garde du pays (chantier 4G).

Prouvé par `outils/bancs/banc-urbanisme-nature-refusee.js` : **20 épreuves**, dont
l'accord tacite qui passe encore — une garde qui ferme tout ne prouve rien — et la
vérification que la garde du pays n'a pas été déplacée (elle est examinée
d'abord). Contre-épreuve faite : garde retirée, **9 des 20 épreuves rougissent**.

### 3.4 Trois constantes qui n'étaient surveillées par rien — déclarées

`FUSEAU_ELECTORAL`, `CANDIDATURES_MIN_MS` et `REPARTITION_PORT_DEFAUT` sont
déclarées **sous exactement le même nom des deux côtés**. Le contrôle des
référentiels ne regarde que les copies suffixées `_SERVEUR` : celles-ci
n'existaient donc dans **aucune** déclaration du dépôt. Mesurées égales
aujourd'hui, et désormais comparées par valeur à chaque passage.

## 4. Ce qui diverge pour de vrai, et à qui ça appartient

### 4.1 La copie du Journal, et les prix de moitié

`api/_journal-collecte.js` détient sa propre `getPrixRessource`. **Les 103 cas de
la grille divergent** — et ce n'est pas la fonction qui dérive : son texte ne
diffère du canon que par un `null` au lieu de `0` sur une clé inconnue, ce qui est
voulu (le Journal distingue « pas de prix » de « prix nul »). C'est sa **donnée**.
Ce module porte sa propre table `RESSOURCES_ECONOMIE`, et elle diverge du canon de
**33 écarts**, dont des prix de base **de moitié** (bois 2,5 contre 5, alcool 7
contre 14) et une matière absente (textile).

Cette divergence était **déjà connue, déjà déclarée** dans
`outils/baseline/referentiels.json`, et **déjà attribuée au lot 4D**. Elle n'est
pas réparée ici : réparer un référentiel au passage d'un autre chantier, c'est
entamer ce chantier-là. Elle est **reportée** dans `fonctions.json` avec son compte
exact, parce que c'est elle qui fait diverger la fonction.

> **Quand le lot 4D fermera la table, ce compte tombera à 1 et le contrôle rougira
> en annonçant une déclaration périmée.** C'est le signal attendu, et c'est le même
> mécanisme qui, au chantier 3, a trouvé un `GRANT` à `PUBLIC` qu'une migration
> croyait avoir retiré.

### 4.2 Le texte du document d'urbanisme

`texteAccordTaciteServeur` n'imprime pas la ligne « *Établi le jour N (dépôt :
jour M)* » que son canon produit. Les 4 cas de la grille divergent. **Ce n'est pas
une dérive** : c'est le texte qu'un module serverless peut écrire sans les
catalogues du navigateur, et le dépôt l'annonçait déjà (« miroir volontairement
resserré »). L'étendue est déclarée, donc surveillée.

## 5. Trois choses que la mesure a apprises sur l'état du jeu

Elles ne sont pas des défauts. Elles sont des **faits d'architecture** qu'il vaut
mieux savoir avant de toucher à ces fichiers.

**1. Huit canons sont morts au navigateur.** `planifierApprovisionnement`,
`reliquatNPC`, `lotsLivrablesDepuisPlan`, `verdictAccordTacite`,
`coutRevientLotMilitaire`, `palierGreveOrdinaire`, `calendrierTourSuivant`,
`lundiMinuitParisApresSemaines` n'ont plus **aucun appelant** côté navigateur. La
règle ne tourne plus que dans le cron — et, pour l'approvisionnement, dans la
porte SQL `chantier_approvisionner` (registre 599). **La copie serveur est devenue
l'implémentation, pas le miroir.** Les canons sont conservés : ils sont la
référence de comparaison, et les supprimer priverait le contrôle de son témoin.

**2. Un canon a carrément disparu.** `verifierEffetsEtDistributionFiscale` n'existe
plus dans `plateau-justice-economie.js` — qui le dit lui-même : « *vivaient ici* ».
`distribuerFiscaliteServeur` n'a donc plus de paire. C'est l'état cible, pas une
dette.

**3. Une transition quotidienne est appliquée par les deux côtés, et c'est voulu.**
`verifierExpulsionsAmbassadeursQuotidien` tourne encore dans le navigateur **et**
son miroir serveur tourne la nuit. Le partage est écrit dans les deux fichiers et
daté du 20 septembre 2026 : le navigateur met à jour l'ambassade (écriture
idempotente, effet immédiat pour le joueur présent), le serveur émet l'avis
d'expulsion avec son autorité. Ce n'est pas un doublon oublié — et la désertion,
elle, a bien été retirée du navigateur pour cette raison-là. Les deux côtés sont
épinglés pour qu'un déplacement de cette frontière ne passe pas inaperçu.

## 6. Les huit contre-épreuves du contrôle

Un garde-fou qu'on n'a jamais vu rouge ne prouve rien. Chaque refus a été provoqué
une fois, puis défait — **les huit rendent 1 et nomment le motif attendu** :

| Perturbation | Refus attendu |
|---|---|
| `+ 1` ajouté au seuil des deux tiers au serveur | `DIVERGE` |
| une fonction copiée neuve ajoutée au cron | `copie non declaree` |
| une épinglée dont une ligne change | `TEXTE MODIFIE` |
| `FUSEAU_ELECTORAL` passé à `Europe/Lisbon` | constante `DIVERGE` |
| une copie déclarée renommée | `declaree introuvable` |
| l'étendue d'une divergence déclarée changée | `ETENDUE CHANGEE` |
| une exclusion qui ne désigne plus rien | `ecartee perimee` |
| un canon renommé au navigateur | `CANON ABSENT` |

## 7. Ce qui n'est PAS fait, et qui est consigné

1. **Aucune copie n'est supprimée, et ce n'était pas le but.** Une copie serveur
   existe parce qu'un module serverless ne peut pas charger un script de
   navigateur. La faire disparaître demande la **couche de référentiels pure** —
   la voie B de l'audit 4B — qui modifie `data.js` et huit `plateau-*.js` : un vrai
   changement de runtime, à faire par lots. Ce chantier rend la dérive **impossible
   à passer inaperçue** ; il ne supprime pas la duplication.
2. **La couche d'accès PostgREST reste recopiée dans cinq modules de `api/`**
   (21 fonctions, nommées une par une dans `hors_perimetre`). Chantier
   d'architecture, déjà commencé avec `api/_supabase.js`.
3. **`caisseTerritorialeServeur` et `libererMiroirSubdivision` sont mortes** dans
   `api/cron-minuit.js` — aucun appelant, mesuré. Elles ne sont **pas** des copies
   de fonctions du navigateur, donc pas le sujet d'ici. La première est le seul
   lecteur d'un référentiel généré : la retirer demande de retirer sa génération.
4. **`CHAMPIONNAT_FILTRE_ID` est écrit en dur dans deux modules de `api/`**
   (`'id=eq.2'`) alors que le navigateur le calcule depuis `CHAMPIONNAT_ROW_ID`.
   Les deux commentaires disent « doit rester synchronisée », et **rien ne
   l'applique**. Valeur identique aujourd'hui. Non comparable par valeur sans
   charger `supabase.js`, que la portée isolée n'admet pas encore : c'est une
   dette, nommée, du chantier des référentiels.
5. **Deux copies de référentiels de `api/_journal-collecte.js` ne sont déclarées
   nulle part** : `ENTREPOTS_PAR_PAYS` et les libellés de `TYPES_ORGANISATIONS`.
   Données, donc axe 4C, pas celui-ci.
6. **La divergence `ressources_economie` du Journal reste ouverte** et appartient
   au lot 4D (§4.1).
7. **`NIVEAUX_CONSTRUCTION_SERVEUR` facture 50 000 / 70 000 / 100 000 là où le jeu
   demande 60 000 / 90 000 / 120 000.** C'est une **constante**, pas une fonction,
   déjà déclarée « à arbitrer — ni 4A ni 4C ne l'avaient vue », et **morte** :
   aucun lecteur. Elle est hors du périmètre d'ici, et c'est le seul arbitrage de
   game design que l'inventaire des fonctions a croisé — il ne bloquait rien.

## Reproduire cet inventaire

Le relevé des copies n'est écrit nulle part à la main : il est refait par le
contrôle à chaque passage. Pour le voir seul :

```
python3 -c "import importlib.util as u; s=u.spec_from_file_location('v','outils/baseline/verifier-fonctions.py'); m=u.module_from_spec(s); s.loader.exec_module(m); [print(x) for x in m.copies_du_depot(None)]"
```
