# Groupes universels — reprise de #216 et #217, 28 octobre 2026

**CHANTIER NON TERMINÉ.** Préparation sauvegardée sur la branche #219 pour
l'intégration #230 par ChatGPT ; aucune fusion ni migration de production ici.
Les transports internationaux passent localement ; combats et interceptions
collectifs restent inachevés. Aucun nouveau développement immobilier après
l'arbitrage `main` 9e8901b : transmission à Claude documentée séparément.

## 29 octobre — sélection de combat et composition gelée

Préparation `20261029110000` à `20261029110300` : sélection canonique privée des membres présents/disponibles ; pas de valeur inventée pour les caractéristiques militaires absentes (leurs moteurs conservent leurs profils). Les portes de composition ne permettent plus de quitter/rejoindre/déposer/transmettre/rappeler pendant une confrontation existante ; verrous de graphe communs. Recrutement militaire distinguant service national et position physique, excluant les incapables/détenus/interceptés ou engagés ailleurs. Le combat policier réutilise la sélection pour contrôler l'état de l'acteur après lecture d'un éventuel reçu, avant les coups.

**200/200 PostgreSQL jetable** : 173 acquis plus sélection réelle 2 PJ/4 soldats/3 policiers, exclusions et non-participants, round militaire de deux camps dans le même pays avec rapports, deux vrais rounds policiers/rejeu après raccordement et concurrence de deux sessions. Contres : 7, 6 et 2 échecs respectivement en retirant les trois protections. Preuves `preuves-groupes-219-recrutement-20261029/`. Pas une recette Supabase.

**Toujours incomplet** : sélection disponible ne signifie pas résolution mixte universelle achevée. Les deux groupes d'une interception, le chef innocent avec recherché accompagnant, la reddition, la séparation à l'écrou, les anciens écrivains d'effectifs et les transports spéciaux demandent encore un raccordement. Aucune activation ou fusion. Aucun immobilier/PR225 touché.

## 29 octobre — miroirs institutionnels et transmission

L'arbitrage immobilier est transmis à Claude dans `TRANSMISSION-IMMOBILIER-CLAUDE-20261029.md` ; aucun nouveau développement immobilier. Le lot préparé `20261029100000` conserve morts, détenus et PA canoniques à travers les miroirs police/douane. Il reprend une seule fois les PA historiques valides, sans réimport au rejeu. Les rounds policiers existants enregistrent leurs dégâts dans le socle avant projection, sans second coup ni dépense additionnelle.

173/173 cas locaux passent ; sans correctif, six des mêmes 173 cas échouent. Les vrais corps historiques de police sont archivés avec SHA256 dans `fixtures/groupes-police-corps-git-20261028.json`. Les ACL du décor authenticated sont explicites : aucune preuve d'identité au catalogue vivant. Le banc n'établit pas encore le recrutement/combat mixte complet. Globaux 5/12, sans modification des références. Preuves : `preuves-groupes-219-miroirs-20261029/`.

Les anciennes écritures d'effectifs restent à fermer après raccordement de leurs ordres ; le lot ne doit pas être activé isolément. Les autres travaux de rounds mixtes, interception et transports spéciaux restent ouverts. ChatGPT organise #230, les prévols et la production.

## État le plus récent — 29 octobre, lot international

Le code étend les moteurs existants, sans deuxième déplacement, billetterie,
douane ou prison. PJ/PNJ réels du décor sont identifiés par le lecteur commun.
Passage douanier enregistré par le serveur pour chaque PJ ; un booléen du
navigateur ne peut autoriser l'embarquement. Le passage est annulé à la sortie.
Avion et bateau contrôlent de nouveau les objets avant paiement/déplacement,
avec annulation des nouvelles saisies/convocations si le paiement global échoue.
Les biens de quête protégés restent protégés. Les PNJ ne sont pas convoqués,
et leur payeur ne reçoit pas leur responsabilité judiciaire. Les étiquettes
historiques d'accessoires ne supplantent pas l'axe de possession déjà au socle.

