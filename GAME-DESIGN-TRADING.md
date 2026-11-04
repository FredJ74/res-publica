# Trading de matières premières — décisions de Fred

## Décisions du 31 octobre 2026 (matériels par combinaison)

1. Un ordinateur seul ne sert à rien : ordinateur + box internet = connexion internet.
2. Prérequis de tous les combos ordinateur + box : les installer préalablement dans son **bureau**, c'est-à-dire tout local dont on a la jouissance légale. Le propriétaire peut les désinstaller.
3. La connexion permet le trading de matières premières : connaître les cours dans les villes, commander et payer à distance. Les cours consultés sont **les cours des matières dans les entrepôts** de chaque ville.
4. À distance on ne peut **qu'acheter**, jamais vendre (ce serait de la vente forcée). Les entrepôts n'ont pas un stock illimité.
5. Entre deux États, la marchandise est expédiée **en caisses de fret par les ports industriels** (international, pas encore ouvert). **À l'intérieur d'un État, livraison terrestre** (décision de Fred, 04/11/2026, voir 11). Le stockage ensuite n'a rien de spécifique : le PJ se débrouille (gardiennage au port, ou son propre entrepôt).
6. Le trading se fait **à travers une organisation commerciale** (organisation économique), pas à titre individuel. Les achats sont payés par la caisse de l'organisation ; le chef autorise les membres à trader ; la redistribution de l'argent se règle entre eux, hors code.
7. Un directeur d'entrepôt ou un trader peut passer des **offres d'achat**, servies par les PJ traders comme par les directeurs d'entrepôt (étape 2, à venir).
8. Priorité : le trading doit être en place assez vite.

## Décisions du 3 novembre 2026

9. Le trader doit se trouver **dans son bureau** (là où son ordinateur et sa box sont installés) pour consulter les cours et acheter.
10. Consulter les cours : **0 PA**. Passer un achat à distance : **1 PA** par commande.
11. **Livraison terrestre nationale** (décision de Fred, 04/11/2026, remplace l'envoi par bateau au port de PSM, absurde pour du transport national) : la caisse part le jour même par camion ou train vers l'**Entrepôt Logistique de la ville choisie par le trader** (par défaut celle où il se trouve), **sans droits de douane** ; **six livraisons par jour, tranches de 4 h** (0 h, 4 h, 8 h, 12 h, 16 h, 20 h, heure de Paris ; décision de Fred, 04/11/2026) : une commande passée dans une tranche est livrée à la fin de la tranche suivante (commandée à 7 h, livrée à 12 h) ; arrivée constatée par le serveur à la consultation (`fret_arrivees_constater`, migration `20261104181000`). **Courrier d'arrivée** (décision de Fred, 04/11/2026) : « Votre caisse est arrivée à l'entrepôt de X », envoyé dans la minute qui suit l'échéance tant qu'un joueur est connecté, sinon à la connexion suivante ou à minuit (migration `20261104183000`). Retrait à la **Salle des ventes** de l'entrepôt, ordre « Réceptionner une caisse » (1 PA). Un courrier de l'Entrepôt Logistique indique le lieu et l'heure de disponibilité.

12. Offres d'achat : l'argent est **bloqué dès la publication** (caisse de l'entrepôt pour un directeur, caisse de l'organisation pour un trader).
13. Une offre vaut **7 jours** ; la part non servie revient à la caisse qui l'avait bloquée, au retrait par son auteur ou à l'échéance.
14. Un **directeur** sert une offre depuis le stock de son entrepôt (tableau de bord), payé à la caisse de l'entrepôt. Un **trader** la sert depuis son bureau connecté, avec des matières qu'il a sur lui **ou dans le stock d'un de ses locaux**, payé à la caisse de son organisation. Vente **partielle** admise.
15. Livraison au cron de minuit : dans l'entrepôt si l'acheteur est directeur, en caisse livrée par voie terrestre à l'entrepôt de la ville où se trouve l'auteur de l'offre si l'acheteur est trader (courrier de livraison, 04/11/2026).

## Implémentation (étape 1, 3 novembre 2026)

- Ordre existant « Installer des équipements » des bureaux du centre d'affaires : 2 emplacements à l'origine (3 depuis la décision 18) ; installer / désinstaller son ordinateur et sa box ; bouton « Trading de matières premières » quand les deux sont installés.
- Jouissance légale = bail actif au nom du PJ ou d'une organisation dont il est membre (`locations_actives`).
- Prix et disponibilité : ceux de la vente sur place à l'entrepôt (prix manuel du directeur, sinon prix de référence ; stock moins la réserve militaire).
- Paiement : caisse de l'organisation → caisse de l'entrepôt ; stock de l'entrepôt diminué ; caisse `en_transit` vers l'entrepôt logistique choisi (`p_livraison`, migration `20261104173000`), déjà dédouanée, au nom du trader ; arrivée, retrait et mise en vente à J15 par le cycle existant du fret.
- Chef : « Gérer mes traders » (autoriser / retirer un membre).
- Migration `20261103020000_trading_matieres_premieres` (appliquée le 03/11), banc annulé `outils/bancs/banc-trading-matieres.sql`.

## Implémentation (étape 2, 3 novembre 2026)

- Table `offres_achat` ; `offre_achat_publier` / `_retirer` / `_servir`, `offres_achat_lire`, `offres_achat_expirer_nuit` (étape 5 c du cron de minuit).
- Écran commun « Offres d'achat » (`plateau-equipements.js`) : depuis la fenêtre de trading (trader) et le tableau de bord de l'entrepôt (directeur).
- Migration `20261103030000_trading_offres_achat` (appliquée le 03/11), banc annulé `outils/bancs/banc-trading-offres.sql` (côté trader ; aucun directeur en poste pour éprouver le côté directeur en production).

## Implémentation (étape 3, 3 novembre 2026) — perte de la jouissance du local

16. Décision du 31/10 : si le PJ perd la jouissance du local (bail non valide), il perd la connexion immédiatement et dispose de **48 h pour désinstaller** ; faute de quoi le matériel devient la propriété du **propriétaire foncier**.

- La connexion était déjà coupée dès la perte du bail (`trading_connexion_interne` exige la jouissance).
- Passe de nuit `equipements_jouissance_nuit` (étape 5 d du cron) : la première nuit sans bail valide, le délai est daté et un courrier « Équipement à désinstaller sous 48 h » part au propriétaire de l'équipement ; deux nuits plus tard (48 h), transfert. Si le bail redevient valide entre-temps, le délai est effacé. Le délai court donc à partir de la nuit qui constate la perte du bail.
- Propriétaire foncier résolu comme pour le loyer : lot d'un bien subdivisé → propriétaire actuel du terrain ; tout autre local (bureaux du centre d'affaires) → la commune.
  - PJ : l'équipement reste installé et lui appartient ; il peut le désinstaller sur place (courrier).
  - Organisation : il lui appartient, son chef peut le désinstaller.
  - Commune : saisi par la commune et retiré du local (journal `equipements_saisis`).
