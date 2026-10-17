# Audit transversal — horloge universelle de Human Gambit

## Invariant fondateur validé
**Un seul temps réel commun à toute la société**, tous les PJ, PNJ, villes, empires et systèmes. À 16 h à Luthécia, il est 16 h partout dans le monde fictif. Les délais et événements doivent être ancrés sur des instants réels communs, indépendants de la connexion et du personnage. Le fuseau Europe/Paris est actuellement utilisé comme convention d'affichage et de calendrier dans le code ; il ne crée pas de fuseaux propres aux empires.

## Constats établis dans le dépôt (lecture seule)
- `plateau-core.js` vers 538 : `HORLOGE_PA_ACTIVE = false`. L'ancienne fonction `advanceTime(pa)` est encore présente, mais désactivée ; elle ne doit jamais redevenir une horloge concurrente.
- `syncRealTime()` vers 2228 synchronise heure/minute sur le temps réel mais **ne synchronise pas `state.day`** : `state.day = state.day || 1`.
- `runMidnightUpdate()` vers 2441 incrémente `state.day++` lors d'un passage à minuit du client ; `dormirData.day` peut également modifier ce compteur (vers 792). Cela laisse subsister des jours de personnage différents.
- `jourPartageISO()` vers 2200 est déjà une primitive commune basée sur la date réelle Europe/Paris. Plusieurs commentaires du code reconnaissent explicitement le danger des compteurs personnels dans des tables partagées.
- Relevé statique partiel des références à `state.day` : 52 dans `plateau-organisations-quetes.js`, 23 dans `plateau-core.js`, 7 dans `plateau-multijoueur.js`. Les occurrences incluent commentaires, métadonnées et vrais calculs ; **ne pas les remplacer en bloc**.

## Risques fonctionnels à traiter par domaines
1. **Football et santé sportive** : `calculerContributionEquipe` (vers 2488), `tenterBlessureLive` (vers 2726), `estIndisponiblePourSport` (vers 3901), `doTenueMatch` et entraînements (vers 3896–3995) comparent/écrivent `jusquauJour` avec un jour privé.
2. **Bâtiments** : fermeture évaluée par `jour_fin > state.day` (`plateau-core.js` vers 1021–1027), susceptible de diverger selon le PJ.
3. **Criminalité** : expiration des traces de hooliganisme (`plateau-organisations-quetes.js` vers 1232), recherche d'actions traçables (vers 393).
4. **Organisations** : cooldowns et limites quotidiennes des actions syndicales (vers 3400–3490), adhésions et historique ; élections et finances des clubs/supporters (vers 7889–8004, 8462, 8690).
5. **Économie et administrations** : historique des budgets, décisions et événements datés en jours personnels.
6. **Multijoueur** : délais et expirations `expireJour` (`plateau-multijoueur.js` vers 1240), qui doivent être communs.

## Doctrine de correction
- Pour les nouveaux délais : instant UTC stocké côté serveur (ou date civile canonique dérivée du même instant) et comparaison avec l'heure réelle serveur.
- Pour les règles « par jour » : une même date civile du référentiel du jeu pour tous ; ne pas utiliser un compteur lié au PJ.
- Préserver l'historique et les anciennes données : **ne pas interpréter un ancien numéro de jour comme un timestamp** ; définir une migration/compatibilité explicite, système par système.
- Ne pas confondre durée réelle et compteur de PA : le sommeil peut reconstituer des PA, mais ne doit jamais avancer le temps.
- Les traitements collectifs à échéance doivent pouvoir tourner sans joueur connecté, avec exécution idempotente côté serveur.
- Audit puis corrections séparées, tests de non-régression ; ne pas toucher au chantier financier isolé de Codex.

## Prochaines vérifications
Retracer le schéma Supabase des blessures, fermetures et traces, puis la gestion des transitions de minuit et des champs historiques avant tout correctif de production. Étendre l'inventaire des références temporelles aux autres fichiers du dépôt et aux crons.

