# Construction et immobilier #94 — état au 23 octobre 2026

**CHANTIER NON TERMINÉ. Aucune fusion ni application en production réalisée dans cette intervention.** Le développement n'est pas seulement bloqué par les accès : des parcours métier restent à terminer. Aucun test sur les personnages réels, aucun solde ni inventaire de joueur modifié.

## Code réalisé et sauvegardé

Le dernier main `33910be` est intégré dans les trois branches ; ses nouveautés commerciales et graphiques sont conservées. La consolidation générale n'est pas fusionnée.

| Branche | Base conservée | Corrections principales |
|---|---|---|
| codex/urbanisme-documents-94-20261023 | PR112 f467411 | Archives attestées, SAS canonique et idempotent, décisions et instruction quotidiennes transactionnelles, gardes des anciennes écritures. |
| codex/occupation-fiabilisation-94-20261023 | PR113 98aa542 | Réapplication contrôlée, fin de visite liée aussi à la ville, création paresseuse depuis le catalogue déclaré sans écraser les caractéristiques persistantes. |
| codex/lots-reamenagement-94-20261023 | PR114 04dd178 | Travail des tiers raccordé, réaménagement dans les commandes/journées/réception communes, protections des anciens actes de lots, signature du bail et premier loyer atomiques, matériaux/prix partagés, préservation des fonds existants et refus de création avant débit de l'apport. |

Commits de développement de cette dernière branche : `45f0c9f`, `9bcc451`, `5223a9f`, `aa57cbb`, `38de5de`, avec intégration de main `82e1c42`. Urbanisme : `14a79cb`, `c4a9ec5`, intégration `79d8511`. Occupation : `3425d37`, intégration `06c30a5`, inventaire des données absentes `2d9ce0d`. Les commits de documentation suivants ne modifient pas les règles.

La création de chacune des trois PR a été tentée et refusée par l'API GitHub : `Forbidden`. Les branches sont poussées. Aucune des PR112/113/114 n'a été fusionnée par cette intervention ; aucun numéro de PR nouvelle n'est inventé.

## Vérifications exécutées

| Contrôle | Résultat |
|---|---|
| Bancs client — urbanisme / occupation / lots | 94/94 ; 93/93 ; 96/96 |
| Contre-épreuves — lots | 90/90 |
| Contre-épreuves — urbanisme, avant ajout du journal de ventes de main | 91/91 |
| Bancs PostgreSQL du workflow de la branche lots | **23/24**, budget de réaménagement rouge |
| Pilote joueur sur fixtures | 69/69, aucun compte réel |
| Calendriers et contrôles Node dédiés | 11/11 |
| Contrôles globaux | **10/12** : Workflow vert ; Authority et Referential rouges |

Tests spécifiques supplémentaires : documents urbanisme 54 assertions + 56 du dépôt, occupation 32, travailleur tiers 9 + 62 du moteur, réaménagement 23 + 62, miroirs de lots 14 + 62, location 30 + 62, matériaux de réaménagement 12 en plus des scénarios d'origine. Les répétitions du moteur ne sont pas comptées comme de nouveaux scénarios uniques. PostgreSQL est réel et jetable ; identité, calendrier et certains services annexes sont simulés. Les tests de transport simulent les pertes de réponse et vérifient les reçus ; ils ne constituent pas des essais réseau authentifiés Supabase.

Les assertions de rollback comprennent les contreparties, stocks, baux, fonds et reçus concernés. Les tests historiques n'ont pas été désactivés ; leurs attentes de routage ont été adaptées aux commandes communes, avec les mêmes garanties et des scénarios comportementaux additionnels.

## Échec réel conservé

Pour 100 m², le tarif est 1 000 FR : matériaux 300 FR, travail 700 FR. Le panier historique arrondi coûte 305 FR (20 bois, 10 minerai, 7 métal), laissant 695 FR : 9 heures payables et 90 % de progression. Le financement est plafonné au prix total. Le contrôle exige toujours un chantier finissable ; il échoue et reste exécuté en CI. Aucun prix, salaire, résultat ou empreinte n'a été modifié pour le faire passer. L'arbitrage demandé est soit un panier respectant le budget, soit un apport complémentaire ; aucune réponse n'est présumée.

