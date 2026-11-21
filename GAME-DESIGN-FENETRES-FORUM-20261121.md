# Fenêtres et forum — décisions de Fred du 21/11/2026 (consigne intégrale, anti-perte)

Nouveau chantier : fenêtres et forum, décisions de Fred du 21/11/2026. À traiter dans une PR à part, juste après la PR climat du 21/11. Contexte : un nouveau joueur (ami de Fred) n'arrive pas à se servir du forum ni des fenêtres. Principe directeur de Fred : « codons comme pour un enfant ». Le jeu se veut WYSIWYG : un joueur qui n'a jamais rien lu, distrait ou fatigué, doit comprendre chaque fenêtre au premier coup d'œil.

Commence par consigner ces décisions mot pour mot sur main dans GAME-DESIGN-FENETRES-FORUM-20261121.md.

## 1. Fenêtres : aucun chevauchement, jamais

- À l'ouverture, une nouvelle fenêtre se place sous la dernière fenêtre ouverte, sans la recouvrir.
- Il n'y a pas de limite de place : la page s'allonge vers le bas autant que nécessaire et les fenêtres s'empilent.
- Quand le joueur déplace une fenêtre et la lâche en chevauchement d'une autre, elle revient à son emplacement initial et une infobulle s'affiche : « Vos fenêtres ne peuvent pas se superposer : elles seraient illisibles ».
- Règle valable pour toutes les fenêtres du jeu, sans exception.

## 2. Défauts visibles sur la capture du forum (Forum National, sujet « Pour une Révolution Planétaire et Intra-Cosmique. »)

- La première ligne du corps du message affiche deux textes imprimés l'un sur l'autre (le titre ou un texte d'aide superposé au contenu). Trouve la cause et corrige-la pour tous les messages du forum.
- Le bandeau en haut à gauche affiche encore « RES PUBLICA » : remplace-le par « Human Gambit », et cherche dans toute l'interface visible par les joueurs les autres restes de l'ancien nom.

## 3. Forum lisible par un enfant

Passe le forum en revue avec les yeux d'un joueur qui l'ouvre pour la première fois, et applique ces règles :
- Chaque bouton porte un libellé en toutes lettres ; aucune action importante signalée par une icône seule.
- Dans chaque forum ouvert, un bouton « Nouveau sujet » bien visible en haut de la liste ; dans chaque sujet, le bouton « Répondre » visible sans avoir à faire défiler.
- Un forum vide n'affiche jamais une liste vide : il affiche une phrase qui dit qu'aucun sujet n'existe encore et invite à en créer un avec le bouton « Nouveau sujet ».
- Un forum verrouillé (cadenas) dit en clair, au survol et au clic, pourquoi il l'est et qui peut y écrire.
- Le chemin où se trouve le joueur est toujours affiché en haut (par exemple : Forums nationaux › Forum National › titre du sujet), et chaque étape est cliquable pour revenir en arrière.

Dans ton rapport, liste tout autre point du forum qui te semble obscur pour un débutant, sans le modifier : Fred tranchera.

## 4. Contrôle

Tests couvrant : ouverture de plusieurs fenêtres sans chevauchement, retour à l'emplacement initial avec infobulle en cas de chevauchement au lâcher, affichage correct de la première ligne d'un message, absence de « Res Publica » dans l'interface, forum vide avec phrase d'invitation.
