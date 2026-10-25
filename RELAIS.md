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
- 25/10 : voyants de la messagerie synchronisés (bouton « Messages/Forums »,
  « Boîte Mail », « Mails reçus » lisent la même copie de ce que rend le
  serveur), et règle commune : **l'agent fusionne lui-même** quand les
  contrôles passent (voir `AGENTS.md`).
- 25/10 : **`GAME-DESIGN-AMBASSADES.md`**, la référence des décisions de Fred
  (secrétaires PNJ, naturalisation, transfert de détenus, asile, valise,
  immunité, réceptions ; visas et dépêches écartés). Portes du hall
  cliquables et onglets avec infobulle « Accès limité : il faut avoir une
  invitation. » (branche `claude/portes-ambassades-20261025`, fonction
  `ambassade_acces_bureaux` appliquée, registre 20261025002311).
- 25/10 nuit : **asile politique** (branche `claude/asile-ambassades-20261025`) :
  demande à l'accueil (2 PA), décision de l'ambassadeur PNJ selon le dossier
  (recherché ou affaire vivante) sous 0 à 3 jours, mail ; le réfugié entre
  dans le bureau de son ambassade et ne peut pas être arrêté au Quartier des
  Ambassades (patch de `detention_ouvrir_interne` et `police_detection_verifier`,
  + déclencheur filet). Trois migrations appliquées (registre 20261025004912,
  20261025004941, 20261025005227).
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

Suite exécutée sans nouvel arrêt : vol de chantier préparé dans `20261025000429_chantier_vol_transactionnel.sql`. Retrait par le moteur terrain existant + vraie réception versionnée d’objets + coût/bonus/effets/reçu, une seule transaction ; 45 assertions PostgreSQL et trois contre-épreuves passent. Sauvegarde REST périmée, écritures ignorées et pertes de réponse éprouvées, parité avec les fonctions pures de vol conservée. Commande **privée, non activée**, aucun changement du client historique : L09 garde cinq autres hôtes à terminer avant branchement global et fermeture des anciens chemins. Lire la suite de `REPRISE-TERRAINS-135-20261025.md` et le prévol enrichi. L’exécution continue après cette sauvegarde ; aucune donnée réelle ni migration appliquée.

### Suite continue — enquête et publication transactionnelles

Troisième hôte privé terminé localement : `police_enquete_commande`. Deux migrations préparées `20261025001934_enquete_instruction_trace_commune.sql`, puis `20261025002313_enquete_commande_transactionnelle.sql`, après le garde de confirmation déjà préparé. Le moteur d’instruction est unique : l’ancienne signature délègue à la nouvelle forme privée, droits préservés. L’enquête lie le fait réellement choisi, respecte la durée des traces sur le temps commun, ne consomme rien sans jet, et réunit paiement, arrestation/contre-espionnage, transmission, chronologie, notification, événement et reçu. 40 assertions natives et trois mutants passent ; contre-espionnage réellement chargé, plus simulé dans ce banc. Les écritures ignorées sont éprouvées.

Le vol est porté à 48 assertions avec le vrai garde judiciaire et les événements publics existants. Migration complémentaire `20261025004601_vol_chantier_evenement_transactionnel.sql` après le vol initial, sans réexécuter celui-ci ensuite. Les deux événements et les notifications ne se doublent pas au rejeu. Ensemble du workflow enrichi : 43/43 configurations PostgreSQL ; globaux toujours 6/12, mêmes six rouges. Aucun fichier généré altéré. Prévol enrichi : registre, fonctions, RLS, droits, corps des triggers et dépendances judiciaires, dont `justice_executer_condamnation_soi` dont la définition n’est pas archivée ici.

L09 reste privé et non activé ; quatre hôtes et le branchement global demeurent : chasse à l’homme, achat illégal, vol ordinaire, évasion. Je poursuis par la chasse avec les moteurs judiciaires existants, sans inventer la fonction personnelle manquante. Les preuves actuelles sont dans `BENEDICTION-135-20261024.md` et `luthecia-20261025/`. Aucun compte réel ni migration appliquée ; aucune demande technique à Fred.

### Suite continue — chasse à l’homme

Après les composants judiciaires précédents : `20261025005521_execution_condamnation_continuite.sql`, puis `20261025005717_chasse_commande_transactionnelle.sql`. Aucun de ces fichiers n’est installé ni activé. La première garde accepte le corps archivé de `justice_executer_condamnation` (`a7c59553d969fc20077b2059c2c8e9c6`) ou son propre corps (`cb4eeecfc22f4a0ec8aa27f19a78e1f6`). Le prévol vivant est indispensable : ce moteur n’était pas dans les 22 définitions fournies.

Défaut reproduit : pour une peine initiale de 20 jours, un reliquat de 5 et une sanction d’évasion de 2, l’ancien moteur exécutait 22 jours. La correction reprend la règle déjà écrite dans le client : 7 jours effectifs, sans altérer les motifs historiques. Les liens vers la détention précédente, le reliquat et la ville du jugement sont conservés ; la détention s’ouvre dans la ville de l’arrestation. Les peines ordinaires conservent leur calcul et leur repli existants.

`police_chasse_commande` réutilise la recherche judiciaire, l’exécution, la détention, le payeur et la caisse existants. Autorité du commissaire, présence, état réel, condamnation exécutable et pays vérifiés avant dépense. PA, caisse, bonus, jet, jugement, prison, courrier, événement et reçu partagent la même transaction. Aucun succès d’arrestation sans jugement exécuté, détention active et projection concordante. Le rejeu ne repaie et ne republie rien.

**33 assertions PostgreSQL natives** : reproduction du défaut, seuil exact, succès et échec, coûts, requêtes concurrentes, réponse perdue, changement de cible, écritures ignorées, panne finale, jet nul, consommation unique du bonus, refus de présence/juridiction/état/caisse, reliquats invalides et absence d’extradition. Trois contre-épreuves détectées : reliquat ignoré, cible substituée et bonus réutilisé. Les définitions d’exécution et de détention sont réelles ; fixtures fictives uniquement.

Limite précise : `justice_executer_condamnation_soi(text)` est appelée par les circuits existants, mais sa définition n’est archivée ni dans le baseline ni dans les sources examinées. Cela ne démontre pas son absence en production. La branche personnelle refuse sans dépense si elle manque ; elle n’a pas été reconstruite ou simulée. Son export vivant et sa validation sont requis avant activation globale. Le prévol complémentaire la demande déjà.

L09 n’est pas terminé : achat d’arme illégal, vol ordinaire et évasion restent à transactionnaliser avant le raccordement global du navigateur et la fermeture des anciens chemins. Les quatre hôtes préparés restent privés ; ne pas les activer isolément.
