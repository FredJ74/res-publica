# Remontées du test en forêt de Krasnov, 22/11/2026 fin de nuit — texte de Fred, mot pour mot

```text
MISSION SUIVANTE – HUMAN GAMBIT (22/11/2026, fin de nuit) – REMONTÉES DU TEST EN FORÊT DE KRASNOV

0. ORDRE ET RÈGLES
- Si la mission précédente (22/11, nuit : chantier, types de bâtiments, forum, H à K, images…) n'est pas terminée, termine-la entièrement et rends son rapport, puis enchaîne directement sur celle-ci sans attendre de feu vert. Les deux rapports peuvent être fusionnés en un seul.
- Règles inchangées : relire RELAIS.md et AGENTS.md ; ne jamais toucher au goulag (active=false à conserver) ; contrôle en lecture après chaque migration ; toi seul migres (Codex travaille côté navigateur sur sa branche : logo, courrier de bienvenue, fenêtres, PR #1176) ; noter dans RELAIS.md les fichiers du navigateur modifiés ; relancer compresser-catalogues-i18n.cjs après tout changement de catalogue.
- Tu restes autorisé à modifier entièrement les fonctions communes nécessaires, avec contrôle et rejeu des tests après chacune.
- Principe : « codons comme pour un enfant ». Chaque fenêtre comprise au premier coup d'œil, jamais d'action sans issue, pédagogie maximale, mise à jour en direct sans jamais recharger la page.
- Pour information : cette nuit, Claude (claude.ai) a corrigé directement en base, pour les tests de Fred : PA d'Arnie et de Tom Tom, sortie d'hôpital d'Arnie (hospitalisation remise à null, deux fois), Revolver .38 ajouté à l'inventaire d'Arnie, et retrait de bois et de peaux de leurs inventaires pour lever une surcharge. Ne pas annuler ces changements.

1. TAILLE DE TEXTE MINIMALE – TOUT LE JEU
- Aucune fenêtre, aucun rapport, aucune note ne doit afficher de texte plus petit que le texte courant des pages du jeu. Passe en revue toutes les fenêtres (rapports de combat, rencontres, mentions grises, notes, infobulles, journaux) et corrige.

2. SYNCHRONISATION EN DIRECT – TOUT LE JEU
- Tout changement doit apparaître aussitôt chez le joueur concerné et chez toutes les personnes présentes, sans rafraîchir ni se déplacer : PA, inventaire, objets déposés et ramassés au sol, arrivées et départs, groupe, masque, cachette.
- Cas constatés : Tom Tom dépose du bois, son stock affiché ne baisse pas ; Arnie ramasse ce bois, il reste affiché au sol chez Tom Tom.

3. INVENTAIRE – DÉPOSER, RAMASSER, CAPACITÉ
- Déposer et ramasser : fenêtre de choix de la quantité (champ + bouton « Tout »), plafonnée à ce que le joueur possède (déposer) ou à la pile au sol et à la place libre (ramasser). Aujourd'hui, déposer se fait une unité par clic.
- On ne peut jamais dépasser sa capacité : ramasser, recevoir un don, acheter, recevoir un butin sont plafonnés à la place libre, avec un message clair (« Votre inventaire ne peut accueillir que 12 unités de plus. »). Aujourd'hui, Arnie et Tom Tom ont pu ramasser au-delà de 100 unités, puis ne pouvaient plus couper de bois.
- Capacité par personnage : remplacer la limite de 100 écrite en dur (inventaire_place_restante et son équivalent côté navigateur) par une capacité propre à chaque personnage, 100 par défaut, réglable par un MJ et utilisée à l'identique par le serveur et le navigateur.

4. DONNER, MONTRER, ÉCHANGER ENTRE MEMBRES D'UN GROUPE
- Tom Tom (chef) n'arrive pas à donner un objet à Arnie (membre de son groupe). La fonction serveur inventaire_donner n'a aucune restriction de groupe : le blocage est dans l'interface (liste des destinataires ou bouton, probablement depuis l'affichage des groupes en bloc). Reproduire dans les deux sens (chef → membre, membre → chef), corriger, et vérifier aussi montrer et échanger un objet.

5. GROUPES – ACTIONS DES MEMBRES
- Un membre de groupe ne perd QUE le droit de se déplacer. Toutes ses autres actions restent ouvertes : couper du bois, récolter, fouiller, donner, combattre, etc.
- Chacun récolte pour lui seul : quand le chef coupe du bois, il reçoit sa propre récolte, sans doublement dû à la présence des membres. Un membre qui coupe reçoit sa récolte dans son inventaire, avec ses PA.
- Seul le chef déclenche une rencontre ou un combat. Les coupes d'un membre ne font jamais apparaître de créature (fausses alertes autorisées pour l'ambiance).
- Combat lancé par le chef : tous les membres présents combattent. Chacun se bat avec son arme, ou à mains nues s'il n'en a pas, et inflige ses propres blessures. Vérifier dans le moteur (militaire_bataille_actions et suivantes) que les membres attaquent réellement, et corriger sinon.
- Butin d'un combat : tout va au chef, SANS doublement (aujourd'hui, 6 viandes sont devenues 12). Le chef redistribue à la main s'il le veut.
- Journal des événements : chaque membre du groupe reçoit le rapport de combat et le récit des rencontres (Olga, ours, loups, fausses alertes). Aujourd'hui, seul le chef reçoit quelque chose.

6. RAPPORT DE COMBAT – NOUVELLE PRÉSENTATION
- Pour chaque round, de haut en bas :
  à gauche, le camp du joueur, un combattant par ligne (le chef en premier, puis les membres) ;
  un trait vertical ;
  à droite, le camp adverse, son premier combattant au même niveau que le chef, les suivants en dessous ;
  à côté de chaque nom, les dégâts subis dans le round (« −12 PA ») ; un combattant tombé garde sa ligne avec son état (coma, en fuite, mort).
- Conclusion à la fin (exemple : « La meute rompt le combat et s'enfuit entre les arbres : ni peau ni viande. »).
- Le vrai nom de l'adversaire partout : plus jamais « 1 à 2 soldats » pour des loups.
- Exemple attendu :
  ROUND 1
  Tom Tom     −0 PA   │   Loup 1   −8 PA (mort)
  Arnie      −6 PA    │   Loup 2   −4 PA
                      │   Loup 3   −0 PA

7. FAUNE DE LA FORÊT DE KRASNOV
- La meute devient trois loups séparés (titre « Meute de 3 loups », combattants « Loup 1 », « Loup 2 », « Loup 3 ») : 8 PA chacun ; chacun attaque une fois par round une cible tirée au hasard pour lui seul ; chacun peut tomber ou fuir séparément ; un loup mort ne frappe plus. Dégâts d'une morsure : environ le tiers des dégâts actuels de la meute (aujourd'hui un seul coup a retiré 27 puis 25 PA à Arnie).
- Pas de plafond de dégâts par round : la forêt reste mortelle.
- L'ours reste un combattant unique.
- Suspense en deux fenêtres pour toutes les rencontres (Olga, ours, loups) : une première fenêtre avec seulement le texte de tension (« Un bruit dans les fourrés… Les branches craquent, une masse sombre approche… vous serrez votre hache. ») ; à sa fermeture, la seconde fenêtre avec l'image, le texte de la rencontre, puis le bonus, le combat ou le butin.

8. FORÊT ET MÉTÉO – AFFICHAGE
- Le bouton « Explorer la forêt » reprend le format des boutons classiques pour entrer dans un bâtiment (taille, police, cadre) ; supprimer le halo, qui donne l'impression d'un problème d'affichage.
- La pluie (et tout effet climatique : orage, blizzard, brouillard, canicule) s'affiche dans toutes les vues en plein air de la ville touchée, y compris le camp de bûcherons et toutes les vues de la forêt. Vérifier toutes les vues en plein air de Sovarka et de la Républia.
- Pictogramme d'alerte climatique : ANNULE la consigne précédente (coin supérieur gauche, trop petit, illisible). L'alerte s'affiche dans un bandeau au-dessus de l'image, centré, en taille normale et lisible, sans jamais couvrir la photo ni une flèche de déplacement.

9. RAPPORT FINAL
- Ce qui est fait, point par point, et ce qui ne l'est pas avec la raison.
- Migrations appliquées (numéro, nom) et contrôles effectués.
- Fichiers du navigateur modifiés (aussi dans RELAIS.md pour Codex).
- Un test de bout en bout rejoué : groupe de deux en forêt, coupe du chef, coupe du membre, combat contre trois loups, rapport affiché aux deux, butin au chef, don d'objet entre eux, dépôt et ramassage avec quantité, tout en direct sans rechargement.
```
