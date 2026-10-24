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
  **Fusionnée le 24/10.** Son tirage de 70 % côté navigateur est remplacé par
  le parcours d'audience ci-dessous.
- PR #141 (branche `claude/audit-ambassades-20261024`, documentation) :
  `AUDIT_AMBASSADES.md` v2 (game design retrouvé, 12 écarts écran/serveur)
  et `AUDIT_BNE.md` (audit complet du Bureau). Chacun finit par les
  questions à trancher par Fred.
- **Audiences d'ambassade (nouveau parcours, arbitrage Fred 24/10)** — branche
  `claude/audiences-ambassades-20261024` : demande à l'accueil (1 PA, une par
  ambassade) → mail « transmise » → délai tiré par le serveur (0 à 3 jours,
  jamais de refus) → mail « accordée » → bureau ouvert 48 h pour ce joueur,
  ambassadeur PNJ dedans. Fonctions `ambassade_*` **appliquées en production**
  (registre 20261024185323 et 20261024185346), baseline pas encore
  réextrait. Passe de nuit ajoutée dans `api/cron-minuit.js`.
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

Bilan de la reprise vérifié sur code `2c35900` : 111/111 bancs client, 37/37 configurations PostgreSQL du workflow (incluant 7 mutants terrain/banque et 3 filature), 91/91 contre-épreuves historiques. Globaux : 6/12, mêmes six rouges ; Authority signale honnêtement 38 RPC non extraites et une ancienne signature inconnue. `outils/audits/luthecia-20261024/RESULTATS.json` actualisé ; ancienne photographie conservée séparément. Les nouveaux résultats ne revendiquent ni les tests en jeu ni la disponibilité de Supabase. Prochaine étape de code : hôte d’enquête transactionnel réutilisant le moteur corrigé, puis chasse, vol de matériaux, achat illégal, vol et évasion ; aucune consommation séparée exposée. Le décalage entre les dates des anciennes traces et les jours personnels doit être traité sans dater fictivement les faits. Pas de modification des chantiers ambassades/BNE de Claude.

### 25/10 — priorité terrains reprise par Codex

Main `6a249a1` intégré sur la branche existante, sans modifier les audiences d’ambassade ni le BNE. Correction démontrée de reprise construction : un reçu confirmé ne fait plus supprimer l’intention tant que le terrain courant et les finances n’ont pas été relus. Le lecteur commun reçoit une option interne pour éviter la récursion ; aucune nouvelle RPC ni règle métier. Dix tests de commande client passent, dont l’ancienne panne réinjectée, lecture impossible, réponse tardive et changement de personnage. Contrôleur complet : 111/111. Le parcours PostgreSQL intégré des cinq parcelles est également vérifié et doit être sauvegardé dans le lot de preuves suivant ; aucun joueur réel ni migration de production.

Suite terrains sauvegardée : `banc-parcours-terrain-construction-135-local.py` réunit les cinq parcelles de Luthécia et les quatre paliers dans la même base PostgreSQL jetable. Superficies/prix comparés à data.js ; deux libérations par négociation, compromis/permis, acte, 35/35/30, entrepôt, rémunérations, délais, plans/lots, réception. 324 assertions, cinq pannes de réception intégralement annulées, cinq réceptions concurrentes, nouvelle connexion et jour personnel sans nouveau quota. Trois mutants détectés (deuxième journée, parcelles uniformisées, tranche modifiée). Workflow final : 39/39 configurations PostgreSQL, 111/111 bancs client, 91/91 contre-épreuves historiques. Globaux : 6/12, Authority passe honnêtement de 38 à 42 RPC non extraites avec les audiences intégrées de main ; pas de falsification de référence. Preuves et limites : `outils/audits/REPRISE-TERRAINS-135-20261025.md`, `outils/audits/luthecia-20261025/RESULTATS.json`. Pas de migration supplémentaire, pas de fusion ni données réelles modifiées. L09 demeure distinct et incomplet ; installation/recette authentifiée du parcours terrain à coordonner par l’agent principal selon le prévol, sans manipulation demandée à Fred.
