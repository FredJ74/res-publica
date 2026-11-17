# Portraits de Starovka — livraison du 17 novembre 2026

Source : planche PNG **Galerie de portraits buryătes chaleureux.png** ajoutée par Fred sur GitHub au commit `f8ba24c`.

## Recette de découpe

- 9 portraits de la planche 3 × 3 (1254 × 1254 px), dans l'ordre de lecture, sans réutilisation des portraits déjà présents.
- 1 portrait du sergent Bair Dorjiev extrait du militaire assis au bureau de droite sur la photographie existante du centre d'écoute.
- Fichiers finaux 512 × 512 px en WebP, JPEG ni PNG nouveaux.
- Découpage et contrôle automatiques par `outils/images/decouper_portraits_starovka_20261117.py`.
- La planche PNG est supprimée **après** création et validation des dix WebP.
- Raccord uniquement des dix noms exacts dans `WORLD.soviet.ville_a` via `data.js`.
- Les portraits déjà présents, notamment **Bookmaker Officiel**, la secrétaire du centre d'affaires et Tömör Ochirov, restent inchangés.
- Conservation des visuels de fond des pièces et des autres villes.
- Recette visuelle effectuée pour Damdin, Dolgor, le meneur des supporters et le sergent ; les six autres portraits sont validés par contrôle d'image et de dimensions et restent à revoir visuellement en jeu.

Le sergent a été rattaché à l'homme assis au bureau de droite, seul visage orienté vers la caméra dans la scène. Cette identification est un choix de mise en scène, non une information explicite du décor.

**Preuves** : workflow `Starovka — découpe et pose des portraits` (10 fichiers WebP validés, `node --check data.js` réussi), commit `832a422`.
