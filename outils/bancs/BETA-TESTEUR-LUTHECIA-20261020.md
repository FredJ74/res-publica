# Bêta-testeur automatisé de Luthécia — 20 octobre 2026

## Verdict

**Exécuteur livré et testé localement ; campagne authentifiée bloquée, aucune visite réelle effectuée.**

Le lancement effectif du pilote a été tenté, avec le site de production comme cible. Il s'est arrêté avec le code 2, avant toute connexion : aucun compte de test, mot de passe, UID de test ou autorisation explicite n'est configuré dans cette session. Les lectures HTTPS publiques du site et de l'API GitHub échouent aussi au proxy (`CONNECT tunnel failed, response 403`, aucun statut HTTP applicatif obtenu). Ce refus ne prouve pas une panne de Vercel ou du jeu.

Aucun identifiant personnel recherché ou utilisé, aucune connexion détournée, aucune donnée de joueur ni migration modifiée. Aucun nouveau mécanisme de jeu, aucune modification des visuels ou des quatre vues de Port-Sainte-Marie.

## Résultats réellement obtenus

| Nature | Résultat |
| --- | --- |
| Tests du pilote, fixtures et transports simulés, dont un parcours Chromium local | **22/22**, aucun désactivé |
| Chromium local du pilote | Clics espacés, changement de pièce confirmé par une source serveur de fixture, carte et fiche produit, prix 25 FR et stock nul visibles, rejet des divergences et changements d'identité |
| Bancs client existants | **90/90** réussis, sans SQL ni compte réel |
| Prévol / tentative de campagne authentifiée | **BLOQUÉ**, code 2, zéro visite, zéro ordre réel |
| Tests authentifiés Supabase | **Non exécutés** |
| Modification serveur / migration | **Aucune** |
| Déploiement et GitHub Actions distants | **Non vérifiés**, API et site inaccessibles au proxy |
| Vérification YAML et garde-fous des deux workflows | Réussie ; environnement dédié, permissions lecture, concurrence sérialisée, délai maximal et activation conditionnelle vérifiés |
| Contrôle du workflow de dépôt | Conforme |
| Contrôles globaux | **10/12** : Authority et Referential restent rouges, sans modification des références |

Le premier passage des contrôles globaux sans l'adaptateur historique était à 9/12 : `verifier-fonctions.py` s'abstenait faute de JavaScriptCore. Le passage via le helper Node déjà documenté (`PYTHONPATH=/workspace/hg-tools`) a exécuté ce contrôle et l'a réussi. Aucun test n'a été déclaré réussi sans moteur ni aucune assertion retirée.

Les deux contrôles restants signalent les mêmes familles d'écarts que le rapport restaurant : RPC non confirmées dans le baseline archivé et empreintes de référentiels divergentes. Ce chantier n'a modifié ni les appels RPC du jeu ni les référentiels ; il n'a pas falsifié le catalogue pour les rendre verts.

## Parcours livré

L'outil `outils/e2e/luthecia.cjs` emploie Playwright et le lanceur Chromium robuste existant. Il utilise le formulaire normal de connexion, des contextes séparés pour deux comptes autorisés, puis les zones, flèches et onglets visibles. Le graphe du jeu est lu pour choisir le chemin, jamais utilisé pour téléporter ou appeler directement un moteur d'écriture.

Parcours de consultation préparé :

- Office notarial : accueil, bureau des successions, bureau des contrats et archives ; ouverture des quatre consultations sans engagement, dialogue PNJ avec requête corrélée à la question envoyée, sortie sans rechargement.
- Hôtel : accueil, bar et restaurant ; cartes, stocks, prix par article, boutons de production, fiche produit, rechargement puis sortie.
- Lectures officielles pour les positions de rue et sorties (`rue_position_lire`) ; comparaison de la fiche serveur et des miroirs locaux pour l'argent liquide, les PA, la Santé et le Moral.

**Aucun de ces lieux n'a été réellement visité dans cette session.** Le parcours Chromium local mentionné plus haut teste une page de fixture du pilote, pas une copie du jeu prétendument authentifiée.

L'achat, la production, la tournée, les invitations/réponses des deux convives, le dîner 2+2 et la réception disposent de points d'exécution contrôlés par un plan : identité, origine/backend, entreprises réservées, autorisation de scénario, handler exact, variations attendues, verdict RPC et nouveau résultat UI. Les pertes et retards de réponse peuvent être injectés sans réexécuter la requête serveur. Les doubles clics sont également pris en charge.

