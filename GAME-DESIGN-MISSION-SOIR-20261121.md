# Mission du soir du 21/11/2026 — décisions de Fred (texte d'origine)

Consigné tel que Fred l'a écrit (deux messages du 21/11/2026, soir). L'état de réalisation est dans RELAIS.md.

## Urgence : texte de la page d'accueil (human-gambit.com)

1. Sur la page d'accueil, dans l'encadré sous les boutons, remplace le titre et le premier paragraphe (« Human Gambit ouvre sa beta. » / « Republia est le premier empire a ouvrir ses portes… façonnera la suite. ») par ce texte exact, accents compris :

Titre : HUMAN GAMBIT OUVRE SA BÊTA.

Paragraphe : « Deux empires ouvrent leurs portes. En Républia : trois villes, une Assemblée, des tribunaux, un championnat et quelques personnes peu recommandables. En Sovarka : le Parti, ses kolkhozes, ses Héros du Travail et une forêt où rôde un ours. Les empires voisins attendent leur tour. Ce que vous ferez ici — et ce que vous nous en direz — façonnera la suite. »

Le second paragraphe (« Traduction en cours… ») reste inchangé.

2. Mets à jour la même phrase dans les 7 autres langues de la page (English, Español, 繁體中文（台灣）, Русский, 한국어, العربية, Português (Brasil), Deutsch), traduite fidèlement. Noms propres conservés tels quels : Républia (Republia dans les langues sans accents), Sovarka.

3. Vérifie la page en ligne en français et dans au moins deux autres langues, et confirme-le en une ligne en tête de ton rapport final.

## Mission suivante

### 0. Ordre et règles
- Si la mission en cours (A à K) n'est pas terminée, termine-la d'abord entièrement, puis enchaîne directement sur cette mission sans attendre de feu vert. Un seul rapport final pour l'ensemble (A à K + cette mission).
- Règles inchangées : relire RELAIS.md et la PR #1176 avant toute migration ; ne jamais toucher au goulag (sovarka_goulag_*, configuration active=false à conserver) ; les fonctions communes ne se modifient que par simple appel ajouté ; contrôle en lecture après chaque migration ; tenir AGENTS.md / RELAIS.md à jour pour Codex (qui reprendra après ton rapport).
- Principe de toutes les interfaces : « codons comme pour un enfant ». Chaque fenêtre comprise au premier coup d'œil, jamais de formulaire qu'on ne peut pas envoyer, jamais d'action sans issue, un maximum de pédagogie dans les messages, mise à jour en direct sans jamais recharger la page.
- Les fichiers d'image cités ci-dessous doivent se trouver dans le dépôt. S'il en manque un, branche tout le reste, mets l'emplacement prêt à recevoir le fichier, et liste les fichiers manquants dans le rapport sans bloquer.

### 1. Presse – vérifier que l'étape F a tout couvert (compléter sinon)
- Aucune référence au monde réel dans toute la presse : « sovarkien », jamais « soviétique ». Revue des modèles d'articles ET des textes déjà en base.
- Chaque journal défend le point de vue de son pays (exemple : la Pravdovka parle des agressions de ministres étrangers sur son sol et demande ce qu'ils faisaient là, surtout sur un site militaire ou d'écoute).
- Anonymat absolu : jamais de rapprochement entre deux affaires qui laisserait deviner un auteur anonyme.
- Noms cliquables : le nom d'un personnage cité ouvre sa fiche publique avec la possibilité de lui écrire. Un auteur anonyme n'est jamais nommé.

### 2. Forum – compléments
- Sur petits écrans, les blocs s'empilent dans leur ordre de lecture. Sur ordinateur, l'agencement libre reste inchangé (chevauchement toujours interdit).
- On peut coller une image directement dans le message (presse-papiers) ou y glisser un fichier. Les images extérieures sont toujours copiées dans le stockage du jeu.

