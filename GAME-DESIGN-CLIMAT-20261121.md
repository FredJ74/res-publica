# Climat — décisions de Fred du 21/11/2026 (version définitive)

Consigne intégrale, recopiée mot pour mot. Elle remplace la version du matin du 21/11 (crue de 12 heures, etc.).

---

Chantier climat : version définitive des décisions de Fred du 21/11/2026. Ce message REMPLACE intégralement celui envoyé ce matin sur le même sujet (crue de 12 heures, etc.) : plusieurs décisions ont changé depuis. Si tu as déjà commencé à le coder, reprends ton travail pour qu'il corresponde à ce message-ci. Priorité inchangée : PR à part, dès la fin de la PR en cours (marché unique et eau de Krasnov), avant le reste du lot de Krasnov. Raison : cette nuit, un nouveau joueur (Régis, ami de Fred) est arrivé pendant une crue, n'a pas pu se déplacer, n'a pas compris ce qui se passait et a abandonné. Le climat est une menace qui pousse à l'action et crée une atmosphère réaliste ; il ne doit jamais devenir une punition qui fait fuir un joueur.

Consigne d'abord ces décisions mot pour mot sur main dans GAME-DESIGN-CLIMAT-20261121.md (remplace la version de ce matin si tu l'as déjà créée).

1. Diagnostic préalable
Avant toute modification, relis le code de la crue et établis ce qu'elle fait réellement aujourd'hui : déplacements bloqués, lieux fermés, affichage sur la carte de la ville (le joueur a décrit une « carte zébrée ») et dans les vues de rue. Indique dans ton rapport la cause exacte du blocage subi par Régis.

2. Déplacements et lieux fermés
- Un événement climatique n'entrave jamais les déplacements : on circule partout, on peut toujours rejoindre la gare et partir.
- La gare n'est jamais touchée par une crue : exclue du tirage des lieux inondés, dans toutes les villes.
- Crue : un commerce ou un entrepôt protégé par des sacs de sable reste ouvert et garde ses stocks. Seuls les lieux non protégés parmi les 2 ou 3 lieux tirés (règle de tirage inchangée) sont fermés et perdent 20 % de leurs stocks. Toute tentative d'entrée dans un lieu fermé affiche un message clair : cause, durée restante, ce que le joueur peut faire en attendant.

3. Durées
- Crue, orage, canicule et brouillard durent 6 heures dans une ville. Tous leurs effets suivent cette durée : lieux fermés, chantiers bloqués, coupures de l'orage, effets de la canicule, bonus aux actes illégaux du brouillard, filtres visuels, alerte des vues de rue.
- Le blizzard reste un coup ponctuel, règles inchangées.
- Fréquences, propagation d'une ville à l'autre et alerte 48 heures avant : inchangées, sous réserve du point 4.

4. Un seul événement à la fois par pays
Deux événements climatiques ne peuvent jamais se chevaucher dans un même pays, même dans deux villes différentes. Tant qu'un événement n'a pas fini de traverser toutes les villes du pays, aucun autre ne se déclenche ; un tirage qui tomberait pendant cette période est reporté après la fin de l'événement en cours. Les alertes 48 heures avant suivent la même règle : jamais deux alertes d'événements différents en même temps dans un pays.

5. Aucune exemption
Un nouveau personnage subit les événements exactement comme les autres personnages de la ville.

