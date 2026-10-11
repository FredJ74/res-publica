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
| `AUDIT-CHANTIER-7-FONCTIONS-RECOPIEES.md` | chantier 7 | les **55 copies de fonctions** entre `api/` et le navigateur, mesurées : 42 exécutées des deux côtés sur **1 870 cas**, zéro divergence de formule ; deux chemins d'argent non atomiques sans appelant supprimés, un libellé faux fermé. **À lire avant de toucher à `api/cron-minuit.js`** |
| `CASERNE-REPUBLIA-CLOTURE.md` | caserne / militaire | les **arbitrages rendus** sur la hiérarchie, la caisse, l'inspection et l'ordre de bataille, et les six écarts fermés. **À lire avant de toucher à la caserne** : il dit aussi ce qui est un état NORMAL du jeu (une compagnie sans Capitaine) et ne doit pas être « réparé » |
| `PALAIS-PRESIDENTIEL-CLOTURE.md` | Palais présidentiel / Garde républicaine | les **arbitrages rendus** sur la Présidence volontairement sobre, les trois référents et leur découpage, le canal de contexte public des dialogues, et la Garde républicaine. **À lire avant de toucher au Palais, à la Garde, ou au dialogue des PNJ** : il dit aussi ce qui est un état NORMAL du jeu — un poste décimé compte deux hommes, pas trois — et il corrige une conclusion fausse de l'audit sur l'effet de groupe |
| `PALAIS-GOUVERNEMENT-PREMIERE-PASSE.md` | Palais du Gouvernement | **le bâtiment n'est PAS clos** — la visite est en cours. Ce qui a été livré (faux Premier ministre retiré, secrétaires ministériels génériques, autorité de tribune au serveur, huit assets WebP) et ce qui reste ouvert : un **écart de coût consigné et non tranché** entre l'arbitrage et le code, et deux mécaniques arbitrées non implémentées |
| `PALAIS-GOUVERNEMENT-DEUXIEME-PASSE.md` | Palais du Gouvernement / conférence de presse | **le bâtiment n'est toujours PAS clos.** Les deux arbitrages du soir : **qui paie une communication** (budget de l'Information par défaut, caisse du poste sur accord explicite, jamais de financement mixte, aucun PA perdu sur un refus) et **la conférence de presse** (une question à la fois, de une à cinq, refus de répondre qui ne termine rien, fermeture = fin immédiate, aucun jugement, transcription immuable). **À lire avant de toucher à la parole officielle, au Journal ou à La Tribune** : il dit pourquoi la publication automatique du lendemain est ABANDONNÉE, et pourquoi la règle « les paroles du ministre sont intangibles » est propre à Républia. Il consigne aussi un défaut de la veille — la chronique nationale n'est pas attestée — et un défaut de fraîcheur des seeds du socle PNJ, trouvés et corrigés |
| `ASSEMBLEE-NATIONALE-PREMIERE-PASSE.md` | Assemblée nationale / PNJ du hall | **le bâtiment n'est PAS clos** — l'audit continue. Le garde était déjà raccordé au socle générique : seul son PROFIL était faux (il se disait à l'Élysée dans les trois halls). L'hôtesse devient référente pédagogique avec la procédure RÉELLE (échéance du mercredi 22 h, 36 h de mise en application, barème de sanction). Renée Toitout CONSTATE et n'enquête pas. **À lire avant de toucher à l'Assemblée ou à un PNJ qui raconte ce qu'il a vu** : il contient l'audit complet de ce qui est attestable et de ce qui ne l'est pas — l'assiduité des députés ne l'est PAS (aucun scrutin jamais clos) — et nomme 4 écarts trouvés, dont les 25 sièges de la vitrine contre les 9 réels, et Seb Lex qui n'existe pas |
| `ASSEMBLEE-NATIONALE-DEUXIEME-PASSE.md` | Assemblée nationale / la séance parlementaire | **le bâtiment n'est PAS clos.** La parole, la discipline, la protestation et le boycott sont livrés ; **l'ÉLECTION du Président ne l'est pas** — trois décisions de game design manquent (candidature, vote des neuf députés PNJ, absence de candidat PJ), et le tirage à la courte paille comme la nouvelle élection après deux suspensions en dépendent. **À lire avant de toucher à la popularité d'un autre personnage** : le registre des causes ne marchait POUR PERSONNE depuis sa livraison — sept mécaniques inertes, une porte qui répondait `ok` sans rien faire. Contient aussi la lecture retenue des « épisodes distincts » d'un boycott, à valider, et le constat que les neuf députés PNJ n'ont AUCUNE fiche de personnage |
| `ASSEMBLEE-NATIONALE-TROISIEME-PASSE.md` | Assemblée nationale / l'élection de la présidence | **le bâtiment n'est PAS clos.** L'élection est livrée : aucune candidature (les neuf éligibles d'office), les PNJ s'abstiennent toujours, courte paille tirée par le SERVEUR et rejouée par l'écran sans un seul `Math.random`. La suspension présidentielle devient un ÉTAT, et le deuxième boycott remet la présidence en jeu. **À lire avant de toucher à `organisations`** : la faille d'appartenance est fermée par un déclencheur qui garde la VÉRITÉ et non la porte — et les organisations NON politiques restent forgeables, dette nommée. **Et une sous-partie est ARRÊTÉE** : la ville du Président Laroche n'est pas déterminable par les données, le PNJ qu'il remplacerait est un choix de game design — les neuf noms possibles sont dans le document |
| `ASSEMBLEE-NATIONALE-QUATRIEME-PASSE.md` | Assemblée nationale / Laroche député et le seuil d'une heure | **le bâtiment n'est PAS clos.** Laroche n'est plus une dixième carte : il est député de Luthécia au rang 3, et **Benoît Delorme** lui cède le siège — l'hémicycle ne contient plus AUCUNE personne statique. **À lire avant de toucher au calendrier des sessions** : « prochaine session parlementaire » n'a PAS été inventée, c'est le RENVOI du §27 qui existait déjà (statut `renvoyee`, `cloture_ts` NULL, et la fenêtre du mercredi soir fait le reste) — une preuve refuse tout `+7 days` dans la porte de renvoi. Une suspension présidentielle de plus d'une heure renvoie les scrutins et **annule les suffrages**, mesurée sur `ouverte_le` / `close_le` sans aucun minuteur client, et appliquée AVANT le dépouillement — l'ordre des appels dans le cron EST la règle. On n'élit plus son Président depuis le hall. Deux points de game design sont **rapportés et non tranchés** : l'emplacement unique de `state.poste` pour le cumul affiché, et le Président évincé de son siège par trois députés PJ de sa ville. **Et un banc était rouge depuis la troisième passe** sans que personne l'ait vu |
| `ASSEMBLEE-NATIONALE-CORRECTIF-LEGISLATURE.md` | Assemblée nationale / la présidence suit la législature | **le bâtiment n'est PAS clos.** L'invariant : un Président de l'Assemblée est l'un des NEUF députés de la législature EN COURS, et il n'existe JAMAIS de période où un ancien député préside. **À lire avant de toucher à `assemblee_occupation_sieges` ou à `poste_depute`** : le siège d'un député joueur était dérivé d'un champ POSÉ sur la fiche, que le déclencheur d'attestation ne vérifie qu'à l'ÉCRITURE — un mandat achevé y survivait INDÉFINIMENT pour un joueur déconnecté, et la remise à zéro n'existait que dans le NAVIGATEUR. La correction tient en deux lignes et ne dépend d'AUCUN calendrier : le siège passe par `poste_est_atteste`, la présidence est DÉRIVÉE des neuf. Aucun cron ne porte l'invariant — un cron ne peut pas garantir « jamais ». La justification « le dernier PNJ à céder sa place » de la quatrième passe était FAUSSE et elle est retirée ; aucune ligne de code ne l'avait implémentée. **Trois décors de banc ont dû être corrigés** parce qu'ils forgeaient un Président sans siège — on a corrigé le décor, pas la règle. **Et l'écart de calendrier est REMONTÉ, non comblé** : l'arbitrage dit hebdomadaire/dimanche, l'existant fait 5 semaines/lundi avec deux semaines de vide entre deux législatures |
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
