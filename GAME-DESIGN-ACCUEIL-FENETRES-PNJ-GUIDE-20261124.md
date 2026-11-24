# Accueil, fenêtres et PNJ guide — décisions de Fred (mission « Purge », bloc A, 24/11/2026)

Consigne recopiée mot pour mot (A.6, A.7 et A.9 confiés à un autre agent). Mise en œuvre et lectures retenues en fin de
document ; les questions encore ouvertes sont dans `docs/purge/BLOC-A.md`.

---

═══ BLOC A — ACCUEIL, FENÊTRES ET PNJ GUIDE ═══
Contexte : en arrivant en jeu, le personnage de test « Bernard » a reçu trois fenêtres à la suite (accueil, événement climatique, revue de presse). Le nouveau venu doit pouvoir respirer.

A.1 Comptes de test de Fred : marque-les en base, puis exclus-les des statistiques, des élections et de tous les tirages au sort. À faire en premier : le PNJ guide (A.10) en dépend.

A.2 Nouvelle pop-up d'accueil, à la première connexion d'un nouveau personnage. Elle remplace le contenu de la pop-up de première connexion actuelle. Texte exact (ville et pays de départ en variables) :
« Bienvenue à {ville} en {pays},
Ça doit faire bizarre d'arriver en terre inconnue, mais sache que tu n'es pas seul : on est là pour t'aider.
[image du bouton d'aide]
Demande aussi aux personnages que tu croiseras : ils seront très probablement en mesure de t'aider, de t'orienter.
Je te laisse découvrir un peu la ville, on reviendra vers toi très rapidement. Et si tu as besoin d'aide, n'oublie pas : on est là. »
- L'image est l'icône réelle du bouton d'aide du jeu, celle que le joueur voit dans la barre du haut.
- Elle ne se ferme QUE par la croix : pas de clic à côté, pas de touche Échap, et aucune autre fenêtre ne la ferme ni ne la recouvre. La croix est grande sur téléphone.
- Signature : un personnage du jeu dédié à l'accueil, que Fred créera plus tard. Prévois l'emplacement de son nom et de son portrait, mais laisse-le vide et n'invente aucun personnage. Note-le comme en attente dans le tableau de suivi.

A.3 Calendrier du nouveau venu. Les temps se comptent en minutes de jeu cumulées, d'une connexion à l'autre : un joueur qui se déconnecte au bout de 3 minutes reprend à 3 minutes.
- De 0 à 5 minutes : aucune autre fenêtre, sauf l'avertissement sur les PA, qui reste déclenché au premier ordre qui coûte des PA.
- Entre 5 et 10 minutes (moment tiré au hasard dans la fourchette) : l'interview d'accueil (A.5). Elle remplace le déclenchement « après le 3e déplacement », que tu retires.
- Si le joueur a parlé à un PNJ dans les 5 dernières minutes, l'interview est repoussée de 5 minutes, autant de fois que nécessaire. À 30 minutes de jeu, elle arrive quand même : elle attend seulement que la fenêtre ouverte soit fermée, sans jamais la recouvrir.
- Pendant la première heure de jeu, aucune autre fenêtre automatique : ni événement climatique, ni revue de presse, ni journal du jour, ni proposition de notifications (A.8), ni message du PNJ guide (A.10).
- Après la première heure, et pour tous les joueurs : au plus UNE fenêtre automatique par connexion. Les autres attendent derrière un badge cliquable (icône journal pour la revue de presse et le journal du jour, icône météo pour l'événement climatique). Elles ne se superposent jamais.
- Ce calendrier s'applique aux personnages créés après la mise en ligne, rerolls compris.
- Banc qui rejoue l'arrivée de Bernard : jamais deux fenêtres automatiques à la suite pendant la première heure, rien avant 5 minutes hormis l'avertissement PA, interview repoussée par une conversation avec un PNJ puis forcée à 30 minutes, journal du jour absent avant une heure de jeu.

A.4 Interview : choix du journaliste par pays.
- Le déclencheur jodie_interview_vers_forum écrit « Jodie Moitout » en dur. Choisis le journaliste selon le pays : Jodie Moitout en Républia, Vera Pravdina en Sovarka.
- Filtre par pays la liste du forum de presse.
- Re-signe et reclasse l'article de Bernard.
- Banc pour une interview publiée en Sovarka.

A.5 Contenu de l'interview : la journaliste demande au nouveau ce qu'il veut être. Elle précise que s'il ne le sait pas encore, c'est normal, et qu'il a le temps de se décider. Les six chemins existants restent proposés (politique, affaires, intrigue et influence, crime, uniforme, belle vie). Une interview fermée sans réponse reste reprenable dans « Mes objectifs ».

A.8 Notifications navigateur, pour le chat uniquement :
- Proposées par une bulle (avec « ? ») la première fois qu'un message de chat arrive en jeu, mais jamais pendant la première heure de jeu d'un nouveau venu. Dans ce cas, la bulle attend la fin de cette heure.
- Un réglage pour les activer ou les couper.
- Une notification par interlocuteur jusqu'à la reconnexion, et pas plus d'une par heure.
- Jamais le texte du message : seulement le nom et le lieu, ou « Quelqu'un vous a parlé » si l'interlocuteur est caché ou anonyme.
- Pas de courriel.

A.10 PNJ GUIDE DES NOUVEAUX JOUEURS (décidé par Fred le 24/11)
Deux voix, toutes deux annoncées comme PNJ (badge « PNJ » visible dans le chat) et animées par DeepSeek :
  a) La journaliste de l'interview, qui reprend contact : Jodie Moitout en Républia, Vera Pravdina en Sovarka (même choix par pays qu'en A.4).
  b) Un habitant PNJ par ville jouable, qui repère les nouveaux venus et vient leur parler dans le chat. Crée-en un par ville, avec sa fiche DeepSeek, un nom et un caractère cohérents avec la ville. Place-le dans un lieu existant qui a déjà son image (le PNJ suit l'image ; pas de nouvelle image à produire). Liste dans le rapport les habitants créés, avec ville, lieu et nom.
Contenu de leurs messages :
- Ils orientent vers des TYPES d'activité et vers les PNJ référents, jamais vers un parti ni vers un joueur précis. Exemple de ton : « Tu veux intégrer une équipe, un réseau : les partis recrutent. Plus ils ont d'adhérents, plus ils sont puissants. Va à la mairie, la secrétaire t'expliquera. »
- Ils s'appuient sur le profil du nouveau (carrière, caractéristiques, réponses à l'interview) et sur l'état réel du monde (élections en cours, partis existants, commerces).
- La liste des PNJ référents est lue en base (pnj_referents), pas codée en dur : les référents ajoutés plus tard dans cette mission (bloc G) doivent y apparaître automatiquement.
- Ils peuvent nommer un lieu tenu par un PNJ, ou un commerce tenu par un joueur TIRÉ AU HASARD parmi les commerces ACTIFS qui correspondent au goût ou au métier du nouveau. Actif veut dire : propriétaire connecté dans les 3 derniers jours ET stock disponible. Comptes de test exclus. Jamais deux fois le même commerce pour le même nouveau. S'il n'y a aucun commerce actif qui correspond, ils citent un lieu tenu par un PNJ.
Rythme, pour laisser respirer le nouveau :
- Rien pendant la première heure de jeu (A.3).
- La journaliste écrit au plus tôt le lendemain de l'interview, à une connexion du nouveau, jamais pendant qu'une fenêtre est ouverte.
- L'habitant n'écrit jamais le même jour que la journaliste.
- Au plus UN message de guide par jour, les deux voix confondues, et au plus 3 messages par voix, pendant les 7 jours qui suivent l'inscription. Ensuite, ils s'effacent pour de bon.
- Chaque message est court (2 ou 3 phrases) et ne donne qu'une seule piste.
- Pas de relance si le nouveau ne répond pas.
- S'il leur écrit, ils répondent (DeepSeek, dans le même cadre : jamais de parti ni de joueur précis). Ces réponses ne comptent pas dans les plafonds, mais sont limitées à 5 par jour et par PNJ.
- Sous chaque message de guide, un bouton « Je me débrouille, merci » arrête définitivement les deux voix pour ce joueur.
- Les messages de guide ne déclenchent pas de notification navigateur (A.8).
Bancs :
- Aucun message ne nomme un parti ni un joueur.
- Le tirage exclut les comptes de test et les commerces inactifs.
- Les plafonds et délais sont respectés, et rien n'arrive pendant la première heure.
- Vera Pravdina parle aux nouveaux de Sovarka, Jodie Moitout à ceux de Républia.
- « Je me débrouille, merci » coupe tout.

