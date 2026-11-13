# Objectifs, missions et calepin : audit et internationalisation

13 novembre 2026. Base initiale : `main` `517a425a3945e61a2f2ee8c8bba05358ef049198`.
Branche : `codex/i18n-objectifs-carnet-20261113`. PR [#852](https://github.com/FredJ74/res-publica/pull/852). Rebasée sur `main` `7cf66d5f` après #851 ; ajout de son catalogue de biographies préservé dans l’audit commun.

## Références et coordination

Lecture d’AGENTS.md, RELAIS.md, CONSTITUTION.md, architecture, index du référentiel et fiches S-01/S-02 des parcours sociaux, atlas, expérience/rétention, `GAME-DESIGN-ENIGME-MUSEE-LUTHECIA.md`. Les états et récompenses décrits par ces documents ne sont pas redéfinis.

Branches, PR ouvertes et commits examinés avant codage : pas de chantier concurrent sur ces deux écrans. PR #849 fusionnée (`787f256`), vérifiée sur GitHub ; validation SQL des Tsars confirmée explicitement par Fred dans cette mission, sans rejouer de migration. PR #812 (biographies nationales), #805 (informatique), #760 (Aide HRP), chantiers Sovarka de Claude exclus.

## Audit de couverture et lot retenu

| Surface | État au départ | Traitement |
| --- | --- | --- |
| Bouton du panneau personnel « Mes objectifs 🎯 » | Déjà traduit (`personalPanel.myGoals`) | Inchangé |
| Titres, score, confidentialité, six archétypes et 24 objectifs secrets | Français dans `afficherObjectifsSecrets` | Inclus |
| 21 étapes d’accueil dans « Mes objectifs » | 18 consignes françaises distinctes | Inclus ; textes/identifiants sources inchangés |
| Missions criminelle, politique, entrepreneuriale | 9 consignes françaises dans `queteCarriereObjectifActuel` | Inclus dans cet écran uniquement |
| Fenêtres de carrière et scènes Jérémy | Catalogue `jeremy-scenes-resources.js`, banc carrière existant | Inchangés ; pas de nouvelle traduction de ces dialogues |
| Calepin du Portrait disparu | Titre, préfixes, « La parcelle B-127 », « Les témoins » en français | Inclus ; noms des personnages, dates, ordre des cases et noms de lieux conservés |
| Jodie Moitout, appels et mémoire | Lots narratifs existants et banc dédié ; des textes d’appel restent français | Hors lot ; aucune reprise des dialogues ni du déclenchement |
| Valérie, cadre vide, révélation, archives mairie/notaire/presse et leurs refus | Plusieurs textes fixes/narratifs encore français | Hors lot, restent à internationaliser séparément |
| Notifications « Dossier mis à jour », reconnaissance d’objectifs, rumeurs du journal | Français restant | Hors lot ; journal et fonctions de récompense inchangés |
| Missions universitaires | Catalogues et bancs spécifiques | Non modifiés ; cohérence des 28 missions testée |
| Tsars, Ilia, Ouliana et fiches déjà traduites des musées | Catalogues i18n livrés | Inchangés |
| Aide HRP, interfaces propres à Sovarka | Lots indépendants / mission Claude | Inchangés |

**Le lot n’internationalise pas toutes les enquêtes du jeu.** Il couvre un ensemble cohérent d’écrans de suivi sans modifier les récits ni l’ergonomie.

## Implémentation

67 clés dans neuf langues : **603 entrées, dont 536 traductions nouvelles**. Français extrait directement des sources et conservé dans `fixtures/player-missions-fr-20261113.json`. Nombres, devises FR, HP, noms propres, lieux de destination, B-127 et variables restent sémantiquement identiques. Les valeurs des étapes ne sont pas traduites dans le modèle de jeu.

Trois lignes ajoutées aux fonctions d’affichage existantes : elles appellent optionnellement `RPPlayerMissionsI18n.apply()` après le rendu. Aucun autre changement dans les modules métier. Le catalogue reconnaît seulement les chaînes françaises exactes de ces deux écrans et les balise avec `data-i18n` / `data-i18n-values`. **Seul le moteur commun `RPI18nPlateau.apply` traduit** ; aucun moteur ou interpolation concurrente. Le titre est balisé dans ses nœuds enfants, pour ne laisser aucun attribut périmé à une autre fenêtre.

La bascule de langue modifie les mêmes nœuds de texte. Le seul rappel spécifique ajuste `dir` sur le conteneur identifié. Elle n’appelle jamais `afficherObjectifsSecrets`, `verifierObjectifs`, `enigme1AfficherCalepin`, une RPC ou une sauvegarde. Aucun coût, inventaire, récompense, état, condition, profil IA ou migration modifié. L’ouverture initiale des objectifs conserve sa vérification serveur d’origine.

## Vérifications locales

- 3 nouveaux tests : français intégral, 67 clés/9 langues, variables/nombres/devises/noms ; couverture de toutes les consignes réelles ; comparaison des modules métier à main après suppression des trois lignes de présentation, absence de modifications des fichiers protégés.
- 42 tests existants : objectifs secrets (anti-double crédit et réponses tardives), archives du musée, départ de l’énigme, Jodie, quête d’accueil/fiche, carrière i18n, panneau personnel, audit éditorial, douze fonctions Vercel et catalogues universitaires. Tous verts.
- 2 bancs Chromium : **38 situations × 9 langues × 3 formats = 1 026 vérifications de situation/langue/format**, 320×568, 390×844, 1280×900. Français affiché comparé aux fonctions de main, puis retour au français ; progression/PA/inventaire/appels/journal/récompenses inchangés, mêmes nœuds, 67 clés réellement affichées, langues longues, arabe RTL, absence de débordement horizontal, repli d’une traduction supprimée, préservation d’une autre fenêtre et de son brouillon.
- Syntaxe JavaScript et `git diff --check` : verts.

Réponses serveur simulées dans Chromium ; aucun ordre joué sur un personnage réel et aucune requête Supabase pour ce lot. Essai sur téléphone physique et relecture linguistique native non réalisés.

## Comparaison transversale avec main

Sur deux checkouts isolés et avec les mêmes dépendances (dont pglast 7.21), exécution de `node --test outils/bancs/test-*.mjs outils/bancs/banc-i18n-vehicules-garage-20261112.cjs` : **298 tests, 291 réussites et les sept mêmes échecs**, sur `main` `7cf66d5f` comme sur le code rebasé `4fdb9688`. Zéro nouvel échec. Détail reproductible dans `i18n-objectifs-carnet-20261113-preuves.json`.

Sept tests préexistants concernés : version HTML du garage, raccordements de l’audit global Républia, géométrie des galeries, couverture des descriptions Sovarka, assertion des rôles Sovarka, banc des personnalités des musées de province (depuis #851), RPC après lot 219. Aucun de ces chantiers modifié. Une première exécution sans pglast produisait des erreurs de dépendance ; seules les mesures après installation et alignement des dépendances font foi.

Les deux suites GitHub transversales rouges (garage et services sociaux Montrouge) ont aussi été rejouées séparément sur la branche et le même main : 13 tests, 9 réussites, quatre échecs identiques. Le détail est ajouté au JSON de preuves. Elles ne constituent pas une régression du lot.

Garde du payload Vercel : 310,0 Mo, plafond 330,0 Mo, verte.

## Livraison et contrôles restants

Première [CI dédiée](https://github.com/FredJ74/res-publica/actions/runs/43346422292) verte ; 45 tests catalogue/régression puis 2 bancs Chromium. Rebasage retesté (catalogue, Chromium et audit éditorial verts). PR #852 sortie du brouillon. Résultats finaux de CI, fusion et publication suivis dans la description de la PR, avec SHA et état Vercel. La recette de publication réutilise le banc Chromium sur une copie des fichiers réellement servis, via `MISSIONS_ASSET_DIR`, sans appel métier. Aucun déploiement n’est déduit du seul succès d’un commit.
