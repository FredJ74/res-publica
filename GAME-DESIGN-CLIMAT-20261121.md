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
