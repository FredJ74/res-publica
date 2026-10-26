*DOCUMENT FONDATEUR · I SUR IV*

# Constitution de Human Gambit

Ce document n'énonce pas les règles du jeu. Il explique pourquoi elles sont ce qu'elles sont, et à quoi l'on reconnaîtra qu'une règle future trahit le projet.

**2 OCTOBRE 2026**  
**DOCUMENT DE CONCEPTION**  
**À LIRE AVANT TOUTE DÉCISION DE GAME DESIGN**  

## Préambule

Human Gambit n'est pas un jeu que l'on gagne. C'est un lieu où des gens se rencontrent, s'allient, se trahissent, se gouvernent et se racontent. Les empires, les monnaies, les tribunaux et les stades ne sont pas le jeu : ils sont les prétextes à ce que des joueurs aient quelque chose à se disputer, à se vendre, à se pardonner.

Il en découle une conséquence qui gouverne tout le reste : le code n'est pas le jeu, il en est le support. Un moteur réussi n'est pas celui qui simule le plus de choses, c'est celui qui laisse le plus de place à ce que les joueurs feront eux-mêmes — et qui tient fermement les quelques points qu'eux ne peuvent pas tenir.

Ce document est écrit pour durer plus longtemps que la mémoire de ceux qui l'écrivent. Chaque article énonce un principe, ce qu'il implique, ce qu'il interdit, et — quand elle existe — la décision réelle qui l'a déjà appliqué. Ces précédents comptent autant que les principes : ils prouvent que la règle a déjà résisté à un cas concret.

## TITRE I
De la nature du jeu

### ARTICLE 1 — L'ÉCOSYSTÈME

Human Gambit est un écosystème humain. Sa matière première est la relation entre deux joueurs ; tout le reste en est l'environnement.

Un écosystème ne se pilote pas, il s'entretient. On ne décide pas qu'il y aura une opposition politique, un marché noir ou une rivalité de clubs : on crée les conditions pour qu'ils apparaissent, et on accepte qu'ils apparaissent autrement qu'on l'avait prévu. La réussite d'une mécanique ne se mesure donc pas à ce qu'elle produit, mais à ce que les joueurs en font.

**Ce que cela implique** — Une fonctionnalité sans second joueur à l'horizon est suspecte, même si elle est bien faite. Avant d'écrire, on nomme qui parlera à qui.

**Ce que cela interdit** — Concevoir le jeu comme une somme de systèmes autonomes qu'un joueur seul pourrait parcourir du début à la fin.

### ARTICLE 2 — LES HISTOIRES APPARTIENNENT AUX JOUEURS

Le jeu ne raconte pas d'histoire. Il fournit des lieux, des rôles, des contraintes et des enjeux ; l'histoire est écrite par ceux qui jouent.

Un scénario écrit à l'avance est une histoire qu'on fait subir. Une bonne mécanique est muette sur l'issue : elle rend possible le coup d'État sans le programmer, la faillite sans la décider, la réconciliation sans la récompenser.

**Précédent.** L'excommunication est accordée au Grand Prêtre « de façon totalement arbitraire : aucune preuve ni justification n'est exigée par le jeu, seuls les joueurs peuvent en tirer les conséquences politiques ». Le moteur donne le pouvoir et refuse de juger son usage. C'est l'article 2 en une phrase.

### ARTICLE 3 — LA PRIMAUTÉ DE L'INTERACTION HUMAINE

Quand une interaction humaine et une mécanique peuvent produire le même résultat, c'est l'interaction humaine qui l'emporte.

Ce principe est contre-intuitif pour un développeur, dont le métier est d'automatiser. Ici, automatiser un échange entre deux joueurs, c'est le supprimer. Négocier un prix, convaincre un électeur, obtenir un rendez-vous, se faire pardonner : ce sont des actions de jeu à part entière, et les coder serait les retirer.

**Ce que cela implique** — Le jeu doit savoir rester incomplet. Un parcours qui exige qu'un joueur en convainque un autre n'est pas un parcours cassé.

**Ce que cela interdit** — Tout bouton qui obtient d'un PNJ ce qu'un joueur aurait pu obtenir d'un joueur.

## TITRE II
De l'office du code

### ARTICLE 4 — LE SEUIL D'INTERVENTION

