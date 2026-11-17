# Propositions d'amélioration des mécaniques — en vue du lancement du 19/12/2026

Rédigé par Claude le 16/11/2026 au soir, à la demande de Fred (« travaille sur l'amélioration des mécaniques »).
**Ce sont des propositions, pas des décisions.** Rien n'est codé. Chaque proposition se termine par la question à trancher ; on les prendra une par une.

Cadre respecté :
- **le gel de l'étendue** : aucun nouveau bâtiment, aucune nouvelle ville ;
- **la Constitution**, en particulier l'article 16 : une mécanique doit créer des interactions entre joueurs, pas en remplacer ;
- **la situation du lancement** : peu de joueurs au départ, venus de 9 langues, dont beaucoup essaieront le jeu puis partiront.

Contrôle fait dans le code : il n'existe ni gestion des élus inactifs, ni parrainage, ni objectifs du jour, ni règle contre les comptes multiples.

---

## 1. Les élus inactifs libèrent leur poste — priorité haute

**Problème.** Au lancement, beaucoup de joueurs s'inscriront, prendront un poste (maire, député, chef de parti, directeur) puis abandonneront. Un poste tenu par un absent est pire qu'un poste vide. Le PNJ ne peut plus assurer l'intérim et personne ne peut le prendre. Une ville entière peut se figer.

**Proposition.** Après N jours sans connexion, le titulaire est déclaré **démissionnaire d'office**. Un PNJ reprend l'intérim (article 5 : « en attendant, jamais à la place ») et l'élection ou la nomination habituelle est relancée. L'annonce est publique (journal, courrier aux membres concernés). Un joueur qui sait qu'il va s'absenter peut se déclarer **« en congé »**, ce qui suspend le compteur une fois, pour une durée limitée.

**Constitution.** Articles 5 (une place vide est une invitation) et 14 (pas de blocage).

**Question pour Fred :** combien de jours d'absence avant la démission d'office (par exemple 7 jours pour un poste électif, 5 pour un poste nommé) ?

---

## 2. Parrainage entre joueurs

**Problème.** Les PNJ référents (Pat Hounette, etc.) et le conseiller de l'onglet Aide accueillent bien. Mais l'article 3 dit qu'un joueur vaut mieux qu'un PNJ. Le meilleur accueil, c'est un autre joueur qui vous prend sous son aile, et c'est aussi la première relation, donc le premier attachement.

**Proposition.** Un joueur installé peut se porter **parrain volontaire**. Un nouveau peut choisir un parrain dans une liste, ou en recevoir un proposé dans sa langue ou dans son empire. Le parrain gagne une **reconnaissance visible**, sans aucun avantage de jeu (titre « Mentor », compteur de filleuls restés actifs au moins 7 jours) : jamais d'argent ni de PA, pour ne pas fabriquer des filleuls fictifs. Le parrainage sert aussi au **recrutement** : un joueur qui invite un ami en devient le parrain.

**Constitution.** Articles 1, 3 et 9 (le joueur « chef de bande » ou bavard trouve sa place).

**Question pour Fred :** la récompense du parrain reste-t-elle purement honorifique (titre, compteur), ou lui donne-t-on un petit avantage de prestige, par exemple un bonus de popularité plafonné ?

---

## 3. Tableau des places à prendre

**Problème.** Un nouveau ne voit pas ce qui est disponible pour lui. Or, avec peu de joueurs, presque tout est disponible : postes tenus par des PNJ, commerces sans exploitant, locaux libres, partis sans chef.

**Proposition.** Un **tableau « Places à prendre »** par ville, affiché au hall de la mairie et dans le journal du matin : postes tenus par un PNJ en intérim, commerces et locaux libres, prochaines élections avec date limite de candidature. Le tableau ne fait qu'**informer** : il ne donne rien. Pour prendre la place, il faut toujours passer par le parcours normal (candidature, programme, notaire…).

**Constitution.** Article 5 (« une place vide est une invitation » : encore faut-il que l'invitation soit visible) et article 15 (le jeu dit la vérité sur lui-même).

**Question pour Fred :** ce tableau est-il public pour tous, ou réservé aux domiciliés de la ville ?

---

## 4. Objectifs du jour tournés vers les autres

**Problème.** Le conseiller de l'onglet Aide répond très justement « il n'y a pas de quête principale ». Mais un joueur qui revient le lendemain sans savoir quoi faire ne revient pas le surlendemain.

**Proposition.** Chaque matin, le journal propose **3 objectifs facultatifs**, tirés d'une liste qui ne contient **que des gestes envers d'autres joueurs** : saluer trois personnes, assister à un match ou à une séance, lire un programme électoral, acheter dans le commerce d'un joueur, écrire à un élu… La récompense est minime et non cumulable (par exemple 1 point de popularité, ou une petite somme). Aucun objectif ne peut se remplir seul (article 16). Les objectifs s'adaptent à la vocation déclarée au conseiller d'Aide, si le joueur en a donné une.

**Constitution.** Articles 1, 9 et 16. Une liste d'objectifs solitaires serait anticonstitutionnelle : la liste doit rester sociale.

**Question pour Fred :** une récompense, même minime, ou aucune (simple suggestion) ?

---

## 5. Un compte par personne — priorité haute

**Problème.** Dans un jeu politique ouvert au monde entier, le premier abus sera le **compte multiple** : voter plusieurs fois, fabriquer un parti, se faire des dons à soi-même, tenir les deux camps d'un procès. Avec peu de joueurs au départ, deux ou trois tricheurs suffisent à fausser une élection.

**Proposition.**
- **Règle écrite** dans les CGU : un compte par personne.
- **Détection discrète côté serveur** : même appareil ou même réseau, votes et dons croisés.
- **Traitement par un modérateur humain**, jamais par une sanction automatique : un couple ou une colocation partagent légitimement la même connexion.
- **Déclaration volontaire** : deux joueurs du même foyer peuvent se déclarer, et leurs comptes ne peuvent alors pas voter dans la même élection pour l'autre ni se faire de dons.

**Constitution.** Article 4 (l'arbitrage et l'argent relèvent du code) et article 10 (un contre-pouvoir fictif n'en est pas un).

**Question pour Fred :** pour les joueurs d'un même foyer, interdiction de se soutenir (vote et dons) ou simple déclaration sans restriction ?

---

## 6. Le local personnalisé se visite

**Problème.** Le premium est pensé pour l'attachement (décision 12). Mais selon l'article 11, un local n'existe que parce qu'on y croise quelqu'un. Un décor que personne ne voit attache moins.

**Proposition.** Le local personnalisé s'affiche à tous les visiteurs, avec un **livre d'or** : un visiteur peut laisser un mot de quelques lignes, traduit automatiquement (décision 7), que le propriétaire peut effacer. Ajouter à cela la **liste des visiteurs récents**, visible du seul propriétaire, et on obtient un lieu de rencontre plutôt qu'une vitrine. Pas de nouvelle mécanique d'argent.

**Constitution.** Articles 1 et 11 ; renforce la décision 12.

**Question pour Fred :** le livre d'or est-il réservé aux locaux personnalisés (et devient un argument du premium), ou ouvert à tous les locaux ?

---

## 7. Arrivée concentrée dans les capitales

**Problème.** Avec 6 villes et peu de joueurs, chaque ville risque d'être vide. L'article 11 rappelle qu'un lieu vide n'a pas de sens.

**Proposition.** À la création, le nouveau joueur choisit son empire. Il est domicilié **par défaut dans la capitale** (Luthécia ou Novomirsk), mais garde un **choix libre** en un clic : rien n'est interdit, c'est seulement le chemin proposé. La province se rejoint ensuite par les déplacements normaux. On pourra assouplir ce défaut quand la population le justifiera.

**Constitution.** Article 11. Aucune restriction, donc pas de contradiction avec l'article 13.

**Question pour Fred :** capitale par défaut, ou choix de la ville d'arrivée laissé ouvert sans recommandation ?

---

## 8. La chronique des joueurs en une du journal

**Problème.** Le journal du matin est généré par IA. Pour les spectateurs (article 9) et pour la fierté des acteurs, il doit d'abord raconter **ce que les joueurs ont fait** : élu, condamné, faillite, ouverture d'un commerce, manifestation, record au stade.

**Proposition.** Une règle de rédaction du journal : les événements produits par des joueurs passent **avant** les événements aléatoires du monde. Chaque joueur cité reçoit un courrier « Vous êtes dans le journal ». Les secrets sont respectés : seuls les faits publics y figurent, jamais un acte illégal non découvert, conformément à l'article 6.

**Constitution.** Articles 2 (les histoires appartiennent aux joueurs) et 9 (le spectateur).

**Question pour Fred :** le joueur cité est-il prévenu par courrier, ou découvre-t-il l'article par lui-même ?

---

## Ordre de traitement suggéré

1. **Élus inactifs (1)** et **un compte par personne (5)** : sans eux, le lancement peut se gripper dès la première semaine.
2. **Tableau des places à prendre (3)**, **arrivée dans les capitales (7)** et **chronique (8)** : petits chantiers, effet immédiat sur les nouveaux.
3. **Parrainage (2)** et **objectifs du jour (4)** : rétention à J1 et J7.
4. **Livre d'or (6)** : avec les options premium.

Tous ces chantiers sont petits ou moyens et entrent dans le mois de robustesse, à condition d'être décidés avant le début de la bêta élargie (fin novembre), puisque c'est là qu'on les éprouvera.
