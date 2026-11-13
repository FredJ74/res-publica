# Tableau de bord internationalisation — Human Gambit

Base analysée : `d7d3c6985db278192a5cad84d70c47d333ebc42e`. Empreinte du corpus : `3121389037f05da4f03d884d35adaad09e15c1971f5ce0ae1070abe76f6ad542`.

**Mesure technique du corpus identifié, pas pourcentage certifié de tout le jeu.** Le français est la référence, pas une traduction. Aucune qualité linguistique native certifiée.

**17276 textes distincts repérés**, 30129 occurrences dans les sources. 218 fichiers JS/HTML et 498 fichiers SQL analysés.

## Périmètre et certitude

| Classe | Textes uniques | Mots source |
|---|---:|---:|
| static-render-path | 7538 | 50314 |
| candidate-review | 7589 | 63537 |
| server-source-review | 870 | 13237 |
| ai-context-not-output | 1279 | 53942 |

Les taux suivants portent seulement sur `static-render-path` : un chemin de rendu est identifié, sans preuve que chaque état soit accessible en session. Les autres classes restent visibles, hors dénominateur. Une même chaîne est dédupliquée globalement ; ses occurrences gardent leur contexte. Une seule occurrence non prouvée suffit à empêcher sa certification complète.

## Neuf langues

| Langue | Corpus | Raccordés prouvés* | Taux textes* | Taux mots* | Ressource disponible** | Mots à traiter/vérifier |
|---|---:|---:|---:|---:|---:|---:|
| Français | 7538 | 7538 | 100.00 % | 100.00 % | 7538 | 0 |
| Anglais | 7538 | 874 | 11.59 % | 21.45 % | 1466 | 39523 |
| Espagnol | 7538 | 881 | 11.69 % | 21.46 % | 1482 | 39515 |
| Chinois traditionnel | 7538 | 883 | 11.71 % | 21.47 % | 1488 | 39513 |
| Russe | 7538 | 883 | 11.71 % | 21.47 % | 1487 | 39513 |
| Coréen | 7538 | 883 | 11.71 % | 21.47 % | 1488 | 39513 |
| Arabe | 7538 | 883 | 11.71 % | 21.47 % | 1487 | 39513 |
| Portugais brésilien | 7538 | 880 | 11.67 % | 21.46 % | 1484 | 39516 |
| Allemand | 7538 | 882 | 11.70 % | 21.47 % | 1484 | 39514 |

* Preuve statique stricte : clé explicite de même français, traducteur exporté/wrapper transparent, guide accepté par son garde d’intégrité ou description d’ordre reconnue par le résolveur existant dans son pays, dans chacune des huit langues. C’est un plancher de raccordements identifiés, pas la mesure de toutes les traductions qui fonctionnent. Les valeurs identiques au français restent à vérifier sauf sigles neutres documentés.

** Une ressource correspondante peut exister sans preuve de raccordement. Elle ne compte PAS comme texte traduit dans la colonne « raccordés ». Les mots à traiter incluent donc traduction ET vérification des branchements.

## Domaines (recouvrements possibles)

| Domaine | Textes du corpus | EN raccordés | EN sans ressource | EN mots à traiter/vérifier |
|---|---:|---:|---:|---:|
| Bâtiments et pièces | 959 | 642 | 43 | 2631 |
| Courriers, notifications et journaux | 388 | 59 | 283 | 1534 |
| Création et connexion | 154 | 83 | 55 | 498 |
| Enquêtes, missions et objectifs | 898 | 0 | 834 | 5136 |
| Interface générale et autres activités | 1938 | 70 | 1685 | 9826 |
| Navigation et transports | 139 | 0 | 97 | 706 |
| Ordres et descriptions | 974 | 659 | 50 | 2678 |
| PNJ, guides et récits | 508 | 27 | 454 | 3297 |
| Politique, justice et administration | 1322 | 2 | 1210 | 7204 |
| Économie et commerces | 1855 | 7 | 1732 | 10221 |

Les neuf langues et leurs volumes par domaine sont détaillés dans `tableau-de-bord.json` → `domains`. Aucun domaine n’est déclaré complet sur la seule présence de clés.

### Planchers de preuves par domaine et langue (textes / mots)

