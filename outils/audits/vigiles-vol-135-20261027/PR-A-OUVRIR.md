Préparation #135 : affectations de vrais employés PNJ sur les chantiers, vol traité par `chantier_commande` et ses reçus existants, et calculs de détection partagés avec le détecteur policier par patchs exacts. Aucun recrutement, inventaire, payeur ou moteur de combat parallèle.

**BROUILLON — NE PAS FUSIONNER OU DÉPLOYER EN L'ÉTAT.** La remise en police après neutralisation reste à préciser et à raccorder. Le stockage persistant du bonus de bénédiction utilisé par le vol n'est pas identifié dans le schéma archivé : le prévol refuse cette absence, les tests signalent explicitement leur hypothèse. Les définitions de sécurité retrouvées dans Git ne sont pas une photographie vivante.

Validation isolée : 118 tests du pilote, 105 bancs clients, 81 assertions supplémentaires sécurité/vol (plus les 62 historiques), 354 assertions intégrées aux cinq terrains, et six mutants métier détectés. Grilles exactes : 720 cas du vol, 112 du détecteur, 16 de perception. Capacité d'inventaire, piles historiques et métadonnées, réponse perdue, ancien onglet, panne après stock et panne au reçu sont couverts.

Les contre-épreuves historiques restent rouges sur deux ancrages préexistants hors immobilier (89/91, contre 84/91 sur main). Les contrôles globaux restent à 4/12. Authority ajoute les deux RPC préparées absentes du baseline ; Referential signale aussi le nouvel ordre gratuit. Aucune empreinte ou référence n'est retouchée pour masquer ces attentes de déploiement.

Aucune donnée réelle, aucun compte ou secret modifié ; aucune migration appliquée, aucun test authentifié nouveau. Sources métier de Claude conservées ; #195 intégré. Ne ferme pas #135.
