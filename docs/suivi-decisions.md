# Suivi des décisions de Fred

## But

Ce tableau suit chaque décision de game design de Fred, de la décision à la mise en ligne. Il sert à produire
**chaque soir trois listes** (script `outils/suivi/listes-du-soir.py`) :

1. **décidé aujourd'hui** (colonne Date = ce jour) ;
2. **en ligne aujourd'hui** (colonne En ligne le = ce jour) ;
3. **encore en attente** (état différent de « en ligne », toutes dates confondues).

## Règle de mise à jour

- **À chaque bloc de chaque mission, l'agent ajoute ou modifie au moins une ligne** : nouvelle décision → ligne
  `décidé` ; code poussé sur une branche ou migration écrite non appliquée → `en cours` ; présent dans `origin/main` ET,
  si la décision touche la base, migration réellement appliquée en production (registre
  `supabase_migrations.schema_migrations`) → `en ligne`.
- Colonnes : `Date` (date de la décision, JJ/MM/AAAA) ; `Décision` (une phrase) ; `État` (`décidé`, `en cours`,
  `en ligne`) ; `En ligne le` (date du passage à « en ligne », JJ/MM/AAAA, vide sinon) ; `Commit` (sha court sur `main`
  qui la met en ligne, vide si pas en ligne) ; `Source` (document de game design, fichier et point ou section).
- On ne coche jamais « en ligne » d'après un rapport : on le vérifie dans le code de `origin/main` (git log -S, grep) et,
  pour la base, dans le registre des migrations (lecture seule).
- Une ligne par décision distincte ; les micro-détails d'un même point sont regroupés. Une décision remplacée par une
  plus récente garde sa ligne, avec la mention « remplacée le … ».
- Le banc `outils/bancs/test-suivi-decisions.mjs` vérifie le format du tableau.

Rempli rétroactivement le 24/11/2026 (décisions depuis le 01/11/2026), vérifié sur `origin/main` au commit `0d1a9fc9`
et sur le registre de production jusqu'à `20261123222538 renommages_pnj_finale`.

## Tableau

