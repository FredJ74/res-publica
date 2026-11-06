# Véhicules personnels, garage et station-service — décisions de Fred

Décisions explicites de Fred, 5 novembre 2026 (tour de Novomirsk, vue 11 : Garage).
Socle commun à tous les empires ; le garage de Novomirsk et la station de Krasnov
sont les **seuls commerces PNJ** de ce type : ils servent d'exemple, ce sont les PJ
qui ouvriront les autres (même logique que l'agence Grobras pour la sécurité privée).

## À quoi sert un véhicule

- Se déplacer **entre les villes d'un même pays**, à la place du train, du bus ou
  du taxi du centre multimodal. **Jamais entre deux pays.**
- Départ : **de n'importe quel endroit** d'une ville. Arrivée : **devant le centre
  multimodal / la gare** de la ville choisie.
- Réseau routier : en Républia, toutes les villes sont reliées. En Sovarka,
  **seulement Novomirsk ↔ Krasnov** ; Starovka est inaccessible par la route.
- Un trajet coûte **1 PA à chaque occupant** (conducteur et passagers), contre
  2 PA et 75 FR par personne pour le train.
- **Peut conduire quiconque possède une clé** du véhicule (socle des serrures :
  clés et doubles, voir `GAME-DESIGN-SERRURES.md`).

## Les trois modèles (catalogue : `voiture`, `deux-roues`, `vehicule-utilitaire`)

| Modèle | Places | Chargement | Réservoir | Recette | PA | Prix PNJ |
|---|---|---|---|---|---|---|
| Voiture | 4 | 150 | 18 | 300 métal, 200 textile, 300 dérivés pétrochimiques | 190 | 42 000 FR |
| Deux-roues | 2 | 50 | 12 | 150 métal, 100 textile, 150 dérivés pétrochimiques | 95 | 21 000 FR |
| Utilitaire | 3 | 500 | 25 | 450 métal, 100 textile, 250 dérivés pétrochimiques | 255 | 50 000 FR |

- Prix fixés par Fred (voiture 42 000, utilitaire 50 000, deux-roues = voiture ÷ 2) ;
  les PA sont déduits par la **règle existante** des commerces PNJ : prix = 2 × coût
  de revient, 1 PA = 50 FR, matières au prix de référence (métal 15, textile 5,
  dérivés pétrochimiques 20). Le plastique de la voiture **est compté en dérivés
  pétrochimiques** (pas de nouvelle matière).
- En plus du chargement du véhicule, **chaque PJ porte 100 unités sur lui**.

## Carburant

- Le carburant **existe déjà** (raffinerie de Montrouge, `RESSOURCES_ECONOMIE.carburant`,
  référence 20 FR, prix de gros 10 FR).
- Il s'achète **à la station-service ou en bidons**. **1 bidon = 1 unité de carburant
  = 1 unité de transport.** Faire le plein d'une voiture = verser 18 bidons.
- Consommation d'un trajet entre deux villes : **10 unités + 1 unité par tranche de
  50 unités de chargement** (même règle pour les trois modèles). Ex. utilitaire plein
  (500) : 20 unités.
- **Voulu par Fred** : aucun réservoir ne permet deux trajets sans refaire le plein ;
  il faut trouver du carburant à l'arrivée ou en emporter en bidons.
- **Prix** : la station s'approvisionne au **prix de gros (10 FR)** ; un commerce PNJ
  vend le bidon **20 FR** (règle ×2). Une station de PJ fixe son prix (plafond ×4 du
  coût de revient), la concurrence peut le faire baisser. Seul, la voiture coûte plus
  cher que le train mais économise 1 PA et transporte ; dès 3 occupants elle gagne
  sur tout.

## Révision et pannes

- Une révision **tous les 10 trajets** ; elle consomme **10 dérivés pétrochimiques
  et 1 PA**, soit **500 FR** dans un garage PNJ (règle ×2). Vaut pour les trois modèles.
- Risque de panne selon le nombre de trajets depuis la dernière révision :
  trajets 1 à 9 : aucun ; 10e : 50 % ; puis +10 % par trajet (11e 60 %, 12e 70 %,
  13e 80 %, 14e 90 %) ; au **15e, le véhicule ne démarre plus**. Tirage serveur.
- **Panne en route** : pop-up avec l'image d'une voiture en panne, capot ouvert,
  « Vous êtes en panne ! », « Vous n'avez d'autre choix que d'appeler un dépanneur. »,
  « Le garage le plus proche est … » avec les **garages existants (PNJ ou PJ) des deux
  villes du trajet**. Le **conducteur choisit** ; le dépannage coûte **450 FR** et
  ramène véhicule et occupants dans la ville du garage choisi.
- Si **aucune des deux villes n'a de garage** : la pop-up propose les garages du reste
  du pays, dépannage **600 FR** (450 + 150 de surcoût).
- Le dépannage **ne remplace pas la révision** : il faut encore la payer avant de
  repartir (« Ça fait réfléchir, non ? »).

## PNJ

- Garage de Novomirsk : **Sergueï Zaptchastov** (*запчасти*, pièces détachées).
- Station-service de Krasnov : **Lioudmila Zapravkina** (*заправка*, station-service).

## Socle technique retenu (choix de l'agent)

- Pas de nouveau moteur : le véhicule reprend le modèle du **camion militaire**
  (`plateau-camion-militaire.js`) — objet serveur avec position, occupants qui suivent
  le conducteur par le socle des groupes ; le trajet passe par le moteur de transport
  existant. Toute consommation, tout tirage de panne et tout débit sont serveur.

## Implémentation (Claude, 5 novembre 2026)

- **Serveur** (migrations `20261105222000` à `20261105222300`, appliquées, banc annulé
  `outils/bancs/banc-vehicules.sql` vert) : `vehicules_modeles`, `routes_vehicules` (réseau déclaré
  par empire, aucun repli), `vehicules` (bien localisé, carburant, cargaison, trajets depuis la
  révision, panne) ; la clé est une serrure de cible `vehicule` (doubles par `cle_dupliquer`).
  Une seule porte : `vehicule_acte(requete, action, paramètres)` — `acheter`, `carburant`, `plein`,
  `charger`, `decharger`, `trajet`, `depanner`, `reviser` — et la lecture `vehicules_lire()`.
  Le trajet reprend les gardes du moteur de transport (chef de groupe, groupe complet et réuni,
  disponibilité, surcharge à 100 unités par PJ) et le socle des groupes pour les PNJ.
- **Panne** : PA et carburant du trajet sont dépensés, personne n'arrive ; le véhicule reste
  « en panne » tant que le conducteur n'a pas appelé un dépanneur. Le dépannage ramène le véhicule
  et le groupe présent avec le conducteur au garage choisi (devant le centre multimodal si ce garage
  n'est pas un lieu déclaré) et laisse le véhicule « à réviser » (il ne démarre plus avant la révision).
- **Révision** : consomme 10 dérivés pétrochimiques du stock du garage ; le garage les rachète aux
  joueurs (« Vendre des matières au garage »). Garage PNJ : 500.
- **Bidons** : un bidon est une unité de la pile `carburant` de l'inventaire (la même matière que celle
  de la raffinerie). La station rachète le carburant et le conditionne par dix (0 PA).
- **Stock de départ** du garage de Novomirsk : 3 voitures, 3 deux-roues, 2 utilitaires, 100 dérivés ;
  station de Krasnov : 200 bidons.
- **Écran** : `plateau-vehicules.js` ; ordres `garage_vehicules`, `garage_reviser`, `station_carburant`,
  `mes_vehicules` (aussi depuis la fiche du personnage, « Mes véhicules »).

## Fabrication au garage — décision de Fred (6 novembre 2026)

- **Durées** : voiture **10 jours**, utilitaire **15 jours**, deux-roues **5 jours**.
- **Même principe que les bâtiments et les bateaux** : un PJ peut fournir la main-d'œuvre de la
  journée, sinon ce sont les PNJ qui s'en occupent.

Mise en œuvre (choix de l'agent, migrations `20261105233000` et `20261105233100`, appliquées ; banc
annulé `outils/bancs/banc-vehicules-fabrication.sql` vert) :
- Tout PJ présent lance une fabrication (règle de production du 01/11 : place sous le plafond de stock
  fixé par le propriétaire) ; **un véhicule à la fois** par garage.
- La main-d'œuvre totale est le PA de la recette (95 / 190 / 255), répartie jour par jour, de même que
  les matières (aucune unité perdue).
- « Travailler » : le PJ présent donne des PA de la journée en cours, payés **50 par PA** par la caisse
  du garage, sans dépasser le besoin du jour.
- À minuit, si les matières du jour sont au stock du garage et que sa caisse paie le reste de la journée
  aux ouvriers PNJ (50 par PA), la journée avance ; sinon la fabrication attend, sans jour perdu, et le
  travail déjà fourni par les PJ reste acquis. Le dernier jour, le véhicule entre en vitrine.
