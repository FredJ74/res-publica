# Décor local de la PR #1020

Relevé du 16 novembre 2026 sur `res-publica` : métadonnées uniquement, aucun profil, inventaire, compte Auth ou jeton de production. Les définitions et colonnes proviennent des catalogues PostgreSQL ; les références sont les lieux/rues de Sovarka et les coûts existants des deux transports.

Le banc installe le baseline, complète ses colonnes/tables manquantes et charge les fonctions vivantes nécessaires au parcours (104 définitions, dépendances comprises). Il exerce les migrations de #1020 sur un serveur jetable. Ce décor ne reproduit pas toutes les contraintes, politiques RLS ni données de production : il ne certifie pas un clone fidèle de Supabase. Les primitives Auth sont des fonctions de fixture, pas une connexion GoTrue.

Le CHECK interdisant l'activation est éprouvé avant toute simulation. Certains tests le retirent dans leur seule base locale et utilisent des paramètres marqués FIXTURE. Ces paramètres ne sont ni des règles proposées, ni une configuration livrée ; aucun mécanisme d'arrestation n'est implémenté par ces valeurs.

Exécution : `python3 outils/bancs/test-goulag-postgresql-20261116.py --postgres-bin <binaires PostgreSQL 17.6>/bin`. Aucune URL distante n'est acceptée. Les appels client passent au rôle `authenticated`, avec identité fictive et chemin `/rpc/`. Le test de concurrence ouvre deux connexions réelles.
