# Tableau de bord internationalisation — Human Gambit

Base analysée : `9d21b7c5203db18c1f71cb61ff98aad7140f8501`. Empreinte du corpus : `98fec2432c16741d11291f794b546c72df2b08c52c0b2d0d9401f3408c0ce46b`.

**Mesure technique du corpus identifié, pas pourcentage certifié de tout le jeu.** Le français est la référence, pas une traduction. Aucune qualité linguistique native certifiée.

**17383 textes distincts repérés**, 30744 occurrences dans les sources. 223 fichiers JS/HTML et 515 fichiers SQL analysés.

## Périmètre et certitude

| Classe | Textes uniques | Mots source |
|---|---:|---:|
| static-render-path | 7565 | 50690 |
| candidate-review | 7617 | 63726 |
| server-source-review | 908 | 13567 |
| ai-context-not-output | 1293 | 54765 |

Les taux suivants portent seulement sur `static-render-path` : un chemin de rendu est identifié, sans preuve que chaque état soit accessible en session. Les autres classes restent visibles, hors dénominateur. Une même chaîne est dédupliquée globalement ; ses occurrences gardent leur contexte. Une seule occurrence non prouvée suffit à empêcher sa certification complète.

## Neuf langues

| Langue | Corpus | Raccordés prouvés* | Taux textes* | Taux mots* | Ressource disponible** | Mots à traiter/vérifier |
|---|---:|---:|---:|---:|---:|---:|
| Français | 7565 | 7565 | 100.00 % | 100.00 % | 7565 | 0 |
| Anglais | 7565 | 1001 | 13.23 % | 24.01 % | 1549 | 38519 |
| Espagnol | 7565 | 1008 | 13.32 % | 24.03 % | 1565 | 38511 |
| Chinois traditionnel | 7565 | 1010 | 13.35 % | 24.03 % | 1571 | 38509 |
| Russe | 7565 | 1010 | 13.35 % | 24.03 % | 1570 | 38509 |
| Coréen | 7565 | 1010 | 13.35 % | 24.03 % | 1571 | 38509 |
| Arabe | 7565 | 1010 | 13.35 % | 24.03 % | 1570 | 38509 |
| Portugais brésilien | 7565 | 1007 | 13.31 % | 24.02 % | 1567 | 38512 |
| Allemand | 7565 | 1009 | 13.34 % | 24.03 % | 1567 | 38510 |

* Preuve statique stricte : clé explicite de même français, traducteur exporté/wrapper transparent, guide accepté par son garde d’intégrité ou description d’ordre reconnue par le résolveur existant dans son pays, dans chacune des huit langues. C’est un plancher de raccordements identifiés, pas la mesure de toutes les traductions qui fonctionnent. Les valeurs identiques au français restent à vérifier sauf sigles neutres documentés.

** Une ressource correspondante peut exister sans preuve de raccordement. Elle ne compte PAS comme texte traduit dans la colonne « raccordés ». Les mots à traiter incluent donc traduction ET vérification des branchements.

## Domaines (recouvrements possibles)

| Domaine | Textes du corpus | EN raccordés | EN sans ressource | EN mots à traiter/vérifier |
|---|---:|---:|---:|---:|
| Bâtiments et pièces | 973 | 701 | 44 | 2082 |
| Courriers, notifications et journaux | 388 | 104 | 238 | 1217 |
| Création et connexion | 158 | 94 | 48 | 388 |
| Enquêtes, missions et objectifs | 898 | 0 | 833 | 5136 |
| Interface générale et autres activités | 1954 | 90 | 1679 | 9803 |
| Navigation et transports | 139 | 0 | 97 | 706 |
| Ordres et descriptions | 987 | 718 | 50 | 2104 |
| PNJ, guides et récits | 508 | 23 | 456 | 3318 |
| Politique, justice et administration | 1323 | 2 | 1210 | 7210 |
| Économie et commerces | 1856 | 8 | 1730 | 10221 |

