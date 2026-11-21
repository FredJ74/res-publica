# Climat — décisions de Fred du 21/11/2026 (consigne intégrale, anti-perte)

Nouveau chantier prioritaire : climat, décisions de Fred du 21/11/2026. À traiter dans une PR à part, dès la fin de la PR en cours (marché unique et eau de Krasnov), avant le reste du lot de Krasnov. Raison : cette nuit, un nouveau joueur (ami de Fred, venu de Genève) est arrivé pendant une crue, n'a pas pu se déplacer et a abandonné le jeu. Le climat ne doit plus jamais faire fuir un joueur.

Commence par consigner ces décisions mot pour mot sur main dans GAME-DESIGN-CLIMAT-20261121.md.

## 1. Diagnostic préalable

Avant toute modification, relis le code de la crue et établis ce qu'elle fait réellement aujourd'hui : quels déplacements elle bloque, quels lieux elle ferme, comment elle s'affiche sur la carte de la ville et dans les vues de rue. Le joueur a décrit une « carte zébrée » et l'impossibilité de bouger. Indique dans ton rapport la cause exacte du blocage.

## 2. Déplacements

- Une crue n'entrave jamais les déplacements : on circule partout dans la ville, on peut toujours rejoindre la gare et partir en train.
- La gare n'est jamais touchée par une crue : exclue du tirage des lieux inondés, dans toutes les villes.
- Les 2 ou 3 lieux touchés par la crue (tirés au hasard et nommés dans l'alerte, règle inchangée) restent fermés : on peut passer devant, pas y entrer. Toute tentative d'entrée affiche un message clair : la cause (crue), la durée restante, et ce que le joueur peut faire en attendant.

## 3. Durées

- Crue, orage, canicule et brouillard durent 12 heures (au lieu de 24 heures, ou de toute la journée pour le brouillard). Tous leurs effets suivent cette durée : lieux fermés, chantiers bloqués, coupures de l'orage, perte de PA et insalubrité de la canicule, bonus aux actes illégaux du brouillard, filtres visuels, message clignotant des vues de rue.
- Le blizzard n'est pas concerné : c'est un coup ponctuel, ses règles restent inchangées.
- Les règles de fréquence, de propagation entre villes et d'alerte 48 heures avant restent inchangées.

## 4. Aucune exemption

Un nouveau personnage subit les événements climatiques exactement comme les autres personnages de la ville. Aucune immunité de départ.

## 5. Information du nouveau joueur

- Un personnage nouvellement créé qui arrive dans une ville où un événement climatique est en cours reçoit, à son arrivée, une fenêtre d'accueil qui explique : l'événement en cours, sa durée restante, les lieux fermés, ce que l'événement change pour lui, et ce qu'il peut faire en attendant. Ton bienveillant, dans l'esprit du jeu. Une seule fois par événement.
- Sur la carte de la ville, tout lieu marqué par un événement climatique (hachures ou autre marque) affiche au survol et au clic la raison du marquage et la durée restante. Une marque ne doit jamais rester sans explication.

## 6. Contrôle

Ajoute des tests couvrant : déplacements possibles pendant une crue, gare jamais tirée, lieux touchés fermés avec message, durée de 12 heures pour les quatre événements, fenêtre d'accueil du nouveau personnage affichée une seule fois. Rapport attendu : cause du blocage d'origine, ce qui a changé, ce qui reste à décider par Fred.
