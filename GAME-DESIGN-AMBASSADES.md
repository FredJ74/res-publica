# Game design des ambassades — décisions de Fred

Référence commune à Codex et Claude. **Ce fichier dit ce que Fred a décidé** ;
l'état du code est dans `AUDIT_AMBASSADES.md`. Tenir ce fichier à jour à chaque
nouvel arbitrage.

## Feuille de route (24/10/2026)

Terminer Luthécia, puis Port-Sainte-Marie et Montrouge (fin de Républia), puis
la traduction, puis les trois autres empires en dupliquant le socle de Républia.
Les mécaniques qui supposent un autre empire **existent dans le jeu mais ne sont
raccordées qu'au codage de ces empires**.

## Règle transversale

**Une seule réalité, celle du serveur** : tirages, délais, accords, accès et
statuts sont décidés et enregistrés par le serveur ; l'écran n'affiche que ce
qu'il rend (`AGENTS.md`).

## Les personnages

- **Trois ambassadeurs PNJ** à Luthécia, chacun incarne un défaut :
  - Valery Antonov (Sovarka) : **la rigidité** ;
  - Guillermo Vasquez (El Estado) : **la corruption** ;
  - Mohamed Al-Mansoori (Al-Khalija) : **le snobisme**.
- Fred génère leurs portraits (à brancher sur les fiches quand ils arrivent).
- **Quand un joueur devient ambassadeur**, le PNJ reste dans le bureau comme
  **secrétaire de l'ambassadeur** et devient le **référent en diplomatie**.
- L'hôtesse du hall et le ministre PNJ Jean-Jacques Carlin sont inchangés.

## Ministre et ambassadeur : deux rôles distincts

| Ministre des Affaires étrangères | Ambassadeur |
|---|---|
| Ouvre ou ferme une ambassade, nomme, démet, expulse | Représente son pays sur place |
| Signe les traités, décide des sanctions | Prépare le terrain par les réceptions |
| Accepte ou refuse les transferts de détenus | Demande le transfert d'un ressortissant détenu |
| — | Accepte ou refuse l'asile et la naturalisation |

## Mécaniques décidées

### Audience (en jeu depuis le 24/10)
Demande à l'accueil, 1 PA, une demande en cours par ambassade → mail
« transmise » → ambassadeur PNJ : délai tiré par le serveur entre tout de suite
et 3 jours, **jamais de refus** ; ambassadeur joueur : il accorde quand il veut →
mail « accordée » → bureau ouvert **48 heures** pour ce joueur seul.

### Accès aux bureaux (25/10)
Les trois portes du hall sont cliquables, comme les onglets. Sans invitation :
infobulle **« Accès limité : il faut avoir une invitation. »**
Ont accès : **audience accordée**, **immunité diplomatique** (l'ambassadeur en
poste), **statut de réfugié politique**.

### Asile politique (25/10 — en jeu depuis le 25/10)
- Demande à l'accueil du hall ; l'ambassadeur **accepte ou refuse**.
- Ambassadeur PNJ : décision **selon le dossier** — accepté si le joueur est
  réellement menacé (recherché, poursuivi, condamné), refusé sinon ; réponse par
  mail sous 0 à 3 jours, comme l'audience.