Le leader paie tous les voyageurs, PA existants une seule fois : neuf voyageurs
= **2 700 FR/2 PA en avion**, **900 FR/5 PA en bateau**. Vol individuel et train
conservés. Le reçu empêche le double paiement. Le client relit les comptes,
la position et l'inventaire par les portes existantes ; aucun inventaire reconstruit.
La corruption conserve ses coûts/jets/détection et ne dispense que son auteur.
Son ancien appel sans reçu est refusé avant débit ; le client actuel transmet
un reçu, dont le rejeu ne répète pas le paiement ni le jet.

Les corps de confiscation et de justice sont factorisés en adaptateurs internes
privés ; droits/identité des portes publiques conservés. Des empreintes strictes
refusent une définition différente. **La version de confiscation de #213 et le
catalogue vivant doivent être rapprochés avant toute application.** Ne pas
prendre un corps Git pour une définition actuellement installée. La source
judiciaire provient de `bfae7cf0`, la source police retrouvée de `5c3a7743`.

Défaut de raccordement corrigé : l'ancien écrou posait la peine et laissait
l'écran terminer la position. Le serveur pose maintenant aussi la cellule,
QHS compris. Les anciennes portes d'auto-incarcération ne donnent pas un
transport vers une ville arbitraire ou par une peine nulle. Pas de sanction
fictive créée pour un joueur réel.

**167/167 scénarios PostgreSQL jetable**, dont 19 nouveaux après les 148 acquis.
Les nouveaux tests utilisent les vraies lois, saisies, jets, jugements, exécution,
écrou et transfert QHS. La justice fictive des anciennes contre-épreuves de
détection est renommée avant ces scénarios, pas réutilisée comme preuve.
Identités et données de décor seulement, rôle authenticated aux portes ; aucune
authentification Supabase réelle. Les deux actes fictifs déjà committés dans
pgserver pour les snapshots concurrents restent explicitement signalés.

**115/115 bancs client**, **105/105 pilote local**, **12/12 douanes client** et
**8/8 transport client** (comptes qui se recouvrent). Contre-épreuves sur la même
suite de 167 : un échec lorsque le passage du chef couvre un autre PJ ; trois
échecs sans les nouvelles positions/gardes carcérales. Aucun scénario désactivé.
SQL/YAML/JS analysés. CI existante raccordée à la chaîne complète ; résultats
GitHub de ce nouveau SHA non observés, pas assimilés aux six workflows antérieurs.

**Contrôles globaux : 5/12.** Sept familles rouges maintenues : classification,
fidélité du baseline, Authority, Referential, Fonctions, Assemblage, Reconstruction.
Authority compte 109 RPC absentes du baseline, pas 109 nouvelles failles ; deux
appels explicites préparés s'ajoutent au lot précédent. Le détail des écarts
historiques et les refus JavaScriptCore sont conservés dans les sorties brutes.
Aucun baseline, empreinte ou vérificateur modifié pour masquer un écart.

Preuves : `preuves-groupes-219-international-20261029/` et manifeste SHA-256.
Transmission immobilière : `TRANSMISSION-IMMOBILIER-CLAUDE-20261029.md`.

**NON TERMINÉ / NON DÉPLOYABLE en bloc.** Recrutement/rounds réellement mixtes,
interception du groupe entier, anciens écrivains et taxis particuliers restent
à traiter. Le miroir policier qui remet le statut actif, confirmé dans le prévol
#230, doit aussi être corrigé avant activation. Aucun personnage connecté dans
cette session. Accès aux commentaires GitHub refusé, Supabase non exposé ; les
prévols actualisés sont destinés à l'agent connecté, pas à Fred. ChatGPT garde
les applications, tests combinés, fusion et livraison. Ne pas appliquer un
sous-ensemble de ces migrations interdépendantes.

## Dernier complément — transports et accès particuliers après `8c2904dc`

