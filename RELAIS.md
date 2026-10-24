# Relais entre agents

Passage de témoin entre Codex et Claude. Mis à jour à **chaque push**.
Règles : voir `AGENTS.md`.

## En cours

### #135 — Stabilisation Luthécia, terrain / banque / construction

- Agent : Codex ; branche `codex/stabilisation-luthecia-135-20261024` (reprise de la branche existante).
- PR d’intégration déjà ouverte par l’agent principal : #139, branche `integration/livraison-terrain-135-20261024`. Aucun nouveau lot sensible fusionné ou déployé par cette session.
- Code sauvegardé : L04 prêt consommation et L11 acquisition/financement atomiques ; permis joint, instruction/accord tacite sous verrou et archivage, compatibilité des anciens dossiers. Main f69ae9b intégré sans modifier les travaux indépendants.
- Commits de lots : 17d99f1, 11ebd80, 249e8d6, c366afc ; preuves/reliquat 90198df ; correctif ciblé de bénédiction sans jet 2502abb. Les noms de RPC et paramètres du pont client sont rendus explicites pour le contrôle d’autorité.
- Vérifications : 110 bancs client, 33 configurations PostgreSQL, 91 contre-épreuves historiques ; banc terrain/banque porté à 61 assertions, 59 de négociation conservées, sept mutants détectés. Tests sur identités fictives ; aucun personnage réel.
- Installation : lire `outils/audits/LIVRAISON-TERRAIN-BANQUE-135-20261024.md` pour l’ordre des quinze migrations, leurs gardes et prévols. L’agent principal assure lectures Supabase, installation autorisée, réextraction, PR/fusion et Vercel. Aucun SQL ni manipulation demandé à Fred.
- Reste de code : L09, attribution et consommation serveur de bénédiction dans les circuits concernés. Le déplacement du bonus d’enquête évite sa consommation sans jet, mais ne sécurise pas la persistance serveur. Ne pas le déclarer terminé.
- Globaux : six contrôles rouges conservés (Classification, Baseline, Authority, Referential, Assemblage, Reconstruction). Les signatures financières explicites augmentent les noms non extraits signalés ; ne pas les masquer.
- Test pour Fred : aucune nouvelle action en production à ce stade ; les preuves actuelles sont locales. Après installation contrôlée et validation, le parcours terrain/notaire/banque doit être vérifié avec un compte de test autorisé, sans dépenser les fonds d’un joueur réel.

### Travaux parallèles à préserver

**Ambassades et Bureau de l'Emploi (Claude)** — **Codex : ne pas toucher aux
ambassades ni au Bureau de l'Emploi** tant que ces chantiers sont ouverts.
- Contexte : objectif actuel = terminer Luthécia. Les ambassades ne seront
  raccordées aux autres empires que lorsqu'ils seront codés (arbitrage
  Fred, 24/10). Nouvelle règle de Fred : **une seule réalité, celle du
  serveur** (voir `AGENTS.md`).
- PR #142 (branche `claude/ambassadeurs-pnj-20261024`) : trois ambassadeurs
  PNJ reçus **sur audience seulement** — Valery Antonov (Sovarka, la
  rigidité), Guillermo Vasquez (El Estado, la corruption), Mohamed
  Al-Mansoori (Al-Khalija, le snobisme). Fenêtre à la charte ardoise et or.
  **Attend le test de Fred**, et sa décision sur le tirage de 70 %, fait par
  le navigateur, donc contraire à la règle serveur (garder via une fonction
  serveur, ou supprimer le tirage).
- PR #141 (branche `claude/audit-ambassades-20261024`, documentation) :
  `AUDIT_AMBASSADES.md` v2 (game design retrouvé, 12 écarts écran/serveur)
  et `AUDIT_BNE.md` (audit complet du Bureau). Chacun finit par les
  questions à trancher par Fred.
- Prochaines étapes, **après réponses de Fred** :
  1. BNE B1 (le mail d'arbitrage rejoué peut faire perdre l'emploi) :
     migration de `bne_agir` + test ;
  2. BNE B2-B4 (textes faux : mail de cumul, montant de « Dormir »,
     « 0 FR/jour ») ;
  3. griser « Bientôt disponible » les ordres d'ambassade non raccordables.
- Bancs : 85/102 en local, les 17 échecs sont identiques sur `main`
  (bancs navigateur, environnement).
- Issue #143 : passer toutes les fenêtres à la charte (plus tard).

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

Socle privé d’attribution/persistance/consommation implémenté et éprouvé : 41 assertions PostgreSQL. Migration `20261024174646_benediction_etat_prive_et_attribution.sql`, sans exposition de la commande d’attribution aux clients. Filature serveur préparée en privé ; raccordement navigateur des sept actes encore absent ; ne pas annoncer L09 terminé ni activer ce lot seul. Lire `outils/audits/BENEDICTION-135-20261024.md` et le prévol complémentaire associé. Le développement continue par les actes hôtes, en réutilisant leurs moteurs existants.

Suite sauvegardée : filature serveur privée et lecteur des dernières 24 heures réelles, catalogue des emplacements généré depuis les ordres existants. Banc natif : 30 assertions, coûts/PA/bonus/rapport atomiques, erreurs injectées et concurrence ; trois contre-épreuves ajoutées. Lire la suite de `BENEDICTION-135-20261024.md` pour l’ordre des trois migrations et leurs gardes. Aucun raccordement navigateur ni activation partielle : les six autres hôtes restent à terminer, avec fermeture contrôlée des anciens chemins à l’activation finale. Aucun SQL appliqué en production.

Main `f69ae9b` intégré (ambassades et règle de réalité serveur préservées ; aucun changement de ces fonctions). Correction ciblée supplémentaire : succès du vol de matériaux ne plante plus sur la réaffectation d’une constante après retrait serveur ; trois tests, dont reproduction de l’ancienne exception. Ce chemin reste à transactionnaliser pour L09 : ne pas assimiler cette correction à une sécurisation de son transfert d’inventaire. Contrôleur client avant cette correction : 110/110 ; nouvelle campagne à relancer avec le banc ajouté.

Nouvelle étape vérifiée : garde judiciaire de confirmation (12 assertions PostgreSQL, dont reproduction de fausse réussite et concurrence). Migration `20261024185228_enquete_confirmation_detention_transactionnelle.sql` ; prévol vivant encore nécessaire avant installation, aucune migration appliquée. Socle bénédiction porté à 44 assertions : migration complémentaire `20261024185500_benediction_refuser_jet_absent.sql`, refus de NULL/0/101 avec rollback. Le banc judiciaire simule le contre-espionnage ; il ne valide pas ce domaine. Voir `BENEDICTION-135-20261024.md` pour les empreintes exactes, ordre et limites. Contrôleur client après correction des matériaux : 111/111. L09 non terminé : six hôtes et branchement client restent à sécuriser, pas d’activation partielle.