Le code n'intervient que lorsqu'il apporte une valeur que les joueurs ne peuvent raisonnablement pas produire eux-mêmes.

« Raisonnablement » est le mot important : il ne s'agit pas de ce qui est théoriquement possible, mais de ce qui est tenable pour des gens qui ne sont pas connectés en même temps, qui ne se font pas confiance, et qui ne tiendront pas une comptabilité à la main. Cinq domaines franchissent ce seuil, et à peu près eux seuls :

- **L'ARGENT ET LES BIENS** — Parce qu'un joueur ne peut pas vérifier que l'autre a vraiment payé, ni s'empêcher lui-même de tricher.

- **LE TEMPS** — Parce que personne ne peut être présent toutes les nuits pour que le monde avance.

- **LA MÉMOIRE** — Parce qu'un serment, une dette ou un casier doivent survivre à la déconnexion de ceux qui les ont faits.

- **L'ARBITRAGE** — Parce qu'un conflit entre deux joueurs a besoin d'un tiers qui ne soit ni l'un ni l'autre.

- **LE SECRET** — Parce qu'un secret qu'un joueur peut lire dans une table n'est pas un secret.

- **LA SIMULTANÉITÉ** — Parce que deux joueurs qui agissent au même instant doivent obtenir un résultat cohérent.

**Précédent.** La confession efface une trace judiciaire, mais « le contenu d'une confession n'est jamais consultable par qui que ce soit, pas même le Grand Prêtre ». Le moteur tient le secret — ce qu'aucun joueur ne pourrait garantir à un autre — et ne tient rien d'autre.

### ARTICLE 5 — LE MOTEUR PROTÈGE, IL NE DIRIGE PAS

Le moteur est un arbitre et un garde-fou. Il n'a pas de projet pour la société qu'il héberge.

Un moteur qui dirige se reconnaît à ce qu'il décide à la place des joueurs lorsqu'ils tardent : il nomme, il condamne, il élit, il attribue. Un moteur qui protège se reconnaît à ce qu'il empêche l'impossible et laisse le reste ouvert, y compris l'inaction, y compris le vide.

Il existe une nuance, et elle est délicate : le monde ne doit pas s'arrêter faute de joueurs. Un PNJ peut donc tenir une charge vacante — mais il la tient en attendant, jamais à la place. Un PNJ qui occupe un poste doit toujours être déplaçable par un joueur, ne jamais être meilleur qu'un joueur, et ne jamais rendre la charge inintéressante.

**Ce que cela implique** — Une place vide est un état valide du jeu. Elle est même une invitation.

**Ce que cela interdit** — Qu'un automate rende une fonction humaine superflue, ou qu'il la remplisse mieux qu'un joueur ne le ferait.

### ARTICLE 6 — LE MOTEUR NE SAIT QUE CE QUI LE REGARDE

Ce qui appartient aux joueurs ne doit pas entrer dans la base. L'ignorance du moteur est une garantie, pas une lacune.

Un moteur qui enregistre tout devient un témoin permanent, et un témoin permanent détruit la confidence, le mensonge, et donc la politique. La bonne façon de garantir qu'une information ne sera pas conservée n'est pas de promettre de ne pas l'écrire : c'est de ne prévoir aucun endroit où l'écrire.

**Précédent.** Lorsqu'un joueur demande à Pat Hounette d'être mis en relation avec une organisation criminelle, Pat lui demande son projet. Ce texte ne quitte jamais le navigateur — non par discipline, mais parce que la fonction serveur n'a aucun paramètre pour le recevoir. Une règle qu'on pourrait oublier d'appliquer a été remplacée par une forme qui ne permet pas de l'enfreindre.

### ARTICLE 7 — LES MÉCANIQUES SE PARTAGENT, LES CONTENUS JAMAIS

Un moteur est commun à tous les empires. Un personnage, un lieu, une histoire n'appartiennent qu'à un seul.

C'est la règle de socle énoncée le 1er octobre 2026, et elle vaut au-delà des empires : elle sépare ce qui doit être écrit une fois de ce qui doit être écrit à chaque fois. Mutualiser un personnage, c'est faire croire à deux joueurs de deux mondes qu'ils parlent à la même personne. Si une solution technique conduit à partager des personnages entre plusieurs empires, cette solution est contraire au socle et doit être écartée.

