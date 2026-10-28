# Prévol cinq points — stabilisation de Luthécia, 28 octobre 2026

Périmètre indépendant des travaux groupes (Codex) et inventaire (Claude). Lecture du code `main` et interrogations **en lecture seule** du projet Supabase `jxpwoosmmhohoihxpbuc` et de Vercel.

## 1. Navigation et sorties de bâtiments

- `plateau-navigation.js` : `sortirBatiment` utilise `rue_sortie_batiment_lire` puis `rue_position_enregistrer`. La réponse perdue est traitée par `rue_position_lire`, sans relance aveugle de l'ordre de mouvement. Le verrou local `sortieBatimentEnCours` est libéré dans `finally`.
- La définition serveur `rue_sortie_batiment_lire()` sélectionne une sortie déclarée dans `rue_sorties_batiments` et vérifie que le noeud figure dans `rue_noeuds_serveur`.
- Requête exécutée : **Luthécia 36 sorties, Port-Sainte-Marie 33, Montrouge 41 ; zéro noeud orphelin**. Ces données ne prouvent ni que chaque bâtiment possède une sortie ni que toute transition réussit en jeu.
- **Restant** : campagne authentifiée de sortie depuis les pièces réellement problématiques, avec le code de refus et la position serveur avant/après ; éviter de fabriquer des mouvements sur des fiches réelles.

## 2. Erreurs « réception indisponible » et connexion

- Aucun libellé littéral « réception indisponible » retrouvé dans `plateau-navigation.js`, `plateau-router.js`, `plateau-justice-economie.js`, `plateau-core.js`, `plateau-multijoueur.js`, `supabase.js`. Le problème peut provenir d'un autre module, d'une réponse réseau ou d'un libellé indirect.
- `sbTransportRest` distingue erreurs HTTP, réseau et session perdue ; refuse une mutation sans jeton et ne réessaie pas les écritures non idempotentes. `signalerEchecSortie` donne un message et un diagnostic sans identité ni jeton.
- **Défaut de transport démontré dans le code** : dans `sbTransportRest`, une réponse HTTP 200 au JSON illisible était transformée en `etat:'ok', donnees:true`, ce qui peut faire apparaître une mutation non confirmée comme réussie. Correction préparée sur la branche : réponse `reponse_invalide`, sans relance automatique des mutations ; le cas 204 sans corps reste explicitement accepté. Banc Node `outils/bancs/banc-reception-rest-20261028.cjs` ajouté (5 cas), non exécuté en CI ; **ses cinq cas équivalents ont été exécutés avec la fonction réelle extraite de `supabase.js` dans un environnement JavaScript isolé : 5/5 réussis, une seule requête par cas**. Cela ne prouve pas la résolution des messages exacts « réception indisponible » en jeu ; absence de trace HTTP authentifiée.

## 3. Banque

- Tables réellement présentes : `prets`, `prets_bancaires`, `prets_nationaux_demandes`, `placements_bancaires` ; la table supposée `prets_nationaux` n'existe pas.
- Audit agrégé exécuté : `prets` **2 lignes, 0 montant négatif** ; `prets_bancaires` **0 ligne** ; `placements_bancaires` **3 lignes, 0 montant négatif**.
- Fonctions vivantes retrouvées : `pret_national_contracter_versionne`, `pret_national_creer_interne`, `creer_placement_national_securise` et plusieurs fonctions bancaires. Leur seule présence ne prouve pas un crédit bancaire exact ou visible.
- **Restant** : rapprocher en lecture seule les écritures de crédit/débit de prêts et soldes, avec des données de test autorisées ; vérifier que les montants affichés proviennent du serveur. Aucun solde réel modifié.

## 4. Vercel / GitHub / migrations

