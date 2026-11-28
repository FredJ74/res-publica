# Ciudad Roja, capitale d'El Estado (décisions de Fred, 27 et 28/11/2026)

> **Principe de contraste (Fred, 28/11/2026), qui guide tous les ajouts futurs dans ces empires.**
> Al-Khalija revendique une morale irréprochable mais s'arrange en douce avec elle (le whisky dans la théière, le
> passage forcé contre un jour de chambre). **El Estado est un empire complètement décadent et corrompu, où l'on est
> pourtant très pieux.** Voir aussi `GAME-DESIGN-AL-MADINA.md`.

**Statut : codé, migration appliquée le 27/11/2026, en bêta.** El Estado reste fermé aux joueurs : le garde-fou serveur
`frontieres_fermees_v1` refuse tout passage vers `narco` (« Frontière fermée, ouverture au premier trimestre 2027 »).
Ce chantier ne l'ouvre pas. Chantier ouvert par ChatGPT (PR #1213), repris et terminé par Claude.

## Rues

Deux vues de rue (`narco`, `capitale`), moteur des autres empires, autorité serveur (`rue_noeuds_serveur`,
`rue_sorties_batiments`) :

- **Devant le centre multimodal** (`ciudad-roja-centre-multimodal`, point de départ de la ville) : façade cliquable
  (entrée du bâtiment `centre-multinodal-luthecia`) ; flèche en bas vers la rue de l'hôtel.
- **Devant l'hôtel** (`ciudad-roja-hotel`) : façade cliquable (entrée de `hotel-republica`) ; flèche en haut vers le
  centre multimodal.
- La sortie de chaque bâtiment ramène devant sa propre façade ; le serveur refuse l'entrée d'un bâtiment depuis la
  façade de l'autre.

## Centre multimodal de Ciudad Roja

Trois pièces : hall principal (`hall_gare`), douanes (`hall_douanes`), zone d'embarquement (`zone_embarquement`).
Transports et contrôle douanier existants inchangés. PNJ : Carlos Retraso et Juanita Soborno au hall, Juanita Soborno
aux douanes (l'inspecteur de Républia du gabarit n'apparaît plus).

**À venir, non codé :** glisser un billet dans la panière des douaniers pour tenter de passer sans confiscation du
matériel illégal ; jet et modalités à définir par Fred.

## Hotel Ciudad Roja

Cinq vues : Réception (`accueil`), Suite (`chambres`), Restaurant (`restaurant`), Piscine (`piscine`, pièce propre à
Ciudad Roja), Bar extérieur (`bar`).

- **Aucun onglet vers le bar** : on rejoint la piscine, puis on clique sur le bar de l'illustration.
- Depuis le bar extérieur, on rejoint la piscine ou le restaurant, et rien d'autre.
- Le serveur impose ce parcours (`ciudad_roja_bar_v1` dans `navigation_interieure_personnage_interne`) : entrée au
  bar seulement depuis la piscine ; sortie du bar seulement vers la piscine ou le restaurant.
- Les suites privée et présidentielle du gabarit de Luthécia sont exclues (client et serveur).
- Personnel refait par Fred le 28/11/2026 (voir ci-dessous) : Pedro Tequila, Lupe Cantina et Lola Discreta ne sont
  plus à l'hôtel.

## Ouverture en teaser (décision 17, codée le 28/11/2026)

- Frontière : seule Ciudad Roja est ouverte dans El Estado (`frontieres_fermees` garde ville_a et ville_b) ; dans la
  capitale, seuls le **centre multimodal** et l'**Hotel Ciudad Roja** sont ouverts (`navigation_lieux_regles.ferme`).
- Au centre multimodal, **seul l'avion** vers les autres capitales fonctionne. Bus, train et taxi, et la flèche du bas
  de la rue de l'hôtel, affichent : « Accès interdit ! Il sera ouvert quand Républia et Sovarka seront suffisamment
  peuplées. Parlez du jeu autour de vous pour accélérer son ouverture ! », avec un gros « ? » cerclé qui ouvre les
  conditions et le compteur.
- Conditions d'ouverture, calculées par le serveur (`teaser_ouverture_compteur`) et affichées ville par ville et poste
  par poste ; le compteur peut redescendre :
  - au moins **150 PJ actifs** (connectés dans les 7 derniers jours et domiciliés dans la ville) dans **chacune des six
    villes** de Républia et de Sovarka ;
  - **et** tous les postes de **ministre** (Affaires étrangères, Défense, Finances, Information, Intérieur, Justice),
    de **maire** et de **maire adjoint** (trois villes par pays) occupés par des joueurs.

## Hotel Ciudad Roja : gestes (monnaie : PS)

Ordres habituels de l'hôtel, plus (serveur : `hotel_teaser_agir`) :

