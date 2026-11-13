# Tableau de bord internationalisation — Human Gambit

Base analysée : `2d673bc11d59eeedfd06aba25a16c77017a0bf61`. Empreinte du corpus : `d31ca07fa12e57820ca66470d6b1c3ef3fed5a5455f55b19dfe34671abadc488`.

**Mesure technique du corpus identifié, pas pourcentage certifié de tout le jeu.** Le français est la référence, pas une traduction. Aucune qualité linguistique native certifiée.

**17404 textes distincts repérés**, 32275 occurrences dans les sources. 216 fichiers JS/HTML et 496 fichiers SQL analysés.

## Périmètre et certitude

| Classe | Textes uniques | Mots source |
|---|---:|---:|
| static-render-path | 7666 | 50334 |
| candidate-review | 7591 | 63551 |
| server-source-review | 868 | 13221 |
| ai-context-not-output | 1279 | 53942 |

Les taux suivants portent seulement sur `static-render-path` : un chemin de rendu est identifié, sans preuve que chaque état soit accessible en session. Les autres classes restent visibles, hors dénominateur. Une même chaîne est dédupliquée globalement ; ses occurrences gardent leur contexte. Une seule occurrence non prouvée suffit à empêcher sa certification complète.

## Neuf langues

| Langue | Corpus | Raccordés prouvés* | Taux textes* | Taux mots* | Ressource disponible** | Mots à traiter/vérifier |
|---|---:|---:|---:|---:|---:|---:|
| Français | 7666 | 7666 | 100.00 % | 100.00 % | 7666 | 0 |
| Anglais | 7666 | 803 | 10.47 % | 19.16 % | 1289 | 40688 |
| Espagnol | 7666 | 810 | 10.57 % | 19.18 % | 1305 | 40680 |
| Chinois traditionnel | 7666 | 812 | 10.59 % | 19.18 % | 1311 | 40678 |
| Russe | 7666 | 812 | 10.59 % | 19.18 % | 1310 | 40678 |
| Coréen | 7666 | 812 | 10.59 % | 19.18 % | 1311 | 40678 |
| Arabe | 7666 | 812 | 10.59 % | 19.18 % | 1310 | 40678 |
| Portugais brésilien | 7666 | 809 | 10.55 % | 19.18 % | 1307 | 40681 |
| Allemand | 7666 | 811 | 10.58 % | 19.18 % | 1307 | 40679 |

* Preuve statique stricte : clé explicite de même français, traducteur exporté/wrapper transparent, guide accepté par son garde d’intégrité ou description d’ordre reconnue par le résolveur existant dans son pays, dans chacune des huit langues. C’est un plancher de raccordements identifiés, pas la mesure de toutes les traductions qui fonctionnent. Les valeurs identiques au français restent à vérifier sauf sigles neutres documentés.

** Une ressource correspondante peut exister sans preuve de raccordement. Elle ne compte PAS comme texte traduit dans la colonne « raccordés ». Les mots à traiter incluent donc traduction ET vérification des branchements.

## Domaines (recouvrements possibles)

| Domaine | Textes du corpus | EN raccordés | EN sans ressource | EN mots à traiter/vérifier |
|---|---:|---:|---:|---:|
| Bâtiments et pièces | 964 | 578 | 217 | 3748 |
| Courriers, notifications et journaux | 277 | 53 | 181 | 889 |
| Création et connexion | 169 | 83 | 70 | 500 |
| Enquêtes, missions et objectifs | 927 | 0 | 863 | 5137 |
| Interface générale et autres activités | 2112 | 69 | 1856 | 10523 |
| Navigation et transports | 153 | 0 | 111 | 706 |
| Ordres et descriptions | 978 | 595 | 223 | 3795 |
| PNJ, guides et récits | 526 | 27 | 472 | 3298 |
| Politique, justice et administration | 1362 | 2 | 1250 | 7205 |
| Économie et commerces | 1901 | 7 | 1778 | 10221 |

Les neuf langues et leurs volumes par domaine sont détaillés dans `tableau-de-bord.json` → `domains`. Aucun domaine n’est déclaré complet sur la seule présence de clés.

### Planchers de preuves par domaine et langue (textes / mots)

