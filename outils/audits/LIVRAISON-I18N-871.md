# Livraison de la mission #871 — 13 novembre 2026

Le socle multi-empires, le répertoire/courrier et les retours fixes du forum sont
livrés par trois lots indépendants. Aucune modification de l’exécution des ordres,
des prix, droits, PA, RPC, inventaires, PNJ ou données de jeu ; aucune migration.

| Lot | PR | Commit de fusion | Résultat |
|---|---|---|---|
| Socle déclaratif des descriptions d’ordres | #872 | `e10d5fa` | Catalogue commun et catalogues par pays, clé stable facultative, compatibilité exacte, troisième empire simulé |
| Répertoire partagé et courrier | #876 | `c7f197e` | 8 clés × 9 langues, 64 traductions étrangères |
| Retours fixes forum/courrier | #877 | `e9989c6` | 43 clés × 9 langues, 344 traductions étrangères |

## Progression mesurée

51 clés nouvelles, 459 entrées dont **408 traductions étrangères**. Le socle n’ajoute
aucune traduction et ne recompte pas les 189 descriptions Républia ni les 205 communes.
À méthode identique, comparaison du code précédent les deux lots de traduction
(`94d4631`) au code livré : **+50 textes uniques et +352 mots source entièrement
raccordés dans chacune des huit langues étrangères**, +51 ressources uniques.
Le corpus passe de 7 536 textes/50 312 mots à 7 538/50 314, par formalisation des
variables du répertoire, sans suppression de texte pour gonfler le taux.
Les améliorations de reconnaissance et l’exclusion des catalogues non chargés sont
appliquées aux deux états comparés ; elles ne sont pas des traductions nouvelles.

## Tableau de bord conservateur

Dénominateur : **7 538 textes uniques, 50 314 mots français**, ayant un chemin de
rendu statique identifié. Ces chiffres constituent un plancher de raccordements
reconnus par l’extracteur, **pas le pourcentage certifié de tout Human Gambit**.
La dernière colonne mesure la disponibilité en ressources, pas l’affichage traduit.

| Langue | Textes raccordés | Taux textes | Mots source raccordés | Taux mots | Mots avec ressource |
|---|---:|---:|---:|---:|---:|
| Anglais | 913 | 12.11 % | 11083 | 22.03 % | 28.46 % |
| Espagnol | 920 | 12.2 % | 11091 | 22.04 % | 28.5 % |
| Chinois traditionnel | 922 | 12.23 % | 11093 | 22.05 % | 28.51 % |
| Russe | 922 | 12.23 % | 11093 | 22.05 % | 28.5 % |
| Coréen | 922 | 12.23 % | 11093 | 22.05 % | 28.51 % |
| Arabe | 922 | 12.23 % | 11093 | 22.05 % | 28.5 % |
| Portugais brésilien | 919 | 12.19 % | 11090 | 22.04 % | 28.5 % |
| Allemand | 921 | 12.22 % | 11092 | 22.05 % | 28.5 % |

Les textes non reconnus ne sont pas tous non traduits : annotateurs, clés construites,
assemblages et branches conditionnelles demandent encore une vérification. Les
contenus libres, sorties IA, textes serveur non certifiés, images et états non visités
restent séparés. Aucun contenu privé de joueur n’a été lu.

## Tests et preuves

- 66 contrôles locaux regroupés verts : moteur, catalogues historiques, audit,
  descriptions tactiles, répertoire, forum et Chromium 320/390/1280.
- Neuf langues, français exact, RTL, chaînes longues, repli, brouillons/focus et
  progression préservés ; aucun appel métier, publication ou débit à la bascule.
- Répertoire : 162 situations ; forum : 837 rendus et 351 bascules sur gardes réelles.
- Troisième empire uniquement en fixture ; catalogues propres isolés et paramètres
  nationaux conservés.
- Les 14 tests SSM rendent les mêmes 11 succès et 3 échecs préexistants sur la
  référence main et la branche. Les CI dédiées sont vertes ; aucun échec nouveau.
- Les sept artefacts d’audit ont été reproduits à l’identique ; aucune erreur
  d’extraction. Les sources, empreintes et règles sont conservées avec le rapport.

## Production

Forum : Vercel `dpl_BQV57ujrMBbGZcss1aTqGtHjB7GG` **READY**, commit
`e9989c6e35a35619ff5ae762799754f5d6065ee2`, alias public confirmé. Treize fichiers
publics comparés octet pour octet au code fusionné : identiques. Les deux bancs
Chromium forum et répertoire rejoués sur ces fichiers sont verts : 837 rendus,
351 bascules sur gardes réelles et 162 situations répertoire/courrier.
Empreintes : `LIVRAISON-I18N-871-production.json`.

Pour le socle : Vercel `dpl_ArpbFnCAHRe6XUhSyJgr7qx5W8Fn`, quinze fichiers publics
comparés et banc troisième empire rejoué sans serveur. Pour le répertoire :
`dpl_41cY9NbTN6Fvu7Sua2V4tXEi1wsL`, dix fichiers comparés et Chromium rejoué.
Ces recettes utilisent les fichiers réellement servis, dans un navigateur isolé ;
elles ne constituent pas une session de joueur authentifié.

## Non vérifié et suite

Relecture linguistique native, compte authentifié et téléphone physique non vérifiés.
L’issue #871 reste ouverte pour les prochains lots ; aucun chantier Sovarka, HRP,
rétention ou nouvelle énigme n’est engagé ici. Les domaines encore non confirmés
figurent dans `i18n-global/priorites.json.gz` : ils doivent être audités avant de
traduire pour éviter les doublons et ne pas confondre absence de ressource et
raccordement non reconnu.

Références : `SOCLE-I18N-ORDRES-871.md`, `I18N-REPERTOIRE-COURRIER-871.md`,
`I18N-RETOURS-FORUM-871.md`, preuves JSON associées et `i18n-global/TABLEAU-DE-BORD.md`.
