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

## Extension multicouche du 2 novembre 2026 — décision validée

Architecture unique et monde partagé ; traduction comme couche de présentation, jamais comme moteur de jeu. Les six langues initiales validées sont `fr`, `en`, `es`, `zh-TW`, `ru`, `ko`. Les trois langues supplémentaires sont `ar`, `pt-BR` (avec variante `pt-PT`) et `de`. Elles sont toutes préparées dès maintenant, mais leur activation reste indépendante. Le moteur existant accepte les variantes régionales et conserve `fr` par défaut.

**Ces catalogues sont des démonstrateurs de 15 clés, pas des traductions exhaustives ni validées éditorialement.** Aucun de ces scripts n'est raccordé à la page de jeu. Ne pas introduire de sélecteur de langue ou de persistance avant validation d'un parcours complet et du mécanisme d'activation explicite. Exécuter `node --test outils/bancs/banc-i18n.cjs outils/bancs/banc-i18n-langues.cjs`.

### Contrats de la prochaine intégration

- Générer l'inventaire des libellés réellement servis depuis le main courant, avec attribution par domaine (UI, serveur, RP, PNJ, contenu joueur) ; ne pas compter les 15 clés pilotes comme couverture du jeu.
- Convertir par composants/écrans, et mesurer la couverture des clés françaises + chaque langue ; conserver les noms propres et la sémantique des ordres côté serveur.
- Tous les retours serveur doivent exposer des codes stables + paramètres ; ne pas interpréter automatiquement des textes français comme des identifiants de logique.
- Les contenus joueurs conservent la langue source et une option « voir l'original » ; prévoir une traduction à la lecture et un cache versionné, sans jamais remplacer la source ni faire de traduction silencieuse des ordres.
- Tester l'interface de droite à gauche pour l'arabe (direction du texte, pas inversion des cartes, images ou contrôles géographiques).
- Prévoir un commutateur de fonctionnalité désactivé par défaut pour chaque langue, indépendant de la présence du fichier de traduction ; seules les langues explicitement validées pourront être activées ultérieurement.
- Les couches linguistiques restent hors des fichiers et migrations PNJ/DeepSeek confiés à Claude et de l'audit transverse Codex. Les nouveaux textes de ces chantiers seront inventoriés à leur fusion.
- Aucune migration Supabase, aucun changement du gameplay, aucune activation publique sur cette PR.

## Découverte d'intégration du 02/11 — éviter deux moteurs i18n

Le `main` effectif contient **déjà** `i18n/resources.js` (six langues et traductions d'accueil/création), `i18n/i18n-init.js` et i18next, câblés dans `index.html`. Le prototype `HGI18n` de cette PR #278 **ne doit pas être chargé en parallèle** sur l'accueil ni créer une seconde préférence de langue. PR #377 ajoute les trois langues restantes dans le moteur effectivement utilisé, sans fusion de #278. Les catalogues pilotes HGI18n peuvent servir de matériel de traduction/contrôle, mais les prochains travaux doivent **converger vers les catalogues i18next existants**, en préservant le choix déjà stocké sous `respublica_language`. Aucun double moteur en production.
