# Blocus syndical — règles décidées

Décisions de Fred. **Remis en service et passé au serveur le 02/11/2026** (Claude, branche
`claude/blocus-syndical-20261102`, migration `20261102135437_blocus_syndical_serveur`, appliquée en
production le 02/11 ; banc annulé `outils/bancs/banc-blocus-syndical.sql`).

## Décisions explicites de Fred (02/11/2026)

1. **Qui organise et renouvelle** : le Secrétaire Général et le Secrétaire Général Adjoint du
   syndicat, et eux seuls. (Le code laissait passer `gradeIdx` 1-2, soit Délégué et Secrétaire
   Adjoint, et bloquait le Secrétaire Général : à corriger.)
2. **Effet sur le bâtiment bloqué** : on peut entrer dans la première pièce, pas dans les autres ;
   les ordres du bâtiment ne sont pas accessibles.
3. **Ordres qui restent possibles** : ils ne sont pas rattachés au bâtiment. « Renouveler le
   blocus » relève du syndicat (menu du personnage) ; « Faire intervenir les forces de l'ordre »
   relève du commissaire. Conséquence technique : depuis son bureau, le commissaire choisit parmi
   les blocus en cours dans sa ville.

## Décisions explicites de Fred (02/11/2026, après la remise en service)

4. **Participants** : un blocus demande un nombre minimum de participants, PJ ou PNJ. Les PNJ sont
   des syndicalistes PNJ (militants recrutés) ; les PJ sont des syndicalistes qui se groupent au
   leader syndical (Secrétaire Général ou Adjoint). Traduction retenue : l'organisateur, les PJ de son
   groupe membres du même syndicat et présents dans la même pièce, et les militants mobilisés ;
   minimum 2 au total ; un participant PJ compte comme un militant dans les chances et l'intensité.
5. **Coût** : 2 PA par PJ participant, tout ou rien.
6. **Une seule tentative par jour et par syndicat** (le SG et l'Adjoint la partagent), réussie ou non.
7. **Les hôpitaux sont exclus des blocus** : seul lieu où un blocus ne peut pas s'exercer. Appliqué aux
   hôpitaux publics (dispensaires) et à la clinique privée (migration
   `20261102151241_blocus_syndical_hopitaux_exclus`, appliquée le 02/11).

## Règles déjà présentes dans le code (août 2026), conservées

- ~~Prérequis : au moins 2 militants PNJ recrutés~~ remplacé par la décision 4 (2 participants, PJ ou PNJ).
- Réussite : min(90, 10 + 6 × militants mobilisés + puissance/5) % ; intensité : min(90, 10 + 6 × militants).
- Renouvellement quotidien ; fin automatique après 25 h sans renouvellement (nuit).
- Effet de nuit : le maire de la ville perd max(1, intensité/15) POP.
- Dispersion par la police : max(10, min(90, 55 − intensité/3)) % ; les militants restent employés.
- Répression violente : +1 `repressionsSubies` (puissance +8) ; chaque blocus réussi : +1 `blocusReussis` (puissance +5).
- Interdit pendant une grève d'un syndicat de policiers (répression).

## Ce qui est implémenté (02/11/2026)

- **Organiser** (menu du personnage, dans le bâtiment où l'on se tient) : `blocus_syndical_organiser`
  vérifie le grade (Secrétaire Général = rang le plus haut ou chef de l'organisation, Adjoint = rang
  juste en dessous), réunit les participants (décision 4), prélève 2 PA à chaque PJ participant,
  consomme la tentative du jour du syndicat, tire le jet, pose le blocus et ajoute +1 au palmarès
  (migration `20261102144753_blocus_syndical_participants_cout`, appliquée le 02/11).
- **Renouveler** (menu du personnage, à distance) : choix parmi les blocus en cours du syndicat
  (`blocus_syndical_renouveler`).
- **Effet** : le serveur refuse toute pièce autre que la première (déplacement, motif
  `blocus_syndical`) et tout ordre payant rattaché au bâtiment (porte commune des ordres). La liste
  des ordres par bâtiment vient du catalogue effectif (table `blocus_ordres_batiments`, 961 ordres,
  régénérable par `outils/generateurs/generer_blocus_ordres_batiments.py`). « Faire intervenir les
  forces de l'ordre » n'y figure pas. Un joueur déjà dans une pièce intérieure quand le blocus tombe y
  reste, mais ne peut ni passer d'ordre du bâtiment ni changer de pièce, sauf pour revenir à la première.
- **Commissaire** (bureau du commissaire, ordre « Faire intervenir les forces de l'ordre », 2 PA) :
  « Disperser un blocus syndical » ou « Réprimer un blocus syndical par la force », parmi les blocus
  de sa ville (`blocus_syndical_intervenir`). Dispersion réussie : blocus levé, −8 POP au commissaire,
  mail au dirigeant. Répression : le blocus tient, +1 répression subie au syndicat, −15 POP ; refusée
  pendant une grève de policiers. L'indice national de sécurité reste tenu par l'écran, comme pour
  toutes les interventions de police (pas de persistance serveur des indices nationaux).
- **Nuit** : `blocus_nuit_expirer` (fin après 25 h sans renouvellement, mail) et `blocus_nuit_effets`
  (le maire **de la ville** du blocus perd max(1, intensité/15) POP ; l'ancien cron prenait le premier
  maire du pays).
- **Retirés** : « Forcer le passage » et le bonus aux ordres illégaux (remplacés par la décision 2) ;
  le volet « blocus » du ministre de l'Intérieur dans « Réprimer une manifestation » (décision 3 :
  l'intervention relève du commissaire ; ce parcours était d'ailleurs injoignable). L'écran ne peut
  plus écrire la sous-clé `blocus` (`commande_serveur_requise`).

## Points ouverts (à trancher par Fred)

- Conséquence littérale de la décision 2 : dans un commissariat bloqué, le commissaire ne peut plus rejoindre son bureau
  pour intervenir, et les détenus ne peuvent plus tenter de s'évader.

## Règle « une seule réalité » (tenue)

Jet, écriture du blocus sur le bâtiment, palmarès du syndicat, renouvellement, dispersion et
répression par des fonctions serveur ; refus d'entrer au-delà de la première pièce et refus des
ordres du bâtiment tenus par le serveur, pas seulement masqués à l'écran.
