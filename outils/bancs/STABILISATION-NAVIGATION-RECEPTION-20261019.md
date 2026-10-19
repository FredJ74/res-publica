# Stabilisation : réception et navigation — 19 octobre 2026

## Bilan

Corrections de navigation codées, testées et poussées sur main. Aucun nouveau mécanisme métier ni migration créé. **Vérification indépendante de production non réalisée**, faute d'accès réseau aux services. Les équipements collectifs et leurs migrations restent inchangés et non activés par cette session.

Main repris propre à `d054567`, puis avance rapide sur `d069be2` et `6c2ab1b`. Le premier corrige la position des flèches des lots, le second invalide le cache. Ces deux modifications sont conservées. Dernier fetch avant livraison : aucun autre travail concurrent à intégrer.

## Réception atomique : installation signalée, pas de rejeu

Le propriétaire indique que ChatGPT a appliqué la migration des trois RPC et contrôlé leurs droits. Cette information est conservée comme confirmation externe ; **la migration n'a pas été réappliquée**. Aucun inventaire ni livraison de joueur n'a été modifié pour un essai.

Dans cette session, le tunnel vers Supabase REST renvoie 403 avant réponse du projet ; aucun connecteur Supabase n'est exposé. Registre, sources vivantes, ACL et parcours authentifié restent donc non vérifiés indépendamment. Aucune conclusion d'absence en production n'est tirée du baseline archivé.

Le prévol existant `outils/bancs/banc-reception-contrat-lecture.sql` est complété, sans appeler de fonction métier : lecture des versions/noms pertinents du registre, présence explicite des trois signatures, empreintes vivantes/préparées, SECURITY DEFINER, search_path et EXECUTE anon/authenticated. Enveloppe READ ONLY / ROLLBACK conservée, syntaxe PostgreSQL analysée localement (14 instructions). Il reste à l'exécuter avec l'accès technique autorisé, puis à produire les extractions canoniques du workflow. Une divergence de hash est à examiner, jamais à écraser.

Banc PostgreSQL local de réception relancé : **31 groupes réussis**. Ce résultat éprouve le contrat préparé, pas la définition réellement installée par ChatGPT. Aucun archivage de migration ou changement de version de registre inventé faute de relevé.

## Flèches, destinations et quatre vues PSM

- Lots Luthécia : retour vers `luthecia-terrains-artisanal`.
- Lots PSM : retour vers `psm-terrains-vente`.
- Flèche de retour en bas, centrée ; contrôle réel du rectangle et du clic avec Chromium à **1280 et 390 pixels**.
- Les quatre images du carrefour central PSM restent distinctes selon la provenance artisanal/phare/tribunal/église. Les zones, bandes verticales du tribunal et directions propres à chaque vue sont testées. Aucune orientation n'est normalisée en graphe symétrique dans le client.
- Les 31 scènes de Luthécia/PSM ont leurs images, destinations de flèches et sous-scènes présentes dans le dépôt.
- Comparaison d'exécution des données de `RUE_CENTRALE_NOEUDS` avant/après : **strictement identiques à `6c2ab1b`**, pour toutes les scènes. Aucun bâtiment, image, zone ou lien de carte modifié.

Les tests Chromium utilisent les vrais JS, CSS et images servis localement avec des RPC simulées. Ils vérifient le rendu, les clics et le noeud local après confirmation simulée ; ils ne vérifient pas la position Supabase d'un joueur après déploiement.

## Défauts reproduits et corrigés

Avant correction, le nouveau banc donnait six scénarios nominaux verts et sept échecs : réponses tardives après changement de contexte, double ordre simultané et animations différées envoyant un ordre pour le personnage suivant.

`plateau-rue-centrale.js` :

- Les transitions et réponses appartiennent au personnage (objet et nom), au compte, à la session, au pays/ville et au bâtiment/pièce qui les ont déclenchées.
- Un callback d'animation devenu obsolète n'envoie plus de nouvel ordre. Une réponse ancienne n'affiche plus sa scène et n'écrit plus le cache pour un autre contexte.
- Un seul déplacement serveur simultané par contexte ; verrou libéré après succès, refus ou panne. Les transitions attendent le retour de la fonction existante avant de terminer le fondu.
- Les restaurations de position sont ordonnées. Une lecture ancienne, y compris partie pendant un déplacement, ne rétablit plus un ancien noeud après la confirmation plus récente.
- Les retours asynchrones police/détachement vérifient également le contexte avant rendu.