## Parcours encore inachevés

- Interactions d'occupation : négociation persistante, police/enquête de trois jours, dissimulation, neutralisation et gros bras. Les quatre situations et visites sont persistantes, mais cela ne termine pas les conséquences. Les profils déclarés donnent le même métier citoyen aux deux squats, sans barème de résistance distinct ; la définition de `combat_coup_resoudre`, référencée par la police préparée, manque au catalogue archivé. Ne pas inventer un second combat ou une bataille militaire fictive.
- Acquisition financée #65 : la signature et l'empreinte de `pret_national_contracter` sont connues par observation fournie, pas son corps dans le dépôt. Les conditions des prêts immobiliers ne sont pas définies ; les règles travaux ne leur sont pas substituées. Aucun ancien prêt recrédité.
- Vols et sécurité privée du chantier : encore à regrouper avec leurs effets dans les moteurs communs autoritaires. Ne pas assimiler les tests de progression aux tests de combat/sécurité.
- Exploitation complète des nouveaux lots : le résolveur de vocation archivé ne reconnaît que les centres statiques. La création refusée ne perd plus son apport ; les fonds déjà existants gardent leurs liens/transferts. Cela n'active pas encore tous les nouveaux fonds dynamiques. Références typées, paiements historiques, tarification des lots initialisés à loyer zéro et liens avec les titres de lots vendus restent à achever/rapprocher du catalogue vivant.
- Superficies : 11 absences dans le code sur 36 parcelles déclarées, dont quatre à Port-Sainte-Marie et une à Montrouge. L'inventaire JSON de la branche occupation ne prétend pas mesurer la base ; les états persistants peuvent être plus complets. Aucune superficie ou valeur existante n'est uniformisée ni inventée.

## Pourquoi les contrôles globaux restent rouges

Authority constate une signature de migration non attestée (`acheter_produit_commerce_interne`, migration Fontaine déjà sur main) et 33 RPC absentes du baseline archivé, dont certaines ont une migration préparée et d'autres une définition à extraire. Une déclaration SQL ne prouve pas son installation. Referential relève les divergences d'ordres_couts, postes_nommes_regles et miroirs_entreprises ; la mesure historique des ressources compte encore 17 entrées alors que le client en décrit 18. Les déclarations, observations et empreintes du baseline sont conservées. L'absence du catalogue vivant empêche de trancher la concordance réelle ; elle ne dispense pas de terminer le code listé ci-dessus.

## Migrations et déploiement

**Aucune migration de production appliquée.** Les scripts préparés et leurs dépendances sont décrits dans `URBANISME-94-20261023.md`, `OCCUPATION-SUITE-94-20261023.md` et `LOTS-REAMENAGEMENT-94-20261023.md` sur leurs branches respectives. Les dernières migrations de lots vont de `20261023090008` à `20261023092229`. Ne pas fusionner la branche WIP tant que son contrôle budget et les parcours critiques restent ouverts.

Prévol prévu : `outils/bancs/prevol-cloture-construction-94.sql`, transaction en lecture seule. Il examine registre, signatures, corps et empreintes, colonnes/droits, RLS et triggers, ainsi que les superficies persistantes sans noms de joueurs. Le connecteur Supabase n'est pas disponible dans cette session et l'accès direct a déjà été refusé CONNECT 403 : le prévol vivant n'a pas été exécuté. Aucun déploiement Vercel ni fonctionnement authentifié en jeu n'est confirmé.

Ordre du paquet à examiner : PR112 → PR114 → urbanisme → correctifs de lots. Il faut vérifier les gardes et dépendances avant chaque script ; ne pas appliquer aveuglément toutes les migrations par nom. Aucune importation des coffres ou successions de la consolidation. Après résolution des points ouverts : revue des PR limitées, prévol vivant conforme, tests authentifiés sur environnement isolé autorisé, validation des transactions, puis seulement activation contrôlée. En retour arrière, conserver données, reçus et protections serveur ; ne pas rouvrir les anciennes écritures permissives.

Les résultats machine sont dans `VERIFICATIONS-CLOTURE-CONSTRUCTION-94-20261023.json`. Les rapports n'annoncent ni clôture, ni feu vert production.
