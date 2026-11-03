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

## Implémentation (étape 1, 3 novembre 2026)

- Ordre existant « Installer des équipements » des bureaux du centre d'affaires : 2 emplacements (version gratuite) ; installer / désinstaller son ordinateur et sa box ; bouton « Trading de matières premières » quand les deux sont installés.
- Jouissance légale = bail actif au nom du PJ ou d'une organisation dont il est membre (`locations_actives`).
- Prix et disponibilité : ceux de la vente sur place à l'entrepôt (prix manuel du directeur, sinon prix de référence ; stock moins la réserve militaire).
- Paiement : caisse de l'organisation → caisse de l'entrepôt ; stock de l'entrepôt diminué ; caisse de fret `en_transit` vers `port-sainte-marie`, déjà dédouanée, au nom du trader ; arrivée, retrait et mise en vente à J15 par le cycle existant du fret.
- Chef : « Gérer mes traders » (autoriser / retirer un membre).
- Migration `20261103020000_trading_matieres_premieres` (appliquée le 03/11), banc annulé `outils/bancs/banc-trading-matieres.sql`.

## Reste à faire

- Étape 2 : offres d'achat (décision 7).
- Perte de la jouissance du local : perte immédiate de la connexion (déjà vrai), puis 48 h pour désinstaller faute de quoi le matériel revient au propriétaire foncier (décision du 31/10, non codée).
- Cours des autres empires et achats internationaux : avec les autres empires.
- Premium : 4 emplacements au lieu de 2 (annoncé à l'écran depuis l'origine, non codé).