La règle validée par Fred est raccordée aux transports intra-empire préparés :
**le leader paie le tarif existant multiplié par tous les voyageurs PJ et PNJ,
leader compris ; les PA de l'ordre ne sont pas multipliés**. Le serveur résout
les membres, garde leur disponibilité, contrôle la surcharge de chacun et
encaisse via le moteur existant, dans la transaction du déplacement. Aucun
paiement individuel supplémentaire, tarif client ou solde d'un passager exposé.

Le paiement public historique reste unitaire. Son identité et ses droits sont
conservés ; seules deux portes internes privées réutilisent le même corps.
Les signatures internes n'ont pas de paramètres par défaut ambigus. Le reçu
persisté évite un deuxième paiement après réponse perdue/concurrente. Le client
relit position et soldes actuels avant rendu ; il n'adopte pas les anciens soldes
d'un reçu. Prix affiché comme un tarif par voyageur, payeur nommé. Aucun timer.

Les accès aux bureaux d'ambassade utilisent le contrôle existant d'audience et
d'asile pour chaque PJ, avec la même identité publique. Les lots dynamiques sont
lus via `terrain_etat_lire`, sans second catalogue immobilier, et leur terrain
est verrouillé avant le groupe. Ces adaptations ciblées ne réécrivent pas les
travaux de Claude.

**141/141 scénarios PostgreSQL locaux**, incluant les 112 acquis. Deux PJ et sept
PNJ : train 675 FR/2 PA au seul leader ; bus 1 350 FR/1 PA. Billet individuel,
complément bancaire, refus faute de fonds pour tout le groupe, passager sans PA,
surcharge, prison, verrou concurrent réellement observé et rollback sur erreur
de projection sont éprouvés. Une sortie et un transport fictifs sont committés
uniquement dans PostgreSQL éphémère pour la visibilité après attente ; les autres
scénarios sont annulés. Rôle authenticated aux portes, aucun compte réel.
Contre-épreuve du tarif unique réintroduit : **5 échecs sur les mêmes 141 cas** ;
ce sont des régressions provoquées, pas cinq défauts historiques distincts.

**114/114 bancs clients**, **8/8 cas transport**, **105/105 pilote local**.
Grammaire SQL, YAML, syntaxe JS et Workflow conformes. Contrôle global : **5/12** ;
les sept familles rouges restent signalées. Authority compte 107 RPC absentes du
baseline, dont `transport_effectuer` préparée dans cette branche. Aucune référence
ou empreinte de contrôle ajustée. Preuves :
`preuves-groupes-219-transports-20261028/` (empreintes SHA-256 du contenu).

**Toujours NON TERMINÉ / NON DÉPLOYABLE.** Train/bus et accès particuliers ne
clôturent ni douanes/avion/bateau, ni taxis spéciaux, ni tous les écrivains de
position, ni le combat/interception universels. Le refus explicite des parcours
douaniers non raccordés est une garde de développement, pas une fonctionnalité
livrée. Les migrations restent préparées et interdépendantes ; aucun prévol
vivant exécuté, aucune fusion ou application Supabase, aucune recette réelle.
La tarification des PNJ n'est plus un arbitrage en attente.

## Reprise suivante — état le plus récent après `04efd8e5`

**CHANTIER NON TERMINÉ.** Ce complément prévaut sur les bilans historiques
suivants. Il ajoute du code et des tests ; il ne prétend pas clore les points
encore absents. Aucun accès ou solde réel utilisé/modifié.

### Terminé et vérifié localement

- **Parcours intérieur ordinaire** raccordé : deux PJ, quatre soldats prêtés et
  trois policiers font rue → hôtel → accueil → bar → restaurant → accueil →
  sortie → rue. Même moteur de composition/verrous que la rue, validation de
  tous avant mutation, garde commune de disponibilité et projections existantes.
  Échec de projection : rollback. Commandes concurrentes réellement bloquées
  puis annulées sur deux connexions ; aucune position partielle.
