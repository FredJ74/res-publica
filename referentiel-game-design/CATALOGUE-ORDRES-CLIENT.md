# Inventaire des déclarations d'ordres côté client — data.js

**Extraction statique datée du 9 novembre 2026** : déclarations littérales `fn:` dans [`data.js`](../data.js), version `a8bd5e266f18f3432ec3feb11d53dbb799043531`. Cette extraction ne charge pas le JavaScript ; elle conserve les répétitions, les variantes et les références de lignes. Les colonnes PA/coût et libellé ne sont renseignées **que si la valeur est littérale sur la même ligne**. Une cellule « — » **n'implique ni absence ni gratuité**.

**1072 entrées de déclaration statique** (sur plusieurs bâtiments et villes possibles). Le catalogue n'établit ni que la commande est visible, ni qu'elle exécute la RPC correspondante, ni qu'elle est disponible au PJ. Le statut `type:'grey'` peut indiquer un menu qui ouvre des sous-actions plutôt qu'une mécanique propre. Voir `CROISEMENT-CATALOGUES.md` pour les 517 tarifs serveur et les écarts de noms.

| Ligne data.js | Identifiant `fn` | Libellé sur cette ligne | PA littéral | Coût littéral |
|---:|---|---|---:|---:|
| [315](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L315) | `installer_equipements` | — | — | — |
| [345](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L345) | `louer_local` | Louer ce local (200 FR/jour) | 1 | 0 |
| [346](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L346) | `gerer_local` | Gérer mon local | 1 | 0 |
| [549](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L549) | `imprimer_tracts_choix` | Imprimer des tracts | 0 | 0 |
| [551](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L551) | `imprimer_tracts_electoraux` | — | — | — |
| [552](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L552) | `imprimer_tracts_calomnieux` | Imprimer des tracts calomnieux | 1 | 150 |
| [564](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L564) | `deposer_petite_annonce` | Déposer une petite annonce | 1 | 0 |
| [585](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L585) | `marche_noir` | Marché Noir | 1 | 0 |
| [623](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L623) | `produire_commerce` | Produire les articles du marché | 0 | 0 |
| [624](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L624) | `faire_achats_marche` | Faire des achats | 0 | 0 |
| [625](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L625) | `vendre_matiere_commerce` | Vendre des matières au marché | 0 | 0 |
| [715](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L715) | `embaucher_agent_securite` | Embaucher un agent de sécurité | 1 | 500 |
| [718](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L718) | `embaucher_maitre_chien` | Embaucher un maître-chien | 1 | 700 |
| [760](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L760) | `consulter_elections` | Voir les candidats | 0 | 0 |
| [761](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L761) | `voter_election` | Voter | 0 | 0 |
| [766](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L766) | `contester_resultats` | Contester des resultats | 2 | 200 |
| [767](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L767) | `falsifier_listes_electorales` | Falsifier les listes electorales | 2 | 0 |
| [768](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L768) | `bourrer_urnes` | Bourrer les urnes | 1 | 0 |
| [769](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L769) | `truquer_depouillement` | Truquer le depouillement | 2 | 0 |
| [779](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L779) | `consulter_etat_civil` | Consulter l'état-civil | 0 | 0 |
| [780](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L780) | `consulter_mandats_maires` | Consulter les résumés de mandats | 0 | 0 |
| [848](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L848) | `consulter_caisse_usine` | Consulter la caisse | 0 | 0 |
| [849](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L849) | `consulter_stock_usine` | Consulter le stock | 0 | 0 |
| [850](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L850) | `vendre_matiere_usine` | Vendre des matières à l\'usine | 0 | 0 |
| [851](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L851) | `consulter_catalogue_manufactures` | Catalogue des produits | 0 | 0 |
| [889](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L889) | `publicite_premium` | Publicité premium | 0 | 0 |
| [890](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L890) | `consulter_archives_presse` | Consulter les archives de presse | 0 | 0 |
| [891](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L891) | `fabriquer_scandale` | Fabriquer un scandale | 3 | 800 |
| [892](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L892) | `corrompre_journaliste` | Corrompre un journaliste | 2 | 500 |
| [893](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L893) | `deposer_petite_annonce` | Déposer une petite annonce | 1 | 0 |
| [894](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L894) | `article` | Placer un article favorable | 1 | 500 |
| [895](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L895) | `etouffer` | Contrer une campagne de presse | 1 | 1000 |
| [909](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L909) | `consulter_offres_emploi` | Postes à pourvoir | 0 | 0 |
| [910](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L910) | `bne_passer_annonce` | Passer une annonce | 1 | 0 |
| [1178](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1178) | `imprimer_tracts_calomnieux` | Imprimer des tracts calomnieux | 1 | 150 |
| [1201](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1201) | `produire_commerce` | Produire les articles du marché | 0 | 0 |
| [1202](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1202) | `faire_achats_marche` | Faire des achats | 0 | 0 |
| [1203](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1203) | `vendre_matiere_commerce` | Vendre des matières au marché | 0 | 0 |
| [1219](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1219) | `marche_noir` | Marché Noir | 1 | 0 |
| [1298](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1298) | `publicite_premium` | Publicité premium | 0 | 0 |
| [1299](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1299) | `consulter_archives_presse` | Consulter les archives de presse | 0 | 0 |
| [1300](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1300) | `fabriquer_scandale` | Fabriquer un scandale | 3 | 800 |
| [1301](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1301) | `corrompre_journaliste` | Corrompre un journaliste | 2 | 500 |
| [1302](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1302) | `deposer_petite_annonce` | Déposer une petite annonce | 1 | 0 |
| [1303](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1303) | `article` | Placer un article favorable | 1 | 500 |
| [1304](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1304) | `etouffer` | Contrer une campagne de presse | 1 | 1000 |
| [1316](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1316) | `consulter_offres_emploi` | Postes à pourvoir | 0 | 0 |
| [1317](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1317) | `bne_passer_annonce` | Passer une annonce | 1 | 0 |
| [1356](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1356) | `consulter_elections` | Voir les candidats | 0 | 0 |
| [1357](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1357) | `voter_election` | Voter | 0 | 0 |
| [1362](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1362) | `contester_resultats` | Contester des resultats | 2 | 200 |
| [1363](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1363) | `falsifier_listes_electorales` | Falsifier les listes electorales | 2 | 0 |
| [1364](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1364) | `bourrer_urnes` | Bourrer les urnes | 1 | 0 |
| [1365](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1365) | `truquer_depouillement` | Truquer le depouillement | 2 | 0 |
| [1382](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1382) | `consulter_etat_civil` | Consulter l'état-civil | 0 | 0 |
| [1383](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1383) | `consulter_mandats_maires` | Consulter les résumés de mandats | 0 | 0 |
| [1477](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1477) | `acheter_terrain` | Acheter ce terrain (2100 m² — 25 200 FR) | 2 | 25200 |
| [1566](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1566) | `marche_noir` | Marché Noir | 1 | 0 |
| [1846](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1846) | `diner_affaires` | Diner d\'affaires | 2 | 100 |
| [1908](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1908) | `sovarka_commerces_libres` | Commerces non attribués | 0 | 0 |
| [1909](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1909) | `sovarka_signer_attribution` | Signer une attribution | 1 | 0 |
| [1910](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1910) | `sovarka_cession` | Céder ou reprendre un droit d\'exploiter | 1 | 0 |
| [1964](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1964) | `marche_noir` | Marché Noir | 1 | 0 |
| [1986](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1986) | `sovarka_musee_billet` | Billet du musée présidentiel | 0 | 8 |
| [1995](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L1995) | `sovarka_repas_presidentiel` | Repas du Président | 0 | 0 |
| [2015](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2015) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [2033](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2033) | `sovarka_lois_examen` | Projets de loi à trancher | 0 | 0 |
| [2034](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2034) | `sovarka_autocritique` | Autocritique publique | 1 | 0 |
| [2035](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2035) | `sovarka_signalements` | Registre des signalements | 0 | 0 |
| [2037](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2037) | `sovarka_seance` | Séance du jeudi | 0 | 0 |
| [2044](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2044) | `sovarka_signalements` | Registre des signalements | 0 | 0 |
| [2045](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2045) | `sovarka_surveiller` | Placer sous surveillance | 2 | 0 |
| [2049](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2049) | `sovarka_saisir_juge` | Saisir le juge | 1 | 0 |
| [2051](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2051) | `sovarka_registre_plaintes` | Affaires judiciaires | 0 | 0 |
| [2053](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2053) | `sovarka_conscription` | Conscription | 0 | 0 |
| [2055](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2055) | `sovarka_sondages` | Sondages en attente | 0 | 0 |
| [2199](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2199) | `sovarka_conscrit_presenter` | Se présenter (conscription) | 1 | 0 |
| [2226](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2226) | `produire_medicaments` | Produire des médicaments | 1 | 0 |
| [2227](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2227) | `produire_desinfectant` | Produire du désinfectant | 1 | 0 |
| [2465](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2465) | `marche_noir` | Marché Noir | 1 | 0 |
| [2764](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2764) | `reserver_chambre_hotel` | Reserver une chambre | 0 | 80 |
| [2765](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2765) | `choisir_suite` | Louer une suite | 1 | 0 |
| [2782](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2782) | `diner_affaires` | Diner d\'affaires | 2 | 300 |
| [2783](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2783) | `ecouter_rumeurs` | Ecouter les tables | 0 | 0 |
| [2784](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2784) | `lancer_rumeur_cible` | Lancer une rumeur | 1 | 0 |
| [2785](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2785) | `produire_commerce` | Cuisiner | 0 | 0 |
| [2786](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2786) | `consulter_carte_commerce` | Consulter la carte | 0 | 0 |
| [2787](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2787) | `gerer_commerce` | Gérer mon commerce | 0 | 0 |
| [2788](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2788) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [2804](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2804) | `ecouter_rumeurs` | Ecouter le barman | 0 | 0 |
| [2805](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2805) | `recruter_informateur_pnj` | Recruter un informateur | 1 | 150 |
| [2806](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2806) | `escort_piege` | Organiser une rencontre piège | 3 | 800 |
| [2807](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2807) | `produire_commerce` | Préparer les consommations | 0 | 0 |
| [2808](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2808) | `consulter_carte_commerce` | Consulter la carte | 0 | 0 |
| [2809](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2809) | `offrir_tournee` | Offrir à boire | 1 | 0 |
| [2810](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2810) | `gerer_commerce` | Gérer mon commerce | 0 | 0 |
| [2811](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2811) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [2822](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2822) | `dormir_chambre` | Dormir | 0 | 0 |
| [2823](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2823) | `service_etage` | Faire appel au service d\'etage | 0 | 150 |
| [2835](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2835) | `louer_local` | Louer cette suite (500 FR/jour) | 1 | 0 |
| [2836](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2836) | `gerer_local` | Gérer mon local | 1 | 0 |
| [2848](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2848) | `louer_local` | Louer cette suite (500 FR/jour) | 1 | 0 |
| [2849](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2849) | `gerer_local` | Gérer mon local | 1 | 0 |
| [2876](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2876) | `solliciter_audience_president` | Solliciter une audience | 0 | 0 |
| [2908](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2908) | `gestion_premier_ministre` | Le Premier ministre | 0 | 0 |
| [2909](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2909) | `postes_par_decret` | Postes et comites par decret | 0 | 0 |
| [2910](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2910) | `pouvoirs_exceptionnels` | Pouvoirs exceptionnels | 0 | 0 |
| [2911](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2911) | `adresse_a_la_nation` | S adresser a la Nation | 0 | 0 |
| [2912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2912) | `gracier` | Traiter les demandes de grâce | 2 | 0 |
| [2915](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2915) | `effort_national` | Effort national | 0 | 0 |
| [2927](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2927) | `conference_presse` | Conference de presse | 2 | 0 |
| [2928](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2928) | `propagande_etat` | Propagande d\'Etat | 3 | 500 |
| [2929](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2929) | `dementi` | Dementi officiel | 2 | 0 |
| [2945](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2945) | `reception_etat` | Organiser une reception | 2 | 1000 |
| [2946](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2946) | `banquet_diplo` | Banquet diplomatique | 3 | 2000 |
| [2981](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2981) | `postuler` | Postuler a un poste | 1 | 0 |
| [2998](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2998) | `nommer_ministre_pm` | Nommer des ministres | 2 | 0 |
| [2999](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2999) | `revoquer_ministre_pm` | Revoquer un ministre | 1 | 0 |
| [3000](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3000) | `declencher_vote_confiance` | Déclencher un vote de confiance | 3 | 0 |
| [3035](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3035) | `conference_presse` | Conférence de presse | 2 | 0 |
| [3036](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3036) | `propagande_etat` | Campagne de propagande | 3 | 500 |
| [3037](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3037) | `dementi` | Démenti officiel | 2 | 0 |
| [3050](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3050) | `consulter_dossiers_gouv` | Consulter des dossiers | 2 | 0 |
| [3051](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3051) | `fuite_info` | Produire une fuite | 3 | 0 |
| [3092](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3092) | `gestion_manifestations` | Gerer les manifestations | 0 | 0 |
| [3093](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3093) | `demandes_naturalisation` | Demandes de naturalisation | 0 | 0 |
| [3094](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3094) | `gerer_couvre_feu` | Instaurer un couvre-feu | 2 | 0 |
| [3095](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3095) | `gerer_chef_douanes` | Gérer le Chef des Douanes | 1 | 0 |
| [3106](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3106) | `gerer_budget_interieur` | Gérer le budget de l'Intérieur | 0 | 0 |
| [3107](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3107) | `subvention_min_int` | Financer la police | 0 | 0 |
| [3114](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3114) | `lois_votees_an` | Lois votées par l\'AN | 0 | 0 |
| [3141](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3141) | `pilotage_fiscal_budgetaire` | Fiscalité et budget | 2 | 0 |
| [3142](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3142) | `bne_caisse_prelever` | Caisse du Bureau de l'Emploi | 1 | 0 |
| [3143](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3143) | `subvention` | Accorder une subvention | 2 | 0 |
| [3144](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3144) | `gestion_industrielle_portuaire` | Gestion industrielle et portuaire | 1 | 0 |
| [3145](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3145) | `preempter_entreprise` | Droit de preemption sur une entreprise | 2 | 0 |
| [3177](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3177) | `ouvrir_enquete` | Ouvrir une enquete | 2 | 0 |
| [3178](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3178) | `proposer_grace` | Proposer une grace | 2 | 0 |
| [3179](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3179) | `gerer_juges` | Gérer les juges | 1 | 0 |
| [3183](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3183) | `gerer_budget_justice` | Gérer le budget de la Justice | 0 | 0 |
| [3184](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3184) | `gestion_qhs` | Gestion du QHS | 0 | 0 |
| [3219](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3219) | `mobilisation_nationale` | Mobilisation nationale | 0 | 0 |
| [3220](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3220) | `activer_cessez_le_feu` | Activer un cessez-le-feu | 2 | 0 |
| [3227](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3227) | `garde_republicaine` | Garde republicaine | 0 | 0 |
| [3241](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3241) | `renseignement_militaire` | Renseignement militaire | 0 | 0 |
| [3248](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3248) | `gestion_caserne` | Gestion de la caserne | 0 | 0 |
| [3275](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3275) | `propagande_etat` | Campagne de propagande | 3 | 500 |
| [3276](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3276) | `censurer_media` | Censurer un media | 2 | 0 |
| [3277](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3277) | `commanditer_sondage` | Commanditer un sondage | 1 | 200 |
| [3278](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3278) | `dementi` | Dementi officiel | 2 | 0 |
| [3305](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3305) | `proposer_treve` | Proposer une trêve | 3 | 0 |
| [3306](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3306) | `diplomatie_bilaterale` | Diplomatie bilaterale | 0 | 0 |
| [3307](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3307) | `gerer_ambassades` | Ambassades et ambassadeurs | 2 | 0 |
| [3351](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3351) | `calendrier_elections` | Calendrier electoral | 0 | 0 |
| [3356](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3356) | `seance_parlementaire` | Séance parlementaire | 0 | 0 |
| [3381](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3381) | `seance_parlementaire` | Séance parlementaire | 0 | 0 |
| [3382](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3382) | `observer_debats` | Observer les débats | 1 | 0 |
| [3383](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3383) | `voter_loi` | Voter une loi | 0 | 0 |
| [3384](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3384) | `projet_loi` | Déposer un projet de loi | 1 | 0 |
| [3385](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3385) | `amender_projet` | Amender mon projet | 0 | 0 |
| [3391](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3391) | `marchander_vote` | Marchander un vote | 1 | 100 |
| [3392](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3392) | `reveiller_depute` | Réveiller un député | 1 | 0 |
| [3406](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3406) | `consulter_lobbyiste` | Consulter le Lobbyiste | 1 | 150 |
| [3407](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3407) | `ecouter_rumeurs` | Ecouter les rumeurs | 1 | 0 |
| [3422](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3422) | `registre_assemblee` | Consulter le registre | 0 | 0 |
| [3448](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3448) | `consulter_dossier_notarial` | Se renseigner sur un dossier | 0 | 0 |
| [3465](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3465) | `gerer_testament` | Rédiger / modifier son testament | 1 | 200 |
| [3466](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3466) | `reclamer_heritage` | Réclamer un héritage | 0 | 0 |
| [3478](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3478) | `officialiser_transaction` | Officialiser une transaction | 1 | 0 |
| [3479](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3479) | `commerces_fonds_murs` | Fonds et murs des commerces | 0 | 0 |
| [3480](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3480) | `racheter_entreprise` | Racheter une entreprise | 0 | 0 |
| [3481](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3481) | `acte_rachat_entreprise_preemption` | Officialiser une preemption d\'Etat | 1 | 0 |
| [3482](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3482) | `transfert_compromis` | Transfert de compromis | 1 | 0 |
| [3483](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3483) | `demander_divorce` | Divorcer | 1 | 200 |
| [3484](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3484) | `acte_officiel_notaire` | Demander un acte officiel | 1 | 100 |
| [3496](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3496) | `consulter_archives_notariales` | Consulter les archives notariales | 0 | 0 |
| [3520](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3520) | `observer_match` | Consulter le calendrier et le classement | 0 | 0 |
| [3521](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3521) | `regarder_live` | Suivre le foot | 0 | 0 |
| [3533](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3533) | `prendre_licence_sportive` | Prendre sa licence sportive | 1 | 150 |
| [3534](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3534) | `demander_non_renouvellement_licence` | Ne pas renouveler ma licence | 1 | 0 |
| [3535](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3535) | `annuler_non_renouvellement_licence` | Annuler la demande de non-renouvellement | 0 | 0 |
| [3536](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3536) | `tenue_entrainement` | Mettre la tenue d'entraînement | 2 | 0 |
| [3537](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3537) | `tenue_match` | Mettre la tenue de match | 0 | 0 |
| [3538](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3538) | `conseil_entraineur_adjoint` | Demander conseil à l'entraîneur adjoint | 0 | 0 |
| [3550](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3550) | `consommer_buvette` | Prendre un verre | 1 | 50 |
| [3551](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3551) | `produire_commerce` | Servir | 0 | 0 |
| [3552](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3552) | `consulter_carte_commerce` | Consulter la carte | 1 | 0 |
| [3553](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3553) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [3554](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3554) | `choisir_accessoire_club` | Acheter un accessoire | 0 | 0 |
| [3555](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3555) | `acheter_accessoire_personnalise` | Acheter un accessoire personnalisé | 0 | 0 |
| [3567](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3567) | `parier_match` | Parier sur un match | 1 | 0 |
| [3568](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3568) | `consulter_classement_joueurs_club` | Connaître le classement des joueurs du club | 0 | 75 |
| [3580](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3580) | `rejoindre_club_supporters` | Rejoindre le club de supporters | 1 | 50 |
| [3581](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3581) | `consulter_palmares` | Consulter le palmares du championnat | 0 | 0 |
| [3582](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3582) | `consulter_organigramme_supporters` | Consulter l\'organigramme | 0 | 0 |
| [3583](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3583) | `declencher_election_club` | Déclencher une élection | 1 | 0 |
| [3584](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3584) | `organiser_manifestation` | Organiser une manifestation | 2 | 0 |
| [3585](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3585) | `organiser_boycott` | Organiser un boycott | 2 | 0 |
| [3595](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3595) | `postuler_president_club` | Postuler au poste de président | 2 | 0 |
| [3596](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3596) | `consulter_bureau_president` | Consulter le bureau | 0 | 0 |
| [3597](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3597) | `proposer_transfert` | Proposer un transfert | 2 | 0 |
| [3598](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3598) | `gerer_offres_transfert` | Gérer les offres reçues | 0 | 0 |
| [3599](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3599) | `sponsoriser_club` | Sponsoriser le club | 1 | 0 |
| [3600](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3600) | `consulter_budget_club` | Consulter le budget du club | 0 | 0 |
| [3601](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3601) | `gerer_salaires_club` | Gérer les salaires des joueurs | 0 | 0 |
| [3622](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3622) | `recolter_matiere` | Récolter | 2 | 0 |
| [3664](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3664) | `defense` | Se defendre | 2 | 300 |
| [3665](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3665) | `temoins_mes_convocations` | Mes convocations de temoin | 0 | 0 |
| [3666](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3666) | `audience_salle` | Assister a l\'audience | 0 | 0 |
| [3689](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3689) | `parquet` | Dossiers du parquet | 0 | 0 |
| [3690](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3690) | `rendre_sentence` | Rendre la sentence | 2 | 0 |
| [3691](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3691) | `audience_juge` | Tenir l\'audience | 0 | 0 |
| [3692](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3692) | `acte_officiel_juge` | Delivrer un acte officiel | 1 | 0 |
| [3705](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3705) | `archives` | Consulter les archives | 1 | 0 |
| [3706](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3706) | `falsifier_document` | Falsifier un document | 3 | 300 |
| [3707](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3707) | `demander_juge_instruction` | Demander à parler à un juge | 1 | 0 |
| [3711](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3711) | `avocat_dossiers` | Dossiers de mes clients | 0 | 0 |
| [3712](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3712) | `avocat_barreau` | Mon inscription au barreau | 0 | 0 |
| [3713](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3713) | `greffe_affaires` | Affaires en cours | 0 | 0 |
| [3714](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3714) | `greffe_archives` | Archives du greffe | 0 | 0 |
| [3720](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3720) | `casier_mon_extrait` | Demander mon extrait de casier | 1 | 100 |
| [3721](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3721) | `casier_extrait_enquete` | Extrait de casier (enquete) | 1 | 0 |
| [3722](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3722) | `orga_extrait_duplicata` | Duplicata d\'un extrait de domiciliation | 1 | 75 |
| [3723](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3723) | `greffe_corrompre_dossier` | Corrompre le greffier — copie d\'un dossier | 3 | 300 |
| [3724](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3724) | `greffe_corrompre_faux_casier` | Corrompre le greffier — faux casier vierge | 3 | 300 |
| [3749](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3749) | `gerer_finances` | Gérer mon compte / mes placements | 0 | 0 |
| [3750](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3750) | `emprunter` | Emprunter | 1 | 0 |
| [3752](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3752) | `virements` | Virements | 0 | 0 |
| [3753](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3753) | `presenter_autorisation_coffre` | Présenter une autorisation judiciaire | 1 | 0 |
| [3765](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3765) | `louer_local` | Louer ce coffre (600 FR/jour) | 1 | 0 |
| [3766](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3766) | `gerer_local` | Gérer mon coffre | 1 | 0 |
| [3791](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3791) | `gerer_finances` | Ouvrir / gérer mon compte | 0 | 0 |
| [3792](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3792) | `compte_offshore` | Placements et optimisation fiscale | 0 | 0 |
| [3793](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3793) | `emprunter_prive` | Emprunter (sans verification) | 1 | 0 |
| [3794](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3794) | `blanchiment` | Blanchir des fonds | 0 | 0 |
| [3795](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3795) | `societe_ecran` | Creer une societe ecran | 0 | 0 |
| [3820](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3820) | `vendre_ressource_medicale` | Fournir des ressources médicales | 0 | 0 |
| [3821](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3821) | `ouvrir_chambres_clinique` | Chambres | 0 | 0 |
| [3822](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3822) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [3837](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3837) | `gerer_visites_chambre` | Autoriser / Interdire les visites | 0 | 0 |
| [3838](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3838) | `soins` | Soin standard | 0 | 100 |
| [3839](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3839) | `soins_urgence` | Soins acceleres (urgence) | 0 | 500 |
| [3840](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3840) | `soins_discrets` | Soins sans trace | 1 | 800 |
| [3841](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3841) | `centre_anti_poison` | Centre anti-poison | 1 | 150 |
| [3842](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3842) | `repas_clinique` | Prendre le repas de la clinique | 1 | 30 |
| [3843](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3843) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [3846](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3846) | `gerer_visites_chambre` | Autoriser / Interdire les visites | 0 | 0 |
| [3847](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3847) | `soins` | Soin standard | 0 | 100 |
| [3848](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3848) | `soins_urgence` | Soins acceleres (urgence) | 0 | 500 |
| [3849](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3849) | `soins_discrets` | Soins sans trace | 1 | 800 |
| [3850](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3850) | `centre_anti_poison` | Centre anti-poison | 1 | 150 |
| [3851](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3851) | `repas_clinique` | Prendre le repas de la clinique | 1 | 30 |
| [3852](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3852) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [3855](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3855) | `gerer_visites_chambre` | Autoriser / Interdire les visites | 0 | 0 |
| [3856](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3856) | `soins` | Soin standard | 0 | 100 |
| [3857](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3857) | `soins_urgence` | Soins acceleres (urgence) | 0 | 500 |
| [3858](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3858) | `soins_discrets` | Soins sans trace | 1 | 800 |
| [3859](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3859) | `centre_anti_poison` | Centre anti-poison | 1 | 150 |
| [3860](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3860) | `repas_clinique` | Prendre le repas de la clinique | 1 | 30 |
| [3861](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3861) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [3864](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3864) | `gerer_visites_chambre` | Autoriser / Interdire les visites | 0 | 0 |
| [3865](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3865) | `soins` | Soin standard | 0 | 100 |
| [3866](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3866) | `soins_urgence` | Soins acceleres (urgence) | 0 | 500 |
| [3867](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3867) | `soins_discrets` | Soins sans trace | 1 | 800 |
| [3868](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3868) | `centre_anti_poison` | Centre anti-poison | 1 | 150 |
| [3869](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3869) | `repas_clinique` | Prendre le repas de la clinique | 1 | 30 |
| [3870](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3870) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [3873](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3873) | `gerer_visites_chambre` | Autoriser / Interdire les visites | 0 | 0 |
| [3874](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3874) | `soins` | Soin standard | 0 | 100 |
| [3875](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3875) | `soins_urgence` | Soins acceleres (urgence) | 0 | 500 |
| [3876](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3876) | `soins_discrets` | Soins sans trace | 1 | 800 |
| [3877](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3877) | `centre_anti_poison` | Centre anti-poison | 1 | 150 |
| [3878](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3878) | `repas_clinique` | Prendre le repas de la clinique | 1 | 30 |
| [3879](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3879) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [3882](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3882) | `gerer_visites_chambre` | Autoriser / Interdire les visites | 0 | 0 |
| [3883](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3883) | `soins` | Soin standard | 0 | 100 |
| [3884](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3884) | `soins_urgence` | Soins acceleres (urgence) | 0 | 500 |
| [3885](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3885) | `soins_discrets` | Soins sans trace | 1 | 800 |
| [3886](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3886) | `centre_anti_poison` | Centre anti-poison | 1 | 150 |
| [3887](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3887) | `repas_clinique` | Prendre le repas de la clinique | 1 | 30 |
| [3888](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3888) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [3891](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3891) | `gerer_visites_chambre` | Autoriser / Interdire les visites | 0 | 0 |
| [3892](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3892) | `soins` | Soin standard | 0 | 100 |
| [3893](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3893) | `soins_urgence` | Soins acceleres (urgence) | 0 | 500 |
| [3894](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3894) | `soins_discrets` | Soins sans trace | 1 | 800 |
| [3895](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3895) | `centre_anti_poison` | Centre anti-poison | 1 | 150 |
| [3896](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3896) | `repas_clinique` | Prendre le repas de la clinique | 1 | 30 |
| [3897](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3897) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [3900](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3900) | `gerer_visites_chambre` | Autoriser / Interdire les visites | 0 | 0 |
| [3901](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3901) | `soins` | Soin standard | 0 | 100 |
| [3902](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3902) | `soins_urgence` | Soins acceleres (urgence) | 0 | 500 |
| [3903](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3903) | `soins_discrets` | Soins sans trace | 1 | 800 |
| [3904](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3904) | `centre_anti_poison` | Centre anti-poison | 1 | 150 |
| [3905](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3905) | `repas_clinique` | Prendre le repas de la clinique | 1 | 30 |
| [3906](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3906) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [3909](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3909) | `gerer_visites_chambre` | Autoriser / Interdire les visites | 0 | 0 |
| [3910](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3910) | `soins` | Soin standard | 0 | 100 |
| [3911](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3911) | `soins_urgence` | Soins acceleres (urgence) | 0 | 500 |
| [3912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3912) | `soins_discrets` | Soins sans trace | 1 | 800 |
| [3913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3913) | `centre_anti_poison` | Centre anti-poison | 1 | 150 |
| [3914](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3914) | `repas_clinique` | Prendre le repas de la clinique | 1 | 30 |
| [3915](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3915) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [3918](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3918) | `gerer_visites_chambre` | Autoriser / Interdire les visites | 0 | 0 |
| [3919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3919) | `soins` | Soin standard | 0 | 100 |
| [3920](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3920) | `soins_urgence` | Soins acceleres (urgence) | 0 | 500 |
| [3921](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3921) | `soins_discrets` | Soins sans trace | 1 | 800 |
| [3922](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3922) | `centre_anti_poison` | Centre anti-poison | 1 | 150 |
| [3923](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3923) | `repas_clinique` | Prendre le repas de la clinique | 1 | 30 |
| [3924](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3924) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [3949](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3949) | `soin_public` | Soin standard | 0 | 25 |
| [3950](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3950) | `repas_hopital` | Prendre le repas de l\'hôpital | 1 | 0 |
| [3951](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3951) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [3952](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3952) | `centre_anti_poison` | Centre anti-poison | 1 | 60 |
| [3953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3953) | `transfert_clinique_privee` | Être transféré en clinique privée | 0 | 1000 |
| [3954](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3954) | `vendre_ressource_medicale` | Fournir des ressources médicales | 0 | 0 |
| [3990](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3990) | `plainte_police` | Porter plainte | 1 | 0 |
| [3991](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3991) | `archives_police` | Consulter les archives | 1 | 0 |
| [3992](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3992) | `arreter` | Arrestation d'urgence | 3 | 0 |
| [3993](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3993) | `se_justifier` | Se justifier (convocation) | 1 | 0 |
| [3998](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3998) | `temoin_deposition` | Temoigner (convocation) | 0 | 0 |
| [4010](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4010) | `se_rebeller` | Se rebeller | 2 | 0 |
| [4011](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4011) | `tentative_evasion` | Tenter de s\'evader | 3 | 0 |
| [4025](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4025) | `dossiers_plaintes` | Dossiers de plainte | 0 | 0 |
| [4026](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4026) | `mener_enquete` | Mener l'enquete | 2 | 250 |
| [4027](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4027) | `organiser_filature` | Organiser une filature | 2 | 150 |
| [4028](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4028) | `organiser_chasse_homme` | Organiser une chasse a l'homme | 3 | 300 |
| [4029](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4029) | `recruter_policier` | Recruter un policier | 1 | 0 |
| [4030](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4030) | `recruter_policier_cynophile` | Recruter une unite cynophile | 1 | 0 |
| [4031](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4031) | `mobiliser_police` | Faire intervenir les forces de l\'ordre | 2 | 0 |
| [4032](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4032) | `gerer_effectifs_police` | Gerer mes effectifs | 0 | 0 |
| [4063](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4063) | `se_renseigner` | Se renseigner | 0 | 0 |
| [4068](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4068) | `imprimer_tracts_electoraux` | Imprimer des tracts électoraux | 1 | 150 |
| [4069](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4069) | `vendre_bois_imprimerie` | Vendre des matières premières | 0 | 0 |
| [4083](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4083) | `publicite_premium` | Publicité premium | 0 | 0 |
| [4084](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4084) | `consulter_archives_presse` | Consulter les archives de presse | 0 | 0 |
| [4087](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4087) | `produire_fuite` | Produire une fuite | 2 | 0 |
| [4091](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4091) | `fabriquer_scandale` | Fabriquer un scandale | 3 | 800 |
| [4092](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4092) | `interview` | Donner une interview | 1 | 0 |
| [4093](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4093) | `article` | Placer un article favorable | 1 | 500 |
| [4096](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4096) | `corrompre_journaliste` | Corrompre un journaliste | 2 | 500 |
| [4097](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4097) | `etouffer` | Contrer une campagne de presse | 1 | 1000 |
| [4123](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4123) | `demander_parler_loge` | Demander a parler a quelqu\'un | 1 | 0 |
| [4150](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4150) | `recruter_informateur_2` | Recruter un informateur (Niv.2) | 1 | 400 |
| [4151](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4151) | `recruter_info_4` | Recruter une Taupe N4 | 3 | 0 |
| [4152](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4152) | `consulter_info_4` | Consulter la Taupe N4 | 1 | 0 |
| [4153](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4153) | `gerer_informateurs` | Gérer mes informateurs | 0 | 0 |
| [4166](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4166) | `deliberer_loge` | Participer aux deliberations | 2 | 0 |
| [4191](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4191) | `donner_conf` | Donner une conference | 2 | 0 |
| [4192](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4192) | `recruter_etud` | Recruter des militants | 2 | 0 |
| [4208](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4208) | `suivre_formation` | Suivre une formation | 0 | 0 |
| [4234](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4234) | `syndicat_etudiant_creer` | Domicilier un syndicat étudiant | 2 | 150 |
| [4235](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4235) | `syndicat_etudiant_gerer` | Gérer un syndicat étudiant | 0 | 0 |
| [4236](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4236) | `recruter_etud` | Recruter des militants | 2 | 0 |
| [4261](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4261) | `choisir_arme` | — | — | — |
| [4267](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4267) | `acheter_gilet` | — | — | — |
| [4274](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4274) | `consulter_registre_armes` | — | — | — |
| [4279](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4279) | `produire_arme` | Produire une arme | 0 | 0 |
| [4280](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4280) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [4306](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4306) | `se_nourrir` | Acheter a manger | 0 | 8 |
| [4307](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4307) | `pouls_populaire` | Prendre le pouls | 0 | 0 |
| [4310](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4310) | `lancer_rumeur_cible` | Lancer une rumeur | 1 | 0 |
| [4338](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4338) | `calendrier_elections` | Calendrier electoral | 0 | 0 |
| [4348](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4348) | `etat_civil` | État civil | 0 | 0 |
| [4350](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4350) | `objet_trouve` | Reclamer un objet trouve | 1 | 0 |
| [4351](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4351) | `consulter_organigramme_mairie` | Consulter l\'organigramme | 0 | 0 |
| [4363](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4363) | `fixer_impots_locaux` | Fixer les impôts locaux | 2 | 0 |
| [4364](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4364) | `repartition_budget_local` | Repartir le budget municipal | 2 | 0 |
| [4365](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4365) | `subvention_proposer` | Proposer une subvention | 2 | 0 |
| [4366](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4366) | `campagne_securite` | Lancer une campagne de securite | 2 | 500 |
| [4367](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4367) | `nominations_municipales` | Nominations | 0 | 0 |
| [4377](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4377) | `traiter_demandes_permis` | Traiter les demandes de permis | 1 | 0 |
| [4378](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4378) | `consulter_dossiers_urbanisme` | Consulter les dossiers d'urbanisme | 0 | 0 |
| [4380](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4380) | `demander_logement_social` | Déposer une demande de logement social | 1 | 0 |
| [4381](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4381) | `traiter_demandes_logement_social` | Tableau de bord des logements sociaux | 1 | 0 |
| [4382](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4382) | `acte_officiel_mairie` | Delivrer un acte officiel | 1 | 0 |
| [4383](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4383) | `financer_communal` | Financer un batiment communal | 1 | 0 |
| [4395](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4395) | `consulter_elections` | Voir les candidats | 0 | 0 |
| [4396](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4396) | `voter_election` | Voter | 0 | 0 |
| [4401](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4401) | `contester_resultats` | Contester des resultats | 2 | 200 |
| [4402](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4402) | `falsifier_listes_electorales` | Falsifier les listes electorales | 2 | 0 |
| [4403](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4403) | `bourrer_urnes` | Bourrer les urnes | 1 | 0 |
| [4404](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4404) | `truquer_depouillement` | Truquer le depouillement | 2 | 0 |
| [4416](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4416) | `consulter_etat_civil` | Consulter l'état-civil | 0 | 0 |
| [4417](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4417) | `consulter_mandats_maires` | Consulter les résumés de mandats | 0 | 0 |
| [4460](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4460) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4471](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4471) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4482](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4482) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4493](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4493) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4504](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4504) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4527](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4527) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4538](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4538) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4551](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4551) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4587](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4587) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4596](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4596) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4605](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4605) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4614](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4614) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4623](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4623) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4639](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4639) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4648](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4648) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4657](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4657) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [4685](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4685) | `se_renseigner` | Se renseigner | 0 | 0 |
| [4698](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4698) | `commerce_pj` | Ce commerce | 0 | 0 |
| [4699](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4699) | `louer_local` | Louer ce local (800 FR/jour) | 1 | 0 |
| [4700](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4700) | `gerer_local` | Gérer mon local | 1 | 0 |
| [4712](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4712) | `commerce_pj` | Ce commerce | 0 | 0 |
| [4713](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4713) | `louer_local` | Louer ce local (400 FR/jour) | 1 | 0 |
| [4714](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4714) | `gerer_local` | Gérer mon local | 1 | 0 |
| [4726](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4726) | `commerce_pj` | Ce commerce | 0 | 0 |
| [4727](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4727) | `louer_local` | Louer ce local (150 FR/jour) | 1 | 0 |
| [4728](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4728) | `gerer_local` | Gérer mon local | 1 | 0 |
| [4740](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4740) | `commerce_pj` | Ce commerce | 0 | 0 |
| [4741](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4741) | `louer_local` | Louer ce local (80 FR/jour) | 1 | 0 |
| [4742](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4742) | `gerer_local` | Gérer mon local | 1 | 0 |
| [4767](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4767) | `se_renseigner` | Se renseigner | 0 | 0 |
| [4784](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4784) | `commerce_pj` | Ce commerce | 0 | 0 |
| [4785](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4785) | `louer_local` | Louer ce local (600 FR/jour) | 1 | 0 |
| [4786](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4786) | `gerer_local` | Gérer mon local | 1 | 0 |
| [4798](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4798) | `commerce_pj` | Ce commerce | 0 | 0 |
| [4799](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4799) | `louer_local` | Louer ce local (300 FR/jour) | 1 | 0 |
| [4800](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4800) | `gerer_local` | Gérer mon local | 1 | 0 |
| [4812](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4812) | `commerce_pj` | Ce commerce | 0 | 0 |
| [4813](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4813) | `louer_local` | Louer ce local (100 FR/jour) | 1 | 0 |
| [4814](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4814) | `gerer_local` | Gérer mon local | 1 | 0 |
| [4842](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4842) | `se_renseigner` | Se renseigner | 0 | 0 |
| [4855](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4855) | `louer_local` | Louer ce local (1000 FR/jour) | 1 | 0 |
| [4856](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4856) | `gerer_local` | Gérer mon local | 1 | 0 |
| [4869](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4869) | `louer_local` | Louer ce local (500 FR/jour) | 1 | 0 |
| [4870](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4870) | `gerer_local` | Gérer mon local | 1 | 0 |
| [4883](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4883) | `louer_local` | Louer ce local (200 FR/jour) | 1 | 0 |
| [4884](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4884) | `gerer_local` | Gérer mon local | 1 | 0 |
| [4896](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4896) | `produire_fuite` | Produire une fuite | 2 | 0 |
| [4897](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4897) | `interview` | Donner une interview | 1 | 0 |
| [4912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4912) | `appeler_police_terrain` | Appeler la police | 1 | 0 |
| [4912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4912) | `faire_disparaitre_cadavre` | Appeler la police | 1 | 0 |
| [4912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4912) | `negocier_squatteurs` | Appeler la police | 1 | 0 |
| [4912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4912) | `signer_compromis` | Appeler la police | 1 | 0 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `acheter_terrain` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `construire_sur_terrain` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `corrompre_rdv_notaire` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `payer_versement_chantier` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `travailler_chantier` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `vendre_materiaux_chantier` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `modifier_plan_chantier` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `corrompre_chantier` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `voler_materiel_chantier` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `diviser_construction` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `reconfigurer_lots` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `louer_lot_ici` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `gerer_lot_loue` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `gerer_fonds_commerce` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `emprunter_construction` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) | `racheter_terrain` | Acheter ce terrain (1850 m² — 22 200 FR) | 2 | 22200 |
| [4918](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4918) | `appeler_police_terrain` | Appeler la police | 1 | 0 |
| [4918](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4918) | `faire_disparaitre_cadavre` | Appeler la police | 1 | 0 |
| [4918](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4918) | `negocier_squatteurs` | Appeler la police | 1 | 0 |
| [4918](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4918) | `signer_compromis` | Appeler la police | 1 | 0 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `acheter_terrain` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `construire_sur_terrain` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `corrompre_rdv_notaire` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `payer_versement_chantier` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `travailler_chantier` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `vendre_materiaux_chantier` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `modifier_plan_chantier` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `corrompre_chantier` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `voler_materiel_chantier` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `diviser_construction` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `reconfigurer_lots` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `louer_lot_ici` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `gerer_lot_loue` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `gerer_fonds_commerce` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `emprunter_construction` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) | `racheter_terrain` | Acheter ce terrain (2750 m² — 33 000 FR) | 2 | 33000 |
| [4924](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4924) | `appeler_police_terrain` | Appeler la police | 1 | 0 |
| [4924](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4924) | `faire_disparaitre_cadavre` | Appeler la police | 1 | 0 |
| [4924](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4924) | `negocier_squatteurs` | Appeler la police | 1 | 0 |
| [4924](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4924) | `signer_compromis` | Appeler la police | 1 | 0 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `acheter_terrain` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `construire_sur_terrain` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `corrompre_rdv_notaire` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `payer_versement_chantier` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `travailler_chantier` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `vendre_materiaux_chantier` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `modifier_plan_chantier` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `corrompre_chantier` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `voler_materiel_chantier` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `diviser_construction` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `reconfigurer_lots` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `louer_lot_ici` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `gerer_lot_loue` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `gerer_fonds_commerce` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `emprunter_construction` | Acheter ce terrain | 2 | 25000 |
| [4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) | `racheter_terrain` | Acheter ce terrain | 2 | 25000 |
| [4930](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4930) | `appeler_police_terrain` | Appeler la police | 1 | 0 |
| [4930](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4930) | `faire_disparaitre_cadavre` | Appeler la police | 1 | 0 |
| [4930](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4930) | `negocier_squatteurs` | Appeler la police | 1 | 0 |
| [4930](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4930) | `signer_compromis` | Appeler la police | 1 | 0 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `acheter_terrain` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `construire_sur_terrain` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `corrompre_rdv_notaire` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `payer_versement_chantier` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `travailler_chantier` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `vendre_materiaux_chantier` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `modifier_plan_chantier` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `corrompre_chantier` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `voler_materiel_chantier` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `diviser_construction` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `reconfigurer_lots` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `louer_lot_ici` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `gerer_lot_loue` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `gerer_fonds_commerce` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `emprunter_construction` | Acheter ce terrain | 2 | 25000 |
| [4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) | `racheter_terrain` | Acheter ce terrain | 2 | 25000 |
| [4946](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4946) | `appeler_police_terrain` | Appeler la police | 1 | 0 |
| [4946](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4946) | `faire_disparaitre_cadavre` | Appeler la police | 1 | 0 |
| [4946](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4946) | `negocier_squatteurs` | Appeler la police | 1 | 0 |
| [4946](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4946) | `signer_compromis` | Appeler la police | 1 | 0 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `acheter_terrain` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `construire_sur_terrain` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `corrompre_rdv_notaire` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `payer_versement_chantier` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `travailler_chantier` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `vendre_materiaux_chantier` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `modifier_plan_chantier` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `corrompre_chantier` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `voler_materiel_chantier` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `diviser_construction` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `reconfigurer_lots` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `louer_lot_ici` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `gerer_lot_loue` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `gerer_fonds_commerce` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `emprunter_construction` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) | `racheter_terrain` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [4952](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4952) | `appeler_police_terrain` | Appeler la police | 1 | 0 |
| [4952](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4952) | `faire_disparaitre_cadavre` | Appeler la police | 1 | 0 |
| [4952](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4952) | `negocier_squatteurs` | Appeler la police | 1 | 0 |
| [4952](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4952) | `signer_compromis` | Appeler la police | 1 | 0 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `acheter_terrain` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `construire_sur_terrain` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `corrompre_rdv_notaire` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `payer_versement_chantier` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `travailler_chantier` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `vendre_materiaux_chantier` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `modifier_plan_chantier` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `corrompre_chantier` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `voler_materiel_chantier` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `diviser_construction` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `reconfigurer_lots` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `louer_lot_ici` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `gerer_lot_loue` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `gerer_fonds_commerce` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `emprunter_construction` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) | `racheter_terrain` | Acheter ce terrain (1800 m² — 21 600 FR) | 2 | 21600 |
| [4958](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4958) | `appeler_police_terrain` | Appeler la police | 1 | 0 |
| [4958](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4958) | `faire_disparaitre_cadavre` | Appeler la police | 1 | 0 |
| [4958](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4958) | `negocier_squatteurs` | Appeler la police | 1 | 0 |
| [4958](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4958) | `signer_compromis` | Appeler la police | 1 | 0 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `acheter_terrain` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `construire_sur_terrain` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `corrompre_rdv_notaire` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `payer_versement_chantier` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `travailler_chantier` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `vendre_materiaux_chantier` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `modifier_plan_chantier` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `corrompre_chantier` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `voler_materiel_chantier` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `diviser_construction` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `reconfigurer_lots` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `louer_lot_ici` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `gerer_lot_loue` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `gerer_fonds_commerce` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `emprunter_construction` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) | `racheter_terrain` | Acheter ce terrain (2200 m² — 26 400 FR) | 2 | 26400 |
| [4964](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4964) | `appeler_police_terrain` | Appeler la police | 1 | 0 |
| [4964](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4964) | `faire_disparaitre_cadavre` | Appeler la police | 1 | 0 |
| [4964](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4964) | `negocier_squatteurs` | Appeler la police | 1 | 0 |
| [4964](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4964) | `signer_compromis` | Appeler la police | 1 | 0 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `acheter_terrain` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `construire_sur_terrain` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `corrompre_rdv_notaire` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `payer_versement_chantier` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `travailler_chantier` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `vendre_materiaux_chantier` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `modifier_plan_chantier` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `corrompre_chantier` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `voler_materiel_chantier` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `diviser_construction` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `reconfigurer_lots` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `louer_lot_ici` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `gerer_lot_loue` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `gerer_fonds_commerce` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `emprunter_construction` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) | `racheter_terrain` | Acheter ce terrain (2500 m² — 30 000 FR) | 2 | 30000 |
| [4970](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4970) | `appeler_police_terrain` | Appeler la police | 1 | 0 |
| [4970](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4970) | `faire_disparaitre_cadavre` | Appeler la police | 1 | 0 |
| [4970](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4970) | `negocier_squatteurs` | Appeler la police | 1 | 0 |
| [4970](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4970) | `signer_compromis` | Appeler la police | 1 | 0 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `acheter_terrain` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `construire_sur_terrain` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `corrompre_rdv_notaire` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `payer_versement_chantier` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `travailler_chantier` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `vendre_materiaux_chantier` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `modifier_plan_chantier` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `corrompre_chantier` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `voler_materiel_chantier` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `diviser_construction` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `reconfigurer_lots` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `louer_lot_ici` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `gerer_lot_loue` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `gerer_fonds_commerce` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `emprunter_construction` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) | `racheter_terrain` | Acheter ce terrain (3000 m² — 36 000 FR) | 2 | 36000 |
| [4989](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4989) | `appeler_police_terrain` | Appeler la police | 1 | 0 |
| [4990](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4990) | `faire_disparaitre_cadavre` | Faire disparaitre le corps | 2 | 0 |
| [4991](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4991) | `negocier_squatteurs` | Negocier le depart | 1 | 0 |
| [4992](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4992) | `donner_argent_pnj` | Donner de l\'argent | 1 | 0 |
| [4993](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4993) | `signer_compromis` | Signer un compromis | 2 | 1000 |
| [4995](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4995) | `acheter_terrain` | Acheter ce terrain (2150 m² — 25 800 FR) | 2 | 25800 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `construire_sur_terrain` | Construire | 0 | 0 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `corrompre_rdv_notaire` | Construire | 0 | 0 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `payer_versement_chantier` | Construire | 0 | 0 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `travailler_chantier` | Construire | 0 | 0 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `vendre_materiaux_chantier` | Construire | 0 | 0 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `modifier_plan_chantier` | Construire | 0 | 0 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `corrompre_chantier` | Construire | 0 | 0 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `voler_materiel_chantier` | Construire | 0 | 0 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `diviser_construction` | Construire | 0 | 0 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `reconfigurer_lots` | Construire | 0 | 0 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `louer_lot_ici` | Construire | 0 | 0 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `gerer_lot_loue` | Construire | 0 | 0 |
| [4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) | `gerer_fonds_commerce` | Construire | 0 | 0 |
| [4997](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4997) | `emprunter_construction` | Faire un prêt (Banque Nationale) | 0 | 0 |
| [4998](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4998) | `racheter_terrain` | Offre de rachat | 2 | 0 |
| [5026](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5026) | `calendrier_elections` | Calendrier electoral | 0 | 0 |
| [5027](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5027) | `objet_trouve` | Reclamer un objet trouve | 1 | 0 |
| [5033](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5033) | `etat_civil` | État civil | 0 | 0 |
| [5035](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5035) | `consulter_organigramme_mairie` | Consulter l\'organigramme | 0 | 0 |
| [5048](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5048) | `fixer_impots_locaux` | Fixer les impôts locaux | 2 | 0 |
| [5049](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5049) | `repartition_budget_local` | Répartir le budget municipal | 2 | 0 |
| [5050](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5050) | `subvention_proposer` | Proposer une subvention | 2 | 0 |
| [5051](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5051) | `campagne_securite` | Lancer une campagne de securite | 2 | 500 |
| [5052](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5052) | `nominations_municipales` | Nominations | 0 | 0 |
| [5063](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5063) | `traiter_demandes_permis` | Traiter les demandes de permis | 1 | 0 |
| [5064](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5064) | `consulter_dossiers_urbanisme` | Consulter les dossiers d'urbanisme | 0 | 0 |
| [5066](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5066) | `demander_logement_social` | Déposer une demande de logement social | 1 | 0 |
| [5067](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5067) | `traiter_demandes_logement_social` | Tableau de bord des logements sociaux | 1 | 0 |
| [5068](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5068) | `acte_officiel_mairie` | Delivrer un acte officiel | 1 | 0 |
| [5069](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5069) | `financer_communal` | Financer un batiment communal | 1 | 0 |
| [5100](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5100) | `produire_commerce` | Préparer le petit-déjeuner | 0 | 0 |
| [5101](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5101) | `consulter_carte_commerce` | Petit-déjeuner | 1 | 0 |
| [5102](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5102) | `gerer_commerce` | Gérer mon commerce | 0 | 0 |
| [5103](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5103) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [5104](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5104) | `reserver_chambre_hotel` | Réserver une chambre d\'hôtel | 0 | 60 |
| [5115](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5115) | `dormir_chambre` | Dormir | 0 | 0 |
| [5117](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5117) | `service_etage` | Faire appel au service d\'etage | 0 | 50 |
| [5166](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5166) | `produire_commerce` | Préparer les consommations | 0 | 0 |
| [5167](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5167) | `consulter_carte_commerce` | Consulter la carte | 0 | 0 |
| [5168](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5168) | `offrir_tournee` | Offrir à boire | 1 | 0 |
| [5169](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5169) | `gerer_commerce` | Gérer mon commerce | 0 | 0 |
| [5170](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5170) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [5171](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5171) | `ecouter_rumeurs` | Ecouter le patron | 0 | 0 |
| [5175](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5175) | `lancer_rumeur_cible` | Lancer une rumeur | 1 | 0 |
| [5176](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5176) | `recruter_informateur_pnj` | Recruter un informateur | 1 | 150 |
| [5199](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5199) | `ssm_besoin_aide` | Besoin d’aide ? | 0 | 0 |
| [5200](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5200) | `ssm_demander_rendezvous` | Prendre rendez-vous avec Edwige Jacquard | 0 | 0 |
| [5210](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5210) | `demander_logement_social` | Déposer une demande de logement social | 1 | 0 |
| [5248](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5248) | `mobiliser` | Mobiliser les membres | 2 | 0 |
| [5270](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5270) | `acheter_entreprise` | Racheter l\'usine | 3 | 8000 |
| [5297](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5297) | `produire_commerce` | Préparer le petit-déjeuner | 0 | 0 |
| [5298](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5298) | `consulter_carte_commerce` | Petit-déjeuner | 1 | 0 |
| [5299](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5299) | `gerer_commerce` | Gérer mon commerce | 0 | 0 |
| [5300](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5300) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [5301](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5301) | `reserver_chambre_hotel` | Réserver une chambre d\'hôtel | 0 | 60 |
| [5316](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5316) | `dormir_chambre` | Dormir | 0 | 0 |
| [5318](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5318) | `service_etage` | Faire appel au service d\'etage | 0 | 50 |
| [5343](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5343) | `gerer_finances` | Gérer mon compte / mes placements | 0 | 0 |
| [5344](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5344) | `emprunter` | Emprunter | 1 | 0 |
| [5346](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5346) | `virements` | Virements | 0 | 0 |
| [5368](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5368) | `soin_public` | Soin standard | 0 | 25 |
| [5370](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5370) | `centre_anti_poison` | Centre anti-poison | 1 | 60 |
| [5371](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5371) | `transfert_clinique_privee` | Être transféré en clinique privée | 0 | 1000 |
| [5372](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5372) | `repas_hopital` | Prendre le repas de l\'hôpital | 1 | 0 |
| [5373](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5373) | `sortie_hopital` | Sortir de l\'hôpital | 0 | 0 |
| [5374](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5374) | `vendre_ressource_medicale` | Fournir des ressources médicales | 0 | 0 |
| [5411](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5411) | `plainte_police` | Porter plainte | 1 | 0 |
| [5414](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5414) | `archives_police` | Consulter les archives | 1 | 0 |
| [5415](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5415) | `arreter` | Arrestation d'urgence | 3 | 0 |
| [5420](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5420) | `se_justifier` | Se justifier (convocation) | 1 | 0 |
| [5425](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5425) | `temoin_deposition` | Temoigner (convocation) | 0 | 0 |
| [5448](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5448) | `se_rebeller` | Se rebeller | 2 | 0 |
| [5449](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5449) | `tentative_evasion` | Tenter de s\'evader | 3 | 0 |
| [5461](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5461) | `dossiers_plaintes` | Dossiers de plainte | 0 | 0 |
| [5462](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5462) | `mener_enquete` | Mener l'enquete | 2 | 250 |
| [5463](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5463) | `organiser_filature` | Organiser une filature | 2 | 150 |
| [5464](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5464) | `organiser_chasse_homme` | Organiser une chasse a l'homme | 3 | 300 |
| [5465](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5465) | `recruter_policier` | Recruter un policier | 1 | 0 |
| [5466](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5466) | `recruter_policier_cynophile` | Recruter une unite cynophile | 1 | 0 |
| [5467](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5467) | `mobiliser_police` | Faire intervenir les forces de l\'ordre | 2 | 0 |
| [5468](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5468) | `gerer_effectifs_police` | Gerer mes effectifs | 0 | 0 |
| [5495](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5495) | `defense` | Se defendre | 2 | 300 |
| [5496](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5496) | `temoins_mes_convocations` | Mes convocations de temoin | 0 | 0 |
| [5497](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5497) | `audience_salle` | Assister a l\'audience | 0 | 0 |
| [5511](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5511) | `parquet` | Dossiers du parquet | 0 | 0 |
| [5512](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5512) | `rendre_sentence` | Rendre la sentence | 2 | 0 |
| [5513](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5513) | `audience_juge` | Tenir l\'audience | 0 | 0 |
| [5514](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5514) | `acte_officiel_juge` | Delivrer un acte officiel | 1 | 0 |
| [5531](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5531) | `archives` | Consulter les archives | 1 | 0 |
| [5533](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5533) | `falsifier_document` | Falsifier un document | 3 | 300 |
| [5534](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5534) | `avocat_dossiers` | Dossiers de mes clients | 0 | 0 |
| [5535](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5535) | `avocat_barreau` | Mon inscription au barreau | 0 | 0 |
| [5536](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5536) | `greffe_affaires` | Affaires en cours | 0 | 0 |
| [5537](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5537) | `greffe_archives` | Archives du greffe | 0 | 0 |
| [5543](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5543) | `casier_mon_extrait` | Demander mon extrait de casier | 1 | 100 |
| [5544](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5544) | `casier_extrait_enquete` | Extrait de casier (enquete) | 1 | 0 |
| [5545](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5545) | `orga_extrait_duplicata` | Duplicata d\'un extrait de domiciliation | 1 | 75 |
| [5546](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5546) | `greffe_corrompre_dossier` | Corrompre le greffier — copie d\'un dossier | 3 | 300 |
| [5547](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5547) | `greffe_corrompre_faux_casier` | Corrompre le greffier — faux casier vierge | 3 | 300 |
| [5579](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5579) | `imprimer_tracts_electoraux` | Imprimer des tracts électoraux | 1 | 150 |
| [5602](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5602) | `imprimer_tracts_calomnieux` | Imprimer des tracts calomnieux | 1 | 150 |
| [5603](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5603) | `vendre_bois_imprimerie` | Vendre des matières premières | 0 | 0 |
| [5642](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5642) | `produire_commerce` | Produire les articles du march\u00e9 | 0 | 0 |
| [5643](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5643) | `faire_achats_marche` | Faire des achats | 0 | 0 |
| [5645](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5645) | `pouls_populaire` | Prendre le pouls | 0 | 0 |
| [5646](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5646) | `vendre_matiere_commerce` | Vendre des mati\u00e8res au march\u00e9 | 0 | 0 |
| [5649](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5649) | `lancer_rumeur_cible` | Lancer une rumeur | 1 | 0 |
| [5683](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5683) | `diner_affaires` | Diner d\'affaires | 2 | 150 |
| [5684](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5684) | `ecouter_rumeurs` | Ecouter les tables | 0 | 0 |
| [5685](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5685) | `lancer_rumeur_cible` | Lancer une rumeur | 1 | 0 |
| [5686](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5686) | `produire_commerce` | Cuisiner | 0 | 0 |
| [5687](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5687) | `consulter_carte_commerce` | Consulter la carte | 0 | 0 |
| [5688](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5688) | `gerer_commerce` | Gérer mon commerce | 0 | 0 |
| [5689](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5689) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [5721](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5721) | `choisir_arme` | — | — | — |
| [5727](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5727) | `acheter_gilet` | — | — | — |
| [5734](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5734) | `consulter_registre_armes` | — | — | — |
| [5739](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5739) | `produire_arme` | Produire une arme | 0 | 0 |
| [5740](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5740) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [5741](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5741) | `marche_noir` | Marché Noir | 1 | 0 |
| [5762](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5762) | `organiser_manifestation_spontanee` | Organiser une manifestation spontanée | 1 | 0 |
| [5818](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5818) | `consulter_devis_chantier_naval` | Consulter les devis des bateaux | 0 | 0 |
| [5830](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5830) | `consulter_devis_chantier_naval` | Consulter les devis des bateaux | 0 | 0 |
| [5866](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5866) | `prier` | Prier le Formulaire Sacr\u00e9 | 1 | 0 |
| [5867](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5867) | `faire_don` | Faire un don a l\'Eglise | 1 | 200 |
| [5959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5959) | `acheter_terrain` | Acheter ce terrain (1500 m² — 18 000 FR) | 2 | 18000 |
| [5960](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5960) | `deposer_demande_permis` | Déposer une demande de permis | 1 | 100 |
| [5961](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5961) | `corrompre_fonctionnaire_permis` | Corrompre un fonctionnaire (accélérer) | 2 | 800 |
| [5982](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5982) | `acheter_terrain` | Acheter ce terrain (1 650 m² — 19 800 FR) | 2 | 19800 |
| [5983](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5983) | `deposer_demande_permis` | Déposer une demande de permis | 1 | 100 |
| [5984](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5984) | `corrompre_fonctionnaire_permis` | Corrompre un fonctionnaire (accélérer) | 2 | 800 |
| [6005](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6005) | `acheter_terrain` | Acheter ce terrain (2 200 m² — 26 400 FR) | 2 | 26400 |
| [6006](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6006) | `deposer_demande_permis` | Déposer une demande de permis | 1 | 100 |
| [6007](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6007) | `corrompre_fonctionnaire_permis` | Corrompre un fonctionnaire (accélérer) | 2 | 800 |
| [6028](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6028) | `acheter_terrain` | Acheter ce terrain (3 100 m² — 37 200 FR) | 2 | 37200 |
| [6029](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6029) | `deposer_demande_permis` | Déposer une demande de permis | 1 | 100 |
| [6030](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6030) | `corrompre_fonctionnaire_permis` | Corrompre un fonctionnaire (accélérer) | 2 | 800 |
| [6054](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6054) | `acheter_terrain` | Acheter ce terrain (4 200 m² — 50 400 FR) | 2 | 50400 |
| [6055](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6055) | `deposer_demande_permis` | Déposer une demande de permis | 1 | 100 |
| [6056](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6056) | `corrompre_fonctionnaire_permis` | Corrompre un fonctionnaire (accélérer) | 2 | 800 |
| [6077](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6077) | `acheter_terrain` | Acheter ce terrain (5 500 m² — 66 000 FR) | 2 | 66000 |
| [6078](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6078) | `deposer_demande_permis` | Déposer une demande de permis | 1 | 100 |
| [6079](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6079) | `corrompre_fonctionnaire_permis` | Corrompre un fonctionnaire (accélérer) | 2 | 800 |
| [6100](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6100) | `acheter_terrain` | Acheter ce terrain (2300 m² — 27 600 FR) | 2 | 27600 |
| [6101](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6101) | `deposer_demande_permis` | Déposer une demande de permis | 1 | 100 |
| [6102](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6102) | `corrompre_fonctionnaire_permis` | Corrompre un fonctionnaire (accélérer) | 2 | 800 |
| [6123](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6123) | `acheter_terrain` | Acheter ce terrain (2300 m² — 27 600 FR) | 2 | 27600 |
| [6124](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6124) | `deposer_demande_permis` | Déposer une demande de permis | 1 | 100 |
| [6125](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6125) | `corrompre_fonctionnaire_permis` | Corrompre un fonctionnaire (accélérer) | 2 | 800 |
| [6166](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6166) | `nommer_lieutenant` | Nommer un Lieutenant | 0 | 0 |
| [6181](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6181) | `s_engager_armee` | S\'engager dans l\'armée | 1 | 0 |
| [6182](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6182) | `traiter_candidatures` | Candidatures à l\'engagement | 0 | 0 |
| [6183](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6183) | `decouvrir_affectation` | Découvrir mon affectation | 0 | 0 |
| [6186](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6186) | `calepin_campagne` | Consulter son calepin de campagne | 0 | 0 |
| [6193](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6193) | `decorer_militaire` | Decerner une decoration | 0 | 0 |
| [6194](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6194) | `quitter_armee` | Quitter l\'armée | 0 | 0 |
| [6195](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6195) | `demettre_lieutenant` | Démettre un Lieutenant | 0 | 0 |
| [6196](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6196) | `se_presenter_affectation` | Se présenter à mon affectation | 1 | 0 |
| [6197](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6197) | `stage_caserne` | Stage à la Caserne | 3 | 0 |
| [6219](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6219) | `retirer_trousse` | Retirer une trousse de premiers secours | 0 | 0 |
| [6274](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6274) | `nommer_capitaine` | Nommer un Capitaine | 0 | 0 |
| [6275](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6275) | `recherche_militaire` | Lancer une recherche sur l\'armement | 2 | 0 |
| [6287](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6287) | `caisse_caserne` | Gérer la caisse de la caserne | 0 | 0 |
| [6288](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6288) | `repartir_armement` | Doter ma section en armement | 1 | 0 |
| [6289](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6289) | `recruter_compagnie` | Recruter une compagnie | 3 | 0 |
| [6297](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6297) | `gerer_detachement` | Gérer mon détachement | 0 | 0 |
| [6298](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6298) | `voir_ma_section` | Voir ma section | 0 | 0 |
| [6299](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6299) | `entrainer_section` | Entrainer la section | 0 | 0 |
| [6305](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6305) | `reposer_section` | Faire reposer la section | 0 | 0 |
| [6306](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6306) | `equiper_section` | Gerer l\'equipement de ma section | 1 | 0 |
| [6311](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6311) | `declencher_mutinerie` | Declencher une mutinerie | 0 | 0 |
| [6312](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6312) | `remonter_renseignement` | Faire remonter un renseignement | 1 | 0 |
| [6320](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6320) | `inspecter_troupes` | Inspecter les troupes | 1 | 0 |
| [6321](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6321) | `gerer_budget_caserne` | Gérer le budget militaire | 0 | 0 |
| [6324](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6324) | `tableau_effort_guerre` | Effort de guerre — tableau de contrôle | 0 | 0 |
| [6346](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6346) | `retirer_armes_militaires` | Retirer des armes | 0 | 0 |
| [6347](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6347) | `retirer_explosifs_militaires` | Retirer des explosifs | 0 | 0 |
| [6352](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6352) | `retirer_equipement_militaire` | Retirer de l\'équipement | 0 | 0 |
| [6353](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6353) | `acheter_bombe_illegale` | Subtiliser des explosifs | 2 | 0 |
| [6377](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6377) | `manger_ration` | Manger sa ration | 0 | 0 |
| [6380](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6380) | `retirer_rations` | Emporter des rations de combat | 0 | 0 |
| [6392](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6392) | `consulter_faits_armes` | Consulter les faits d\'armes | 0 | 0 |
| [6579](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6579) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [6589](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6589) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [6600](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6600) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [6611](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6611) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [6622](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6622) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [6642](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6642) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [6662](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6662) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [6720](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6720) | `organiser_manifestation_spontanee` | Organiser une manifestation spontanée | 1 | 0 |
| [6743](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6743) | `demander_audience_ambassadeur` | Demander audience à l\'ambassadeur | 1 | 0 |
| [6744](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6744) | `demander_asile_politique` | Demander l\'asile politique | 2 | 0 |
| [6745](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6745) | `reserver_salle_reception` | Réserver la Salle de Réception | 1 | 0 |
| [6762](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6762) | `relations_bilaterales` | Consulter les relations bilatérales | 0 | 0 |
| [6763](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6763) | `organiser_reception_diplomatique` | Organiser une réception diplomatique | 2 | 1200 |
| [6764](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6764) | `financer_oeuvre_culturelle` | Financer une œuvre culturelle | 1 | 600 |
| [6765](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6765) | `demander_transfert_detenu` | Demander le transfert d\'un détenu | 1 | 0 |
| [6774](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6774) | `relations_bilaterales` | Consulter les relations bilatérales | 0 | 0 |
| [6775](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6775) | `organiser_reception_diplomatique` | Organiser une réception diplomatique | 2 | 1200 |
| [6776](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6776) | `financer_oeuvre_culturelle` | Financer une œuvre culturelle | 1 | 600 |
| [6777](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6777) | `demander_transfert_detenu` | Demander le transfert d\'un détenu | 1 | 0 |
| [6786](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6786) | `relations_bilaterales` | Consulter les relations bilatérales | 0 | 0 |
| [6787](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6787) | `organiser_reception_diplomatique` | Organiser une réception diplomatique | 2 | 1200 |
| [6788](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6788) | `financer_oeuvre_culturelle` | Financer une œuvre culturelle | 1 | 600 |
| [6789](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6789) | `demander_transfert_detenu` | Demander le transfert d\'un détenu | 1 | 0 |
| [6819](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6819) | `demander_audience_ambassadeur` | Demander audience à l\'ambassadeur | 1 | 0 |
| [6820](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6820) | `demander_asile_politique` | Demander l\'asile politique | 2 | 0 |
| [6821](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6821) | `reserver_salle_reception` | Réserver la Salle de Réception | 1 | 0 |
| [6838](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6838) | `relations_bilaterales` | Consulter les relations bilatérales | 0 | 0 |
| [6839](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6839) | `organiser_reception_diplomatique` | Organiser une réception diplomatique | 2 | 1200 |
| [6840](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6840) | `financer_oeuvre_culturelle` | Financer une œuvre culturelle | 1 | 600 |
| [6841](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6841) | `demander_transfert_detenu` | Demander le transfert d\'un détenu | 1 | 0 |
| [6851](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6851) | `relations_bilaterales` | Consulter les relations bilatérales | 0 | 0 |
| [6852](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6852) | `organiser_reception_diplomatique` | Organiser une réception diplomatique | 2 | 1200 |
| [6853](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6853) | `financer_oeuvre_culturelle` | Financer une œuvre culturelle | 1 | 600 |
| [6854](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6854) | `demander_transfert_detenu` | Demander le transfert d\'un détenu | 1 | 0 |
| [6864](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6864) | `relations_bilaterales` | Consulter les relations bilatérales | 0 | 0 |
| [6865](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6865) | `organiser_reception_diplomatique` | Organiser une réception diplomatique | 2 | 1200 |
| [6866](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6866) | `financer_oeuvre_culturelle` | Financer une œuvre culturelle | 1 | 600 |
| [6867](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6867) | `demander_transfert_detenu` | Demander le transfert d\'un détenu | 1 | 0 |
| [6911](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6911) | `ecouter_rumeurs` | Écouter la serveuse | 0 | 0 |
| [6912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6912) | `recruter_informateur_pnj` | Recruter un informateur | 1 | 150 |
| [6913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6913) | `produire_commerce` | Préparer les consommations | 0 | 0 |
| [6914](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6914) | `consulter_carte_commerce` | Consulter la carte | 0 | 0 |
| [6915](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6915) | `offrir_tournee` | Offrir à boire | 1 | 0 |
| [6916](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6916) | `gerer_commerce` | Gérer mon commerce | 0 | 0 |
| [6917](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6917) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [6928](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6928) | `louer_local` | Louer cette suite (500 PSK/jour) | 1 | 0 |
| [6929](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6929) | `gerer_local` | Gérer mon local | 1 | 0 |
| [6940](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6940) | `louer_local` | Louer cette suite (500 PSK/jour) | 1 | 0 |
| [6941](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6941) | `gerer_local` | Gérer mon local | 1 | 0 |
| [6952](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6952) | `louer_local` | Louer cette suite (500 PSK/jour) | 1 | 0 |
| [6953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6953) | `gerer_local` | Gérer mon local | 1 | 0 |
| [6986](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6986) | `louer_local` | Louer cet appartement (500 PSK/jour) | 1 | 0 |
| [6987](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6987) | `gerer_local` | Gérer mon local | 1 | 0 |
| [6998](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6998) | `louer_local` | Louer cet appartement (500 PSK/jour) | 1 | 0 |
| [6999](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6999) | `gerer_local` | Gérer mon local | 1 | 0 |
| [7010](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7010) | `louer_local` | Louer cet appartement (500 PSK/jour) | 1 | 0 |
| [7011](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7011) | `gerer_local` | Gérer mon local | 1 | 0 |
| [7022](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7022) | `louer_local` | Louer cet appartement (500 PSK/jour) | 1 | 0 |
| [7023](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7023) | `gerer_local` | Gérer mon local | 1 | 0 |
| [7034](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7034) | `louer_local` | Louer cet appartement (1200 PSK/jour) | 1 | 0 |
| [7035](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7035) | `gerer_local` | Gérer mon local | 1 | 0 |
| [7060](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7060) | `garage_vehicules` | Véhicules : vitrine et atelier | 0 | 0 |
| [7061](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7061) | `garage_reviser` | Faire réviser un véhicule | 0 | 0 |
| [7062](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7062) | `mes_vehicules` | Mes véhicules | 0 | 0 |
| [7087](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7087) | `salon_coupe` | Se faire couper les cheveux | 0 | 0 |
| [7119](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7119) | `gerer_logement_social` | Mon logement | 0 | 0 |
| [7130](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7130) | `gerer_logement_social` | Mon logement | 0 | 0 |
| [7141](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7141) | `gerer_logement_social` | Mon logement | 0 | 0 |
| [7152](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7152) | `gerer_logement_social` | Mon logement | 0 | 0 |
| [7163](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7163) | `gerer_logement_social` | Mon logement | 0 | 0 |
| [7174](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7174) | `gerer_logement_social` | Mon logement | 0 | 0 |
| [7185](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7185) | `gerer_logement_social` | Mon logement | 0 | 0 |
| [7196](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7196) | `gerer_logement_social` | Mon logement | 0 | 0 |
| [7221](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7221) | `pharmacie_medicaments` | Acheter des médicaments | 0 | 0 |
| [7246](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7246) | `poissonniere_poisson` | Acheter du poisson de rivière | 0 | 0 |
| [7247](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7247) | `ecouter_rumeurs` | Tendre l\'oreille | 0 | 0 |
| [7248](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7248) | `lancer_rumeur_cible` | Lui glisser une rumeur | 1 | 0 |
| [7249](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7249) | `contrebande_poissonniere` | Du poisson « de l\'autre rive » | 1 | 0 |
| [7268](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7268) | `station_carburant` | Acheter des bidons de carburant | 0 | 0 |
| [7269](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7269) | `mes_vehicules` | Mes véhicules | 0 | 0 |
| [7293](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7293) | `receptionner_commande` | Réceptionner une caisse | 1 | 0 |
| [7293](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7293) | `acheter_ressources_entrepot` | Réceptionner une caisse | 1 | 0 |
| [7302](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7302) | `tableau_bord_entrepot` | Tableau de bord logistique | 0 | 0 |
| [7303](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7303) | `fixer_prix_achat_entrepot` | Fixer les prix de vente | 1 | 0 |
| [7341](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7341) | `renseignement_militaire` | Renseignement militaire | 0 | 0 |
| [7350](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7350) | `interroger_renseignement` | Interroger un detenu | 2 | 0 |
| [7373](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7373) | `visiter_prisonnier` | Visiter un detenu | 1 | 0 |
| [7374](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7374) | `corrompre_fonct` | Corrompre le directeur | 3 | 1500 |
| [7375](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7375) | `archives_police` | Consulter le registre | 1 | 0 |
| [7388](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7388) | `greve_faim` | Greve de la faim | 0 | 0 |
| [7389](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7389) | `corrompre_gardien` | Corrompre un gardien | 2 | 800 |
| [7390](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7390) | `tentative_evasion` | Tenter de s\'evader | 3 | 0 |
| [7400](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7400) | `interroger` | Interroger un detenu | 2 | 0 |
| [7401](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7401) | `corrompre_fonct` | Falsifier un proces-verbal | 3 | 500 |
| [7411](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7411) | `se_reposer` | Prendre l\'air | 0 | 0 |
| [7452](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7452) | `prier` | Prier le Formulaire Sacré | 1 | 0 |
| [7453](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7453) | `faire_don` | Faire un don a l\'Eglise | 1 | 200 |
| [7495](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7495) | `prier` | Communier avec la Feuille | 1 | 0 |
| [7496](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7496) | `se_confesser` | Se confesser | 2 | 0 |
| [7497](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7497) | `faire_don` | Faire une offrande | 1 | 200 |
| [7498](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7498) | `pelerin` | Se déclarer pèlerin | 2 | 0 |
| [7522](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7522) | `prier` | Chanter l\'hymne au Tracteur | 1 | 0 |
| [7523](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7523) | `se_confesser` | Se confesser | 2 | 0 |
| [7524](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7524) | `faire_don` | Donner au Kolkhoze | 1 | 200 |
| [7525](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7525) | `pelerin` | Se déclarer pèlerin | 2 | 0 |
| [7549](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7549) | `prier` | Communier avec le Loukoum | 1 | 0 |
| [7550](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7550) | `se_confesser` | Se confesser | 2 | 0 |
| [7551](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7551) | `faire_don` | Offrir des loukoums | 1 | 200 |
| [7552](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7552) | `pelerin` | Se déclarer pèlerin | 2 | 0 |
| [7553](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7553) | `acheter_relique` | Acheter une relique du Loukoum | 0 | 500 |
| [7575](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7575) | `receptionner_commande` | Réceptionner une caisse | 1 | 0 |
| [7575](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7575) | `acheter_ressources_entrepot` | Réceptionner une caisse | 1 | 0 |
| [7584](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7584) | `tableau_bord_entrepot` | Tableau de bord logistique | 0 | 0 |
| [7585](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7585) | `fixer_prix_achat_entrepot` | Fixer les prix de vente | 1 | 0 |
| [7607](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7607) | `receptionner_commande` | Réceptionner une caisse | 1 | 0 |
| [7607](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7607) | `acheter_ressources_entrepot` | Réceptionner une caisse | 1 | 0 |
| [7616](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7616) | `tableau_bord_entrepot` | Tableau de bord logistique | 0 | 0 |
| [7617](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7617) | `fixer_prix_achat_entrepot` | Fixer les prix de vente | 1 | 0 |
| [7637](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7637) | `vente_directe_usine` | Vente directe | 0 | 0 |
| [7646](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7646) | `fixer_prix_vente_directe` | Fixer les prix de vente | 1 | 0 |
| [7647](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7647) | `fixer_repartition_production` | Répartir la production | 1 | 0 |
| [7648](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7648) | `virement_usine_ministere` | Virement vers le Ministère | 1 | 0 |
| [7658](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7658) | `produire_carburant` | Produire du carburant | 1 | 0 |
| [7659](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7659) | `produire_derives_petrochimiques` | Produire des dérivés pétrochimiques | 1 | 0 |
| [7662](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7662) | `vendre_matiere_usine` | Vendre des matières à l\'usine | 0 | 0 |
| [7686](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7686) | `consulter_offres_emploi` | Postes à pourvoir | 0 | 0 |
| [7687](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7687) | `bne_passer_annonce` | Passer une annonce | 1 | 0 |
| [7709](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7709) | `vente_directe_usine` | Vente directe | 0 | 0 |
| [7718](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7718) | `fixer_prix_vente_directe` | Fixer les prix de vente | 1 | 0 |
| [7719](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7719) | `fixer_repartition_production` | Répartir la production | 1 | 0 |
| [7720](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7720) | `virement_usine_ministere` | Virement vers le Ministère | 1 | 0 |
| [7730](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7730) | `produire_alcool` | Produire de l'alcool | 1 | 0 |
| [7733](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7733) | `vendre_matiere_usine` | Vendre des matières à l\'usine | 0 | 0 |
| [7743](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7743) | `produire_tabac` | Produire du tabac | 1 | 0 |
| [7746](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7746) | `vendre_matiere_usine` | Vendre des matières à l\'usine | 0 | 0 |
| [7766](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7766) | `receptionner_commande` | Réceptionner une caisse | 1 | 0 |
| [7766](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7766) | `acheter_ressources_entrepot` | Réceptionner une caisse | 1 | 0 |
| [7775](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7775) | `tableau_bord_entrepot` | Tableau de bord logistique | 0 | 0 |
| [7776](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7776) | `fixer_prix_achat_entrepot` | Fixer les prix de vente | 1 | 0 |
| [7796](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7796) | `receptionner_commande` | Réceptionner une caisse | 1 | 0 |
| [7796](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7796) | `acheter_ressources_entrepot` | Réceptionner une caisse | 1 | 0 |
| [7805](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7805) | `tableau_bord_entrepot` | Tableau de bord logistique | 0 | 0 |
| [7806](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7806) | `fixer_prix_achat_entrepot` | Fixer les prix de vente | 1 | 0 |
| [7827](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7827) | `vente_directe_usine` | Vente directe | 0 | 0 |
| [7833](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7833) | `acheter_sels_ammoniaque` | Acheter des sels d\'ammoniaque | 0 | 0 |
| [7843](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7843) | `fixer_prix_vente_directe` | Fixer les prix de vente | 1 | 0 |
| [7844](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7844) | `fixer_repartition_production` | Répartir la production | 1 | 0 |
| [7845](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7845) | `virement_usine_ministere` | Virement vers le Ministère | 1 | 0 |
| [7855](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7855) | `produire_medicaments` | Produire des médicaments | 1 | 0 |
| [7856](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7856) | `produire_desinfectant` | Produire du désinfectant | 1 | 0 |
| [7857](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7857) | `vendre_matiere_usine` | Vendre des matières à l\'usine | 0 | 0 |
| [7881](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7881) | `prendre_train` | Prendre le train | 2 | 75 |
| [7882](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7882) | `prendre_bus_taxi` | Prendre un bus ou taxi | 1 | 150 |
| [7883](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7883) | `aller_douanes_aeroport` | Prendre l\'avion | 0 | 0 |
| [7884](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7884) | `taxi_caserne` | Taxi vers la Caserne | 1 | 200 |
| [7885](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7885) | `taxi_qhs` | Taxi vers le QHS | 1 | 200 |
| [7897](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7897) | `passer_douanes_aeroport` | Passer le contrôle douanier | 0 | 0 |
| [7898](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7898) | `corrompre_douanier` | Corrompre l\'agent des douanes | 1 | 300 |
| [7910](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7910) | `prendre_avion` | Prendre l\'avion | 2 | 300 |
| [7933](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7933) | `prendre_train` | Prendre le train | 2 | 75 |
| [7934](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7934) | `prendre_bus_taxi` | Prendre un bus ou taxi | 1 | 150 |
| [7958](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7958) | `prendre_train` | Prendre le train | 2 | 75 |
| [7959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7959) | `prendre_bus_taxi` | Prendre un bus ou taxi | 1 | 150 |
| [7976](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7976) | `produire_commerce` | Produire | 0 | 0 |
| [7977](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7977) | `consulter_carte_commerce` | Consulter la carte | 0 | 0 |
| [7982](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7982) | `offrir_tournee` | Offrir à boire | 1 | 0 |
| [7983](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7983) | `gerer_commerce` | Gérer mon commerce | 0 | 0 |
| [7984](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7984) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [7987](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7987) | `lancer_rumeur_cible` | Lancer une rumeur | 1 | 0 |
| [7998](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7998) | `produire_commerce` | Cuisiner | 0 | 0 |
| [7999](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7999) | `consulter_carte_commerce` | Consulter la carte | 1 | 0 |
| [8000](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8000) | `gerer_commerce` | Gérer mon commerce | 0 | 0 |
| [8001](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8001) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [8004](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8004) | `lancer_rumeur_cible` | Lancer une rumeur | 1 | 0 |
| [8024](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8024) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [8025](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8025) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [8026](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8026) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [8027](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8027) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [8028](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8028) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [8029](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8029) | `consulter_personnalites_musee` | Consulter les personnalités | 0 | 0 |
| [8048](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8048) | `prier` | Prier le Formulaire Sacré | 1 | 0 |
| [8049](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8049) | `faire_don` | Faire un don a l\'Eglise | 1 | 200 |
| [8062](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8062) | `organiser_manifestation_spontanee` | Organiser une manifestation spontanée | 1 | 0 |
| [8093](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8093) | `travailler_jardins` | Travailler aux jardins | 1 | 0 |
| [8094](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8094) | `laisser_legumes_jardins` | Laisser des légumes | 0 | 0 |
| [8095](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8095) | `prendre_legumes_jardins` | Se servir dans la réserve | 0 | 0 |
| [8137](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8137) | `gerer_logement_social` | Mon logement | 0 | 0 |
| [8149](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8149) | `gerer_logement_social` | Mon logement | 0 | 0 |
| [8161](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8161) | `gerer_logement_social` | Mon logement | 0 | 0 |
| [8173](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8173) | `gerer_logement_social` | Mon logement | 0 | 0 |
| [8194](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8194) | `produire_commerce` | Produire | 0 | 0 |
| [8195](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8195) | `consulter_carte_commerce` | Consulter la carte | 0 | 0 |
| [8198](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8198) | `offrir_tournee` | Offrir à boire | 1 | 0 |
| [8199](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8199) | `gerer_commerce` | Gérer mon commerce | 0 | 0 |
| [8200](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8200) | `vendre_matiere_commerce` | Vendre des matières au commerce | 0 | 0 |
| [8201](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8201) | `lancer_rumeur_cible` | Lancer une rumeur | 1 | 0 |
| [8240](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8240) | `prendre_bateau` | Prendre le bateau | 5 | 100 |
| [8241](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8241) | `inspecter_cargaisons` | Inspecter les cargaisons | 2 | 0 |
| [8251](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8251) | `acheter_criee` | Acheter à la Criée | 0 | 0 |
| [8271](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8271) | `marchandises_non_reclamees` | Marchandises non réclamées | 0 | 0 |
| [8278](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8278) | `expedier_colis` | Réserver une caisse de fret | 2 | 200 |
| [8279](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8279) | `receptionner_commande` | Réceptionner une caisse | 1 | 0 |
| [8304](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8304) | `louer_box` | Louer un box (15 FR/jour) | 1 | 0 |
| [8305](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8305) | `gerer_box` | Gérer mon box | 1 | 0 |
| [8326](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8326) | `consulter_effectifs_douane` | Consulter les effectifs | 0 | 0 |
| [8327](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8327) | `recruter_douanier` | Recruter un douanier | 1 | 0 |
| [8328](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8328) | `recruter_douanier_cynophile` | Recruter une unité cynophile | 1 | 0 |
| [8329](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8329) | `gerer_effectifs_douane` | Gérer les effectifs douaniers | 0 | 0 |
| [8330](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8330) | `controler_caisse_douane` | Contrôler une caisse de fret | 1 | 0 |
| [8354](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8354) | `se_syndiquer` | Se syndiquer | 1 | 50 |
| [8355](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8355) | `consulter_organigramme_syndicat` | Consulter l\'organigramme | 0 | 0 |
| [8356](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8356) | `declencher_election_syndicat` | Déclencher une élection | 1 | 0 |
| [8357](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8357) | `organiser_manifestation_syndicat` | Organiser une manifestation | 2 | 0 |
| [8358](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8358) | `blocus_portuaire` | Blocus portuaire | 3 | 0 |
| [8371](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8371) | `consulter_manifeste` | Consulter le manifeste | 0 | 0 |
| [8372](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8372) | `consulter_administration_port` | Administration du port | 0 | 0 |
| [8373](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8373) | `gerer_logistique_port` | Gérer la logistique nationale | 0 | 0 |
| [8397](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8397) | `prendre_bateau` | Prendre le bateau | 5 | 100 |
| [8398](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8398) | `expedier_colis` | Expédier un colis | 2 | 200 |
| [8399](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8399) | `receptionner_commande` | Réceptionner une commande | 1 | 0 |
| [8400](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8400) | `contrebande_port` | Contrebande portuaire | 3 | 0 |
| [8401](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8401) | `acheter_polonium` | Obtenir du Polonium | 2 | 600 |
| [8402](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8402) | `inspecter_cargaisons` | Inspecter les cargaisons | 2 | 0 |
| [8426](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8426) | `prendre_bateau` | Prendre le bateau | 5 | 100 |
| [8427](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8427) | `expedier_colis` | Expédier un colis | 2 | 200 |
| [8428](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8428) | `receptionner_commande` | Réceptionner une commande | 1 | 0 |
| [8429](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8429) | `contrebande_port` | Contrebande portuaire | 3 | 0 |
| [8430](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8430) | `acheter_ghb` | Acheter du GHB | 0 | 300 |
| [8431](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8431) | `blocus_portuaire` | Blocus portuaire | 3 | 0 |
| [8455](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8455) | `prendre_bateau` | Prendre le bateau | 5 | 100 |
| [8456](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8456) | `expedier_colis` | Expédier un colis | 2 | 200 |
| [8457](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8457) | `receptionner_commande` | Réceptionner une commande | 1 | 0 |
| [8458](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8458) | `contrebande_port` | Contrebande portuaire | 3 | 0 |
| [8459](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8459) | `acheter_vipere` | Acheter une Vipère des sables | 0 | 350 |
| [8460](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8460) | `inspecter_cargaisons` | Inspecter les cargaisons | 2 | 0 |
| [9230](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9230) | `orga_petition` | Lancer une pétition | 2 | 0 |
| [9231](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9231) | `orga_meeting` | Organiser un meeting | 3 | 500 |
| [9232](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9232) | `demander_autorisation_manifester` | Demander une autorisation de manifester | 1 | 0 |
| [9251](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9251) | `orga_benediction` | Ceremonie de benediction | 2 | 200 |
| [9252](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9252) | `orga_anatheme` | Ceremonie d\'anatheme | 2 | 200 |
| [9253](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9253) | `orga_collecte` | Collecte de dons | 2 | 0 |
| [9254](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9254) | `orga_pelerinage` | Organiser un pelerinage | 3 | 1000 |
| [9255](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9255) | `orga_excommunier` | Excommunier un membre | 1 | 0 |
| [9256](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9256) | `demander_autorisation_manifester` | Demander une autorisation de manifester | 1 | 0 |
| [9274](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9274) | `demander_autorisation_manifester` | Demander une autorisation de manifester | 1 | 0 |
| [9275](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9275) | `greve_lancer` | Lancer une grève | 1 | 0 |
| [9278](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9278) | `greve_terminer` | Mettre fin à la grève | 0 | 0 |
| [9281](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9281) | `greve_generale_appeler` | Appeler à une grève générale | 1 | 0 |
| [9284](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9284) | `greve_generale_retirer` | Retirer le syndicat de la grève générale | 0 | 0 |
| [9305](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9305) | `orga_blocus` | Blocus commercial | 3 | 1000 |
| [9306](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9306) | `orga_dividendes` | Verser des dividendes | 1 | 0 |
| [9307](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9307) | `orga_audit` | Auditer un concurrent | 2 | 500 |
| [9326](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9326) | `orga_intimidation` | Intimidation | 2 | 0 |
| [9346](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9346) | `orga_cooptation` | Cooptation discrete | 2 | 1000 |
| [9347](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9347) | `orga_rituel` | Rituel d\'initiation | 2 | 500 |
| [9348](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9348) | `orga_reseau` | Activer le reseau | 2 | 300 |
| [9367](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9367) | `orga_campagne_presse` | Campagne de presse | 2 | 500 |
| [9368](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9368) | `orga_fake_news` | Fake news | 2 | 300 |
| [9369](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9369) | `orga_rehabilitation` | Rehabilitation d\'image | 3 | 1000 |
| [9370](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9370) | `orga_scoop` | Publier un scoop | 2 | 0 |
| [9371](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9371) | `orga_silence` | Etouffer une affaire | 3 | 2000 |
| [9406](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9406) | `orga_motion_supporters` | Publier un communique | 1 | 0 |
| [9407](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9407) | `orga_hooliganisme` | Organiser des echauffourees | 3 | 0 |
| [9408](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L9408) | `demander_autorisation_manifester` | Demander une autorisation de manifester | 1 | 0 |
| [10149](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L10149) | `corrompre_fonctionnaire_permis` | Corrompre un fonctionnaire (accélérer le permis) | 2 | 800 |
| [10530](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L10530) | `sovarka_reunion_reserver` | — | — | — |
| [10538](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L10538) | `sovarka_reunion_evenement` | — | — | — |
| [10549](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L10549) | `sovarka_demande_location` | Demande de location | 1 | 0 |
| [10589](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L10589) | `sovarka_partis` | Partis constitués | 0 | 0 |
| [10591](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L10591) | `sovarka_parti_fonder` | Créer un parti | 2 | 15 |
| [10593](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L10593) | `sovarka_mon_parti` | Mon parti | 0 | 0 |
| [10596](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L10596) | `sovarka_extrait_parti` | Extrait d'enregistrement du parti | 1 | 7 |

**Interprétation interdite :** jamais assimiler cet inventaire aux 846 ordres/346 actions historiques ; les deux nombres relèvent de comptages et de dates distincts. Les références sont des points de départ pour reconstruire pays/ville/bâtiment/pièce/préconditions/handler/RPC/tests. Les champs dynamiques et les autres modules client ne sont pas couverts par ce relevé.
