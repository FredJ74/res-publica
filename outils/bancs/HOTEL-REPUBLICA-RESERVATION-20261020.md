# Hôtel La Républia — réservation à l'accueil, 20 octobre 2026

## État de livraison

**CORRECTION CODÉE ET TESTÉE, NON DÉPLOYÉE SUR SUPABASE. INCIDENT NON CLOS EN PRODUCTION.**

La panne signalée est reproduite avec les définitions de `20261019221500_luthecia_cartes_et_diners.sql`. La définition vivante n'a pas pu être lue dans cette session. Aucun outil MCP Supabase n'est exposé ; les requêtes HTTPS vers le projet Supabase et l'API Vercel échouent au tunnel réseau (`CONNECT 403`). Aucune clé d'administration Supabase ni session authentifiée autorisée de test n'est disponible ici. Le jeton GitHub ne donne pas un accès SQL.

## Cause reproduite et correction

Le client `doReserverChambreHotel`, depuis `hotel-republica/accueil`, appelle le moteur existant `commerceVendreProduit` avec panier vide, mode `service`, ordre `reserver_chambre_hotel` et coût déclaré de **80 FR, 0 PA**. Ce moteur appelle `commerce_vendre_produit_interne`.

Deux gardes de la migration restaurant bloquaient cette prestation :

1. `restaurant_luthecia_vente_verifier` imposait `bar` ou `restaurant`, donc refusait `accueil` avec `pas_sur_place`.
2. Même depuis le bar, la garde suivante exigeait le contexte privé d'un dîner pour **tout** mode `service`.

La migration corrective est **`migrations/20261020114246_reservation_republica_accueil.sql`**. Elle transmet explicitement l'ordre au contrôle interne, qui exige pour la réservation : personnage serveur en Républia, ville `capitale`, bâtiment `hotel-republica`, pièce `accueil`, mode `service`, panier vide. La présence d'un ordre dans l'interface ne fait pas autorité. Le contrôle à quatre arguments reste compatible, délègue au même contrôle et ne peut déduire une réservation d'un panier vide.

Les achats gardent leurs restrictions de pièce et de carte ; les dîners gardent leur garde privée. Le prédicat de périmètre exact est conservé : les autres hôtels ne prennent pas ce nouveau chemin. Les contrôles internes restent inaccessibles directement aux rôles clients. L'appel public, l'authentification, les tarifs, `payer_ordre`, la fiscalité et la caisse existante sont conservés. Aucun second paiement ni moteur d'encaissement n'est ajouté.

## Réservation payée et sommeil

Une autre fenêtre était visible dans le code : la réservation était créée seulement dans `state.char`, puis sauvegardée après le retour du paiement. Une fermeture immédiate pouvait intervenir après paiement, avant persistance. Le moteur existant enregistre maintenant `reservation_hotel` **dans la transaction qui encaisse**. Il conserve le format déjà relu par `sbLoadPersonnage` et les bonus existants : **2 PA et 3 Moral**. Le PA provient de `pa_bonus_hotel`, dont la valeur attendue est vérifiée avant migration.

Une panne de persistance lève une erreur et annule aussi le débit, la taxe et le crédit de caisse. Aucun inventaire ni solde existant n'est modifié par l'application du DDL. Aucun succès artificiel n'est renvoyé. Cette correction n'introduit pas de contrat d'idempotence pour des requêtes de réservation répétées : le test d'un paiement unique porte sur une exécution, et le test concurrent vérifie que les mêmes fonds ne peuvent pas être dépensés deux fois.

Le vrai moteur SQL `pa_bonus_chambre` est exercé après reconnexion : +2 PA, consommation de la réservation, deuxième bonus refusé. Les vrais handlers JavaScript et le vrai chargeur sont testés sur fixtures : restauration après rechargement, sommeil uniquement dans la chambre réservée, appel au bonus serveur et +3 Moral. Les mécanismes de sommeil ne sont pas réécrits.

## Fichiers

