# Préparation de l'internationalisation — chantier autonome

**Statut : infrastructure isolée, non activée dans le jeu.**

## Contexte

Le jeu contient des textes français à plusieurs endroits : `plateau.html`, `plateau-*.js`, `data.js`, dialogues de PNJ, messages Supabase, courriers, journaux et contenus RP. Le moteur doit rester universel tandis que les contenus des empires conservent leurs particularités. Aucun texte existant n'est remplacé par cette préparation.

## Fichiers préparés

- `i18n/core.js` : catalogue de clés textuelles, substitution littérale, repli français, formatage `Intl`, sélection de langue uniquement par appel explicite.
- `i18n/fr.js` : 15 libellés communs français servant de référence.
- `i18n/en.js` : traduction témoin des mêmes clés, à revoir éditorialement.
- `outils/bancs/banc-i18n.cjs` : tests Node.js sans dépendances supplémentaires.

Ces fichiers ne sont pas inclus dans `plateau.html`, et ne sont donc pas exécutés en production. Aucun localStorage, aucun cookie, aucun champ utilisateur ni SQL n'est modifié. **Ne pas fusionner pour activer silencieusement la traduction.**

## Procédure ultérieure

1. Extraire un inventaire exhaustif des libellés des 57 fichiers client et classer chaque occurrence : UI générique, mécanique partagée, contenu d'empire, dialogue RP, message serveur, donnée joueur.
2. Définir les clés stables par domaine ; préserver les identifiants SQL, noms de fonctions, noms de colonnes, valeurs de commandes, rôles, monnaies et PA/FR des mécaniques.
3. Traduire progressivement les libellés génériques, avec un banc de parité `fr` (texte original = valeur source) et tests de variables et pluriels.
4. Prévoir une couche de traduction adaptée aux messages du serveur, plutôt que traduire le résultat de RPC via heuristique ; garantir les traces et contrôles d'accès.
5. Traiter séparément les textes RP, PNJ, presse et contenus propres à chaque empire, après validation éditoriale et tests contextualisés.
6. Brancher ensuite, dans une PR distincte, le chargement des catalogues, le choix de langue et une persistance consentie par l'utilisateur. Aucune langue ne doit être activée sans recette complète.

## Garde-fous

- Le français reste source de vérité et langue de repli.
- Pas de traduction automatique des noms propres, titres de journaux, codes serveur, pays, objets de l'inventaire ni de l'histoire RP.
- `t()` retourne toujours du texte brut : **ne jamais injecter ce résultat comme HTML non échappé**.
- Les placeholders `{amount}` sont textuels ; ne jamais interpoler du code.
- Les prix, calendriers, calculs et l'horloge restent pilotés par le serveur. `Intl` ne sert qu'à la présentation.
- Les pluriels, genre et variation grammaticale demanderont une extension documentée avant conversion massive.
- Vérifier toute traduction de PA et FR selon le design, ne pas changer leur sémantique.
- Ne pas modifier les chantiers #219 et #275.
