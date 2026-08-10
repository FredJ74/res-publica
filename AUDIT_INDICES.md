# Audit des indices — Phase 1 du chantier "refonte des ordres"

Date : 2026-08-08/09. Investigation uniquement, aucun code modifié à ce stade.
Objectif : inventaire complet de tous les indices du jeu (nationaux, locaux, religieux) avant de bâtir une refonte cohérente du système d'indices en lien avec les taux de réussite des ordres.

## Vue d'ensemble : 3 systèmes distincts

1. **`INDICES_NATIONAUX`** (`data.js:5825`) — 4 indices officiels par empire (+1 ajouté après-coup) : **ISN, IE, ID, IS, IP**.
2. **`INDICES_VILLES`** (`plateau-divers.js:150`) — même 4 indices que ci-dessus, déclinés par ville. Structure prévue pour les 4 empires × 3 villes, **mais seule Luthécia (Republia) est peuplée**.
3. Deux propriétés fantômes (**`.POP`**, **`.INF`**) écrites directement sur `INDICES_NATIONAUX` par erreur, hors de tout système officiel.

Valeurs de départ (`INDICES_NATIONAUX`) :
```
republic: { ISN: 30, IE: 50, ID: 40, IS: 45 }
narco:    { ISN: 15, IE: 30, ID: 20, IS: 25 }
soviet:   { ISN: 70, IE: 40, ID: 30, IS: 35 }
khalija:  { ISN: 60, IE: 65, ID: 50, IS: 40 }
```
`IP` n'existe dans aucune de ces définitions initiales — il est ajouté dynamiquement (`if (!INDICES_NATIONAUX[pays].IP) INDICES_NATIONAUX[pays].IP = 40;`) à 40 par un bloc d'init exécuté au chargement de `data.js`.

---

## ISN — Indice de Sécurité Nationale

**Définition** : niveau de répression/contrôle policier du régime. Affiché comme "Sécurité" dans les grilles.

**Modifié par** : très largement — mobilisation policière, campagnes de sécurité (mairie), corruption de fonctionnaires ratée, incendies détectés, saisies, taxe foncière au-delà de 25% (`if (tauxTotal > 25) ISN -= ...`), et une douzaine d'autres actions (`plateau-politique.js` principalement).

**Ce qu'il modifie réellement** (3 fonctions consommatrices distinctes, quasi-identiques) :
- `getMalusISN()` (`plateau-politique.js:4789`) — **la vraie source utilisée en jeu**, 20 sites d'appel dans `plateau-navigation.js`/`plateau-actions-illegales-rumeurs.js`/`plateau-justice-economie.js` : soustrait un malus (0 à 25) au taux de réussite de quasiment tous les actes illégaux (contrebande, corruption, meurtre, kidnapping, etc.).
- `getMalusIllegal(country)` (`data.js:5832`) — **formule strictement identique** à `getMalusISN()`, mais utilisée nulle part sauf pour l'affichage du tableau de bord des indices (`plateau-politique.js:3179`). Doublon mort en pratique.
- `getMultDetection(country)` (`data.js:5841`) — calcule un multiplicateur x1/x2/x3 selon l'ISN, **affiché** dans le même tableau de bord ("taux de détection x2")… **mais jamais réellement appliqué**. `checkDetection()` (existe en double, identique, dans `plateau-actions-illegales-rumeurs.js` et `plateau-justice-economie.js`) calcule le taux de détection uniquement à partir de `acte.detectRate - DIS/10` — **aucune référence à l'ISN ni à ce multiplicateur**. Vrai trou : le joueur voit "x2" affiché, mais ça n'affecte jamais le vrai jet.
- Génération de PNJ sur terrain vague (`plateau-pnj.js:1651-1656`) : ISN influence la probabilité de squatteurs/inspecteur/terrain vide.

**Aussi lu par** : évasion de prison, taux d'incendie (affichage), tarif de campagne de sécurité — cohérent avec sa fonction.

---

## IE — Indice Économique

