# Groupes universels — reprise de #216 et #217, 28 octobre 2026

**CHANTIER NON TERMINÉ.** Trois lots de corrections sont codés, testés localement et
sauvegardés. Aucun groupe universel n'est annoncé en production. Les déplacements
collectifs des PJ et les combats de groupes mixtes restent à raccorder au serveur.

## Reprise de la PR #219 — état le plus récent

**Cette section remplace l'état historique ci-dessous pour les soldats et leurs
interfaces. Le chantier global reste NON TERMINÉ et NON DÉPLOYÉ.**

Branche conservée, PR #219 existante (aucune nouvelle PR tentée). Départ `cb3957fe`,
commits supplémentaires `e46ea788`, `d5c7c327`, `c1b18f0a`, intégration du main
`c10c10832b5bf6a7ee90895bc4160e2591782190` au merge `3c464794`.
Le seul conflit concernait le relais : les notes des deux agents sont conservées.
Le transport REST, la création de personnage et les bancs de sortie de ChatGPT
ne sont pas remplacés par les versions antérieures de la branche. Cache remonté.

### TERMINÉ ET VÉRIFIÉ SUR POSTGRESQL JETABLE / FIXTURES

- Prise, prêt, dépose et rappel de **quatre véritables soldats** de
  `pnj_soldats_metier`, sous autorité du véritable résolveur de section
  `militaire_autorite_de_perimetre`. Leur chef emprunteur porte le poste
  `commissaire` dans la fiche fictive. Après dépose il ne peut pas les reprendre ;
  le lieutenant conserve ce droit. Aucun employé renommé en soldat.
- Projection transactionnelle par **`militaire_blob_projeter` existant**, et
  vrai déclencheur `pnj_miroir_compagnie_trg` conservé. Position des ancrages/rues
  projetée ; représentation des suiveurs PJ compatible avec la contrainte
  `pnj_position_deux_etats`. Pas de désactivation de hiérarchie ni de miroir.
- Verrou de compagnie avant PJ/PNJ, observé sur deux connexions. Les helpers
  de projection ne sont exécutables ni par anon, authenticated, ni service_role.
- Une panne de projection annule la prise dans sa totalité. Rappel de l'unité
  entière et rejeu sans objet ni droit créé ; métadonnées et propriété préservées.
- `militaire_deposer_soldats`, `militaire_recuperer_soldats`,
  `militaire_affecter_leader` restent les adaptateurs des interfaces par nombre,
  mais délèguent désormais les actes aux portes communes, au lieu de réécrire
  les positions eux-mêmes. La garde de section existante est conservée ; la
  restriction du destinataire à un soldat de la même section, contradictoire
  avec la décision universelle, est retirée au profit des contrôles communs.
- Reprise d'une ancre seule : refus nommé `unite_incomplete`, sans mutation ni
  exception de contrainte ; reprise de l'unité complète par nombre testée.
- L'interface de conduite lit les capacités et droits serveur : dépose du
  membre commandé, reprise/prêt sous autorité administrative, rappel d'une
  ancre. Soldat non activé tant que la capacité serveur n'est pas confirmée.
  Double clic bloqué ; anciennes sessions/personnages et lectures de panneau
  périmées ignorés. Une réponse perdue déclenche une lecture, jamais un rejeu.
- Défaut reproductible de **la porte militaire de combat archivée** : sa requête
  utilisait `c.data->>'pays'` alors que seul `pnj_membres m` y est défini. Patch
  ciblé vers `m.pays`, sans changer le prédicat de guerre. Test du vrai corps
  sans ennemi et du refus non-militaire, **pas un round collectif réussi**.

### CODÉ MAIS NON DÉPLOYÉ

Quatre migrations supplémentaires :

1. `20261028161732_groupes_soldats_projection_commune.sql` : verrou/projection
   dans les cinq portes PNJ, réutilisation du projecteur, ouverture de la seule
   restriction métier soldat contredite par les décisions de Fred.
2. `20261028163800_groupes_capacite_conduite_serveur.sql` : capacités et droit
   d'administration dans la projection de présence existante.
