## #219 — reprise du socle policier, 29 octobre (EN COURS, NON DÉPLOYÉ)

Main `416f275b` intégré sur `codex/groupes-universels-20261028`. Les contrôles ordinaires utilisent maintenant le détecteur commun, le dossier `police_interceptions` et les portes/reçus de reddition et fuite existants. DUP/PER après détection effective, saisie/convocation ou écrou +1 jour dans une transaction. Aucun jet ni sanction ordinaire à l’écran ; inventaire versionné relu, sans adopter l’inventaire ancien du reçu. `procederArrestation` attend confirmation/relecture de la détention et n’anticipe plus argent, poste ou téléportation ; réponses tardives ignorées. Immunité locale existante conservée, aucun pouvoir ajouté aux agents privés.

Deux migrations supplémentaires préparées : `20261029220000`, puis `20261029220100`, avec le client correspondant ; refus d’installation partielle testé. **289/289 SQL jetables**, dont 16 nouveaux cas, et 18 cas clients ciblés (10 arrestation, 8 contrôle). Contrôleur complet **126/127** : seul Workflow échoue, car main contient deux fichiers `20261029190000` (locations et rumeurs). Contrôles globaux **4/12 sur branche et main 416f275b**, donc huit rouges conservés ; Authority 120 RPC absentes du baseline contre 109 sur main, les mêmes onze préparations propres à #219.

Le banc judiciaire vérifie désormais la liste exacte des identités canoniques actives du commissariat, pas une taille figée de trois : le banc d’embauche peut avoir ajouté un policier et un autre combat en avoir retiré un. Aucun mort réactivé pour le décor. Les tests concurrents committent uniquement des données fictives dans PostgreSQL jetable ; aucune authentification Supabase réelle. Les premières erreurs de test ont été corrigées (dépendance de contexte du banc client, hypothèse de taille fixe, décor encore engagé dans une bataille).

Toujours NON PRÊTE : combat des squatteurs non ouvert/configuré. Les sources ne donnent ni effectif ni profils distincts validés ; aucune valeur inventée. Réponse positive au contrat invalide refusée et trace de contrôle affichée seulement après confirmation. Question de design en cours : ce qui décide neutralisation/décès, le moteur militaire tuant à 0 PA et le policier neutralisant. Corps vivant de `crime_neutraliser` demandé au prévol mais inaccessible ici (seule sa définition Git est lisible). Catalogue vivant, comparaison avec #213/#235, revue et livraison groupée restent à ChatGPT ; aucune donnée réelle, fusion, migration ou production touchée. Ne pas renuméroter aveuglément les migrations de main sans lire leur registre.

## Référence finale #219 — 29 octobre, NON PRÊTE

Branche `codex/groupes-universels-20261028`, main `cbae23ff` intégré, code testé `2bae9802`. **273/273 SQL répétés ; 124/124 bancs clients ; contres neuf et deux échecs attendus ; globaux 5/12 contre 5/12 sur main.** Dix-sept migrations préparées, aucune appliquée. Preuves : `outils/audits/preuves-groupes-219-main-cbae-20261029/`. Rapport faisant foi : `outils/audits/FINALISATION-GROUPES-UNIVERSELS-20261028.md`.

Batailles mixtes/reçus/verrous testés localement ; contrat textuel squatteurs de Claude repris depuis main. Ouverture/profils persistants, différenciation de résistance, neutralisation civile et anciens contrôles policiers ordinaires restent incomplets. Ne pas promouvoir #219. Aucun joueur réel, fusion, déploiement ou migration de production ; CI distante non attestée. ChatGPT conserve prévol/intégration #230, immobilier à Claude. **Les états précédents ci-dessous sont historiques.**


### Priorité P0 explicite — affichage navigateur / vérité serveur (29/10)

**Responsable unique : ChatGPT (coordination avec Codex pour socle inventaire/groupes).** La clôture Luthécia exige : (1) cartographier les valeurs calculées, sauvegardées ou affichées localement sans confirmation serveur ; (2) supprimer/adapter les anciennes écritures qui écrasent positions, inventaire, soldes, santé, moral, sanctions et état du PJ ; (3) sécuriser chargement, autosauvegarde, perte de réponse, reconnexion, changement de version après déploiement ; (4) tester égalité état UI / état canonique après action, refresh, reconnexion et deux sessions, sans mutation d'un PJ réel lors de l'audit. **Ne pas confondre suppression d'une double autorité avec simple actualisation cosmétique.** Les six fermetures liées à #213 restent subordonnées à prévol et validation. Toute régression de cette catégorie bloque la promotion en production.

## 29 octobre — rapprochement du main cbae23ff et transport MCP

