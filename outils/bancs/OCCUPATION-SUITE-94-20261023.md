# Occupation #94 — corrections de persistance

Branche issue de PR113 98aa542, main 33910be intégré. Préparée seulement : aucune migration appliquée.

Défauts corrigés : migration non réapplicable ; fin de visite qui ne comparait pas la ville ; refus des parcelles déclarées sans ligne terrains_etat. Le catalogue privé est généré depuis WORLD, les ordres effectifs et SURFACE_TERRAINS. Aucune surface ou valeur absente n'est inventée. La création paresseuse n'écrit que la nouvelle parcelle, sans écraser les propriétaires ou caractéristiques persistantes.

Ordre de déploiement : catalogue 20261023080100 avant activation de la RPC de visite. Installer les migrations avant le client. Si l'ancienne migration PR113 était déjà appliquée, ne pas en modifier l'historique : extraire une migration corrective ultérieure après inspection du catalogue vivant. Le registre vivant est inaccessible ici ; aucune application automatique n'est autorisée sur cette base.

Tests : banc-terrain-occupation-local.py, 32 assertions PostgreSQL réussies ; banc-terrains-referentiel.cjs, 2 tests réussis ; contrôleur client 93/93. Authentification et données de test simulées dans une base jetable. Ni navigation authentifiée réelle ni production vérifiées.

Restent : négociations, police, dissimulation et combat transactionnels. Les deux profils PNJ déclarent tous deux citoyen, sans résistance numérique différenciée ; ne pas inventer le barème. La primitive combat_coup_resoudre référencée par la police préparée n'a pas de définition dans le catalogue archivé. Le socle militaire possède des primitives réutilisables, mais son enveloppe de bataille ne doit pas être appelée avec une bataille fictive. Ces corrections de persistance ne terminent pas le lot occupation.

Audit du catalogue source : 36 parcelles declarees, 11 superficies absentes (dont 4 a Port-Sainte-Marie et 1 a Montrouge). Le detail est dans `TERRAINS-DONNEES-MANQUANTES-94-20261023.json`. Ce fichier ne decrit pas la base vivante : des lignes persistantes peuvent deja porter les surfaces manquantes dans le code. Aucune valeur completee par conjecture.

## Reprise apres arbitrage du 23 octobre

Arbitrage recu : les deux groupes sont des PNJ beta, les sympathiques moins resistants, aucun nouveau bareme numerique autorise. Les seuils de resultat <50 / 50–89 / 90–100 restent inchanges et ne sont pas reutilises comme defense.

Recherche supplementaire : `historique/sql-racine/migrations/migration_20260921_militaire_combat_v2.sql`, fonctions `militaire_defense_pnj(text)` et `militaire_taux_combat(numeric,numeric,numeric,integer)`. La defense PNJ militaire renvoie 8 pour toute cle ; la difficulte depend de l'entrainement de la cible et du bonus d'arme. Cela offre bien un mecanisme commun de differenciation, mais aucune valeur d'entrainement propre aux deux groupes de squatteurs n'est definie dans les profils examines. Leur relation ally/enemy et le drapeau agressif ne sont pas des valeurs de defense. Reutiliser arbitrairement l'entrainement d'un soldat ou transformer ces drapeaux en coefficients inventerait un bareme. La definition de `combat_coup_resoudre` manque toujours aux sources disponibles. Aucun moteur alternatif ni metier artificiel ajoute.

Les autres interactions ne sont pas declarees bloquees par ce seul bareme : elles restent du travail a realiser. La negociation actuelle depend de CHA effective, bonus d'organisation et benediction consommee a la resolution ; la separer en nouveau debit/jet serveur sans raccorder ces contreparties supprimerait des regles. L'expulsion legale actuelle inscrit localement expulsionDemandeeAt/expulsionAt : ce n'est pas un circuit serveur transactionnel deja disponible. Ces limites sont applicatives, en plus de l'absence d'acces au catalogue vivant. Le lot occupation n'est pas termine.

Main aadc2cb integre : les cinq images de friche et la correction de consommation sur place sont conservees. Aucune migration appliquee, aucun personnage reel modifie.