---

## Mise en œuvre (Claude, 24/11/2026, branche `claude/purge-a-20261124`)

- **A.1** : table `comptes_test` (nom ou compte : un reroll reste marqué), `est_compte_test`, `comptes_test_noms` ;
  tirage des candidatures, dépouillement du cron (copie filtrée du cycle) et tirage du commerce du guide sans compte de test.
- **A.2** : bienvenue dans `plateau-accueil-progressif.js` (module de la PR #1188 repris), mémorisée au serveur
  (`accueil_bienvenue_vue`) ; emplacement de signature lu dans `accueil_parametres_textes` (vide).
- **A.3** : temps de jeu cumulé crédité par le battement de présence (déclencheur `zz_accueil_temps_jeu` sur `presences`),
  interview tirée une fois entre 5 et 10 min, report de 5 min après une conversation PNJ (`accueil_pnj_parle`, appelée par
  `api/chat.js` et par la fenêtre PNJ), forcée à 30 min ; fins de la découverte (5 min) et de la première heure annoncées par
  le serveur. Portier des fenêtres automatiques et badges dans le même module ; délai de respiration de 2 min entre deux
  fenêtres automatiques pendant la première heure (garde de Luthécia, interview non forcée).
- **A.4** : `jodie_interview_vers_forum` signe avec le journaliste du pays ; presse filtrée par pays à l'écran ; article de
  Bernard re-signé Vera Pravdina et rangé en Sovarka.
- **A.5** : question d'accueil réécrite (`accueil_journalistes.question`).
- **A.8** : `plateau-notifications-chat.js`, réglage gardé au serveur (`notifications_chat`).
- **A.10** : migration `20261124106000_pnj_guide`, `api/_pnj-guide.js` (`/api/chat?mode=guide`), `plateau-pnj-guide.js`,
  six habitants guides au marché de chaque ville (fiches dans `api/_pnj-personnalites.js`).

Lectures retenues faute de décision écrite (à confirmer par Fred, voir `docs/purge/BLOC-A.md`) : « goût » = chemin choisi à
l'interview (à défaut, pistes par défaut) ; « reconnexion » = retour sur l'onglet du jeu ou rechargement ; la journaliste
n'écrit que si l'interview a été donnée ; les deux voix ne concernent que les personnages créés après la mise en ligne.
