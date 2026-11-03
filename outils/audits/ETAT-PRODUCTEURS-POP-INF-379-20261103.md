# PR #379 — état actualisé des producteurs POP/INF
> Révision de travail sur branche #410 (ciblant #379). **Non certifié en production.**

## Preuves exécutées

- **Ancienne fusion en production** : MD5 `248b3f7f5e8c24148afa624649ee3f47`, prévol Supabase lecture seule. La migration de protection n'est pas appliquée.
- Première protection `20261103183000` : 18/18 tests PGlite (vieux cache et répétitions), mais un client avec `popBase=10,pop=99` et `infBase=10,inf=99` passe toujours ; **interdit de présenter ce lot comme une fermeture complète**.
- Fermeture stricte : `outils/livraison/preparatifs-379/fermeture-pop-inf-serveur-seul.sql` volontairement **hors dossier migrations**. Rejouer `node --test outils/bancs/banc-pop-inf-forge-379.cjs` ; 3/3 preuves en environnement isolé (contre-preuve première protection puis refus par la stricte). Ne livrer qu'après migration de tous les producteurs actifs.
- Grâce présidentielle : `20261103133000`, 15/15 SQL isolés, 5/5 côté client ; réparation de l'ancien circuit PA/QHS/POP. Ce lot n'est pas une certification de production.
- Inspection portuaire : `20261103203000`, 14/14 PGlite et contrôles client ; bonus INF +5 ou malus -3 décidé par serveur, 2 PA, rôle min_def, présence au quai, reçu anti-rejeu.
- Sondage historique et allègement fiscal inatteignables : supprimés de la branche, 2/2 tests ciblés. L'ordre officiel `commanditer_sondage` transactionnel et le message « allegement fiscal indisponible » sont conservés.

## Producteurs de l'inventaire d'origine : état des travaux

| Producteur | État sur la branche #410 | Action restante |
|---|---|---|
| `applyCharToState` | Chargement de fiche, pas un producteur de gain | Contrôler l'adoption au retour de commande |
| `doInspecterCargaisons` | **Raccordé**, RPC reçue atomiquement | Certification PG natif et cohérence avec groupes/effects |
| `envoyerInvitationSociale` | Gain INF encore local | Porter contrat, PA et invitation au serveur |
| `verifierReponseInvitationSociale` | Gain INF encore local | Contrat reçu et anti-rejeu |
| `repondreInvitationSociale` | Gain INF encore local | Contrat reçu et anti-rejeu |
| `interagirPnjTerrain` | Aucun appel statique retrouvé | Prouver l'inaccessibilité ou porter les deux gains |
| `payerEscorts` | Malus POP local de non-paiement | Coupler au paiement/renvoi serveur |
| `publierDecret` | POP et INF locales, publication séparée | Transaction publication/PA/jauges |
| `publierMessagePresidentiel` | POP et INF locales | Déterminer puis transférer la récompense validée |
| `confirmerEtatUrgence` | Ancienne implémentation présente sur #379 | **Réutiliser la migration Claude de main**, pas la dupliquer |
| `confirmerGrace` | **Raccordée** dans #410 | Prévol PG natif, contrôle compatibilité clients anciens |
| `executerOrdreTexte` | Malus POP local pour manifestations | **Réutiliser la migration manifestations de main**, comparer les autres branches |
| `appliquerAllegement` | **Supprimée** ; route orpheline retirée | Aucun ordre à réactiver sans arbitrage |
| `censurer` | Malus POP local aléatoire | Porter l'indice, le jet et la dépense au serveur |
| `confirmerBanquetDiplomatique` | Débit serveur partiel, jauges locales | Terminer commande unique et aléa serveur |
| `doReceptionAvecBonus` | Débit serveur partiel, jauges locales | Terminer commande unique et aléa serveur |
| `confirmerMobilisationPolice` | POP locale | Relier au serveur et indices de main |
| `traiterDemandeManifestation` | POP locale | Réutiliser contrats de manifestations sur main |
| `confirmerGuerreEmpire` | POP/INF locales | Commande militaire/diplomatique server |
| `confirmerDonArgent` | INF locale dans branche PNJ | Coupler au don serveur |
| `appliquerBonusLocation` | POP/INF locales au réveil | Coupler aux loyers réellement encaissés au cron |
| `confirmerDonPnj` | POP/INF locales selon PNJ | Paiement/reward par destinataire |
| `confirmerDonObjetPnj` | POP/INF locales selon objet | Transaction remise/effet |
| `confirmerCorruptionRegistre` | Ancienne implémentation sur #379 | Réutiliser travaux Claude de main |
| `commanderProduitCommerce` | POP locale après consommation | Créditer lors de la vente/consommation serveur |
| `commanderSondage` | **Supprimée**, aucun appel d'ordre ni UI | Aucun ; le vrai sondage reste `commanditer_sondage` |
| `appliquerMalusPopExcommunication` | Local si cible=self, RPC sinon | Unifier le jugement et l'effet au serveur |
| `doFaireDon` | République déjà par `religionAgirServeur` | Garder autres empires hors périmètre ou porter plus tard |
| `doBenedictionEtat` | **Supprimée** avec l'ancien ordre religieux | Aucun |
| `doConsulterConfessions` | **Supprimée** avec l'ancien ordre religieux | Aucun |

## Garde de livraison

Ne pas fusionner #379 ou #410, ni appliquer la **fermeture stricte**, avant :
1. Rebase réel sur `main`, sans écraser les livraisons Claude ; vérification des 30 producteurs sur le code résultant.
2. Aucun gain légitime dépendant encore d'une sauvegarde `popBase/infBase` côté navigateur.
3. Contre-épreuves **base périmée**, **base courante falsifiée**, **deux onglets**, **réponse perdue** et **gain serveur + gain local** sur PostgreSQL jetable.
4. Prévol Supabase lecture seule, conformité des empreintes et des versions de migrations, puis approbation du game designer pour la livraison.
