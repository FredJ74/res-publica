# Méthode d'audit et traçabilité

## Capture initiale
- Dépôt : `FredJ74/res-publica`; `main` : `a8bd5e266f18f3432ec3feb11d53dbb799043531` (lecture du 9 novembre 2026).
- Arbre Git récursif GitHub non tronqué : **5 003 fichiers** ; dont **300** dans `migrations/`, **327** dans `baseline/`, **34** dans `api/`, **31** dans `i18n/`, **818** dans `images/`, **1 511** dans `outils/`, **1 469** dans `historique/`. Ces nombres sont un **inventaire de chemins**, pas un nombre de mécaniques actives.
- **93 bâtiments, 249 pièces, 846 ordres, 346 actions, 357 tables, 1 058 fonctions** : chiffres historiques **déclarés dans `ARCHITECTURE.md` pour octobre**, non recalculés et non certifiés pour le SHA ci-dessus.
- Aucune écriture dans Supabase et aucun PJ sollicité pendant cette collecte.

## Séquence de vérification exigée
1. **Intention** : Constitution → décision explicite datée → arbitrage postérieur éventuel ; distinguer règle ferme, proposition d'agent et valeur restant à valider.
2. **Exposition** : l'ordre est-il réellement visible au bon endroit, pour le bon empire, le bon poste et la bonne position ? Une zone cliquable ou un élément `data.js` peut être inerte.
3. **Exécution** : handler client → routeur générique ou spécialisé → RPC / API → contrôles d'identité / pays / position → transaction / réponse.
4. **Effet serveur** : tables, propriétaire, monnaie, PA, objets, temps, journal, idempotence ; signaler les états décidés par le client.
5. **Preuves** : banc positif et contre-épreuves (droits, absence, double clic, perte de réponse, concurrence), version testée, CI et éventuelle migration.
6. **Recette** : une action de consultation peut être vérifiée sur compte isolé ; les achats, crimes et autres actes à conséquence nécessitent un environnement isolé. Tests iPhone/Android réels distincts des fixtures Chromium.
7. **Interaction sociale** : nommer l'autre joueur que le système fait rencontrer, dépendre, rivaliser, influencer, aider ou observer ; sans partenaire identifiable, marquer le risque d'activité en vase clos.

## Taxonomie des preuves
| Code | Niveau | Ce que cela prouve | Ce que cela ne prouve pas |
|---|---|---|---|
| DOC | `CONSTITUTION.md`, `GAME-DESIGN-*.md` | Intention et règles écrites | Implémentation |
| SRC | JS, migrations ou baseline du SHA ciblé | Code commité, chemin candidat | Migration, absence de bug |
| TEST-F | Fichier de banc sans résultat exécuté dans l'audit | Test disponible | Test vert sur SHA courant |
| TEST-R | Journal de test daté, SHA, assertion et environnement | Exécution rapportée | Toutes les variantes ou production |
| MIG-R | Rapport affirmant « migration appliquée » | Déclaration attribuable | Vérification indépendante du catalogue réel |
| CI-R | Workflow terminé, état, SHA | Contrôles CI de ce SHA | Recette humaine |
| DEP-R | Déploiement READY relié à SHA | Infrastructure de publication | Action réellement jouable |
| UX-R | Session humaine documentée et résultat attendu/obtenu | Parcours vécu | Tous les PJ/téléphones |

Les suffixes **-R** sont des rapports historiques lorsqu'ils ne sont pas recoupés par leur source de vérité.

## Pièges déjà observés
- La Constitution (article 15) impose que l'interface ne promette jamais un effet absent ; `Bientôt disponible` et fenêtres en place ne constituent pas une mécanique jouable.
- L'audit `AUDIT_UNE_SEULE_VERITE.md` du 25–26 octobre dénombrait des écritures client et accès SQL dangereux ; ce constat est **historique**, pas une preuve que ces risques demeurent tous le 9 novembre. Chaque correction doit être vérifiée par tables/RLS et non par une mention « réglé ».
- Un jeu de tests local avec Supabase simulé ne démontre pas que les RPC SQL sont déployées ni accessibles aux véritables joueurs.
- Un état « codé le 8 novembre » consigné dans `RELAIS.md` doit être comparé à la branche main et aux dernières PR avant de conclure à une disponibilité publique.
- Préserver les règles de non-écriture directe de la fiche `personnages` définies dans `AGENTS.md`.

## Références directes pour les agents
- `AGENTS.md` : collaboration, séparation décisions/code/tests, branche dédiée, autorité serveur.
- `WORKFLOW-SUPABASE.md` : doctrine baseline et migrations.
- `outils/audits/CERTIFICATION-MOBILE-20261108.md` et `outils/audits/RECETTE-PHYSIQUE-MOBILE-20261108.md` : automate et recette physique **distincts**.
- `baseline/seeds/90_socle/pnj_social_jalons_regles.sql` : deux déclencheurs sociaux effectivement décrits dans la seed.
- `plateau-social-pnj.js` et `api/chat.js` : raccord client/mémoire/dialectique IA.
- `plateau-naval.js` et `GAME-DESIGN-CHANTIER-NAVAL.md` : exemple d'une construction présente sans navigation privée déclarée.

## Vérification GitHub du SHA de référence

Le 9 novembre, interrogation directe des contrôles GitHub du commit `a8bd5e266f18f3432ec3feb11d53dbb799043531` : **6 check-runs terminés en succès** — `parcours-immobilier`, `bancs-hors-production`, `verifier` (deux workflows distincts), `mesurer-le-payload` et `placements`. Les six workflows correspondants sont `Garde du payload Vercel`, `Novomirsk — decors du marche et de la presse`, `Titres ministeriels — isolation des empires`, `Parcours immobilier cinq terrains - PostgreSQL jetable`, `Placement national transactionnel`, `Cohérence client et transactions locales`. Source : [contrôles GitHub du commit](https://github.com/FredJ74/res-publica/commit/a8bd5e266f18f3432ec3feb11d53dbb799043531/checks). **Ces six succès ne prouvent pas l'exécution de tous les bancs du dépôt, les migrations de production ni une recette de jeu.** Ce sont des preuves CI-R du SHA historique seulement.

## État des opérations de cet audit
Lecture GitHub uniquement, aucune compilation locale ni exécution directe de banc ni vérification physique ; contrôles GitHub du SHA source consultés. La publication de ce référentiel est un **travail documentaire**, à ne pas interpréter comme la certification de l'état du jeu.
