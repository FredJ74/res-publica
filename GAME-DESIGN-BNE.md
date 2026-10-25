# Game design du Bureau National de l'Emploi — décisions de Fred

Référence commune à Codex et Claude. **Ce fichier dit ce que Fred a décidé** ;
l'état du code est dans `AUDIT_BNE.md`. Tenir ce fichier à jour à chaque nouvel
arbitrage. Décisions du 25 octobre 2026, qui **remplacent** la formule d'août
(sept offres fictives).

## Principe

Le Bureau ne recrute pas lui-même. Il fait deux choses :
1. il **recense** les postes réels du jeu qu'un joueur peut occuper et qu'un PNJ
   tient faute de joueur ;
2. il **affiche les annonces** que les joueurs passent pour trouver du monde.

Les annonces portent sur Luthécia, les autres villes du pays, et l'international
(qui existe mais ne sera raccordé qu'avec les autres empires).

**Les joueurs passent avant les PNJ.** Le Bureau ne propose **aucun poste
politique** (ministres, Premier ministre, maire adjoint, député…).

## Ce qui disparaît

- Les **sept offres** d'août (serveur, docker, hôtelier, secrétaire, commerçant
  itinérant, conseiller bancaire, hôtesse diplomatique) : fictives, supprimées.
  Le joueur qui en occupe une la perd et reçoit un mail du Bureau qui explique la
  nouvelle formule (ces emplois n'étaient pas payés : il ne perd rien).
- L'**inscription comme demandeur d'emploi** : supprimée. Tout joueur consulte
  et postule directement.
- Le **Bureau de direction** : question reportée à la fin du chantier (pièce
  créée en août par copie du modèle de l'entrepôt, jamais remplie).

## 1. Les postes recensés automatiquement

**Lesquels** : les postes métier, de justice et de police sans titulaire joueur.
D'après le code au 25/10 :

| Poste | Recruteur officiel |
|---|---|
| Directeur de l'Entrepôt (par ville) | Maire |
| Directeur de la Raffinerie, de l'Usine Pharmaceutique, du Pôle Tabac & Alcools | Ministre des Finances |
| Commandant du Port | Ministre des Finances |
| Chef des Douanes | Ministre de l'Intérieur |
| Juge (par ville), Procureur | Ministre de la Justice |
| Commissaire (par ville) | Maire |
| Commandant de la Caserne | Ministre de la Défense |
| Capitaine | Commandant |
| Lieutenant | Capitaine |

**L'armée** : le Bureau affiche « L'armée recrute » et les postes réellement à
pourvoir d'après les unités qui existent (une compagnie sans capitaine joueur =
1 poste de capitaine ; une section = ses places de soldats tenues par des PNJ…).
Commandant, capitaine, lieutenant : « Postulez ici ». Soldats : nombre de places
et « Postulez directement à la caserne » (l'engagement reste celui de la caserne).

**Candidature** : depuis le Bureau, **1 PA pour toute candidature** à un poste (postes de l'État et grades militaires, Fred 25/10), prélevé par le serveur ; un refus ne coûte rien. Les candidatures aux élections et à la présidence d'un club ne sont pas concernées. Le Bureau **transmet** la candidature
au recruteur officiel ; il ne court-circuite pas le recrutement normal. Un joueur
peut postuler à **plusieurs postes** en même temps.

**Décision : le circuit du 25 août 2026 est conservé en entier** (Fred, 25/10 —
la règle du vendredi et du jet d'Entregent, proposée le même jour, est abandonnée) :
- **recruteur PNJ** : le joueur est nommé **tout de suite** ;
- **recruteur joueur** : il a **48 heures** pour choisir ; sinon **tirage au sort**
  parmi les candidats et **popularité du recruteur divisée par deux** ;
- un joueur nommé est **protégé 7 jours** contre une révocation arbitraire.
Capitaine et lieutenant : candidature militaire existante (2 PA), déposable au
Bureau comme à la caserne.

**Le premier poste attribué annule** les autres candidatures du joueur.

## 2. Les annonces des joueurs

**Contenu** : intitulé, descriptif, lieu, salaire — rien d'autre — et
l'**adresse mail du recruteur**, ajoutée automatiquement.

**Gratuites** : le Bureau est un service public gratuit ; une annonce consomme
**1 PA**, reste affichée **7 jours** (le formulaire le dit avant publication),
**sans limite** de nombre par joueur.

**Option payante — parution dans la presse** : le Bureau propose de publier aussi
l'annonce dans La Tribune de Républia, en reprenant l'ordre « Déposer une petite
annonce » et son prix (30 FR, 1 PA, 3 jours) : le joueur ne paie pas plus cher
qu'au journal. **L'argent reste au Bureau**, le journal ne touche rien.

**Le jeu ne code pas l'embauche** : candidatures, choix, négociation se règlent
entre joueurs par mail. Nous sommes dans un JDR, tout ne se code pas.

## 3. La paie

- **Manuelle** : le recruteur paie lui-même ; le jeu ne tient pas de contrat.
- **Virement automatique** pour faciliter : **mis en place à la banque**,
  **arrêté depuis l'interface personnelle** (si l'employé part, on coupe sans se
  déplacer).
- Un employé non payé est libre de partir ; il peut **porter plainte** contre son
  employeur (système de plaintes existant).
- **Selon le genre de travail** :
  - **Chantier** : payé à l'heure de travail (1 PA = 1 heure), par la trésorerie
    du chantier, ordre « Travailler sur le chantier » existant, **laissé
    cliquable** comme aujourd'hui. Le **propriétaire fixe le taux horaire**, au
    moins le **salaire minimum de 50 FR de l'heure**.
  - **Travail au jour** (exemple : sécurité privée d'un bâtiment) : salaire
    journalier, par virement.
  - Travail dans un bâtiment : payé par la caisse du bâtiment ; mercenaires et
    joueurs recrutés pour leurs compétences : par le compte du recruteur.

## Constats techniques liés (25/10)

- Aucun virement d'un joueur à un autre n'existe : à créer avant le virement
  automatique.
- L'ordre « Déposer une petite annonce » de la Tribune est entièrement décidé par
  le navigateur (PA, argent, enregistrement, recette du journal) : à repasser par
  le serveur. Le Bureau n'a pas de caisse : à créer.
- Le taux horaire des chantiers est fixe (70 FR) dans le code.
