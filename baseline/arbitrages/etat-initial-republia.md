# Tableau d'arbitrage 2 — état initial des lieux de Républia

**À remplir par Fred.** Une ligne = un champ d'état initial qui
demande vraiment une décision. Les champs purement techniques et les champs
dérivés ne sont pas listés.

`etat_actuel_informatif` est l'état de la bêta : il n'est **pas** une proposition.
`proposition_si_valeur_authored` n'est rempli que là où une valeur d'origine est
clairement identifiable (surface d'un terrain, autorisation de construire…).

Les lignes de test et celles créées par un joueur pendant la bêta sont signalées
plutôt que supprimées : elles n'ont pas à être arbitrées, mais vous devez savoir
qu'elles existent.

Périmètre : Républia uniquement.

| type | nom_lisible | identifiant_technique | ville | champ_a_arbitrer | etat_actuel_informatif | proposition_si_valeur_authored | decision_finale | remarque |
|---|---|---|---|---|---|---|---|---|
| batiment | centre-affaires (redaction) | centre-affaires | Luthecia | redaction.caisse | 0 |  |  | Caisse de ce volet du batiment. |
| batiment | clinique-privee (sante) | clinique-privee | Luthecia | sante.caisse | 178 |  |  | Caisse de ce volet du batiment. |
| batiment | clinique-privee (sante) | clinique-privee | Luthecia | sante.stockMatieres | {"medicaments": 2} |  |  | Etat consomme en partie : la valeur actuelle n'est pas un etat initial. |
| batiment | clinique-privee (sante) | clinique-privee | Luthecia | sante.coutMoyenMatieres | {"medicaments": 11} |  |  | Etat consomme en partie : la valeur actuelle n'est pas un etat initial. |
| batiment | entrepot-logistique-luthecia (entrepot) | entrepot-logistique-luthecia | Luthecia | entrepot.caisse | 4900 |  |  | Caisse de ce volet du batiment. |
| batiment | entrepot-logistique-luthecia (entrepot) | entrepot-logistique-luthecia | Luthecia | entrepot.stock | {"bois": 750, "metal": 200, "tabac": 32, "alcool": 100, "viande": 83, "charbon": 400, "minerai": 500, "petrole": 200, "plantes": 300, "poisson": 125, "textile": 125, "cereales": 73, "carburant": 17, "medicaments": 21, "desinfectant": 32, "fruits_legumes": 150, "produits_exotiques": 125} |  |  | Stock. Pour le port, il accumule les arrivages quotidiens : la valeur actuelle n'est PAS un etat initial. |
| batiment | la-tribune (imprimerie) | la-tribune | Luthecia | imprimerie.caisse | 178 |  |  | Caisse de ce volet du batiment. |
| batiment | la-tribune (imprimerie) | la-tribune | Luthecia | imprimerie.stockBois | 4 |  |  | Etat consomme en partie : la valeur actuelle n'est pas un etat initial. |
| batiment | la-tribune (redaction) | la-tribune | Luthecia | redaction.caisse | 0 |  |  | Caisse de ce volet du batiment. |
| batiment | usine-pharmaceutique-luthecia (usine) | usine-pharmaceutique-luthecia | Luthecia | usine.caisse | 1656 |  |  | Caisse de ce volet du batiment. |
| batiment | usine-pharmaceutique-luthecia (usine) | usine-pharmaceutique-luthecia | Luthecia | usine.stockMatieres | {"alcool": 6, "plantes": 0} |  |  | Etat consomme en partie : la valeur actuelle n'est pas un etat initial. |
| batiment | usine-pharmaceutique-luthecia (usine) | usine-pharmaceutique-luthecia | Luthecia | usine.venteDirecte | {"medicaments": 50, "desinfectant": 32} |  |  | Prix de vente directe. Ressemble a une valeur authored : a confirmer plutot qu'a redefinir. |
| batiment | centre-affaires (redaction) | centre-affaires | Port-Sainte-Marie | redaction.caisse | 0 |  |  | Caisse de ce volet du batiment. |
| batiment | entrepot-logistique-psm (entrepot) | entrepot-logistique-psm | Port-Sainte-Marie | entrepot.caisse | 4559 |  |  | Caisse de ce volet du batiment. |
| batiment | entrepot-logistique-psm (entrepot) | entrepot-logistique-psm | Port-Sainte-Marie | entrepot.stock | {"bois": 750, "metal": 200, "tabac": 22, "alcool": 100, "viande": 83, "charbon": 400, "minerai": 500, "petrole": 200, "plantes": 300, "poisson": 125, "textile": 125, "cereales": 70, "carburant": 17, "medicaments": 20, "desinfectant": 32, "fruits_legumes": 150, "produits_exotiques": 125} |  |  | Stock. Pour le port, il accumule les arrivages quotidiens : la valeur actuelle n'est PAS un etat initial. |
| batiment | imprimerie-librairie (imprimerie) | imprimerie-librairie | Port-Sainte-Marie | imprimerie.caisse | 200 |  |  | Caisse de ce volet du batiment. |
| batiment | pole-tabac-alcools-psm (usine) | pole-tabac-alcools-psm | Port-Sainte-Marie | usine.caisse | 3499 |  |  | Caisse de ce volet du batiment. |
| batiment | pole-tabac-alcools-psm (usine) | pole-tabac-alcools-psm | Port-Sainte-Marie | usine.stockMatieres | {"plantes": 4, "cereales": 142} |  |  | Etat consomme en partie : la valeur actuelle n'est pas un etat initial. |
| batiment | pole-tabac-alcools-psm (usine) | pole-tabac-alcools-psm | Port-Sainte-Marie | usine.venteDirecte | {"tabac": 50, "alcool": 48} |  |  | Prix de vente directe. Ressemble a une valeur authored : a confirmer plutot qu'a redefinir. |
| batiment | port-sainte-marie (port) | port-sainte-marie | Port-Sainte-Marie | port.stock | {"bois": 11386, "produits_exotiques": 308} |  |  | Stock. Pour le port, il accumule les arrivages quotidiens : la valeur actuelle n'est PAS un etat initial. |
| batiment | centre-affaires (redaction) | centre-affaires | Montrouge | redaction.caisse | 0 |  |  | Caisse de ce volet du batiment. |
| batiment | entrepot-logistique-montrouge (entrepot) | entrepot-logistique-montrouge | Montrouge | entrepot.caisse | 4494.5 |  |  | Caisse de ce volet du batiment. |
| batiment | entrepot-logistique-montrouge (entrepot) | entrepot-logistique-montrouge | Montrouge | entrepot.stock | {"bois": 750, "metal": 200, "tabac": 26, "alcool": 100, "viande": 84, "charbon": 400, "minerai": 500, "petrole": 200, "plantes": 300, "poisson": 125, "textile": 125, "cereales": 74, "carburant": 17, "medicaments": 23, "desinfectant": 32, "fruits_legumes": 150, "produits_exotiques": 125} |  |  | Stock. Pour le port, il accumule les arrivages quotidiens : la valeur actuelle n'est PAS un etat initial. |
| batiment | la-tribune (imprimerie) | la-tribune | Montrouge | imprimerie.caisse | 200 |  |  | Caisse de ce volet du batiment. |
| batiment | la-tribune (imprimerie) | la-tribune | Montrouge | imprimerie.stockBois | 0 |  |  | Etat consomme en partie : la valeur actuelle n'est pas un etat initial. |
| batiment | la-tribune (redaction) | la-tribune | Montrouge | redaction.caisse | 0 |  |  | Caisse de ce volet du batiment. |
| batiment | raffinerie-montrouge (usine) | raffinerie-montrouge | Montrouge | usine.caisse | 2680 |  |  | Caisse de ce volet du batiment. |
| batiment | raffinerie-montrouge (usine) | raffinerie-montrouge | Montrouge | usine.stockMatieres | {"petrole": 6} |  |  | Etat consomme en partie : la valeur actuelle n'est pas un etat initial. |
| batiment | raffinerie-montrouge (usine) | raffinerie-montrouge | Montrouge | usine.venteDirecte | {"carburant": 34} |  |  | Prix de vente directe. Ressemble a une valeur authored : a confirmer plutot qu'a redefinir. |
| commerce | armurerie-republic-capitale | armurerie-republic-capitale | Luthecia | caisse | 30686 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | armurerie-republic-capitale | armurerie-republic-capitale | Luthecia | stockMatieres | {"bois": 2, "metal": 7} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | armurerie-republic-capitale | armurerie-republic-capitale | Luthecia | stockProduits | {"couteau": 0, "revolver": 0, "carabine_chasse": 1} |  |  | Produits finis en rayon. Un commerce neuf en a-t-il, ou part-il a vide ? |
| commerce | brasserie-republic-capitale-hotel-republica | brasserie-republic-capitale-hotel-republica | Luthecia | caisse | 5628.5 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | brasserie-republic-capitale-hotel-republica | brasserie-republic-capitale-hotel-republica | Luthecia | stockMatieres | {"viande": 12, "poisson": 7, "cereales": 21, "fruits_legumes": 19, "produits_exotiques": 11} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | brasserie-republic-capitale-hotel-republica | brasserie-republic-capitale-hotel-republica | Luthecia | stockProduits | {"vin": 15, "biere_pression": 15, "boisson_sans_alcool": 10, "menu_gastronomique_1": 10, "menu_gastronomique_2": 5, "menu_gastronomique_3": 4} |  |  | Produits finis en rayon. Un commerce neuf en a-t-il, ou part-il a vide ? |
| commerce | buvette-republic-capitale-stade-buvette | buvette-republic-capitale-stade-buvette | Luthecia | caisse | 0 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | buvette-republic-capitale-stade-buvette | buvette-republic-capitale-stade-buvette | Luthecia | stockMatieres | {"alcool": 10, "cereales": 5} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | marche-republic-capitale-marche | marche-republic-capitale-marche | Luthecia | caisse | 0 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | marche-republic-capitale-marche | marche-republic-capitale-marche | Luthecia | stockMatieres | {"bois": 9, "metal": 10, "viande": 8, "textile": 10, "cereales": 8, "fruits_legumes": 8, "produits_exotiques": 10} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | marche-republic-capitale-marche | marche-republic-capitale-marche | Luthecia | stockProduits | {"croque_monsieur_luthecia": 8, "carte_luthecia_institutions": 16} |  |  | Produits finis en rayon. Un commerce neuf en a-t-il, ou part-il a vide ? |
| commerce | armurerie-republic-ville_a | armurerie-republic-ville_a | Port-Sainte-Marie | caisse | 20000 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | armurerie-republic-ville_a | armurerie-republic-ville_a | Port-Sainte-Marie | stockMatieres | {"bois": 10, "metal": 20} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | bar-republic-ville_a-bar-des-pecheurs-salle_bar | bar-republic-ville_a-bar-des-pecheurs-salle_bar | Port-Sainte-Marie | caisse | 2000 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | bar-republic-ville_a-bar-des-pecheurs-salle_bar | bar-republic-ville_a-bar-des-pecheurs-salle_bar | Port-Sainte-Marie | stockMatieres | {"cereales": 10, "fruits_legumes": 10, "produits_exotiques": 10} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | brasserie-republic-ville_a-capitaine-sauvage-salle_principale | brasserie-republic-ville_a-capitaine-sauvage-salle_principale | Port-Sainte-Marie | caisse | 2800 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | brasserie-republic-ville_a-capitaine-sauvage-salle_principale | brasserie-republic-ville_a-capitaine-sauvage-salle_principale | Port-Sainte-Marie | stockMatieres | {"viande": 9, "poisson": 7, "cereales": 12, "fruits_legumes": 7} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | brasserie-republic-ville_a-capitaine-sauvage-salle_principale | brasserie-republic-ville_a-capitaine-sauvage-salle_principale | Port-Sainte-Marie | stockProduits | {"vin": 15, "menu_psm_1": 6, "menu_psm_2": 6, "menu_psm_3": 6} |  |  | Produits finis en rayon. Un commerce neuf en a-t-il, ou part-il a vide ? |
| commerce | marche-republic-ville_a-marche-psm-etals | marche-republic-ville_a-marche-psm-etals | Port-Sainte-Marie | caisse | 0 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | marche-republic-ville_a-marche-psm-etals | marche-republic-ville_a-marche-psm-etals | Port-Sainte-Marie | stockMatieres | {"bois": 10, "poisson": 10, "textile": 10, "cereales": 10} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | armurerie-republic-ville_b | armurerie-republic-ville_b | Montrouge | caisse | 20000 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | armurerie-republic-ville_b | armurerie-republic-ville_b | Montrouge | stockMatieres | {"bois": 10, "metal": 20} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | brasserie-republic-ville_b-brasserie-voyageurs-montrouge | brasserie-republic-ville_b-brasserie-voyageurs-montrouge | Montrouge | caisse | 2942 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | brasserie-republic-ville_b-brasserie-voyageurs-montrouge | brasserie-republic-ville_b-brasserie-voyageurs-montrouge | Montrouge | stockMatieres | {"viande": 13, "poisson": 10, "cereales": 13} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | brasserie-republic-ville_b-brasserie-voyageurs-montrouge | brasserie-republic-ville_b-brasserie-voyageurs-montrouge | Montrouge | stockProduits | {"saucisse_puree": 4, "carbonade_frites": 4} |  |  | Produits finis en rayon. Un commerce neuf en a-t-il, ou part-il a vide ? |
| commerce | cafe-republic-ville_b-cafe-gare-montrouge | cafe-republic-ville_b-cafe-gare-montrouge | Montrouge | caisse | 1733.5 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | cafe-republic-ville_b-cafe-gare-montrouge | cafe-republic-ville_b-cafe-gare-montrouge | Montrouge | stockMatieres | {"viande": 7, "cereales": 11, "fruits_legumes": 8, "produits_exotiques": 9} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | cafe-republic-ville_b-cafe-gare-montrouge | cafe-republic-ville_b-cafe-gare-montrouge | Montrouge | stockProduits | {"vin": 12, "cafe_boisson": 14, "jus_de_fruits": 15, "biere_pression": 12, "boeuf_bourguignon": 13} |  |  | Produits finis en rayon. Un commerce neuf en a-t-il, ou part-il a vide ? |
| commerce | cafe-republic-ville_b-cafe-tabac-cheminots-montrouge | cafe-republic-ville_b-cafe-tabac-cheminots-montrouge | Montrouge | caisse | 1856 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | cafe-republic-ville_b-cafe-tabac-cheminots-montrouge | cafe-republic-ville_b-cafe-tabac-cheminots-montrouge | Montrouge | stockMatieres | {"viande": 8, "cereales": 7, "fruits_legumes": 9, "produits_exotiques": 10} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | cafe-republic-ville_b-cafe-tabac-cheminots-montrouge | cafe-republic-ville_b-cafe-tabac-cheminots-montrouge | Montrouge | stockProduits | {"vin": 14, "biere_pression": 14, "boeuf_bourguignon": 3, "sandwich_cheminots": 5} |  |  | Produits finis en rayon. Un commerce neuf en a-t-il, ou part-il a vide ? |
| commerce | cafe-republic-ville_b-hotel-mineur | cafe-republic-ville_b-hotel-mineur | Montrouge | caisse | 1000 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | cafe-republic-ville_b-hotel-mineur | cafe-republic-ville_b-hotel-mineur | Montrouge | stockMatieres | {"cereales": 10} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | marche-republic-ville_b-marche | marche-republic-ville_b-marche | Montrouge | caisse | 0 |  |  | Une dotation de caisse par type de commerce existe deja, authored, dans commerces_dotations : verifier si elle suffit avant d'arbitrer. |
| commerce | marche-republic-ville_b-marche | marche-republic-ville_b-marche | Montrouge | stockMatieres | {"bois": 10, "viande": 10, "textile": 8, "cereales": 10} |  |  | Une dotation de stock par type existe deja dans commerces_dotations. |
| commerce | marche-republic-ville_b-marche | marche-republic-ville_b-marche | Montrouge | stockProduits | {"casquette_montrouge": 5} |  |  | Produits finis en rayon. Un commerce neuf en a-t-il, ou part-il a vide ? |
| commerce | armurerie-republic | armurerie-republic |  | existence | ville et batiment absents |  |  | LIGNE SANS VILLE NI BATIMENT : ressemble a un reste d'avant la dimension ville. A qualifier avant d'arbitrer, pas a seeder. |
| commerce | Aux Souvenirs d'Arnie | fonds-republic-1790594742432-237945 |  | existence | proprietaire = Arnie, statut = actif |  |  | FONDS DE COMMERCE CREE PAR UN JOUEUR pendant la bêta. Ne fait pas partie du monde initial : rien a arbitrer. A ne pas seeder. |
| terrain | terrain-a-batir-1 | terrain-a-batir-1 | Luthecia | proprietaire |  |  |  | Un terrain appartient-il a quelqu'un au premier jour, ou est-il libre ? |
| terrain | terrain-a-batir-1 | terrain-a-batir-1 | Luthecia | constructionAutorisee | true | true |  | Valeur authored vraisemblable : a confirmer. |
| terrain | terrain-a-batir-1 | terrain-a-batir-1 | Luthecia | valeur_totale | 25800 | 25800 |  | Valeur authored vraisemblable (surface x prix) : a confirmer. |
| terrain | terrain-a-batir-2 | terrain-a-batir-2 | Luthecia | proprietaire |  |  |  | Un terrain appartient-il a quelqu'un au premier jour, ou est-il libre ? |
| terrain | terrain-a-batir-2 | terrain-a-batir-2 | Luthecia | constructionAutorisee | true | true |  | Valeur authored vraisemblable : a confirmer. |
| terrain | terrain-a-batir-2 | terrain-a-batir-2 | Luthecia | valeur_totale | 27600 | 27600 |  | Valeur authored vraisemblable (surface x prix) : a confirmer. |
| terrain | terrain-a-batir-3 | terrain-a-batir-3 | Luthecia | proprietaire |  |  |  | Un terrain appartient-il a quelqu'un au premier jour, ou est-il libre ? |
| terrain | terrain-a-batir-3 | terrain-a-batir-3 | Luthecia | constructionAutorisee | true | true |  | Valeur authored vraisemblable : a confirmer. |
| terrain | terrain-a-batir-3 | terrain-a-batir-3 | Luthecia | valeur_totale | 27600 | 27600 |  | Valeur authored vraisemblable (surface x prix) : a confirmer. |
| terrain | terrain-a-batir-4 | terrain-a-batir-4 |  | proprietaire |  |  |  | Un terrain appartient-il a quelqu'un au premier jour, ou est-il libre ? |
| terrain | terrain-a-batir-4 | terrain-a-batir-4 |  | constructionAutorisee | false | false |  | Valeur authored vraisemblable : a confirmer. |
| terrain | terrain-a-batir-4 | terrain-a-batir-4 |  | valeur_totale | 25000 | 25000 |  | Valeur authored vraisemblable (surface x prix) : a confirmer. |
| terrain | terrain-a-batir-4 | terrain-a-batir-4 |  | occupant PNJ | squatter_cool | squatter_cool |  | Un PNJ est pose dans le blob du terrain (squatteurs). Contenu authored vraisemblable : a confirmer. |

## Lignes écartées de ce tableau, et pourquoi

Elles existent toujours en base. Elles ne sont pas à arbitrer, mais vous devez savoir qu'elles existent : rien n'est écarté en silence.

| source | ligne | raison |
|---|---|---|
| tableau 2 / entreprises | `armurerie-republic-zzville-1789383319` | Commerce de test. Rien a arbitrer. |
| tableau 2 / entreprises | `armurerie-republic-zzville-1789384067` | Commerce de test. Rien a arbitrer. |
| tableau 2 / entreprises | `armurerie-republic-zzville-1789384590` | Commerce de test. Rien a arbitrer. |
| tableau 2 / entreprises | `zztest-commerce-p3` | Commerce de test. Rien a arbitrer. |
