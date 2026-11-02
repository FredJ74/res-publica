# Audit transversal #135 : raccordements canoniques et régressions des trois villes

Mission du commentaire du 2 novembre : vérifier les livraisons existantes et corriger
les chemins concurrents démontrés, en préservant les PNJ/DeepSeek de Claude.

Les entrées de transport, douane et taxi délèguent désormais toujours aux actes
atomiques existants. Le renderer commun échappe correctement les clics réservés
à un poste ; la relecture du greffe conserve la révision de l'inventaire. Les
anciens boutons électoraux deviennent des adaptateurs, les fonctions globales
en doublon sont retirées, et une réponse bancaire perdue n'annonce plus l'absence de débit.
L'installation des dépendances CI précède maintenant les tests transversaux.

Main intégré jusqu'à #378 (`a52e1a00`) ; aucun prix, droit de poste, effet ou mécanisme
métier modifié. Aucun fichier PNJ/DeepSeek modifié par ce lot. Aucune migration nouvelle.

Validation locale : **169 bancs clients, 118 tests pilote/Chromium, 53 tests
transversaux, 379 cas PostgreSQL 17.6 et 12 contrôles globaux réussis**. Les
contre-épreuves dénoncent les anciens défauts ; les preuves sont versionnées.
Ces nombres se recouvrent, ils ne s'additionnent pas en une couverture globale.

- [Rapport et matrice de livraison](CLOTURE-TRANSVERSALE-135-20261102.md)
- [Résultats et empreintes des preuves](PREUVES-CLOTURE-TRANSVERSALE-135-20261102.json)
- [Inventaire différentiel des appels](INVENTAIRE-CLIENT-135-20261102.json)

**Revue préparée, production non certifiée.** Le catalogue vivant, la version
réellement servie et la recette authentifiée ne sont pas accessibles ici.
Les reliquats conditionnels (anciens vols/impacts, subtilisation, recrutement
codétenu) sont nommés dans le rapport, pas déclarés corrigés. Prévol SELECT prêt.
Observer la CI sur le SHA exact et valider la livraison avant toute fusion.

Refs #135, #250, #262, #282, #349, #366, #371. Ne ferme pas #135 automatiquement.
