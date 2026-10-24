# #135 — reprise du parcours terrain, 25 octobre

## Correction de reprise côté client

Après une réponse perdue, `constructionReconcilierCommandes` retrouvait le reçu et relisait les finances, puis effaçait l’intention avant de connaître le terrain courant. La lecture appelée ensuite par `chargerTerrainState` pouvait échouer : l’écran gardait un terrain ancien, sans preuve de reprise en attente. Le test combinant les deux vraies fonctions reproduit ce défaut avec l’ancien code.

La réconciliation attend désormais une lecture distante réussie du terrain, puis des finances et du bail si nécessaire. Elle conserve l’intention en cas d’échec ou de changement de contexte. Elle ne charge pas le snapshot ancien contenu dans le reçu. Une option interne du lecteur existant empêche d’appeler récursivement la réconciliation ; ce n’est ni une nouvelle route de navigation ni un contournement serveur. Aucun débit ni mutation métier client ajouté.

Fichiers : `plateau-construction-commandes.js`, `plateau-justice-economie.js`, versions de cache de ces deux scripts dans `plateau.html`, `banc-construction-commandes.cjs`. Dix tests ciblés réussis, dont cinq nouveaux : reprise avec terrain actuel, panne de lecture, panne financière après lecture, réponse destinée à un ancien personnage, contre-épreuve de l’ancienne perte d’intention. Contrôleur client : 111/111 après intégration de main `6a249a1`.

Aucune migration nécessaire pour **cette correction de reprise seule** : elle emploie les lecteurs de reçu, de terrain et de finances déjà utilisés. Elle ne remplace pas le prévol et l’installation coordonnée des quinze migrations terrain/banque de la livraison précédente. Ne pas fusionner la branche entière pour livrer quelques lignes indépendantes. Les audiences/BNE et leurs arbitrages restent au chantier de Claude.

Aucune fusion, installation Supabase ni vérification authentifiée en jeu par Codex. Les résultats décrivent des tests locaux.