- Catalogue serveur technique de **284 bâtiments**, dérivé de `data.js`, sans
  modifier le contenu du jeu. Générateur et contrôle de conformité fournis.
  Superficies, prix, images et règles économiques ne sont pas modifiés.
- Contrôles existants d'adhésion à la loge et de visites de clinique, vérifiés
  pour tous les PJ ; un membre refusé bloque le groupe. Rencontre avec le
  portier conservée pour le seul demandeur concerné, pas aux frais d'un autre
  membre. Les restrictions d'embarquement et d'ambassade non raccordées sont
  refusées explicitement, jamais ouvertes sur une donnée du navigateur.
- **Anciennes sauvegardes de position** : garde sur la table canonique,
  neutralisant pays/ville/bâtiment/pièce/rue venant des PATCH généraux. Test
  via une vue au rôle authenticated, après mouvement collectif. Aucun corps
  de sauvegarde de fiche réécrit et aucun verrou d'inventaire ajouté. Payload,
  file différée et fermeture omettent les lieux après activation du contrat ;
  création initiale conserve son insertion normale. Le garde ne constitue pas
  encore une clôture des autres écrivains RPC/transport.
- Client : confirmation avant rendu, garde jusqu'au transport, double clic,
  réponses tardives, contrat incomplet refusé, perte de réponse réconciliée par
  lecture sans rejouer l'ordre. Les caches locaux ne vetoent plus le rendu
  d'une position confirmée. Activation annoncée par la lecture de groupe déjà
  faite au chargement, aucun timer ajouté.
- Lecteur privé commun `groupe_participants_interne(text)` : les neuf membres
  sont distingués par leurs clés PJ/PNJ, pas par des matricules ambigus ou un
  filtre métier. Navigation raccordée à ce lecteur. **Le combat ne l'utilise
  pas encore pour son recrutement complet.**

### Tests et contre-épreuves

**112/112 scénarios SQL** : les 86 acquis, les nouveaux parcours intérieurs,
le lecteur de participants et trois cas du moteur de rounds existant. Deux
rounds complets réellement exécutés par `militaire_bataille_poursuivre` sous
`authenticated` : deux PJ militaires, puis un PJ avec quatre vrais soldats
contre un PJ. Coups, rapports et PA réels du moteur archivé ; aucune substitution
de coup. ACL canoniques copiées et accès direct au helper interdit vérifié.
**Cela ne démontre pas le recrutement universel, les policiers, les douaniers,
la fuite ou la prison collective.** L'unique acte fictif committé reste celui
du scénario historique de snapshot ; les nouveaux actes sont annulés.

**113/113 bancs clients complets**, puis **13/13 tests ciblés** après la
conservation finale du portier ; **105/105 pilote local**. Aucune connexion de
joueur ni recette authentifiée. **23/109 contre-épreuves rouges** sans le
raccordement intérieur, comprenant des fonctions/contrats nouveaux absents :
pas 23 défauts historiques. SQL/YAML, tailles des migrations, générateur et
analyse des 23 API contrôlés. CI existante étendue, pas de nouveau pipeline.

**Globaux 5/12 :** Workflow vert ; sept familles rouges conservées. Authority
compte **106 RPC absentes du baseline** (dont la porte intérieure préparée),
quatre signatures antérieures et la garde d'identité du bail déjà signalée.
Referential/fonctions non mesurables sans JavaScriptCore ; classification,
fidélité, assemblage et reconstruction restent décrits dans le journal. Aucun
contrôle, résultat ni baseline modifié pour obtenir un feu vert.

### Migrations et dépendances

Après toutes les préparations précédentes de #219 :

1. `20261028185300_navigation_reference_commune.sql` : référence privée des lieux.
2. `20261028185301` à `20261028185305_navigation_lieux_reference.sql` : déclaration
   générée, découpée selon la limite de taille existante, vérifiable depuis data.js.
