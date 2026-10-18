# Interception policière — PR 46 — 18 octobre 2026

**CHANTIER NON TERMINÉ. Corrections clientes éprouvées, fusion et déploiement suspendus.**

## État vérifié

Branche `fix/interception-policiere-main-20261018`, départ `0b48c741d946de46079d050e79354214306b41e8`. Main récupéré : `e66dd19` (optimisation des vues lorsque l'onglet est masqué, PR 45), ancêtre de la branche : pas de divergence locale à intégrer lors du contrôle. PR 40 récupérée uniquement en lecture comme référence ; aucune migration de cette ancienne branche n'est importée ou exécutée.

Aucun outil Supabase/Vercel exposé, aucun accès SQL ou jeton de ces services dans l'environnement. Les accès au catalogue REST Supabase, à `https://res-publica.vercel.app/` et à l'API GitHub sont refusés par le proxy HTTPS (403). Git fetch/push fonctionne. Le brouillon et les contrôles distants de la PR ne peuvent pas être relus ici. Les signatures annoncées par le propriétaire sont une référence de travail, **pas une inspection vivante réalisée dans cette session**.

## Corrections réalisées

- Le point d'entrée direct de reddition refuse désormais aussi une réponse incertaine : appeler ce helper ne contourne plus le verrou de l'interface.
- Dès qu'un acte est envoyé, les boutons deviennent désactivés ; dès qu'une réponse est perdue, la fenêtre est réaffichée sans actions. Les trois choix restent présents lorsque le résultat est certain et les autorise.
- Reddition confirmée sans identifiant de détention, combat incomplet, arrestation sans détention ou fuite confirmée sans destination exploitable : état incertain conservé, sans inventer de conséquence ni autoriser un autre déplacement.
- Une arrestation explicitement confirmée par le serveur prime sur une neutralisation simultanée : le retour `arrestation:true` n'est plus perdu au profit d'une simple fermeture de combat.
- Les retours asynchrones sont liés au personnage, au compte et à l'identifiant stable de connexion. Une réponse d'une ancienne connexion ne transfère pas le nouveau personnage ni ne remplace ses PA. Un ancien dossier n'est pas conservé sur le personnage suivant.
- Entrée de bâtiment, entrée de pièce, sortie et mouvement de rue passent par une garde commune pendant l'interception ou sa résolution. Ce sont des protections **clientes supplémentaires**, pas une preuve d'autorité serveur contre un navigateur modifié.
- La fuite réussie conserve le rendu d'une destination déjà persistée par le serveur, sans rejouer un ordre de déplacement. La restauration de rue demeure en lecture seule.
- Aucun moteur de combat ajouté : les résolutions restent des RPC. Les effectifs et PA affichés sont issus du verdict ; aucun tirage de combat local.
- Versions des trois scripts modifiés incrémentées dans `plateau.html`. Modale commune et charte existante conservées, aucune nouvelle charte.

## Vérifications exécutées

- **28/28 tests ciblés exécutant les vraies fonctions clientes** : les trois choix, doubles clics/requêtes simultanées dans le même client, réponses perdues, appels directs, réponses d'un ancien personnage, PA et effectifs, neutralisation, arrestation, détection, navigation bloquée, clôture et restauration de rue en lecture seule.
- **74/74 bancs du contrôleur complet**, dont détention, avis de recherche et conditionnement Vercel des API. Les dépendances du banc sont celles de cette branche ; ne pas comparer ce total aux branches comportant d'autres bancs non fusionnés.
- **90/90 contre-épreuves**, défauts réintroduits dans des copies.
- **5/5 tests calendrier universel**.
- **23 modules API** analysés. JavaScriptCore absent sur Linux : lanceur Node externe au dépôt utilisé pour les anciens outils ; aucune assertion retirée.
- Garde du payload conforme : **313,1 Mo / 330 Mo**.
- Préflight SQL analysé par pglast : **8 instructions**, aucune exécutée.
- Contrôle global : **10/12 conformes**, Authority et Referential non conformes (voir ci-dessous). Le premier passage a aussi signalé le format `BEGIN TRANSACTION READ ONLY` du nouveau préflight, que le garde ne reconnaît pas. Il a été remplacé par `BEGIN; SET TRANSACTION READ ONLY; ... ROLLBACK;`, en conservant sa sécurité et le test.

**Portée des tests ciblés : réponses RPC simulées, pas des requêtes authentifiées vers Supabase.** La concurrence testée est celle du client, pas celle de deux transactions PostgreSQL réelles. Aucun test intégré de production, aucune nouvelle observation serveur, aucune preuve de déploiement Vercel.

## Blocages de clôture : serveur et reprise

Les seules définitions SQL examinables ici sont des **sources historiques de PR 40**. Il faut les comparer aux définitions vivantes avant toute correction serveur.

1. La définition historique de `police_combat_rounds` ne conserve que `(personnage,rencontre,round_key,created_at)`, sans résultat. La dernière définition historique de combat insère directement la clé, sans traitement du conflit ni restitution d'un reçu. Une contrainte unique peut refuser le rejeu, mais **elle ne permet pas de récupérer le verdict perdu**. La fonction valide aussi détention/expiration avant ce point : le simple ajout d'un `ON CONFLICT` ne suffirait pas à récupérer un round terminal.
2. Le RPC historique `rue_position_lire` renvoie seulement pays, ville, bâtiment, pièce et rue. Il ne renvoie ni rencontre active, ni round courant, ni effet de fuite, ni détention ni PA. Sa lecture ne suffit pas pour les reprises A–E demandées.
3. Les opérations historiques de reddition/fuite expirent la rencontre. Sans reçu persistant consultable par son propriétaire, une répétition peut répondre `rencontre_invalide` au lieu de restituer une décision déjà commise. Une rencontre non chargée après reconnexion n'est pas sécurisée par une variable JavaScript transitoire.
4. Les gardes clientes ajoutées ne remplacent pas le contrôle serveur des déplacements de bâtiment/pièce ni la protection contre deux onglets. Les circuits historiques de sauvegarde de position doivent être confrontés aux triggers/RLS vivants avant de les déclarer sûrs.
5. Le socle commun `combat_coup_resoudre`, les privilèges, signatures uniques, prérogatives des agents, positions, transferts carcéraux dans les trois villes et dates civiles exigent une inspection vivante puis des tests PostgreSQL et authentifiés isolés. Aucun test sur un joueur réel ne doit servir de substitut.

Aucun nouveau RPC de récupération inventé côté client ; aucune migration aveugle et aucune suppression de protection pour contourner ces blocages. Le message de rechargement est conservé comme précaution, **pas présenté comme une reprise serveur désormais implémentée**.

### Contrôles globaux toujours rouges

Authority : **11 RPC absentes du baseline**, dont les procédures de ce chantier. La déclaration ancienne du baseline ne prouve pas leur absence en production ; le signal reste bloquant tant que l'état vivant n'est pas réconcilié.

Referential : deux mesures périmées (`ordres_couts`, `postes_nommes_regles`) et trois diagnostics en cascade déjà connus sur cette base. La correction de diagnostic de la PR 42 n'est pas importée dans ce chantier distinct. Aucun relevé, empreinte ni attente n'est falsifié pour verdir ces contrôles.

## Reprise technique sûre

`outils/bancs/PREFLIGHT-INTERCEPTION-46.sql` est préparé pour inspecter, en transaction explicitement READ ONLY, les définitions/signatures, droits, RLS, colonnes, index et triggers nécessaires. Il ne lit aucun personnage. Il n'a pas été exécuté ici et n'est pas une migration.

Après accès technique rétabli : relever le catalogue vivant et le registre ; établir les définitions exactes et leurs dépendances ; concevoir sur ces contrats un reçu immuable du résultat des actes/rounds, persisté dans la même transaction que les PA/agents/détentions/positions ; garantir sa restitution au propriétaire avant les gardes qui deviennent fausses après un acte terminal ; fournir une lecture autorisée de l'état courant et de la rencontre encore valide. Conserver les verrous d'acteur/rencontre et le moteur de combat commun. Tester succès, refus, rollback, deux connexions concurrentes, reprise des résultats et expiration sur PostgreSQL isolé, puis en authentifié sur comptes autorisés. Aucun de ces travaux n'est délégué au game designer.

Les 20 cas de la mission ne sont donc **pas tous validés côté serveur** : les comportements de reprise réelle, concurrence inter-sessions, détention restaurée et expiration demeurent à vérifier/corriger. Cette absence de preuve interdit la fusion, la sortie du brouillon et une annonce de mise en production.

Aucune donnée réelle modifiée. Aucune migration appliquée. Aucune fusion de main ou de PR 40. Aucun déploiement annoncé.

## Vérification vivante complémentaire — session ChatGPT du 18 octobre

Les accès GitHub, Supabase et Vercel ont été rétablis **dans cette session**, sans changement de configuration par Codex. Vérifications directes :

- GitHub PR 46 : ouverte, brouillon, fusionnable, HEAD `89c9e9aee9acb77d0b466bbbc2c8dd8c4e3cb00f` ; trois workflows GitHub Actions de ce commit réussis.
- Supabase `jxpwoosmmhohoihxpbuc` : projet `ACTIVE_HEALTHY`. Les définitions **vivantes** de `police_combat_resoudre`, `police_detection_verifier`, `police_fuite_resoudre`, `police_reddition_resoudre`, `rue_position_lire` et `rue_position_enregistrer` ont été lues.
- La définition vivante du combat insère `(personnage, rencontre, round_key)` sans enregistrer de verdict ; l'index primaire unique protège contre la réexécution mais ne restitue pas le résultat. Le test de détention et d'expiration précède l'insertion, ce qui empêche la reprise fiable d'un round terminal.
- `police_combat_rounds` contient uniquement `personnage`, `rencontre`, `round_key`, `created_at`. `police_interceptions` ne possède ni colonne de reçu ni colonne de round courant. Les deux tables possèdent une clé primaire composite ; aucune politique RLS n'a été renvoyée pour elles dans le relevé.
- `police_fuite_resoudre` marque `fuite_tentee` puis déplace le PJ et expire la rencontre en cas de réussite ; `police_reddition_resoudre` exécute la condamnation puis expire la rencontre. Aucune des deux procédures ne conserve un verdict consultable après perte de réponse.
- `rue_position_lire` ne renvoie que pays, ville, bâtiment, pièce et rue. `rue_position_enregistrer` refuse les déplacements si une interception active existe.
- Vercel : déploiement **preview** du commit `89c9e9a` en état `READY` ; **aucun déploiement production ni fusion confirmé**.

**Conclusion** : le blocage d'accès est levé, mais les défauts serveur sont désormais établis sur les procédures réellement installées. Il faut un reçu immuable transactionnel et une API de reprise authentifiée, puis des tests d'idempotence et de concurrence. Ne pas fusionner avant cette étape. Aucun changement de données ni de schéma n'a été réalisé lors de cette vérification.
