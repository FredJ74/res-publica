# Arnie — raccordement du personnage historique, consultation seule

## Verdict réel

**RACCORDEMENT NON TERMINÉ. Aucun parcours authentifié effectué.**

Le personnage autorisé est exclusivement **Arnie**. Son `user_id` n'a pas pu être lu dans cette session et son type d'authentification dans `auth.users` reste **inconnu**. Aucun UID n'est repris d'un autre personnage ni inventé. Les UUID des tests sont des valeurs fictives locales, jamais une identification du compte réel.

Aucun connecteur Supabase n'est exposé à Codex et aucune variable d'accès Supabase n'est disponible. Les requêtes HTTPS vers `jxpwoosmmhohoihxpbuc.supabase.co/auth/v1/health`, le site et l'API GitHub (environnement `luthecia-e2e`) échouent au tunnel du proxy : `CONNECT tunnel failed, response 403`. Aucun statut HTTP applicatif n'a été obtenu ; cela ne prouve ni une panne Supabase/Vercel ni un défaut des droits du compte.

Aucun compte réel créé, converti ou réinitialisé. Aucun transfert, changement d'UID, inventaire, finance, caractéristique, progression, relation ou mandat réel modifié. Aucun jeton du navigateur personnel recherché, copié ou enregistré. Aucun mot de passe réel inventé ou récupéré. Aucun SQL exécuté en production.

## Audit de l'existant, limité au code accessible

- `auth.js` conserve une session Supabase avec renouvellement. Une ouverture du jeu sans saisie de mot de passe peut correspondre à une session anonyme **ou** classique conservée : ce symptôme ne suffit pas à déterminer le type d'Arnie.
- `rpAuthSecuriserCompte` utilise la procédure existante `PUT /auth/v1/user`, sur le compte connecté, avec seulement e-mail et mot de passe. Aucun paramètre d'UID ni de personnage ne sert à choisir une autre identité. L'UID de réponse est comparé à l'UID précédent ; un UID différent provoque un refus explicite.
- `rpAuthEtatCompte` lit GoTrue et distingue compte encore anonyme, adresse en attente et adresse confirmée. `rpAuthSeConnecter` ouvre une session indépendante par e-mail/mot de passe, puis le serveur détermine le personnage avec `mon_personnage`.
- Une session anonyme ne peut pas être transportée vers le robot sans facteur de connexion indépendant. Copier les jetons personnels ou appeler `rattacher_personnage` serait un contournement exclu de ce chantier.

Ces constats de code **ne vérifient pas** les déclencheurs réels d'authentification, le compte ou le patrimoine d'Arnie. Les tests de conservation d'UID utilisent les vraies fonctions JavaScript avec des réponses fictives, pas le compte réel.

## Modifications réalisées

### Mode `consultation_seule`

Le pilote accepte l'autorisation historique pour Arnie sans prétendre qu'il soit un compte réservé aux tests. Il exige avant lancement un audit vivant récent : nom exact, UID exact, compte unique, `auth.users` vérifié, accès classique confirmé, correspondance entre adresse et UID, et effets de navigation inspectés. Une adresse différente est refusée avant tentative de connexion ; cela évite de connecter accidentellement un compte du propriétaire ou de sa famille.

La réponse d'authentification et la réponse de `mon_personnage` sont contrôlées avant d'être exposées à l'application. Un autre UID, un autre personnage ou un compte non confirmé ne deviennent jamais Arnie « par défaut ». Les contrôles de session avant/après les déplacements restent en place.

La garde réseau du contexte Chromium est installée avant la première page. Elle bloque notamment :

- création anonyme, conversion d'authentification, rattachement et administration de comptes ;
- sauvegardes générales et urgentes, écritures de présence et d'inventaire, réceptions automatiques, dons et transferts ;
- production, achats, invitations, réponses et autres RPC non établies sans effet ;
- API métier et cron, y compris par GET, Edge Functions et WebSockets ;
- dialogues PNJ, car leur absence de coût et d'effet de mémoire/progression n'est pas démontrée pour cette campagne.

