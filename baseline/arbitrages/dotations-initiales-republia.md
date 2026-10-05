# Tableau d'arbitrage 1 — dotations initiales de Républia

**À remplir par Fred.** Une ligne = une décision. La colonne
`montant_initial_a_arbitrer` est la seule à renseigner.

`valeur_actuelle_informative` sert à reconnaître le lieu, **pas** à suggérer une
réponse : c'est un solde de bêta. Aucun montant n'en a été déduit, et aucun n'a
été déduit du journal `dotations_amorcage_caisses`, qui dit ce qui *a été* versé
et non ce qui *doit* l'être.

Une seule ligne est préremplie, parce qu'elle est déjà arbitrée : le budget du
ministère de la Défense de Républia.

Périmètre : Républia uniquement. Les trois villes sont Luthécia (`capitale`),
Port-Sainte-Marie (`ville_a`) et Montrouge (`ville_b`).

Ce tableau couvre l'argent et les matières premières. Les bâtiments, commerces
et terrains sont dans le tableau 2, y compris les caisses qui vivent dans leur
blob — la frontière est posée pour que rien ne tombe entre les deux.

| categorie | entite | table | ville | identifiant_technique | role_dans_le_jeu | valeur_actuelle_informative | montant_initial_a_arbitrer | remarque |
|---|---|---|---|---|---|---|---|---|
| budget national | Reserve du jour | budgets_nationaux |  | republic.reserveJour | Reserve monetaire nationale du jour. | 0 |  |  |
| budget national | Taux national | budgets_nationaux |  | republic.tauxNational | Taux de prelevement national, en pourcentage. | 5 |  |  |
| budget national | Rations du refectoire | budgets_nationaux |  | republic.refectoire.rations | Nombre de rations disponibles au refectoire de la caserne. | 2 |  |  |
| matiere premiere | Caserne -- cereales | budgets_nationaux |  | republic.caserneMatieres.cereales | Stock de cereales detenu par la caserne, consomme par le refectoire et l'infirmerie. | 2 |  | NON COUVERT par l'arbitrage des matieres premieres du 5 octobre 2026, qui porte sur les ENTREPOTS DE VILLE. Ce stock-ci est celui de la caserne, et il est national, pas municipal. A arbitrer separement -- en gardant a l'esprit qu'un monde neuf n'a ni compagnie ni soldat au premier jour. |
| matiere premiere | Caserne -- desinfectant | budgets_nationaux |  | republic.caserneMatieres.desinfectant | Stock de desinfectant detenu par la caserne, consomme par le refectoire et l'infirmerie. | 0 |  | NON COUVERT par l'arbitrage des matieres premieres du 5 octobre 2026, qui porte sur les ENTREPOTS DE VILLE. Ce stock-ci est celui de la caserne, et il est national, pas municipal. A arbitrer separement -- en gardant a l'esprit qu'un monde neuf n'a ni compagnie ni soldat au premier jour. |
| matiere premiere | Caserne -- medicaments | budgets_nationaux |  | republic.caserneMatieres.medicaments | Stock de medicaments detenu par la caserne, consomme par le refectoire et l'infirmerie. | 0 |  | NON COUVERT par l'arbitrage des matieres premieres du 5 octobre 2026, qui porte sur les ENTREPOTS DE VILLE. Ce stock-ci est celui de la caserne, et il est national, pas municipal. A arbitrer separement -- en gardant a l'esprit qu'un monde neuf n'a ni compagnie ni soldat au premier jour. |
| matiere premiere | Caserne -- textile | budgets_nationaux |  | republic.caserneMatieres.textile | Stock de textile detenu par la caserne, consomme par le refectoire et l'infirmerie. | 0 |  | NON COUVERT par l'arbitrage des matieres premieres du 5 octobre 2026, qui porte sur les ENTREPOTS DE VILLE. Ce stock-ci est celui de la caserne, et il est national, pas municipal. A arbitrer separement -- en gardant a l'esprit qu'un monde neuf n'a ni compagnie ni soldat au premier jour. |
| matiere premiere | Caserne -- viande | budgets_nationaux |  | republic.caserneMatieres.viande | Stock de viande detenu par la caserne, consomme par le refectoire et l'infirmerie. | 2 |  | NON COUVERT par l'arbitrage des matieres premieres du 5 octobre 2026, qui porte sur les ENTREPOTS DE VILLE. Ce stock-ci est celui de la caserne, et il est national, pas municipal. A arbitrer separement -- en gardant a l'esprit qu'un monde neuf n'a ni compagnie ni soldat au premier jour. |
| equipement militaire | Armurerie nationale -- arme_de_poing | budgets_nationaux |  | republic.stockArmurerieMilitaire.arme_de_poing | Quantite de arme_de_poing en armurerie nationale, distribuable aux sections. | 0 |  | Stock a 0 et AUCUN lot enregistre : ni dotation initiale ni ajout. A decider. |
| equipement militaire | Armurerie nationale -- gilet_pare_balles | budgets_nationaux |  | republic.stockArmurerieMilitaire.gilet_pare_balles | Quantite de gilet_pare_balles en armurerie nationale, distribuable aux sections. | 0 |  | Stock a 0 et AUCUN lot enregistre : ni dotation initiale ni ajout. A decider. |
| equipement militaire | Armurerie nationale -- jumelles | budgets_nationaux |  | republic.stockArmurerieMilitaire.jumelles | Quantite de jumelles en armurerie nationale, distribuable aux sections. | 3 |  | PROVENANCE ECRITE : le registre des lots porte un lot nomme `dotation-initiale` de 1 unite(s). C'est la dotation voulue telle qu'elle a ete enregistree. Le reste du stock vient d'un autre lot (dotation-beta-2026-09-22 = 2, dotation-initiale = 1). A confirmer plutot qu'a redefinir. |
| equipement militaire | Armurerie nationale -- mitraillette | budgets_nationaux |  | republic.stockArmurerieMilitaire.mitraillette | Quantite de mitraillette en armurerie nationale, distribuable aux sections. | 0 |  | Stock a 0 et AUCUN lot enregistre : ni dotation initiale ni ajout. A decider. |
| equipement militaire | Armurerie nationale -- radio | budgets_nationaux |  | republic.stockArmurerieMilitaire.radio | Quantite de radio en armurerie nationale, distribuable aux sections. | 3 |  | AUCUN lot `dotation-initiale` pour cet article : la totalite du stock vient de lots posterieurs (dotation-beta-2026-09-22 = 3). La dotation voulue n'est donc pas lisible, elle doit etre decidee. |
| equipement militaire | Armurerie nationale -- tente | budgets_nationaux |  | republic.stockArmurerieMilitaire.tente | Quantite de tente en armurerie nationale, distribuable aux sections. | 1 |  | AUCUN lot `dotation-initiale` pour cet article : la totalite du stock vient de lots posterieurs (dotation-beta-2026-09-22 = 1). La dotation voulue n'est donc pas lisible, elle doit etre decidee. |
| equipement militaire | Armurerie nationale -- tenue_camouflage | budgets_nationaux |  | republic.stockArmurerieMilitaire.tenue_camouflage | Quantite de tenue_camouflage en armurerie nationale, distribuable aux sections. | 6 |  | PROVENANCE ECRITE : le registre des lots porte un lot nomme `dotation-initiale` de 1 unite(s). C'est la dotation voulue telle qu'elle a ete enregistree. Le reste du stock vient d'un autre lot (dotation-beta-2026-09-22 = 5, dotation-initiale = 1). A confirmer plutot qu'a redefinir. |
| agence privee | agence-grobras-securite | caisses_batiments |  | republic_agence-grobras-securite | Caisse d'une agence privee, reservee au serveur. | 0 |  |  |
| assemblee | assemblee | caisses_batiments |  | republic_assemblee | Caisse de l'Assemblee, par chemin serveur dedie. | 75763 |  |  |
| banque | banque-privee | caisses_batiments |  | republic_banque-privee | Caisse de la banque privee. | 0 |  |  |
| militaire | caserne-militaire | caisses_batiments |  | republic_caserne-militaire | Caisse de la caserne. Debitee par le Commandant et le ministre de la Defense. | 14900 |  |  |
| transport | centre-multinodal-luthecia | caisses_batiments | Luthecia | republic_centre-multinodal-luthecia | Caisse d'un centre multimodal. | 2568 |  |  |
| transport | centre-multinodal-montrouge | caisses_batiments | Montrouge | republic_centre-multinodal-montrouge | Caisse d'un centre multimodal. | 200 |  |  |
| transport | centre-multinodal-port-sainte-marie | caisses_batiments | Port-Sainte-Marie | republic_centre-multinodal-port-sainte-marie | Caisse d'un centre multimodal. | 320 |  |  |
| police | commissariat | caisses_batiments | Luthecia | republic_commissariat | Caisse d'un commissariat. | 0 |  |  |
| police | commissariat_capitale | caisses_batiments | Luthecia | republic_commissariat_capitale | Caisse d'un commissariat. | 71090 |  |  |
| police | commissariat_ville_a | caisses_batiments | Port-Sainte-Marie | republic_commissariat_ville_a | Caisse d'un commissariat. | 3322 |  |  |
| police | commissariat_ville_b | caisses_batiments | Montrouge | republic_commissariat_ville_b | Caisse d'un commissariat. | 2775 |  |  |
| police | commissariat-local | caisses_batiments |  | republic_commissariat-local | Caisse d'un commissariat. | 0 |  | Solde a 0 et aucune ville dans l'identifiant : ressemble a une ligne heritee d'avant la dimension ville. A qualifier avant d'arbitrer. |
| sante | dispensaire_capitale | caisses_batiments | Luthecia | republic_dispensaire_capitale | Caisse d'un dispensaire. | 3428 |  |  |
| sante | dispensaire_ville_a | caisses_batiments | Port-Sainte-Marie | republic_dispensaire_ville_a | Caisse d'un dispensaire. | 360 |  |  |
| sante | dispensaire_ville_b | caisses_batiments | Montrouge | republic_dispensaire_ville_b | Caisse d'un dispensaire. | 200 |  |  |
| sante | dispensaire-public | caisses_batiments | Luthecia | republic_dispensaire-public | Caisse d'un dispensaire. | 0 |  |  |
| sante | dispensaire-public-v | caisses_batiments |  | republic_dispensaire-public-v | Caisse d'un dispensaire. | 0 |  | Solde a 0 et aucune ville dans l'identifiant : ressemble a une ligne heritee d'avant la dimension ville. A qualifier avant d'arbitrer. |
| culte | eglise-montrouge | caisses_batiments | Montrouge | republic_eglise-montrouge | Caisse d'un lieu de culte ou de collecte. | 200 |  |  |
| ministere | gouvernement-min_ae | caisses_batiments |  | republic_gouvernement-min_ae | Caisse d'un ministere. Le poste est lu dans l'identifiant. | 66240 |  |  |
| ministere | gouvernement-min_def | caisses_batiments |  | republic_gouvernement-min_def | Caisse d'un ministere. Le poste est lu dans l'identifiant. | 62520 |  |  |
| ministere | gouvernement-min_fin | caisses_batiments |  | republic_gouvernement-min_fin | Caisse d'un ministere. Le poste est lu dans l'identifiant. | 66209 |  |  |
| ministere | gouvernement-min_info | caisses_batiments |  | republic_gouvernement-min_info | Caisse d'un ministere. Le poste est lu dans l'identifiant. | 55205 |  |  |
| ministere | gouvernement-min_int | caisses_batiments |  | republic_gouvernement-min_int | Caisse d'un ministere. Le poste est lu dans l'identifiant. | 82887 |  |  |
| ministere | gouvernement-min_just | caisses_batiments |  | republic_gouvernement-min_just | Caisse d'un ministere. Le poste est lu dans l'identifiant. | 66177 |  |  |
| ministere | gouvernement-pm | caisses_batiments |  | republic_gouvernement-pm | Caisse d'un ministere. Le poste est lu dans l'identifiant. | 88202 |  |  |
| hotellerie | hotel_capitale | caisses_batiments | Luthecia | republic_hotel_capitale | Caisse d'un hotel. | 792 |  |  |
| hotellerie | hotel_ville_a | caisses_batiments | Port-Sainte-Marie | republic_hotel_ville_a | Caisse d'un hotel. | 254 |  |  |
| hotellerie | hotel_ville_b | caisses_batiments | Montrouge | republic_hotel_ville_b | Caisse d'un hotel. | 200 |  |  |
| municipal | mairie_caserne | caisses_batiments |  | republic_mairie_caserne | Caisse d'une mairie. Debitee par le maire et son adjoint. | 0 |  |  |
| municipal | mairie_ville_a | caisses_batiments | Port-Sainte-Marie | republic_mairie_ville_a | Caisse d'une mairie. Debitee par le maire et son adjoint. | 5931 |  |  |
| municipal | mairie_ville_b | caisses_batiments | Montrouge | republic_mairie_ville_b | Caisse d'une mairie. Debitee par le maire et son adjoint. | 4168 |  |  |
| municipal | mairie-capitale | caisses_batiments | Luthecia | republic_mairie-capitale | Caisse d'une mairie. Debitee par le maire et son adjoint. | 102845 |  |  |
| commerce public | marche | caisses_batiments | Luthecia | republic_marche | Caisse d'un marche. | 0 |  |  |
| commerce public | marche_capitale | caisses_batiments | Luthecia | republic_marche_capitale | Caisse d'un marche. | 3885 |  |  |
| commerce public | marche_ville_a | caisses_batiments | Port-Sainte-Marie | republic_marche_ville_a | Caisse d'un marche. | 1620 |  |  |
| commerce public | marche_ville_b | caisses_batiments | Montrouge | republic_marche_ville_b | Caisse d'un marche. | 1468 |  |  |
| culte | notre-dame-mer | caisses_batiments | Port-Sainte-Marie | republic_notre-dame-mer | Caisse d'un lieu de culte ou de collecte. | 200 |  |  |
| notariat | office-notarial | caisses_batiments | Luthecia | republic_office-notarial | Caisse de l'office notarial. | 200 |  |  |
| gouvernement | palais-gouvernement | caisses_batiments | Luthecia | republic_palais-gouvernement | Caisse du siege du Premier ministre. | 0 |  |  |
| presidence | palais-presidentiel | caisses_batiments |  | republic_palais-presidentiel | Caisse de la Presidence. | 151797 |  |  |
| port | port-sainte-marie | caisses_batiments | Port-Sainte-Marie | republic_port-sainte-marie | Caisse de la capitainerie du port industriel. | 200 |  |  |
| justice | qhs-prison | caisses_batiments |  | republic_qhs-prison | Caisse du quartier de haute securite. | 200 |  |  |
| reserve | reserve-nationale | caisses_batiments |  | republic_reserve-nationale | Reserve nationale, debitee par le ministre des Finances. | 18939 |  |  |
| sport | stade | caisses_batiments |  | republic_stade | Caisse d'un stade ou de sa buvette. | 0 |  | Solde a 0 et aucune ville dans l'identifiant : ressemble a une ligne heritee d'avant la dimension ville. A qualifier avant d'arbitrer. |
| sport | stade_capitale | caisses_batiments | Luthecia | republic_stade_capitale | Caisse d'un stade ou de sa buvette. | 2614 |  |  |
| sport | stade_ville_a | caisses_batiments | Port-Sainte-Marie | republic_stade_ville_a | Caisse d'un stade ou de sa buvette. | 320 |  |  |
| sport | stade_ville_b | caisses_batiments | Montrouge | republic_stade_ville_b | Caisse d'un stade ou de sa buvette. | 200 |  |  |
| sport | stade-buvette | caisses_batiments | Luthecia | republic_stade-buvette | Caisse d'un stade ou de sa buvette. | 88 |  |  |
| culte | tabernacle-impots | caisses_batiments | Luthecia | republic_tabernacle-impots | Caisse d'un lieu de culte ou de collecte. | 200 |  |  |
| justice | tribunal | caisses_batiments | Luthecia | republic_tribunal | Caisse d'un tribunal. | 0 |  |  |
| justice | tribunal_capitale | caisses_batiments | Luthecia | republic_tribunal_capitale | Caisse d'un tribunal. | 54365 |  |  |
| justice | tribunal_ville_a | caisses_batiments | Port-Sainte-Marie | republic_tribunal_ville_a | Caisse d'un tribunal. | 3080 |  |  |
| justice | tribunal_ville_b | caisses_batiments | Montrouge | republic_tribunal_ville_b | Caisse d'un tribunal. | 2092 |  |  |
| justice | tribunal-local | caisses_batiments |  | republic_tribunal-local | Caisse d'un tribunal. | 0 |  | Solde a 0 et aucune ville dans l'identifiant : ressemble a une ligne heritee d'avant la dimension ville. A qualifier avant d'arbitrer. |
| budget municipal | Caisse -- Luthecia | budgets_municipaux | Luthecia | republic_capitale.caisse | Caisse de la municipalite. | 400 |  |  |
| budget municipal | Caisse -- caserne | budgets_municipaux |  | republic_caserne.caisse | Caisse de la municipalite. | 0 |  | Cette ligne n'est pas une ville : elle porte le budget de la caserne. A confirmer avant d'arbitrer. |
| budget municipal | Taux foncier -- caserne | budgets_municipaux |  | republic_caserne.tauxFoncier | Taux de la taxe fonciere municipale. | 0.05 |  |  |
| budget municipal | Caisse -- Port-Sainte-Marie | budgets_municipaux | Port-Sainte-Marie | republic_ville_a.caisse | Caisse de la municipalite. | 12 |  |  |
| budget municipal | Caisse -- Montrouge | budgets_municipaux | Montrouge | republic_ville_b.caisse | Caisse de la municipalite. | 0 |  |  |
| budget municipal | Taux foncier -- Montrouge | budgets_municipaux | Montrouge | republic_ville_b.tauxFoncier | Taux de la taxe fonciere municipale. | 0.05 |  |  |
| club sportif | La Brise Mariannaise | budgets_clubs | Port-Sainte-Marie | brise-mariannaise | Caisse du club de football. | 0 |  | Le bareme de salaires (titulaire / remplacant / prime de victoire) est identique sur les 12 clubs des 4 empires : il releve du socle et n'a pas a etre arbitre ici. |
| club sportif | Union Cheminote de Montrouge | budgets_clubs | Montrouge | cheminote-montrouge | Caisse du club de football. | 0 |  | Le bareme de salaires (titulaire / remplacant / prime de victoire) est identique sur les 12 clubs des 4 empires : il releve du socle et n'a pas a etre arbitre ici. |
| club sportif | Olympique de Luthécia | budgets_clubs | Luthecia | olympique-luthecia | Caisse du club de football. | 0 |  | Le bareme de salaires (titulaire / remplacant / prime de victoire) est identique sur les 12 clubs des 4 empires : il releve du socle et n'a pas a etre arbitre ici. |
| matiere premiere | Entrepots de ville -- alcool | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.alcool | Stock de alcool dans l'entrepot logistique de chaque ville. | Luthecia=100, Port-Sainte-Marie=100, Montrouge=100 | 100 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=100, Port-Sainte-Marie=100, Montrouge=100) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- bois | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.bois | Stock de bois dans l'entrepot logistique de chaque ville. | Luthecia=750, Port-Sainte-Marie=750, Montrouge=750 | 750 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=750, Port-Sainte-Marie=750, Montrouge=750) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- carburant | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.carburant | Stock de carburant dans l'entrepot logistique de chaque ville. | Luthecia=17, Port-Sainte-Marie=17, Montrouge=17 | 17 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=17, Port-Sainte-Marie=17, Montrouge=17) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- cereales | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.cereales | Stock de cereales dans l'entrepot logistique de chaque ville. | Luthecia=73, Port-Sainte-Marie=70, Montrouge=74 | 75 | ARBITRE. La bêta avait DERIVE selon la ville (Luthecia=73, Port-Sainte-Marie=70, Montrouge=74) : la valeur d'origine n'y etait plus lisible, elle est donc fixee. |
| matiere premiere | Entrepots de ville -- charbon | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.charbon | Stock de charbon dans l'entrepot logistique de chaque ville. | Luthecia=400, Port-Sainte-Marie=400, Montrouge=400 | 400 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=400, Port-Sainte-Marie=400, Montrouge=400) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- desinfectant | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.desinfectant | Stock de desinfectant dans l'entrepot logistique de chaque ville. | Luthecia=32, Port-Sainte-Marie=32, Montrouge=32 | 32 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=32, Port-Sainte-Marie=32, Montrouge=32) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- fruits_legumes | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.fruits_legumes | Stock de fruits_legumes dans l'entrepot logistique de chaque ville. | Luthecia=150, Port-Sainte-Marie=150, Montrouge=150 | 150 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=150, Port-Sainte-Marie=150, Montrouge=150) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- medicaments | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.medicaments | Stock de medicaments dans l'entrepot logistique de chaque ville. | Luthecia=21, Port-Sainte-Marie=20, Montrouge=23 | 25 | ARBITRE. La bêta avait DERIVE selon la ville (Luthecia=21, Port-Sainte-Marie=20, Montrouge=23) : la valeur d'origine n'y etait plus lisible, elle est donc fixee. |
| matiere premiere | Entrepots de ville -- metal | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.metal | Stock de metal dans l'entrepot logistique de chaque ville. | Luthecia=200, Port-Sainte-Marie=200, Montrouge=200 | 200 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=200, Port-Sainte-Marie=200, Montrouge=200) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- minerai | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.minerai | Stock de minerai dans l'entrepot logistique de chaque ville. | Luthecia=500, Port-Sainte-Marie=500, Montrouge=500 | 500 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=500, Port-Sainte-Marie=500, Montrouge=500) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- petrole | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.petrole | Stock de petrole dans l'entrepot logistique de chaque ville. | Luthecia=200, Port-Sainte-Marie=200, Montrouge=200 | 200 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=200, Port-Sainte-Marie=200, Montrouge=200) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- plantes | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.plantes | Stock de plantes dans l'entrepot logistique de chaque ville. | Luthecia=300, Port-Sainte-Marie=300, Montrouge=300 | 300 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=300, Port-Sainte-Marie=300, Montrouge=300) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- poisson | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.poisson | Stock de poisson dans l'entrepot logistique de chaque ville. | Luthecia=125, Port-Sainte-Marie=125, Montrouge=125 | 125 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=125, Port-Sainte-Marie=125, Montrouge=125) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- produits_exotiques | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.produits_exotiques | Stock de produits_exotiques dans l'entrepot logistique de chaque ville. | Luthecia=125, Port-Sainte-Marie=125, Montrouge=125 | 125 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=125, Port-Sainte-Marie=125, Montrouge=125) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- tabac | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.tabac | Stock de tabac dans l'entrepot logistique de chaque ville. | Luthecia=32, Port-Sainte-Marie=22, Montrouge=26 | 30 | ARBITRE. La bêta avait DERIVE selon la ville (Luthecia=32, Port-Sainte-Marie=22, Montrouge=26) : la valeur d'origine n'y etait plus lisible, elle est donc fixee. |
| matiere premiere | Entrepots de ville -- textile | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.textile | Stock de textile dans l'entrepot logistique de chaque ville. | Luthecia=125, Port-Sainte-Marie=125, Montrouge=125 | 125 | ARBITRE. La bêta portait deja cette valeur a l'identique sur les trois villes (Luthecia=125, Port-Sainte-Marie=125, Montrouge=125) : elle est confirmee, pas deduite. |
| matiere premiere | Entrepots de ville -- viande | batiments_etat | les 3 villes | entrepot-logistique-*.entrepot.stock.viande | Stock de viande dans l'entrepot logistique de chaque ville. | Luthecia=83, Port-Sainte-Marie=83, Montrouge=84 | 85 | ARBITRE. La bêta avait DERIVE selon la ville (Luthecia=83, Port-Sainte-Marie=83, Montrouge=84) : la valeur d'origine n'y etait plus lisible, elle est donc fixee. |
| caisse d'entrepot | Entrepot de Luthecia | batiments_etat | Luthecia | entrepot-logistique-luthecia.entrepot.caisse | Caisse de l'entrepot logistique, qui achete et revend les matieres. | 4900 |  |  |
| caisse d'entrepot | Entrepot de Port-Sainte-Marie | batiments_etat | Port-Sainte-Marie | entrepot-logistique-psm.entrepot.caisse | Caisse de l'entrepot logistique, qui achete et revend les matieres. | 4559 |  |  |
| caisse d'entrepot | Entrepot de Montrouge | batiments_etat | Montrouge | entrepot-logistique-montrouge.entrepot.caisse | Caisse de l'entrepot logistique, qui achete et revend les matieres. | 4494.5 |  |  |

## Lignes écartées de ce tableau, et pourquoi

Elles existent toujours en base. Elles ne sont pas à arbitrer, mais vous devez savoir qu'elles existent : rien n'est écarté en silence.

| source | ligne | raison |
|---|---|---|
| tableau 1 / caisses_batiments | `republic_commissariat_zzville-cmr` | Identifiant portant un marqueur de test. N'appartient pas au monde initial : il n'y a donc rien a arbitrer. La ligne existe toujours en base. |