**Les plans sensibles propres au jeu ne sont pas encore construits ni validés sur des ressources réelles isolées.** La liste des cas requis est un inventaire de couverture attendue ; elle n'est pas présentée comme une campagne entièrement implémentée et réussie. Le pilote refuse un oracle invalide avant l'action et laisse les cas sans preuves dans `casNonExecutes`. La lecture d'un bouton de production ne démontre pas les permissions serveur.

## Sécurité, rythme et preuves

Pauses de deux à cinq secondes entre les actions, deux à quatre après les mouvements, en plus des attentes de chargement et de confirmation serveur. Délais explicites : 15 secondes pour les contrôles usuels, 30 pour les positions et actes, 45 pour navigation/authentification/dialogue ; maximum configurable de 40 minutes pour le pilote.

Une réponse ou une action destinée à un autre personnage ne peut pas poursuivre le parcours. Les actes sensibles sont journalisés avant le clic. Une reprise déclarée depuis un rapport contenant une opération exécutée ou incertaine refuse un nouveau plan financier jusqu'à réconciliation. Aucun acte perdu n'est rejoué spontanément.

Le pilote ferme Playwright puis le groupe Chromium et supprime son profil temporaire sur erreur ou arrêt. Les rapports n'enregistrent ni mots de passe, jetons, corps de requêtes, URL avec paramètres ni dialogues entiers. Les journaux conservent les opérations, statuts, catégories et empreintes d'erreurs. Aucune session, HAR ou trace Playwright avec secrets n'est exportée. Les captures sur échec nécessitent encore l'identité de test vérifiée ; aucune capture de parcours authentifié n'a pu être produite ici.

## Exécution persistante

`.github/workflows/beta-testeur-luthecia.yml` fournit un hébergement GitHub Actions : lancement manuel sur `main`, ou passage planifié **seulement si la variable de dépôt `HG_E2E_NIGHTLY` vaut `true`**. Environnement protégé `luthecia-e2e`, comptes de test par secrets, concurrence sérialisée, pilote limité à 35 minutes, job limité à 45 minutes, artefacts conservés trois jours. Aucune migration ou publication de jeu n'y est exécutée.

La configuration distante des secrets, protections et variables n'a pas pu être inspectée. Le workflow n'a pas été déclenché dans cette session. **Aucune campagne authentifiée n'est annoncée comme continuant après la fin de la session Codex.**

Le workflow client existant valide désormais le pilote sur fixtures, sans lui fournir d'identifiants. Ce contrôle ne lance pas de test sur la production.

## Accès et opérations restantes

Un opérateur technique disposant des accès appropriés doit pouvoir :

1. Identifier des comptes réellement autorisés et réservés, avec les UID exacts, et les ressources/contreparties isolées pour les opérations financières ; aucun compte ordinaire ne doit être transformé en fixture.
2. Vérifier les RPC et migrations effectivement installées, notamment les cartes et le dîner du chantier précédent, sans rejouer une migration supposée appliquée.
3. Fournir les secrets par l'environnement protégé, examiner les plans sensibles à partir de l'interface réelle et de ses reçus, puis déclencher la campagne et relire ses artefacts.
4. Corriger uniquement les anomalies reproduites avec ces preuves et retester.

La procédure détaillée se trouve dans `outils/e2e/README.md`. **Aucune manipulation SQL, GitHub ou provision de comptes n'est demandée au game designer.** Les accès manquants restent un blocage technique constaté, pas une opération réputée réalisée.

Le brouillon de configuration cloud a été sauvegardé : installation reproductible du pilote, instructions de reprise et demandes d'accès aux domaines nécessaires, en conservant les destinations existantes. Cette sauvegarde requiert publication et ne modifie pas à elle seule le réseau de l'instance ; elle ne fournit aucun compte de test.

## Fichiers livrés

- `outils/e2e/luthecia.cjs` : exécuteur et rapport structuré.
- `outils/e2e/test-executeur.cjs` : tests de sécurité et du pilote, dont Chromium local.
- `outils/e2e/package.json`, `package-lock.json` : Playwright verrouillé, sans téléchargement de navigateur supplémentaire.
- `outils/e2e/README.md` : préconditions, parcours, contrats, limites et reprise.
- `.github/workflows/beta-testeur-luthecia.yml` : campagne persistante conditionnelle.
- `.github/workflows/coherence-client.yml` : régression locale du pilote dans le job existant.
- Ce rapport et `outils/e2e/resultats-20261020.json` : résultats et blocages observés.

Aucune question de game design identifiée. Aucune correction applicative déduite artificiellement d'un test simulé.
