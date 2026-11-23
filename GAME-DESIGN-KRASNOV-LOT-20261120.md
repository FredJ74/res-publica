# Lot de Krasnov (1re partie) — consigne intégrale

Feu vert de Fred le 20/11/2026. Consigné mot pour mot avant tout code (étape 0, anti-perte). À prendre après #1156, #1157 et les deux chantiers précédents (organisations secrètes, distillerie).

---

LOT DE KRASNOV (1re partie) : feu vert de Fred le 20/11. À prendre après #1156, #1157 et les deux chantiers précédents (organisations secrètes, distillerie).

ÉTAPE 0, ANTI-PERTE, AVANT TOUT CODE : consigne l'intégralité de ce message dans GAME-DESIGN-KRASNOV-LOT-20261120.md, commité seul, PR à part fusionnée tout de suite. Fusionne aussi #1158 (image seule, pas de contrôle long).
Pour chaque point, vérifie d'abord dans le code s'il est déjà fait.

1. FORÊT DES BÛCHERONS : un ours tué donne en plus 10 pots de graisse d'ours (avec viande, peau, 2 dents). Matière brute.

2. MARCHÉ DE KRASNOV : nouvelle interface unique
- Une fenêtre avec la liste des produits et trois colonnes : Acheter / Vendre / Produire. Saisie de quantités, boutons Annuler et Valider (plusieurs actions en un clic). Totaux en direct (PSK dépensés et gagnés, PA). Valider grisé avec infobulle explicative si la caisse du marché est vide ou si les PA, l'argent ou le stock manquent. Rien n'est exécuté à moitié.
- Vendre : ouvert pour TOUS les produits, objets compris (ex. un masque revendu entre dans le stock et débite la caisse du marché). Rachat par un commerce PNJ = prix de vente moins 25 %. Dans les commerces de PJ, le commerçant fixe lui-même son prix de rachat (inchangé).
- Produire : seulement pour les transformés. La fabrication puise dans le stock du marché et y verse les produits. Le fabricant touche 15 PSK par PA, payés par la caisse du marché. Caisse : dotation de départ.
- Prix des transformés = (matières, environ 2 PSK chacune + PA à 15 PSK) réparti sur les unités, puis ×2.
- Recettes : confiture = 1 fruit et légume + 1 sucre + 1 PA → 4 bocaux, 10 PSK, effet 1 PA cumulable avec un repas brut. Pain noir = 1 céréale + 1 bouteille d'eau + 1 PA → 5 pains, 8 PSK, effet 1 PA au prochain Dormir (repas, non cumulable avec un repas brut). Portion de goulash = 1 fruit et légume + 1 poisson + 1 PA → 3 portions, gain de 2 PA. Chemise de bûcheron = 1 textile + 1 PA → 2 chemises, 18 PSK, se porte avec « Revêtir » : +1 ENT tant qu'on est à Krasnov, effet perdu si l'on revêt la tenue ninja ou le gilet.
- Bruts : fruits et légumes ; œufs vendus et consommés par 3 (le lot compte pour 1 unité, 2 PSK au rachat) ; volaille = matière « viande », 3 PSK ; graisse d'ours vendue 16 PSK (rachat 12) ; tenue ninja et masque de carnaval aussi en vente. Produits bruts consommés = 1 PA au prochain Dormir.
- Le guide des baies sauvages n'est plus vendu au marché (il passe au musée, voir 7).
- Portrait de Nina Gorbounova à descendre légèrement.

3. EAU : un seul objet, la bouteille d'eau (sert aussi à la canicule). Puisée gratuitement à une fontaine, 8 bouteilles par PA, vendue 2 PSK. Une fontaine par ville sur une vue existante, à Krasnov sur la place de l'Ours.

4. KOLKHOZE S. M. KIROV : caisse commune ergonomique, avec saisie des quantités de chaque matière puis un seul ordre « Donner ».

5. COMMISSARIAT : brigadier de garde Matveï Doubov (remplace « Brigadier Local ») ; le commissaire Egor Tikhonov, interrogé sur la tête d'ours de son bureau, parle de la chasse à l'ours, du gain et du danger ; nouveaux textes de l'accueil, du bureau du commissaire et des geôles validés le 19/11 (retrouve-les dans le dépôt ; s'ils n'y sont pas, signale-le, n'invente pas). Accents manquants dans les ordres et « Securite » à corriger.

6. STADE ÉTOILE ROUGE : tenancière de la buvette Avdotia Doubova (femme du brigadier) ; entraîneur adjoint Pavel Zapasnoï (nouveau PNJ) ; textes du terrain et de la buvette validés le 19/11 (même consigne) ; la buvette garde « Vendre des matières au commerce » ; club des supporters : plus de boycott en Sovarka, manifestation uniquement « en faveur », cible au choix (président du club ou maire), même mécanisme que la manifestation syndicale de Sovarka, y compris la perte de POP sous 50 %.

