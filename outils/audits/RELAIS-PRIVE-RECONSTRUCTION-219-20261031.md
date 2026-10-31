# #219 — reprise des exports privés, 31 octobre 2026

**Non livrable en production. Aucune fusion, migration distante ou demande de déploiement.**

Main conservé : `9f6deee541ae5bfbc4083a7a7951e2743e75e5a7` (#276/#277 intégrées). Branche : `codex/groupes-universels-20261028`.

## Acquisition vérifiée et défaut réel

Le relais privé fourni par Fred a été inspecté puis exécuté après la sauvegarde du lot d'audit indépendant. `gh api` refuse la lecture des blobs avec `Forbidden`. Une autre voie autorisée fonctionne : `git fetch` de chacun des six objets, lecture par `git cat-file blob`, puis comparaison avec `git hash-object`. Les six empreintes correspondent et les six JSON se décodent. Les 1 199 définitions de fonctions correspondent aussi à leurs empreintes internes. Aucun identifiant d'objet privé ni export brut n'est publié dans cette PR.

Le registre contient 1 002 versions, dernière `20261030193635`. Le catalogue annonce 376 tables, 1 199 fonctions, 264 policies et 42 séquences. Les exports restent hors des worktrees, sous permissions privées. Aucune donnée de joueur n'a été demandée.

**Une empreinte conforme au fichier transféré ne prouve pas sa fidélité à PostgreSQL.** L'installation sur PostgreSQL natif 17.6 échoue réellement avant les fonctions : `communication/10_tables.sql`, ordre 33, SQLSTATE `22003`. Les 42 séquences ont toutes `max = 9223372036854776000`, valeur supérieure au maximum bigint, `9223372036854775807`. Le fichier vérifié contient déjà cette valeur invalide. L'écart est compatible avec un arrondi IEEE-754 pendant le transport, mais le point exact ayant introduit cet arrondi n'est pas établi. Impossible de retrouver une borne originale arbitraire en inversant un arrondi : aucune valeur n'est remplacée par une supposition.

Les fichiers SQL produits pendant cette tentative ont été retirés ; les fichiers générés versionnés et l'ancien contrôle global ont été restaurés à leur état précédent. Le nouveau contrôle global n'est pas promu partiellement. Les exports de fonctions/droits/logique sont récupérés, mais l'épreuve canonique refuse tout le jeu d'exports tant que la structure est invalide.

## Corrections de l'outillage

- `requetes.py` transporte désormais start/increment/min/max/cache des séquences en **texte décimal exact** dans l'export canonique ; aucun changement de mécanique ni de schéma distant.
- `rendre.py` accepte ce format exact, contrôle les limites du type et la cohérence des options, et refuse les données arrondies **avant toute génération**. Aucun plafonnement ou arrondi correctif. `seeds.py` conserve le recalage exact des séquences ascendantes et descendantes avec ce format.
- Le contrôle global SQL omettait trois champs pourtant lus par son vérificateur : `colonnes_de_vues`, `fonctions_security_invoker`, `tables_sans_rls`. Ils sont ajoutés à la requête, vérifiée sur PostgreSQL jetable ; aucun relevé distant n'est fabriqué pour les remplir.
- L'épreuve de reconstruction ne peut plus retourner un code de succès après une erreur de comparaison du catalogue. La fidélité n'est annoncée que si la comparaison réussit.
- 50 nouvelles tables sont explicitement classées, ainsi que les nouvelles fonctions et la vue d'archives. La liste couvre exactement les 376 tables de l'export, indépendamment du CSV. La référence de nombre/liste du contrôle est actualisée depuis ces métadonnées, pas depuis le CSV. Douze référentiels ont besoin de lignes et de comptes relevés : ils restent `non_releve`, jamais zéro inventé. La classification reste donc **rouge**. Neuf lignes CSV contenant des points-virgules descriptifs sont correctement citées, sans supprimer leurs textes.

## Tests exécutés

Preuves : `preuves-relais-prive-219-20261031/`.

- **24/24** tests d'exports/rendu/reconstruction sur PostgreSQL 17.6 natif, dont refus des bornes arrondies, texte bigint exact, options invalides, champs du contrôle global, génération de seeds sans données privées et refus explicite des relevés manquants.
- **379/379** scénarios SQL groupes, combats, interceptions, détention, radio et transports réussis sur les décors existants. Ils ne constituent pas les tests intégrés de la copie complète encore bloquée.
- **Six contre-épreuves détectées**, 379 scénarios chacune : issue fausse (2 échecs), double paiement (5), PNJ immobile (1), faux mouvement PJ (5), camion solo (4), provenance oubliée (1). Un essai supplémentaire retirant les dépendances soldats échoue à l'installation ; il n'est pas compté comme contre-épreuve métier validée.
- **144/144** bancs clients réussis. **105/105 tests Chromium locaux réussis**, sans visite de joueur réel.
- Contrôleur global : **6/12**. Workflow, fonctions, monde neuf, navigation générée, pilote et archive passent. Classification, baseline, Authority, Referential, assemblage et reconstruction restent rouges. Les observations anciennes, les cinq écarts de référentiels et les signatures manquantes ne sont pas effacés.

## Suite technique indispensable

1. L'intégrateur disposant du connecteur réextrait `export_structure` avec la requête corrigée (options de séquences en texte), puis le contrôle global complet ; fournir ces objets par un nouveau relais privé. Ne pas passer les grandes valeurs par `Number`/une conversion flottante. Les autres exports doivent rester cohérents avec ce même relevé ; s'il y a eu du DDL depuis, réextraire l'ensemble.
2. Extraire uniquement les seeds autorisés par la classification et leurs comptes, après revue de leur périmètre ; les six fichiers actuels ne contiennent pas ces lignes. Aucune table d'état vivant ou de joueur à copier.
3. Régénérer le baseline et les seeds avec les outils, vérifier toutes les empreintes/dépendances. Ne pas éditer les SQL générés ni supprimer une garde pour passer.
4. Réhorodater les **88** préparations #219 après le nouveau point de coupe, avec une table de correspondance et mise à jour des références/hachages/tests. Ne pas antidater le relevé, ne pas rejouer les migrations déjà enregistrées en base.
5. Reconstruire la copie fidèle 17.6, installer l'intégralité du bundle atomique, puis exécuter les tests sur cette copie et la recette authentifiée isolée. Préserver #258/#260 et toutes les restrictions d'Arnie.

Ces opérations restent à l'intégrateur technique ; aucune commande SQL ou manipulation de compte n'est demandée au game designer. #219 demeure ouverte, sans feu vert de fusion ou production.