| Domaine | fr | en | es | zh-TW | ru | ko | ar | pt-BR | de |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bâtiments et pièces | 100.00 % / 100.00 % | 66.94 % / 72.85 % | 66.94 % / 72.85 % | 67.05 % / 72.86 % | 67.05 % / 72.86 % | 67.05 % / 72.86 % | 67.05 % / 72.86 % | 66.94 % / 72.85 % | 67.05 % / 72.86 % |
| Courriers, notifications et journaux | 100.00 % / 100.00 % | 15.21 % / 17.79 % | 15.21 % / 17.79 % | 15.21 % / 17.79 % | 15.21 % / 17.79 % | 15.21 % / 17.79 % | 15.21 % / 17.79 % | 15.21 % / 17.79 % | 15.21 % / 17.79 % |
| Création et connexion | 100.00 % / 100.00 % | 53.90 % / 47.52 % | 55.19 % / 47.73 % | 55.84 % / 47.84 % | 55.84 % / 47.84 % | 55.84 % / 47.84 % | 55.84 % / 47.84 % | 55.19 % / 47.73 % | 55.84 % / 47.84 % |
| Enquêtes, missions et objectifs | 100.00 % / 100.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % |
| Interface générale et autres activités | 100.00 % / 100.00 % | 3.61 % / 21.72 % | 3.87 % / 21.77 % | 3.87 % / 21.77 % | 3.87 % / 21.77 % | 3.87 % / 21.77 % | 3.87 % / 21.77 % | 3.82 % / 21.76 % | 3.82 % / 21.76 % |
| Navigation et transports | 100.00 % / 100.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % |
| Ordres et descriptions | 100.00 % / 100.00 % | 67.66 % / 73.05 % | 67.66 % / 73.05 % | 67.76 % / 73.06 % | 67.76 % / 73.06 % | 67.76 % / 73.06 % | 67.76 % / 73.06 % | 67.66 % / 73.05 % | 67.76 % / 73.06 % |
| PNJ, guides et récits | 100.00 % / 100.00 % | 5.31 % / 44.09 % | 5.31 % / 44.09 % | 5.31 % / 44.09 % | 5.31 % / 44.09 % | 5.31 % / 44.09 % | 5.31 % / 44.09 % | 5.31 % / 44.09 % | 5.31 % / 44.09 % |
| Politique, justice et administration | 100.00 % / 100.00 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % |
| Économie et commerces | 100.00 % / 100.00 % | 0.38 % / 0.30 % | 0.38 % / 0.30 % | 0.38 % / 0.30 % | 0.38 % / 0.30 % | 0.38 % / 0.30 % | 0.38 % / 0.30 % | 0.38 % / 0.30 % | 0.38 % / 0.30 % |

## Descriptions d’ordres par empire

| Empire (identifiant interne) | Descriptions distinctes | Ressources EN présentes | EN différentes du français ou neutres | EN reconnues par le résolveur du pays |
|---|---:|---:|---:|---:|
| khalija | 315 | 311 | 311 | 184 |
| narco | 314 | 312 | 311 | 184 |
| republic | 394 | 394 | 394 | 394 |
| soviet | 306 | 306 | 305 | 305 |

Les descriptions communes sont présentes dans plusieurs empires : ne pas additionner ces lignes. Une formule chiffrée inchangée peut être légitimement identique ; elle reste à vérifier si elle ne figure pas dans les sigles neutres. Chaque langue est détaillée dans le JSON.

## Catalogue central et autres ressources

Le catalogue central expose **3293 clés françaises**. Les tables locales, guides et matrices sont inventoriés séparément (4235 enregistrements après déduplication structurelle). Les traductions supplémentaires sans français de référence ne sont pas artificiellement ajoutées au dénominateur.

| Langue | Clés absentes | Variables incohérentes |
|---|---:|---:|
| fr | 0 | 0 |
| en | 0 | 0 |
| es | 0 | 0 |
| zh-TW | 0 | 0 |
| ru | 0 | 0 |
| ko | 0 | 0 |
| ar | 0 | 0 |
| pt-BR | 0 | 0 |
| de | 0 | 0 |

## Priorités

| Priorité | Textes candidats non entièrement prouvés | Usage |
|---|---:|---|
| 1 | 233 | Compréhension d’un ordre, d’un refus ou entrée dans le jeu |
| 2 | 9911 | Commandes et messages de gameplay |
| 3 | 2932 | Compréhension d’une mission ou interaction narrative |
| 4 | 2049 | Description ou repère de lieu |

Classement automatique à confirmer en jeu. `inventaire.json.gz` fournit texte, identifiant, fichier, ligne, pays et ressources candidates ; `priorites.json.gz` fournit les langues manquantes et les branchements à vérifier. Les descriptions Républia restantes ne sont pas traduites par cet audit.

### Exemples de cibles sans ressource confirmée (à vérifier avant traduction)

