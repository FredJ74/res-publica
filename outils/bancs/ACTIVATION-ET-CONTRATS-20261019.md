# Du code au jeu : état d'activation et lots contrôlés — 19 octobre 2026

**CHANTIER NON TERMINÉ. Aucune fonctionnalité nouvelle vérifiée opérationnelle IG par cette session.** Des parcours supplémentaires sont raccordés et éprouvés, mais aucune migration n'a été appliquée à Supabase. Le verrouillage global des organisations n'est pas achevé.

## Accès : étape exacte bloquée

Le propriétaire confirme `234c9f1` READY en production Vercel. Cette confirmation est retenue ; elle ne prouve pas la présence des contrats SQL.

Les tentatives de cette session vers Supabase REST, le jeu et l'API GitHub Actions échouent à l'établissement du tunnel réseau avec **403 Forbidden**, avant réponse de ces services. Aucun connecteur Supabase/Vercel n'est exposé. Git fetch et push fonctionnent. Aucun diagnostic de panne de production ou de quota déduit de ces refus. Aucun essai de contournement, recherche de secrets ou déploiement par une voie détournée.

La première étape bloquée est **la lecture autorisée du registre et du catalogue vivant**. Sans elle, impossible de confirmer les sources, triggers, RLS, ACL et dépendances, de choisir les migrations absentes, de les éprouver contre le vrai schéma puis de les appliquer. Ce n'est pas une interdiction de déployer déduite d'un test local ; c'est un accès technique manquant. L'étape suivante de vérification authentifiée manque également de comptes/environnement isolés autorisés.

Aucune manipulation SQL, aucun secret ni script n'est demandé au game designer. La reprise exige un accès technique de session aux services concernés. Les appels bloqués n'ont pas été répétés en boucle ; le travail indépendant ci-dessous a continué.

## Lots existants : candidats à activation indépendante, sous préconditions vivantes

| Lot préparé | Dépendance / inspection indispensable | État distant vérifié ici |
|---|---|---|
| Réception `20261016131932` | Types d'inventaire, trois RPC, triggers/RLS, écritures concurrentes ; préserver les livraisons existantes | Non accessible |
| Assemblage correctif `20261018231225` | Moteur d'assemblage préalable `20261018234500`, définition exacte, recettes/stocks et écritures financières | Non accessible |
| Jodie `20261018231849` et complément portraits `20261019002000` | Tables et triggers interviews/forum/journal, définition existante et absence de doublon | Non accessible |
| Administration `20261019094425` | Fonctions/types/registre de reçus et ACL ; lot additif, pas dépendant des équipements | Non accessible |
| Membres `20261019130213`, progression `20261019130951` | Registre administratif, miroir des neuf types, fonctions et garde de direction | Non accessible |
| Invitation/élection `20261019132431` | Voir ci-dessous ; invitation indépendante de la validité du moteur de paiement | Non accessible |
| Refus silencieux `20261019132908` | Définitions examinées des commandes administratives et membres après progression | Non accessible |
| Équipements `20261019064000`, achat `20261019064500` | Fermeture effective des écritures générales puis contrats d'achat/finances examinés | **Non activables en sécurité à ce stade du code**, indépendamment du réseau |

Aucune liste n'est une consigne d'application aveugle par ordre alphabétique. Interroger d'abord le registre : ne pas rejouer une migration éventuellement appliquée par une autre session. Puis les quatre extractions canoniques de WORKFLOW-SUPABASE.md et le prévol ciblé en lecture seule. Ne pas adapter un hash pour faire passer un corps non examiné. Le baseline suit une application vérifiée ; aucun SQL généré du baseline n'a été édité.

## Nouveau lot : invitation, paiement électoral et publications

**Lacune constatée avant ajout :** `envoyerInvitationOrga` séparait courrier et invitation persistante ; `confirmerDeclenchementElection` séparait paiement, élection, sujet et message, avec un sujet fictif de repli dans le cache. Les contrats existants ne couvraient pas ces ensembles atomiquement.

Migration `migrations/20261019132431_organisations_invitations_elections_atomiques.sql`, nouvelle orchestration `organisation_commande_evenement` :

