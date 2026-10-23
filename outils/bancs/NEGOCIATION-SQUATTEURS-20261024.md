# Négociation des squatteurs — arbitrages du 24 octobre 2026

Le bouton « Faire une proposition » est accessible depuis la conversation. Les PNJ restent en personnage : les agressifs insultent et menacent, sans déclencher automatiquement de combat. La discussion libre ne conclut aucune transaction.

Le serveur décide de l'acceptation, prélève 1 PA par tentative valide et verse la somme uniquement en cas d'accord. Un refus conserve les occupants et propose « Nouvelle proposition » ; le montant doit strictement dépasser le dernier refus de ce personnage pour cette occupation. Le minimum, le groupe, les organisations et l'indice social sont relus côté serveur. Le barème d'argent existant est conservé.

L'accord des sympathiques comprend la mousse et +1 Moral, plafonné à 100. Le bonus, le paiement et le départ sont dans la même transaction. Un reçu empêche tout nouveau prélèvement, tirage ou bonus au rejeu. Le terrain libéré est scellé pour éviter un nouveau tirage après le départ. Après fermeture du résultat, une relecture confirme que le terrain est encore libre avant de proposer l'achat.

## Vérifications

- 14 tests JavaScript ciblés : dialogue RP, réponses de résultat, offres refusées, taux, réessai réseau, changement de personnage, cadavre, accès à l'achat et cinq parcelles.
- CI GitHub du commit `b8f84676d0f13faf7668ad70d062f819bb33d326` : deux workflows réussis ; 59 assertions PostgreSQL sur la négociation, dont concurrence, rejouement et panne après paiement. Les autres bancs client, parcours joueur et transactions du workflow réussissent aussi.
- Migration `20261023231127_squatteurs_negociation_transactionnelle.sql` appliquée avant activation du client. Aucun compte réel utilisé par les bancs ; empreintes des soldes, PA, Moral et états de terrains identiques avant/après installation. Registres de négociation vides après installation.
- Tables privées avec RLS et sans droits clients ; aucun accès anonyme aux RPC, aucun accès client au générateur de jet. Pas de nouvelle alerte de sécurité Supabase par rapport au contrôle précédent.
- Baseline du domaine immobilier réextrait par le rendu officiel depuis les quatre exports exacts du catalogue. Les autres domaines et les références des contrôles globaux restent inchangés. La dette de synchronisation antérieure des autres domaines n'est pas déclarée résolue.

## Limites explicites

Le bonus historique de bénédiction était exclusivement local et sans colonne persistante. Il n'est pas accepté comme un taux annoncé par le navigateur. Aucun avantage de combat différent entre les deux groupes n'est inventé. Les appels DeepSeek authentifiés et le parcours complet sur un compte de production ne sont pas simulés par les bancs.

La publication du client doit être confirmée séparément par le statut de déploiement et la lecture des fichiers réellement servis.

Les bancs historiques de dépôt de permis et de construction chargent désormais leurs véritables définitions avant migration depuis des fixtures figées. La garde d’empreinte de la migration reste inchangée ; le baseline vivant conserve les protections postérieures du serveur.
