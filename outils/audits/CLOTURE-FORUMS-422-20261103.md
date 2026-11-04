# Forums #422 — migration appliquée ; collecte canonique à recevoir

## Dernière reprise — capture privée annoncée, non reçue

Main `ea199d56` intégré dans `780db210` : #431, #432, #436 et #437 conservées,
aucun ancien moteur rétabli. Le conflit du seul banc prêts garde les assertions
de main et les cas de panne/refus (34 assertions). Version cache de supabase.js
majorée dans les deux pages. Les correctifs Forums restent raccordés à la même
source serveur. Aucun code financier, immobilier ou combat modifié par ce lot.

Vérifications réexécutées après main : **12/12 globaux, 191/191 clients,
119/119 Chromium, 92/92 transversaux, 25/25 PostgreSQL17.6**. Les anciennes policies
et l'ancien helper échouent réellement en contre-épreuves. Ces fixtures locales
ne certifient pas un clone fidèle au nouveau catalogue, ni une session PJ réelle.
La CI du prochain SHA reste à observer, pas déduite de `844d0f3d`.

### Verrou extérieur de transfert, solutions accessibles épuisées

Le dernier prompt annonce une collecte déjà réussie (403 tables,1449 fonctions,
252 policies,1190 migrations), dans l'instantané Vercel
`snap_VVIJobjaBuB1JmUk0KnbWfkzXRFQ` (expiration annoncée11/11). **Ces données et
empreintes sont des attentes transmises par l'intégrateur, pas une réception.**
Aucun catalogue complet ni fichier chiffré n'est publié ici.

Recherches locales effectuées : noms de capture/manifeste, fichiers cryptographiques
liés à #422 et fichiers des deux tailles annoncées, dans /workspace et /tmp.
Aucun trouvé ; aucune récupération active. `gpg` est installé mais aucune clé
privée ni GNUPGHOME n'est disponible. Aucun outil Supabase/Vercel, CLI Vercel,
jeton ou configuration d'authentification sur les emplacements usuels. Les outils
exposés ne permettent pas de restaurer un instantané Vercel. L'identifiant seul
ne fournit ni URL privée ni autorisation ; aucune restauration fictive tentée.
Supabase direct n'a pas de jeton ni de canal authentifié disponible. Aucun
contournement par une ancienne capture, un rôle anonyme ou une fonction de joueur.

**Unique action nécessaire : ChatGPT intégrateur transmet le JSON existant déjà
déchiffré en pièce jointe privée** (5 639 402 octets ; SHA256
`054043e74e8f50dbfcff6f42cc224bf7f547953779126c73cfd1a162305af954`).
Cela évite la transmission d'une clé et une nouvelle collecte inutile. Le manifeste
original `hg422_capture_manifest.json` n'est pas reconstitué artificiellement :
les attentes sont consignées séparément dans le MANIFESTE du paquet de réception.
Si un autre snapshot est fourni, sa provenance et son SHA indépendant doivent
l'accompagner ; jamais remplacer une empreinte pour le faire accepter.

Après réception : SHA/taille, validateur existant et matérialisation privée, rendu
canonique, seeds autorisés, diff intégral, empreintes, registre et contrôles.
La migration Forums demeure **déjà appliquée sous `20261104001711`** ; ne pas la
rejouer. Aucune nouvelle migration ni donnée PJ touchée dans cette reprise.
Baseline de production non régénéré, fusion non effectuée, Vercel READY et recette
authentifiée non vérifiés. Le paquet de réception précédent reste fonctionnel.

---

## État courant — 04/11, après application par l'intégrateur

