# Descriptions des ordres accessibles au toucher

13 novembre 2026. Base `main` `4d44222` (PR #853). Branche `codex/ordres-info-tactile-20261113`.

## Audit et décision

AGENTS.md, RELAIS.md, référentiel de navigation/accessibilité, rendu `renderRoomActions`, contrôleur mobile, styles et bancs existants examinés. PR ouvertes et main vérifiés : pas de doublon ; #853 intégrée. Claude conserve son chantier de traduction des 205 descriptions communes. Aucun catalogue i18n de ce lot n’est modifié.

Fred a retenu explicitement le bouton d’information « ⓘ », sans appui long, avec retour immédiat à l’interface précédente. Ce document ne décide ni règle ni prix.

## Rendu et isolation

- En présence d’un pointeur tactile (`any-pointer: coarse`), ajout d’un vrai bouton frère à chaque `.action-btn` portant une infobulle ou un descripteur d’ordre. Le bouton métier demeure le même nœud, avec le même handler, les mêmes attributs d’accès et les mêmes coûts. Un ordre `disabled` garde un bouton d’information actif.
- Sur bureau sans pointeur tactile : aucun bouton ni conteneur ajouté. Rendu, titres et paramètres du clic comparés au main initial dans les neuf langues.
- Dialogue HTML natif séparé des `.modal-overlay` : ne remplace ni ne ferme la fenêtre sous-jacente ; arrière-plan rendu inerte par le navigateur. Fermeture par bouton, Échap ou fond ; retour du focus et des positions de défilement. Le piège clavier mobile existant ne reçoit pas Tab/Échap pendant ce dialogue.
- La description reprend l’infobulle actuelle. Pour les infobulles remplacées par un refus, le descripteur conserve aussi les détails déjà calculés (description, gains, risques et réussite disponibles). Quelques refus dont le motif n’était présent qu’au clic conservent leur texte existant dans un champ de présentation. Aucun handler de refus n’est exécuté pour l’obtenir.
- Langue : API `RPSovarkaInfobullesI18n` de #853 et clés existantes `plateau.description` / `plateau.closeButton`, rafraîchies après les libellés et infobulles. Aucune interpolation ni moteur concurrent. Les textes non encore traduits restent en français. Les traductions et leurs catalogues restent le domaine de Claude.
- Contenu inséré avec `textContent`, sans exécuter de HTML venant des descriptions. Source retirée : fermeture de l’information devenue périmée. Nouvelles listes ou sous-menus : boutons ajoutés après leur apparition.

Pas de modification des fonctions exécutant les ordres, tarifs, PA, devises, probabilités, conditions, droits, RPC, données des personnages ou migrations. Le descripteur reprend les nombres déjà employés par l’infobulle, sans calcul supplémentaire.

## Vérifications

- **35 tests ciblés verts** : source limitée à la présentation, catalogues protégés, infobulles et salon de Claude, libellés/paramètres des ordres, présentation mobile, objectifs et anti-double crédit, double tap Helvetia, audit éditorial, douze fonctions Vercel.
- **8 bancs Chromium verts** : nouveau parcours tactile 320/390 px dans neuf langues (8 cas dont disabled, absence de description, gratuit/payant, bloqué et poste requis), bureau 1280 comparé à main, plus les 6 tests navigateur existants des infobulles/salon et transitions/scroll. Vrai renderer, vrai moteur i18next, CSS réels et vrai `plateau-mobile.js` ; transports et doOrder instrumentés. Aucune requête ou dépense sur les ouvertures/fermetures ; clic principal = exactement un appel avec les arguments d’origine.
- Ouvertures répétées et double clic synthétique sur l’information, Entrée/Tab/Échap, langue pendant la lecture, RTL, russe/allemand, absence de débordement horizontal, brouillon et fenêtre précédente conservés, retour du focus, listes renouvelées et fermeture de source disparue.
- Tous les `test-*.mjs` et le banc garage : **308 tests, 304 verts et quatre échecs identiques sur main et la branche**. JSON de preuve associé. Aucun nouvel échec.
- Commerce unifié : 34 tests, 19 verts, 15 échecs dans les décors existants ; même résultat sur main. Aucun correctif métier effectué.
- Coque mobile historique : comparaison main en cours au premier commit ; ne pas considérer ses échecs comme nouveaux sans contre-épreuve.

Téléphone physique et lecture avec un lecteur d’écran humain non réalisés. Les tests vérifient les rôles/noms de dialogue, le focus et le clavier ; aucune partie authentifiée exécutée.

## Livraison

CI dédiée `.github/workflows/ordres-info-tactile.yml`. PR, fusion, publication et contrôle des fichiers servis à renseigner dans la PR ; aucun déploiement annoncé à ce stade. Le banc navigateur accepte `ORDER_INFO_ASSET_DIR` pour rejouer la recette sur les fichiers téléchargés du déploiement.