- Réutilisation du registre privé de reçus administratif et des mêmes clés d'intention durables ; pas de nouvelle comptabilité.
- Invitation : chef courant, organisation secrète, destinataire réel du même pays, non membre et non déjà invité. Courrier existant `mails`, marqueurs d'action du système mail existant, provenance organisationnelle et entrée d'invitation dans la même transaction. Nom échappé ; aucun moteur de messagerie parallèle.
- Élection : membre courant, pas d'élection active, délai existant de sept jours. Coût issu des deux ordres existants : **1 PA, 0 FR**, contrôlé contre `ordres_couts` et `data.js`, non fourni par le client. Paiement par **le vrai `payer_ordre` archivé**, sans primitive financière de substitution.
- Enregistrement des trois jours de candidatures puis trois jours de vote, sujet et premier message dans les tables de forum existantes. Motivation échappée, pas de succès ni de sujet local inventé si une écriture échoue.
- Même nonce : un seul paiement, courrier/sujet et reçu. Autre contenu sous le même nonce : refus. Erreur tardive : rollback du paiement, de l'élection, du sujet, du message et du reçu.
- L'invitation reste utilisable si la définition financière diffère : la garde du corps de `payer_ordre` n'est exécutée que pour l'action électorale, avant tout débit. Cas testé. Une définition de paiement inconnue bloque l'élection sans être écrasée ou acceptée mécaniquement.

Le modèle actuel n'expose ces ordres payants que pour supporters et syndicats ; aucun droit électoral supplémentaire n'est inventé pour les autres types. Leur progression générique reste celle du lot précédent.

Client : intentions seulement pour ces deux parcours lorsque le contrat est installé ; absence explicitement attestée du contrat conserve provisoirement le parcours historique. Aucun repli après panne/refus. Pas de deuxième appel à `deduireCoutOrdre` après confirmation serveur. Relecture PA/finances par le helper existant `commercePjActualiserPersonnage`, sans delta ni nouveau mécanisme de synchronisation. Relecture impossible : transaction confirmée annoncée avec actualisation indisponible, pas de PA inventés.

## Refus silencieux : contre-preuve et correction

PostgreSQL autorise un trigger BEFORE à retourner NULL : l'écriture est ignorée sans erreur SQL. Les commandes administratives/membres pouvaient alors renvoyer `ok:true` sans mutation effective. Le banc reproduit ce faux succès en retirant les nouveaux contrôles dans la base jetable, puis vérifie le correctif.

`migrations/20261019132908_organisations_refus_silencieux.sql` adapte seulement les corps exacts préparés et examinés : contrôle `FOUND` immédiatement après UPDATE/DELETE et insertion du reçu. Corps inconnu : refus avant remplacement. Transformation finale vérifiée, rejeu de migration idempotent. Cette évolution ne permet pas une fermeture générale des droits encore utilisés.

Le nouveau lot événementiel contrôle aussi la réalité des insertions mail/sujet/message, de la mutation d'organisation et du reçu. Un trigger qui lève OU ignore une de ces écritures provoque l'annulation complète. Les tests vérifient les succès après retrait du refus, pas seulement les erreurs.

## Contrôle de rues réutilisé et intégré

Deux commits concurrents `87707e1` et `c0ddcc7` ont été intégrés sans conflit avant le push : contrôle SQL transversal et suppression d'une autoliaison PSM. Leur correction de données n'est pas exécutée par cette session.

Réutilisation de `outils/bancs/controle-coherence-rues-sorties.sql`, pas de second contrôleur de graphe : enveloppe READ ONLY / ROLLBACK et correction d'un défaut démontré. `NOT (source=ANY(voisins))` ne signalait pas l'absence de retour lorsque `voisins` était NULL ; `coalesce(...,false)` traite maintenant cette absence sans modifier les règles de déplacement.

Nouveau banc PostgreSQL local intégré à la CI existante : graphe sain, cinq classes d'anomalies, retour NULL, cloisonnement par ville et interdiction effective d'une écriture dans la transaction de contrôle. Aucune rue de production modifiée.

## Vérifications exécutées

