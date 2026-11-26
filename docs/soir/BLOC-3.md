# Mission du soir (25/11/2026) — bloc 3 : souvenirs et frontières fermées

Branche `claude/soir-b3-20261125` (issue de main 985d1c94). Migration **écrite, non appliquée** :
`migrations/20261125600000_souvenirs_achat_listes_frontieres.sql` (contrôles en lecture dans son en-tête). Sans elle, rien ne
change pour le joueur : aucun ordre « Acheter un souvenir » (la lecture `souvenirs_ici` échoue, la source d'ordres rend une
liste vide), armoires en liste 1, voyages vers les empires fermés déjà grisés à l'écran.

Banc : `outils/bancs/banc-souvenirs-frontieres-pglite-20261125.cjs` (6/6 : statique + PGlite sur 300000 puis 600000, ancrages
relevés en production et comptés à 1 chacun le 25/11 au soir). Rejoués verts : `test-*.mjs` (441/441), bancs de l'armoire
(PGlite et navigateur), catalogue des manufactures, stock unique des commerces, clé d'unicité des achats, raccordements
d'inventaire, fiche d'objet unique, ordres tactiles, clinique, informateurs.

## 3.1 Souvenirs achetables sur place

- Table `souvenirs_objets` (secrète : aucun droit de lecture pour les joueurs) : 42 souvenirs ; 18 achetables (villes
  ouvertes), 24 des villes fermées achetables nulle part. Prix = réglage MJ (colonne `prix`, devise du pays du lieu).
