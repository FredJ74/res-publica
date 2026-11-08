# Catalogue des mécaniques — extraction de l'architecture historique

**Source :** [ARCHITECTURE.md](../ARCHITECTURE.md), inventaire du 26–27 octobre 2026 ; extraction fidèle des colonnes « Mécanique / Ce qu'elle fait / État / Pour un nouvel empire », sans correction interprétative. **Les statuts Serveur/Mixte/Écran/À créer sont historiques et ne sont pas les statuts D/C/T/M/P/J de l'audit.** Le rapprochement avec le code du 9 novembre reste à réaliser au niveau des ordres.

**61 lignes de mécanismes réparties en 15 domaines.** Cet inventaire explicite complète l'atlas et évite de perdre les petites mécaniques entre les chapitres.


## Moteur

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Identité et autorité | Reconnaît le joueur, son poste, sa présence sur place ; refuse ce qu'il n'a pas le droit de faire. | Serveur | Rien : commun. |
| Temps | Horloge commune (heure de Paris), bascule à minuit pour tous, échéances en temps réel. | Mixte | Rien : l'horloge est commune. Pas de date d'origine propre sans décision. |
| Paiement des ordres | Prélève PA et francs selon le coût déclaré de chaque ordre. | Serveur | Coûts des ordres propres à l'empire. |
| Caisses | Caisses des bâtiments et des institutions ; un crédit doit venir d'un paiement réel. | Serveur | Caisses de ses institutions. |
| Inventaire | Objets possédés, donnés, consommés, confisqués. | Mixte | Objets propres (armes, reliques, produits). |
| Lieux et présence | Bâtiments, pièces, déplacements, qui est où. | Mixte | Plan, rues, bâtiments, images. |
| Messagerie | Mails à boutons d'action, forum, chat de pièce, salons. | Serveur | Rien : commun. |
| Mémoire publique | Journal personnel, chronique nationale, annonces publiques. | Mixte | Rien : commun. |
| Ordres | Catalogue des actions par pièce et routeur ; l'ordre générique (cinq ordres) est tiré par le serveur depuis le 27/10. | Serveur | Ordres adaptés à l'histoire de l'empire. |
| Intérim des PNJ | Un PNJ tient un poste vacant en attendant un joueur. | Mixte | Noms et portraits des titulaires PNJ. |
| Dialogues des PNJ | Conversations des PNJ par DeepSeek, avec fiches de personnalité. | Serveur | Fiches de personnalité, bibles de contexte. |
| Indices | Sécurité, économie, social, piété, moral par ville ; Indice Diplomatique par pays. | Mixte | Valeurs de départ. |