6. Pédagogie
6a. Alertes 48 heures avant : chaque alerte (presse, journal d'événements, message du gouvernement) explique la menace, ses conséquences et la parade, avec le lieu où se procurer la protection. Reprends les textes du point 7.
6b. Alerte pendant l'événement, dans les vues de rue : le message clignotant actuel devient un pictogramme dans un triangle jaune, avec le texte en dessous, clignotant lentement, sans agressivité. Les flèches de navigation restent nettes au-dessus. Pictogrammes (dessine-les en SVG, style signalétique officielle, trait noir sur fond jaune) :
- Orage : éclair — « Attention : orage »
- Crue : vagues — « Attention : crue »
- Canicule : soleil et thermomètre — « Attention : canicule »
- Brouillard : nappes horizontales — « Attention : brouillard »
- Blizzard : flocon — « Attention : blizzard »
6c. Un clic sur l'alerte ouvre une fenêtre qui affiche la durée restante, puis le texte du point 7 correspondant.
6d. Un nouveau personnage qui arrive dans une ville touchée par un événement en cours reçoit à son arrivée la même fenêtre, précédée d'une phrase d'accueil bienveillante expliquant qu'un événement climatique frappe la ville en ce moment. Une seule fois par événement.
6e. Sur la carte de la ville, tout lieu marqué par un événement (hachures ou autre marque) affiche au survol et au clic la raison et la durée restante. Aucune marque sans explication.

7. Textes des consignes (fenêtre de l'alerte et alertes 48 heures avant)
Les lieux de vente cités sont ceux décidés par Fred. Vérifie chacun dans le code et corrige le texte si le lieu réel diffère ; signale toute correction dans ton rapport.

Orage :
« Pendant 6 heures, ordinateurs, box et caméras sont hors service : plus de surveillance, de trading à distance ni de piratage, et les chantiers sont à l'arrêt. Débranchez vos appareils électroniques. Pour garder le courant, équipez-vous d'un groupe électrogène, en vente chez le garagiste, avec 5 bidons de carburant. »

Crue :
« Pendant 6 heures, les commerces et entrepôts non protégés de la zone inondable sont fermés et perdent 20 % de leurs stocks, et les chantiers sont à l'arrêt. Sécurisez vos propriétés : posez des sacs de sable, en vente à la quincaillerie (1 PA, valables pour une crue). Les lieux protégés restent ouverts. La gare et tous les déplacements restent libres. »

Canicule :
« Toute personne présente en ville perd 3 PA, et la nourriture portée sur soi devient insalubre. Gardez une bouteille d'eau sur vous et ne transportez pas de nourriture. [LIEU DE L'EAU, voir point 8] En cas de coup de chaleur, achetez des sels de réhydratation en pharmacie. »

Brouillard :
« Pendant 6 heures, les malfaiteurs agissent plus facilement et échappent plus souvent à la police, à la sécurité et aux caméras. Sécurisez vos propriétés : ne laissez rien de précieux sans surveillance, et pensez à engager un agent de sécurité dans une agence de sécurité. » Si la ville possède une agence de sécurité, ajoute son nom en fin de phrase (à Luthécia : « l'agence Grobras »). Si la ville n'en a pas, n'ajoute rien.

Blizzard :
« Le blizzard fait perdre 3 PA à chacun, et la grippe menace ceux qui n'ont plus de forces. Reposez-vous pour garder vos PA : c'est la meilleure protection. Achetez de la graisse animale : de renne à Starovka, d'ours au marché de Krasnov, de castor chez la poissonnière de Novomirsk, ou dans une pharmacie tenue par un joueur. »

8. Eau gratuite aux points d'eau
- Nouvelle action « Remplir une bouteille d'eau » : gratuite, 0 PA, disponible uniquement aux points d'eau. Elle donne une bouteille d'eau, objet identique à la bouteille d'eau existante.
- Premier point d'eau : la fontaine de la statue de l'Ours, place de l'Ours, à Krasnov. Fred désignera les autres points d'eau plus tard et fournira une image pour chacun ; prévois la liste des points d'eau en configuration, pour pouvoir en ajouter sans nouveau développement.
- Tant qu'une ville n'a pas de point d'eau, la bouteille reste disponible là où elle se vend aujourd'hui.
- Dans le texte de la canicule, remplace [LIEU DE L'EAU] par la phrase qui correspond à la ville : « Remplissez-la gratuitement à [nom du point d'eau]. » si la ville a un point d'eau, sinon « En vente à [lieu de vente actuel]. »

9. Contrôle
Tests couvrant : déplacements libres pendant une crue, gare jamais tirée, lieu protégé ouvert et stocks intacts, lieu non protégé fermé avec message, durée de 6 heures pour les quatre événements, jamais deux événements ni deux alertes simultanés dans un pays, alerte cliquable avec fenêtre, fenêtre d'accueil du nouveau personnage affichée une seule fois, remplissage gratuit à la fontaine de la place de l'Ours.
Rapport attendu : cause du blocage subi par Régis, ce qui a changé, lieux de vente corrigés, ce qui reste à décider par Fred.

---

## Complément du 21/11/2026 (lieux de vente des parades), recopié mot pour mot

Complément climat, décisions de Fred du 21/11/2026, à intégrer dans la PR climat (claude/climat-crue-accueil-20261121) avant que Fred l'ouvre. Ajoute ces décisions à GAME-DESIGN-CLIMAT-20261121.md.

Principe à consigner : certains commerces n'existent volontairement que dans une seule ville. Ce sont des vitrines, pour donner aux joueurs l'envie d'ouvrir le même genre de commerce dans leur ville. En attendant, les parades climatiques doivent toujours pouvoir s'acheter quelque part dans chaque pays.

1. Groupe électrogène et carburant en Républia
- Le groupe électrogène et les bidons de carburant (5 bidons par journée de coupure, règle inchangée) sont vendus à la quincaillerie, en plus du garagiste là où il existe.
- Prix : règle commune des prix du jeu.

2. Sels de réhydratation
- Les sels de réhydratation (parade du coup de chaleur) sont produits et vendus à l'usine pharmaceutique de Républia et à l'usine pharmaceutique de Novomirsk, en plus des pharmacies ouvertes par des joueurs.
- Prix : règle commune des prix du jeu.

3. Textes des consignes
Mets à jour les consignes de l'orage et de la canicule (alertes 48 heures avant, presse, journal, message du gouvernement, fenêtre de l'alerte) pour qu'elles citent les vrais lieux de vente de chaque ville, avec le nom de la ville quand le commerce n'existe que dans une autre :
- Orage : « équipez-vous d'un groupe électrogène, en vente à la quincaillerie [de ville], avec 5 bidons de carburant ».
- Canicule : « En cas de coup de chaleur, achetez des sels de réhydratation à l'usine pharmaceutique [de ville] ou dans une pharmacie. »
Une consigne ne doit jamais renvoyer vers un lieu qui n'existe pas dans le pays.

Contrôle : test qui vérifie, pour chaque pays, que chaque parade citée dans une consigne est réellement en vente dans au moins un lieu de ce pays. Confirme quand c'est intégré.

---

## Décisions de Fred du 21/11/2026 sur les questions des parades, recopiées mot pour mot

1. Sels de réhydratation en Sovarka : règle de moitié prix, soit 22 PSK (44 FR en Républia, inchangé).
2. Port-Sainte-Marie sans quincaillerie : c'est voulu. Aux joueurs de créer les commerces qui manquent ; la consigne continue de renvoyer aux quincailleries de Luthécia et de Montrouge.
3. Bidons de carburant en Sovarka : vends-les aussi au garage de Novomirsk, au même prix qu'à la station-service de Krasnov, pour qu'on y trouve le groupe électrogène et son carburant au même endroit. Mets à jour la consigne de l'orage en Sovarka en conséquence, et refais passer le contrôle des parades pays par pays.

---

## Décisions de Fred du 21/11/2026 sur les quatre questions climat, recopiées mot pour mot

> ⚠️ Message reçu tronqué : il s'arrête à « Contrôle : tests ». La liste des tests est à compléter dès que Fred la renverra.

Décisions de Fred du 21/11/2026 sur tes quatre questions climat. Ajoute-les mot pour mot à GAME-DESIGN-CLIMAT-20261121.md et intègre-les dans la PR climat (claude/climat-crue-accueil-20261121).
Rappel : la pause sur Supabase en production est toujours en vigueur (Codex termine les migrations du goulag). Prépare et teste les migrations nécessaires en local, versionne-les, mais ne les applique pas en production avant le feu vert de Fred.

Q1 – Horaire : l'heure de début de chaque événement climatique est tirée au hasard sur les 24 heures, uniformément, car le jeu sera joué dans le monde entier. Durée de 6 heures inchangée. L'alerte reste donnée 48 heures avant et annonce l'heure exacte de début (heure du jeu), dans la presse, le journal d'événements, le message du gouvernement et la fenêtre de l'alerte. Applique-le aussi aux événements déjà planifiés.

Q2 – Cadence : le brouillard passe à 1 par mois et par ville, dans les deux pays. Recalcule le calendrier pour que crues, orages et canicules reviennent à leur date quand c'est possible, toujours avec la règle d'un seul événement à la fois par pays et 48 heures d'écart. Indique dans ton rapport les dates qui bougent.

Q3 – Catastrophe naturelle : une seule option. Si le Premier ministre déclare l'état de catastrophe naturelle, tous les sinistrés sont indemnisés à 50 % de la valeur des stocks perdus. Il reste libre de ne pas la déclarer.
Définition du sinistré : le propriétaire d'un commerce ou d'un entrepôt tiré par la crue, non protégé par des sacs de sable, qui a réellement perdu des stocks.
- Un lieu protégé ne perd rien : il n'est pas sinistré.
- Un lieu tiré mais sans stock ne perd rien : il n'est pas sinistré.
- La fermeture n'est pas indemnisée : seul compte le stock perdu, jamais le manque à gagner.
- L'état de catastrophe naturelle ne concerne que la crue.
Supprime l'option « seulement ceux qui avaient posé des sacs ».

Q4 – Sacs de sable : un seul sac (60 FR, 1 PA pour le poser) protège entièrement un lieu pour une crue. Il remplace définitivement la règle du 19/11 (10 % de perte en moins par sac, 9 sacs au plus) : supprime toute trace de cette ancienne règle dans le code et les textes.

Contrôle : tests

[… message tronqué ici, suite à recevoir …]

---

## Complément du 22/11/2026 (remontées du test en forêt de Krasnov, point 8) — source : `GAME-DESIGN-FORET-TEST-20261122.md`

- **Vues en plein air** : la pluie et tout effet climatique (orage, blizzard, brouillard, canicule, crue) s'affichent dans toutes
  les vues en plein air de la ville touchée, et plus seulement dans les rues : camp de bûcherons et vues de la forêt de Krasnov
  compris. Liste tenue dans `plateau-climat.js` (`PIECES_PLEIN_AIR`) : camp de bûcherons, clairière et quatre vues de la forêt de
  Krasnov ; champs de pétrole de Starovka ; cours des fermes et kolkhozes ; terrains à bâtir ; pelouse du stade ; Parc botanique ;
  quais des ports. Une nouvelle pièce en plein air s'ajoute à cette liste, ou par `pleinAir: true` dans sa fiche (`data.js`).
- **Alerte** : annule le coin supérieur gauche compact du 22/11 (nuit, point 5), jugé trop petit et illisible. L'alerte s'affiche
  dans un **bandeau au-dessus de l'image**, centré, en taille normale (pictogramme, « Attention : orage », lien « Durée et
  consignes »), sans jamais couvrir la photo ni une flèche de déplacement. Seul le pictogramme clignote lentement.