- Réfugié accepté : **protégé dans l'ambassade** qui l'accueille (accès à son
  bureau, impossible à arrêter tant qu'il y est), **arrêtable dès qu'il sort du
  Quartier des Ambassades**.
- Règles d'application posées sans arbitrage contraire : coût 2 PA (coût déjà
  déclaré de l'ordre) ; une seule demande en cours ou un seul asile actif par
  joueur ; une demande refusée peut être renouvelée ; l'asile reste acquis
  (aucune fin prévue pour l'instant).

### Ambassadeur joueur (25/10 — en jeu depuis le 25/10)
- Les quatre actions du ministre (ouvrir, nommer, démettre, expulser) sont faites
  par le serveur : autorité vérifiée, 2 PA, aucun faux succès ; l'échéance
  d'expulsion (24 h) est posée par le serveur et la mission prend fin la nuit.
- L'ambassadeur joueur accorde l'audience et **tranche l'asile** depuis ses mails.
- Les PNJ deviennent **secrétaires de l'ambassadeur**, référents de la diplomatie,
  dès qu'un joueur est en poste (rôle et dialogue).
- **Valise diplomatique** : l'ambassadeur en poste passe la douane de l'aéroport
  sans contrôle.

### Attendent le voyage entre empires (constat du 25/10)
Le jeu ne sait pas encore faire séjourner un joueur dans un autre empire : rien ne
dit au serveur qu'un joueur est « dans le pays hôte ». Restent donc à brancher avec
le voyage : l'immunité, l'arrestation de l'expulsé resté sur place, le transfert
d'un détenu, la naturalisation dans un autre empire.

### Naturalisation (25/10 — avec les autres empires)
La demande se fait à l'ambassade du pays visé ; **l'ambassadeur accepte ou
refuse**.

### Transfert d'un détenu (25/10 — avec les autres empires)
Un ressortissant détenu à l'étranger : l'ambassadeur demande son transfert au
**ministre des Affaires étrangères** de son pays, qui accepte ou refuse. Si
accepté, **transfert automatique** dans la prison de la **ville de domiciliation**
du détenu, dans son pays d'origine.

### Valise diplomatique (25/10 — avec les autres empires)
**Pas de passage en douane pour les ambassadeurs.**

### Immunité diplomatique (25/10 — avec les autres empires)
L'ambassadeur **ne peut pas être arrêté** dans le pays hôte ; il peut seulement
être **expulsé**. Arrestation de l'expulsé qui ne part pas dans les 24 heures :
décision du 15/07 (3 jours de prison), à rétablir avec une vérification de sa
présence dans le pays.

### Rôle de l'ambassade (Fred, 25/10)
L'ambassade est **un outil pour les joueurs**. Elle doit pouvoir remplir plusieurs
rôles : aider les concitoyens perdus dans un autre empire à regagner leur pays,
développer le soft power du pays, servir de sanctuaire aux espions grâce à
l'immunité diplomatique, etc. Human Gambit laisse la place un maximum aux joueurs :
**on ne code pas les interactions humaines**, comme la corruption entre joueurs.

### Indice Diplomatique (Fred, 25/10 — en jeu depuis le 25/10)
**Un indice par pays**, réel, tenu par le serveur (0 à 100, valeurs de départ :
Républia 40, El Estado 20, Sovarka 30, Al-Khalija 50). Toutes les variations
existantes sont gardées et appliquées par le serveur :
- ouvrir une ambassade : +8 ;
- réception diplomatique de l'ambassadeur : voir ci-dessous ;
- mécénat culturel de l'ambassadeur : +3 (et +8 de popularité) ;
- propagande d'État : −5 ;
- déclarer une guerre : −20 ; activer un cessez-le-feu : +10 (une fois par camp) ;
- mobilisation nationale : −5 pour chacun des autres pays ;
- banquet diplomatique du Président : +8 si tous les invités viennent (chacun vient 7 fois sur 10) ;
- réception d'État du Président : +5 si elle réussit (chance selon la popularité) ;
- proposition diplomatique acceptée : +12 (traité) ou +8 (négociations) pour les
  deux pays ; refusée : autant en moins pour le pays qui refuse.

**À quoi il sert concrètement : décidé plus tard** (Fred).

### Réception diplomatique (Fred, 25/10 — en jeu depuis le 25/10)
**Avec présence** : l'ambassadeur réserve la Salle de Réception pour le jour
(1 PA, une ambassade par jour), puis organise la réception (2 PA, 1 200 FR).
Chaque joueur du pays hôte présent dans la Salle de Réception (l'ambassadeur
exclu) rapporte **+1 Indice Diplomatique et +1 popularité** à l'ambassadeur,
plafonnés à **+10 et +5**. **Une réception ratée** (personne) : **−3 et −3**.
Une réception par réservation.

### Corruption d'un homologue local — supprimée (Fred, 25/10)
L'ordre « Corrompre un homologue local » est supprimé des trois bureaux : la
corruption entre joueurs se joue entre joueurs.

### Réceptions et traités (avec les autres empires)
Un traité proposé par le ministre a plus de chances d'aboutir si l'ambassadeur
a préparé le terrain : à raccorder quand l'usage de l'Indice Diplomatique sera
décidé et que les autres empires seront codés.

## Écartés par Fred

- **Politique des visas** (25/10) : trop complexe pour l'instant.
- **Dépêches diplomatiques** hebdomadaires de l'ambassadeur au ministre (25/10).
- Protection consulaire au-delà de la demande de transfert (25/10).

## Questions encore ouvertes

- À quoi sert concrètement l'Indice Diplomatique (Fred : « plus tard »).
- Les ordres d'ambassade non raccordables : les passer en « Bientôt disponible ».