3. `20261028185500_navigation_interieure_validation.sql` : disponibilité et accès,
   garde de rue factorisée ; dépend des tables de bataille/fermeture, organisations
   et locations existantes.
4. `20261028185600_navigation_interieure_groupe.sql` : moteur de composition unique,
   portes de rue et pièce ; l'ancienne porte conserve ses droits.
5. `20261028185800_navigation_positions_sauvegardes.sql` : garde et annonce de capacité.
6. `20261028191900_groupes_participants_canoniques.sql` : lecteur partagé de membres.

**Aucune appliquée. Ne pas activer ce lot :** le garde général bloquerait encore
les déplacements légitimes de certains transports clients après leur paiement.
Il faut terminer leurs portes serveur avant toute livraison. La séquence a été
rejouée étape par étape sur base jetable, pas réappliquée à une production.

### Toujours non terminé — travaux de code, pas seulement accès

- Embarquement : `doPasserDouanesAeroport` conserve une autorisation locale
  `state.douanePassee` ; la future navigation ne doit pas lui faire confiance.
  Son passage doit être attesté par son circuit serveur, sans refaire les saisies.
- Bureaux d'ambassades : `ambassade_acces_bureau(text)` contrôle l'appelant.
  L'accès de chaque membre exige de réutiliser sa logique sans usurper son JWT,
  sans copier une autorisation du chef et sans remplacer le travail de Claude.
- Locaux dynamiques absents des déclarations statiques et transmissions de
  ville/pays : conserver leurs règles propres via leurs moteurs existants.
- Tous les écrivains de position RPC et transports : le garde distingue RPC et
  PATCH, mais n'atteste pas la sûreté de chaque écrivain RPC. Le recensement
  `POSITIONS-GROUPES-219-20261028.json` est volontairement limité aux sources
  disponibles et aux UPDATE directs, pas un inventaire vivant exhaustif.
- Recrutement de combats universels : le recruteur militaire demeure limité à
  ses combattants militaires ; le lecteur neuf ne l'a pas remplacé. Verrouillage
  de tous les participants et protections de round à compléter dans les portes
  existantes. Ne pas transformer les deux tests militaires réussis en preuve
  de tous les groupes mixtes.
- Interceptions : composition entière des forces et du recherché, identités
  inter-commissariats, fuite/reddition/round/prison toujours à raccorder ensemble.
  Les tests de calcul ou de lecture de groupe ne les rendent pas opérationnels.

### Accès, intégration et livraison

Une seule nouvelle tentative de lecture des commentaires #219 : **Forbidden**.
Aucun outil Supabase exposé. Le prévol versionné inclut maintenant navigation,
triggers et nouvelles versions ; l'agent connecté doit comparer les corps
vivants avant toute application, notamment les portes de position, d'accès
spécial et de combat/interception. Aucune manipulation ni aucun secret demandé
à Fred. L'absence d'accès ne masque pas les développements restants ci-dessus.

Branche conservée, PR #219 non fusionnée. Fetch final : main `c10c1083` toujours
ancêtre. Sauvegarde `04efd8e5` puis commit de ce complément ; preuves dans
`preuves-groupes-219-interieurs-20261028/`. Aucun inventaire, solde, ambassade
ou BNE modifié ; aucune migration ou opération de production. Éventuels Preview
et nouveaux résultats Actions non observés ; pas de lancement Vercel manuel.

**Conditions de livraison :** terminer les accès/transport/combats/interceptions,
tester leurs interactions et les reçus, recueillir le prévol vivant conforme,
réaliser la recette isolée authentifiée, puis seulement préparer une revue de
clôture. La PR ne doit pas être présentée comme prête à fusionner.

## État final de cette reprise — A à F

**CHANTIER NON TERMINÉ / NON DÉPLOYÉ.** Cette section remplace les constats
historiques suivants. Les obstacles de code restent distincts des accès manquants.

### A. Terminé et vérifié localement