3. `20261028164500_groupes_ordres_militaires_adaptateurs.sql` : anciens ordres
   par nombre et reprise d'ancre. Refuse tout corps vivant différent de
   l'ancien corps archivé ou du nouveau corps exact. Empreintes de `prosrc`
   dérivées des sources testées, aucune empreinte globale retouchée.
4. `20261028165000_groupes_bataille_pays_adverse.sql` : correction de l'alias
   de pays adverse de la porte existante.

Appliquer uniquement après les migrations déjà préparées et après prévol complet,
**pas maintenant** : les raccordements essentiels du groupe universel manquent.
Les neuf étapes antérieures ne sont pas prétendues installées. Aucune version
Supabase appliquée ou estampillée ici. La comparaison au catalogue doit aussi
écarter un patch déjà présent ou une définition désormais différente.

### Résultats finaux de cette reprise

- **49/49 SQL** : 35 précédents + 9 militaires + 2 diagnostics policiers +
  2 contrôles de porte de combat + 1 refus de dérive de définition.
  Les deux diagnostics policiers n'indiquent PAS que leur déplacement fonctionne.
- **27/27 contrats clients ciblés** ; **111/111 bancs clients complets** après
  le nouveau main, dont les trois bancs de ChatGPT ; **105/105 pilote local**.
- Protections d'interception #216 : **19/19** ; variante concurrence **20/20**
  avec un acte fictif committé dans le serveur éphémère seulement ; **35/35**
  interception côté client avec réponses simulées.
- Contre-épreuve `--contre-soldats` : les nouvelles attentes militaires et le
  défaut d'alias échouent avant le raccordement. Les absences de nouveaux
  contrats ne sont pas comptées comme des bugs historiques. Code de sortie
  d'échec conservé, aucun test neutralisé.
- Quatre nouveaux SQL analysés par PostgreSQL (`pglast`), taille <12 500 chacun,
  rejeu des étapes testé ; YAML et API contrôlés. Workflow existant réutilisé,
  le banc étendu remplace son invocation précédente pour éviter de le doubler.
- **Contrôles globaux : 5/12**, mêmes sept rouges. Authority conserve 103
  écarts RPC au baseline ; les quatre préparations PJ/radio ne sont pas
  déclarées déployées. Referential/fonctions : JavaScriptCore absent ;
  classification/fidélité/assemblage/reconstruction restent rouges.
  Aucun vérificateur ni baseline modifié.

Toutes les identités et données de scénario sont fictives. Les véritables tables,
contraintes, résolveurs, corps et triggers sont utilisés sur un PostgreSQL jetable.
Le décor local est committé pour les connexions concurrentes ; les actions testées
sont annulées. Aucune authentification Supabase réelle, aucun mouvement/solde réel.
Les tests d'interception hérités simulent les coups et la justice ; les nouveaux
cas de porte militaire ne les remplacent pas par une fausse preuve de rounds.

### NON TERMINÉ

- Déplacement collectif de PJ, validation commune de tous les membres et
  protection de tous les anciens écrivains de position : aucun raccordement
  sûr au moteur vivant n'a pu être codé sans son corps complet.
- Groupe simultané **quatre soldats + trois policiers**, police et douanes dans
  les mêmes portes, projections/anciens ordres de placement à raccorder ensemble.
- Combat collectif PJ/PNJ non militaires, recrutement des bons participants
  dans les rounds et interception du groupe du recherché. Ne pas utiliser le
  correctif d'alias comme preuve de ces fonctions.
- Recette authentifiée et vérification de prison/radio/déplacements en jeu.

Les vrais policiers de deux commissariats ont été construits dans leurs tables
et miroirs réels. Le résolveur territorial est vérifié. Le test reproduit aussi
l'échec de `pnj_miroir_police` avec un suiveur : il tente de recopier une position
fixe incompatible avec le lien de suivi et la contrainte échoue. **Cette preuve
est celle d'un raccordement absent, pas d'un policier déplacé avec succès.**
Lever la garde institutionnelle seule rendrait donc le socle incohérent. Les
anciens boutons policiers écrivent encore le blob ; les changer partiellement
sans le détecteur et les portes de déplacement ne constituerait pas un socle
universel sûr. Les règles douanières et la PR #215 ne sont pas réécrites.

