# Centre artisanal et stade — 24 octobre 2026

Suite aux tests de Fred. PR #136 ; défaut du stade suivi dans #137. Ce lot reste distinct des terrains.

## Comportement livré

- Henrico est un référent de sécurité privée employé par Grobras Sécurité. Dès le premier conseil, il indique l'agence du Centre d'Affaires et oriente vers Gaston Grobras ou Sandra Pelle. Le Centre Artisanal est son affectation, pas son employeur. Il explique son métier en personnage sans promettre de contrat conclu dans une discussion.
- La fiche de Céd' Labone propose « Acheter une boulette — 50 FR », avec confirmation. Une boulette de shit (résine de cannabis), illégale, occupe une place dans l'inventaire. Aucun effet de consommation n'est ajouté dans ce lot. Le paiement utilise les fonds ordinaires, liquide puis complément national, sans toucher aux placements ni à Helvetia. Aucun PA supplémentaire n'est facturé.
- La transaction réunit débit, ajout d'inventaire versionné, preuve `achat_drogue` dans `actions_tracables` et reçu UUID. La preuve alimente les lecteurs existants de rumeurs/enquêtes ; une formulation de rumeur est ajoutée. Pas d'arrestation automatique ni de condamnation inventée. L'objet rejoint le contrôle générique des objets `legal:false`.
- Une réponse perdue conserve le même UUID, y compris après rechargement dans le même onglet. Le rejeu rend l'inventaire et les fonds actuels. La discussion IA ne verse ni argent ni marchandise. Ced peut nommer son offre et oriente vers Pat Hounette pour les groupes criminels.
- Les deux entraînements quotidiens se comptent sur `cree_le`, entre deux minuits Europe/Paris. Le jour personnel et l'ordre dormir ne réinitialisent plus le quota. Les lignes historiques restent inchangées et comptent à leur véritable date. L'affichage explique la limite et sa remise à zéro à minuit.

## Migrations réellement installées

- `20261024074120_centre_artisanal_achat_ced`.
- `20261024074129_football_quota_jour_commun`.

Les noms des fichiers suivent les versions du registre Supabase. Aucun achat ni entraînement de personnage réel n'est exécuté par les migrations. Aucun ancien compteur ni historique n'est effacé.

Le reçu est fermé aux accès directs clients, RLS active ; seule la commande authentifiée est exposée. Le compteur interne n'est pas exécutable par les clients. Les avis Supabase nouveaux correspondent à ces choix explicites : registre fermé sans policy et porte transactionnelle SECURITY DEFINER authentifiée avec contrôle d'identité. Aucune ouverture anonyme.

## Vérifications et limites

- Banc PostgreSQL natif sur base jetable : vrais corps SQL, fonds ordinaires et garde de révision ; identité et monde fictifs. Authentification absente, mauvais lieu, inventaire plein, fonds insuffisants, fonds mixtes, livraison, reçu, rejeu, reprise hors du lieu, panne au dépôt de preuve ou reçu, achats simultanés. Football : hier/aujourd'hui avec jour personnel figé, sommeil simulé sans nouveau quota, troisième refus sans PA débités, concurrence et changements d'heure été/hiver.
- Banc client : double clic, réponse perdue et rechargement conservant UUID, reconnexion sans recopie sur un autre personnage, refus sans objet local, vrais choix du stade actifs/désactivés, prompts Henrico/Ced et formulation des rumeurs. Les bancs existants de conversation et squatteurs restent applicables.
- Avant/après installation, les empreintes des comptes bancaires, traces et entraînements sont identiques ; le registre d'achats est vide. L'empreinte globale des personnages a changé pendant la période de vérification : elle n'autorise donc pas à affirmer que tout le monde vivant est resté identique. Les migrations n'ont aucune instruction de mutation de ces personnages ; aucune correction de données joueur n'a été tentée.
- Baseline des domaines `socle PNJ` et `sport` régénéré par les outils officiels depuis les quatre requêtes officielles, puis sélection des seuls domaines concernés. Autres domaines conservés ; aucune référence de contrôle élargie pour masquer une dette. Les 79 fonctions réextraites et empreintes de fichiers sont vérifiées.
- Pas de conversation DeepSeek payante, pas de compte joueur utilisé pour acheter ou s'entraîner. La recette authentifiée reste distincte des tests sur fixtures et de la vérification du déploiement.

## Défaut de couverture de l'audit initial

L'audit Luthécia n'a pas identifié la dépendance du quota sportif à `personnages_donnees.day`. Les contrôles de calendrier réussis ne validaient pas ce parcours. Il ne fallait pas laisser penser qu'ils le couvraient.

La vérification doit désormais inclure, pour chaque quota quotidien audité : source de date serveur, franchissement de minuit sans dormir, sommeil dans la même journée, historique conservé et requêtes concurrentes. Le banc livré met ces scénarios en CI pour le stade. Il ne constitue pas une nouvelle validation globale de tous les quotas du jeu.
