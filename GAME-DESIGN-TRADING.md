# Trading de matières premières — décisions de Fred

## Décisions du 31 octobre 2026 (matériels par combinaison)

1. Un ordinateur seul ne sert à rien : ordinateur + box internet = connexion internet.
2. Prérequis de tous les combos ordinateur + box : les installer préalablement dans son **bureau**, c'est-à-dire tout local dont on a la jouissance légale. Le propriétaire peut les désinstaller.
3. La connexion permet le trading de matières premières : connaître les cours dans les villes, commander et payer à distance. Les cours consultés sont **les cours des matières dans les entrepôts** de chaque ville.
4. À distance on ne peut **qu'acheter**, jamais vendre (ce serait de la vente forcée). Les entrepôts n'ont pas un stock illimité.
5. La marchandise est expédiée **en caisses de fret par les ports industriels** des États. Le stockage ensuite n'a rien de spécifique : le PJ se débrouille (gardiennage au port, ou son propre entrepôt).
6. Le trading se fait **à travers une organisation commerciale** (organisation économique), pas à titre individuel. Les achats sont payés par la caisse de l'organisation ; le chef autorise les membres à trader ; la redistribution de l'argent se règle entre eux, hors code.
7. Un directeur d'entrepôt ou un trader peut passer des **offres d'achat**, servies par les PJ traders comme par les directeurs d'entrepôt (étape 2, à venir).
8. Priorité : le trading doit être en place assez vite.

## Décisions du 3 novembre 2026

9. Le trader doit se trouver **dans son bureau** (là où son ordinateur et sa box sont installés) pour consulter les cours et acheter.
10. Consulter les cours : **0 PA**. Passer un achat à distance : **1 PA** par commande.
11. La marchandise part le jour même en caisse de fret vers le **port industriel de Port-Sainte-Marie** (le port industriel de la Républia) et arrive au cron de minuit, **sans droits de douane** : elle ne quitte pas la Républia.

12. Offres d'achat : l'argent est **bloqué dès la publication** (caisse de l'entrepôt pour un directeur, caisse de l'organisation pour un trader).
13. Une offre vaut **7 jours** ; la part non servie revient à la caisse qui l'avait bloquée, au retrait par son auteur ou à l'échéance.
14. Un **directeur** sert une offre depuis le stock de son entrepôt (tableau de bord), payé à la caisse de l'entrepôt. Un **trader** la sert depuis son bureau connecté, avec des matières qu'il a sur lui **ou dans le stock d'un de ses locaux**, payé à la caisse de son organisation. Vente **partielle** admise.
15. Livraison au cron de minuit : dans l'entrepôt si l'acheteur est directeur, en caisse de fret au port industriel de PSM si l'acheteur est trader.

## Implémentation (étape 1, 3 novembre 2026)

- Ordre existant « Installer des équipements » des bureaux du centre d'affaires : 2 emplacements (version gratuite) ; installer / désinstaller son ordinateur et sa box ; bouton « Trading de matières premières » quand les deux sont installés.
- Jouissance légale = bail actif au nom du PJ ou d'une organisation dont il est membre (`locations_actives`).
- Prix et disponibilité : ceux de la vente sur place à l'entrepôt (prix manuel du directeur, sinon prix de référence ; stock moins la réserve militaire).
- Paiement : caisse de l'organisation → caisse de l'entrepôt ; stock de l'entrepôt diminué ; caisse de fret `en_transit` vers `port-sainte-marie`, déjà dédouanée, au nom du trader ; arrivée, retrait et mise en vente à J15 par le cycle existant du fret.
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

## Reste à faire

- Cours des autres empires et achats internationaux : avec les autres empires.
- Premium : 4 emplacements au lieu de 2. **Non codable pour l'instant** : le jeu n'a encore aucun statut de compte premium (aucune donnée ni fonction serveur ne dit qui est premium ; les offres premium existantes sont gratuites en bêta ou « Bientôt disponible »). Le serveur répond aujourd'hui `emplacements: 2` à un seul endroit (`equipements_local_lire`, `equipement_installer`) : il suffira d'y lire le futur statut premium.