## TITRE III
De la diversité des trajectoires

### ARTICLE 8 — IL N'EXISTE PAS UNE SEULE MANIÈRE DE RÉUSSIR

Le pouvoir politique, la fortune, la gloire sportive, la foi, le crime et la réputation sont des réussites de rang égal. Aucune n'est l'antichambre d'une autre.

Un jeu qui n'a qu'un sommet n'a qu'une seule partie, rejouée indéfiniment par des gens qui s'y disputent la même place. Plusieurs sommets, c'est plusieurs parties simultanées qui se croisent — et c'est le croisement qui fait l'histoire : le criminel qui blanchit dans le sport, l'industriel qui finance l'élection qui décidera de son sort.

**Ce que cela implique** — Chaque grande famille doit offrir un parcours qui aboutit sans passer par la politique.

**Ce que cela interdit** — Qu'une trajectoire soit décorative : un domaine où l'on ne peut pas monter n'est pas une trajectoire, c'est un décor.

### ARTICLE 9 — CHAQUE PROFIL DE JOUEUR TROUVE SA PLACE

Le bavard, le comptable, le solitaire, le chef de bande, le collectionneur et le spectateur doivent tous avoir quelque chose à faire le soir où ils se connectent.

Tous les joueurs ne veulent pas parler à vingt personnes. Certains veulent gérer, d'autres fouiller, d'autres regarder. L'écosystème a besoin d'eux tous : sans spectateurs, pas de public pour les ambitieux ; sans gestionnaires, rien à prendre ; sans solitaires, personne à recruter.

La contrepartie est stricte : une occupation solitaire est légitime tant qu'elle produit quelque chose dont d'autres auront besoin. Collectionner, tenir un commerce, enquêter — tout cela finit entre les mains d'un autre joueur. Une activité qui ne débouche sur personne est un passe-temps, pas une place.

### ARTICLE 10 — LES CONTRE-POUVOIRS

Tout pouvoir doit pouvoir être contesté par un autre joueur, par un autre moyen que celui qui l'a établi.

Les contre-pouvoirs n'existent pas pour l'équilibre, mais pour la diversité des trajectoires : ils sont ce qui garantit qu'un joueur arrivé plus tard, ou choisissant une autre voie, a encore prise sur le monde. Le juge sur l'élu, la presse sur le gouvernement, la rue sur le ministre, le Grand Prêtre sur le puissant, le supporter sur le président de club.

**Ce que cela implique** — Un pouvoir nouveau s'accompagne de la question : qui peut y résister, et avec quoi ?

**Ce que cela interdit** — Un pouvoir dont le seul contre-pouvoir est un pouvoir du même ordre, détenu par un joueur du même camp.

### ARTICLE 11 — LES SUPPORTS NE SONT JAMAIS DES FINS

Les bâtiments, l'argent, les religions, le football, la criminalité, la politique sont des supports d'interaction. Aucun n'est une fin en soi.

Un bâtiment n'existe pas pour être visité : il existe parce qu'on y croise quelqu'un. L'argent n'existe pas pour être accumulé : il existe parce qu'il crée de la dépendance entre joueurs. Une religion n'existe pas pour être pratiquée : elle existe parce qu'elle donne à un joueur un pouvoir moral sur un autre.

Le test est simple et impitoyable : retirez les autres joueurs, et regardez ce qui reste debout. Ce qui tient encore est un support mal conçu.

**Précédent.** Dans les tribunes, « seuls les supporters réellement présents au moment où le match se joue comptent », et leur effet « ne garantit jamais la victoire ». Le stade n'est pas un bâtiment à visiter : c'est un endroit où la présence physique d'autres joueurs change quelque chose, sans jamais décider à leur place.

## TITRE IV
Des garanties dues au joueur

### ARTICLE 12 — LE TEMPS DU JOUEUR EST RÉEL

Les délais qui concernent des joueurs se comptent en temps réel. Le temps de jeu ne gouverne que ce qui ne concerne qu'une simulation.

**Précédent.** Les trois jours pendant lesquels Pat Hounette refuse une nouvelle demande sont trois jours réels, « parce que cette attente concerne des joueurs réels et non une mécanique de simulation ». De même, un match dure trente minutes réelles, mais « arriver en cours de match ne pénalise jamais » et fermer la fenêtre ne coûte rien : on respecte le temps du joueur sans exiger sa présence continue.

