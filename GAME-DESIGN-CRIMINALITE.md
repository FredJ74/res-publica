# Criminalité — règles du game designer

Décisions de Fred, 18 novembre 2026, session claude.ai. **Document en cours : la criminalité ne se limite pas à la neutralisation, d'autres volets restent à trancher. NE PAS CODER avant le prompt complet « Criminalité » de Fred.**

Remplace la note « Assassinats discrets » de `GAME-DESIGN-QUESTIONS-APRES-SOVARKA.md`.

## Esprit

- La criminalité est un moteur de jeu important : ni dissuadée, ni intouchable.
- L'identité de l'assassin doit rester inconnue dans la grande majorité des cas, pour entretenir la tension liée au risque d'être neutralisé.

## 1. Se dissimuler avant d'agir

Trois façons d'agir :

- **À visage découvert** : le PJ apparaît normalement. La victime connaît **toujours** son agresseur, quelle que soit l'issue.
- **Caché** (ordre « Se cacher ») : le PJ est dans la pièce et voit tout, mais n'apparaît pas dans la liste des présents.
- **Masqué** (masque de carnaval revêtu) : le PJ apparaît comme « Individu masqué », sans portrait ; plusieurs masqués dans la même pièce sont numérotés (« Individu masqué n°1 », « n°2 »).
- Caché et masqué se cumulent : débusqué, il n'apparaît que comme individu masqué.

### Se cacher

- 1 PA. Vaut pour la pièce courante ; **reste actif après une tentative de neutralisation**, jusqu'à la sortie de la pièce (même règle à appliquer à l'empoisonnement, qui consomme aujourd'hui la cachette).
- Réussite : **70 % + 5 % par tranche de 20 points de DIS** (95 % à 100 de DIS) **+ 15 % avec la tenue ninja**, **plafond 98 %**.
- **Échec critique** = les 2 derniers points du jet, quel que soit le taux (au plafond de 98 %, tout échec est critique) : **−15 de moral**, rien d'autre.
- Échec ordinaire : seul le PA est perdu, personne n'est prévenu, on peut réessayer.

### Fouiller

