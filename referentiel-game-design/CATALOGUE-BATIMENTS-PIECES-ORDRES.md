# Catalogue des bâtiments, pièces et ordres — source statique data.js

**Extraction technique du 11 novembre 2026** (`outils/referentiel/generer_catalogues.cjs`). Périmètre **uniquement** l'objet littéral `BUILDINGS` dans [`data.js`](../data.js), version [`50e3c118`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js), évalué tel que le jeu le charge. Les déclarations dynamiques (`WORLD`, `buildingContext`, `RP_ORDRES_DYNAMIQUES` des fichiers `plateau-*.js`, comme « Fouiller les lieux » ou « Équipements et serrure »), les variantes de pièces ou les routes serveur peuvent modifier les lieux réellement affichés.

**121 clés de bâtiments**, **318 clés de pièces** et **1121 références `fn`** situées par cette analyse (relevé précédent, 09/11 au SHA `a8bd5e26` : 110 / 303 / 956).

**Avertissement** : l'ordre peut être un menu, une action grisée, une fonction conditionnelle, un double emploi ou une entrée dans une ville non jouable ; la présence dans la liste ne certifie aucune interaction. Les lignes de source permettent de poursuivre jusqu'au handler, au contrôle serveur et au test.

## Localisation de chaque déclaration