Les neuf langues et leurs volumes par domaine sont détaillés dans `tableau-de-bord.json` → `domains`. Aucun domaine n’est déclaré complet sur la seule présence de clés.

### Planchers de preuves par domaine et langue (textes / mots)

| Domaine | fr | en | es | zh-TW | ru | ko | ar | pt-BR | de |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bâtiments et pièces | 100.00 % / 100.00 % | 72.05 % / 79.08 % | 72.05 % / 79.08 % | 72.15 % / 79.09 % | 72.15 % / 79.09 % | 72.15 % / 79.09 % | 72.15 % / 79.09 % | 72.05 % / 79.08 % | 72.15 % / 79.09 % |
| Courriers, notifications et journaux | 100.00 % / 100.00 % | 26.80 % / 34.78 % | 26.80 % / 34.78 % | 26.80 % / 34.78 % | 26.80 % / 34.78 % | 26.80 % / 34.78 % | 26.80 % / 34.78 % | 26.80 % / 34.78 % | 26.80 % / 34.78 % |
| Création et connexion | 100.00 % / 100.00 % | 59.49 % / 60.57 % | 60.76 % / 60.77 % | 61.39 % / 60.87 % | 61.39 % / 60.87 % | 61.39 % / 60.87 % | 61.39 % / 60.87 % | 60.76 % / 60.77 % | 61.39 % / 60.87 % |
| Enquêtes, missions et objectifs | 100.00 % / 100.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % |
| Interface générale et autres activités | 100.00 % / 100.00 % | 4.61 % / 22.79 % | 4.86 % / 22.83 % | 4.86 % / 22.83 % | 4.86 % / 22.83 % | 4.86 % / 22.83 % | 4.86 % / 22.83 % | 4.81 % / 22.83 % | 4.81 % / 22.83 % |
| Navigation et transports | 100.00 % / 100.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % |
| Ordres et descriptions | 100.00 % / 100.00 % | 72.75 % / 79.31 % | 72.75 % / 79.31 % | 72.85 % / 79.32 % | 72.85 % / 79.32 % | 72.85 % / 79.32 % | 72.85 % / 79.32 % | 72.75 % / 79.31 % | 72.85 % / 79.32 % |
| PNJ, guides et récits | 100.00 % / 100.00 % | 4.53 % / 43.73 % | 4.53 % / 43.73 % | 4.53 % / 43.73 % | 4.53 % / 43.73 % | 4.53 % / 43.73 % | 4.53 % / 43.73 % | 4.53 % / 43.73 % | 4.53 % / 43.73 % |
| Politique, justice et administration | 100.00 % / 100.00 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % |
| Économie et commerces | 100.00 % / 100.00 % | 0.43 % / 0.41 % | 0.43 % / 0.41 % | 0.43 % / 0.41 % | 0.43 % / 0.41 % | 0.43 % / 0.41 % | 0.43 % / 0.41 % | 0.43 % / 0.41 % | 0.43 % / 0.41 % |

## Descriptions d’ordres par empire

| Empire (identifiant interne) | Descriptions distinctes | Ressources EN présentes | EN différentes du français ou neutres | EN reconnues par le résolveur du pays |
|---|---:|---:|---:|---:|
| khalija | 313 | 310 | 310 | 229 |
| narco | 312 | 311 | 310 | 229 |
| republic | 397 | 395 | 395 | 394 |
| soviet | 358 | 358 | 358 | 356 |

Les descriptions communes sont présentes dans plusieurs empires : ne pas additionner ces lignes. Une formule chiffrée inchangée peut être légitimement identique ; elle reste à vérifier si elle ne figure pas dans les sigles neutres. Chaque langue est détaillée dans le JSON.

## Catalogue central et autres ressources

