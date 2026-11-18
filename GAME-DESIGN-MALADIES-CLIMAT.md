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
