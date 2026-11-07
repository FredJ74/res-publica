# Jouabilité mobile des écrans de Sovarka — 07/11/2026

Base : main `6e157d093398b658d18e4d7ea49f5c00e731f326`.
Branche : `codex/mobile-sovarka-20261107`.

## Inventaire et correction

| Écrans | Socle réutilisé | Constat / couverture |
| --- | --- | --- |
| Garage, révision, véhicules, chargement | `plateau-vehicules.js`, `vehModal`, `cpj-dialogue` | Formulaires et PSK ; sélecteur de cargaison bénéficie de la correction commune |
| Coiffure | `plateau-salon.js`, `vehModal` | Fenêtre réelle testée, bouton conservé |
| Pharmacie et accessoires du salon | catalogue `plateau-commerce-pj.js` | Catalogue partagé, règles L5 existantes ; aucune adaptation économique |
| Logements sociaux | `plateau-logements-sociaux.js`, fenêtre postes | Rendu réel testé ; pas de débordement constaté, aucune réécriture |
| Notaire, droits, dossiers municipaux | `plateau-sovarka-droits.js`, `vehModal` | Sélecteur de local de 62 px illisible sur téléphone : largeur disponible sous 1024 px |
| Galeries, centre d’affaires | demande de location de `plateau-sovarka-droits.js` | Lettre et champ activité dans la même fenêtre ; champs à 100 % contenus par box-sizing |
| Événements des salles de réunion | `plateau-reunions-evenements.js` | Sélecteur de caractéristique bénéficie de la même règle |
| Salle des partis, Soviet | `plateau-sovarka-partis.js`, `plateau-sovarka-pouvoir.js` | Création, liste et Soviet rendus avec fixtures de lecture |
| Caserne en ville | caserne et terminal militaires communs | L7 existant ; aucune variante Sovarka du rendu |
| Direction du Renseignement | panneaux de fonction de `plateau-politique.js` | Fenêtres communes L3/L7, aucun changement de pouvoirs ou de texte |
| Rue Novomirsk V1–V12 et mairie | `plateau-rue-centrale.js` et coque L2 | Aucun raccordement ni destination modifié |

Seuls `style.css` et sa version de cache dans `plateau.html` changent dans le jeu.
Deux règles sous `max-width:1023px` : dimensionnement contenu des champs de
`cpj-dialogue`, sélecteurs `cpj-champ` sur une ligne pleine. Aucun moteur ajouté.
Aucun JS métier, montant, ordre, texte RP, image ou fichier Sovarka modifié.

## Preuves et limites

Le banc `banc-mobile-sovarka.cjs` exécute les fonctions de rendu réelles dans
Chromium avec réponses de lecture isolées. Toute RPC non prévue est refusée.
Aucune connexion de joueur ni opération financière. Les PSK viennent de la
fixture du serveur, aucune correction monétaire locale.

Le témoin CSS compressé provient du main ci-dessus ; SHA-256 contrôlé :
`f1dbccdf30f9caf5ec997c7cf096ed75385f8248c27ba1ba0ff1a498a4fe7fd0`.
La contre-épreuve recharge ce témoin et reproduit le sélecteur trop étroit.
La comparaison bureau porte sur les pixels des fenêtres réelles, à 1440 px.
Les tests à 360, 390 et 768 px contrôlent débordements et largeur des champs.

Résultats finaux et contrôles complets : à compléter après exécution.
Ces rendus locaux ne constituent pas une recette authentifiée en production,
ni un essai matériel Safari/iOS. Aucune migration, écriture ou livraison de
production effectuée. Aucune décision de game design nécessaire.