**Définition** : santé économique de l'empire. "Éco" dans les grilles.

**Modifié par** : diplomatie économique, accords commerciaux, quelques actions présidentielles/décrets, corruption de fonctionnaire ratée (-3).

**Ce qu'il modifie réellement** :
- `getTauxPret(typeBanque)` (`plateau-justice-economie.js:3826`) — taux d'intérêt des prêts bancaires (`5 + IE/10` national, `12 + IE/10` privé). Vrai effet économique, cohérent.
- `getCoutNaturalisation(paysVise)` (`plateau-politique.js:2270`) — coût de naturalisation (`2000 + IE×30`). Cohérent (empire riche = citoyenneté chère).
- Génération de PNJ terrain (`promoteur` plus probable si IE élevé).

**Trou** : c'est tout. Pas de lien avec les salaires, le commerce entre joueurs, les prix du marché, etc., alors que le libellé ("Impact sur les revenus fiscaux et les salaires", `plateau-politique.js:3138`) le suggère explicitement dans l'UI — texte trompeur, aucun code ne fait ça.

---

## ID — Indice Diplomatique

**Définition** : qualité des relations internationales. "Diplo" dans les grilles.

**Modifié par** : de très loin le plus manipulé — traités, ambassades, trêves, propositions diplomatiques acceptées/refusées, sanctions, expulsions d'ambassadeurs (~25 sites d'écriture rien que dans `plateau-politique.js`).

**Ce qu'il modifie réellement** :
- Génération de PNJ terrain (`plateau-pnj.js:1653`) : `prob cadavre = prob + (100-ID)/500` — plus la diplomatie est mauvaise, plus la probabilité de trouver un cadavre sur un terrain vague augmente légèrement.
- Un score de "force" comparatif entre empires en cas de conflit (`plateau-politique.js:4051-4052`, `notreScore = ISN + PER + INT` d'un ambassadeur).
- Sinon : **uniquement affiché** ("Indice Diplomatique actuel : X", `plateau-politique.js:4158`), jamais lu pour moduler un taux de réussite, un coût, ou une mécanique.

**Trou le plus important trouvé dans cet inventaire** : ID a de très loin le plus d'écritures (dizaines d'actions diplomatiques y investissent du temps de jeu) pour l'un des plus faibles retours mécaniques (un seul effet indirect, obscur, sur la génération aléatoire de PNJ). Tout l'arsenal diplomatique (traités, sanctions, guerres) n'a aujourd'hui presque aucune conséquence de gameplay au-delà du nombre affiché.

---

## IS — Indice Social

**Définition** : climat social / tension populaire. "Social" dans les grilles.

**Modifié par** : couvre-feu, répression, taxe locale/nationale élevée (>18%), corruption ratée, hooliganisme.

**Ce qu'il modifie réellement** :
- Taux d'évasion de prison (`plateau-justice-economie.js:1190`) : `taux = 10 + (DUP-10)×2 - (IS-45)/3`.
- Taux de réussite d'enquête du commissaire (`plateau-justice-economie.js:4463` et 3 sites similaires) : `+ (IS-45)/5`.
- Négociation avec squatteurs sur terrain (`plateau-pnj.js:1677`, jet CHA+IS).
- Génération de PNJ terrain (squatteurs agressifs plus probables si IS élevé).

C'est l'indice le **mieux intégré des 4** — modifié par des actions cohérentes avec sa définition, et lu par plusieurs mécaniques réellement liées au "climat social".

---

## IP — Indice de Piété (système religieux, séparé)

**Définition** : ferveur religieuse. Système à part (`plateau-divers.js`, section "SYSTÈME RELIGIEUX"), avec ses propres fonctions `getIP()`/`modifierIP(delta)` plutôt que l'accès direct utilisé pour les 4 autres.

**Modifié par** : 4 sites dans `plateau-divers.js` (lignes 258/298/326/351 — actions religieuses type prière/don/cérémonie/pèlerinage), toujours +3 à +10.