| Bâtiment | Pièce | Fonction `fn` | Source |
|---|---|---|---|
| `hotel-republica` | `accueil` | `reserver_chambre_hotel` | [L2808](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2808) |
| `hotel-republica` | `accueil` | `choisir_suite` | [L2809](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2809) |
| `hotel-republica` | `restaurant` | `diner_affaires` | [L2826](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2826) |
| `hotel-republica` | `restaurant` | `ecouter_rumeurs` | [L2827](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2827) |
| `hotel-republica` | `restaurant` | `lancer_rumeur_cible` | [L2828](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2828) |
| `hotel-republica` | `restaurant` | `produire_commerce` | [L2829](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2829) |
| `hotel-republica` | `restaurant` | `consulter_carte_commerce` | [L2830](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2830) |
| `hotel-republica` | `restaurant` | `gerer_commerce` | [L2831](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2831) |
| `hotel-republica` | `restaurant` | `vendre_matiere_commerce` | [L2832](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2832) |
| `hotel-republica` | `bar` | `ecouter_rumeurs` | [L2848](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2848) |
| `hotel-republica` | `bar` | `recruter_informateur_pnj` | [L2849](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2849) |
| `hotel-republica` | `bar` | `escort_piege` | [L2850](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2850) |
| `hotel-republica` | `bar` | `produire_commerce` | [L2851](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2851) |
| `hotel-republica` | `bar` | `consulter_carte_commerce` | [L2852](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2852) |
| `hotel-republica` | `bar` | `offrir_tournee` | [L2853](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2853) |
| `hotel-republica` | `bar` | `gerer_commerce` | [L2854](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2854) |
| `hotel-republica` | `bar` | `vendre_matiere_commerce` | [L2855](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2855) |
| `hotel-republica` | `chambres` | `dormir_chambre` | [L2866](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2866) |
| `hotel-republica` | `chambres` | `service_etage` | [L2867](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2867) |
| `hotel-republica` | `suite_privee` | `louer_local` | [L2879](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2879) |
| `hotel-republica` | `suite_privee` | `gerer_local` | [L2880](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2880) |
| `hotel-republica` | `suite_presidentielle` | `louer_local` | [L2892](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2892) |
| `hotel-republica` | `suite_presidentielle` | `gerer_local` | [L2893](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2893) |
| `palais-presidentiel` | `accueil_elysee` | `solliciter_audience_president` | [L2920](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2920) |
| `palais-presidentiel` | `bureau_president` | `gestion_premier_ministre` | [L2952](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2952) |
| `palais-presidentiel` | `bureau_president` | `postes_par_decret` | [L2953](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2953) |
| `palais-presidentiel` | `bureau_president` | `pouvoirs_exceptionnels` | [L2954](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2954) |
| `palais-presidentiel` | `bureau_president` | `adresse_a_la_nation` | [L2955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2955) |
| `palais-presidentiel` | `bureau_president` | `gracier` | [L2956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2956) |
| `palais-presidentiel` | `bureau_president` | `effort_national` | [L2959](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2959) |
| `palais-presidentiel` | `salle_presse_elysee` | `conference_presse` | [L2971](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2971) |
| `palais-presidentiel` | `salle_presse_elysee` | `propagande_etat` | [L2972](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2972) |
| `palais-presidentiel` | `salle_presse_elysee` | `dementi` | [L2973](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2973) |
| `palais-presidentiel` | `salle_reception` | `reception_etat` | [L2989](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2989) |
| `palais-presidentiel` | `salle_reception` | `banquet_diplo` | [L2990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2990) |
| `palais-gouvernement` | `hall` | `postuler` | [L3025](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3025) |
| `palais-gouvernement` | `bureaux` | `nommer_ministre_pm` | [L3042](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3042) |
| `palais-gouvernement` | `bureaux` | `revoquer_ministre_pm` | [L3043](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3043) |
| `palais-gouvernement` | `bureaux` | `declencher_vote_confiance` | [L3044](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3044) |
| `palais-gouvernement` | `salle_presse` | `conference_presse` | [L3079](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3079) |
| `palais-gouvernement` | `salle_presse` | `propagande_etat` | [L3080](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3080) |
| `palais-gouvernement` | `salle_presse` | `dementi` | [L3081](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3081) |
| `palais-gouvernement` | `archives_gouv` | `consulter_dossiers_gouv` | [L3094](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3094) |
| `palais-gouvernement` | `archives_gouv` | `fuite_info` | [L3095](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3095) |
| `palais-gouvernement` | `bureau_min_int` | `gestion_manifestations` | [L3136](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3136) |
| `palais-gouvernement` | `bureau_min_int` | `demandes_naturalisation` | [L3137](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3137) |
| `palais-gouvernement` | `bureau_min_int` | `gerer_couvre_feu` | [L3138](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3138) |
| `palais-gouvernement` | `bureau_min_int` | `gerer_chef_douanes` | [L3139](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3139) |
| `palais-gouvernement` | `bureau_min_int` | `gerer_budget_interieur` | [L3150](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3150) |
| `palais-gouvernement` | `bureau_min_int` | `subvention_min_int` | [L3151](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3151) |
| `palais-gouvernement` | `bureau_min_int` | `lois_votees_an` | [L3158](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3158) |
| `palais-gouvernement` | `bureau_min_fin` | `pilotage_fiscal_budgetaire` | [L3185](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3185) |
| `palais-gouvernement` | `bureau_min_fin` | `bne_caisse_prelever` | [L3186](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3186) |
| `palais-gouvernement` | `bureau_min_fin` | `subvention` | [L3187](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3187) |
| `palais-gouvernement` | `bureau_min_fin` | `gestion_industrielle_portuaire` | [L3188](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3188) |
| `palais-gouvernement` | `bureau_min_fin` | `preempter_entreprise` | [L3189](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3189) |
| `palais-gouvernement` | `bureau_min_just` | `ouvrir_enquete` | [L3221](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3221) |
| `palais-gouvernement` | `bureau_min_just` | `proposer_grace` | [L3222](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3222) |
| `palais-gouvernement` | `bureau_min_just` | `gerer_juges` | [L3223](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3223) |
| `palais-gouvernement` | `bureau_min_just` | `gerer_budget_justice` | [L3227](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3227) |
| `palais-gouvernement` | `bureau_min_just` | `gestion_qhs` | [L3228](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3228) |
| `palais-gouvernement` | `bureau_min_def` | `mobilisation_nationale` | [L3263](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3263) |
| `palais-gouvernement` | `bureau_min_def` | `activer_cessez_le_feu` | [L3264](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3264) |
| `palais-gouvernement` | `bureau_min_def` | `garde_republicaine` | [L3271](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3271) |
| `palais-gouvernement` | `bureau_min_def` | `renseignement_militaire` | [L3285](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3285) |
| `palais-gouvernement` | `bureau_min_def` | `gestion_caserne` | [L3292](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3292) |
| `palais-gouvernement` | `bureau_min_info` | `propagande_etat` | [L3319](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3319) |
| `palais-gouvernement` | `bureau_min_info` | `censurer_media` | [L3320](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3320) |
| `palais-gouvernement` | `bureau_min_info` | `commanditer_sondage` | [L3321](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3321) |
| `palais-gouvernement` | `bureau_min_info` | `dementi` | [L3322](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3322) |
| `palais-gouvernement` | `bureau_min_ae` | `proposer_treve` | [L3349](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3349) |
| `palais-gouvernement` | `bureau_min_ae` | `diplomatie_bilaterale` | [L3350](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3350) |
| `palais-gouvernement` | `bureau_min_ae` | `gerer_ambassades` | [L3351](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3351) |
| `assemblee` | `accueil_assemblee` | `calendrier_elections` | [L3395](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3395) |
| `assemblee` | `accueil_assemblee` | `seance_parlementaire` | [L3400](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3400) |
| `assemblee` | `hemicycle` | `seance_parlementaire` | [L3425](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3425) |
| `assemblee` | `hemicycle` | `observer_debats` | [L3426](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3426) |
| `assemblee` | `hemicycle` | `voter_loi` | [L3427](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3427) |
| `assemblee` | `hemicycle` | `projet_loi` | [L3428](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3428) |
| `assemblee` | `hemicycle` | `amender_projet` | [L3429](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3429) |
| `assemblee` | `hemicycle` | `marchander_vote` | [L3435](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3435) |
| `assemblee` | `hemicycle` | `reveiller_depute` | [L3436](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3436) |
| `assemblee` | `couloirs` | `consulter_lobbyiste` | [L3450](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3450) |
| `assemblee` | `couloirs` | `ecouter_rumeurs` | [L3451](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3451) |
| `assemblee` | `salle_archives_assemblee` | `registre_assemblee` | [L3466](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3466) |
| `office-notarial` | `accueil_notaire` | `consulter_dossier_notarial` | [L3492](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3492) |
| `office-notarial` | `bureau_successions` | `gerer_testament` | [L3509](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3509) |
| `office-notarial` | `bureau_successions` | `reclamer_heritage` | [L3510](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3510) |
| `office-notarial` | `bureau_contrats` | `officialiser_transaction` | [L3522](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3522) |
| `office-notarial` | `bureau_contrats` | `commerces_fonds_murs` | [L3523](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3523) |
| `office-notarial` | `bureau_contrats` | `racheter_entreprise` | [L3524](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3524) |
| `office-notarial` | `bureau_contrats` | `acte_rachat_entreprise_preemption` | [L3525](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3525) |
| `office-notarial` | `bureau_contrats` | `transfert_compromis` | [L3526](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3526) |
| `office-notarial` | `bureau_contrats` | `demander_divorce` | [L3527](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3527) |
| `office-notarial` | `bureau_contrats` | `acte_officiel_notaire` | [L3528](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3528) |
| `office-notarial` | `archives_notariales` | `consulter_archives_notariales` | [L3540](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3540) |
| `stade` | `terrain` | `observer_match` | [L3564](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3564) |
| `stade` | `terrain` | `regarder_live` | [L3565](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3565) |
| `stade` | `vestiaires` | `prendre_licence_sportive` | [L3577](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3577) |
| `stade` | `vestiaires` | `demander_non_renouvellement_licence` | [L3578](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3578) |
| `stade` | `vestiaires` | `annuler_non_renouvellement_licence` | [L3579](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3579) |
| `stade` | `vestiaires` | `tenue_entrainement` | [L3580](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3580) |
| `stade` | `vestiaires` | `tenue_match` | [L3581](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3581) |
| `stade` | `vestiaires` | `conseil_entraineur_adjoint` | [L3582](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3582) |
| `stade` | `buvette` | `produire_commerce` | [L3594](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3594) |
| `stade` | `buvette` | `consulter_carte_commerce` | [L3595](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3595) |
| `stade` | `buvette` | `vendre_matiere_commerce` | [L3596](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3596) |
| `stade` | `buvette` | `choisir_accessoire_club` | [L3597](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3597) |
| `stade` | `buvette` | `acheter_accessoire_personnalise` | [L3598](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3598) |
| `stade` | `guichet_paris` | `parier_match` | [L3610](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3610) |
| `stade` | `guichet_paris` | `consulter_classement_joueurs_club` | [L3611](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3611) |
| `stade` | `siege_supporters` | `rejoindre_club_supporters` | [L3623](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3623) |
| `stade` | `siege_supporters` | `consulter_palmares` | [L3624](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3624) |
| `stade` | `siege_supporters` | `consulter_organigramme_supporters` | [L3625](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3625) |
| `stade` | `siege_supporters` | `declencher_election_club` | [L3626](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3626) |
| `stade` | `siege_supporters` | `organiser_manifestation` | [L3627](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3627) |
| `stade` | `siege_supporters` | `organiser_boycott` | [L3628](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3628) |
| `stade` | `bureau_president` | `postuler_president_club` | [L3638](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3638) |
| `stade` | `bureau_president` | `consulter_bureau_president` | [L3639](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3639) |
| `stade` | `bureau_president` | `proposer_transfert` | [L3640](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3640) |
| `stade` | `bureau_president` | `gerer_offres_transfert` | [L3641](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3641) |
| `stade` | `bureau_president` | `sponsoriser_club` | [L3642](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3642) |
| `stade` | `bureau_president` | `consulter_budget_club` | [L3643](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3643) |
| `stade` | `bureau_president` | `gerer_salaires_club` | [L3644](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3644) |
| `zone-production` | `zone_recolte` | `recolter_matiere` | [L3665](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3665) |
| `tribunal` | `salle_audience` | `defense` | [L3707](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3707) |
| `tribunal` | `salle_audience` | `temoins_mes_convocations` | [L3708](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3708) |
| `tribunal` | `salle_audience` | `audience_salle` | [L3709](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3709) |
| `tribunal` | `bureau_magistrats` | `parquet` | [L3732](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3732) |
| `tribunal` | `bureau_magistrats` | `rendre_sentence` | [L3733](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3733) |
| `tribunal` | `bureau_magistrats` | `audience_juge` | [L3734](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3734) |
| `tribunal` | `bureau_magistrats` | `acte_officiel_juge` | [L3735](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3735) |
| `tribunal` | `greffe` | `archives` | [L3748](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3748) |
| `tribunal` | `greffe` | `falsifier_document` | [L3749](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3749) |
| `tribunal` | `greffe` | `demander_juge_instruction` | [L3750](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3750) |
| `tribunal` | `greffe` | `avocat_dossiers` | [L3754](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3754) |
| `tribunal` | `greffe` | `avocat_barreau` | [L3755](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3755) |
| `tribunal` | `greffe` | `greffe_affaires` | [L3756](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3756) |
| `tribunal` | `greffe` | `greffe_archives` | [L3757](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3757) |
| `tribunal` | `greffe` | `casier_mon_extrait` | [L3763](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3763) |
| `tribunal` | `greffe` | `casier_extrait_enquete` | [L3764](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3764) |
| `tribunal` | `greffe` | `orga_extrait_duplicata` | [L3765](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3765) |
| `tribunal` | `greffe` | `greffe_corrompre_dossier` | [L3766](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3766) |
| `tribunal` | `greffe` | `greffe_corrompre_faux_casier` | [L3767](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3767) |
| `banque-nationale` | `accueil_banque` | `gerer_finances` | [L3792](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3792) |
| `banque-nationale` | `accueil_banque` | `emprunter` | [L3793](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3793) |
| `banque-nationale` | `accueil_banque` | `virements` | [L3795](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3795) |
| `banque-nationale` | `accueil_banque` | `presenter_autorisation_coffre` | [L3796](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3796) |
| `banque-nationale` | `coffre_privatif` | `louer_local` | [L3808](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3808) |
| `banque-nationale` | `coffre_privatif` | `gerer_local` | [L3809](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3809) |
| `banque-privee` | `bureau_prive` | `gerer_finances` | [L3834](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3834) |
| `banque-privee` | `bureau_prive` | `compte_offshore` | [L3835](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3835) |
| `banque-privee` | `bureau_prive` | `emprunter_prive` | [L3836](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3836) |
| `banque-privee` | `bureau_prive` | `blanchiment` | [L3837](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3837) |
| `banque-privee` | `bureau_prive` | `societe_ecran` | [L3838](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3838) |
| `clinique-privee` | `reception_clinique` | `vendre_ressource_medicale` | [L3863](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3863) |
| `clinique-privee` | `reception_clinique` | `ouvrir_chambres_clinique` | [L3864](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3864) |
| `clinique-privee` | `reception_clinique` | `sortie_hopital` | [L3865](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3865) |
| `clinique-privee` | `chambre_1` | `gerer_visites_chambre` | [L3880](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3880) |
| `clinique-privee` | `chambre_1` | `soins` | [L3881](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3881) |
| `clinique-privee` | `chambre_1` | `soins_urgence` | [L3882](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3882) |
| `clinique-privee` | `chambre_1` | `soins_discrets` | [L3883](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3883) |
| `clinique-privee` | `chambre_1` | `centre_anti_poison` | [L3884](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3884) |
| `clinique-privee` | `chambre_1` | `repas_clinique` | [L3885](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3885) |
| `clinique-privee` | `chambre_1` | `sortie_hopital` | [L3886](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3886) |
| `clinique-privee` | `chambre_2` | `gerer_visites_chambre` | [L3889](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3889) |
| `clinique-privee` | `chambre_2` | `soins` | [L3890](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3890) |
| `clinique-privee` | `chambre_2` | `soins_urgence` | [L3891](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3891) |
| `clinique-privee` | `chambre_2` | `soins_discrets` | [L3892](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3892) |
| `clinique-privee` | `chambre_2` | `centre_anti_poison` | [L3893](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3893) |
| `clinique-privee` | `chambre_2` | `repas_clinique` | [L3894](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3894) |
| `clinique-privee` | `chambre_2` | `sortie_hopital` | [L3895](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3895) |
| `clinique-privee` | `chambre_3` | `gerer_visites_chambre` | [L3898](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3898) |
| `clinique-privee` | `chambre_3` | `soins` | [L3899](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3899) |
| `clinique-privee` | `chambre_3` | `soins_urgence` | [L3900](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3900) |
| `clinique-privee` | `chambre_3` | `soins_discrets` | [L3901](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3901) |
| `clinique-privee` | `chambre_3` | `centre_anti_poison` | [L3902](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3902) |
| `clinique-privee` | `chambre_3` | `repas_clinique` | [L3903](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3903) |
| `clinique-privee` | `chambre_3` | `sortie_hopital` | [L3904](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3904) |
| `clinique-privee` | `chambre_4` | `gerer_visites_chambre` | [L3907](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3907) |
| `clinique-privee` | `chambre_4` | `soins` | [L3908](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3908) |
| `clinique-privee` | `chambre_4` | `soins_urgence` | [L3909](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3909) |
| `clinique-privee` | `chambre_4` | `soins_discrets` | [L3910](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3910) |
| `clinique-privee` | `chambre_4` | `centre_anti_poison` | [L3911](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3911) |
| `clinique-privee` | `chambre_4` | `repas_clinique` | [L3912](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3912) |
| `clinique-privee` | `chambre_4` | `sortie_hopital` | [L3913](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3913) |
| `clinique-privee` | `chambre_5` | `gerer_visites_chambre` | [L3916](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3916) |
| `clinique-privee` | `chambre_5` | `soins` | [L3917](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3917) |
| `clinique-privee` | `chambre_5` | `soins_urgence` | [L3918](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3918) |
| `clinique-privee` | `chambre_5` | `soins_discrets` | [L3919](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3919) |
| `clinique-privee` | `chambre_5` | `centre_anti_poison` | [L3920](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3920) |
| `clinique-privee` | `chambre_5` | `repas_clinique` | [L3921](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3921) |
| `clinique-privee` | `chambre_5` | `sortie_hopital` | [L3922](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3922) |
| `clinique-privee` | `chambre_6` | `gerer_visites_chambre` | [L3925](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3925) |
| `clinique-privee` | `chambre_6` | `soins` | [L3926](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3926) |
| `clinique-privee` | `chambre_6` | `soins_urgence` | [L3927](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3927) |
| `clinique-privee` | `chambre_6` | `soins_discrets` | [L3928](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3928) |
| `clinique-privee` | `chambre_6` | `centre_anti_poison` | [L3929](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3929) |
| `clinique-privee` | `chambre_6` | `repas_clinique` | [L3930](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3930) |
| `clinique-privee` | `chambre_6` | `sortie_hopital` | [L3931](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3931) |
| `clinique-privee` | `chambre_7` | `gerer_visites_chambre` | [L3934](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3934) |
| `clinique-privee` | `chambre_7` | `soins` | [L3935](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3935) |
| `clinique-privee` | `chambre_7` | `soins_urgence` | [L3936](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3936) |
| `clinique-privee` | `chambre_7` | `soins_discrets` | [L3937](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3937) |
| `clinique-privee` | `chambre_7` | `centre_anti_poison` | [L3938](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3938) |
| `clinique-privee` | `chambre_7` | `repas_clinique` | [L3939](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3939) |
| `clinique-privee` | `chambre_7` | `sortie_hopital` | [L3940](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3940) |
| `clinique-privee` | `chambre_8` | `gerer_visites_chambre` | [L3943](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3943) |
| `clinique-privee` | `chambre_8` | `soins` | [L3944](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3944) |
| `clinique-privee` | `chambre_8` | `soins_urgence` | [L3945](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3945) |
| `clinique-privee` | `chambre_8` | `soins_discrets` | [L3946](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3946) |
| `clinique-privee` | `chambre_8` | `centre_anti_poison` | [L3947](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3947) |
| `clinique-privee` | `chambre_8` | `repas_clinique` | [L3948](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3948) |
| `clinique-privee` | `chambre_8` | `sortie_hopital` | [L3949](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3949) |
| `clinique-privee` | `chambre_9` | `gerer_visites_chambre` | [L3952](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3952) |
| `clinique-privee` | `chambre_9` | `soins` | [L3953](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3953) |
| `clinique-privee` | `chambre_9` | `soins_urgence` | [L3954](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3954) |
| `clinique-privee` | `chambre_9` | `soins_discrets` | [L3955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3955) |
| `clinique-privee` | `chambre_9` | `centre_anti_poison` | [L3956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3956) |
| `clinique-privee` | `chambre_9` | `repas_clinique` | [L3957](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3957) |
| `clinique-privee` | `chambre_9` | `sortie_hopital` | [L3958](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3958) |
| `clinique-privee` | `chambre_10` | `gerer_visites_chambre` | [L3961](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3961) |
| `clinique-privee` | `chambre_10` | `soins` | [L3962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3962) |
| `clinique-privee` | `chambre_10` | `soins_urgence` | [L3963](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3963) |
| `clinique-privee` | `chambre_10` | `soins_discrets` | [L3964](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3964) |
| `clinique-privee` | `chambre_10` | `centre_anti_poison` | [L3965](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3965) |
| `clinique-privee` | `chambre_10` | `repas_clinique` | [L3966](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3966) |
| `clinique-privee` | `chambre_10` | `sortie_hopital` | [L3967](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3967) |
| `dispensaire-public` | `salle_attente` | `soin_public` | [L3992](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3992) |
| `dispensaire-public` | `salle_attente` | `repas_hopital` | [L3993](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3993) |
| `dispensaire-public` | `salle_attente` | `sortie_hopital` | [L3994](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3994) |
| `dispensaire-public` | `salle_attente` | `centre_anti_poison` | [L3995](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3995) |
| `dispensaire-public` | `salle_attente` | `transfert_clinique_privee` | [L3996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3996) |
| `dispensaire-public` | `salle_attente` | `vendre_ressource_medicale` | [L3997](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3997) |
| `commissariat` | `accueil_police` | `plainte_police` | [L4033](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4033) |
| `commissariat` | `accueil_police` | `archives_police` | [L4034](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4034) |
| `commissariat` | `accueil_police` | `arreter` | [L4035](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4035) |
| `commissariat` | `accueil_police` | `se_justifier` | [L4036](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4036) |
| `commissariat` | `accueil_police` | `temoin_deposition` | [L4041](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4041) |
| `commissariat` | `prison` | `se_rebeller` | [L4053](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4053) |
| `commissariat` | `prison` | `tentative_evasion` | [L4054](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4054) |
| `commissariat` | `bureau_commissaire` | `dossiers_plaintes` | [L4068](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4068) |
| `commissariat` | `bureau_commissaire` | `mener_enquete` | [L4069](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4069) |
| `commissariat` | `bureau_commissaire` | `organiser_filature` | [L4070](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4070) |
| `commissariat` | `bureau_commissaire` | `organiser_chasse_homme` | [L4071](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4071) |
| `commissariat` | `bureau_commissaire` | `recruter_policier` | [L4072](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4072) |
| `commissariat` | `bureau_commissaire` | `recruter_policier_cynophile` | [L4073](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4073) |
| `commissariat` | `bureau_commissaire` | `mobiliser_police` | [L4074](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4074) |
| `commissariat` | `bureau_commissaire` | `gerer_effectifs_police` | [L4075](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4075) |
| `la-tribune` | `accueil_tribune` | `se_renseigner` | [L4106](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4106) |
| `la-tribune` | `accueil_tribune` | `imprimer_tracts_electoraux` | [L4111](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4111) |
| `la-tribune` | `accueil_tribune` | `vendre_bois_imprimerie` | [L4112](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4112) |
| `la-tribune` | `redaction` | `publicite_premium` | [L4126](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4126) |
| `la-tribune` | `redaction` | `consulter_archives_presse` | [L4127](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4127) |
| `la-tribune` | `redaction` | `produire_fuite` | [L4130](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4130) |
| `la-tribune` | `redaction` | `fabriquer_scandale` | [L4134](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4134) |
| `la-tribune` | `redaction` | `interview` | [L4135](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4135) |
| `la-tribune` | `redaction` | `article` | [L4136](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4136) |
| `la-tribune` | `redaction` | `corrompre_journaliste` | [L4139](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4139) |
| `la-tribune` | `redaction` | `etouffer` | [L4140](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4140) |
| `loge-maconnique` | `portail` | `demander_parler_loge` | [L4166](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4166) |
| `loge-maconnique` | `bureau_venerable` | `recruter_informateur_2` | [L4193](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4193) |
| `loge-maconnique` | `bureau_venerable` | `recruter_info_4` | [L4194](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4194) |
| `loge-maconnique` | `bureau_venerable` | `consulter_info_4` | [L4195](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4195) |
| `loge-maconnique` | `bureau_venerable` | `gerer_informateurs` | [L4196](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4196) |
| `loge-maconnique` | `salle_reunion_loge` | `deliberer_loge` | [L4209](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4209) |
| `universite` | `amphi` | `donner_conf` | [L4234](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4234) |
| `universite` | `amphi` | `recruter_etud` | [L4235](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4235) |
| `universite` | `amphi` | `suivre_formation` | [L4251](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4251) |
| `universite` | `salle_reunion` | `syndicat_etudiant_creer` | [L4277](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4277) |
| `universite` | `salle_reunion` | `syndicat_etudiant_gerer` | [L4278](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4278) |
| `universite` | `salle_reunion` | `recruter_etud` | [L4279](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4279) |
| `armurerie` | `magasin` | `choisir_arme` | [L4304](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4304) |
| `armurerie` | `magasin` | `acheter_gilet` | [L4310](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4310) |
| `armurerie` | `magasin` | `consulter_registre_armes` | [L4317](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4317) |
| `armurerie` | `magasin` | `produire_arme` | [L4322](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4322) |
| `armurerie` | `magasin` | `vendre_matiere_commerce` | [L4323](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4323) |
| `marche` | `marche_ext` | `se_nourrir` | [L4349](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4349) |
| `marche` | `marche_ext` | `pouls_populaire` | [L4350](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4350) |
| `marche` | `marche_ext` | `lancer_rumeur_cible` | [L4353](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4353) |
| `mairie-capitale` | `hall_mairie` | `calendrier_elections` | [L4381](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4381) |
| `mairie-capitale` | `hall_mairie` | `etat_civil` | [L4391](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4391) |
| `mairie-capitale` | `hall_mairie` | `objet_trouve` | [L4393](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4393) |
| `mairie-capitale` | `hall_mairie` | `consulter_organigramme_mairie` | [L4394](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4394) |
| `mairie-capitale` | `bureau_maire` | `fixer_impots_locaux` | [L4406](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4406) |
| `mairie-capitale` | `bureau_maire` | `repartition_budget_local` | [L4407](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4407) |
| `mairie-capitale` | `bureau_maire` | `subvention_proposer` | [L4408](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4408) |
| `mairie-capitale` | `bureau_maire` | `campagne_securite` | [L4409](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4409) |
| `mairie-capitale` | `bureau_maire` | `nominations_municipales` | [L4410](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4410) |
| `mairie-capitale` | `bureau_maire_adjoint` | `traiter_demandes_permis` | [L4420](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4420) |
| `mairie-capitale` | `bureau_maire_adjoint` | `consulter_dossiers_urbanisme` | [L4421](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4421) |
| `mairie-capitale` | `bureau_maire_adjoint` | `demander_logement_social` | [L4423](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4423) |
| `mairie-capitale` | `bureau_maire_adjoint` | `traiter_demandes_logement_social` | [L4424](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4424) |
| `mairie-capitale` | `bureau_maire_adjoint` | `acte_officiel_mairie` | [L4425](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4425) |
| `mairie-capitale` | `bureau_maire_adjoint` | `financer_communal` | [L4426](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4426) |
| `mairie-capitale` | `salle_elections` | `consulter_elections` | [L4438](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4438) |
| `mairie-capitale` | `salle_elections` | `voter_election` | [L4439](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4439) |
| `mairie-capitale` | `salle_elections` | `contester_resultats` | [L4444](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4444) |
| `mairie-capitale` | `salle_elections` | `falsifier_listes_electorales` | [L4445](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4445) |
| `mairie-capitale` | `salle_elections` | `bourrer_urnes` | [L4446](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4446) |
| `mairie-capitale` | `salle_elections` | `truquer_depouillement` | [L4447](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4447) |
| `mairie-capitale` | `salle_archives` | `consulter_etat_civil` | [L4459](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4459) |
| `mairie-capitale` | `salle_archives` | `consulter_mandats_maires` | [L4460](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4460) |
| `musee-port-sainte-marie` | `salle_criminels` | `consulter_personnalites_musee` | [L4503](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4503) |
| `musee-port-sainte-marie` | `salle_maires` | `consulter_personnalites_musee` | [L4514](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4514) |
| `musee-port-sainte-marie` | `salle_personnalites` | `consulter_personnalites_musee` | [L4525](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4525) |
| `musee-port-sainte-marie` | `salle_entrepreneurs` | `consulter_personnalites_musee` | [L4536](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4536) |
| `musee-port-sainte-marie` | `salle_organisations` | `consulter_personnalites_musee` | [L4547](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4547) |
| `musee-port-sainte-marie` | `salle_honneur_militaire` | `consulter_personnalites_musee` | [L4570](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4570) |
| `musee-port-sainte-marie` | `salle_unions` | `consulter_personnalites_musee` | [L4581](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4581) |
| `musee-port-sainte-marie` | `salle_scandales` | `consulter_personnalites_musee` | [L4594](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4594) |
| `musee-novomirsk` | `salle_criminels` | `consulter_personnalites_musee` | [L4630](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4630) |
| `musee-novomirsk` | `salle_maires` | `consulter_personnalites_musee` | [L4639](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4639) |
| `musee-novomirsk` | `salle_personnalites` | `consulter_personnalites_musee` | [L4648](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4648) |
| `musee-novomirsk` | `salle_entrepreneurs` | `consulter_personnalites_musee` | [L4657](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4657) |
| `musee-novomirsk` | `salle_organisations` | `consulter_personnalites_musee` | [L4666](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4666) |
| `musee-novomirsk` | `salle_honneur_militaire` | `consulter_personnalites_musee` | [L4682](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4682) |
| `musee-novomirsk` | `salle_unions` | `consulter_personnalites_musee` | [L4691](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4691) |
| `musee-novomirsk` | `salle_scandales` | `consulter_personnalites_musee` | [L4700](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4700) |
| `centre-commercial` | `hall` | `se_renseigner` | [L4728](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4728) |
| `centre-commercial` | `vitrine_principale` | `commerce_pj` | [L4741](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4741) |
| `centre-commercial` | `vitrine_principale` | `louer_local` | [L4742](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4742) |
| `centre-commercial` | `vitrine_principale` | `gerer_local` | [L4743](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4743) |
| `centre-commercial` | `boutique_milieu` | `commerce_pj` | [L4755](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4755) |
| `centre-commercial` | `boutique_milieu` | `louer_local` | [L4756](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4756) |
| `centre-commercial` | `boutique_milieu` | `gerer_local` | [L4757](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4757) |
| `centre-commercial` | `arriere_boutique` | `commerce_pj` | [L4769](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4769) |
| `centre-commercial` | `arriere_boutique` | `louer_local` | [L4770](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4770) |
| `centre-commercial` | `arriere_boutique` | `gerer_local` | [L4771](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4771) |
| `centre-commercial` | `cave_reserve` | `commerce_pj` | [L4783](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4783) |
| `centre-commercial` | `cave_reserve` | `louer_local` | [L4784](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4784) |
| `centre-commercial` | `cave_reserve` | `gerer_local` | [L4785](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4785) |
| `centre-artisanal` | `travees` | `se_renseigner` | [L4810](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4810) |
| `centre-artisanal` | `echoppe_facade` | `commerce_pj` | [L4827](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4827) |
| `centre-artisanal` | `echoppe_facade` | `louer_local` | [L4828](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4828) |
| `centre-artisanal` | `echoppe_facade` | `gerer_local` | [L4829](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4829) |
| `centre-artisanal` | `atelier_milieu` | `commerce_pj` | [L4841](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4841) |
| `centre-artisanal` | `atelier_milieu` | `louer_local` | [L4842](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4842) |
| `centre-artisanal` | `atelier_milieu` | `gerer_local` | [L4843](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4843) |
| `centre-artisanal` | `reserve_arriere` | `commerce_pj` | [L4855](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4855) |
| `centre-artisanal` | `reserve_arriere` | `louer_local` | [L4856](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4856) |
| `centre-artisanal` | `reserve_arriere` | `gerer_local` | [L4857](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4857) |
| `centre-affaires` | `hall` | `se_renseigner` | [L4885](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4885) |
| `centre-affaires` | `bureau_prestige` | `louer_local` | [L4898](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4898) |
| `centre-affaires` | `bureau_prestige` | `gerer_local` | [L4899](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4899) |
| `centre-affaires` | `bureau_prestige` | `installer_equipements` | déclaration partagée [L315](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L315) |
| `centre-affaires` | `bureau_standard` | `louer_local` | [L4912](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4912) |
| `centre-affaires` | `bureau_standard` | `gerer_local` | [L4913](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4913) |
| `centre-affaires` | `bureau_standard` | `installer_equipements` | déclaration partagée [L315](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L315) |
| `centre-affaires` | `open_space` | `louer_local` | [L4926](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4926) |
| `centre-affaires` | `open_space` | `gerer_local` | [L4927](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4927) |
| `centre-affaires` | `open_space` | `installer_equipements` | déclaration partagée [L315](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L315) |
| `centre-affaires` | `tribune_republia` | `produire_fuite` | [L4939](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4939) |
| `centre-affaires` | `tribune_republia` | `interview` | [L4940](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4940) |
| `terrain-a-batir-4` | `terrain` | `appeler_police_terrain` | [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-4` | `terrain` | `faire_disparaitre_cadavre` | [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-4` | `terrain` | `negocier_squatteurs` | [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-4` | `terrain` | `signer_compromis` | [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-4` | `terrain` | `acheter_terrain` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `construire_sur_terrain` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `corrompre_rdv_notaire` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `corrompre_fonctionnaire_permis` | déclaration partagée [L6004](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6004) |
| `terrain-a-batir-4` | `terrain` | `payer_versement_chantier` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `travailler_chantier` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `vendre_materiaux_chantier` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `modifier_plan_chantier` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `voler_materiel_chantier` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `diviser_construction` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `reconfigurer_lots` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `louer_lot_ici` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `gerer_lot_loue` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `gerer_fonds_commerce` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `emprunter_construction` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-4` | `terrain` | `racheter_terrain` | [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-5` | `terrain` | `appeler_police_terrain` | [L4961](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4961) |
| `terrain-a-batir-5` | `terrain` | `faire_disparaitre_cadavre` | [L4961](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4961) |
| `terrain-a-batir-5` | `terrain` | `negocier_squatteurs` | [L4961](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4961) |
| `terrain-a-batir-5` | `terrain` | `signer_compromis` | [L4961](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4961) |
| `terrain-a-batir-5` | `terrain` | `acheter_terrain` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `construire_sur_terrain` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `corrompre_rdv_notaire` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `corrompre_fonctionnaire_permis` | déclaration partagée [L6004](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6004) |
| `terrain-a-batir-5` | `terrain` | `payer_versement_chantier` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `travailler_chantier` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `vendre_materiaux_chantier` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `modifier_plan_chantier` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `voler_materiel_chantier` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `diviser_construction` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `reconfigurer_lots` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `louer_lot_ici` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `gerer_lot_loue` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `gerer_fonds_commerce` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `emprunter_construction` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-5` | `terrain` | `racheter_terrain` | [L4962](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4962) |
| `terrain-a-batir-6` | `terrain` | `appeler_police_terrain` | [L4967](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4967) |
| `terrain-a-batir-6` | `terrain` | `faire_disparaitre_cadavre` | [L4967](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4967) |
| `terrain-a-batir-6` | `terrain` | `negocier_squatteurs` | [L4967](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4967) |
| `terrain-a-batir-6` | `terrain` | `signer_compromis` | [L4967](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4967) |
| `terrain-a-batir-6` | `terrain` | `acheter_terrain` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `construire_sur_terrain` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `corrompre_rdv_notaire` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `corrompre_fonctionnaire_permis` | déclaration partagée [L6004](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6004) |
| `terrain-a-batir-6` | `terrain` | `payer_versement_chantier` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `travailler_chantier` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `vendre_materiaux_chantier` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `modifier_plan_chantier` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `voler_materiel_chantier` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `diviser_construction` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `reconfigurer_lots` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `louer_lot_ici` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `gerer_lot_loue` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `gerer_fonds_commerce` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `emprunter_construction` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-6` | `terrain` | `racheter_terrain` | [L4968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4968) |
| `terrain-a-batir-7` | `terrain` | `appeler_police_terrain` | [L4973](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4973) |
| `terrain-a-batir-7` | `terrain` | `faire_disparaitre_cadavre` | [L4973](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4973) |
| `terrain-a-batir-7` | `terrain` | `negocier_squatteurs` | [L4973](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4973) |
| `terrain-a-batir-7` | `terrain` | `signer_compromis` | [L4973](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4973) |
| `terrain-a-batir-7` | `terrain` | `acheter_terrain` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `construire_sur_terrain` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `corrompre_rdv_notaire` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `corrompre_fonctionnaire_permis` | déclaration partagée [L6004](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6004) |
| `terrain-a-batir-7` | `terrain` | `payer_versement_chantier` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `travailler_chantier` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `vendre_materiaux_chantier` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `modifier_plan_chantier` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `voler_materiel_chantier` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `diviser_construction` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `reconfigurer_lots` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `louer_lot_ici` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `gerer_lot_loue` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `gerer_fonds_commerce` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `emprunter_construction` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-7` | `terrain` | `racheter_terrain` | [L4974](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4974) |
| `terrain-a-batir-montrouge-3` | `terrain` | `appeler_police_terrain` | [L4989](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4989) |
| `terrain-a-batir-montrouge-3` | `terrain` | `faire_disparaitre_cadavre` | [L4989](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4989) |
| `terrain-a-batir-montrouge-3` | `terrain` | `negocier_squatteurs` | [L4989](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4989) |
| `terrain-a-batir-montrouge-3` | `terrain` | `signer_compromis` | [L4989](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4989) |
| `terrain-a-batir-montrouge-3` | `terrain` | `acheter_terrain` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `construire_sur_terrain` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `corrompre_rdv_notaire` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `corrompre_fonctionnaire_permis` | déclaration partagée [L6004](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6004) |
| `terrain-a-batir-montrouge-3` | `terrain` | `payer_versement_chantier` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `travailler_chantier` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `vendre_materiaux_chantier` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `modifier_plan_chantier` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `voler_materiel_chantier` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `diviser_construction` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `reconfigurer_lots` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `louer_lot_ici` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `gerer_lot_loue` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `gerer_fonds_commerce` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `emprunter_construction` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-3` | `terrain` | `racheter_terrain` | [L4990](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4990) |
| `terrain-a-batir-montrouge-7` | `terrain` | `appeler_police_terrain` | [L4995](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4995) |
| `terrain-a-batir-montrouge-7` | `terrain` | `faire_disparaitre_cadavre` | [L4995](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4995) |
| `terrain-a-batir-montrouge-7` | `terrain` | `negocier_squatteurs` | [L4995](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4995) |
| `terrain-a-batir-montrouge-7` | `terrain` | `signer_compromis` | [L4995](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4995) |
| `terrain-a-batir-montrouge-7` | `terrain` | `acheter_terrain` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `construire_sur_terrain` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `corrompre_rdv_notaire` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `corrompre_fonctionnaire_permis` | déclaration partagée [L6004](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6004) |
| `terrain-a-batir-montrouge-7` | `terrain` | `payer_versement_chantier` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `travailler_chantier` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `vendre_materiaux_chantier` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `modifier_plan_chantier` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `voler_materiel_chantier` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `diviser_construction` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `reconfigurer_lots` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `louer_lot_ici` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `gerer_lot_loue` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `gerer_fonds_commerce` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `emprunter_construction` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-7` | `terrain` | `racheter_terrain` | [L4996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4996) |
| `terrain-a-batir-montrouge-8` | `terrain` | `appeler_police_terrain` | [L5001](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5001) |
| `terrain-a-batir-montrouge-8` | `terrain` | `faire_disparaitre_cadavre` | [L5001](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5001) |
| `terrain-a-batir-montrouge-8` | `terrain` | `negocier_squatteurs` | [L5001](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5001) |
| `terrain-a-batir-montrouge-8` | `terrain` | `signer_compromis` | [L5001](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5001) |
| `terrain-a-batir-montrouge-8` | `terrain` | `acheter_terrain` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `construire_sur_terrain` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `corrompre_rdv_notaire` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `corrompre_fonctionnaire_permis` | déclaration partagée [L6004](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6004) |
| `terrain-a-batir-montrouge-8` | `terrain` | `payer_versement_chantier` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `travailler_chantier` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `vendre_materiaux_chantier` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `modifier_plan_chantier` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `voler_materiel_chantier` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `diviser_construction` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `reconfigurer_lots` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `louer_lot_ici` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `gerer_lot_loue` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `gerer_fonds_commerce` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `emprunter_construction` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-8` | `terrain` | `racheter_terrain` | [L5002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5002) |
| `terrain-a-batir-montrouge-9` | `terrain` | `appeler_police_terrain` | [L5007](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5007) |
| `terrain-a-batir-montrouge-9` | `terrain` | `faire_disparaitre_cadavre` | [L5007](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5007) |
| `terrain-a-batir-montrouge-9` | `terrain` | `negocier_squatteurs` | [L5007](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5007) |
| `terrain-a-batir-montrouge-9` | `terrain` | `signer_compromis` | [L5007](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5007) |
| `terrain-a-batir-montrouge-9` | `terrain` | `acheter_terrain` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `construire_sur_terrain` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `corrompre_rdv_notaire` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `corrompre_fonctionnaire_permis` | déclaration partagée [L6004](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6004) |
| `terrain-a-batir-montrouge-9` | `terrain` | `payer_versement_chantier` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `travailler_chantier` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `vendre_materiaux_chantier` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `modifier_plan_chantier` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `voler_materiel_chantier` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `diviser_construction` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `reconfigurer_lots` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `louer_lot_ici` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `gerer_lot_loue` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `gerer_fonds_commerce` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `emprunter_construction` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-9` | `terrain` | `racheter_terrain` | [L5008](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5008) |
| `terrain-a-batir-montrouge-12` | `terrain` | `appeler_police_terrain` | [L5013](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5013) |
| `terrain-a-batir-montrouge-12` | `terrain` | `faire_disparaitre_cadavre` | [L5013](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5013) |
| `terrain-a-batir-montrouge-12` | `terrain` | `negocier_squatteurs` | [L5013](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5013) |
| `terrain-a-batir-montrouge-12` | `terrain` | `signer_compromis` | [L5013](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5013) |
| `terrain-a-batir-montrouge-12` | `terrain` | `acheter_terrain` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `construire_sur_terrain` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `corrompre_rdv_notaire` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `corrompre_fonctionnaire_permis` | déclaration partagée [L6004](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6004) |
| `terrain-a-batir-montrouge-12` | `terrain` | `payer_versement_chantier` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `travailler_chantier` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `vendre_materiaux_chantier` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `modifier_plan_chantier` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `voler_materiel_chantier` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `diviser_construction` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `reconfigurer_lots` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `louer_lot_ici` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `gerer_lot_loue` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `gerer_fonds_commerce` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `emprunter_construction` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-montrouge-12` | `terrain` | `racheter_terrain` | [L5014](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5014) |
| `terrain-a-batir-1` | `terrain` | `appeler_police_terrain` | [L5032](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5032) |
| `terrain-a-batir-1` | `terrain` | `faire_disparaitre_cadavre` | [L5033](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5033) |
| `terrain-a-batir-1` | `terrain` | `negocier_squatteurs` | [L5034](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5034) |
| `terrain-a-batir-1` | `terrain` | `signer_compromis` | [L5036](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5036) |
| `terrain-a-batir-1` | `terrain` | `acheter_terrain` | [L5038](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5038) |
| `terrain-a-batir-1` | `terrain` | `construire_sur_terrain` | [L5039](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5039) |
| `terrain-a-batir-1` | `terrain` | `corrompre_rdv_notaire` | [L5039](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5039) |
| `terrain-a-batir-1` | `terrain` | `corrompre_fonctionnaire_permis` | déclaration partagée [L6004](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6004) |
| `terrain-a-batir-1` | `terrain` | `payer_versement_chantier` | [L5039](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5039) |
| `terrain-a-batir-1` | `terrain` | `travailler_chantier` | [L5039](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5039) |
| `terrain-a-batir-1` | `terrain` | `vendre_materiaux_chantier` | [L5039](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5039) |
| `terrain-a-batir-1` | `terrain` | `modifier_plan_chantier` | [L5039](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5039) |
| `terrain-a-batir-1` | `terrain` | `voler_materiel_chantier` | [L5039](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5039) |
| `terrain-a-batir-1` | `terrain` | `diviser_construction` | [L5039](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5039) |
| `terrain-a-batir-1` | `terrain` | `reconfigurer_lots` | [L5039](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5039) |
| `terrain-a-batir-1` | `terrain` | `louer_lot_ici` | [L5039](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5039) |
| `terrain-a-batir-1` | `terrain` | `gerer_lot_loue` | [L5039](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5039) |
| `terrain-a-batir-1` | `terrain` | `gerer_fonds_commerce` | [L5039](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5039) |
| `terrain-a-batir-1` | `terrain` | `emprunter_construction` | [L5040](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5040) |
| `terrain-a-batir-1` | `terrain` | `racheter_terrain` | [L5041](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5041) |
| `mairie` | `accueil_mairie` | `calendrier_elections` | [L5069](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5069) |
| `mairie` | `accueil_mairie` | `objet_trouve` | [L5070](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5070) |
| `mairie` | `accueil_mairie` | `etat_civil` | [L5076](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5076) |
| `mairie` | `accueil_mairie` | `consulter_organigramme_mairie` | [L5078](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5078) |
| `mairie` | `bureau_maire_local` | `fixer_impots_locaux` | [L5091](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5091) |
| `mairie` | `bureau_maire_local` | `repartition_budget_local` | [L5092](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5092) |
| `mairie` | `bureau_maire_local` | `subvention_proposer` | [L5093](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5093) |
| `mairie` | `bureau_maire_local` | `campagne_securite` | [L5094](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5094) |
| `mairie` | `bureau_maire_local` | `nominations_municipales` | [L5095](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5095) |
| `mairie` | `bureau_maire_adjoint` | `traiter_demandes_permis` | [L5106](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5106) |
| `mairie` | `bureau_maire_adjoint` | `consulter_dossiers_urbanisme` | [L5107](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5107) |
| `mairie` | `bureau_maire_adjoint` | `demander_logement_social` | [L5109](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5109) |
| `mairie` | `bureau_maire_adjoint` | `traiter_demandes_logement_social` | [L5110](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5110) |
| `mairie` | `bureau_maire_adjoint` | `acte_officiel_mairie` | [L5111](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5111) |
| `mairie` | `bureau_maire_adjoint` | `financer_communal` | [L5112](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5112) |
| `hotel-port` | `hall_port` | `produire_commerce` | [L5143](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5143) |
| `hotel-port` | `hall_port` | `consulter_carte_commerce` | [L5144](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5144) |
| `hotel-port` | `hall_port` | `gerer_commerce` | [L5145](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5145) |
| `hotel-port` | `hall_port` | `vendre_matiere_commerce` | [L5146](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5146) |
| `hotel-port` | `hall_port` | `reserver_chambre_hotel` | [L5147](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5147) |
| `hotel-port` | `chambre_port` | `dormir_chambre` | [L5158](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5158) |
| `hotel-port` | `chambre_port` | `service_etage` | [L5160](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5160) |
| `bar-des-pecheurs` | `salle_bar` | `produire_commerce` | [L5209](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5209) |
| `bar-des-pecheurs` | `salle_bar` | `consulter_carte_commerce` | [L5210](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5210) |
| `bar-des-pecheurs` | `salle_bar` | `offrir_tournee` | [L5211](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5211) |
| `bar-des-pecheurs` | `salle_bar` | `gerer_commerce` | [L5212](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5212) |
| `bar-des-pecheurs` | `salle_bar` | `vendre_matiere_commerce` | [L5213](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5213) |
| `bar-des-pecheurs` | `salle_bar` | `ecouter_rumeurs` | [L5214](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5214) |
| `bar-des-pecheurs` | `salle_bar` | `lancer_rumeur_cible` | [L5218](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5218) |
| `bar-des-pecheurs` | `salle_bar` | `recruter_informateur_pnj` | [L5219](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5219) |
| `services-sociaux-montrouge` | `accueil` | `ssm_besoin_aide` | [L5242](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5242) |
| `services-sociaux-montrouge` | `accueil` | `ssm_demander_rendezvous` | [L5243](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5243) |
| `services-sociaux-montrouge` | `bureau_assistante_sociale` | `demander_logement_social` | [L5253](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5253) |
| `siege-syndical` | `bureau_syndical` | `mobiliser` | [L5291](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5291) |
| `usine-principale` | `direction_usine` | `acheter_entreprise` | [L5313](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5313) |
| `hotel-mineur` | `hall_mineur` | `produire_commerce` | [L5340](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5340) |
| `hotel-mineur` | `hall_mineur` | `consulter_carte_commerce` | [L5341](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5341) |
| `hotel-mineur` | `hall_mineur` | `gerer_commerce` | [L5342](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5342) |
| `hotel-mineur` | `hall_mineur` | `vendre_matiere_commerce` | [L5343](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5343) |
| `hotel-mineur` | `hall_mineur` | `reserver_chambre_hotel` | [L5344](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5344) |
| `hotel-mineur` | `chambre_mineur` | `dormir_chambre` | [L5359](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5359) |
| `hotel-mineur` | `chambre_mineur` | `service_etage` | [L5361](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5361) |
| `banque-locale` | `guichet` | `gerer_finances` | [L5386](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5386) |
| `banque-locale` | `guichet` | `emprunter` | [L5387](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5387) |
| `banque-locale` | `guichet` | `virements` | [L5389](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5389) |
| `dispensaire-public-v` | `attente` | `soin_public` | [L5411](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5411) |
| `dispensaire-public-v` | `attente` | `centre_anti_poison` | [L5413](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5413) |
| `dispensaire-public-v` | `attente` | `transfert_clinique_privee` | [L5414](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5414) |
| `dispensaire-public-v` | `attente` | `repas_hopital` | [L5415](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5415) |
| `dispensaire-public-v` | `attente` | `sortie_hopital` | [L5416](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5416) |
| `dispensaire-public-v` | `attente` | `vendre_ressource_medicale` | [L5417](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5417) |
| `commissariat-local` | `accueil_loc` | `plainte_police` | [L5454](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5454) |
| `commissariat-local` | `accueil_loc` | `archives_police` | [L5457](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5457) |
| `commissariat-local` | `accueil_loc` | `arreter` | [L5458](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5458) |
| `commissariat-local` | `accueil_loc` | `se_justifier` | [L5463](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5463) |
| `commissariat-local` | `accueil_loc` | `temoin_deposition` | [L5468](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5468) |
| `commissariat-local` | `geoles` | `se_rebeller` | [L5491](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5491) |
| `commissariat-local` | `geoles` | `tentative_evasion` | [L5492](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5492) |
| `commissariat-local` | `bureau_commissaire` | `dossiers_plaintes` | [L5504](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5504) |
| `commissariat-local` | `bureau_commissaire` | `mener_enquete` | [L5505](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5505) |
| `commissariat-local` | `bureau_commissaire` | `organiser_filature` | [L5506](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5506) |
| `commissariat-local` | `bureau_commissaire` | `organiser_chasse_homme` | [L5507](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5507) |
| `commissariat-local` | `bureau_commissaire` | `recruter_policier` | [L5508](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5508) |
| `commissariat-local` | `bureau_commissaire` | `recruter_policier_cynophile` | [L5509](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5509) |
| `commissariat-local` | `bureau_commissaire` | `mobiliser_police` | [L5510](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5510) |
| `commissariat-local` | `bureau_commissaire` | `gerer_effectifs_police` | [L5511](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5511) |
| `tribunal-local` | `salle_audience_locale` | `defense` | [L5538](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5538) |
| `tribunal-local` | `salle_audience_locale` | `temoins_mes_convocations` | [L5539](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5539) |
| `tribunal-local` | `salle_audience_locale` | `audience_salle` | [L5540](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5540) |
| `tribunal-local` | `bureau_magistrats` | `parquet` | [L5554](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5554) |
| `tribunal-local` | `bureau_magistrats` | `rendre_sentence` | [L5555](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5555) |
| `tribunal-local` | `bureau_magistrats` | `audience_juge` | [L5556](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5556) |
| `tribunal-local` | `bureau_magistrats` | `acte_officiel_juge` | [L5557](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5557) |
| `tribunal-local` | `greffe` | `archives` | [L5574](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5574) |
| `tribunal-local` | `greffe` | `falsifier_document` | [L5576](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5576) |
| `tribunal-local` | `greffe` | `avocat_dossiers` | [L5577](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5577) |
| `tribunal-local` | `greffe` | `avocat_barreau` | [L5578](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5578) |
| `tribunal-local` | `greffe` | `greffe_affaires` | [L5579](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5579) |
| `tribunal-local` | `greffe` | `greffe_archives` | [L5580](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5580) |
| `tribunal-local` | `greffe` | `casier_mon_extrait` | [L5586](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5586) |
| `tribunal-local` | `greffe` | `casier_extrait_enquete` | [L5587](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5587) |
| `tribunal-local` | `greffe` | `orga_extrait_duplicata` | [L5588](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5588) |
| `tribunal-local` | `greffe` | `greffe_corrompre_dossier` | [L5589](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5589) |
| `tribunal-local` | `greffe` | `greffe_corrompre_faux_casier` | [L5590](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5590) |
| `imprimerie-librairie` | `accueil_imprimerie` | `imprimer_tracts_electoraux` | [L5622](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5622) |
| `imprimerie-librairie` | `atelier` | `imprimer_tracts_calomnieux` | [L5645](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5645) |
| `imprimerie-librairie` | `atelier` | `vendre_bois_imprimerie` | [L5646](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5646) |
| `marche-psm` | `etals` | `produire_commerce` | [L5685](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5685) |
| `marche-psm` | `etals` | `faire_achats_marche` | [L5686](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5686) |
| `marche-psm` | `etals` | `pouls_populaire` | [L5688](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5688) |
| `marche-psm` | `etals` | `vendre_matiere_commerce` | [L5689](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5689) |
| `marche-psm` | `etals` | `lancer_rumeur_cible` | [L5692](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5692) |
| `capitaine-sauvage` | `salle_principale` | `diner_affaires` | [L5726](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5726) |
| `capitaine-sauvage` | `salle_principale` | `ecouter_rumeurs` | [L5727](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5727) |
| `capitaine-sauvage` | `salle_principale` | `lancer_rumeur_cible` | [L5728](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5728) |
| `capitaine-sauvage` | `salle_principale` | `produire_commerce` | [L5729](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5729) |
| `capitaine-sauvage` | `salle_principale` | `consulter_carte_commerce` | [L5730](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5730) |
| `capitaine-sauvage` | `salle_principale` | `gerer_commerce` | [L5731](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5731) |
| `capitaine-sauvage` | `salle_principale` | `vendre_matiere_commerce` | [L5732](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5732) |
| `chasse-peche-psm` | `boutique` | `choisir_arme` | [L5764](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5764) |
| `chasse-peche-psm` | `boutique` | `acheter_gilet` | [L5770](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5770) |
| `chasse-peche-psm` | `boutique` | `consulter_registre_armes` | [L5777](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5777) |
| `chasse-peche-psm` | `boutique` | `produire_arme` | [L5782](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5782) |
| `chasse-peche-psm` | `boutique` | `vendre_matiere_commerce` | [L5783](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5783) |
| `chasse-peche-psm` | `boutique` | `marche_noir` | [L5784](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5784) |
| `place-armes-psm` | `place` | `organiser_manifestation_spontanee` | [L5805](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5805) |
| `chantier-naval` | `hall` | `consulter_devis_chantier_naval` | [L5861](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5861) |
| `chantier-naval` | `bureau` | `consulter_devis_chantier_naval` | [L5873](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5873) |
| `notre-dame-mer` | `nef` | `prier` | [L5909](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5909) |
| `notre-dame-mer` | `nef` | `faire_don` | [L5910](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5910) |
| `terrain-a-batir-8` | `terrain8` | `appeler_police_terrain` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-8` | `terrain8` | `faire_disparaitre_cadavre` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-8` | `terrain8` | `negocier_squatteurs` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-8` | `terrain8` | `signer_compromis` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-8` | `terrain8` | `acheter_terrain` | [L6002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6002) |
| `terrain-a-batir-8` | `terrain8` | `construire_sur_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `corrompre_rdv_notaire` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `corrompre_fonctionnaire_permis` | [L6004](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6004) |
| `terrain-a-batir-8` | `terrain8` | `payer_versement_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `travailler_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `vendre_materiaux_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `modifier_plan_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `voler_materiel_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `diviser_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `reconfigurer_lots` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `louer_lot_ici` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `gerer_lot_loue` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `gerer_fonds_commerce` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `emprunter_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-8` | `terrain8` | `racheter_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `appeler_police_terrain` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-9` | `terrain9` | `faire_disparaitre_cadavre` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-9` | `terrain9` | `negocier_squatteurs` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-9` | `terrain9` | `signer_compromis` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-9` | `terrain9` | `acheter_terrain` | [L6025](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6025) |
| `terrain-a-batir-9` | `terrain9` | `construire_sur_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `corrompre_rdv_notaire` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `corrompre_fonctionnaire_permis` | [L6027](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6027) |
| `terrain-a-batir-9` | `terrain9` | `payer_versement_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `travailler_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `vendre_materiaux_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `modifier_plan_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `voler_materiel_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `diviser_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `reconfigurer_lots` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `louer_lot_ici` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `gerer_lot_loue` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `gerer_fonds_commerce` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `emprunter_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-9` | `terrain9` | `racheter_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `appeler_police_terrain` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-10` | `terrain10` | `faire_disparaitre_cadavre` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-10` | `terrain10` | `negocier_squatteurs` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-10` | `terrain10` | `signer_compromis` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-10` | `terrain10` | `acheter_terrain` | [L6048](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6048) |
| `terrain-a-batir-10` | `terrain10` | `construire_sur_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `corrompre_rdv_notaire` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `corrompre_fonctionnaire_permis` | [L6050](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6050) |
| `terrain-a-batir-10` | `terrain10` | `payer_versement_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `travailler_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `vendre_materiaux_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `modifier_plan_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `voler_materiel_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `diviser_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `reconfigurer_lots` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `louer_lot_ici` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `gerer_lot_loue` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `gerer_fonds_commerce` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `emprunter_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-10` | `terrain10` | `racheter_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `appeler_police_terrain` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-11` | `terrain11` | `faire_disparaitre_cadavre` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-11` | `terrain11` | `negocier_squatteurs` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-11` | `terrain11` | `signer_compromis` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-11` | `terrain11` | `acheter_terrain` | [L6071](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6071) |
| `terrain-a-batir-11` | `terrain11` | `construire_sur_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `corrompre_rdv_notaire` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `corrompre_fonctionnaire_permis` | [L6073](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6073) |
| `terrain-a-batir-11` | `terrain11` | `payer_versement_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `travailler_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `vendre_materiaux_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `modifier_plan_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `voler_materiel_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `diviser_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `reconfigurer_lots` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `louer_lot_ici` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `gerer_lot_loue` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `gerer_fonds_commerce` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `emprunter_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-11` | `terrain11` | `racheter_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `appeler_police_terrain` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-psm-12` | `terrain` | `faire_disparaitre_cadavre` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-psm-12` | `terrain` | `negocier_squatteurs` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-psm-12` | `terrain` | `signer_compromis` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-psm-12` | `terrain` | `acheter_terrain` | [L6097](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6097) |
| `terrain-a-batir-psm-12` | `terrain` | `construire_sur_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `corrompre_rdv_notaire` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `corrompre_fonctionnaire_permis` | [L6099](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6099) |
| `terrain-a-batir-psm-12` | `terrain` | `payer_versement_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `travailler_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `vendre_materiaux_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `modifier_plan_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `voler_materiel_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `diviser_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `reconfigurer_lots` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `louer_lot_ici` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `gerer_lot_loue` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `gerer_fonds_commerce` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `emprunter_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-12` | `terrain` | `racheter_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `appeler_police_terrain` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-psm-13` | `terrain` | `faire_disparaitre_cadavre` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-psm-13` | `terrain` | `negocier_squatteurs` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-psm-13` | `terrain` | `signer_compromis` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-psm-13` | `terrain` | `acheter_terrain` | [L6120](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6120) |
| `terrain-a-batir-psm-13` | `terrain` | `construire_sur_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `corrompre_rdv_notaire` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `corrompre_fonctionnaire_permis` | [L6122](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6122) |
| `terrain-a-batir-psm-13` | `terrain` | `payer_versement_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `travailler_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `vendre_materiaux_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `modifier_plan_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `voler_materiel_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `diviser_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `reconfigurer_lots` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `louer_lot_ici` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `gerer_lot_loue` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `gerer_fonds_commerce` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `emprunter_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-psm-13` | `terrain` | `racheter_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `appeler_police_terrain` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-2` | `terrain` | `faire_disparaitre_cadavre` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-2` | `terrain` | `negocier_squatteurs` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-2` | `terrain` | `signer_compromis` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-2` | `terrain` | `acheter_terrain` | [L6143](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6143) |
| `terrain-a-batir-2` | `terrain` | `construire_sur_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `corrompre_rdv_notaire` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `corrompre_fonctionnaire_permis` | [L6145](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6145) |
| `terrain-a-batir-2` | `terrain` | `payer_versement_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `travailler_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `vendre_materiaux_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `modifier_plan_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `voler_materiel_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `diviser_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `reconfigurer_lots` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `louer_lot_ici` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `gerer_lot_loue` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `gerer_fonds_commerce` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `emprunter_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-2` | `terrain` | `racheter_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `appeler_police_terrain` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-3` | `terrain` | `faire_disparaitre_cadavre` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-3` | `terrain` | `negocier_squatteurs` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-3` | `terrain` | `signer_compromis` | déclaration partagée [L4955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4955) |
| `terrain-a-batir-3` | `terrain` | `acheter_terrain` | [L6166](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6166) |
| `terrain-a-batir-3` | `terrain` | `construire_sur_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `corrompre_rdv_notaire` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `corrompre_fonctionnaire_permis` | [L6168](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6168) |
| `terrain-a-batir-3` | `terrain` | `payer_versement_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `travailler_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `vendre_materiaux_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `modifier_plan_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `voler_materiel_chantier` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `diviser_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `reconfigurer_lots` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `louer_lot_ici` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `gerer_lot_loue` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `gerer_fonds_commerce` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `emprunter_construction` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `terrain-a-batir-3` | `terrain` | `racheter_terrain` | déclaration partagée [L4956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4956) |
| `caserne-militaire` | `corps_garde` | `nommer_lieutenant` | [L6209](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6209) |
| `caserne-militaire` | `corps_garde` | `s_engager_armee` | [L6224](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6224) |
| `caserne-militaire` | `corps_garde` | `traiter_candidatures` | [L6225](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6225) |
| `caserne-militaire` | `corps_garde` | `decouvrir_affectation` | [L6226](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6226) |
| `caserne-militaire` | `corps_garde` | `calepin_campagne` | [L6229](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6229) |
| `caserne-militaire` | `corps_garde` | `decorer_militaire` | [L6236](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6236) |
| `caserne-militaire` | `corps_garde` | `quitter_armee` | [L6237](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6237) |
| `caserne-militaire` | `corps_garde` | `demettre_lieutenant` | [L6238](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6238) |
| `caserne-militaire` | `corps_garde` | `se_presenter_affectation` | [L6239](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6239) |
| `caserne-militaire` | `corps_garde` | `stage_caserne` | [L6240](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6240) |
| `caserne-militaire` | `infirmerie` | `retirer_trousse` | [L6262](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6262) |
| `caserne-militaire` | `salle_commandement` | `nommer_capitaine` | [L6317](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6317) |
| `caserne-militaire` | `salle_commandement` | `recherche_militaire` | [L6318](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6318) |
| `caserne-militaire` | `salle_commandement` | `caisse_caserne` | [L6330](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6330) |
| `caserne-militaire` | `salle_commandement` | `repartir_armement` | [L6331](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6331) |
| `caserne-militaire` | `salle_commandement` | `recruter_compagnie` | [L6332](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6332) |
| `caserne-militaire` | `salle_commandement` | `gerer_detachement` | [L6340](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6340) |
| `caserne-militaire` | `salle_commandement` | `voir_ma_section` | [L6341](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6341) |
| `caserne-militaire` | `salle_commandement` | `entrainer_section` | [L6342](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6342) |
| `caserne-militaire` | `salle_commandement` | `reposer_section` | [L6348](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6348) |
| `caserne-militaire` | `salle_commandement` | `equiper_section` | [L6349](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6349) |
| `caserne-militaire` | `salle_commandement` | `declencher_mutinerie` | [L6354](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6354) |
| `caserne-militaire` | `salle_commandement` | `remonter_renseignement` | [L6355](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6355) |
| `caserne-militaire` | `salle_commandement` | `inspecter_troupes` | [L6363](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6363) |
| `caserne-militaire` | `salle_commandement` | `gerer_budget_caserne` | [L6364](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6364) |
| `caserne-militaire` | `salle_commandement` | `tableau_effort_guerre` | [L6367](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6367) |
| `caserne-militaire` | `armurerie_militaire` | `retirer_armes_militaires` | [L6389](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6389) |
| `caserne-militaire` | `armurerie_militaire` | `retirer_explosifs_militaires` | [L6390](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6390) |
| `caserne-militaire` | `armurerie_militaire` | `retirer_equipement_militaire` | [L6395](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6395) |
| `caserne-militaire` | `armurerie_militaire` | `acheter_bombe_illegale` | [L6396](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6396) |
| `caserne-militaire` | `refectoire` | `manger_ration` | [L6420](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6420) |
| `caserne-militaire` | `refectoire` | `retirer_rations` | [L6423](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6423) |
| `caserne-militaire` | `salle_faits_armes` | `consulter_faits_armes` | [L6435](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6435) |
| `musee-national-republia` | `salle_honneur_militaire_nationale` | `consulter_personnalites_musee` | [L6622](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6622) |
| `musee-national-republia` | `salle_politiques` | `consulter_personnalites_musee` | [L6632](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6632) |
| `musee-national-republia` | `salle_civils_intellectuels` | `consulter_personnalites_musee` | [L6643](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6643) |
| `musee-national-republia` | `salle_organisations` | `consulter_personnalites_musee` | [L6654](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6654) |
| `musee-national-republia` | `salle_artistes_sportifs` | `consulter_personnalites_musee` | [L6665](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6665) |
| `musee-national-republia` | `salle_reussites_economiques` | `consulter_personnalites_musee` | [L6685](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6685) |
| `musee-national-republia` | `salle_criminels_pays` | `consulter_personnalites_musee` | [L6705](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6705) |
| `place-formulaire-liberte` | `place` | `organiser_manifestation_spontanee` | [L6763](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6763) |
| `quartier-ambassades` | `accueil_ambassades` | `demander_audience_ambassadeur` | [L6786](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6786) |
| `quartier-ambassades` | `accueil_ambassades` | `demander_asile_politique` | [L6787](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6787) |
| `quartier-ambassades` | `accueil_ambassades` | `reserver_salle_reception` | [L6788](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6788) |
| `quartier-ambassades` | `bureau_al_khalija` | `relations_bilaterales` | [L6805](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6805) |
| `quartier-ambassades` | `bureau_al_khalija` | `organiser_reception_diplomatique` | [L6806](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6806) |
| `quartier-ambassades` | `bureau_al_khalija` | `financer_oeuvre_culturelle` | [L6807](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6807) |
| `quartier-ambassades` | `bureau_al_khalija` | `demander_transfert_detenu` | [L6808](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6808) |
| `quartier-ambassades` | `bureau_sovarka` | `relations_bilaterales` | [L6817](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6817) |
| `quartier-ambassades` | `bureau_sovarka` | `organiser_reception_diplomatique` | [L6818](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6818) |
| `quartier-ambassades` | `bureau_sovarka` | `financer_oeuvre_culturelle` | [L6819](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6819) |
| `quartier-ambassades` | `bureau_sovarka` | `demander_transfert_detenu` | [L6820](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6820) |
| `quartier-ambassades` | `bureau_el_estado` | `relations_bilaterales` | [L6829](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6829) |
| `quartier-ambassades` | `bureau_el_estado` | `organiser_reception_diplomatique` | [L6830](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6830) |
| `quartier-ambassades` | `bureau_el_estado` | `financer_oeuvre_culturelle` | [L6831](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6831) |
| `quartier-ambassades` | `bureau_el_estado` | `demander_transfert_detenu` | [L6832](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6832) |
| `palais-ambassades-novomirsk` | `accueil_ambassades_novomirsk` | `demander_audience_ambassadeur` | [L6862](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6862) |
| `palais-ambassades-novomirsk` | `accueil_ambassades_novomirsk` | `demander_asile_politique` | [L6863](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6863) |
| `palais-ambassades-novomirsk` | `accueil_ambassades_novomirsk` | `reserver_salle_reception` | [L6864](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6864) |
| `palais-ambassades-novomirsk` | `bureau_republia_novomirsk` | `relations_bilaterales` | [L6881](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6881) |
| `palais-ambassades-novomirsk` | `bureau_republia_novomirsk` | `organiser_reception_diplomatique` | [L6882](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6882) |
| `palais-ambassades-novomirsk` | `bureau_republia_novomirsk` | `financer_oeuvre_culturelle` | [L6883](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6883) |
| `palais-ambassades-novomirsk` | `bureau_republia_novomirsk` | `demander_transfert_detenu` | [L6884](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6884) |
| `palais-ambassades-novomirsk` | `bureau_khalija_novomirsk` | `relations_bilaterales` | [L6894](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6894) |
| `palais-ambassades-novomirsk` | `bureau_khalija_novomirsk` | `organiser_reception_diplomatique` | [L6895](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6895) |
| `palais-ambassades-novomirsk` | `bureau_khalija_novomirsk` | `financer_oeuvre_culturelle` | [L6896](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6896) |
| `palais-ambassades-novomirsk` | `bureau_khalija_novomirsk` | `demander_transfert_detenu` | [L6897](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6897) |
| `palais-ambassades-novomirsk` | `bureau_estado_novomirsk` | `relations_bilaterales` | [L6907](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6907) |
| `palais-ambassades-novomirsk` | `bureau_estado_novomirsk` | `organiser_reception_diplomatique` | [L6908](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6908) |
| `palais-ambassades-novomirsk` | `bureau_estado_novomirsk` | `financer_oeuvre_culturelle` | [L6909](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6909) |
| `palais-ambassades-novomirsk` | `bureau_estado_novomirsk` | `demander_transfert_detenu` | [L6910](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6910) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `ecouter_rumeurs` | [L6954](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6954) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `recruter_informateur_pnj` | [L6955](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6955) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `produire_commerce` | [L6956](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6956) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `consulter_carte_commerce` | [L6957](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6957) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `offrir_tournee` | [L6958](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6958) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `gerer_commerce` | [L6959](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6959) |
| `pavillon-ambassadeurs-novomirsk` | `bar` | `vendre_matiere_commerce` | [L6960](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6960) |
| `pavillon-ambassadeurs-novomirsk` | `suite_privee` | `louer_local` | [L6971](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6971) |
| `pavillon-ambassadeurs-novomirsk` | `suite_privee` | `gerer_local` | [L6972](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6972) |
| `pavillon-ambassadeurs-novomirsk` | `suite_presidentielle` | `louer_local` | [L6983](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6983) |
| `pavillon-ambassadeurs-novomirsk` | `suite_presidentielle` | `gerer_local` | [L6984](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6984) |
| `pavillon-ambassadeurs-novomirsk` | `suite_parti` | `louer_local` | [L6995](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6995) |
| `pavillon-ambassadeurs-novomirsk` | `suite_parti` | `gerer_local` | [L6996](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6996) |
| `residence-imperiale-novomirsk` | `appartement_1` | `louer_local` | [L7029](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7029) |
| `residence-imperiale-novomirsk` | `appartement_1` | `gerer_local` | [L7030](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7030) |
| `residence-imperiale-novomirsk` | `appartement_2` | `louer_local` | [L7041](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7041) |
| `residence-imperiale-novomirsk` | `appartement_2` | `gerer_local` | [L7042](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7042) |
| `residence-imperiale-novomirsk` | `appartement_3` | `louer_local` | [L7053](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7053) |
| `residence-imperiale-novomirsk` | `appartement_3` | `gerer_local` | [L7054](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7054) |
| `residence-imperiale-novomirsk` | `appartement_4` | `louer_local` | [L7065](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7065) |
| `residence-imperiale-novomirsk` | `appartement_4` | `gerer_local` | [L7066](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7066) |
| `residence-imperiale-novomirsk` | `grand_appartement` | `louer_local` | [L7077](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7077) |
| `residence-imperiale-novomirsk` | `grand_appartement` | `gerer_local` | [L7078](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7078) |
| `garage-novomirsk` | `atelier_garage` | `garage_vehicules` | [L7103](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7103) |
| `garage-novomirsk` | `atelier_garage` | `garage_reviser` | [L7104](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7104) |
| `garage-novomirsk` | `atelier_garage` | `mes_vehicules` | [L7105](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7105) |
| `salon-coiffure-novomirsk` | `salon_coiffure` | `salon_coupe` | [L7130](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7130) |
| `logements-novomirsk` | `petit_appartement_1` | `gerer_logement_social` | [L7162](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7162) |
| `logements-novomirsk` | `petit_appartement_2` | `gerer_logement_social` | [L7173](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7173) |
| `logements-novomirsk` | `petit_appartement_3` | `gerer_logement_social` | [L7184](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7184) |
| `logements-novomirsk` | `petit_appartement_4` | `gerer_logement_social` | [L7195](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7195) |
| `logements-novomirsk` | `grand_appartement_1` | `gerer_logement_social` | [L7206](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7206) |
| `logements-novomirsk` | `grand_appartement_2` | `gerer_logement_social` | [L7217](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7217) |
| `logements-novomirsk` | `grand_appartement_3` | `gerer_logement_social` | [L7228](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7228) |
| `logements-novomirsk` | `grand_appartement_4` | `gerer_logement_social` | [L7239](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7239) |
| `pharmacie-officielle-novomirsk` | `comptoir_pharmacie` | `pharmacie_medicaments` | [L7264](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7264) |
| `poissonniere-novomirsk` | `etal_poissonniere` | `poissonniere_poisson` | [L7289](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7289) |
| `poissonniere-novomirsk` | `etal_poissonniere` | `ecouter_rumeurs` | [L7290](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7290) |
| `poissonniere-novomirsk` | `etal_poissonniere` | `lancer_rumeur_cible` | [L7291](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7291) |
| `poissonniere-novomirsk` | `etal_poissonniere` | `contrebande_poissonniere` | [L7292](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7292) |
| `station-service-krasnov` | `boutique_station` | `station_carburant` | [L7311](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7311) |
| `station-service-krasnov` | `boutique_station` | `mes_vehicules` | [L7312](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7312) |
| `entrepot-logistique-novomirsk` | `salle_ventes` | `receptionner_commande` | [L7336](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7336) |
| `entrepot-logistique-novomirsk` | `salle_ventes` | `acheter_ressources_entrepot` | [L7336](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7336) |
| `entrepot-logistique-novomirsk` | `bureau_direction` | `tableau_bord_entrepot` | [L7345](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7345) |
| `entrepot-logistique-novomirsk` | `bureau_direction` | `fixer_prix_achat_entrepot` | [L7346](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7346) |
| `siege-renseignement` | `salle_ecoutes` | `renseignement_militaire` | [L7384](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7384) |
| `siege-renseignement` | `salle_interrogatoire_renseignement` | `interroger_renseignement` | [L7393](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7393) |
| `qhs-prison` | `entree_qhs` | `visiter_prisonnier` | [L7416](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7416) |
| `qhs-prison` | `entree_qhs` | `corrompre_fonct` | [L7417](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7417) |
| `qhs-prison` | `entree_qhs` | `archives_police` | [L7418](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7418) |
| `qhs-prison` | `cellules_qhs` | `greve_faim` | [L7431](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7431) |
| `qhs-prison` | `cellules_qhs` | `corrompre_gardien` | [L7432](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7432) |
| `qhs-prison` | `cellules_qhs` | `tentative_evasion` | [L7433](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7433) |
| `qhs-prison` | `salle_interrogatoire` | `interroger` | [L7443](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7443) |
| `qhs-prison` | `salle_interrogatoire` | `corrompre_fonct` | [L7444](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7444) |
| `qhs-prison` | `promenoir` | `se_reposer` | [L7454](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7454) |
| `tabernacle-impots` | `nef_principale` | `prier` | [L7495](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7495) |
| `tabernacle-impots` | `nef_principale` | `faire_don` | [L7496](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7496) |
| `laboratoire-priere` | `salle_communion` | `prier` | [L7538](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7538) |
| `laboratoire-priere` | `salle_communion` | `se_confesser` | [L7539](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7539) |
| `laboratoire-priere` | `salle_communion` | `faire_don` | [L7540](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7540) |
| `laboratoire-priere` | `salle_communion` | `pelerin` | [L7541](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7541) |
| `kolkhoze-spirituel` | `grange_sainte` | `prier` | [L7565](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7565) |
| `kolkhoze-spirituel` | `grange_sainte` | `se_confesser` | [L7566](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7566) |
| `kolkhoze-spirituel` | `grange_sainte` | `faire_don` | [L7567](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7567) |
| `kolkhoze-spirituel` | `grange_sainte` | `pelerin` | [L7568](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7568) |
| `patisserie-sacree` | `salle_degustation` | `prier` | [L7592](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7592) |
| `patisserie-sacree` | `salle_degustation` | `se_confesser` | [L7593](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7593) |
| `patisserie-sacree` | `salle_degustation` | `faire_don` | [L7594](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7594) |
| `patisserie-sacree` | `salle_degustation` | `pelerin` | [L7595](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7595) |
| `patisserie-sacree` | `salle_degustation` | `acheter_relique` | [L7596](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7596) |
| `entrepot-logistique-montrouge` | `salle_ventes` | `receptionner_commande` | [L7618](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7618) |
| `entrepot-logistique-montrouge` | `salle_ventes` | `acheter_ressources_entrepot` | [L7618](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7618) |
| `entrepot-logistique-montrouge` | `bureau_direction` | `tableau_bord_entrepot` | [L7627](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7627) |
| `entrepot-logistique-montrouge` | `bureau_direction` | `fixer_prix_achat_entrepot` | [L7628](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7628) |
| `entrepot-logistique-krasnov` | `salle_ventes` | `receptionner_commande` | [L7650](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7650) |
| `entrepot-logistique-krasnov` | `salle_ventes` | `acheter_ressources_entrepot` | [L7650](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7650) |
| `entrepot-logistique-krasnov` | `bureau_direction` | `tableau_bord_entrepot` | [L7659](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7659) |
| `entrepot-logistique-krasnov` | `bureau_direction` | `fixer_prix_achat_entrepot` | [L7660](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7660) |
| `raffinerie-montrouge` | `salle_ventes` | `vente_directe_usine` | [L7680](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7680) |
| `raffinerie-montrouge` | `bureau_direction` | `fixer_prix_vente_directe` | [L7689](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7689) |
| `raffinerie-montrouge` | `bureau_direction` | `fixer_repartition_production` | [L7690](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7690) |
| `raffinerie-montrouge` | `bureau_direction` | `virement_usine_ministere` | [L7691](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7691) |
| `raffinerie-montrouge` | `salle_production` | `produire_carburant` | [L7701](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7701) |
| `raffinerie-montrouge` | `salle_production` | `produire_derives_petrochimiques` | [L7702](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7702) |
| `raffinerie-montrouge` | `salle_production` | `vendre_matiere_usine` | [L7705](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7705) |
| `bureau-national-emploi` | `accueil` | `consulter_offres_emploi` | [L7729](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7729) |
| `bureau-national-emploi` | `accueil` | `bne_passer_annonce` | [L7730](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7730) |
| `pole-tabac-alcools-psm` | `salle_ventes` | `vente_directe_usine` | [L7752](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7752) |
| `pole-tabac-alcools-psm` | `bureau_direction` | `fixer_prix_vente_directe` | [L7761](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7761) |
| `pole-tabac-alcools-psm` | `bureau_direction` | `fixer_repartition_production` | [L7762](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7762) |
| `pole-tabac-alcools-psm` | `bureau_direction` | `virement_usine_ministere` | [L7763](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7763) |
| `pole-tabac-alcools-psm` | `distillerie` | `produire_alcool` | [L7773](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7773) |
| `pole-tabac-alcools-psm` | `distillerie` | `vendre_matiere_usine` | [L7776](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7776) |
| `pole-tabac-alcools-psm` | `manufacture_tabac` | `produire_tabac` | [L7786](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7786) |
| `pole-tabac-alcools-psm` | `manufacture_tabac` | `vendre_matiere_usine` | [L7789](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7789) |
| `entrepot-logistique-psm` | `salle_ventes` | `receptionner_commande` | [L7809](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7809) |
| `entrepot-logistique-psm` | `salle_ventes` | `acheter_ressources_entrepot` | [L7809](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7809) |
| `entrepot-logistique-psm` | `bureau_direction` | `tableau_bord_entrepot` | [L7818](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7818) |
| `entrepot-logistique-psm` | `bureau_direction` | `fixer_prix_achat_entrepot` | [L7819](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7819) |
| `entrepot-logistique-luthecia` | `salle_ventes` | `receptionner_commande` | [L7839](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7839) |
| `entrepot-logistique-luthecia` | `salle_ventes` | `acheter_ressources_entrepot` | [L7839](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7839) |
| `entrepot-logistique-luthecia` | `bureau_direction` | `tableau_bord_entrepot` | [L7848](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7848) |
| `entrepot-logistique-luthecia` | `bureau_direction` | `fixer_prix_achat_entrepot` | [L7849](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7849) |
| `usine-pharmaceutique-luthecia` | `salle_ventes` | `vente_directe_usine` | [L7870](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7870) |
| `usine-pharmaceutique-luthecia` | `salle_ventes` | `acheter_sels_ammoniaque` | [L7876](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7876) |
| `usine-pharmaceutique-luthecia` | `bureau_direction` | `fixer_prix_vente_directe` | [L7886](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7886) |
| `usine-pharmaceutique-luthecia` | `bureau_direction` | `fixer_repartition_production` | [L7887](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7887) |
| `usine-pharmaceutique-luthecia` | `bureau_direction` | `virement_usine_ministere` | [L7888](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7888) |
| `usine-pharmaceutique-luthecia` | `salle_production` | `produire_medicaments` | [L7898](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7898) |
| `usine-pharmaceutique-luthecia` | `salle_production` | `produire_desinfectant` | [L7899](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7899) |
| `usine-pharmaceutique-luthecia` | `salle_production` | `vendre_matiere_usine` | [L7900](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7900) |
| `centre-multinodal-luthecia` | `hall_gare` | `prendre_train` | [L7924](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7924) |
| `centre-multinodal-luthecia` | `hall_gare` | `prendre_bus_taxi` | [L7925](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7925) |
| `centre-multinodal-luthecia` | `hall_gare` | `aller_douanes_aeroport` | [L7926](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7926) |
| `centre-multinodal-luthecia` | `hall_gare` | `taxi_caserne` | [L7927](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7927) |
| `centre-multinodal-luthecia` | `hall_gare` | `taxi_qhs` | [L7928](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7928) |
| `centre-multinodal-luthecia` | `hall_douanes` | `passer_douanes_aeroport` | [L7940](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7940) |
| `centre-multinodal-luthecia` | `hall_douanes` | `corrompre_douanier` | [L7941](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7941) |
| `centre-multinodal-luthecia` | `zone_embarquement` | `prendre_avion` | [L7953](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7953) |
| `centre-multinodal-port-sainte-marie` | `hall_gare_psm` | `prendre_train` | [L7976](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7976) |
| `centre-multinodal-port-sainte-marie` | `hall_gare_psm` | `prendre_bus_taxi` | [L7977](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7977) |
| `centre-multinodal-montrouge` | `hall_gare_montrouge` | `prendre_train` | [L8001](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8001) |
| `centre-multinodal-montrouge` | `hall_gare_montrouge` | `prendre_bus_taxi` | [L8002](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8002) |
| `cafe-gare-montrouge` | `salle` | `produire_commerce` | [L8019](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8019) |
| `cafe-gare-montrouge` | `salle` | `consulter_carte_commerce` | [L8020](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8020) |
| `cafe-gare-montrouge` | `salle` | `offrir_tournee` | [L8025](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8025) |
| `cafe-gare-montrouge` | `salle` | `gerer_commerce` | [L8026](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8026) |
| `cafe-gare-montrouge` | `salle` | `vendre_matiere_commerce` | [L8027](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8027) |
| `cafe-gare-montrouge` | `salle` | `lancer_rumeur_cible` | [L8030](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8030) |
| `brasserie-voyageurs-montrouge` | `salle` | `produire_commerce` | [L8041](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8041) |
| `brasserie-voyageurs-montrouge` | `salle` | `consulter_carte_commerce` | [L8042](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8042) |
| `brasserie-voyageurs-montrouge` | `salle` | `gerer_commerce` | [L8043](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8043) |
| `brasserie-voyageurs-montrouge` | `salle` | `vendre_matiere_commerce` | [L8044](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8044) |
| `brasserie-voyageurs-montrouge` | `salle` | `lancer_rumeur_cible` | [L8047](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8047) |
| `musee-histoire-montrouge` | `salle_terre` | `consulter_personnalites_musee` | [L8067](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8067) |
| `musee-histoire-montrouge` | `salle_industrie` | `consulter_personnalites_musee` | [L8068](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8068) |
| `musee-histoire-montrouge` | `salle_rail` | `consulter_personnalites_musee` | [L8069](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8069) |
| `musee-histoire-montrouge` | `salle_ville` | `consulter_personnalites_musee` | [L8070](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8070) |
| `musee-histoire-montrouge` | `salle_luttes` | `consulter_personnalites_musee` | [L8071](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8071) |
| `musee-histoire-montrouge` | `salle_loisirs` | `consulter_personnalites_musee` | [L8072](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8072) |
| `eglise-montrouge` | `salle` | `prier` | [L8091](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8091) |
| `eglise-montrouge` | `salle` | `faire_don` | [L8092](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8092) |
| `place-du-rail-montrouge` | `place` | `organiser_manifestation_spontanee` | [L8105](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8105) |
| `jardins-ouvriers-montrouge` | `salle` | `travailler_jardins` | [L8136](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8136) |
| `jardins-ouvriers-montrouge` | `salle` | `laisser_legumes_jardins` | [L8137](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8137) |
| `jardins-ouvriers-montrouge` | `salle` | `prendre_legumes_jardins` | [L8138](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8138) |
| `logements-montrouge` | `petit_appartement_1` | `gerer_logement_social` | [L8180](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8180) |
| `logements-montrouge` | `petit_appartement_2` | `gerer_logement_social` | [L8192](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8192) |
| `logements-montrouge` | `grand_appartement_1` | `gerer_logement_social` | [L8204](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8204) |
| `logements-montrouge` | `grand_appartement_2` | `gerer_logement_social` | [L8216](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8216) |
| `cafe-tabac-cheminots-montrouge` | `salle` | `produire_commerce` | [L8237](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8237) |
| `cafe-tabac-cheminots-montrouge` | `salle` | `consulter_carte_commerce` | [L8238](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8238) |
| `cafe-tabac-cheminots-montrouge` | `salle` | `offrir_tournee` | [L8241](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8241) |
| `cafe-tabac-cheminots-montrouge` | `salle` | `gerer_commerce` | [L8242](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8242) |
| `cafe-tabac-cheminots-montrouge` | `salle` | `vendre_matiere_commerce` | [L8243](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8243) |
| `cafe-tabac-cheminots-montrouge` | `salle` | `lancer_rumeur_cible` | [L8244](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8244) |
| `port-sainte-marie` | `quai_principal` | `prendre_bateau` | [L8283](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8283) |
| `port-sainte-marie` | `quai_principal` | `inspecter_cargaisons` | [L8284](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8284) |
| `port-sainte-marie` | `criee` | `acheter_criee` | [L8294](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8294) |
| `port-sainte-marie` | `entrepot` | `marchandises_non_reclamees` | [L8314](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8314) |
| `port-sainte-marie` | `entrepot` | `expedier_colis` | [L8321](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8321) |
| `port-sainte-marie` | `entrepot` | `receptionner_commande` | [L8322](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8322) |
| `port-sainte-marie` | `box_a_louer` | `louer_box` | [L8347](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8347) |
| `port-sainte-marie` | `box_a_louer` | `gerer_box` | [L8348](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8348) |
| `port-sainte-marie` | `douanes` | `consulter_effectifs_douane` | [L8369](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8369) |
| `port-sainte-marie` | `douanes` | `recruter_douanier` | [L8370](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8370) |
| `port-sainte-marie` | `douanes` | `recruter_douanier_cynophile` | [L8371](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8371) |
| `port-sainte-marie` | `douanes` | `gerer_effectifs_douane` | [L8372](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8372) |
| `port-sainte-marie` | `douanes` | `controler_caisse_douane` | [L8373](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8373) |
| `port-sainte-marie` | `bureau_syndical_dockers` | `se_syndiquer` | [L8397](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8397) |
| `port-sainte-marie` | `bureau_syndical_dockers` | `consulter_organigramme_syndicat` | [L8398](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8398) |
| `port-sainte-marie` | `bureau_syndical_dockers` | `declencher_election_syndicat` | [L8399](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8399) |
| `port-sainte-marie` | `bureau_syndical_dockers` | `organiser_manifestation_syndicat` | [L8400](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8400) |
| `port-sainte-marie` | `bureau_syndical_dockers` | `blocus_portuaire` | [L8401](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8401) |
| `port-sainte-marie` | `administration_portuaire` | `consulter_manifeste` | [L8414](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8414) |
| `port-sainte-marie` | `administration_portuaire` | `consulter_administration_port` | [L8415](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8415) |
| `port-sainte-marie` | `administration_portuaire` | `gerer_logistique_port` | [L8416](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8416) |
| `port-novomirsk` | `quai_sovarka` | `prendre_bateau` | [L8440](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8440) |
| `port-novomirsk` | `quai_sovarka` | `expedier_colis` | [L8441](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8441) |
| `port-novomirsk` | `quai_sovarka` | `receptionner_commande` | [L8442](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8442) |
| `port-novomirsk` | `quai_sovarka` | `contrebande_port` | [L8443](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8443) |
| `port-novomirsk` | `quai_sovarka` | `acheter_polonium` | [L8444](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8444) |
| `port-novomirsk` | `quai_sovarka` | `inspecter_cargaisons` | [L8445](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8445) |
| `port-ciudad-roja` | `quai_el_estado` | `prendre_bateau` | [L8469](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8469) |
| `port-ciudad-roja` | `quai_el_estado` | `expedier_colis` | [L8470](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8470) |
| `port-ciudad-roja` | `quai_el_estado` | `receptionner_commande` | [L8471](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8471) |
| `port-ciudad-roja` | `quai_el_estado` | `contrebande_port` | [L8472](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8472) |
| `port-ciudad-roja` | `quai_el_estado` | `acheter_ghb` | [L8473](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8473) |
| `port-ciudad-roja` | `quai_el_estado` | `blocus_portuaire` | [L8474](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8474) |
| `port-al-madina` | `quai_al_khalija` | `prendre_bateau` | [L8498](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8498) |
| `port-al-madina` | `quai_al_khalija` | `expedier_colis` | [L8499](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8499) |
| `port-al-madina` | `quai_al_khalija` | `receptionner_commande` | [L8500](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8500) |
| `port-al-madina` | `quai_al_khalija` | `contrebande_port` | [L8501](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8501) |
| `port-al-madina` | `quai_al_khalija` | `acheter_vipere` | [L8502](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8502) |
| `port-al-madina` | `quai_al_khalija` | `inspecter_cargaisons` | [L8503](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8503) |
| `entrepot-logistique-starovka` | `salle_ventes` | `receptionner_commande` | [L7336](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7336) |
| `entrepot-logistique-starovka` | `salle_ventes` | `acheter_ressources_entrepot` | [L7336](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7336) |
| `entrepot-logistique-starovka` | `bureau_direction` | `tableau_bord_entrepot` | [L7345](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7345) |
| `entrepot-logistique-starovka` | `bureau_direction` | `fixer_prix_achat_entrepot` | [L7346](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7346) |
| `port-starovka` | `entrepot` | `marchandises_non_reclamees` | [L8314](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8314) |
| `port-starovka` | `entrepot` | `expedier_colis` | [L8321](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8321) |
| `port-starovka` | `entrepot` | `receptionner_commande` | [L8322](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8322) |
| `locaux-starovka` | `local_1` | `sovarka_demande_location` | [L10592](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10592) |
| `locaux-starovka` | `local_1` | `commerce_pj` | [L10840](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10840) |
| `locaux-starovka` | `local_2` | `sovarka_demande_location` | [L10966](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10966) |
| `locaux-starovka` | `local_2` | `commerce_pj` | [L10968](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10968) |
| `poste-vigilance-glaciale` | `salle_ecoute` | `voler_archives_ecoute` | [L10878](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10878) |
| `station-radar-krasnov` | `salle_ecoute` | `voler_archives_ecoute` | [L10878](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10878) |
| `maison-starovka` | `piece_maison` | `maison_habitant` | [L10905](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10905) |
| `maison-starovka` | `piece_maison` | `trinquer_habitant` | [L10907](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10907) |
| `maison-starovka` | `piece_maison` | `dormir_chambre` | [L10909](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10909) |
| `maison-krasnov` | `piece_maison` | `maison_habitant` | [L10905](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10905) |
| `maison-krasnov` | `piece_maison` | `trinquer_habitant` | [L10907](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10907) |
| `maison-krasnov` | `piece_maison` | `dormir_chambre` | [L10909](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10909) |
| `ferme-starovka` | `cour_ferme` | `ferme_renne` | ordre construit (bâtiment [L2786](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786)) |
| `ferme-starovka` | `cour_ferme` | `ferme_traire` | ordre construit (bâtiment [L2786](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786)) |
| `ferme-krasnov` | `cour_ferme` | `ferme_legumes` | ordre construit (bâtiment [L2786](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786)) |
| `ferme-krasnov` | `cour_ferme` | `ferme_oeufs` | ordre construit (bâtiment [L2786](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786)) |
| `ferme-krasnov` | `cour_ferme` | `ferme_poulet` | ordre construit (bâtiment [L2786](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786)) |
| `ferme-krasnov` | `cour_ferme` | `ferme_lapin` | ordre construit (bâtiment [L2786](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786)) |
| `distillerie-krasnov` | `atelier_distillerie` | `sovarka_demande_location` | [L10592](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10592) |
| `distillerie-krasnov` | `atelier_distillerie` | `commerce_pj` | [L10840](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10840) |
| `fourreur-starovka` | `boutique_fourreur` | `sovarka_demande_location` | [L10592](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10592) |
| `fourreur-starovka` | `boutique_fourreur` | `commerce_pj` | [L10840](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L10840) |

## Répertoire des bâtiments

Un bâtiment ou une pièce sans ordre dans `data.js` peut être purement social, visuel ou géré dans un autre module. Ils ne sont **pas** automatiquement des bâtiments inachevés. Bâtiments sans aucun ordre déclaré : **7**.

- [`hotel-republica`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2788) : 6 pièces, 23 références d'ordres
- [`palais-presidentiel`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2900) : 4 pièces, 12 références d'ordres
- [`palais-gouvernement`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2994) : 11 pièces, 38 références d'ordres
- [`assemblee`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3357) : 4 pièces, 12 références d'ordres
- [`office-notarial`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3472) : 4 pièces, 11 références d'ordres
- [`stade`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3544) : 6 pièces, 28 références d'ordres
- [`zone-production`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3648) : 1 pièce, 1 référence d'ordres
- [`tribunal`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3669) : 3 pièces, 19 références d'ordres
- [`banque-nationale`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3773) : 2 pièces, 6 références d'ordres
- [`banque-privee`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3815) : 1 pièce, 5 références d'ordres
- [`clinique-privee`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3844) : 11 pièces, 73 références d'ordres
- [`dispensaire-public`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L3972) : 2 pièces, 6 références d'ordres
- [`commissariat`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4015) : 3 pièces, 15 références d'ordres
- [`la-tribune`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4081) : 2 pièces, 11 références d'ordres
- [`loge-maconnique`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4146) : 4 pièces, 6 références d'ordres
- [`universite`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4215) : 2 pièces, 6 références d'ordres
- [`armurerie`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4285) : 1 pièce, 5 références d'ordres
- [`marche`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4329) : 1 pièce, 3 références d'ordres
- [`mairie-capitale`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4360) : 5 pièces, 23 références d'ordres
- [`musee-port-sainte-marie`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4468) : 10 pièces, 8 références d'ordres
- [`musee-novomirsk`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4603) : 10 pièces, 8 références d'ordres
- [`centre-commercial`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4708) : 5 pièces, 13 références d'ordres
- [`centre-artisanal`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4789) : 4 pièces, 10 références d'ordres
- [`centre-affaires`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4861) : 5 pièces, 12 références d'ordres
- [`terrain-a-batir-4`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4950) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-5`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4957) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-6`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4963) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-7`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4969) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-montrouge-3`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4985) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-montrouge-7`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4991) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-montrouge-8`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L4997) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-montrouge-9`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5003) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-montrouge-12`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5009) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-1`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5015) : 1 pièce, 20 références d'ordres
- [`mairie`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5047) : 3 pièces, 15 références d'ordres
- [`hotel-port`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5118) : 2 pièces, 7 références d'ordres
- [`bar-des-pecheurs`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5164) : 1 pièce, 8 références d'ordres
- [`services-sociaux-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5229) : 2 pièces, 3 références d'ordres
- [`parking-tribunal-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5257) : 1 pièce, 0 référence d'ordres
- [`siege-syndical`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5273) : 1 pièce, 1 référence d'ordres
- [`usine-principale`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5295) : 1 pièce, 1 référence d'ordres
- [`hotel-mineur`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5317) : 2 pièces, 7 références d'ordres
- [`banque-locale`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5365) : 1 pièce, 3 références d'ordres
- [`dispensaire-public-v`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5393) : 2 pièces, 6 références d'ordres
- [`commissariat-local`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5432) : 3 pièces, 15 références d'ordres
- [`tribunal-local`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5515) : 3 pièces, 18 références d'ordres
- [`imprimerie-librairie`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5596) : 2 pièces, 3 références d'ordres
- [`marche-psm`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5650) : 1 pièce, 5 références d'ordres
- [`capitaine-sauvage`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5696) : 1 pièce, 7 références d'ordres
- [`chasse-peche-psm`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5736) : 1 pièce, 6 références d'ordres
- [`place-armes-psm`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5788) : 1 pièce, 1 référence d'ordres
- [`ecole-marine`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5817) : 2 pièces, 0 référence d'ordres
- [`chantier-naval`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5845) : 2 pièces, 2 références d'ordres
- [`notre-dame-mer`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5877) : 3 pièces, 2 références d'ordres
- [`phare-psm`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5931) : 1 pièce, 0 référence d'ordres
- [`port-plaisance-psm`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5956) : 2 pièces, 0 référence d'ordres
- [`terrain-a-batir-8`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L5985) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-9`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6008) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-10`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6031) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-11`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6054) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-psm-12`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6080) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-psm-13`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6103) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-2`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6126) : 1 pièce, 20 références d'ordres
- [`terrain-a-batir-3`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6149) : 1 pièce, 20 références d'ordres
- [`caserne-militaire`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6174) : 7 pièces, 33 références d'ordres
- [`musee-ville-luthecia`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6459) : 12 pièces, 0 référence d'ordres
- [`musee-national-republia`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6579) : 12 pièces, 7 références d'ordres
- [`parc-botanique-national`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6709) : 2 pièces, 0 référence d'ordres
- [`place-formulaire-liberte`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6740) : 1 pièce, 1 référence d'ordres
- [`quartier-ambassades`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6767) : 5 pièces, 15 références d'ordres
- [`palais-ambassades-novomirsk`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6843) : 5 pièces, 15 références d'ordres
- [`pavillon-ambassadeurs-novomirsk`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L6921) : 6 pièces, 13 références d'ordres
- [`residence-imperiale-novomirsk`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7003) : 6 pièces, 10 références d'ordres
- [`garage-novomirsk`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7087) : 1 pièce, 3 références d'ordres
- [`salon-coiffure-novomirsk`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7114) : 1 pièce, 1 référence d'ordres
- [`logements-novomirsk`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7138) : 9 pièces, 8 références d'ordres
- [`pharmacie-officielle-novomirsk`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7248) : 1 pièce, 1 référence d'ordres
- [`poissonniere-novomirsk`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7273) : 1 pièce, 4 références d'ordres
- [`station-service-krasnov`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7296) : 1 pièce, 2 références d'ordres
- [`entrepot-logistique-novomirsk`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7321) : 2 pièces, 4 références d'ordres
- [`siege-renseignement`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7360) : 3 pièces, 2 références d'ordres
- [`qhs-prison`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7397) : 5 pièces, 9 références d'ordres
- [`tabernacle-impots`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7469) : 2 pièces, 2 références d'ordres
- [`laboratoire-priere`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7518) : 1 pièce, 4 références d'ordres
- [`kolkhoze-spirituel`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7545) : 1 pièce, 4 références d'ordres
- [`patisserie-sacree`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7572) : 1 pièce, 5 références d'ordres
- [`entrepot-logistique-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7602) : 2 pièces, 4 références d'ordres
- [`entrepot-logistique-krasnov`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7635) : 2 pièces, 4 références d'ordres
- [`raffinerie-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7664) : 3 pièces, 7 références d'ordres
- [`bureau-national-emploi`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7709) : 1 pièce, 2 références d'ordres
- [`pole-tabac-alcools-psm`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7736) : 4 pièces, 8 références d'ordres
- [`entrepot-logistique-psm`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7793) : 2 pièces, 4 références d'ordres
- [`entrepot-logistique-luthecia`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7823) : 2 pièces, 4 références d'ordres
- [`usine-pharmaceutique-luthecia`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7853) : 3 pièces, 8 références d'ordres
- [`centre-multinodal-luthecia`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7904) : 3 pièces, 8 références d'ordres
- [`centre-multinodal-port-sainte-marie`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7957) : 1 pièce, 2 références d'ordres
- [`centre-multinodal-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L7981) : 1 pièce, 2 références d'ordres
- [`cafe-gare-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8010) : 1 pièce, 6 références d'ordres
- [`brasserie-voyageurs-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8032) : 1 pièce, 5 références d'ordres
- [`musee-histoire-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8055) : 7 pièces, 6 références d'ordres
- [`eglise-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8074) : 1 pièce, 2 références d'ordres
- [`place-du-rail-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8097) : 1 pièce, 1 référence d'ordres
- [`cinema-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8110) : 3 pièces, 0 référence d'ordres
- [`jardins-ouvriers-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8123) : 1 pièce, 3 références d'ordres
- [`logements-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8140) : 5 pièces, 4 références d'ordres
- [`cafe-tabac-cheminots-montrouge`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8220) : 1 pièce, 6 références d'ordres
- [`port-sainte-marie`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8248) : 7 pièces, 21 références d'ordres
- [`port-novomirsk`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8420) : 1 pièce, 6 références d'ordres
- [`port-ciudad-roja`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8449) : 1 pièce, 6 références d'ordres
- [`port-al-madina`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L8478) : 1 pièce, 6 références d'ordres
- [`entrepot-logistique-starovka`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786) : 2 pièces, 4 références d'ordres
- [`port-starovka`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786) : 3 pièces, 3 références d'ordres
- [`locaux-starovka`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786) : 2 pièces, 4 références d'ordres
- [`poste-vigilance-glaciale`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786) : 1 pièce, 1 référence d'ordres
- [`station-radar-krasnov`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786) : 1 pièce, 1 référence d'ordres
- [`maison-starovka`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786) : 1 pièce, 3 références d'ordres
- [`maison-krasnov`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786) : 1 pièce, 3 références d'ordres
- [`ferme-starovka`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786) : 1 pièce, 2 références d'ordres
- [`ferme-krasnov`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786) : 1 pièce, 4 références d'ordres
- [`distillerie-krasnov`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786) : 1 pièce, 2 références d'ordres
- [`fourreur-starovka`](https://github.com/FredJ74/res-publica/blob/50e3c11857e27b3b24666145820ba09a5f558b46/data.js#L2786) : 1 pièce, 2 références d'ordres

## Limites du découpage automatique

- La structure vient de l'évaluation de `data.js` ; les numéros de ligne viennent d'une recherche séquentielle dans le bloc du bâtiment. Un ordre repris d'une constante commune pointe sa « déclaration partagée » ; sans aucun littéral `fn:` dans le fichier, il est signalé « ordre construit ».
- L'extraction ne vérifie ni les villes associées à chaque bâtiment, ni les filtres d'apparition, ni les extensions injectées par `plateau-*.js` après la déclaration.
- Pour l'audit de la géographie, rapprocher ces identifiants de `WORLD`, `VILLES`, `plateau-navigation.js` et des positions/réseaux en base ; une présence dans `BUILDINGS` n'implique pas une entrée accessible à pied.
- Les liens pointent le **SHA figé de l'extraction**, non la version future de `main`.