Le catalogue central expose **3490 clés françaises**. Les tables locales, guides et matrices sont inventoriés séparément (4441 enregistrements après déduplication structurelle). Les traductions supplémentaires sans français de référence ne sont pas artificiellement ajoutées au dénominateur.

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
| 1 | 180 | Compréhension d’un ordre, d’un refus ou entrée dans le jeu |
| 2 | 9907 | Commandes et messages de gameplay |
| 3 | 2937 | Compréhension d’une mission ou interaction narrative |
| 4 | 2067 | Description ou repère de lieu |

Classement automatique à confirmer en jeu. `inventaire.json.gz` fournit texte, identifiant, fichier, ligne, pays et ressources candidates ; `priorites.json.gz` fournit les langues manquantes et les branchements à vérifier. Les descriptions Républia restantes ne sont pas traduites par cet audit.

### Exemples de cibles sans ressource confirmée (à vérifier avant traduction)

- Priorité 1 — La session de ce navigateur n'est plus reconnue par le serveur. Rechargez la page : une nouvelle session sera ouverte et la creati — `creation.js:1256` (23 mots source ; identifiant `0992d6e654559b672aa6`).
- Priorité 1 — Si ce personnage est le votre et que vous avez perdu l'acces, utilisez « Retrouver mon personnage » depuis l'accueil plutot que d' — `creation.js:1240` (23 mots source ; identifiant `c736a3a6c07b70a9d058`).
- Priorité 1 — Retournez a l'accueil pour le reprendre. Pour en creer un autre, il faut d'abord detruire celui que vous possedez, depuis sa fiche — `creation.js:1246` (22 mots source ; identifiant `cc7faa7b891a4a7bedc5`).
- Priorité 2 — Sans déclaration préalable. Il faut être le chef d'un groupe d'au moins 10 PJ présents sur la place. Chaque participant fait gagne — `plateau-communication.js:2687` (68 mots source ; identifiant `3aa1f0b09eca4a8dcd9c`).
- Priorité 2 — Vous engagez la responsabilité de votre gouvernement devant l'Assemblée Nationale (9 sièges de députés). Vote sous 48h réelles. En — `plateau-politique.js:10324` (59 mots source ; identifiant `05e32526bf0eeb1365bf`).
- Priorité 2 — ACTE ILLEGAL. 300 FR et 3 PA sont preleves A LA TENTATIVE, reussie ou non. Si la corruption est decouverte, vous n'obtenez rien et — `plateau-justice-economie.js:14494` (54 mots source ; identifiant `fea7c948803a7ffe7803`).
- Priorité 3 — Caillon... oh que oui ce nom me dit quelque chose, forcément, j'ai fait trente ans dans la police. Une drôle d'affaire, à l'époque — `plateau-pnj.js:1631` (132 mots source ; identifiant `3ccfb4caa7866bb5e00b`).
- Priorité 3 — Thibault ? Ah oui, le père Thibault ! Bien sûr que je m'en souviens, on se croisait tout le temps au marché, avant. Une belle terr — `plateau-pnj.js:1636` (102 mots source ; identifiant `1c46f876a3c222deb97c`).
- Priorité 3 — Ah, mes années à l'école... j'en ai vu passer, des enfants ! Thibault... Thibault... Attendez, laissez-moi réfléchir. Oui ! Une pe — `plateau-pnj.js:1626` (84 mots source ; identifiant `3b7ab222f61ad1d6e329`).
- Priorité 4 — Je confirme disposer des droits nécessaires sur les images fournies, y compris les autorisations des personnes représentées, et ac — `plateau-commerce-pj.js:2429` (25 mots source ; identifiant `846851839ae60f450ae4`).
- Priorité 4 — Acheter ce terrain (4 200 m² — 50 400 FR) — `data.js:6241` (9 mots source ; identifiant `3f38fd58b36e4f5a56b8`).
- Priorité 4 — Acheter ce terrain (2 200 m² — 26 400 FR) — `data.js:6192` (9 mots source ; identifiant `649cad5cdcaf3717a419`).

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