Aucune autorité de déplacement ajoutée au navigateur : `rue_position_enregistrer` reste la porte existante ; un refus n'entraîne aucun déplacement local. Aucune modification de coût, interception judiciaire, droit d'accès ou règle de navigation.

Cache du script actualisé à `v=157`. Les fixtures d'extraction de deux bancs existants chargent les nouvelles dépendances réelles ; leurs assertions sont conservées.

## Contrôles globaux

Résultat : **10/12**.

Authority conserve **21 contrats absents du baseline**. Cela n'est pas un décompte de RPC absentes de Supabase : notamment, les trois RPC de réception sont signalées comme installées par le propriétaire. Le diagnostic indique désormais les fichiers déclarant les fonctions et la nécessité d'une vérification du registre/extraction ; une déclaration SQL ne rend aucun invariant vert. Un test vérifie cette distinction.

Referential conserve les deux divergences `ordres_couts` et `postes_nommes_regles`. Sans catalogue vivant, impossible de déterminer si le miroir distant ou la mesure archivée doit évoluer. Aucune empreinte ni observation remplacée pour masquer l'écart. Aucun SQL de baseline modifié manuellement.

## Lots indépendants restant candidats à activation

| Lot | Condition avant application | État de cette session |
|---|---|---|
| Réception | Installation déjà signalée ; lire le registre, corps et droits, puis extraire le baseline | Ne pas rejouer ; lecture distante bloquée |
| Assemblage `20261018231225` | Moteur préalable et empreinte réelle, recettes/stocks/finances | Préconditions distantes non comparées |
| Jodie `20261018231849` et portraits `20261019002000` | Tables/triggers interviews, forum et journal ; absence de doublon | Préconditions distantes non comparées |
| Administration, membres et élections | Registre partagé, signatures, sources et dépendances des lots déjà préparés | Additifs, mais installation distante non vérifiée |
| Invitation initiale et paiement électoral | Mail/forum ; pour l'élection, définition réelle de `payer_ordre` | Préconditions distantes non comparées |
| Refus silencieux | Corps exacts des commandes préparées, après progression électorale | Préconditions distantes non comparées |

Ces correctifs indépendants ne sont pas bloqués conceptuellement par les équipements ; leur activation est ici bloquée par l'accès au catalogue. Les équipements restent en plus bloqués par la sécurisation inachevée des organisations : aucune tentative de les activer, de fermer prématurément des droits ou de contourner leurs gardes.

## Vérifications finales

- Contrôleur client complet : **86/86 bancs réussis**.
- Navigation ciblée : **20/20 tests** ; Chromium rues **2/2** (1280 et 390 pixels).
- Fixtures existantes session/interception : **42/42 tests**, assertions conservées.
- Réception PostgreSQL : **31 groupes réussis** ; raccordements rues/sorties PostgreSQL : **5/5**.
- Contre-épreuves : **90/90**.
- Contrôle global : **10/12**, Authority et Referential toujours rouges, sans neutralisation.
- Syntaxe JS du module et `git diff --check` conformes ; prévol SQL analysé sans exécution distante.

GitHub Actions et jeu/Vercel inaccessibles via le proxy (403 de tunnel). Git fetch/push fonctionne. **Aucun SHA réellement servi ni parcours authentifié confirmé par cette session.** Ce refus ne prouve pas une panne de production. La nouvelle confirmation d'installation des trois RPC provient du propriétaire, pas d'une observation des outils ici.

## Sauvegarde et reprise

- `bfe3ed3` : transitions protégées, tests de navigation et Chromium ; poussé.
- `3e22150` : diagnostic Authority, lecture de registre réception et dépendances de fixtures ; poussé.
- Commit accompagnant ce rapport : bilan et limites de vérification.

Prochaine étape technique : accès autorisé au registre/catalogue, vérification de la réception déjà installée sans mutation, extraction canonique et comparaison des miroirs ; puis observation du SHA servi et des deux retours de lots sur un compte de test autorisé. Aucun SQL ni manipulation GitHub n'est demandé au game designer.

Aucune migration appliquée ni rejouée ; aucun solde, inventaire, livraison, personnage ou poste de bêta-testeur modifié. Aucun changement de game design.
