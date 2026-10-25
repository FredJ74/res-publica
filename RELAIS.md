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
- 25/10 nuit : **corrections du Bureau de l'Emploi** (branche
  `claude/bne-corrections-20261025`) : B1-B7, B9, B10 et un bug trouvé au banc
  (aucun emploi n'était payé). Migration appliquée (registre 20261025010423).
  Détail dans `AUDIT_BNE.md` § 6.
- Prochaines étapes :
  1. BNE B11 (« les emplois donnent vie au plateau ») : à concevoir avec Fred ;
     B12-B13 : questions reformulées, en attente de sa réponse ;
  2. griser « Bientôt disponible » les ordres d'ambassade non raccordables.
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

### Suite continue — intégration main et confirmation financière

`main e4e8820` intégré sans conflit, en conservant intégralement les travaux d’ambassades et de messagerie. Aucun de ces moteurs n’est modifié par Codex. Le banc supplémentaire `banc-chasse-asile-135-local.py` charge les deux lecteurs d’asile, le véritable patch de la porte de détention et son trigger depuis les migrations de main : **7 assertions**. Une cible protégée ne peut être incarcérée ; le refus nommé annule le coût, le bonus et les conséquences de chasse. La sortie du quartier permet l’arrestation sans supprimer le statut d’asile. Ce banc ne prétend tester ni la demande d’asile ni la détection policière : la définition source de `police_detection_verifier` n’est pas archivée ici et n’est pas simulée. Le prévol vivant est enrichi de ces dépendances.

### Défaut financier de filature reproduit et corrigé en complément

`banc-filature-confirmation-135-local.py` reproduit un succès erroné du prototype : un trigger ignore le prélèvement de 2 PA, la réponse annonce pourtant `ok:true`, la caisse perd 150 FR et le bonus est consommé. Le payeur commun n’est pas remplacé. `20261025011201_filature_confirmation_financiere.sql` ajoute au même hôte la confirmation de ses écritures de PA et de caisse, ainsi que la concordance explicite entre UID authentifié et propriétaire du personnage. Une écriture non confirmée lève une erreur qui annule tous les effets, sans faux rapport payé.

Ordre : après `20261024183157_filature_commande_transactionnelle.sql`, et ne pas réexécuter ce dernier ensuite. Corps initial accepté `b9fb18b681d2f59a9d0cadfb74da364c`, corps corrigé `646fca07f84d381130d96b52a24c0ed4`. Droits privés inchangés, aucune exposition nouvelle. **8 assertions supplémentaires** et **3 contre-épreuves** : absence de confirmation PA, absence de confirmation caisse, absence de vérification UID. Les trois mutations du code chargé dans PostgreSQL font réellement échouer le banc. Concurrence et réponse perdue restent couvertes après correction.

Les preuves sont locales et fictives. Aucun solde réel, aucune installation Supabase, aucune fusion ni déploiement par cette session. Les hôtes manquants et le raccordement global restent explicitement ouverts.

### Validation de la reprise, état sauvegardé après main e4e8820

- **111/111 bancs clients**, **91/91 contre-épreuves historiques** ; sources et tests de messagerie de Claude conservés.
- **47/47 configurations PostgreSQL du workflow**, puis le nouveau banc inter-hôtes exécuté séparément avec sortie 0 : les **48 commandes** désormais déclarées ont été éprouvées. Le nouveau banc ajoute **11 assertions** : filature et chasse concurrentes, une seule consommation de la génération commune, coût cumulé exact, relecture des deux reçus après nouvelle attribution, UUID réutilisé entre familles refusé avec rollback.
- Les **six contrôles globaux rouges** restent Classification, Baseline, Authority, Referential, Assemblage et Reconstruction ; les six autres passent, dont les fonctions. Authority signale maintenant 44 noms RPC non extraits, après les ajouts d’ambassades de main, et la signature historique de fontaine inconnue. Aucune référence ni empreinte modifiée pour masquer ces écarts. Le moteur JavaScript local a été remis dans PATH avant la mesure finale ; l’abstention initiale faute de moteur n’est pas présentée comme un résultat métier.
- Syntaxe SQL des trois migrations nouvelles validée par pglast, scripts Python compilés et diff sans erreur. Aucune modification manuelle du baseline.
- Preuves brutes : `outils/audits/luthecia-20261025/VALIDATION-*`, `BENEDICTION-INTER-HOTES-POSTGRESQL.txt` et `CONTRE-EPREUVES-HISTORIQUES-FINALES.txt`. Les résultats ne prouvent aucune installation ni recette authentifiée en production.

Le parcours terrain déjà éprouvé (324 assertions, cinq parcelles, leurs superficies/prix distincts et leurs délais propres) est conservé. Cette session a poursuivi L09 par la chasse, le reliquat, l’asile et la confirmation financière. L09 reste **non terminé et non activable seul** : achat illégal, vol ordinaire et évasion, puis raccordement global et fermeture contrôlée des anciennes voies demeurent. Ces développements restants ne sont pas présentés comme bloqués par le seul accès Supabase ; l’absence du catalogue empêche en plus la validation vivante et l’activation sûre. La fonction personnelle d’exécution et la détection policière doivent être exportées par l’agent principal ; leur définition manquante n’a pas été inventée.

Aucun solde réel modifié, aucune migration appliquée, aucune fusion ou publication Vercel par Codex. Branche de reprise : `codex/stabilisation-luthecia-135-20261024`, intégration existante #139 à actualiser par l’agent principal. Ne pas fusionner en bloc cette branche qui contient des composants privés non activables ; poursuivre les lots restants puis installer selon le prévol réel. Aucun SQL ni commande demandé à Fred.

### Suite L09 — achat clandestin préparé et testé, non activé

Deux migrations privées : `20261025012601_armes_jet_referentiel.sql` (générée depuis les emplacements et armes existants), puis `20261025012701_arme_clandestine_commande.sql`. Le nouvel hôte réutilise `commerce_vendre_produit_interne` en mode `marche_noir`, le même payeur, le même stock, la même réception versionnée et le même registre judiciaire. Le tarif reste triple, un PA uniquement si la vente réussit, aucun revenu pour le propriétaire. Le bonus, le tirage, le débit, le stock, l’objet livré, les traces, la dénonciation et la convocation éventuelle sont enregistrés avec le reçu dans une seule transaction. Les images/noms propres à Port-Sainte-Marie sont extraits du résolveur existant, sans retouche.

28 assertions PostgreSQL locales passent ; trois mutants détectés (rejeu retiré, prix altéré, bonus non consommé). Sont éprouvés les écritures ignorées, l’échec final, la réponse perdue, les achats concurrents du dernier exemplaire et la convocation à 24 heures réelles. Le moteur commercial utilisé est chargé depuis la migration existante, sans simulation de vente ou d’encaissement. Ce lot reste privé et non raccordé au client ; les définitions vivantes et les gardes réelles doivent être comparées avant activation. Aucun compte réel modifié. Poursuite immédiate : vol ordinaire, évasion, puis raccordement global et fermeture des anciens chemins.

### Suite L09 — vol ordinaire privé

`20261025014001_vol_pnj_referentiel.sql` est générée depuis les PNJ d’ambiance déclarés ; le socle PNJ et sa position effective restent prioritaires. `20261025014101_vol_commande_transactionnelle.sql` réutilise les payeurs ordinaires, les helpers d’inventaire, la réception versionnée et le registre de traces. Le hasard continu est exécuté par PostgreSQL ; les seuils 25/50/75, les caractéristiques, carrières et indices ne sont pas fournis par le navigateur. Le genre choisi n’a jamais de repli. La victime est réellement sur place. Les transferts sont immédiats et leurs deux contreparties sont confirmées dans une seule transaction ; les reçus empêchent tout second traitement. Aucun nouvel enregistrement différé n’est créé. Les objets gardent identifiants et métadonnées, une seule pile est retirée même si plusieurs partagent une clé.

40 assertions locales passent et trois mutants sont détectés : rejeu, genre et retrait absent. Les quatre empires, les cinq bornes 25/49/50/74/75, la visibilité des notifications, les PNJ, les objets protégés, la panne finale, la concurrence et l’ancienne sauvegarde d’inventaire sont éprouvés. Le succès sur PNJ conserve l’issue actuelle sans butin : aucun nouvel arbitrage de distribution de ses possessions n’est introduit.

**Interdiction d’activer ce prototype isolément** : la source du client et le trigger de vue archivés révèlent toujours une sauvegarde générale financière sans comparaison atomique de version. Les 22 définitions vivantes fournies ne couvrent pas cette protection. Le prévol doit identifier le garde financier réellement installé ; s’il est absent, ce garde et l’ensemble des écritures financières légitimes doivent être sécurisés avant activation du vol d’argent. Le test versionné protège les objets, pas les soldes : aucun résultat d’inventaire n’est présenté comme une preuve financière. Les soldes fractionnaires rencontrés par ce chemin historique entier sont refusés sans arrondi plutôt qu’altérés. Ce point est une condition technique ouverte, pas un réglage de game design.

Aucune mutation de données réelles, aucun SQL appliqué. Le client historique n’est pas branché sur ce hôte privé. La suite indépendante est l’évasion et la préparation du raccordement ; la clôture demeure subordonnée aux garanties manquantes, sans prétendre qu’une migration préparée est installée.

### Suite continue — évasion, schéma canonique et raccordement préparés

Main `c6aa8ec` intégré, corrections BNE de Claude conservées. Conflit limité aux versions des scripts de plateau.html résolu en gardant les deux ensembles ; aucun code métier BNE/ambassade modifié.

Préparés, **privés et non activés** : `20261025103801_peines_et_inscription_communes.sql`, `20261025104001_evasion_commande_transactionnelle.sql`, `20261025105001_jets_resources_canoniques.sql`, `20261025105501_jets_dispatch_et_identite.sql`, `20261025110001_jets_gardes_historiques.sql`. Ordre impératif : les hôtes initiaux et le complément financier de filature d’abord, puis ces cinq fichiers. Ne pas rejouer un hôte initial après sa correction canonique. Les corps inconnus sont refusés ; les migrations de correction ne déclarent pas que les dépendances absentes sont installées.

Évasion ordinaire : 23 assertions ciblées et trois mutants. Même moteur de clôture/prolongation, 3 PA, une tentative par date commune, ancien quota conservé, +1 jour/500 FR plafonnés aux fonds en cas d’échec ; clôture, reliquat, recherche et reçu indivisibles en cas de succès. Le registre judiciaire utilise une seule fonction privée d’inscription extraite de justice_condamner ; toutes les gardes publiques du juge et de son audience sont conservées. La lecture et l’exécution de peine utilisent le même calcul du reliquat. Les motifs historiques restent intacts, la recherche devient consultable par justice_recherches.

**Défaut de fixture corrigé explicitement** : les premières preuves des prototypes policiers utilisaient une colonne simplifiée inf ; celle du vol utilisait pop. Le schéma archivé met ces valeurs dans resources. La migration canonique corrige les hôtes, sans ajouter ces colonnes en production. Deux nouvelles configurations suppriment les colonnes artificielles puis passent réellement (5 assertions police, 4 vol). Les résultats anciens ne sont pas présentés comme une preuve de compatibilité vivante.

Le client prépare les huit entrées existantes (les sept actes et le contact religieux), derrière la transition serveur existante rp_transitions, sans en créer ou activer une. Les hôtes gardent leurs moteurs ; le dispatch n’est qu’un adaptateur d’identité et de paramètres. L’identifiant UUID de personnage, confirmé par le serveur, protège le cas d’un nouveau personnage du même nom. Le reçu se relit avant les contrôles de position et après suspension ; ses paramètres restent liés. Les intentions persistantes survivent aux réponses perdues et au rechargement. La relecture utilise les helpers financiers et d’inventaire existants ; aucun simple rafraîchissement partiel ne rebase le repère d’une sauvegarde générale. 16 tests client ciblés passent. Aucun sondage périodique ajouté.

Les gardes conditionnelles bloquent les anciens paiements et lecteurs/commandes concernés après activation, pas avant, et ne bloquent pas l’achat légal d’armes. Deux configurations de 15 assertions passent ; trois contre-épreuves détectent les gardes retirées. La définition vivante de justice_executer_condamnation_soi manque toujours : aucun patch inventé de cette porte ni promesse de fermeture globale.

**Blocages réels, donc pas de clôture ni d’activation** : historique du bonus d’évasion du déserteur non sauvegardé dans les sources examinées (aucune remise à zéro inventée ; refus avant dépense), protection financière contre les sauvegardes périmées non attestée, définition de l’exécution personnelle absente des archives, inventaire des anciens vols en attente et prévol Supabase vivant manquants. L’accès Supabase/Vercel n’est toujours pas exposé à Codex. L’agent principal doit obtenir ces observations réelles ; aucune manipulation SQL demandée à Fred. La campagne complète est en cours après ces corrections ; les résultats finaux seront sauvegardés séparément, sans assimiler le local à la production.


Complément client de reprise : délai local borné à 15 secondes sans présumer d’un refus serveur, conservation du même UUID, garde de contexte avant l’envoi et réponse tardive ignorée. Les messages persistés au journal échappent le texte reçu ; les zéros sont conservés. 19 tests client ciblés passent. Les noms RPC restent explicites dans le transport pour ne pas les dissimuler au contrôle Authority. Le prévol inclut maintenant les transitions existantes, les droits de la vue et l’arriéré des vols agrégé ; aucun accès Supabase ni activation disponible. La campagne complète précédente passe 112 clients / 61 configurations PostgreSQL / 91 contre-épreuves ; ultime vérification client après ce complément en cours.


Corrections finales encore privées : après les gardes historiques, `20261025113001_jets_suspension_sans_legacy.sql` maintient la fermeture même lorsque la transition existante est suspendue (les anciens clients ne doivent pas retrouver une porte ouverte). `20261025113501_vol_pnj_caracteristiques_reelles.sql`, après la correction canonique des ressources, utilise car_per/car_int du socle PNJ plutôt qu’une estimation à neuf ; la fixture de schéma reproduit l’écart 75 contre 60 puis vérifie sa correction, sans inventer de butin PNJ. Aucun changement de seuil ni de caractéristique réelle. La campagne finale est relancée ; aucune transition activée, aucune donnée réelle modifiée.


Dernière garde client : une relecture sans propriétaire confirmé est refusée, même après un reçu valide ; l’intention reste disponible pour reprise. Le banc ciblé couvre désormais 20 cas, dont délais, réponse tardive, changement de personnage, identité recréée, suspension, valeurs nulles et texte du journal. Sources applicatives figées pour l’archivage final ; les blocages Supabase, du compteur déserteur et des sauvegardes financières restent ouverts.


### Bilan final de la continuation — sources 4e68e41

Dernier main intégré et revérifié : `c6aa8ec`, aucune nouvelle avance distante au dernier fetch. Code et preuves sauvegardés sur la branche de reprise. Campagne finale : **112/112 clients, 61/61 configurations PostgreSQL, 91/91 contre-épreuves historiques**, 20 cas client ciblés inclus. Globaux **6/12**, les mêmes six rouges ; Authority 47 RPC non extraites et ancienne signature de fontaine, Referential trois écarts d’empreintes inchangés. Aucun ajustement de baseline pour masquer un échec.

Lire `outils/audits/CLOTURE-L09-135-20261025.md` pour ce qui est réellement codé et ce qui ne l’est pas, l’ordre des onze composants de ce tour, la suspension sans retour legacy et les conditions de déploiement. Preuves brutes, manifeste et sources liées : `outils/audits/luthecia-20261025/CLOTURE-L09-*`.

**CHANTIER NON TERMINÉ** : pas d’accès Supabase/Vercel dans Codex. Restent le compteur historique du déserteur, le garde financier contre sauvegardes périmées à confirmer ou compléter, l’exécution personnelle et ses appelants vivants, l’arriéré legacy et la recette authentifiée isolée. Ne pas inventer zéro, ne pas purger, ne pas exposer les commandes privées ni activer une transition pour prétendre terminer. Le prévol prêt à l’emploi est destiné à l’agent principal avec connecteur ; aucune manipulation technique demandée à Fred. Aucun merge main, aucune migration appliquée et aucun joueur réel modifié par cette session. Ne pas fermer #135.
