# Audit indépendant du déplacement — 26 octobre 2026

La cinquième campagne authentifiée a confirmé la position initiale d'Arnie, sans déplacement.

## Fonctions serveur vivantes

- `rue_position_enregistrer(p_noeud text)` écrit `current_building`, `current_room`, `current_street` dans `personnages_donnees` et met à jour les interceptions policières.
- Le déclencheur `terrain_visites_deplacement` sur `personnages_donnees` appelle `terrain_visites_clore_interne`, qui peut supprimer des visites actives du joueur lorsqu'il quitte un terrain.
- `rue_position_lire()` et `rue_sortie_batiment_lire()` ne comportent pas d'écriture dans leurs définitions consultées.
- La fonction interne `chantier_besoin_jour_interne(jsonb, integer)` est bien installée sur la base vivante ; `bne_heures_chantiers()` l'appelle.

## Conséquences

Le mouvement n'est pas une simple navigation graphique. Le testeur `consultation_seule` doit conserver l'interdiction d'écrire la position et de circuler avec Arnie.

Les tests du navigateur sur des personnages fictifs, et les tests PostgreSQL jetables, sont les voies sûres pour éprouver le parcours. Ne pas assimiler un banc local à une validation en production.

## Reste à éprouver

- Déplacements, interceptions et fermeture de visites actives sur PostgreSQL isolé.
- Parcours des cinq terrains dans un navigateur isolé.
- Vérification vivante non destructive des droits de lecture, de la sécurité privée et du raccordement BNE.