- Priorité 1 — Votre personnage est désormais rattaché à votre compte. Connectez-vous ci-dessous avec cette adresse et votre mot de passe pour le — `creation.js:181` (29 mots source ; identifiant `0094a29fb3eba71bdb49`).
- Priorité 1 — La session de ce navigateur n'est plus reconnue par le serveur. Rechargez la page : une nouvelle session sera ouverte et la creati — `creation.js:1225` (23 mots source ; identifiant `0992d6e654559b672aa6`).
- Priorité 1 — Il a expiré, ou une adresse plus récente l'a remplacé. Rouvrez votre personnage sur l'appareil où vous jouez et demandez un nouvea — `creation.js:173` (23 mots source ; identifiant `70fbaea2321e32c20eed`).
- Priorité 2 — Sans déclaration préalable. Il faut être le chef d'un groupe d'au moins 10 PJ présents sur la place. Chaque participant fait gagne — `plateau-communication.js:2687` (68 mots source ; identifiant `3aa1f0b09eca4a8dcd9c`).
- Priorité 2 — Vous engagez la responsabilité de votre gouvernement devant l'Assemblée Nationale (9 sièges de députés). Vote sous 48h réelles. En — `plateau-politique.js:10233` (59 mots source ; identifiant `05e32526bf0eeb1365bf`).
- Priorité 2 — ACTE ILLEGAL. 300 FR et 3 PA sont preleves A LA TENTATIVE, reussie ou non. Si la corruption est decouverte, vous n'obtenez rien et — `plateau-justice-economie.js:14489` (54 mots source ; identifiant `fea7c948803a7ffe7803`).
- Priorité 3 — Caillon... oh que oui ce nom me dit quelque chose, forcément, j'ai fait trente ans dans la police. Une drôle d'affaire, à l'époque — `plateau-pnj.js:1613` (132 mots source ; identifiant `3ccfb4caa7866bb5e00b`).
- Priorité 3 — Thibault ? Ah oui, le père Thibault ! Bien sûr que je m'en souviens, on se croisait tout le temps au marché, avant. Une belle terr — `plateau-pnj.js:1618` (102 mots source ; identifiant `1c46f876a3c222deb97c`).
- Priorité 3 — Ah, mes années à l'école... j'en ai vu passer, des enfants ! Thibault... Thibault... Attendez, laissez-moi réfléchir. Oui ! Une pe — `plateau-pnj.js:1608` (84 mots source ; identifiant `3b7ab222f61ad1d6e329`).
- Priorité 4 — Acheter ce terrain (4 200 m² — 50 400 FR) — `data.js:6211` (9 mots source ; identifiant `3f38fd58b36e4f5a56b8`).
- Priorité 4 — Acheter ce terrain (2 200 m² — 26 400 FR) — `data.js:6162` (9 mots source ; identifiant `649cad5cdcaf3717a419`).
- Priorité 4 — Acheter ce terrain (3 100 m² — 37 200 FR) — `data.js:6185` (9 mots source ; identifiant `a5c130c59d864fbdc750`).

## Données serveur et limites

Relevé serveur en lecture seule : 2026-11-13. Agrégats de références statiques, aucune donnée de personnage.

| Source | Textes distincts (dans cette source) | Mots séparés par espaces |
|---|---:|---:|
| catalogue_generiques.libelle | 96 | 198 |
| pnj_candidats_catalogue.accroche | 30 | 323 |
| pnj_referents_sujets_connus.libelle | 8 | 37 |
| recettes_commerce.description | 24 | 258 |
| recettes_commerce.label | 90 | 484 |
| scandales_predefinis.texte | 10 | 177 |
| sovarka_maisons_ragots.texte | 0 | 0 |

- Présence en catalogue ≠ branchement correct ≠ qualité linguistique. Les taux sont techniques et conservateurs, jamais un taux certifié de tout le jeu.
- Chemin statique ≠ observation en session : droits, progression, pièces inaccessibles et conditions dynamiques nécessitent une recette en jeu.
- Contexte IA recensé à part : ce ne sont pas des répliques affichées. Réponses IA, journaux générés et conversation en cours : volume illimité, traduction non certifiée.
- Courriers, forums, chats et écrits de joueurs : langue inconnue, volume évolutif, aucun contenu privé lu ou exporté.
- Agrégats serveur figés, non additionnables au corpus (doublons possibles), sans certification de traduction ou de langue source.
- SQL du dépôt : candidats, peut contenir des définitions remplacées ; non assimilé aux fonctions actuellement déployées.
- JS : candidats extraits des littéraux/templates, sans analyse complète des flux ; concaténations, tableaux assemblés et HTML injecté à vérifier.
- Texte incrusté dans les images/vidéos, ressources distantes, états non visités, styles CSS : volume de texte inconnu.
- Les domaines se recoupent : leur somme peut dépasser le total unique. La segmentation en mots est une convention Unicode, pas une estimation de temps.

## Reproduction et suivi

Voir [le mode d’emploi](README.md). Les rapports ne contiennent aucune donnée de session ou de joueur. Le script ne se connecte pas à Supabase ; le relevé agrégé est explicite et daté.

Erreurs d’extraction : **0**. Toute erreur est conservée dans le JSON et fait échouer la commande. Les variations se calculent avec `--previous` ; un changement de périmètre/exclusions est signalé.
