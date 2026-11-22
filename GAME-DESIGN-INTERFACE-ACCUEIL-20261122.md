# Interface, accueil, tabac-presse, crue — décisions de Fred (22/11/2026, soir)

Mission « Suites de Santé, interface et accueil ». La partie A (suites de la Santé) est consignée dans
GAME-DESIGN-SANTE-20261122.md (section « Suites »). Texte consigné tel quel. Règles : le serveur décide de tout ; toute valeur
chiffrée va dans une table de paramètres réglable par le MJ ; aucun texte plus petit que le texte courant ; nouvelles clés de
traduction listées pour Codex dans RELAIS.md.

## PARTIE B — BUG DE L'ORGANIGRAMME

15. Dans « Organigramme national — Sovarka », Arnie apparaît Ministre de la Défense de la Patrie, alors que postes_attribues n'a qu'une ligne pour lui (republic_min_def_national, country = republic) et que sa fiche a nationalite = republic, country = soviet (il est à Krasnov) et poste = {"id":"min_def"} sans pays. Corrige les organigrammes national et municipal pour qu'ils lisent uniquement postes_attribues, filtré sur le pays affiché (et la ville pour les postes municipaux).
16. Cherche partout (navigateur, api, fonctions SQL de production) chaque endroit qui déduit le pays d'un poste de personnages.country ou compare poste.id sans pays : habilitations, ordres réservés, salaires, nominations, révocations, panneau du personnage, liste des PJ, élections. Corrige-les tous : un personnage en voyage garde son poste et ses pouvoirs dans son pays et n'obtient jamais aucun pouvoir du pays où il se trouve. Ne modifie aucune ligne de postes_attribues ni le poste d'aucun personnage. Liste les endroits corrigés.

## PARTIE C — REGROUPEMENT DES ORDRES DANS LES PIÈCES

17. « Inspecter la pièce » devient une fenêtre unique à trois volets : « Ce qui est installé ici » (liste du matériel installé non caché, caméras exclues, 0 PA, avec en face de chaque matériel qui n'est pas au joueur un bouton « Voler » qui applique les règles existantes de voler_materiel) ; « Fouiller les lieux » (1 PA, personne cachée ou caméra) ; « Désinstaller », légal, seulement à côté du matériel du joueur, ou de tout le matériel quand il est chez lui. Le bouton « Désinstaller du matériel » disparaît de toutes les pièces ; désinstaller le matériel d'autrui n'existe plus, cela passe uniquement par le vol. « Se cacher » reste un ordre à part.
18. Accueil des mairies, dans tous les pays : ordre « Élections » (calendrier électoral et organigramme) et ordre « Guichet » (une fenêtre avec les démarches administratives de la mairie, chacune avec une phrase d'explication : en Sovarka État civil, Réclamer un objet trouvé, Demander un commerce, Bons d'État ; en Républia les démarches équivalentes déjà présentes). « Héros du Travail » reste à part.
19. Salle des partis : ordre « Les partis » (liste des partis et demande d'adhésion ; volet « Créer un parti » pour qui n'a pas de parti ; volets « Mon parti » et « Extrait d'enregistrement » pour un membre) et ordre « Dénonciations » (poster et registre).
20. Bureau du syndicat : ordre « Le syndicat » (consulter pour tous ; Adhérer pour un non-membre ; Quitter et Déclencher une élection pour un membre) et ordre « Fonctions du chef du syndicat ».
21. Règle générale pour tous les postes : dans le bureau de chaque fonction (maire, maire adjoint, ministres, commissaire, directeurs, juge, chef du syndicat…), un seul bouton « Fonctions de [poste] » regroupe ses ordres réservés, rangés par thème avec leurs sous-menus. Visible par tous : le titulaire agit, les autres lisent en lecture seule ce que le poste permet, une phrase par pouvoir et la mention « Réservé au [poste] ». Le bureau du maire y range aussi « Dossiers commerciaux ».
22. Relevé, sans rien coder : après ces changements, liste dans le rapport chaque pièce qui affiche encore plus de 6 ordres, avec ta proposition de regroupement.

## PARTIE D — ACCUEIL DES NOUVEAUX JOUEURS

23. À la première connexion, une interview RP s'ouvre d'elle-même, en réutilisant le mécanisme existant d'interviews_jodie : Jodie Moitout en Républia ; en Sovarka, nouvelle PNJ Vera Pravdina, journaliste de « La Voix de Sovarka » (si un journaliste PNJ existe déjà en Sovarka, signale-le dans le rapport, mais crée Vera). Elle propose six chemins : la politique, les affaires, l'intrigue et l'influence, le crime, l'uniforme (armée ou police), la belle vie ; le joueur peut ajouter un mot à lui. L'article est publié comme aujourd'hui ; en Sovarka, il est retouché à la gloire du Parti.
24. Chaque chemin dépose dans « Mes objectifs » un parcours de trois étapes concrètes, avec le lieu où aller, bâties uniquement sur des ordres existants du pays du joueur ; la troisième le confie au PNJ référent du domaine. Exemple politique : consulter le calendrier électoral à la mairie, adhérer à un parti ou en créer un, postuler à un premier poste. Écris les étapes des six chemins pour les deux pays et liste-les dans le rapport.
25. En se fermant, la fenêtre de l'interview se réduit et file vers « Mes objectifs ». Fermée sans réponse, l'interview reste dans « Mes objectifs » comme première étape (« Jodie Moitout vous attend pour une interview »), à reprendre ou ignorer. Tous les personnages qui n'ont jamais fait l'interview la reçoivent à leur prochaine connexion.
26. Au premier ordre qui coûte des PA, la jauge des PA s'allume et une bulle HRP s'ouvre à côté : « Vous venez de dépenser X PA. Les PA sont votre énergie du jour : chaque action en coûte. Dormir les recharge. À 0, c'est l'hôpital. » Une seule fois par personnage.

## PARTIE E — TABAC-PRESSE DE KRASNOV

27. Le produit devient « Cigarettes papirossy « Étoile du Nord » » : elles arrivent dans l'inventaire et se fument quand on veut, comme les chocolats à emporter, +2 Moral à la consommation.
28. Carte postale (bug) : ajoute dans l'inventaire l'action « Écrire et envoyer » : le joueur rédige un message, choisit un personnage destinataire, et la carte arrive dans son inventaire avec l'image au recto et, au verso, le message signé de l'expéditeur ; un clic retourne la carte. Une carte ne s'écrit qu'une fois. Les cartes, vierges ou écrites, et les revues lues sont acceptées par les armoires à souvenirs. Corrige la description : « sous la pluie d'automne » au lieu de « sous la neige ». Sous l'image, la fenêtre affiche la légende traduite « Krasnov, capitale de l'ours » (clé de traduction ; une légende par carte de ville). Fred fournira plus tard une nouvelle image de recto avec le titre en russe : garde l'image actuelle d'ici là.
29. Revue « Chasse, Pêche & Tracteurs » : +1 ENT pendant 24 h à partir de l'achat, non cumulable (un nouvel achat pendant le bonus ne l'augmente ni ne le prolonge). Elle reste dans l'inventaire comme objet de collection, avec le numéro du mois.
    → Points 27 à 29 préparés le 22/11 (soir, Claude) : migration 20261123150000_tabac_presse_crue (écrite, NON appliquée).
    Cigarettes : famille de produit « tabac », fumées par inventaire_consommer, +2 Moral (réglage aliments_parametres.papirossy_moral).
    Carte : écrite une seule fois par le serveur (carte_postale_envoyer), sas objets_recus et plafond commun des dons ; le bug
    venait de la fenêtre de détail de l'onglet Inventaire, qui n'avait pas l'action « Écrire et envoyer ». Recto (image et
    légende), un clic la retourne (message signé). Une clé de légende par carte de ville : seule Krasnov a son texte ; les neuf
    autres attendent celui de Fred. Armoires : le critère serveur (souvenir_utilisable_interne) accepte cartes et revues lues,
    mais le dépôt dans l'armoire n'est toujours pas codé (décision du 13/11). Revue : bonus de 24 h posé à l'achat
    (revue_ent_bonus, revue_ent_heures), non cumulable, revue gardée « lue » avec le numéro du mois.

