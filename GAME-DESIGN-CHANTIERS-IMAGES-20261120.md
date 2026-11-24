# Chantier « Construction » — consigne complète et définitive

Décisions de Fred des 20 et 21/11/2026, consignées mot pour mot. Elles remplacent toutes les consignes précédentes sur la construction (images par étape du 20/11, refonte de l'ergonomie et accélération du 21/11). À traiter après le lot de Krasnov.

---

CHANTIER « CONSTRUCTION » : consigne complète et définitive (décisions de Fred des 20 et 21/11). Elle remplace toutes les consignes précédentes sur la construction, y compris GAME-DESIGN-CHANTIERS-IMAGES-20261120.md, que tu mets à jour avec ce texte. À traiter après le lot de Krasnov.

Contexte : premier chantier réel jamais lancé (Arnie, terrain 3 de Luthécia, building, lancé le 20/11). Le parcours serveur fonctionne, mais l'interface et les images ne vont pas.

1. BUG D'AFFICHAGE
Après le lancement du chantier, l'image et l'état du terrain ne se sont mis à jour qu'après un clic. Règle de Fred : jamais besoin de recharger la page. Lancement, actions des joueurs, progression de nuit et réception doivent se refléter immédiatement à l'écran.

2. IMAGES DU CHANTIER
- Démarrage (moins d'un tiers du chantier) : UNE image commune à toute la Républia, images/chantier-en-cours.webp. Fred l'a nettoyée de ses fausses données (PR #1168, même nom de fichier, image seule à fusionner dès que les contrôles rapides sont verts ; version de cache si besoin).
- Gros œuvre (du tiers aux deux tiers), façade et finitions (au-delà des deux tiers), bâtiment achevé (après réception) : une série PAR VILLE, dans le style de la ville (sans coller à la géographie exacte du terrain) : Luthécia, Montrouge, Port-Sainte-Marie ; même structure prévue pour les villes des autres empires.
- Gros œuvre et façade en deux gabarits par ville. Bas = hangar, commerce standard, commerce premium, logements sociaux petit. Haut = building, logements moyen, barre d'immeuble.
- Bâtiment achevé : une image par ville et par type de bâtiment, sans encarts.
- Convention de fichiers : images/chantiers/<ville>/gros-oeuvre-bas.webp, gros-oeuvre-haut.webp, facade-bas.webp, facade-haut.webp, final-<palier>.webp (ville = luthecia, montrouge, psm…). Si un fichier manque : repli sur l'image actuelle correspondante.
- Déjà fournies pour Luthécia (images seules, à fusionner) : gros-oeuvre-haut (#1164), facade-haut (#1165), final-building (#1167). images/chantiers/luthecia/fondations.webp est dans le dépôt mais ne sert plus : ne pas la brancher.
- Les fiches actuelles avec encarts (building-construction-terrain.webp, etc.) restent l'illustration du choix du bâtiment à construire, avant le lancement.

3. SURCOUCHE D'AVANCEMENT
Sur l'image du chantier, une jauge d'avancement en surcouche avec les vraies données du serveur : pourcentage, jour X / durée, étape en cours, prochaine étape, date de fin prévisionnelle recalculée, jour d'avance ouvert le cas échéant, arrêt pour financement ou pour matériaux. Lisible sans masquer le texte de la pièce.

4. FENÊTRE UNIQUE « LE CHANTIER » (refonte de l'ergonomie)
Constat : ordres éparpillés et redondants (« Information sur le chantier », « Information et approvisionnement du chantier » ▾, « Approvisionner le chantier », « Travail et division des lots » ▾, « Salaire horaire des ouvriers », « Prix d'achat des matériaux » ; plateau-construction-commandes.js et plateau-politique.js). Fenêtre des prix sans mise en forme, sans accents (« metal »), sans explication.
Nouvelle interface : UN seul ordre « Le chantier » ouvrant UNE fenêtre, sur le modèle de la fenêtre du marché de Krasnov, en trois parties :
- ÉTAT (tous) : progression (jour X / durée, %), trésorerie, stock de matériaux face aux besoins du jour, heures du jour faites / restantes, jour d'avance ouvert ou non et ses heures restantes, prochain appel de fonds, salaire horaire en vigueur, prix de rachat des matériaux, avec une phrase explicative : « Si les joueurs terminent les heures du jour, le jour suivant s'ouvre en avance : le chantier gagne une journée cette nuit. »
- PARTICIPER (tous) : travailler sur le chantier (nombre d'heures, 1 PA par heure, salaire affiché) ; vendre des matériaux au chantier (quantité par matière, prix unitaire et total) ; donner des matériaux.
- GESTION (maître d'ouvrage seul) : prix de rachat de bois / minerai / métal (phrase : c'est le prix auquel le chantier rachète les matériaux aux joueurs), salaire horaire (minimum 50 FR), apport de fonds, définition des lots, puis « Réceptionner le bâtiment » une fois le chantier terminé.
- En bas : Annuler / Valider, totaux en direct (PA, argent), Valider grisé avec infobulle explicative si les PA, l'argent, le stock ou la trésorerie ne suffisent pas. Rien n'est exécuté à moitié.
- Supprimer les anciens ordres et menus déroulants qui font doublon. Le vol de matériaux reste un ordre à part (acte illégal, règles communes du vol).
- Libellés propres, accentués, traduits (clés pour Codex dans RELAIS).

5. ACCÉLÉRATION PAR LE TRAVAIL DES JOUEURS (règle serveur)
Règle actuelle (chantier_travailler / chantier_jour_traiter) : 1 jour d'avancement par nuit au maximum ; capacité = coutTravail / taux / durée (50 h par jour pour un building) ; les heures des joueurs remplacent celles des PNJ sans gain de vitesse.
Nouvelle règle :
- Quand les heures du jour en cours ont toutes été faites par des joueurs, les heures du jour suivant s'ouvrent aussitôt (jour d'avance), aux mêmes conditions (1 PA par heure, salaire fixé par le propriétaire, payé par la trésorerie).
- À minuit, si un jour d'avance a été ouvert, les PNJ terminent ses heures restantes (payées comme aujourd'hui) et le chantier avance de DEUX jours.
- Limite stricte : un seul jour d'avance par jour. Une fois le jour d'avance complet, plus aucune heure disponible jusqu'à minuit. Un chantier va au plus deux fois plus vite (12 jours au minimum pour un building de 24 jours). Ne jamais ouvrir de troisième jour (l'accélération au-delà est réservée au P2W des futurs empires).
- Garde-fous inchangés : le jour d'avance exige les matériaux des deux jours (sinon avancement proportionnel) et respecte les paliers d'appel de fonds (pas de dépassement du tiers sans les 70 %, ni des deux tiers sans les 100 %). Le coût total ne change pas : on paie plus vite, pas plus.
- Journal du chantier : signaler les nuits où un jour a été gagné.
- Bancs : jour normal ; jour complet sans avance ; jour d'avance partiel complété par les PNJ (+2 jours) ; troisième jour refusé ; matériaux insuffisants pour deux jours ; palier d'appel de fonds non versé.

Hors refonte de la règle d'accélération (point 5), ne change aucune règle serveur (coûts, taux, appels de fonds). Fred testera ensuite avec Arnie sur le terrain 3 de Luthécia, et on ajustera.

---

# Complément du 21/11/2026 : terrains à bâtir, cohérence des vues avec l'avancement des constructions — consigne intégrale

TERRAINS À BÂTIR : cohérence des vues avec l'avancement des constructions (décisions de Fred, 21/11). À traiter avec le chantier « construction », après le lot de Krasnov.

Constat : la vue des lots (Luthécia : « LOT 1 À VENDRE… LOT 5 À VENDRE », surfaces dessinées) et la vue de rue figent un état qui devient faux dès qu'un lot est vendu ou construit.

1. VUE DES LOTS : PLAN DU LOTISSEMENT EN VIGNETTES (à tester, Fred jugera le rendu)
- Remplacer l'image unique des lots par un plan en vignettes : une carte cliquable par lot, qui mène au lot comme aujourd'hui.
- Chaque vignette montre l'image ACTUELLE du lot : image de terrain nu s'il est à vendre ou acheté sans chantier ; image de l'étape du chantier s'il est en travaux (démarrage commun images/chantier-en-cours.webp, puis gros œuvre / façade par ville et par gabarit) ; image du bâtiment achevé s'il est construit (final-<palier> de la ville). Mêmes fichiers et même convention que le chantier « construction » (images/chantiers/<ville>/…), avec repli sur l'image actuelle si un fichier manque.
- Sous chaque vignette, une étiquette tirée du serveur, par exemple : « Lot 3 — 2 300 m² — À vendre », « Lot 3 — Chantier 47 % », « Lot 3 — Building de Arnie ».
- Mise à jour immédiate, sans recharger la page.

2. VUE DE RUE : TROIS ÉTATS PAR VILLE
- État 1, terrain vague en chantier (image actuelle) : tant qu'aucun bâtiment n'est réceptionné dans le lotissement de la ville.
- État 2, quartier en partie vivant : dès la réception du PREMIER bâtiment.
- État 3, quartier achevé : à la réception du DERNIER bâtiment.
- Seule la zone des terrains change sur l'image ; tout le reste de la rue est identique. Les zones cliquables et les sorties ne bougent pas.
- Convention de fichiers : images/terrains/<ville>/rue-etat-1.webp, rue-etat-2.webp, rue-etat-3.webp (ville = luthecia, montrouge, psm). Repli sur l'image actuelle si un fichier manque. Fred fournira les images.
- Même principe pour Montrouge et Port-Sainte-Marie, avec leur lotissement respectif.
- Bancs : aucune réception → état 1 ; une réception → état 2 ; toutes les réceptions → état 3 ; fichier manquant → repli.

---

# Mission « Purge » du 24/11/2026, bloc C : fenêtre du chantier simplifiée — consigne de Fred, mot pour mot

Elle remplace, pour la fenêtre « Le chantier », le point 6 de GAME-DESIGN-MISSION-SOIR-20261121.md (quatre onglets État,
Stock de matériaux, Main-d'œuvre, Gestion ; tableau du stock). Le reste (images, jauges, jour d'avance, commande de nuit) est inchangé.

═══ BLOC C — CHANTIER (fenêtre à simplifier au maximum) ═══
C.1 Résumé permanent en haut : « Encore X heures à faire aujourd'hui » + « ? », et les matériaux du jour.
C.2 « Travailler sur ce chantier » dans la fenêtre principale : heures avec + et −, plafonnées, gain affiché avant validation.
C.3 « Vendre mes matériaux au chantier » : un seul contrôle par action.
C.4 Propriétaire : « Gérer mon chantier » dans une fenêtre à part, une ligne par réglage.
C.5 Plus de tableaux à colonnes : cartes lisibles sur téléphone, couleurs du jeu, onglets non coupés.
C.6 Lot 3 de Luthécia : « Lot de la Châtaigneraie (2 300 m²) » est incohérent, renomme-le « Terrain à bâtir ».

Mise en œuvre (Claude, 24/11/2026, branche `claude/purge-c-20261124`) :
- Le plafond d'heures, le salaire, les prix et les plafonds de vente viennent du serveur : nouvelle lecture sans effet
  `chantier_fenetre_lire` (migration `20261124120000_chantier_fenetre_lire`), qui rejoue la vraie `chantier_travailler`
  dans une sous-transaction annulée. Gain affiché = heures choisies × salaire renvoyé par le serveur.
- Fenêtre : résumé en haut, emplacement du climat juste dessous (rempli par le module climat, bloc D), deux onglets
  « Participer » (par défaut : travailler, vendre) et « Avancement » (ancien « État » : image, jauges, journal) ;
  propriétaire : bouton « Gérer mon chantier », vue à part dans la même fenêtre (jamais une fenêtre par-dessus une autre),
  une ligne par réglage avec son seul bouton, « ← Retour au chantier ».
- Vente : une carte par matériau ; « Vendre … » et « Donner … gratuitement » sont deux boutons distincts (la case
  « Donner au lieu de vendre » disparaît).
- C.6 : le libellé n'existe que dans `data.js` (description de la pièce du lot 3) ; aucune donnée en base ni renvoi
  (quêtes, aide, i18n, bancs) ne le cite.
- Bancs : `banc-purge-c-chantier-20261124.cjs`, `banc-purge-c-chantier-navigateur-20261124.cjs` (390 et 1280 px),
  `banc-purge-c-chantier-pglite-20261124.cjs`.