---

## Décision de Fred du 22/11/2026 (soir) — crue et état de catastrophe naturelle — source : `GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md`, points 30 à 32

Cette décision **remplace** tout ce qui précède sur la crue (fermeture des lieux, pertes de stock, sacs de sable Q4).

- **Principe** : un événement climatique peut coûter quelque chose, il ne bloque jamais le jeu d'un joueur.
- **Crue** : elle arrête seulement **tous les chantiers de la ville pendant une journée** : le chantier prend **un jour de
  retard**. Plus aucune fermeture de lieu, plus aucune perte de stock, plus de sacs de sable (ni vente ni pose). Sont gardés :
  l'alerte 48 h avant, le filtre de pluie, le bandeau clignotant et sa fenêtre, avec des textes mis à jour.
  Mise en œuvre (migration `20261123150000_tabac_presse_crue`, partie F) : le travail des joueurs sur les chantiers de la ville
  est refusé du début de la crue jusqu'à minuit de ce jour-là ; la nuit suivante, le chantier n'avance pas (aucun salaire, aucune
  consommation ni commande de matériaux, ligne « crue » dans le journal du chantier). Réglage MJ : « Bloque les chantiers » de la
  crue (`climat_parametres.bloque_chantiers`).
- **État de catastrophe naturelle** : **en sommeil, intérêt à définir.** Retiré de l'interface (boutons des courriers) ; les
  fonctions serveur sont conservées mais refusent tant que le réglage MJ « État de catastrophe naturelle »
  (`climat_parametres.catastrophe_active`, crue) vaut non. Sans pertes de stock, il n'a plus rien à indemniser : son rôle est à
  redéfinir par Fred avant tout réveil.

