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
- **`plateau-football-realisateur-tests.js`** — 17 assertions Node (règles dures, déterminisme,
  anti-répétition, performance, campagne 1200 matchs). `node plateau-football-realisateur-tests.js`.
- **`plateau-organisations-quetes.js`** — deux ajouts additifs :
  1. hooks sprites (`acteurMatchMiniature` / `appliquerSceneActeursPreview`, voir plus bas) ;
  2. pont debug dans `initPreviewRealisateur` (bouton "🤖 Sélection IA (debug)").

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
ponderationRarete()  →  malus par répétition récente + cooldown de famille spectaculaire
        │
tirage pondéré (PRNG seedé)  →  plan { intention, intensity, selectedGrammar, primitives, ... }
        │
[côté navigateur uniquement] résolution de selectedGrammar → SCENARIOS_PREVIEW_REALISATEUR
        │
lancerSequencePreview / executerSequenceRealisation (INCHANGÉS)
```

## Ce qui est branché ce soir, et ce qui ne l'est pas

- **Branché** : le banc d'essai preview (`?footballPreview=1`) a un bouton additif qui passe par
  le nouveau sélecteur puis appelle la même fonction d'exécution que les boutons manuels. Le
  simulateur headless tourne en conditions réelles (2000+ matchs, voir rapport).
- **PAS branché** : `jouerMicroAction` (le vrai match live) continue d'utiliser
  `genererSequenceRealisation` telle quelle. Basculer le match réel sur le nouveau sélecteur est
  un choix réversible mais visible par les joueurs — laissé à l'arbitrage de Fred (voir rapport
  final, section "points à arbitrer"), faute de pouvoir l'inspecter visuellement cette nuit.

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