### ARTICLE 13 — LE GESTE ÉLÉMENTAIRE EST INVIOLABLE

Donner, parler, se déplacer et se montrer ne se refusent jamais. Ce sont les gestes par lesquels un joueur en atteint un autre.

La loi peut fermer des circuits ; elle ne ferme pas le monde. Une marchandise interdite reste possédable, consommable et donnable — l'interdiction retire l'accès aux circuits institutionnels, jamais la capacité d'un joueur à tendre un objet à un autre. C'est ce qui sépare un État d'une prison.

**Ce que cela implique** — Le don est le dernier recours de l'écosystème : quand tout est verrouillé, il reste une main tendue.

**Ce que cela interdit** — Rendre un objet intransférable, ou un joueur injoignable, pour des raisons de règle.

### ARTICLE 14 — L'ÉCHEC EST UNE ISSUE, LE BLOCAGE N'EN EST PAS UNE

Un joueur peut tout perdre. Il ne doit jamais se retrouver sans aucune action possible.

Perdre une élection, être condamné, faire faillite, être excommunié : ce sont des récits. Ne plus pouvoir sortir d'un lieu, ou ne plus pouvoir adresser la parole à personne, n'en est pas un — c'est la fin de la participation. La prison elle-même doit laisser une porte : visiter, écrire, se confesser, s'évader.

### ARTICLE 15 — LE JEU DIT LA VÉRITÉ SUR LUI-MÊME

Ce que l'interface annonce doit se produire. Une promesse non tenue coûte plus cher qu'une fonctionnalité absente.

Un joueur pardonne un manque ; il ne pardonne pas d'avoir investi du temps dans une action qui n'avait aucun effet. Il vaut donc mieux ne rien afficher que d'afficher un bouton inerte, une règle périmée, ou un message qui dit « momentanément indisponible » là où rien n'a jamais fonctionné.

**Ce que cela implique** — Les règles écrites font partie du jeu et vieillissent comme lui : elles se vérifient.

**Ce que cela interdit** — Documenter ou proposer ce qui n'existe pas encore, au motif que cela existera.

## TITRE V
De l'application

### ARTICLE 16 — LA QUESTION PRÉALABLE

Avant toute fonctionnalité nouvelle, une seule question est posée : crée-t-elle de nouvelles interactions entre joueurs, ou en remplace-t-elle une ?

Si elle en crée, elle est bienvenue. Si elle en remplace, elle est refusée, quelle que soit sa qualité technique. Si elle ne fait ni l'un ni l'autre, elle est reportée : elle n'est pas nuisible, elle est simplement moins urgente que tout ce qui crée des interactions. La grille qui permet de trancher fait l'objet du document II.

### ARTICLE 17 — CE QUE CETTE CONSTITUTION N'EXIGE PAS

Elle n'exige ni simplicité, ni petitesse, ni lenteur.

Un système profond, une économie exigeante, une procédure judiciaire détaillée sont parfaitement constitutionnels s'ils donnent aux joueurs davantage à se disputer. Ce qui est proscrit n'est pas la complexité : c'est la complexité qui tourne à vide, celle qu'un joueur peut parcourir entièrement sans jamais avoir eu besoin de personne.

### ARTICLE 18 — DE LA RÉVISION

Cette Constitution se modifie par décision explicite du game design, jamais par l'accumulation de cas particuliers.

Une exception qui se répète n'est pas une exception : c'est une règle qu'on n'a pas osé écrire. Lorsqu'un article gêne trois fois de suite, il faut le réviser ouvertement — ou constater qu'il avait raison.

Les quatre documents fondateurs. I — la présente Constitution, qui dit pourquoi. II — le Guide de game design, qui dit comment trancher. III — la refonte des règles du jeu, qui dit comment l'expliquer aux joueurs. IV — l'audit philosophique de Républia, qui dit où le jeu se tient aujourd'hui par rapport à ces principes.

Les précédents cités sont des décisions réellement prises et appliquées dans le projet, vérifiées dans le dépôt au 1er octobre 2026. Ils ne sont pas des illustrations : ils sont la preuve que l'article a déjà tenu face à un cas concret.

