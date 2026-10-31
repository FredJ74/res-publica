# Autorités concurrentes — premier lot isolé, 31 octobre 2026

Base : main `9f6deee541ae5bfbc4083a7a7951e2743e75e5a7`. Branche : `codex/audit-chemins-historiques-20261031`.

Ce lot est réalisé pendant le blocage extérieur de reconstruction de #219. Il ne clôt ni #219 ni l'audit serveur global. Le script privé d'exports a depuis été reçu : son exploitation reprend après la sauvegarde de ce lot, conformément à la consigne de Fred.

## Corrections livrables

L'analyse Acorn des 58 scripts réellement chargés révèle quatre doubles définitions globales. Les copies identiques de `openWorldMap`, `closeWorldMap` et `doSesoigner` sont retirées ; leurs implémentations existantes restent respectivement dans navigation et personnage. Les règles de soin ne changent pas.

Les deux `voterElection` se masquaient : la variante nationale calculait localement des voix, dont des voix PNJ aléatoires, alors que la variante organisation possédait une autre signature. Le moteur organisation est nommé `voterElectionOrganisation`, ses boutons sont raccordés et son contenu est conservé. Un adaptateur garde les anciens appels : deux arguments délèguent à ce moteur, un seul ouvre le tableau électoral national existant. Les anciens écrans de candidature/vote nationaux ouvrent désormais `ouvrirTableauElectoral`, sans fabriquer de scrutin ou de résultat. Le cache des anciennes sauvegardes n'est pas effacé. Une fonction de candidature morte sans appel retrouvé est retirée.

Les versions de cache des quatre scripts modifiés sont montées. Deux bancs reprennent les dépendances de caisse déjà corrigées sur #219 : aucune logique commerciale ou immobilière n'est modifiée.

## Inventaire des chemins encore à contrôler

Ces constats portent sur le code exécutable de main ; le catalogue archivé ne prouve pas l'état de production.

| Domaine | Appel et constat | Autorité / suite nécessaire |
|---|---|---|
| Déplacements | `enterRoom`, `deplacerGroupeAvecPj` et `quitterGroupe` modifient encore des miroirs locaux. `sortirBatiment` utilise déjà les confirmations serveur. | Réconcilier avec les migrations universelles de #219, sans deuxième moteur ni fermeture prématurée d'une compatibilité nécessaire. |
| Combat / police | `confirmerSubtilisationExplosif`, accessible par `acheter_bombe_illegale`, appelle `militaire_subtiliser_tenter`, puis traite localement PA, inventaire et QHS. La définition archivée débite déjà les PA et renvoie un objet sans révision. `procederArrestation` possède aussi des appelants institutionnels. | Vérifier les vrais contrats et leurs conséquences transactionnelles dans les exports ; ne pas généraliser les exceptions légitimes telles que les députés PNJ. |
| Inventaire | `removeFromInventory` et `executerReceptionInventaire` utilisent les contrats serveur versionnés : ils sont conservés. Le soin canonique consomme via ce circuit puis ajoute localement de la santé. | Ne pas poser le verrou final interdit par Fred ; audit des mutations restantes et coordination avec le chantier fiche de Claude. |
| Argent / recrutement | Le bouton PNJ codétenu mène à `confirmerRecrutementCodetenu` : prix, caractéristiques et employé ajoutés localement. | Réutiliser le recrutement canonique après identification des profils et du contrat réel ; aucun profil ni nouveau tarif inventé. |
| Immobilier | L'ordre terrain `donner_argent_pnj` mène encore à `confirmerDonArgent`, avec argent et tirage locaux. | Transmettre à Claude, responsable immobilier ; aucun moteur immobilier modifié ici. |
| Élections / permissions | Anciens boutons nationaux et double signature de vote corrigés dans ce lot. Le traitement organisation existant garde ses contrôles et sa compatibilité. | Cette correction ne prétend pas fermer toutes les anciennes RPC ou garantir les politiques RLS vivantes. |

`outils/auditer-etats-client.py --appels` réutilise l'outil existant et produit les définitions, appels directs et boutons, mutations et appels SQL. L'analyse est conservatrice : un chemin statique n'est pas une exécution authentifiée ; appels dynamiques non résolus et absence de chemin ne prouvent pas du code mort. Les preuves compressées contiennent 931 descriptions d'opérations et les emplacements précis. Aucun export privé du catalogue n'y figure.

## Vérifications

Preuves et empreintes : `preuves-chemins-historiques-20261031/`.

- 25 tests ciblés réussis, dont reproduction du vote local ancien qui échoue aux mêmes garanties et réintroduction de doublons détectée.
- 131/131 bancs clients réussis.
- 105/105 tests Chromium réussis.
- 41 assertions organisations sur PostgreSQL natif 17.6 jetable réussies, avec identités de test ; aucune connexion de joueur réel.
- Contrôle Workflow conforme. Aucun résultat Authority/Referential présenté comme vert : leur clôture nécessite toujours la reconstruction canonique de #219.

Aucune migration créée ou appliquée, aucune donnée de production consultée ou modifiée, aucun déploiement. Les risques serveur du tableau restent ouverts. Prochaine étape : exploiter le relais privé, reconstruire #219, puis poursuivre cet audit à partir des véritables contrats.

## Complément après récupération du catalogue privé

La reprise de #219 a pu récupérer les quatre exports et le registre. Les 1 199 définitions correspondent à leurs empreintes internes. La reconstruction complète reste bloquée par des bornes de séquences impossibles déjà présentes dans le fichier transféré ; voir `RELAIS-PRIVE-RECONSTRUCTION-219-20261031.md` sur la branche #219, commit `a0a465c1`.

Les corps exportés confirment `militaire_subtiliser_tenter(text)` : débit serveur de 2 PA et concaténation directe d'inventaire ; la consommation canonique met bien à jour l'inventaire, mais n'applique pas à elle seule le soin de santé du client. `inventaire_sauver_revision` possède encore le chemin d'observation des ajouts interdit, conformément au verrou final différé. Aucune de ces portes n'est fermée aveuglément ici : leurs remplaçants et conséquences doivent être validés sur la reconstruction et coordonnés avec #219/Claude.

Un autre défaut démontré est corrigé : après une réponse bancaire absente ou perdue, `confirmerVirementJoueur` affirmait qu'aucun prélèvement n'avait eu lieu. Le client ne peut pas le savoir. Il annonce maintenant une confirmation indisponible et demande de consulter le compte avant de renouveler la demande. Aucun nouvel appel, mouvement financier ou mécanisme de reprise ajouté. La règle et le moteur bancaires restent inchangés. Cinq tests couvrent réponse perdue, erreur de transport, exception, refus métier et succès confirmé ; le cache du script est monté. Cette correction ne garantit pas l'idempotence d'un virement renouvelé manuellement.

Les tests ciblés comprennent désormais 14 cas de chemins historiques et les 16 cas organisations conservés. Le lot est sauvegardé sur sa branche ; la création de PR par `gh pr create` a été refusée par l'API GraphQL (`Forbidden`). Aucun contournement des permissions tenté. L'audit serveur global reste ouvert et n'est pas livré en production.

Après le complément : 131/131 bancs clients repassés. Contrôleur global de cette branche : 5/12 ; six axes de baseline restent rouges et le contrôle fonctions ne peut pas mesurer sans JavaScriptCore. Cette limite environnementale est distincte du 6/12 de #219, qui contient déjà son lanceur JavaScript portable. Aucun contrôle supprimé.
