# Novomirsk (capitale de Sovarka) — raccordement des bâtiments

Chantier lancé par Fred le 04/11/2026 : raccorder les bâtiments de Novomirsk **vue par vue**
dans la navigation de rue, pour tester la duplication des couches du socle sur un autre empire
(écart volontaire et décidé par Fred avec la feuille de route d'`ARCHITECTURE.md`, qui plaçait
les autres empires après l'internationalisation).

Point de départ (04/11/2026) : 18 vues, 34 zones cliquables, 17 raccordées (16 bâtiments, le
Grand Hôtel ayant deux entrées), 17 marquées « à venir ».

## Décisions de Fred

| Date | Vue | Zone | Décision |
|---|---|---|---|
| 04/11/2026 | V1 Place du Peuple | Librairie du Peuple | Copie de l'Imprimerie-Librairie Gutenberg de Port-Sainte-Marie (tracts électoraux à l'accueil ; tracts calomnieux et vente de bois à l'atelier). Libraire propre à Novomirsk : **Ludmila Pamphletova** (nom choisi par Fred). L'ouvrier typographe reste anonyme, comme à PSM. |
| 04/11/2026 | V1 Place du Peuple | Palais du Gouvernement | **Pas réellement raccordé** malgré sa zone cliquable (constat de Fred). Gros morceau : gardé pour la fin du tour. |
| 04/11/2026 | V2 | Restaurant La Mère Volga | Copie du Capitaine Sauvage de PSM ; la carte sera retravaillée plus tard. Serveuse propre à Novomirsk : **Tatiana Bortchova** (nom choisi par Fred). |
| 04/11/2026 | V2 | Musée municipal de Novomirsk | Copie du musée de PSM : panthéon de la ville (nouveau bâtiment `musee-novomirsk`). PNJ propres choisis par Fred : **Irina Guichetova** (accueil), **Docteur Lev Patrimonov** (conservateur), **Vétéran Ilia Médailline** (guide bénévole). Figures historiques des salles écrites par Claude, **à relire par Fred** (`plateau-musee-personnalites.js`) ; Salle des Plumes laissée aux joueurs. |
| 04/11/2026 | V6 | Palais des Ambassades | Copie du Quartier des Ambassades de Luthécia (nouveau bâtiment `palais-ambassades-novomirsk`, pour ne pas hériter des contrôles d'accès propres aux ambassades ouvertes en Républia). Bureaux de Républia, d'Al-Khalija et d'El Estado ; ambassadeurs nommés par Fred : **Hubert de La Courtoisie**, **Cheikh Rachid Al-Diplomi**, **Don Esteban Cortesano**. Tous les ordres « Bientôt disponible » jusqu'au voyage entre empires. |
| 04/11/2026 | V7 | Pavillon des Ambassadeurs | Appartements de luxe, pas spécialement réservés aux ambassadeurs : l'équivalent des suites de l'hôtel Républica (nouveau bâtiment `pavillon-ambassadeurs-novomirsk`). **Trois suites** louables à 500 FR/jour : Suite Privée (+8 INF +10 DIS) et Suite Présidentielle (+8 POP +8 INF +2 DIS) à l'identique, **Suite du Parti (+10 POP +6 INF +2 DIS)** ; une **grande salle de réception** (copie de celle des ambassadeurs, sans ordre) ; un **bar** (copie du Bar du Républica : commerce `bar`, boissons et snacks). PNJ nommés par Fred : **Arkadi Discretov** (maître d'hôtel), **Lena Glaçonova** (serveuse façon traiteur). « Organiser une rencontre piège » non repris (aucune agence d'escorts à Novomirsk). |
| 04/11/2026 | V4/V5 | Grand Hôtel de Sovarka | **Plus de suites** (elles sont au Pavillon) : pièces `suite_privee` et `suite_presidentielle` exclues, ordre « Louer une suite » retiré. Lecture retenue de « n'aura que des chambres, pas de suites » : seules les suites sont retirées ; restaurant et bar de l'hôtel restent en place, à confirmer par Fred. |
| 04/11/2026 | V7 | Résidence impériale | Logements de prestige louables comme les suites du Pavillon (nouveau bâtiment `residence-imperiale-novomirsk`) : **quatre appartements à 500/jour (+4 POP +4 INF +4 DIS)** et **un grand appartement à 1 200/jour (+15 POP +15 INF +5 DIS)**. Gardien anonyme. |
| 04-05/11/2026 | V8 | Entrepôt Logistique | Interface copiée de Luthécia (nouveau bâtiment `entrepot-logistique-novomirsk` : Salle des Ventes, Bureau de Direction), **tous les ordres « Bientôt disponible »** jusqu'à l'économie de Sovarka (décision de Fred du 04/11). Directeur PNJ : **Boris Stockov** (nom choisi par Fred le 05/11). Pas encore de ligne `entrepots_par_ville` ni d'état serveur : à ajouter quand l'approvisionnement de Sovarka sera décidé. |
| 05/11/2026 | V8 | Direction du Renseignement de Sovarka | **Siège du renseignement militaire, bâtiment du socle** (`siege-renseignement`) : il fait partie de l'architecture commune même si un empire ne l'utilise pas ; la Républia ne le liste pas (son ministre de la Défense garde l'ordre au Palais), Sovarka si, et d'autres empires plus tard. Trois pièces : **Accueil**, où le **Sergent Viktor Muetov** (nom de Fred) vous accueille froidement ; **Salle des Écoutes**, avec l'ordre existant « Renseignement militaire » (ministre de la Défense ; à Novomirsk l'ordre vit là, pas au Palais) ; **Salle d'Interrogatoire**, copie de « Interroger un détenu » du QHS (2 PA, 75 %, +5 INF), réservée au ministre de la Défense. Migration `20261105004500_siege_renseignement_militaire` appliquée. |
| 05/11/2026 | V11/V12 | Caserne centrale de Novomirsk | **Socle de la caserne de Républia** (`caserne-militaire` : sept pièces, mêmes ordres, mêmes fonctions serveur), avec une différence : **en Sovarka la caserne est en ville**, et non dans une zone hors ville. Deux entrées (V11 et V12), sortie par V12 ; plus de taxi vers la caserne au Centre multimodal de Novomirsk. Le serveur demande désormais où est la caserne d'un pays (`caserne_ville`, `caserne_noeud`) pour l'incorporation, la création d'une compagnie, le repli et le retour d'un soldat neutralisé (migration `20261105200100_caserne_novomirsk_en_ville`). PNJ propres validés par Fred : **Commandant Igor Bataillov**, **Adjudant Piotr Galonov** (corps de garde), **Infirmière Olga Pansementova**, **Caporal Vassili Kachaev** (réfectoire), **Caporal Dimitri Corvéev** et **Soldat Sacha Gamelline** (quartier des troupes) ; armurier et archiviste anonymes. Les quatre référents parlent comme ceux de Luthécia (fiches générées depuis les leurs, noms et lieux de Novomirsk). |
| 05/11/2026 | V11 | Garage de Novomirsk | **Véhicules personnels** (socle commun, règles complètes dans `GAME-DESIGN-VEHICULES.md`) : seul garage PNJ du jeu, garagiste **Sergueï Zaptchastov** ; vente de voitures, deux-roues et utilitaires avec leur clé, révision, dépannage. Station-service PNJ de Krasnov (rue de la station et du musée), gérante **Lioudmila Zapravkina**. Route Novomirsk ↔ Krasnov seulement ; Starovka n'est pas reliée. Images à venir. |

**Méthode (Fred, 04/11/2026)** : d'abord l'interface intérieure de chaque bâtiment, avec ses
différentes pièces ; Fred générera ensuite les images avec ChatGPT. En attendant, un bâtiment
copié porte `imagesAVenir: true` dans son `buildingContext` : ses pièces s'affichent sur leur
fond, sans emprunter les images de la ville d'origine.

Monnaie (décision de Fred, 04/11/2026) : le **para sovarkien, sigle PSK** (le para était le centime du dinar yougoslave), à la place de l'ancien sigle « RP ». Pas de taux de change : mêmes chiffres que les FR. Les libellés de loyer de Novomirsk affichent « PSK ». La monnaie d'El Estado (« PS ») n'est pas encore validée.

Pays du poste (05/11/2026, Fred : « on ne continue pas si ce n'est pas réglé ») : **réglé** par la migration
`20261105013000_pays_du_poste_et_lieu_des_ordres`. Le serveur prenait pour pays d'un poste le pays où se
trouvait son titulaire (Arnie, ministre de la Défense de Républia, était ainsi traité en ministre de Sovarka
à Novomirsk, pour les 27 fonctions d'autorité). Désormais le pays vient du registre des postes ; un ordre de
poste se passe dans le pays du poste ; « Renseignement militaire » se lance dans son pays, au siège du
renseignement si l'empire en a un, sinon au Palais du Gouvernement. Les quatre agents de
renseignement (`renseignement_identites_reelles`) et leurs portraits sont encore ceux de Républia : un
vivier propre à Sovarka sera à nommer par Fred avant d'ouvrir le renseignement de cet empire.

## Couches à dupliquer pour un bâtiment existant du gabarit

Relevé sur la Librairie du Peuple (migration `20261104203000_novomirsk_librairie_peuple`) :

- **Écran** : `data.js` (liste `buildings` de la ville ; `buildingContext` : nom, description,
  PNJ locaux), `plateau-rue-centrale.js` (zone de la vue passée de `a-venir` à `batiment`),
  version `?v=` des scripts dans `plateau.html` et `index.html`.
- **Serveur** : `batiments_etat` (état propre à la ville, identifiant `<pays>_<ville>_<bâtiment>`,
  colonnes `country`, `city`, `building_id` obligatoires), `navigation_lieux_regles` (pièces
  autorisées), `rue_sorties_batiments` (entrée depuis la vue). Un commerce (`commerces_types`,
  `commerces_dotations`, indexés par bâtiment et pièce, sans pays) n'a rien à semer : le serveur
  crée l'entreprise de la ville au premier accès. Pas de `blocus_ordres_batiments`
  ni de `pnj_lieux_metiers` hors Républia (ces deux tables ne couvrent que Républia).
- **Générés** : `api/_pnj-scenes-generes.js` (`generer-pnj-lieux-metiers.cjs --scenes-js`),
  fiche minimale du PNJ dans `api/_pnj-personnalites.js` ; le bâtiment est exclu de la
  génération historique de `navigation-lieux.cjs`, comme les ajouts de Montrouge et de PSM.

## Limites connues

- Aucune image d'intérieur n'existe pour Sovarka : pièces sur fond uni (`imagesAVenir`) en
  attendant les images de Fred.
- Pas de titre de murs pour les commerces de Sovarka (aucun commerce hors Républia n'en a) :
  la mécanique murs/fonds ne s'y applique pas encore.
- Le plan de Novomirsk emprunte encore celui de Luthécia : les bâtiments raccordés n'y sont pas
  dessinés tant que la ville n'a pas son propre cadastre.
- Plusieurs noms anciens du `buildingContext` de Novomirsk ne correspondent pas aux noms des
  zones de rue (ex. « Distribution Collective » pour le Marché) ; à harmoniser vue par vue.

## Entrepôts : le pays dans la clé (04/11/2026, chantier socle demandé par Fred)

Avant le V8, la table serveur `entrepots_par_ville` ne connaissait que la ville : « capitale »
désignait Luthécia pour tous les pays, et un entrepôt copié à Novomirsk aurait lu et vendu le
stock de Luthécia. Désormais (migration `20261104230000_entrepots_par_pays`) la clé est
**pays + ville** ; les huit fonctions serveur qui lisent la table filtrent sur le pays, le
directeur d'entrepôt est rattaché à l'entrepôt de son propre pays, l'embargo se juge depuis le
pays de l'entrepôt qui commande, la vente du port est payée à la caisse de ce port.
Pour raccorder l'entrepôt de Novomirsk, il suffit d'ajouter la ligne
(`soviet`, `capitale`, `entrepot-logistique-novomirsk`) et l'entrée écran `ENTREPOT_PAR_PAYS_VILLE.soviet`.

Restent hors de ce chantier (économie propre à Sovarka, à décider avec Fred) : l'approvisionnement
de nuit (la passe de minuit ne nourrit que les entrepôts de Républia, avec ses usines et le port
de PSM), un port de Sovarka, le directeur PNJ de l'entrepôt dans la cascade des postes.
