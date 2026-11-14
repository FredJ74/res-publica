# #871 — explications complètes des refus de création du personnage

PR #929, suite de #928. Six messages encore français : autre personnage du compte,
nom déjà pris, compte déjà pourvu, genre manquant, session expirée et échec générique.
Leur texte entier est conservé, sans résumé : onze fragments selon les paragraphes
et passages en italique existants, 88 traductions étrangères ajoutées à `connectionUi`.
Les titres et le message d’attente déjà livrés sont réutilisés, sans nouvelle copie.
Les mentions de l’action « Retrouver mon personnage » correspondent au libellé du
bouton existant dans chaque langue. Republia et les valeurs nom/motif sont conservées.

Le rendu marque les seuls textes fixes avec le moteur existant. Les valeurs sont
insérées comme texte dans les paragraphes, jamais interprétées comme HTML ou clé.
Le titre, les sauts de ligne et l’emphase sont conservés ; aucun formulaire ni champ
saisi n’est reconstruit. Si le moteur ou le français de référence manque, le rendu
français original sert de repli. La langue met à jour les marqueurs existants et
ne réexécute ni création, ni vérification, ni écriture du cache métier.

Deux tests Node comparent l’AST entier de creation.js avant/après retrait des seuls
changements de présentation et des six métadonnées, et les onze fragments français
aux appels originaux, HTML de paragraphes/emphase compris. Neuf langues complètes,
variables et ancien catalogue intacts. Les bancs des titres acceptent désormais les
ajouts au catalogue en vérifiant toujours chaque ancienne valeur ; leur preuve
HTML est figée au commit propre du lot, pour ne pas bloquer les chantiers suivants.
Les fixtures navigateur sont partagées et chargent le rendu réel lorsqu’il existe.

Chromium : 270 bascules sur 320/390/1280, six messages et sept parcours comparés à
main, noms/motifs comprenant des balises ou un libellé du jeu, RTL, aucun débordement,
français entier et paragraphes identiques, mêmes appels/cache/verrou/navigation,
aucune requête ou dépense nouvelle, aucune image injectée, valeurs et saisies intactes.
Replis sans traduction allemande, sans source française et sans moteur vérifiés.
432 bascules d’attente/titres et 54 par le vrai sélecteur/récapitulatif passent aussi
avec les nouveaux corps. 43 tests Node ciblés verts.

Les six bancs complémentaires (explications, titres, compte, recherche, confirmation
et connexion) passent : 18 tests au total, dont les vérifications navigateur.
Mesure même extracteur sur main ccad268 et code 1405fcd : corpus inchangé
7 587 textes/50 923 mots ; huit ressources supplémentaires / 126 mots source
dans chaque langue étrangère. Aucun raccordement statique supplémentaire reconnu
pour ces clés choisies par table ; les onze fragments sont prouvés en navigateur,
sans gonfler le taux. Anglais : 24,33 % des mots statiques identifiés, pas de tout
le jeu ; 29,81 % des mots disposent d’une ressource, raccordement à vérifier.
Zéro erreur d’extraction.

CI du code : huit contrôles verts, deux rouges étrangers déjà reproduits sur main
(SSM et inventaires du socle). Contrôles du dernier push, fusion et production
restent à vérifier. Aucun compte ou
personnage réel créé, aucune donnée réelle lue/modifiée, aucune migration ou RPC
modifiée. Pas de revue native ni téléphone physique.
