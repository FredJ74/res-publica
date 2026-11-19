# Maladies, péremption des aliments et événements climatiques

Décisions de Fred du 18/11/2026 (après-midi), consignées depuis claude.ai.
**État : en cours (Claude Code, à partir du 18/11/2026 au soir), par lots — voir § 11.** Socle commun : tous les empires,
sauf mention contraire. Tout texte affiché est écrit dans les neuf langues.

## 1. Principe d'architecture

- Deux mécaniques **génériques et paramétrables**, sans code propre à chaque cas :
  - **maladie** : nom, symptômes visibles, malus, durée, médicament, contagion éventuelle ;
  - **événement climatique** : nom, ville touchée, fréquence, perte de PA, objet protecteur,
    maladie déclenchée, effets, filtre visuel.
- **Fonctionnement automatique aléatoire par défaut**, avec une **prise en main par le MJ**.
- **Outils de MJ** : *tous* les paramètres sont modifiables (« qui peut le plus peut le moins ») :
  noms, symptômes, malus, durées, pourcentages de risque et de contagion, objets protecteurs,
  fréquences, villes. Le MJ peut aussi :
  - **renommer temporairement** une maladie (ex. la grippe devient une gastro-entérite pour un coup
    de sirocco dans un autre pays) et changer sa durée ;
  - **bloquer** les événements automatiques (une ville ou un pays) ;
  - **déclencher** un événement à la main (ville, date, alerte 24 h avant) ;
  - **déclarer la fin** d'une épidémie.

## 2. Maladies

| Maladie | Malus | Symptôme (exemple) | Durée | Médicament | Contagieuse |
|---|---|---|---|---|---|
| Intoxication alimentaire | −2 CHA | « Vous vomissez toutes les 10 minutes, ce qui vous rend moins charmeur. » | 3 jours | anti-nauséeux | non |
| Gueule de bois | −1 INT, −1 CHA, **bonus de l'arme supprimé** (moins adroit) | « La lumière vous agresse et chaque pensée vous coûte. » | 24 h | aspirine | non |
| Grippe | −2 INT, **impossible de dépasser 15 PA** | « Vous avez le nez qui coule et les idées embrumées. » | 4 jours | antigrippal | **oui** |
| Coup de chaleur | −1 INT, −1 CHA | « Vous avez la tête qui tourne et transpirez à grosses gouttes. » | 2 jours | sels de réhydratation | non |

- **Médicaments** : produits par l'**usine pharmaceutique** de chaque pays, vendus en **pharmacie**,
  prix par la règle commune (prix PNJ = 2 × coût de revient). Le médicament adapté **guérit au
  prochain Dormir**, quelle que soit la durée restante. Une épidémie peut créer une pénurie.
- **Visibilité** : les **symptômes** sont visibles dans la fenêtre d'interaction du personnage
  (ex. « Il tousse et a le nez rouge »), **jamais le nom de la maladie**. Paranoïa voulue : un malade
  peut mentir en RP (« c'est juste une allergie »).

### Risques

- **Viande crue** (toute viande brute) : **15 %** d'intoxication par portion consommée.
- **Alcool** : les **deux premiers verres** de la journée sont sans risque, puis **30 %** de gueule de
  bois par verre.
- **Contagion de la grippe** :
  - **30 %** si l'on a partagé **la pièce** d'un grippé dans la journée ;
  - **70 %** en cas d'**interaction directe** avec un grippé (saluer, parler, dîner, combattre…) ;
  - **un seul tirage par jour et par grippé croisé**, au niveau le plus élevé atteint.
  - Intention de Fred : quarantaines, parodie de la crise du covid, jeu politique autour de l'épidémie.

## 3. Alimentation et péremption

- **Viande et laitages bruts** (matières `viande` et `laitages`, partout) : se consomment et
  rapportent **1 PA** au prochain Dormir (décision du 18/11 au matin). Confiture d'airelles : 1 PA,
  cumulable avec un repas brut.
- **Péremption** : **tous les aliments** se périment au bout de **10 jours**.
  (Fred se souvenait d'une ancienne règle de 7 jours pour les achats du marché : elle n'a été trouvée
  ni dans le code ni dans les documents ; elle est remplacée par celle-ci.)
- **Canicule** : toute la nourriture **portée sur soi** est avariée à la fin de la journée de canicule,
  quel que soit son âge. La nourriture stockée dans un bâtiment n'est pas touchée.
- **Aucune marque visuelle** sur un aliment avarié, ni pour son propriétaire ni pour les autres.
  Le propriétaire reçoit seulement **un message** quand ses aliments se gâtent. Un aliment déposé puis
  ramassé par un autre ne révèle rien.
- **Aliment avarié consommé** : rapporte toujours ses PA, mais **50 %** de risque d'intoxication.
- **Plat cuisiné** avec au moins un ingrédient avarié : **20 %** de risque d'intoxication (la cuisson
  tue les bactéries, pas les toxines déjà produites) ; invisible lui aussi.

