# PR #379 — état actualisé des producteurs POP/INF
> Révision de travail sur branche #410 (ciblant #379). **Non certifié en production.**

## Preuves exécutées

- **Ancienne fusion en production** : MD5 `248b3f7f5e8c24148afa624649ee3f47`, prévol Supabase lecture seule. La migration de protection n'est pas appliquée.
- Première protection `20261103183000` : 18/18 tests PGlite (vieux cache et répétitions), mais un client avec `popBase=10,pop=99` et `infBase=10,inf=99` passe toujours ; **interdit de présenter ce lot comme une fermeture complète**.
- Fermeture stricte : `outils/livraison/preparatifs-379/fermeture-pop-inf-serveur-seul.sql.prepa` volontairement **hors dossier migrations**. Rejouer `node --test outils/bancs/banc-pop-inf-forge-379.cjs` ; 3/3 preuves en environnement isolé (contre-preuve première protection puis refus par la stricte). Ne livrer qu'après migration de tous les producteurs actifs.
- Grâce présidentielle : `20261103133000`, 15/15 SQL isolés, 5/5 côté client ; réparation de l'ancien circuit PA/QHS/POP. Ce lot n'est pas une certification de production.
- Inspection portuaire : `20261103203000`, 14/14 PGlite et contrôles client ; bonus INF +5 ou malus -3 décidé par serveur, 2 PA, rôle min_def, présence au quai, reçu anti-rejeu.
- Sondage historique et allègement fiscal inatteignables : supprimés de la branche, 2/2 tests ciblés. L'ordre officiel `commanditer_sondage` transactionnel et le message « allegement fiscal indisponible » sont conservés.

## Reprise Claude (03/11 au soir)

- Main #404–#418 fusionné dans la branche (conflits : main fait foi). La subtilisation suit le corps serveur de #409 ; l'ancienne migration `20261102202046` est retirée.
- Lot présidence `20261103230000` et lot 2 `20261103233000` : banc annulé `outils/bancs/banc-pop-inf-presidence-379.sql` sur base jetable (17/17) ; garde écran `outils/bancs/test-pop-inf-producteurs-379.mjs`.
- Lot 3 restant : invitations sociales (3), dons aux PNJ (argent, objets, promoteur), bonus de location du chef d'organisation, impayé d'escort.

## Producteurs de l'inventaire d'origine : état des travaux

| Producteur | État sur la branche #410 | Action restante |
|---|---|---|
| `applyCharToState` | Chargement de fiche, pas un producteur de gain | Contrôler l'adoption au retour de commande |
| `doInspecterCargaisons` | **Raccordé**, RPC reçue atomiquement | Certification PG natif et cohérence avec groupes/effects |
| `envoyerInvitationSociale` | Gain INF encore local | **Lot 3** : porter contrat, PA et invitation au serveur |
| `verifierReponseInvitationSociale` | Gain INF encore local | Contrat reçu et anti-rejeu |
| `repondreInvitationSociale` | Gain INF encore local | Contrat reçu et anti-rejeu |
| `interagirPnjTerrain` | **Supprimée** (Claude, lot 2) : aucun appel | Aucun |
| `payerEscorts` | Malus POP local de non-paiement (paiement lui-même encore local) | **Lot 3** : coupler au paiement/renvoi serveur |
| `publierDecret` | **Raccordé** (lot présidence) : `decret_inutile`, aléa serveur | Aucun |
| `publierMessagePresidentiel` | **Raccordé** : tribunes dans `communication_officielle_publier`, référendum/deuil par `message_presidentiel` | « annonce » sans menu : aucun gain |
| `confirmerEtatUrgence` | Remplacé par main #405 (serveur) à la fusion | Aucun |
| `confirmerGrace` | **Raccordée** dans #410 | Prévol PG natif, contrôle compatibilité clients anciens |
| `executerOrdreTexte` | Branches interdire/réprimer **supprimées** (aucun ordre ne les ouvrait) | Aucun |
| `appliquerAllegement` | **Supprimée** ; route orpheline retirée | Aucun ordre à réactiver sans arbitrage |
| `censurer` | **Raccordé** : `censurer_media` (jet 30 %, -20 POP) | IS national encore affiché localement (hors POP/INF) |
| `confirmerBanquetDiplomatique` | **Raccordé** : jauges dans `indice_diplomatique_ordre` | Aucun |
| `doReceptionAvecBonus` | **Raccordé** : jauges dans `indice_diplomatique_ordre` | Aucun |
| `confirmerMobilisationPolice` | **Raccordé** : `mobiliser_police` (commissaire) | ISN national encore local (hors POP/INF) |
| `traiterDemandeManifestation` | **Raccordé** (lot 2) : `manifestation_traiter`, statut sous verrou | DIS -5 encore locale (hors POP/INF) |
| `confirmerGuerreEmpire` | **Raccordé** : jauges dans `guerre_declarer` | Aucun |
| `confirmerDonArgent` | INF locale (promoteur) | **Lot 3** (dons aux PNJ) |
| `appliquerBonusLocation` | POP/INF locales au réveil | **Lot 3** : coupler aux loyers encaissés |
| `confirmerDonPnj` | POP/INF locales selon PNJ (argent aussi local) | **Lot 3** |
| `confirmerDonObjetPnj` | POP/INF locales selon objet | **Lot 3** |
| `confirmerCorruptionRegistre` | **Raccordé** (lot 2) : `corrompre_armurier` | Aucun |
| `commanderProduitCommerce` | Ligne POP **supprimée** : aucune recette ne porte d'effet POP | Aucun |
| `commanderSondage` | **Supprimée**, aucun appel d'ordre ni UI | Aucun ; le vrai sondage reste `commanditer_sondage` |
| `appliquerMalusPopExcommunication` | **Raccordé** : soi-même par `personnage_ajuster_pop_inf` (cause vérifiée) | Aucun |
| `doFaireDon` | République déjà serveur | Autres empires (non ouverts) : à porter avec eux |
| `doBenedictionEtat` | **Supprimée** avec l'ancien ordre religieux | Aucun |
| `doConsulterConfessions` | **Supprimée** avec l'ancien ordre religieux | Aucun |

## Garde de livraison

Ne pas fusionner #379 ou #410, ni appliquer la **fermeture stricte**, avant :
1. Rebase réel sur `main`, sans écraser les livraisons Claude ; vérification des 30 producteurs sur le code résultant.
2. Aucun gain légitime dépendant encore d'une sauvegarde `popBase/infBase` côté navigateur.
3. Contre-épreuves **base périmée**, **base courante falsifiée**, **deux onglets**, **réponse perdue** et **gain serveur + gain local** sur PostgreSQL jetable.
4. Prévol Supabase lecture seule, conformité des empreintes et des versions de migrations, puis approbation du game designer pour la livraison.