**Ce qu'il modifie réellement** : **rien trouvé**. Aucun autre fichier ne lit `INDICES_NATIONAUX[pays].IP` ni n'appelle `getIP()` en dehors de sa propre définition et de l'affichage dans `rendreGrilleIndices`. Un indice qu'on peut faire monter, qu'on peut voir dans le tableau de bord impérial, mais qui ne débloque, ne modifie et ne conditionne absolument rien ailleurs dans le jeu.

---

## INDICES_VILLES — indices locaux (jamais vraiment construits)

**Définition** : déclinaison par ville des 4 indices nationaux (ISN/IE/ID/IS), pour un futur système de nuances locales.

**État réel** : seule `republic.capitale` (Luthécia) a une entrée (`{ ISN:30, IE:50, ID:40, IS:45 }`). Aucune autre ville, aucun autre empire.

**Modifié par** : **un seul site** dans tout le code (`plateau-justice-economie.js:4810`, `modifierIndiceVille(pays, ville, 'IS', -1)`).

**Lu par** : **aucun site**. `getIndicesVille()` n'est appelée nulle part. Pas de persistance Supabase non plus (confirmé par un commentaire déjà présent dans le code : "le malus prévu sur les indices de ville n'est pas encore possible").

C'est un système entièrement décoratif aujourd'hui — une seule écriture qui ne sert à rien, puisque rien ne relit jamais ces valeurs.

---

## Anomalie trouvée : `.POP` et `.INF` sur `INDICES_NATIONAUX`

Deux endroits (`plateau-justice-economie.js:1235` et `:4672-4673`, contextes d'évasion de prison / émeute) écrivent `INDICES_NATIONAUX[pays].POP` et `.INF` — des propriétés qui **n'existent dans aucune définition officielle** des indices nationaux (ni ISN/IE/ID/IS/IP). Elles sont créées à la volée (`|| 50`, `|| 0`) et **ne sont jamais relues nulle part**. Très probablement une confusion avec `state.pop`/`state.inf` (les ressources du joueur, un concept complètement différent) — écriture morte, sans aucun effet, à traiter comme un vrai bug plutôt qu'un indice à conserver.

---

## Doublons de code trouvés (sans rapport direct avec les indices, mais pertinents pour la refonte)

- `getMalusISN()` (plateau-politique.js) et `getMalusIllegal()` (data.js) : formule identique, la première utilisée partout en jeu, la seconde seulement pour l'affichage.
- `checkDetection(fn, resultType)` : définie **deux fois**, mot pour mot identique, dans `plateau-actions-illegales-rumeurs.js` et `plateau-justice-economie.js` — l'une écrase silencieusement l'autre au chargement.

---

## Résumé des trous, du plus au moins grave

1. **ID** : énorme investissement en écriture (traités, guerres, sanctions...), quasi aucun retour mécanique.
2. **`getMultDetection`** : multiplicateur de détection affiché à l'écran mais jamais appliqué au vrai jet.
3. **IP** : indice complet (get/modifier dédiés, 4 actions qui le font monter) mais zéro consommateur.
4. **INDICES_VILLES** : système entier non branché, une seule écriture qui ne sert à rien.
5. **`.POP`/`.INF`** : écritures orphelines, probable confusion avec les ressources du joueur — à corriger, pas à intégrer.
6. **IE** : texte d'UI ("salaires") qui promet plus que ce que le code fait réellement.
7. **`getMalusIllegal`/`checkDetection` dupliqué** : dette technique à nettoyer avant/pendant la refonte.

---

## Suite du chantier

Phase 1 (cet audit) terminée. Phases 2-5 du "grand chantier de refonte des ordres" à définir/mener ensuite — Phase 2 : mapper les 344 ordres de Luthécia sur la grille de difficulté commune (Automatique 100% / Facile 85% / Standard 70% / Difficile 55% / Très difficile 40% / Exceptionnel 25% / Désespéré 10%) en s'appuyant sur le tableau interactif `.scratch/audit-ordres-luthecia.html`.
