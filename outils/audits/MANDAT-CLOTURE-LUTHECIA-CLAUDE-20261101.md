# HUMAN GAMBIT / RES PUBLICA — REPRISE INTÉGRALE ET CLÔTURE DE LUTHÉCIA

## TA MISSION

Tu prends désormais **l'entière responsabilité technique de la clôture de Luthécia**, hors recette finale réalisée par les personnages joueurs.

Fred est le game designer. Tu es responsable de l'exécution technique jusqu'à la livraison vérifiée.

**Tu remplaces ChatGPT comme intégrateur principal et tu reprends le travail de Codex sur la PR #219.**

Ne renvoie pas le chantier à Codex. N'attends pas de nouvelle instruction pour enchaîner les opérations réalisables. N'arrête pas ton intervention lorsqu'un test passe, qu'un commit est poussé ou qu'un blocage est identifié.

L'objectif est de terminer la livraison en production, pas de rédiger un nouveau diagnostic.

## 1. ÉTAT EXACT DE LA CERTIFICATION CODEX

Dépôt : `FredJ74/res-publica`

PR principale : https://github.com/FredJ74/res-publica/pull/219

Commit certifié localement :

`57f4ede9008e293fbe422db5abed7a4819068445`

Rapport à lire intégralement :

`outils/audits/CERTIFICATION-1022-219-20261101.md`

Lire également, dans cet ordre :

- `AGENTS.md`
- `RELAIS.md`
- `AUDIT_UNE_SEULE_VERITE.md`
- Les manifestes, plans et rapports de certification #219.
- Les documents de livraison des PR #318 et #324.

**Codex a déjà réussi :**

- Reconstruction fidèle d'une capture privée de 1 022 migrations.
- PostgreSQL 17.6, ICU en-US 153.121.
- Six empreintes racines du schéma conformes.
- Douze référentiels privés conformes.
- Recompilation de 1 221 fonctions.
- Installation des 95 migrations #219 sur clone jetable.
- Rollback et rejeu vérifiés.
- Installation des deux migrations complémentaires #318 et #324.
- 27/27 tests HTTP authentifiés.
- 163/163 bancs clients.
- 29/29 assertions financières.
- 14 cas de déplacements résiduels.
- 30 cas d'hospitalisation.
- Réconciliation des 460 tarifs actuels.
- Intégration du dernier `main` connu par Codex, `9ce70b64`.

Les archives privées ne doivent jamais être publiées dans GitHub.

**Ne recommence pas cette reconstruction inutilement.** Réutilise les preuves, le code et les outils existants. Relance seulement les tests nécessaires pour démontrer tes corrections et valider le candidat final.

## 2. PRIORITÉ ABSOLUE : RÉSOUDRE LES DEUX CONTRÔLES ROUGES

État : **10/12 contrôles globaux réussis**.

### A. Authority

Onze diagnostics restent signalés :

- Un spread statique de `tournee_creer`.
- Deux RPC de manifestation absentes.
- Huit anciens appels dont l'exécution est refusée.

Pour chacun :

1. Identifie précisément l'appelant, la fonction, sa signature, son niveau d'autorité et son chemin d'exécution.
2. Vérifie si le circuit est encore accessible ou s'il s'agit d'un vestige effectivement mort.
3. Si le circuit est actif, raccorde-le au mécanisme serveur canonique.
4. S'il est obsolète, supprime proprement sa référence après preuve de non-utilisation.
5. Vérifie l'autorité réelle du PJ/PNJ, les coûts PA/FR, l'atomicité, les doubles clics et les réponses tardives.
6. Ajoute des tests positifs et des contre-épreuves.

**Interdiction de rouvrir des permissions dangereuses, d'autoriser une ancienne RPC pour obtenir artificiellement du vert ou de neutraliser le contrôle.**

Les deux RPC de manifestation doivent être examinées avec le chantier de manifestation spontanée déjà préparé.

### B. Referential

Quatre divergences subsistent :

- Ressources : `2c2a88b3833ca978` / `d65ae14b210eaac4`.
- Chantiers : `fc8ab593a408ed33` / `6f16826f81bad98a`.
- Entreprises : `6b59b4035f19fc59` / `e2b15dda50c9a640`.
- BNE : `d41d8cd98f00b204` / `2cf0edcba2fa05fc`.