7. ÉCOLE ET ÉNIGME DE KRASNOV
- Supprimer les ordres copiés de l'université (conférence, recruter des militants, formation). Nouvel ordre « Stage de survie en forêt », dispensé par l'institutrice Alevtina Gramotova : +4 VOL pendant 24 h, 3 PA + 25 PSK versés à la mairie.
- Guide des baies sauvages : lecture 2 PA, +1 INT pendant 24 h, une fois par semaine ; vendu au musée de Krasnov (prix fixé lors du passage au musée, mets une valeur provisoire signalée).
- Feuille volante glissée dans chaque guide : objet d'inventaire échangeable, qui ne disparaît jamais. Elle porte l'énigme et une recette polycopiée incomplète (eau pure, myrtilles, un œuf, vodka, ingrédient effacé). Indice : cet ingrédient servait parfois pur à éloigner les ours des essaims sauvages. La résolution est attachée au personnage, pas à la feuille ; la feuille n'est utilisable dans l'armoire aux souvenirs que si l'énigme est résolue.
- Pop-up au démarrage : « Ici commence l'énigme de Krasnov : saurez-vous la résoudre… ? » (pop-up générique, même formule pour chaque ville).
- Chaîne : avant le démarrage, Alevtina oriente vers le musée et le guide ; l'apicultrice Praskovia Pakhomova raconte que son père utilisait ce produit secret contre les ours, qu'un ours a ravagé le rucher l'année où il en manquait, et qu'il est revenu des bois le visage lacéré avec 10 bocaux ; elle montre son bocal presque vide à ficelle (image #1158) ; Kouzma, après avoir bu, lâche que le père se serait évité cette peine en allant au marché ; au marché, on reconnaît le même bocal et la même ficelle, et Nina dit qu'un ours donne 10 pots de graisse ; le directeur du musée, consterné, déclare que l'organisation n'a plus lieu d'exister et envoie le PJ l'annoncer à l'institutrice, qui s'effondre : « alors notre lutte est vaine, il ne reste plus qu'une chose à espérer : que l'on puisse continuer à manger du miel ». Solution : la graisse d'ours.
- **Mise à jour du 23/11/2026 (Fred, mission Novomirsk, point 29)** : le directeur du musée est **supprimé**. C'est le guide **Arkadi Pamiatnikov** qui reçoit la solution (dans sa fenêtre « Écouter le guide », le serveur juge toujours) et qui, consterné, envoie le PJ chez l'institutrice. L'ordre « Soumettre la solution de l'énigme au directeur » est supprimé ; le carnet dit « Soumettez votre solution au guide du musée. » Décision complète : `GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md`.
- Au bar, les habitués : « À Krasnov, on a les plus belles femmes du pays ! Elle n'est pas belle notre Miss ? Et intelligente ! Elle enseigne à l'école ! »
- Énigmes résolues : une distinction et une liste sur le personnage, dans la colonne de droite de l'inventaire.

8. RADAR (CENTRE D'ÉCOUTE)
- Le colonel Gleb Voronov vend le polonium sous le manteau : 150 PSK, 2 PA, 50 % de réussite. L'ordre reste caché tant que le PJ n'a pas l'information, puis est acquis définitivement. Sources : l'habitué du bar de Krasnov (selon les paliers d'informateur), Kalachnikov à Novomirsk, Ganbaatar Tsybikov à Starovka (indigné, « je ne suis pas une balance »). Phrase de passe : « Demander au colonel des nouvelles de notre ami de Luthécia ». Échec : « Je ne connais personne à Luthécia, camarade ». Échec critique (jet 98-100) = dénonciation. Trace exploitable contre l'acheteur seulement (le commissaire ne peut pas enquêter sur le colonel). Kalachnikov reste un point de vente.
- Carnet privé « Contacts et secrets » dans la colonne de droite de l'inventaire, visible du seul joueur ; le colonel en est la première entrée.
- Salle d'écoute, nouveau texte : « Cinq téléphones : une ligne pour Luthécia, une pour la Républia, une pour El Estado, une pour Al-Khalija… et la rouge, pour Novomirsk. Personne ne sait vraiment qui décroche à l'autre bout, mais le colonel Voronov prend des notes. Le caporal Sorokine branche les fiches du standard. » Retouche de l'image : étiquettes « Эль-Эстадо » et « Аль-Халиджа » (si tu ne peux pas retoucher proprement, signale-le, Fred fournira l'image).
- Vol dans les archives d'écoute : il suit les règles communes du vol (DIS du voleur contre PER de l'opérateur Sorokine, +15 carrière criminelle, échec inaperçu à 50 % sinon repéré, 10 % de vrai combat, arrestation si perdu). Pas de bonus de lieu : la difficulté d'un vol ne vient que des personnes présentes. Bug à corriger : les PA de l'arrestation n'apparaissent pas dans le journal.

9. ACTIONS DE PIÈCE (tous les lieux)
- « Fouiller ou voler » devient « Inspecter la pièce ».
- « Voler quelqu'un » en sort (doublon avec la fenêtre de rencontre).
- Fouiller les lieux + débusquer = un seul ordre à 1 PA qui révèle une personne cachée ou une caméra (conserver le journal du débusqué de #1156).
- « Emporter ce qu'il y a ici » remplacé par « Désinstaller du matériel » : liste du matériel installé, 2 PA par matériel ; l'objet tombe au sol, n'est plus lié à la pièce et se ramasse sans PA. Légal chez soi et dans le local d'une organisation dont on est membre ; ailleurs, acte illégal soumis aux règles communes du vol (jet contre les présents, trace, plainte possible).
- « Se cacher » n'est plus que dans les actions de la pièce (à côté d'Inspecter) ; on supprime le bouton de la fiche personnelle.

10. FIN DE TOUR (images, à faire quand Fred les fournira) : rue du commissariat, avec un drapeau propre à Sovarka à la place du drapeau russe et l'enseigne « МИЛИЦИЯ » au lieu de « ПОЛИЦИЯ ».

Nouvelles clés de traduction listées dans RELAIS pour Codex. Rapport par point (fait / déjà fait / bloqué), PR thématiques. J'ouvre les PR depuis claude.ai si l'API te refuse.
