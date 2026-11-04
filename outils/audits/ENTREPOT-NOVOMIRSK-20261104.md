# Entrepôt logistique de Novomirsk — préparation du 4 novembre 2026

## État réel

**CHANTIER NON TERMINÉ / NON DÉPLOYÉ.** Le raccordement et les transactions locales ci-dessous
sont codés et éprouvés sur fixtures. Le prévol Supabase vivant n'a pas pu être exécuté : aucun
outil Supabase n'est exposé dans cette session. Aucun schéma, joueur, stock ou solde de production
n'a été modifié. Aucune migration appliquée, aucune fusion ni déploiement demandé.

Branche : `codex/entrepot-novomirsk-20261104`, base `7def091f`, main `f60d89a8` intégré sans
écraser le manifeste du port de Claude (#461) ni le relais #462. Seul conflit : version de cache
de `plateau-justice-economie.js`, résolue en conservant les deux lots.

Création de PR tentée via `gh pr create --draft` : GraphQL **Forbidden**. Consultation de la CI
par `gh run list` également **Forbidden**. Donc aucune PR ni aucun statut CI distant ne sont
annoncés comme obtenus. Branche à ouvrir depuis :
https://github.com/FredJ74/res-publica/pull/new/codex/entrepot-novomirsk-20261104

L'approvisionnement initial/automatique est le seul paramétrage économique encore à retrouver :
Fred a demandé une recherche des spécificités, réalisée et consignée dans
[SPECIFICITES-ECONOMIQUES-SOVARKA-20261104.md](SPECIFICITES-ECONOMIQUES-SOVARKA-20261104.md).
Les 150 bois/jour historiques sont un flux exporté vers Républia ; ils ne justifient pas de
créditer 150 autres bois/jour à Novomirsk. Le panier républien n'est pas recopié. Le cron de
réapprovisionnement reste républien ; aucun approvisionnement automatique sovarkien n'est
présenté comme terminé. La recherche n'établit pas que les instructions n'existent nulle part,
seulement qu'aucun barème complet n'a été retrouvé dans les sources accessibles.

## Fonctionnalités codées et testées localement

| Parcours | Résultat local |
|---|---|
| Rue `novomirsk-vue-8` | Zone reliée au bâtiment ; retour trouvé sur ce même nœud |
| Accueil, salle des ventes, bureau | Onglets communs ; agent d'accueil et directeur PNJ de fonction ; visibilité du directeur PJ selon le mécanisme existant, cache territorial corrigé |
| Catalogue | Ordres du modèle républien réutilisés, stock nul conservé, prix de référence ou manuel, capacité commune |
| Achat sur place | Dépôt, argent, caisse et reçu atomiques ; hors salle ou pays étranger refusé |
| Direction | Stocks/objectifs, caisse, registre, prix ; 1 PA et modification des prix dans la même transaction |
| Offres | Blocage de fonds, vente locale depuis l'inventaire, retrait/remboursement, épuisement et rejouements |
| Trading national | Caisse de l'organisation, paiement réel, stock vendeur et caisse terrestre nationale ; tranches existantes préservées |
| Isolation | `(pays,ville)` ; source/destination étrangères refusées avant paiement ; noms des courriers et villes résolus dans le bon pays |
| Concurrence | Deux connexions, même requête : une exécution ; deux commandes pour le dernier stock : une seule acceptée |

Les salles ne réutilisent pas des illustrations portant « Luthécia » ou « Montrouge ». Aucun
nouveau dessin généré : fond existant sans image intérieure, à compléter uniquement avec une
ressource adaptée validée. Les illustrations des trois entrepôts républiens restent intactes.
La réserve militaire existante est soustraite du stock vendable ; aucun nouveau régime de
mobilisation militaire de Sovarka n'est activé.

## Défauts réellement reproduits/corrigés

- Le résolveur du directeur composait `republic_…` depuis la seule ville : un directeur sovarkien pointait sur Luthécia. Contre-épreuve exécutée avant migration.
- `entrepots_par_ville` n'avait ni pays ni clé capable de distinguer deux capitales. Passage à `(pays,ville)` ; les lignes existantes sont conservées, aucun `CASCADE`.
- `fixer_prix_entrepot` acceptait un pays fourni par l'écran sans le comparer à celui du titulaire ; il est désormais vérifié.
- L'achat sur place créditait `entrepot.caisse` dans le blob ; le produit va à la caisse institutionnelle existante et un refus de crédit annule toute l'opération.
- La commande directeur ignorait le résultat du crédit fournisseur et permettait de vendre la réserve militaire. Les deux cas ont une contre-épreuve et une vérification d'annulation.
- La fixation des prix prélevait son PA avant une deuxième RPC susceptible d'échouer. Enveloppe transactionnelle et reçu communs, ancien accès non versionné fermé au navigateur.
- Commandes, achats de trading et offres sans clé stable : surcharges réutilisant `achat_requete_ouvrir_interne` / `_clore_interne`, avec le pilote `executerReceptionInventaire` existant. Aucun deuxième moteur ou registre financier.
- Une réponse de trading rejouée pouvait réafficher les anciens PA scalaires malgré le reçu frais : adoption du paiement courant, sans ce recalcul.
- Cache des titulaires et tableau tardif pouvaient mêler deux pays : filtrage, portée du cache et refus de la réponse périmée.
- Les noms « capitale » dans les courriers et la carte de trading étaient toujours rendus comme Luthécia. Résolution par pays, depuis `villes`/`VILLES`.
- Reconstruction de `20261104173000` : le fragment du champ PA ne correspondait pas au corps d'origine, à cause d'un saut de ligne. Correction bornée aux espaces, garde d'échec conservée. **Ce n'est pas une instruction de réappliquer cette ancienne migration en production.**

## Fichiers principaux

- `data.js`, `plateau-rue-centrale.js`, `plateau-navigation.js` : déclaration et navigation.
- `plateau-entrepots.js`, `plateau-justice-economie.js`, `plateau-equipements.js` : interfaces existantes, nation et transactions.
- `plateau-multijoueur.js` : cache des titulaires par pays ; `api/cron-minuit.js` : la lecture des directeurs républiens exclut ceux de Sovarka.
- `api/_pnj-personnalites.js`, `api/_pnj-scenes-generes.js` : deux profils ordinaires de fonction, métadonnées régénérées ; aucune personnalité spéciale inventée.
- `outils/generateurs/navigation-lieux.cjs` : nouvelle déclaration exclue du générateur historique immuable #219, car portée par sa migration dédiée.
- `index.html`, `plateau.html` : versions des scripts modifiés.
- `migrations/20261104183122_entrepot_novomirsk_isolation_pays.sql` : migration préparée, **non appliquée**.
- `outils/bancs/prevol-entrepot-novomirsk.sql` : prévol en transaction cohérente et lecture seule ; ne lit aucun compte, `auth.users`, journal privé ni contenu d'inventaire.
- Trois bancs Novomirsk (client, navigateur, PostgreSQL), ce rapport, recherche des règles, architecture et relais.

## Preuves locales

- **196/196 bancs clients** réussis sur le code final, sans SQL ni production.
- **129 tests ciblés** : entrepôt, noms/territoires, titulaires, nominations municipales, dialogues/contextes et livraison terrestre. Réponses IA simulées : aucune réponse DeepSeek réelle déclarée vérifiée.
- **60 assertions PostgreSQL 17.6** au rôle `authenticated`, `request.path` renseigné, transaction annulée. Vrais corps SQL et vraies primitives financières ; identité fixture, connexion internet et légalité simulées explicitement. Schéma minimal, pas une reconstruction certifiée de tout Supabase.
- **64 assertions avec concurrence** : les mêmes cas plus quatre assertions sur deux connexions réelles. Ce mode commite uniquement le décor et les actes fictifs de la base jetable pour qu'ils soient visibles des deux sessions, puis détruit le cluster. Il n'est donc pas présenté comme un banc entièrement annulé par une unique transaction.
- **20 tests navigation/réception**, dont quatre tests Chromium (deux Novomirsk, deux navigation Républia), formats 390/1280. Rue, vrais onglets et vrai catalogue ; entrée/sortie observées avec mutations serveur simulées. Ce n'est pas une recette authentifiée de production.
- **13 tests du bundle Vercel** réussis localement ; aucun déploiement de test déclenché.
- **Workflow conforme**, 14 tests de rangement et contre-épreuves réussis. L'erreur initiale de rangement du SQL de prévol a été corrigée, sans changer le contrôleur.
- Contrôles globaux : **9/12**, mêmes trois familles rouges que le main isolé de référence. Baseline : seed `ordres_couts` en retard sur son générateur. Authority : deux références non résolues de la signature créée dynamiquement par `20261104173000`. Referential : empreinte déclarée d'`ordres_couts` différente du générateur. La branche résout déjà l'appel de trading incompatible repéré sur le main, mais ne déclare pas Authority vert. Aucune empreinte ni observation corrigée artificiellement.

Journaux, résultats et empreintes : `preuves-entrepot-novomirsk-20261104/`. Ces fichiers ne
contiennent que des fixtures et des diagnostics locaux. Aucun export privé de production.

## Procédure de livraison et retour arrière

1. Créer la PR avec l'accès GitHub d'intégration, obtenir la CI sur son SHA final et coordonner la résolution des trois contrôles hérités. Ne pas fusionner un lot encore bloqué.
2. Retrouver/confirmer le seul paramétrage économique manquant de l'approvisionnement de Novomirsk ; ne pas déduire un nouveau stock du flux exporté historique.
3. Intégrateur technique : exécuter le prévol réel en lecture seule ; vérifier **par nom** le registre, les signatures, ACL/RLS, contraintes, triggers et écrivains qui dépendent du référentiel. Dépendances : socles #219/#379, achats/reçus existants, trading/offres du 03/11, livraisons terrestres `20261104173000`, `20261104181000`, `20261104183000`. Si déjà appliquées, ne pas les rejouer. La nouvelle migration est horodatée après elles.
4. Comparer chaque fragment de définition à la production et rejouer la nouvelle migration sur un clone fidèle. Elle refuse les fragments inconnus, un autre référentiel de clés ou tout appelant SQL du référentiel non audité ; aucun résultat de fixture ne dispense de ce contrôle.
5. Capturer définitions/droits et empreintes des tables touchées par le canal technique autorisé ; appliquer uniquement la nouvelle migration via le registre après certification. Réextraire le baseline conformément au workflow. Aucun solde PJ existant à « corriger ».
6. Livrer le client compatible, constater Vercel READY et les ressources servies, puis recette avec comptes/fixtures autorisés. Aucun achat, nomination ou déplacement à effet sur un joueur réel pour tester.

Avant application : retour arrière = abandonner la branche, rien en production n'a changé.
Pendant l'essai : rollback intégral et rejeu déjà éprouvés. Après une activation et des actes
réels : ne pas supprimer le nouvel entrepôt, ses reçus, stocks, offres ou caisses et ne jamais
rétablir les résolveurs ambigus par ville seule. Privilégier une migration corrective qui
conserve les données et l'isolation territoriale ; une restauration de définitions/ACL doit
être réexaminée avec les opérations intervenues, pas appliquée à l'aveugle.
