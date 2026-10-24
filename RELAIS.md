# Relais entre agents

Passage de témoin entre Codex et Claude. Mis à jour à **chaque push**.
Règles : voir `AGENTS.md`.

## En cours

### #135 — Stabilisation Luthécia, terrain / banque / construction

- Agent : Codex ; branche `codex/stabilisation-luthecia-135-20261024` (reprise de la branche existante).
- PR d’intégration déjà ouverte par l’agent principal : #139, branche `integration/livraison-terrain-135-20261024`. Aucun nouveau lot sensible fusionné ou déployé par cette session.
- Code sauvegardé : L04 prêt consommation et L11 acquisition/financement atomiques ; permis joint, instruction/accord tacite sous verrou et archivage, compatibilité des anciens dossiers. Main 3c437d6 intégré sans modifier les travaux indépendants.
- Commits de lots : 17d99f1, 11ebd80, 249e8d6, c366afc ; preuves/reliquat 90198df ; correctif ciblé de bénédiction sans jet 2502abb. Les noms de RPC et paramètres du pont client sont rendus explicites pour le contrôle d’autorité.
- Vérifications : 110 bancs client, 33 configurations PostgreSQL, 91 contre-épreuves historiques ; banc terrain/banque porté à 61 assertions, 59 de négociation conservées, sept mutants détectés. Tests sur identités fictives ; aucun personnage réel.
- Installation : lire `outils/audits/LIVRAISON-TERRAIN-BANQUE-135-20261024.md` pour l’ordre des quinze migrations, leurs gardes et prévols. L’agent principal assure lectures Supabase, installation autorisée, réextraction, PR/fusion et Vercel. Aucun SQL ni manipulation demandé à Fred.
- Reste de code : L09, attribution et consommation serveur de bénédiction dans les circuits concernés. Le déplacement du bonus d’enquête évite sa consommation sans jet, mais ne sécurise pas la persistance serveur. Ne pas le déclarer terminé.
- Globaux : six contrôles rouges conservés (Classification, Baseline, Authority, Referential, Assemblage, Reconstruction). Les signatures financières explicites augmentent les noms non extraits signalés ; ne pas les masquer.
- Test pour Fred : aucune nouvelle action en production à ce stade ; les preuves actuelles sont locales. Après installation contrôlée et validation, le parcours terrain/notaire/banque doit être vérifié avec un compte de test autorisé, sans dépenser les fonds d’un joueur réel.

Travaux déjà ouverts avant la mise en place du relais (pull requests
existantes, à reprendre si Fred le demande) :
- #139 `integration/livraison-terrain-135-20261024` — terrains : occupation
  transactionnelle, réaménagement, protection des locaux (issue #135).
  L04/L11 sont désormais codés sur la branche Codex indiquée ci-dessus, à intégrer après prévol ; L09 reste à terminer.
- Nombreuses PR WIP plus anciennes (construction #94, successions #95,
  interception policière…) : voir la liste des PR ouvertes.

## Derniers chantiers

- 24/10/2026 — Mise en place du relais Codex/Claude (`AGENTS.md`,
  `CLAUDE.md`, `RELAIS.md`).

### Suite L09 préparée, non activée

Socle privé d’attribution/persistance/consommation implémenté et éprouvé : 41 assertions PostgreSQL. Migration `20261024174646_benediction_etat_prive_et_attribution.sql`, sans exposition de la commande d’attribution aux clients. Aucun raccordement des sept actes encore réalisé ; ne pas annoncer L09 terminé ni activer ce lot seul. Lire `outils/audits/BENEDICTION-135-20261024.md` et le prévol complémentaire associé. Le développement continue par les actes hôtes, en réutilisant leurs moteurs existants.

Suite sauvegardée : filature serveur privée et lecteur des dernières 24 heures réelles, catalogue des emplacements généré depuis les ordres existants. Banc natif : 30 assertions, coûts/PA/bonus/rapport atomiques, erreurs injectées et concurrence ; trois contre-épreuves ajoutées. Lire la suite de `BENEDICTION-135-20261024.md` pour l’ordre des trois migrations et leurs gardes. Aucun raccordement navigateur ni activation partielle : les six autres hôtes restent à terminer, avec fermeture contrôlée des anciens chemins à l’activation finale. Aucun SQL appliqué en production.
