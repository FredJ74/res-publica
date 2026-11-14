# #871 — paramètres d’organisation

PR #947. Seule ouvrirOptionsOrga change : quinze clés et 120 traductions étrangères renseignées pour le titre, les labels, l’exemple de devise, l’aperçu, le choix d’image, les formats/limite, la sauvegarde, la visibilité et la dissolution. Aucune correspondance française exacte trouvée dans le registre chargé ; pas de traduction existante dupliquée. « — ou — » est identique en français/portugais brésilien : identité correcte documentée, pas texte manquant.

Français exact, y compris les graphies Parametres / VISIBILITE / Rendre secrete. Nom, devise et URL du joueur jamais traduits. Le libellé de choix de fichier est un span enfant : le moteur commun ne remplace pas le label contenant l’input. Champs dir:auto, classe mobile existante. Titre en span détruit par les autres fenêtres, pas de moteur ni callback supplémentaire. Sauvegarde, upload, validation des fichiers et seuils, prévisualisation, visibilité, dissolution et droits strictement intacts par comparaison AST du fichier entier hors fonction de présentation ; les cinq premières instructions métier de cette fonction restent identiques.

## Tests

125 tests Node ciblés verts et 123 anciens correspondants verts sur main 38b6978. Quinze français exacts/neuf langues, formats PNG/JPG/JPEG/WEBP et nombre 2 inchangés. Chromium : quatorze états couvrant les neuf types, les deux visibilités criminelles, le type inconnu et les refus ; plus saisie URL et vrai fichier PNG choisi via l’input. 432 bascules en neuf langues et 320/390/1280, quinze clés effectivement exercées. Français entier/contrôles/handlers/droits comparés à main ; champs, curseur, focus, sélection de fichier et objet File d’origine préservés ; aucune lecture, sauvegarde ou upload par bascule. Clic et clavier envoient les mêmes arguments une seule fois à des espions ; aucune écriture réelle. Fermeture répétée, autre fenêtre, repli français, RTL et absence de débordement vérifiés. Quatre anciens bancs également verts : adhésions 513, membres 243, formulaires 756, tableau 999 ; total cinq bancs/2 943 bascules.

Comparaison transverse : mêmes 27/31 main/branche ; trois SSM et une assertion sur deux descriptions de salle électorale de Krasnov, hors catalogue Sovarka. Aucune modification de ce catalogue ou de fonctionnalité Sovarka. Payload déjà rouge sur main 38b6978 : 348 380 191 octets, branche 348 386 316 (+6 125 octets propres), soit 332,2 Mo pour un plafond déclaré de 330 Mo. Ni images ni plafond touchés.

## Mesure à extracteur identique

Base 38b6978/code 8c6033c9. Corpus commun de 7 589 textes / 50 907 mots : +12 textes/+42 mots raccordés dans sept langues étrangères ; portugais +11/+41, car l’identité correcte « — ou — » reste volontairement non certifiée par la règle statique stricte. Mêmes gains de ressources disponibles à corpus commun. Trois fragments nouveaux (Parametres, Rendre secrete, Rendre visible), cinq mots ; une ancienne concaténation de titre resegmentée, aucun retrait français (comparaison navigateur). Corpus 7 590/50 908 → 7 592/50 912. Anglais : 1 059 textes/12 551 mots raccordés, 24,65 % des mots statiques identifiés, pas du jeu entier. Zéro erreur d’extraction ; détails et écarts dans le JSON.

CI finale, fusion et production à vérifier. Pas de données joueur réelles lues/modifiées, pas de recette PJ authentifié, téléphone physique ni validation par des locuteurs natifs.
