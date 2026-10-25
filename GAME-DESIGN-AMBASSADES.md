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

### Asile politique (25/10 — réalisable dès Luthécia)
- Demande à l'accueil du hall ; l'ambassadeur **accepte ou refuse**.
- Ambassadeur PNJ : décision **selon le dossier** — accepté si le joueur est
  réellement menacé (recherché, poursuivi, condamné), refusé sinon ; réponse par
  mail sous 0 à 3 jours, comme l'audience.
- Réfugié accepté : **protégé dans l'ambassade** qui l'accueille (accès à son
  bureau, impossible à arrêter tant qu'il y est), **arrêtable dès qu'il sort du
  Quartier des Ambassades**.

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

### Réceptions et relations (25/10 — avec les autres empires)
L'ambassadeur invite des joueurs du pays hôte dans la salle de réception ; les
invités présents améliorent la relation entre les deux pays, et un traité
proposé par le ministre a plus de chances d'aboutir si l'ambassadeur a préparé
le terrain. Suppose un **Indice Diplomatique réel et partagé** (question ouverte
de l'audit).

## Écartés par Fred

- **Politique des visas** (25/10) : trop complexe pour l'instant.
- **Dépêches diplomatiques** hebdomadaires de l'ambassadeur au ministre (25/10).
- Protection consulaire au-delà de la demande de transfert (25/10).

## Questions encore ouvertes

- L'Indice Diplomatique : le rendre réel et partagé, ou le retirer de
  l'affichage tant qu'il ne l'est pas.
- La « faveur » obtenue en corrompant un homologue.
- Les ordres d'ambassade non raccordables : les passer en « Bientôt disponible ».
