# Mission de jour du 25/11/2026 — décisions de Fred (texte de la consigne)

Source : consigne de Fred du 25/11/2026 au matin (feu vert donné avec le message). Suivi : `docs/suivi-decisions.md`,
section « Mission de jour (25/11/2026) ». Les migrations de cette mission sont écrites mais **non appliquées** : Fred les
valide à son retour ; le code poussé fonctionne sans elles.

## Bloc 1 — Réponses de Fred aux questions de la Purge

1.1 **PNJ guide**
- Le « goût » du nouveau joueur pour le tirage du commerce est le chemin choisi à l'interview ; à défaut de chemin, c'est sa carrière.
- Si l'interview a été fermée sans réponse, la journaliste écrit quand même (au plus tôt le lendemain), pour proposer de la
  reprendre. Son message mène à « Mes objectifs », où l'interview attend. Ton : « Vous m'avez filé entre les doigts l'autre
  jour… on reprend quand vous voulez ? »
- Ce message porte un choix « Ne plus me proposer d'interview d'accueil », qui coupe définitivement cette relance. Ce refus
  ne vaut QUE pour l'interview d'accueil : toute autre interview future (par exemple celle d'un joueur élu président) reste possible.

1.2 **Canicule (D.4)** : les 20 bouteilles d'eau offertes aux ouvriers lèvent l'arrêt du chantier pour la journée en cours
seulement. Si la canicule continue, le chantier s'arrête de nouveau le lendemain. Le réglage MJ `canicule_eau_*` passe à ce
comportement par défaut.

1.3 **Comptes de test (A.1)** : seuls Arnie, Tom Tom et Bernard Bernardov sont des comptes de test. Tous les autres comptes
listés dans `docs/purge/BLOC-A.md` sont de vrais joueurs : ne pas les marquer. Interrupteur de MJ qui réintègre les comptes
de test dans le dépouillement des élections le temps d'un test ; par défaut, ils restent exclus.

1.4 **Forum du tribunal** : les parties à l'affaire et les juges y lisent et écrivent où qu'ils soient. Tous les autres
joueurs le lisent sans y écrire (suivre un procès à distance, rappeler les jours d'audience). Règle contrôlée par le serveur.

1.5 **Format des dates** « 23/11 à 18 h 48 » : aussi au chat et au journal (un seul format partout).

1.6 **Lot 3 de Luthécia (C.6)** : le bâtiment devient « Lot 3 — Terrain à bâtir ». Dans la fenêtre du chantier, le bouton
« Donner » est gardé, discret, sous « Vendre mes matériaux au chantier ».

1.7 **Forêt de Krasnov** : un PNJ bûcheron au campement de la forêt, s'il est visible sur l'image du lieu (le PNJ suit
l'image ; sinon, le noter et ne rien créer). Nom et caractère cohérents avec Krasnov. Fiche DeepSeek, rôle : « Couper du
bois, ça permet de vivre confortablement, sauf si on y laisse un membre dans un combat contre un ours ou des loups… », et la
même explication que Matveï, Nina et le commissaire : « L'ours ne se chasse pas, c'est l'ours qui vous chasse… ». Portrait
recadré depuis l'image s'il y figure.

1.8 **Quêtes « Une affaire mystérieuse »** (trois ébauches générées automatiquement en septembre et octobre) : elles restent
en sommeil, invisibles. Aucun écran de quêtes.

1.9 **Images dont le nom contient des espaces (E.2)** : toutes renommées, avec redirections dans `vercel.json` et mise à jour
des références.

1.10 **Blizzard** : une fois par mandat, à Starovka seulement. Vérifier que le tirage le fait ; ne rien changer s'il le fait déjà.

1.11 En-têtes des quatre migrations du 25/11 (20261125100000 à 130000) : « NON APPLIQUÉE » remplacé par la date d'application.

## Bloc 2 — Chronique de l'empire (journal des événements à deux onglets)

Le journal des événements s'ouvre sur deux onglets : « Mes événements » (le contenu actuel du journal) et « L'empire »
(la chronique publique du pays du joueur, comme on lirait les faits divers et la vie publique) : actes illégaux (vols,
effractions, rumeurs, tentative de vol d'explosifs…), procès (ouverture, audiences, verdicts), décisions des ministères et
des mairies, incidents climatiques ou autres, bagarres (entre joueurs, ou entre joueur et PNJ), rencontres avec l'ours ou le
loup en forêt.
- Anonymat : quand l'auteur d'un acte n'est pas identifié, la chronique montre l'acte sans son auteur. Le nom n'apparaît que
  s'il est publiquement connu : identifié, recherché, arrêté ou jugé. Jamais un indice partiel.
- Lue côté serveur (RPC de lecture), filtrée par pays, de la plus récente à la plus ancienne, dates au format unique. Elle ne
  révèle rien qu'un joueur ne puisse savoir.
- Chaque entrée est courte et lisible par un enfant ; lien vers le lieu quand c'est utile. Comptes de test exclus.

## Bloc 3 — Armoire à souvenirs : dépôt et collection (H.9)

Règles du guide du jeu (`plateau-personnage.js`, « ARMOIRE À SOUVENIRS ») et de `GAME-DESIGN-SERRURES.md`, partie serveur :
- Chaque armoire a sa liste de douze souvenirs, un par grande ville du monde ; plusieurs listes différentes, attribuées aux
  armoires fabriquées ; listes en base.
- Contenu enregistré par le serveur ; seul le souvenir exact de la liste remplit son emplacement ; les autres objets n'y entrent
  pas, sauf les cartes postales.
- Le propriétaire (jouissance du lieu, vérifiée au moment de l'acte) dépose et reprend. Une armoire non verrouillée peut être
  vidée par un visiteur présent : ce n'est pas un vol, mais le propriétaire peut porter plainte pour vol. Fermée à clé, elle ne
  s'ouvre qu'avec une de ses clés.
- Collection complète : avantage de confort au personnage qui dort en présence de son armoire ; plusieurs armoires complètes dans
  la même pièce ne cumulent pas. Valeur reprise des documents si chiffrée, sinon question + réglage MJ.
- Armoire entièrement vidée avant tout déplacement ou désinstallation.
- Cartes postales : gardent leur fonctionnement ; une carte postale peut être l'un des souvenirs de la liste ; celles hors liste se
  rangent dans l'armoire sans compter pour la collection.
- Écran : douze emplacements, « Déposer » depuis l'inventaire, « Reprendre », progression « 7/12 ».