## Vie du personnage

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Création | Origine, école, archétype, carrière, caractéristiques. | Mixte | Origines et écoles du pays. |
| Santé, moral, popularité | Points de vie, moral, popularité, influence, discrétion. | Écran | Rien : commun. |
| Hospitalisation à 0 PA | PA tombés à 0 (ordres ou combat perdu) : hospitalisation automatique au dispensaire de la ville (déclencheur différé, détention prioritaire) ; J0 sans déplacement, Dormir, mail ni forum ; Dormir 2 / 6 puis 12 PA, ×3 en clinique ; repas de l'hôpital 1 PA (+2 au Dormir suivant), de la clinique 1 PA + 30 FR (+4) ; rébellion (arrêté au terme du combat) : J0 à l'hôpital sous écrou, 2 PA à J1 puis cellule, 4 PA par Dormir en détention ; transfert en clinique dès J0 et sortie (J2, 20 PA) par la porte `hospitalisation_lieu_rejoindre`. L'empoisonnement garde ses durées par palier. Règles : `GAME-DESIGN-HOSPITALISATION.md`. Préparé le 01/11 (correctif à intégrer après #318), non déployé. | Serveur | Un dispensaire référencé par ville (`navigation_lieux_regles`, `dispensaire-public%`) et sa sortie de rue. |
| Université | Inscription à un cursus, jalons, seconde carrière ; syndicats étudiants, conférences. Le bouton « Suivre une formation » est en « bientôt ». | Serveur | Établissements et cursus. |
| État civil | Demande en mariage (depuis la fiche d'un joueur), divorce, testament, héritage, actes à la mairie. | Mixte | Rien : commun. |
| Quêtes et énigmes | Quête d'accueil, quête de carrière, énigmes de ville. | Mixte | Énigmes et référents propres. |

## Économie et travail

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Entreprises et commerces | Commerces de joueurs, prix, stocks, ventes. | Serveur | Entreprises et commerces du pays. |
| Droits d'exploiter (Sovarka) | (06/11) Pas de propriété privée : demande à la mairie (`sovarka_demande_deposer`), acceptation par l'autorité municipale (maire, sinon adjoint, sinon `min_fin`), signature chez le notaire (bail `locations_actives` marqué `droitExploiter`, ou `entreprises.proprietaire` pour un commerce PNJ), cession enregistrée par le notaire, retour à l'État au décès (`succession_ouvrir`) ou par le juge ; immeubles collectifs bâtis par la mairie sur ses terrains (`sovarka_urbanisme_passe`, tâche de minuit). Tables `sovarka_*`. | Serveur | Locaux, terrains et régime de propriété du pays. |
| Usines et chaînes | Production, matières, directeurs, ventes directes. | Serveur | Usines et chaînes du pays. |
| Entrepôts et ressources | Stocks régionaux, prix, matières premières. Trading (03/11) : ordinateur + box installés dans un bureau (`equipements_installes`), cours et achat à distance pour une organisation économique, livraison en caisse de fret au port de PSM (`GAME-DESIGN-TRADING.md`). Clé pays + ville depuis le 04/11 (`entrepots_par_ville.pays`) : un entrepôt d'un autre pays ne se confond plus avec celui de Républia ; commande entre entrepôts du même pays seulement. | Serveur | Une ligne `entrepots_par_ville` (pays, ville, bâtiment) et `ENTREPOT_PAR_PAYS_VILLE` à l'écran. Reste à faire : approvisionnement nocturne propre au pays (la passe de minuit `ENTREPOTS_VILLES` ne nourrit que Républia), son port, son directeur PNJ dans la cascade. |
| Serrures et clés | Quincaillerie des armureries (04/11, #434) : serrure à clé (2 métal + 1 PA = 2, 60 FR en PNJ) et clé vierge (1 métal + 1 PA = 10) dans `recettes_commerce` source `quincaillerie`, hors circuit des armes. Table `serrures` : pose sur un local dont on a la jouissance, sur l'entrée d'un bâtiment dont on a l'intégralité de la jouissance (`batiment_jouissance_integrale_interne`) ou sur une armoire à souvenirs installée (`equipements_installes`), fermer/ouvrir avec une clé détenue, porte fermée refusée par `navigation_interieure_personnage_interne` à qui n'a pas de clé, doubles illimités (`cle_dupliquer`), destruction au départ du locataire (`serrures_fin_bail_interne`, à l'accès et dans la passe de nuit). | Serveur | Prix et pays autorisés des recettes de quincaillerie. |
| Véhicules personnels | (05/11) Voiture, deux-roues, utilitaire : biens localisés (`vehicules`), vendus avec une clé (serrure de cible `vehicule`), trajet entre villes reliées d'un même pays (`routes_vehicules`) pour le groupe du conducteur, 1 PA par occupant, carburant en bidons (pile `carburant`), cargaison, révision tous les 10 trajets, panne tirée par le serveur et dépannage vers un garage. Porte unique `vehicule_acte`, lecture `vehicules_lire`. Fabrication au garage (06/11) : 5, 10 ou 15 jours, un véhicule à la fois, main-d'œuvre du jour par les PJ (payée par la caisse du garage) sinon par les PNJ à minuit (`garage_fabrications_avancer_jour`). Garage PNJ de Novomirsk et station PNJ de Krasnov (exemples). Règles : `GAME-DESIGN-VEHICULES.md`. | Serveur | Ses routes dans `routes_vehicules` ; garages et stations ouverts par les PJ. |
| Salon de coiffure | (06/11) Prestation « coupe » de toute entreprise qui déclare `prestations.coupe` : `salon_coupe` (+5 POP, CHA +1 jusqu'à minuit par effet actif `coupe_cha`, une coupe tous les 3 jours de jeu, table `salon_coupes`), encaissement commun des prestations. Salon PNJ de Novomirsk ; prix de Sovarka à décider. `GAME-DESIGN-SALON-COIFFURE.md`. | Serveur | Salons du pays. |
| Port et fret | Bateau, colis, box, douane, criée, marchandises non réclamées (achat d'un lot encore décidé par l'écran). | Mixte | Ports et routes. |
| Bureau de l'Emploi | Postes à pourvoir, annonces, référentes. | Serveur | Agences et référentes. |
| Chantiers | Travail à l'heure, taux du propriétaire, ouvriers PNJ. | Serveur | Rien : commun. |

## Argent

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Banques | Comptes, virements simples et automatiques. | Serveur | Banques du pays. |
| Prêts | Prêts bancaires, mensualités, saisies. | Mixte | Banques et taux. |
| Fiscalité | Taxes locales et nationales, recettes, répartition. | Mixte | Déclarer le circuit national de l'empire. |
| Budgets publics | Budgets nationaux, municipaux, des clubs. | Mixte | Institutions et répartitions. |

## Territoire

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Terrains et construction | Achat, permis, chantier, réception, occupation. | Serveur | Terrains par ville. |
| Locations et logements | Baux, loyers, logement social. | Mixte | Parc de logements. |

## Pouvoir

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Postes et nominations | Candidatures, nomination, protection de 7 jours, révocation. | Serveur | Postes du pays et leurs recruteurs. |
| Élections | Cycles, candidatures, votes, fraudes, contestation (tout par le serveur depuis le 27/10). | Serveur | Calendrier, postes électifs. |
| Assemblée nationale | Sièges, lois, séances, votes. | Serveur | Sièges et calendrier ; fermée sans eux. |
| Gouvernement et présidence | Ministères, décrets, mesures d'exception, vote de confiance (par le serveur depuis le 27/10), banquets. | Mixte | Ministères, palais. |

## Justice et ordre

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Plaintes et enquêtes | Dépôt, enquête, transmission au tribunal. | Mixte | Rien : commun. |
| Police | Interception, contrôle, avis de recherche. | Mixte | Commissariats, profils de policiers. |
| Tribunal et greffe | Procès, juges, avocats, témoins, casier, archives. | Serveur | Tribunaux. |
| Prison et QHS | Détention, évasion, codétenus, haute sécurité. | Mixte | Établissements pénitentiaires. |
| Grâce | Recommandation du ministre, décision du président. | Mixte | Rien : commun. |

## Crime

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Actes illégaux | Vol, neutralisation, empoisonnement, incendie, explosifs, falsification, contrebande (jet, effets, détection et découverte de nuit par le serveur depuis le 27/10 ; « Se cacher » au serveur depuis le 05/11, cachette exigée par l'empoisonnement ; restent à l'écran la neutralisation d'un député, tracts calomnieux et fausse rumeur). Achat de poisons et contrebande : seulement dans les ports des autres empires. Dissuasion (03/11, #135) : hommes armés présents (agents privés hors ceux de l'auteur, soldats en mission `securiser`, Garde républicaine) → malus min(40, 10 + hommes) au jet de réussite et au taux de détection, par `securite_malus_lieu_interne`. Agence de sécurité d'un PJ (03/11) : commerce servant de guichet au socle d'embauche des agences, vivier par ville (`pnj_employeurs.vivier`), frais à la caisse du commerce. | Mixte | Objets et lieux du marché noir. |
| Corruption | Douaniers, fonctionnaires, presse, greffe (douanier et fonctionnaires par le serveur depuis le 27/10). | Mixte | Rien : commun. |
| Organisations criminelles | Mise en relation, recrutement. | Serveur | Organisations du pays. |

## Armée

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Carrière militaire | Grades, unités, engagement, solde, désertion. | Serveur | Grades et unités. |
| Opérations | Soldats postés = renforts policiers en paix, sans mission choisie (GAME-DESIGN-ARMEE.md, 03/11), combats, armurerie, ravitaillement, effort de guerre. | Serveur | Matériel et casernes. |

## Presse et opinion

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Journal et rédaction | Journal du matin généré, articles, petites annonces, étouffement. | Mixte | Titres de presse du pays. |
| Communication officielle | Tribunes, conférences de presse, propagande. | Serveur | Tribunes et salles. |
| Rumeurs et scandales | Rumeurs, calomnies, scandales, démentis (démenti, rumeurs politiques, « lancer une rumeur » et scandale de la nuit par le serveur depuis le 27/10). | Mixte | Scandales types (table `scandales_predefinis`). |

## Organisations

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Organisations | Cinq types, grades, adhésion, puissance. | Mixte | Grades par empire. |
| Grèves et manifestations | Grèves ordinaires et générales, manifestations, répression. | Mixte | Rien : commun. |
| Blocus syndical | SG et Adjoint bloquent un bâtiment (première pièce seulement, ordres du bâtiment refusés) ; renouvellement à distance ; dispersion ou répression par le commissaire depuis son bureau ; levée et malus du maire la nuit. | Serveur (`blocus_syndical_*`, `blocus_nuit_*`, 02/11/2026) | Régénérer `blocus_ordres_batiments` (`outils/generateurs/generer_blocus_ordres_batiments.py`) avec les bâtiments de l'empire. |

## Foi

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Cultes | Prière, dons, confession, pèlerinage, reliques ; excommunication par le Grand Prêtre. La bénédiction n'a pas de bouton dans les lieux de culte (seulement par un contact). | Mixte (prière, don, piété, grades et charges par le serveur depuis le 27/10 pour Républia) | Religion d'État et lieux de culte. |

## Sport

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Football | Clubs, licences, entraînements, matchs en direct, championnat, transferts, supporters. | Mixte | Clubs et stades. |

## Renseignement et social

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Renseignement | Informateurs (loge, hôtel, bar ; tenus par le serveur depuis le 27/10, interroger coûte 1 PA), cellules de renseignement à l'étranger, renseignement militaire. Bâtiment du socle `siege-renseignement` (05/11, décision de Fred) : accueil, salle des écoutes (« Renseignement militaire »), salle d'interrogatoire ; listé par les empires qui l'utilisent (Sovarka), pas par la Républia. Règle du socle (05/11) : le pays d'un poste est celui du registre `postes_attribues` (grades militaires : leur compagnie), jamais la position du titulaire (`acteur_poste_courant`) ; un ordre de poste se passe dans le pays du poste. | Mixte | Services du pays. |
| Vie sociale | Dîners d'affaires, tournées offertes, escortes, dons d'objets, contacts, débauchage d'employés PNJ. | Mixte | Agences et PNJ. |

## Entre empires

| Mécanique | Comportement décrit en octobre | Autorité décrite en octobre | Pour un nouvel empire |
|---|---|---|---|
| Ambassades | Ouverture, ambassadeur, audience, asile, réception, mécénat. | Serveur | Ambassades et ambassadeurs PNJ. |
| Diplomatie et guerres | Indice Diplomatique, propositions, traités, guerres, trêves. | Serveur | Rien : commun. |
| Voyage entre empires | N'existe pas encore. | À créer | À créer une seule fois, pour tous. |

## Mise à jour exigée
Chaque ligne doit être reliée au catalogue d'ordres vivant, à ses fonctions, à ses tests et à une recette, avant de recevoir un état actuel. Ne pas convertir les affirmations historiques de l'architecture en preuve de jouabilité.