- Portes communes et projections des vrais soldats, policiers et douaniers,
  autorité institutionnelle distincte du commandement ; prêt de quatre soldats
  à un commissaire et conduite avec trois policiers, droits de reprise préservés.
- Sortie et marche de deux PJ avec ces sept PNJ par le moteur de rue existant,
  dont le corps Git complet reproduit exactement l'empreinte communiquée.
  Tous les PJ sont validés avant mutation ; prison, interception, coma/hôpital,
  dispersion et itinéraires invalides bloquent sans mouvement partiel. Échec
  de projection : rollback total. Deux requêtes concurrentes ont réellement
  attendu le verrou ; la seconde reconnaît le mouvement déjà enregistré.
- Menu commun des unités distantes, sans leur inventer de bourse/possessions,
  reprise de l'ancre avec ses membres, radio et délégation via les portes
  existantes. Gardes de session/personnage transmises jusqu'au transport,
  y compris adhésion PJ et employés. Aucun polling ajouté.
- Défaut supplémentaire reproduit : ancienne rue projetée alors que le chef
  est dans une pièce. Correction dans le projecteur institutionnel commun,
  test avant/après conservé, aucun autre pouvoir municipal ou métier changé.

Résultats : **86/86 SQL**, incluant les 77 précédents ; **40/40 groupe client**,
**12/12 police**, **21/21 navigation**, **112/112 bancs clients**, **105/105 pilote
local**. Audit #216 **20/20** avec ses coups/justice simulés, donc distinct de
la preuve de calcul réel. La nouvelle suite utilise le détecteur historique
Git et le vrai coup + taux/degrés/dégâts militaires ; justice d'éligibilité
fictive. Ce n'est ni une authentification Supabase ni un round mixte complet.
Un seul acte fictif committé sur PostgreSQL éphémère pour observer le snapshot
concurrent ; aucune production. Les autres scénarios métier sont annulés.

Contre-épreuves : **12/77 rouges** sans le raccordement de rue ; **10/59 rouges**
sans le pont public. Certaines vérifient de nouveaux contrats absents, elles
ne représentent pas 22 bugs historiques. La présence fantôme est reproduite
séparément avant correction. Aucune attente ni empreinte globale affaiblie.

### B. Codé mais non déployé

Migrations `20261028180000`, `20261028180100`, `20261028183000` et leurs clients,
en complément des préparations précédentes. Le moteur privé de rue possède
une déclaration explicite, un prévol exact de la fonction remplacée et un
contrôle des deux définitions au rejeu. Cela élimine le faux inconnu de cette
création dynamique dans Authority sans modifier le contrôleur.
Le prévol de lecture seule inclut ces trois versions. Elles restent
interdépendantes ; aucune application individuelle n'est autorisée ici.

### C. Non terminé

1. Entrées dans les bâtiments et changements de pièces pour le groupe entier.
2. Protection de tous les anciens écrivains de position/sauvegardes périmées.
   `updated_at` est actualisé par le mouvement commun, mais ne constitue pas
   seul une protection complète de tous ces chemins. La fiche est laissée
   intacte pour ne pas écraser le chantier parallèle.
3. Recrutement de tous les PJ/PNJ mixtes dans les rounds et persistance commune
   de leurs conséquences. Le calcul réel du coup ne démontre pas ce branchement.
4. Groupe du recherché et groupe complet de la force intervenante. Le détecteur
   historique lit encore le registre du commissariat de la ville : il ne résout
   pas toutes les origines de policiers ni toutes les compositions canoniques.
   La fuite/le combat persistent encore certains PA par matricule local. Les
   collisions d'identités et les prêts entre services doivent être traités
   ensemble, puis la prison testée par la justice existante.
5. Recette authentifiée isolée, sur identités de test autorisées exclusivement.

Ce sont des travaux restant à coder et tester, pas uniquement une ouverture
Supabase. **Ne pas fusionner ni activer ces préparations en l'état.**

### D. Bloqué extérieurement