### 3. Eau de la place de l'Ours (Krasnov)
- Retirer le bouton « Remplir une bouteille d'eau » posé sur l'image de la place de l'Ours.
- Le remplacer par un ordre de pièce VERT « Puiser de l'eau » dans la liste des actions de la place, qui ouvre une fenêtre dédiée illustrée par Krasnov_place_ours_fontaine.webp. Renseigner cette image sur le point d'eau existant krasnov-fontaine-ours (image vide aujourd'hui).
- Règles : eau gratuite ; 1 PA par puisage quelle que soit la quantité ; au plus 10 bouteilles par tranche de 6 h (compteur remis à zéro à 0 h, 6 h, 12 h, 18 h, heure de Paris) ; quantité choisie par le joueur, plafonnée automatiquement au plus petit de deux nombres : le reste de la tranche et la place libre dans l'inventaire ; aucun PA consommé si le plafond est atteint ou l'inventaire plein ; pas de bouteille vide nécessaire.
- Boire : une bouteille bue disparaît sans laisser de bouteille vide. Vérifier TOUS les endroits où l'on boit et corriger ceux qui laissent une bouteille vide.
- Le marché garde son eau déjà puisée à 2 PSK, sans PA (ne pas toucher).
- Textes exacts :
  En tête de fenêtre : « Fontaine de la statue de l'Ours. L'eau est gratuite. Puiser coûte 1 PA, quelle que soit la quantité. Vous pouvez puiser jusqu'à 10 bouteilles toutes les 6 heures. »
  Reste : « Vous pouvez encore puiser 7 bouteilles avant 12 h 00. » (chiffre et heure calculés) ; si l'inventaire limite, ajouter : « Votre inventaire ne peut accueillir que 5 bouteilles de plus. »
  Plafond atteint : « Vous avez déjà puisé vos 10 bouteilles pour cette période. La fontaine sera de nouveau à vous à 18 h 00. Astuce : le marché vend de l'eau déjà puisée, sans dépense de PA. »
  Inventaire plein : « Votre inventaire est plein : faites de la place pour puiser de l'eau. »
  Après puisage : « Vous avez puisé 5 bouteilles d'eau (−1 PA). Elles sont dans votre inventaire. »
  Quand le puisage est impossible, le bouton de validation est désactivé et le texte explique pourquoi.

### 4. Refonte des types de bâtiments (7 types en base → 5)
- Hangar : 30 000, 6 jours, 300 h ; aucune subdivision.
- Commerce standard : 60 000, 12 jours, 600 h ; aucune subdivision.
- Commerce premium : 90 000, 18 jours, 900 h ; boutiques de 600 m² minimum.
- Logement : 90 000, 18 jours, 900 h ; 6 appartements (3 petits de 45 m², 3 grands de 75 m²).
- Building (mixte logements et commerces) : 120 000, 24 jours, 1 200 h ; commerces de 300 m² minimum, appartements de 150 m² minimum, au plus 6 commerces et 14 appartements ; la somme des lots ne dépasse pas la surface du terrain (pas d'étages). Remplace la barre : un building peut avoir peu ou pas de commerces.
- Supprimés : logements sociaux petit et barre (l'ancien moyen devient le type Logement unique). S'il existe en base des chantiers ou bâtiments des types supprimés, les convertir vers le type nouveau le plus proche et les lister dans le rapport.
- Catégorie selon le donneur d'ordre, pour Logement comme pour Building : mairie = logements sociaux (attribués par le maire, loyer bas fixé par le jeu, bonus de moral et de santé au sommeil) ; joueur = logements classiques (loyer et attribution libres).
- Le chantier d'Arnie (terrain 3 de Luthécia, building) ne doit pas être modifié.
- Mettre à jour toutes les fonctions qui citent les 7 anciens types : dépôt et décision du permis, acquisition de terrain, valeur des biens pour les prêts d'Helvetia (qui doit désormais compter les logements), découpage des lots, libellés côté client.

### 5. Images de construction
- Image de démarrage : photo commune à toute la Républia, SAUF Port-Sainte-Marie. Luthécia et Montrouge gardent leur photo unique pour tous les types.
- Port-Sainte-Marie, série complète à brancher :
  PSM_chantier_demarrage_petit.webp (hangar, commerce standard)
  PSM_chantier_demarrage_grand.webp (commerce premium, logement, building)
  PSM_chantier_fondations.webp, PSM_chantier_gros_oeuvre.webp, PSM_chantier_facade.webp (une image par étape, quelle que soit la taille)
  PSM_batiment_hangar.webp, PSM_batiment_commerce_standard.webp, PSM_batiment_commerce_premium.webp, PSM_batiment_logement.webp, PSM_batiment_building.webp
  rue-terrains-lots-detail-psm.webp (remplace l'actuelle : 6 lots, LOT 01 1 500 m² à LOT 06 5 500 m² ; si les lots en base ne correspondent pas à l'image, le signaler dans le rapport sans modifier la base)
  rue-terrains-psm-etat2.webp (quartier en partie vivant), rue-terrains-psm-etat3.webp (quartier achevé) ; état 1 = vue actuelle « Terrains à vendre » (brancher dans la mécanique de rue en trois états de l'étape J).
- Dans le rapport : liste des images manquantes pour les bâtiments achevés de Luthécia et Montrouge (par type), pour qu'aucune image ne soit produite en double.

### 6. Fenêtre « Le chantier » (remplace la version actuelle)
- La fenêtre ne s'ouvre JAMAIS automatiquement en entrant sur le terrain : uniquement par l'ordre « Le chantier ».
- Supprimer de la page l'ancien encadré « État du chantier » qui reste visible derrière la fenêtre et chevauche le texte du terrain.
- Police nettement plus grande partout dans la fenêtre.
- Quatre onglets, dans cet ordre : État (ouvert par défaut), Stock de matériaux, Main-d'œuvre, Gestion. Chaque onglet affiche son contenu dans la fenêtre elle-même (jamais une fenêtre par-dessus une autre).
- Style des jauges : barre épaisse et arrondie dans un cadre sombre en relief (bronze/brun du jeu), petits carrés à l'intérieur qui s'allument au fil de la progression, en dégradé du rouge vers le vert en passant par l'orange, avec reflet brillant ; onglet incliné au-dessus de la barre avec quelques rayures obliques, portant le titre ; texte écrit à côté ; animation de remplissage discrète à l'ouverture. Dessiné en code (CSS/SVG), aucune image externe.
- Onglet État : image de l'étape en cours ; jauge du CHANTIER (un carré par jour du chantier : 24 pour un building, 6 pour un hangar…, traits fins entre les étapes, onglet = nom de l'étape, texte « Jour 2 / 24 · 4 % », étape suivante, fin prévue) ; jauge du JOUR sur les heures (10 carrés, texte « 23 / 50 h ») ; trois petites jauges du jour pour bois, minerai, métal (mêmes carrés, texte « 40 / 100 »).
- Onglet Stock de matériaux : tableau, une ligne par matériau. Colonnes : matériau ; prix de rachat par le chantier ; stock actuel / stock max (stock max = besoin du jour) ; quantité à saisir (plafonnée automatiquement à ce qui manque et à ce que le joueur possède) ; case à cocher « Donner au lieu de vendre » ; petite jauge du matériau. Un bouton de validation avec un résumé clair avant l'envoi (« Vous vendez 20 bois pour 120 FR »).
- Onglet Main-d'œuvre : heures restant à faire / heures du jour (exemple 27 / 50), salaire horaire ; à côté, case du nombre d'heures voulu avec la mention « (1 PA/h) » (plafonnée aux heures restantes et aux PA du joueur) et bouton « Travailler ».
- Onglet Gestion (propriétaire seulement) : tableau de bord sur le modèle de celui des commerces. En tête : trésorerie, fonds versés / coût total, prochain appel de fonds (montant, échéance). Puis tous les réglages : prix de rachat des matériaux, salaire horaire, versement de fonds, commande de matériaux.
- Bugs à corriger : « Heures du jour : 0 faites, 0 restante(s) » sur le chantier d'Arnie (un building doit offrir environ 50 h par jour) ; vérifier en lecture pourquoi les matériaux sont à 0 au jour 2 (besoin non remis à zéro ou simple retard) et corriger s'il s'agit d'un bug ; choix mal alignés (bouton rond au-dessus du texte) qui disparaissent avec le nouveau tableau.
- Remettre l'ordre de pièce « Voler des matériaux » sur les terrains en chantier, dans la couleur des ordres criminels, hors de la fenêtre du chantier, branché sur la fonction existante crime_voler_materiaux. La refonte complète du vol viendra plus tard : ici, seulement le remettre en état de marche.

### 7. Groupes
- Colonne « Personnes présentes » : un groupe forme toujours un bloc. Le chef en premier, nommé « Groupe <nom du chef> » ; les membres juste en dessous, en plus petit et légèrement décalés du bord, comme un sous-paragraphe. Rien ne s'intercale dans le bloc (ni PNJ ni autre joueur), dans la rue comme dans les bâtiments ; les PNJ et personnes seules viennent avant ou après.
- Mise à jour en direct pour tous les présents (arrivée ou départ d'un membre, masque, cachette) : aujourd'hui Tom Tom a dû recharger sa page pour voir Arnie le rejoindre.
- Vérifier pourquoi Tom Tom apparaissait « Absent » côté Arnie alors qu'il était connecté et chef du groupe ; corriger si c'est un bug.
- Un membre qui n'est pas chef garde l'ordre « Sortir » (et les autres ordres de déplacement). Au clic, une infobulle : « Impossible de vous déplacer : vous n'êtes pas chef de groupe. Quittez le groupe pour vous déplacer seul. »
- Se cacher : quand le chef se cache, tout le groupe se cache avec lui, sur un seul jet calculé sur la dissimulation du chef, avec un malus de 5 points par membre en plus du chef (plafond 98 % et 2 % d'échec critique inchangés ; tenue de ninja du chef prise en compte comme aujourd'hui). Réussite = tout le groupe caché ; échec = personne. Qui rejoint un groupe caché est caché sans jet. Quand le chef sort de sa cachette ou est découvert, tout le groupe redevient visible. Message pédagogique annonçant les chances et le malus avant le jet.

### 8. Masque de carnaval
- Être masqué n'est pas être caché : un personnage masqué reste visible dans « Personnes présentes » (aujourd'hui Tom Tom disparaît de la liste d'Arnie quand il se masque). Pour les autres : portrait remplacé par l'image de l'objet masque, nom remplacé par « Personnage masqué » ; aucun lien vers sa fiche réelle.
- Le personnage masqué voit aussi son état « Masqué » sur sa propre ligne de « Personnes présentes » (pas seulement dans sa fiche à gauche).
- Chef de groupe masqué : les personnes extérieures au groupe voient « Groupe d'un personnage masqué » ; les membres du groupe continuent de voir « Groupe <nom du chef> ».

### 9. Navigation – mairie de Krasnov
- Supprimer la sortie mairie → krasnov-place-ours dans rue_sorties_batiments : on ne sort de la mairie que dans krasnov-rue-mairie-place.
- La porte cliquable de la mairie doit être sur l'image de la rue krasnov-rue-mairie-place, et retirée de l'image de la place de l'Ours (la mairie y est visible en fond, mais on n'y entre pas par là).
- Vérifier tous les bâtiments de Sovarka qui ont plusieurs sorties enregistrées ou une porte cliquable sur une autre vue que leur rue, et corriger les incohérences du même genre ; les lister dans le rapport.

### 10. Rapport final (un seul, pour A à K + cette mission)
- Ce qui est fait, point par point, et ce qui ne l'est pas avec la raison.
- Migrations appliquées (numéro, nom) et contrôles effectués.
- État de la PR climat et de la PR #1176.
- Fichiers d'image manquants ; liste des images à produire pour les bâtiments achevés de Luthécia et Montrouge.
- Résultat de la vérification en lecture du chantier d'Arnie et du compte de Régis.
- Ce que Codex doit savoir pour reprendre (aussi écrit dans RELAIS.md).