### BLOQUÉ EXTÉRIEUREMENT

Aucun outil Supabase exposé. Lecture des commentaires #219 tentée par GraphQL et
par GET REST `/repos/FredJ74/res-publica/issues/219/comments` : **Forbidden** dans
les deux cas ; aucune autre tentative ni contournement. Push Git fonctionnel.

Le MD5 `5e819694359c4bf2f11470c7f9f95ad8`, fourni par Fred, ne donne pas le corps
complet de `rue_position_enregistrer`. Une recherche dans les worktrees et les
fichiers SQL/JSON/MD accessibles a retrouvé une ancienne enveloppe **préparée**
`20261021120231_rue_garde_realites.sql` dans un ancien checkout : elle délègue à un
moteur non fourni. Elle n'est pas importée comme définition vivante. Les derniers
rapports de ChatGPT sur main décrivent les gardes mais ne fournissent pas non
plus les corps complets. Aucun moteur manquant n'est inventé pour faire un test.

**Opération technique précise restante pour l'agent disposant du connecteur :**
exécuter en lecture seule `outils/bancs/PREFLIGHT-GROUPES-UNIVERSELS-20261028.sql`
et `PREFLIGHT-AUDIT-SECURITE-135.sql`, puis verser les résultats complets versionnés
sur la branche de #219. Le premier export inclut la définition complète, les empreintes distinctes du
corps et de la définition, les droits, triggers et les quatre versions nouvelles.
Il faut notamment les corps de `rue_position_enregistrer`, de son/ses écrivains
sur la fiche, de `police_detection_verifier`, des RPC d'interception et des miroirs.
Cette opération est une collecte, pas une application de migration. Aucune
manipulation SQL ou de secret n'est demandée au game designer.

### ANCIENS MÉCANISMES

- Trois écritures de mouvement des anciens ordres militaires sont remplacées par
  les appels aux portes existantes. Les noms d'ordres et interfaces par nombre
  restent utilisables ; pas de deuxième moteur.
- Le projecteur et le miroir militaires restent nécessaires et sont testés,
  pas supprimés. La sélection par grade et les groupes de bataille ne sont pas
  transformés arbitrairement en un nouveau combat.
- `state.group` reste une projection ; l'adhésion n'est pas restaurée comme une
  autorité locale. Les autres vieux calculs et placements encore actifs ne sont
  pas supprimés avant leur remplacement effectif. Nettoyage global non achevé.

**Pas de fusion, pas de migration Supabase, pas de déploiement en production
engagé par Codex.** Les éventuelles Preview automatiques de la branche ne sont
pas observées et ne sont pas prises pour une validation du jeu. Aucun inventaire,
solde, authentification, ambassade ou BNE modifié par ces nouveaux lots.

---

## Base et périmètre

Branche `codex/groupes-universels-20261028`, créée depuis #217
`c85d36d53a3419d4f2bbabbffc32a01ed36f0664`, qui contient #216. Intégration du main
`3a9b0c5d5f09901e310358f91165ec78ba1de0d1`, correction été/hiver conservée.
Les branches des autres agents ne sont ni réécrites ni fusionnées. #212 ne doit
pas être fusionnée telle quelle. L'inventaire #213 reste à Claude.

Lecture des consignes, constitution, architecture, relais, audit « une seule
vérité », workflow Supabase, règles privées et règles universelles de #217.
Les arbitrages du prompt de Fred du 28/10 gouvernent cette reprise, notamment
la séparation autorité/commandement/appartenance et la portée radio même ville.

Le relevé vivant de ChatGPT dans `PREVOL-VIVANT-SECURITE-135-20261028.md` est une
source documentaire : ses empreintes ne sont pas un accès de Codex au catalogue,
ni les corps complets du détecteur et des gardes de déplacement. Aucun outil
Supabase n'est exposé dans cette session. Aucun mot de passe recherché.

## Corrections effectuées

### Adhésion PJ et navigateur

- Même verrou transactionnel de graphe pour adhésion et départ ; acteurs
  verrouillés dans un ordre stable. La précédente clé fondée sur le seul minimum
  des deux noms ne sérialisait pas tous les changements d'un même graphe.