- Écran : l'ancien locataire voit l'échéance de son délai à côté de son équipement.
- Migration `20261103040000_trading_equipements_perte_jouissance` (appliquée le 03/11), banc annulé `outils/bancs/banc-trading-perte-jouissance.sql`.

## Décisions du 3 novembre 2026 (option premium des bureaux)

17. Il n'y a **pas de compte premium** dans Human Gambit, mais des **options premium** payantes, achetées une à une.
18. Un bureau offre **3 emplacements** d'équipement en gratuit ; l'option premium en donne **6**. (Remplace les « 2 gratuits / 4 premium » de la première version.)
19. L'option s'achète **pour un bureau donné**, **définitive** tant que l'acheteur garde ce bureau ; elle est perdue avec la jouissance du local. **Gratuite pendant la bêta** (comme la publicité premium), le paiement viendra plus tard.

## Implémentation (option premium, 3 novembre 2026)

- Table `bureaux_option_premium` (acheteur, bureau, `paiement = 'gratuit_beta'`) ; `equipements_emplacements_interne` est le seul endroit qui décide 3 ou 6 (6 si un occupant légal du bureau a activé l'option) ; `equipement_option_premium_activer` (bureau en jouissance, une fois) ; la passe de nuit efface l'option d'un acheteur qui n'a plus la jouissance du bureau.
- Écran : « x / 3 emplacements occupés » et bouton « Activer l'option » (gratuite pendant la bêta) dans la fenêtre des équipements.
- Le paiement réel se branchera dans `equipement_option_premium_activer` (commentaire en place).
- Migration `20261103090000_trading_option_premium_emplacements` (appliquée le 03/11), banc annulé `outils/bancs/banc-trading-option-premium.sql`.

## Reste à faire

- Cours des autres empires et achats internationaux : avec les autres empires.