Main `cbae23ff` (#233, #234, #240, #241) intégré sans réécrire les fonctions de Claude. Son contrat de squatteurs est déjà textuel (issue réelle) : l'adaptateur utilise désormais ce corps, pas l'ancienne version à score. Une collision de version avec la migration locative `20261029190000` et la limite MCP ont été corrigées : **nouveaux compléments = `20261029210000`, `20261029210100`, `20261029211000`, `20261029212000`**, tous sous 12 500 caractères ; les anciens préfixes 190000/191000/192000 de Codex n'ont jamais été appliqués et ne doivent plus être utilisés. Les treize fichiers précédents restent préparés ; total de cette reprise : dix-sept. Les appels de bataille sont refusés pendant l'installation partielle et ne se réactivent qu'avec le contrat à reçus. Rechargement du schéma PostgREST demandé après installation des surcharges.

Le décor de bataille initialise maintenant explicitement les PA de ses PNJ fictifs : les dégâts de la confrontation concurrente du banc parent ne constituent pas les conditions initiales de cette autre bataille. Ni métier ni identité ni statut ne sont renommés/rétablis. Première validation après rapprochement : **273/273 SQL et 124/124 bancs clients** ; validation et preuves finales en cours d'archivage. Les anciens dossiers de preuves sont historiques, pas une attestation du nouveau SHA.

## 29 octobre — état final sauvegardé, #219 NON PRÊTE

Depuis `4ee72dea` : `b9b5ad45` (batailles mixtes), `ae63e92e` (commandes et client), `ac30c2ac` (verrous avant coups), puis adaptateur squatteurs/validation. **272/272 SQL répétés**, **122/122 bancs clients**, contres **9** et **2** échecs attendus sur le même corpus. Globaux **5/12**, identiques en catégories au main `4648840e` testé séparément. Huit signatures d'adaptateurs propres à la branche corrigées ; 11 RPC supplémentaires sans baseline restent signalées car leurs migrations ne sont pas appliquées/extraites. Aucun contrôle affaibli.

Le dernier état fait foi dans `outils/audits/FINALISATION-GROUPES-UNIVERSELS-20261028.md` et `preuves-groupes-219-cloture-locale-20261029/`. Seize migrations préparées : les treize initiales, puis `20261029210000`, `20261029211000`, `20261029212000`. La dernière dépend aussi du SQL de Claude #233 (`20261029181000`), dont le corps est épinglé comme fixture, pas fusionné.

**Suite Codex indispensable** : 1. amorçage/persistance et profils distincts des groupes de squatteurs, contexte non létal et corps + survivants ; le contrat d'issue réelle seul ne réalise pas ce combat en jeu ; 2. portage du contrôle policier ordinaire, de `procederArrestation` et du +1 jour de fuite (encore partiellement client) avant toute fermeture ; 3. rapprocher l'ancien `crime_neutraliser` après lecture de son corps vivant (absent des sources disponibles). Ne pas retirer les règles en attendant. Le prévol SQL, la fiche générale #235, la fusion #230 et la production restent à ChatGPT. Aucun joueur réel ni production touchés, aucune nouvelle modification immobilière.

## 29 octobre — verrouillage des combattants avant les coups (#219)

Complément de `20261029210000` : les projections, PJ et PNJ des deux camps sont verrouillés avant de relire/appliquer les PA. Le verrou de graphe seul ne remplace pas ces verrous de lignes face aux autres écrivains serveur. Prévol complété pour examiner aussi le traitement militaire de calendrier vivant. Validation finale répétée : **272/272 SQL**, contres **9/272** et **2/272** échecs attendus, **122/122 bancs clients**. Pas de production.

## 29 octobre — commandes de bataille et reprise réseau (#219, EN COURS)

Après `b9b5ad45`, `20261029211000` fournit reçus et round attendu aux trois portes existantes : engager, poursuivre, décider. Les corps historiques sont privés, les anciens appels sans reçu refusés. Deux commandes concurrentes = un round ; une réponse perdue retrouve son résultat, un round obsolète ne relance aucun coup. Les décisions du chef exigent sa disponibilité/présence ; l'observation/poursuite par un participant évacué reste permise comme avant, sans le faire combattre. Le lecteur exclut les indisponibles et le round clôt leurs engagements avant ses coups.

Client : reçu et round conservés ensemble, doubles clics et anciennes sessions bloqués, relecture propre des PA/position et réponse inventaire versionnée originale après round ; pas de fausse certitude d'échec après perte réseau. Fenêtre d'interception à la charte commune. Cache de chaque JS changé. Déclarations SQL des adaptateurs rendues explicites (DDL réellement exécuté), ce qui élimine les huit nouveaux écarts de signatures d'Authority sans changer son test. Les quatre signatures inconnues restantes existaient sur main.

Validation en fin de lot : 272 scénarios SQL (265 socle + 7 contrats squatteurs), 122 bancs clients dont 13 cas du client de bataille. Recette Supabase non effectuée. Aucun DDL, fusion ni déploiement en production. Le raccordement des squatteurs n'est pas complet : seul son contrat de sortie est testé ; profils persistants/résistances distinctes et ouvrant manquent. Les contrôles policiers ordinaires restent un autre ancien chemin actif à porter (jets/conséquences encore partiellement client), pas le circuit judiciaire moderne déjà raccordé.

## 29 octobre — bataille militaire mixte : identités, effets et repli (#219, EN COURS)

Préparation `20261029210000`, après les treize migrations déjà décrites. Référence `pnj_id` dans les engagements existants, sans faux métier/compagnie pour policiers/douaniers/employés. Le recrutement métier reste la porte de guerre ; il inclut le groupe canonique présent, sans modifier employeur/mandat. Même passe de coups, armes des possessions, défenses métier ; compétences militaires absentes = même zéro non entraîné que les PJ sans formation. Gilet PNJ factorisé depuis le corps existant. PA/décès au socle, historique et possessions via `pnj_mourir`. Chef neutralisé séparé avant évacuation, autres PJ non téléportés. Repli par l'acte existant, garde d'indisponibilité avant mouvement de tous, verrous communs et projections mixtes.

**253/253 SQL jetables** : les 243 acquis, recrutements réels quatre métiers et quatre PJ, round authentifié/rapports, bornes terminales par helpers privés, non-résurrection après miroirs, repli/refus atomique et chef seul évacué. Preuves `preuves-groupes-219-bataille-mixte-20261029/`. Aucun joueur réel, aucune production.

Suite : commandes/reçus de rounds et interface, anciens circuits actifs, contre-épreuves et comparaison des contrôles avec main. PR233 relue par Git (`94ce5fb5`), pas importée. Incompatibilité explicitée : son contrat exige un score final 0–100 alors que les rounds donnent une issue et des jets par coup ; arbitrage demandé sans bloquer les autres corrections. Les valeurs distinctes de résistance des squatteurs ne sont toujours pas définies dans les références (point déjà isolé par Fred).

## 29 octobre — ordres d'effectifs police/douane raccordés (#219)

`20261029131000` remplace les quatre recrutements et le licenciement douanier par un ordre transactionnel : mandat officiel, coût déclaré, création/retrait et miroir commun, reçu anti-rejeu. Le navigateur n'écrit plus ces listes et relit ses propres PA ; cache JS monté. Les quatre douaniers initiaux restent la règle existante, initialisée côté serveur uniquement en l'absence de tout effectif historique ; un effectif vide n'est jamais reconstitué. Le mandat douanier vient du registre et survit au voyage du titulaire. Ancien document et paiement isolé nommés refusés avant mutation ; garde des écritures brutes, même chemin falsifié. Un PNJ détaché déjà figé dans une interception ne peut être licencié.

**243/243 SQL natifs**, dont deux connexions concurrentes pour un seul recrutement/paiement, panne aval avec rollback, licenciement/rejeu et dotation vide préservée ; **118/118 bancs clients**, dont 11 cas réseau propres aux effectifs. Contre-épreuves : oubli des forces, du groupe recherché et réouverture du document. Décor fictif local committé pour concurrence, aucune identité Supabase. Aucun DDL de production.

Main `4648840e` (#236–238) intégré à la branche de travail : correctifs PSM et rechargement de position préservés, versions de cache combinées. Après intégration : **243/243 SQL**, **121/121 bancs clients**, contrôles globaux **5/12**. Preuves finales `preuves-groupes-219-integration-20261029/`. Les protections générales de fiche et de version restent à ChatGPT (#235), le recrutement des compagnons non militaires dans une bataille militaire reste ouvert. **NON PRÊT pour activation globale.**

## 29 octobre — suite #219 : miroir militaire et anciennes écritures

Branche `codex/groupes-universels-20261028`, sans fusion/application. `20261029130000` conserve les identités et statuts des soldats morts/détenus au miroir, y compris après le cycle de mort puis retrait du document de compagnie. Garde des écritures de compagnie : ordres existants conservés, remplacement brut authenticated refusé même avec chemin RPC falsifié. **230/230 SQL jetables**, **117/117 bancs clients** ; sans ce correctif **5 des mêmes 230 cas échouent**. Preuves `preuves-groupes-219-miroir-militaire-20261029/`. Globaux toujours **5/12**, détails préservés, aucun résultat ajusté. Ce n'est pas une authentification Supabase.

Restent en développement le remplacement des recrutements/licenciements police/douane avant fermeture de leurs anciens écrivains, puis le recrutement de tous les types de compagnons dans les batailles militaires (les rounds policiers mixtes passent déjà). Prévol vivant à ChatGPT. PR225/235 et immobilier non touchés.

## Arbitrage du 29 octobre 2026 — clôture Luthécia au 1er novembre

**Décision explicite du game designer : Claude reprend les cinq terrains et l'intégralité du parcours immobilier.** Codex cesse les nouveaux changements sur ce périmètre (parcelles, occupation, compromis, notaire, permis, construction, approvisionnement, division, livraison, rénovation), y compris dans ses PR historiques ; il transmet à Claude les branches/PR, commits, migrations et résultats de tests existants. Claude repart du dernier main et incorpore les modifications vérifiées sans écraser les travaux du socle.

**Répartition sans chevauchement :**
- **Claude :** terrains, immobilier, prêts et placements fonctionnels ; revue/correction des défauts bloquants commerce, électronique, premium, presse, PNJ et douanes. Sur sécurité privée, il ne touche qu'au raccordement immobilier après livraison du socle commun.
- **Codex :** inventaire serveur, groupes PJ/PNJ, police/armée, sécurité privée universelle, combats par rounds, atomicité des déplacements, transports et anciennes écritures concurrentes propres à ce socle. Pas de modification immobilière, sauf transmission de correctifs déjà préparés.
- **ChatGPT :** inventaire réel SQL/ACL/RLS des autres écrivains, fiche personnage, orchestration PR #230, migration et fermeture des anciens accès inventaire après vérification, tests combinés, fusion et production. Les **six fermetures associées à #213** doivent être identifiées précisément avant exécution ; ne jamais les inventer ni les appliquer sur une livraison incomplète.

**Cadence de livraison :** une fenêtre de livraison quotidienne en fin de journée pour les lots **prêts et testés**, sans obligation de livrer si garde bloquante ; pas d'accumulation forcée jusqu'à dimanche. Avant chaque livraison, rebase/réconciliation sur main, tests de l'exact SHA, prévol SQL, migrations ordonnées, contrôle Vercel READY et recette. Les modifications communes (`data.js`, `plateau-*.js`, `supabase.js`) sont ciblées et les agents repartent du dernier main publié.

**Critère dimanche :** Luthécia jouable sans défaut bloquant, données des PJ protégées, parcours essentiels vérifiés. Les non-bloquants restent listés explicitement : ne pas les présenter comme terminés. Ne pas repousser un verrou de sécurité qui expose directement argent, inventaire, position ou sanctions si la voie reste exploitable.

---

## #219 — interception collective et taxis raccordés, Codex 29/10, EN COURS

- Après `8848048f`, adaptations privées du détecteur et du round existants, sans JWT substitué. Chef non recherché / compagnon recherché : détection effective, groupes complets, commandement du chef, reddition personnelle, seul le jugement du recherché exécuté. Rébellion du commandeur qui choisit de combattre conservée, pas de peine automatique du compagnon au chef. Reçus lisibles par leur commandeur après séparation, rounds futurs/obsolètes refusés avant coup.
- Même recrutement avant/après détection ; perception du groupe réel et priorité police existantes, sans créer de faux dossier avant le jet ni laisser un groupe se détecter lui-même. Gel des deux compositions dès détection. Même jet/reçu de fuite, puis même navigation commune : tous passent ou aucun, incapacité annule l'ensemble. Une transaction concurrente par round, réponse identique relue sans second coup.
- Taxis Caserne/QHS raccordés à `transport_effectuer` : 9 voyageurs, 1 PA et 1 800 FR au leader, aucune dépense séparée à l'écran. Zones spéciales réelles, sans les introduire dans `villes`. Entrées publiques et sortie vers aperçu utilisent `navigation_interieure`, puis bus retour existant (9 voyageurs, 1 PA / 1 350 FR). Aucune prison ni restriction contournée.
- Client : distingue cible/chef, droits des boutons et peine personnelle ; PA et détention du compte connecté relus avant affichage, pas ceux du compagnon. Anciennes réponses ignorées après changement de personnage/session. Cache des deux JS monté. **224/224 SQL jetables**, **41 tests réseau/interception**, **14 tests intérieurs client**. Contres mêmes 224 cas sur oubli des membres de l'un ou l'autre camp, preuves `preuves-groupes-219-interception-20261029/`. Une rencontre fictive commitée seulement dans PostgreSQL jetable pour deux connexions concurrentes ; aucune donnée réelle.
- **Suite en cours, NON PRÊT** : anciennes écritures d'effectifs à fermer après remplacement de leurs actions utiles, miroirs militaires/statuts, derniers contrôles et recette globale. Prévol vivant/extraction à ChatGPT (#230), aucune tentative Supabase renouvelée. Aucune fusion ni migration appliquée, aucun immobilier ni PR225/235 touché.

## #219 — rounds mixtes et séparation à l'écrou, Codex 29/10, EN COURS

- Après `df3ee78d`, préparation `20261029120000` / `20261029121000`. Même branche/PR219, aucune production. Séparation extraite de la porte PNJ commune puis réutilisée par l'écrou existant ; chef/membre emprisonné quitte son groupe, ses PNJ restent à leur position précédente sans changement d'emploi/propriété. Une panne aval annule détention et séparation.
- Le **même `police_combat_resoudre`** utilise maintenant les deux groupes canoniques ; chaque membre conserve ses PA. Même `combat_coup_resoudre`, mêmes formules et reçus. Soldats : formation/defense militaires existantes ; profils agents du catalogue. Composition figée dans l'interception existante, pas de nouvelle bataille parallèle. Le recherché n'est pas récupéré tant que ses compagnons combattent ; seul son jugement est exécuté après la défaite du groupe. PNJ neutralisés en PA selon le contexte policier, pas de nouveau barème de mort.
- **209/209 SQL jetables** : les 200 acquis, séparation chef/membre, refus/rejeu/rollback et portes privées, deux rounds opposant groupes PJ/policiers/soldats/agents privés, victoire de groupe et défaite avec écrou du seul recherché. Retour au registre pour chaque PA, sans impact sur les soldes/inventaires. Preuves `preuves-groupes-219-rounds-mixtes-20261029/`.
- **Suite en cours, NON PRÊT** : recherché accompagnant un chef innocent et UI collective/reprise, reddition/fuite, concurrence supplémentaire et contres, vieux écrivains d'effectifs, transports spéciaux et contrôles globaux restent à terminer. Aucun arbitrage immobilier ni PR225/235 touché. Prévol vivant à ChatGPT, pas de tentative Supabase renouvelée.

## #219 — sauvegarde finale sélection et contrôles portables, Codex 29/10

- Lot précédent poussé `b40d54d4`. Ordre des verrous du round policier complété : ressources du groupe avant le verrou propre au PJ ; reçu conservé avant la garde d'éligibilité. La concurrence finale cible une vraie prise PNJ, pas seulement le départ PJ déjà verrouillé.
- **200/200 SQL**, **117/117 bancs clients**, contre-épreuves sur les mêmes 200 cas : **8**, **6**, **2** échecs attendus selon la protection retirée. Preuves finales séparées `outils/audits/preuves-groupes-219-selection-finale-20261029/` ; les preuves précédentes ne sont pas réécrites. Identités fictives/authenticated dans PostgreSQL jetable, aucune connexion de joueur réel.
- Les contrôles Référentiels/Fonctions et le générateur associé peuvent maintenant utiliser l'adaptateur Node existant si JavaScriptCore macOS est absent. Aucun seuil, donnée, empreinte, déclaration ou assertion affaibli. Banc d'exécution réelle/calcul/exception ajouté. **Globaux toujours 5/12** : classification/base/catalogue incohérents, Authority (109 RPC sans baseline et autres écarts), miroirs/référentiels (certains autres générateurs restent dépendants de JSC), copie de `tauxHoraireChantierServeur` non déclarée et contrôle d'expulsion ambassadeur à rapprocher, deux fonctions de triggers absentes, reconstruction en échec. Ni immobilier ni ambassades corrigés sous couvert des contrôles.
- Derniers distants relus : main `dc92077f` déjà ancêtre de la branche ; PR230 `b054264f`, complément d'audit ACL, aucune réécriture de son travail ni de PR225. Lecture API GitHub des commentaires toujours Forbidden ; aucun connecteur Supabase accessible pour le prévol vivant.
- **NON PRÊT pour intégration/activation complète.** Le code restant (rounds mixtes à deux groupes, recherché accompagnant/chef innocent, reddition et séparation à l'écrou, anciens écrivains d'effectifs, trajets spéciaux) n'est pas réduit à un défaut d'accès Supabase. Sélection/gardes ne clôturent pas ces circuits. Pas de migration, fusion ou déploiement. ChatGPT conserve #230 et la livraison.

## #219 — sélection et composition sous confrontation, Codex 29/10, EN COURS

- Reprise `ca72fe22`, même branche. Références PR230 relues via Git (`b054264f`, nouvel audit ACL) ; API PR219 Forbidden, aucune nouvelle tentative répétée. Aucun connecteur Supabase exposé, aucune production. Les six workflows antérieurs sont l'information de Fred, pas une nouvelle observation CI de ces commits.
- Quatre migrations préparées `20261029110000` à `20261029110300` : lecteur privé des combattants depuis le groupe serveur (position réelle, HP/PA, prison, hospitalisation, interception et autre bataille), pas de métier inventé ni de caractéristiques militaires de repli. Gardes sur rejoindre/quitter/prendre/déposer/transmettre/radio : pas d'évasion par recomposition pendant une confrontation. Même verrou de graphe avant les ressources ; forces sélectionnées également protégées.
- Recrutement militaire existant corrigé : camp lu dans le service, pays physique contrôlé sur le champ de bataille ; morts/incapables/détenus/interceptés/engagés ailleurs exclus. Le round policier existant réutilise la sélection pour refuser les états incompatibles avant les coups, après relecture d'un reçu existant. Aucun nouveau moteur de combat ni barème.
- **200/200 scénarios PostgreSQL jetable** passent, dont round militaire réel de deux camps dans un même pays, deux rounds police réels et rejeu, composition concurrente sur deux sessions, 173 acquis conservés. CI existante raccordée à la nouvelle chaîne. Contre-épreuves sur les mêmes 200 cas : 7 échecs sans garde de composition, 6 sans correction militaire, 2 sans garde d’état policier. Preuves `outils/audits/preuves-groupes-219-recrutement-20261029/`.
- **NON TERMINÉ** : le lecteur de groupe n'est pas encore un round mixte universel. Toute la résolution à deux groupes, les droits du chef face à une reddition d'un autre PJ, la séparation à l'écrou, les vieux écrivains d'effectifs et les trajets spéciaux restent ouverts. Ne pas activer partiellement. Aucune modification de la PR225 ni de l'immobilier.

## #219 → #230 — transports internationaux, Codex 29/10, EN COURS

- Arbitrage `main` **9e8901b** lu. **Tout l'immobilier est transmis à Claude** : `outils/audits/TRANSMISSION-IMMOBILIER-CLAUDE-20261029.md` (branches distantes/SHAs vérifiés, PR historiques, 38 références SQL, tests et limites). Aucun nouveau code immobilier. Codex conserve inventaire/socles groupes, déplacements, transports, police/armée/sécurité et combats ; ChatGPT orchestre #230, prévol réel, fermetures identifiées et livraisons. Pas de nouvelle PR, fusion ou production par ce lot.
- Après `d44665a5`, code testé : contrôles douaniers de chaque PJ/PNJ, mêmes règles de saisie et de quête protégée, convocations des PJ uniquement (Fred), pas de responsabilité transférée au leader. Un accessoire de soldat d'origine historique `blob_accessoires` est saisi selon l'axe socle déjà autoritaire, sans réapparition au miroir ; un axe encore hors socle reste refusé, pas supprimé aveuglément.
- Avion/bateau raccordés à **transport_effectuer**, mêmes verrous/composition, payer_ordre et reçus : neuf voyageurs coûtent 2 700 FR/2 PA en avion, 900 FR/5 PA en bateau, payés au seul leader. Vol individuel et train conservés. Attestation serveur par PJ invalidée à la sortie ; aucune autorité de `state.douanePassee`. Corruption garde ses coûts/jets/détection, reçu stable et dispense personnelle ; ancien appel sans reçu refusé avant paiement, client moderne raccordé. Inventaire après trajet relu via sa porte existante, réponse originale adoptée.
- L'écrou existant pose désormais la cellule côté serveur, QHS compris ; aucune prison parallèle. Ancienne porte d'auto-incarcération bornée à la ville réelle et durée positive, sans transport libre via une peine nulle. Découverte/jugement/détention/position testés avec vrais corps historiques, sans justice simulée dans ces nouveaux cas. Les anciennes fixtures d'éligibilité restent explicitement signalées dans les tests antérieurs.
- **167/167 scénarios PostgreSQL jetable** (148 acquis + 19 nouveaux), **115/115 bancs client**, **105/105 pilote**, **12/12 douanes client**, **8/8 transport client**. Contres sur les mêmes 167 cas : 1 rouge si le passage du chef couvre autrui ; 3 rouges sans les gardes/positions carcérales nouvelles. SQL/YAML/JS conformes. Globaux **5/12**, mêmes sept familles rouges ; Authority **109** RPC absentes du baseline, dont nouveaux appels préparés mais non installés. Aucune référence modifiée.
- Source historique de `justice_executer_condamnation_soi` retrouvée à `bfae7cf0`, source police de #46 à `5c3a7743` ; **pas des relevés vivants récents**. Adaptateurs privés gardés par prévol des corps, identités publiques/ACL préservées. Dépendance #213 à rapprocher avant l'extraction du corps de confiscation ; ne pas écraser sa nouvelle version. Prévol élargi aux ACL/RLS/triggers/mandats et versions. Aucun verrou final d'inventaire ajouté ni six fermetures inventées.
- **Chantier global NON TERMINÉ.** Restent recrutement/rounds mixtes et interception collective complète, tous les anciens écrivains encore utiles et taxis spéciaux. Prévol vivant et recette réelle non exécutés ici. ChatGPT #230 confirme un miroir policier remettant statut actif : traiter ce défaut de socle au prochain lot avant activation. Les transports ne sont pas livrés en production ; ne pas appliquer une partie de la chaîne. Preuves immuables : `outils/audits/preuves-groupes-219-international-20261029/`.

## #219 — relais immobilier transmis et miroirs police/douane, Codex 29/10

- Arbitrage main `9e8901b` lu et intégré ; aucun nouveau développement immobilier. Transmission versionnée `outils/audits/TRANSMISSION-IMMOBILIER-CLAUDE-20261029.md` déjà poussée avec branches distantes vérifiées, PR, migrations et limites des tests. ChatGPT garde intégration/livraison #230 ; aucune fusion ni migration ici.
- Préparé : migration `20261029100000_groupes_miroirs_statuts_et_pa.sql`. Un miroir ne réactive plus les morts/détenus. Projection des PA/statuts canoniques, morts retirés de l'affichage sans suppression de leur identité. Import unique des PA historiques valides ; rejeu sans réimport. Le combat policier existant écrit ses dégâts au socle avant sa projection, sous le verrou de groupe commun.
- **173/173 cas PostgreSQL jetable**, vrais corps historiques des RPC police, détection, justice et coups ; deux rounds et rejeu. Contre-épreuve identique sans correctif : **6 échecs/173**. Ce n'est ni une authentification Supabase ni un combat mixte complet. Sources historiques/empreintes archivées dans la fixture, comparaison au vivant obligatoire. CI existante étendue à cette chaîne sans second pipeline.
- Sauvegarde du correctif `1760a1e1`, puis main `dc92077f` intégré uniquement dans la branche de travail : priorités P0 et corrections Jodie/dialogues conservées. **116/116 bancs client** avant ce dernier main ; après intégration, **43/43 épreuves dialogues**, destinations multimodales et catalogue **284 bâtiments** vérifiés. Pas de régression ciblée observée ; pas de recette authentifiée ni de contrôle Vercel revendiqué.
- Globaux **5/12**, sept familles rouges non masquées (classification, baseline, Authority, Referential, fonctions, assemblage, reconstruction). Preuves dans `outils/audits/preuves-groupes-219-miroirs-20261029/`.
- **NON TERMINÉ / NON DÉPLOYABLE** : recrutement sécurisé et anciennes écritures d'effectifs, rounds mixtes, interception collective et taxis spéciaux restent à raccorder. Prévol réel, compatibilité #213/#230 et recette authentifiée restent requis. Aucun solde/objet/donnée de joueur modifié.

## #219 — pays physiques et autorité en voyage, Codex 28/10, EN COURS

- Reprise après `d2682feb`, même branche/PR, main inchangé `c10c1083`. #215 lue par Git : profils de dialogue, pas une porte d'embarquement. API commentaires #219 Forbidden, un seul essai ; aucun connecteur Supabase exposé. Aucun déploiement.
- Préparé et testé : `position_pays` au socle PNJ pour la position détachée, pays effectif du chef pendant le suivi ; jamais changement du pays institutionnel. Dépose/ancre, co-présence et reprises à l'étranger conservées, gardes de navigation lisant le lieu effectif. Trigger interdit un PATCH direct et prévol refuse sa désactivation. Résolveur policier lit le registre existant `postes_attribues`, pas le pays courant du personnage ; prévol refuse les mandats historiques non attestés, aucune attribution automatique.
- **148/148 SQL natifs locaux**, dont les 141 acquis. Contre-épreuves précédant les deux derniers contrôles : 4/146 rouges avec le pays d'origine forcé comme position ; 3/146 avec l'ancien résolveur policier. Preuves dédiées `preuves-groupes-219-pays-20261028/`. Pas une preuve de billet international : le décor de changement de pays est explicite.
- Nouvel arbitrage de Fred consigné : les PNJ ne sont pas convoqués, seuls les PJ le sont ; aucun transfert automatique de responsabilité au payeur. Douanes et billet international à poursuivre puis combats/interceptions. Les corps historiques de `justice_executer_condamnation_soi` et des RPC police de #46 ont été retrouvés dans Git ; ils ne sont pas déclarés identiques au serveur vivant.
- **Toujours NON TERMINÉ, aucune fusion ni migration Supabase.** Le lot ne clôture ni le contrôle douanier ni les combats. Les essais/recherche du prochain lot se poursuivent ; ne pas redémarrer l'inventaire de Claude.

## #219 — transports collectifs : arbitrage raccordé, Codex 28/10, EN COURS

- Même branche `codex/groupes-universels-20261028`, PR #219 ; ce lot remplace explicitement l'attente de tarification du point de sauvegarde `8c2904dc`. Règle de Fred consignée dans `outils/audits/REGLES-GROUPES-UNIVERSELS-20261028.md` : le leader paie tous les PJ/PNJ, coût en PA de l'ordre inchangé.
- Train/bus : quantité calculée exclusivement depuis les participants serveur ; tarif unitaire validé par `payer_ordre` existant avant multiplication interne. Aucun coût reçu du navigateur. Une seule dépense de PA au leader. Passagers sans fonds/PA acceptés si disponibles et habilités. Paiement historique individuel conservé, helpers non accessibles sur le réseau.
- **141/141 scénarios PostgreSQL jetable**, dont neuf voyageurs (2 PJ + 7 PNJ), train 675 FR/2 PA et bus 1 350 FR/1 PA, compte national complémentaire, refus collectif, surcharge du passager, rollback aval des positions/débit/reçu, vrai verrou concurrent puis même reçu sans second débit. Un transport fictif et la sortie historique committés seulement dans pgserver pour les snapshots, autres scénarios annulés. Contre-épreuve du billet unique : cinq échecs attendus, aucun scénario désactivé.
- **114/114 bancs clients**, **8/8 transport ciblé**, **105/105 pilote local**. CI existante utilise maintenant la chaîne complète (aucun second job). Prévol vivant étendu aux signatures/ACL et triggers de paiement/transport/terrain. Cache JS remonté. **Globaux 5/12**, Authority 107 RPC absentes du baseline ; aucune empreinte ni référence modifiée. Preuves : `outils/audits/preuves-groupes-219-transports-20261028/`.
- **NON TERMINÉ, NON DÉPLOYABLE.** Pas de fusion ni migration Supabase ni donnée réelle. Restent douanes/avion/bateau et taxis spéciaux, tous les écrivains de position, recrutement/rounds universels et interception/prison collective. Ne pas activer la garde générale isolément ; le nouveau transport refuse les parcours douaniers encore non raccordés. Aucun raccordement partiel déclaré opérationnel en production.

## Groupes universels — continuité transports et accès, Codex 28/10, EN COURS

- Branche #219 conservée après `c5ce1c78`, main vérifié par fetch. Aucune fusion, application Supabase ou donnée réelle. Ne pas prendre ce point de sauvegarde pour un compte rendu de clôture.
- Code préparé : accès d'ambassade factorisé dans une porte interne privée prenant le nom, ancien contrôle audience/asile intégral réutilisé, porte publique gardant son identité et ses ACL. Prévol de corps strict. Navigation vérifie chacun des PJ, sans JWT remplacé ; rendu sans seconde demande d'audience. Lots dynamiques lus directement via `terrain_etat_lire`/subdivisions, pas copiés dans un catalogue ; frontières et identités ambiguës refusées, verrou partagé du terrain avant personnages.
- Train/bus PJ préparés : même `payer_ordre` factorisé uniquement pour sa garde publique, encaissement réel et mouvement dans une transaction, reçu technique idempotent. Tarifs et villes extraits par les générateurs existants pour le banc ; aucun seed/baseline modifié. Client utilise le reçu puis relit la fiche et les comptes, pas des soldes historiques de reçu. Aucun solde d'un autre voyageur divulgué.
- **131 scénarios SQL locaux passent**, dont les 112 acquis ; **8 tests client transport passent**. Contrôleur client complet lancé. Suite à poursuivre : contre-épreuves, concurrence, autres raccordements et recette locale globale.
- **Arbitrage véritable demandé, sans arrêter les autres travaux :** les sources facturent le PJ qui clique mais ne fixent pas le tarif/PA/payeur des PNJ transportés. La consigne interdit d'inventer une gratuité commune ; `transport_effectuer` refuse donc les PNJ sans aucun débit (`tarification_pnj_a_preciser`) en attente de la réponse. Aucun tarif ou débit PNJ inventé. Deux PJ peuvent chacun payer leur billet existant. Avion/bateau restent fermés tant que les contrôles douaniers ne sont pas attestés côté serveur ; ne pas activer la garde générale de positions.
- Toujours à coder : douanes/transport international, recrutement et rounds universels, interceptions du groupe entier et prison. Les 131 cas ne constituent pas une clôture. Inventaire, ambassades/BNE de Claude non réécrits : seulement une factorisation ciblée d'accès dans une nouvelle migration.

## Groupes universels — intérieurs et preuves de rounds existants, Codex 28/10, EN COURS

- Branche `codex/groupes-universels-20261028`, PR #219. Nouveau lot sauvegardé après `04efd8e5`, qui suivait `31218e65`. **Toujours NON TERMINÉ / NON DÉPLOYABLE. Aucun joueur réel, aucune migration Supabase, aucune fusion.**
- Intérieurs raccordés à la même composition/verrous que la rue : catalogue de 284 bâtiments généré depuis les déclarations, deux PJ + quatre soldats + trois policiers jusqu'à la sortie ; mêmes gardes prison/interception/combat/hospitalisation. Un soldat prêté engagé dans une bataille bloque aussi le mouvement. Adhésions de loge et visites de clinique contrôlées pour chacun, rencontre existante avec le portier conservée pour le demandeur refusé seulement. Anciens caches d'accès ne peuvent invalider le rendu du verdict serveur confirmé.
- Garde de la table canonique contre les positions issues des PATCH généraux, sans réécrire les autres champs. Payload, file et déchargement omettent les lieux après capacité serveur ; création initiale conservée. Neutralisation d'une vieille sauvegarde via vue testée sous authenticated ; contrôle de trigger actif au rejeu. **Les autres écrivains RPC et les transports ne sont pas clos**, ne pas activer ce garde seul.
- Lecteur privé `groupe_participants_interne` : clés PJ/PNJ non ambiguës, sans filtre métier ; réutilisé dans la navigation. Il ne constitue pas à lui seul un recrutement de combat.
- **112/112 scénarios SQL**, dont les 86 précédents et de vrais rounds complets du moteur militaire : deux PJ ; puis un PJ et quatre vrais soldats contre un PJ, avec rapports/PA persistés. ACL réelles des helpers copiées du baseline, porte authenticated ; aucun coup simulé pour ces rounds. Ce ne sont PAS les rounds universels policiers/douaniers ni la prison collective. **113/113 bancs clients**, complétés ensuite par **13/13 ciblés intérieurs/portier** ; **105/105 pilote local**. Contre-épreuve : **23/109 rouges**, contrats nouveaux absents compris. Globaux **5/12**, Workflow vert, Authority **106** RPC absentes du baseline et mêmes autres familles d'écarts ; aucun vérificateur ou baseline retouché.
- Blocages de code : embarquement (autorisation encore locale `douanePassee`), accès d'ambassade pour chaque identité (porte publique centrée sur l'appelant), locaux dynamiques ; transports et tous les auteurs de position ; recrutement/rounds universels, identité complète des forces et du groupe recherché, fuite/reddition/prison. Ne pas annoncer la clôture en les réduisant à un accès Supabase.
- Accès : une lecture des commentaires #219 tentée, Forbidden ; aucun connecteur Supabase exposé. Fetch final de main : `c10c10832b5bf6a7ee90895bc4160e2591782190`, déjà intégré. Pas de travail inventaire, finances, ambassades ou BNE importé/modifié. Les bureaux d'ambassade restent bloqués, pas ouverts par un cache.
- Preuves : `outils/audits/preuves-groupes-219-interieurs-20261028/`. Recensement statique limité : `POSITIONS-GROUPES-219-20261028.json` ; ne pas le prendre pour un inventaire exhaustif des fonctions vivantes. Rapport de #219 actualisé, CI existante étendue sans pipeline supplémentaire.

## Groupes universels — reprise entrées et protection des positions, Codex 28/10, EN COURS

- Branche #219 conservée à partir de `31218e65` ; fetch main inchangé `c10c1083`. **Aucune fusion, migration appliquée ou production.**
- Préparation du catalogue des pièces dérivé de WORLD/BUILDINGS (284 bâtiments, génération contrôlable), validation intérieure, composition et verrous uniques pour rue et intérieur. L'ancien moteur de rue reste la seule résolution des itinéraires ; garde commune prison/interception/combat/hospitalisation.
- **101/101 SQL locaux**, dont les 86 acquis : deux PJ et sept PNJ font rue → hôtel → bar → restaurant → accueil → sortie → rue. Refus d'accès sans raccord, pièce inconnue, groupe dispersé, combat/incapacité et surcharge ; surcharge n'interdit pas de changer de pièce. Sauvegarde de position ancienne via une vue au rôle authenticated neutralisée par le garde de la table canonique, sans réécrire la fiche.
- Client préparé derrière capacité annoncée par `groupe_pj_lire` : confirmation serveur avant rendu, double clic, garde de session, réponse perdue réconciliée par lecture. Payload normal/file/fermeture omet les positions après activation. Banc ciblé en cours et contrôleur complet lancé.
- **Non déployable :** les portes spéciales (loge, embarquement, bureaux d'ambassades, chambres de clinique) restent explicitement refusées, pas ouvertes sur simple cache ; leurs validations existantes par membre restent à factoriser. Transports et autres écrivains RPC de position à vérifier avant activation du garde. Le catalogue ne remplace pas encore tous les locaux dynamiques. Combats mixtes/interception complète restent à réaliser ; ne pas présenter ce lot comme clôture.

## Groupes universels — lot unités distantes et preuves finales locales, 28/10, Codex

- Même branche `codex/groupes-universels-20261028`, PR #219. Sauvegarde précédente `00b537f2`, après `e80efd80`. **CHANTIER NON TERMINÉ, aucune fusion ni migration ni livraison.**
- Consultation des unités sous autorité depuis le menu commun : soldats/douaniers/policiers/employés, pas de bourse ou inventaire reconstitué. Reprise d'une ancre avec ses suiveurs ; commandes, prêts, reprises employés et adhésions PJ transmettent la garde de contexte au transport existant. Lectures anciennes et doubles clics protégés. Deux anciens sélecteurs de placement sans références retirés, adaptateurs conservés.
- Défaut confirmé et corrigé : projection institutionnelle conservant une rue ancienne alors que le chef se trouve dans une pièce. La rue projetée est désormais nulle à l'intérieur. Contre-épreuve avant correction archivée.
- Le moteur privé de rue est maintenant déclaré explicitement (même corps et mêmes empreintes), après prévol strict. Le contrôleur Authority peut le reconnaître sans exception ajoutée. Son refus pour signature inconnue disparaît ; les quatre autres restent. Aucun baseline/vérificateur modifié.
- **86/86 SQL natifs**, incluant les 77 précédents. Vrai détecteur historique et vrai calcul `combat_coup_resoudre` retrouvés dans Git, mêmes formules militaires, sans faux détecteur/coup. L'éligibilité judiciaire reste une table de fixture ; pas une prison réelle ni un round universel complet. Un seul déplacement fictif committé sur PostgreSQL éphémère pour le snapshot concurrent.
- **40/40 groupe client ; 12/12 police ; 21/21 navigation ; 112/112 bancs clients ; 105/105 pilote local ; audit #216 20/20 avec justice/coups simulés**. Contre-épreuves rue : 12/77 rouges ; force publique : 10/59 rouges, comprenant absences de contrats nouveaux. **Globaux 5/12, Workflow vert**, Authority 105 RPC absentes du baseline, quatre signatures antérieures et une garde d'identité de bail ; Referential/fonctions non mesurables sans JavaScriptCore. Les autres rouges restent consignés.
- Main relu par fetch : `c10c10832b5bf6a7ee90895bc4160e2591782190`, déjà ancêtre de la branche. Aucun fichier inventaire/fiche/ambassades/BNE modifié par ces lots. Aucun outil Supabase exposé, API GitHub lecture PR refusée, push Git disponible.
- **À continuer réellement :** entrées/pièces collectives, sauvegardes/anciens écrivains de position, recrutement et rounds PJ/PNJ mixtes, unité complète du recherché et des forces dans l'interception puis prison par le moteur existant. Le détecteur historique ne sait pas encore recruter tous les groupes canoniques ni résoudre les identités de policiers d'origines différentes ; ne pas l'activer partiellement. Prévol vivant et recette isolée authentifiée ensuite. Détails A–F dans le rapport ; preuves immuables de cette reprise dans `outils/audits/preuves-groupes-219-suite-20261028/`.

## Groupes universels — rue commune récupérée et testée, 28/10, Codex

- Même branche `codex/groupes-universels-20261028`, PR #219, après `e80efd80`. **Non terminé, aucune fusion/application/déploiement.**
- Corps Git de `rue_position_enregistrer` retrouvé au commit `5e23f714` : son `pg_get_functiondef` donne exactement le MD5 communiqué `5e819694359c4bf2f11470c7f9f95ad8`. Source et provenance archivées dans `outils/bancs/fixtures/groupes-corps-git-20261028.json`. Les autres sources historiques (détecteur/coup/lecture) ne sont pas prétendues des relevés vivants récents.
- Migration préparée `20261028183000_groupes_rue_transaction_commune.sql` : le moteur de rue existant devient privé et paramétrable, gardes communes conservées, validation de chaque PJ avant mutation, positions atomiques du chef et des membres, projections PNJ existantes, verrou du graphe et ordre de verrous commun. Prison, interception et hospitalisation bloquent tout le groupe ; actualisation de `updated_at`. Rejeu sans nouvelle mutation ; dérive de définition publique ou privée refusée. Aucune porte d'identité arbitraire exposée.
- **77/77 cas PostgreSQL jetable**, incluant les 59 précédents, sortie/marche réelle de deux PJ et sept PNJ, refus et rollback aval, concurrence réellement observée. Un acte fictif committé dans le serveur éphémère pour le snapshot concurrent, jamais Supabase. **21/21 navigation cliente**, contexte transmis au transport pendant le renouvellement d'authentification. CI existante étendue, cache remonté.
- **Restent de vrais développements :** entrées et pièces pour groupes, anciens écrivains de position/sauvegardes périmées, recrutement et rounds mixtes, interception du groupe recherché. Le déplacement rue ne démontre pas ces parcours. Pas de recette authentifiée. Aucun joueur réel, fiche financière ou inventaire modifié.

## Nouvelle reprise #219 — 28/10/2026, Codex, EN COURS

- Branche `codex/groupes-universels-20261028`, départ `6a72c964`, main `c10c1083` contrôlé. Une seule tentative REST de lecture des nouveaux commentaires : Forbidden. Aucun moteur de rue ou détecteur reconstruit ; leurs corps restent indispensables pour l'étape PJ/interception.
- **Nouveau lot codé, non appliqué** : police/douanes raccordées aux portes PNJ communes avec position autoritaire au socle et projection des anciennes listes, miroirs qui ne réimportent plus la position lorsque l'axe est au socle. Toutes les autres données et les PA du registre sont conservés. Projection conditionnelle pour arrêter la récursion, format JSON objet/chaîne conservé. Verrous services puis compagnies puis PJ/PNJ ; résolveurs territoriaux existants inchangés. Activation interdépendante, ne rien appliquer isolément.
- Anciennes affectations policières remplacées par reprise/dépose sur position réelle/radio via les portes communes ; aucun lieu fixé dans le navigateur ni réécriture de blob de position. Lecture commune des unités sous autorité ou commandement, sans inventaire ni annuaire d'autrui. Le transport existant reçoit la garde de contexte avant envoi.
- **59 cas PostgreSQL réussis** (49 conservés puis 10 nouveaux) : quatre vrais soldats + trois vrais policiers prêtés au commissaire, positions dérivées après un déplacement fictif du chef dans la base locale (PAS la vraie RPC de déplacement), dépose/reprise selon autorité ; douaniers réels, radio, ancien blob, autorité multi-commissariat, confidentialité et projections. **12 contrats clients policiers passent**. Tests au rôle authenticated sur identités fictives ; aucune connexion Supabase ni donnée réelle. CI existante passe par le banc étendu sans doublonner l'exécution.
- Suite active : régressions, contre-épreuves et raccordements indépendants suivants. Déplacement collectif PJ et rounds/interception du groupe entier restent inachevés. Ne pas fusionner #219 ni déployer ; aucun coût, inventaire, fiche, ambassade/BNE ou règle douanière métier modifié.

## Reprise PR #219 — 28/10/2026, Codex, EN COURS

- Branche conservée **`codex/groupes-universels-20261028`**, départ `cb3957fe`. Nouveaux commits poussés `e46ea788`, `d5c7c327`, `c1b18f0a`, merge du main `c10c1083` en `3c464794`, puis garde et preuves finales. PR #219 existante, aucune nouvelle PR tentée. Transport REST, création PJ, sorties et notes concurrentes de ChatGPT conservés ; cache remonté.
- **Codé et testé localement, non déployé** : vrais soldats dans les portes communes prise/dépose/prêt/radio, résolveur de section et miroir/projecteur militaires existants conservés. Compagnie verrouillée avant PJ/PNJ (deux connexions le vérifient). Trois anciens ordres par nombre deviennent des adaptateurs des mêmes portes. Restriction individuelle soldat levée avec le raccordement, autres familles inchangées. Reprise d'ancre partielle refusée proprement, unité complète reprise ; panne de projection annule l'acte.
- Interface : reprise/dépose/prêt/radio selon capacité et autorité serveur ; commandes et lectures PNJ protégées contre doubles clics, ancien personnage/session et réponse perdue. Porte de combat militaire archivée : référence à l'alias inexistant `c` corrigée vers le pays `m.pays`, sans autre règle ni nouveau round. Garde de migration refuse de remplacer un corps militaire non examiné.
- **Résultats : 49/49 cas PostgreSQL** (35 antérieurs, 9 militaires, 2 diagnostics policiers, 2 contrôles de porte combat, 1 refus de dérive), **27/27 clients ciblés**, **111/111 bancs clients après main**, **105/105 pilote**, **35/35 interception**. #216 : **19/19** et variante concurrence **20/20** ; cette variante commet un acte fictif seulement dans PostgreSQL éphémère. Les autres actions de scénario sont annulées. Contre-épreuve militaire finale : **10 cas rouges /49** avant raccordement, dont contrats absents et défaut d'alias — pas 10 bugs historiques. Aucun test neutralisé. CI existante raccordée au banc étendu sans double invocation.
- **Toujours NON TERMINÉ / NON DÉPLOYÉ.** Pas de mouvement collectif PJ ni de combat mixte/interception de tout le groupe livré. Quatre soldats peuvent être prêtés au vrai poste commissaire dans le décor ; le scénario simultané avec trois policiers reste bloqué. Les vrais miroirs/structures policiers reproduisent la contradiction du suivi, et les frontières entre commissariats sont vérifiées. Pas d'ouverture isolée d'axe policier ; douanes #215 non réécrites. Aucun nouveau besoin de game design identifié.
- **Accès :** GraphQL puis endpoint REST des commentaires #219 refusés. Aucun outil Supabase exposé. Le MD5 vivant de rue communiqué par Fred n'est pas son corps ; ancienne enveloppe préparée retrouvée dans un vieux checkout, pas importée comme moteur réel. Opération technique requise pour l'agent ayant le connecteur : exporter les résultats complets de `PREFLIGHT-GROUPES-UNIVERSELS-20261028.sql` et du prévol #216 sur cette branche. Pas de SQL ni de secret demandé à Fred. Ne pas appliquer de migration partielle.
- **Globaux : 5/12**, sept rouges inchangés, Authority **103** RPC au baseline, aucune référence modifiée. JavaScriptCore manque aux deux comparaisons globales concernées ; elles ne sont pas déclarées réussies. Rapport mis à jour : `outils/audits/FINALISATION-GROUPES-UNIVERSELS-20261028.md`, section reprise #219 ; preuves dédiées. Aucune fusion ni migration Supabase, aucun déploiement production engagé ; aucune donnée réelle, inventaire, finance, authentification, ambassade ou BNE modifié par ces lots.

## Groupes universels EN COURS — Codex, 28/10/2026

- Branche isolée **`codex/groupes-universels-20261028`**, issue de #217 `c85d36d5`, conserve #216 et main `3a9b0c5d` (horaire été/hiver). Poussés : `e0e03084`, `84e2dad7`, `b404cf38`, puis preuves/finalisation. Ne pas fusionner #212 ni appliquer de migration isolément.
- Codé/testé : adhésion volontaire persistée, départ, hydratation, protection des réponses tardives/doubles clics ; prêts, prises/déposes atomiques via portes PNJ existantes, position rue ; rappel radio de l'unité complète avec autorité/équipements/ville et gardes ; projection serveur de la présence employée ; unités privées liées au chef réel, pas à la seule co-présence. Cache JS remonté. RPC laissées littérales pour le contrôleur d'autorité.
- Validation finale : **35/35 scénarios PostgreSQL annulés**, identité JWT de fixture, contraintes et trigger communs actifs ; **22/22 clients** ; **108/108 bancs clients complets**, **105/105 pilote local**, **35/35 interception** ; #216 **19/19**, variante snapshot **20/20** (un acte fictif committé dans PostgreSQL jetable uniquement). Contre-épreuves : **18/35 rouges sur #217** (incluent les nouveaux contrats, pas 18 bugs), **8/19 rouges sur #212**. Grammaire des neuf SQL, YAML et 23 API vérifiés. CI existante raccordée au nouveau banc.
- **Globaux : 5/12**, même liste de sept rouges sur main. Authority passe de 99 à **103 écarts RPC** (les quatre fonctions de groupe préparées, absentes du baseline) ; autres écarts inchangés. Referential/fonctions non mesurés faute de JavaScriptCore. Aucun baseline ni vérificateur modifié ; preuves et rapport : `outils/audits/FINALISATION-GROUPES-UNIVERSELS-20261028.md`.
- **NON TERMINÉ / NON DÉPLOYÉ.** Restent le déplacement collectif PJ et la protection de toutes les sauvegardes de position, les projections police/douanes, le raccordement des soldats et du combat collectif au groupe universel, le groupe du recherché dans l'interception, puis la recette authentifiée. Ces raccordements sont encore du code à terminer, pas seulement un accès à ouvrir. Aucun groupe militaire/PJ réel testé. Le prévol complet est préparé dans `outils/bancs/PREFLIGHT-GROUPES-UNIVERSELS-20261028.sql`. Les empreintes de ChatGPT ne remplacent pas les corps vivants manquants.
- Catalogue Supabase et API GitHub indisponibles dans cette session ; lecture PR GraphQL refusée. Branche sauvegardée au commit `01acc471` puis complément de preuve de concurrence ; création de PR en brouillon effectivement tentée : **GraphQL Forbidden**, aucune PR créée par Codex ; aucun refus contourné. Aucune fusion, migration Supabase, connexion de joueur ni déploiement. Inventaire, fiches/soldes, ambassades et BNE préservés. Ne pas nettoyer les anciens mécanismes avant le remplacement opérationnel. Aucun nouvel arbitrage de game design demandé.

## En cours

### Groupes universels — progression complémentaire (28/10, ChatGPT)

- **Préparé en code, non appliqué** : `20261028123000_groupe_pj_adhesion_volontaire.sql` (adhésion volontaire PJ persistée, présence identique vérifiée par serveur, sortie et lecture), `20261028123500_pnj_rappel_radio_universel.sql` (rappel d'une unité PNJ via la radio du PJ et d'au moins un membre, autorité sur tous, même ville), `20261028124000_transfert_pnj_autorite_origine.sql` (transfert de PNJ exige l'autorité administrative, pas le commandement seul).
- **Interface** : `plateau-multijoueur.js` lie « Rejoindre » et « Quitter » à la confirmation RPC et ajoute le bouton 📻 sur les employés PNJ détachés dotés d'un identifiant socle ; `supabase.js` expose le rappel radio et la lecture du groupe. Le serveur vérifie les radios, l'autorité, l'état de l'unité et la même ville. Ce bouton ne simule aucun déplacement, mais la validation UI et le serveur n'ont pas encore fait l'objet d'une recette de bout en bout.
- **Important : incomplet** : mouvement synchronisé de plusieurs PJ, groupe PJ+PNJ en combat, interception d'un PJ recherché accompagné, UX de rappel radio des PNJ, persistance/hydratation `state.group`, tests PostgreSQL authentifiés et contrôle des migrations avec vraie exécution. Le seul ajout d'une table d'adhésion ne constitue **pas** un groupe universel complet. Ne pas mettre en production.
- **Vestiges de l'ancienne règle** : ne pas supprimer avant que tous les mécanismes de remplacement soient codés/testés conformément à la demande de Fred. Le flux local `state.group` et la reprise cliente `recupererPnjDansGroupe` restent à remplacer.
- Prévol Supabase confirme `personnages_donnees.name` unique et l'ancre de patch `pnj_transferer`. Aucune donnée PJ modifiée.


### Groupes universels — vérification radio (28/10, ChatGPT)

- Branche `chatgpt/reprise-securite-135-20261028`, dérivée de l'audit corrigé de Codex ; PR #217 de prévol. Ne pas fusionner l'ensemble du #135 sans tests serveur et recette authentifiée.
- Décisions de Fred consignées dans `outils/audits/REGLES-GROUPES-UNIVERSELS-20261028.md` : autorité administrative distincte du commandement, groupes PJ/PNJ, engagement collectif, rappel radio unique déplacement autonome, deux radios nécessaires et **même ville obligatoire**.
- **Code ajouté :** migration `20261028122000_radio_ordres_meme_ville.sql` appliquant la restriction *même ville* dans la RPC existante `militaire_ordre_collectif` pour ses ordres transmis par radio. `plateau-politique.js` annonce explicitement `radio_hors_ville`. Aucun nouveau moteur ni déplacement créé. Banc `banc-radio-ordres-meme-ville-20261028.sql` exécuté en lecture seule sur la production, ancre unique validée.
- Reprise PNJ : migration `20261028122500_reprise_pnj_autorite_administrative.sql` créée, avec banc `banc-reprise-autorite-universelle-20261028.sql` vérifié en lecture seule. Elle sépare l'autorité administrative du simple commandement : un chef ne peut reprendre des PNJ prêtés après les avoir détachés. Non déployée.
- **Reste essentiel :** implémenter le groupe PJ persistant, les prêts inter-administrations, le rappel universel d'un groupe PNJ et son déplacement autorisé, le combat collectif, la prise en compte des groupes lors des interceptions, vérifier les affectations et les radios d'équipement des PNJ hors armée. Le correctif de portée radio est **préparé mais non appliqué** en production.
- Éviter de fusionner indépendamment les PR #212/#216/#217 tant que leur dépendance et leur faisabilité n'ont pas été testées. Aucun joueur réel modifié.


### Audit indépendant sécurité #135 / PR #212 — Codex, 28/10

- **Audit local livré, non déployable.** Code sauvegardé : `ba3d267f`, `2f4b6551`, `b95b29ef` ; contre-épreuves et preuves : `9198e6ec`. Huit échecs techniques sur l'original, distincts de la nouvelle garde de reprise (testée sans imputer un faux défaut au schéma initial). Création d'une PR d'audit en brouillon réellement tentée : GraphQL Forbidden, aucun numéro créé. Branche distante disponible pour relecture ; #212 reste inchangée à `7c91ef1b`, main inchangé à `3efca838` lors de la vérification Git finale. Pas de fusion ni application en production. Les dépendances encore ouvertes sont détaillées dans le rapport A–F.

- Branche **`codex/audit-securite-135-20261028`**, issue du HEAD réel #212 `7c91ef1b`, main `3efca838` (#214) intégré sans conflit. Aucun travail de #213/inventaire importé ou modifié. PR #196 seulement examinée, jamais fusionnée ; aucune migration appliquée, aucun joueur réel utilisé.
- Audit demandé par Fred : ne pas présumer l'architecture de #212 correcte. Premiers défauts serveur reproduits sur ses sources : suppression de policiers non participants dans deux parcours, dépose contournant les gardes communes, ancienne identité de groupe conservée après séparation, lecture concurrente des PA avant verrou. Les six premiers scénarios PostgreSQL corrigés passent ; rôle authenticated + request.path, opérations métier annulées, décor/identité/justice/coups fictifs. Le détecteur vivant n'est PAS reconstruit ni testé, sa définition manque au dépôt et aucun outil Supabase n'est exposé.
- Préparation : colonne `groupe_deploiement_id` retirée du SQL non appliqué ; déploiement limité à un adaptateur de `pnj_quitter_groupe`, liens PNJ existants ; reprise collective valide avant de déplacer puis détache via le même ordre, avec déclencheur réel anti-sous-hiérarchie conservé. Registre policier intégral préservé au combat ; verrou PNJ avant lecture des PA ; relecture de reçu inchangée. Aucun moteur de combat/prison nouveau.
- Client : effectif affiché = unité confirmée par le serveur, pas tous les policiers co-présents ; cache actualisé. 35 tests interception locaux passent. Trois anciens bancs SQL maintenant auto-annulés, Workflow conforme. Préparation scindée en `20261027222500` puis `20261028074753` et `20261028074754`, toutes sous 12 500 caractères. Position/co-présence en rue corrigées dans le socle et JOIN privé compensatoire retiré ; l’identité des agents doit être explicite. Audit, prévol en lecture seule et preuves : `outils/audits/AUDIT-CRITIQUE-SECURITE-GROUPES-135-20261028.md`. Validation finale : 19 scénarios PostgreSQL annulés, variante snapshot 20 avec un seul acte fictif committé dans PostgreSQL éphémère, jamais Supabase ; 8 contre-tests rouges sur l’original (la garde du nouveau format est testée séparément, sans faux défaut imputé au format original). Le défaut du groupe universel PJ et les raccordements policiers restent réellement à développer, pas seulement bloqués par l’accès. Aucun nouveau besoin d’arbitrage identifié. **Ne pas fusionner ni appliquer #212 ou cette branche.**

- **Écritures de l'écran (Claude, 29/10, branche `claude/ecritures-ecran-20261029`)** : migration `20261029200000` préparée, non appliquée et compatible avec l'écran en ligne. Elle garde `prets` et `budgets_municipaux`. Mariage par le serveur (Fred : pas de mariage contre son gré) : `201000` tout de suite, `201100` après déploiement de l'écran. Restent ouverts et signalés : `budgets_clubs` et `organisations.caisse` (Codex), `budgets_nationaux`, `quetes_actives`. Bilan : `outils/bancs/ECRITURES-ECRAN-20261029.md`.

### Centres des trois villes et location par le serveur — Claude 29/10 soir (branche `claude/centres-villes-20261029`)

Mission de Fred : généraliser les raccordements métier à Montrouge et PSM, fermer les vestiges. **Constat** : les centres commercial, artisanal et d'affaires des trois villes utilisent UN gabarit (`BUILDINGS`) ; les villes ne surchargent que nom et images (banc). Les 11 fonctions serveur du commerce (fonds, références, production, vente, sur place, Premium, loyers) n'ont aucune ville en dur.

**Défaut reproduit (toutes villes)** : le bail d'un local à loyer fixe (centres, suites de La Republica, coffre) était écrit par l'écran ; un joueur absent de Montrouge s'est inscrit locataire de la Vitrine Principale à 1 FR/jour, +99 POP/INF, sans premier loyer. **Correctif** (`20261029190000`, PRÊTE, NON APPLIQUÉE — application par ChatGPT, compatible avec l'écran en ligne) : référentiel `locaux_loyers_referentiel` (équivalence avec data.js prouvée par `banc-locaux-loyers.cjs`), porte `local_louer` (lieu réel, local libre, organisation dont on est membre, 1 PA, premier loyer par `prelever_loyer_bail`, reçu), garde immédiate imposant prix et bonus du référentiel aux baux écrits par l'écran (box portuaire compris, 15 FR). Écran : `confirmerLocation` appelle `local_louer` ; rafraîchissement des ordres Premium après chargement des baux généralisé (était réservé au centre commercial de PSM). **Après livraison** : `20261029190100` (l'écran ne crée plus ces baux ; box exclu).
Répétition à blanc : hall refusé ; fonds insuffisants sans PA ni bail ; Montrouge vitrine 800 FR + organisation + reçu ; local occupé ; organisation d'autrui refusée ; PSM bureau prestige 1 000 FR ; open space de Luthécia refusé, poste B accepté ; bail forgé ramené au tarif ; box forgé ramené à 15 FR ; après fermeture, échoppe écrite par l'écran refusée.
**À vérifier en jeu** : louer un local dans chaque centre de Montrouge et de PSM, installer un commerce dans un local commercial ou artisanal, ouvrir l'Option Commerce (décoration) en titulaire, vérifier qu'un autre joueur ne la voit pas.


### Terrains, parcours immobilier, prêts, placements — Claude 29/10 (branche `claude/terrains-immobilier-20261029`)

Mission confiée par Fred le 29/10 (plan ChatGPT « finir Luthécia d'ici dimanche ») : **Claude reprend les terrains et le parcours immobilier** (cédés par Codex), plus prêts et placements. Codex garde le socle universel (déplacements, détection, combats, inventaire #213, groupes #219, sécurité privée).

**Méthode** : parcours rejoués sur la vraie base, au rôle authenticated, en transactions annulées (Arnie, Jean Jaaj ; aucun joueur réel modifié) : achat direct, compromis + prêt + permis, permis et accord tacite, chantiers hangar et commerce premium jour par jour, plan des lots au dernier tiers, réception, location, loyer de nuit, prêts consommation/travaux, placements.

**Fonctionne déjà** : achat direct et acte notarié, compromis avec prêt et permis joints, dépôt de permis (100 FR + 1 PA) et accord tacite, lancement, appels de fonds 35/70/100 %, journées de chantier, plan au dernier tiers, réception, location d'un lot, prêts nationaux, occupation des terrains redessinée à chaque visite, négociation.

**Défauts reproduits et corrigés (migrations APPLIQUÉES, compatibles avec l'écran en ligne)** :
- `20261029094119` : on pouvait **lancer un chantier avec un permis encore en instruction** (terrains 1-3 gardaient `constructionAutorisee` d'anciens essais) → lancement exige un permis `valide`, reliquat remis à faux. **Les lots nés du plan valaient 0 FR et rien ne permettait de fixer leur loyer** → porte `terrain_lot_loyer_fixer` (titulaire des murs, lot libre), un lot sans loyer ne se loue plus (`loyer_non_fixe`). **Toute location à loyer positif échouait** : `prelever_loyer_bail` créditait le propriétaire par la vue `personnages` (refus « personnage_non_possede » quand le locataire signe) → écrit la table.
- `20261029094135` : **rendement des placements dicté par l'écran** (intelligence et ville envoyées → +12 % garantis avec une intelligence forgée) → lues sur la fiche ; ancienne `creer_placement_national` fermée aux joueurs.
- `20261029094215` : **impossible d'avoir deux placements** malgré la règle #86 (index unique resté en base) → index retiré.
- `20261029095142` : **« Accélérer le rendez-vous (corruption) »** : l'écran envoyait la nouvelle date et payait à part → porte `terrain_rdv_notaire_accelerer` (paiement 2 PA + 800 FR, date calculée par le serveur, reçu).

**Écran (branche, non fusionnée)** : « Information sur les locaux » permet au titulaire de fixer le loyer de chaque lot libre ; la liste « Louer un lot » n'affiche que les lots à loyer fixé ; l'accélération du rendez-vous appelle la porte serveur. Caches : `plateau-politique.js`, `plateau-justice-economie.js`, `plateau-pnj.js` → `?v=terrains-20261029`. Banc `banc-etat-terrain.js` mis à jour (43/43). Bancs clients : mêmes 19 échecs d'environnement que main (dépendances npm indisponibles ici), aucun nouveau.

- `20261029122342` : **« Corrompre un fonctionnaire (accélérer) » le permis** : l'écran envoyait le permis entier ; un demandeur pouvait se poser lui-même `statut: valide` ou une instruction d'un jour, sans payer (reproduit) → porte `terrain_permis_corrompre` (2 PA + 800 FR, découverte 25 % tirée par le serveur avec détection pénale commune, durée divisée par deux sur le dossier enregistré). Écran raccordé.

- `20261029122748` : **décision du maire adjoint sur un permis** : l'acte fusionnait le permis entier envoyé par l'écran (palier, demandeur, durées modifiables), l'écran archivait et écrivait le courrier → porte `terrain_permis_decider` (décision + motif seulement ; statut, archive, arrêté remis, courrier et 1 PA dans une transaction). Éprouvé : refus à un non-adjoint, motif court refusé, dossier tranché une seule fois, lancement possible après accord. Écran raccordé.
- Le maire constate encore : aucune autre écriture cliente sur le permis n'est restée ouverte hors `permis_plan_modifier` (plan, autorité vérifiée).

**Réorganisation payante des lots (29/10 soir) : VALIDÉE**, essai annulé sur la base réelle : 10 FR/m² touché (200 m² → 2 000 FR = 600 matériaux + 1 400 travail), débit unique et atomique (banque puis espèces), refus nommés (fonds insuffisants, lot loué touché `local_occupe`, surface du terrain dépassée et lot sous le minimum `plan_invalide`, simple renommage `aucun_changement`, second réaménagement, construction ou loyer pendant les travaux), réception requise, nouveau découpage persistant, lot loué et son bail intacts. Ancienne porte `terrain_reamenagement_poser` déjà fermée. Aucun défaut.

**PRÊTES, NON APPLIQUÉES (à appliquer par ChatGPT, consigne de Fred du 29/10) :**
- `20261029180000` — **à appliquer tout de suite** (compatible avec l'écran en ligne) : raccorde les anciens actes `achat_direct_accelerer` et `permis_accelerer` à la règle serveur (plus de date ni de dossier venant de l'écran, délai enregistré divisé par deux, une seule fois, dossier du seul demandeur). Répétée à blanc : date forgée ignorée (48 h → 24 h, prix intact), permis « valide » forgé ignoré (7 → 3 jours, statut et palier intacts), second essai `deja_accelere`, autre joueur `pas_mon_dossier`.
- `20261029181000` — raccordement immobilier du **combat des squatteurs** : `terrain_squatteurs_issue_interne(terrain, acteur, issue, requete)`, serveur seulement, appelée par le moteur commun de Codex. **CONTRAT (Fred, 29/10) : l'issue réelle du combat remplace définitivement le score final de 0 à 100** — `defaite` (rien ne change), `neutralises` (terrain libéré, délit **agression** : 25 %, 1 j, 500 FR), `tues` (cadavres laissés, requalification en **meurtre** : 25 %, 2 j, 1 500 FR). Le combat ne cesse que lorsqu'un des deux camps tombe à 0 PA. Reçu idempotent. **Dépend de Codex** : la résolution d'un combat collectif PJ (+ gros bras) contre un groupe de PNJ rendant cette issue.

**État d'intégration (29/10, 19 h)** : #233 et #234 à jour avec main (#238 inclus et intact : aucun écart sur ses fichiers ; seul conflit `plateau.html`, cache de `plateau-justice-economie.js` renouvelé en `terrains-psm-20261029`). #231 : fiches PNJ et Jodie **déjà livrées par #232**, la PR ne porte plus qu'une note de relais → à fermer. Bancs ciblés : `banc-etat-terrain` 43/43, `banc-dialogue-pnj-republia` 43/43.

**À appliquer JUSTE APRÈS la livraison de cette branche** : `20261029160000` (ferme les anciens actes `achat_direct_accelerer`, `permis_accelerer` et `permis_decider`). Répétées à blanc : OK.

**Constats non corrigés (à arbitrer ou à raccorder)** :
- **#224 loyers non prélevés** : cause trouvée. Au passage à l'heure d'hiver (25/10), le cron Vercel est resté sur `0 22 * * *` UTC = 23 h à Paris : les passes des 26 et 27 ont tourné une heure AVANT minuit, et la journée du 28 n'a eu **aucune passe** (cron_journal : 25, 26, 27, 29). Le réglage est déjà rattrapé (`0 23 * * *`, commit 3a9b0c5). Pas de rattrapage rétroactif sans accord de Fred. Fragilité restante (transversal, ChatGPT) : une passe lancée avant minuit Paris se compte pour la veille.
- **Prêt immobilier national débloqué trop tôt** (règle #57-11 : versement seulement à la signature) : CORRIGÉ par `20261029121752` (appliquée) — l'échéance du compromis n'accorde plus que le statut, le prêt est créé et versé dans la transaction de l'acte notarié. Éprouvé : aucun prêt à l'accord, prêt de 60 000 FR créé et acte payé à la signature.
- **Neutralisation des squatteurs par le combat** (#57-5) : pas d'ordre ; dépend du combat commun (Codex). Les trois actions validées de « Gestion des intrus » (négocier, police, cadavre) existent.
- **Matériaux** : un commerce premium ou un immeuble consomme 33 métal/jour ; l'entrepôt de Luthécia en tient 200 et se réapprovisionne la nuit. Deux chantiers simultanés peuvent manquer de matériaux : **décision de Fred (29/10) : courrier au maître d'ouvrage**, comme pour le manque d'argent — fait par `20261029122005` (appliquée, un courrier par arrêt, marqueur retiré à la reprise).
- Le maire décide d'un permis avec un statut envoyé par l'écran (`terrain_permis_acte('permis_decider')`), autorité vérifiée mais contenu client : à passer au serveur.

**Parcours à vérifier en jeu** (Fred, Angie, Vince) : acheter un terrain (dépôt puis notaire), y déposer un permis à la mairie et vérifier que « Construire » reste refusé tant que le permis n'est pas accordé ; après réception d'un commerce premium, fixer le loyer d'un lot dans « Information sur les locaux », le faire louer par un autre joueur et vérifier le crédit du loyer ; souscrire deux placements à la Banque nationale ; accélérer un rendez-vous chez le notaire.


### Vérification commerces, électronique, premium, ventes, presse, PNJ, douanes — Claude 29/10 (branche `claude/verif-luthecia-20261029`)

Suite de la mission du 29/10 (le premier bloc, terrains/immobilier/prêts/placements, est sur `claude/terrains-immobilier-20261029`, PR #233). Même méthode : parcours rejoués sur la vraie base au rôle authenticated, en transactions annulées (Angie, Arnie, Jean Jaaj ; rien de conservé). **Piège de test** : sans `request.path` = `/rpc/...`, le garde `inventaire_revision_garder` annule toute écriture d'inventaire faite au rôle authenticated ; ce n'est pas un défaut du jeu.

**Défaut reproduit et corrigé (migration APPLIQUÉE, compatible avec l'écran en ligne)** : `20261029095808` — dans un commerce de joueur, **« Consommer sur place » refusait toute boisson, tout encas servi, tout plat et tout menu** (`generique_regime_indetermine` : le moteur d'achat commun refuse les génériques ni individualisés ni empilables, c'est-à-dire toute la restauration servie). La « Dégustation à notre fontaine de chocolat » d'Angie (sur place uniquement) ne se vendait donc pas du tout. Corrigé par un drapeau de transaction posé par la consommation sur place ; l'achat à emporter de ces génériques reste refusé.

**Vérifié, fonctionne** : achat à emporter (prix, taxes locale et nationale, caisse du commerce au net, livraison en « objets à recevoir », stock), consommation sur place des produits à emporter (effets PV/moral), refus de l'achat à emporter d'un produit « sur place uniquement », journal des ventes (bonne identité acheteur/enseigne/article/prix, réservé au propriétaire), production des références (refus de dépassement du stock maximum), chaîne électronique complète (composants → ordinateur et téléphone, prix plafonné au coût de revient, vente), plafonds premium de la bêta (3 types / 10 références pour tous), achat à l'entrepôt et vente directe d'usine.

**Presse (#221)** : même cause que les loyers (#224) — au passage à l'heure d'hiver la passe de minuit tournait à 23 h ; aucune passe, donc aucune édition, pour la journée du 28. Éditions du 29 présentes. Réglage déjà rattrapé.

**PNJ** : Marcel Silo, Bernard Piluler et Jean Bonde ont leur fiche (PR #231, empilée sur #227). Restent muets hors Luthécia : Yvon Paletier, Norbert Charton, deux avocats commis d'office.

**Douanes** : portes vérifiées gardées (paie des douaniers et convocations réservées au Chef des Douanes en exercice, ou au serveur). Le voyage entre empires n'existe pas encore (décision : raccordé avec les autres empires).

**Parcours à vérifier en jeu** : chez SLAVA (Angie), consommer la fontaine de chocolat et un chocolat chaud sur place, acheter un ballotin à emporter et le retrouver dans les objets à recevoir ; Angie consulte son journal des ventes.


### Stabilisation Luthécia cinq points — ChatGPT 28/10

- **Connexion/création PJ (nouveau correctif) :** dans `sbCreerPersonnageUnique`, un rejet réseau de `fetch` pouvait remonter comme exception non gérée plutôt que réponse métier. Gestion explicite `creation_incertaine`, sans rejeu d'INSERT (il peut avoir été effectué). Quatre scénarios sur fonction réelle ajoutés dans `banc-creation-personnage-reseau-20261028.cjs`, raccordés au workflow client. Vérification CI en attente à ce stade ; aucun compte réel touché.


- **CI du nouveau banc navigation :** `coherence-client.yml` lance désormais explicitement `node outils/bancs/banc-sortie-reponse-perdue-20261028.cjs` (commit `c0365a6`). Workflow GitHub #40725306741 déclenché, état initial `pending` ; ne pas présenter le banc comme réussi avant conclusion. Aucun déploiement ni donnée joueur modifiée.


- **Navigation (nouveau banc) :** corps vivants `rue_position_enregistrer`, `rue_position_lire`, `rue_sortie_batiment_lire` relus en lecture seule ; banc `banc-sortie-reponse-perdue-20261028.cjs` poussé commit `4fa955f` pour vérifier réponse perdue sans double mutation. Exécution CI du nouveau banc non encore confirmée ; recette authentifiée toujours à faire.


- **Nouveau rapprochement vivant banque, 28/10 :** `fonds_credits_uniques` enregistre une régularisation de 100 000 FR pour le prêt travaux de Jean Jaaj, le 18/10 à 20:27 UTC (`pret-1792353270892`). Un deuxième prêt de 10 000 FR existe aussi, distinct. Les soldes actuels ne prouvent pas le crédit initial ou son affichage. **Ne pas régulariser une seconde fois** ; audit dans `PREVOL-CINQ-POINTS-LUTHECIA-20261028.md`, commit `358aedb`. Aucun solde modifié.

- **Complément vérifié CI / banque (commit `fe952ac`) :** cinq workflows PR #218 au vert ; le journal confirme `OK banc-reception-rest-20261028.cjs`. Prêt travaux national de Jean Jaaj de 100 000 FR présent dans Supabase, restant 76 997 FR, deux comptes distincts ; versement initial non démontré. Rapport prévol enrichi. Aucune écriture en base ni déploiement.

- Branche isolée `chatgpt/fiabilisation-luthecia-20261028` issue de main, hors inventaire et groupes. Audit détaillé `outils/audits/PREVOL-CINQ-POINTS-LUTHECIA-20261028.md`.
- **Navigation :** sortie serveur `rue_sortie_batiment_lire` / `rue_position_enregistrer` vérifiée ; zéro noeud de sortie orphelin sur 36 sorties Luthécia, 33 PSM, 41 Montrouge. Les sorties manquantes et cas d'écran bloqué restent à tester authentifié.
- **Réception :** le transport REST transformait un HTTP 200 à JSON illisible en succès `donnees:true` ; correction dans `supabase.js` : `reponse_invalide`, pas de réessai aveugle d'écriture ; 204 conservé. Banc isolé `banc-reception-rest-20261028.cjs` ajouté, non exécuté ici. La panne remontée par les joueurs n'est pas déclarée résolue.
- **Banque :** contrôle agrégé, 2 prêts, 3 placements, aucun montant négatif ; versements / écarts de solde pas encore rapprochés. **Vercel :** production `READY` sur main `3a9b0c5d`, les previews Codex ne sont pas la production. Contrôle SQL réutilisable `banc-luthecia-controle-navigation-banque-20261028.sql` exécuté en lecture seule.
- **Recette générale** : priorités et défauts restants inscrits dans le rapport. Aucune migration ni déploiement production ; aucun personnage modifié.


### Fiabilisation GitHub / Vercel — 28/10, Codex

- **Complément demandé par Fred après création manuelle de la PR : Workflow corrigé.** Deux doublons SQL supprimés au profit des fixtures existantes `banc-fixture-*` (mêmes corps), trois sources déplacées octet pour octet dans `historique/fixtures-bancs/`, quatre bancs Python raccordés. Aucun SQL métier ni inventaire modifié. Le vérificateur `verifier-workflow.py` reste strictement inchangé ; les neuf familles passent. Nouveau banc de rangement : six tests dont trois refus explicites des mauvais rangements/enveloppes. PostgreSQL jetable : permis 56, Céd/football 45, construction 62 (et variante #112 : 62), banque 61 (et variante location : 61), parcours cinq terrains 324. Les variantes partagent leurs assertions : ne pas additionner comme des cas distincts. Contrôleur client complet après rangement : **107/107 bancs réussis**. Aucun accès production ni migration appliquée.

- Branche isolée **`codex/fiabilisation-ci-20261028`**, issue du main `da5ecc0`. Aucun fichier du jeu, de l'inventaire, des ambassades/BNE ou aucune migration modifié. L'inventaire reste confié à Claude ; Fred a ensuite autorisé explicitement la correction du seul rangement des cinq fixtures SQL (28/10), sans toucher à l'inventaire.
- Défaut reproduit du contrôleur : enfant encore actif après expiration du délai, diagnostics partiels jetés. Correction de l'arrêt du groupe privé, journaux conservés après timeout, distinction lancement/timeout/assertion et résultats JSON progressifs avec état complet/interrompu ; TERM nettoie aussi. Aucun verrou métier ni délai assoupli.
- Deux workflows coûteux rejoignent la politique existante d'annulation des seules anciennes exécutions d'une même PR (parcours immobilier et placements). Tests et noms de contrôles conservés ; main n'est pas annulé. Configuration distante et `vercel.json` inchangés.
- Vérifié localement : **106/106 bancs** avec le lanceur Linux du dépôt sans adaptateur externe ; **105/105 pilote local**, **7 régressions Python**, **24 tests ciblés**, **3 mutants détectés**, **3 passages Chromium (27/27 scénarios)**, **11 tests calendrier/placements**, **23 API** syntaxiquement valides ; payload **256,5/330 Mo**, 12 YAML analysés. Les comptes se recouvrent, ne pas les additionner.
- Rapport et preuves : `outils/vercel/FIABILISATION-20261028.md`, `outils/vercel/preuves-20261028/`. API GitHub runs/PR refusée ; HTTPS Vercel refusé par le proxy. Pas de résultat distant observé, pas de fusion/déploiement demandé ni effectué. Code et preuves poussés au commit `7777b42`. Création de PR réellement tentée après push : GraphQL `Forbidden`, aucun numéro créé. Branche prête pour revue, non fusionnée.


### Sécurité privée #135 — arbitrages du 27/10 (ChatGPT)

- **28/10, groupe universel : déploiement ensemble ou séparé** : `pnj_membres.groupe_deploiement_id` facultatif et RPC générale `pnj_deployer_unite(text[], boolean)` introduites dans la migration #135. Le chef PJ authentifié peut déposer les PNJ qui le suivent dans une seule unité (clé de déploiement partagée) ou individuellement (aucune clé commune) ; le détecteur utilise cette distinction. Tests SQL réels sur groupe de 2 et 2 unités isolées, refus d'un PJ non chef, validation autorisation/position, `BEGIN/ROLLBACK` : succès, aucune migration en production. **À compléter** : groupes mixtes PJ+PNJ et UI, reprise des PNJ, raccordement de l'ancien ordre militaire de dépose au même socle ; aucun fichier de Codex touché.


- **28/10, règle universelle des groupes PJ+PNJ (Fred)** : chaque groupe est commandé par un PJ ; seul ce chef déplace le groupe, entraînant ses membres ; le chef peut déployer tout ou partie de ses membres à sa position. Ceci vaut pour **tous les joueurs/PNJ**, pas seulement militaires, policiers ou privés. La source Kraland est inspiration, sans copie des quotas, coûts, interdictions ou capture. Spécification versionnée dans `GAME-DESIGN-SECURITE-PRIVEE-135.md`. Audit : les liens `pnj_membres.leader_pj/leader_pnj_id` et groupes de bataille existent, mais le regroupement PJ universel et le déploiement ne sont pas encore localisés/vérifiés ; ne pas assimiler le `groupe_id` de bataille à un groupe persistant. Préserver la PR brouillon, et ne pas inventer de moteur/tables parallèles ni modifier les fichiers de Codex.


- **28/10, raccordement au socle militaire confirmé** : `militaire_bataille_groupes_constituer(bigint)` utilise déjà `batailles_engagements.groupe_id` pour regrouper compagnie, section et chef. Dans la migration #135, le détecteur accepte désormais le même `groupe_id` explicite pour les policiers (avec alias historique `groupeId`) ; les privés restent attachés au `leader_pnj_id` du socle PNJ. Le banc de priorités utilisant `groupe_id` passe dans `BEGIN/ROLLBACK` sur Supabase. Attention : `batailles_groupes` est limité aux batailles, donc la preuve de constitution et de circulation de groupes policiers hors bataille reste à établir avant clôture. Codex non touché.


- **Validation du groupement PNJ (27/10)** : nouveau test de deux agents privés réellement liés par `leader_pnj_id`, sélectionnés comme un groupe de 2 avec PER moyen +1 ; test transactionnel Supabase réussi. La présence commune sans lien ne suffit pas à grouper les unités. Branche `chatgpt/securite-privee-20261027` / PR #212 toujours en brouillon, sans migration appliquée durablement.


- **Implémentation des priorités (27/10)** : migration SQL #135 enrichie d'un ordre d'unités (police avant privé ; taille décroissante ; ex aequo aléatoires), jets séquentiels au premier succès, et `police_interceptions.intervenants` pour limiter fuite et combat aux seuls agents détecteurs. Le regroupement des PNJ privés repose sur `leader_pnj_id`; côté policier, les unités sans `groupeId` explicite restent isolées, même dans la même salle. Six réexécutions transactionnelles réussies des 3 bancs sur Supabase (deux passes de chaque), sans modification durable. Spécification versionnée : `GAME-DESIGN-SECURITE-PRIVEE-135.md`. Reste à raccorder la constitution effective de groupes policiers sans inventer une mécanique, recette finale puis fusion/déploiement. Aucun fichier Codex modifié.


- **Arbitrage prioritaire #135 (27/10, validé par Fred)** : la détection est séquentielle, jamais mutualisée. **Police d'abord**, puis **sécurité privée seulement si tous les jets policiers échouent**. Dans chaque catégorie, priorité aux **groupes constitués les plus nombreux**, puis aux groupes plus petits et aux agents isolés ; **ordre aléatoire entre effectifs de même taille** (y compris policiers isolés). Chaque groupe ou agent a son propre jet de détection existant. **Première réussite : arrêt immédiat des autres jets**, interception par ce seul groupe/agent, combat uniquement contre ses membres (un isolé = 1 contre 1). Échec de tous : aucun contrôle. Le même ordre vaut pour les agents privés, avec les mécanismes d'emploi, déplacement et combat déjà existants ; ne pas confondre présence simultanée avec groupe constitué. **Raccordement de la PR #212 corrigé et testé en transaction : jets séquentiels, priorité des groupes et intervenants figés.** Reste la formation explicite des groupes policiers dans le socle d'affectation (catalogue actuel individuel), les vérifications d'intégration et le déploiement.


- **27/10, permissions et anti-rejeu** : assertion `has_function_privilege` garantissant que `anon` et `authenticated` n'exécutent pas directement l'auxiliaire des agents privés ; contrôle d'égalité stricte des deux reçus d'un même round, sans jamais accorder `SELECT` sur `pnj_membres` au joueur. Banc migration + SQL exécutés dans `BEGIN/ROLLBACK` sur Supabase : OK.
- **27/10, combat à plusieurs rounds** : banc enrichi d'un second round authentifié avec deux agents privés simultanés ; un troisième round est refusé après leur départ collectif. Migration + banc SQL exécutés sur la base réelle dans `BEGIN/ROLLBACK` : succès ; aucun fichier de Codex touché, aucun déploiement durable.
- **27/10, poursuite sans relance** : banc du combat enrichi des assertions de PA persistants, d'un deuxième agent de type `maitre_chien`, et de la présence simultanée de deux agents ; refus du second round seulement si tous les agents ont quitté la zone. Migration + banc joués dans une transaction Supabase annulée : succès. Aucune intervention dans les fichiers de Codex.
- **27/10, escorte PNJ** : banc d'un agent fictif suivant son leader PJ testé avec `pnj_position_effective` : présent dans la salle du PJ, mais non hostile à l'employeur ; aucun ordre d'affectation nouveau. Le test respecte les protections contre la suppression d'un PNJ vivant (statut `detenu` puis transaction annulée). Contrôle SQL complet OK.
- **27/10, recette des issues versionnée** : nouveau `outils/bancs/banc-securite-privee-issues-135.sql`, tests authentifiés séparés pour reddition conduisant à `detention_id` et fuite arbitrée par `police_fuite_resoudre`. Savepoints, migration et jeu fictif exécutés ensemble dans une transaction annulée Supabase : OK. Les tests ne modifient aucune donnée permanente.
- **27/10, tests de sécurité supplémentaires** : six assertions de présence/absence du PNJ (ville, salle, PA, employeur, détention), refus de combat depuis une autre identité authentifiée, et refus d'un nouveau round lorsque l'agent quitte la zone. Migration + banc SQL complets joués ensemble dans `BEGIN/ROLLBACK` Supabase : OK. Ne pas fusionner avant baseline canonique, tests d'intégration complets et jonction malus/vol avec Codex.
- **27/10, poursuite en parallèle** : correction de la persistance des PA des agents privés lors du combat dans `pnj_membres` (aucune affectation de chantier) ; banc SQL versionné enrichi d'un personnage fictif sous `authenticated`, du combat et de son rejeu idempotent ; migration et banc rejoués ensemble sur Supabase dans `BEGIN/ROLLBACK` : OK. Aucun fichier inventaire/vol de matériaux modifié ; aucune écriture persistante en production.
- **27/10, branche de travail ChatGPT** : `chatgpt/securite-privee-20261027`, [PR #212](https://github.com/FredJ74/res-publica/pull/212) **en brouillon**. Raccordement client serveur-first, adaptateur de présence PNJ aux trois fonctions policières existantes, RP « remis à la police ». Bancs transactionnels réels annulés sur personnages artificiels : compilation, 4 assertions de présence, détection sous `authenticated`, reddition/détention, fuite et un round de combat OK. Cinq workflows GitHub au vert sur `fc32aa8c`, prévisualisation Vercel READY. **Non déployé en production**, migration non appliquée ; avant fusion : recette complète, baseline Supabase selon WORKFLOW-SUPABASE.md, coordination du vol de matériaux avec Codex et contrôle production. La PR #196 demeure incompatible et ne doit pas être fusionnée.

- Fred confirme : **seulement deux socles**, embauche/déplacement des PNJ et mécanique policière (malus actes illégaux, détection, interpellation, prison). « Vigile de chantier » est cosmétique. **Aucune affectation au chantier**, aucun moteur/table d'affectation propre aux vigiles. Le PJ employeur déplace librement son PNJ. En cas d'interpellation réussie, mécanisme carcéral policier existant et message RP « remis à la police, conduit en prison ».
- `AGENTS.md` a été corrigé pour lever l'ancien arbitrage contradictoire. La PR #196 `codex/vigiles-vol-135-20261027` est **ouverte, non fusionnable en l'état** : elle ajoute `chantier_vigiles_affectations` et un moteur privé de détection, en contradiction avec cette décision ; ne pas appliquer ses migrations.
- Vérification réelle Supabase en lecture seule : `pnj_position_effective(text)`, `police_detection_verifier(text,text,text)`, `combat_coup_resoudre(numeric,numeric,numeric,integer,integer)` existent. `police_detection_verifier` lit les effectifs policiers de `batiments_etat` ; il faut factoriser/utiliser son algorithme commun pour les agents PNJ sans faux policiers, sans nouvelle mécanique parallèle. Préserver les règles serveur de détection, les gardes anti-relance et le parcours d'incarcération.
- Codex traite actuellement **l'inventaire**, y compris le vol de matériaux ; ne pas toucher à ces fichiers ni aux migrations objets. Préparer séparément le raccordement de sécurité passive et la détection/interpellation avec tests en transaction annulée (`authenticated`), puis déployer seulement après tests complets.


### #135 — Recette de clôture du 27 octobre

- Branche `codex/cloture-immobilier-135-20261027`, issue de main `74128ee` : #174/#175/#178/#188 conservées, aucun ancien correctif réimporté. Aucun fichier métier ambassades/BNE ni socle transversal de Claude modifié.
- Défaut réel corrigé : `confirmerVolMateriaux` réaffectait une constante après réponse serveur. Quantité demandée distincte de la quantité accordée ; quatre tests réels sur fixtures dont contre-épreuve de l'exception, version du script actualisée.
- 105/105 pilote, 105/105 bancs clients, navigation 60/60 (incluse), occupation 30, négociation 59, permis 56, cinq parcours 324 + banque 61, progression/salaire 62+15, matériaux conformes. Assemblage des cinq parcours complété du taux horaire actuel. Trois mutants SQL détectés, preuves archivées.
- Globaux 4/12, résultats identiques au main courant : aucun contrôle maquillé. Le vol demeure un circuit historique non entièrement atomique et le raccordement des vigiles aux affectations/détection/combat communs n'est pas démontré ; ne pas déclarer ce volet fini.
- Audit du 26 : cinquième connexion Arnie et position initiale confirmées en lecture seule, résultat archivé, pas réexécuté ici. API GitHub Forbidden, HTTPS Vercel refusé par proxy, aucun outil Supabase exposé. Aucun joueur déplacé et aucune migration appliquée.
- Correctif et preuves poussés : `736ab07`. Tentative de PR en brouillon refusée par GraphQL (`Forbidden`), aucun numéro créé ni fusion.
- Rapport et preuves : `outils/audits/CLOTURE-IMMOBILIER-135-20261027.md`. PR/intégration/déploiement à vérifier par accès technique ; #135 reste ouvert. Intervention unique : fournir ces accès à une session exécutante, sans manipulation SQL ni compte/secret à recréer par Fred.


**Ambassades et Bureau de l'Emploi : chantiers de Claude seul** (Fred, 25/10). Ces
notes sont la trace du travail, pour reprendre l'historique. **Codex : ne pas toucher aux
ambassades ni au Bureau de l'Emploi.**
- **Nuit du 26 au 27/10 (Claude)** : `CONSTITUTION.md` et `ARCHITECTURE.md` ajoutés (à lire,
  `AGENTS.md` y renvoie ; tenir `ARCHITECTURE.md` à jour). Fusionnés : ordre générique par le
  serveur (`ordre_generique_executer`) ; couvre-feu et recherche militaire dans la passe de nuit
  (`minuit_couvre_feu_recherche`) ; code mort supprimé ; inventaire vérifié. Matin du 27 : objets
  abandonnés par le serveur (`20261027030000`) ; carrière religieuse de Républia par le serveur
  (`religion_agir`, `20261027040000`/`040100`) — `titulaires_pnj` et `contributions_piete` ne sont
  plus écrites par les joueurs. **Codex : pour la popularité ou l'influence rendues par une RPC,
  utiliser `adopterJaugeServeur('pop'|'inf', valeur)`, jamais `state.pop = v.pop`** (double
  comptage à la sauvegarde suivante). **Bancs SQL : se placer au rôle `authenticated`** (`set_config('role','authenticated',true)`),
  sinon `est_appel_serveur()` est vrai et masque les défauts (c'est ainsi que l'annulation des
  gains de popularité écrits par le serveur est passée inaperçue ; corrigé, `20261027050000`).
  Démenti et rumeurs politiques par le serveur (`dementi_executer`, `20261027060000`). **Scrutins fermés aux joueurs** (`cycles_electoraux`) : engendrement, dissolution et
  contestation par le serveur (`20261027070000`/`070100`) ; la passe de nuit pose
  `cycle.dernierScrutin` à chaque proclamation (ne pas le retirer : la contestation en dépend). Fraudes électorales par le serveur (`fraude_electorale_tenter`, `20261027080000`). Vote de confiance par le serveur (`20261027090000`). **Justice** (`20261027100000`-`100200`) : `recherche_retirer` refuse le retrait libre (seulement
  juste après un écrou, ou désertion éteinte) — **Codex : tout nouveau retrait de motif passe par
  une fonction serveur qui sait pourquoi** ; `enquete_garde_a_vue` n'est plus appelable ;
  convocations tenues par le serveur (`convocation_se_justifier`, `minuit_convocations`). **Crime** (`20261027110000`/`110100`) : socle pénal serveur (détection, trace, découverte de nuit) ; neutraliser, incendier, explosifs par le serveur ; `impact_deposer('hp_set')` refusé et `batiments_fermes` fermée aux joueurs — **Codex : un dégât ou une fermeture se pose dans la fonction serveur de l'acte**. Vol et empoisonnement par le serveur (`crime_voler`, `crime_empoisonner`, `20261027120000`/`120100`) ; `vols_en_attente` n'est plus écrite par les joueurs. Détection des ordres illégaux, corruptions, contrebande et falsification par le serveur (`20261027130000`) — **Codex : un nouvel acte illégal tire sa détection dans sa fonction serveur (`crime_detecter_interne`), jamais par `checkDetection` à l'écran**. Scandale de la nuit par le serveur (`minuit_scandale`, cron). **Codex : une réponse serveur qui change l'inventaire rend `inventory` et `revision`, et l'écran adopte la réponse elle-même (`sbAdopterInventaireServeur(v)`)**. Informateurs par le serveur (`informateur_recruter`/`_interroger`/`_congedier`, `minuit_informateurs` au cron) ; la colonne `informateurs` n'est plus écrite par l'écran ; interroger coûte 1 PA (Fred). Marché noir (armes, explosifs) et suites de la neutralisation d'un député par le serveur. **Codex : `corrompre_fonctionnaire_permis` (terrains) et le hooliganisme (organisations) écrivent encore leur trace de crime à l'écran ; à passer par `crime_tracer_interne` dans vos chantiers, après quoi la découverte cliente (`verifierDecouverteCrimesPasses`) pourra disparaître.** Rumeurs : `rumeur_lancer` ; les causes `rumeur_pj`/`rumeur_gouvernement` sont fermées aux joueurs. **Attention : `inventaire_sauver_revision` accepte encore tout inventaire du navigateur (voir l'audit) ; tout nouvel objet doit être déposé par le serveur.** **Chantier inventaire EN COURS (Claude, Fred : « Oui, maintenant », 27/10)** : lots 1 à 3 fusionnés (achats d'armes, gilet, poisons, relique, récolte, produits du marché, tracts ; dépôt serveur unique `inventaire_deposer_interne`, catalogue `objets_modeles`). Reste à faire, dans l'ordre : sels d'ammoniaque (`confirmerAcheterSels`, caisse `pays_usine-pharmaceutique-luthecia`), objets trouvés (`reclamerObjetTrouve`), fret (4 sites de `plateau-justice-economie.js`), employés (`plateau-multijoueur.js`), état civil, énigmes, missions de PNJ et escort, effort de guerre, acte d'entreprise et publications ; documents d'urbanisme et vol de matériaux (terrains), récompenses de quête et accessoires de club (organisations, championnat) = **Codex** ; puis, en dernier, le verrou : `inventaire_sauver_revision` ne doit plus accepter d'ajout venu du navigateur. Liste des sites : `grep -n "addToInventory(\|inventory.push(" plateau-*.js`.
- **Corrections « une seule vérité » (Fred, 26/10 : « fais dans l'ordre que tu veux »)** — Claude.
  Fait : caisses adossées (`fonds_en_transit`, `batiment_caisse_client_crediter`, primitives de
  caisse retirées au navigateur, `usine_virer_vers_ministere`, `ministere_virer_vers_usine`,
  `imprimerie_acheter_bois`). **Codex : tout nouveau crédit de caisse se fait dans la fonction
  serveur de l'action** ; un crédit demandé par le navigateur doit être adossé à un paiement.
  Suite prévue : tables ouvertes (hors successions, terrains, urbanisme, championnat), fiche,
  ordre générique.
- **Audit « une seule vérité » (26/10, nuit, branche `claude/audit-une-seule-verite-20261026`)** :
  `AUDIT_UNE_SEULE_VERITE.md` inventorie tout le jeu (tables ouvertes à tout joueur, RPC
  qui créent de l'argent sur demande, champs de fiche encore libres, ~95 tirages et l'ordre
  générique décidés par l'écran, passe de minuit cliente, échéances à l'horloge du
  navigateur, deux affichages, code mort). **Rien n'est corrigé hors ambassades et BNE** :
  l'ordre des chantiers est à décider par Fred. Corrigé côté ambassades : annonces publiques
  par le serveur, traités lus sur le serveur (migration `20261026010000`).
- **Décisions de la série de questions (25/10, branche
  `claude/decisions-ambassades-bne-20261025`)** : Indice Diplomatique réel, un par pays
  (`indices_diplomatiques` + journal, `indices_diplomatiques_lire`, seule écriture
  `indice_diplomatique_varier_interne`) ; toutes les variations par le serveur
  (`ambassade_ouvrir`, `ambassade_reception_organiser` avec présence,
  `ambassade_mecenat`, `ambassade_reserver_salle`, patchs de
  `communication_officielle_publier`, `guerre_cessez_le_feu_activer`, `guerre_declarer`,
  `indice_diplomatique_ordre` pour mobilisation / banquet / réception d'État,
  `diplomatie_repondre`). Le client ne modifie plus `INDICES_NATIONAUX[p].ID` : il la
  recharge (`chargerIndicesDiplomatiques`). Corruption d'un homologue supprimée ; Bureau de
  direction du BNE supprimé ; ouvriers PNJ payés au taux du propriétaire
  (`reliquatNPCServeur`) ; caisse du BNE ouverte au Ministre des Finances
  (`bne_caisse_lire`, `bne_caisse_prelever`, ordre `bne_caisse_prelever`). Migrations
  `20261025120000`, `120100`, `120200`.
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
- 25/10 soir : **nouvelle formule du Bureau de l'Emploi** décidée par Fred,
  consignée dans **`GAME-DESIGN-BNE.md`** (recensement des postes réels tenus
  par des PNJ, candidature transmise au recruteur officiel avec décision le
  vendredi, annonces des joueurs, virement automatique, suppression des sept
  offres fictives et de l'inscription).
- 25/10 soir, **lot 1 livré** (branche `claude/bne-recensement-20261025`, registre
  20261025181516) : sept offres et inscription supprimées, mail aux titulaires,
  écran « Postes à pourvoir » lu sur `bne_postes_a_pourvoir` ; candidature par le
  circuit existant du 25 août (Fred : « on conserve l'ancien fonctionnement en
  entier ») ; capitaine/lieutenant postulables depuis le Bureau.
- 25/10 soir : **1 PA par candidature** (registre 20261025182135) et **lot 3,
  annonces des joueurs** (registre 20261025183757 : `bne_annonces`,
  `bne_annonce_publier/lister/retirer`, option Tribune 30 FR versés à la caisse
  `<pays>_bureau-national-emploi`).
- 25/10 soir : **taux horaire des chantiers** fixé par le titulaire, minimum 50 FR
  (registre 20261025193111) : action `taux` de `chantier_commande`,
  `chantier_taux_definir`, `chantier_travailler` paie au taux du chantier. **Codex :
  touche à tes fichiers construction** (`plateau-construction-commandes.js` : ordre
  dynamique `taux_chantier` ; `plateau-chantiers.js` : `tauxHoraireChantier`). Le
  travail PNJ (cron) reste au taux de référence de 70 FR.
- 25/10 soir : **virements entre joueurs** (registre 20261025194235 et
  20261025194255) : `banque_virement`, `banque_virement_automatique_creer`,
  `virements_automatiques_mes`, `virement_automatique_arreter`, passe de nuit
  `virements_automatiques_executer` (cron). Tous les lots de `GAME-DESIGN-BNE.md`
  sont livrés ; reste la question du Bureau de direction (fin de chantier).
- 25/10 soir : **trois référentes emploi** (Nathalie Boulot, Edwige Leroux, Pétra
  Vaillepas), fiches dans `api/_pnj-referents.js`, déclarées dans `pnj_referents`
  (registre 20261025201502).
- 25/10 nuit : **fin des chantiers**. BNE : restes retirés, heures de chantier et
  dossier de candidature par le serveur (#162). Ambassades : actions du ministre par
  le serveur, table en lecture seule pour les joueurs, asile tranché par
  l'ambassadeur joueur, secrétaires, valise (registre 20261025210049, …210208,
  …210344). Bloqués par l'absence de voyage entre empires : immunité, arrestation de
  l'expulsé, transfert de détenus, naturalisation (voir `GAME-DESIGN-AMBASSADES.md`).
- Prochaines étapes (Claude) : coder `GAME-DESIGN-BNE.md` par lots — 1. suppression
  des offres et de l'inscription + recensement ; 2. candidatures et décision du
  vendredi ; 3. annonces des joueurs (+ parution Tribune par le serveur, caisse du
  Bureau) ; 4. virement entre joueurs puis virement automatique ; 5. taux horaire
  des chantiers fixé par le propriétaire (minimum 50 FR).
  Ambassades : griser « Bientôt disponible » les ordres non raccordables (en
  attente de Fred).
- Bancs : 85/102 en local, les 17 échecs sont identiques sur `main`
  (bancs navigateur, environnement).
- Issue #143 : passer toutes les fenêtres à la charte (plus tard).

Travaux déjà ouverts avant la mise en place du relais (pull requests
existantes, à reprendre si Fred le demande) :
- #139 `integration/livraison-terrain-135-20261024` — terrains : occupation
  transactionnelle, réaménagement, protection des locaux (issue #135).
  Restent L11 acquisition/financement, L04 prêt conso, L09 bénédiction.
- Nombreuses PR WIP plus anciennes (construction #94, successions #95,
  interception policière…) : voir la liste des PR ouvertes.

## Derniers chantiers

- 24/10/2026 — Mise en place du relais Codex/Claude (`AGENTS.md`,
  `CLAUDE.md`, `RELAIS.md`).
