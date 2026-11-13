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
| 07/11/2026 | V1 Place du Peuple | Palais du Gouvernement | Nom unique **« Palais du Gouvernement de Sovarka »** (décision de Fred), sur la place comme à l'intérieur ; « Siège du Comité Central » abandonné. |
| 04/11/2026 | V2 | Restaurant La Mère Volga | Copie du Capitaine Sauvage de PSM ; la carte sera retravaillée plus tard. Serveuse propre à Novomirsk : **Tatiana Bortchova** (nom choisi par Fred). |
| 04/11/2026 | V2 | Musée municipal de Novomirsk | Copie du musée de PSM : panthéon de la ville (nouveau bâtiment `musee-novomirsk`). PNJ propres choisis par Fred : **Irina Filippova** (accueil), **Docteur Lev Vinogradov** (conservateur), **Vétéran Ilia Krioukov** (guide bénévole). Figures historiques des salles écrites par Claude, **à relire par Fred** (`plateau-musee-personnalites.js`) ; Salle des Plumes laissée aux joueurs. |
| 04/11/2026 | V6 | Palais des Ambassades | Copie du Quartier des Ambassades de Luthécia (nouveau bâtiment `palais-ambassades-novomirsk`, pour ne pas hériter des contrôles d'accès propres aux ambassades ouvertes en Républia). Bureaux de Républia, d'Al-Khalija et d'El Estado ; ambassadeurs nommés par Fred : **Hubert de La Courtoisie**, **Cheikh Rachid Al-Diplomi**, **Don Esteban Cortesano**. Tous les ordres « Bientôt disponible » jusqu'au voyage entre empires. |
| 04/11/2026 | V7 | Pavillon des Ambassadeurs | Appartements de luxe, pas spécialement réservés aux ambassadeurs : l'équivalent des suites de l'hôtel Républica (nouveau bâtiment `pavillon-ambassadeurs-novomirsk`). **Trois suites** louables à 500 FR/jour : Suite Privée (+8 INF +10 DIS) et Suite Présidentielle (+8 POP +8 INF +2 DIS) à l'identique, **Suite du Parti (+10 POP +6 INF +2 DIS)** ; une **grande salle de réception** (copie de celle des ambassadeurs, sans ordre) ; un **bar** (copie du Bar du Républica : commerce `bar`, boissons et snacks). PNJ nommés par Fred : **Arkadi Belov** (maître d'hôtel), **Lena Abramova** (serveuse façon traiteur). « Organiser une rencontre piège » non repris (aucune agence d'escorts à Novomirsk). |
| 04/11/2026 | V4/V5 | Grand Hôtel de Sovarka | **Plus de suites** (elles sont au Pavillon) : pièces `suite_privee` et `suite_presidentielle` exclues, ordre « Louer une suite » retiré. Lecture retenue de « n'aura que des chambres, pas de suites » : seules les suites sont retirées ; restaurant et bar de l'hôtel restent en place, à confirmer par Fred. |
| 04/11/2026 | V7 | Résidence impériale | Logements de prestige louables comme les suites du Pavillon (nouveau bâtiment `residence-imperiale-novomirsk`) : **quatre appartements à 500/jour (+4 POP +4 INF +4 DIS)** et **un grand appartement à 1 200/jour (+15 POP +15 INF +5 DIS)**. Gardien anonyme. |
| 04-05/11/2026 | V8 | Entrepôt Logistique | Interface copiée de Luthécia (nouveau bâtiment `entrepot-logistique-novomirsk` : Salle des Ventes, Bureau de Direction), **tous les ordres « Bientôt disponible »** jusqu'à l'économie de Sovarka (décision de Fred du 04/11). Directeur PNJ : **Boris Stockov** (nom choisi par Fred le 05/11). Pas encore de ligne `entrepots_par_ville` ni d'état serveur : à ajouter quand l'approvisionnement de Sovarka sera décidé. |
| 05/11/2026 | V8 | Direction du Renseignement de Sovarka | **Siège du renseignement militaire, bâtiment du socle** (`siege-renseignement`) : il fait partie de l'architecture commune même si un empire ne l'utilise pas ; la Républia ne le liste pas (son ministre de la Défense garde l'ordre au Palais), Sovarka si, et d'autres empires plus tard. Trois pièces : **Accueil**, où le **Sergent Viktor Muetov** (nom de Fred) vous accueille froidement ; **Salle des Écoutes**, avec l'ordre existant « Renseignement militaire » (ministre de la Défense ; à Novomirsk l'ordre vit là, pas au Palais) ; **Salle d'Interrogatoire**, copie de « Interroger un détenu » du QHS (2 PA, 75 %, +5 INF), réservée au ministre de la Défense. Migration `20261105004500_siege_renseignement_militaire` appliquée. |
| 05/11/2026 | V11/V12 | Caserne centrale de Novomirsk | **Socle de la caserne de Républia** (`caserne-militaire` : sept pièces, mêmes ordres, mêmes fonctions serveur), avec une différence : **en Sovarka la caserne est en ville**, et non dans une zone hors ville. Deux entrées (V11 et V12), sortie par V12 ; plus de taxi vers la caserne au Centre multimodal de Novomirsk. Le serveur demande désormais où est la caserne d'un pays (`caserne_ville`, `caserne_noeud`) pour l'incorporation, la création d'une compagnie, le repli et le retour d'un soldat neutralisé (migration `20261105200100_caserne_novomirsk_en_ville`). PNJ propres validés par Fred : **Commandant Igor Saveliev**, **Adjudant Piotr Antipov** (corps de garde), **Infirmière Olga Komarova**, **Caporal Vassili Kachaev** (réfectoire), **Caporal Dimitri Loguinov** et **Soldat Sacha Iline** (quartier des troupes) ; armurier et archiviste anonymes. Les quatre référents parlent comme ceux de Luthécia (fiches générées depuis les leurs, noms et lieux de Novomirsk). |
| 05/11/2026 | V11 | Garage de Novomirsk | **Véhicules personnels** (socle commun, règles complètes dans `GAME-DESIGN-VEHICULES.md`) : seul garage PNJ du jeu, garagiste **Sergueï Zaptchastov** ; vente de voitures, deux-roues et utilitaires avec leur clé, révision, dépannage. Station-service PNJ de Krasnov (rue de la station et du musée), gérante **Lioudmila Zapravkina**. Route Novomirsk ↔ Krasnov seulement ; Starovka n'est pas reliée. Images à venir. |
| 06/11/2026 | V12 | Salon de coiffure de Novomirsk | **Nouveauté** (règles complètes dans `GAME-DESIGN-SALON-COIFFURE.md`) : commerce de services et d'accessoires non alimentaires (mécanique générale des fonds) ; coupe **+5 POP, CHA +1 jusqu'à minuit sans cumul, une coupe tous les 3 jours** ; relooking premium cosmétique (backlog) ; tenu par la PNJ **Ludmila Egorova**, local rachetable par un PJ ; **prix de Sovarka à décider** (coupe « Bientôt disponible »). Images à venir. |
| 06/11/2026 | V14 | Logements collectifs de Novomirsk | **En Sovarka, tous les logements hors suites sont des logements sociaux**, sur la mécanique de Montrouge (demande à la mairie par un résident officiel, attribution par l'adjoint au maire, loyer à la commune, résiliation au départ). **4 petits à 10 PSK** (+3 moral +4 santé au sommeil) et **4 grands à 20 PSK** (+5 moral +7 santé) ; loyers arrondis par Fred depuis la règle du PA (15 PSK contre 50 FR). Plus d'appartements avec une navigation lisible : à réfléchir (#498). Images à venir. |
| 06/11/2026 | V14 | Pharmacie officielle de Novomirsk | **Commerce comme tous les commerces** : 2 familles et 4 articles en freemium, 3 familles et 10 articles en premium (règle générale, #500) ; vend des **médicaments** (types et effets à définir plus tard : vente « Bientôt disponible ») ; tenue par la PNJ **Valentina Pilioulkina**, commerce rachetable par un PJ (prix à décider). Rappel : seule une personne domiciliée à Novomirsk peut y demander un logement social (règle déjà appliquée par le serveur). Images à venir. |
| 06/11/2026 | Toutes | PNJ hérités du gabarit, trois villes | **Les PNJ de Républia présents en Sovarka sont renommés** (demande de Fred : Palais du Gouvernement, Palais présidentiel, Grand Hôtel, Assemblée, tribunal, commissariat, mairies, notaire, centres d'affaires, commercial et artisanal, douanes, loge, ancienne zone de caserne, QHS). Noms sovarkiens proposés par Claude sur mandat de Fred, **à sa relecture** : table `PNJ_SOVARKA` à la fin de `data.js`. Des noms distincts par ville (règle « pas de connexion entre les villes »), et Starovka au type mongol / bouriate. Le notaire de Novomirsk s'appelle **Camarade Bâtissov**, nom déjà prévu par la quête de carrière. **Portraits de Républia retirés**, à remplacer. Les intitulés génériques (Guichetier, Hôtesse…) gardent leur nom, sans portrait ; le Garde républicain devient **Garde du Peuple**. Fiches de dialogue dérivées de celles de Républia (`api/_pnj-sovarka.js`). Républia inchangée (vérifiée à l'identique). |
| 06/11/2026 | Commissariat | Bureau du Commissaire de Novomirsk | **Le commissaire seul** : le bureau a son image et son personnage (Vassili Ostrovski) ; l'inspectrice (Bronislava Jarova, héritée de Brigitte Menottes) est retirée. Luthécia inchangée (Brigitte y porte la quête criminelle). |
| 06/11/2026 | Notaire | Office notarial de Novomirsk (et mairies, tribunaux, terrains des trois villes) | **En Sovarka, la propriété privée n'existe pas : l'État possède les murs ET le fonds.** Acheter un commerce ne donne pas la propriété mais un **droit d'exploiter**, **sans limite de durée**, que **seul le tribunal** (le juge) peut retirer, **sans indemnité**. Le droit **s'échange de PJ à PJ**, la cession étant **enregistrée par le notaire**, **sans prix officiel** (l'État possède tout ; les PJ s'arrangent entre eux). **La caisse appartient à l'exploitant tant qu'il exploite** : il peut la vider avant de céder, le repreneur n'ayant aucun frais, une caisse vide n'est pas scandaleuse. **Au décès, le droit revient à l'État** ; l'argent et les objets restent transmissibles (testament maintenu). **Un PJ ne peut pas acheter de terrain en nom propre** : il dépose une **demande d'ouverture de commerce à la mairie** ; le maire examine les demandes **deux fois par mois** et construit à chaque fois un **bâtiment collectif** (mixte commerces/logements, ou uniquement des commerces), **tout payé par la mairie** ; sans financement, le dossier attend et **reste valide**. Le maire clique « Accepter » en face du candidat ; le candidat reçoit un **mail d'acceptation** et va **signer l'attribution chez le notaire**, qui tient (comme le maire) la **liste des commerces non attribués** et **enregistre** l'attribution sans la décider. Sans maire, **l'adjoint** décide ; sans adjoint, le **ministre de l'Économie collective** (= ministre des Finances, `min_fin`). **Loyer très bas fixé par le maire, de 0 à 100 PSK** pour les plus grands locaux ; **pas de droit au bail**. À l'accueil du notaire, **la secrétaire seule**, sous le nom de l'ancienne clerc (Klara Delounova). Code : migrations `20261106133000` et `20261106140000`, `plateau-sovarka-droits.js` ; voir la section « Droits d'exploiter » ci-dessous. |
| 06/11/2026 | V16 Quai du marché | Marchande de poissons | **Commerçante comme au marché**, tenue par une PNJ (**Galina Karpova**, nom validé par Fred le 06/11). Elle vend du **poisson de rivière, légèrement moins cher qu'à l'entrepôt**, mais **12 poissons par jour au plus** (pour toute la ville) ; au-delà elle répond : « Désolé, il faut que mon mari relève les filets, on a tout vendu la précédente pêche. » Elle **connaît les rumeurs de la ville et peut en colporter** (ordres existants « Écouter les rumeurs » et « Lancer une rumeur »). Son **mari est contrebandier, via elle** : un marché noir propre à l'étal, où il fait passer par la rivière **ce que la Sovarka importe officiellement de Républia, alcool et médicaments**, moins chers que le circuit d'État ; achat illégal (détection, trace découvrable par le commissaire). **Valeurs proposées par Claude, validées par Fred le 06/11** : poisson à 75 % du prix de référence de l'entrepôt (3 PSK au lieu de 4) ; contrebande à 80 % (alcool 11, médicaments 18), 1 PA, arrivage de 10 unités par jour ; détection et barème du délit mineur existants (comme la contrebande portuaire : 20 %, 2 jours, 500). L'argent du poisson va à la caisse de l'étal ; celui de la contrebande sort de l'économie déclarée. Si un PJ reprend l'étal, la pêche et la contrebande du mari s'arrêtent (elles sont attachées à la PNJ). Migration `20261106172000_poissonniere_novomirsk`. Images à venir. |
| 06/11/2026 | V18 | Usine pharmaceutique Pharmanov | **L'usine pharmaceutique du pays, rien de spécial** : usine du socle (mêmes pièces, ordres et fonctions serveur que l'usine de Républia), état propre à Sovarka ; **directeur nommé par le ministre de l'Économie collective** ; PNJ directeur **Boris Kovaliov** (nom proposé par Claude, à valider). Les sels d'ammoniaque restent propres à l'Assemblée de Républia. Fred génère les images. Migration `20261106173500_usine_pharmanov_novomirsk`. |
| 06/11/2026 | V18 | Usine Pharmanov, salaire de production | En Sovarka (un PA ≈ 15 PSK), le **salaire de production se situe entre 15 et 20 PSK par PA** (Fred). Retenu : **médicaments 18 PSK, désinfectant 15 PSK**. Table serveur `salaires_production_pays` (un pays sans ligne garde le salaire du gabarit) ; migration `20261106184000_salaires_production_par_pays`. |
| 06/11/2026 | V18 | Musée de la République de Sovarka | **Copie du Musée National de Républia** (bâtiment du socle `musee-national-republia`, mêmes 12 salles et ordres) ; **les différences propres à Sovarka seront codées ensuite** (Fred). En attendant : images à venir, pas d'audioguide (ceux de Républia), figures des salles vides (pas de personnalités de Républia hors Républia). Migration `20261106194500_novomirsk_musee_national`. |
| 06/11/2026 | — | Grand Hôtel de Sovarka, accueil | Images posées par Fred (accueil, restaurant, bar, chambres). Nom aligné sur l'enseigne : **Grand Hôtel de Sovarka** (ex-« Hôtel Kollektiv »). **Accueil : deux PNJ seulement**, la réceptionniste **Vera Pavlova** et le bagagiste **Ivan Semionov** (noms et fiches proposés par Claude, à valider), portraits tirés de l'image de la réception. Olga Soupe, Boris Betterave et Natasha Privilege, qui s'affichaient à l'accueil, sont retirés en attendant le tour du restaurant et du bar. |
| 06/11/2026 | — | Grand Hôtel de Sovarka, bar et restaurant | **Gardés : la capitale doit être opulente** (Fred ; exception à la règle « hôtellerie et restauration séparées » de province, comme La Républia à Luthécia). **Bar** : un barman (**Arkadi Melnikov**), un espion assis au comptoir (**Gleb Lazarev**, affiché « Habitué du bar », ne l'avoue jamais), une escort à la broche (**Anouchka Rodionova**). **Restaurant** : un serveur seulement (**Pavel Denissov**). Noms et fiches proposés par Claude, à valider ; portraits tirés des images. Retirés : Kostia, Natacha, Julien, Leonid Orlov ; Smetanine, Vodkaïev, Blinova, Partiïev, Macha Scoopova. |
| 06/11/2026 | — | Grand Hôtel de Sovarka, carte du restaurant | **3 menus russes** (Fred : « partons là-dessus ») à la place des 3 menus de Républia : **Impérial** (caviar Beluga sur blinis, esturgeon braisé au champagne, charlotte russe ; 2 poissons + 1 céréales), **des Tsars** (bortsch impérial et pirojki, bœuf Stroganoff, pavlova ; viande, fruits et légumes, céréales), **du Plan** (salade Olivier des banquets officiels, pelmenis « selon les quotas », paskha ; viande, céréales, fruits et légumes). Réglages de La Républia (3 PA, 5 portions, +10 santé, +1 moral, +3 PA au prochain Dormir). **Prix 40 PSK**, proposé par Claude (125 FR de Luthécia à l'échelle de Sovarka), à valider. Migration `20261106213500_grand_hotel_sovarka_carte`. |

**Méthode (Fred, 04/11/2026)** : d'abord l'interface intérieure de chaque bâtiment, avec ses
différentes pièces ; Fred générera ensuite les images avec ChatGPT. En attendant, un bâtiment
copié porte `imagesAVenir: true` dans son `buildingContext` : ses pièces s'affichent sur leur
fond, sans emprunter les images de la ville d'origine.

**Direction artistique de Starovka (Fred, 06/11/2026)** : les rues sont presque vides, et c'est voulu,
puisqu'il y fait un froid polaire. On trouve les gens à l'intérieur des bâtiments. Les habitants y sont
**accueillants**, avec un **type mongol / bouriate** (peuples de Sibérie et des steppes), pas un type
slave par défaut. Référence de style : le hall de la gare de Starovka (`images/Sovarka/Starovka/Starovka_gare_hall.webp`),
soit une lumière chaude dedans et le froid visible dehors. Cela vaut pour les images des intérieurs et pour les portraits de
PNJ de Starovka. Krasnov garde son ambiance de province slave en automne.

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


## Droits d'exploiter : ce qui est codé (06/11/2026)

- **Locaux attribuables** (`sovarka_locaux`) : les 7 locaux des centres commercial et artisanal de chaque ville, les commerces tenus par un PNJ (garage, salon, pharmacie, station : le « rachat » n'existe pas en Sovarka, ils s'attribuent comme les autres) et les locaux des immeubles collectifs. Le guichet « Louer ce local » est fermé en Sovarka (`attribution_municipale`).
- **Mairie** : « Demander un commerce » (1 PA, un dossier actif par ville) ; « Dossiers commerciaux » pour l'autorité : accepter en désignant un local libre, ou sans local (le dossier attend l'immeuble), fixer les loyers, choisir mixte ou commerces seulement.
- **Notaire de Novomirsk** (seul notaire de Sovarka) : « Commerces non attribués », « Signer une attribution » (1 PA), « Céder ou reprendre un droit d'exploiter » (1 PA pour proposer, 1 PA pour accepter). Vente de terrain, murs, rachat, préemption et transfert de compromis retirés.
- **Tribunal** (bureau des magistrats) : « Retirer un droit d'exploiter », réservé au juge de la ville (1 PA, motif obligatoire, mail à l'exploitant).
- **Immeubles collectifs** : la passe de minuit (`urbanisme_sovarka`) lance, le 1er et le 15, un immeuble par ville sur un terrain à bâtir libre, dimensionné aux dossiers acceptés qui attendent ; il est payé par la caisse de la mairie, ou attend les fonds ; à la livraison, les locaux vont aux dossiers dans l'ordre d'acceptation (mail), et les logements d'un immeuble mixte rejoignent les logements sociaux de la ville (attribués par l'adjoint comme les autres). Les terrains de Sovarka n'ont plus d'ordres d'achat ou de chantier privé.
- **Valeurs provisoires proposées par Claude, à valider par Fred** : 1 000 PSK de construction par local (commerce ou logement), chantier de 7 jours, logements d'immeuble au loyer des petits logements (10 PSK), autant de logements que de commerces dans un immeuble mixte ; plafond de loyer des locaux d'immeuble 50 PSK, et des locaux des centres proportionnel à leur loyer de Républia (vitrine 100, boutique 50, arrière-boutique 19, cave 10 ; échoppe 75, atelier 38, réserve 13) ; loyer de départ 0 tant que le maire ne l'a pas fixé ; les commerces PNJ attribués n'ont pas de loyer.
- **Limites** : un seul immeuble par terrain (5 à Novomirsk, 1 à Starovka, 1 à Krasnov) : au-delà, les dossiers attendent ; la fiche de dialogue de Klara Delounova reste celle de la clerc dont elle hérite.

## Galeries de Novomirsk (06/11/2026, décisions de Fred)

- **Entrée** : les deux PNJ hérités de Luthécia (voleuse et magicien) sont retirés ; un seul PNJ, le **portier** visible sur l'image, **Ignat Frolov** (nom proposé par Claude, à valider), portrait tiré de l'image, fiche de dialogue à relire.
- **Locaux** : deux grands (Grand local A, Grand local B) et deux moyens (Local moyen A, Local moyen B), images de Fred.
- **« Demande de location »** (remplace « Attribution par la mairie » dans tous les locaux des centres de Sovarka) : une lettre adressée à la mairie décrit le bien (nom du local, emplacement, description) ; le nom du PJ demandeur y figure ; une ligne facultative « activité envisagée ». À l'envoi (1 PA, même coût que la demande déposée à la mairie), la demande rejoint les **Dossiers commerciaux** du maire, avec le nom du demandeur et le **local demandé**, présélectionné s'il est encore libre. Une seule demande active par PJ et par ville (règle existante) ; plusieurs PJ peuvent demander le même local, le maire choisit. Il faut être dans le local pour écrire la lettre ; un local exploité ou déjà attribué la refuse.
- Fonction serveur `sovarka_demande_location` (migration `20261106230000_sovarka_demande_location`, appliquée) ; banc annulé `outils/bancs/banc-sovarka-demande-location.sql`.

## Marges des commerces en Sovarka (06/11/2026, décision de Fred)

- Mêmes ratios qu'en Républia, sans exception pour Novomirsk : un PNJ vend à **2 fois** son coût de revient, un PJ peut monter jusqu'à **4 fois**. Le coût de la main-d'œuvre, bien plus bas en Sovarka, suffit à faire la différence. « On reste là-dessus, sans complexifier. »
- Le coefficient serveur de Sovarka manquait (un commerçant PJ ne pouvait pas fixer ses prix) : migration `20261106232000_coef_prix_max_pj_sovarka`, appliquée.
- Novomirsk reste l'exception opulente de Sovarka (« plus la Russie des Tsars que l'URSS ») : plafonds de loyer des Galeries à **150 PSK/jour pour chaque grand local et 75 PSK pour chaque moyen** (validé par Fred le 06/11 ; ailleurs en Sovarka, 100 PSK pour le plus grand local). Migration `20261106233000_galeries_novomirsk_plafonds_loyer`, appliquée.
- **À faire quand Novomirsk sera terminée** (Fred, 06/11) : relever les bâtiments qui n'ont pas de loyer.

## Commerce Premium gratuit pendant la bêta (06/11/2026, décision de Fred, socle commun)

- « L'option premium est gratuite pendant la bêta, ça permet de voir si elle fonctionne bien. Quand elle sera payante, on ne pourra pas souffrir de bugs. »
- Dans l'écran de gestion de son commerce, le propriétaire active « Commerce Premium » gratuitement : 3 types d'activité et 10 articles au lieu de 2 et 4 (règle des commerces du 06/11), attaché au fonds (transmis à la vente, perdu à la résiliation du bail). La génération d'image et les codes promotionnels restent « bientôt ».
- Les commerces déjà au-delà du gratuit (plus de 2 types ou de 4 articles) sont passés premium d'office, sans rien perdre. Migration `20261106234500_commerce_premium_beta`, appliquée (constantes, `fonds_premium_activer`, plafonds lus sur le fonds). Le jour du paiement : `commerce_premium_gratuit_beta` à 0 et un opérateur de paiement à raccorder.

## Centre d'affaires de Novomirsk (07/11/2026, décisions de Fred)

- Accueil : **Valery Burov** (réceptionniste) et **Pietr Kastanov** (agent de sécurité).
- **Bureaux prestige A et B** : attribués selon le schéma des locaux commerciaux de Sovarka, même cheminement que les Galeries (« Demande de location » depuis le bureau, dossiers du maire, signature chez le notaire). Loyer **150 PSK/jour** (plafond 150). On peut y installer le siège d'une association et du matériel. Guichet « Louer ce local » fermé.
- **Salles de réunion** (deux grandes à 150 PSK, deux moyennes à 100 PSK) : location à la journée, **sans approbation du maire** (location courte durée). À enrichir : on pourra y créer des événements (assemblées générales, conseils d'administration…), à concevoir avec Fred.
- **Événements en salle de réunion** (Fred, 07/11 : idées 5 et 6 de Claude) : conférence de presse, soirée de réseautage, séminaire de formation, buffet du Grand Hôtel ; réservés à celui qui a loué la salle, pour les PJ présents. Valeurs proposées par Claude, **validées par Fred le 07/11** : conférence de presse +3 POP +1 par présent (max +10) ; réseautage +2 INF à chaque présent, +1 INF par participant à l'organisateur (max +8) ; séminaire +1 à la caractéristique choisie jusqu'à minuit, sans cumul ; buffet 40 PSK par présent au restaurant du Grand Hôtel, +2 PA chacun.

## Organisation du pouvoir en Sovarka (Fred, 07/11/2026)

Sovarka n'a pas le circuit de la Républia (président → Premier ministre → ministres) : organisation propre, volontairement parodique.

- **Semaine à la gloire des partis** : elle remplace la semaine électorale. Les partis recrutent des partisans par les **tracts, avec la mécanique du vote de Républia** (tracts distribués aux PNJ présents en jeu ; le « candidat » est un parti). En fin de semaine, compte des **adhérents PJ (volontaires) + partisans PNJ (recrutés par tractage)** : le parti qui en a le plus l'emporte.
- **Élection présidentielle conservée, la même semaine.** Le président élu est **obligé de nommer chef du gouvernement le chef du parti vainqueur**.
- **Chef du gouvernement** : nomme les ministres, **uniquement parmi les membres de son parti**.
- **Président** : aucun pouvoir (il nomme une personne qui lui est imposée), mais des avantages : un repas gratuit par jour dans ses appartements ; il peut y recevoir un invité et lui offrir à manger ; un salaire ; il compte comme **dignitaire** et peut à ce titre être invité par un autre chef de gouvernement ou par des ambassadeurs.
- **Élection présidentielle comme en Républia** (même vote, mêmes tracts) ; pendant la semaine, les tracts servent donc aux partis et aux candidats, le joueur choisit sa cible.
- **Salaires** : président 800 PSK, Président du Conseil du Peuple 700 PSK, ministre 560 PSK.
- **Intitulés** (proposés par Claude, validés par Fred) : Président de la République de Sovarka ; Président du Conseil du Peuple (chef du gouvernement) ; ministre de la Sécurité du Peuple (Intérieur) ; ministre de l'Économie collective (Finances) ; ministre de la Justice prolétarienne ; ministre de la Défense de la Patrie ; ministre de la Vérité officielle (Information) ; ministre de l'Amitié entre les Peuples (Affaires étrangères).
- **Soviet Suprême** : les sièges de députés sont **répartis entre les partis à la proportionnelle des partisans** de la semaine à la gloire ; chaque chef de parti désigne ses députés.
- **Lois (décision de Fred, 08/11/2026)** : le Soviet Suprême **approuve toujours, à l'unanimité** (parodie : « le Parti ne connaît pas le désaccord ») ; les lois viennent du gouvernement et le Soviet ne fait qu'entériner. **Dépôt des projets de loi : par les partis** — chaque parti peut déposer un projet de loi (décision de Fred, 08/11). **Circuit (Fred, 08/11)** : le projet est d'abord examiné par le **Président du Conseil du Peuple**, qui **tranche seul**, sans réunir ses ministres ; s'il l'accepte, la loi est **promulguée aussitôt**, puis soumise aux députés « pour approbation » alors qu'elle s'applique déjà — pour bien montrer que les députés n'ont aucun pouvoir. **Approbation (Fred, 08/11)** : « Approuver » ou « S'abstenir » ; l'abstention est permise mais **notée** (signalement à la cellule de surveillance des partis du Capitaine Balatov, perte de **5 POP** pour le parti par abstention, décision de Fred du 08/11 : une désobéissance plus grave qu'un refus d'adhésion). **Pas de chambre des députés** : ils sont **convoqués par mail une fois par semaine, le jeudi**, au Palais du Gouvernement, dans la **Salle du Conseil du Peuple**, pour approuver ou s'abstenir. **Indemnité de député : 250 PSK/jour** ; le député qui ne se déplace pas la perd **pour toute la semaine**, jusqu'à la convocation suivante (7 jours, 1 750 PSK ; décision de Fred, 08/11), ce que le mail précise. **À coder plus tard, sur la liste d'ordres que Fred prépare.**
- **Ministères (08/11/2026)** : chaque ministre de Sovarka part des ordres de son homologue de Républia (socle), puis on ajoute ou retire ministère par ministère selon le background.
- **Manifestations (Fred, 08/11/2026)** : en Sovarka, **seules les manifestations de soutien** sont permises (en faveur du parti au pouvoir ou du gouvernement) ; toute manifestation hostile est interdite d'office et ses participants sont arrêtables. **Pas de manifestation spontanée en Sovarka** (l'ordre de place commun est retiré des villes de Sovarka) : uniquement des manifestations de soutien organisées. **Organisées par les partis** (Fred, 08/11) : chaque parti peut organiser une manifestation de soutien, mais seulement en faveur du parti au pouvoir ou du gouvernement ; pour un parti d'opposition, c'est une façon de faire allégeance. **Effet** (Fred, 08/11) : +1 POP au parti au pouvoir par participant, comme en Républia, **rien pour le parti organisateur** (l'allégeance est gratuite et ne sert qu'à se faire bien voir).
- **Fiscalité de Sovarka (Fred, 08/11/2026)** : les **mairies** reçoivent les **loyers** ; l'**État** reçoit un impôt de **10 % sur les ventes** et de **10 % sur la main-d'œuvre** ; les **recettes municipales** sont elles aussi taxées à **10 %** au profit de l'État. **Taux modifiables par le ministre de l'Économie collective** (Fred, 08/11), comme le ministre des Finances de Républia (bornes de Républia reprises par défaut). Le droit de préemption du ministre de l'Économie collective est retiré (l'État possède déjà murs et fonds).
- **Retrait d'un droit d'exploiter (Fred, 08/11/2026)** : seul le **ministre de la Justice prolétarienne** peut saisir le juge contre un exploitant, sans avoir à se justifier ; le juge décide. Juge PJ : décision libre ; **juge PNJ : donne toujours raison au ministre** (retrait automatique ; Fred, 08/11).
- **Censure (Fred, 08/11/2026)** : le ministre de la Vérité officielle censure **légalement et sans risque** La Tribune et les forums de Sovarka : c'est son métier. **Sondages** (Fred, 08/11) : le sondage commandé est réel, le ministre seul reçoit les vrais chiffres et choisit de le publier tel quel, de l'enterrer, ou de le **publier en faussant le résultat**. Un sondage faussé peut être **démasqué** : par une **fuite** (les vrais chiffres sont conservés aux Archives du gouvernement, ordre existant « Produire une fuite » ; le ministre démasqué perd alors **10 POP**, Fred 08/11) et par **piratage** (combo ordinateur + box, quand il existera).
- **Conscription (Fred, 08/11/2026)** : pas de service militaire obligatoire par défaut ; le **ministre de la Défense de la Patrie** peut déclencher une **conscription**, qui appelle les PJ de Sovarka **sans poste**. L'appelé reçoit une **convocation par mail** et a **48 h pour se présenter à la caserne** ; passé ce délai, il est **réfractaire et recherché**. Le service dure **jusqu'à ce que le ministre lève la conscription**, pour tous les appelés à la fois.
- **Président du Conseil du Peuple (Fred, 08/11/2026)** : garde « Nommer des ministres » et « Révoquer un ministre » ; le **vote de confiance est retiré** et remplacé par l'**« Autocritique publique »** : il contraint un ministre à une autocritique publiée dans la presse ; le ministre perd **5 POP** mais garde son poste, le Président du Conseil en gagne **2** ; **une autocritique par ministre et par semaine** au plus.
- **Amitié entre les Peuples** : ordres « Bientôt disponible » tant que le voyage inter-empires n'existe pas.
- **Maires** : élus comme en Républia, mais **tout candidat doit d'abord adhérer à un parti**. **Même règle pour la présidentielle** : tout candidat à un poste électif de Sovarka est membre d'un parti.
- **Cas limites** (proposés par Claude, validés) : égalité entre partis → le plus d'adhérents PJ, puis le plus ancien ; aucun parti en Sovarka → le président nomme librement le chef du gouvernement.

### Pouvoir en Sovarka : ce qui est codé (07/11/2026)

- **Intitulés** : `INTITULES_POSTES_PAR_PAYS` + `intitulePoste()` (`data.js`) ; journal du matin (`api/_journal-collecte.js`). Bureaux et rôles des PNJ du Siège du Comité Central aux nouveaux intitulés (images des bureaux à venir).
- **Salaires** (migration `20261107094000`) : le pays employeur se lit au registre (`postes_attribues`, puis `cycles_electoraux` pour un élu), plus au barème unique.
- **Partis** (`20261107120000`) : organisations de type `politique` de Sovarka (`sovarka_parti_de`) ; candidature à la présidence ou à une mairie refusée sans parti (`parti_requis`) ; pas de candidature de député (`depute_designe_par_parti`).
- **Semaine à la gloire** (`20261107121500`) : cycles de Sovarka créés (présidentielle, trois mairies, `gloire_partis` au calendrier de la présidentielle) ; les candidats du cycle de la gloire sont les partis (resynchronisés chaque nuit) ; les tracts visent le **nom du parti** ; décompte à la proclamation par `sovarka_gloire_proclamer` (avant la présidentielle de la même nuit) ; 9 sièges du Soviet Suprême aux plus forts restes sur les partisans (sur le total si aucun partisan) ; chef du parti vainqueur nommé d'office Président du Conseil du Peuple (sauf s'il est déjà président ou maire : `chef_deja_elu` ; **le chef désigne alors qui il veut parmi les membres de son parti**, depuis « Mon parti », décision de Fred du 08/11, migration `20261108001500` ; Fred note qu'un parti n'a de toute façon aucun intérêt à présenter son chef aux présidentielles) ; tant qu'un parti a gagné, le président ne nomme plus le pm (`pm_impose_par_le_parti`) ; ministres choisis parmi les membres du parti du pm (`ministre_hors_parti`). **Quand le pm change de parti, les ministres en place gardent leur poste** (décision de Fred, 08/11 : le parti était majoritaire, un seul départ ne change pas la logique) ; conforme au code.
- **Députés** (`20261107123000`) : à l'hémicycle du Soviet Suprême, le chef de parti désigne ou retire ses députés, dans la limite de ses sièges ; la fiche porte « Député du Soviet Suprême » ; la législature sortante perd ses sièges à la proclamation suivante. Aucun salaire de député de Sovarka (non décidé).
- **Repas du président** (`20261107124500`, effets choisis par Fred le 07/11 : ceux du dîner d'affaires) : pièce « Appartements présidentiels » au Palais du Parti (`20261107130000` pour la navigation serveur) ; un repas par jour, seul ou avec un invité présent : +10 Santé, +2 Moral, +5 INF, +3 PA au prochain Dormir pour chacun. Image à venir.
- **Reste** : statut de dignitaire à raccorder quand les invitations des ambassades et entre gouvernements existeront (voyage inter-empires).

### Ministères de Sovarka : ce qui est codé (08/11/2026)

- Migrations `20261108013000_sovarka_pouvoir_ministeres` et `20261108023000_sovarka_manif_mairie_couts` (appliquées) ; `sovarka_pouvoir_lire` / `sovarka_pouvoir_commande` ; passe de nuit `sovarka_pouvoir_passe` (tâche `sovarka_pouvoir`) ; écran `plateau-sovarka-pouvoir.js`.
- **Lois** : « Mon parti » → « Déposer un projet de loi » (chef, 1 PA ; déclarative, interdiction d'une catégorie entière, abrogation) ; bureau du Président du Conseil → « Projets de loi à trancher » (promulgation = loi adoptée et appliquée à l'instant) ; Salle du Conseil du Peuple → « Séance du jeudi » (émarger, approuver / s'abstenir). Ordre du jour d'un jeudi : lois promulguées du vendredi précédent à ce jeudi. Indemnité payée chaque nuit sur la caisse du Soviet (`soviet_assemblee`, plafonnée à son solde).
- **Manifestation de soutien** : depuis « Mon parti » ; elle part de la mairie (pas d'ordre de rue en Sovarka) avec au moins 10 manifestants du groupe du chef présents dans la mairie (1 PA) ; une par ville et par jour.
- **Fiscalité** : taxe de transaction 0 % local / 10 % national ; 10 % de la main-d'œuvre (production des commerces, fabrication des véhicules) et 10 % des recettes municipales (loyers…) versés au Trésor (`budgets_nationaux.soviet.reserveJour`) ; trois curseurs au bureau du ministre. **Redistribution nationale (décision de Fred, 08/11/2026, « socle adapté »)** : chaque nuit, dotation fixe de **24 600 PSK** + impôts du jour, répartis par la cascade du socle (`budget_cascade_quotidienne`, lancée par `sovarka_pouvoir_passe` avant les indemnités) depuis la caisse de l'Économie collective : Présidence **3 %** (aucun pouvoir), Président du Conseil 9 %, Sécurité du Peuple **15 %** (État policier), Économie collective 9 % (conservés), Justice 9 %, Défense 9 %, Vérité officielle 9 %, Amitié entre les Peuples 9 %, Palais du Gouvernement 9 %, **Soviet Suprême 19 %** (couvre les indemnités : ≈ 4 675 PSK/nuit pour 2 250 dus) ; Défense → Caserne 65 % comme en Républia. Clés dans `repartitions_budgetaires` (pays `soviet`), modifiables par le ministre de l'Économie collective comme en Républia. Nota : la question posée à Fred citait l'ancienne clé de Républia (15/12/10/8 %) ; la clé réelle (9 % par caisse, Assemblée 19 %) a été adaptée dans le même esprit (président fortement réduit, Sécurité du Peuple renforcée, indemnités couvertes). Migration `20261108170000_sovarka_tresor_signalements`.
- **Justice** : « Saisir le juge » (1 PA) au bureau du ministre ; le juge PJ traite « Saisines du ministre » au tribunal (retirer ou rejeter) ; sans saisine, plus de retrait.
- **Vérité officielle** : « Commanditer un sondage » (1 PA, 200) → popularité réelle des partis, puis « Sondages en attente » ; « Produire une fuite » aux Archives révèle le dernier sondage faussé (acte illégal tracé ; −10 POP au ministre). Censure sans risque.
- **Conscription** : bureau du ministre de la Défense ; à la caserne de Novomirsk « Se présenter (conscription) » dépose l'engagement de soldat (1 PA) ; pas de démission tant que la conscription n'est pas levée ; à la levée, retrait des sections et fin de l'avis de recherche.
- **Autocritique publique** : bureau du Président du Conseil (1 PA), publiée au forum national. Vote de confiance et préemption fermés en Sovarka.
- **Coûts en PA confirmés par Fred (08/11/2026)** : dépôt de loi 1, saisine 1, autocritique 1, manifestation 1 par manifestant ; émargement, approbation et conscription gratuits.
- **Registre des signalements de la cellule Balatov (décision de Fred, 08/11/2026)** : dossier consultable, **sans effet automatique** — lisible par le Président du Conseil et le ministre de la Sécurité du Peuple (ordre « Registre des signalements » dans leurs bureaux) ; les PJ en font usage (révocation, pression, saisine…). « Produire une fuite » aux Archives propose désormais deux pièces : le dernier sondage truqué, ou le registre (signalements des 30 derniers jours, publié au forum national ; acte illégal tracé).
- **Surveillance d'un citoyen (décisions de Fred, 08/11/2026)** — seul ajout propre à la Sécurité du Peuple (indicateurs et passeport intérieur écartés par Fred). Ordre « Placer sous surveillance » au bureau du ministre : **4 jours**, **2 PA** au ministre, **150 PSK** sur la caisse du ministère. **Rapport garanti chaque matin**, par courrier et consultable au bureau : **tous les déplacements** de la cible et **les PJ croisés** dans chaque lieu ; hors de Sovarka, « hors du territoire ». **Risque de découverte** chaque nuit, selon la **perception** et l'**intelligence** de la cible et la **sécurité de la ville** (10 % + 1,5 × (PER − 10) + 0,5 × (INT − 10) − (ISN − 30) / 5, borné 2-40 % ; ≈ 1 chance sur 3 sur 4 jours pour un personnage moyen) : la cible reçoit un courrier anonyme (« impression d'être suivi »), sans savoir qui ni pourquoi, et la surveillance continue. **Toute cible**, ministres et Président compris. **3 surveillances simultanées** au plus, une seule par cible. Code : migrations `20261108180000_sovarka_surveillance` et `20261108180100_sovarka_surveillance_portes` (appliquées), `sovarka_surveillance_commande` / `_lire`, rapports dans `sovarka_pouvoir_passe` ; écran `plateau-sovarka-pouvoir.js`.

## Partis de Sovarka (décisions de Fred, 07/11/2026)

- **« Postuler à un poste »** (hall du Palais du Gouvernement) : sans parti, message « Vous ne pouvez pas obtenir un poste si vous n'adhérez pas à un parti », avec la liste des partis constitués (demande d'adhésion) et l'accès à la création. Le serveur refuse aussi toute candidature ou nomination à un poste nommé sans parti (`parti_requis`).
- **Condition suivante** : la règle de Républia. Si l'autorité qui nomme est un PJ, elle accepte ou refuse ; si c'est un PNJ, la candidature est acceptée d'office, pour peu que le candidat adhère à un parti.
- **Ministres** : choisis dans le parti du Président du Conseil, **sauf si aucun membre du parti n'est libre** (tous occupent déjà un poste du gouvernement) : le Président du Conseil peut alors prendre un ministre hors de son parti.
- **Création libre** à chacun, dans la **salle des partis** d'une des trois mairies (Novomirsk, Starovka, Krasnov) : **2 PA et 15 PSK** de droits d'enregistrement. Le parti est **national**, son **siège** est dans la ville de création.
- **Un seul parti à la fois** ; pour en rejoindre un autre, quitter d'abord le sien.
- **Adhésion sur demande** (2 PA), acceptée ou refusée par le chef ; **un refus coûte 2 POP au parti**, sans plafond (« les joueurs abuseront des mécaniques, c'est assumé »). Le **droit d'entrée** est fixé par le chef, **payé à l'acceptation**, versé à la **caisse du parti** ; si le candidat ne peut plus payer, l'acceptation est refusée et la demande reste en attente.
- **Quitter coûte 1 PA**. Le chef doit d'abord **désigner un successeur** ; s'il est le dernier membre, le parti est **dissous**. **Quitter ne fait perdre aucune POP** (décision de Fred, 07/11), ni au membre ni au parti ; c'est déjà le cas dans le code.
- **Popularité du parti** : jauge propre au parti (les organisations n'en avaient pas), **0 au départ** (décision de Fred, 07/11 : « à lui de faire augmenter sa popularité » ; migration `20261107233500_sovarka_parti_pop_depart_zero`, appliquée), bornée 0-100 ; **jamais négative** (décision de Fred, 07/11) : un refus (−2) ne coûte rien à un parti resté à 0. Elle ne sert encore à rien d'autre que d'afficher les refus.
- Code : migration `20261107184000_sovarka_partis_salle` (`sovarka_partis_liste`, `sovarka_parti_commande`, `sovarka_nomination_refus` ; portes génériques des organisations fermées aux partis de Sovarka), `plateau-sovarka-partis.js`, salle `salle_partis` ajoutée par `roomsExtra` à la fin de `data.js`.

## Règle des noms de PNJ de Sovarka (Fred, 07/11/2026)

Noms russes authentiques (bouriates à Starovka), sans jeu de mots français. Exceptions : sept figures satiriques (Innokenti Partiïev, Zinaïda Propagandova, Rostislav Censurov, Raïssa Communiqueva, Macha Scoopova, Pavel Pistonov, Dimitri Compassov) ; les noms choisis par Fred ; les noms bâtis sur un mot russe (Smetanine, Blinova, Vodkaïev, Sévérov…). Tout nouveau PNJ de Sovarka suit cette règle. Le renommage du 07/11 a appliqué le tableau validé par Fred (75 noms, voir l'historique Git).

## Palais présidentiel de Sovarka (décisions de Fred, 08/11/2026)

- **Députés** : pas de bâtiment dédié, ils se réunissent dans la salle de réunion du Palais du Gouvernement (acté).
- **Bâtiment propre à la présidence**, le **Palais présidentiel** (nom choisi par Fred), à côté du Palais du Gouvernement ; il remplace, sur la vue 10 revisitée par Fred (rue du Tribunal), l'ancien palais incohérent près de la gare. Id du socle `palais-presidentiel` (ex-« Palais du Parti », qui n'avait aucune entrée dans les rues). Le président n'a presque aucun pouvoir : ses appartements sont « presque une prison ouverte ».
- **Quatre pièces** : hall d'entrée, appartements du Président, salle de restaurant, musée présidentiel. Bureau et salle de presse du socle retirés.
- **Hall** : chef du protocole **Konstantin Lvovitch Orlov** (nom proposé par Claude, validé par Fred). **Aucun garde** ne protège le président.
- **Appartements** : logement de fonction **gratuit** ; le président qui y dort gagne **+1 PA** chaque nuit (bonus quotidien, seulement s'il dort dans ses appartements). On n'y entre que **groupé au président**.
- **Salle de restaurant** : on n'y entre que **groupé au président**. Le repas quotidien du président y est servi (et non plus dans les appartements) ; **repas du président gratuit** ; il peut inviter **plusieurs** personnes, **60 PSK par invité**, payés par la caisse présidentielle, tant qu'elle a assez d'argent. Effets du dîner d'affaires pour chacun (décision du 07/11).
- **Musée présidentiel** : entrée **8 PSK**, versés à la caisse présidentielle ; **le président entre gratuitement** (Fred, 08/11). Figures (présidents fictifs) écrites par Claude, à la relecture de Fred.
- **Caisse présidentielle** (`soviet_palais-presidentiel`) : alimentée par la ligne « Présidence » de la répartition budgétaire (3 %, inchangée) ; elle paie le **salaire du président, ramené de 800 à 600 PSK**, et les repas des invités.

### Ce qui est codé (08/11/2026, branche `claude/palais-presidentiel-sovarka-20261108`)

- Zone cliquable sur la vue 10, entrée serveur `rue_sorties_batiments` (novomirsk-vue-10).
- Billet du musée : ordre « Billet du musée présidentiel » au hall (8 PSK, valable jusqu'à minuit, `sovarka_musee_billet`) ; sans billet, la porte du musée refuse. Le billet s'achète une fois par jour, chaque visiteur prend le sien ; le président entre sans billet.
- Accès réservés : garde serveur dans la navigation intérieure (`sovarka_palais_acces_interne`) — restaurant et appartements ouverts au président et aux membres de son groupe (le président est chef du groupe).
- Repas : `sovarka_repas_presidentiel(requete, invites[])`, refus nommé « caisse insuffisante » avec le nombre d'invités possibles.
- Repos : `pa_repos_nocturne` ajoute +1 PA au président élu qui dort dans ses appartements (Dormir ordinaire, passé dans la pièce).
- L'ordre « Solliciter une audience » du hall est hérité du socle (courrier au président).

## Greffe du Tribunal Populaire (décisions de Fred, 08/11/2026)

Intention : un sentiment d'enfermement, peu de moyens d'échapper aux règles communes. La justice est vite expédiée.

- **Retirés** : les deux ordres d'avocat (pas de barreau en Sovarka), « Demander à parler à un juge » (quête de Républia), les deux corruptions du greffier, « Falsifier un document » (reste possible ailleurs avec un ordinateur et une imprimante). « Consulter les archives » (liste des jugements) est retiré aussi, doublon des « Archives du greffe » désormais réservées.
- **Affaires en cours** et **Archives du greffe** : réservées aux commissaires, juges, ministre de la Justice prolétarienne et ministre de la Sécurité du Peuple.
- **Demander mon extrait de casier** : 1 PA, 8 PSK (caisse du Tribunal Populaire).
- **Extrait de casier (enquête)** : mêmes autorités, sur n'importe quel habitant de Sovarka, sans affaire en cours ; 1 PA, aucun frais (l'État ne se paie pas lui-même).
- **Règle commune** : ces ordres ne visent que les habitants de Sovarka ; le casier d'un étranger n'est consultable que s'il a commis une infraction en Sovarka. Le casier lu est celui du pays : seules les condamnations prononcées en Sovarka y figurent.
- **Duplicata d'un extrait de domiciliation** : quitte le greffe pour la salle des partis, à 7 PSK.

### Ce qui est codé (08/11/2026)

- Écran : surcharge `roomOverrides.greffe` des tribunaux des trois villes de Sovarka (`data.js`, bloc « droits d'exploiter ») ; rangement en menus étendu au Tribunal Populaire (`plateau-politique.js`).
- Serveur : migration `20261108224500_sovarka_greffe_tribunal_populaire` (appliquée le 08/11) — `sovarka_greffe_autorite_interne`, garde `greffe_sovarka_restreint_v1` dans `justice_affaires_publiques` et `justice_archives_greffe`, prix `greffe_sovarka_prix_v1` dans `casier_mon_extrait`, aiguillage `greffe_sovarka_enquete_v1` de `casier_extrait_enquete` vers `sovarka_casier_extrait_enquete_interne`. Refus nommés : `reserve_autorites_sovarka`, `etranger_hors_juridiction`.

## Justice de Sovarka : bureau des magistrats et circuit sans procureur (décisions de Fred, 08/11/2026)

**Circuit judiciaire**
- Pas de procureur en Sovarka. La plainte est inscrite au registre du commissariat.
- Le **commissaire** et le **ministre de la Justice prolétarienne** peuvent tous deux **saisir le juge**, ou **enterrer** l'affaire : elle n'est pas classée, elle est « perdue » — elle reste au registre du commissariat, n'apparaît jamais au registre du tribunal, et peut toujours être transmise plus tard. Une affaire enterrée alimente les **rumeurs** (« On dit qu'une plainte contre Untel s'est égarée au commissariat… », sans nommer qui l'a enterrée).

**Bureau des magistrats**
- Gardés : Rendre la sentence, Tenir l'audience, Saisines du ministre. Retiré : Dossiers du parquet.
- **Prendre les ordres du ministre** (nouveau) : le ministre de la Justice a la liste de chaque affaire et peut envoyer au juge, jusqu'à la veille du procès, l'une des consignes : condamner sévèrement, condamner légèrement, relaxer, libre à vous (défaut si rien n'est coché). Le juge consulte ces consignes et reste libre. **Aucun effet automatique** : le juge, nommé par le ministre, peut être démis puis poursuivi ; tout se joue entre joueurs avec les moyens existants (le ministre vérifie par les Archives du greffe).
- **Offrir un café** (nouveau, sur le modèle d'« Offrir une tournée ») : réservé au magistrat, à une personne présente dans le bureau ; +10 moral ; 1 PSK pris sur la caisse du tribunal ; un café par jour et par bénéficiaire, nombre de bénéficiaires illimité.

**Greffe**
- **Délivrer un acte officiel** (état civil / succession) quitte le bureau du juge pour le greffe : chacun pour soi (1 PA, 8 PSK, caisse du Tribunal Populaire) ; juge, commissaire et ministre de la Justice pour n'importe qui (1 PA, sans frais).

**Salle des partis**
- Le duplicata de domiciliation devient l'**Extrait d'enregistrement du parti** : délivré au chef du parti, 1 PA et 7 PSK ; nom, chef, siège et membres du parti.

**Titulaires PNJ (référents justice)**
- Juges et commissaires PNJ inscrits comme titulaires dans les trois villes (aujourd'hui aucun titulaire en Sovarka, d'où le refus de « Saisines du ministre ») : Novomirsk juge **Pravdine**, commissaire **Vassili Ostrovski** ; Starovka juge **Dulma Tsyrenova**, commissaire **Bato Dashiev** ; Krasnov juge **Anatoli Gromov**, commissaire **Egor Tikhonov** (noms validés par Fred ; Egor Tikhonov remplace Oleg Morozov, homonyme du chef de cabinet du Président du Conseil, décision du 08/11).
- Quand un PJ prend le poste, le PNJ reste comme **référent justice**, assistant du juge (ou du commissaire).
- Le « Défenseur Collectif, Avocat du Peuple » est retiré du tribunal de Novomirsk (plus d'avocats).

Salle d'audience : pas de changement demandé. Les audiences existent côté serveur mais n'ont jamais servi (aucune plainte ni aucun jugement en base) ; en Sovarka elles dépendent du nouveau circuit ci-dessus.

### Ce qui est codé (08/11/2026, branche `claude/justice-sovarka-20261108`)

- Serveur : migration `20261108230000_sovarka_justice_circuit`. Titulaires PNJ dans `titulaires_pnj` (six lignes `soviet_juge_*` / `soviet_commissaire_*`). `sovarka_justice_registre` (commissaire : sa ville ; ministre : tout Sovarka ; juge : ses affaires saisies, avec la consigne), `sovarka_justice_decider` (saisir : statut `saisie`, acte `juge_saisi`, courrier au juge PJ ; enterrer : statut `enterree`, jamais clos ni expiré, trace `plainte_egaree` d'auteur « Le commissariat » pour les rumeurs), `sovarka_consigne_envoyer` (table `sovarka_consignes_ministre`, refus le jour de l'audience ou après son ouverture, courrier au juge PJ), `sovarka_offrir_cafe` (tables `sovarka_cafes_magistrat` et `sovarka_cafes_requetes`), `sovarka_parti_extrait` (document `domiciliation_extrait`, motif `enregistrement_parti`). Patchs sous empreinte : `etat_civil_document_recevoir` (acte au greffe de Sovarka, plus au bureau des magistrats), `rumeur_ecoute_jauges_interne` (`plainte_egaree` audible), `justice_affaires_publiques` (en Sovarka, seules les affaires saisies). La plainte garde son statut historique `au_parquet`, qui signifie ici « au registre du commissariat ».
- Écran : `plateau-sovarka-justice.js` ; ordres « Registre des plaintes » (bureau du commissaire, trois villes), « Affaires judiciaires » (bureau du ministre de la Justice prolétarienne), « Prendre les ordres du ministre » et « Offrir un café » (bureau des magistrats), « Demander / Délivrer un acte officiel » (greffe), « Extrait d'enregistrement du parti » (salle des partis) ; « Dossiers du parquet » et l'acte du juge retirés du bureau ; Défenseur Collectif retiré ; juges et commissaires PNJ avec titre de référent quand un PJ tient le poste.
- Choix laissés à la relecture de Fred : saisir, enterrer, consigner et offrir un café ne coûtent pas de PA (aucun coût décidé) ; les 7 PSK de l'extrait du parti vont à la caisse de la mairie ; la rumeur ne s'entend que là où l'on écoute les rumeurs (en Sovarka, le Grand Hôtel de Novomirsk) ; quand commissaire et ministre sont des PNJ, les plaintes attendent au registre.

## Starovka et Krasnov : audit du 09/11/2026 (Claude, feu vert de Fred)

Constat : les deux villes ont 17 bâtiments chacune, dont 14 copiés de Montrouge. Les règles nationales de Sovarka y étaient
déjà en place (droits d'exploiter, demande de commerce, salle des partis, greffe, justice, juges et commissaires), mais
**la plupart des bâtiments étaient inaccessibles** : les rues dessinées par Fred n'avaient de façade cliquable que pour la gare,
l'entrepôt et le port (Starovka), et la gare, l'entrepôt, le stade, le commissariat et la station (Krasnov).

### Ce qui est codé (branche `claude/krasnov-starovka-20261109`, PR #647)

- **Onze façades raccordées**, chacune dans la rue qui porte son nom : Starovka — hôtel (rue de l'hôtel), terrain municipal,
  stade, mairie (rue mairie-marché), commissariat (rue lycée-commissariat), centre d'affaires (immeuble « Офисы в аренду »,
  rue bureaux-caserne) ; Krasnov — terrain municipal, centre artisanal, centre commercial, mairie (place), centre d'affaires
  (rue des bureaux). Migration `20261109004500_starovka_krasnov_entrees_rue`.
- **Bureaux des centres d'affaires de province** : demande à la mairie, comme les locaux des centres (règles du 06 et du
  07/11) ; le guichet privé (1 000 / 500 / 200 par jour) est fermé. Migration `20261109003000_sovarka_bureaux_provinces`.
  **Plafonds proposés par Claude, à valider** : prestige 100, standard 50, open space 20 PSK (même règle provisoire que les
  centres : proportionnels au loyer de Républia, le plus grand à 100, plafond des provinces décidé le 06/11).
- **Textes** : plus de renvoi à Montrouge, Luthécia ou Port-Sainte-Marie (hôtel, EHPAD, geôles, syndicat, usine « propriété
  de l'État » au lieu de « Rachetable », gare « vers une autre ville de Sovarka », terrain municipal) ; bureau des magistrats
  sans Procureur dans les trois villes (pas de parquet). Textes neutres, **à relire par Fred**.
- **Devise** : partout hors Républia, les libellés d'ordres affichent le sigle du pays (PSK) au lieu de « FR » ; les montants
  ne changent pas (mêmes chiffres, décision du 04/11).

### Questions ouvertes pour Fred (à poser une par une)

1. **Banque locale** des deux villes : que devient-elle dans un pays sans propriété privée (comptes, placements, prêts) ?
2. **Siège syndical** : un syndicat ouvrier a-t-il sa place sous le régime des partis, et avec quels ordres ?
3. **Bâtiments sans façade** : banque, dispensaire, tribunal, siège syndical, usine et zone de production n'apparaissent dans
   aucune rue. Dans quelle rue les placer (ou faut-il une nouvelle image) ?
4. **Rue « locaux à louer » de Starovka** : les deux bâtiments « Помещение в аренду » sont-ils le centre commercial, le centre
   artisanal, ou de nouveaux locaux ?
5. **Bâtiments dessinés mais inexistants** : Starovka — marché, lycée, poste militaire, magasin de chasse, restaurant « Entre
   terre et mer », fourreur, pétrole, ferme, logements collectifs ; Krasnov — église, école, distillerie, radar, marché, ferme,
   tabac-bar, musée, maisons. Lesquels doivent devenir des bâtiments, et dans quel ordre ?
6. **Prix courants à l'échelle de Sovarka** (un PA ≈ 15 PSK) : train 75, bus/taxi 150, soin 25, transfert en clinique 1 000,
   licence sportive 150, chambre d'hôtel 60, recrutement de policiers 50 et 100 par jour sont encore au barème de Républia.
7. **Hôtel** : « Hôtel des Mineurs » convient-il aux deux villes, ou un nom propre à chacune (l'enseigne de Starovka dit
   « Гостиница путешественников », hôtel des voyageurs) ?
8. **Antenne « La Tribune de Républia »** au centre d'affaires des deux villes : la garder, la renommer (journal de Sovarka) ou
   la retirer ?
9. **Terrain de Starovka** : l'image annonce 4 parcelles, le serveur n'en connaît qu'une (un seul immeuble collectif à la fois).
10. **Anciens noms jamais affichés** (« Baraquement Sibirsk-9 », « Caisse Minière Collective », « Gazette du Charbon »,
    « Infirmerie du Froid », etc.) : à reprendre ou à supprimer ?
11. **Route de Starovka** : elle n'est reliée par la route à aucune ville (véhicules personnels) ; voulu ?

### Fermes : production (Fred, 10/11/2026, midi)

Une ferme ne consomme que du travail (PA), sans matière première en entrée, comme les jardins ouvriers :
- **Abattre et dépecer un renne** (Starovka) : 5 PA → 3 viandes de renne, 2 peaux, 1 bois de renne ;
- **Extraire des légumes** (Krasnov) : 1 PA → 1 fruit et légume ;
- **Traire les rennes** (Starovka) : 1 PA → 2 laits de renne.
- **Ramasser les œufs** (Krasnov) : 1 PA → 3 œufs.
- **Abattre un poulet** (Krasnov) : 2 PA → 2 poulets ; **abattre un lapin** : 2 PA → 1 lapin et 1 peau (textile). **1 poulet ou 1 lapin = 1 viande** (matière `viande` existante, pas de nouvelle matière).
- La **viande de renne** n'est que de la **viande** : l'appellation est purement RP (le service de Dolgor demande donc 2 viandes).
- Le **lait de renne** est des **laitages** (matière existante), appellation purement RP.
- Les **œufs** sont une **nouvelle matière** (`oeufs`), **hors du commerce international** (pas de trading). **Consommer 3 œufs rapporte 2 PA au prochain Dormir** (le lendemain). Les œufs se transportent sur soi et se mangent quand on veut (par exemple à l'hôpital, en plus du repas de l'hôpital) ; manger ne coûte pas de PA, seul le ramassage coûte 1 PA. Les œufs vont **toujours par 3, indissociables** : on ne mange jamais 1 œuf, mais les 3 d'un coup ; le chiffre 3 est cosmétique (une unité d'œufs = 3 œufs ; ramassage : 1 PA → 1 unité ; le service de Stepan « 6 œufs » = 2 unités). **Prix : 6 FR ou 3 PSK** l'unité de 3 œufs. **Les entrepôts ne vendent pas d'œufs** : ressource locale, équivalent d'un sandwich ou d'un repas ; un commerce classique peut vendre les œufs que son propriétaire a ramassés.
- Le **bois de renne** est du **bois** (matière existante), appellation purement RP : pas de nouvelle matière, pas de distinction sur le couteau vendu (la recette du couteau ne change pas).
- Le **sucre** (distillerie, 5 fruits et légumes = 10 sucres) est une **ressource locale** comme les œufs : ni entrepôt ni trading, gardé sur soi, revendable par un commerce, sans effet pour l'instant ; **prix : 2 FR ou 1 PSK** (jamais de décimales dans les monnaies).
- Les **peaux** sont du **textile** (matière existante). Le libellé de la matière devient « Tissus et peaux » (proposé par Fred, retenu par Claude ; la clé technique `textile` ne change pas).
- **Fourreur** : commerce classique (mécanique générale des commerces). Le commerçant nomme lui-même ses articles pour coller au RP (chapka plutôt que slip de bain en peau de bête, mais libre à chacun). Aucun effet bonus pour l'instant (Fred ne se l'interdit pas plus tard).

**Codé le 10/11 (partie 2 du lot, feu vert de Fred à 13 h 02, branche `claude/sovarka-lot-suivant-partie2-20261110`, PR #686)** :
- **Fermes** : « Ferme de Starovka » (éleveur Bair Sambuev) et « Kolkhoze S. M. Kirov » à Krasnov (présidente Galina Belova),
  façades sur les enseignes ; ouvertes à tous, comme les jardins ouvriers (le produit va dans l'inventaire de qui travaille),
  sans limite par jour autre que les PA. Serveur `sovarka_ferme_travailler`.
- **Œufs** : matière `oeufs` hors `ressources_economie` (donc hors entrepôts et trading) ; bouton « Manger 3 œufs » dans la
  fiche de l'objet, sans PA, +2 PA au prochain Dormir (`sovarka_oeufs_manger`, source `oeufs`). Stepan demande « 6 œufs » =
  2 unités ; Dolgor « 2 viandes ».
- **Distillerie de Krasnov** et **fourreur « La Fourrure chaude »** (Starovka) : locaux de Sovarka (demande à la mairie,
  signature chez le notaire), puis commerce classique. Type de commerce **« Distillerie »**, réservé au local de la distillerie :
  vodka, slivovitz, samogon (10 bouteilles par recette, 1 PA) et sucre (5 fruits et légumes = 10 sucres). Le fourreur prend
  le type « Vêtements » et nomme ses articles (habillage du fonds). Un commerce alimentaire peut revendre œufs et sucre
  (« Ressource locale »). À l'achat, bouteilles, sucre et œufs arrivent sous leur clé (vodka, slivovitz, samogon, sucre,
  oeufs) : on peut trinquer chez l'habitant, lui rendre service ou manger ses œufs avec ce qu'on a acheté.
- **Matière textile** affichée « Tissus et peaux ».
- **Choix de Claude à relire par Fred** : plafond de loyer de la distillerie et du fourreur 30 PSK (comme les locaux de
  Starovka) ; 1 PA par recette de distillerie ; revente des œufs par lots de 5 unités et du sucre par 10 (pour que le
  commerce ait un coût de revient : le prix de vente reste fixé par le commerçant sous le plafond habituel, le « 6 FR / 3 PSK »
  de Fred n'est donc pas imposé) ; noms des deux fermiers.

### Forêt profonde de Krasnov : ce qui est codé (10/11/2026, partie 2, PR #686)

Décisions ci-dessous (point 5, « Exploitation forestière »). Lecture retenue et non contestée par Fred au feu vert : sur les
vues 3 et 4, une seule coupe rapporte du bois, la tentative suivante déclenche la rencontre (vue 3 : attaquant tiré au sort
— précision du 09/11, 23 h 41, qui prime sur « vue 3 = toujours l'ours » ; vue 4 : Olga).
- Les 4 vues sont des pièces masquées de l'exploitation forestière de Krasnov : on y entre, on y change de vue et on en sort
  **uniquement** par « S'enfoncer dans la forêt » et « Revenir à l'entrée de la forêt » (tirages au serveur,
  `sovarka_foret_aller`) ; la navigation libre est refusée (« vous êtes en pleine forêt »). Hospitalisation et décrochage de
  combat ne sont pas bloqués.
- « Couper du bois » (`sovarka_foret_couper`) : 2 à 4 bois (le double d'une récolte), 2 coupes sur les vues 1 et 2, 1 sur les
  vues 3 et 4 ; fausse alerte une fois sur deux à la seconde coupe des vues 1 et 2 (lièvre, tractoriste perdu, élan…).
- Attaquant : PNJ de combat temporaire (comme les squatteurs), combat par le moteur universel (bataille de type « faune »,
  jamais tracée comme agression) ; victoire = butin au leader (en inventaire, ou en réception s'il est plein, plus un mail) ;
  « Fuir » lâche le bois coupé sur la vue et ramène le groupe à l'entrée ; « Ne pas se défendre » met les PA du groupe
  présent à 0 : hospitalisation automatique, comme un combat perdu (`sovarka_foret_rencontre`).
- En groupe : seul le chef coupe et décide du chemin ; un membre qui veut couper doit quitter le groupe.
- **Choix de Claude à relire par Fred** : 2 PA par coupe (comme la récolte), y compris la tentative qui déclenche la
  rencontre ; les coupes de la forêt profonde ne comptent pas dans les 2 récoltes du jour ; force des créatures en combat
  rapproché (loup 9, meute 13, ours 16 ; un PJ moyen est à 8-10) ; « Fuir » ramène à l'entrée ; les dents d'ours sont un
  objet empilable « Dent d'ours » (son passage dans l'armoire à souvenirs n'a pas été vérifié).
- Images des 4 vues : à faire par Fred (`imagesAVenir`).
- **Précision de Fred (10/11/2026, 14 h 40)** : lecture confirmée (vues 3 et 4 : une coupe, puis la tentative suivante
  déclenche la rencontre). **La première coupe est acquise** : la fuite ne fait perdre que le bénéfice de la **seconde**.
  « Fuir » ne retire plus aucun bois (corrigé, voir ci-dessous).
- **Victoire totale (Fred, 10/11/2026, 14 h 42)** : sur la vue 3, un groupe qui gagne le combat reçoit **le bois de la
  seconde coupe (2 à 4 bois) en plus du butin** de la créature.
- **Olga (Fred, 10/11/2026, 14 h 42)** : sur la vue 4, la seconde coupe rapporte **aussi son bois (2 à 4) en plus du
  repas** d'Olga.
- **Codé et appliqué le 10/11 (feu vert de Fred à 14 h 43)** : migration `20261110144500_sovarka_foret_seconde_coupe`
  (patchs ancrés de `sovarka_foret_rencontre`, `sovarka_foret_issue_combat_interne`, `sovarka_foret_couper` ; Olga exige
  désormais 4 places d'inventaire), banc annulé `outils/bancs/banc-sovarka-foret.sql` vert sur la production avant
  application ; écran : libellé de « Fuir » et bois d'Olga affichés.

### Règle des prix en Sovarka (Fred, 10/11/2026)

En Sovarka on gagne peu mais on paie peu, sauf à Novomirsk, la ville des tsars : loyers et prix plus bas dans les
provinces (Starovka, Krasnov) qu'à Novomirsk. Novomirsk garde pourtant sa classe ouvrière (quartier du marché) :
logements sociaux au même prix dans les trois villes (10 / 20 PSK).

### Réponses de Fred (09/11/2026, soir) — feu vert de Fred le 10/11 à 1 h 05

**Codé le 10/11 (branche `claude/sovarka-lot-nuit-20261110`, PR #670)** : prix courants à l'échelle de Sovarka
(réponse 6 ; table serveur `ordres_couts_pays`, seul tarif valable pour un joueur du pays, policiers 20/40 PSK),
hôtels (7), « La Voix de Sovarka » et ses deux antennes (8), siège syndical retiré (2), deux locaux à louer à
Starovka (4, plafond **30 PSK** décidé par Fred le 10/11 au lieu des 50 proposés), 4 parcelles sur le terrain de Starovka (9, parcelle n = « terrain@pn »),
anciens noms supprimés (10 ; « Baraquement Sibirsk-9 » = logements collectifs de Starovka), et bâtiments du socle
de la réponse 5 : marchés des deux villes, magasin de chasse (armurerie), restaurant « Entre terre et mer », lycée
et école (université), logements collectifs (4 petits à 10 PSK, 4 grands à 20 PSK, comme Novomirsk — **validé par Fred le 10/11** : Novomirsk a aussi sa classe ouvrière, voir le contraste entre le quartier chic et celui du marché),
église du Tractorisme, musée et bar-tabac de Krasnov, façades « Compagnie Nationale du Pétrole » et « Exploitation
forestière » sur la zone de production du socle. Noms des PNJ proposés par Claude, **validés par Fred le 10/11** :
Tuyana Dashieva (marché), Bato Tsyrenov (chasse), Sesegma Badmaeva (restaurant), Darima Zhambalova (lycée) à
Starovka ; Nina Gorbounova (marché), Pavel Smirnov (école), Vera Lebedeva (musée), Grigori Zaitsev (Bar Sever) à
Krasnov. Manifestations : vérifié, en Sovarka seules existent les manifestations de soutien des partis
(`sovarka_manifs`), la manifestation spontanée n'a pas de place dans le pays : les manifestations hostiles y sont
donc impossibles, conforme.

**Codé le 10/11 (lot suivant, branche `claude/sovarka-lot-suivant-20261110`, PR #681)** : extraction du pétrole (Starovka)
et du bois (Krasnov) ; bons d'État (1) ; centres d'écoute ; maisons. Choix de Claude à relire par Fred : vol d'archives à 2 PA,
jet de base 45 % (celui de la falsification) ; repas chez l'habitant = +2 PA au prochain sommeil ; habitants proposés :
**Dolgor Tsybikova** (Starovka), **Stepan Kouznetsov** (Krasnov) ; la réaction de l'habitant à la bouteille est une phrase
fixe selon l'alcool (pas encore l'IA). Les banques de Sovarka n'ont pas de façade dans les rues : les bons d'État seront
accessibles après le tour des images. Restent la forêt profonde et les fermes, distillerie et fourreur.

**Relecture de Fred (13/11/2026)** :
- Vol d'archives : **2 PA validés** ; jet **45 + (DIS − 50) ÷ 3 + (VOL − 8) + (DUP − 8)**, borné 5-85 % (plafond des
  caractéristiques à 16 : espion optimisé DIS 100 / VOL 16 / DUP 16 ≈ 78 %, moyen 45 %, maladroit ≈ 33 %). Puis les
  malus existants (ISN de la ville, hommes armés présents), dont le **total est plafonné à −33** (option A de Fred :
  l'espion optimisé ne descend pas sous 45 %, l'amateur reste dissuadé). Plafond appliqué **au vol
  d'archives seulement** ; son extension à tous les actes illégaux est une **question ouverte**, Fred y réfléchit.
- Repas chez l'habitant : **+1 PA** au prochain sommeil (et non +2), car la maison est un logement gratuit.
- Noms des habitants **validés** : Dolgor Tsybikova (Starovka), Stepan Kouznetsov (Krasnov).
- Réaction de l'habitant à la bouteille : **écrite par l'IA (DeepSeek)**, comme les dialogues des PNJ, à la place de la
  phrase fixe (coût jugé faible, effet bien meilleur).
- **Codé le 13/11 au soir** (migration `20261113193000_relecture_fred_20261113`, appliquée ; banc vert) : formule du vol d'archives
  et plafond des malus (vérifié au Poste de Vigilance Glaciale : espion optimisé 73 %, moyen 40 %, avec 5 de malus) ; repas
  +1 PA ; réaction de l'habitant écrite par DeepSeek via `/api/chat?mode=trinquer` (un seul appel par bouteille, garanti par le
  serveur ; si l'IA ne répond pas, la phrase fixe reste affichée).

**Reste à coder** (lot suivant) : bons d'État (1), fermes, distillerie et fourreur (commerces), centres d'écoute
(poste militaire « Poste de Vigilance Glaciale », station radar), maisons (hospitalité, beuverie, ragots), forêt
de Krasnov (vues profondes, coupes, rencontres) et extraction du pétrole. Point technique relevé : la récolte de la
zone de production est encore décidée par le navigateur (« Récolter », sans fonction serveur) ; l'extraction du
pétrole et du bois devra d'abord passer au serveur (règle « une seule réalité »).


1. **Banque de Sovarka** (les trois villes) : **ni placements privés ni prêts** (un projet est financé par la collectivité).
   À la place, des **bons d'État « pour soutenir l'économie de Sovarka »** :
   - motivation **purement RP** (geste patriotique), aucun avantage en jeu ;
   - rendement **fixé à la souscription** d'après l'**indice Économie moyen des trois villes** : de **+3 %** (économie au
     plus haut) à **−10 %** (au plus bas), proportionnel entre les deux ;
   - durée **7 jours** ; mise ± rendement rendue à l'échéance ;
   - l'argent va au **Trésor de Sovarka**, qui rembourse ; **Trésor vide à l'échéance : planche à billets**, uniquement pour
     les bons — le PJ est remboursé quand même, mais **à −10 %** quel que soit le rendement prévu ;
   - pas de plancher ni de plafond de souscription hors l'argent du PJ (proposé par Claude, non contesté).
2. **Pas de syndicat en Sovarka** : les partis les remplacent ; siège syndical retiré de Starovka et Krasnov.
   **Manifestations hostiles interdites** : une manifestation de PJ y est illégale et hors de toute organisation
   (socle de la manifestation spontanée, toujours illégale en Sovarka — à vérifier au codage).
3. **Bâtiments sans façade** (banque, dispensaire, tribunal, usine, zone de production) : Fred fera les images pendant le
   **tour des deux villes**. **À lui rappeler à ce moment-là.**
4. **Rue « locaux à louer » de Starovka** : deux **nouveaux locaux simples**, demandés à la mairie comme les autres locaux
   de Sovarka.
5. **Bâtiments dessinés** : tous auront une vraie utilité.
   - **Codables dès maintenant depuis le socle** : marchés, église (Krasnov), magasin de chasse (= armurerie), lycée et
     école (modèle de l'université de Luthécia), logements collectifs (= logements sociaux), restaurant « Entre terre et
     mer », tabac-bar, distillerie, fourreur (commerces), musée (Krasnov).
   - **Lieux d'extraction** : **pétrole** (Starovka) et **exploitation forestière** (Krasnov) — RP du pays, et les PJ
     peuvent y extraire des matières premières pour augmenter la production (partir de la zone de production du socle).
   - **Ferme (décision de Fred, 10/11/2026)** : se raccorde à la **mécanique des commerces** (produits alimentaires et
     non alimentaires ; 2 familles et 4 articles en freemium, 3 familles et 10 articles en premium). **Ferme de
     Starovka** : viande de renne, fourrure (= tissu), lait de renne, **bois de renne** (non alimentaire) ; le bois de
     renne peut servir à **fabriquer des couteaux dans les armureries, à la place du bois d'arbre** : **un seul couteau**, le bois de
     renne remplace le bois d'arbre dans la recette au choix de l'armurier (même objet, même effet). Renommer ses objets :
     idée premium cosmétique notée dans `IDEES_PREMIUM.md`, non codée.
     **Ferme de Krasnov** (même principe) : œufs, poulets, lapins, légumes (matière `fruits_legumes` existante).
     **Alcool local à la ferme** (ex. vin) : piste de Fred, **à voir**, non décidée.
   - **Distillerie** : produit de l'**alcool** (matière existante) à partir de la matière première **fruits et légumes**.
     C'est un **commerce** : un PJ peut l'exploiter si le maire accepte sa demande (droit d'exploiter de Sovarka).
     **Trois recettes** (validées par Fred, 10/11), pour 10 bouteilles : **vodka** = 6 céréales ; **slivovitz** = 8 fruits
     et légumes ; **samogon** (gnôle de contrebande, la moins chère) = 4 fruits et légumes + 2 céréales. **Sucre** :
     **4e article de la distillerie** (Fred, 10/11), tiré des fruits et légumes (betterave), sur le modèle historique des
     sucreries-distilleries ; recette : **5 fruits et légumes = 10 sucres** ; nouvelle matière ; **son utilité sera décidée plus tard** (pas d'adjuvant pour l'instant).
   - **Poste militaire (Starovka) et station radar (Krasnov)** (Fred, 10/11) : des **centres d'écoute** ; **spécialité
     de Sovarka : l'espionnage**. Ils permettent d'**intercepter des communications**, et serviront aussi à **espionner
     l'empire extraterrestre** (monde P2W) quand il existera (point à concilier avec la règle « entre les deux mondes,
     seul le tourisme »). **Fonctionnement** : chaque centre intercepte **10 % des mails** de la journée ; en fin de
     journée, les écoutes sont **compilées en un rapport consigné** ; le **ministre de la Défense** (pas de poste de chef
     du renseignement, décision de Fred du 10/11) demande à chaque cellule de renseignement le rapport du jour qu'il veut, **à distance** : il le demande et le **reçoit par mail**. Couverture :
     **Novomirsk** = la ville + Républia + l'empire parodie des USA (P2W) ; **Starovka** = la ville + El Estado + l'empire
     parodie d'un pays d'Afrique (P2W) ; **Krasnov** = la ville + Al-Khalija + l'empire extraterrestre (P2W). Seul
     l'empire parodie de la Corée et du Japon **ne peut pas être espionné**. « Mails de la ville » / « d'un pays » = mails
     envoyés ou reçus par un PJ **domicilié** dans cette ville / ce pays. Seuls les mails écrits entre PJ sont
     interceptés (pas les notifications du jeu) ; les joueurs sont prévenus que leurs mails peuvent être lus en jeu.
     Poste militaire et station radar : **bâtiments où l'on entre**, **une seule pièce** avec **l'opérateur** (PNJ) et
     **les archives** (les rapports consignés). Opérateurs validés par Fred (10/11) : **Sergent Bair Dorjiev**
     (Starovka, bouriate taciturne) et **Lieutenante Nadejda Sokolova** (Krasnov, méticuleuse, tout en triple exemplaire).
     **Vol d'archives** (tout PJ qui n'est pas ministre de la Défense) : voler **un rapport au hasard parmi ceux des 30
     derniers jours** ; acte illégal, jet selon la règle existante des actes illégaux. **Échec** : bagarre avec l'opérateur,
     puis **prison**. **Réussite** : le PJ obtient le rapport mais **laisse une trace**.
   - **Maisons** (Fred, 10/11) : occupées par des **habitants PNJ très accueillants et sympathiques**, qui offrent
     **spontanément l'hospitalité contre un service** — hommage à l'**hospitalité russe**. Ex. : « Tu peux rester manger
     et dormir ici, étranger. Je te demande juste de me ramener 3 bois. » Service rendu (les 3 bois donnés) : le PJ peut
     **manger et dormir** chez l'habitant, avec les **bonus de PA** de chaque ordre. Le service demandé est
     **tiré au hasard chaque jour** dans une liste de besoins locaux : **Starovka** = 3 bois, 2 poissons, 1 bidon de
     carburant, 2 viandes de renne, 1 bouteille de vodka ; **Krasnov** = 3 bois, 5 fruits et légumes, 6 œufs, 1 bouteille
     de vodka (« pour trinquer ensemble », dans les deux villes). **Une hospitalité par jour et par PJ.** Bonus proposés
     par Claude (non contestés) : manger = repas ordinaire ; dormir = une nuit à l'hôtel de la ville, gratuite.
     **Trinquer avec l'habitant** (Fred, 10/11) : on peut se saouler avec le PNJ ; **une bouteille consommée à chaque
     fois** ; à chaque bouteille bue se déclenche la mécanique **« secret contre secret »** des escorts de Luthécia : le PJ
     livre un secret, le PNJ livre **un secret de la ville**. Le PJ livre son secret **malgré lui** (l'alcool aidant) : le
     serveur tire au hasard un renseignement réel sur le PJ, que l'habitant retient ; plus on boit, plus on en dit.
     **Nid à ragots** (validé) : l'habitant **répète au buveur suivant** ce qu'il a appris ; les secrets des PJ deviennent
     des « secrets de la ville ». Il puise aussi dans le **circuit des rumeurs alimenté par les traces des actes
     illégaux** (ex. « Il paraîtrait qu'Arnie a volé un rapport d'espionnage à la station radar… »). **La bouteille est fournie par
     le PJ** (de son inventaire), **n'importe quel alcool** ; l'IA fait réagir l'habitant à ce qu'on lui apporte (ex.
     « Oh, je n'ai jamais bu de vin de Républia ! »). **Chaque bouteille bue coûte 3 PA** : la limite vient de là (pas de plafond de bouteilles ; tomber à 0 PA suit la règle d'hospitalisation, avec
     l'avertissement existant).
   - **Exploitation forestière de Krasnov** (idée de Fred du 21/10/2026, issue #72 retrouvée par Fred le 09/11 ;
     les décisions ci-dessous priment sur l'issue) — **précision du 09/11, 23 h 41** : la rencontre de la **vue 3**
     tire au sort l'un des **trois attaquants**, du plus facile au plus dur à battre : **loup solitaire**, **meute de
     loups** (un seul PNJ collectif en combat), **ours** — **un tiers de chances chacun** ; mécanique de combat existante. Trois options face à l'attaquant :
     **combattre**, **fuir** ou **ne pas se défendre** (« se laisser bouffer », parodique ; mêmes suites qu'un combat
     perdu). **On ne meurt jamais dans le jeu : on se réveille à l'hôpital.** **Exploration en groupe** possible
     (socle des groupes) : le combat se fait alors **groupe contre créature**. En groupe, la limite de coupes par vue compte **par groupe**
     (le groupe = un seul bûcheron) ; un PJ groupé qui veut couper pour lui doit **quitter le groupe**, et prend alors
     seul le risque d'être attaqué. Devant un groupe, **Olga nourrit tout le monde** (effet d'un repas ordinaire pour
     chaque membre). **Attaquant battu** : on récupère **sa viande et sa peau**. La peau
     **équivaut à du tissu** (matière textile existante) : **une peau d'ours = 10 tissus**. En groupe, **le leader reçoit
     le butin**, les PJ se partagent entre eux, hors code. Butin : **loup solitaire** = 3 tissus + 3 viande ;
     **meute** = 9 tissus (3 peaux) + 6 viande ; **ours** = 10 tissus + 9 viande **+ 2 dents d'ours** (objet de collection
     pour l'armoire à souvenirs, revendable librement entre PJ : de quoi susciter des vocations de chasseurs d'ours).
     **Fuir** fait lâcher le bois coupé sur la vue. **Fausses alertes** (validées, 10/11) : le bruit dans les fourrés
     peut aussi venir d'un lièvre, d'un tractoriste perdu… : à la **seconde coupe des vues 1 et 2**, le bruit survient **une fois sur deux** et finit en
     fausse alerte (au bruit, le joueur ne sait jamais s'il est sur une vue dangereuse). Capture et dressage de l'ours (#72) :
     piste pour plus tard, non codée.
     Base décidée : l'**entrée** est un lieu
     sûr (extraction normale). On peut **s'enfoncer dans la forêt** : arrivée sur l'une des **4 vues de forêt profonde**
     (1 chance sur 4, proposé par Claude). Sur les 4 vues, « **Couper du bois** » rapporte **×2** ; **2 fois au plus** sur
     les vues 1 et 2, **1 fois** sur les vues 3 et 4. Une **seconde coupe** déclenche la rencontre : **vue 3 = toujours
     l'ours**, **vue 4 = toujours Olga**. Mise en scène commune : un bruit dans les fourrés, le joueur croit jusqu'au
     dernier moment que c'est l'ours. **L'ours** : mécanique de combat existante, **combattre ou fuir**. **Olga** apporte
     à manger : effet d'un **repas ordinaire** (PA au prochain Dormir). **Ressortir** : « Revenir à l'entrée de la forêt »
     n'y mène qu'à **20 %** ; sinon on retombe sur l'une des 4 vues (20 % chacune) — on s'est perdu.
6. **Prix courants de Sovarka** ramenés à l'échelle du pays (÷ 2,5 environ) : train 30, bus/taxi 60, soin 10, transfert en
   clinique 400, licence sportive 60, chambre d'hôtel 25, policiers 20 et 40 PSK par jour ; Fred ajustera en jeu.
7. **Hôtels** : « **Hôtel des Voyageurs** » à Starovka (comme l'enseigne), « **Hôtel du Kolkhoze** » à Krasnov.
8. **Presse** : le journal de Sovarka s'appelle **« La Voix de Sovarka »** (façade de l'agence officielle de Novomirsk) —
   l'agence de Novomirsk (affichée « Bulletin du Parti Local ») est alignée, et les mentions « La Tribune » de Sovarka
   (censure, 08/11) désignent ce journal. Antennes à Starovka et Krasnov, journalistes validés : **Saran Batbayar**
   (Starovka), **Anatoli Kolosov** (Krasnov).
9. **Terrain de Starovka** : **4 parcelles** ; la mairie y construit ce qu'elle veut, logements ou commerces.
10. **Anciens noms** : « **Baraquement Sibirsk-9** » devient le nom des logements collectifs de Starovka ; « **Poste de
    Vigilance Glaciale** » celui du poste militaire de Starovka ; le **Goulag de Sovarka** sera ajouté (fiche gardée) ;
    tous les autres anciens noms sont supprimés.
11. **Route de Starovka** : **aucune, voulu** (train et bateau seulement). Piste écartée pour l'instant : la motoneige
    (il faudrait de la neige dans les autres villes).

### Cartes des restaurants de Sovarka (Fred, 10/11/2026, 22 h 27 – 22 h 45)

1. **En Sovarka, plus aucun plat français ni vin** : les plats génériques de la Républia (bœuf bourguignon, saucisse-purée,
   plat de poisson, petit-déjeuner, vin, carbonade-frites, sandwich des cheminots) sont réservés à la Républia ; bière, café,
   boissons sans alcool et cacahuètes restent communs.
2. **La Mère Volga** (Novomirsk) : Menu du Prolétaire (chtchi, kacha de sarrasin, kissel de canneberge), Menu du Stakhanoviste
   (vinegret, côtelettes Pojarski, syrniki), Menu du Jour de Repos (hareng sous fourrure, golubtsy, blinis à la confiture).
3. **« Entre terre et mer »** (Starovka) : Menu du Pêcheur des Glaces (stroganina, oukha, airelles au miel), Menu de l'Éleveur
   (bouillon de renne, bouzy, boortsog), Menu Terre et Mer (chou de mer, omoul fumé et côtes de renne, crème de lait de renne).
4. **Bar Sever** (Krasnov) : tartine de salo et cornichons, solianka, petit-déjeuner du kolkhozien, verre de vodka, thé au samovar.
5. **Grand Hôtel de Novomirsk** : ses trois menus, plus zakouski, champagne soviétique et vodka impériale glacée (8 PSK fixes).

**Codé le 10/11 (feu vert de Fred à 22 h 45)** : migration `20261110230000_sovarka_cartes_restaurants` appliquée (registres
`sovarka_cartes_restaurants_20261110230000` et `sovarka_diner_champagne_20261110230500`). Prix PNJ : formule commune
(2 × coût de revient) à l'échelle de Sovarka — menus 6 PSK, plats du Bar Sever 5, boissons 2 à 3. Socle : une dotation de
commerce peut viser un pays et une ville (clé `bâtiment|pièce@pays.ville`, prioritaire sur `@ville`). **Choix technique** : le
dîner d'affaires du Grand Hôtel sert désormais une bouteille de **champagne soviétique** au lieu du vin (banc
`banc-diner-grand-hotel-sovarka.sql` vert). 

### Marché de Krasnov (Fred, 10/11/2026, 23 h 19)

Le marché vend **une portion de goulash, un guide des baies sauvages de Krasnov et des chemises de bûcheron à carreaux**.
**Codé le 10/11** : migration `20261110233000_marche_krasnov` appliquée (dotation `marche@soviet.ville_b`, il n'hérite plus
des objets de Montrouge). Choix techniques : goulash = aliment ; chemise = objet d'intégration locale (+1 ENT à Krasnov,
cible `soviet.ville_b`) ; guide = objet simple ; prix PNJ 4, 3 et 6 PSK (formule commune). Images à faire par Fred.

### Guide du Musée de la République (Fred, 11/11/2026, 9 h 35 – 9 h 44) — décisions en cours, PAS de feu vert de codage

- **Principe** : une guide (PNJ) présente dans **toutes les salles du Musée de la République** de Novomirsk (pièces créées par
  Fred). Ordre de pièce **« Écouter la guide »** : ouvre la fenêtre de la guide, qui récite d'abord une **présentation fixe**
  de la salle, puis propose de la **questionner librement**. Le musée de la ville aura plus tard **un autre guide**.
- **Présentation fixe** : générée une fois par langue puis stockée (système de traduction existant), resservie gratuitement.
  Les audioguides français restent un bonus ; pas d'audio multilingue (décision de Fred).
- **Dialogue libre** (DeepSeek, langue du joueur) : **1 PA** ouvre le dialogue dans la salle, **3 questions au maximum**,
  ensuite la guide invite poliment à avancer dans la visite.
- **Personnage** : employée de l'État, elle risque sa place, voire la prison, si elle va contre le régime. **Réellement
  cultivée et intelligente**, elle **élude subtilement** les questions gênantes ; poussée dans ses retranchements, elle
  peut répondre sèchement : « Vous voulez peut-être en discuter avec la Police Politique ?! »
- **Conséquences** : **aucune pour l'instant**, la menace reste une réplique. Piste d'ambiance pour plus tard : après un
  avertissement ignoré, un PNJ policier apparaît pour ce seul joueur (détection par marque d'alerte de l'IA, pas sur une
  seule alerte).
- **Fait le 11/11 (13 h 49, demande de Fred)** : portrait de la guide recadré dans l'image de l'accueil
  (`images/Sovarka/Novomirsk/Novo_guide_musee_national_portrait.webp`) ; guide présente dans les **neuf salles**
  (`GUIDE_MUSEE_NOVOMIRSK` dans `data.js`). Sa carte n'ouvre **pas** le dialogue libre gratuit : message d'attente
  jusqu’à l’ordre « Écouter la guide ». **Nom : Ouliana Historiskaïa** (Fred, 13 h 56).
- **Fiches de présentation (présentation fixe d'Ouliana)** : rédigées par Claude, relues et modifiées par Fred
  dans la conversation, une salle à la fois. Validées :

**Les neuf fiches sont rédigées et validées (11/11, 20 h 58)**. **Codé le 11/11 au soir (feu vert de Fred, 21 h 32)** : ordre « Écouter la guide » (0 PA) dans les neuf salles et carte d'Ouliana → présentation fixe de la salle, dans la langue du joueur ; fiches traduites une fois et stockées dans `i18n/guide-musee-novomirsk-resources.js` (chargé à la première ouverture). **Dialogue libre codé le 11/11 (22 h, demande de Fred)** : sous la fiche, « Poser des questions (1 PA) » ouvre trois questions dans la salle, **une fois par salle et par jour** (heure de Paris ; confirmé par Fred le 11/11, 22 h 33) ; Ouliana répond par l'IA dans la langue du joueur, sur son histoire officielle ; le serveur compte les questions (migration `20261111211500_guide_musee_dialogue`, appliquée) et ne consomme une question qu'après une réponse obtenue ; après la troisième, elle invite à poursuivre la visite. Reste à coder : l'exposition premium. Orthographe corrigée au codage ; la phrase d'Arvydas Tkatchenko a été légèrement remise d'aplomb (« Repéré à 12 ans… il eut des débuts… ») et « 3 buts/match » devient « 3 buts par match ». Musée présidentiel : Belov, Sokolov et la ressemblance avec Gromov répercutés.

#### Accueil — validée par Fred sans changement (11/11, 20 h 58)

> Bonjour et bienvenue au Musée de la République de Sovarka, camarades. Je suis Ouliana Historiskaïa, guide officielle du musée, au service de l'histoire. De l'histoire officielle, s'entend : c'est la seule qui ait été conservée.
>
> Le parcours vous mènera des grands présidents aux grands partis, de nos héros militaires à nos artistes, sans oublier le tractorisme, nos sportifs et nos grandes crises. Je vous conseille de suivre l'ordre de la visite. Rien n'est interdit, bien sûr. C'est simplement conseillé, très fortement.
>
> La photographie est autorisée partout, sauf là où elle ne l'est pas. Les gardiens vous le signaleront.
>
> Avez-vous des questions ? Uniquement historiques, je vous prie.

#### Salle des présidents — validée par Fred (11/11, 14 h 24)

Corrections de Fred : les cinq présidents sont des **hommes** ; les trois derniers se **ressemblent** (notion
d'appartenance familiale, ressemblance qui leur vaut une part de popularité, parenté niée officiellement).
**À répercuter au codage** dans le Musée présidentiel du Palais (`plateau-musee-personnalites.js`) : Tamara
Sergueïevna Belova → **Taras Sergueïevitch Belov**, Galina Andreïevna Sokolova → **Guennadi Andreïevitch Sokolov**,
et la ressemblance Gromov / Lebedev / Sokolov.

> Bienvenue dans la Salle des présidents, camarades visiteurs. Approchez, approchez.
>
> Voici les cinq grands guides qui ont conduit Sovarka sur le chemin du progrès.
>
> À gauche, le camarade Arkadi Ivanovitch Zolotov, premier Président de notre République. C'est lui qui inaugura le Palais présidentiel. Pendant trente ans, il honora de sa présence chaque ouverture d'usine, de pont et d'école du pays. Aucun président n'a coupé autant de rubans au service du peuple.
>
> Vient ensuite Taras Sergueïevitch Belov. On lui doit le célèbre décret sur l'heure du thé, toujours en vigueur aujourd'hui. Un texte d'une rare stabilité : jamais contesté, jamais abrogé.
>
> Le camarade Boris Nikolaïevitch Gromov fut réélu sept fois. Le peuple l'aimait tant qu'il n'eut même pas besoin de se porter candidat.
>
> Lui succéda Vladimir Petrovitch Lebedev. Vous remarquez sans doute la ressemblance avec son prédécesseur… Elle est en effet troublante. Le peuple, qui avait tant aimé le camarade Gromov, reporta naturellement sur lui une grande partie de son affection. Lebedev fut aussi un grand défenseur du dialogue entre les institutions : sa correspondance avec le Conseil du Peuple est conservée aux archives… en trois exemplaires.
>
> Enfin, Guennadi Andreïevitch Sokolov. Oui, la même mâchoire, le même regard. Les électeurs y virent le signe d'une admirable continuité. Il offrit au Palais son samovar d'argent, qui réchauffe encore aujourd'hui les plus hautes délibérations de l'État.
>
> Il n'existe, bien entendu, aucun lien de parenté entre ces trois grands hommes. Les noms de famille le prouvent. Les registres de l'état civil de l'époque ont malheureusement été détruits lors de l'incendie des archives, mais l'historiographie officielle est formelle.
>
> Et ces deux cadres vides, me direz-vous ? Ils attendent les futurs dirigeants que le peuple aura la sagesse de choisir. Qui sait… peut-être l'un d'entre vous ?
>
> Avez-vous des questions ? Je vous rappelle que je ne réponds qu'aux questions historiques.

#### Salle des partis politiques victorieux — rédigée par Fred (11/11, 19 h 00)

Texte de Fred, recopié tel quel (une première version, corrigée dans une session précédente, n'avait pas été consignée et a été perdue). Partis : **PPP** = Zolotov et Belov ; **Prolétariat Heureux** = Gromov (dissous) ; **Progrès Nostalgique** = Lebedev et Sokolov. Au codage, corriger seulement l'orthographe (« d'autres », « qu'il a fallu rééduquer », double espace).

> Voici la Salle des partis politiques victorieux. Admirez ces bannières : chacune porte le visage d'un président élu, et derrière chaque visage, le grand parti qui l'a porté au pouvoir.
> Car oui, un Président n'est que l'humble représentant du parti qui l'a porté au pouvoir, et le parti n'est lui-même que la modeste structure qui représente le peuple souverain.
> Commençons par le Parti des Précurseurs Politiques. Ce sont eux qui ont conduit notre nation hors des ténèbres tsaristes, vers la vie hautement démocratique que nous connaissons aujourd'hui. Hautement démocratique, oui. Je pèse mes mots. Le Parti a donné à Sovarka ses deux premiers présidents, le camarade Zolotov et le camarade Belov. Dans la vitrine, vous verrez la première carte du Parti, la plume qui signa la Constitution, et une photographie du premier scrutin libre. On y distingue très bien l'urne, et le représentant du Parti qui en assurait la protection.
> Au centre, le Parti du Prolétariat Heureux, celui du camarade Gromov. Son programme tenait en une phrase : le prolétariat est heureux. Les études de l'époque l'ont confirmé à cent pour cent. Le Parti s'est ensuite dissous de lui-même, sa mission étant accomplie.
> Enfin, le Parti du Progrès Nostalgique, qui a donné au pays les camarades Lebedev et Sokolov. Sa devise : « Avancer vers le passé sans jamais reculer ».  Certains pays appellent ceci le "moonwalk", d'autre le tango Estadien. Ses adversaires, des traîtres à la nation qui a fallut ré-éduquer, disaient qu'il n'avait rien de nouveau à proposer. C'était justement tout son programme.
> Vous remarquerez peut-être que les camarades Lebedev et Sokolov ressemblent beaucoup au camarade Gromov, alors qu'ils appartenaient à un autre parti. C'est la preuve que chez nous, le pluralisme n'empêche pas la continuité.
> Ces trois grands partis ont un point commun : ils ont remporté toutes les élections auxquelles ils se sont présentés. Les autres partis ? Ils n'étaient pas prêts. Ils le sont peut-être aujourd'hui… Les registres d'inscription se trouvent à la mairie.
> Avez-vous des questions ? Uniquement historiques, je vous prie.

#### Salle des honneurs militaires — validée par Fred (11/11, 19 h 08)

Apports de Fred : les 47 médailles (près de 15 kg) arrêtent la balle de l'attentat de Krasnov ; Sovarka n'a jamais été conquise, l'une de ses plus grandes fiertés.

> Approchez, camarades. Vous entrez dans la Salle des honneurs militaires. Ici, chaque médaille raconte une victoire, et chaque victoire a été dûment homologuée par le ministère de la Défense de la Patrie.
>
> Dans la grande vitrine, l'uniforme d'apparat du premier commandant de l'Armée populaire. Il compte quarante-sept médailles : près de quinze kilos de métal. Les historiens s'accordent à dire qu'il les a toutes méritées, y compris celles qu'il s'est remises lui-même. Lors de l'attentat de Krasnov, elles lui ont sauvé la vie : la balle, tirée en plein cœur, s'est écrasée contre elles, ne lui causant qu'un léger hématome.
>
> Sur ce mur, la carte de la Grande Défense du Nord. Nos soldats y ont tenu leurs positions pendant onze hivers, face à un ennemi qui, faute de documents, reste à ce jour inconnu. Il n'est jamais venu : la preuve que la défense fut parfaite. Notez d'ailleurs que Sovarka n'a jamais été conquise. C'est l'une de ses plus grandes fiertés.
>
> Ce casque cabossé appartenait au soldat Piotr Neviyev, héros de la nation. Il fut le premier à franchir le fleuve gelé lors de la marche de 1924. Le second fut son commandant, qui tenait à vérifier que la glace était solide.
>
> Remarquez enfin le registre d'honneur des conscrits. Chaque citoyen appelé sous les drapeaux y inscrit son nom avec fierté. Ceux qui ne s'y sont pas inscrits figurent dans un autre registre, conservé ailleurs.
>
> Avez-vous des questions ? Uniquement historiques, je vous prie.

#### Salle du tractorisme — validée par Fred (11/11, 19 h 12)

Apport de Fred : les graines de la liberté et de l'émancipation qui germent dans les consciences labourées (lecture double, propagande ou message glissé par Ouliana).

> Bienvenue dans la Salle du tractorisme, camarades. Vous êtes ici au cœur de l'âme de Sovarka.
>
> Le tractorisme n'est pas une superstition : c'est une religion scientifique. Elle enseigne que le Tracteur Collectif laboure les champs comme il laboure les consciences, en ligne droite et sans jamais reculer. Et dans une conscience bien labourée, les graines de la liberté et de l'émancipation finissent toujours par germer.
>
> Dans cette vitrine, la Sainte Bougie, une bougie d'allumage retrouvée intacte dans le premier tracteur du kolkhoze de Krasnov. On lui attribue de nombreux miracles. Le plus connu est celui de l'hiver 1931 : le tracteur a démarré du premier coup.
>
> Sur ce mur, les Dix Commandements de l'Entretien. Le premier : « Tu vidangeras tous les cinq mille kilomètres. » Le dixième : « Tu ne convoiteras pas le tracteur de ton voisin, car tous les tracteurs appartiennent au peuple. »
>
> Remarquez ces vêtements liturgiques : la salopette bleue des grandes fêtes et le bleu de travail des jours ordinaires. Le Camarade Pontife Tractorenko les porte encore lors de la Bénédiction des Moteurs, chaque printemps, à la Grande Église.
>
> L'État et le tractorisme sont parfaitement séparés, bien entendu. Il arrive simplement qu'ils pensent la même chose, au même moment.
>
> Avez-vous des questions ? Uniquement historiques, je vous prie.

#### Salle des sportifs de Sovarka — rédigée par Fred (11/11, 19 h 36)

Athlètes de l'image de la salle. Texte de Fred recopié tel quel (introduction et conclusion de Claude gardées). Le basketteur s'appelle **Arvydas Tkatchenko** (Fred, 21 h 01 : « Vladimir Tkhatchenko » existe réellement ; l'image sera refaite avec la plaque « Арвидас Ткаченко »). Au codage, corriger seulement l'orthographe : « inarrêtable », « l'entraîneur de la ville », « forêt », « basketteur », « qui l'a propulsé », doubles espaces ; « Volkok » = **Volkov** (plaque de l'image).

> Voici la Salle des sportifs de Sovarka, camarades. Ici sont célébrés ceux qui ont porté haut nos couleurs, à Novomirsk, à Krasnov et à Starovka.
>
> Igor Sedov, footballeur de Novomirsk. Le plus grand buteur de l’histoire du championnat national. Il était inarrétable, surtout en troisième mi-temps.  Il était célèbre pour fêter chaque but en buvant une bouteille de vodka cul sec. Il n'a jamais marqué plus de 3 buts/match, ceci expliquant cela...
>
> Arvydas Tkatchenko, basketteur de Krasnov, était un véritable colosse. Repéré par l'entraineur de le ville alors qu'il combattait les ours à mains nues en fôret de Krasnov où il était bûcheron, à 12 ans, ses débuts comme basketteurs furent compliqués pour les panneaux de basket qui ont dû être renforcés spécialement du fait de ses dunks destructeurs. Il est le symbole de la puissance Sovarkienne.
>
> Andreï Volkok, perchiste de Novomirsk, était surnommé l'oiseau. Avec sa perche, il déviait les lois de la pesanteur. La légende dit qu'il a eu un orteil gelé suite à un saut qui la propulsé dans la stratosphère. Un accident avec un satellite a mis prématurément fin à sa carrière. Andreï est la seule personne au monde pour qui "Sky is not the limit".
>
> Batyr Nourbaïev, biathlète de Starovka, était prédestiné à devenir un champion. Fils de fermier, il accompagnait les troupeaux de rennes à ski, et devait les défendre contre les attaques de loups et d'ours polaires.  Ses capacités hors normes lui ont valu d'être recruté par l'armée de Sovarka où il fut nommé capitaine de la compagnie en charge de défendre la frontière nord du pays. Mais qui pouvait bien arriver par le nord quand on est la ville la plus au nord du monde... ?
>
> Enfin, Elena Gromova, gymnaste de Krasnov, dix fois championne nationale. Non, camarades, aucun lien avec le président Gromov. La ressemblance des noms est un pur hasard, comme toutes les ressemblances de ce musée. Elle incarne à elle seule la force et la grâce de notre belle nation.
>
> Le sport, camarades, enseigne l'effort, la discipline et le respect des résultats officiels.
>
> Avez-vous des questions ? Uniquement historiques, je vous prie.

#### Salle des artistes de Sovarka — validée par Fred sans changement (11/11, 19 h 40)

Artistes de l'image de la salle : Alexeï Mironov (poète), Severny Veter (groupe de rock), Viktor Roudenko (sculpteur, glace et bois), Sergueï Kravtsov (peintre).

> Voici la Salle des artistes de Sovarka, camarades. La création y est libre, totalement libre, dans le cadre prévu à cet effet.
>
> Alexeï Mironov, poète. Son recueil « Odes au Plan quinquennal » fut tiré à deux millions d'exemplaires, un pour chaque foyer, et sa lecture fut rendue obligatoire. Jamais un poète n'a été autant lu. Son second recueil, plus personnel, n'a jamais été retrouvé. Lui non plus, d'ailleurs, pendant quelques années.
>
> Le groupe Severny Veter, « Vent du Nord », le premier groupe de rock de Sovarka. Leur premier album fut interdit. Le deuxième aussi. Le troisième, « Hymne au Tracteur », est enfin passé à la radio d'État. Les fans de la première heure n'en parlent jamais.
>
> Viktor Roudenko, sculpteur du bois et de la glace, à la tronçonneuse. Ses statues de glace des héros de la nation sont d'une fidélité saisissante, jusqu'au printemps. Il fallait chaque année tout recommencer. L'État y vit la plus belle métaphore de la révolution permanente.
>
> Sergueï Kravtsov, peintre. Il a consacré sa vie aux paysages de Sovarka : usines, cheminées, fumées. Les critiques étrangers lui reprochaient de peindre toujours le même tableau. C'est faux : il a peint aussi la fumée par temps de neige.
>
> L'art, camarades, élève l'âme du peuple. Tant qu'il ne l'élève pas trop haut.
>
> Avez-vous des questions ? Uniquement historiques, je vous prie.

#### Salle des grandes crises de Sovarka — validée par Fred (11/11, 19 h 46)

Quatre crises de l'image : famine (années 1920-1930), Grande Guerre, grève générale (années 1930), finale de 1937 perdue contre El Estado. Apports de Fred : le cœur qui saigne toujours, la blessure indélébile avec laquelle on apprend à vivre.

> Voici la Salle des grandes crises de Sovarka, camarades. Un peuple fort ne cache pas ses épreuves : il les expose, sous verre, avec un éclairage soigné.
>
> La famine des années vingt. Les historiens étrangers parlent de famine. Chez nous, on parle de « période de sobriété alimentaire volontaire ». Dans la vitrine, la carte de rationnement, le sac de farine et le dernier pain de l'époque. Il est authentique. Personne n'a osé le manger.
>
> La Grande Guerre. Nos soldats ont combattu avec un courage que le monde entier nous envie. Je vous rappelle que Sovarka n'a jamais été conquise. Les villes en ruines que vous voyez sur ce tableau ont été réorganisées de manière stratégique par notre état-major.
>
> La grève générale des années trente. Les ouvriers réclamaient des droits pour les travailleurs. Le Parti leur a donné entière satisfaction : la grève a été déclarée illégale, puisque les travailleurs étaient désormais au pouvoir. Contre qui auraient-ils fait grève ? Contre eux-mêmes ?
>
> Et enfin, la plus douloureuse de toutes : la finale de 1937, perdue contre El Estado. Ce jour-là, la nation entière a pleuré. Aujourd'hui encore, notre cœur saigne : jamais Sovarka ne se remettra de cette défaite. On n'oublie pas, on apprend simplement à vivre avec cette blessure indélébile. Notre arbitre avait pourtant été soigneusement choisi. Le leur aussi, hélas. La revanche n'a jamais eu lieu : El Estado refuse toujours de rejouer ce match. Il faut croire qu'ils ont peur.
>
> Avez-vous des questions ? Uniquement historiques, je vous prie. Et si possible, pas sur le football.

#### Salle des expositions tournantes — décision de Fred (11/11, 19 h 53), PAS de feu vert de codage

- La salle fonctionne en **génération d'image premium**, sur le modèle des options premium des commerces : coût réel **1,90 €**.
- **Ouverte à tout joueur** (Fred, 19 h 55 : pas réservée aux dignitaires). L'image reste exposée **7 jours**.
- **Aucun effet de jeu** : ni bonus, ni POP, purement cosmétique (règle du freemium jamais pay-to-win).
- **Espace de liberté** (Fred, 20 h 00) : aucune évaluation automatique du caractère « subversif ». Ce sont les autorités
  jouées par des PJ qui jugent : l'auteur (connu par le registre du musée) peut **répondre de ses actes en jeu** s'il est mis
  en cause (circuit de justice existant : plaintes, consignes, juge). **L'image n'est jamais décrochée** avant ses 7 jours,
  pour éviter toute protestation HRP d'un joueur qui a payé ; seul l'auteur peut être poursuivi.
- **Modération réelle** : celle de l'IA au moment de la génération (contenus interdits), qui protège naturellement le jeu.
- **Une seule exposition à la fois** (Fred, 20 h 52).
- L'option premium comprend **l'image et un texte** écrit par l'auteur, que la **guide raconte** aux visiteurs, **en
  multilingue** (traduit dans la langue de chaque joueur, sur le principe de la présentation fixe : traduit une fois par
  langue puis resservi). Le texte reste celui d'un joueur : la guide le récite, il ne lui donne aucune instruction.
- **File d'attente** (Fred, 20 h 54) : un joueur peut réserver alors que la salle est occupée ; sa demande prend place dans
  l'ordre des réservations, et chaque exposition démarre à la fin de la précédente.
- **Textes de la guide validés par Fred (20 h 56)**, nom de l'auteur affiché :

  Salle vide :

  > Voici la Salle des expositions tournantes, camarades. Admirez. Vous ne voyez rien ? C'est normal : l'exposition précédente est terminée, et la suivante n'a pas encore été réservée. Certains visiteurs y voient une œuvre d'art à part entière : « Vitrines vides », le seul chef-d'œuvre de Sovarka que l'État n'a jamais eu à censurer. Si vous souhaitez exposer, adressez-vous à l'accueil.

  Exposition en cours (`{auteur}` = nom du PJ, `{texte}` = texte de l'auteur, jamais modifié, traduit pour l'affichage) :

  > Voici la Salle des expositions tournantes, camarades. Cette semaine, le musée a l'honneur de présenter l'œuvre de {auteur}. Je vous lis les mots de l'artiste :
  >
  > « {texte} »
  >
  > Le musée rappelle que les opinions exprimées ici n'engagent que leur auteur. Et elles l'engagent entièrement.


## Pavillon des Ambassadeurs — accès réservé aux dignitaires (Fred, 11/11/2026, 23 h 27) — CODÉ le 12/11/2026 (feu vert de Fred)

**Codé (12/11/2026)** : migration `20261111232000_acces_reserve_pavillon_residence.sql` (appliquée), module `plateau-acces-reserve.js` (9 langues), banc `outils/bancs/banc-acces-reserve-20261112.cjs`. Porte serveur dans la navigation intérieure (raisons `acces_dignitaires`, `location_requise`, `un_seul_invite`) ; RPC `acces_forcer_passage` (2 PA, jet serveur, intrusion jusqu'à la sortie du bâtiment, recherche `forcer_passage`) ; garde temporaire `garde_acces:<id>` combattu dans le moteur de combat (bataille `garde_acces`, victoire = intrusion) ; RPC `residence_etat` et `residence_acte` (réserver, renouveler, mini-bar) ; bonus de nuit dans `pa_repos_nocturne`. Choix de codage : le Hall du Pavillon reçoit l'ordre d'information « Demander l'accès aux salons » ; un invité de la Résidence est admis s'il est **seul** membre du groupe du locataire. **Reste à faire** : le service d'étage (achat à distance de la carte du Grand Hôtel), non livré dans ce lot.

- Seul l'**accueil** (hall) est ouvert à tous. **Toutes les autres pièces** (bar, grande salle de réception, trois suites) sont réservées aux personnes qui ont l'un des postes requis (Fred, 23 h 30).
- Un clic sur l'onglet d'une pièce réservée ouvre une fenêtre : « Accès strictement réservé aux personnes possédant les postes de : [liste des postes]. »
- Ordre **« Forcer le passage »**, acte illégal : s'il est détecté, **1 jour de prison et 1 500 PSK d'amende**. S'il réussit, le PJ visite la pièce de l'onglet, mais il est **recherché par la police**.
- Cette règle remplace la mention « À LOUER » des suites.
- **Même mécanique à la Résidence impériale** (bâtiment d'en face, Fred, 23 h 50), codée en même temps : un seul mécanisme réglé par bâtiment (pièces réservées, critère d'accès, garde à affronter). **Accueil de la Résidence** (Fred, 12/11, 0 h 04) : les deux personnes de l'image, une réceptionniste qui prend les réservations et un homme en uniforme qui **fait office de gardien** (c'est lui qu'on affronte en forçant le passage). Noms **validés par Fred** (12/11, 0 h 06) : **Lev Zamkov** (le gardien ; *zamok*, la serrure) et **Ekaterina Klioutcheva** (la réceptionniste ; *klioutch*, la clé). **Ordres à refaire au codage** (Fred, 0 h 06) : les appartements portent encore l'ancienne location de local (« Louer cet appartement (500 PSK/jour) », « Gérer mon local ») ; ils doivent céder la place à la réservation à l'accueil (3 jours renouvelables, 1 000 / 1 800 PSK la nuit, rendu à 12 h 00), au service d'étage, au mini-bar et à « Remplir le minibar » ; noms des pièces sans « Local à louer ». Ils remplacent le « Gardien de la Résidence » sans nom.
- **Critère d'accès à la Résidence** (Fred, 23 h 55) : avoir **réservé un des appartements à l'accueil**. Mécanique des hôtels, mais en **location privative** de **3 jours renouvelables** : l'appartement se rend **au bout de 3 jours à 12 h 00**, ou la location est renouvelée. Bonus du 04/11 **confirmés** (Fred, 12/11, 0 h 02) : petits appartements +4 POP +4 INF +4 DIS, grand appartement +15 POP +15 INF +5 DIS, appliqués comme à l'hôtel, à chaque nuit passée dans l'appartement (ordre « Dormir »).
- **Tarifs de la Résidence** (Fred, 11/11, 23 h 59, remplacent 500 et 1 200 du 04/11) : **1 000 PSK la nuit** pour les petits appartements, **1 800 PSK** pour le grand.
- Pas de restaurant ni de bar dans la Résidence : **l'accès est limité à son propre appartement**. Le locataire peut **amener une seule personne** qui l'accompagne.
- Dans les appartements : **service d'étage** proposant la carte du restaurant du Grand Hôtel de Sovarka, **payé en plus** ; **mini-bar gratuit, limité à 3 bouteilles d'alcool local par location de 3 jours** ; ordre **« Remplir le minibar »** (350 PSK) pour le regarnir (Fred, 12/11, 0 h 01).
- **Forcer le passage** (Fred, 23 h 36) : **2 PA** ; réussite **60 % + 4 % par point de VOL au-dessus de 13** (moins 4 % par point en dessous). Sans borne à prévoir : la VOL va de 3 à 16 (relevé des fiches le 11/11), soit de 20 % à 72 % (76 % avec un séminaire). En cas d'**échec**, le PJ **entre en combat contre le garde** (Arkadi Belov), moteur de combat existant.
- **Issue du combat** (Fred, 23 h 42) : s'il **gagne**, le PJ entre dans la pièce ; il **ne peut pas la louer**, mais peut y **poser une caméra, déposer un objet ou la fouiller** ; il est **recherché par la police**. S'il perd : règle habituelle du combat perdu (hôpital).
- **Une fois entré** (Fred, 23 h 45), le PJ circule librement entre les pièces réservées : le garde est neutralisé. Ce libre accès dure **jusqu'à ce qu'il ressorte du Pavillon** (Fred, 23 h 48) ; pour revenir, il doit forcer le passage à nouveau.
- **Postes qui ouvrent l'accès** (Fred, 23 h 32) : les dignitaires étrangers (ambassadeurs, ministres, présidents, députés) **et ceux de Sovarka** (Président, Président du Conseil du Peuple, ministres, députés). Les prix pratiqués face aux salaires sovarkiens alimenteront les scandales : c'est du jeu entre joueurs, aucune mécanique à coder.

## Pavillon des Ambassadeurs — personnages et portraits (Fred, 11/11/2026, 23 h 11)

Les personnages suivent désormais les images, et leurs portraits en sont tirés. **Hall** : Arkadi Belov devient le **garde** du Pavillon (décision de Fred) ; deux hôtesses ajoutées, **Touyana Dachieva** et **Alina Belokourova**. **Grande salle de réception** : **Grigori Podnosov** et **Varvara Salfetkina**, serveurs de réception. **Bar** : **Mikhaïl Stakanov**, barman, aux côtés de Lena Abramova. Noms proposés par Claude (Fred : « invente les noms »). La suite s'appelle désormais **Suite des Partis**, comme sur sa plaque (Fred, 23 h 20) ; sa description cite le **buste du camarade président Zolotov** au lieu d'un « Secrétaire général » inexistant en Sovarka (Fred, 23 h 27). Restent signalés par l'audit du 11/11 : description de la Suite Privée héritée du Républica et mention « À LOUER » (à régler par l'accès réservé aux dignitaires, en discussion le 11/11 au soir), enseigne « Résidences Impériales » au pluriel vue des suites, prix du bar affichés en FR. La ligne « État technique : non livré » ci-dessous est caduque depuis la PR #764.

## Pavillon des Ambassadeurs — décisions financières du 11/11/2026

La règle explicite la plus récente de Fred prévaut sur la ligne du 04/11 : les suites sont réservées aux dignitaires étrangers (ambassadeurs, ministres, présidents, députés), payées par l'institution signataire et non par le portefeuille du joueur. **Tarifs journaliers : Suite du Parti 500 FR ; Suite Privée 650 FR ; Suite Présidentielle 800 FR.** Bail de sept jours renouvelable ; résiliation avant terme : un seul jour de ménage supplémentaire facturé une fois. Le bénéficiaire d'une suite louée reçoit +3 PA lors de chaque sommeil autorisé, jamais au moment de la réservation. La grande salle de réception se réserve exclusivement par une institution pour 1 500 PSK par jour, recettes à Sovarka.

**Décision complémentaire de Fred du 11/11 : parité fixe et sans frais, 1 PSK = 1 FR.** Les règlements de ces chambres et de la réception peuvent utiliser la parité 1:1 sans faux différentiel monétaire ; la comptabilité doit conserver les informations de devise de chaque opération. Aucune conversion générale des autres monnaies/transactions du jeu n'est décidée.

**État technique au moment du relevé : non livré.** Les anciens boutons `louer_local` et tarifs 500 PSK sont encore présents pour les trois suites, et la salle ne dispose pas de réservation. La facturation des ambassadeurs doit encore s'appuyer sur une caisse institutionnelle autorisée et reconnue, pas sur la création arbitraire d'un compte. Voir l'issue #753.

## Pavillon et Résidence : service d'étage, escorts et espionnage (Fred, 12/11/2026, 0 h 41 – 1 h 23) — CODÉ le 12/11/2026 (feu vert de Fred, 1 h 23)

**Codé (12/11/2026, branche `claude/escorts-pavillon-residence-20261112`, PR #779)** : migrations `20261112005000_escorts_roxane_velours_sovarka`
et `20261112012000_escort_rumeur_marqueur` **appliquées, NE PAS RÉAPPLIQUER** (banc annulé `outils/bancs/banc-escorts-roxane-velours-20261112.sql`
vert sur la production avant application) ; écran `plateau-escorts-sovarka.js` (9 langues), banc `banc-escorts-sovarka-20261112.cjs`.
- Ordres verts **« Appel à un(e) escort »** (`escort_standard`) et **« Service d'étage »** (`service_etage_carte` : `service_etage` est déjà
  l'ordre des hôtels de Républia) dans les 3 suites du Pavillon et les 5 appartements de la Résidence ; le serveur vérifie que l'on est le
  locataire, dans sa pièce (bail diplomatique actif au Pavillon, location en cours à la Résidence).
- Standard : la réponse libre est lue par le serveur (`escort_demande_analyser` : chiffres et nombres en neuf langues, « une/un escort »,
  « les deux ») ; demande incomprise ou genre imprécis = Rebecca demande de préciser ; demande plafonnée aux escorts libres du catalogue et
  au plafond de 10 employés. Validation = embauche identique à `escort_recruter` (800 PSK chacun, paie de nuit, renvoi par le PJ), trace
  `appel_escort` (cible « lieu|intitulé du poste »).
- Rumeur : `rumeur_ecoute_jauges_interne` reconnaît `appel_escort` ; chaque écoute retire 3 POP (`escort_scandales.ecoutes`) ; à la 3e,
  projets d'article (`interieur_dossiers`) au ministre de l'Intérieur de Sovarka et, si le poste est étranger, à celui de son pays ;
  ministre PJ = courrier + ordre **« Dossiers confidentiels »** (bureau du ministre de l'Intérieur, Républia et Sovarka) : valider la
  publication (article dans la file du journal du pays) ou mettre en attente ; ministre PNJ = tirage à 50 %. La trace s'éteint après
  7 jours de jeu, comme toutes les traces de rumeur.
- Choix de codage : aucun poste de journaliste PJ n'existe aujourd'hui, les journalistes sont donc toujours des PNJ et le projet va
  toujours au ministre ; un intrus ou un invité ne voit pas l'ordre agir (refus « réservé au locataire ») ; les 20 PSK de service vont à la
  caisse du restaurant du Grand Hôtel ; un dossier piraté laisse une trace « pirater » au nom de l'escort, jamais racontée par les rumeurs.
- Secrets : déclencheur sur `renseignements_connus` (confidences et « secret contre secret » reçus par une escort du catalogue, client
  présent en Sovarka) → dossier et courrier au ministre de la Sécurité du Peuple.
- Piratage : branché dans le Dormir (`pa_repos_nocturne`), une fois par nuit (`escort_piratages_nuits`).
- **« Faire l'amour » au serveur (12/11/2026, Républia et Sovarka, exigence de Fred : « une seule vérité »)** : `escort_intimite`
  (migration `20261112014500_escort_intimite_serveur`) vérifie l'embauche, paie l'étape éventuelle et la nuit en un seul débit, tient
  le palier de complicité (`escorts_complicite`, remis à zéro si l'escort change d'employeur) et applique les effets. Barèmes repris
  à l'identique de l'écran, sans nouvelle décision : étapes 100 / 300 / 600, nuit 300 (monnaie du PJ) ; Moral +15/18/22/28,
  Santé +5/6/7/10, ENT +2/2/3/4 selon le palier ; ENT plafonnée à 20 et une seule progression par jour réel, désormais enregistrée
  au serveur (`ent_gains_quotidiens`).


**Service d'étage** : disponible dans les **deux** bâtiments (suites du Pavillon, appartements de la Résidence). Carte du restaurant du Grand Hôtel de Sovarka **à son prix**, **+ 20 PSK de service par commande** (les 50 FR des hôtels de province de Républia à l'échelle de Sovarka) ; mêmes effets qu'au restaurant.

**Ordre « Appel à un(e) escort »**
- **Ordre vert** de pièce dans les suites du Pavillon et les appartements de la Résidence ; **seul le locataire** peut le passer.
- **Légal mais immoral.**
- Il ouvre une fenêtre qui simule le **standard de l'agence internationale Roxane Velours** (clin d'œil assumé : l'agence a été fondée par Roxane Velours, l'escort du catalogue ; même orthographe). Accueil fixe : « Bonsoir, agence internationale Roxane Velours à l'appareil, Rebecca pour vous servir. Que puis-je pour vous ? » ; **réponse libre** du PJ (un, une, les deux, plusieurs) ; Rebecca : « Très bien, je vous les envoie de suite. Le coût est de [nombre] × 800 PSK. Validez le paiement sur votre téléphone. » ; pictogrammes **valider / refuser** cliquables ; refus : « Vous n'avez pas validé, ce n'est pas grave. En espérant vous satisfaire une prochaine fois. Passez une bonne soirée. », puis fermeture.
- **Validation** : les escorts PNJ apparaissent immédiatement dans la pièce ; **c'est la validation qui déclenche la trace**.
- **800 PSK par jour et par escort** ; ils ne disparaissent que si le PJ **rompt le contrat** : **mêmes mécanismes qu'en Républia** (embauche, paie de nuit, secret contre secret, « Faire l'amour »…). Escorts envoyés : les **7 du catalogue de Républia** (agence internationale) ; le PJ donne un nombre et des genres, le serveur choisit ; de nouveaux PNJ escorts viendront probablement plus tard.
- Note de codage (Claude) : la réponse libre est interprétée par le serveur (nombre et genres seulement ; hors sujet = Rebecca reformule) ; les bonus de « Faire l'amour », encore calculés par l'écran en Républia, passeront au serveur.

**Rumeur et presse**
- Chaque fois que la rumeur est entendue (« Écouter les rumeurs », barman, tables) : **−3 POP** au dignitaire.
- **Décompte** : à la **3ᵉ écoute** (−9 POP), la rumeur parvient aux journalistes ; elle **continue de circuler** ensuite, −3 POP à chaque écoute, **sans plafond**.
- Journalistes prévenus : **celui de La Voix de Sovarka à Novomirsk** et **un journaliste du pays du dignitaire** (dignitaire de Sovarka : Zoïa seule).
- **Journaliste PNJ** : il en réfère au **ministre de l'Intérieur de son pays** (Sécurité du Peuple en Sovarka), par courrier, sous forme de **projet d'article** ; le ministre **valide la publication** ou la **met en attente** (sans date limite, publiable quand il veut) ; **ministre PNJ : tirage à 50 %**.
- Accueil de La Voix de Sovarka à Novomirsk (remplace le « Correspondant Local » générique) : **Zoïa Glazounova**, journaliste (la réceptionniste au regard inquiétant) ; **Capitaine Arseni Petchatnikov**, officier de censure (ambiance).
- Textes validés :
  - rumeur : « On raconte que l'agence Roxane Velours a fait livrer de la compagnie au Pavillon des Ambassadeurs, chez {nom}, {poste}. Et pas pour parler politique. » (lieu adapté : « à la Résidence impériale ») ;
  - projet d'article : **« Soirée velours pour {poste} »** — « Selon nos informations, {nom}, {poste}, a fait appel aux services de l'agence internationale Roxane Velours dans son appartement du {lieu}, aux frais de qui, la question reste posée. La rédaction a tenté de joindre l'intéressé, sans succès. »

**Espionnage**
- En Sovarka, **tous les secrets** obtenus par les escorts (secret sur l'oreiller et secret contre secret) sont **transmis au ministre de l'Intérieur**.
- Dignitaire venu avec un **ordinateur** (dans son inventaire) : **25 % de chances, une fois par nuit** (escort sous contrat, nuit passée dans l'appartement), qu'un escort PNJ le pirate : **copie discrète d'un dossier au hasard** pour le ministre de l'Intérieur de Sovarka ; le dignitaire garde l'original et **n'est pas prévenu** (seule la trace d'un acte illégal ordinaire).

## Musée municipal de Novomirsk et énigme du trésor des Tsars (Fred, 12/11/2026, 18 h 46 – 20 h 14) — CODÉ le 12/11/2026 (feu vert de Fred, 20 h 14)

**Novomirsk** : ancienne ville des Tsars ; bâtiments cossus au centre, la ville ouvrière construite autour.

**Musée municipal** : hall d'accueil conservé (Irina Filippova, Docteur Lev Vinogradov, vétéran Ilia Krioukov, guide militaire à la retraite). Les neuf salles du panthéon sont remplacées, à Novomirsk seulement (Krasnov, qui réutilise le bâtiment, garde les siennes) ; images à venir.
- **Salle 1 — Salle des Origines** : Novomirsk sur le fleuve Sovarka, zone riche et fertile (agriculture, pêche), fleuve d'échanges entre villes et pays ; capitale des Tsars, restée capitale quand la démocratie a renversé le régime. Légende : le trésor des Tsars a disparu au fond du fleuve quand Sergueï IV, dit le Terrible, s'est enfui dans une barque qui prenait l'eau et s'est noyé ; depuis, les pêcheurs espèrent remonter un coffre plutôt qu'une carpe. Ordre « Écouter le guide » (gratuit).
- **Salle 2 — Salle des Personnalités discrètes** : les présidents, sportifs et artistes sont au musée national ; ici, les personnalités plus discrètes. Sophia Nouiseteskaïa (métier à tisser, voile transparent, vêtements de nuit au pouvoir fou sur les hommes) ; Viktor Polov (coursier de Léonid III, le sac de sucre de Krasnov passé de cavalier en cavalier, origine du polo, disparu dans la Sovarka) ; Alexander Aspirine (vin fermenté contre les maux de tête, fait vomir à forte dose) ; Ivan Betonov (architecte du Palais du Gouvernement, cinq ans de pénurie de matériaux) ; Anna Mouriskova (prostituée et espionne, exécutée sur ordre du camarade président Taras Sergueïevitch Belov, jalousie ou secrets, on ne saura jamais). Dates proposées par Claude.

**Énigme du trésor des Tsars** : première énigme de Novomirsk, **gratuite** (règle : la première énigme de chaque ville est gratuite). **Étapes dans l'ordre imposé** ; un PNJ abordé trop tôt ne révèle rien ; **chaque joueur mène sa propre enquête**.
1. **Le guide** (Salle des Origines) termine par : « demandez à la femme du pêcheur qui vend du poisson le long des quais si ses poissons valent de l'or… ».
2. **Galina Karpova**, la poissonnière, reconnaît « or, trésor, coffre » : son mari pêche de père en fils, rien trouvé sauf un morceau de bois gravé de l'aigle impérial ; renvoie au vieux **Evgueni Sudakov** (familles brouillées ; il est à l'EHPAD, perd la tête sauf pour insulter les Karpov qui lui auraient pris sa zone de pêche).
3. **Evgueni Sudakov** (EHPAD de Novomirsk) reconnaît « or, trésor, coffre, aigle, impérial, empereur, tsar » : il a couru après le trésor toute sa vie, croyait la barque coulée le long des quais dans la concession des « maudits Karpov » (qu'il avait demandée avant eux) ; veut que le joueur le trouve avant eux ; indice : une vieille dame de l'EHPAD, décédée, faisait le ménage au palais présidentiel, où un livre raconterait le naufrage et l'endroit exact où la barque a coulé.
4. **Musée du Palais présidentiel** : l'ordre de fouille trouve **à coup sûr** le livre « Le fabuleux trésor des Tsars » (un exemplaire par joueur), à moitié effacé : « le trésor est composé… », le dessin d'une chose ronde posée sur une chose ronde (bas effacé), puis « …chez la mère Volga ».
5. **Tatiana Bortchova** (Mère Volga) reconnaît le livre ou « livre, trésor, Sergueï, tsar » et demande à le voir ; le joueur le lui **donne** (il quitte l'inventaire) ; « MON DIEU ! LE TRÉSOR DES TSARS ! » ; le joueur répond ce qu'il veut ; récit : son arrière-grand-mère, pâtissière de la cour, inventa le gâteau (pâte à choux, crème chiboust, amandes effilées, chantilly), servi chaque dimanche avec le « Nectar des Dieux » ; Léonid III soulevait le couvercle par la noisette : « J'ouvre le coffre et je découvre le trésor des tsars » ; Sergueï emporta le livre de recettes, le bateau coula, le livre s'échoua et fut rapporté au palais par un vieux pêcheur, Sudakov, emprisonné à vie par les révolutionnaires ; le livre resta à l'abandon. Récompense : **deux « Trésor des tsars »**.
- **Le gâteau** : +1 PA et +10 de moral ; à manger avant 4 jours (au-delà, la crème a tourné : −1 PA, comme un aliment périmé — choix de Claude, par cohérence).
- Image de Tatiana à recentrer (à faire avec les images).

## Musée municipal de Novomirsk — achèvement visuel et deux épisodes locaux (Fred, 12/11/2026)

**Direction artistique validée :** architecture impériale du musée (colonnes, plafonds ornés, parquet, vitrines en bois et laiton, éclairage chaleureux), avec une salle distincte par exposition ; aucune image ne doit mélanger les collections. **Ilia Krioukov** est présent dans l'interface des personnages de chaque salle ; sa photo de profil s'affiche dans la colonne des présents, mais **jamais dans le décor des salles**. Le mécanisme serveur de l'énigme du trésor des Tsars et de la fouille demeure inchangé.

- **Salle des Origines** : cartes historiques, filets et barques, vitrine impériale vide ; ordre gratuit « Écouter le guide », première étape de l'énigme existante.
- **Salle des Personnalités discrètes** : cinq portraits et objets relatifs à Sophia Nouiseteskaïa, Viktor Polov, Alexander Aspirine, Ivan Betonov et Anna Mouriskova ; « Consulter les personnalités » conserve son fonctionnement.
- **Salle de la Bataille du Fleuve (1742)** : le prince Mikhaïl Dragounov descend la Sovarka avec 27 embarcations et près de 800 hommes ; le capitaine Piotr Karassov et les pêcheurs de Novomirsk retirent les balises et placent des pieux. Citation traditionnelle : « Ils avaient huit cents soldats. Nous avions le fleuve. » La barque exposée est attribuée à Karassov, sans certitude historique ; Ilia est particulièrement fier de cet épisode.
- **Salle du Grand Incendie (1887)** : le four oublié d'un apprenti de la boulangerie Grigori Pirogov déclenche trois jours d'incendie dans le quartier marchand, ravageant près d'un tiers de la vieille ville ; reconstruction en pierre et en brique. Exposition : fresque, casques, pompe à bras, plans et miche de pain calcinée.

**Livraison technique :** les quatre PNG de Fred ont été convertis en quatre WebP distincts puis supprimés ; les quatre salles ont leur image dans `data.js`. Deux nouveaux IDs de pièces : `salle_bataille_fleuve`, `salle_grand_incendie`. Seule la navigation `soviet/capitale/musee-novomirsk` est étendue côté Supabase (migration enregistrée `musee_novomirsk_bataille_incendie_20261112`) ; Krasnov conserve son musée et exclut ces quatre pièces novomirskoises. PR #827 fusionnée, tests GitHub Actions réussis, déploiement Vercel READY sur `bab23f40`. Visite réelle en PJ encore à contrôler.

### Visite d'Ilia Krioukov — musée municipal (livraison du 12/11/2026)

Décision de Fred après essai en jeu : **ne plus afficher le long récit historique par-dessus l'image**, car il est illisible. À la place, dans **les cinq pièces** du musée municipal de Novomirsk, le bouton gratuit **« Écouter le guide »** ou la carte du vétéran Ilia Krioukov ouvre une fenêtre avec son portrait, un récit oral en paragraphes propres à la salle, et sa proposition de répondre aux questions du visiteur. Ilia n'est pas dessiné sur les images de salle, seulement présent dans la colonne de personnages.

Même règle de questions que la guide Ouliana du musée national : **1 PA ouvre 3 questions par salle et par jour**, comptées par le serveur. L'ordre de la Salle des Origines reste `tresor_ecouter_guide` et continue d'appeler la RPC `tresor_tsars_guide` avant la fenêtre ; **aucune modification** des fonctions serveur de l'énigme des Tsars ou de la fouille. Les autres salles et le hall utilisent `ilia_ecouter_guide`. Le corpus IA d'Ilia sait expliquer les cinq personnalités et les deux événements locaux sans inventer de récompense ni dévoiler les secrets de l'énigme.

**Statut technique au 12/11** : PR #830 fusionnée ; CI du guide et de l'énigme réussie ; migration `ilia_questions_musee_municipal_20261112` enregistrée et vérifiée sur Supabase ; Vercel production READY sur `87dc83a8`. La visite connectée et les réponses DeepSeek réelles restent à essayer. Les cinq nouveaux récits fixes sont en français pour le moment, avec un repli français dans les autres langues bêta.

## Héros du Travail (Fred, 13/11/2026 après-midi) — CODÉ le 13/11/2026 (feu vert de Fred)
- **Points** : les PA dépensés en ordres de production en Sovarka (usines, commerces, récoltes, ferme, forêt, garage, chantiers), par **tout personnage présent en Sovarka, étrangers compris** (un chasseur de médailles comme Vince peut venir la gagner).
- **Semaine** : du lundi 0 h au dimanche 24 h, heure de Paris.
- **Classement** : envoyé par courrier à minuit, la nuit de dimanche à lundi, au **ministre de l'Économie collective** ; sans ministre, au **Président du Conseil du Peuple**.
- **Attribution non automatique** : le ministre décide, dans son bureau du Palais du Gouvernement (« Héros du Travail »).
- **Record en attente** : il ne peut pas décorer quelqu'un qui a moins de points que le meilleur record non décoré, toutes semaines confondues (20 points non décorés bloquent un 17 la semaine suivante). À égalité, il choisit.
- **Médaille** : objet d'inventaire avec l'image de la plaque, gravé au nom du décoré (semaine, points). Installable (déposer / reprendre) dans un logement dont on a la jouissance : **+3 Moral à quiconque y dort**, sans cumul. Donnable, vendable, volable, transmise par succession.
- **Publicité** : liste des décorés à l'**accueil** des trois mairies ; décorations affichées dans la fenêtre d'interaction d'un personnage ; annonce au journal du matin. **Aucun bonus de POP.**
- Choix d'interprétation (Claude) : une seule décoration par semaine.

## Boîte aux lettres du Parti (Fred, 13/11/2026 après-midi) — CODÉ le 13/11/2026 (feu vert de Fred)
- Une boîte par parti, dans la **salle des partis** des trois mairies.
- Bouton vert « **Poster une dénonciation** » : fenêtre « Dans quelle boîte aux lettres de parti voulez-vous poster votre dénonciation anonyme ? », menu déroulant des partis, **texte libre**, aucune vérification, aucune liste de cibles. **1 PA**, pas d'argent.
- **Anonymat total** : l'auteur n'est enregistré nulle part.
- **Registre** : tout y est consigné. Le **chef du parti** désigne qui y a accès ; **seul le chef** supprime une dénonciation.
- **Information pure** : la suite appartient aux joueurs.
- Choix d'interprétation (Claude) : registre lu dans la salle des partis ; 2 000 caractères au plus ; le chef peut désigner n'importe quel personnage.
