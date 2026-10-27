# #135 — Vigiles, détection commune et vol atomique, 27 octobre 2026

**CHANTIER NON TERMINÉ. Branche de préparation, à ne pas fusionner ni déployer en l'état.** Les mécanismes décrits ci-dessous sont codés et éprouvés sur PostgreSQL jetable. La modalité terminale de remise à la police et le contrat persistant de bénédiction empêchent encore la clôture. Aucun résultat local n'est présenté comme une preuve de fonctionnement en production.

## Périmètre et reprise

Branche : `codex/vigiles-vol-135-20261027`. Départ de `83b5c78605713670fffddbdf0620c69c33446c44` (#194), puis intégration propre du main documentaire `051e6ad59d770e0f6324db7f7af60a3e2f601365` (#195). Le déploiement READY de #194 est une information transmise par Fred ; cette session ne l'a pas vérifié à distance.

AGENTS, RELAIS, Constitution, Architecture et workflow Supabase lus. Les fichiers métier ambassades/BNE et la refonte transversale de Claude ne sont pas modifiés. Aucun fichier généré du baseline ni aucune empreinte de contrôle modifiés. Aucun prix, coefficient ou taux économique changé.

Décisions de référence : [GAME-DESIGN-SECURITE-CHANTIERS-135.md](../../GAME-DESIGN-SECURITE-CHANTIERS-135.md). Le droit d'intervenir après détection est déjà validé ; il n'est pas remis en question.

## Code réellement préparé

### Agents réels

`chantier_vigiles_affectations` relie une mission aux PNJ employés existants, à leur employeur et au maître d'ouvrage. Les positions, statuts, métiers et droits viennent du socle : `pnj_position_effective`, `pnj_co_present`, `pnj_peut_conduire`, `pnj_quitter_groupe` et autorité commune du chantier. Aucun recrutement parallèle et aucun PNJ inventé.

Les agents portés par un groupe, absents, sans PA, licenciés, mutés ailleurs ou dont la mission ne correspond plus au propriétaire sont exclus de la protection. Un même PNJ n'a qu'une affectation. Le prévol refuse les sources PNJ/terrains directement falsifiables par un rôle navigateur. Le menu du propriétaire réutilise le roster commun et permet l'affectation ; le rappel utilise la gestion de groupe existante.

Le JSON historique `chantier.vigiles` ne décide plus de la protection : à l'ouverture du vol, le client lit la présence autorisée ; pendant l'acte, le serveur la recalcule sous verrou. L'ordre gratuit d'affectation est déclaré dans le code et ajouté au miroir par la migration future, sans avancer sa référence d'empreinte.

### Vol transactionnel

L'action `voler` est raccordée à **`chantier_commande` et à ses reçus existants**. Le serveur relit identité, UID, position, capacité d'action, chantier, stock, groupe, DUP, réputation, indice et agents. Il utilise le payeur commun, le calcul historique porté en SQL, l'inventaire commun et ses révisions, les recherches, traces, événements et journal persistants. Aucun résultat ou montant final n'est dicté par le navigateur.

Les refus métier d’intentions valides sont également figés dans ce registre : la réponse perdue d’un refus reste ce refus même après réapprovisionnement, et sa clé ne peut pas être réutilisée pour une autre matière. Aucun payload mal formé n’est stocké.

Le même reçu englobe le paiement des PA, le retrait de stock, le crédit d'inventaire et les conséquences. Le rejeu restitue le résultat sans nouvelle exécution ; une requête réutilisée sur d'autres paramètres est refusée. Les erreurs après stock ou au reçu annulent tous les effets. L'ancienne porte `chantier_materiaux_voler` refuse de fonctionner hors commande versionnée.

La capacité volontaire de 100 unités existante est réutilisée. Un inventaire plein est refusé avant paiement. Si seules deux unités peuvent entrer, seules deux sont prises. Le premier empilement compatible est augmenté avec le helper commun ; les autres piles historiques et leurs métadonnées restent intactes. La quantité ajoutée doit exactement correspondre au stock retiré. Aucun inventaire existant n'est purgé ou normalisé.

Le client transmet seulement la matière et la commande commune, conserve son intention après perte de réponse et relit terrain, finances et inventaire. Aucun ajout local d'objet, jet ou second débit. Le contexte est vérifié avant l'envoi après renouvellement d'authentification, puis après les attentes. Une réponse `ok` incomplète garde l'intention ; elle ne fabrique ni résultat ni nouvel identifiant.

Les quatre tests historiques #194 sont conservés sur une fixture explicitement archivée du handler remplacé. Les nouveaux tests exécutent le handler actuel et son raccordement réel à la commande ; les gardes historiques de terrain contrôlent désormais la délégation atomique et interdisent tout crédit local.

### Détection réellement partagée

La recherche ciblée dans **l'historique Git** a retrouvé les sources de `police_detection_verifier` et `combat_coup_resoudre`, absentes de l'arbre courant. Elles sont conservées dans `outils/bancs/fixtures/securite-commune-historique-135.json`, avec commits complets, chemins d'origine et SHA-256. Ce sont des photographies de test, **pas des relevés de Supabase vivant**.

La migration factorise uniquement les fragments exacts de perception et de tirage du détecteur policier ; ses autres contrôles restent en place. Police et agents privés utilisent les mêmes trois primitives. Un fragment différent provoque un refus bruyant, sans remplacement par l'ancienne définition. Les droits du détecteur sont conservés et vérifiés sur le moteur jetable.

`chantier_vigiles_detecter` utilise les recherches opposables du moteur commun et étend son registre de tentatives, avec anti-relance et preuve persistante. Il ne crée aucune fausse rencontre policière. La preuve est liée au personnage, au lieu, aux agents et au mandat. Une porte interne la revalide avant toute future intervention ; elle refuse les preuves inventées, agents partis, autres pièces et recherches levées. Aucun joueur ne peut appeler cette confirmation interne.

**La détection et sa précondition sont préparées ; l'orchestration terminale interception/combat/remise n'est pas implémentée.** La primitive commune de combat a été retrouvée et exécutée avec les vrais taux, degrés et dégâts militaires. Ceci ne constitue pas un combat privé complet en jeu. Le nouveau détecteur n'est pas branché automatiquement sur la navigation tant que cette orchestration n'est pas sûre.

## Prérequis qui bloquent encore

1. **Modalité terminale privée.** Une question précise est en attente sur la retenue puis remise à la police après neutralisation, notamment la réutilisation du délai du signalement existant. Aucun nouveau lieu de détention, déplacement forcé, délit de rébellion réservé à la police ou pouvoir institutionnel n'est inventé. Le reste des opérations indépendantes a été poursuivi.
2. **Bénédiction.** Le handler historique consommait `state.char.benediction`; aucun stockage ni producteur persistant correspondant n'est identifié dans les sources actuelles (`sbSavePersonnage` ne transporte pas ce champ). Le schéma archivé ne contient pas la colonne. La base vivante reste à vérifier. La migration refuse explicitement son absence ; les bancs ajoutent une colonne JSONB de contrat dans leur seule base jetable, avec un drapeau d'hypothèse dans les résultats. **Il ne suffit pas d'ajouter une colonne pour franchir le prévol** : il faut établir le producteur, la sauvegarde/consommation, les unités d'expiration et leur compatibilité avec la règle historique, sans accepter un bonus forgé par le client. Cette dépendance du socle partagé doit être résolue avant activation du vol.
3. **Catalogue vivant et permissions.** Les droits, révisions d'inventaire, triggers, fonctions de sécurité et écritures historiques doivent être confrontés à Supabase. Les sources historiques et les fixtures ne les prouvent pas. Ne pas changer une empreinte pour masquer un écart.
4. **Recette authentifiée réservée.** Aucun compte isolé autorisé n'est accessible ici. Arnie conserve le périmètre de consultation seule ; aucun déplacement, vol ou combat n'est effectué avec lui.

## Migrations préparées, ordre et portée

| Chemin | Portée / dépendance |
|---|---|
| `migrations/20261027121000_chantier_vigiles_socle.sql` | Affectations des vrais PNJ, portes de lecture/affectation, miroir de l'ordre gratuit ; exige l'autorité réelle et les sources non modifiables depuis le navigateur |
| `migrations/20261027122000_chantier_vol_transaction_interne.sql` | Moteur interne du vol ; exige le contrat persistant de bénédiction et le trigger d'inventaire révisé |
| `migrations/20261027122100_chantier_vol_commande_et_fermeture.sql` | Raccordement au reçu commun et fermeture du vol legacy ; dépend des deux précédentes |
| `migrations/20261027130336_securite_detection_partagee.sql` | Primitives de détection communes, patch exact de la police et preuve privée ; dépend des affectations et du registre commun vivant |

**Aucune appliquée à Supabase.** Chaque fichier reste sous la limite indicative de transport MCP de 12 500 caractères. Les migrations sont rejouées dans les bancs. Le refus d'une formule de détection inconnue et le rollback du DDL sont aussi éprouvés.

Prévol : `python3 outils/bancs/prevol-vigiles-vol-135.py` imprime les requêtes en transaction READ ONLY, en réutilisant `PREFLIGHT-INTERCEPTION-46.sql`. Il ne se connecte à rien et n'exécute aucun SQL. Le connecteur technique devra l'exécuter sur `jxpwoosmmhohoihxpbuc`, examiner les définitions et contraintes, puis suivre intégralement `WORKFLOW-SUPABASE.md`. Ne pas rejouer les anciennes migrations récupérées dans la fixture Git.

## Résultats isolés

| Contrôle | Résultat |
|---|---|
| Pilote complet, Chromium local inclus | **118/118**, aucun ignoré |
| Contrôleur client complet | **105/105** |
| Sécurité/vol sur PostgreSQL jetable | **81 assertions supplémentaires**, en plus des **62** historiques du banc commun |
| Grilles différentielles exactes | **720** du vol, **112** de détection, **16** de perception de groupe (pièce et rue) |
| Parcours intégré des cinq terrains | **354 assertions** : les **324** existantes conservées et **30** ajoutées dans les mêmes chantiers ; **61** assertions bancaires sous-jacentes |
| Trois mutants du vol/sécurité | Tous détectés : crédit absent, paramètres ignorés au rejeu, statut d'agent ignoré |
| Trois mutants du parcours intégré | Tous détectés : prix/surfaces uniformisés, jour rejoué, tranche financière altérée |
| Contre-épreuves historiques | **89/91**, contre **84/91** sur le main de référence ; voir les deux échecs ci-dessous |
| Syntaxe API | **23 modules** conformes ; aucun appel distant |
| Grammaire SQL des quatre migrations et du prévol | Conforme |
| Contrôles globaux | **4/12**, huit contrôles rouges conservés |

Les preuves brutes et le manifeste sont dans `outils/audits/vigiles-vol-135-20261027/`. Les tests de réseau sont des transports contrôlés et des promesses retardées ; les tests PostgreSQL utilisent de vraies transactions, mais une authentification/identité de fixture. La comparaison de schéma réel n'est pas remplacée par ces tests.

Les cas incluent : cinq affectations, agent absent/licencié/porté/autre chantier, malus effectif de 0/1/2 agents, autorité, recherches et preuves, deux voleurs sans aucun verrou PNJ parasite, doubles appels, réponse perdue et reconnexion, même clé modifiée, deux points de panne, contexte de transport invalide, anciens PATCH/CAS d'inventaire, capacité et métadonnées de piles, changement de personnage/ville/pièce, renouvellement d'auth différé et réponse `ok` incomplète.

Les 354 assertions **ne couvrent pas une arrestation, un combat privé terminal ou une remise à la police**. La bénédiction et le détecteur reposent sur les hypothèses clairement marquées par le JSON de résultat. Ne pas les présenter comme un schéma vivant vérifié.

### Échecs conservés et expliqués

Les cinq contre-épreuves immobilières devenues obsolètes ont été raccordées aux vrais adaptateurs actuels, sans retrait d'épreuve et avec renforcement de l'absence de patch client. Deux ancrages restent en échec, déjà présents sur main et hors immobilier :

- « enquête conclue attend la transmission » : chaîne attendue introuvable ;
- « Suivre une formation / bientôt » : deux occurrences au lieu d'une.

Ils n'ont été ni désactivés ni artificiellement réussis. Aucun fichier de jeu correspondant n'est modifié pour les faire passer.

Les huit contrôles globaux rouges sont Workflow, Classification, Baseline, Authority, Referential, Fonctions, Assemblage et Reconstruction. Les familles d'échecs existaient avant ce lot. Les sorties **ne sont pas identiques** : Authority relève 85 RPC absentes du baseline contre 83 sur le main de référence, en raison des deux RPC clientes préparées. Referential change aussi l'empreinte générée des ordres avec le nouvel ordre gratuit, non encore appliqué/réextrait. Ces écarts supplémentaires sont attendus pour une branche non déployée mais restent des écarts, pas des succès. Aucune référence du baseline avancée pour les cacher.

## GitHub, Vercel et données réelles

Sauvegardes régulières poussées sur la branche dédiée. Création de PR en brouillon tentée : `Post https://api.github.com/graphql: Forbidden`, donc **aucun numéro de PR créé ni fusion effectuée**. Lecture de l'issue par l'API également refusée. Le texte de revue est prêt ; ne pas fermer #135.

HTTPS Vercel échoue avant réponse du site : `Tunnel connection failed: 403 Forbidden`. Aucun outil Supabase/Vercel exposé et aucun accès direct de base disponible. Ceci ne démontre pas une panne de production. Aucun nouveau déploiement de production effectué par cette session ; éventuels Preview de branche non observés.

Aucun compte, mot de passe, UID, secret, solde, inventaire ou position de joueur réel modifié. Aucune migration ni transaction métier exécutée en production. Aucune campagne authentifiée nouvelle lancée.

## Reprise technique et retour arrière

L'agent chargé de l'intégration doit récupérer le prévol vivant, résoudre le stockage de bénédiction avec le socle partagé, puis terminer la remise/intervention selon la modalité validée, avec la primitive commune. Ajouter ses scénarios terminaux aux bancs existants, vérifier les hypothèses et interactions réelles, puis seulement envisager CI, fusion, migrations enregistrées et réextraction/rendu du baseline selon le workflow. Le client doit être publié après vérification du contrat serveur, pas avant.

Avant migration : conserver définitions/ACL exactes des deux fonctions patchées, empreintes des données concernées, registre et dépendances ; vérifier qu'aucun lecteur/ancien écrivain ne contourne le stock ou les révisions. Les DDL ne contiennent aucun achat, vol témoin, création de PJ ou autre démonstration métier réelle.

Une reprise après application interrompue commence par le registre, pas par une nouvelle commande de joueur. Ne pas réouvrir la porte legacy pour « revenir en arrière ». Si un défaut apparaît après activation, suspendre l'ordre de vol, conserver reçus et affectations, puis corriger en avant. Ne supprimer aucune colonne, table ou inventaire contenant des actes ; toute restauration d'une définition sauvegardée doit conserver les reçus et les propriétés déjà acquises, et être vérifiée via le processus officiel.

**Développement avancé et sauvegardé ; clôture technique et recette réelle non acquises.** Aucun travail nécessaire n'est délégué au game designer, hors la seule modalité de remise déjà demandée.
