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
- **Maires** : élus comme en Républia, mais **tout candidat doit d'abord adhérer à un parti**. **Même règle pour la présidentielle** : tout candidat à un poste électif de Sovarka est membre d'un parti.
- **Cas limites** (proposés par Claude, validés) : égalité entre partis → le plus d'adhérents PJ, puis le plus ancien ; aucun parti en Sovarka → le président nomme librement le chef du gouvernement.

### Pouvoir en Sovarka : ce qui est codé (07/11/2026)

- **Intitulés** : `INTITULES_POSTES_PAR_PAYS` + `intitulePoste()` (`data.js`) ; journal du matin (`api/_journal-collecte.js`). Bureaux et rôles des PNJ du Siège du Comité Central aux nouveaux intitulés (images des bureaux à venir).
- **Salaires** (migration `20261107094000`) : le pays employeur se lit au registre (`postes_attribues`, puis `cycles_electoraux` pour un élu), plus au barème unique.
- **Partis** (`20261107120000`) : organisations de type `politique` de Sovarka (`sovarka_parti_de`) ; candidature à la présidence ou à une mairie refusée sans parti (`parti_requis`) ; pas de candidature de député (`depute_designe_par_parti`).
- **Semaine à la gloire** (`20261107121500`) : cycles de Sovarka créés (présidentielle, trois mairies, `gloire_partis` au calendrier de la présidentielle) ; les candidats du cycle de la gloire sont les partis (resynchronisés chaque nuit) ; les tracts visent le **nom du parti** ; décompte à la proclamation par `sovarka_gloire_proclamer` (avant la présidentielle de la même nuit) ; 9 sièges du Soviet Suprême aux plus forts restes sur les partisans (sur le total si aucun partisan) ; chef du parti vainqueur nommé d'office Président du Conseil du Peuple (sauf s'il est déjà président ou maire : `chef_deja_elu`, le président nomme alors librement) ; tant qu'un parti a gagné, le président ne nomme plus le pm (`pm_impose_par_le_parti`) ; ministres choisis parmi les membres du parti du pm (`ministre_hors_parti`).
- **Députés** (`20261107123000`) : à l'hémicycle du Soviet Suprême, le chef de parti désigne ou retire ses députés, dans la limite de ses sièges ; la fiche porte « Député du Soviet Suprême » ; la législature sortante perd ses sièges à la proclamation suivante. Aucun salaire de député de Sovarka (non décidé).
- **Repas du président** (`20261107124500`, effets choisis par Fred le 07/11 : ceux du dîner d'affaires) : pièce « Appartements présidentiels » au Palais du Parti (`20261107130000` pour la navigation serveur) ; un repas par jour, seul ou avec un invité présent : +10 Santé, +2 Moral, +5 INF, +3 PA au prochain Dormir pour chacun. Image à venir.
- **Reste** : statut de dignitaire à raccorder quand les invitations des ambassades et entre gouvernements existeront (voyage inter-empires).

## Règle des noms de PNJ de Sovarka (Fred, 07/11/2026)

Noms russes authentiques (bouriates à Starovka), sans jeu de mots français. Exceptions : sept figures satiriques (Innokenti Partiïev, Zinaïda Propagandova, Rostislav Censurov, Raïssa Communiqueva, Macha Scoopova, Pavel Pistonov, Dimitri Compassov) ; les noms choisis par Fred ; les noms bâtis sur un mot russe (Smetanine, Blinova, Vodkaïev, Sévérov…). Tout nouveau PNJ de Sovarka suit cette règle. Le renommage du 07/11 a appliqué le tableau validé par Fred (75 noms, voir l'historique Git).
