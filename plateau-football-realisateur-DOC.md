# Réalisateur football — architecture (chantier "industrialisation du réalisateur", 30 août 2026)

Documentation courte du pipeline ajouté par ce chantier. Pour le détail des briques visuelles
préexistantes (gabarits, banc d'essai A-F, 4 effets), voir les commentaires denses directement
dans `plateau-organisations-quetes.js` (section "REALISATEUR AUTOMATIQUE", ~ligne 3419) — ce
document ne les répète pas.

## Frontière canonique / visuel

Inchangée et non touchée par ce chantier : `_liveViewerAfficheCanoniqueEnCours`,
`_liveViewerFileCanonique`, `afficherInsertCanonique` restent l'unique autorité sur les
événements sportifs. Le nouveau code ne lit et n'écrit jamais `live.evenements` /
`live.scoreHome/Away` / PA / Santé / Popularité / salaires.

## Fichiers

- **`plateau-football-realisateur-ia.js`** — module pur (zéro DOM), vocabulaire de primitives,
  intentions, registre de grammaires, matrice de compatibilité, calcul d'intensité, mémoire de
  rareté, sélecteur centralisé déterministe. Chargeable en navigateur (`window.RealisateurIA`) ou
  en Node (`module.exports`).
- **`plateau-football-realisateur-simulateur.js`** — outil de dev (jamais chargé par
  `plateau.html`), génère des matchs synthétiques et exécute le vrai sélecteur en mode headless.
  `node plateau-football-realisateur-simulateur.js --matchs=1000 --seed=xxx [--json]`.
- **`plateau-football-realisateur-tests.js`** — 25 assertions Node (règles dures, déterminisme,
  anti-répétition, raccord MR1/MR2/MR3, respiration, whitelist R0, performance, campagne 1200
  matchs). `node plateau-football-realisateur-tests.js`.
- **`plateau-organisations-quetes.js`** — additifs :
  1. hooks sprites (`acteurMatchMiniature` / `appliquerSceneActeursPreview`, voir plus bas) ;
  2. pont debug dans `initPreviewRealisateur` (bouton "🤖 Sélection IA (debug)" + TEST A/B/C) ;
  3. `trouverSequenceProductionAvecGabaritId` (résolution des gabarits de production) ;
  4. correctif MR4 dans `reinitialiserSceneApresSequenceRealisation`.

## Whitelist et statut (audit du catalogue, 30 août 2026)

Chaque grammaire porte un `statut` (`VALIDATED_PRODUCTION` / `VALIDATED_BANC_ESSAI` /
`VALIDATED_A_CONFIRMER`) et `nbPlansAttendu`/`dureeMsAttendueApprox`, vérifiés contre le code
source réel. `estAutoriseAutomatiquement()` est la porte unique du pool automatique (gate R0,
en tête de `validerCompatibiliteGrammaire`) — **exister dans le registre ne signifie pas être
autorisé** : toute future entrée non `VALIDATED_*` en serait exclue par défaut. Aujourd'hui les
22 entrées sont toutes validées (aucune `INTERNAL`/`DEBUG`/`LEGACY` trouvée lors de l'audit).

**A/B/C ne sont pas absents du registre — ils sont rares par construction** (poids 0.3–0.5 contre
1 pour les 6 gabarits, en concurrence avec la respiration et les cooldowns MR1/MR2) : sur 3000
clics simulant exactement la rotation du bouton debug, A choisi 10 fois, B 53 fois, C 4 fois.
Ne pas augmenter leurs poids sans décision explicite de Fred (voir rapport).

**Cause de "C vu comme une seule image"** : établie par test à timers réels — un second
déclenchement (n'importe lequel des 16+ boutons du banc d'essai, comportement pré-existant, pas
introduit par ce chantier) efface tous les timers en attente du précédent. `resoudreSequenceDepuisGrammaire`
retourne toujours l'objet complet (vérifié sur les 22 grammaires) ; la troncature se produit à
l'exécution si un second clic arrive avant la fin naturelle. `window.__debugRealisateurEnCours`
rend maintenant cette interruption visible dans la trace (observationnel, aucun verrou ajouté).

## Pipeline

```
situation (micro-action déjà connue, étape coup franc déjà résolue, ou rien pour un
canonique nu — ces derniers restent gérés par afficherInsertCanonique/afficherAmbiancePhase)
        │
formeSituation()  →  'micro' | 'coupfranc' | 'canonique' | null
        │
intentionsAutoriseesPourSituation()  →  liste d'intentions dramatiques possibles
        │
calculerIntensiteRealisation()  →  0..1, signaux PRÉSENTS uniquement (jamais le futur)
        │
grammairesEligibles()  →  validerCompatibiliteGrammaire() par entrée du registre
        │  (règles dures : carton/blessure jamais mis en scène, résultat canonique requis avant
        │   sélection d'une grammaire "but"/"arrêt", forme de situation stricte, intention requise)
        │
+ injection de la respiration (id __respiration__, forme 'micro' uniquement) → concurrent normal
        │
appliquerReglesRaccord()  →  MR1 (spectacle→spectacle sans respiration), MR2 (spectacle juste
        │   après une réaction terminale), MR3 (chaîne coup-franc brute déprioritisée si sa
        │   variante raccordée est éligible) — jamais un blocage total du pool
        │
ponderationRarete()  →  malus par répétition récente + cooldown de famille spectaculaire
        │
tirage pondéré (PRNG seedé)  →  plan { intention, intensity, selectedGrammar, primitives,
        │   etatSortie, isRespiration?, ... } — memoire.dernierEtatSortie mis à jour (sauf
        │   respiration/plan nul, qui ne changent pas ce que le spectateur regarde encore)
        │
[côté navigateur uniquement] résolution de selectedGrammar :
        │   source==='production' → trouverSequenceProductionAvecGabaritId (rejoue
        │     genererSequenceRealisation jusqu'au bon gabaritId, même principe que
        │     trouverSequenceCrashTestRasDuSol) ; sinon → SCENARIOS_PREVIEW_REALISATEUR
        │
lancerSequencePreview / executerSequenceRealisation (INCHANGÉS)
```

## Montage continu / raccord (ajouté suite au retour "les enchaînements ne paraissent pas
## naturels" en production)

Chaque grammaire déclare un `etatSortie` léger, audité directement dans les sequences réelles
(jamais inventé) : `medium` ('miniature'/'illustre_image'/'illustre_pictogram'/'illustre_video'),
`reactionTerminale` (dernier plan = vidéo/aftermath assumée — seulement vrai pour F1/F2 et leurs
chaînes), `resolutionAssumee`, `retourTerrainInclus`. `memoire.dernierEtatSortie` porte cet état
d'un appel du sélecteur à l'autre.

**Respiration** (`RealisateurIA.ID_RESPIRATION`) est une troisième issue de premier ordre, à côté
d'un plan réel ou d'un rejet : "ne rien montrer de nouveau, laisser le mini-terrain continuer".
Boostée après une réaction terminale (×4) ou un spectacle récent (×2.5) — paramètres dans
`PARAMETRES_RACCORD`. Sur la campagne de référence (2500 matchs), 72679/153000 sélections
(~47%) sont des respirations : le mini-terrain est redevenu la couche de continuité dominante.

**Cause factuelle des clics sans réaction** (mesurée, pas supposée) : avant correctif, le pont
debug ne savait résoudre que les grammaires du banc d'essai preview — 48,6% des clics simulés ne
produisaient aucune réaction visible (39,5% gabarit de production sans scénario preview dédié,
8,3% carton adversarial légitime, 0,8% id mismatch `crash_test_ras_du_sol`/`plan_unique`).
Corrigé : les grammaires `source==='production'` sont maintenant résolues via
`trouverSequenceProductionAvecGabaritId`. 0% de résolution échouée sur 3000 clics simulés après
correctif (voir rapport pour le détail).

**MR4** : `reinitialiserSceneApresSequenceRealisation` fixe désormais explicitement
`pelouse.style.transition = 'transform .4s ease'` avant `scale(1)`, au lieu d'hériter la
transition laissée par le dernier plan joué (source concrète des retours à l'état neutre
incohérents d'un enchaînement à l'autre). Fonction partagée avec le vrai match live — amélioration
de cohérence visuelle mineure, pas une bascule de sélection.

## Ce qui est branché ce soir, et ce qui ne l'est pas

- **Branché** : le banc d'essai preview (`?footballPreview=1`) a un bouton additif qui passe par
  le nouveau sélecteur puis appelle la même fonction d'exécution que les boutons manuels. Le
  simulateur headless tourne en conditions réelles (2000+ matchs, voir rapport).
- **PAS branché** : `jouerMicroAction` (le vrai match live) continue d'utiliser
  `genererSequenceRealisation` telle quelle. **Consigne explicite de Fred (30 août 2026, après
  test visuel du bouton debug en production) : ne pas brancher `jouerMicroAction` sur le nouveau
  Réalisateur tant que les raccords n'ont pas été validés visuellement.** Ce chantier reste donc
  strictement additif/preview jusqu'à nouvel ordre.

## Registre de grammaires — comment en ajouter une

Ajouter une entrée dans `REGISTRE_GRAMMAIRES_REALISATEUR` (`plateau-football-realisateur-ia.js`) :
`id` (doit correspondre à un id réel dans `SCENARIOS_PREVIEW_REALISATEUR` ou
`POOL_GABARITS_REALISATEUR` côté navigateur), `declencheurs` (sous-ensemble de
`['micro','coupfranc','canonique']` — jamais vide), `microActionsCompatibles` /
`coupFrancEtapesCompatibles` / `canoniquesCompatibles` selon la forme, `resultatCanoniqueRequis`
si la grammaire montre un but/arrêt, `intentionsCompatibles`, `familleRarete`, `poidsBase`,
`spectaculaire`. Ne jamais recoder la séquence visuelle elle-même ici.

## Rareté — paramètres de prototype (`PARAMETRES_RARETE_REALISATEUR`)

`memoireTailleMax:10`, `cooldownFamilleSpectaculaire:4`, `cooldownIdExact:2`,
`malusRepetitionImmediate:0.05`, `malusParOccurrenceRecente:0.35`. Valeurs de prototype
documentées, à ajuster après retour visuel réel — jamais un équilibrage artistique définitif.

## Hooks sprites (prototype, aucun asset)

`acteurMatchMiniature` renseigne désormais `animation` ('idle'/'run'), `animationSpeed` (1),
`frozen` (false), et quand un déplacement est détecté : `direction` (8 valeurs), `mirrored`
(true pour W/SW/NW), `directionArt` (art réel à utiliser, avec mirroir pour W/SW/NW — convention
5 arts + mirroir déjà validée). `appliquerSceneActeursPreview` les recopie en attributs `data-*`
inertes sur le DOM (aucune règle CSS ne les lit aujourd'hui — rendu "Smartie" strictement
inchangé). FREEZE/TIME_RAMP ne pilotent pas encore ces hooks (pas de sprite à animer) — la
prochaine étape serait de faire varier `frozen`/`animationSpeed` par situation avant de brancher
un vrai renderer sprite.

## Lancer les vérifications

```
node plateau-football-realisateur-tests.js                                  # 17 assertions
node plateau-football-realisateur-simulateur.js --matchs=2000 --seed=xxx    # campagne lisible
node plateau-football-realisateur-simulateur.js --matchs=2000 --seed=xxx --json > out.json
```

Nécessite Node (absent de l'environnement de développement habituel de ce dépôt au moment de ce
chantier — voir rapport final, section K, sur l'installation locale utilisée cette nuit).
