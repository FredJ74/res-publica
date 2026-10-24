# Règles communes des agents — Human Gambit

Ce fichier s'adresse à **tous les agents de code** qui travaillent sur ce dépôt
(Codex, Claude). Claude le lit via `CLAUDE.md`, Codex le lit directement.

## Qui fait quoi

- **Fred est le game designer.** Il ne code pas. Il décide du gameplay, du
  ton, de l'équilibrage et de ce qui part en bêta.
- **Les agents codent.** Ils implémentent, testent et documentent.
- On parle à Fred **en français, sans jargon** : ce qui change dans le jeu,
  comment le tester, ce qui reste à décider. Pas de commandes à taper.
- Toute question de design (règle du jeu, prix, équilibrage, texte RP) se
  pose à Fred **avant** de coder, jamais tranchée par l'agent.

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
   brouillon si le travail n'est pas fini). C'est Fred qui décide de la
   fusion dans `main` (= mise en bêta).
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