- Co-présence selon le lieu réel : à l'intérieur, la rue antérieure ne décide
  pas ; dans la rue, une ancienne pièce ne décide pas et un nœud est obligatoire.
- L'adhésion ne reçoit que le chef désiré : elle ne peut imposer de membre tiers.
  Refus des chefs déjà membres et du départ d'un chef vers un autre groupe tant
  qu'il conduit des membres. Un départ du chef sépare les adhésions sans déplacer
  les personnages et sans choisir arbitrairement un successeur.
- Les commandes rendent directement l'appartenance serveur (`contrat: 1`).
  Pas de seconde lecture nécessaire pour annoncer un succès.
- Hydratation via le chargement existant `sbLoadPersonnage`, uniquement pour la
  fiche du compte courant. Aucun groupe local restauré comme vérité serveur.
- Double clic bloqué ; réponses d'un autre personnage ou d'une autre session
  ignorées ; lectures anciennes invalidées par une commande ultérieure.
- Réponse perdue : relecture de l'appartenance sans rejouer l'ordre ni annoncer
  une réussite incertaine. Les quatre appels RPC restent littéraux et visibles
  par le contrôleur d'autorité ; aucune alerte masquée par un appel dynamique.

**Limite :** la table d'adhésion est héritée de la préparation #217. La migration
rappelle explicitement qu'il faut d'abord vérifier dans le catalogue vivant
l'absence d'une relation équivalente. Aucun CREATE en production ici.

### PNJ : dépose, reprise et prêt

Les portes existantes `pnj_quitter_groupe`, `pnj_prendre`, `pnj_transferer` sont
corrigées ; aucune nouvelle autorité ni second moteur n'est introduit.

- Validation de toute la sélection avant mutation, identifiants inconnus,
  doublons et membres inactifs refusés ; verrous ordonnés.
- Position de tous les membres figée avant la séparation d'une ancre ; rue
  matérialisée et conservée après dépose. Le déclencheur anti-sous-hiérarchie
  reste actif pendant tous les tests.
- Prêt : l'autorité administrative d'origine reste nécessaire ; le commandement
  ne permet pas de sous-prêter. Aucun propriétaire modifié. Un chef temporaire
  peut laisser le PNJ qu'il conduit, mais ne peut le reprendre après séparation.
- Pays et rue du destinataire contrôlés en plus de ville/bâtiment/pièce.
  L'administrateur doit aussi être présent pour le prêt ordinaire.
- Une ancre ne peut être transférée en laissant derrière elle une sous-hiérarchie
  interdite. La séparation commune prépare le transfert de l'unité complète.
- Les anciens boutons employés « laisser »/« récupérer » n'écrivent plus
  immédiatement `inGroupe`. Ils utilisent les RPC communes et relisent
  `employe_mes_employes`. Cette projection reçoit la position effective via un
  patch ciblé, pour éviter de reconstruire le lieu depuis un cache périmé.

### Radio et unités privées

- L'unité entière est verrouillée puis revalidée, y compris autorité sur chaque
  PNJ, statut, position effective et gardes de famille/métier communes.
- Équipements réels dans l'inventaire et `pnj_possessions`, quantités invalides
  ou nulles non acceptées ; possessions verrouillées. Aucun objet créé/consommé.
- Même ville et même pays obligatoires. Une autorité répartie entre responsables
  entraîne un refus global si l'appelant ne dispose pas de tous les droits.
- L'unité entière rejoint le même chef ; l'ancienne hiérarchie au sol est
  matérialisée avant aplatissement, sans désactiver la contrainte commune.
- Un second rappel après perte de réponse reconnaît l'ancre déjà portée. Il ne
  prétend pas retrouver les anciens membres depuis des liens déjà dissous :
  l'écran relit la projection des employés, pas seulement l'ancre.
- Le patch de portée de `militaire_ordre_collectif` est testé sur son vrai corps
  archivé pour les refus avant effet ; son rejeu reconnaît la garde exacte,
  pas simplement la présence du mot `radio_hors_ville`.
- Les agents privés portés par le même chef réel appartiennent à la même unité.
  Les PNJ portés par deux PJ qui ont effectivement adhéré au même groupe se
  raccordent à ce chef. Deux responsables seulement co-présents restent distincts.
  Aucune nouvelle colonne ou identité de détachement.

