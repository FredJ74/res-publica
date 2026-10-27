# Règles communes des agents — Human Gambit

Ce fichier s'adresse à **tous les agents de code** qui travaillent sur ce dépôt
(Codex, Claude). Claude le lit via `CLAUDE.md`, Codex le lit directement.


**Avant toute décision de game design, lire `CONSTITUTION.md`** (document fondateur I sur IV de Fred, 2 octobre 2026) : elle dit pourquoi les règles sont ce qu'elles sont, et à quoi l'on reconnaît qu'une règle trahit le projet.
**L'état du socle et des mécaniques est dans `ARCHITECTURE.md`** : les couches du jeu, l'inventaire des mécaniques et la marche à suivre pour un nouvel empire. Le tenir à jour.

## Qui fait quoi

- **Fred est le game designer.** Il ne code pas. Il décide du gameplay, du
  ton, de l'équilibrage et de ce qui part en bêta.
- **Les agents codent.** Ils implémentent, testent et documentent.
- On parle à Fred **en français, sans jargon** : ce qui change dans le jeu,
  comment le tester, ce qui reste à décider. Pas de commandes à taper.
- Toute question de design (règle du jeu, prix, équilibrage, texte RP) se
  pose à Fred **avant** de coder, jamais tranchée par l'agent.

## Décisions de game design : aucune décision oubliée

**Avant de solliciter un arbitrage de Fred, rechercher si la question a déjà été tranchée.**
L'agent consulte, selon le sujet, `CONSTITUTION.md`, les documents de game design,
`ARCHITECTURE.md`, `RELAIS.md`, les issues GitHub, les échanges et comptes rendus
accessibles, ainsi que les discussions des PR. Il distingue clairement **règle décidée**,
**règle implémentée** et **règle testée** : l'absence d'une fonction dans le code ne
constitue jamais la preuve qu'une décision de gameplay n'existe pas.

- Une décision antérieure retrouvée s'applique sans reposer la même question.
  Citer sa source dans le chantier et signaler l'écart entre décision et code.
- Si les documents se contredisent, rechercher la décision explicite la plus
  récente de Fred ; **ne jamais remplacer silencieusement une règle par une
  hypothèse technique**. Ne demander à Fred que l'arbitrage qui reste réellement
  indéterminé, après cette recherche.
- Toute nouvelle décision explicite de Fred, ou décision ancienne retrouvée mais
  absente des références, doit être **consignée dans un document de game design
  versionné et reliée à l'issue concernée**. Mettre aussi `RELAIS.md` à jour pour
  assurer la transmission aux autres agents, sans transformer un compte rendu
  de session en seule source de vérité.
- Lors de la reprise d'un chantier, vérifier les règles qui le concernent
  **avant** de modifier le code ou de demander un nouvel arbitrage.

**Précédent #135 — sécurité privée des chantiers (décision de Fred déjà prise).**
Les « vigiles de chantier » sont simplement des **agents de sécurité privée ordinaires**.
**Deux socles exclusivement** : (1) embauche, groupe, déplacement et présence des PNJ ;
(2) dissuasion des actes illégaux, détection, confrontation et emprisonnement selon
le fonctionnement policier existant. L'employeur déplace librement son agent ;
aucune affectation obligatoire au chantier, aucun statut de vigile, aucun moteur
parallèle, aucun nouveau lieu de détention. L'agent présent impose les malus
de sécurité applicables et peut interpeller un PJ recherché **uniquement après
sa détection effective**. Si l'interpellation réussit, le parcours carcéral
policier existant s'applique ; le récit précise que l'agent privé a remis le PJ
à la police avant sa conduite en prison (décisions explicites de Fred, 27/10/2026).
Le raccordement reste à tester en production, ne pas le présenter comme réalisé.

## Une seule réalité : celle du serveur (règle de Fred, 24/10/2026)

- **L'écran ne doit jamais pouvoir afficher autre chose que ce que le
  serveur a décidé et enregistré.**
- Tirages, gains, pertes, droits d'accès, échéances : décidés par une
  fonction serveur, jamais par `Math.random()`, `Date.now()` ou un cache du
  navigateur.
- Pas de message de succès avant la réponse du serveur ; un refus est nommé.
- Pas de montant ou d'effet annoncé que l'écran a calculé lui-même : il
  affiche ce que le serveur renvoie.

## Le relais entre agents

Fred alterne les agents : il travaille avec l'un jusqu'à sa limite de
session, puis bascule sur l'autre. Le travail doit donc pouvoir être
**repris à tout moment** par un autre agent.

1. **En arrivant**, lire `RELAIS.md`. S'il indique un chantier en cours,
   le reprendre **sur sa branche**, sans en créer une nouvelle.
2. **Une branche par chantier**, nommée `<agent>/<sujet>-AAAAMMJJ`
   (ex. `claude/squatteurs-20261024`). Jamais de commit direct sur `main`.
3. **Sauvegarder souvent** : après chaque étape qui fonctionne, commit et
   push. Une limite de session ne doit jamais faire perdre plus que
   l'étape en cours.
4. **À chaque push, mettre à jour `RELAIS.md`** : chantier, branche, PR,
   ce qui est fait, ce qui reste, comment Fred peut tester.
5. **Une pull request par chantier**, ouverte dès le premier push (en
   brouillon si le travail n'est pas fini). **L'agent fusionne lui-même**
   dans `main` (= mise en bêta) dès que le chantier est fini et que les
   contrôles passent, sans attendre le feu vert de Fred (décision de Fred,
   25/10/2026). Il ne fusionne jamais un chantier qui attend une décision
   de design, ni une branche en conflit, et il dit à Fred ce qui est parti
   en bêta et comment le tester.
6. **Chantier terminé et fusionné** : vider la section « En cours » de
   `RELAIS.md` et ajouter une ligne dans « Derniers chantiers ».

Le backlog vit dans les **issues GitHub** ; les chantiers s'y réfèrent par
leur numéro (#57, #135…).

## Sécurité du code

- Ne jamais réécrire un fichier entier de mémoire : modifications ciblées
  sur le contenu réel du fichier.
- Vérifier le contenu réel (fonctions et variables présentes), pas
  seulement que la syntaxe passe.
- En cas de doute sur l'état d'un fichier, Git fait foi (`git log -S`).
- **Base Supabase** : suivre `WORKFLOW-SUPABASE.md` sans exception.
- Freemium **jamais pay-to-win** : le premium est cosmétique ou de confort.
- Aucune clé ni secret dans le dépôt ou les messages.

## Charte graphique

- Toute fenêtre pop-up suit la **charte ardoise et or** de `style.css` :
  conteneur `cpj-dialogue`, texte secondaire `cpj-note`, boutons
  `cpj-touche` (`cpj-primaire` pour l'action principale), champs
  `cpj-champ`. Pas de couleurs en dur : l'ancienne palette brune
  (`#0f0d05`, `#8a8060`, `#2a2010`…) ne doit plus être recopiée.
