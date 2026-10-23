# Occupation #94 — corrections de persistance

Branche issue de PR113 98aa542, main 12c0e05 intégré. Préparée seulement : aucune migration appliquée.

Défauts corrigés : migration non réapplicable ; fin de visite qui ne comparait pas la ville ; refus des parcelles déclarées sans ligne terrains_etat. Le catalogue privé est généré depuis WORLD, les ordres effectifs et SURFACE_TERRAINS. Aucune surface ou valeur absente n'est inventée. La création paresseuse n'écrit que la nouvelle parcelle, sans écraser les propriétaires ou caractéristiques persistantes.

Ordre de déploiement : catalogue 20261023080100 avant activation de la RPC de visite. Installer les migrations avant le client. Si l'ancienne migration PR113 était déjà appliquée, ne pas en modifier l'historique : extraire une migration corrective ultérieure après inspection du catalogue vivant. Le registre vivant est inaccessible ici ; aucune application automatique n'est autorisée sur cette base.

Tests : banc-terrain-occupation-local.py, 32 assertions PostgreSQL réussies ; banc-terrains-referentiel.cjs, 2 tests réussis ; contrôleur client 92/92. Authentification et données de test simulées dans une base jetable. Ni navigation authentifiée réelle ni production vérifiées.

Restent : négociations, police, dissimulation et combat transactionnels. Les deux profils PNJ déclarent tous deux citoyen, sans résistance numérique différenciée ; ne pas inventer le barème. La primitive combat_coup_resoudre référencée par la police préparée n'a pas de définition dans le catalogue archivé. Le socle militaire possède des primitives réutilisables, mais son enveloppe de bataille ne doit pas être appelée avec une bataille fictive. Ces corrections de persistance ne terminent pas le lot occupation.
