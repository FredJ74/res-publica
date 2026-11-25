# Préparations du lancement (non appliquées)

Scripts SQL **préparés pour une opération unique**, jamais exécutés tant que Fred
n'a pas donné son feu vert explicite le jour dit. Ce ne sont pas des migrations :
aucun outil ne les rejoue.

| Fichier | Rôle |
|---|---|
| `remise-a-zero-20261219.sql` | remise à zéro du 19/12/2026, **généré** par `outils/lancement/generer-remise-a-zero.py` (ne pas l'éditer à la main) |
| `remise-a-zero.modele.sql` | son modèle (garde-fous, relevé, effacement, offre des testeurs) |

Mode d'emploi et banc : `docs/premium/REMISE-A-ZERO-20261219.md`.