| Date | Décision | État | En ligne le | Commit | Source |
|---|---|---|---|---|---|
| 01/11/2026 | Les ordres qui attendent le voyage entre empires restent visibles, grisés, « Bientôt disponible ». | en ligne | 01/11/2026 | 9ce70b64 | GAME-DESIGN-AMBASSADES.md, « Décidé le 01/11/2026 » |
| 01/11/2026 | Transfert de joueur de football : prix du transfert au club de départ et prime de signature, tous deux payés par le club recruteur. | en ligne | 01/11/2026 | 8fdaaf51 | GAME-DESIGN-FOOTBALL.md, « Transferts de joueurs » |
| 01/11/2026 | Hôpital : pas de sortie avant 20 PA ; à partir de J3 le Dormir rend 12 PA. | en ligne | 01/11/2026 | 27b9bf56 | GAME-DESIGN-HOSPITALISATION.md, « Condition de sortie » |
| 01/11/2026 | Manifestation spontanée : groupe d'au moins 10 PJ, chef seul, une par jour et par ville, participants hors-la-loi. | en ligne | 01/11/2026 | 9aa87fa5 | GAME-DESIGN-MANIFESTATIONS.md, « Règles » |
| 01/11/2026 | Loyer quotidien entre fonds et murs, non appliqué quand le fonds est tenu par un PNJ. | en ligne | 01/11/2026 | bd4e834a | GAME-DESIGN-FONDS-MURS.md, « Loyer entre murs et fonds » |
| 01/11/2026 | Serrure à clé : article de quincaillerie (2 métal + 1 PA = 2 serrures, 60 FR), détruite au départ du locataire, clés vierges et doubles. | en ligne | 04/11/2026 | 06657545 | GAME-DESIGN-SERRURES.md, 01/11 |
| 01/11/2026 | Agences de sécurité privée ouvertes par les PJ (pas de Grobras en province), vivier local commun. | en ligne | 03/11/2026 | 6b556b98 | GAME-DESIGN-SECURITE-PRIVEE-135.md, points 11 à 14 |
| 02/11/2026 | Blocus syndical : organisé par le Secrétaire général ou son adjoint, au moins 2 participants, première pièce seule accessible. | en ligne | 02/11/2026 | bf2680b3 | GAME-DESIGN-BLOCUS.md, décisions du 02/11 |
| 02/11/2026 | Drogues : consommer est légal, acheter et transporter est illégal ; aucune drogue réelle nommée. | en ligne | 02/11/2026 | 9e340dba | GAME-DESIGN-DROGUES.md |
| 02/11/2026 | Fraude électorale valable pour son seul tour ; une contestation qui révèle une fraude impose le recompte. | en ligne | 03/11/2026 | 0d9b4907 | GAME-DESIGN-ELECTIONS.md, décisions du 02/11 |
| 03/11/2026 | Soldats postés en temps de paix = renforts policiers ; plus d'ordre de mission. | en ligne | 03/11/2026 | a746549e | GAME-DESIGN-ARMEE.md, « Mission des soldats » |
| 03/11/2026 | Dissuasion des hommes armés : malus min(40, 10 + hommes), moins de réussite et plus de repérage. | en ligne | 03/11/2026 | e3729066 | GAME-DESIGN-SECURITE-PRIVEE-135.md, points 8 à 10 |
| 03/11/2026 | Trading de matières premières depuis son bureau (cours 0 PA, achat 1 PA), offres d'achat 7 jours, 48 h pour désinstaller après perte du bail. | en ligne | 03/11/2026 | bc91a71c | GAME-DESIGN-TRADING.md, décisions du 03/11 |
| 03/11/2026 | Pas de compte premium mais des options : bureau à 3 emplacements gratuits, 6 en option, gratuite pendant la bêta. | en ligne | 03/11/2026 | a6d6fb71 | GAME-DESIGN-TRADING.md, points 17 à 19 |
| 03/11/2026 | Forums : le forum local est celui de la ville où se trouve le PJ, cloisonné par pays. | en ligne | 04/11/2026 | e2574784 | GAME-DESIGN-FORUMS.md |
| 03/11/2026 | Objectifs secrets : +2 INF par lot nouvellement accompli ; anathème : la cible perd 15 Moral et 10 POP. | en ligne | 03/11/2026 | 4c657b53 | GAME-DESIGN-JAUGES-379.md |
| 04/11/2026 | Livraison terrestre nationale du trading (camion ou train vers l'entrepôt choisi). | en ligne | 04/11/2026 | 140ebafd | GAME-DESIGN-TRADING.md, point 11 |
| 04/11/2026 | Douanes : poste à l'aéroport de Luthécia, amende double sur le non-déclaré due sur la caisse, une caisse sur trois inspectée. | en ligne | 04/11/2026 | 2bd2fc6d | GAME-DESIGN-DOUANES.md, décisions du 04/11 |
| 04/11/2026 | Fenêtre de confirmation obligatoire avant un ordre qui laisserait à 0 PA. | en ligne | 04/11/2026 | 36ccb402 | GAME-DESIGN-HOSPITALISATION.md, « Avertissement avant 0 PA » |
| 04/11/2026 | Serrure posée : fermer et ouvrir avec une clé, cadenas affiché, armoire à souvenirs installable, clé vierge 14 FR par lot de 10. | en ligne | 04/11/2026 | 8a721f35 | GAME-DESIGN-SERRURES.md, décisions du 04/11 |
| 04/11/2026 | Chantier naval de Port-Sainte-Marie : bateaux 3 et 5 places (90 000 / 150 000 FR), 7 et 10 jours, 35 % d'acompte. | en ligne | 04/11/2026 | dcf1dff9 | GAME-DESIGN-CHANTIER-NAVAL.md |
| 04/11/2026 | Entrepôts : le pays fait partie de la clé. | en ligne | 05/11/2026 | c77aea34 | GAME-DESIGN-NOVOMIRSK.md, « Entrepôts : le pays dans la clé » |
| 05/11/2026 | Entrepôt logistique de Krasnov (Fiodor Kolkhozov) et achat international via les ports. | en ligne | 05/11/2026 | 2fe8ed42 | GAME-DESIGN-TRADING.md, points 20 à 23 |
| 06/11/2026 | Les trois villes de Sovarka au trading, port industriel de Starovka en service. | en ligne | 06/11/2026 | 25cd49c6 | GAME-DESIGN-TRADING.md, point 24 |
| 06/11/2026 | Fabrication de véhicules au garage : voiture 10 j, utilitaire 15 j, deux-roues 5 j, main-d'œuvre PJ ou PNJ. | en ligne | 06/11/2026 | 49b8cf2d | GAME-DESIGN-VEHICULES.md, « Fabrication au garage » |
| 06/11/2026 | Salon de coiffure de Novomirsk : coupe à 20 PSK avec bonus de CHA. | en ligne | 06/11/2026 | 1fee3710 | GAME-DESIGN-SALON-COIFFURE.md |
| 06/11/2026 | Commerce premium gratuit pendant la bêta. | en ligne | 06/11/2026 | 074eb426 | GAME-DESIGN-NOVOMIRSK.md, « Commerce Premium gratuit » |
| 06/11/2026 | Galeries de Novomirsk : plafonds de loyer ; marges des commerces de Sovarka. | en ligne | 06/11/2026 | f0460e87 | GAME-DESIGN-NOVOMIRSK.md, « Galeries » et « Marges » |
| 07/11/2026 | Centre d'affaires de Novomirsk : bureaux en location. | en ligne | 07/11/2026 | 6a6902fb | GAME-DESIGN-NOVOMIRSK.md, « Centre d'affaires de Novomirsk » |
| 07/11/2026 | Organisation du pouvoir et partis de Sovarka (salaires, candidatures, gloire des partis, députés désignés). | en ligne | 07/11/2026 | c5776cf9 | GAME-DESIGN-NOVOMIRSK.md, « Organisation du pouvoir » et « Partis » |
| 07/11/2026 | Dotation initiale des entrepôts de province. | en ligne | 07/11/2026 | 81477477 | GAME-DESIGN-NOVOMIRSK.md / ARCHITECTURE.md, 07/11 |
| 08/11/2026 | Palais présidentiel, greffe du Tribunal populaire et justice de Sovarka sans procureur. | en ligne | 09/11/2026 | a8bd5e26 | GAME-DESIGN-NOVOMIRSK.md, sections du 08/11 |
| 10/11/2026 | Règle des prix et tarifs nationaux de Sovarka. | en ligne | 10/11/2026 | 81fd5c9c | GAME-DESIGN-NOVOMIRSK.md, « Règle des prix en Sovarka » |
| 10/11/2026 | Fermes, distillerie, fourreur et forêt profonde de Krasnov (créatures, seconde coupe). | en ligne | 10/11/2026 | dda8063a | GAME-DESIGN-NOVOMIRSK.md, « Fermes » et « Forêt profonde » |
| 10/11/2026 | Cartes des restaurants de Sovarka et marché de Krasnov. | en ligne | 10/11/2026 | dd224f6b | GAME-DESIGN-NOVOMIRSK.md, « Cartes des restaurants », « Marché de Krasnov » |
| 10/11/2026 | Caméras : une pièce ou une vue de rue, rapport des passages et des actes visibles, Couinator. | en ligne | 11/11/2026 | 09beabb7 | GAME-DESIGN-EQUIPEMENTS.md, « Décisions du 10 novembre » |
| 11/11/2026 | L'onglet « Règles » devient « Aide », avec un conseiller HRP en premier écran. | en ligne | 11/11/2026 | 48682eb7 | GAME-DESIGN-AIDE.md |
| 11/11/2026 | Au plus 12 fonctions serveur Vercel (l'aide passe par /api/chat). | en ligne | 11/11/2026 | 782eacd6 | AGENTS.md, « Fonctions serveur Vercel » |
| 11/11/2026 | Pavillon des Ambassadeurs : baux institutionnels, accès réservé aux dignitaires, portraits tirés des images. | en ligne | 12/11/2026 | f635c946 | GAME-DESIGN-NOVOMIRSK.md, sections du 11/11 |
| 11/11/2026 | Musée national de Novomirsk : textes des salles et questions libres au guide. | en ligne | 11/11/2026 | 166cab12 | GAME-DESIGN-NOVOMIRSK.md, « Guide du Musée de la République » |
| 11/11/2026 | Salle des expositions tournantes : contenu à venir (pas de feu vert de codage). | décidé |  |  | GAME-DESIGN-NOVOMIRSK.md, « Salle des expositions tournantes » |
| 12/11/2026 | Service d'étage, escorts et espionnage au Pavillon et à la Résidence. | en ligne | 12/11/2026 | 360e859c | GAME-DESIGN-NOVOMIRSK.md, « Pavillon et Résidence » |
| 12/11/2026 | Musée municipal de Novomirsk et énigme du trésor des Tsars. | en ligne | 12/11/2026 | c0d99602 | GAME-DESIGN-NOVOMIRSK.md, « Musée municipal » |
| 12/11/2026 | Appartements populaires : +1 PA au sommeil, option premium, colocation, époux. | en ligne | 13/11/2026 | b100b2ef | GAME-DESIGN-APPARTEMENTS.md |
| 13/11/2026 | Musée de Luthécia : Valérie Loisillon met sur la voie au départ de l'enquête, le coupable se tait. | en ligne | 13/11/2026 | 68275b00 | GAME-DESIGN-ENIGME-MUSEE-LUTHECIA.md, « Départ lisible » |
| 13/11/2026 | Soins sans trace en clinique : aucun dossier ni fuite vers la presse. | en ligne | 13/11/2026 | f74e57bb | GAME-DESIGN-HOSPITALISATION.md, « Soins sans trace » |
| 13/11/2026 | Chambre dans les hôpitaux publics de Sovarka (Dormir, repas de l'hôpital). | en ligne | 13/11/2026 | 517a425a | GAME-DESIGN-HOSPITALISATION.md, « Chambres des hôpitaux de Sovarka » |
| 13/11/2026 | Héros du Travail et boîte aux lettres du Parti. | en ligne | 13/11/2026 | 077b4ce3 | GAME-DESIGN-NOVOMIRSK.md, sections du 13/11 |
| 13/11/2026 | Direction du Renseignement : équipes par empire et par ministère, habilitations, interrogatoire. | en ligne | 13/11/2026 | 67d2a5c1 | GAME-DESIGN-NOVOMIRSK.md, « Direction du Renseignement » |
| 13/11/2026 | Dotation initiale du stock de Novomirsk et cloisonnement national des ministres. | en ligne | 13/11/2026 | d6d2f083 | GAME-DESIGN-NOVOMIRSK.md, « Dotation initiale et cloisonnement » |
| 13/11/2026 | Camion militaire de Novomirsk. | en ligne | 13/11/2026 | b785a65f | GAME-DESIGN-NOVOMIRSK.md, « Camion militaire » |
| 13/11/2026 | Le port de Sovarka nourrit chaque nuit les entrepôts de Sovarka, comme celui de Républia. | en ligne | 15/11/2026 | 2e88566a | GAME-DESIGN-NOVOMIRSK.md, décisions du 13/11 (23 h 44) |
| 14/11/2026 | La confirmation avant 0 PA annonce 2 à 3 jours d'immobilisation (9 langues). | en ligne | 14/11/2026 | 38b69784 | GAME-DESIGN-HOSPITALISATION.md, 14/11 |
| 14/11/2026 | Krasnov : kolkhoze avec caisse, maisonnettes, centre commercial à 4 box de 20 PSK, tabac-presse à 4 articles. | en ligne | 14/11/2026 | 0174e978 | GAME-DESIGN-NOVOMIRSK.md, sections du 14/11 |
| 15/11/2026 | Kouzma (batiouchka) et Praskovia : rôles et histoire d'amour. | en ligne | 15/11/2026 | 2f08c477 | GAME-DESIGN-KRASNOV-KOUZMA-PRASKOVIA.md ; GAME-DESIGN-NOVOMIRSK.md, 15/11 |
| 15/11/2026 | Tour de Starovka : vues de rue, bons d'État au guichet de la mairie, raffinerie à trois salles. | en ligne | 15/11/2026 | b9fced8d | GAME-DESIGN-NOVOMIRSK.md, « Tour de Starovka » ; GAME-DESIGN-STAROVKA-RAFFINERIE.md |
| 15/11/2026 | Production et logistique de Sovarka : usines par pays, production passée, contrats de médicaments. | en ligne | 15/11/2026 | ca4e34a8 | GAME-DESIGN-NOVOMIRSK.md, « Production et logistique » |
| 16/11/2026 | Régulation de la production et de la récolte. | en ligne | 16/11/2026 | 99c6828a | GAME-DESIGN-REGULATION-PRODUCTION.md |
| 16/11/2026 | Lancement mondial le samedi 19/12/2026, 9 langues, une seule horloge (Paris), gel de l'étendue. | décidé |  |  | GAME-DESIGN-LANCEMENT.md, points 1 à 10 |
| 16/11/2026 | Tout texte écrit par un joueur est traduit automatiquement pour tous, avec « voir l'original » (couverture complète à vérifier). | en cours |  |  | GAME-DESIGN-LANCEMENT.md, point 7 |
| 16/11/2026 | Premium payant dès l'ouverture, toutes les options si possible (grille de prix non décidée). | décidé |  |  | GAME-DESIGN-LANCEMENT.md, points 12 et 13 |
| 16/11/2026 | Goulag de Sovarka : quatre arbitrages, traversée de la toundra et cinq pièces ; installé verrouillé. | en ligne | 21/11/2026 | b514b1be | GAME-DESIGN-GOULAG-SOVARKA.md |
| 17/11/2026 | Goulag : ordres internes des cinq pièces (installés, goulag verrouillé). | en ligne | 21/11/2026 | b514b1be | GAME-DESIGN-GOULAG-SOVARKA-ORDRES-INTERNES.md |
| 17/11/2026 | Pas de débat de politique réelle hors jeu ; réponse aux abus par un contre-pouvoir. | décidé |  |  | GAME-DESIGN-LANCEMENT.md, points 15 et 16 |
| 17/11/2026 | Compte confirmé et quota IA (audit des failles du 16/11). | en ligne | 17/11/2026 | f0f8d268 | GAME-DESIGN-LANCEMENT.md, point 14 |
| 17/11/2026 | Starovka : identité bouriate des personnages, sans centre commercial, local de chasse. | en ligne | 17/11/2026 | 749c2759 | GAME-DESIGN-STAROVKA-BOURIATES.md |
| 18/11/2026 | Nationalité et domicile ne changent plus en voyage ; élections et forums selon la nationalité. | en ligne | 18/11/2026 | 1f1828ad | GAME-DESIGN-ELECTIONS.md, « Nationalité, domicile et élections » |
| 18/11/2026 | Investiture gratuite, naturalisation acceptée faute de réponse, forum local du domicile lisible à l'étranger. | en ligne | 18/11/2026 | ef437719 | GAME-DESIGN-ELECTIONS.md, « Compléments de Fred » |
| 18/11/2026 | Départ d'un maire : l'adjoint a 72 h pour accepter, sinon tutelle du ministre. | en ligne | 18/11/2026 | ef437719 | GAME-DESIGN-ELECTIONS.md, « Départ d'un maire » |
| 18/11/2026 | PNJ de Starovka : personnalités, référents, train, syndicat national et kolkhoze. | en ligne | 18/11/2026 | 9081f76a | GAME-DESIGN-NOVOMIRSK.md, « PNJ de Starovka » et « Décisions du 18/11 » |
| 18/11/2026 | Maladies : socle, nom du médicament, boissons. | en ligne | 18/11/2026 | 4452045d | GAME-DESIGN-MALADIES-CLIMAT.md, lot 1 |
| 18/11/2026 | Aliments : piles datées, contrôle à la réception, bandelettes, plats cuisinés, furet renifleur. | en ligne | 18/11/2026 | 460dc41b | GAME-DESIGN-MALADIES-CLIMAT.md, lot 2 |
| 18/11/2026 | Climat : socle des événements (alerte 48 h, chantiers arrêtés après l'alerte). | en ligne | 18/11/2026 | 0b9f561c | GAME-DESIGN-MALADIES-CLIMAT.md, décisions climat du 18/11 |
| 18/11/2026 | Criminalité : cadre commun des crimes et corruption. | en ligne | 19/11/2026 | f0f5fbb4 | GAME-DESIGN-CRIMINALITE.md, §§ 6 et 12 |
| 19/11/2026 | Blizzard et grippe ; effets du climat ; corrections de Fred. | en ligne | 19/11/2026 | d775fd9f | GAME-DESIGN-MALADIES-CLIMAT.md, lots 4 et 5 |
| 19/11/2026 | État de catastrophe naturelle déclaré par le PM (remplacée le 21/11 puis mise en sommeil le 22/11). | en ligne | 19/11/2026 | a7218507 | GAME-DESIGN-MALADIES-CLIMAT.md, « Décision du 19/11 — catastrophe » |
| 19/11/2026 | Sacs de sable proportionnels (remplacée le 21/11 par un sac par lieu, puis supprimée le 22/11). | en ligne | 19/11/2026 | a7218507 | GAME-DESIGN-MALADIES-CLIMAT.md, « Sacs de sable proportionnels » |
| 19/11/2026 | Criminalité : délits d'information, mise en ordre des peines, carrière criminelle, envoi au QHS (lots 1 à 10). | en ligne | 19/11/2026 | f0f5fbb4 | GAME-DESIGN-CRIMINALITE.md, §§ 13 à 16 |
| 19/11/2026 | Barème commun des informateurs (Républia 20-50 FR, Sovarka 7-20 PSK). | en ligne | 21/11/2026 | e00fd911 | GAME-DESIGN-CRIMINALITE.md, « Barème commun des informateurs » |
| 19/11/2026 | Refonte des informateurs : plus de recrutement, PNJ spécialistes de lieu et généralistes payés au barème. | en ligne | 22/11/2026 | 6d3606de | GAME-DESIGN-INFORMATEURS-20261121.md, points 1 à 6 |
| 20/11/2026 | Criminalité : valeurs provisoires tranchées, marché noir sans bonus, discrétion, groupe masqué sans indice. | en ligne | 20/11/2026 | d7c2e083 | GAME-DESIGN-CRIMINALITE.md, « Décisions du 20/11/2026 » |
| 20/11/2026 | Laissez-passer : mécanisme définitif avec registre. | en ligne | 20/11/2026 | 6df1fef5 | GAME-DESIGN-CRIMINALITE.md, « Laissez-passer » |
| 20/11/2026 | Organisations secrètes (deux options). | en ligne | 20/11/2026 | a0ac251e | GAME-DESIGN-CRIMINALITE.md, § 3 bis |
| 20/11/2026 | Faits divers dans le Journal du jour. | en ligne | 20/11/2026 | 160770d7 | GAME-DESIGN-PRESSE.md, « Faits divers » |
| 20/11/2026 | Compte confirmé exigé pour être candidat, être nommé, créer un parti ou une organisation. | en ligne | 20/11/2026 | 090bf500 | GAME-DESIGN-ELECTIONS.md, « Compte confirmé » |
| 20/11/2026 | Lot de Krasnov 1 : un ours tué donne en plus 10 pots de graisse d'ours. | en ligne | 21/11/2026 | b888d2db | GAME-DESIGN-KRASNOV-LOT-20261120.md, point 1 |
| 20/11/2026 | Lot de Krasnov 2 : marché de Krasnov en fenêtre unique Acheter / Vendre / Produire. | en ligne | 22/11/2026 | 5a1c24e1 | GAME-DESIGN-KRASNOV-LOT-20261120.md, point 2 |
| 20/11/2026 | Lot de Krasnov 3 : un seul objet bouteille d'eau, une fontaine par ville. | en ligne | 22/11/2026 | 5a1c24e1 | GAME-DESIGN-KRASNOV-LOT-20261120.md, point 3 |
| 20/11/2026 | Lot de Krasnov 4 : caisse commune du kolkhoze avec un seul ordre « Donner ». | en ligne | 21/11/2026 | b888d2db | GAME-DESIGN-KRASNOV-LOT-20261120.md, point 4 |
| 20/11/2026 | Lot de Krasnov 5-6 : PNJ et textes du commissariat et du stade Étoile Rouge (Pavel Zapasnoï absent ; textes à réécrire, reportés par Fred). | en cours |  |  | GAME-DESIGN-KRASNOV-LOT-20261120.md, points 5 et 6 |
| 20/11/2026 | Lot de Krasnov 6 : supporters en Sovarka. | en ligne | 21/11/2026 | 1459aea3 | GAME-DESIGN-KRASNOV-LOT-20261120.md, point 6 |
| 20/11/2026 | Lot de Krasnov 7 : école (stage de survie), guide des baies, feuille volante et énigme de Krasnov. | en ligne | 21/11/2026 | c089d5d9 | GAME-DESIGN-KRASNOV-LOT-20261120.md, point 7 |
| 20/11/2026 | Lot de Krasnov 8 : radar, polonium du colonel Voronov, carnet « Contacts et secrets », vol des archives. | en ligne | 21/11/2026 | e00fd911 | GAME-DESIGN-KRASNOV-LOT-20261120.md, point 8 |
| 20/11/2026 | Lot de Krasnov 9 : « Inspecter la pièce », fouiller et débusquer en un ordre, « Désinstaller du matériel », « Se cacher » dans la pièce. | en ligne | 22/11/2026 | 5a1c24e1 | GAME-DESIGN-KRASNOV-LOT-20261120.md, point 9 |
| 20/11/2026 | Lot de Krasnov 10 : rue du commissariat avec drapeau de Sovarka et enseigne « МИЛИЦИЯ ». | en ligne | 21/11/2026 | 06edad46 | GAME-DESIGN-KRASNOV-LOT-20261120.md, point 10 |
| 20/11/2026 | Construction : jamais besoin de recharger, images par étape et par ville, surcouche d'avancement, fenêtre unique « Le chantier ». | en ligne | 21/11/2026 | b7f9c184 | GAME-DESIGN-CHANTIERS-IMAGES-20261120.md, points 1 à 4 |
| 21/11/2026 | Construction : un jour d'avance au plus par jour quand les joueurs font toutes les heures. | en ligne | 21/11/2026 | 2cd23811 | GAME-DESIGN-CHANTIERS-IMAGES-20261120.md, point 5 |
| 21/11/2026 | Terrains à bâtir : plan des lots en vignettes et rue en trois états. | en ligne | 22/11/2026 | 18aeb8e1 | GAME-DESIGN-CHANTIERS-IMAGES-20261120.md, complément du 21/11 |
| 21/11/2026 | Climat : jamais d'entrave aux déplacements, gare jamais inondée, 6 heures, un seul événement à la fois par pays, aucune exemption. | en ligne | 21/11/2026 | 0679b48a | GAME-DESIGN-CLIMAT-20261121.md, points 1 à 5 |
| 21/11/2026 | Climat : pédagogie (pictogrammes, fenêtre de l'alerte, accueil du nouveau personnage, marques expliquées sur la carte) et textes des consignes. | en ligne | 21/11/2026 | 0679b48a | GAME-DESIGN-CLIMAT-20261121.md, points 6 et 7 |
| 21/11/2026 | Climat : parades en vente dans chaque pays (quincaillerie, usines pharmaceutiques, sels à 22 PSK, bidons à Novomirsk). | en ligne | 21/11/2026 | 0679b48a | GAME-DESIGN-CLIMAT-20261121.md, compléments sur les parades |
| 21/11/2026 | Climat : heure de début tirée au hasard, brouillard 1 par mois et par ville. | en ligne | 21/11/2026 | 0679b48a | GAME-DESIGN-CLIMAT-20261121.md, Q1 et Q2 |
| 21/11/2026 | Catastrophe naturelle indemnisant à 50 % et un seul sac de sable par lieu (remplacées le 22/11). | en ligne | 21/11/2026 | 0679b48a | GAME-DESIGN-CLIMAT-20261121.md, Q3 et Q4 |
| 21/11/2026 | Forêt de Krasnov : déplacements sans PA, portique, clairière, retour en deux clics, exploration en groupe. | en ligne | 21/11/2026 | 96b893e3 | GAME-DESIGN-FORET-KRASNOV-20261121.md |
| 21/11/2026 | Fenêtres : une nouvelle fenêtre se place sous la précédente sans la recouvrir. | en ligne | 22/11/2026 | 5f137b44 | GAME-DESIGN-FENETRES-FORUM-20261121.md, § 1 |
| 21/11/2026 | Fenêtres : lâchée en chevauchement, une fenêtre revient à sa place avec l'infobulle « Vos fenêtres ne peuvent pas se superposer » (absente du code). | en cours |  |  | GAME-DESIGN-FENETRES-FORUM-20261121.md, § 1 |
| 21/11/2026 | Bandeau « HUMAN GAMBIT » au lieu de « RES PUBLICA » dans l'interface. | en ligne | 22/11/2026 | 9566f062 | GAME-DESIGN-FENETRES-FORUM-20261121.md, § 2 |
| 21/11/2026 | Forum lisible par un enfant : libellés, « Nouveau sujet », forum vide expliqué, cadenas expliqué, chemin cliquable (chemin non trouvé dans le code). | en cours |  |  | GAME-DESIGN-FENETRES-FORUM-20261121.md, § 3 |
| 21/11/2026 | Interview d'accueil par le journaliste de la ville, toujours publiable, lisible ; fenêtre « Courrier » et compteur corrects. | en ligne | 22/11/2026 | 457b13b2 | GAME-DESIGN-INTERVIEW-ACCUEIL-20261121.md |
| 21/11/2026 | Page d'accueil : « HUMAN GAMBIT OUVRE SA BÊTA. » et paragraphe deux empires, dans toutes les langues. | en ligne | 21/11/2026 | 9242a4e3 | GAME-DESIGN-MISSION-SOIR-20261121.md, urgence 1 à 3 |
| 21/11/2026 | Presse : monde fictif (« sovarkien »), point de vue national, anonymat absolu, noms cliquables. | en ligne | 21/11/2026 | 9d041513 | GAME-DESIGN-MISSION-SOIR-20261121.md, point 1 |
| 21/11/2026 | Forum : blocs empilés sur petit écran, images collées ou glissées copiées dans le stockage du jeu. | en ligne | 22/11/2026 | 40568be5 | GAME-DESIGN-MISSION-SOIR-20261121.md, point 2 ; MISSION-NUIT, point 7 |
| 21/11/2026 | Eau de la place de l'Ours : ordre vert « Puiser de l'eau », 1 PA, 10 bouteilles par tranche de 6 h, bouteille bue sans bouteille vide. | en ligne | 21/11/2026 | c39de4b5 | GAME-DESIGN-MISSION-SOIR-20261121.md, point 3 |
| 21/11/2026 | Types de bâtiments : 7 → 5 (hangar, commerce standard, premium, logement, building), mairie = logements sociaux. | en ligne | 22/11/2026 | edd137e0 | GAME-DESIGN-MISSION-SOIR-20261121.md, point 4 ; MISSION-NUIT, point 6 |
| 21/11/2026 | Images de construction de Port-Sainte-Marie (série complète) et démarrage commun en Républia. | en ligne | 22/11/2026 | 290bdd86 | GAME-DESIGN-MISSION-SOIR-20261121.md, point 5 ; MISSION-NUIT, point 1 |
| 21/11/2026 | Fenêtre « Le chantier » à quatre onglets (État, Stock, Main-d'œuvre, Gestion), jauges en carrés, « Voler des matériaux » remis. | en ligne | 21/11/2026 | c39de4b5 | GAME-DESIGN-MISSION-SOIR-20261121.md, point 6 |
| 21/11/2026 | Groupes en bloc dans « Personnes présentes », mise à jour en direct, cachette de groupe sur un seul jet du chef (−5 par membre). | en ligne | 21/11/2026 | c39de4b5 | GAME-DESIGN-MISSION-SOIR-20261121.md, point 7 |
| 21/11/2026 | Masque de carnaval : masqué reste visible sous « Personnage masqué ». | en ligne | 21/11/2026 | c39de4b5 | GAME-DESIGN-MISSION-SOIR-20261121.md, point 8 |
| 21/11/2026 | Mairie de Krasnov : on n'en sort que dans la rue de la mairie, porte sur cette rue seulement. | en ligne | 21/11/2026 | c39de4b5 | GAME-DESIGN-MISSION-SOIR-20261121.md, point 9 |
| 21/11/2026 | Pause Supabase : aucune migration en production sans feu vert de Fred ; le goulag reste verrouillé. | en ligne | 21/11/2026 | abb6ea44 | AGENTS.md, « Coordination Claude Code / Codex » ; NOVOMIRSK-PNJ-INTERFACE, R11 |
| 22/11/2026 | Chantier : heures du jour toujours ouvertes, commande automatique de nuit à l'entrepôt, journal au lieu du courrier. | en ligne | 22/11/2026 | abe923cd | GAME-DESIGN-MISSION-NUIT-20261122.md, point 2 |
| 22/11/2026 | Images des étapes : fondations par ville, gros œuvre et façade en deux gabarits (images de Montrouge encore à produire). | en ligne | 22/11/2026 | abe923cd | GAME-DESIGN-MISSION-NUIT-20261122.md, point 3 |
| 22/11/2026 | Forêt : égarement 50 %, 15 % de rencontre à l'arrivée dans une vue profonde. | en ligne | 22/11/2026 | abe923cd | GAME-DESIGN-MISSION-NUIT-20261122.md, point 4 |
| 22/11/2026 | Climat : les événements déjà annoncés sont maintenus ; aucune alerte ne couvre une flèche. | en ligne | 22/11/2026 | abe923cd | GAME-DESIGN-MISSION-NUIT-20261122.md, point 5 |
| 22/11/2026 | Place de l'Ours : sortie vers la rue de la mairie à droite ; retour par le côté opposé dans les culs-de-sac de Sovarka. | en ligne | 22/11/2026 | abe923cd | GAME-DESIGN-MISSION-NUIT-20261122.md, point 9 |
| 22/11/2026 | Texte jamais plus petit que le texte courant, dans tout le jeu. | en ligne | 22/11/2026 | 6d3606de | GAME-DESIGN-FORET-TEST-20261122.md, point 1 |
| 22/11/2026 | Inventaire en direct, quantité au dépôt et au ramassage, capacité par personnage (100, réglable), don entre membres d'un groupe. | en ligne | 22/11/2026 | 6d3606de | GAME-DESIGN-FORET-TEST-20261122.md, points 2 à 4 |
| 22/11/2026 | Groupes : un membre ne perd que le déplacement ; butin au chef sans doublement ; rapport à chaque membre. | en ligne | 22/11/2026 | 6d3606de | GAME-DESIGN-FORET-TEST-20261122.md, point 5 |
| 22/11/2026 | Rapport de combat en deux colonnes par round ; meute de trois loups ; suspense en deux fenêtres. | en ligne | 22/11/2026 | 6d3606de | GAME-DESIGN-FORET-TEST-20261122.md, points 6 et 7 |
| 22/11/2026 | Météo dans toutes les vues en plein air ; alerte en bandeau au-dessus de l'image ; bouton « Explorer la forêt » classique. | en ligne | 22/11/2026 | 6d3606de | GAME-DESIGN-FORET-TEST-20261122.md, point 8 ; CLIMAT-20261121, complément du 22/11 |
| 22/11/2026 | Santé : robustesse selon la Santé, 1 Santé par PA perdu, Santé 0 ne bloque plus, coma = 0 PA. | en ligne | 22/11/2026 | 77750497 | GAME-DESIGN-SANTE-20261122.md, points 1 à 3 |
| 22/11/2026 | Santé : maladies (perte à la contraction), MST et antibiotique, escort sans Santé. | en ligne | 22/11/2026 | 77750497 | GAME-DESIGN-SANTE-20261122.md, points 4 à 6 |
| 22/11/2026 | Santé : alcool, sommeil calculé par le serveur, repas, soins, modulation par le Moral. | en ligne | 22/11/2026 | 77750497 | GAME-DESIGN-SANTE-20261122.md, points 7 à 11 |
| 22/11/2026 | Médecin de terrain (Diagnostiquer, Soigner, tarif accepté par le patient) et « Montrer un objet » à 0 PA. | en ligne | 22/11/2026 | 77750497 | GAME-DESIGN-SANTE-20261122.md, points 12 et 22 |
| 22/11/2026 | Une usine pharmaceutique par pays, un ordre « Produire des médicaments », jauges Santé et Moral, « PV » devient « Santé ». | en ligne | 22/11/2026 | 77750497 | GAME-DESIGN-SANTE-20261122.md, points 13 à 15 |
| 22/11/2026 | Vues en plein air sans « Inspecter » ni « Désinstaller » ; nouveaux titres des vues de la forêt ; dernier loup s'enfuit. | en ligne | 22/11/2026 | 77750497 | GAME-DESIGN-SANTE-20261122.md, points 17 à 19 |
| 22/11/2026 | Six fontaines potables sans risque de maladie. | en ligne | 22/11/2026 | 5a1c24e1 | GAME-DESIGN-SANTE-20261122.md, point 20 |
| 22/11/2026 | Suites Santé : « En-cas » / « Zakouski », palier 15+, repas du président, de l'hôpital et de la clinique. | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-SANTE-20261122.md, « Suites », points 1 à 3 |
| 22/11/2026 | Tous les paiements se font en liquide (médecin compris). | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-SANTE-20261122.md, « Suites », point 5 |
| 22/11/2026 | Robustesse appliquée aussi à « se laisser faire », à la répression et à la rébellion. | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-SANTE-20261122.md, « Suites », point 7 |
| 22/11/2026 | Médicaments : matière première, production des PNJ d'usine, caisse d'usine à fonds de roulement, antidote. | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-SANTE-20261122.md, « Suites », point 8 |
| 22/11/2026 | Dons de tracts au plafond commun ; antenne de Starovka « La Voix de Sovarka ». | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-SANTE-20261122.md, « Suites », points 9 et 10 |
| 22/11/2026 | Rachat de tous les marchés à 30 % sous le prix de vente ; confiture 10 PSK ; caisse du marché de Krasnov 1 000 PSK. | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-SANTE-20261122.md, « Suites », point 11 |
| 22/11/2026 | Objectif « Acheter 5 informations à des informateurs différents ». | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-SANTE-20261122.md, « Suites », point 13 |
| 22/11/2026 | Pays d'un poste lu dans le registre, jamais dans la position ; un voyageur garde son poste sans pouvoir sur place. | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, points 15 et 16 ; AGENTS.md |
| 22/11/2026 | Regroupement des ordres : Inspecter à trois volets, Élections et Guichet des mairies, partis, syndicat, « Fonctions de [poste] ». | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, points 17 à 22 |
| 22/11/2026 | Accueil : interview RP à la première connexion (Jodie, Vera Pravdina), six chemins de trois étapes, bulle des PA une seule fois. | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, points 23 à 26 ; AGENTS.md |
| 22/11/2026 | Tabac-presse de Krasnov : papirossy (+2 Moral), carte postale à écrire et envoyer, revue (+1 ENT 24 h). | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, points 27 à 29 |
| 22/11/2026 | Dépôt d'une carte postale ou d'une revue dans l'armoire à souvenirs (non codé). | décidé |  |  | GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, point 28 |
| 22/11/2026 | Crue : arrête seulement les chantiers de la ville une journée ; plus de fermeture, de pertes ni de sacs de sable. | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, point 30 |
| 22/11/2026 | État de catastrophe naturelle en sommeil (retiré de l'interface, réglage MJ), rôle à redéfinir par Fred. | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, point 31 |
| 22/11/2026 | Images de chantier de Luthécia (gros œuvre et façade bas, quatre bâtiments achevés). | en ligne | 22/11/2026 | d8e6d473 | GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, point 33 |
| 23/11/2026 | R4 : rien n'est supprimé sans rediriger tout ce qui l'appelle ; R6 : le PNJ suit l'image ; R9 : crimes et nuit au journal, jamais au courrier. | en ligne | 23/11/2026 | 97fa407b | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, règles générales |
| 23/11/2026 | Point 1 : une seule fiche d'objet réunissant toutes les actions. | en ligne | 23/11/2026 | 15e4fac6 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 1 |
| 23/11/2026 | Points 2-3 : onglet Organisations avec toutes les organisations et leur pays ; fiche Identité avec le pays du PJ, accents. | en ligne | 23/11/2026 | 9924fa5a | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 2 et 3 |
| 23/11/2026 | Point 4 : vérifier le bandeau et les jauges en navigation privée (Tom Tom). | décidé |  |  | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 4 |
| 23/11/2026 | Point 5 : « Taxi vers le QHS » masqué en Sovarka tant que le goulag est verrouillé. | en ligne | 23/11/2026 | 9924fa5a | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 5 |
| 23/11/2026 | Point 6 : tout en liquide, sauf prélèvements automatiques (liquide puis banque). | en ligne | 23/11/2026 | 9924fa5a | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 6 |
| 23/11/2026 | Points 7-9 : excédent des entrepôts reversé à minuit, dotation de plantes des usines, PNJ d'usine non payés. | en ligne | 23/11/2026 | 9924fa5a | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 7 à 9 |
| 23/11/2026 | Points 10-13 : Inspecter à 0 PA, « Voler » chez soi en face du matériel d'autrui, rébellion et répression à 1 PA, ligne desinstaller_materiel retirée. | en ligne | 23/11/2026 | 9924fa5a | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 10 à 13 |
| 23/11/2026 | Point 14 : correction des chemins d'images de Codex appliquée en production. | en ligne | 23/11/2026 | 395a0100 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 14 |
| 23/11/2026 | Point 15 : portrait de Vera Pravdina dans l'interview d'accueil. | en ligne | 23/11/2026 | 9924fa5a | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 15 |
| 23/11/2026 | Points 16-20 : panneau de gauche réordonné, fenêtres Argent et Inventaire, onglets Inventaire et Statistiques supprimés. | en ligne | 23/11/2026 | 15e4fac6 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 16 à 20 |
| 23/11/2026 | Point 17 (écart) : échéance des prêts dans la fenêtre Argent (la table prets n'a pas de date d'échéance). | décidé |  |  | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 20 (état) |
| 23/11/2026 | Points 21-22 : journal sans « Rapports de combat » ni entrées et sorties, croix en vrai bouton ; boutons ronds en bas à droite. | en ligne | 23/11/2026 | d7b02556 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 21 et 22 |
| 23/11/2026 | Point 23 : flèche unique en bas pour la seule rue de l'hôpital de Krasnov, les autres rues gardent l'ancienne disposition (élargie à tort le 23/11, corrigée le 24/11). | en ligne | 24/11/2026 | 94b4ce33 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 23 |
| 23/11/2026 | Point 24 : acheter une information en cliquant sur le PNJ informateur ; l'ordre de pièce disparaît. | en ligne | 23/11/2026 | cfe67fc4 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 24 ; INFORMATEURS-20261121 |
| 23/11/2026 | Point 25 : l'habitué du Bar Sever, PNJ social, offre un verre par jour et vend l'information. | en ligne | 23/11/2026 | cfe67fc4 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 25 |
| 23/11/2026 | Points 26-28 : fiches DeepSeek (Zaitsev, musée, EHPAD, maisons, infirmière Oukolova), Lykov fonctionnaire retraité, Kouzma batiouchka, frères Rybakov. | en ligne | 23/11/2026 | cfe67fc4 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 26 à 28 |
| 23/11/2026 | Point 29 : directeur du musée de Krasnov supprimé, Arkadi reprend l'énigme, « Écouter le guide » dans les cinq salles. | en ligne | 23/11/2026 | 31ba0f4f | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 29 |
| 23/11/2026 | Point 30 : hôpital de Krasnov, salle d'attente pour les visiteurs, chambre pour les hospitalisés, transfert à 0 PA (400 PSK). | en ligne | 23/11/2026 | 31ba0f4f | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 30 ; HOSPITALISATION |
| 23/11/2026 | Point 30 (suite) : même séparation salle d'attente et chambre dans les autres hôpitaux (seul Krasnov est fait). | décidé |  |  | GAME-DESIGN-HOSPITALISATION.md, « Salle d'attente et chambre séparées » |
| 23/11/2026 | Points 31-32 : locaux libres de Sovarka demandés à la mairie (encadré, 1 PA), 4 bureaux du centre d'affaires de Krasnov à 40 PSK. | en ligne | 23/11/2026 | 31ba0f4f | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 31 et 32 |
| 23/11/2026 | Point 33 : karaoké « Chanter l'hymne au Tracteur » dans les églises de la Sainte-Moisson-Commune. | en ligne | 23/11/2026 | 31ba0f4f | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 33 et 39 |
| 23/11/2026 | Point 34 : groupe électrogène à la station-service de Krasnov. | en ligne | 23/11/2026 | 31ba0f4f | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 34 |
| 23/11/2026 | Point 35 : cartes postales de Krasnov et de Starovka. | en ligne | 23/11/2026 | fc2c2d73 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 35 |
| 23/11/2026 | Point 36 : noms propres et 18 icônes dans l'inventaire. | en ligne | 23/11/2026 | fc2c2d73 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 36 |
| 23/11/2026 | Points 37-39 : gare (Vassili Sukhoï, Lioudmila Proverkina), Direction du Renseignement (Naouchnikova, Doprossov, Koulakov), église. | en ligne | 23/11/2026 | 3f7ca907 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 37 à 39 |
| 23/11/2026 | Points 40-41, 43, 46-47 : relevé des PNJ sans portrait, 34 portraits recadrés, planches attribuées, réserve, relevés. | en ligne | 23/11/2026 | 52038d38 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 40 à 43, 46, 47 |
| 23/11/2026 | Points 42 et 44 : noms choisis par Fred (Kvassova, Petchatkina, Arkhipova et 14 noms sovarkiens) ; 7 informateurs renommés en base. | en ligne | 23/11/2026 | 3f7ca907 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 42 et 44 |
| 23/11/2026 | Point 45 : doublon « Le Maire » de Novomirsk retiré avec redirection. | en ligne | 23/11/2026 | fc2c2d73 | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 45 |
| 23/11/2026 | Point 46 : remplacer les images du Cercle des Camarades, de la rédaction de La Voix de Sovarka et de l'amphithéâtre. | décidé |  |  | GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 46 |
| 23/11/2026 | Plan de renommage des images de Codex (migration 20261123170047, jamais appliquée) : REJETÉ par Fred, fichier retiré vers historique/migrations-rejetees (24/11). | en ligne | 24/11/2026 | 218259d7 | RELAIS.md, « Images — relevés et plan de renommage NON APPLIQUÉ » |

## Mission Purge (24/11/2026)

| Date | Décision | État | En ligne le | Commit | Source |
|---|---|---|---|---|---|
| 24/11/2026 | 0.1 Tableau de suivi des décisions (ce fichier), rempli depuis le 01/11 et tenu à chaque bloc ; listes du soir par `outils/suivi/listes-du-soir.py`. | en ligne | 24/11/2026 | ad2424dd | Mission Purge 0.1 |
| 24/11/2026 | 0.2 CI : « Bancs JavaScript » découpés en six parts parallèles ; à la poussée, bancs liés aux fichiers modifiés ; suite complète la nuit (25 → 12 min sur main). | en ligne | 24/11/2026 | 94b4ce33 | Mission Purge 0.2 |
| 24/11/2026 | 0.2 Bancs hérités : test-crim-lot2-resolution, test-montrouge-tribunal-ssm, test-reconnexion-position-serveur recalés (règle valable) ; test-starovka-imprimerie-local : assertion « Ce commerce » inversée (règle abandonnée, point 31). Les 10 bancs *-browser/mobile test-*.cjs ne sont rouges qu'en local (navigateur Playwright absent) : ils tournent dans leurs workflows dédiés. Relevé local de controler-client : rouges dus à l'environnement (Chromium, chemins en dur), aucun rouge en CI sur main. | en ligne | 24/11/2026 | 94b4ce33 | Mission Purge 0.2 |
| 24/11/2026 | 0.3 Flèches : ancienne disposition partout, flèche unique en bas seulement rue de l'hôpital de Krasnov ; relecture des points 1 à 47 : aucune autre consigne élargie à tort. | en ligne | 24/11/2026 | 94b4ce33 | Mission Purge 0.3 |
| 24/11/2026 | 1.1 PR #1183 (formation), #1184 (saisie LTR hors arabe), #1132 (Commerce PJ + organigramme), #1186 (guidage mobile des pièces) fusionnées. | en ligne | 24/11/2026 | ad2424dd | Mission Purge 1.1 |
| 24/11/2026 | 1.1 PR #993/#994 (Ignat) : déjà sur main sauf la règle de dialogue (critique → pédagogie, jamais d'expulsion), ajoutée ; reste périmé, PR fermées. PR #1106 (banc mobile coque) : déjà couverte par main, fermée. | en ligne | 24/11/2026 | ad2424dd | Mission Purge 1.1, GAME-DESIGN-KRASNOV-IGNAT.md |
| 24/11/2026 | 1.5 Migration 20261123170047 retirée (jamais appliquée, absente du registre). | en ligne | 24/11/2026 | 218259d7 | Mission Purge 1.5 |
| 24/11/2026 | 1.2 Branches ChatGPT du 20/11 : « première rue Sovarka » déjà dans main ; « retours d'inscription » : seul l'effacement de l'ancien message d'erreur à la saisie manquait, repris (le reste était déjà sur main) ; « déplacements subis » non repris : déjà couvert par le temps réel du 20/11 (plateau-temps-reel.js), et la branche ajoutait une lecture serveur toutes les 7 s (contraire à #55/#60). | en ligne | 24/11/2026 | fcbf1122 | Mission Purge 1.2 |
| 24/11/2026 | 1.3 Branches : 994 branches supprimées (fusionnées, ou contenu déjà dans main) ; liste et SHA dans docs/branches-supprimees-20261124.tsv (restaurables) ; restent main, la branche de mission et 188 branches non intégrées. | en ligne | 24/11/2026 | dbfeb59a | Mission Purge 1.3 |
| 24/11/2026 | 1.4 #55/#60 consommation : mesure réelle (24 h) ; le filet de sauvegarde de 30 s ne lit ni n'écrit plus rien quand rien n'a changé (≈ 11 900 lectures de fiche et 6 700 écritures d'inventaire par jour) ; lectures de 60/90 s (événements, discrétion, dons, impacts) suspendues onglet masqué. Issues gardées ouvertes (suite possible). | en ligne | 24/11/2026 | dbfeb59a | Mission Purge 1.4 |
| 24/11/2026 | 1.4 #68 session expirée : refus 401 → jeton renouvelé et requête renvoyée une fois ; session perdue → fenêtre de reconnexion du jeu en cours de partie ; renouvellement au retour sur l'onglet. Issue fermée. | en ligne | 24/11/2026 | dbfeb59a | Mission Purge 1.4 |
| 24/11/2026 | 1.4 #72 (bûcheron et rencontres en forêt de Krasnov) fermée : en ligne depuis les migrations forêt du 21-22/11. Backlog de game design (#61, #310, #629, #630, #631) gardé ; autres issues gardées (travail restant). | en ligne | 24/11/2026 | dbfeb59a | Mission Purge 1.4 |
| 24/11/2026 | F.1 Fontaine de Luthécia déplacée du parvis de l'Hôtel de Ville vers la place du Formulaire de la Liberté (lieu où l'on entre ; « Puiser de l'eau » sur la place ; ancien point redirigé ; consigne de canicule suivant le point actif). Migration 20261124130000 appliquée. | en ligne | 24/11/2026 | 219e5475 | Mission Purge F.1 |
| 24/11/2026 | F.2 Images des fontaines de Montrouge (place du Rail) et de Port-Sainte-Marie (place d'Armes) branchées (chemins déjà en base). Fournies en PNG et non en WebP : converties ; « Fontaine baroque au crépuscule à Paris » non branchée (aucune correspondance évidente). | en ligne | 24/11/2026 | 219e5475 | Mission Purge F.2 |
| 24/11/2026 | F.3 Fontaine de Novomirsk (place du Peuple) : image attendue de Fred. | décidé |  |  | Mission Purge F.3 |
| 24/11/2026 | C.1 à C.5 Fenêtre du chantier simplifiée : résumé permanent « Encore X heures à faire aujourd'hui » + « ? » et matériaux du jour ; « Travailler » avec + et −, plafond et gain lus au serveur (nouvelle lecture chantier_fenetre_lire, migration 20261124120000 appliquée) ; une carte par matériau, un bouton par action ; « Gérer mon chantier » à part, une ligne par réglage ; plus de tableaux, deux onglets « Participer » / « Avancement ». | en ligne | 24/11/2026 | bf902f6e | Mission Purge C, GAME-DESIGN-CHANTIERS-IMAGES-20261120.md |
| 24/11/2026 | C.6 Lot 3 de Luthécia : description « Terrain à bâtir » (le nom du bâtiment « Lot 3 (La Châtaigneraie) » est inchangé : question posée). | en ligne | 24/11/2026 | bf902f6e | Mission Purge C.6 |
| 24/11/2026 | D.1 Canicule en journée seulement (début 12 h, 6 h) ; canicules déjà prévues ramenées à 12 h avec message de correction. | en ligne | 24/11/2026 | 44f940e0 | Mission Purge D.1, GAME-DESIGN-CLIMAT-20261121.md |
| 24/11/2026 | D.2 Seules canicule et crue arrêtent les chantiers ; consigne de l'orage « … mais les chantiers continuent » ; blizzard tiré seulement à Starovka (blizzards prévus à Novomirsk et Krasnov annulés). | en ligne | 24/11/2026 | 44f940e0 | Mission Purge D.2 |
| 24/11/2026 | D.3 Arrêt réel : la canicule bloque le travail jusqu'à minuit et la nuit suivante (la décision lit la date de l'événement : l'ordre minuit / pose des effets ne compte plus). Banc PGlite. | en ligne | 24/11/2026 | 44f940e0 | Mission Purge D.3 |
| 24/11/2026 | D.4 Canicule : image dédiée et bouton « Offrir 20 bouteilles d'eau aux ouvriers » (tout joueur présent, « ? », journal du chantier). Effet sur l'arrêt : AUCUN par défaut (réglage MJ canicule_eau_leve_arret = 0), question posée à Fred. | en ligne | 24/11/2026 | 44f940e0 | Mission Purge D.4 |
| 24/11/2026 | D.5 Starovka exclue des canicules ; fontaine de Starovka désactivée (aucun renvoi vers elle). | en ligne | 24/11/2026 | 44f940e0 | Mission Purge D.5 |
| 24/11/2026 | D.6 Bouteille d'eau à 4 PSK dans les boutiques « Équipements contre les intempéries » de Sovarka (Pharmanov et garage à Novomirsk, station-service de Krasnov ; Starovka n'en a pas). | en ligne | 24/11/2026 | 44f940e0 | Mission Purge D.6 |
| 24/11/2026 | G.1 Secrétaires de mairie et officiers des salles des partis des trois villes de Sovarka référents élections (pnj_referents, fiches DeepSeek « comment se présenter »). Migration 20261124140000 appliquée. | en ligne | 24/11/2026 | 12ef5351 | Mission Purge G.1 |
| 24/11/2026 | G.2 Calendrier électoral en cartes (étape en cours, frise Candidatures → Campagne → Vote → Résultats, « ? », « Détails »). | en ligne | 24/11/2026 | 12ef5351 | Mission Purge G.2 |
| 24/11/2026 | H.1 Salle d'attente et chambre séparées dans les six hôpitaux publics (Sovarka et Républia). | en ligne | 24/11/2026 | 12ef5351 | Mission Purge H.1 |
| 24/11/2026 | H.2 Bureaux du centre d'affaires de Krasnov : loyer de départ 30 PSK, plafond 40. Migration appliquée. | en ligne | 24/11/2026 | 12ef5351 | Mission Purge H.2 |
| 24/11/2026 | H.3 Arkadi répond aux questions libres, 1 PA pour 3 questions par salle et par jour. Migration appliquée. | en ligne | 24/11/2026 | 12ef5351 | Mission Purge H.3 |
| 24/11/2026 | H.4 Habitué du Bar Sever : Prokop Stakanov (3 h, un verre par jour, réglages déjà en ligne). Migration appliquée. | en ligne | 24/11/2026 | 12ef5351 | Mission Purge H.4 |
| 24/11/2026 | H.5 Matveï Rybakov est le père de Prokhor (documents points 28 et 37, deux fiches). | en ligne | 24/11/2026 | 12ef5351 | Mission Purge H.5 |
| 24/11/2026 | H.6 Pas d'ordre « Chasser » (il n'existait pas) ; « L'ours ne se chasse pas, c'est l'ours qui vous chasse… » dans les fiches de Matveï, Nina et du commissaire (aucun PNJ bûcheron n'existe : question). | en ligne | 24/11/2026 | 12ef5351 | Mission Purge H.6 |
| 24/11/2026 | H.7 Frère Kolkhoze devient « Diacre laborieux » (fiche, mentions, ancienne clé redirigée ; image gardée). | en ligne | 24/11/2026 | 12ef5351 | Mission Purge H.7 |
| 24/11/2026 | H.8 Dix légendes de cartes postales posées mot pour mot. | en ligne | 24/11/2026 | 12ef5351 | Mission Purge H.8 |
| 24/11/2026 | H.9 Dépôt des cartes postales dans l'armoire à souvenirs : BLOQUÉ, le contrôle serveur n'existe qu'à moitié (aucune fonction de dépôt, contenu d'armoire non enregistré) ; questions posées à Fred. | décidé |  |  | Mission Purge H.9, GAME-DESIGN-APPARTEMENTS.md |
| 24/11/2026 | H.10 Feuille volante de l'énigme : personne ne la possède, rien à mettre à jour. | en ligne | 24/11/2026 | 12ef5351 | Mission Purge H.10 |
| 24/11/2026 | H.11 Quête « Une affaire mystérieuse » : nomme le Sergent Bogdan Zatvorov, Armurerie Militaire de la Caserne centrale de Novomirsk (aucun écran ne lit encore quetes_actives : question). Migration appliquée. | en ligne | 24/11/2026 | 12ef5351 | Mission Purge H.11 |
| 24/11/2026 | E.1 « Inspecter les lieux » à 0 PA : déjà en ligne (seule la fouille coûte 1 PA). | en ligne | 23/11/2026 | 9924fa5a | Mission Purge E.1 |
| 24/11/2026 | E.2 Noms d'images corrigés (acceuil, EPHAD, amabassades) avec redirections vercel.json ; les noms à espaces ne sont pas renommés (question). | en ligne | 24/11/2026 | 12ef5351 | Mission Purge E.2 |
| 24/11/2026 | A.6 Case des PA en jauge (curseur, « ? ») ; lien « Plus d'informations sur les PA ? » vers l'infirmière d'accueil de la ville (six fiches DeepSeek complétées, aucune créée). | en ligne | 24/11/2026 | 02a9cfcf | Mission Purge A.6 |
| 24/11/2026 | A.7 Fenêtre de candidature : conditions en vert/rouge et dates de la période. | en ligne | 24/11/2026 | 02a9cfcf | Mission Purge A.7 |
| 24/11/2026 | A.9 « Aucun message pour le moment » retiré dès qu'un message existe. | en ligne | 24/11/2026 | 02a9cfcf | Mission Purge A.9 |
| 24/11/2026 | B.1 Accès aux forums (national de son pays toujours ; national étranger en lecture seule ; local du domicile toujours ; local visité en lecture-écriture ; sous-forums nationaux comme leur forum), contrôlé par le serveur. Migration 20261124110000 appliquée. | en ligne | 24/11/2026 | 02a9cfcf | Mission Purge B.1, GAME-DESIGN-FORUMS.md |
| 24/11/2026 | B.2 à B.5 Rubrique « Forums locaux » séparée ; tri par activité la plus récente ; dates « 23/11 à 18 h 48 » partout ; blocs vides jamais publiés. | en ligne | 24/11/2026 | 02a9cfcf | Mission Purge B.2-B.5 |
| 24/11/2026 | B.6 Saisie de gauche à droite partout sauf en arabe (sens-saisie.js, tous les champs). | en ligne | 24/11/2026 | 02a9cfcf | Mission Purge B.6 |
| 24/11/2026 | A.1 Comptes de test de Fred marqués (Arnie, Tom Tom, Bernard Bernardov, par nom et par compte) ; exclus des tirages, du dépouillement des élections et du tirage du PNJ guide. Migration appliquée. Autres comptes douteux non marqués (liste dans docs/purge/BLOC-A.md). | en ligne | 24/11/2026 | e6118464 | Mission Purge A.1 |
| 24/11/2026 | A.2 Pop-up de bienvenue au texte exact de Fred, ville et pays lus dans les données du jeu (six villes), icône réelle du bouton d'aide, croix seule (60 px sur téléphone), jamais recouverte. Repart du module #1188 de ChatGPT (précision de Fred). Migration appliquée. | en ligne | 24/11/2026 | e6118464 | Mission Purge A.2, issue #1191 |
| 24/11/2026 | A.2 Signature de la bienvenue : PNJ d'accueil à créer par Fred (emplacement vide prêt). | décidé |  |  | Mission Purge A.2 |
| 24/11/2026 | A.3 Calendrier du nouveau venu tenu par le serveur (temps de jeu cumulé par le battement de présence, d'un appareil à l'autre) : interview entre 5 et 10 min, repoussée de 5 min après une conversation PNJ, forcée à 30 min ; rien d'automatique la première heure ; ensuite une fenêtre automatique par connexion, les autres derrière les badges journal et météo. Migration appliquée. | en ligne | 24/11/2026 | e6118464 | Mission Purge A.3 |
| 24/11/2026 | A.4 / A.5 Interview signée par le journaliste du pays (Jodie Moitout en Républia, Vera Pravdina en Sovarka), presse filtrée par pays, article de Bernard re-signé ; question « que voulez-vous être… vous avez tout le temps de vous décider ». Migrations appliquées. | en ligne | 24/11/2026 | e6118464 | Mission Purge A.4-A.5 |
| 24/11/2026 | A.8 Notifications navigateur du chat (bulle « ? », réglage serveur, une par interlocuteur, une par heure, nom et lieu seulement, jamais pendant la première heure ni pour le PNJ guide). Migration appliquée. | en ligne | 24/11/2026 | e6118464 | Mission Purge A.8 |
| 24/11/2026 | A.10 PNJ guide (journaliste du pays + un habitant par ville : Firmin Badaud, Yvonne Bigorneau, Lucien Boulon, Zinaïda Otcheredova, Bair Namsaraev, Fiodor Medvedkine). Migration 20261124106000 appliquée le 24/11 sur demande de Fred (contrôlée : 6 habitants, 42 pistes). | en ligne | 24/11/2026 | e6118464 | Mission Purge A.10 |

## Mission de nuit (25/11/2026)

| Date | Décision | État | En ligne le | Commit | Source |
|---|---|---|---|---|---|
| 25/11/2026 | 1.1 Généraliste du dispensaire de Luthécia renommé Mathias Spirine (Fred, 32e5b8d) : profil de dialogue, miroir des scènes et bancs à jour ; images propres à Luthécia, salle d'attente et chambre séparées (H.1). Miroir serveur du casting : migration 20261125100000 appliquée et contrôlée le 25/11. | en ligne | 25/11/2026 | 899aa615 | Mission de nuit 1.1 |
| 25/11/2026 | 1.3 Fiodor Medvedkine, guide de Krasnov, présent au marché de Krasnov (avec Nina Gorbounova), comme les cinq autres guides dans leur ville ; banc banc-fiodor-krasnov-20261125.cjs. Aucune migration (le serveur le connaît déjà). | en cours |  |  | Mission de nuit 1.3 |
| 25/11/2026 | 2 Temps de jeu du calendrier d'accueil : une page restée ouverte mais masquée (écran verrouillé, autre onglet) compte au retour, jusqu'à 1 h (battement_absence_max_s) et dans la limite du temps masqué mesuré par la page ; une vraie déconnexion ne compte toujours pas. Migration 20261125110000 appliquée et contrôlée le 25/11. | en ligne | 25/11/2026 | 899aa615 | Mission de nuit 2 |
| 24/11/2026 | 3.1 « Subtiliser des explosifs » : le serveur applique la description (discrétion, réputation criminelle, carrière criminelle +15, ISN, Sovarka −10, dissuasion ; un échec ne fait rechercher que s'il est détecté, 55 % −20 caché −10 masqué). Formule unique crim_subtiliser_chance_interne. Migration 20261125120000 appliquée et contrôlée le 25/11. | en ligne | 25/11/2026 | 899aa615 | Mission de nuit 3.1 |
| 24/11/2026 | 3.2 Motif « Vol d'explosifs militaires » (table des infractions, plateau-core.js, arrestation de la caserne). Base : migration 20261125120000, appliquée et contrôlée le 25/11. | en ligne | 25/11/2026 | 899aa615 | Mission de nuit 3.2 |
| 24/11/2026 | 4.1 « Vos chances réelles : X % » avant le clic, calculées par le serveur avec la formule qui tranche l'ordre (ordres_chances_lire) : se cacher, subtiliser des explosifs, utiliser des explosifs, lancer une rumeur, neutraliser (selon la cible). Pastille sur le bouton, ligne en tête de la bulle « i ». Migration 20261125130000 appliquée et contrôlée le 25/11. | en ligne | 25/11/2026 | 899aa615 | Mission de nuit 4.1 |
| 24/11/2026 | 4.2 Audit de vérité des ordres à chance (descriptions contre serveur) : docs/nuit/AUDIT-CHANCES-20261125.md, aucune règle changée, écarts à trancher par Fred. | en cours |  |  | Mission de nuit 4.2 |

## Mission de jour (25/11/2026)

Décisions de Fred du 25/11 au matin, mot pour mot : `GAME-DESIGN-MISSION-JOUR-20261125.md`. Migrations écrites puis **appliquées en production le 25/11/2026 au soir** (feu vert de Fred, contrôles en lecture tous conformes).

| Date | Décision | État | En ligne le | Commit | Source |
|---|---|---|---|---|---|
| 25/11/2026 | 1.1 PNJ guide : le « goût » du nouveau est le chemin choisi à l'interview, à défaut sa carrière (table `guide_carrieres_criteres`, réglable) (migration 20261125140000 appliquée le 25/11/2026 au soir). | en ligne | 25/11/2026 | da0a315e | Mission de jour 1.1 |
| 25/11/2026 | 1.1 Interview fermée sans réponse : la journaliste écrit quand même, au plus tôt le lendemain, une fois (« Vous m'avez filé entre les doigts l'autre jour… on reprend quand vous voulez ? »), et son message mène à « Mes objectifs » (migration 20261125140000 appliquée le 25/11/2026 au soir). | en ligne | 25/11/2026 | da0a315e | Mission de jour 1.1 |
| 25/11/2026 | 1.1 Choix « Ne plus me proposer d'interview d'accueil » : coupe la relance pour de bon ; ne vaut que pour l'interview d'accueil (migration 20261125140000 appliquée le 25/11/2026 au soir). | en ligne | 25/11/2026 | da0a315e | Mission de jour 1.1 |
| 25/11/2026 | 1.2 Canicule : les 20 bouteilles offertes lèvent l'arrêt du chantier pour la journée en cours seulement ; arrêt de nouveau le lendemain si la canicule continue ; réglage MJ `canicule_eau_leve_arret` à 1 par défaut (migration 20261125150000 appliquée le 25/11/2026 au soir). | en ligne | 25/11/2026 | b1d48071 | Mission de jour 1.2 |
| 25/11/2026 | 1.3 Comptes de test : seuls Arnie, Tom Tom et Bernard Bernardov (vérifié en base : ce sont les trois seuls marqués ; aucun autre marqué). | en ligne | 25/11/2026 | afe94b5c | Mission de jour 1.3 |
| 25/11/2026 | 1.3 Interrupteur MJ qui réintègre les comptes de test dans le dépouillement des élections le temps d'un test (exclus par défaut, extinction automatique) (migration 20261125160000 appliquée le 25/11/2026 au soir). | en ligne | 25/11/2026 | 27cdd4ed | Mission de jour 1.3 |
| 25/11/2026 | 1.4 Forum du tribunal : parties à l'affaire et juges y lisent et écrivent où qu'ils soient ; les autres lisent sans écrire (contrôle serveur) (migration 20261125170000 appliquée le 25/11/2026 au soir). | en ligne | 25/11/2026 | 601c7df5 | Mission de jour 1.4 |
| 25/11/2026 | 1.5 Format de date unique « 23/11 à 18 h 48 » aussi au chat et au journal. | en ligne | 25/11/2026 | ea343b03 | Mission de jour 1.5 |
| 25/11/2026 | 1.6 Lot 3 de Luthécia : « Lot 3 — Terrain à bâtir » ; bouton « Donner » gardé, discret, sous « Vendre mes matériaux au chantier ». | en ligne | 25/11/2026 | fe34d9bb | Mission de jour 1.6 |
| 25/11/2026 | 1.7 Forêt de Krasnov : PNJ bûcheron Grigori Toporkov au campement (visible sur l'image de la cour), fiche DeepSeek, portrait recadré. | en ligne | 25/11/2026 | f8d01849 | Mission de jour 1.7 |
| 25/11/2026 | 1.8 Quêtes « Une affaire mystérieuse » (trois ébauches de septembre et octobre) : restent en sommeil, invisibles ; aucun écran de quêtes (vérifié : aucun écran ni API ne lit `quetes_actives`). | en ligne | 25/11/2026 | c12b2f9b | Mission de jour 1.8 |
| 25/11/2026 | 1.9 Images à espaces : les 38 renommées (espaces → _, sans accents), références à jour, anciennes adresses réécrites dans vercel.json. | en ligne | 25/11/2026 | 09b93bdb | Mission de jour 1.9 |
| 25/11/2026 | 1.10 Blizzard une fois par mandat, à Starovka seulement : vérifié en base (planification par mandat, Novomirsk et Krasnov refusées) ; rien à changer. | en ligne | 25/11/2026 | c12b2f9b | Mission de jour 1.10 |
| 25/11/2026 | 1.11 En-têtes des quatre migrations de la nuit : « appliquée le 25/11/2026 ». | en ligne | 25/11/2026 | 8598927f | Mission de jour 1.11 |
| 25/11/2026 | 2 Chronique de l'empire : le journal s'ouvre sur « Mes événements » et « L'empire » (chronique publique du pays du joueur : actes illégaux connus, procès, décisions publiques, climat, bagarres, ours et loups en forêt) ; auteur nommé seulement s'il est publiquement connu pour cet acte (identifié, arrêté ou jugé pour lui) ; lue au serveur, filtrée par pays, plus récente d'abord, comptes de test exclus (migration 20261125200000 appliquée le 25/11/2026 au soir). | en ligne | 25/11/2026 | c1306b5b | Mission de jour 2 |
| 25/11/2026 | 3 Armoire à souvenirs (H.9) : listes en base (liste 1 recopiée), contenu tenu par le serveur, seul le souvenir exact remplit son emplacement, cartes postales acceptées (dans la liste si elle les demande, sinon rangées hors collection) ; le propriétaire (jouissance du lieu) dépose et reprend ; un visiteur vide une armoire ouverte (pas un vol, constat au propriétaire qui peut porter plainte) ; fermée à clé, seulement avec une clé ; armoire à vider avant tout déplacement ; fenêtre : 12 emplacements, Déposer, Reprendre, « 7/12 » (migration 20261125300000 appliquée le 25/11/2026 au soir). | en ligne | 25/11/2026 | 0ff664c9 | Mission de jour 3 |
| 13/11/2026 | 3 Collection complète : +1 PA au réveil dans la même pièce que son armoire, sans cumul, cumulable avec l'appartement (décision de Fred du 13/11, GAME-DESIGN-APPARTEMENTS.md) ; réglage MJ `armoire_confort_pa` (migration 20261125300000 appliquée le 25/11/2026 au soir). | en ligne | 25/11/2026 | 0ff664c9 | GAME-DESIGN-APPARTEMENTS.md, Mission de jour 3 |

## Mission du soir (25/11/2026)

Décisions de Fred du 25/11 au soir : `docs/mission-soir-20261125.md` (cases cochées à chaque poussée).

| Date | Décision | État | En ligne le | Commit | Source |
|---|---|---|---|---|---|
| 25/11/2026 | 0 Les six migrations de la mission de jour (guide, canicule, comptes de test, forum du tribunal, chronique de l'empire, armoire à souvenirs) sont appliquées en production, contrôles en lecture conformes. | en ligne | 25/11/2026 | cc00ef37 | Mission du soir 0.1 |
| 25/11/2026 | 2.1 PNJ guide : correspondance carrière → goût validée telle que proposée (armée, renseignement → uniforme ; affaires, médecin → affaires ; magistrat, ouvrier → politique ; presse, clergé → influence ; criminel → crime ; escort → belle vie ; enfant, sans expérience → pistes générales) ; rien à changer (table `guide_carrieres_criteres`, appliquée le 25/11). | en ligne | 25/11/2026 | da0a315e | Mission du soir 2.1 |
| 25/11/2026 | 1.1 Audit des chances : chaque description suit le serveur sans changer la règle ; plus de pourcentage écrit en dur, « Vos chances réelles : X % » lue au serveur pour 18 ordres de l'audit ; conséquences d'échec annoncées telles quelles (migration 20261125400000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.1 |
| 25/11/2026 | 1.3a « Mobiliser les membres » (siège syndical) ouvre l'organisation syndicale du joueur, plus l'intervention de police ; 0 PA. | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.3 |
| 25/11/2026 | 1.3b « Écouter les rumeurs » chez la poissonnière de Novomirsk : lieu déclaré au serveur (migration 20261125400000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.3 |
| 25/11/2026 | 1.3c « Inspecter les cargaisons » au quai de Novomirsk accepté par le serveur (migration 20261125400000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.3 |
| 25/11/2026 | 1.3d « Fuite d'information » : la fuite de document n'a jamais été décidée ; description alignée sur la réalité (Républia : effets de POP/INF, Sovarka : sondage ou registre, sans jet). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.3 |
| 25/11/2026 | 1.3e Falsifier les listes électorales : un échec coûte 2 jours de détention (migration 20261125400000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.3 |
| 25/11/2026 | 1.4a Contrebande : chance plafonnée à 85 %, douane sur échec comme sur réussite, échec repéré = saisie et recherche (migration 20261125400000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.4 |
| 25/11/2026 | 1.4b Truquer le dépouillement : échec = 3 jours de détention ; bourrer les urnes reste à 1 jour (migration 20261125400000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.4 |
| 25/11/2026 | 1.4c Évasion : règle du serveur gardée (DUP, ISN ; échec +1 jour, 2 en Sovarka, et 500), annoncée. | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.4 |
| 25/11/2026 | 1.4d Rébellion : règle du serveur gardée (VOL, force du codétenu ; échec −15 DIS, +4 jours, ni transfert ni grilles), annoncée. | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.4 |
| 25/11/2026 | 1.4e Visiter un détenu : sans jet, contrôlé par le serveur (cette prison, une visite par jour et par détenu, QHS : avocat et famille), conversation privée (migration 20261125410000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.4 |
| 25/11/2026 | 1.4f Voler du matériel de chantier : vrai vol, description réelle, l'agent de sécurité posté sur le chantier le protège. | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.4 |
| 25/11/2026 | 1.2 Article favorable et contrer une campagne de presse : jet, PA, prix, versement à la rédaction et effet au serveur, même formule (migration 20261125500000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.2 |
| 25/11/2026 | 1.2 Demander à parler à quelqu'un (loge) : PA et réponse à 95 % au serveur (migration 20261125500000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.2 |
| 25/11/2026 | 1.2 Corrompre un journaliste et fabriquer un scandale : malus de sécurité lu au serveur, accord payé dans la transaction du jet (migration 20261125500000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.2 |
| 25/11/2026 | 1.2 Filature et enquête du commissaire : caisse et PA pris avant le jet, une fois par requête ; enquête sans trace conclue au serveur (migration 20261125500000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.2 |
| 25/11/2026 | 1.2 Censure (−8 indice social) et consultation des dossiers (tirage) décidées au serveur (migration 20261125500000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 1.2 |
| 25/11/2026 | 3.1 Souvenirs des six villes ouvertes : objets du jeu achetés sur place auprès d'un PNJ (lieu à comptoir ou étal), jamais indiqués par le jeu, revendables librement ; cartes postales existantes acceptées dans les listes qui les demandent (migration 20261125600000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 3.1 |
| 25/11/2026 | 3.2 Listes 2, 3 et 4 en base (provisoires, relues le 12/12) ; armoires fabriquées : une des quatre listes au hasard ; souvenirs des empires fermés définis, achetables nulle part (migration 20261125600000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 3.2 |
| 25/11/2026 | 3.3 Frontières des empires fermés : voyage refusé par le serveur (« Frontière fermée, ouverture au premier trimestre 2027 ») ; l'armoire annonce l'ouverture au premier trimestre 2027 sous ces villes (migration 20261125600000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 3.3 |
| 25/11/2026 | 4.1 Premium : options achetées une fois et durables (commerce premium 3 familles / 10 articles, bureau à 6, personnalisation du local ou du bâtiment privé, publicités de joueurs) ; renouvellement d'image à l'unité ; abonnement mensuel = toutes les options + un renouvellement d'image par semaine, non cumulable ; euros, achat par achat ; aucun prix fixé (réglages MJ, plancher 2 €) ; tarifs 4,99 € / 7,99 € / 0,99 € et Stripe retirés (migration 20261125700000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 4.1 |
| 25/11/2026 | 4.2 Droits premium tenus par le serveur (abonnements, achats, droits, compteur hebdomadaire de renouvellements ; chaque option vérifie le droit) ; bêta : tout gratuit pour tous (migration 20261125700000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 4.2 |
| 25/11/2026 | 4.3 Publicité des annonceurs : une par jour au Dormir, joueurs gratuits seulement, jamais les abonnés ; réglage MJ éteint ; aucune régie (migration 20261125700000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 4.3 |
| 25/11/2026 | 4.3 Publicités de joueurs (option premium) : pop-up en ville, réclame au cinéma de Montrouge, annonce dans les journaux ; jeu de rôle, texte court échappé (migration 20261125700000 appliquée le 25/11/2026 en fin de soirée). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 4.3 |
| 25/11/2026 | 4.4 Paiement par un revendeur qui vend en son nom et gère la TVA (fournisseur pas encore arrêté par Fred) : interface serveur prête en mode test, faux fournisseur pour les bancs, aucun achat sous 2 €. | en cours |  |  | Mission du soir 4.4 |
| 25/11/2026 | 4.5 Remise à zéro du 19/12 et offre des testeurs de la bêta : procédure préparée et documentée, non exécutée (Fred décide du moment). | en ligne | 25/11/2026 | 32d9b22b | Mission du soir 4.5 |
| 25/11/2026 | 4.6 Reportage hebdomadaire, film mensuel au cinéma de Montrouge, portrait par IA, mini-jeux : hors mission, forme à trancher avec Fred. | décidé |  |  | Mission du soir 4.6 |
