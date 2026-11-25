# Mission du soir — 25/11/2026

Feu vert de Fred donné avec la consigne. Copie de la mission, une case par point ; chaque case est cochée au moment où le
point est poussé. **Reprise** : « Reprends docs/mission-soir-20261125.md au premier point non coché ».

Branche de travail : `claude/soir-20261125` (worktree `~/ResPublica-soir`), issue de main 77ec9c44.

## Étape zéro

- [x] 0.1 Appliquer en production, dans l'ordre, les six migrations de la mission de jour (Fred à l'écran) : 20261125140000
  (guide), 150000 (canicule), 160000 (comptes de test), 170000 (forum du tribunal), 200000 (chronique de l'empire), 300000
  (armoire à souvenirs). Contrôle en lecture de l'en-tête après chacune ; arrêt et explication si un contrôle échoue.
  En-têtes (date d'application), docs/suivi-decisions.md et RELAIS.md à jour.
  → Fait le 25/11 au soir (registre 20261125184058 à 20261125184440) ; les six contrôles donnent le résultat attendu.
- [x] 0.2 Copier cette mission dans docs/mission-soir-20261125.md, une case par point.

## Règles

- Migrations de CETTE mission : écrites sans être appliquées, sauf si Fred est devant l'écran pour valider. Le code fonctionne
  sans elles (repli propre, aucune erreur pour le joueur). Celles qui restent sont listées dans le rapport, dans l'ordre,
  avec leur contrôle.
- Petits blocs, CI verte avant chaque fusion, une ligne par décision dans docs/suivi-decisions.md (décisions de Fred du 25/11
  au soir), RELAIS.md à jour, quota économe. Textes français nouveaux → liste « Pour Codex ». Pas d'arrêt entre les blocs.
  Une vraie question de game design se note dans le rapport, et le travail continue.
- Si la poussée sur main est refusée : branches enchaînées de façon linéaire, ordre donné dans le rapport.

## Bloc 1 — Audit des chances (docs/nuit/AUDIT-CHANCES-20261125.md)

- [x] 1.1 Principe de Fred : pour tous les écarts de l'audit, la description s'aligne sur ce que fait vraiment le serveur,
  sans changer la règle. Les pourcentages écrits en dur disparaissent au profit de « Vos chances réelles : X % ». Les
  conséquences d'un échec sont annoncées telles qu'elles sont. Ordre par ordre, banc de cohérence description / serveur.
- [x] 1.2 Tous les jets encore tirés dans le navigateur passent au serveur, même formule, coût payé dans la même transaction
  que le jet : article favorable, contrer une campagne de presse, demander à parler à la loge, malus ISN fourni par le
  navigateur (corruption de journaliste, fabriquer un scandale), coûts payés à part (filature, mener une enquête), tirage de
  dossier et effets décidés par le navigateur (censure, consulter les dossiers). Bancs.
- [x] 1.3a « Mobiliser les membres » (siège syndical) est envoyé vers l'intervention de police : remettre le bon ordre.
- [x] 1.3b « Écouter les rumeurs » chez la poissonnière de Novomirsk toujours refusé (lieu inconnu du serveur) : déclarer le lieu.
- [x] 1.3c « Inspecter les cargaisons » : variante de Novomirsk probablement refusée (port attendu) ; vérifier et réparer.
- [x] 1.3d « Fuite d'information » : aucun document ne fuite, aucun jet en Sovarka ; aligner la description sur la réalité si
  la fuite de document n'a jamais été décidée, et le noter.
- [x] 1.3e « Falsifier les listes électorales » : un échec coûte 2 jours de détention (décision de Fred), et non 20.
- [x] 1.4a Contrebande au port : chance plafonnée à 85 % ; risque de détection par la douane sur un échec comme sur une
  réussite ; un échec repéré entraîne la saisie de la marchandise et une recherche. Description fidèle. Banc.
- [x] 1.4b Truquer le dépouillement : un échec coûte 3 jours de détention (au lieu de 20). Bourrer les urnes reste à 1 jour.
- [x] 1.4c Évasion de prison : règle du serveur gardée (chances selon DUP et ISN ; échec +1 jour, 2 en Sovarka, et 500) ; la
  description l'annonce.
- [x] 1.4d Rébellion en prison : règle du serveur gardée (chances selon VOL et la force du codétenu ; échec −15 DIS et
  +4 jours, ni transfert ni grilles endommagées) ; la description l'annonce.
- [x] 1.4e Visiter un prisonnier : sans jet, contrôlé par le serveur. Le prisonnier doit être détenu dans cette prison ; une
  visite par jour et par prisonnier ; au quartier de haute sécurité, seuls l'avocat et la famille déclarée entrent. La
  visite ouvre une conversation privée avec le détenu. Banc.
- [x] 1.4f Voler du matériel de chantier : vrai vol, le serveur a raison. La description cesse de parler de « mise en scène
  parodique » et de 0 % ; elle annonce les vraies chances, les risques, et précise qu'un agent de sécurité posté sur le
  chantier le protège.

## Bloc 2 — PNJ guide

- [x] 2.1 Correspondance carrière → goût (guide_carrieres_criteres) validée par Fred telle que proposée : armée et
  renseignement → uniforme ; affaires et médecin → affaires ; magistrat et ouvrier → politique ; presse et clergé →
  influence ; criminel → crime ; escort → belle vie ; enfant et sans expérience → pistes générales. Rien à changer : le
  noter dans le suivi.

## Bloc 3 — Souvenirs et frontières fermées

- [x] 3.1 Souvenirs des six villes ouvertes (Luthécia, Montrouge, Port-Sainte-Marie, Novomirsk, Starovka, Krasnov) : chaque
  souvenir des listes devient un objet du jeu, acheté SUR PLACE auprès d'un PNJ existant, dans un lieu de sa ville cohérent
  avec l'objet (boutique de musée, kiosque, marché, gare…), dont l'image montre un comptoir ou un étal. Le jeu n'indique
  JAMAIS où trouver un souvenir (aucune aide, aucun PNJ référent). Un souvenir se revend librement entre joueurs. Les cartes
  postales listées sont les cartes postales existantes (légendes validées) : elles gardent leur fonctionnement et remplissent
  aussi leur emplacement dans une armoire dont la liste les demande. Banc.
- [x] 3.2 Listes 2, 3 et 4 en base, telles que validées par Fred (provisoires, relecture le 12/12) ; armoires fabriquées : une
  des quatre listes au hasard ; souvenirs des six villes des empires fermés : objets existants, achetables nulle part avant
  l'ouverture.
  - Liste 2 : Luthécia tampon encreur officiel « Approuvé — en trois exemplaires » ; Montrouge carte postale « Montrouge,
    place du Rail — ici, même les statues sont à l'heure » ; Port-Sainte-Marie bocal de sel des marais ; Novomirsk ticket n° 1
    de la file d'attente de la Distribution Collective, encadré ; Starovka bonnet en laine de renne de la ferme ; Krasnov guide
    des baies sauvages (objet existant de l'énigme de Krasnov, réutilisé s'il existe) ; Ciudad Roja maracas rouges du
    carnaval ; Puerto Negro mignonnette de rhum « Puerto Negro » ; Villa Sangre bougie votive peinte ; Al Madina sachet
    d'épices du souk ; Oasis City flacon de sable de l'oasis ; Al-Petrol porte-clés en forme de derrick doré.
  - Liste 3 : Luthécia carte postale « Luthécia — la liberté, en trois exemplaires et dûment tamponnée » ; Montrouge sifflet
    de chef de gare du musée du Rail ; Port-Sainte-Marie carte postale « Port-Sainte-Marie, sous la protection de Notre-Dame
    de la Mer » ; Novomirsk médaille commémorative du Tractorisme ; Starovka carte postale « Starovka — ici, la chaleur est
    dans les cœurs » ; Krasnov casque miniature de fondeur des hauts-fourneaux ; Ciudad Roja foulard rouge brodé ; Puerto
    Negro dé en os des tripots du port ; Villa Sangre statuette du saint protecteur de la ville ; Al Madina théière miniature
    ciselée ; Oasis City datte en sucre dans sa boîte dorée ; Al-Petrol fiole décorative scellée « pétrole brut ».
  - Liste 4 : Luthécia formulaire vierge de la Liberté, encadré ; Montrouge carte postale « Bons baisers de Montrouge, la
    ville qui ne déraille jamais » ; Port-Sainte-Marie bouée miniature « Port-Sainte-Marie » ; Novomirsk exemplaire relié de
    La Voix de Sovarka ; Starovka bois de renne sculpté ; Krasnov pendentif « L'ours ne se chasse pas » (fausse griffe
    d'ours) ; Ciudad Roja affiche du carnaval ; Puerto Negro boussole de contrebandier ; Villa Sangre chapelet de perles
    noires ; Al Madina babouches brodées miniatures ; Oasis City chameau en peluche « Oasis City » ; Al-Petrol casque de
    chantier pétrolier dédicacé.
- [x] 3.3 Frontières des empires fermés : tout voyage vers Ciudad Roja, Puerto Negro, Villa Sangre, Al Madina, Oasis City ou
  Al-Petrol refusé par le serveur, message « Frontière fermée, ouverture au premier trimestre 2027 ». La fenêtre de l'armoire
  explique sous les emplacements de ces villes : « Cette ville ouvrira ses portes au premier trimestre 2027. » Banc.

## Bloc 4 — Premium : le socle (décisions de Fred du 25/11 au soir)

Principes : jamais de pay-to-win, mêmes statistiques en gratuit et en premium.

- [x] 4.1 Modèle : options achetées une fois et durables (commerce premium : 3 familles et 10 articles au lieu de 2 et 4 ;
  bureau à 6 emplacements ; personnalisation du local ou du bâtiment privé ; publicités de joueurs) ; chaque renouvellement
  d'image (décor du local, enseigne, relooking, portrait…) payé à l'unité ; abonnement mensuel = toutes les options sans les
  acheter + UN renouvellement d'image par semaine, non cumulable, au-delà payé à l'unité ; tout en euros, achat par achat,
  aucune monnaie intermédiaire ; aucun prix fixé : tous les prix sont des réglages MJ, sans valeur par défaut affichée tant
  que Fred ne les a pas fixés ; retirer les « futurs tarifs » écrits en dur (4,99 € et 7,99 €).
- [x] 4.2 Droits côté serveur : tables d'abonnement, d'achats et de droits ; RPC de lecture des droits du joueur ; chaque
  option vérifie le droit au serveur ; compteur hebdomadaire de renouvellements. Pendant la bêta, tout reste gratuit (droits
  accordés à tous).
- [x] 4.3a Publicité des annonceurs extérieurs : une seule par jour, au moment de « Dormir », pour les joueurs gratuits
  seulement (jamais pour les abonnés). Emplacement prêt (fenêtre, compteur quotidien, réglage MJ pour l'activer) ; aucune
  régie branchée : sans annonce, rien ne s'affiche.
- [x] 4.3b Publicités de joueurs (option premium) : pop-up publicitaire en ville, réclame avant le film du cinéma de
  Montrouge, annonce dans les journaux. Repartir de plateau-publicite-premium.js. Jeu de rôle : la publicité vante un
  commerce ou une cause du joueur, dans le ton de l'univers.
- [x] 4.4 Paiement : revendeur qui vend en son nom et gère la TVA de tous les pays (Paddle, Lemon Squeezy ou équivalent ;
  retirer les mentions de Stripe). Interface de paiement côté serveur, prête à être branchée en mode test, avec un faux
  fournisseur pour les bancs. Rapport : fournisseur recommandé et ce que Fred doit faire (cinq lignes). Aucun achat sous 2 € :
  bloquer un prix MJ inférieur.
- [x] 4.5 Remise à zéro du 19/12 : préparer (sans l'exécuter) la procédure qui remet le jeu à zéro le jour du lancement, et
  l'offre ponctuelle des testeurs de la bêta (personnalisation d'un commerce, une annonce dans la presse, une publicité dans
  la rue) à accorder aux comptes de la bêta après la remise à zéro ; comptes de test exclus. Procédure documentée dans
  docs/ ; Fred décide du moment.
- [x] 4.6 Hors mission, à ne pas coder : reportage hebdomadaire, film mensuel au cinéma de Montrouge, portrait par IA,
  mini-jeux (forme à trancher avec Fred). → rien à faire ; noté.

## Fin de mission

- [ ] CI verte, toutes les cases cochées.
- [ ] Rapport court en français : 1) ce qui est en ligne ; 2) migrations à valider, dans l'ordre, avec leur contrôle ;
  3) fournisseur de paiement recommandé et ce que Fred doit faire ; 4) ce qui reste en attente, et pourquoi ; 5) questions de
  game design, une par ligne.