## Précision fondatrice — passage de journée à minuit pile (17 octobre 2026)
- L'horloge réelle universelle détermine **une journée civile commune** : chaque journée se termine à 00:00 et la suivante commence immédiatement, simultanément pour tous les PJ/PNJ, villes et empires.
- Le franchissement de minuit est un événement fonctionnel qui remet à zéro les quotas « une fois par jour » (notamment l'ordre **Dormir**) et fait progresser le décompte des jours d'indisponibilité : blessures, emprisonnement, empoisonnement, régénération après neutralisation, etc.
- **Ne pas substituer** à cette règle des fenêtres glissantes de 24 h depuis l'action, la connexion ou le dernier sommeil. Exemple : dormir à 23:50 puis de nouveau après 00:00 est compatible avec le quota journalier, sous réserve des autres conditions métier.
- Chaque mécanisme doit préciser si son échéance est un **nombre de passages de minuit** ou une durée exacte en heures/minutes ; ne pas transformer l'un en l'autre sans arbitrage.
- Exigence technique : une même date canonique pour tous, passage de minuit traité côté serveur, idempotent et rattrapable après panne/absence de connexion. Les interfaces peuvent se rafraîchir ensuite ; elles ne créent pas elles-mêmes la nouvelle journée.
- La migration des anciens champs `jusquauJour`, `dernierJour`, `expireJour`, `state.day` doit préserver le nombre de passages de minuit restant lorsque cela est déterminable ; sinon signaler les cas ambigus au game designer.

## Audit approfondi du 17 octobre — mécanismes utilisant le changement de journée

### Écart critique : libération des détenus
Dans `api/cron-minuit.js` ~719–800, `libererDetentionsEchuesServeur()` calcule `echeance = debutTs + jours * 24h` et libère lorsque cette durée glissante est atteinte. **Ce calcul ne respecte pas le décompte par franchissements de minuit fixé par le game designer.** Les commentaires du code présentent ce filet comme un remplacement du compteur personnel, mais cela ne suffit pas : il faut une date civile canonique et une échéance exprimée en journées communes. Les prolongations, réductions, QHS, registres et autres détentions ouvertes imposent une migration étudiée. Aucune modification appliquée.

### Écart : blessures et entraînements sportifs
Dans `plateau-organisations-quetes.js` ~2488, 2726, 3895–3905, 3927, 3995 et 4077, le calcul des blessures et leur affichage reposent sur `state.day`. Le quota des entraînements passe déjà par `football_entrainement_consommer` côté serveur (~3940–3985), mais le miroir `entrainementsJour.jour` est encore écrit avec `state.day`. Ne pas confondre quota serveur et miroir client.

### Écart : passages de minuit côté navigateur
Dans `plateau-core.js` ~2433–2515, `runMidnightUpdate()` incrémente `state.day` et conserve des effets locaux ; certaines vérifications quotidiennes de couvre-feu et recherche militaire sont explicitement dépourvues de miroir serveur. Ces effets risquent de ne pas progresser sans PJ connecté. `checkMidnight()` est interrogé à cadence minute et ne constitue pas une garantie d'exécution à 00:00 pile. Distinguer date qui bascule exactement à minuit et traitements serveur qui peuvent nécessiter rattrapage.

### Écart : fermeture des bâtiments
`plateau-core.js` ~1021–1027 filtre `jour_fin > state.day`, alors que la fermeture est un état collectif : deux PJ ne doivent jamais constater deux échéances différentes.

### Écart : restauration locale
`plateau-core.js` ~788–794 recharge `state.day` depuis `localStorage` au retour du joueur, preuve qu'il ne peut pas être utilisé comme date universelle.

### Audit restant, par priorité
1. Retracer précisément l'ordre Dormir, sa garde serveur, son quota et le reset à minuit.
2. Cartographier blessures hors sport, empoisonnement, neutralisation, régénération et indisponibilités ; repérer leurs écritures, échéances, sorties et effets secondaires.
3. Cartographier toutes les tâches de minuit du cron et les effets encore dépendants d'une session client.
4. Comparer schémas et RPC Supabase, sans mutation de production.
5. Proposer corrections atomiques et tests de frontières 23:59 / 00:00, déconnexion, multi-PJ, changement heure été/hiver et rattrapage d'une nuit manquée.

**Statut : inventaire et diagnostic, pas de correctif déployé.** Ne pas interférer avec la branche de reconstruction financière de Codex.