### Contrôle à la réception (commerces et entrepôts)

- Quand un PJ vend des aliments à un commerce ou un entrepôt, chaque aliment avarié est **détecté
  à 70 %** (taux de base). Détecté = **refusé, détruit, non payé**.
- Si le vendeur avait **reçu le message** d'avarie, la tentative est un **acte illégal** (fraude
  alimentaire) qui laisse une trace, comme les autres actes illégaux.
- Les aliments non détectés entrent dans le stock sans marque et peuvent finir dans les plats.
- **Bandelettes réactives** : vendues en **pharmacie** ; réserve gardée dans le commerce ; **chaque
  livraison reçue en consomme une** et fait passer la détection à **95 %** ; réserve vide = 70 %.

### Furet renifleur

- Vendu **uniquement** dans les boutiques **Chasse et Pêche** (on chasse le lapin au furet) : objet
  plutôt rare, à faire venir des villes qui en ont une.
- **Objet-animal permanent** : vente, don, vol, héritage ; pas besoin de le nourrir.
- Ordre **« Faire renifler un aliment »** (1 PA) : il **éternue** si l'aliment est avarié, **ronronne**
  s'il est sain, avec une petite animation drôle.
- Il **meurt s'il renifle plus de 10 aliments avariés** au cours de sa vie (au 11e).

## 4. Événements climatiques — règles communes

