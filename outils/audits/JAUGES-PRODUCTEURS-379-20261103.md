# POP/INF — producteurs restant à examiner, PR #379

Main intégré : `3674d3c2`. Analyse AST des scripts réellement chargés, sans accès
à Supabase. Les appels statiques prouvent un chemin potentiel, pas sa réussite.
Leur absence ne prouve pas qu’un gestionnaire global est inexécutable.

Les commandes déjà portées couvrent débats, archives, inspection, grève de la
faim, forum, objectifs secrets, organisations, buvette, rumeurs et campagne de
sécurité municipale. Les copies de jauges du kompromat et du piège escort ont
été corrigées. Aucun profil PNJ ni arbitrage de Claude n’a été modifié.

**Le verrou des sauvegardes POP/INF n’est pas livré : la contre-épreuve ancien
cache reproduit encore 15→20. Cette liste ne permet aucune exemption Authority.**
Les écritures calculées signalées par l’analyseur exigent également une revue.
Les producteurs ci-dessous ne sont pas tous des gains : chargements, copies,
code historique et actions actives doivent être distingués avant fermeture.

| Fonction | Source | Preuve d’appel | État |
|---|---|---|---|
| `applyCharToState` | `plateau-core.js:1806` | loadCharacter (plateau-core.js:1221) ; loadCharacter (plateau-core.js:1432) | Chargement de fiche ; distinguer adoption d’un gain. |
| `doInspecterCargaisons` | `plateau-navigation.js:2826` | doOrder (plateau-router.js:453) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `envoyerInvitationSociale` | `plateau-pnj.js:2759` | ouvrirModalInvitationSociale (plateau-pnj.js:2730) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `verifierReponseInvitationSociale` | `plateau-pnj.js:2832` | Aucun appel entrant statique retrouvé ; ne prouve pas l’inexécutabilité. | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `repondreInvitationSociale` | `plateau-pnj.js:2935` | verifierInvitationsSocialesRecues (plateau-pnj.js:2928) ; verifierInvitationsSocialesRecues (plateau-pnj.js:2929) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `interagirPnjTerrain` | `plateau-pnj.js:3411` | Aucun appel entrant statique retrouvé ; ne prouve pas l’inexécutabilité. | Ancien parcours sans appel entrant retrouvé ; hors chantiers immobiliers de Claude. |
| `payerEscorts` | `plateau-multijoueur.js:923` | doDormir (plateau-personnage.js:2427) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `publierDecret` | `plateau-politique.js:4712` | signerDecretInutile (plateau-politique.js:4703) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `publierMessagePresidentiel` | `plateau-politique.js:5086` | ouvrirForumNationalSousForumPresident (plateau-politique.js:5076) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `confirmerEtatUrgence` | `plateau-politique.js:7031` | doEtatUrgence (plateau-politique.js:7023) ; doEtatUrgence (plateau-politique.js:7025) | Coordination Claude : commande serveur de ce domaine en chantier sur main. Ne pas dupliquer ; raccorder les gains au contrat final. |
| `confirmerGrace` | `plateau-politique.js:7484` | ouvrirModalGracier (plateau-politique.js:7475) ; ouvrirModalGracier (plateau-politique.js:7476) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `executerOrdreTexte` | `plateau-politique.js:8477` | ouvrirModalTexteLibre (plateau-politique.js:8315) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `appliquerAllegement` | `plateau-politique.js:8528` | ouvrirModalSecteur (plateau-politique.js:8521) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `censurer` | `plateau-politique.js:9095` | ouvrirModalMedia (plateau-politique.js:9088) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `confirmerBanquetDiplomatique` | `plateau-politique.js:9771` | ouvrirBanquetDiplomatique (plateau-politique.js:9765) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `doReceptionAvecBonus` | `plateau-politique.js:9812` | doOrder (plateau-router.js:825) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `confirmerMobilisationPolice` | `plateau-politique.js:9906` | doMobiliserPolice (plateau-politique.js:9897) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `traiterDemandeManifestation` | `plateau-politique.js:10041` | doTraiterManifestations (plateau-politique.js:10030) ; doTraiterManifestations (plateau-politique.js:10031) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `confirmerGuerreEmpire` | `plateau-politique.js:10864` | ouvrirModalGuerreEmpire (plateau-politique.js:10856) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `confirmerDonArgent` | `plateau-justice-economie.js:47` | doDonnerArgentPnj (plateau-justice-economie.js:42) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `appliquerBonusLocation` | `plateau-justice-economie.js:3617` | payerLocations (plateau-justice-economie.js:3600) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `confirmerDonPnj` | `plateau-justice-economie.js:3911` | ouvrirDonPnjModal (plateau-justice-economie.js:3858) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `confirmerDonObjetPnj` | `plateau-justice-economie.js:4025` | ouvrirDonObjetPnjModal (plateau-justice-economie.js:4016) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `confirmerCorruptionRegistre` | `plateau-actions-illegales-rumeurs.js:1464` | ouvrirModalCorruptionRegistre (plateau-actions-illegales-rumeurs.js:1458) | Coordination Claude : commande serveur de ce domaine en chantier sur main. Ne pas dupliquer ; raccorder les gains au contrat final. |
| `commanderProduitCommerce` | `plateau-actions-illegales-rumeurs.js:4460` | doCommanderProduitCommerceUI (plateau-actions-illegales-rumeurs.js:4605) ; doCommanderAchatCommerceUI (plateau-actions-illegales-rumeurs.js:4744) ; confirmerConsommerBoissonUI (plateau-actions-illegales-rumeurs.js:4865) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `commanderSondage` | `plateau-divers.js:69` | Aucun appel entrant statique retrouvé ; ne prouve pas l’inexécutabilité. | Ancien parcours sans appel entrant retrouvé ; ne pas confondre avec commanditer_sondage. |
| `appliquerMalusPopExcommunication` | `plateau-divers.js:478` | appliquerExcommunication (plateau-divers.js:504) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `doFaireDon` | `plateau-divers.js:599` | doOrder (plateau-router.js:566) | Raccordement serveur complet à vérifier/terminer ; pas autorisé à fermer la sauvegarde à cette étape. |
| `doBenedictionEtat` | `plateau-divers.js:772` | doOrder (plateau-router.js:570) | Ordre retiré du catalogue ; ne pas le réactiver. |
| `doConsulterConfessions` | `plateau-divers.js:782` | doOrder (plateau-router.js:571) | Ordre retiré du catalogue ; ne pas le réactiver. |
