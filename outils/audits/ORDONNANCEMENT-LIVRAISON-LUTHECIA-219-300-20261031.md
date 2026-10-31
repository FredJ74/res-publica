# Livraison coordonnée Luthécia — préconditions vérifiables

## Coupes examinées
- #219 : `80d6e6c7ab201c34376a3c1c21a0253a3d92f4b8`, brouillon, six workflows GitHub verts. Paquet **95 migrations** non installé ; contrôles globaux **10/12**, garde Node **13/14** selon Codex.
- #300 : `b035129c17284ec3004e05f8b4dac79da325a81a`, brouillon, cinq workflows GitHub verts. Migrations financières `20261031200000` et `20261031201000` non installées.
- #298 : `7dadd480fe48afd3fc105d5454f783000bf8c15e`, documentation uniquement ; éviter un déploiement séparé.

## Ordre non interchangeable des finances collectives

1. Prévol Supabase actualisé ; vérifier les contrats financiers existants et l'absence de collision de signature. Exécuter le banc SQL en base jetable sur le schéma complet. Ne pas utiliser les personnages réels comme fixtures.
2. Appliquer la migration **étape 1** (`20261031200000_caisses_collectives_portes_serveur.sql`) seulement après validation, sans fermer les écritures directes utilisées par l'ancien écran.
3. Livrer et vérifier l'écran compatible avec les RPC de l'étape 1 (Vercel READY, tests d'appels authentifiés, rafraîchissement, refus, double clic).
4. Appliquer **étape 2** (`20261031201000_caisses_collectives_fermer_ecran.sql`) seulement après confirmation de l'écran READY. Vérifier les ACL/RLS/triggers post-migration.
5. Rejouer les bancs club, organisations et banque ; vérifier les droits du chef, trésorier, membres et tiers. **Pas de retour à une écriture directe sur refus RPC.**

Les droits d'INSERT/UPDATE `organisations` restent partiellement ouverts à l'étape 2 pour les commandes de #219 ; le trigger doit alors bloquer les modifications financières et d'autorité illicites. Cette compatibilité exige une recette authentifiée dédiée, pas seulement des bancs PostgreSQL avec rôle simulé.

## Groupe universel
- Ne pas fusionner #219 tant que les **95 migrations** ne passent pas atomiquement sur le catalogue vivant **1009** et que les écarts Authority/Referential ne sont pas qualifiés. Tester rollback tardif.
- **Précision du payeur** : `md5(prosrc)=5cf45c19e4b9559f6b29e2b9207d3969` correspond déjà à la garde ; ne pas confondre avec `md5(pg_get_functiondef)=37eca91d6eb08c2a6ea97cbe717a216a`.
- Les deux préparations immobilières signalées par la garde Node restent hors paquet ; issue #299.

## Décision de livraison
Toute fusion `main` peut déclencher Vercel ; grouper les étapes compatibles, mais **ne pas déployer l'écran avant l'étape 1**, et **ne pas fermer les permissions avant l'écran compatible**. Si l'ordre ne peut pas être garanti, suspendre la livraison plutôt que provoquer une fenêtre de panne.

Rapport d'intégration préparatoire : aucune fusion, migration, écriture joueur ou déploiement exécuté ici.
