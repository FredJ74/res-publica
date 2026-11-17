# Lancement de Human Gambit — décisions et feuille de route

Session de décisions de Fred avec Claude, lundi 16/11/2026 au soir.
À lire par **tous les agents** (Claude, Codex, ChatGPT) avant de prendre un chantier.
Les décisions de game design ci-dessous sont celles de Fred ; la partie « Répartition » est une **proposition de Claude, à valider par Fred**.

## Décisions de Fred (16/11/2026)

1. **Gel de l'étendue** : pas de nouvel empire ni de nouveau bâtiment. Objectif : rendre Républia et Sovarka parfaitement fonctionnelles avant le lancement.
2. **Lancement mondial d'emblée**, en 9 langues, dans un monde commun (pas de serveur par langue).
3. **Ouverture des autres empires = événement** à part entière, après le lancement.
4. **Une seule horloge**, bascule à minuit heure de Paris. Pas de décalage horaire pour l'instant (non exclu plus tard). Décalage maximal visé avec les pays ciblés : environ 7 h. Le jeu ne prévoit aucune course de dernière heure.
5. **Traduction et textes juridiques confiés à l'IA**, sans juriste ni relecteurs payants.
6. **Rendez-vous collectifs** (élections, séances, événements) à des heures acceptables par le plus grand nombre.
7. **Tout texte écrit par un joueur est traduit automatiquement pour tous** (courrier, forums, tracts, affiches, programmes, noms d'organisations…), avec un bouton « voir l'original ».
8. **Critère de lancement** : traductions fiables et fidèles ; parcours essentiels testés.
9. **Date de lancement : samedi 19 décembre 2026** (début des vacances scolaires de Noël, zones A, B, C).
10. **Starovka terminée avant le week-end du 21-22/11**, puis un mois plein consacré à la robustesse et à la fiabilité.
11. **Bêta élargie à partir de fin novembre** (nombre de testeurs non fixé).
12. **Premium payant dès l'ouverture**, pensé d'abord comme un levier d'attachement (un local personnalisé attache le joueur).
13. **Toutes les options premium au lancement si possible** : commerce premium, bureau à 6 emplacements, personnalisation du local ou du bâtiment privé, portrait du personnage par IA, relooking chez le coiffeur, affiches et panneaux en ville. Le portrait IA selon l'avancement.

14. **Pas de jeu anonyme** (17/11/2026) : il faut un compte confirmé et s'identifier pour jouer (voir `AUDIT-FAILLES-20261116.md`).
15. **Pas de débat de politique réelle hors jeu** (17/11/2026) : les espaces HRP (forums, Discord, aide) servent uniquement au jeu (entraide, bugs, organisation). Aucun forum du type « Politique et Société ». Règle inscrite dans la charte de conduite et les CGU, appliquée par la modération. Leçon tirée de Kraland, où les conflits HRP ont fait fuir les joueurs.
16. **Principe de réponse aux abus** (17/11/2026, leçon de Kraland) : face à un abus signalé par des joueurs, on ajoute une voie de recours ou un contre-pouvoir (articles 10 et 14 de la Constitution), on ne retire pas la liberté à tous (pas d'aseptisation).

**Pas encore décidé (ne pas coder, ne pas proposer de prix)** : grille de prix et forme d'achat (unité, monnaie premium, paquets) ; publicité au coucher au lancement ; heures précises des rendez-vous.

## Chantiers qui en découlent

### A. Finir Starovka (jusqu'au 22/11)
- Rues et bâtiments restants selon les images de Fred.
- À trancher par Fred : la survie dans la toundra (PR #1020, brouillon) fait-elle partie du périmètre de lancement ?

### B. Traduction des textes des joueurs (décision 7) — chantier neuf
- Traduction à la volée par IA, une seule fois par texte et par langue, résultat gardé en base (coût maîtrisé).
- Bouton « voir l'original » partout où un texte de joueur s'affiche.
- Glossaire fixe des noms propres du jeu (personnages, lieux, institutions) pour qu'ils ne soient pas traduits au hasard.
- Prêt **avant la bêta élargie**, pour y être éprouvé.

### C. Fidélité des traductions de l'interface (décisions 5 et 8)
- Méthode sans frais : un modèle traduit, un second relit ; pour la première heure de jeu, retraduction vers le français pour repérer les contresens.
- Bouton « signaler une traduction » pour les joueurs.
- Règle à appliquer aux jeux de mots des noms (Pat Hounette, Harry Cover…) : à proposer par l'agent de traduction, puis validation de Fred.

### D. Textes juridiques (décision 5) — avant la bêta élargie
- CGU, CGV, politique de confidentialité (RGPD), mentions légales, rédigées par IA à partir des modèles de la CNIL, traduites dans les 9 langues.
- Nécessaires **dès que des inconnus s'inscrivent** (fin novembre), pas seulement au 19/12.

### E. Paiement et premium (décisions 12 et 13)
- Choix technique (Claude) : revendeur officiel de type Paddle ou Lemon Squeezy, qui vend en son nom et gère TVA et taxes de tous les pays.
- Branchement et essais en mode test pendant le mois de robustesse ; bascule en réel le 19/12.
- Options existantes (commerce premium, bureau à 6 emplacements) : passer de « gratuit en bêta » à « payant ».
- Options à construire, dans cet ordre proposé : personnalisation du local → affiches et panneaux → relooking → portrait IA (le plus lourd : génération, modération, cohérence avec la fonction réelle ; s'il n'est pas prêt, premier ajout après l'ouverture).
- Rappel des principes : jamais de pay-to-win ; mêmes statistiques en gratuit et en premium.

### F. Parcours essentiels (décision 8)
À vérifier dans les 9 langues, sur ordinateur et sur téléphone :
création du compte et du personnage ; premier emploi et premier salaire ; déplacement entre villes et entre pays ; commerce (acheter, vendre, louer un local) ; élection et prise de poste ; partis de Sovarka ; crime, détection, arrestation, justice, détention ; hospitalisation à 0 PA ; courrier et forums (avec la traduction entre joueurs) ; achat d'une option premium.
La liste « À vérifier en jeu » de RELAIS.md est à solder pendant ce mois.

### G. Bêta élargie (décision 11)
- Inscription ouverte ou sur invitation à partir de fin novembre.
- Canal de retours pour les testeurs (Discord, avec salons par langue).
- Mesure de l'entonnoir (choix technique de Claude, outil gratuit de type PostHog) : inscription → premier ordre → retour à J1 → J7, pour voir où les nouveaux décrochent.

### H. Robustesse (23/11 → 19/12)
- Contrôles CI au vert sur `main`, à commencer par « bancs-hors-production ».
- Essai de charge du serveur (Supabase, Vercel) avec beaucoup de joueurs simultanés.
- Aucun nouveau contenu pendant cette période, seulement des corrections.

## Calendrier

| Période | Objectif |
|---|---|
| 16/11 → 22/11 | Starovka terminée ; démarrage de B (traduction des joueurs) et de D (textes juridiques) |
| 23/11 → 30/11 | B et D terminés ; ouverture de la bêta élargie |
| 1/12 → 12/12 | Parcours essentiels (F) dans les 9 langues ; options premium (E) ; corrections |
| 13/12 → 18/12 | Paiement en essai, dernières corrections, gel total du code le 18 au soir |
| **19/12** | **Lancement mondial** |

## Répartition proposée (à valider par Fred)

- **Claude** : fin de Starovka (A), traduction des textes des joueurs (B), paiement et options premium (E), mesure de l'entonnoir (G).
- **Codex** : catalogues de traduction et fidélité (C), jouabilité sur téléphone, parcours essentiels dans les 9 langues (F).
- **ChatGPT** : images, textes juridiques (D), livraison groupée et production, charge du serveur (H).
- Règle commune : un chantier = un agent ; tout chantier pris s'annonce dans RELAIS.md avant de commencer, pour éviter les conflits.
