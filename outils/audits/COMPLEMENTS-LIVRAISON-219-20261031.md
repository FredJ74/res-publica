# #219 — compléments de clôture, livraison toujours retenue

Ce document complète et actualise `FINALISATION-LIVRAISON-219-20261031.md`. Aucun changement de production, aucune fusion, aucun compte créé ni authentification modifiée. Main #297 (`c44f5c40`) intégré ; travaux de Claude conservés. Corrections sauvegardées sur `codex/groupes-universels-20261028`, PR #219 : `cbf4d64a`, intégration `6ccbe99c`, garde de rejeu `19ba214b`.

## Organisations et coûts

Trois RPC actives : cinq migrations explicitement sélectionnées, contrôles des signatures/droits/reçus, transactions et nonces. Les quatre RPC d’équipements futurs ne sont plus appelées par les scripts chargés. Le code préparé est conservé hors chargement et testé. Absence de contrat = refus, sans sauvegarde générale ni DELETE de secours. Achat personnel préservé. Cela ne ferme pas à lui seul les écritures directes suivies par #295/#296.

Le garde du payeur accepte uniquement les corps examinés, et l’adaptateur universel seulement avec ses deux fonctions internes attestées et fermées aux rôles clients. Aucun payeur remplacé. Le rejeu de la migration des événements accepte son nouveau corps exact ; un corps tiers reste refusé (contre-épreuve ajoutée).

Les 27 couples résiduels ont été analysés : `choisir_arme,1,0` et `donner_argent_pnj,1,0` restent nécessaires. Le plan retire 25 couples périmés et ajoute 39 déclarations actives : 452 triples sources, 413 communs aux 438 capturés. Ni tarif copié arbitrairement depuis la capture ni valeur de gameplay modifiée. Gilet : deux déclarations existantes 0 PA/380 FR et 1 PA/600 FR conservées ; mélange 0 PA/600 FR retiré. L’écart écran/gestionnaire relève du rapprochement commercial #293, pas d’un nouveau prix décidé ici.

Diff individuel et origines : `TARIFS-25-RECONCILIATION-219-20261031.md` et `RECONCILIATION-COUTS-219-20261031.json`. L’origine exacte du mélange gilet ancien n’a pas été retrouvée, contrairement aux autres couples. Migration de tarifs : table verrouillée, matrice complète attestée avant/après, refus de toute dérive et rollback intégral. Export brut gardé hors Git. Seeds régénérés avec l’outil existant.

## Résultats exécutés

- 45/45 commandes Python du workflow réussies après correction, sur le PostgreSQL jetable du gestionnaire utilisé en CI. La première passe (44/45) a effectivement révélé le défaut de rejeu ; il n’a pas été ignoré.
- 154/154 bancs clients après main #297 ; 105/105 tests du pilote Chromium. Pas de campagne GoTrue ni de compte réel.
- 379/379 scénarios groupes : rounds, groupes mixtes, transports, radio, police, écrou, déplacements et protections transactionnelles dans leurs décors.
- Six mutations sur 379 cas chacune détectées : issue fausse (1 échec), double paiement (5), PNJ immobile (1), camion solo (4), repli sans mouvement (5), provenance oubliée (1). Cas obligatoire squatteurs détecté ; la réserve historique sur une issue additionnelle variable reste documentée, sans retrait de test.
- Sur PostgreSQL natif 17.6 : 36 assertions du lot organisations, 29 tarifs, 27 événements et 44 tests d’outillage. Actions de paiement testées sous rôle authenticated ; identité et services de fixture, pas une authentification GoTrue réelle.
- Contrôleur global : **10/12**, Authority et Referential toujours rouges. Aucun changement de vérificateur/observation/empreinte pour masquer ces écarts.

### Échec supplémentaire conservé : garde des écritures par la vue

La commande `node --test outils/bancs/test-*.mjs`, conditionnée aux pushs dans le workflow, a aussi été exécutée. **13/14 passent, un reste rouge**. Le chemin des deux correctifs du 30/10 a été corrigé vers leurs archives réelles ; mêmes assertions conservées.

Le détecteur signale `20261031113610_construction_materiaux_prix_et_dons.sql` et `20261031113631_compromis_financement_reel.sql`. La première contient un UPDATE direct par la vue personnages ; la seconde contient à la fois des recherches textuelles historiques et des remplacements qui réémettent cette écriture. Ces deux préparations immobilières ne sont PAS dans les 95 versions sélectionnées. Elles nécessitent reprise ciblée avec Claude sur leurs entrées actuelles et tests financiers avant activation, sans remplacement aveugle de chaînes ni exclusion du test. Leur rehorodatage les a rendues visibles à la garde récente : ne pas annoncer tous les tests verts simplement parce que les six workflows de PR peuvent sauter cette étape de push.

Preuves brutes dans `preuves-complements-219-20261031/`.

## Installation et prévol — NON exécutés

Les 89 versions initiales avaient été installées dans une transaction sur le catalogue privé 1003 et éprouvées par 30 cas du catalogue entier. Les cinq organisations et le correctif de coûts sont éprouvés séparément. La composition **95 = 5 + 89 + 1** est préparée et analysée, mais **pas exécutée intégralement ni validée contre les 1008 versions annoncées**. Manifeste et empreinte : `LIVRAISON-COMPLETE-219-20261031.json`. Ne pas confondre préparation structurelle et installation réussie.

Aucun connecteur Supabase callable dans cet environnement. La demande ciblée à l’intégrateur ChatGPT est `DEMANDE-PREVOL-ACTUALISE-219-20261031.md` : registre, définitions/ACL/triggers/RLS actuels, empreintes de coûts et contenus des autres référentiels statiques. Pas de nouvelles données joueur ni quatre exports complets redemandés. Les nombres 1008/1199/17 ne prouvent pas la compatibilité des corps.

Après réception : confronter les cinq nouvelles migrations de production au catalogue 1003, mettre à jour le décor privé par les outils canoniques, vérifier toutes les gardes et exécuter les 95 atomiquement avec panne tardive, données fictives et recette GoTrue isolée. Refaire Authority/Referential sur l’état observé après application autorisée seulement ; baseline suit la base.

Aucune exécution sensible avant autorisation et prévol conformes. Le paquet complet fait environ 1 Mo : valider un canal transactionnel autorisé qui accepte le tout ; ne pas découper en commits SQL pour contourner une limite MCP. Avant COMMIT, toute erreur doit annuler les 95 inscriptions et leurs effets. Après COMMIT et reprise des joueurs : pas de restauration aveugle des anciennes données ; un retour de code ou migration compensatoire nécessite son prévol et conservation des actions intervenues.

Recette GoTrue isolée à réaliser ensuite : groupes mixtes, leader payeur, fonds insuffisants sans déplacement partiel, perte de réponse et rejeu, détection avant intervention, remise à la police/prison, rounds, fuite et radio. Arnie demeure en consultation seule.

**CHANTIER NON TERMINÉ.** Code et preuves sauvegardés, production intacte. Blocages : prévol vivant actualisé, exécution intégrée des 95, deux contrôles globaux rouges, préparation immobilière signalée par la garde, recette authentifiée isolée. Aucun feu vert de fusion ou déploiement.