- `migrations/20261020114246_reservation_republica_accueil.sql` : correction ciblée, transactionnelle, idempotente, avec refus d'une définition serveur inconnue.
- `outils/bancs/banc-reservation-republica-local.py` : vrais contrôles, moteur de vente, RPC publique et bonus SQL sur PostgreSQL jetable ; services de paiement/auth/fiscalité de fixture.
- `outils/bancs/banc-reservation-republica.cjs` : vrais handlers et chargeur extraits par AST, réponses de fixture.
- `outils/bancs/banc-reservation-republica-prevol.sql` : lecture seule du registre, définitions, droits, déclencheurs, colonne, bonus et empreintes métier.
- `outils/bancs/banc-restaurant-luthecia-local.py` : option pour exécuter ses assertions existantes après application de ce correctif, sans désactiver les assertions.
- `.github/workflows/coherence-client.yml` : raccordement au job PostgreSQL existant, sans pipeline supplémentaire.

Aucun fichier généré du baseline, code client déployé, règle de prix ou donnée de joueur n'a été retouché. Les commits concurrents `1b488d5` et `d6f1d00` ont été intégrés avant livraison sans modification de leur contenu.

## Tests effectivement exécutés

| Vérification locale | Résultat |
| --- | --- |
| Régression réservation PostgreSQL | **49/49** assertions |
| Handlers réservation, rechargement et sommeil | **4/4** tests |
| Restaurant PostgreSQL, avant et après correctif | **94/94** dans chaque configuration |
| Tournées PostgreSQL existantes | **60/60** |
| Contrôleur client complet, relancé après intégration de main | **91/91 bancs** |
| Contrôles globaux, après intégration de main | **10/12** |
| Grammaire SQL, YAML, diff | Conformes |
| Application Supabase, test authentifié et observation de production | **Non exécutés** |

Les contre-épreuves reproduisent le refus original à l'accueil et la garde dîner depuis le bar. Les cas corrigés couvrent accueil, rue/pièce nulle, bar, restaurant, chambres, mauvais pays/ville/bâtiment, panier déguisé, fonds insuffisants, concurrence, panne après encaissement, droits internes et prévol refusant une définition inconnue. La migration et son rejeu laissent les lignes de fixture intactes.

Les deux rouges globaux préexistants restent **Authority** (28 RPC clientes absentes du baseline disponible) et **Referential** (trois problèmes d'empreintes documentés par le contrôleur). Aucun test, empreinte ou baseline n'a été modifié pour les masquer. Le contrôleur de rangement a initialement refusé l'orthographe `BEGIN TRANSACTION READ ONLY` du prévol : l'enveloppe a été remplacée par `BEGIN; SET TRANSACTION READ ONLY; ... ROLLBACK;`, puis le contrôle est redevenu conforme sans affaiblissement.

## Suite technique requise, sans SQL demandé au game designer

L'agent disposant du canal Supabase autorisé doit :

1. Exécuter le prévol en lecture seule, vérifier le registre et les définitions réellement installées, leurs propriétaires/droits et les déclencheurs. Vérifier aussi les écritures financières transitives. Les gardes de source refusent tout écart non examiné ; ne pas les contourner en changeant les empreintes. Ne pas rejouer les migrations d'initialisation du restaurant.
2. Conserver les définitions/ACL antérieures et les empreintes métier, appliquer **cette seule migration** par `apply_migration` enregistré sous la version `20261020114246`, puis comparer les empreintes et vérifier structurellement les fonctions/droits. La migration n'appelle aucune réservation de test et ne débite personne.
3. Réextraire le baseline et les seeds par les outils du workflow, relire les différences, archiver la migration appliquée et committer cet état réel. Aucun baseline n'est fabriqué ici pour simuler le déploiement.
4. Vérifier le rechargement et le sommeil avec un compte de test autorisé et un cadre isolé ; ne pas débiter Angie pour prouver la correction. Sans cet accès, les tests locaux restent distincts du fonctionnement réel.

La correction est **serveur uniquement** : aucun nouveau bundle client Vercel n'est nécessaire. Un push sur main peut néanmoins déclencher le déploiement automatique existant ; son résultat distant n'est pas observé depuis ce runtime.

En cas de retour arrière, restaurer uniquement les définitions/ACL capturées, après contrôle de la version présente, dans une nouvelle migration enregistrée ; ne pas rejouer la migration d'initialisation et ne pas effacer les réservations déjà payées, ni rembourser/débiter automatiquement des joueurs. Un retour aux anciennes gardes réintroduirait le refus d'accueil.

**Aucune migration appliquée, aucune donnée réelle modifiée, aucune réservation exécutée sur Angie.** Le manque d'accès Supabase est le blocage restant pour lever l'incident en production ; il n'est pas transformé en réussite locale.