- Débusque un PJ caché. 1 PA, ouvert à tous (vérifier si l'ordre existant `fouiller_lieux` peut servir de base).
- Réussite : **40 %** de base, **+2 % par point de PER** du fouilleur, **−1 % par tranche de 10 de DIS** du PJ caché, **−15 %** s'il porte la tenue ninja, **+20 %** pour un policier ou un agent de sécurité privée. **Minimum 10 %, maximum 90 %.**
- Un PJ débusqué perd sa cachette mais garde son masque.

## 2. Neutraliser

- Ouvert à toutes les carrières ; +15 pour la carrière criminelle ; coûts en PA inchangés (2 / 2 / 3) ; formule de réussite actuelle conservée.
- **Frapper depuis sa cachette : +10 % de réussite.** Le masque seul ne donne aucun bonus.
- **Gilet pare-balles revêtu** par la cible : −20 % aux chances de la neutraliser à l'arme à feu, −5 % à mains nues ou à l'arme blanche.

### Réussite

- La victime tombe à 0 PA et part à l'hôpital (règle existante).
- La victime apprend : le nom de l'agresseur s'il était à visage découvert, sinon « un inconnu » (caché) ou « un individu masqué ».
- **Jet de détection** (30 / 40 / 60 % selon le mode) : **−20 si caché, −10 si masqué, minimum 5 %**. Une détection **sans masque** identifie l'assassin ; **avec masque**, elle ne donne pas de nom et laisse seulement une trace.

### Échec

- **Échec critique = 2 % des échecs** :
  - **sans masque** : identité révélée (assassin identifié) et −15 de moral ;
  - **avec masque** : identité non révélée, −15 de moral ; le passage au combat se décide ensuite par le jet normal.
- **Passage au combat** : **10 % des échecs** de base, **+2 % par point de PER de la victime au-dessus de 10**, **+15 %** si la victime a un garde du corps ou une agence de sécurité, **−10 %** si l'assassin était caché ; **minimum 2 %, maximum 40 %**.
- **Échec sans combat** : l'assassin garde sa cachette et peut retenter s'il a des PA. La victime reçoit : « X a tenté de vous neutraliser » (visage découvert), « Quelqu'un a tenté de vous neutraliser » (caché sans masque), « Un individu masqué a tenté de vous neutraliser » (masqué).

### Combat

- Le moteur de combat existant ne change pas.
- **Assassin vaincu** : identifié.
- **Assassin vainqueur** : compte comme une réussite (hôpital pour la victime, jet de détection) ; il perd sa cachette mais garde son masque.

## 3. Justice et enquête

- **Pas d'enquête automatique** : la police n'enquête que sur plainte.
- **Assassin identifié** (visage découvert, détection sans masque, échec critique sans masque, défaite au combat) : **recherché par la police et condamné d'office à 2 jours de prison**, sans plainte. La victime peut ensuite porter plainte contre lui pour des **dommages et intérêts** lors d'un procès.
- **Plainte contre X** : l'enquête revient au **commissaire de la ville où l'agression a eu lieu**. Ordre « Enquêter », 2 PA, une tentative par jour et par plainte.
  - Plafond d'identification : **5 %** après une neutralisation réussie, **15 %** après une tentative ratée sans identification.
  - Départ à la moitié du plafond ; bonus jusqu'au plafond : trace (détection), rumeurs vraies visant le coupable, informateur du commissaire dans la ville.
  - Réussite : coupable identifié (recherché, 2 jours de prison d'office ; dommages et intérêts possibles).
  - Première enquête ratée sur une plainte (**une seule fois par plainte**) : le criminel reçoit « Le commissaire X est sur vos traces. Vous n'êtes pas identifié pour l'instant, mais vous n'avez plus droit à l'erreur. » **−20 de DIS, −15 de moral.**

## 4. Rumeurs

- Pour un agresseur anonyme, les rumeurs donnent des **indices partiels**, façon « Qui est-ce ? » : **le genre** (« l'assassin semblait être une femme ») et **le type précis d'arme** (kalachnikov, revolver, carabine…). Pas l'origine, la carrière ni le domicile.
- Les **traits physiques** s'ajouteront quand le générateur 2D du personnage sera codé.
- Un criminel peut lancer une **fausse piste** avec une rumeur fausse (coût de l'ordre « Lancer une rumeur » actuel).

## 5. Équipement

- Vêtements rangés dans l'inventaire. Ordres **« Revêtir »** (générique : sert aussi au gilet pare-balles et à d'autres accessoires) et **« Retirer »**, **0 PA**. Un vêtement retiré n'a plus d'effet.
- Une **arrestation** retire le masque d'office, avec une **animation de démasquage** (« Bas les masques ! », scène et personnages originaux). À l'hôpital ou en détention, tous les vêtements portés sont retirés et reviennent dans l'inventaire.
- **Tenue ninja** : +15 % à « Se cacher », −15 % aux fouilles qui la visent. Famille Habillement, sous-types *civil* **et** *militaire* (boutique de farces et attrapes / déguisements). Coût de revient 120 FR, prix PNJ 240 FR ; 30 PSK en Sovarka.
- **Masque de carnaval** : anonymat. Famille Habillement, sous-type *civil*. Coût de revient 25 FR, prix PNJ 50 FR ; 8 PSK en Sovarka.
- **Gilet pare-balles** : 380 FR en Républia, **60 PSK en Sovarka** (aujourd'hui vendu au prix de Républia dans l'armurerie de Novomirsk et au Chasse et Pêche de Starovka).

## Plus tard

- Le moral pourrait influencer tous les ordres à jet aléatoire (à étudier).
- Autres volets de la criminalité : à trancher avant le prompt complet.
