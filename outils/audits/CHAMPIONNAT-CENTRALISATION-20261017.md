# Championnat — centralisation serveur (préparation, non déployée)

## État vérifié dans main le 17/10/2026
- `plateau-core.js` lance `verifierEtJouerJournees()` au chargement puis toutes les 300 s par navigateur et `tickFootballLive()` au chargement puis toutes les 20 s par navigateur. Les gardes ajoutées dans main ne protègent que chaque onglet.
- `plateau-organisations-quetes.js` définit `chargerOuInitialiserSaison` (ligne ~1907), `verifierEtJouerJournees` (~2261), `ecrireChampionnatCAS` (~3074), `majChampionnatCAS` (~3092), `avancerFootballLive` (~3114) et `tickFootballLive` (~7626).
- `tickFootballLive` appelle `avancerFootballLive`, puis relit `chargerOuInitialiserSaison` pour calculer le verrou individuel, les popups et le badge.
- `vercel.json` ne programme que `cron-minuit` (23:00 UTC) et `cron-assemblee` (22:00 UTC). Aucun cron football autonome.
- `api/cron-minuit.js` lit le championnat pour les cotisations de supporters et les licences : ces circuits, notamment financiers, ne doivent pas être modifiés par ce chantier.

## Contrat de migration, à vérifier avant écriture
1. **Séparer calcul partagé et UI individuelle** : moteur de saison/live, CAS, effets collectifs d'un côté ; verrou, badge, popups, lecture seule de l'autre. L'exécution serveur ne doit jamais dépendre de `window`, `document`, `state` ou d'un PJ courant.
2. **Un seul déclencheur autorisé pour les écritures partagées** : cron ou orchestrateur serveur authentifié ; ne pas exposer de route anonyme permettant d'avancer le championnat.
3. **Conserver CAS et idempotence** : les exécutions simultanées, retries et retards doivent produire au plus une transition et au plus un effet collectif.
4. **Cadence du live** : le tick actuel est de 20 secondes. Avant de choisir un ordonnanceur, vérifier ses contraintes réelles de fréquence et le contrat des phases (échauffement, deux mi-temps, pause). Un cron à la minute ne doit pas changer implicitement les règles.
5. **Bascule progressive** : d'abord tests de parité sur calendrier, phases, rattrapage, récompenses et événements ; puis nouveau moteur serveur désactivé ; ensuite activation contrôlée ; enfin suppression des écritures collectives côté client. Jamais deux moteurs actifs.
6. **Protection des finances** : aucun changement aux cotisations, licences, récompenses financières, migrations ou à la branche `codex/reconstruction-finances-atomiques` sans coordination explicite.
7. **Critères de réussite** : lecture seule navigateur vérifiée ; un seul écrivain serveur ; rejouabilité ; récupération après panne ; zéro régression des affichages live ; chute mesurée des lectures `championnat` par joueur.

## Risques identifiés
- Déplacer le code navigateur tel quel dans une fonction serveur casserait ses dépendances et effets UI.
- Désactiver les ticks navigateur avant de déployer un moteur serveur arrêterait la compétition.
- Un ordonnanceur trop lent ou non garanti peut retarder les matchs.
- Le CAS protège les versions, mais les effets secondaires doivent être audités séparément.
- PostgreSQL reste intermittent : pas de migration ni de bascule de production avant accès fiable et tests réels.

**Statut : préparation technique uniquement. Aucune fonctionnalité de production modifiée.**

## Arbitrage utilisateur confirmé le 17/10/2026
- Le championnat est inactif en semaine ; échéance le dimanche vers 20 h, heure française (horaire exact à confirmer dans le code).
- **Conserver intégralement le déroulement existant de 30 minutes** : échauffement 5 minutes, première mi-temps 10 minutes, pause 5 minutes, seconde mi-temps 10 minutes.
- L'animation visuelle des matchs reste **hors périmètre**, à reprendre seulement lorsque le jeu sera entièrement codé.
- Ne pas remplacer le live par un calcul instantané ; préserver les résultats, classements, indices et phases finales.
- Point de vigilance technique : le code comporte un rattrapage automatique si personne n'était connecté pendant les 30 minutes ; le moteur serveur devra préserver une reprise sûre après panne, sans simuler une semaine entière.

## Optimisation de transition (PR #19, non déployée)
- Tick live navigateur de 20 s : activé seulement le dimanche 19h45–21h00 Europe/Paris.
- Tick de cycle : une fois au chargement, une fois par jour hors dimanche, 5 min le dimanche ; l'ouverture du panneau du championnat force toujours une vérification.
- **Important** : cette étape ne centralise pas encore le moteur ; le serveur doit prendre le relais avant de retirer entièrement les écritures du navigateur.
- La vérification périodique n'est pas une garantie d'exécution sans joueur connecté ; c'est la centralisation serveur qui apportera cette garantie.
- Les événements du live et le verrou d'immobilisation doivent être testés pendant une fenêtre réelle avant fusion.