| Geste | Pièce | Coût | Effet | Limite |
|---|---|---|---|---|
| Nager dans la piscine | Piscine | 1 PA | +5 Santé ; protège de la canicule pour 12 heures | 2 par jour |
| Jouer au tennis | Piscine | 2 PA | −8 Santé, +7 influence, +5 popularité | 1 par jour |
| Donner un pourboire | Toute pièce avec un employé (réception, restaurant, piscine, bar) | 200 PS | +1 popularité ; à Tito Maletas, un vrai secret sur un joueur réel en prime (réseau Roxane Velours, voir plus bas) | sans limite |
| Appel à un(e) escort | Suite | 800 PS par escort et par jour (même mécanique et même montant qu'à Novomirsk) | — | réservé à un client de l'hôtel (nuitée réservée et pas encore de « Dormir » depuis la réservation) |

- Catalogue d'escorts à Ciudad Roja : les **7 escorts internationales** de l'agence Roxane Velours et **3 escorts de
  l'hôtel** : Svetlana Zolotova, Valentina Fuego, Rafael Toro.
- Secrets sur l'oreiller : ceux confiés à **Svetlana** partent au **ministre de la Sécurité du Peuple de Sovarka** ; ceux
  confiés à **Valentina** ou à **Rafael** partent au **ministre de l'Intérieur d'El Estado** (dossier conservé même si le
  poste est vacant). Les 7 escorts du catalogue ne renseignent personne à Ciudad Roja.

## PNJ de l'hôtel

- **Réception** : Rosario Esmeralda (référente de l'hôtel), Bruno Macizo (sécurité ; tient les gangs armés hors de
  l'hôtel), Tito Maletas (bagagiste, référent de l'ambiance d'El Estado).
- **Piscine** : Svetlana Zolotova, Valentina Fuego, Don Augusto Bigotes (caudillo qui se souvient des gens). Don Augusto
  parle **une seule fois par joueur**, la première fois que ce joueur s'adresse à l'une des deux escorts, avec cette
  tirade exacte : « Dis donc Gringo, tu ne serais pas en train d'essayer de me voler mes filles ?! Tu crois peut-être
  avoir une chance ? Tu sais pourquoi elles sont avec moi ? Parce que je suis beau... AHAHAH ! Mais non, c'est parce que
  je les paye ! Alors si tu as de l'argent, tu appelles l'agence Roxane Velours, et ils te trouveront ce que tu veux !
  Femmes, hommes, peu importe ! Et si tu as de l'argent, invite-toi à notre table de joueurs de poker au casino de la
  ville. On aime bien les petits présomptueux de ton espèce. Ton arrogance me plaît, gringo ! » (serveur :
  `ciudad_roja_augusto_tirade`).
- **Bar extérieur** : Rafael Toro (barman et escort ; réplique type : « Quand j'ai envie de prendre quelque chose, je le
  prends ! Quelque chose ou quelqu'un... partenaire... »).
- **Restaurant** : Matías Bandeja (référent des habitués, d'après les passages réels : `hotel_teaser_habitues`).
- **Suite** : aucun PNJ permanent.

## Centre multimodal de Ciudad Roja

- Hall : Carlos Retraso. Douane : Juanita Soborno (cheffe) et deux douaniers moustachus qui ne répondent que « Voyez
  avec la cheffe ».
- Ordre exclusif **« Donner un billet aux douaniers »**, branché sur le contrôle douanier existant. Le joueur choisit le
  montant.
  - Chance = 50 % + 1 % par tranche de 10 PS + 2 % par point de CHA au-dessus de 8 + 2 % par point d'ENT au-dessus de 8
    + 1 % par 3 points d'indice de sécurité sous 50 ; 95 % au plus.
  - Réussite : passage sans confiscation (le passage est marqué « corrompu » pour l'avion, comme l'ordre existant).
  - Échec : billet perdu, objets illégaux confisqués, ni arrestation ni amende, et Juanita lance : « Si tu avais été
    moins radin, tu aurais gardé tes objets, imbécile ! On t'avait pourtant laissé une chance ! »

## Illustrations

`images/El Estado/Ciudad Roja/` : quatre vues du centre multimodal (extérieur, hall, douanes, embarquement) et six de
l'hôtel (extérieur, réception, suite, restaurant, piscine, bar de la piscine).

## Décisions du 28/11/2026 (après-midi) — migration `20261128100000_reponses_fred_teaser`

- **Escorts de la suite** : la condition « nuitée réservée depuis moins de 36 h » devient « nuitée réservée, pas encore
  consommée, et pas encore d'ordre « Dormir » depuis la réservation » (heure exacte du dernier « Dormir » gardée par le
  serveur, table `personnages_dormir_horodates`).
- **Tito Maletas** : les huit rumeurs écrites à la main sont supprimées. Contre le pourboire, Tito livre **un vrai
  secret sur un joueur réel** tiré au hasard dans tout le jeu (jamais un PNJ, jamais un compte de test), en expliquant
  que sa source est le **réseau international Roxane Velours**, présent dans le monde entier, dont les escorts entendent
  toutes les confidences. Quand des réservations réelles passées par le standard Roxane Velours existent
  (`escort_appels`, `escort_relations`), Tito puise d'abord chez ces clients. Le secret arrive aussi au courrier et dans
  les renseignements connus du joueur. Svetlana, Valentina et Rafael font partie de ce réseau (personnalités de dialogue
  complétées : ils le laissent entendre, sans jamais citer de secret ni de nom).
- **Moteur des « vrais secrets »** (narguilé, « Secret contre secret », Tito ; `hotel_secret_vrai_interne`) : poste,
  argent liquide, domicile, actions récentes, **plus** parti ou organisation publique, biens (locaux loués, terrains),
  casier judiciaire et peine en cours, conjoint et nombre d'employés, crimes passés non élucidés (révélés comme rumeur,
  sans ouvrir d'affaire). **L'appartenance à une organisation secrète n'est jamais révélée, par aucune source** (ni un
  local loué par une organisation secrète). Les maisons de Sovarka gardent leur tirage d'origine.
- **Bruno Macizo** : reste du décor, aucune mécanique. Pas très malin, il installe une ambiance d'insécurité
  (personnalité de dialogue ajustée).
- **Valeurs gardées** : protection canicule 12 h, défi de backgammon qui expire au bout d'1 h sans coût en PA.
- **Bâtiments fermés** : les autres bâtiments de la capitale restent déclarés dans `data.js` et fermés par le serveur.
- **Traductions** : noms de pièces, rôles des PNJ et descriptions des ordres des deux capitales dans les neuf langues
  (`plateau-teaser-traductions.js`).