Aucun outil Supabase n'est exposé dans cette session. Les commentaires #219 sont
refusés par l'API GitHub ; Git fetch/push fonctionne. Le corps de rue est bien
retrouvé, donc son absence ne constitue plus un blocage local. Le détecteur
historique diffère de l'empreinte vivante précédemment communiquée : il ne vaut
pas relevé actuel. L'agent connecté devra exécuter le prévol de lecture seule
versionné, exporter les corps/ACL/RLS/triggers, comparer chaque précondition,
puis seulement envisager la recette et l'application de l'ensemble terminé.
Aucune manipulation SQL ou de secret n'est demandée à Fred.

### E. Anciens mécanismes

Deux auxiliaires sans référence des anciens sélecteurs policiers retirés
(`majSelectRoomsAffectation`, `PREFIXE_RUE_PAR_VILLE`). Les anciens points
publics de menu sont des adaptateurs des commandes communes. Miroirs et
projecteur militaire restent nécessaires et conservés. `state.group` reste
un miroir de présentation hydraté ; ne pas le confondre avec une position
serveur. Les anciens écrivains de position et recruteurs de combat ne sont
pas supprimés tant que leur remplacement complet n'est pas opérationnel.

### F. Intégration et déploiement

Branche unique `codex/groupes-universels-20261028`, PR #219 conservée. Sauvegardes
`e80efd80` puis `00b537f2`, suivies du commit contenant ce rapport et les preuves.
Fetch final : main `c10c10832b5bf6a7ee90895bc4160e2591782190`, déjà intégré et
préservé. Aucun changement aux inventaires, fiches/finances, ambassades ou BNE.
Aucune fusion, migration Supabase, authentification réelle ou livraison Vercel.
Les résultats distants Actions et le statut de revue ne sont pas observables ici.

**Globaux : 5/12**, Workflow vert. Sept rouges inchangés par catégorie :
classification 325/319 ; fidélité 21 écarts du relevé ; Authority (garde de bail,
quatre signatures antérieures et 105 RPC absentes du baseline) ; Referential et
fonctions sans JavaScriptCore ; assemblage et reconstruction avec leurs
incompatibilités/dépendances préexistantes. Ne pas retoucher le baseline pour
faire disparaître des RPC seulement préparées. Les preuves détaillées et les
empreintes des sources testées sont dans
`outils/audits/preuves-groupes-219-suite-20261028/MANIFESTE.json`.

## Dernier complément — rue collective et force publique

L'état historique ci-dessous est dépassé pour la projection police/douanes et
le déplacement en rue. `e80efd80` apporte leurs portes et projection : 59 cas
SQL et 12 contrats clients ciblés. Le corps Git authentique du moteur de rue a
ensuite été retrouvé et son MD5 de définition reproduit à l'identique du relevé
communiqué : `5e819694359c4bf2f11470c7f9f95ad8`.

`20261028183000_groupes_rue_transaction_commune.sql` prépare sa factorisation
privée et l'appel collectif, avec gardes, verrous, validation préalable de tous
les PJ et rollback des projections. Refus des définitions divergentes, y compris
au rejeu. 77 cas SQL passent (59 antérieurs + 18 nouveaux), dont deux PJ, quatre
soldats et trois policiers dans le vrai moteur de rue, refus prison/interception/
coma/hôpital/itinéraire, panne de projection, doubles commandes concurrentes et
réponse perdue. Un acte fictif est committé dans la base éphémère pour observer
le snapshot après attente ; les autres scénarios sont annulés. 21 cas navigation
client passent ; la garde de contexte atteint désormais le transport existant.

**Ce complément ne clôt pas le chantier.** Les anciens écrivains de position et
les entrées/pièces ne sont pas encore sécurisés pour les groupes ; les rounds
mixtes et l'interception collective restent à développer. Les sources historiques
de combat/détection archivées ne remplacent pas une nouvelle lecture de leurs
corps vivants. Aucun changement Supabase, joueur réel, fusion ou déploiement.

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
