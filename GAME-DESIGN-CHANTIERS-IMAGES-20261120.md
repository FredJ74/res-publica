# Chantier de construction : images par étape et par ville — consigne intégrale

Décisions de Fred du 20/11/2026, consignées mot pour mot avant tout code. À prendre après la distillerie et le lot de Krasnov.

---

1. BUG À CORRIGER : après le lancement d'un chantier (test réel d'Arnie, terrain 3 de Luthécia, 20/11), l'image et l'état du terrain ne se sont mis à jour qu'après un clic sur un bouton. Règle de Fred : jamais besoin de recharger la page. Le lancement, la progression de nuit et la réception doivent se refléter immédiatement à l'écran.

2. IMAGES PAR ÉTAPE, PAR VILLE ET PAR GABARIT
- Une série par ville (style propre à la ville, sans coller à la géographie exacte du terrain) : Luthécia, Montrouge, Port-Sainte-Marie ; prévoir la même structure pour les villes des autres empires.
- Étape selon la progression du chantier : fondations (moins d'un tiers), gros œuvre (du tiers aux deux tiers), façade et finitions (au-delà des deux tiers), puis achevé (après réception).
- Fondations : une image par ville, commune à tous les types de bâtiment.
- Gros œuvre et façade : deux gabarits par ville. Bas = hangar, commerce standard, commerce premium, logements sociaux petit. Haut = building, logements moyen, barre d'immeuble.
- Achevé : une image finale par ville et par type de bâtiment, sans encarts.
- Les fiches actuelles avec encarts (building-construction-terrain.webp, etc.) restent l'illustration du choix du bâtiment à construire, avant le lancement.
- Convention de fichiers, pour que Fred puisse déposer les images sans nouveau code : images/chantiers/<ville>/fondations.webp, gros-oeuvre-bas.webp, gros-oeuvre-haut.webp, facade-bas.webp, facade-haut.webp, final-<palier>.webp (ville = luthecia, montrouge, psm…). Si un fichier manque, repli sur l'image actuelle.
- L'image actuelle du chantier en cours (incrustations « 47 % », « élévation R+2 », « fin prévisionnelle 12/01/2027 ») affiche de fausses informations : elle ne doit plus servir que de repli provisoire, et l'état réel du chantier doit rester lisible dans l'interface du jeu.

3. Fred fournira les images au fur et à mesure (fondations de Luthécia déjà faite, transmise depuis claude.ai). Chantier d'image seule ensuite : fusion sans attendre le contrôle long.

---

# Complément du 21/11/2026 : refonte de l'ergonomie du chantier — consigne intégrale

Construction : refonte de l'ergonomie du chantier (validée par Fred le 21/11, à tester puis ajuster). À traiter avec le chantier des images par étape déjà transmis.

Constat (test réel d'Arnie, terrain 3 de Luthécia) : les ordres sont éparpillés et se recoupent (« Information sur le chantier », « Information et approvisionnement du chantier » ▾, « Approvisionner le chantier », « Travail et division des lots » ▾, « Salaire horaire des ouvriers », « Prix d'achat des matériaux ») ; plateau-construction-commandes.js et plateau-politique.js. La fenêtre des prix n'a ni mise en forme, ni accents (« metal »), ni explication, et l'état réel du chantier n'est affiché nulle part.

Nouvelle interface : UN seul ordre « Le chantier » ouvrant UNE fenêtre, sur le modèle de la fenêtre du marché de Krasnov, en trois parties.
1. ÉTAT (tous) : vraie barre de progression (jour X / durée, %), trésorerie, stock de matériaux face aux besoins, heures faites / heures totales, prochain appel de fonds, salaire horaire en vigueur, prix de rachat des matériaux. Toutes les valeurs viennent du serveur.
2. PARTICIPER (tous) : travailler sur le chantier (nombre d'heures, 1 PA par heure, salaire affiché) ; vendre des matériaux au chantier (quantité par matière, prix unitaire et total) ; donner des matériaux.
3. GESTION (maître d'ouvrage seul) : prix de rachat de bois / minerai / métal (avec une phrase expliquant que c'est le prix auquel le chantier rachète les matériaux aux joueurs), salaire horaire (minimum 50 FR), apport de fonds, définition des lots, puis « Réceptionner le bâtiment » une fois le chantier terminé.
- En bas : Annuler / Valider, totaux en direct (PA, argent), Valider grisé avec infobulle explicative si les PA, l'argent, le stock ou la trésorerie ne suffisent pas. Rien n'est exécuté à moitié.
- Supprimer les anciens ordres et menus déroulants qui font doublon. Le vol de matériaux reste un ordre à part (acte illégal, règles communes du vol).
- Mise à jour immédiate de la fenêtre et de l'image après chaque action, sans recharger la page.
- Libellés propres, accentués, traduits (clés pour Codex dans RELAIS).
- Ne change aucune règle serveur (coûts, taux, appels de fonds) : c'est une refonte d'interface.

Après livraison, Fred teste avec Arnie et on ajuste.

---

# Complément du 21/11/2026 : accélération du chantier par le travail des joueurs — consigne intégrale

Construction : accélération du chantier par le travail des joueurs (décision de Fred, 21/11). À intégrer au chantier « construction » déjà transmis (images par étape + fenêtre unique « Le chantier »).

Règle actuelle (chantier_travailler / chantier_jour_traiter) : 1 jour d'avancement par nuit au maximum ; capacité = coutTravail / taux / durée (50 h par jour pour un building) ; les heures faites par les joueurs remplacent celles des PNJ, sans aucun gain de vitesse.

Nouvelle règle :
- Quand les heures du jour en cours ont toutes été faites par des joueurs, les heures du jour suivant s'ouvrent aussitôt (jour d'avance). Les joueurs peuvent y travailler dans la journée, aux mêmes conditions (1 PA par heure, salaire fixé par le propriétaire, payé par la trésorerie).
- À minuit, si un jour d'avance a été ouvert : les PNJ terminent les heures restantes du jour d'avance (payées comme aujourd'hui), et le chantier avance de DEUX jours au lieu d'un.
- Limite stricte : un seul jour d'avance par jour. Une fois le jour d'avance complet, plus aucune heure n'est disponible jusqu'à minuit. Un chantier va donc au plus deux fois plus vite (12 jours au minimum pour un building de 24 jours). Ne pas ouvrir de troisième jour (l'accélération au-delà est réservée au P2W des futurs empires).
- Garde-fous inchangés : le jour d'avance exige les matériaux des deux jours (sinon avancement proportionnel, comme aujourd'hui) et respecte les paliers d'appel de fonds (pas de dépassement du tiers sans les 70 %, ni des deux tiers sans les 100 %). Le coût total du chantier ne change pas : on paie plus vite, pas plus.
- Fenêtre « Le chantier », partie ÉTAT : afficher les heures du jour faites / restantes, si le jour d'avance est ouvert et ses heures restantes, et une phrase explicative du type « Si les joueurs terminent les heures du jour, le jour suivant s'ouvre en avance : le chantier gagne une journée cette nuit. »
- Journal du chantier / événements : signaler les nuits où un jour a été gagné.
- Bancs : jour normal ; jour complet sans avance ; jour d'avance partiellement fait puis complété par les PNJ (+2 jours) ; tentative d'ouvrir un troisième jour refusée ; matériaux insuffisants pour deux jours ; palier d'appel de fonds non versé.
