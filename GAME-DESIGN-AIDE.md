# Onglet Aide — arbitrage du game designer, 11 novembre 2026

## Décision

L'ancien onglet **« Règles » devient « Aide »**. Son **premier écran** est un conseiller conversationnel HRP (hors roleplay), analogue dans son intention pédagogique à un PNJ référent, mais capable d'orienter le joueur sur l'ensemble du jeu. Les rubriques historiques d'explication restent disponibles à côté ; ne jamais effacer leur contenu pour faire place au chat.

### Message d'accueil souhaité

> Tu galères ? Tu ne sais pas trop quoi faire ? Poses moi les questions que tu veux, j'essayerai de te répondre au mieux.

La ponctuation et la grammaire peuvent être harmonisées, le ton doit rester chaleureux, direct et informel. Le conseiller est HRP : il n'est ni un personnage du monde qui pourrait donner des ordres, ni une autorité pouvant modifier les données du joueur.

### Questions autorisées

Les joueurs doivent pouvoir interroger librement le conseiller sur les règles, les PA, les commandes, les interfaces **et aussi sur les motivations et objectifs libres**. Exemples :
- « Je ne comprends pas le système de PA »
- « Qu'est-ce que je dois faire dans le jeu ? »

Pour cette dernière question, **ne pas prétendre qu'il existe une quête principale obligatoire**. Réponse directrice du game designer :

> Explore la ville pour aller à la rencontre d'autres PJ. Essaye de créer un réseau, ou de monter ton business, les possibilités sont vraiment très nombreuses. Le tout est de savoir qui tu veux être dans ce jeu. Tu as déjà une idée ? Ça restera entre nous ;)

Le conseiller peut adapter naturellement cette réponse et aider ensuite le joueur à explorer une vocation choisie : relations, affaires, politique, enquêtes, rivalités, métiers, etc. Aucun objectif forcé ni mécanique nouvelle.

## Contrat technique

- Même discipline que les référents : une réponse utile avant le caractère du conseiller, refus d'inventer une règle non vérifiée ; orienter vers une rubrique/référent si nécessaire.
- Le conseiller ne lit ni le personnage ni un document privé, ne révèle ni secrets ni position, ne distribue rien et ne lance aucune action du jeu.
- Authentification serveur avant l'appel à l'IA ; message et historique bornés ; aucune clé IA ni prompt système fourni par le client.
- Français conservé et interface traduisible dans les neuf langues, RTL arabe ; ne pas confondre HRP et RP.
- Ne pas promettre une confidentialité technique absolue sur la base du « ça restera entre nous », formule de complicité seulement.
- Préserver les guides détaillés existants, les références d'autres modules aux sections `intro`, `sport`, etc.
- Évaluer la qualité réelle des réponses, notamment la capacité du conseiller à éviter les chiffres obsolètes et à expliquer les PA ; les tests statiques ne valident pas DeepSeek.
- Refonte visuelle sous validation du game designer avant fusion/déploiement ; les mécanismes du jeu restent inchangés.

## Historique de livraison et validation

PR #712 fusionnée sous `48682eb7` : panneau HRP et requête dédiée `/api/aide`,
styles adaptés au mobile, neuf langues, bancs ciblés. PR #716 fusionnée sous
`782eacd6` : la route passe par `/api/chat?mode=aide` et le module interne
`_aide.js`, pour respecter les douze fonctions Vercel. Ces commits sont présents
sur main `6b9f5d30` ; cela ne prouve pas à soi seul le déploiement ou une recette
IA authentifiée.

Correctif multilingue en cours, branche `codex/aide-hrp-neuf-langues-20261111` :
langue du sélecteur imposée dans les instructions, corpus thématique canonique
sélectionné par mots-clés dans neuf langues, contexte de la question courante
prioritaire sur le passé. Messages historiques conservés dans leur langue
d'origine ; une réponse en cours garde la langue de son envoi, les suivantes
utilisent la nouvelle sélection. Verrou unique dès l'authentification, saisie
IME respectée, brouillons et erreurs préservés à la bascule. Aucun effet de jeu.
Les tests à fournisseur simulé ne certifient pas la langue d'une réponse réelle
DeepSeek : la recette authentifiée reste à établir si les accès sont absents.

Une future extension peut enrichir le corpus canonique du conseiller à partir des référentiels, avec vérification de versions et sans créer de deuxième source de règles divergente ; ne pas présenter la couverture de tout le gameplay comme déjà exhaustive.