Les protections S1–S6 de #216 sont conservées. Le journal des participants d'une
interception reste une photographie d'engagement, pas une seconde appartenance.

## Vérifications exécutées

| Vérification | Résultat et limite |
|---|---|
| Nouveau banc PostgreSQL | **35/35**, actions annulées, base locale jetable |
| Contre-épreuve #217 | **18 cas échouent / 35**, code de sortie 1 conservé ; ils incluent des contrats ajoutés, ce ne sont pas « 18 bugs historiques » |
| Contrats navigateur groupes | **22/22**, réponses simulées, fonctions réelles extraites par Acorn |
| Contrôleur client complet | **108/108** ; Chromium et serveurs locaux autorisés hors sandbox restrictive |
| Pilote local existant | **105/105**, fixtures, aucun joueur connecté |
| Interception client | **35/35**, réponses simulées |
| Audit PostgreSQL #216 | **19/19** ; vrais corps archivés, identité/coups/justice simulés |
| Concurrence PA #216 | **20/20**, variante avec un acte fictif committé uniquement dans PostgreSQL jetable |
| Contre-épreuve #212 | **8 échecs / 19** attendus, code de sortie 1 conservé |
| SQL préparé | Grammaire PostgreSQL et limite de transport des neuf fichiers #217/compléments vérifiées ; patches disponibles rejoués deux fois |
| API/YAML | 23 API analysées ; workflow existant analysé et complété d'un seul banc SQL |
| Baseline et contrôles | Aucun fichier de baseline ni vérificateur modifié |
| Supabase / Vercel / jeu authentifié | **Non exécutés**, aucun accès effectif dans cette session |

Le nouveau banc utilise des schémas minimaux, les vraies fonctions PNJ, cinq
contraintes et le déclencheur anti-sous-hiérarchie du dépôt. Les RPC sont appelées
au rôle `authenticated` avec `/rpc/<fonction>` ; l'identité JWT est une fixture.
Les helpers internes sont testés comme helpers, pas présentés comme RPC publiques.
Le test de suivi PNJ vérifie une position dérivée après modification fictive du
chef, **pas un déplacement collectif PJ via la porte réelle de production**.
La concurrence d'adhésion observe le verrou de la seconde connexion dans
`pg_stat_activity` avant l'annulation de la première ; ce n'est pas une campagne
authentifiée distante. Le nouveau banc ne prétend pas tester le moteur de combat.

Un premier lancement dans la sandbox a refusé les sockets locales ; le contrôleur
et le pilote ont été relancés avec les permissions locales nécessaires. Les
échecs initiaux ne sont pas maquillés. Les contrôles globaux ont aussi été relancés
avec `pglast` installé, après le premier refus dû à cette dépendance manquante.

### Contrôles globaux : rouges conservés

**5/12 passent**, sur main comme sur la branche. Les sept échecs sont :
classification, fidélité du baseline, Authority, Referential, concordance des
fonctions, assemblage, reconstruction. Comparaison brute des deux sorties archivée.

- Classification : 325 tables classées pour 319 attendues.
- Baseline : intégrité des fichiers conforme, 21 divergences avec le relevé global
  versionné (notamment 320 tables contre 314 attendues). Ce relevé n'est pas une
  interrogation actuelle de Supabase.
- Authority : main signale 99 écarts RPC ; cette branche **103**. Les quatre noms
  supplémentaires sont `groupe_pj_rejoindre`, `groupe_pj_quitter`, `groupe_pj_lire`,
  `pnj_rappeler_radio`, préparés mais absents du baseline. Un invariant d'identité
  et quatre signatures préparées inconnues sont également déjà rouges sur main.
- Referential et fonctions : les vérificateurs exigent JavaScriptCore, absent ici.
  Ils s'abstiennent ; les bancs Node ne valent pas un résultat de ces contrôles.
- Assemblage : `fermeture_definir_date_universelle` et `permis_depot_archive_proteger` absentes du baseline ;
  reconstruction : deux dépendances manquantes et six attentes non satisfaites,
  sans refus de grammaire.

