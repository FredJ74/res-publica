# Refonte des informateurs — consigne intégrale

Décisions de Fred du 19/11/2026, jamais codées, transmises le 21/11 et consignées mot pour mot (anti-perte). À traiter après le lot de Krasnov, en PR à part. À fondre dans GAME-DESIGN-CRIMINALITE.md (section « Barème commun des informateurs », arrivée avec #1169) au moment du codage.

---

Refonte des informateurs (décisions de Fred du 19/11, jamais codées). À traiter après le lot de Krasnov, en PR à part.
1. Supprimer « Recruter un informateur » (150 par jour) et les quatre niveaux d'informateurs recrutés (rue, politique, criminel, taupe), dans tous les pays.
2. Leur rôle passe aux PNJ présents dans les lieux, payés selon le barème commun (GAME-DESIGN-CRIMINALITE.md : Républia 20-29 / 30-44 / 45-50 FR, Sovarka 7-11 / 12-17 / 18-20 PSK). Payer donne toujours une réponse ; la somme en fixe la qualité ; l'argent versé disparaît du jeu ; aucun nom n'est jamais donné, seulement des traits (physiques et sociaux : ville de domicile, nationalité, milieu professionnel, allure), jamais un trait qui désigne une seule personne.
3. Deux profils :
   - spécialiste de lieu (réceptionnistes, serveuses et hôtesses, personnel de l'Assemblée, de la présidence et des mairies, chefs de gare, commandants et directeurs de port, agents de sécurité privée) : rapport sur son lieu (allées et venues des dernières 24 h, cachés exclus, masqués en « individu masqué », une rumeur réelle entendue sur place) ; flou = 1 trait, correct = 2 traits, premier choix = 3 traits dont un social ;
   - généraliste (barmans, habitués de bar) : une seule information au hasard sur toute la ville, au même prix ; flou = information banale ou hors sujet, correct = 1 trait sur le sujet, premier choix = le fait le plus marquant avec 1 trait. Le RP doit rester crédible.
   Spécialistes de sujet dans leur ville : entraîneurs (drogue et addictions), dealers, lobbyistes, dirigeants syndicaux.
4. « Écouter le barman » ne reste pas gratuit : il devient l'ordre payant du généraliste.
5. Non-informateurs : magistrats, policiers et militaires en service, religieux, soignants, notaires et clercs, guides de musée, vendeurs de souvenirs, journalistes hors système.
6. Le commissaire paie aussi selon ces paliers (flou = bonus d'enquête divisé par deux), avec la caisse de son commissariat, et seulement en dernier ressort avec ses fonds propres.
Avant de coder, vérifie dans le dépôt ce qui existe déjà de ces règles, et consigne l'ensemble dans GAME-DESIGN-CRIMINALITE.md.

---

Note de Claude (21/11) : l'habitué du Bar Sever de Krasnov (#1169, lot de Krasnov point 8) applique déjà le barème commun (fonction serveur `informateur_palier_interne`). Il devra rejoindre le profil « généraliste » lors de la refonte, en gardant sa piste vers le colonel Voronov au premier choix.

Note de Claude (22/11) : consigne codée (étape K, branche `claude/informateurs-refonte-20261122`, migration `20261122180000_informateurs_refonte`, non appliquée) et fondue dans GAME-DESIGN-CRIMINALITE.md, section « Barème commun des informateurs » → « Refonte des informateurs ».

### Acheter une information en cliquant sur le PNJ (Fred, 23/11/2026)

Décisions complètes : `GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md`. Point 24. Pour **tous** les informateurs, l'achat se fait en cliquant sur le PNJ (« Acheter une information ») ; l'ordre de pièce « Acheter une information » disparaît. L'habitué du Bar Sever (point 25) offre un verre une fois par jour ; le bouton « Lui offrir un verre » (7 à 20 PSK) déclenche l'information ; l'ordre « Offrir un verre à l'habitué » disparaît.