Seuls restent admis l'authentification normale du même compte, son renouvellement, les lectures REST, quatre RPC de lecture explicitement énumérées et le déplacement de rue existant après validation du personnage, avec destination à Luthécia. La déclaration d'audit ne remplace pas la vérification technique réelle des fonctions et déclencheurs. Aucun contrôle serveur de police, détention ou déplacement n'est contourné et aucun succès fictif ne remplace une requête bloquée.

Le parcours de ce mode ne déclenche pas les ordres métier ni les dialogues et ne recharge pas la page pour contourner un échec de déplacement. Il vérifie l'empreinte de tous les champs de la fiche exposée hormis position et date de modification. Les preuves exportent des empreintes, pas les montants et données privées d'Arnie. Une variation imprévue arrête le pilote ; il ne restaure ni n'écrase les données pour masquer un écart.

### Limite de navigation à résoudre sur l'état réel

Le code actuel `enterRoom` persiste sa position par `sbSavePersonnage`. Ce circuit peut appeler `inventaire_sauver_revision` puis écrire une fiche complète. De plus, le déclencheur archivé `personnages_vue_modifier` réécrit de nombreux champs ; un PATCH contenant seulement une position ne prouve pas, à lui seul, que seules ces colonnes seraient écrites côté serveur.

**Ces écritures restent bloquées dans le mode Arnie.** Si la pièce n'est pas confirmée au serveur, le parcours échoue honnêtement. Ni le transport, ni une réponse simulée, ni une navigation locale ne remplacent cette confirmation. L'accès au catalogue vivant doit permettre d'identifier le circuit de position réellement installé et ses effets ; aucune nouvelle RPC ou migration de navigation n'est créée à l'aveugle pour contourner le problème.

Le mode préparé ne constitue donc pas, à lui seul, une certification que toutes les pièces peuvent déjà être parcourues sans conséquences.

### GitHub Actions

Le workflow manuel propose `consultation_seule` par défaut, avec le nom fixé à Arnie. Ses secrets sont distincts de ceux des comptes isolés : `HG_E2E_ARNIE_EMAIL`, `HG_E2E_ARNIE_PASSWORD`, `HG_E2E_ARNIE_UID`, `HG_E2E_ARNIE_AUTORISATION_JSON`, exclusivement dans l'environnement protégé `luthecia-e2e`. Un secret manquant ne retombe jamais sur la valeur d'un autre compte.

Le mode consultation refuse un déclenchement `schedule`. Le mode isolé refuse Arnie. Aucun planning récurrent avec le personnage principal n'a été activé. Aucun secret distant n'a été lu, créé ou modifié, et l'existence/configuration de l'environnement distant n'a pas pu être vérifiée. Le lancement manuel distant n'a pas été effectué : accès API bloqué et conditions d'identité non établies.

## Prévol Supabase préparé

Fichier : **`outils/bancs/prevol-arnie.sql`**.

Transaction `BEGIN / SET TRANSACTION READ ONLY / ROLLBACK`, destinée à un opérateur technique disposant du canal Supabase autorisé. Elle :

1. recherche exactement `name='Arnie'`, refuse zéro résultat, homonyme, UID nul ou utilisateur Auth absent ;
2. rejoint `auth.users` uniquement par le `user_id` de cette fiche ;
3. relève anonymat, confirmation, présence d'un mot de passe et fournisseurs d'identité sans exposer adresse, mot de passe ou jeton ;
4. fournit une empreinte d'adresse pour vérifier que les secrets correspondent bien à cet UID, une empreinte de la fiche protégée et le nombre de personnages du même compte ;
5. extrait fonctions, droits, RLS et déclencheurs de navigation/fiche, ainsi que les déclencheurs `auth.users` et `auth.identities` à examiner avant toute sécurisation.

