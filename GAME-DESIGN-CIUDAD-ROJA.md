# Ciudad Roja, capitale d'El Estado — navigation (décisions de Fred, 27/11/2026)

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
- PNJ d'El Estado existants, répartis par métier : Pedro Tequila (barman) et Lola Discreta au bar, Lupe Cantina au
  restaurant ; réception et suite sans PNJ (les PNJ de Républia du gabarit n'apparaissent plus). Aucun tarif, bonus,
  PNJ ni mécanique ajoutés.

## Illustrations

`images/El Estado/Ciudad Roja/` : quatre vues du centre multimodal (extérieur, hall, douanes, embarquement) et six de
l'hôtel (extérieur, réception, suite, restaurant, piscine, bar de la piscine).