- **Alerte 24 h avant**, dans la **presse du jour** et le **journal d'événements**, avec un message
  **neutre** que les personnes en poste peuvent reprendre en RP (ex. conférence de presse du ministre
  de l'Information).
- Un événement frappe **une ville**, pas tout le pays.
- **Filtre visuel animé** sur les vues de rue de la ville touchée (sans nouvelles images) :
  brouillard (voile blanc, flou, contraste baissé), blizzard (flocons, image blanchie), orage (pluie,
  éclairs, rues assombries), canicule (teinte chaude, air qui tremble), crue (eau dans les rues).
- **Chantiers de construction** reliés aux événements : blizzard, orage, crue et canicule bloquent
  **tous les chantiers de la ville** ce jour-là. Les aléas individuels existants (`ALEAS_CHANTIER`,
  `api/cron-minuit.js` : intempéries, canicule) restent en plus.
- Rappel : le **parapluie républicain** est une arme (parodie du parapluie bulgare), sans lien avec la
  météo.

## 5. Blizzard (Sovarka)

- **Fréquence** : chacune des **3 villes** de Sovarka est frappée **une fois par mandat présidentiel**,
  à une date tirée au hasard (dates différentes). Intention : mettre les autorités sous tension.
- Toutes les personnes présentes **perdent 3 PA**, sauf celles qui portent un **bocal de graisse**,
  qui est alors consommé :
  - **graisse de renne** à Starovka (magasin du kolkhoze) ;
  - **graisse d'ours** à Krasnov et **graisse de castor** à Novomirsk (lieux de vente à définir).
- Le blizzard **déclenche l'épidémie de grippe** : risque calculé **après** la perte des PA, selon les
  PA restants (« la vraie protection, ce sont les PA ») :

| PA restants | Risque de grippe |
|---|---:|
| 26 à 30 | 0 % |
| 21 à 25 | 10 % |
| 16 à 20 | 25 % |
| 11 à 15 | 50 % |
| 6 à 10 | 65 % |
| 1 à 5 | 80 % |
| 0 (à l'hôpital) | 0 % |

- Le bocal de graisse retire **5 points** au risque (protection faible). Ensuite, la contagion entre
  joueurs prend le relais.

## 6. Brouillard (tous pays)

- **2 journées par mois et par ville**, dates tirées au hasard.
- Pendant la journée : **+10 %** de réussite aux actes illégaux et **−20 %** de chances d'être repéré
  (police, agents de sécurité, caméras).

## 7. Orage et coupure d'électricité et d'internet (tous pays)

- **1 par mois et par ville**, date tirée au hasard.
- Pendant 24 h : **ordinateurs, box et caméras** de la ville hors service (plus de surveillance, de
  trading à distance ni de piratage depuis cette ville) ; chantiers bloqués.
- **Groupe électrogène** : nouvel objet vendu **chez le garagiste** ; installé dans un bureau comme les
  autres équipements, il maintient en service l'ordinateur, la box et les caméras de ce bureau ;
  consomme **5 bidons de carburant** par journée de coupure (sans bidons, il ne fonctionne pas).

## 8. Crue (Républia)

- **Tous les 2 à 3 mois par ville** (intervalle tiré au hasard), seulement dans les villes qui ont une
  **zone inondable**. Fred choisira les bâtiments de chaque zone inondable.
- Pendant 24 h : bâtiments de la zone inondable **inaccessibles** ; entrepôts et commerces de cette
  zone perdent **20 % de leurs stocks**, sauf protection par sacs de sable ; chantiers bloqués.
- **Sacs de sable** : vendus à la **quincaillerie** ; le propriétaire ou l'exploitant en pose un lot
  (**1 PA**), qui protège ce bâtiment pour **une crue**, puis est emporté.

## 9. Canicule (Républia)

- Fréquence : à proposer (non fixée par Fred), réglable par le MJ.
- Pendant 24 h : toutes les personnes présentes **perdent 3 PA**, sauf celles qui portent une
  **bouteille d'eau** (consommée) ; chantiers bloqués ; nourriture portée sur soi avariée (§ 3).
- Puis risque de **coup de chaleur** selon le même tableau de PA que le blizzard, calculé après la
  perte ; la bouteille d'eau retire 5 points.

## 10. À détailler plus tard (ne pas coder)

- **Raspoutitsa** (Sovarka) : saison des boues, routes impraticables quelques jours, train seulement.
- **Gel tardif à Krasnov** : chute de la production des fermes (fruits et légumes, œufs), pénurie.
- Autres empires : **tempête de sable** à Al-Khalija (port fermé, gastro-entérite) ; **ouragan** et
  **dengue** à El Estado (port fermé, moustiquaire comme protection).

## 11. Mise en œuvre (Claude Code, 18/11/2026)

Découpage en lots, **une PR par lot**, textes dans les neuf langues, fichiers du goulag jamais touchés.

| Lot | Contenu |
|---|---|
| 1 | Socle des maladies : catalogue paramétrable, maladies des personnages, malus, guérison, médicaments en pharmacie, risques viande crue et alcool, symptômes visibles, outils de MJ des maladies |
| 2 | Péremption à 10 jours, aliments avariés, contrôle à réception et bandelettes, furet renifleur |
| 3 | Socle des événements climatiques : calendrier, alerte 24 h, filtres visuels, chantiers bloqués, outils de MJ |
| 4 | Blizzard (graisses, tableau de grippe) et contagion de la grippe |
| 5 | Brouillard, orage et groupe électrogène, crue et sacs de sable, canicule et coup de chaleur |

### Choix d'implémentation du lot 1

- **Catalogue** `maladies_parametres` (une ligne par maladie) : tous les paramètres du § 2 y sont, modifiables par le MJ (page
  d'administration) ; le nom et le symptôme **temporaires** du MJ s'affichent tels quels (texte libre), sinon le texte des
  neuf langues du catalogue client.
- **Maladies des personnages** `personnages_maladies` (une maladie active au plus par sorte) ; les malus de caractéristiques
  passent par le mécanisme existant des effets temporaires (`effets_actifs`), déjà lu par `getStatEffective`.
- **Grippe** : plafond de 15 PA appliqué au Dormir et aux gains immédiats ; les PA déjà au-dessus de 15 à la contraction ne
  sont pas retirés.
- **Médicament** : consommé, il marque la maladie « traitée » ; elle disparaît au prochain Dormir. Sans la maladie
  correspondante, le médicament est refusé (il n'est pas gaspillé ; pas de prise préventive).
- **Points de vente** : la pharmacie d'État de Novomirsk (Sovarka) et, faute de pharmacie en Républia, la **salle des ventes
  de l'usine pharmaceutique de Luthécia** (proposition, à valider par Fred). Stock journalier par point de vente,
  réglable par le MJ (0 = pénurie).
- **Alcool** : compteur de verres par personnage et par jour de Paris, alimenté par chaque façon de boire (tournées, trinquer,
  verre offert) ; les deux premiers sont sans risque.
- **Symptômes** : lus par le serveur pour les seules personnes présentes dans la pièce de l'observateur ; le nom de la maladie
  n'est jamais transmis aux autres joueurs.
- **Règle des 7 jours retrouvée** : `inventaire_consommer` donnait +1 PA à un aliment de 7 jours ou moins et −1 PA au-delà.
  Elle sera remplacée au lot 2 par la péremption à 10 jours.

### Décisions de Fred du 18/11 au soir (fin du lot 1)

- **Boissons : deux sous-articles explicites**, « boisson alcoolisée » et « boisson non alcoolisée ». L'étiquette est posée à la
  main sur chaque boisson (colonne `recettes_commerce.boisson`, obligatoire pour toute recette de catégorie `boisson`), jamais
  déduite de la matière « alcool ». Seules les boissons alcoolisées font monter le compteur de verres.
  - Façons de boire comptées : tournée (selon la boisson commandée), consommation sur place au comptoir, service d'étage,
    boisson du dîner d'affaires (le « verre offert » au restaurant, un verre par convive joueur), bouteille bue depuis
    l'inventaire (bouteille du mini-bar de la Résidence impériale, alcools de distillerie), trinquer chez l'habitant
    (toujours alcoolisé : vodka, slivovitz, samogon, alcool).
  - Une boisson achetée à emporter se boit depuis l'inventaire (bouton « Boire »), sans effet sur les PA.
- **Grippe** : comportement inchangé (PA au-dessus de 15 non retirés, plafond au prochain gain).
- **Médicaments en Républia** : le comptoir de l'usine pharmaceutique de Luthécia est le seul point de vente PNJ. La
  production journalière de chaque médicament (le « stock journalier » du MJ) est répartie comme celle des autres usines
  stratégiques : 25 % au comptoir de l'usine, 25 % à chacun des trois entrepôts logistiques (Luthécia, Port-Sainte-Marie,
  Montrouge), au plus fort reste. Les pharmacies ouvertes par des PJ s'y fournissent ; aucun contrat commerçant/usine. La
  recette d'une vente en entrepôt va à la caisse de l'entrepôt.

### Lot 2 : choix d'implémentation (18/11/2026)

Le lot 2 est livré en deux PR : **2a** (piles datées, péremption, consommation, message) et **2b** (contrôle à réception et
bandelettes, plats cuisinés, furet renifleur).

- **Matières périssables** : viande, viande de renne, laitages, poisson, fruits et légumes, œufs. Céréales, sucre et produits
  exotiques ne se périment pas (à confirmer par Fred).
- **Date de pile** (`recu`, jour de Paris) posée au dépôt. Deux piles ne fusionnent que si elles ont le même jour et le même état ;
  une pile qui arrive avec sa date (don, remise) la garde. Le champ `avarie` est réservé à la canicule (lot 5).
- **Retraits** : une quantité se prend sur les piles les plus anciennes d'abord ; une ligne choisie dans l'inventaire est servie
  la première. Les fonctions qui ne regardaient que la première pile (maisons d'hospitalité, kolkhoze, jardins, offres d'achat)
  comptent désormais toutes les piles.
- **Passe de nuit** (`aliments_passe_nuit`, 00 h 10 heure d'hiver) : date les piles arrivées par un chemin qui ne datait pas
  encore, et prépare le message au propriétaire des piles qui viennent de se gâter. Le message s'affiche à la connexion
  suivante, dans la langue du joueur.
- **Consommation** : aliment manufacturé ou matière brute avariée = toujours ses PA, et 50 % d'intoxication (paramètre
  `aliment_avarie` de l'intoxication, réglable par le MJ). La durée de 10 jours est réglable (`aliments_parametres`).
- **Lot 2b — contrôle à la réception** (ventes et dons d'aliments à un commerce, moteur historique et fonds PJ) : les unités
  vendues sont prises sur les piles les plus anciennes ; chaque unité avariée est détectée à 70 % (95 % si une bandelette est
  consommée). Détectée : refusée, détruite, non payée. Les unités non détectées entrent dans le stock et sont comptées à part
  (`matieresAvariees`) pour les plats cuisinés du lot 2c. Le registre des apports garde la quantité livrée.
- **Fraude alimentaire** : si le vendeur avait reçu le message d'avarie de ces piles, la tentative laisse une trace
  (`actions_tracables`, type `fraude_alimentaire`), qu'elle soit détectée ou non.
- **Bandelettes réactives** : vendues dans les pharmacies du lot 1 (4 l'unité, réglable) ; n'importe qui de présent peut en
  déposer dans le commerce de la pièce (c'est un don) ; chaque livraison d'aliments reçue en consomme une.
- **Réglages du MJ** : section « Aliments » de la page d'administration (péremption, deux taux de détection, prix).
- **Lot 2c (à venir)** : plats cuisinés avec un ingrédient avarié (20 %) et furet renifleur.
- **Lot 2c — plats cuisinés** : quand un commerce produit en consommant des unités avariées passées inaperçues, les portions
  produites par ce geste sont contaminées (invisible). Fonds PJ : l'objet emporté porte la marque et le tirage (20 %) se fait
  quand on le mange, ou tout de suite s'il est consommé sur place. Moteur historique (tournées, dîners, service d'étage,
  comptoir) : le tirage se fait pour l'acheteur au moment du service (les invités d'une tournée ou d'un dîner ne sont pas
  tirés, à confirmer).
- **Lot 2c — furet renifleur** : 250 (réglable), deux par boutique et par semaine, Chasse et Pêche de Port-Sainte-Marie et de
  Starovka ; « Faire renifler » 1 PA depuis la fiche d'un aliment ; meurt au 11e aliment avarié reniflé.

### Décisions de Fred du 18/11 au soir — climat (remplacent les §§ 4, 7, 8 et 9 sur ces points)

- **Crue, canicule, orage (Républia)** : chacun **une fois par trimestre et par ville**, dates tirées au hasard dans le
  trimestre (les trois peuvent tomber le même mois). Tout est réglable par le MJ. Le **brouillard** ne change pas (deux
  journées par mois et par ville, tous pays).
- **Propagation** : l'événement frappe une première ville tirée au hasard, puis gagne les deux autres dans un ordre aléatoire.
  Délais entre deux villes : canicule 2 à 4 jours, orage 1 à 2 jours, crue 1 à 3 jours.
- **Alerte au moins 48 h avant**, pour chaque ville, avec une vraie mise en scène : articles de presse, fenêtre de message du
  gouvernement, journal d'événements.
- **Crue** : zones inondables — Luthécia : entrepôt logistique, marché, parc botanique ; Port-Sainte-Marie : port, port de
  plaisance, bar des Pêcheurs, chantier naval, marché, Chasse et Pêche ; Montrouge : entrepôt logistique, zone de production.
  Chaque crue ne touche que **2 ou 3 lieux** de la liste de sa ville, tirés au hasard et **nommés dans l'alerte**.
- **État de catastrophe naturelle** : option que le gouvernement active de lui-même, jamais automatique ; indemnise les pertes
  de stock dues à la crue sur le budget de l'État. Poste qui décide et part remboursée : **proposition à Fred, pas codé**.
- **Graisses** : castor à Novomirsk chez la poissonnière, ours à Krasnov au marché de la ferme ; aussi vendables dans toute
  pharmacie ouverte par un PJ.

### Choix d'implémentation des lots 3 à 5

- **Lot 3, socle** : calendrier serveur (`climat_evenements`), paramètres du MJ (`climat_parametres` : fréquence, délais de
  propagation, durée, préavis), zones inondables (`climat_zones_inondables`), passe horaire (pg_cron) qui planifie le
  trimestre en cours et le suivant, publie les alertes 48 h avant (article de presse en attente, journal d'événements) ;
  l'écran affiche une fenêtre « Message du gouvernement » une fois par alerte et par personnage, dans les neuf langues, et
  un filtre animé sur les vues de la ville touchée pendant l'événement ; les chantiers de la ville sont bloqués pendant un
  blizzard, un orage, une crue ou une canicule ; section MJ « Climat » (lire, créer, annuler, régler).
- **Orage en Sovarka** : la décision du trimestre vise la Républia ; en Sovarka l'orage garde la règle du § 7 (une fois par
  mois et par ville, sans propagation) — à confirmer par Fred.
- **Lot 4** : blizzard (une fois par mandat présidentiel et par ville de Sovarka), graisses, tableau de grippe, contagion.
- **Lot 5** : effets du brouillard, de l'orage (groupe électrogène), de la crue (2 ou 3 lieux, sacs de sable, 20 % de stock)
  et de la canicule (bouteille d'eau, coup de chaleur, nourriture portée avariée).

### Décisions de Fred du 19/11 — points en attente

1. **Canicule** : tirage au hasard dans le trimestre, sans contrainte de saison (le jeu se joue partout dans le monde).
2. **Orages** : une fois par trimestre et par ville, avec propagation (1 à 2 jours entre deux villes), dans **tous les pays**,
   Sovarka comprise (fin du « une fois par mois » de Sovarka). Mise en œuvre : l'orage déjà annoncé à Novomirsk le 21/11
   devient celui du trimestre, Starovka et Krasnov suivent ; les autres orages mensuels, pas encore annoncés, sont annulés.
3. **Denrées périssables** (10 jours) : viande, viande de renne, laitages, poisson, fruits et légumes, œufs. Ne se périment
   pas : céréales, sucre, produits exotiques. Liste validée.
4. **Plats contaminés** (moteur historique : tournées, dîners) : **un seul jet pour la tablée** ; s'il touche, l'acheteur et
   ses invités joueurs tombent malades ensemble.
5. **Prix et taux** (réglables par le MJ) : bandelette 4 ; furet renifleur **150**, deux par boutique et par semaine, meurt au
   11e aliment avarié reniflé ; détection à la réception 70 % sans bandelette, 95 % avec.