Pour chaque divergence :

1. Compare la référence privée capturée, le catalogue reconstruit et les sources actuelles.
2. Détermine si l'écart vient d'un générateur, d'une transformation, d'une ancienne source ou d'une véritable différence métier.
3. Corrige la cause.
4. Préserve les tarifs, recettes, paliers, postes et autres règles déjà validés.
5. Régénère les artefacts à partir des bonnes sources.
6. Ajoute une contre-épreuve qui échouerait si la divergence réapparaissait.

**Ne remplace jamais la référence de production par une valeur arrangée simplement pour obtenir 12/12.**

Ces domaines ont fait l'objet de travaux Claude antérieurs : prends leurs migrations et leurs contrats comme références, sans les réinventer.

**Résultat recherché : 12/12 contrôles globaux, avec preuves exécutables.**

## 3. INTÉGRER DÉFINITIVEMENT #219, #318 ET #324

La branche de reprise Claude existante est :

`claude/integration-219-main-20261101`

Les deux compléments sont :

- #318 : circuits résiduels des déplacements de groupes.
- #324 : hospitalisation à 0 PA.

Vérifie d'abord le graphe Git actuel pour éviter toute double intégration.

La livraison doit conserver :

- Formation et gestion des groupes PJ/PNJ.
- Déplacements collectifs.
- Prêt, dépose et reprise des subordonnés dans les limites d'autorité.
- Commandement radio et portée limitée à la ville.
- Interpellations, combats universels et conséquences judiciaires.
- Cinq rounds de combat obligatoires avant fuite ou reddition.
- Décision collective du chef après le cinquième round.
- Poursuite du combat lorsque le chef est à 0 PA.
- Hospitalisation et déplacements résiduels.
- Protection contre les déplacements partiels, paiements multiples et réponses tardives.
- Positions canoniques serveur et comportement après actualisation.

Les 95 migrations constituent le socle. Les migrations #318 et #324 suivent dans l'ordre certifié.

Réconcilie les branches sans supprimer les corrections déjà fusionnées dans `main`, notamment #327, #328, #305 et #319/#329.

**Ne réintroduis aucune ancienne règle de groupe ou de combat.**

## 4. TRAITER LES MIGRATIONS QUI DÉPENDENT DE #219

Une fois le socle certifié, retrouve et examine les migrations préparées mais dépendantes des groupes universels :

- Manifestation spontanée sur les places des trois villes.
- Issues des combats contre les squatteurs.
- Champs et commandes serveur des organisations.

Vérifie leurs PR, leurs migrations, leurs signatures et leurs dépendances réelles.

Intègre celles qui sont compatibles avec le socle et dont les règles sont déjà validées. Exécute leurs tests et leurs contre-épreuves.

Ne les fusionne pas aveuglément si elles reposent sur des anciennes fonctions.

Pour mémoire, les migrations concernant l'accord tacite des permis, la caisse d'Helvétia et la prime de signature des transferts de football **ont déjà été constatées dans le registre Supabase de production**. Vérifie leur présence mais ne les réapplique pas.

## 5. PRÉVOL FINAL DE PRODUCTION

Avant toute écriture :

1. Relève le dernier `main`.
2. Relève les migrations réellement installées en production par version ou nom canonique.
3. Compare la coupe réelle à la coupe privée 1022 utilisée par Codex.
4. Contrôle les définitions actuelles des fonctions concernées, les empreintes et les référentiels sensibles.
5. Recalcule le delta exact des migrations manquantes.
6. Vérifie que l'ordre respecte toutes les dépendances.
7. Vérifie l'absence de migration déjà appliquée.
8. Prépare un protocole de reprise après interruption, ainsi que les validations après migration.

Si la production a évolué depuis le CSV, **ne suppose pas qu'elle est restée identique**.

Privilégie un prévol en lecture seule, puis une application contrôlée des seules migrations manquantes.

Aucune donnée PJ réelle ne doit être réinitialisée, remplacée par des fixtures ou modifiée par les tests.

