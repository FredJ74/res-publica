# Arnie — prévol automatique et première consultation, 20 octobre 2026

## Résultat réel

**TESTEUR NON OPÉRATIONNEL. Aucune visite réelle effectuée depuis cette session.**

Le propriétaire confirme que les trois secrets d'identité sont configurés et que le compte est classique, confirmé. Le présent environnement ne peut pas lire ces secrets GitHub, ce qui est normal. Il ne dispose pas de connecteur Supabase. Une requête authentifiée à l'API GitHub échoue au tunnel du proxy (`CONNECT 403`), avant réponse de GitHub. Git fetch fonctionne ; cela ne démontre pas l'accès à l'API Actions. Aucun UID ni secret réel n'est connu ou publié par ce chantier.

## Correction livrée

- Suppression de la dépendance au secret `HG_E2E_ARNIE_AUTORISATION_JSON` et aux attestations manuelles `auditArnie`. Le périmètre Arnie vient de l'autorisation explicite du propriétaire, avec déclenchement manuel obligatoire et origine/backend fixes.
- Prévol authentifié automatique **avant la page de connexion** : connexion GoTrue normale, UID/adresse/non-anonymat/confirmation, nouvelle lecture de l'utilisateur, `mon_personnage` exactement Arnie, puis fiche liée au même UID et située à Luthécia. Deux fiches visibles, une absence ou une discordance arrêtent le test. Les RLS ne sont pas contournées ; une ligne invisible ne peut pas être certifiée absente par ce prévol.
- Erreurs distinctes : transport, HTTP, JSON, identité, fiche/territoire. Aucune réponse sensible n'est journalisée. Les accès sont bornés, sans redirection ni rejeu automatique.
- Conservation de la connexion par formulaire et de la garde réseau avant chargement de l'application. Les réponses d'authentification sont contrôlées à nouveau avant exposition au client. L'adresse d'une demande de connexion différente est refusée avant transport.
- Interdiction des dépenses, ordres, réceptions automatiques, transferts, sauvegardes, présence, modifications d'authentification et API métier/cron. WebSockets et Service Workers bloqués. Les lectures REST sans identité confirmée et les RPC non autorisées, y compris un chemin encodé, sont refusées.
- Empreinte de la fiche avant démarrage du jeu et relecture après connexion/consultation, sans exporter son contenu. La position client/serveur doit correspondre à celle du prévol.
- La première campagne consulte exclusivement la scène déjà occupée. Aucun clic de déplacement n'est envoyé, et `rue_position_enregistrer` est bloquée même si un ancien JSON prétend que les effets sont audités. Aucun faux succès n'est injecté dans le jeu.

## Pourquoi le déplacement reste bloqué

`enterRoom` appelle `sbSavePersonnage`. Ce circuit peut écrire l'inventaire puis une fiche générale. Le déclencheur archivé `personnages_vue_modifier` réécrit des champs autres que la position, y compris depuis un PATCH partiel de la vue. Le pilote ne peut donc ni autoriser la sauvegarde, ni la réduire artificiellement en supposant qu'elle serait sans conséquence.

La définition réellement déployée de `rue_position_enregistrer` et les déclencheurs associés n'ont pas été consultés dans cette session. Une empreinte après coup ne prouverait pas l'absence d'effets et ne réparerait pas un dommage. La déclaration manuelle d'innocuité est donc remplacée par un **verrou effectif**, pas par une valeur vraie inventée. L'audit vivant des mouvements reste un travail technique à poursuivre lorsque le canal autorisé est disponible. Aucune migration n'est appliquée ou préparée pour contourner ce manque.

## Vérifications exécutées

| Contrôle | Résultat |
| --- | --- |
| Pilote E2E sur fixtures | **69/69**, aucun test ignoré |
| Prévol via vrai transport Playwright HTTP local | Conforme, quatre appels attendus uniquement |
| Garde Chromium local | Les écritures interdites, y compris le déplacement, n'atteignent pas le serveur local |
| Contrôleur client existant | **90/90 bancs** |
| SQL de prévol sur PostgreSQL jetable | **5/5 groupes** |
| Contrôles globaux | **10/12**, Authority et Referential toujours en échec, aucune référence modifiée |
| Syntaxe JS, YAML et `git diff --check` | Conformes |
| Prévol réel Arnie / visite réelle | **Non exécutés**, secrets uniquement disponibles dans le job GitHub inaccessible depuis ce runtime |
| Catalogue Supabase vivant | **Non consulté** |

Les anciens tests d'attestations manuelles sont remplacés par des refus exercés sur les réponses serveur : autre UID/adresse, anonymat, confirmation manquante, utilisateur relu différent, autre personnage, fiches multiples/absentes, mauvais propriétaire et autre ville. Les tests historiques de l'authentification du jeu sont conservés. Tous les comptes de fixture sont fictifs. Aucun test local ne constitue une preuve en production.

## Lancement restant

Le workflow **Parcours joueur autorise de Luthecia**, branche `main`, mode `consultation_seule`, utilise désormais les trois secrets existants sans quatrième secret ni configuration SQL. La seule manipulation externe nécessaire pour lancer cette première consultation, si le refus réseau persiste, est **Run workflow** depuis la page Actions correspondante. Aucune nouvelle saisie d'identifiants n'est demandée.

L'artefact privé contient le prévol, les refus, les éventuelles anomalies et les visites effectivement confirmées. `CONSULTATION_INITIALE_AUTHENTIFIEE` confirme uniquement la scène initiale ; `CONSULTATION_INITIALE_AVEC_ANOMALIES` conserve les erreurs. Le code de sortie reste 2 parce que le parcours complet n'est pas validé : un job rouge n'invalide pas à lui seul la consultation initiale, et un résultat partiel ne doit pas être présenté comme un testeur opérationnel. Aucun résultat de campagne distante n'est affirmé dans ce rapport.

Aucune modification des données de jeu, des comptes ou de l'authentification, aucun débit/crédit, aucune migration et aucun contournement des permissions serveur.