| Vérification | Résultat |
|---|---|
| Contrôleur client complet final | **84/84 bancs**, zéro échec |
| Invitation/élection PostgreSQL | **27/27 groupes** ; vrai payer_ordre et vrais triggers mail/forum archivés, identité et données bancaires de fixture |
| Client invitation/élection | **7/7** ; pas de deuxième paiement ni courrier legacy après confirmation, coûts réels contrôlés |
| Membres/élections/refus silencieux PostgreSQL | **70/70 groupes** ; dont contre-preuve du faux succès |
| Administration précédente PostgreSQL | **41/41** |
| Équipements PostgreSQL | **33/33** |
| Rues/sorties PostgreSQL | **5/5** |
| Réception / achat / assemblage / Jodie PostgreSQL | **31 / 12 / 20 / 6 groupes réussis** |
| Contre-épreuves existantes | **90/90** |
| Syntaxe API / calendrier | **23/23 modules ; 5/5 tests** |
| Payload simulé Vercel | **315,2 Mo / 330 Mo** |
| Contrôle global | **10/12** |

Tous les PostgreSQL sont jetables et locaux : aucun JWT Supabase réel, aucune donnée de joueur. Les tests ne valent ni migration distante ni parcours authentifié IG. Les résultats distants de GitHub Actions et les nouveaux SHA réellement servis par Vercel ne sont pas observables ici.

Authority : **21 RPC** utilisées absentes du baseline, contre 20 précédemment (nouvelle orchestration événementielle). Referential : mêmes écarts `ordres_couts` et `postes_nommes_regles`. Aucun test retiré, aucune référence observée ou empreinte modifiée pour masquer ces échecs. Le global utilise les dépendances locales PostgreSQL/pglast et le pont JSC/Node déjà disponible, assertions conservées.

## Informatique : réutilisation et limites

Aucune nouvelle fonction informatique déclarée opérationnelle. Le matériel/capacités reste le socle déjà développé ; aucun moteur supplémentaire de finances, inventaire, renseignement, probabilités ou transport ajouté.

| Usage demandé | Socle à réutiliser ; raccordement non réalisé |
|---|---|
| Marchés/commandes | Cours, achat, banque et fret existants ; pas de marché ni livraison parallèles |
| Caméras | Cellule de renseignement ministérielle dans `plateau-politique.js`, avec restitution organisationnelle sans ouvrir les pouvoirs ministériels |
| Renseignement informatique | Circuit d'observations/renseignements existant, dont `api/renseignements.js` ; coûts/détection à raccorder aux contrats réels |
| Intranet | Contrats d'opposition/protection à examiner ; aucun bonus arbitraire inventé |
| Papier | Tracts, presse, bulletins/documents et consommations existants ; aucune impression gratuite simulée |
| 3D | Recettes/stocks/fabrication existants, jamais création arbitraire de ressources |

Un seul ordinateur et plusieurs périphériques simultanés restent la règle du socle. Aucun mini-jeu ajouté.

## Prochaines étapes indispensables

1. Rétablir l'accès technique autorisé au catalogue/registre ; activer indépendamment les correctifs compatibles du tableau, avec préconditions, transactions annulées, extraction canonique et contrôles. Aucun SQL délégué au game designer.
2. Terminer les écritures organisationnelles réellement encore manquantes : fondation/domiciliation, actions métier et adhésions particulières, grèves, caisse/transferts/subventions, rumeurs/successions et tâches `service_role` de minuit. L'invitation initiale et le déclenchement électoral sont désormais préparés et testés : ne pas les redévelopper.
3. Migrer tous les appelants avant fermeture ; retirer sauvegardes globales et replis, verrouiller les droits directs et vérifier aussi les services privilégiés. Les accès manquants ne sont pas la seule dette : ces développements restent à faire.
4. Activer alors les équipements, puis raccorder les usages informatiques aux moteurs existants. Parcours authentifiés isolés et vérification du SHA servi nécessaires avant verdict opérationnel IG.

**Aucune migration appliquée ; aucun avoir, inventaire, livraison ou personnage réel modifié. Angie conserve intégralement ses avoirs : aucune intervention sur les 2 000 FR, le placement bloqué de 500 FR ou l'échéance.** Aucun environnement ou service payant créé, aucun paramètre distant modifié.

## Commits de sauvegarde

- `7188a35` : invitation et déclenchement électoral atomiques (rebasé sur les deux commits de rues concurrents, puis poussé).
- `b09fc51` : refus silencieux et banc de cohérence rues, poussé.
- Commit accompagnant ce rapport : contre-preuves supplémentaires, indépendance de l'invitation face à une définition financière inconnue, prévol étendu et bilan d'activation.

Dernière production confirmée par le propriétaire : `234c9f1` READY. Aucune confirmation distante du déploiement de ces nouveaux lots. L'état Git et les tests locaux ne sont pas présentés comme une fonctionnalité en jeu.