- Vercel connecté et consultable. Dernière production `READY` identifiée : déploiement `dpl_APc4HJi2jCV7UT3iVKevyzfyDyqu`, commit `3a9b0c5d5f09901e310358f91165ec78ba1de0d1` sur `main`.
- Des prévisualisations récentes de la branche `codex/groupes-universels-20261028` sont `READY` ; **ne pas confondre preview avec production**.
- La requête de migrations vivantes du 28/10 n'a renvoyé aucune entrée ; cela ne prouve pas que toutes les fonctions de ce jour sont absentes : il faudrait rapprocher le schéma et les versions réellement enregistrées, opération par opération.
- Aucun déploiement ni migration réalisé par cet audit.

## 5. Recette finale Luthécia : priorités restantes

1. **Bloquant :** quitter une salle et un bâtiment, puis revenir en rue sans rechargement ; confirmer la position en base.
2. **Bloquant :** diagnostiquer les erreurs de réception à partir du module exact, du statut réseau et du contexte d'une action réelle, sans divulguer de jeton.
3. **Bloquant :** valider versement, apparition sur compte, échéances et remboursement des prêts, et gestion des placements.
4. **Intégration :** attendre la finalisation des groupes, de l'inventaire, de la sécurité privée, des douanes et de l'immobilier pour lancer les parcours traversants.
5. **Clôture :** lancer les bancs complets, une recette de PJ authentifié, contrôler les déploiements production puis seulement déclarer la ville stable.

## État et règles de sauvegarde

Banc versionné : `outils/bancs/banc-luthecia-controle-navigation-banque-20261028.sql`, exécuté en lecture seule sur Supabase. Un correctif défensif du transport REST est codé dans `supabase.js` mais non exécuté en production. Aucun mouvement fictif, aucune migration appliquée, aucun déploiement engagé. **L'origine des interruptions de réception réelles reste à confirmer par des traces et des tests.**

## Complément de vérification — 28/10

- PR #218, commit `d5893c21a1f6fb08ab308847119c613dc33fcece` : cinq workflows associés au commit terminés en **succès** (cohérence client/transports simulés, placements, calendrier, payload Vercel, cinq terrains). Journal du job `122922916172` : exécution explicite `OK  banc-reception-rest-20261028.cjs`. Cela valide le banc dans la CI, **pas** un scénario connecté en jeu.
- Supabase vivant, requêtes **SELECT uniquement** : prêt national `travaux` de **Jean Jaaj** de 100 000 FR, créé le 18/10/2026 à 19:54 UTC, capital restant 76 997 FR et statut `en_cours`. Deux comptes rattachés à ce nom, banque `nationale` (solde 2 711 FR) et `helvetia` (88 920 FR). Le prêt apparaît deux fois **uniquement à cause de la jointure sur les deux comptes** : aucune preuve de prêt dupliqué. Les soldes instantanés ne prouvent ni le versement initial ni sa destination. Ne rien créditer manuellement.
- Recherche de tables de mouvements bancaires par nom : aucune table générale explicite `transactions_bancaires` ou `mouvements_bancaires` détectée ; l'audit du flux de crédit doit se poursuivre à partir des RPC et de leur journalisation réelle, plutôt que d'inférer un transfert depuis les soldes actuels.

## Suivi ciblé du prêt Jean Jaaj — lecture vivante complémentaire

- La fonction de production `pret_national_creer_interne` crée dans sa transaction un prêt, une ligne de `fonds_credits_uniques`, puis crédite `comptes_bancaires` banque `nationale` **et** `personnages_donnees.arg` de `p_montant`. Ne pas interpréter ces deux champs automatiquement comme deux versements séparés : comparer leur contrat de synchronisation.
- **Découverte capitale :** `fonds_credits_uniques` contient déjà pour `Jean Jaaj` une ligne `source=regularisation_pret_national`, `reference=pret-1792353270892`, `ordre=emprunter_construction`, `montant=100000`, `cree_le=2026-10-18 20:27:24.88506+00`. Cette ligne confirme qu'une régularisation a été enregistrée après la création du prêt (19:54 UTC), **mais ne démontre pas seule le solde effectivement crédité ni l'affichage client**.
- Conséquence : ne surtout pas ajouter une deuxième régularisation sans rapprochement des écritures, du contrat courant et des soldes. Conserver la vérification authentifiée dans la recette.
