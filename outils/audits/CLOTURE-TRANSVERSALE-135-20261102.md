# Audit technique transversal de clôture — #135, 2 novembre 2026

Mission : [commentaire de Fred du 02/11 à 18 h 32 UTC](https://github.com/FredJ74/res-publica/issues/135#issuecomment-6585083787).
Branche : `codex/audit-transversal-cloture-135-20261102`.
Départ : `main` `9e105f08bb5797c24b18c6d927bdf6cca0a6dd67`.
Dernier main intégré : `a52e1a009b74c88de55a289732b2c945554f02b9` (#378).
Code de recette : `d7654c7536e2e4ab46fe3c118e44bd183ab98aa3`.

> **Reprise du 3 novembre :** les quatre reliquats ont été traités dans le code et
> deux migrations gardées sont préparées. Lire [le rapport de reprise](LIVRAISON-RELIQUATS-379-20261103.md)
> et ses preuves : un diagnostic d'ancien cache reste rouge et bloque la promotion.
> Les constats et nombres ci-dessous restent ceux de la première livraison ; ils
> ne remplacent pas la nouvelle recette et ne valent pas validation de production.

**Verdict : correctifs locaux préparés et éprouvés ; clôture de production non certifiée.**
Les limitations d'accès ne sont pas des anomalies du jeu. Aucune fusion, migration
ou écriture de production effectuée par cette mission. Aucune campagne avec un PJ réel.

## Périmètre et absence de doublon

- AGENTS, RELAIS et WORKFLOW-SUPABASE lus ; PR publiques ouvertes consultées avant modification.
- Réutilisation de #250, #262 et #282 et du lot historique Codex `8c559f71` resté non fusionné.
  Ses outils/tests ont été repris ; les anciens corps métier n'ont pas remplacé ceux de main.
- #219 n'est pas réouverte, ses 95 migrations ne sont pas réinstallées pour refaire sa livraison.
  Les tests PostgreSQL ciblés existants sont réutilisés comme régression.
- PNJ, identités, personnalités, DeepSeek et migrations de Claude exclus des modifications propres.
  Les nouveautés #375, #376 et #378 sont intégrées, pas recodées. Les nouveaux préfixes
  de cache de Claude sont conservés et complétés pour nos sept scripts modifiés.
- #369 n'est pas fusionnée en doublon : #371 a déjà livré les pop-up des greffes.
  #375 a corrigé son propre banc conférence ; cette branche n'en propose pas une seconde correction.
- Aucun tarif, coût en PA, effet, droit de poste ou choix graphique de game design changé.

## 1. Matrice de livraison : cinq preuves différentes

Les statuts GitHub ci-dessous ont été lus dans les pages publiques des PR et de leurs
contrôles. Les descriptions historiques des PR peuvent encore annoncer des travaux
déjà livrés : elles ne remplacent ni main ni un relevé de production récent.

| Sujet | GitHub / code actuellement intégré | CI historique observée | Supabase / Vercel | Recette réellement effectuée ici |
|---|---|---|---|---|
| [#219](https://github.com/FredJ74/res-publica/pull/219) | MERGED, 01/11 21:07:53 UTC ; tête `57f4ede9`, intégration #340 `27b9bf56` sur main | Six contrôles verts sur la tête de #219 | RELAIS rapporte 99 migrations appliquées atomiquement, registre 1023 → 1122, et Vercel READY le 01/11. **Constats historiques, pas relus en direct ici.** D'autres migrations ont été livrées depuis. | 379 scénarios PostgreSQL locaux ciblés, incluant les 141 transports/groupes, plus bancs clients. Pas les 27 HTTP de production. |
| [#349](https://github.com/FredJ74/res-publica/pull/349) commissariats | MERGED `7ae1bb33`, 02/11 00:04:08 UTC ; deux sous-menus dans le renderer commun, trois villes | Cinq contrôles verts | Image présente dans le dépôt, passée en WebP par #357 ; ressource réellement servie non contrôlée | Vrai Chromium local : clics des sous-menus et ordres, commissaire/visiteur, 1280 et 390 px, trois villes |
| [#366](https://github.com/FredJ74/res-publica/pull/366) position | MERGED `57ef60d3`, 02/11 15:05:46 UTC ; réalignement de ville dans `initialiserRueCentrale` | Deux contrôles verts, cohérence rouge : [41467709237](https://github.com/FredJ74/res-publica/actions/runs/41467709237), étape « Bancs JavaScript, transports simulés ». Journaux détaillés non accessibles | Aucun déplacement d'Angie effectué ; sa position actuelle n'a pas été lue | 19 cas exécutant chargement/rue réels sur fixtures ; six cas rue échouent contre le code antérieur à #366. Le TODO de dépendance #219/#318 est activé (5/5). |
| [#371](https://github.com/FredJ74/res-publica/pull/371) greffes | MERGED `fe343936`, 02/11 18:06:09 UTC ; quatre boutons ouvrent les modales existantes | Deux contrôles verts, cohérence rouge : [41497302968](https://github.com/FredJ74/res-publica/actions/runs/41497302968), même étape publique. Cause détaillée non attribuée sans logs | Pas de nouvel essai authentifié | Vrai Chromium local : toutes les actions déclarées, menus et modales, trois villes/deux largeurs. Le juge de la quête reste caché hors enquête. |

Le rapport `INTEGRATION95-ET-CAISSES300-219-20261031.md` contient 27/27 scénarios
GoTrue/PostgREST **locaux datés**. Ils ne prouvent ni une connexion PJ actuelle,
ni la conformité du catalogue vivant du 2 novembre. Leur ancien 10/12 n'est pas
republié comme l'état actuel : les contrôles hors ligne actuels ont été relancés.

Vercel : la tentative de lecture de `https://res-publica.vercel.app/plateau.html`
et de `plateau-navigation.js` est refusée par le proxy de cet environnement
(`Tunnel connection failed: 403 Forbidden`). Aucun SHA servi, READY actuel ou
fonctionnement en jeu n'est donc confirmé ici. Aucun déploiement Vercel manuel
n'a été lancé ; les éventuels traitements automatiques d'une branche ne sont pas observables.

## 2. Anomalies reproduites et corrections

Tous ces correctifs sont sur la branche de revue, **pas livrés en production**.
Les lignes exactes et preuves d'appel sont dans l'inventaire JSON associé.

| Gravité | Chemin / fonction | Attendu / observé avant | Correction et test | Résultat |
|---|---|---|---|---|
| P1 | `plateau-navigation.js` : `executerVoyage`, `confirmerTransport`, `doPasserDouanesAeroport`, `doCorrompreDoanier` ; `plateau-justice-economie.js` : `doTaxiSpecial` | Paiement/déplacement/douane par acte serveur. Un drapeau absent ou faux sélectionnait encore paiement séparé, état local et ancien contrôle aléatoire. | Délégation inconditionnelle aux **commandes atomiques existantes**, mêmes paramètres. Taxi conserve ses destinations autorisées. `banc-transports-sans-repli-local.cjs`. | 16/16 ; ancien code 11 échecs/16. Les 8 tests transport et 12 tests douane existants passent aussi. |
| P2 | `plateau-politique.js` : `renderRoomActions` | Le bouton réservé doit expliquer son refus sans exécuter l'ordre. Les guillemets JSON coupaient l'attribut HTML : `showPostRequired(` incomplet, erreur Chromium `Unexpected end of input`. | Échappement des guillemets de l'attribut commun ; gardes et handlers inchangés. `test-rendu-services-republia.cjs`, vrai CSS/DOM/renderer. | 12 scénarios + parent réussis ; ancien renderer : six scénarios commissariat et parent rouges. |
| P1 | `plateau-justice-economie.js` : `rafraichirInventaireDepuisServeur` | Inventaire **et révision** doivent rester liés. L'ancien GET `select=inventory` avait une provenance valide mais remettait `_inventaireRevision` à `null`. | Reprise de `sbInventaireReceptionEtat`, contrôle de révision entière, adoption de la réponse originale par `sbAdopterInventaireServeur`. Aucun objet recomposé, aucun nouveau moteur. | 10/10 ; quatre échecs sur l'ancien corps. Réponses perdues/incomplètes, changement de personnage/session/génération refusés. |
| P2 | `plateau-communication.js`, `plateau-organisations-quetes.js` : quatre adaptateurs électoraux, `voterElectionOrganisation` | Une ancienne carte ne doit pas fabriquer de votes locaux ni masquer le vote organisation. Deux définitions de `voterElection` avaient des signatures différentes. | Anciennes cartes → tableau électoral officiel ; deux arguments → commande organisation actuelle. **Corps #350 conservé**, pas de sauvegarde générale d'organisation réintroduite. | Banc historique repris : 14/14, dont contre-épreuves et virement ; ancien main : dix échecs/14. Tests organisation #350 conservés/adaptés au nom non ambigu. |
| P2 | `plateau-personnage.js`, `plateau-actions-illegales-rumeurs.js` : carte du monde et `doSesoigner` | Une définition globale par fonction. Trois copies avaient des corps strictement identiques. | Retrait des seules copies ; carte canonique dans navigation, soin canonique dans personnage **inchangé**. | Quatre noms globaux en doublon avant (dont vote), zéro après. Aucun soin ni effet médical modifié. |
| P2 | `plateau-justice-economie.js` : `confirmerVirementJoueur` | Une réponse perdue ne prouve pas l'absence de débit. Le message affirmait « rien n'a été prélevé ». | Message de confirmation indisponible et consultation du compte avant renouvellement ; aucun second paiement/rejeu ajouté. | Cinq issues testées : succès, refus, réponse perdue, transport, exception. |
| P2 | `.github/workflows/coherence-client.yml` | Installer les dépendances avant les tests qui les importent. Le contrôle main passait avant `npm ci`, contrairement aux bancs clients suivants. | Déplacement de l'étape après les deux installations existantes. Aucun nouveau pipeline ni test retiré. `banc-workflow-dependances.cjs`. | Checkout main propre : `MODULE_NOT_FOUND` Acorn ; même main avec dépendances : 53/53. Contre-épreuve de mauvais ordre refusée. |

CI actuelle de main `2c60bb3f` au moment du relevé : trois workflows réussis
(immobilier, payload, placement) ; cohérence en échec à l'étape **Calendrier sur main**,
[run 41504707816 / job 125480910786](https://github.com/FredJ74/res-publica/actions/runs/41504707816/job/125480910786).
La copie propre reproduit précisément l'import Acorn absent. La correction est
validée localement ; **le résultat distant du futur SHA de cette branche n'est pas observé**.
Ne pas attribuer pour autant les anciens échecs #366/#371 à cette même cause.
La dernière lecture publique, après #378 (`a52e1a00`), retrouve trois succès et
la cohérence rouge ([41508724071](https://github.com/FredJ74/res-publica/actions/runs/41508724071)).
Les états publics épurés sont conservés dans `preuves-cloture135-20261102/ci-main-public.json`.

## 3. Inventaire différentiel des chemins historiques

Outils réutilisés : `outils/auditer-etats-client.py --appels` et
`outils/analyser-appels-client.cjs` (analyse Acorn, scripts réellement chargés par plateau.html).
L'inventaire annexe contient les définitions, écritures protégées, appels SQL et
chemins potentiels depuis les événements. Il ne prouve pas l'exécution d'une
branche conditionnelle, les effets d'un alias, les permissions ni le déploiement.

- Départ : 59 scripts, 947 fonctions avec mutation/appel SQL direct, quatre noms globaux en doublon.
- Après corrections et intégration #378 : 59 scripts, 942 fonctions de ce type, zéro doublon.
  La variation ne mesure pas une réduction du trafic ni le nombre de fonctions métier supprimées.
- Deux appels calculés restent explicitement non résolus : `queteAccueilRappel`
  et le lecteur paramétré de `sortirBatiment`. Ne pas les déclarer sans appel.
- Les compatibilités électorales sont conservées comme **délégations** ; l'ancien
  handler sans appel `confirmerCandidatureLegacy_MORT` est retiré. Aucun cache de joueur purgé.
- Les anciens helpers de `PORTES-HISTORIQUES-219-20261101.md`
  (`sbMilitaireSubtiliser`, `sbVendreFondsCommerce`, `sbCreerPlacementNational`,
  `sbTractAppliquerEffetPop`, `sbTractsReclamerDon`, `sbVendreMateriauxChantier`,
  `mouvementBoisAtelier`) ne sont plus définis dans les écrans actuels examinés.
  Leur présence dans un ancien rapport n'est pas un reliquat à réimplémenter.
- #250 : la voie `terrain_proprietaire_muter(...,'recompense_quete',...)` a déjà
  été fermée selon la trace de résolution du 30/10 ; le placement national utilise
  sa porte sécurisée. Aucun ancien droit n'est rouvert ici.
- #262/#282 : audits et relevés datés, non utilisés pour inventer un catalogue vivant.
  Le contrôle du dépôt est vert aujourd'hui ; une réextraction nouvelle doit
  reprendre `requetes.py`, `rendre.py`, `seeds.py`, jamais éditer le SQL généré.

### Reliquats confirmés dans le code, portée serveur à établir

| Chemin / preuve d'appel | Constat certain | Risque et suite préparée |
|---|---|---|
| `recupererVolsEnAttente` ← minuteur de démarrage dans `plateau-core.js` | Avec une ancienne ligne fictive argent, `arg` 100 → 75, liquide reste 100. Une sauvegarde rendue `null` est comptée comme réussie et le marquage est tenté. | Le relais du 31/10 rapporte table vide et UPDATE fermé ; **cela n'est pas un relevé vivant du 02/11**. Ne pas supprimer des enregistrements/compatibilités ou convertir leur argent sans lecture des agrégats et politiques. Prévol annexe prêt. Aucun ancien vol déclenché sur un PJ. |
| `confirmerSubtilisationExplosif` ← ordre routeur → bouton de confirmation | La fonction serveur fait l'acte, mais l'écran recalcule ensuite les PA depuis son ancienne copie. Fixture périmée 100 PA → 98 alors qu'une réalité à 10 PA moins 2 donnerait 8. Le GET inventaire omet également sa révision. | Risque de miroir périmé et de sauvegarde d'une copie erronée ; portée des protections serveur actuelles non relue. Le corps SQL archivé ne suffit pas à certifier le contrat vivant, la réception et la détention militaire. Pas de second moteur/sanction locale ajouté pour contourner le problème. |
| `confirmerRecrutementCodetenu` ← `openPnjModal` → `ouvrirRecrutementCodetenu` | Débit `arg`, tirages de caractéristiques et ajout à `state.employes` encore locaux. | Contrat/catalogue de recrutement PNJ vivant à vérifier avant raccordement. Transmis comme reliquat précis, sans modifier les PNJ/DeepSeek de Claude ni inventer de métier ou tarif. |
| `recupererImpactsEnAttente` ← chargement | Des indices sont encore modifiés localement sur les lignes d'attente. | Tous les impacts ne sont pas nécessairement des attaques anciennes. Lire les types/volumes et le contrat serveur avant de supprimer ce consommateur. L'agression immédiate livrée par #219 n'est pas réécrite. |

Le diagnostic reproductible `outils/audits/observer-compatibilites-135.cjs`
exécute les deux premiers corps avec des réponses fictives ; son code de sortie
**2** signale ces anomalies et ne constitue jamais un contrôle vert.

Ces reliquats ne sont **pas présentés comme corrigés**. Leur exposition au rôle
`authenticated` et les anciennes lignes réelles ne sont pas déduites des seuls
fichiers. Une correction serveur sûre exige ce constat ; aucune migration improvisée
n'est appliquée. Le prévol ne lit que métadonnées/empreintes et agrégats sans identité PJ.

## 4. Vérifications et preuves

Les résultats finaux et empreintes des journaux sont dans
`PREUVES-CLOTURE-TRANSVERSALE-135-20261102.json` et le dossier de preuves associé.

- **169 bancs clients**, contrôleur existant, fichiers de référence conservés.
- **118 tests du pilote/Chromium local**, pas 118 connexions réelles.
- **53 tests transversaux**, dont invariants organisation, écrivains serveur et
  contre-épreuve Authority après lot. Interpréteur Python avec pglast 17 requis.
- **12/12 contrôles globaux hors ligne**, dont Workflow, Authority et Referential.
  Reconstruction signifie ici assemblage/grammaire PG17, **pas nouveau clone du catalogue vivant**.
- **379/379 cas PostgreSQL natif 17.6, ICU en-US 153.121**, fixtures JWT et rôle
  `authenticated`. Les 141 transports/groupes en sont un sous-ensemble, ne pas additionner.
  Les portions committées du décor servent aux verrous concurrents ; la base entière
  est jetable et détruite. Le JSON conserve honnêtement `rollback: false` pour ce banc.
- Contre-épreuve PostgreSQL existante `--contre-tarif-collectif` : cinq assertions
  échouent sur 141 en réintroduisant le paiement d'un billet pour neuf voyageurs.
- Contre-épreuves ancien code : historiques 10 échecs/14 ; transports 11/16 ;
  renderer Chromium six scénarios + parent ; inventaire 4/10 ; rue avant #366 6/19.
  Aucun échec de contre-épreuve n'est compté comme réussite fonctionnelle.
- Syntaxe des scripts modifiés et analyse du prévol SQL en grammaire PostgreSQL 17.
  Prévol rangé dans `outils/bancs/`, transaction `READ ONLY` et `ROLLBACK` ;
  aucun ajout d'exception au contrôle de rangement.

Les premières passes ont correctement dénoncé des bancs ciblant les anciens noms
de vote, la convocation douanière locale supprimée et le GET inventaire sans révision.
Ils vérifient maintenant leurs portes canoniques, sans supprimer les scénarios.
Une première exécution transversale utilisait un Python sans pglast : corrigé par
l'environnement d'exécution existant, pas en neutralisant le test Authority.

## 5. Livrables, blocages externes et livraison

Commits de travail : `24816d56`, `793b7fdd`, `709cd7a0`, `32c5c126`,
`e4d0662d`, `0d6a9e7e` ; merges techniques `1e5de180` et `d7654c75`.
Les fichiers de preuve sont ajoutés après ce SHA de code, sans autre changement métier.

Création de PR réellement tentée après push avec un titre et corps préparés :
`POST https://api.github.com/graphql : Forbidden`. **Pas de numéro de PR inventé.**
L'intégrateur peut reprendre le corps versionné `PR-CLOTURE-TRANSVERSALE-135-20261102.md`
et [la comparaison de branche](https://github.com/FredJ74/res-publica/compare/main...codex/audit-transversal-cloture-135-20261102).
Les pages GitHub publiques ont permis la lecture des statuts, mais ne donnent pas
les journaux privés ni la possibilité de créer/relancer une livraison.

Actions préparées pour l'intégrateur, sans manipulations techniques demandées à Fred :

1. Ouvrir la PR depuis la branche poussée, lancer/observer les contrôles sur son SHA exact,
   relire les petits diff et confirmer l'absence de nouveau conflit avec main.
2. Lire `outils/bancs/PREFLIGHT-LECTURE-SEULE-135-20261102.sql` via le connecteur Supabase
   autorisé : registre actuel, fonctions/empreintes/EXECUTE, politiques et volumes anciens.
   Aucun outil Supabase n'est exposé dans cette session ; **prévol préparé, non exécuté**.
3. Résoudre les reliquats en fonction de ces lectures, coordonner le recrutement avec Claude.
   Aucun ancien droit ne doit être réaccordé pour rendre un test vert.
4. Après validation de livraison, fusionner le lot client/CI et vérifier le SHA servi
   et les scripts au cache neuf sur Vercel ; aucune migration de cette branche à appliquer.
5. Recette authentifiée autorisée, sans effets sur les PJ réels : position/F5 dans les
   trois villes, menus et refus de poste, document délivré retrouvé avec révision.
   Les paiements/douanes/combat utilisent d'abord les comptes isolés ; pas Arnie/Angie
   pour essayer une interception, dépense ou sanction. Ne pas étendre leurs autorisations.

**La clôture globale de Luthécia n'est pas certifiée par cette branche :** code et
preuves de régression sont livrables en revue ; comparaison SQL vivante, CI distante
du nouveau SHA, version Vercel servie et recette authentifiée restent à constater.