Aucune ligne de ce fichier n'a été exécutée sur Supabase ici. Aucun résultat ni empreinte de production n'a été fabriqué pour remplir l'autorisation.

## Vérifications exécutées

| Vérification | Résultat réel |
| --- | --- |
| Pilote et mode consultation, dont Chromium local | **59/59 tests**, zéro ignoré |
| Audit SQL sur PostgreSQL jetable | **5/5 groupes** |
| Contrôleur client existant | **90/90 bancs** |
| Syntaxe JavaScript et analyse SQL | Conformes |
| YAML et sélection des secrets distincts | Conformes localement ; exécution GitHub distante non observée |
| Contrôles globaux | **10/12**, Authority et Referential restent rouges |
| Tentative du pilote pour Arnie | **BLOQUÉ**, code 2, avant connexion : autorisation issue d'un audit réel indisponible |
| Compte Arnie et `auth.users` vivants | **Non consultés**, accès indisponible |
| Parcours authentifié et déploiement vérifié | **Non exécutés / non vérifié** |

Les tests comprennent refus d'un autre nom/UID/adresse, compte partagé, anonymat, confirmation manquante, audit périmé, cron Arnie, plans sensibles, sauvegardes, réceptions et changement d'authentification. Le test Chromium local vérifie que les POST/PATCH/PUT et appels cron interdits n'atteignent pas le serveur de fixture. Les vrais contrats JS de sécurisation sont exercés sur réponse conservant l'UID, confirmation en attente et réponse proposant un UID différent. Le SQL est exécuté sur des lignes locales fictives : cas anonyme/classique, homonymes, UID absent et utilisateur Auth absent.

Ces réussites ne constituent pas une connexion à Arnie. **Bâtiments réellement visités : aucun. Ordres réels exécutés : aucun. Anomalie réelle en jeu reproduite : aucune.** La limite des sauvegardes de pièces est constatée dans les sources accessibles, pas reproduite sur le compte réel.

Le contrôle de rangement a d'abord refusé le SQL placé dans `outils/e2e` ; il a été déplacé dans `outils/bancs`, son emplacement prévu par le workflow, puis les contrôles ont été relancés. Aucune exception de validation ni référence de baseline n'a été modifiée pour obtenir ce résultat.

## Reprise sans opération technique demandée au propriétaire

La prochaine opération relève de l'accès technique : rétablir le canal Supabase autorisé et l'accès à l'API GitHub depuis l'environnement, puis réaliser le prévol en lecture seule. Tant que cela manque, il est impossible d'indiquer honnêtement l'UID d'Arnie, son type de compte ou la présence de ses secrets Actions.

Si et seulement si le compte est constaté anonyme et que la même identité ainsi que les effets des déclencheurs sont vérifiés, l'éventuelle action personnelle minimale sera l'interface déjà présente : **Mon personnage → Identité → Sécurité du compte → Sécuriser mon personnage**, puis la confirmation reçue par e-mail si nécessaire. Le propriétaire choisit et saisit ses identifiants dans cette interface ; aucun secret ne doit être envoyé dans le chat. Le catalogue doit ensuite être relu pour confirmer le même UID, le même personnage et les données protégées.

Si le compte est déjà classique confirmé, aucune conversion n'est nécessaire ; seuls l'accès indépendant approuvé, le circuit de position sûr et les secrets protégés doivent être vérifiés par l'opérateur avant le lancement manuel. Aucune action personnelle du propriétaire n'est démontrée indispensable à ce stade, puisque le type réel reste inconnu. Aucun SQL, script ou réglage GitHub ne lui est demandé.

Les consignes de reprise cloud ont été sauvegardées dans le brouillon avec cette autorisation limitée. Leur publication ne constituerait ni un audit Supabase, ni la configuration des secrets GitHub, ni un lancement de campagne.

Les captures d'échec du mode Arnie sont limitées à l'image de la scène (pièce ou rue), hors portrait, soldes, formulaires et modales personnelles. Aucune capture d'Arnie n'a été produite lors de cette session bloquée.