## 6. TESTS FINAUX

Sur le candidat de livraison actualisé :

- PostgreSQL 17.6 et catalogue conforme.
- 12/12 contrôles globaux.
- Tests SQL canoniques et métier.
- 27 scénarios HTTP authentifiés.
- Bancs clients et Chromium.
- Rollback/rejeu et idempotence.
- Comparaison des 460 tarifs ou de leur état réel actualisé.
- Contrôle des droits serveur.
- Vérification des parcours des groupes, combats, hospitalisation, déplacement et reprise.
- Préservation des correctifs déjà livrés concernant les terrains, banques, commerces, inventaire, presse et transports.

Examine GitHub Actions directement si tes accès le permettent. Le `Forbidden` de Codex n'est pas une preuve d'échec des workflows, mais leurs résultats doivent être vérifiés avant fusion.

Ne désactive aucun test pour rendre une livraison acceptable.

## 7. FUSION ET DÉPLOIEMENT

Quand le candidat est conforme :

1. Prépare une branche d'intégration unique à partir du dernier `main`.
2. Évite de fusionner plusieurs fois les mêmes changements.
3. Ouvre ou actualise la PR d'intégration.
4. Vérifie son diff, ses contrôles et l'absence de conflits.
5. Fusionne le lot validé.
6. Applique les migrations nécessaires en production dans l'ordre vérifié.
7. Déploie sur Vercel, en privilégiant **un seul déploiement groupé**.
8. Vérifie le commit effectivement servi, le statut READY, les alias de production et les principaux appels serveur.
9. Effectue les contrôles post-déploiement sur les mécanismes concernés, sans faire agir de vrais personnages ni prélever leurs ressources à leur insu.

**Attention :** si l'ordre d'application impose de migrer la base avant la mise en ligne du client, ou l'inverse, établis une séquence compatible et sûre. Une réussite sur le clone n'autorise pas automatiquement une migration en production.

Si une autorisation supplémentaire ou un véritable arbitrage métier devient indispensable, prépare l'opération exacte et explique le point de décision. N'invente pas de décision de Fred.

## 8. CLÔTURE DE LUTHÉCIA

Après la livraison #219, fais un dernier audit différentiel de Luthécia pour repérer les éventuels vestiges bloquants :

- Anciennes fonctions encore appelées.
- Ordres affichés mais inopérants.
- Migrations présentes dans Git mais manquantes en production.
- Décalages entre les droits affichés et les droits serveur.
- Dépendances cachées sur les anciens systèmes de combat, déplacement ou inventaire.

Corrige et livre les défauts bloquants qui relèvent des règles déjà validées.

Les essais des PJ (Fred, Angie, Vince, Jaaj) constituent une recette supplémentaire et **ne doivent pas empêcher de clôturer la partie technique déjà vérifiable**.

Les nouvelles fonctionnalités non nécessaires à cette clôture, notamment le bloc serrure #326 et les extensions futures, sont hors périmètre.

Ne commence pas un nouveau chantier avant d'avoir fermé celui-ci.

## 9. EXIGENCES DE COMPTE RENDU

Ne termine pas ton intervention après une simple analyse ou un commit.

Les seuls motifs d'arrêt sont :

1. **Chantier intégralement terminé, fusionné, migré, déployé et vérifié.**
2. Autorisation ou arbitrage réellement indispensable de Fred.
3. Blocage extérieur incontournable, après avoir épuisé les solutions accessibles et préparé l'action précise permettant de reprendre.

Ton rapport final devra indiquer :

- Les deux contrôles rouges et leur résolution prouvée.
- Le résultat final des tests.
- Les PR et commits effectivement intégrés.
- Les migrations appliquées en production, avec leurs identifiants.
- Le déploiement Vercel et le SHA servi.
- Les vérifications post-déploiement réussies.
- Les éventuelles vérifications qui restent exclusivement aux PJ.
- Tout défaut non résolu, sans le présenter comme terminé.

**Tu es désormais l'intégrateur responsable de la clôture de Luthécia. Enchaîne toutes les opérations réalisables, sans attendre de nouvelle relance.**