**La migration n'est plus à appliquer.** Version réelle `20261104001711`, nom
`forums_territoires_et_adhesions`. Confirmation publique lue dans le commentaire
[6618966376](https://github.com/FredJ74/res-publica/pull/422#issuecomment-6618966376).
MD5 lecture `8c3942ad7d820a9533bb54a5111c87a2`, publication
`536c0751b6cddf32381dcac7a8cbd581` ; huit policies et contrôles sans JWT confirmés
par ChatGPT. Ce sont des vérifications de l'intégrateur, pas des appels Supabase
exécutés par Codex. Ne pas renommer/rejouer le fichier Git. Les mentions « non
appliquée » plus bas décrivent les étapes historiques et sont désormais dépassées.

**Priorité bloquante avant fusion : les quatre exports actuels n'ont pas encore
été reçus.** Aucun SQL du baseline n'a été modifié à la main ; aucune nouvelle
réextraction ni régénération complète des seeds revendiquée. Les résultats12/12
hors ligne ne prouvent pas que ce baseline ancien contient les dernières RPC.

Main #430 puis `bcdbe141` intégrés. #428 a été fusionnée indépendamment par
l’intégrateur pendant cette reprise ; aucun import séparé de sa branche. Ses
corrections et le CRON financier restent identiques à main. Les12 contrôles relancés après réconciliation passent. Les191/119/88 et
25+25 tests précédents restent acquis, pas rejoués sans changement des moteurs.
Cinq CI vertes réellement observées sur `59d4fe6b` ; CI du prochain SHA à vérifier.

### Handoff immédiatement exploitable par ChatGPT

Ouvrir `outils/bancs/collecte-forums422/README.md` et **récupérer les quatre exports
canoniques** via le connecteur, avec `outils/bancs/COLLECTE-FORUMS422-capture_atomique.sql` de préférence. Il
réutilise le collecteur existant et les SELECT exacts de `requetes.py`, le contrôle,
le registre et les seeds authored autorisés. Les quatre SELECT séparés sont aussi
fournis, tailles et SHA256 dans `MANIFESTE.json`. Aucun secret ni donnée privée
reçu n'est dans ce paquet public. Les résultats doivent être transmis en privé,
hors Git, complets, avec SHA256 indépendant calculé à la source.

Le validateur existant est renforcé pour comparer comptes et empreinte des ACL au
contrôle global du même snapshot, séquences comprises. Tests : un GRANT réel sur
une séquence est exporté ; retrait d'une ligne, falsification du compteur et perte
d'un privilège à nombre égal sont tous refusés. **24/24 tests sous PostgreSQL17.6
et16.2**, héritant des contre-épreuves du collecteur (lecture seule, snapshots
mélangés, seeds privés, intégrité, interdiction de sortie dans Git).

La réception produit les quatre JSON et fichiers de contrôle/provenance pour les
générateurs existants ; aucun nouveau moteur d'extraction/reconstruction. Le
collecteur existant ne prend que dix tables authored : ne pas régénérer tous les
seeds à partir d'un sous-ensemble en déclarant les autres frais. Émettre la requête
`seeds.py --sql` depuis les exports reçus, relire sa surface et collecter le
contenu autorisé nécessaire (ou provenance explicite des seeds conservés).

Ensuite rendre, régénérer, classer les objets nouveaux si nécessaire, contrôler
et expliquer tout le diff, archiver uniquement les migrations réellement reprises
dans le baseline selon registre par nom. Aucun écrasement d'attente depuis le
résultat rendu. Réconcilier main, certifier le SHA et CI, fusionner, observer READY,
SHA et ressources servies, puis lectures authentifiées isolées. Aucune mutation
sur un vrai PJ pour fabriquer les scénarios voyage/exclusion. Le mode d'emploi
donne les commandes exactes pour les agents et les critères de recette.

**État B de la mission : intervention de ChatGPT intégrateur indispensable pour
l'acquisition des exports ; tout le dispositif est préparé, aucun SQL à demander
au game designer.** Pas d'accès Supabase exposé ici ; pas de fusion ni déploiement
annoncé. Les traces antérieures sont conservées ci-dessous.

---

Branche existante `chatgpt/forums-territoires-et-adhesions-20261103` conservée.
Base réconciliée : main `fbed5ced` (#423), après `4c657b53` (#410). Fusions de travail `2a2ad0e4` puis `5ef8dd5a`.
Corrections : `92242533`, `0c03d2f6`. Aucune fusion ni migration de production.

## Changements

Les corrections initiales `332e64cf` et antérieures sont conservées. Le forum
national et les locaux sont filtrés par pays ; seul le local de la ville actuelle
est proposé. Les organisations du catalogue ne donnent plus un accès privé sans
adhésion ou direction. Les identifiants historiques restent compatibles avec les
publications officielles.

Les réponses de sujets, messages, compteurs et activité sont maintenant liées à
l'identité, la session, la position et l'adhésion. Les caches locaux sont renouvelés
à l'aller et au retour ; les caches privés et leurs voyants sont purgés lors d'une
perte d'accès. Un lien direct non préchargé est résolu en lecture serveur puis via le même chargeur ; il ne suppose plus le forum local courant. Quatre contre-épreuves échouent sur `0ca1a6a0`, puis passent sur le correctif. Une réponse vide confirmée ne conserve plus d'anciens messages. Le
délai de lecture est libéré et une ancienne requête ne déverrouille pas la suivante.

L'ouverture et les accès directs par l'interface relisent les organisations avec
le chargeur existant, en mode `lectureSeule`. Ce mode ne lance ni élections ni
ordre métier ; son fonctionnement normal reste testé et inchangé. Aucun nouveau
sondage périodique n'est ajouté.

La RLS couvre SELECT/INSERT/UPDATE/DELETE des sujets et réponses. La migration
refuse RLS inactive, politique permissive supplémentaire ou définition inconnue.
Une organisation malformée ferme son accès, sans panne globale. Les institutions,
la presse, l'international et le sport conservent leurs règles existantes.

## Compatibilité #410

La publication de #410 est SECURITY DEFINER : la RLS seule ne la contrôle pas.
La migration #422 adapte **uniquement ses autorisations** à la même fonction
canonique de lecture : chef, adhérent, territoire, accès direct au sujet. Chef
absent de la liste des membres et membres représentés par un nom simple restent
pris en charge, y compris une réponse privée depuis un autre pays.

La dépendance à `forum_publication_jauges_interne(text,uuid,jsonb)` est explicite.
Son corps examiné ou notre patch sont les seuls acceptés. Aucun ancien corps n'est
restauré. Le banc compare le bloc d'écriture/récompense au source de main : il
reste identique. **Aucune formule ou écriture POP/INF n'est modifiée.**

## Preuves

Voir `preuves-forums422-20261103/MANIFESTE.json` et les fichiers hachés.

- PostgreSQL natif 17.6 : **25/25** ; PostgreSQL16.2 : **25/25**.
- Tables, vue `personnages`, identité et politiques réelles du baseline, rôles
  authenticated/anon et JWT fictifs. Chaque scénario est annulé ; cluster détruit.
  Ce décor ne constitue pas une reconstruction du catalogue vivant.
- **21/21** cas de contexte client ; **19/19** cas territoriaux initiaux.
- Contrôleur complet après installation des dépendances de main : **188/188 bancs**.
  Une première passe sans PGlite avait quatre erreurs d'environnement ; elles ont
  été réparées par `npm ci`, sans modifier les bancs POP/INF de Claude.
- Chromium local complet : **119/119**, dont rendu réel du local et du forum privé.
  Aucune connexion à un personnage réel et aucun appel Supabase de production.
- Contre-épreuves : anciennes politiques permissives détectées ; ancien helper
  refusant le chef détecté ; ancien client réintroduisant des caches détecté.
- Les cinq jobs CI de la tête initiale `332e64cf` ont été observés terminés sans
  échec. La CI de la tête finale doit être relevée séparément, jamais déduite
  des résultats locaux ni de celle d'un ancien SHA.

## Échecs préexistants, non masqués

Contrôle global : **8/12**, aussi bien sur cette branche que sur main #410 isolé.
Baseline et Referential : miroir `ordres_couts` non régénéré/déclaration de source
périmée ; Authority : signature historique `couvre_feu_patrouille()` ; Fonctions :
ancien miroir client de succession supprimé et corps client d'indice modifié.
Aucune référence, observation ou empreinte n'a été ajustée pour masquer ces écarts.

Transversaux : **99/100** sur la branche ET main #410 isolé. Le contrôle
`test-organisations-ecritures-inventaire.mjs` attend encore
`sbGreveGeneraleSynchroniser(ggId)` dans `confirmerAppelGreveGenerale`, qui utilise
maintenant les commandes de grève serveur. Ce mécanisme de Claude n'est pas
réécrit par ce chantier. Les traces des deux exécutions sont conservées.

## Livraison restant impossible depuis cette session

Aucun outil Supabase `execute_sql`/`apply_migration` n'est exposé. Le prévol
historique de ChatGPT, annulé en transaction, n'est pas une certification de
l'état actuel. Aucun secret n'a été demandé ou extrait pour contourner ce manque.
La tentative HTTP publique Vercel est refusée par le proxy HTTPS (403). Aucun
statut READY ni fonctionnement authentifié en production n'a été observé.

La PR reste en brouillon. Ne pas la fusionner sur la seule foi de ses bancs verts.

## Ordre de reprise pour l'intégrateur disposant des accès

1. Exécuter via le canal technique le prévol en lecture seule
   `outils/bancs/PREFLIGHT-FORUMS-422-LECTURE-SEULE.sql`. Confirmer registre par NOM,
   dépendances #410, corps du helper, rôles/BYPASSRLS, politiques et déclencheurs.
   Une autre définition ou politique exige une relecture ; ne pas forcer le hash.
2. Vérifier le SHA courant, sa CI complète et les échecs transversaux hérités ;
   résoudre ceux qui bloquent la promotion, sans exemption ni suppression de test.
3. Après certification réelle, appliquer au registre la seule migration
   `20261103222000_forums_territoires_et_adhesions.sql`, sauf si elle est déjà
   enregistrée. Elle ne met à jour aucune ligne de PJ, organisation ou message.
   Prendre les définitions/politiques antérieures hors Git. Tout échec DDL doit
   annuler la transaction entière ; ne pas rouvrir les lectures publiques pour
   contourner une panne après déploiement.
4. Relever les catalogues, régénérer avec les outils existants le baseline et les
   seeds, contrôler le diff et les contrôles. Aucun SQL généré ne s'édite à la main.
5. Fusionner seulement après les garde-fous ; vérifier le SHA servi et Vercel READY.
   Recette authentifiée en consultation : aller/retour de ville, changement de
   pays, chef/adhérent/non-adhérent, accès direct sujets/réponses, voyants et comptes.
   Aucune modification de finances, caractéristiques, possessions ou identité PJ.

Aucune manipulation SQL ni commande n'est à déléguer au game designer.

## Dernière réconciliation #423

Les corrections commerciales de `fbed5ced` sont conservées intégralement. Le seul
conflit de workflow a été résolu en gardant les deux étapes. Après intégration :
188/188 bancs clients, 119/119 Chromium, 14/14 cas Montrouge explicites, 25/25
PostgreSQL17.6 et16.2 (table REST et appel RPC sous leurs chemins respectifs).
Les quatre contrôles globaux restent rouges ; leurs traces sont conservées, sans
autoriser une fusion. Aucun code POP/INF ni fichier immobilier n'a été modifié
par les corrections forum. Le dernier SHA publié et ses jobs CI sont consultables
sur la PR #422 ; cette preuve distante complète les observations locales.

## Reprise du 04/11 — remplace les anciens résultats rouges ci-dessus

Main `d2617483` intégré dans `5643ea93` : #424 football, #425/#427 portraits,
#426 hôtels/ambassade conservés ; conflits uniquement RELAIS et versions HTML.
Aucune modification des formules POP/INF, du code immobilier ni des données PJ.

Les douze contrôles **exécutés** passent désormais (traces intégrales dans
`preuves-forums422-20261104/`, manifeste SHA256). Ils restent des contrôles hors
ligne : « reconstruction » vérifie ici la grammaire, pas un clone de production.

- Baseline : le générateur existant `regenerer-seeds-miroirs.py` a régénéré le seed
  `95_a-regenerer/ordres_couts.sql` et son inventaire. Aucun SQL édité manuellement.
- Referential : nouvelle empreinte **source** mesurée avec le générateur réel ;
  `reelle`, `posee`, nombre de lignes et date de capture production inchangés.
  Les divergences historiques source/base restent déclarées et visibles.
- Authority : les signatures exactes créées par une migration précédente sont
  désormais reconnues comme dépendances préparées, jamais comme déployées.
  Tests : aucun nom inventé par commentaire/DO/schema étranger/surcharge.
- Fonctions : ancien écrivain d'indices supprimé par #404, préservé par #410.
  Après revue, nouvelle empreinte client épinglée et test exécutable : aucun
  effet Republia, repli legacy borné inchangé. Contre-épreuve du vrai ancien corps
  `45ed2833^` rouge. Serveur et formules inchangés.
- Workflow : deux migrations de main partageaient `20261104002000`.
  Le fichier football est renommé **sans changer un octet SQL** selon la version
  appliquée `20261103232759`, consignée par l'intégrateur dans RELAIS (#424).
  Ce renommage n'autorise aucune réapplication ; vérifier le registre par nom.
- Transversaux : test de grève adapté aux portes serveur #410 ; adoption et
  recalcul locaux doivent rester absents. Aucun ancien moteur restauré.
  Le contrôleur de routage reconnaît les exclusions inconditionnelles réellement
  présentes dans `allOrders`, par AST. Tests négatifs : filtre retiré, conditionnel,
  autre liste ou commentaire ne masquent jamais un ordre. Aucune règle modifiée.

Résultats : **12/12 globaux, 191/191 bancs clients, 119/119 Chromium,
88/88 tests transversaux, 25/25 SQL PostgreSQL17.6 et 25/25 PostgreSQL16.2**.
Contre-épreuves SQL : anciennes politiques => 11 échecs, ancienne publication =>
1 échec ; jamais comptés comme succès fonctionnels. Dépendance historique du test
d'indice figée en fixture de source (pas de `git show` en CI shallow).

### Coordination de livraison — à exécuter par ChatGPT, pas par Fred

Prévol communiqué par l'intégrateur (non exécuté ici) : RLS activée, politiques
historiques permissives, helper #410 `md5(prosrc)=2a6b4d5f8c468aa12504c2cbf39def54`,
migration #422 non enregistrée lors du relevé. Ce constat n'est pas une preuve
d'application. Aucun outil Supabase disponible ici ; GitHub API et Vercel HTTP
restent refusés par le proxy403 (preuves `acces.json`). Git push fonctionne.

Ordre exact :
1. Sur le SHA courant certifié CI, prévol
   `outils/bancs/PREFLIGHT-FORUMS-422-LECTURE-SEULE.sql` via connecteur ChatGPT.
   Relever registre actuel, déclencheurs, ACL et politiques ; sauvegarder leurs
   définitions hors dépôt avant toute application.
2. Si toujours absente et conforme, appliquer via `apply_migration` le fichier
   `migrations/20261103222000_forums_territoires_et_adhesions.sql` (SHA256 dans le
   manifeste). Transaction unique ; aucun contournement des gardes. Ne pas rejouer
   football/portraits ni aucune autre migration de main.
3. Vérifier **version et nom réellement attribués par le registre**, fonction et
   huit politiques installées ; relever les quatre exports canoniques et régénérer
   baseline/seeds avec les outils documentés du workflow, examiner le diff.
4. Sortir #422 de brouillon et fusionner après vérifications de la tête et CI,
   puis observer Vercel READY et le SHA/ressources réellement servis.
5. Recette authentifiée isolée : pays/villes, aller-retour, chef/membre/tiers,
   révocation, liens sujets/réponses directs, compteurs et anciens messages.
   Les écritures à effets restent réservées aux fixtures, aucun PJ réel modifié.

Pas de migration ni fusion #422 exécutée ici ; pas de READY ni recette production
revendiqués. Les obstacles de canal ne sont pas un abandon : le lot exact est prêt
pour l'intégrateur autorisé. La CI du prochain SHA doit être observée séparément.

CI `5fda5c62` : quatre jobs verts ; cinquième arrêté sur la référence de chemin SQL football dans le workflow, restée à l’ancien horodatage. Chemin corrigé et commandes exactes (banc puis parser SQL) rejouées localement ; le prochain SHA doit être observé. Aucun résultat CI rouge présenté comme vert.

## Suivi CI du paquet de collecte, après main #430

`61b994ca` : quatre CI vertes, cohérence échoue dans les bancs JavaScript.
Reproduction locale précise : `banc-prets-bancaires.js` simulait encore un PATCH
`arg/liquide`, alors que #430 appelle le moteur financier serveur. Le test détecte
maintenant la commande RPC **et** l'ancien PATCH (qui reste interdit), vérifie
l'absence de débit avant revendication, le rejeu et le gel. Refus/panne du moteur
ne doivent pas diminuer la dette ; le remboursement utilise le montant confirmé.
**33/33 assertions ciblées ; contre-épreuve de l'ancien CRON `d2617483` : 9 échecs
attendus sur33.** Aucun code du moteur, du CRON ou des règles financières modifié.
Contrôleur complet relancé ; résultats finaux/CI à observer avant promotion.

## Réconciliation finale de main #428, fusionnée indépendamment

Pendant la recette, main est passé à `bcdbe141` (PR #428 fusionnée par intégrateur).
Fusion sans conflit, code catalogue/routeur/data/CRON identique à main, aucune
nouvelle implémentation de commerce. Les cinq tests du catalogue existants
passent, 33/33 prêts et 24/24 collecte passent ; globaux12/12 relancés. Le
contrôleur complet avait fini191/191 avant cette nouvelle arrivée ; sa CI doit
maintenant couvrir aussi le banc ajouté par main. Seed miroir monde neuf et
empreinte **source** régénérés par les outils après le changement de data.js ;
aucune observation historique de production ni tarif du plan97 modifié.

Les exports vivants restent absents : le baseline et les seeds de production
n'ont donc pas été réextraits. Le seul input encore indispensable est la capture
privée issue de `outils/bancs/COLLECTE-FORUMS422-capture_atomique.sql`, à récupérer
par ChatGPT intégrateur. Ne pas demander une nouvelle application de #422.