## PARTIE F — CRUE

30. Principe : un événement climatique peut coûter quelque chose, il ne bloque jamais le jeu d'un joueur. La crue arrête seulement tous les chantiers de la ville pendant une journée (le chantier prend un jour de retard). Supprime les sacs de sable (vente et pose), les pertes de stock et toute fermeture de lieu. Garde l'alerte 48 h avant, le filtre de pluie, le message clignotant et sa pop-up, avec des textes mis à jour.
31. État de catastrophe naturelle : retiré de l'interface, fonction serveur conservée mais désactivée par un réglage MJ, notée « en sommeil, intérêt à définir » dans le document de game design. Ne la supprime pas.
32. Relève, sans rien changer, tout autre effet climatique qui empêcherait encore un joueur de jouer, et liste-le dans le rapport.

## PARTIE G — IMAGES DE CHANTIER DE LUTHÉCIA

33. Fred joint images-chantier-luthecia.zip (6 images : luthecia-gros-oeuvre-bas, luthecia-facade-bas, luthecia-final-hangar, luthecia-final-commerce-standard, luthecia-final-commerce-premium, luthecia-final-logement). Renomme-les selon les noms que le code attend, convertis-les au format des autres images et branche-les.
    → Fait le 22/11 (soir) : images/chantiers/luthecia/{gros-oeuvre-bas, facade-bas, final-hangar, final-commerce-standard,
    final-commerce-premium, final-logement}.webp (WebP, qualité 82, format d'origine 1672×941 conservé, sans recadrage).

## POUR FINIR

34. Mise en ligne, RELAIS.md et AGENTS.md à jour.
35. Tests de bout en bout sur la vraie base, dans une transaction annulée, avec vérification après coup qu'il ne reste rien : organigrammes d'Arnie à Krasnov puis à Luthécia ; inspecter une pièce avec du matériel à soi et à autrui ; un plat de joueur à 15 PSK ; production de médicaments sans matière première (refusée) puis avec ; reversement de l'excédent d'une usine ; antidote pris puis réveil ; carte postale écrite, envoyée, reçue, retournée et rangée dans une armoire ; revue achetée deux fois dans les 24 h ; crue sur une ville avec un chantier en cours ; interview d'un personnage neuf jusqu'à la première étape de « Mes objectifs », puis bulle des PA.
36. Rapport final unique, point par point dans l'ordre de cette mission : fait / partiel / non fait, avec la raison pour chaque point non terminé.

## Règles de travail

- Migrations écrites à partir des définitions de PRODUCTION (pg_get_functiondef), éprouvées sur PGlite, annoncées une par une
  juste avant le lancement pour validation à l'écran ; une validation expirée : une seule ligne « migration X en attente », arrêt.
- Rien du goulag (sovarka_goulag_*, configuration active=false conservée).