---

## Décisions de Fred du 24/11/2026 (mission « Purge », bloc D), recopiées mot pour mot

Elles **remplacent** ce qui précède sur ces points (heure de la canicule, chantiers arrêtés par l'orage et le blizzard, villes du
blizzard et de la canicule, fontaine de Starovka).

> D.1 La canicule n'a lieu qu'en journée (typiquement de 12 h à 18 h).
> D.2 Seules la CANICULE et la CRUE arrêtent les chantiers. L'orage et le blizzard ne les arrêtent pas : corrige aussi la consigne d'alerte de l'orage. Le blizzard n'existe qu'à Starovka : vérifie le tirage.
> D.3 L'arrêt doit réellement s'appliquer : la tâche de minuit passe avant la pose des effets. Banc.
> D.4 Canicule : image dédiée, et bouton « Offrir 20 bouteilles d'eau aux ouvriers » (ouvert à tout joueur présent, avec « ? », inscrit au journal du chantier).
> D.5 Starovka est exclue des canicules. Pas de fontaine à Starovka : retire-la avec redirections, et ajoute un banc.
> D.6 Bouteille d'eau à 4 PSK l'unité dans toutes les boutiques « Équipements contre les intempéries » de Sovarka.

### Mise en œuvre (Claude, 24/11/2026 ; migrations `20261124131000` à `20261124136000`, banc `outils/bancs/banc-purge-climat-pglite-20261124.cjs`)