| Domaine | fr | en | es | zh-TW | ru | ko | ar | pt-BR | de |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bâtiments et pièces | 100.00 % / 100.00 % | 59.96 % / 61.37 % | 59.96 % / 61.37 % | 60.06 % / 61.38 % | 60.06 % / 61.38 % | 60.06 % / 61.38 % | 60.06 % / 61.38 % | 59.96 % / 61.37 % | 60.06 % / 61.38 % |
| Courriers, notifications et journaux | 100.00 % / 100.00 % | 19.13 % / 25.73 % | 19.13 % / 25.73 % | 19.13 % / 25.73 % | 19.13 % / 25.73 % | 19.13 % / 25.73 % | 19.13 % / 25.73 % | 19.13 % / 25.73 % | 19.13 % / 25.73 % |
| Création et connexion | 100.00 % / 100.00 % | 49.11 % / 47.42 % | 50.30 % / 47.63 % | 50.89 % / 47.74 % | 50.89 % / 47.74 % | 50.89 % / 47.74 % | 50.89 % / 47.74 % | 50.30 % / 47.63 % | 50.89 % / 47.74 % |
| Enquêtes, missions et objectifs | 100.00 % / 100.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % |
| Interface générale et autres activités | 100.00 % / 100.00 % | 3.27 % / 20.49 % | 3.50 % / 20.54 % | 3.50 % / 20.54 % | 3.50 % / 20.54 % | 3.50 % / 20.54 % | 3.50 % / 20.54 % | 3.46 % / 20.53 % | 3.46 % / 20.53 % |
| Navigation et transports | 100.00 % / 100.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % | 0.00 % / 0.00 % |
| Ordres et descriptions | 100.00 % / 100.00 % | 60.84 % / 61.85 % | 60.84 % / 61.85 % | 60.94 % / 61.86 % | 60.94 % / 61.86 % | 60.94 % / 61.86 % | 60.94 % / 61.86 % | 60.84 % / 61.85 % | 60.94 % / 61.86 % |
| PNJ, guides et récits | 100.00 % / 100.00 % | 5.13 % / 44.08 % | 5.13 % / 44.08 % | 5.13 % / 44.08 % | 5.13 % / 44.08 % | 5.13 % / 44.08 % | 5.13 % / 44.08 % | 5.13 % / 44.08 % | 5.13 % / 44.08 % |
| Politique, justice et administration | 100.00 % / 100.00 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % | 0.15 % / 0.06 % |
| Économie et commerces | 100.00 % / 100.00 % | 0.37 % / 0.30 % | 0.37 % / 0.30 % | 0.37 % / 0.30 % | 0.37 % / 0.30 % | 0.37 % / 0.30 % | 0.37 % / 0.30 % | 0.37 % / 0.30 % | 0.37 % / 0.30 % |

## Descriptions d’ordres par empire

| Empire (identifiant interne) | Descriptions distinctes | Ressources EN présentes | EN différentes du français ou neutres | EN reconnues par le résolveur du pays |
|---|---:|---:|---:|---:|
| khalija | 315 | 206 | 206 | 184 |
| narco | 314 | 207 | 206 | 184 |
| republic | 394 | 224 | 224 | 224 |
| soviet | 307 | 307 | 306 | 306 |

Les descriptions communes sont présentes dans plusieurs empires : ne pas additionner ces lignes. Une formule chiffrée inchangée peut être légitimement identique ; elle reste à vérifier si elle ne figure pas dans les sigles neutres. Chaque langue est détaillée dans le JSON.

## Catalogue central et autres ressources

Le catalogue central expose **3285 clés françaises**. Les tables locales, guides et matrices sont inventoriés séparément (4062 enregistrements après déduplication structurelle). Les traductions supplémentaires sans français de référence ne sont pas artificiellement ajoutées au dénominateur.

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
| 1 | 312 | Compréhension d’un ordre, d’un refus ou entrée dans le jeu |
| 2 | 9998 | Commandes et messages de gameplay |
| 3 | 2963 | Compréhension d’une mission ou interaction narrative |
| 4 | 2051 | Description ou repère de lieu |

Classement automatique à confirmer en jeu. `inventaire.json.gz` fournit texte, identifiant, fichier, ligne, pays et ressources candidates ; `priorites.json.gz` fournit les langues manquantes et les branchements à vérifier. Les descriptions Républia restantes ne sont pas traduites par cet audit.

### Exemples de cibles sans ressource confirmée (à vérifier avant traduction)

- Priorité 1 — Réservé au chef d'un groupe d'au moins 10 PJ présents sur la place. Sans déclaration : en faveur ou hostile à un personnage, +1 ou — `data.js:5919` (58 mots source ; identifiant `3022ded2aa88850dc4f6`).
- Priorité 1 — Un extrait de casier affirmant un casier VIERGE, pour n'importe quel PJ. Le vrai casier n'est jamais modifie. Le casier etant nati — `data.js:3840` (45 mots source ; identifiant `4343d8ae97a319e42945`).
- Priorité 1 — Reserve au Juge, au Commissaire et au Procureur, et seulement sur une personne visee par une affaire VIVANTE dont ils sont l'autor — `data.js:3837` (42 mots source ; identifiant `a5ebfc75c555ecf86b39`).
- Priorité 2 — Sans déclaration préalable. Il faut être le chef d'un groupe d'au moins 10 PJ présents sur la place. Chaque participant fait gagne — `plateau-communication.js:2672` (68 mots source ; identifiant `3aa1f0b09eca4a8dcd9c`).
- Priorité 2 — Vous engagez la responsabilité de votre gouvernement devant l'Assemblée Nationale (9 sièges de députés). Vote sous 48h réelles. En — `plateau-politique.js:10232` (59 mots source ; identifiant `05e32526bf0eeb1365bf`).
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
