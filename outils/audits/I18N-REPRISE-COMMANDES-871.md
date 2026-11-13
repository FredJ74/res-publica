# #871 — reprise de commande et titres sur corps opaque

Complément du lot #896 : **deux nouveaux messages fixes**, neuf langues,
**16 nouvelles traductions étrangères**. Le titre existant `naval.notConfirmed`
et ses huit traductions étrangères sont réutilisés sans modification ni copie. La réponse incertaine explique de reprendre
la même commande sans second traitement ; le refus générique et le titre sont
également disponibles. Les français sont ceux du programme d’origine.

La clé du corps est choisie avec les mêmes conditions que le message : transport
incertain, refus sans raison, ou raison variable. Une raison variable est passée
intacte, sans traduction automatique, même si elle contient du texte libre.

## Service commun, pas de second moteur

`RPI18nPlateau.markToast(null, corpsOriginal, undefined, titreOriginal)` marque
seulement le titre connu ; le corps ne reçoit aucun marqueur et ne change jamais.
Le contrôle du texte courant empêche de marquer une notification devenue obsolète.
Les clés texte existantes gardent exactement leur comportement, variables et repli.
Le retour booléen indique un marquage de présentation, jamais une confirmation métier.

Aucun placeholder opaque dupliqué dans neuf langues, aucune réécriture de corps
libre et aucun `showToast` rejoué au changement de langue. La minuterie, les
incidents, les identifiants de commande et les intentions de reprise sont conservés.
Les corps vides restent réellement vides (`:empty`), sans ajout de contenu.

## Preuves

AST entier de la commande identique après retrait des marqueurs ; AST du reste de
`plateau-init.js` identique hors fonction de présentation `markToast`. Aucun RPC,
PA, prix, accès, propriété, bâtiment, PNJ, inventaire ou donnée joueur modifié.
Les preuves de migration sont référencées par commit pour permettre les évolutions
métier futures. Les anciens marqueurs restent vérifiés dans le code courant.

L’audit reconnaît le titre seul et le repli fixe d’un `raison || texte` uniquement
si la condition de choix de clé est exactement la même ; un contre-exemple avec
une autre condition reste non couvert. Le corps opaque n’est jamais compté traduit.
La mesure avant/après utilise ce même extracteur, pas deux méthodes différentes.

Chromium 320/390/1280 : **81 rendus et 81 bascules sur les chemins réels** (réponse
incertaine, refus sans motif, réponse opaque), neuf langues, arabe RTL, repli français.
Corps libre avec caractères HTML conservé exactement, corps vide intact, titre seul,
marqueur obsolète ou clé invalide refusés. Aucun appel métier ou dépense à la bascule.
Le banc précédent conserve ses 270 rendus/bascules ; répertoire et forum également
rejoués pour protéger les autres usages du service commun.

Relecture native, session authentifiée et téléphone physique non réalisés.
Mesure au même extracteur sur main `817d996` et code `70f8b03` : corpus inchangé (7 565 textes / 50 690 mots), +3 textes et +24 mots raccordés par langue étrangère, +2 ressources / 21 mots source. Anglais : 992 textes et 12 057 mots raccordés, soit 23,79 % des mots du corpus identifié. Ce taux technique ne mesure pas les contenus dynamiques inconnus.

31 tests Node finaux, 4 bancs Chromium verts. Les trois échecs SSM sont reproduits sur main (11/14 dans les deux cas). CI et production : relais et PR #902.

## Livraison vérifiée

PR #902 fusionnée : `69a1c0366b625fd14fef67769a7c81a1db8c5f33`. 42 contrôles verts, seul contrôle SSM rouge avec les trois échecs identiques à main. Vercel `dpl_HfQyXpbGHaVEdsej9uXAMMx2mSfo` READY sur ce commit, alias public confirmé ; onze fichiers servis strictement identiques. Deux bancs Chromium rejoués sur ces fichiers : 81 nouveaux rendus/bascules et 270 anciens, verts. Empreintes dans le manifeste de production.
