# Catalogue des bâtiments, pièces et ordres — source statique data.js

**Extraction technique du 9 novembre 2026**. Périmètre **uniquement** l'objet littéral `BUILDINGS` dans [`data.js`](../data.js), version [`a8bd5e26`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js). Les déclarations dynamiques, les variantes de pièces ou les routes serveur peuvent modifier les lieux réellement affichés.

**110 clés de bâtiments**, **303 clés de pièces** et **956 références `fn`** explicitement situées par cette analyse ; ces nombres **ne remplacent pas** les totaux historiques 93/249/846, dont le périmètre et la date sont différents. 0 ordres sans pièce dans ce parseur (contrôle interne de localisation).

**Avertissement** : l'ordre peut être un menu, une action grisée, une fonction conditionnelle, un double emploi ou une entrée dans une ville non jouable ; la présence dans la liste ne certifie aucune interaction. Les lignes de source permettent de poursuivre jusqu'au handler, au contrôle serveur et au test.

## Localisation de chaque déclaration

| Bâtiment | Pièce | Fonction `fn` | Source |
|---|---|---|---|
| `hotel-republica` | `accueil` | `reserver_chambre_hotel` | [L2764](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2764) |
| `hotel-republica` | `accueil` | `choisir_suite` | [L2765](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2765) |
| `hotel-republica` | `restaurant` | `diner_affaires` | [L2782](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2782) |
| `hotel-republica` | `restaurant` | `ecouter_rumeurs` | [L2783](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2783) |
| `hotel-republica` | `restaurant` | `lancer_rumeur_cible` | [L2784](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2784) |
| `hotel-republica` | `restaurant` | `produire_commerce` | [L2785](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2785) |
| `hotel-republica` | `restaurant` | `consulter_carte_commerce` | [L2786](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2786) |
| `hotel-republica` | `restaurant` | `gerer_commerce` | [L2787](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2787) |
| `hotel-republica` | `restaurant` | `vendre_matiere_commerce` | [L2788](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2788) |
| `hotel-republica` | `bar` | `ecouter_rumeurs` | [L2804](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2804) |
| `hotel-republica` | `bar` | `recruter_informateur_pnj` | [L2805](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2805) |
| `hotel-republica` | `bar` | `escort_piege` | [L2806](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2806) |
| `hotel-republica` | `bar` | `produire_commerce` | [L2807](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2807) |
| `hotel-republica` | `bar` | `consulter_carte_commerce` | [L2808](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2808) |
| `hotel-republica` | `bar` | `offrir_tournee` | [L2809](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2809) |
| `hotel-republica` | `bar` | `gerer_commerce` | [L2810](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2810) |
| `hotel-republica` | `bar` | `vendre_matiere_commerce` | [L2811](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2811) |
| `hotel-republica` | `chambres` | `dormir_chambre` | [L2822](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2822) |
| `hotel-republica` | `chambres` | `service_etage` | [L2823](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2823) |
| `hotel-republica` | `suite_privee` | `louer_local` | [L2835](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2835) |
| `hotel-republica` | `suite_privee` | `gerer_local` | [L2836](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2836) |
| `hotel-republica` | `suite_presidentielle` | `louer_local` | [L2848](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2848) |
| `hotel-republica` | `suite_presidentielle` | `gerer_local` | [L2849](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2849) |
| `palais-presidentiel` | `accueil_elysee` | `solliciter_audience_president` | [L2876](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2876) |
| `palais-presidentiel` | `bureau_president` | `gestion_premier_ministre` | [L2908](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2908) |
| `palais-presidentiel` | `bureau_president` | `postes_par_decret` | [L2909](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2909) |
| `palais-presidentiel` | `bureau_president` | `pouvoirs_exceptionnels` | [L2910](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2910) |
| `palais-presidentiel` | `bureau_president` | `adresse_a_la_nation` | [L2911](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2911) |
| `palais-presidentiel` | `bureau_president` | `gracier` | [L2912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2912) |
| `palais-presidentiel` | `bureau_president` | `effort_national` | [L2915](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2915) |
| `palais-presidentiel` | `salle_presse_elysee` | `conference_presse` | [L2927](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2927) |
| `palais-presidentiel` | `salle_presse_elysee` | `propagande_etat` | [L2928](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2928) |
| `palais-presidentiel` | `salle_presse_elysee` | `dementi` | [L2929](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2929) |
| `palais-presidentiel` | `salle_reception` | `reception_etat` | [L2945](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2945) |
| `palais-presidentiel` | `salle_reception` | `banquet_diplo` | [L2946](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2946) |
| `palais-gouvernement` | `hall` | `postuler` | [L2981](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2981) |
| `palais-gouvernement` | `bureaux` | `nommer_ministre_pm` | [L2998](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2998) |
| `palais-gouvernement` | `bureaux` | `revoquer_ministre_pm` | [L2999](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2999) |
| `palais-gouvernement` | `bureaux` | `declencher_vote_confiance` | [L3000](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3000) |
| `palais-gouvernement` | `salle_presse` | `conference_presse` | [L3035](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3035) |
| `palais-gouvernement` | `salle_presse` | `propagande_etat` | [L3036](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3036) |
| `palais-gouvernement` | `salle_presse` | `dementi` | [L3037](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3037) |
| `palais-gouvernement` | `archives_gouv` | `consulter_dossiers_gouv` | [L3050](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3050) |
| `palais-gouvernement` | `archives_gouv` | `fuite_info` | [L3051](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3051) |
| `palais-gouvernement` | `bureau_min_int` | `gestion_manifestations` | [L3092](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3092) |
| `palais-gouvernement` | `bureau_min_int` | `demandes_naturalisation` | [L3093](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3093) |
| `palais-gouvernement` | `bureau_min_int` | `gerer_couvre_feu` | [L3094](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3094) |
| `palais-gouvernement` | `bureau_min_int` | `gerer_chef_douanes` | [L3095](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3095) |
| `palais-gouvernement` | `bureau_min_int` | `gerer_budget_interieur` | [L3106](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3106) |
| `palais-gouvernement` | `bureau_min_int` | `subvention_min_int` | [L3107](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3107) |
| `palais-gouvernement` | `bureau_min_int` | `lois_votees_an` | [L3114](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3114) |
| `palais-gouvernement` | `bureau_min_fin` | `pilotage_fiscal_budgetaire` | [L3141](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3141) |
| `palais-gouvernement` | `bureau_min_fin` | `bne_caisse_prelever` | [L3142](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3142) |
| `palais-gouvernement` | `bureau_min_fin` | `subvention` | [L3143](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3143) |
| `palais-gouvernement` | `bureau_min_fin` | `gestion_industrielle_portuaire` | [L3144](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3144) |
| `palais-gouvernement` | `bureau_min_fin` | `preempter_entreprise` | [L3145](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3145) |
| `palais-gouvernement` | `bureau_min_just` | `ouvrir_enquete` | [L3177](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3177) |
| `palais-gouvernement` | `bureau_min_just` | `proposer_grace` | [L3178](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3178) |
| `palais-gouvernement` | `bureau_min_just` | `gerer_juges` | [L3179](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3179) |
| `palais-gouvernement` | `bureau_min_just` | `gerer_budget_justice` | [L3183](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3183) |
| `palais-gouvernement` | `bureau_min_just` | `gestion_qhs` | [L3184](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3184) |
| `palais-gouvernement` | `bureau_min_def` | `mobilisation_nationale` | [L3219](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3219) |
| `palais-gouvernement` | `bureau_min_def` | `activer_cessez_le_feu` | [L3220](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3220) |
| `palais-gouvernement` | `bureau_min_def` | `garde_republicaine` | [L3227](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3227) |
| `palais-gouvernement` | `bureau_min_def` | `renseignement_militaire` | [L3241](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3241) |
| `palais-gouvernement` | `bureau_min_def` | `gestion_caserne` | [L3248](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3248) |
| `palais-gouvernement` | `bureau_min_info` | `propagande_etat` | [L3275](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3275) |
| `palais-gouvernement` | `bureau_min_info` | `censurer_media` | [L3276](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3276) |
| `palais-gouvernement` | `bureau_min_info` | `commanditer_sondage` | [L3277](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3277) |
| `palais-gouvernement` | `bureau_min_info` | `dementi` | [L3278](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3278) |
| `palais-gouvernement` | `bureau_min_ae` | `proposer_treve` | [L3305](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3305) |
| `palais-gouvernement` | `bureau_min_ae` | `diplomatie_bilaterale` | [L3306](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3306) |
| `palais-gouvernement` | `bureau_min_ae` | `gerer_ambassades` | [L3307](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3307) |
| `assemblee` | `accueil_assemblee` | `calendrier_elections` | [L3351](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3351) |
| `assemblee` | `accueil_assemblee` | `seance_parlementaire` | [L3356](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3356) |
| `assemblee` | `hemicycle` | `seance_parlementaire` | [L3381](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3381) |
| `assemblee` | `hemicycle` | `observer_debats` | [L3382](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3382) |
| `assemblee` | `hemicycle` | `voter_loi` | [L3383](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3383) |
| `assemblee` | `hemicycle` | `projet_loi` | [L3384](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3384) |
| `assemblee` | `hemicycle` | `amender_projet` | [L3385](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3385) |
| `assemblee` | `hemicycle` | `marchander_vote` | [L3391](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3391) |
| `assemblee` | `hemicycle` | `reveiller_depute` | [L3392](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3392) |
| `assemblee` | `couloirs` | `consulter_lobbyiste` | [L3406](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3406) |
| `assemblee` | `couloirs` | `ecouter_rumeurs` | [L3407](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3407) |
| `assemblee` | `salle_archives_assemblee` | `registre_assemblee` | [L3422](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3422) |
| `office-notarial` | `accueil_notaire` | `consulter_dossier_notarial` | [L3448](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3448) |
| `office-notarial` | `bureau_successions` | `gerer_testament` | [L3465](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3465) |
| `office-notarial` | `bureau_successions` | `reclamer_heritage` | [L3466](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3466) |
| `office-notarial` | `bureau_contrats` | `officialiser_transaction` | [L3478](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3478) |
| `office-notarial` | `bureau_contrats` | `commerces_fonds_murs` | [L3479](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3479) |
| `office-notarial` | `bureau_contrats` | `racheter_entreprise` | [L3480](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3480) |
| `office-notarial` | `bureau_contrats` | `acte_rachat_entreprise_preemption` | [L3481](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3481) |
| `office-notarial` | `bureau_contrats` | `transfert_compromis` | [L3482](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3482) |
| `office-notarial` | `bureau_contrats` | `demander_divorce` | [L3483](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3483) |
| `office-notarial` | `bureau_contrats` | `acte_officiel_notaire` | [L3484](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3484) |
| `office-notarial` | `archives_notariales` | `consulter_archives_notariales` | [L3496](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3496) |
| `stade` | `terrain` | `observer_match` | [L3520](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3520) |
| `stade` | `terrain` | `regarder_live` | [L3521](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3521) |
| `stade` | `vestiaires` | `prendre_licence_sportive` | [L3533](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3533) |
| `stade` | `vestiaires` | `demander_non_renouvellement_licence` | [L3534](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3534) |
| `stade` | `vestiaires` | `annuler_non_renouvellement_licence` | [L3535](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3535) |
| `stade` | `vestiaires` | `tenue_entrainement` | [L3536](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3536) |
| `stade` | `vestiaires` | `tenue_match` | [L3537](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3537) |
| `stade` | `vestiaires` | `conseil_entraineur_adjoint` | [L3538](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3538) |
| `stade` | `buvette` | `consommer_buvette` | [L3550](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3550) |
| `stade` | `buvette` | `produire_commerce` | [L3551](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3551) |
| `stade` | `buvette` | `consulter_carte_commerce` | [L3552](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3552) |
| `stade` | `buvette` | `vendre_matiere_commerce` | [L3553](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3553) |
| `stade` | `buvette` | `choisir_accessoire_club` | [L3554](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3554) |
| `stade` | `buvette` | `acheter_accessoire_personnalise` | [L3555](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3555) |
| `stade` | `guichet_paris` | `parier_match` | [L3567](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3567) |
| `stade` | `guichet_paris` | `consulter_classement_joueurs_club` | [L3568](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3568) |
| `stade` | `siege_supporters` | `rejoindre_club_supporters` | [L3580](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3580) |
| `stade` | `siege_supporters` | `consulter_palmares` | [L3581](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3581) |
| `stade` | `siege_supporters` | `consulter_organigramme_supporters` | [L3582](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3582) |
| `stade` | `siege_supporters` | `declencher_election_club` | [L3583](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3583) |
| `stade` | `siege_supporters` | `organiser_manifestation` | [L3584](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3584) |
| `stade` | `siege_supporters` | `organiser_boycott` | [L3585](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3585) |
| `stade` | `bureau_president` | `postuler_president_club` | [L3595](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3595) |
| `stade` | `bureau_president` | `consulter_bureau_president` | [L3596](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3596) |
| `stade` | `bureau_president` | `proposer_transfert` | [L3597](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3597) |
| `stade` | `bureau_president` | `gerer_offres_transfert` | [L3598](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3598) |
| `stade` | `bureau_president` | `sponsoriser_club` | [L3599](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3599) |
| `stade` | `bureau_president` | `consulter_budget_club` | [L3600](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3600) |
| `stade` | `bureau_president` | `gerer_salaires_club` | [L3601](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3601) |
| `zone-production` | `zone_recolte` | `recolter_matiere` | [L3622](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3622) |
| `tribunal` | `salle_audience` | `defense` | [L3664](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3664) |
| `tribunal` | `salle_audience` | `temoins_mes_convocations` | [L3665](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3665) |
| `tribunal` | `salle_audience` | `audience_salle` | [L3666](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3666) |
| `tribunal` | `bureau_magistrats` | `parquet` | [L3689](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3689) |
| `tribunal` | `bureau_magistrats` | `rendre_sentence` | [L3690](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3690) |
| `tribunal` | `bureau_magistrats` | `audience_juge` | [L3691](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3691) |
| `tribunal` | `bureau_magistrats` | `acte_officiel_juge` | [L3692](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3692) |
| `tribunal` | `greffe` | `archives` | [L3705](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3705) |
| `tribunal` | `greffe` | `falsifier_document` | [L3706](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3706) |
| `tribunal` | `greffe` | `demander_juge_instruction` | [L3707](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3707) |
| `tribunal` | `greffe` | `avocat_dossiers` | [L3711](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3711) |
| `tribunal` | `greffe` | `avocat_barreau` | [L3712](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3712) |
| `tribunal` | `greffe` | `greffe_affaires` | [L3713](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3713) |
| `tribunal` | `greffe` | `greffe_archives` | [L3714](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3714) |
| `tribunal` | `greffe` | `casier_mon_extrait` | [L3720](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3720) |
| `tribunal` | `greffe` | `casier_extrait_enquete` | [L3721](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3721) |
| `tribunal` | `greffe` | `orga_extrait_duplicata` | [L3722](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3722) |
| `tribunal` | `greffe` | `greffe_corrompre_dossier` | [L3723](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3723) |
| `tribunal` | `greffe` | `greffe_corrompre_faux_casier` | [L3724](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3724) |
| `banque-nationale` | `accueil_banque` | `gerer_finances` | [L3749](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3749) |
| `banque-nationale` | `accueil_banque` | `emprunter` | [L3750](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3750) |
| `banque-nationale` | `accueil_banque` | `virements` | [L3752](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3752) |
| `banque-nationale` | `accueil_banque` | `presenter_autorisation_coffre` | [L3753](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3753) |
| `banque-nationale` | `coffre_privatif` | `louer_local` | [L3765](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3765) |
| `banque-nationale` | `coffre_privatif` | `gerer_local` | [L3766](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3766) |
| `banque-privee` | `bureau_prive` | `gerer_finances` | [L3791](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3791) |
| `banque-privee` | `bureau_prive` | `compte_offshore` | [L3792](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3792) |
| `banque-privee` | `bureau_prive` | `emprunter_prive` | [L3793](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3793) |
| `banque-privee` | `bureau_prive` | `blanchiment` | [L3794](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3794) |
| `banque-privee` | `bureau_prive` | `societe_ecran` | [L3795](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3795) |
| `clinique-privee` | `reception_clinique` | `vendre_ressource_medicale` | [L3820](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3820) |
| `clinique-privee` | `reception_clinique` | `ouvrir_chambres_clinique` | [L3821](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3821) |
| `clinique-privee` | `reception_clinique` | `sortie_hopital` | [L3822](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3822) |
| `clinique-privee` | `chambre_1` | `gerer_visites_chambre` | [L3837](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3837) |
| `clinique-privee` | `chambre_1` | `soins` | [L3838](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3838) |
| `clinique-privee` | `chambre_1` | `soins_urgence` | [L3839](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3839) |
| `clinique-privee` | `chambre_1` | `soins_discrets` | [L3840](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3840) |
| `clinique-privee` | `chambre_1` | `centre_anti_poison` | [L3841](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3841) |
| `clinique-privee` | `chambre_1` | `repas_clinique` | [L3842](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3842) |
| `clinique-privee` | `chambre_1` | `sortie_hopital` | [L3843](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3843) |
| `clinique-privee` | `chambre_2` | `gerer_visites_chambre` | [L3846](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3846) |
| `clinique-privee` | `chambre_2` | `soins` | [L3847](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3847) |
| `clinique-privee` | `chambre_2` | `soins_urgence` | [L3848](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3848) |
| `clinique-privee` | `chambre_2` | `soins_discrets` | [L3849](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3849) |
| `clinique-privee` | `chambre_2` | `centre_anti_poison` | [L3850](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3850) |
| `clinique-privee` | `chambre_2` | `repas_clinique` | [L3851](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3851) |
| `clinique-privee` | `chambre_2` | `sortie_hopital` | [L3852](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3852) |
| `clinique-privee` | `chambre_3` | `gerer_visites_chambre` | [L3855](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3855) |
| `clinique-privee` | `chambre_3` | `soins` | [L3856](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3856) |
| `clinique-privee` | `chambre_3` | `soins_urgence` | [L3857](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3857) |
| `clinique-privee` | `chambre_3` | `soins_discrets` | [L3858](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3858) |
| `clinique-privee` | `chambre_3` | `centre_anti_poison` | [L3859](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3859) |
| `clinique-privee` | `chambre_3` | `repas_clinique` | [L3860](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3860) |
| `clinique-privee` | `chambre_3` | `sortie_hopital` | [L3861](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3861) |
| `clinique-privee` | `chambre_4` | `gerer_visites_chambre` | [L3864](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3864) |
| `clinique-privee` | `chambre_4` | `soins` | [L3865](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3865) |
| `clinique-privee` | `chambre_4` | `soins_urgence` | [L3866](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3866) |
| `clinique-privee` | `chambre_4` | `soins_discrets` | [L3867](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3867) |
| `clinique-privee` | `chambre_4` | `centre_anti_poison` | [L3868](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3868) |
| `clinique-privee` | `chambre_4` | `repas_clinique` | [L3869](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3869) |
| `clinique-privee` | `chambre_4` | `sortie_hopital` | [L3870](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3870) |
| `clinique-privee` | `chambre_5` | `gerer_visites_chambre` | [L3873](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3873) |
| `clinique-privee` | `chambre_5` | `soins` | [L3874](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3874) |
| `clinique-privee` | `chambre_5` | `soins_urgence` | [L3875](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3875) |
| `clinique-privee` | `chambre_5` | `soins_discrets` | [L3876](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3876) |
| `clinique-privee` | `chambre_5` | `centre_anti_poison` | [L3877](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3877) |
| `clinique-privee` | `chambre_5` | `repas_clinique` | [L3878](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3878) |
| `clinique-privee` | `chambre_5` | `sortie_hopital` | [L3879](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3879) |
| `clinique-privee` | `chambre_6` | `gerer_visites_chambre` | [L3882](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3882) |
| `clinique-privee` | `chambre_6` | `soins` | [L3883](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3883) |
| `clinique-privee` | `chambre_6` | `soins_urgence` | [L3884](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3884) |
| `clinique-privee` | `chambre_6` | `soins_discrets` | [L3885](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3885) |
| `clinique-privee` | `chambre_6` | `centre_anti_poison` | [L3886](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3886) |
| `clinique-privee` | `chambre_6` | `repas_clinique` | [L3887](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3887) |
| `clinique-privee` | `chambre_6` | `sortie_hopital` | [L3888](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3888) |
| `clinique-privee` | `chambre_7` | `gerer_visites_chambre` | [L3891](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3891) |
| `clinique-privee` | `chambre_7` | `soins` | [L3892](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3892) |
| `clinique-privee` | `chambre_7` | `soins_urgence` | [L3893](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3893) |
| `clinique-privee` | `chambre_7` | `soins_discrets` | [L3894](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3894) |
| `clinique-privee` | `chambre_7` | `centre_anti_poison` | [L3895](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3895) |
| `clinique-privee` | `chambre_7` | `repas_clinique` | [L3896](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3896) |
| `clinique-privee` | `chambre_7` | `sortie_hopital` | [L3897](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3897) |
| `clinique-privee` | `chambre_8` | `gerer_visites_chambre` | [L3900](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3900) |
| `clinique-privee` | `chambre_8` | `soins` | [L3901](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3901) |
| `clinique-privee` | `chambre_8` | `soins_urgence` | [L3902](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3902) |
| `clinique-privee` | `chambre_8` | `soins_discrets` | [L3903](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3903) |
| `clinique-privee` | `chambre_8` | `centre_anti_poison` | [L3904](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3904) |
| `clinique-privee` | `chambre_8` | `repas_clinique` | [L3905](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3905) |
| `clinique-privee` | `chambre_8` | `sortie_hopital` | [L3906](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3906) |
| `clinique-privee` | `chambre_9` | `gerer_visites_chambre` | [L3909](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3909) |
| `clinique-privee` | `chambre_9` | `soins` | [L3910](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3910) |
| `clinique-privee` | `chambre_9` | `soins_urgence` | [L3911](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3911) |
| `clinique-privee` | `chambre_9` | `soins_discrets` | [L3912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3912) |
| `clinique-privee` | `chambre_9` | `centre_anti_poison` | [L3913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3913) |
| `clinique-privee` | `chambre_9` | `repas_clinique` | [L3914](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3914) |
| `clinique-privee` | `chambre_9` | `sortie_hopital` | [L3915](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3915) |
| `clinique-privee` | `chambre_10` | `gerer_visites_chambre` | [L3918](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3918) |
| `clinique-privee` | `chambre_10` | `soins` | [L3919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3919) |
| `clinique-privee` | `chambre_10` | `soins_urgence` | [L3920](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3920) |
| `clinique-privee` | `chambre_10` | `soins_discrets` | [L3921](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3921) |
| `clinique-privee` | `chambre_10` | `centre_anti_poison` | [L3922](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3922) |
| `clinique-privee` | `chambre_10` | `repas_clinique` | [L3923](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3923) |
| `clinique-privee` | `chambre_10` | `sortie_hopital` | [L3924](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3924) |
| `dispensaire-public` | `salle_attente` | `soin_public` | [L3949](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3949) |
| `dispensaire-public` | `salle_attente` | `repas_hopital` | [L3950](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3950) |
| `dispensaire-public` | `salle_attente` | `sortie_hopital` | [L3951](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3951) |
| `dispensaire-public` | `salle_attente` | `centre_anti_poison` | [L3952](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3952) |
| `dispensaire-public` | `salle_attente` | `transfert_clinique_privee` | [L3953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3953) |
| `dispensaire-public` | `salle_attente` | `vendre_ressource_medicale` | [L3954](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3954) |
| `commissariat` | `accueil_police` | `plainte_police` | [L3990](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3990) |
| `commissariat` | `accueil_police` | `archives_police` | [L3991](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3991) |
| `commissariat` | `accueil_police` | `arreter` | [L3992](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3992) |
| `commissariat` | `accueil_police` | `se_justifier` | [L3993](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3993) |
| `commissariat` | `accueil_police` | `temoin_deposition` | [L3998](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3998) |
| `commissariat` | `prison` | `se_rebeller` | [L4010](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4010) |
| `commissariat` | `prison` | `tentative_evasion` | [L4011](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4011) |
| `commissariat` | `bureau_commissaire` | `dossiers_plaintes` | [L4025](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4025) |
| `commissariat` | `bureau_commissaire` | `mener_enquete` | [L4026](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4026) |
| `commissariat` | `bureau_commissaire` | `organiser_filature` | [L4027](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4027) |
| `commissariat` | `bureau_commissaire` | `organiser_chasse_homme` | [L4028](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4028) |
| `commissariat` | `bureau_commissaire` | `recruter_policier` | [L4029](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4029) |
| `commissariat` | `bureau_commissaire` | `recruter_policier_cynophile` | [L4030](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4030) |
| `commissariat` | `bureau_commissaire` | `mobiliser_police` | [L4031](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4031) |
| `commissariat` | `bureau_commissaire` | `gerer_effectifs_police` | [L4032](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4032) |
| `la-tribune` | `accueil_tribune` | `se_renseigner` | [L4063](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4063) |
| `la-tribune` | `accueil_tribune` | `imprimer_tracts_electoraux` | [L4068](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4068) |
| `la-tribune` | `accueil_tribune` | `vendre_bois_imprimerie` | [L4069](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4069) |
| `la-tribune` | `redaction` | `publicite_premium` | [L4083](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4083) |
| `la-tribune` | `redaction` | `consulter_archives_presse` | [L4084](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4084) |
| `la-tribune` | `redaction` | `produire_fuite` | [L4087](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4087) |
| `la-tribune` | `redaction` | `fabriquer_scandale` | [L4091](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4091) |
| `la-tribune` | `redaction` | `interview` | [L4092](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4092) |
| `la-tribune` | `redaction` | `article` | [L4093](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4093) |
| `la-tribune` | `redaction` | `corrompre_journaliste` | [L4096](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4096) |
| `la-tribune` | `redaction` | `etouffer` | [L4097](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4097) |
| `loge-maconnique` | `portail` | `demander_parler_loge` | [L4123](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4123) |
| `loge-maconnique` | `bureau_venerable` | `recruter_informateur_2` | [L4150](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4150) |
| `loge-maconnique` | `bureau_venerable` | `recruter_info_4` | [L4151](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4151) |
| `loge-maconnique` | `bureau_venerable` | `consulter_info_4` | [L4152](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4152) |
| `loge-maconnique` | `bureau_venerable` | `gerer_informateurs` | [L4153](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4153) |
| `loge-maconnique` | `salle_reunion_loge` | `deliberer_loge` | [L4166](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4166) |
| `universite` | `amphi` | `donner_conf` | [L4191](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4191) |
| `universite` | `amphi` | `recruter_etud` | [L4192](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4192) |
| `universite` | `amphi` | `suivre_formation` | [L4208](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4208) |
| `universite` | `salle_reunion` | `syndicat_etudiant_creer` | [L4234](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4234) |
| `universite` | `salle_reunion` | `syndicat_etudiant_gerer` | [L4235](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4235) |
| `universite` | `salle_reunion` | `recruter_etud` | [L4236](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4236) |
| `armurerie` | `magasin` | `choisir_arme` | [L4261](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4261) |
| `armurerie` | `magasin` | `acheter_gilet` | [L4267](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4267) |
| `armurerie` | `magasin` | `consulter_registre_armes` | [L4274](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4274) |
| `armurerie` | `magasin` | `produire_arme` | [L4279](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4279) |
| `armurerie` | `magasin` | `vendre_matiere_commerce` | [L4280](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4280) |
| `marche` | `marche_ext` | `se_nourrir` | [L4306](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4306) |
| `marche` | `marche_ext` | `pouls_populaire` | [L4307](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4307) |
| `marche` | `marche_ext` | `lancer_rumeur_cible` | [L4310](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4310) |
| `mairie-capitale` | `hall_mairie` | `calendrier_elections` | [L4338](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4338) |
| `mairie-capitale` | `hall_mairie` | `etat_civil` | [L4348](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4348) |
| `mairie-capitale` | `hall_mairie` | `objet_trouve` | [L4350](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4350) |
| `mairie-capitale` | `hall_mairie` | `consulter_organigramme_mairie` | [L4351](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4351) |
| `mairie-capitale` | `bureau_maire` | `fixer_impots_locaux` | [L4363](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4363) |
| `mairie-capitale` | `bureau_maire` | `repartition_budget_local` | [L4364](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4364) |
| `mairie-capitale` | `bureau_maire` | `subvention_proposer` | [L4365](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4365) |
| `mairie-capitale` | `bureau_maire` | `campagne_securite` | [L4366](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4366) |
| `mairie-capitale` | `bureau_maire` | `nominations_municipales` | [L4367](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4367) |
| `mairie-capitale` | `bureau_maire_adjoint` | `traiter_demandes_permis` | [L4377](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4377) |
| `mairie-capitale` | `bureau_maire_adjoint` | `consulter_dossiers_urbanisme` | [L4378](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4378) |
| `mairie-capitale` | `bureau_maire_adjoint` | `demander_logement_social` | [L4380](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4380) |
| `mairie-capitale` | `bureau_maire_adjoint` | `traiter_demandes_logement_social` | [L4381](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4381) |
| `mairie-capitale` | `bureau_maire_adjoint` | `acte_officiel_mairie` | [L4382](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4382) |
| `mairie-capitale` | `bureau_maire_adjoint` | `financer_communal` | [L4383](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4383) |
| `mairie-capitale` | `salle_elections` | `consulter_elections` | [L4395](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4395) |
| `mairie-capitale` | `salle_elections` | `voter_election` | [L4396](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4396) |
| `mairie-capitale` | `salle_elections` | `contester_resultats` | [L4401](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4401) |
| `mairie-capitale` | `salle_elections` | `falsifier_listes_electorales` | [L4402](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4402) |
| `mairie-capitale` | `salle_elections` | `bourrer_urnes` | [L4403](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4403) |
| `mairie-capitale` | `salle_elections` | `truquer_depouillement` | [L4404](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4404) |
| `mairie-capitale` | `salle_archives` | `consulter_etat_civil` | [L4416](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4416) |
| `mairie-capitale` | `salle_archives` | `consulter_mandats_maires` | [L4417](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4417) |
| `musee-port-sainte-marie` | `salle_criminels` | `consulter_personnalites_musee` | [L4460](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4460) |
| `musee-port-sainte-marie` | `salle_maires` | `consulter_personnalites_musee` | [L4471](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4471) |
| `musee-port-sainte-marie` | `salle_personnalites` | `consulter_personnalites_musee` | [L4482](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4482) |
| `musee-port-sainte-marie` | `salle_entrepreneurs` | `consulter_personnalites_musee` | [L4493](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4493) |
| `musee-port-sainte-marie` | `salle_organisations` | `consulter_personnalites_musee` | [L4504](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4504) |
| `musee-port-sainte-marie` | `salle_honneur_militaire` | `consulter_personnalites_musee` | [L4527](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4527) |
| `musee-port-sainte-marie` | `salle_unions` | `consulter_personnalites_musee` | [L4538](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4538) |
| `musee-port-sainte-marie` | `salle_scandales` | `consulter_personnalites_musee` | [L4551](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4551) |
| `musee-novomirsk` | `salle_criminels` | `consulter_personnalites_musee` | [L4587](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4587) |
| `musee-novomirsk` | `salle_maires` | `consulter_personnalites_musee` | [L4596](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4596) |
| `musee-novomirsk` | `salle_personnalites` | `consulter_personnalites_musee` | [L4605](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4605) |
| `musee-novomirsk` | `salle_entrepreneurs` | `consulter_personnalites_musee` | [L4614](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4614) |
| `musee-novomirsk` | `salle_organisations` | `consulter_personnalites_musee` | [L4623](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4623) |
| `musee-novomirsk` | `salle_honneur_militaire` | `consulter_personnalites_musee` | [L4639](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4639) |
| `musee-novomirsk` | `salle_unions` | `consulter_personnalites_musee` | [L4648](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4648) |
| `musee-novomirsk` | `salle_scandales` | `consulter_personnalites_musee` | [L4657](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4657) |
| `centre-commercial` | `hall` | `se_renseigner` | [L4685](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4685) |
| `centre-commercial` | `vitrine_principale` | `commerce_pj` | [L4698](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4698) |
| `centre-commercial` | `vitrine_principale` | `louer_local` | [L4699](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4699) |
| `centre-commercial` | `vitrine_principale` | `gerer_local` | [L4700](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4700) |
| `centre-commercial` | `boutique_milieu` | `commerce_pj` | [L4712](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4712) |
| `centre-commercial` | `boutique_milieu` | `louer_local` | [L4713](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4713) |
| `centre-commercial` | `boutique_milieu` | `gerer_local` | [L4714](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4714) |
| `centre-commercial` | `arriere_boutique` | `commerce_pj` | [L4726](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4726) |
| `centre-commercial` | `arriere_boutique` | `louer_local` | [L4727](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4727) |
| `centre-commercial` | `arriere_boutique` | `gerer_local` | [L4728](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4728) |
| `centre-commercial` | `cave_reserve` | `commerce_pj` | [L4740](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4740) |
| `centre-commercial` | `cave_reserve` | `louer_local` | [L4741](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4741) |
| `centre-commercial` | `cave_reserve` | `gerer_local` | [L4742](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4742) |
| `centre-artisanal` | `travees` | `se_renseigner` | [L4767](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4767) |
| `centre-artisanal` | `echoppe_facade` | `commerce_pj` | [L4784](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4784) |
| `centre-artisanal` | `echoppe_facade` | `louer_local` | [L4785](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4785) |
| `centre-artisanal` | `echoppe_facade` | `gerer_local` | [L4786](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4786) |
| `centre-artisanal` | `atelier_milieu` | `commerce_pj` | [L4798](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4798) |
| `centre-artisanal` | `atelier_milieu` | `louer_local` | [L4799](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4799) |
| `centre-artisanal` | `atelier_milieu` | `gerer_local` | [L4800](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4800) |
| `centre-artisanal` | `reserve_arriere` | `commerce_pj` | [L4812](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4812) |
| `centre-artisanal` | `reserve_arriere` | `louer_local` | [L4813](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4813) |
| `centre-artisanal` | `reserve_arriere` | `gerer_local` | [L4814](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4814) |
| `centre-affaires` | `hall` | `se_renseigner` | [L4842](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4842) |
| `centre-affaires` | `bureau_prestige` | `louer_local` | [L4855](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4855) |
| `centre-affaires` | `bureau_prestige` | `gerer_local` | [L4856](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4856) |
| `centre-affaires` | `bureau_standard` | `louer_local` | [L4869](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4869) |
| `centre-affaires` | `bureau_standard` | `gerer_local` | [L4870](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4870) |
| `centre-affaires` | `open_space` | `louer_local` | [L4883](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4883) |
| `centre-affaires` | `open_space` | `gerer_local` | [L4884](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4884) |
| `centre-affaires` | `tribune_republia` | `produire_fuite` | [L4896](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4896) |
| `centre-affaires` | `tribune_republia` | `interview` | [L4897](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4897) |
| `terrain-a-batir-4` | `terrain` | `appeler_police_terrain` | [L4912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4912) |
| `terrain-a-batir-4` | `terrain` | `faire_disparaitre_cadavre` | [L4912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4912) |
| `terrain-a-batir-4` | `terrain` | `negocier_squatteurs` | [L4912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4912) |
| `terrain-a-batir-4` | `terrain` | `signer_compromis` | [L4912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4912) |
| `terrain-a-batir-4` | `terrain` | `acheter_terrain` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `construire_sur_terrain` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `corrompre_rdv_notaire` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `payer_versement_chantier` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `travailler_chantier` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `vendre_materiaux_chantier` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `modifier_plan_chantier` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `corrompre_chantier` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `voler_materiel_chantier` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `diviser_construction` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `reconfigurer_lots` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `louer_lot_ici` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `gerer_lot_loue` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `gerer_fonds_commerce` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `emprunter_construction` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-4` | `terrain` | `racheter_terrain` | [L4913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4913) |
| `terrain-a-batir-5` | `terrain` | `appeler_police_terrain` | [L4918](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4918) |
| `terrain-a-batir-5` | `terrain` | `faire_disparaitre_cadavre` | [L4918](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4918) |
| `terrain-a-batir-5` | `terrain` | `negocier_squatteurs` | [L4918](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4918) |
| `terrain-a-batir-5` | `terrain` | `signer_compromis` | [L4918](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4918) |
| `terrain-a-batir-5` | `terrain` | `acheter_terrain` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `construire_sur_terrain` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `corrompre_rdv_notaire` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `payer_versement_chantier` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `travailler_chantier` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `vendre_materiaux_chantier` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `modifier_plan_chantier` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `corrompre_chantier` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `voler_materiel_chantier` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `diviser_construction` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `reconfigurer_lots` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `louer_lot_ici` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `gerer_lot_loue` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `gerer_fonds_commerce` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `emprunter_construction` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-5` | `terrain` | `racheter_terrain` | [L4919](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4919) |
| `terrain-a-batir-6` | `terrain` | `appeler_police_terrain` | [L4924](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4924) |
| `terrain-a-batir-6` | `terrain` | `faire_disparaitre_cadavre` | [L4924](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4924) |
| `terrain-a-batir-6` | `terrain` | `negocier_squatteurs` | [L4924](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4924) |
| `terrain-a-batir-6` | `terrain` | `signer_compromis` | [L4924](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4924) |
| `terrain-a-batir-6` | `terrain` | `acheter_terrain` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `construire_sur_terrain` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `corrompre_rdv_notaire` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `payer_versement_chantier` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `travailler_chantier` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `vendre_materiaux_chantier` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `modifier_plan_chantier` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `corrompre_chantier` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `voler_materiel_chantier` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `diviser_construction` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `reconfigurer_lots` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `louer_lot_ici` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `gerer_lot_loue` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `gerer_fonds_commerce` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `emprunter_construction` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-6` | `terrain` | `racheter_terrain` | [L4925](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4925) |
| `terrain-a-batir-7` | `terrain` | `appeler_police_terrain` | [L4930](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4930) |
| `terrain-a-batir-7` | `terrain` | `faire_disparaitre_cadavre` | [L4930](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4930) |
| `terrain-a-batir-7` | `terrain` | `negocier_squatteurs` | [L4930](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4930) |
| `terrain-a-batir-7` | `terrain` | `signer_compromis` | [L4930](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4930) |
| `terrain-a-batir-7` | `terrain` | `acheter_terrain` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `construire_sur_terrain` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `corrompre_rdv_notaire` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `payer_versement_chantier` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `travailler_chantier` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `vendre_materiaux_chantier` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `modifier_plan_chantier` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `corrompre_chantier` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `voler_materiel_chantier` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `diviser_construction` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `reconfigurer_lots` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `louer_lot_ici` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `gerer_lot_loue` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `gerer_fonds_commerce` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `emprunter_construction` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-7` | `terrain` | `racheter_terrain` | [L4931](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4931) |
| `terrain-a-batir-montrouge-3` | `terrain` | `appeler_police_terrain` | [L4946](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4946) |
| `terrain-a-batir-montrouge-3` | `terrain` | `faire_disparaitre_cadavre` | [L4946](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4946) |
| `terrain-a-batir-montrouge-3` | `terrain` | `negocier_squatteurs` | [L4946](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4946) |
| `terrain-a-batir-montrouge-3` | `terrain` | `signer_compromis` | [L4946](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4946) |
| `terrain-a-batir-montrouge-3` | `terrain` | `acheter_terrain` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `construire_sur_terrain` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `corrompre_rdv_notaire` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `payer_versement_chantier` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `travailler_chantier` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `vendre_materiaux_chantier` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `modifier_plan_chantier` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `corrompre_chantier` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `voler_materiel_chantier` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `diviser_construction` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `reconfigurer_lots` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `louer_lot_ici` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `gerer_lot_loue` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `gerer_fonds_commerce` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `emprunter_construction` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-3` | `terrain` | `racheter_terrain` | [L4947](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4947) |
| `terrain-a-batir-montrouge-7` | `terrain` | `appeler_police_terrain` | [L4952](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4952) |
| `terrain-a-batir-montrouge-7` | `terrain` | `faire_disparaitre_cadavre` | [L4952](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4952) |
| `terrain-a-batir-montrouge-7` | `terrain` | `negocier_squatteurs` | [L4952](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4952) |
| `terrain-a-batir-montrouge-7` | `terrain` | `signer_compromis` | [L4952](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4952) |
| `terrain-a-batir-montrouge-7` | `terrain` | `acheter_terrain` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `construire_sur_terrain` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `corrompre_rdv_notaire` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `payer_versement_chantier` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `travailler_chantier` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `vendre_materiaux_chantier` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `modifier_plan_chantier` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `corrompre_chantier` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `voler_materiel_chantier` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `diviser_construction` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `reconfigurer_lots` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `louer_lot_ici` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `gerer_lot_loue` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `gerer_fonds_commerce` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `emprunter_construction` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-7` | `terrain` | `racheter_terrain` | [L4953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4953) |
| `terrain-a-batir-montrouge-8` | `terrain` | `appeler_police_terrain` | [L4958](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4958) |
| `terrain-a-batir-montrouge-8` | `terrain` | `faire_disparaitre_cadavre` | [L4958](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4958) |
| `terrain-a-batir-montrouge-8` | `terrain` | `negocier_squatteurs` | [L4958](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4958) |
| `terrain-a-batir-montrouge-8` | `terrain` | `signer_compromis` | [L4958](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4958) |
| `terrain-a-batir-montrouge-8` | `terrain` | `acheter_terrain` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `construire_sur_terrain` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `corrompre_rdv_notaire` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `payer_versement_chantier` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `travailler_chantier` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `vendre_materiaux_chantier` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `modifier_plan_chantier` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `corrompre_chantier` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `voler_materiel_chantier` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `diviser_construction` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `reconfigurer_lots` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `louer_lot_ici` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `gerer_lot_loue` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `gerer_fonds_commerce` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `emprunter_construction` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-8` | `terrain` | `racheter_terrain` | [L4959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4959) |
| `terrain-a-batir-montrouge-9` | `terrain` | `appeler_police_terrain` | [L4964](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4964) |
| `terrain-a-batir-montrouge-9` | `terrain` | `faire_disparaitre_cadavre` | [L4964](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4964) |
| `terrain-a-batir-montrouge-9` | `terrain` | `negocier_squatteurs` | [L4964](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4964) |
| `terrain-a-batir-montrouge-9` | `terrain` | `signer_compromis` | [L4964](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4964) |
| `terrain-a-batir-montrouge-9` | `terrain` | `acheter_terrain` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `construire_sur_terrain` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `corrompre_rdv_notaire` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `payer_versement_chantier` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `travailler_chantier` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `vendre_materiaux_chantier` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `modifier_plan_chantier` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `corrompre_chantier` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `voler_materiel_chantier` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `diviser_construction` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `reconfigurer_lots` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `louer_lot_ici` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `gerer_lot_loue` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `gerer_fonds_commerce` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `emprunter_construction` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-9` | `terrain` | `racheter_terrain` | [L4965](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4965) |
| `terrain-a-batir-montrouge-12` | `terrain` | `appeler_police_terrain` | [L4970](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4970) |
| `terrain-a-batir-montrouge-12` | `terrain` | `faire_disparaitre_cadavre` | [L4970](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4970) |
| `terrain-a-batir-montrouge-12` | `terrain` | `negocier_squatteurs` | [L4970](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4970) |
| `terrain-a-batir-montrouge-12` | `terrain` | `signer_compromis` | [L4970](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4970) |
| `terrain-a-batir-montrouge-12` | `terrain` | `acheter_terrain` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `construire_sur_terrain` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `corrompre_rdv_notaire` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `payer_versement_chantier` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `travailler_chantier` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `vendre_materiaux_chantier` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `modifier_plan_chantier` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `corrompre_chantier` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `voler_materiel_chantier` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `diviser_construction` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `reconfigurer_lots` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `louer_lot_ici` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `gerer_lot_loue` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `gerer_fonds_commerce` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `emprunter_construction` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-montrouge-12` | `terrain` | `racheter_terrain` | [L4971](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4971) |
| `terrain-a-batir-1` | `terrain` | `appeler_police_terrain` | [L4989](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4989) |
| `terrain-a-batir-1` | `terrain` | `faire_disparaitre_cadavre` | [L4990](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4990) |
| `terrain-a-batir-1` | `terrain` | `negocier_squatteurs` | [L4991](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4991) |
| `terrain-a-batir-1` | `terrain` | `donner_argent_pnj` | [L4992](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4992) |
| `terrain-a-batir-1` | `terrain` | `signer_compromis` | [L4993](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4993) |
| `terrain-a-batir-1` | `terrain` | `acheter_terrain` | [L4995](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4995) |
| `terrain-a-batir-1` | `terrain` | `construire_sur_terrain` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `corrompre_rdv_notaire` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `payer_versement_chantier` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `travailler_chantier` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `vendre_materiaux_chantier` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `modifier_plan_chantier` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `corrompre_chantier` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `voler_materiel_chantier` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `diviser_construction` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `reconfigurer_lots` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `louer_lot_ici` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `gerer_lot_loue` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `gerer_fonds_commerce` | [L4996](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4996) |
| `terrain-a-batir-1` | `terrain` | `emprunter_construction` | [L4997](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4997) |
| `terrain-a-batir-1` | `terrain` | `racheter_terrain` | [L4998](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4998) |
| `mairie` | `accueil_mairie` | `calendrier_elections` | [L5026](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5026) |
| `mairie` | `accueil_mairie` | `objet_trouve` | [L5027](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5027) |
| `mairie` | `accueil_mairie` | `etat_civil` | [L5033](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5033) |
| `mairie` | `accueil_mairie` | `consulter_organigramme_mairie` | [L5035](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5035) |
| `mairie` | `bureau_maire_local` | `fixer_impots_locaux` | [L5048](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5048) |
| `mairie` | `bureau_maire_local` | `repartition_budget_local` | [L5049](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5049) |
| `mairie` | `bureau_maire_local` | `subvention_proposer` | [L5050](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5050) |
| `mairie` | `bureau_maire_local` | `campagne_securite` | [L5051](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5051) |
| `mairie` | `bureau_maire_local` | `nominations_municipales` | [L5052](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5052) |
| `mairie` | `bureau_maire_adjoint` | `traiter_demandes_permis` | [L5063](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5063) |
| `mairie` | `bureau_maire_adjoint` | `consulter_dossiers_urbanisme` | [L5064](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5064) |
| `mairie` | `bureau_maire_adjoint` | `demander_logement_social` | [L5066](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5066) |
| `mairie` | `bureau_maire_adjoint` | `traiter_demandes_logement_social` | [L5067](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5067) |
| `mairie` | `bureau_maire_adjoint` | `acte_officiel_mairie` | [L5068](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5068) |
| `mairie` | `bureau_maire_adjoint` | `financer_communal` | [L5069](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5069) |
| `hotel-port` | `hall_port` | `produire_commerce` | [L5100](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5100) |
| `hotel-port` | `hall_port` | `consulter_carte_commerce` | [L5101](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5101) |
| `hotel-port` | `hall_port` | `gerer_commerce` | [L5102](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5102) |
| `hotel-port` | `hall_port` | `vendre_matiere_commerce` | [L5103](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5103) |
| `hotel-port` | `hall_port` | `reserver_chambre_hotel` | [L5104](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5104) |
| `hotel-port` | `chambre_port` | `dormir_chambre` | [L5115](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5115) |
| `hotel-port` | `chambre_port` | `service_etage` | [L5117](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5117) |
| `bar-des-pecheurs` | `salle_bar` | `produire_commerce` | [L5166](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5166) |
| `bar-des-pecheurs` | `salle_bar` | `consulter_carte_commerce` | [L5167](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5167) |
| `bar-des-pecheurs` | `salle_bar` | `offrir_tournee` | [L5168](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5168) |
| `bar-des-pecheurs` | `salle_bar` | `gerer_commerce` | [L5169](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5169) |
| `bar-des-pecheurs` | `salle_bar` | `vendre_matiere_commerce` | [L5170](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5170) |
| `bar-des-pecheurs` | `salle_bar` | `ecouter_rumeurs` | [L5171](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5171) |
| `bar-des-pecheurs` | `salle_bar` | `lancer_rumeur_cible` | [L5175](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5175) |
| `bar-des-pecheurs` | `salle_bar` | `recruter_informateur_pnj` | [L5176](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5176) |
| `bar-des-pecheurs` | `salle_bar` | `contrebande` | [L5177](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5177) |
| `services-sociaux-montrouge` | `accueil` | `ssm_besoin_aide` | [L5199](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5199) |
| `services-sociaux-montrouge` | `accueil` | `ssm_demander_rendezvous` | [L5200](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5200) |
| `services-sociaux-montrouge` | `bureau_assistante_sociale` | `demander_logement_social` | [L5210](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5210) |
| `siege-syndical` | `bureau_syndical` | `mobiliser` | [L5248](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5248) |
| `usine-principale` | `direction_usine` | `acheter_entreprise` | [L5270](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5270) |
| `hotel-mineur` | `hall_mineur` | `produire_commerce` | [L5297](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5297) |
| `hotel-mineur` | `hall_mineur` | `consulter_carte_commerce` | [L5298](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5298) |
| `hotel-mineur` | `hall_mineur` | `gerer_commerce` | [L5299](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5299) |
| `hotel-mineur` | `hall_mineur` | `vendre_matiere_commerce` | [L5300](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5300) |
| `hotel-mineur` | `hall_mineur` | `reserver_chambre_hotel` | [L5301](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5301) |
| `hotel-mineur` | `chambre_mineur` | `dormir_chambre` | [L5316](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5316) |
| `hotel-mineur` | `chambre_mineur` | `service_etage` | [L5318](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5318) |
| `banque-locale` | `guichet` | `gerer_finances` | [L5343](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5343) |
| `banque-locale` | `guichet` | `emprunter` | [L5344](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5344) |
| `banque-locale` | `guichet` | `virements` | [L5346](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5346) |
| `dispensaire-public-v` | `attente` | `soin_public` | [L5368](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5368) |
| `dispensaire-public-v` | `attente` | `centre_anti_poison` | [L5370](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5370) |
| `dispensaire-public-v` | `attente` | `transfert_clinique_privee` | [L5371](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5371) |
| `dispensaire-public-v` | `attente` | `repas_hopital` | [L5372](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5372) |
| `dispensaire-public-v` | `attente` | `sortie_hopital` | [L5373](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5373) |
| `dispensaire-public-v` | `attente` | `vendre_ressource_medicale` | [L5374](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5374) |
| `commissariat-local` | `accueil_loc` | `plainte_police` | [L5411](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5411) |
| `commissariat-local` | `accueil_loc` | `archives_police` | [L5414](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5414) |
| `commissariat-local` | `accueil_loc` | `arreter` | [L5415](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5415) |
| `commissariat-local` | `accueil_loc` | `se_justifier` | [L5420](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5420) |
| `commissariat-local` | `accueil_loc` | `temoin_deposition` | [L5425](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5425) |
| `commissariat-local` | `geoles` | `se_rebeller` | [L5448](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5448) |
| `commissariat-local` | `geoles` | `tentative_evasion` | [L5449](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5449) |
| `commissariat-local` | `bureau_commissaire` | `dossiers_plaintes` | [L5461](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5461) |
| `commissariat-local` | `bureau_commissaire` | `mener_enquete` | [L5462](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5462) |
| `commissariat-local` | `bureau_commissaire` | `organiser_filature` | [L5463](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5463) |
| `commissariat-local` | `bureau_commissaire` | `organiser_chasse_homme` | [L5464](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5464) |
| `commissariat-local` | `bureau_commissaire` | `recruter_policier` | [L5465](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5465) |
| `commissariat-local` | `bureau_commissaire` | `recruter_policier_cynophile` | [L5466](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5466) |
| `commissariat-local` | `bureau_commissaire` | `mobiliser_police` | [L5467](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5467) |
| `commissariat-local` | `bureau_commissaire` | `gerer_effectifs_police` | [L5468](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5468) |
| `tribunal-local` | `salle_audience_locale` | `defense` | [L5495](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5495) |
| `tribunal-local` | `salle_audience_locale` | `temoins_mes_convocations` | [L5496](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5496) |
| `tribunal-local` | `salle_audience_locale` | `audience_salle` | [L5497](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5497) |
| `tribunal-local` | `bureau_magistrats` | `parquet` | [L5511](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5511) |
| `tribunal-local` | `bureau_magistrats` | `rendre_sentence` | [L5512](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5512) |
| `tribunal-local` | `bureau_magistrats` | `audience_juge` | [L5513](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5513) |
| `tribunal-local` | `bureau_magistrats` | `acte_officiel_juge` | [L5514](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5514) |
| `tribunal-local` | `greffe` | `archives` | [L5531](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5531) |
| `tribunal-local` | `greffe` | `falsifier_document` | [L5533](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5533) |
| `tribunal-local` | `greffe` | `avocat_dossiers` | [L5534](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5534) |
| `tribunal-local` | `greffe` | `avocat_barreau` | [L5535](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5535) |
| `tribunal-local` | `greffe` | `greffe_affaires` | [L5536](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5536) |
| `tribunal-local` | `greffe` | `greffe_archives` | [L5537](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5537) |
| `tribunal-local` | `greffe` | `casier_mon_extrait` | [L5543](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5543) |
| `tribunal-local` | `greffe` | `casier_extrait_enquete` | [L5544](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5544) |
| `tribunal-local` | `greffe` | `orga_extrait_duplicata` | [L5545](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5545) |
| `tribunal-local` | `greffe` | `greffe_corrompre_dossier` | [L5546](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5546) |
| `tribunal-local` | `greffe` | `greffe_corrompre_faux_casier` | [L5547](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5547) |
| `imprimerie-librairie` | `accueil_imprimerie` | `imprimer_tracts_electoraux` | [L5579](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5579) |
| `imprimerie-librairie` | `atelier` | `imprimer_tracts_calomnieux` | [L5602](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5602) |
| `imprimerie-librairie` | `atelier` | `vendre_bois_imprimerie` | [L5603](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5603) |
| `marche-psm` | `etals` | `produire_commerce` | [L5642](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5642) |
| `marche-psm` | `etals` | `faire_achats_marche` | [L5643](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5643) |
| `marche-psm` | `etals` | `pouls_populaire` | [L5645](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5645) |
| `marche-psm` | `etals` | `vendre_matiere_commerce` | [L5646](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5646) |
| `marche-psm` | `etals` | `lancer_rumeur_cible` | [L5649](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5649) |
| `capitaine-sauvage` | `salle_principale` | `diner_affaires` | [L5683](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5683) |
| `capitaine-sauvage` | `salle_principale` | `ecouter_rumeurs` | [L5684](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5684) |
| `capitaine-sauvage` | `salle_principale` | `lancer_rumeur_cible` | [L5685](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5685) |
| `capitaine-sauvage` | `salle_principale` | `produire_commerce` | [L5686](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5686) |
| `capitaine-sauvage` | `salle_principale` | `consulter_carte_commerce` | [L5687](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5687) |
| `capitaine-sauvage` | `salle_principale` | `gerer_commerce` | [L5688](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5688) |
| `capitaine-sauvage` | `salle_principale` | `vendre_matiere_commerce` | [L5689](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5689) |
| `chasse-peche-psm` | `boutique` | `choisir_arme` | [L5721](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5721) |
| `chasse-peche-psm` | `boutique` | `acheter_gilet` | [L5727](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5727) |
| `chasse-peche-psm` | `boutique` | `consulter_registre_armes` | [L5734](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5734) |
| `chasse-peche-psm` | `boutique` | `produire_arme` | [L5739](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5739) |
| `chasse-peche-psm` | `boutique` | `vendre_matiere_commerce` | [L5740](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5740) |
| `chasse-peche-psm` | `boutique` | `marche_noir` | [L5741](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5741) |
| `place-armes-psm` | `place` | `organiser_manifestation_spontanee` | [L5762](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5762) |
| `chantier-naval` | `hall` | `consulter_devis_chantier_naval` | [L5818](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5818) |
| `chantier-naval` | `bureau` | `consulter_devis_chantier_naval` | [L5830](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5830) |
| `notre-dame-mer` | `nef` | `prier` | [L5866](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5866) |
| `notre-dame-mer` | `nef` | `faire_don` | [L5867](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5867) |
| `terrain-a-batir-8` | `terrain8` | `acheter_terrain` | [L5959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5959) |
| `terrain-a-batir-8` | `terrain8` | `deposer_demande_permis` | [L5960](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5960) |
| `terrain-a-batir-8` | `terrain8` | `corrompre_fonctionnaire_permis` | [L5961](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5961) |
| `terrain-a-batir-9` | `terrain9` | `acheter_terrain` | [L5982](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5982) |
| `terrain-a-batir-9` | `terrain9` | `deposer_demande_permis` | [L5983](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5983) |
| `terrain-a-batir-9` | `terrain9` | `corrompre_fonctionnaire_permis` | [L5984](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5984) |
| `terrain-a-batir-10` | `terrain10` | `acheter_terrain` | [L6005](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6005) |
| `terrain-a-batir-10` | `terrain10` | `deposer_demande_permis` | [L6006](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6006) |
| `terrain-a-batir-10` | `terrain10` | `corrompre_fonctionnaire_permis` | [L6007](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6007) |
| `terrain-a-batir-11` | `terrain11` | `acheter_terrain` | [L6028](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6028) |
| `terrain-a-batir-11` | `terrain11` | `deposer_demande_permis` | [L6029](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6029) |
| `terrain-a-batir-11` | `terrain11` | `corrompre_fonctionnaire_permis` | [L6030](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6030) |
| `terrain-a-batir-psm-12` | `terrain` | `acheter_terrain` | [L6054](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6054) |
| `terrain-a-batir-psm-12` | `terrain` | `deposer_demande_permis` | [L6055](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6055) |
| `terrain-a-batir-psm-12` | `terrain` | `corrompre_fonctionnaire_permis` | [L6056](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6056) |
| `terrain-a-batir-psm-13` | `terrain` | `acheter_terrain` | [L6077](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6077) |
| `terrain-a-batir-psm-13` | `terrain` | `deposer_demande_permis` | [L6078](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6078) |
| `terrain-a-batir-psm-13` | `terrain` | `corrompre_fonctionnaire_permis` | [L6079](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6079) |
| `terrain-a-batir-2` | `terrain` | `acheter_terrain` | [L6100](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6100) |
| `terrain-a-batir-2` | `terrain` | `deposer_demande_permis` | [L6101](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6101) |
| `terrain-a-batir-2` | `terrain` | `corrompre_fonctionnaire_permis` | [L6102](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6102) |
| `terrain-a-batir-3` | `terrain` | `acheter_terrain` | [L6123](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6123) |
| `terrain-a-batir-3` | `terrain` | `deposer_demande_permis` | [L6124](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6124) |
| `terrain-a-batir-3` | `terrain` | `corrompre_fonctionnaire_permis` | [L6125](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6125) |
| `caserne-militaire` | `corps_garde` | `nommer_lieutenant` | [L6166](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6166) |
| `caserne-militaire` | `corps_garde` | `s_engager_armee` | [L6181](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6181) |
| `caserne-militaire` | `corps_garde` | `traiter_candidatures` | [L6182](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6182) |
| `caserne-militaire` | `corps_garde` | `decouvrir_affectation` | [L6183](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6183) |
| `caserne-militaire` | `corps_garde` | `calepin_campagne` | [L6186](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6186) |
| `caserne-militaire` | `corps_garde` | `decorer_militaire` | [L6193](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6193) |
| `caserne-militaire` | `corps_garde` | `quitter_armee` | [L6194](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6194) |
| `caserne-militaire` | `corps_garde` | `demettre_lieutenant` | [L6195](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6195) |
| `caserne-militaire` | `corps_garde` | `se_presenter_affectation` | [L6196](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6196) |
| `caserne-militaire` | `corps_garde` | `stage_caserne` | [L6197](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6197) |
| `caserne-militaire` | `infirmerie` | `retirer_trousse` | [L6219](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6219) |
| `caserne-militaire` | `salle_commandement` | `nommer_capitaine` | [L6274](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6274) |
| `caserne-militaire` | `salle_commandement` | `recherche_militaire` | [L6275](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6275) |
| `caserne-militaire` | `salle_commandement` | `caisse_caserne` | [L6287](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6287) |
| `caserne-militaire` | `salle_commandement` | `repartir_armement` | [L6288](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6288) |
| `caserne-militaire` | `salle_commandement` | `recruter_compagnie` | [L6289](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6289) |
| `caserne-militaire` | `salle_commandement` | `gerer_detachement` | [L6297](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6297) |
| `caserne-militaire` | `salle_commandement` | `voir_ma_section` | [L6298](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6298) |
| `caserne-militaire` | `salle_commandement` | `entrainer_section` | [L6299](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6299) |
| `caserne-militaire` | `salle_commandement` | `reposer_section` | [L6305](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6305) |
| `caserne-militaire` | `salle_commandement` | `equiper_section` | [L6306](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6306) |
| `caserne-militaire` | `salle_commandement` | `declencher_mutinerie` | [L6311](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6311) |
| `caserne-militaire` | `salle_commandement` | `remonter_renseignement` | [L6312](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6312) |
| `caserne-militaire` | `salle_commandement` | `inspecter_troupes` | [L6320](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6320) |
| `caserne-militaire` | `salle_commandement` | `gerer_budget_caserne` | [L6321](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6321) |
| `caserne-militaire` | `salle_commandement` | `tableau_effort_guerre` | [L6324](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6324) |
| `caserne-militaire` | `armurerie_militaire` | `retirer_armes_militaires` | [L6346](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6346) |
| `caserne-militaire` | `armurerie_militaire` | `retirer_explosifs_militaires` | [L6347](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6347) |
| `caserne-militaire` | `armurerie_militaire` | `retirer_equipement_militaire` | [L6352](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6352) |
| `caserne-militaire` | `armurerie_militaire` | `acheter_bombe_illegale` | [L6353](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6353) |
| `caserne-militaire` | `refectoire` | `manger_ration` | [L6377](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6377) |
| `caserne-militaire` | `refectoire` | `retirer_rations` | [L6380](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6380) |
| `caserne-militaire` | `salle_faits_armes` | `consulter_faits_armes` | [L6392](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6392) |
| `musee-national-republia` | `salle_honneur_militaire_nationale` | `consulter_personnalites_musee` | [L6579](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6579) |
| `musee-national-republia` | `salle_politiques` | `consulter_personnalites_musee` | [L6589](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6589) |
| `musee-national-republia` | `salle_civils_intellectuels` | `consulter_personnalites_musee` | [L6600](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6600) |
| `musee-national-republia` | `salle_organisations` | `consulter_personnalites_musee` | [L6611](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6611) |
| `musee-national-republia` | `salle_artistes_sportifs` | `consulter_personnalites_musee` | [L6622](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6622) |
| `musee-national-republia` | `salle_reussites_economiques` | `consulter_personnalites_musee` | [L6642](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6642) |
| `musee-national-republia` | `salle_criminels_pays` | `consulter_personnalites_musee` | [L6662](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6662) |
| `place-formulaire-liberte` | `place` | `organiser_manifestation_spontanee` | [L6720](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6720) |
| `quartier-ambassades` | `accueil_ambassades` | `demander_audience_ambassadeur` | [L6743](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6743) |
| `quartier-ambassades` | `accueil_ambassades` | `demander_asile_politique` | [L6744](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6744) |
| `quartier-ambassades` | `accueil_ambassades` | `reserver_salle_reception` | [L6745](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6745) |
| `quartier-ambassades` | `bureau_al_khalija` | `relations_bilaterales` | [L6762](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6762) |
| `quartier-ambassades` | `bureau_al_khalija` | `organiser_reception_diplomatique` | [L6763](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6763) |
| `quartier-ambassades` | `bureau_al_khalija` | `financer_oeuvre_culturelle` | [L6764](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6764) |
| `quartier-ambassades` | `bureau_al_khalija` | `demander_transfert_detenu` | [L6765](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6765) |
| `quartier-ambassades` | `bureau_sovarka` | `relations_bilaterales` | [L6774](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6774) |
| `quartier-ambassades` | `bureau_sovarka` | `organiser_reception_diplomatique` | [L6775](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6775) |
| `quartier-ambassades` | `bureau_sovarka` | `financer_oeuvre_culturelle` | [L6776](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6776) |
| `quartier-ambassades` | `bureau_sovarka` | `demander_transfert_detenu` | [L6777](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6777) |
| `quartier-ambassades` | `bureau_el_estado` | `relations_bilaterales` | [L6786](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6786) |
| `quartier-ambassades` | `bureau_el_estado` | `organiser_reception_diplomatique` | [L6787](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6787) |
| `quartier-ambassades` | `bureau_el_estado` | `financer_oeuvre_culturelle` | [L6788](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6788) |
| `quartier-ambassades` | `bureau_el_estado` | `demander_transfert_detenu` | [L6789](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6789) |
| `palais-ambassades-novomirsk` | `accueil_ambassades_novomirsk` | `demander_audience_ambassadeur` | [L6819](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6819) |
| `palais-ambassades-novomirsk` | `accueil_ambassades_novomirsk` | `demander_asile_politique` | [L6820](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6820) |
| `palais-ambassades-novomirsk` | `accueil_ambassades_novomirsk` | `reserver_salle_reception` | [L6821](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6821) |
| `palais-ambassades-novomirsk` | `bureau_republia_novomirsk` | `relations_bilaterales` | [L6838](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6838) |
| `palais-ambassades-novomirsk` | `bureau_republia_novomirsk` | `organiser_reception_diplomatique` | [L6839](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6839) |
| `palais-ambassades-novomirsk` | `bureau_republia_novomirsk` | `financer_oeuvre_culturelle` | [L6840](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6840) |
| `palais-ambassades-novomirsk` | `bureau_republia_novomirsk` | `demander_transfert_detenu` | [L6841](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6841) |
| `palais-ambassades-novomirsk` | `bureau_khalija_novomirsk` | `relations_bilaterales` | [L6851](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6851) |
| `palais-ambassades-novomirsk` | `bureau_khalija_novomirsk` | `organiser_reception_diplomatique` | [L6852](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6852) |
| `palais-ambassades-novomirsk` | `bureau_khalija_novomirsk` | `financer_oeuvre_culturelle` | [L6853](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6853) |
| `palais-ambassades-novomirsk` | `bureau_khalija_novomirsk` | `demander_transfert_detenu` | [L6854](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6854) |
| `palais-ambassades-novomirsk` | `bureau_estado_novomirsk` | `relations_bilaterales` | [L6864](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6864) |
| `palais-ambassades-novomirsk` | `bureau_estado_novomirsk` | `organiser_reception_diplomatique` | [L6865](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6865) |
| `palais-ambassades-novomirsk` | `bureau_estado_novomirsk` | `financer_oeuvre_culturelle` | [L6866](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6866) |
| `palais-ambassades-novomirsk` | `bureau_estado_novomirsk` | `demander_transfert_detenu` | [L6867](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6867) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `ecouter_rumeurs` | [L6911](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6911) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `recruter_informateur_pnj` | [L6912](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6912) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `produire_commerce` | [L6913](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6913) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `consulter_carte_commerce` | [L6914](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6914) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `offrir_tournee` | [L6915](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6915) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `gerer_commerce` | [L6916](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6916) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `vendre_matiere_commerce` | [L6917](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6917) |
| `pavillon-ambassadeurs-novomirsk` | `suite_privee` | `louer_local` | [L6928](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6928) |
| `pavillon-ambassadeurs-novomirsk` | `suite_privee` | `gerer_local` | [L6929](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6929) |
| `pavillon-ambassadeurs-novomirsk` | `suite_presidentielle` | `louer_local` | [L6940](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6940) |
| `pavillon-ambassadeurs-novomirsk` | `suite_presidentielle` | `gerer_local` | [L6941](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6941) |
| `pavillon-ambassadeurs-novomirsk` | `suite_parti` | `louer_local` | [L6952](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6952) |
| `pavillon-ambassadeurs-novomirsk` | `suite_parti` | `gerer_local` | [L6953](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6953) |
| `residence-imperiale-novomirsk` | `appartement_1` | `louer_local` | [L6986](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6986) |
| `residence-imperiale-novomirsk` | `appartement_1` | `gerer_local` | [L6987](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6987) |
| `residence-imperiale-novomirsk` | `appartement_2` | `louer_local` | [L6998](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6998) |
| `residence-imperiale-novomirsk` | `appartement_2` | `gerer_local` | [L6999](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6999) |
| `residence-imperiale-novomirsk` | `appartement_3` | `louer_local` | [L7010](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7010) |
| `residence-imperiale-novomirsk` | `appartement_3` | `gerer_local` | [L7011](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7011) |
| `residence-imperiale-novomirsk` | `appartement_4` | `louer_local` | [L7022](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7022) |
| `residence-imperiale-novomirsk` | `appartement_4` | `gerer_local` | [L7023](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7023) |
| `residence-imperiale-novomirsk` | `grand_appartement` | `louer_local` | [L7034](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7034) |
| `residence-imperiale-novomirsk` | `grand_appartement` | `gerer_local` | [L7035](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7035) |
| `garage-novomirsk` | `atelier_garage` | `garage_vehicules` | [L7060](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7060) |
| `garage-novomirsk` | `atelier_garage` | `garage_reviser` | [L7061](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7061) |
| `garage-novomirsk` | `atelier_garage` | `mes_vehicules` | [L7062](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7062) |
| `salon-coiffure-novomirsk` | `salon_coiffure` | `salon_coupe` | [L7087](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7087) |
| `logements-novomirsk` | `petit_appartement_1` | `gerer_logement_social` | [L7119](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7119) |
| `logements-novomirsk` | `petit_appartement_2` | `gerer_logement_social` | [L7130](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7130) |
| `logements-novomirsk` | `petit_appartement_3` | `gerer_logement_social` | [L7141](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7141) |
| `logements-novomirsk` | `petit_appartement_4` | `gerer_logement_social` | [L7152](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7152) |
| `logements-novomirsk` | `grand_appartement_1` | `gerer_logement_social` | [L7163](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7163) |
| `logements-novomirsk` | `grand_appartement_2` | `gerer_logement_social` | [L7174](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7174) |
| `logements-novomirsk` | `grand_appartement_3` | `gerer_logement_social` | [L7185](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7185) |
| `logements-novomirsk` | `grand_appartement_4` | `gerer_logement_social` | [L7196](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7196) |
| `pharmacie-officielle-novomirsk` | `comptoir_pharmacie` | `pharmacie_medicaments` | [L7221](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7221) |
| `poissonniere-novomirsk` | `etal_poissonniere` | `poissonniere_poisson` | [L7246](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7246) |
| `poissonniere-novomirsk` | `etal_poissonniere` | `ecouter_rumeurs` | [L7247](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7247) |
| `poissonniere-novomirsk` | `etal_poissonniere` | `lancer_rumeur_cible` | [L7248](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7248) |
| `poissonniere-novomirsk` | `etal_poissonniere` | `contrebande_poissonniere` | [L7249](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7249) |
| `station-service-krasnov` | `boutique_station` | `station_carburant` | [L7268](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7268) |
| `station-service-krasnov` | `boutique_station` | `mes_vehicules` | [L7269](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7269) |
| `entrepot-logistique-novomirsk` | `salle_ventes` | `receptionner_commande` | [L7293](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7293) |
| `entrepot-logistique-novomirsk` | `salle_ventes` | `acheter_ressources_entrepot` | [L7293](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7293) |
| `entrepot-logistique-novomirsk` | `bureau_direction` | `tableau_bord_entrepot` | [L7302](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7302) |
| `entrepot-logistique-novomirsk` | `bureau_direction` | `fixer_prix_achat_entrepot` | [L7303](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7303) |
| `siege-renseignement` | `salle_ecoutes` | `renseignement_militaire` | [L7341](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7341) |
| `siege-renseignement` | `salle_interrogatoire_renseignement` | `interroger_renseignement` | [L7350](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7350) |
| `qhs-prison` | `entree_qhs` | `visiter_prisonnier` | [L7373](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7373) |
| `qhs-prison` | `entree_qhs` | `corrompre_fonct` | [L7374](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7374) |
| `qhs-prison` | `entree_qhs` | `archives_police` | [L7375](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7375) |
| `qhs-prison` | `cellules_qhs` | `greve_faim` | [L7388](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7388) |
| `qhs-prison` | `cellules_qhs` | `corrompre_gardien` | [L7389](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7389) |
| `qhs-prison` | `cellules_qhs` | `tentative_evasion` | [L7390](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7390) |
| `qhs-prison` | `salle_interrogatoire` | `interroger` | [L7400](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7400) |
| `qhs-prison` | `salle_interrogatoire` | `corrompre_fonct` | [L7401](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7401) |
| `qhs-prison` | `promenoir` | `se_reposer` | [L7411](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7411) |
| `tabernacle-impots` | `nef_principale` | `prier` | [L7452](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7452) |
| `tabernacle-impots` | `nef_principale` | `faire_don` | [L7453](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7453) |
| `laboratoire-priere` | `salle_communion` | `prier` | [L7495](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7495) |
| `laboratoire-priere` | `salle_communion` | `se_confesser` | [L7496](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7496) |
| `laboratoire-priere` | `salle_communion` | `faire_don` | [L7497](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7497) |
| `laboratoire-priere` | `salle_communion` | `pelerin` | [L7498](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7498) |
| `kolkhoze-spirituel` | `grange_sainte` | `prier` | [L7522](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7522) |
| `kolkhoze-spirituel` | `grange_sainte` | `se_confesser` | [L7523](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7523) |
| `kolkhoze-spirituel` | `grange_sainte` | `faire_don` | [L7524](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7524) |
| `kolkhoze-spirituel` | `grange_sainte` | `pelerin` | [L7525](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7525) |
| `patisserie-sacree` | `salle_degustation` | `prier` | [L7549](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7549) |
| `patisserie-sacree` | `salle_degustation` | `se_confesser` | [L7550](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7550) |
| `patisserie-sacree` | `salle_degustation` | `faire_don` | [L7551](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7551) |
| `patisserie-sacree` | `salle_degustation` | `pelerin` | [L7552](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7552) |
| `patisserie-sacree` | `salle_degustation` | `acheter_relique` | [L7553](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7553) |
| `entrepot-logistique-montrouge` | `salle_ventes` | `receptionner_commande` | [L7575](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7575) |
| `entrepot-logistique-montrouge` | `salle_ventes` | `acheter_ressources_entrepot` | [L7575](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7575) |
| `entrepot-logistique-montrouge` | `bureau_direction` | `tableau_bord_entrepot` | [L7584](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7584) |
| `entrepot-logistique-montrouge` | `bureau_direction` | `fixer_prix_achat_entrepot` | [L7585](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7585) |
| `entrepot-logistique-krasnov` | `salle_ventes` | `receptionner_commande` | [L7607](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7607) |
| `entrepot-logistique-krasnov` | `salle_ventes` | `acheter_ressources_entrepot` | [L7607](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7607) |
| `entrepot-logistique-krasnov` | `bureau_direction` | `tableau_bord_entrepot` | [L7616](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7616) |
| `entrepot-logistique-krasnov` | `bureau_direction` | `fixer_prix_achat_entrepot` | [L7617](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7617) |
| `raffinerie-montrouge` | `salle_ventes` | `vente_directe_usine` | [L7637](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7637) |
| `raffinerie-montrouge` | `bureau_direction` | `fixer_prix_vente_directe` | [L7646](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7646) |
| `raffinerie-montrouge` | `bureau_direction` | `fixer_repartition_production` | [L7647](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7647) |
| `raffinerie-montrouge` | `bureau_direction` | `virement_usine_ministere` | [L7648](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7648) |
| `raffinerie-montrouge` | `salle_production` | `produire_carburant` | [L7658](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7658) |
| `raffinerie-montrouge` | `salle_production` | `produire_derives_petrochimiques` | [L7659](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7659) |
| `raffinerie-montrouge` | `salle_production` | `vendre_matiere_usine` | [L7662](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7662) |
| `bureau-national-emploi` | `accueil` | `consulter_offres_emploi` | [L7686](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7686) |
| `bureau-national-emploi` | `accueil` | `bne_passer_annonce` | [L7687](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7687) |
| `pole-tabac-alcools-psm` | `salle_ventes` | `vente_directe_usine` | [L7709](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7709) |
| `pole-tabac-alcools-psm` | `bureau_direction` | `fixer_prix_vente_directe` | [L7718](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7718) |
| `pole-tabac-alcools-psm` | `bureau_direction` | `fixer_repartition_production` | [L7719](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7719) |
| `pole-tabac-alcools-psm` | `bureau_direction` | `virement_usine_ministere` | [L7720](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7720) |
| `pole-tabac-alcools-psm` | `distillerie` | `produire_alcool` | [L7730](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7730) |
| `pole-tabac-alcools-psm` | `distillerie` | `vendre_matiere_usine` | [L7733](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7733) |
| `pole-tabac-alcools-psm` | `manufacture_tabac` | `produire_tabac` | [L7743](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7743) |
| `pole-tabac-alcools-psm` | `manufacture_tabac` | `vendre_matiere_usine` | [L7746](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7746) |
| `entrepot-logistique-psm` | `salle_ventes` | `receptionner_commande` | [L7766](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7766) |
| `entrepot-logistique-psm` | `salle_ventes` | `acheter_ressources_entrepot` | [L7766](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7766) |
| `entrepot-logistique-psm` | `bureau_direction` | `tableau_bord_entrepot` | [L7775](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7775) |
| `entrepot-logistique-psm` | `bureau_direction` | `fixer_prix_achat_entrepot` | [L7776](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7776) |
| `entrepot-logistique-luthecia` | `salle_ventes` | `receptionner_commande` | [L7796](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7796) |
| `entrepot-logistique-luthecia` | `salle_ventes` | `acheter_ressources_entrepot` | [L7796](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7796) |
| `entrepot-logistique-luthecia` | `bureau_direction` | `tableau_bord_entrepot` | [L7805](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7805) |
| `entrepot-logistique-luthecia` | `bureau_direction` | `fixer_prix_achat_entrepot` | [L7806](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7806) |
| `usine-pharmaceutique-luthecia` | `salle_ventes` | `vente_directe_usine` | [L7827](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7827) |
| `usine-pharmaceutique-luthecia` | `salle_ventes` | `acheter_sels_ammoniaque` | [L7833](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7833) |
| `usine-pharmaceutique-luthecia` | `bureau_direction` | `fixer_prix_vente_directe` | [L7843](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7843) |
| `usine-pharmaceutique-luthecia` | `bureau_direction` | `fixer_repartition_production` | [L7844](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7844) |
| `usine-pharmaceutique-luthecia` | `bureau_direction` | `virement_usine_ministere` | [L7845](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7845) |
| `usine-pharmaceutique-luthecia` | `salle_production` | `produire_medicaments` | [L7855](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7855) |
| `usine-pharmaceutique-luthecia` | `salle_production` | `produire_desinfectant` | [L7856](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7856) |
| `usine-pharmaceutique-luthecia` | `salle_production` | `vendre_matiere_usine` | [L7857](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7857) |
| `centre-multinodal-luthecia` | `hall_gare` | `prendre_train` | [L7881](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7881) |
| `centre-multinodal-luthecia` | `hall_gare` | `prendre_bus_taxi` | [L7882](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7882) |
| `centre-multinodal-luthecia` | `hall_gare` | `aller_douanes_aeroport` | [L7883](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7883) |
| `centre-multinodal-luthecia` | `hall_gare` | `taxi_caserne` | [L7884](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7884) |
| `centre-multinodal-luthecia` | `hall_gare` | `taxi_qhs` | [L7885](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7885) |
| `centre-multinodal-luthecia` | `hall_douanes` | `passer_douanes_aeroport` | [L7897](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7897) |
| `centre-multinodal-luthecia` | `hall_douanes` | `corrompre_douanier` | [L7898](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7898) |
| `centre-multinodal-luthecia` | `zone_embarquement` | `prendre_avion` | [L7910](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7910) |
| `centre-multinodal-port-sainte-marie` | `hall_gare_psm` | `prendre_train` | [L7933](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7933) |
| `centre-multinodal-port-sainte-marie` | `hall_gare_psm` | `prendre_bus_taxi` | [L7934](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7934) |
| `centre-multinodal-montrouge` | `hall_gare_montrouge` | `prendre_train` | [L7958](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7958) |
| `centre-multinodal-montrouge` | `hall_gare_montrouge` | `prendre_bus_taxi` | [L7959](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7959) |
| `cafe-gare-montrouge` | `salle` | `produire_commerce` | [L7976](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7976) |
| `cafe-gare-montrouge` | `salle` | `consulter_carte_commerce` | [L7977](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7977) |
| `cafe-gare-montrouge` | `salle` | `offrir_tournee` | [L7982](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7982) |
| `cafe-gare-montrouge` | `salle` | `gerer_commerce` | [L7983](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7983) |
| `cafe-gare-montrouge` | `salle` | `vendre_matiere_commerce` | [L7984](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7984) |
| `cafe-gare-montrouge` | `salle` | `lancer_rumeur_cible` | [L7987](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7987) |
| `brasserie-voyageurs-montrouge` | `salle` | `produire_commerce` | [L7998](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7998) |
| `brasserie-voyageurs-montrouge` | `salle` | `consulter_carte_commerce` | [L7999](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7999) |
| `brasserie-voyageurs-montrouge` | `salle` | `gerer_commerce` | [L8000](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8000) |
| `brasserie-voyageurs-montrouge` | `salle` | `vendre_matiere_commerce` | [L8001](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8001) |
| `brasserie-voyageurs-montrouge` | `salle` | `lancer_rumeur_cible` | [L8004](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8004) |
| `musee-histoire-montrouge` | `salle_terre` | `consulter_personnalites_musee` | [L8024](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8024) |
| `musee-histoire-montrouge` | `salle_industrie` | `consulter_personnalites_musee` | [L8025](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8025) |
| `musee-histoire-montrouge` | `salle_rail` | `consulter_personnalites_musee` | [L8026](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8026) |
| `musee-histoire-montrouge` | `salle_ville` | `consulter_personnalites_musee` | [L8027](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8027) |
| `musee-histoire-montrouge` | `salle_luttes` | `consulter_personnalites_musee` | [L8028](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8028) |
| `musee-histoire-montrouge` | `salle_loisirs` | `consulter_personnalites_musee` | [L8029](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8029) |
| `eglise-montrouge` | `salle` | `prier` | [L8048](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8048) |
| `eglise-montrouge` | `salle` | `faire_don` | [L8049](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8049) |
| `place-du-rail-montrouge` | `place` | `organiser_manifestation_spontanee` | [L8062](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8062) |
| `jardins-ouvriers-montrouge` | `salle` | `travailler_jardins` | [L8093](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8093) |
| `jardins-ouvriers-montrouge` | `salle` | `laisser_legumes_jardins` | [L8094](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8094) |
| `jardins-ouvriers-montrouge` | `salle` | `prendre_legumes_jardins` | [L8095](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8095) |
| `logements-montrouge` | `petit_appartement_1` | `gerer_logement_social` | [L8137](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8137) |
| `logements-montrouge` | `petit_appartement_2` | `gerer_logement_social` | [L8149](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8149) |
| `logements-montrouge` | `grand_appartement_1` | `gerer_logement_social` | [L8161](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8161) |
| `logements-montrouge` | `grand_appartement_2` | `gerer_logement_social` | [L8173](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8173) |
| `cafe-tabac-cheminots-montrouge` | `salle` | `produire_commerce` | [L8194](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8194) |
| `cafe-tabac-cheminots-montrouge` | `salle` | `consulter_carte_commerce` | [L8195](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8195) |
| `cafe-tabac-cheminots-montrouge` | `salle` | `offrir_tournee` | [L8198](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8198) |
| `cafe-tabac-cheminots-montrouge` | `salle` | `gerer_commerce` | [L8199](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8199) |
| `cafe-tabac-cheminots-montrouge` | `salle` | `vendre_matiere_commerce` | [L8200](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8200) |
| `cafe-tabac-cheminots-montrouge` | `salle` | `lancer_rumeur_cible` | [L8201](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8201) |
| `port-sainte-marie` | `quai_principal` | `prendre_bateau` | [L8240](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8240) |
| `port-sainte-marie` | `quai_principal` | `inspecter_cargaisons` | [L8241](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8241) |
| `port-sainte-marie` | `criee` | `acheter_criee` | [L8251](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8251) |
| `port-sainte-marie` | `entrepot` | `marchandises_non_reclamees` | [L8271](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8271) |
| `port-sainte-marie` | `entrepot` | `expedier_colis` | [L8278](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8278) |
| `port-sainte-marie` | `entrepot` | `receptionner_commande` | [L8279](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8279) |
| `port-sainte-marie` | `box_a_louer` | `louer_box` | [L8304](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8304) |
| `port-sainte-marie` | `box_a_louer` | `gerer_box` | [L8305](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8305) |
| `port-sainte-marie` | `douanes` | `consulter_effectifs_douane` | [L8326](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8326) |
| `port-sainte-marie` | `douanes` | `recruter_douanier` | [L8327](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8327) |
| `port-sainte-marie` | `douanes` | `recruter_douanier_cynophile` | [L8328](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8328) |
| `port-sainte-marie` | `douanes` | `gerer_effectifs_douane` | [L8329](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8329) |
| `port-sainte-marie` | `douanes` | `controler_caisse_douane` | [L8330](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8330) |
| `port-sainte-marie` | `bureau_syndical_dockers` | `se_syndiquer` | [L8354](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8354) |
| `port-sainte-marie` | `bureau_syndical_dockers` | `consulter_organigramme_syndicat` | [L8355](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8355) |
| `port-sainte-marie` | `bureau_syndical_dockers` | `declencher_election_syndicat` | [L8356](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8356) |
| `port-sainte-marie` | `bureau_syndical_dockers` | `organiser_manifestation_syndicat` | [L8357](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8357) |
| `port-sainte-marie` | `bureau_syndical_dockers` | `blocus_portuaire` | [L8358](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8358) |
| `port-sainte-marie` | `administration_portuaire` | `consulter_manifeste` | [L8371](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8371) |
| `port-sainte-marie` | `administration_portuaire` | `consulter_administration_port` | [L8372](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8372) |
| `port-sainte-marie` | `administration_portuaire` | `gerer_logistique_port` | [L8373](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8373) |
| `port-novomirsk` | `quai_sovarka` | `prendre_bateau` | [L8397](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8397) |
| `port-novomirsk` | `quai_sovarka` | `expedier_colis` | [L8398](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8398) |
| `port-novomirsk` | `quai_sovarka` | `receptionner_commande` | [L8399](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8399) |
| `port-novomirsk` | `quai_sovarka` | `contrebande_port` | [L8400](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8400) |
| `port-novomirsk` | `quai_sovarka` | `acheter_polonium` | [L8401](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8401) |
| `port-novomirsk` | `quai_sovarka` | `inspecter_cargaisons` | [L8402](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8402) |
| `port-ciudad-roja` | `quai_el_estado` | `prendre_bateau` | [L8426](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8426) |
| `port-ciudad-roja` | `quai_el_estado` | `expedier_colis` | [L8427](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8427) |
| `port-ciudad-roja` | `quai_el_estado` | `receptionner_commande` | [L8428](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8428) |
| `port-ciudad-roja` | `quai_el_estado` | `contrebande_port` | [L8429](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8429) |
| `port-ciudad-roja` | `quai_el_estado` | `acheter_ghb` | [L8430](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8430) |
| `port-ciudad-roja` | `quai_el_estado` | `blocus_portuaire` | [L8431](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8431) |
| `port-al-madina` | `quai_al_khalija` | `prendre_bateau` | [L8455](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8455) |
| `port-al-madina` | `quai_al_khalija` | `expedier_colis` | [L8456](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8456) |
| `port-al-madina` | `quai_al_khalija` | `receptionner_commande` | [L8457](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8457) |
| `port-al-madina` | `quai_al_khalija` | `contrebande_port` | [L8458](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8458) |
| `port-al-madina` | `quai_al_khalija` | `acheter_vipere` | [L8459](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8459) |
| `port-al-madina` | `quai_al_khalija` | `inspecter_cargaisons` | [L8460](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8460) |

## Répertoire des bâtiments et pièces sans ordre déclaré

Un bâtiment ou une pièce sans ordre dans `data.js` peut être purement social, visuel ou géré dans un autre module. Ils ne sont **pas** automatiquement des bâtiments inachevés.

- [`hotel-republica`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2745) : 6 pièces, 23 références d'ordres
- [`palais-presidentiel`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2857) : 4 pièces, 12 références d'ordres
- [`palais-gouvernement`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L2952) : 11 pièces, 38 références d'ordres
- [`assemblee`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3314) : 4 pièces, 12 références d'ordres
- [`office-notarial`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3429) : 4 pièces, 11 références d'ordres
- [`stade`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3501) : 6 pièces, 29 références d'ordres
- [`zone-production`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3606) : 1 pièces, 1 références d'ordres
- [`tribunal`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3627) : 3 pièces, 19 références d'ordres
- [`banque-nationale`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3731) : 2 pièces, 6 références d'ordres
- [`banque-privee`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3773) : 1 pièces, 5 références d'ordres
- [`clinique-privee`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3802) : 11 pièces, 73 références d'ordres
- [`dispensaire-public`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3930) : 2 pièces, 6 références d'ordres
- [`commissariat`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L3973) : 3 pièces, 15 références d'ordres
- [`la-tribune`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4039) : 2 pièces, 11 références d'ordres
- [`loge-maconnique`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4104) : 4 pièces, 6 références d'ordres
- [`universite`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4173) : 2 pièces, 6 références d'ordres
- [`armurerie`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4243) : 1 pièces, 5 références d'ordres
- [`marche`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4287) : 1 pièces, 3 références d'ordres
- [`mairie-capitale`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4318) : 5 pièces, 23 références d'ordres
- [`musee-port-sainte-marie`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4427) : 10 pièces, 8 références d'ordres
- [`musee-novomirsk`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4561) : 10 pièces, 8 références d'ordres
- [`centre-commercial`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4667) : 5 pièces, 13 références d'ordres
- [`centre-artisanal`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4748) : 4 pièces, 10 références d'ordres
- [`centre-affaires`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4820) : 5 pièces, 9 références d'ordres
- [`terrain-a-batir-4`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4909) : 1 pièces, 20 références d'ordres
- [`terrain-a-batir-5`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4915) : 1 pièces, 20 références d'ordres
- [`terrain-a-batir-6`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4921) : 1 pièces, 20 références d'ordres
- [`terrain-a-batir-7`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4927) : 1 pièces, 20 références d'ordres
- [`terrain-a-batir-montrouge-3`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4943) : 1 pièces, 20 références d'ordres
- [`terrain-a-batir-montrouge-7`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4949) : 1 pièces, 20 références d'ordres
- [`terrain-a-batir-montrouge-8`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4955) : 1 pièces, 20 références d'ordres
- [`terrain-a-batir-montrouge-9`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4961) : 1 pièces, 20 références d'ordres
- [`terrain-a-batir-montrouge-12`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4967) : 1 pièces, 20 références d'ordres
- [`terrain-a-batir-1`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L4973) : 1 pièces, 21 références d'ordres
- [`mairie`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5005) : 3 pièces, 15 références d'ordres
- [`hotel-port`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5076) : 2 pièces, 7 références d'ordres
- [`bar-des-pecheurs`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5123) : 1 pièces, 9 références d'ordres
- [`services-sociaux-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5187) : 2 pièces, 3 références d'ordres
- [`parking-tribunal-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5215) : 1 pièces, 0 références d'ordres
- [`siege-syndical`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5232) : 1 pièces, 1 références d'ordres
- [`usine-principale`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5254) : 1 pièces, 1 références d'ordres
- [`hotel-mineur`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5276) : 2 pièces, 7 références d'ordres
- [`banque-locale`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5324) : 1 pièces, 3 références d'ordres
- [`dispensaire-public-v`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5352) : 2 pièces, 6 références d'ordres
- [`commissariat-local`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5391) : 3 pièces, 15 références d'ordres
- [`tribunal-local`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5474) : 3 pièces, 18 références d'ordres
- [`imprimerie-librairie`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5554) : 2 pièces, 3 références d'ordres
- [`marche-psm`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5609) : 1 pièces, 5 références d'ordres
- [`capitaine-sauvage`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5654) : 1 pièces, 7 références d'ordres
- [`chasse-peche-psm`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5694) : 1 pièces, 6 références d'ordres
- [`place-armes-psm`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5746) : 1 pièces, 1 références d'ordres
- [`ecole-marine`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5775) : 2 pièces, 0 références d'ordres
- [`chantier-naval`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5803) : 2 pièces, 2 références d'ordres
- [`notre-dame-mer`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5835) : 3 pièces, 2 références d'ordres
- [`phare-psm`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5889) : 1 pièces, 0 références d'ordres
- [`port-plaisance-psm`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5914) : 2 pièces, 0 références d'ordres
- [`terrain-a-batir-8`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5943) : 1 pièces, 3 références d'ordres
- [`terrain-a-batir-9`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5966) : 1 pièces, 3 références d'ordres
- [`terrain-a-batir-10`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L5989) : 1 pièces, 3 références d'ordres
- [`terrain-a-batir-11`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6012) : 1 pièces, 3 références d'ordres
- [`terrain-a-batir-psm-12`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6038) : 1 pièces, 3 références d'ordres
- [`terrain-a-batir-psm-13`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6061) : 1 pièces, 3 références d'ordres
- [`terrain-a-batir-2`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6084) : 1 pièces, 3 références d'ordres
- [`terrain-a-batir-3`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6108) : 1 pièces, 3 références d'ordres
- [`caserne-militaire`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6132) : 7 pièces, 33 références d'ordres
- [`musee-ville-luthecia`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6418) : 12 pièces, 0 références d'ordres
- [`musee-national-republia`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6538) : 12 pièces, 7 références d'ordres
- [`parc-botanique-national`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6668) : 2 pièces, 0 références d'ordres
- [`place-formulaire-liberte`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6699) : 1 pièces, 1 références d'ordres
- [`quartier-ambassades`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6726) : 5 pièces, 15 références d'ordres
- [`palais-ambassades-novomirsk`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6801) : 5 pièces, 15 références d'ordres
- [`pavillon-ambassadeurs-novomirsk`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6879) : 6 pièces, 13 références d'ordres
- [`residence-imperiale-novomirsk`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L6961) : 6 pièces, 10 références d'ordres
- [`garage-novomirsk`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7045) : 1 pièces, 3 références d'ordres
- [`salon-coiffure-novomirsk`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7072) : 1 pièces, 1 références d'ordres
- [`logements-novomirsk`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7096) : 9 pièces, 8 références d'ordres
- [`pharmacie-officielle-novomirsk`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7206) : 1 pièces, 1 références d'ordres
- [`poissonniere-novomirsk`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7231) : 1 pièces, 4 références d'ordres
- [`station-service-krasnov`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7254) : 1 pièces, 2 références d'ordres
- [`entrepot-logistique-novomirsk`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7279) : 2 pièces, 4 références d'ordres
- [`siege-renseignement`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7318) : 3 pièces, 2 références d'ordres
- [`qhs-prison`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7355) : 5 pièces, 9 références d'ordres
- [`tabernacle-impots`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7428) : 2 pièces, 2 références d'ordres
- [`laboratoire-priere`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7477) : 1 pièces, 4 références d'ordres
- [`kolkhoze-spirituel`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7504) : 1 pièces, 4 références d'ordres
- [`patisserie-sacree`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7531) : 1 pièces, 5 références d'ordres
- [`entrepot-logistique-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7561) : 2 pièces, 4 références d'ordres
- [`entrepot-logistique-krasnov`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7593) : 2 pièces, 4 références d'ordres
- [`raffinerie-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7623) : 3 pièces, 7 références d'ordres
- [`bureau-national-emploi`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7668) : 1 pièces, 2 références d'ordres
- [`pole-tabac-alcools-psm`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7695) : 4 pièces, 8 références d'ordres
- [`entrepot-logistique-psm`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7752) : 2 pièces, 4 références d'ordres
- [`entrepot-logistique-luthecia`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7782) : 2 pièces, 4 références d'ordres
- [`usine-pharmaceutique-luthecia`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7812) : 3 pièces, 8 références d'ordres
- [`centre-multinodal-luthecia`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7863) : 3 pièces, 8 références d'ordres
- [`centre-multinodal-port-sainte-marie`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7916) : 1 pièces, 2 références d'ordres
- [`centre-multinodal-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7940) : 1 pièces, 2 références d'ordres
- [`cafe-gare-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7968) : 1 pièces, 6 références d'ordres
- [`brasserie-voyageurs-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L7990) : 1 pièces, 5 références d'ordres
- [`musee-histoire-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8013) : 7 pièces, 6 références d'ordres
- [`eglise-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8032) : 1 pièces, 2 références d'ordres
- [`place-du-rail-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8055) : 1 pièces, 1 références d'ordres
- [`cinema-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8068) : 3 pièces, 0 références d'ordres
- [`jardins-ouvriers-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8081) : 1 pièces, 3 références d'ordres
- [`logements-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8098) : 5 pièces, 4 références d'ordres
- [`cafe-tabac-cheminots-montrouge`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8178) : 1 pièces, 6 références d'ordres
- [`port-sainte-marie`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8207) : 7 pièces, 21 références d'ordres
- [`port-novomirsk`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8379) : 1 pièces, 6 références d'ordres
- [`port-ciudad-roja`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8408) : 1 pièces, 6 références d'ordres
- [`port-al-madina`](https://github.com/FredJ74/res-publica/blob/a8bd5e266f18f3432ec3feb11d53dbb799043531/data.js#L8437) : 1 pièces, 6 références d'ordres

## Limites du découpage automatique

- Les `rooms` écrits sur une seule ligne ont été associés à leur pièce (notamment certains terrains).
- L'extraction ne vérifie ni les villes associées à chaque bâtiment, ni les filtres d'apparition, ni les extensions injectées dans `data.js` ou `plateau-*.js` après la déclaration.
- Pour l'audit de la géographie, rapprocher ces identifiants de `WORLD`, `VILLES`, `plateau-navigation.js` et des positions/réseaux en base ; une présence dans `BUILDINGS` n'implique pas une entrée accessible à pied.
- Les liens pointent le **SHA figé de l'audit**, non la version future de `main`.

**Certification suivante :** rattacher le graphe des rues et les droits d'accès à chaque bâtiment, puis chaque `fn` à la fonction client et au contrat RPC réel. Sans tests de parcours, la colonne J reste inconnue.