- Écran `plateau-souvenirs.js` : ne connaît aucun lieu. Dans chaque pièce, il demande `souvenirs_ici()` (ce qui se vend ICI,
  rien d'autre) ; s'il y a quelque chose, l'ordre « Acheter un souvenir » apparaît (source `RP_ORDRES_DYNAMIQUES`) et ouvre la
  fenêtre du PNJ. `souvenir_acheter(p_requete, p_cle)` : idempotent, présence exacte dans la pièce, paiement en liquide
  (comme les boutiques de PNJ), place dans l'inventaire ; refus identique (`pas_vendu_ici`) pour un souvenir inconnu, fermé ou
  vendu ailleurs (aucun indice de lieu). Le banc vérifie qu'aucun fichier servi au navigateur ne cite une clé de souvenir.
- Lieux choisis (image avec comptoir ou étal, vue sur planche) :

| Ville | Souvenir (liste) | Lieu | PNJ | Prix |
|---|---|---|---|---|
| Luthécia | Reproduction miniature du Palais présidentiel (1) | Musée de la Ville, hall | Valérie Loisillon | 45 FR |
| Luthécia | Tampon encreur officiel « Approuvé — en trois exemplaires » (2) | L'Autruche Entravée, accueil (comptoir de librairie) | Rosalie Caractère | 25 FR |
| Luthécia | Formulaire vierge de la Liberté, encadré (4) | Musée de la Ville, hall | Valérie Loisillon | 35 FR |
| Montrouge | Ticket du cinéma de Montrouge (1) | Marché de Montrouge (étals) | Josette Betterave | 10 FR |
| Montrouge | Sifflet de chef de gare du musée du Rail (3) | Musée de Montrouge, accueil | Elsa Montbaron | 30 FR |
| Port-Sainte-Marie | Mug « Port Sainte-Marie » (1) | Marché, étals | Bastien Leroux (vendeur de souvenirs) | 20 FR |
| Port-Sainte-Marie | Bocal de sel des marais (2) | Marché, étals | Mireille Legall | 15 FR |
| Port-Sainte-Marie | Bouée miniature « Port-Sainte-Marie » (4) | Musée, hall | Soizic Le Gall | 25 FR |
| Novomirsk | Poupée traditionnelle de Novomirsk (1) | Musée municipal, accueil-billetterie | Irina Filippova | 15 PSK |
| Novomirsk | Ticket n° 1 de la file d'attente… encadré (2) | Distribution Collective | Distributeur Équitable | 8 PSK |
| Novomirsk | Médaille commémorative du Tractorisme (3) | Musée municipal, accueil | Irina Filippova | 12 PSK |
| Novomirsk | Exemplaire relié de La Voix de Sovarka (4) | Librairie du Peuple, accueil | Ludmila Pamphletova | 10 PSK |
| Starovka | Flasque métallique gravée « Starovka » (1) | Chasse et Pêche, magasin | Bato Tsyrenov | 14 PSK |
| Starovka | Bonnet en laine de renne de la ferme (2) | Magasin du kolkhoze | Tuyana Sambueva | 18 PSK |
| Starovka | Bois de renne sculpté (4) | Marché (étal « Souvenirs ») | Tsypilma Dashieva | 16 PSK |
| Krasnov | Insigne émaillé des hauts-fourneaux (1) | Musée de Krasnov, accueil | Zoïa Biletova | 10 PSK |
| Krasnov | Casque miniature de fondeur (3) | Station-service, boutique | Leonid Zapravkine | 12 PSK |
| Krasnov | Pendentif « L'ours ne se chasse pas » (4) | Marché, étals | Nina Gorbounova | 9 PSK |

- Cartes postales des listes = cartes existantes (`carte_modele`) avec leurs légendes validées ; elles gardent leur
  fonctionnement (écrire, envoyer, lire) : Montrouge place du Rail (L2), Luthécia institutions (L3), Notre-Dame de la Mer (L3),
  Starovka hiver (L3), Montrouge touristique (L4). Krasnov L2 : guide des baies sauvages existant (`guide_baies_krasnov`).
- Revente libre : le souvenir est un objet ordinaire (`type` = sa clé, `souvenir: true`) ; ni `inventaire_donner` ni les
  offres `vente_objet` ne filtrent ce type (vérifié en lecture).
- Durcissement : un emplacement se remplit par `type`/`stackKey` (que la « mutation » d'un don ne peut pas réécrire) ou par le
  modèle de carte ; le nom seul ne suffit plus (il était réécrivable). Les 12 emplacements de la liste 1 reçoivent leur clé.
- Aide, guide, référents : `api/_aide-themes.js`, `guide_pistes`, `pnj_referents` ne parlent pas des souvenirs (vérifié).
  Deux mentions préexistantes, non modifiées : le rôle de Bastien Leroux (« Vendeur de souvenirs », fiche DeepSeek) et la bible
  du gouvernement (« souvenirs » au Marché Central de Luthécia, qui vise les porte-clés existants du marché).

## 3.2 Listes 2, 3, 4 et armoires fabriquées

- Listes 2, 3, 4 mot pour mot en base (et en affichage dans `LISTES_SOUVENIRS`, fenêtre de l'armoire non installée).
- Armoire achetée à la Scierie (`acheter_produit_manufacture`, raccord `armoire_liste_hasard_v1`) : nom, id propre et une des
  listes au hasard (`listeId`). Aucune armoire n'existe en production (relevé du 25/11) : rien à reprendre.

## 3.3 Frontières fermées

- `frontieres_fermees` (6 villes, message « Frontière fermée, ouverture au premier trimestre 2027 ») ; supprimer une ligne
  ouvre la ville. `transport_effectuer` refuse (`frontiere_fermee`, raccord `frontieres_fermees_v1`) ; déclencheur
  `zz_frontiere_fermee_garder` : aucune écriture ne place un personnage dans une ville fermée (création comprise).
- Écran : motif du refus dans `plateau-navigation.js` ; fenêtre de l'armoire : « Cette ville ouvrira ses portes au premier
  trimestre 2027. » sous les six emplacements (`ville_fermee` du serveur, repli sur les noms).

## Lignes de suivi prêtes

| 25/11/2026 | 3.1 Souvenirs des six villes ouvertes : objets du jeu achetés sur place auprès d'un PNJ (lieu à comptoir ou étal), jamais indiqués par le jeu, revendables librement ; cartes postales existantes acceptées dans les listes qui les demandent (migration 20261125600000 écrite, non appliquée). | en cours |  |  | Mission du soir 3.1 |
| 25/11/2026 | 3.2 Listes 2, 3 et 4 en base (provisoires, relues le 12/12) ; armoires fabriquées : une des quatre listes au hasard ; souvenirs des empires fermés définis, achetables nulle part (migration 20261125600000 écrite, non appliquée). | en cours |  |  | Mission du soir 3.2 |
| 25/11/2026 | 3.3 Frontières des empires fermés : voyage refusé par le serveur (« Frontière fermée, ouverture au premier trimestre 2027 ») ; l'armoire annonce l'ouverture au premier trimestre 2027 sous ces villes (migration 20261125600000 écrite, non appliquée). | en cours |  |  | Mission du soir 3.3 |

## Migration à valider

1. `20261125600000_souvenirs_achat_listes_frontieres` — contrôles en tête du fichier : emplacements 12/12/12/12 ; 18 achetables
   et 24 non ; 0 emplacement sans clé ; 6 frontières ; marques `frontieres_fermees_v1`, `armoire_liste_hasard_v1`,
   `frontieres_armoire_v1` présentes ; `souvenir_acheter` ouvert aux joueurs, `souvenirs_ici` fermé à anon, table des lieux
   illisible par les joueurs.

## Pour Codex (français nouveau)

- `plateau-souvenirs.js`, tout l'objet `TXT` (« Acheter un souvenir », description, « {pnj} vous propose : », « Acheter —
  {prix} {devise} », « {nom} est à vous (−{prix} {devise}). », refus).
- `plateau-armoire-souvenirs.js` `TXT.villeFermee` ; `plateau-personnage.js` (même phrase, fenêtre de l'armoire non installée).
- `plateau-navigation.js` motif `frontiere_fermee` ; message serveur `frontieres_fermees.message`.
- Noms des souvenirs : les 36 emplacements des listes 2 à 4 (`LISTES_SOUVENIRS`, `souvenirs_emplacements`), et la
  description serveur « Souvenir de {ville}. » (`souvenir_objet_interne`).

## Questions de game design

- Le cinéma de Montrouge n'a pas de PNJ (le guichet est vide sur l'image) : le ticket de cinéma est vendu au marché par
  Josette Betterave. Faut-il un(e) caissier(ère) au cinéma pour le vendre au guichet ?
- Médaille du Tractorisme : la cathédrale (Kolkhoze Spirituel) n'a pas de comptoir sur son image ; la médaille est vendue à
  l'accueil du musée municipal. La vouloir à la cathédrale ?
- Prix proposés (8 à 45, réglables par le MJ) : à valider.