Ces points restent ouverts. Pas de correction de données/empreintes pour les
faire disparaître ; pas de refonte des chantiers de Claude.

## Ce qui empêche encore la clôture

1. **Catalogue vivant** : exporter les corps/ACL/triggers des fonctions avec
   `PREFLIGHT-GROUPES-UNIVERSELS-20261028.sql` et le prévol #216. Le rapport #217
   fournit des empreintes mais pas les définitions complètes requises. Vérifier
   l'absence de relation PJ équivalente avant la nouvelle table.
2. **Déplacement des PJ** : le corps vivant `rue_position_enregistrer` n'est pas
   disponible dans le dépôt. `deplacement_enregistrer` du baseline écrit un
   historique, pas la position. Le substituer serait un faux raccordement.
   Il reste à appeler les validations communes pour tous les membres avant
   toute mutation et à verrouiller les écritures des anciennes sauvegardes.
   Pas de trigger de téléportation qui contournerait coma, police ou prison.
3. **Police/douanes** : `pnj_miroir_police` recopie encore les positions du blob
   `effectifsPolice` vers le socle. L'axe `position_leader` reste institutionnel.
   Lever seulement la garde créerait deux vérités ou une violation de contrainte
   au prochain miroir. Aucun producteur de patrouille universelle n'est démontré.
4. **Soldats et projections** : leur position est au socle, mais le mouvement
   individuel est encore fermé et les ordres militaires projettent les blobs
   via `militaire_blob_projeter`. La nouvelle règle autorise les groupes mixtes ;
   il faut raccorder ces écrivains et projections ensemble, pas supprimer une
   garde isolément. Le scénario lieutenant→commissaire avec vrais soldats et
   policiers n'est **pas** couvert par un test d'employés renommés.
5. **Combat collectif/interception** : `militaire_bataille_recruter` recrute des
   militaires ; `militaire_bataille_combattants` lit les PNJ via
   `pnj_soldats_metier`. Les rounds existent, mais les entrées non militaires
   et le groupe du recherché restent à raccorder à ces moteurs et au véritable
   détecteur. Pas de nouveau moteur ni barème inventé, pas de fausse incarcération.
6. **Recette authentifiée** : aucun personnage connecté ici. Aucun combat réel,
   déplacement collectif PJ, prison, radio militaire complète ou jeu rechargé
   n'est déclaré vérifié en production. Pas d'usage d'Arnie hors autorisation.

Les points 2–5 sont des raccordements **encore inachevés**, pas de simples tests
à cocher après déploiement. L'absence du catalogue interdit de choisir aveuglément
une seconde persistance ou de modifier ces protections vivantes. Aucun arbitrage
de game design supplémentaire n'est demandé.

## Migrations, intégration et nettoyage

Ne pas appliquer ces fichiers séparément. Ordre préparé : les trois étapes #216,
puis les cinq migrations #217 `122000` à `124000`, puis `135642`, `135643`, `140626`,
`141500`. Les quatre dernières renforcent les portes/projections existantes.
Même après prévol, les raccordements restants doivent être terminés et testés
avant une activation cohérente ; cet ordre ne constitue **pas** un feu vert.
Après application autorisée, registre, réextraction générée et workflow complet
restent obligatoires. Aucun estampillage d'application fictif.

Nettoyage final différé conformément à la mission : `state.group`, les moyennes
clientes, les menus militaires par nombre, la restriction individuelle soldat,
les projections policières/douanières et les groupes de bataille sont des points
à inventorier. Plusieurs sont encore actifs ; aucun n'est supprimé sous prétexte
d'être ancien avant que son remplacement soit opérationnel. Les groupes de
bataille gardent leur fonction d'engagement ; ils ne deviennent pas la persistance
du groupe de rue.

Commits de code poussés : `e0e03084`, `84e2dad7`, `b404cf38` (plus la finalisation
et les preuves). Branche autonome, **aucune fusion, aucune migration appliquée,
aucun déploiement ni donnée réelle modifiée**. GitHub GraphQL refuse la lecture de
PR ; la création en brouillon a été tentée une seule fois après le push `01acc471` :
**GraphQL Forbidden**, aucune PR créée par Codex. Les PR #212,
#216 et #217 ne sont pas modifiées par cette session.