- **D.1** : une canicule commence à **12 h** (heure de Paris, réglage MJ `aliments_parametres.canicule_heure_debut`) et dure
  `climat_parametres.duree_heures` (6 h) : 12 h → 18 h. Les reports « un seul événement à la fois par pays » retombent aussi à 12 h.
  Les canicules déjà planifiées sont ramenées à 12 h le même jour (correction publiée si l'alerte était sortie). Les autres
  événements gardent l'heure tirée au hasard (Q1 du 21/11).
- **D.2** : `climat_parametres.bloque_chantiers` = non pour l'orage et le blizzard (oui pour la crue et la canicule). Consigne de
  l'orage : « Pendant 6 heures, ordinateurs, box et caméras sont hors service : plus de surveillance, de trading à distance ni de
  piratage, mais les chantiers continuent. Débranchez vos appareils électroniques. […] » (remplace « et les chantiers sont à
  l'arrêt » du point 7). Blizzard : table `climat_villes_exclues` (Novomirsk et Krasnov exclues) ; le tirage du mandat ne crée plus
  qu'un blizzard à Starovka ; ceux déjà planifiés à Novomirsk (28/11) et Krasnov (01/12) sont annulés.
- **D.3** : la canicule arrête les chantiers **comme la crue** : travail des joueurs refusé du début de la canicule jusqu'à minuit,
  et la nuit suivante le chantier n'avance pas (ligne « canicule » au journal du chantier, un jour de retard). La nuit lit la
  **date** de début de l'événement, jamais la pose de ses effets : l'ordre entre la tâche de minuit (`api/cron-minuit.js`, non
  modifié) et `climat_passe` (17 de chaque heure) ne compte plus. Cause constatée : la canicule de Luthécia du 22/11 (0 h – 6 h)
  n'avait arrêté aucune nuit de chantier.
- **D.4** : pendant l'arrêt de canicule (du début de la canicule à minuit), la zone d'alerte climatique de la fenêtre du chantier
  affiche l'image dédiée (`images/chantier-alea-canicule.webp`), l'heure de fin de l'arrêt et le bouton « Offrir 20 bouteilles
  d'eau aux ouvriers » avec son « ? ». Ouvert à tout joueur présent sur le terrain (pas seulement le maître d'ouvrage), une fois
  par chantier et par canicule, 0 PA ; les 20 bouteilles (réglage MJ `canicule_eau_ouvriers_bouteilles`) sortent de son
  inventaire ; ligne « eau offerte » au journal du chantier. **Effet choisi par Claude, à confirmer par Fred** : l'eau lève l'arrêt
  de canicule pour ce chantier (travail des joueurs accepté, la nuit suivante le chantier avance) — réglage MJ
  `canicule_eau_leve_arret` (1 = oui, 0 = geste sans effet sur l'arrêt).
