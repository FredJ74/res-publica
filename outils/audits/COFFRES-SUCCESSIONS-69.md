# Issue #69 — audit et protection préalable du règlement successoral

Les décisions de tailles, prix annuels, capacités et succession sont lues intégralement. L'ancienne offre de 600 FR/jour n'a pas été remplacée par une façade qui ferait croire les coffres opérationnels : aucun moteur bancaire multiformat complet n'est livré ici.

Défaut démontré sur le vrai `succession_regler(text)` archivé : une disposition `coffre` (ou tout type inconnu) sans branche de transfert traverse les trois seuls types terrain/entreprise/argent et reçoit malgré tout `regle=true`, puis clôture le dossier. Le contre-exemple PostgreSQL local le reproduit avant correction. Ce serait une perte comptable de transmission lors du raccordement des coffres.

La migration préparée `20261021220151_succession_refuser_actifs_non_raccordes.sql` ajoute une garde dans la sous-transaction existante de chaque disposition. Un type inconnu reste non réglé, est nommé dans `echecs`, et interdit la fausse clôture ; les dispositions reconnues indépendantes continuent. Aucune transmission fictive ni moteur successoral parallèle. Corps et droits existants conservés par patch gardé, aucun appel métier pendant le DDL.

15/15 assertions PostgreSQL locales : contre-exemple antérieur, coffre/type inconnu/type absent, indépendance d'une autre disposition, marqueurs, rejeu, argent nul reconnu, migration répétée et refus de définition divergente. Données entièrement fictives, pas de compte de joueur. Aucun coffre réel lu, modifié, supprimé ou transféré.

Reste à faire : location annuelle via le bail commun, capacité transactionnelle, stockage privé et transferts d'inventaire révisé, renouvellement/impayés, résiliation vide, ouverture/gel des dispositions avant suppression et cascade successeur/remplaçant/conjoint du moteur existant. Le parcours de suppression actuel ouvre et gèle la succession par plusieurs RPC, puis supprime le personnage ; il faut traiter toute la chaîne avant de rendre une nouvelle location disponible. Le contenu ne doit jamais passer provisoirement par l'inventaire du défunt/héritier.

Obstacle de définition confirmé : le noyau commun de `plateau-objets.js` contient id/nom/famille/catégorie/icone/régime/qty ; aucun poids numérique commun ni calcul de poids d'inventaire n'a été trouvé dans le code/SQL examinés. Les capacités 50/100/150/400 ne fixent pas à elles seules le coût de chaque référence. L’arbitrage reçu le 22 octobre fixe désormais une unité par exemplaire ou unité empilable ; ce point n’est plus bloquant. Aucun coefficient de masse physique n’est ajouté. Le calendrier affiche la date civile réelle Paris, mais la convention de renouvellement annuel et le traitement des anciens baux doivent être confrontés aux contrats vivants ; ne pas substituer simplement un prélèvement quotidien de 250 FR au vieux 600 FR.

Prévol Supabase non accessible. La garde seule est indépendante et candidate à revue, mais non fusionnée dans main/non déployée. Elle ne constitue pas la clôture de #69. Après activation éventuelle, préserver les dispositions retenues et traiter leurs erreurs ; aucun retour arrière par suppression de contenu ni restauration de vieux patrimoines.


## Précision validée le 22 octobre : occupation en unités

Une unité par exemplaire ou unité empilable. Les capacités restent S=50, M=100, L=150, XL=400. Un objet individuel compte un, même si une ancienne donnée porte un champ `qty` ; une pile compte sa quantité entière positive. Une quantité fractionnaire/invalide est refusée, jamais arrondie silencieusement. Le champ historique `encombrement` n’invente pas de poids pour ces coffres.

Une nouvelle primitive SQL privée `inventaire_occupation_unites(jsonb)` applique cette convention aux deux représentations (régime du noyau et `stackable` historique). Elle ne constitue pas une RPC de dépôt : la capacité doit être vérifiée dans la future transaction verrouillant le coffre et l’inventaire. Aucun nouveau bouton de souscription n’est activé.

La vérification du moteur commun a aussi révélé une perte reproductible : `inventaire_retirer` soustrayait la quantité demandée à **chaque ligne** partageant une `stackKey`, alors que `helvetia_inventaire_sortie` valide le total. Un retrait de 6 sur deux lignes de 4 et 5 annonçait 6 sortis, mais détruisait les 9 unités. La migration préparée `20261022115612_inventaire_unites_et_retrait_multilignes.sql` répartit le retrait une seule fois dans l’ordre des lignes, préserve les métadonnées et refuse un stock insuffisant. Elle réutilise le moteur commun, sans nouveau moteur de transfert. Avant production, contrôler les définitions et tous les appelants vivants ; les droits existants de la fonction remplacée ne sont pas élargis.

Validation du noyau : **35/35 assertions PostgreSQL locales**, plus 100 retraits générés déterministes, avec les vraies fonctions archivées de localisation/protection/extraction. Le banc reproduit d’abord la perte antérieure, vérifie les quatre seuils, les quantités invalides, les objets uniques/protégés, les métadonnées, le refus transactionnel et les définitions divergentes. Le compteur ne remplace pas encore les verrous/contrats/reçus des futures RPC de coffre. **#69 reste non terminé et non déployable** tant que baux, renouvellement, dépôt/retrait privés et succession complète ne sont pas raccordés.

## Arbitrage du propriétaire — changement de taille (22 octobre 2026)

Règle désormais validée pour le raccordement au bail commun :

- La capacité change immédiatement ; la date de renouvellement annuel initiale ne change jamais.
- Agrandissement : paiement immédiat de la différence entre le tarif annuel de l'ancienne taille et celui de la nouvelle taille (S 250, M 450, L 750, XL 1250 FR). Aucun prorata au nombre de jours, aucun remboursement. Exemple S → M : 200 FR ; M → XL : 800 FR.
- Réduction : gratuite, aucun remboursement. Le nouveau tarif s'applique au prochain renouvellement, à la même échéance.
- Réduction refusée si le nombre d'unités effectivement stockées excède la capacité cible ; aucun objet n'est déplacé ou supprimé pour la permettre.
- Le tarif comparé est celui de la taille immédiatement précédente : une réduction puis un nouvel agrandissement ne crée pas un crédit mémorisé sur un ancien paiement.

L'acte devra être transactionnel avec le paiement, la taille, le tarif de renouvellement et son reçu : refus de paiement ou capacité insuffisante = aucun changement ; même intention après réponse perdue = aucun second prélèvement. Préserver le même coffre, son contrat, son échéance et toutes les métadonnées des objets. Aucun nouveau moteur de facturation.

**Statut : arbitrage enregistré, raccordement financier et interface non encore réalisés.** Ce texte ne constitue pas une migration ni une activation. Le cycle annuel et la succession complète restent à terminer comme indiqué dans `FINALISATION-57-69-20261022.md`.
