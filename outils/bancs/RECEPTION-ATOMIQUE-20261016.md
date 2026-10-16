# Réception atomique des objets — préparation du 16 octobre 2026

**Préparation locale testée et destinée à `main`. NON DÉPLOYÉE sur Supabase.**
Départ : `4307890586761154391f6cce21bf77527919a680`. Aucun accès Supabase exposé,
aucune donnée personnelle consultée et aucun personnage réel utilisé comme fixture.
La migration d'achat est déjà appliquée et vérifiée **selon les informations
transmises dans cette mission** : elle n'a pas été rejouée en production.
Son fichier et le baseline n'ont pas été modifiés.

## Dépendance de déploiement immédiate

La nouvelle réception n'utilise jamais le repli « DELETE puis ajout local ».
**Après déploiement de ce client, tant que la migration ci-dessous n'est pas
appliquée, les livraisons restent en file et le jeu indique réception indisponible.**
Il faut coordonner le déploiement client/SQL ; cette préparation n'est pas annoncée
comme une réception opérationnelle en production. Aucune purge ni fausse confirmation.

La migration à examiner puis déployer séparément par l'agent autorisé est :

[`migrations/20261016131932_reception_objets_atomique.sql`](../../migrations/20261016131932_reception_objets_atomique.sql).

**Elle n'a pas été appliquée à Supabase dans cette mission.** Aucun SQL ni script
n'est demandé au game designer. La phase d'application reste expressément hors mission.

## 1. Audit des circuits et des écrivains

| Circuit | Chemin existant et traitement préparé |
|---|---|
| Achats commerce PJ | `acheter_produit_commerce` livre dans `objets_recus`. Le débit corrigé en production n'est pas modifié. La réception utilise l'objet complet stocké dans la file. |
| Achats directs, stocks, matières, usine | Plusieurs RPC écrivent directement l'inventaire réel. Elles restent en place ; le déclencheur incrémente la révision et le client garde la provenance de leurs retours. |
| Dons entre personnages | `inventaire_donner` et les dépôts existants alimentent la même file. Pas de nouveau circuit d'émission ou de retrait chez le donneur. |
| Vols | Le dépôt confirmé du butin reste le producteur existant. Seule la collecte du destinataire est remplacée. Les étapes antérieures retrait/dépôt ne sont pas certifiées atomiques par cette mission. |
| Tracts reçus | Les identifiants `don-tracts-*` suivent la fusion historique par type, cible, variante, légalité et absence d'origine de quête ; quantités dans `quantite`. Plus de suppression autonome par `tracts_reclamer_don` depuis le client après migration. |
| Documents | Les documents en file utilisent la transaction ; ceux insérés directement par les RPC officielles restent sur leur circuit et bénéficient de la révision. Le contenu n'est pas reconstruit depuis le catalogue. |
| Cartes postales | Objet complet conservé ; notification et journal génériques, sans expéditeur ni contenu du courrier. Aucun gain de moral ajouté à la réception. |
| Aliments, chocolat | Conservation notamment de `familleProduitMarche`, `dateAchat`, provenance et données annexes. Une consommation par le vrai helper SQL archivé est testée après réception. |
| Objets individualisés | Ajout de l'objet intégral, notamment `exemplaire.id`, encombrement et champs de quête. |
| Objets empilables | Premier lot de même `stackKey`, comme `addToInventory` ; seule sa quantité augmente, ses autres métadonnées restent celles du lot existant. Un nouveau lot conserve tous les champs entrants. |
| Quêtes | Champs conservés, tracts de quête exclus de la fusion ordinaire ; protection du colis secret vérifiée par le helper historique de sortie. Les ajouts locaux existants passent par la sauvegarde avec révision quand le contrat est actif. |

L'outil [`auditer-ecrivains-inventaire.py`](../auditer-ecrivains-inventaire.py)
produit [`ECRIVAINS-INVENTAIRE-20261016.json`](ECRIVAINS-INVENTAIRE-20261016.json) :
**29 fonctions et 33 affectations d'inventaire dans les sources du baseline**, avec
les positions des verrous à lire et les points client. C'est une cartographie
textuelle du code archivé, pas une certification exhaustive du serveur vivant.
Les lectures de snapshots repérées utilisent des verrous de personnage, parfois
via la vue et parfois sur la table ; un `FOR UPDATE` trouvé ailleurs dans une
fonction ne prouve pas, seul, le verrou correct. La vue et son trigger, les RPC,
les versions plus récentes, le SQL dynamique et les Edge Functions doivent être
confrontés au catalogue réel avant application.

Les réécritures complètes client étaient principalement `sbSavePersonnage`, la
sauvegarde de fermeture et les adoptions de retours RPC/lectures dans les modules
personnage, divers, communication, commerce, politique, justice-économie,
actions illégales et effort de guerre. Le résultat des mêmes transports reste
compatible ; seule l'adoption d'un ancien inventaire est désormais refusée.

## 2. Transaction et identité stable de livraison

La migration ajoute :

- `personnages_donnees.inventory_revision`, compteur serveur ;
- `objets_recus.reception_token`, UUID propre à chaque entrée en file, et son unicité ;
- `inventaire_livraisons_recues`, reçu durable minimal : jeton, ancien identifiant,
  destinataire et date. Aucun contenu d'objet supplémentaire recopié ; aucun accès direct client ;
- un déclencheur sur la table réelle et trois RPC sécurisées.

Les identifiants de file ne sont pas supposés uniques pour toute l'histoire du
jeu : après suppression, une future livraison peut réutiliser le même `id`.
Le **jeton** distingue ces incarnations. Une ancienne demande perdue revient sur
son reçu, sans toucher une nouvelle livraison portant le même identifiant.
Un INSERT ignoré par `ON CONFLICT(id) DO NOTHING` conserve le jeton de la livraison
encore présente. Les livraisons déjà en attente reçoivent un jeton lors de la
migration ; elles ne sont ni supprimées ni modifiées dans leur contenu.

`inventaire_reclamer_livraison(text,text,uuid,bigint)` :

1. Vérifie `auth.uid()`, appelle la garde existante `exiger_acteur` et vérifie aussi
   explicitement `personnages_donnees.user_id` pour le nom demandé.
2. Verrouille la vraie ligne du personnage, puis l'entrée de file correspondante.
3. Vérifie destinataire, jeton et révision ; une répétition déjà confirmée retourne
   l'inventaire actuel avec `rejeu=true`, sans nouvel ajout.
4. Décode `data` JSON objet ou JSONB contenant une chaîne JSON ; un format inconnu
   échoue sans purger la file.
5. Reproduit les règles de fusion existantes et permet la surcharge. Ne réutilise
   pas `inventaire_ajouter` pour construire un objet au risque de perdre ses champs.
6. Met à jour l'inventaire et sa révision, inscrit le reçu et supprime la livraison
   **dans la même transaction PostgreSQL**. Une exception annule les quatre effets.
7. Retourne inventaire, révision, statut de rejeu et informations nécessaires aux
   notifications, sous l'identité autorisée.

Les fonctions nouvelles ont `SECURITY DEFINER`, `search_path=public,pg_temp`,
EXECUTE réservé à `authenticated`, et un contrôle d'acteur effectif. Le trigger
n'est pas appelable par le client. Le registre de reçus a RLS et aucun privilège
client direct. Les anciens DELETE de file et l'ancienne RPC suppressive de tracts
sont révoqués pour PUBLIC/anon/authenticated ; la migration vérifie que le rôle
joueur n'en conserve pas un accès par héritage. Les producteurs existants ne
changent pas de droits d'insertion.

## 3. Empêcher qu'une ancienne fiche efface la réception

`inventaire_revision_garder`, placé en dernier BEFORE UPDATE de la table réelle,
augmente la révision à chaque modification d'inventaire, y compris par les anciens
écrivains serveur. Il ignore une révision imposée par un payload.

Pour un rôle PostgREST client (`anon`/`authenticated`) hors route `/rpc/…`,
le trigger conserve l'inventaire réel : un ancien PATCH de fiche ne peut plus
publier son inventaire périmé, même à travers le trigger INSTEAD OF de la vue.
Les autres champs de cette fiche gardent leur circuit existant. Les anciennes
RPC qui écrivent via la vue restent compatibles sous leur contexte RPC.

**Précondition réelle à vérifier :** `request.path` et `role` sont les GUC
PostgREST attendus, fournis par le serveur. Ce ne sont pas des en-têtes client.
Les tests locaux émulent ces GUC, ils ne testent pas un vrai PostgREST/Supabase.
Si le contexte attendu n'est pas reconnu et que l'écriture n'est pas réalisée,
la fonction de réception lève une exception avant de supprimer la livraison.

Les ajouts/modifications locaux legacy sont sauvegardés par
`inventaire_sauver_revision(text,bigint,jsonb)`, sous verrou et à révision égale.
Un snapshot différent avec une révision ancienne est refusé, jamais rajeuni.
Un inventaire déjà exactement égal est un no-op. Cela conserve le circuit legacy
d'ajouts locaux ; ce n'est pas une nouvelle validation métier de tous les objets.
Les contrôles métier de sortie existants restent dans leurs RPC.

Dans `sbEnfilerEcriturePersonnage`, la révision est capturée avec le snapshot
avant toute attente. Quand le contrat est actif, l'inventaire est exclu du PATCH
générique et de la sauvegarde de fermeture. Un ancien retour RPC sans révision
ne peut pas autoriser une sauvegarde complète : le client attend une nouvelle
lecture cohérente avant de réécrire l'inventaire.

Une seconde course a été traitée : un retour ancien pouvait être reçu, puis
adopté **après** une réception récente. Les transports annotent les retours
d'inventaire d'une provenance locale (personnage, session, compte et génération).
L'adopteur partagé vérifie cette provenance **au point de mutation**. Le symbole
est conservé par spread mais n'est jamais sérialisé vers le serveur. Les points
d'adoption hérités utilisent cet adopteur ; les retours périmés sont écartés.
La comparaison des inventaires ignore l'ordre des clés JSON.

## 4. Raccordement client et conflits

`verifierObjetsRecus` conserve les gardes d'identité/session et le verrou de poll.
Il relit l'état autoritaire, préserve les ajouts locaux non encore sauvés, puis
réclame les couples ID/jeton avec la révision courante. Il adopte le résultat
serveur ; il n'ajoute plus l'objet localement et ne sauvegarde plus la réception
par un second acte. Les notifications historiques restent distinctes pour les
tracts et les cartes postales.

Si le client a évolué pendant une attente, le retour ne remplace pas ses nouvelles
modifications. Si le serveur et les modifications locales ont divergé, il signale
un conflit et ne devine pas une fusion. Une livraison **déjà confirmée** demeure
sur le serveur ; celles qui ne sont pas encore réclamées restent en file.

**Limite volontaire :** les modifications locales non confirmées ne sont pas un
inventaire serveur validé. Un conflit peut nécessiter une resynchronisation ; les
changements non sauvés ne sont ni fusionnés ni déclarés acquis. Une fermeture
avant leur sauvegarde n'est pas réparée par cette mission. Les effets économiques
ou l'émission d'un don/vol encore legacy ne deviennent pas atomiques par cette
réception. Aucun tarif, quantité de gameplay ou règle de consommation modifié.

## 5. Preuves et limites des tests

[`banc-reception-atomique-local.py`](banc-reception-atomique-local.py) n'accepte
aucun DSN externe. Il démarre son PostgreSQL jetable, applique la vraie migration,
la rejoue, charge des vrais helpers SQL archivés, puis utilise uniquement Alice,
Bob et des objets de fixture. `auth.uid()` est une fixture, pas un JWT Supabase.
Les contrôles d'acteur/consommation/destruction/localisation/protection chargés
sont ceux des sources archivées. Le trigger INSTEAD OF du test est une fixture
reproduisant le transfert vers la table réelle, pas le corps vivant certifié.

**31 groupes de scénarios PostgreSQL réussis**, dont :

- Réception normale et répétition ; même ID réutilisé par une nouvelle livraison.
- JSON objet et JSON encodé en chaîne, documents et métadonnées complets.
- Empilement, quantité de tracts, exclusion des tracts de quête, objets individualisés.
- Aliments/chocolat, consommation fraîche et PA historiques, cartes postales, objet
  de quête protégé contre destruction par la vraie fonction archivée.
- Inventaire plein (100 → 101) et empilement dépassant le plafond.
- Autre destinataire, autre UID et absence de UID refusés ; exécution sous rôle
  `authenticated` et refus des anciennes réclamations.
- Rollback avant commit ; erreur après insertion mais avant suppression : aucun
  changement d'inventaire, de révision ou de reçu n'est conservé.
- Commit suivi d'une réponse perdue ; rejeu sans second ajout.
- Deux connexions sur la même livraison ; deux livraisons distinctes avec conflit
  de révision puis reprise explicite, sans perte.
- Ancienne sauvegarde CAS refusée ; ancien PATCH direct ou à travers une vue avec
  trigger SECURITY DEFINER conservant la réception ; révision falsifiée ignorée.
- Compatibilité avec `inventaire_detruire`, `inventaire_consommer`,
  `inventaire_localiser`, `inventaire_place_restante`, `inventaire_ajouter` et les
  helpers de sortie/protection existants.
- Trigger AFTER incompatible : état persistant relu après déclencheurs, postcondition
  refusée et rollback intégral. Format inconnu conservé en file, schéma/definition
  inconnus refusés au déploiement.

**20 tests client de réception** couvrent notamment changements de personnage,
compte et session, poll concurrent, réponse perdue, ajouts locaux avant/pendant
réception, conflits, confidentialité, tract, snapshot de révision, fermeture,
adoption tardive et égalité JSON indépendante de l'ordre des clés.

Validation globale : **68/68 bancs**, 2 193 épreuves historiques et 261 tests Node ;
**90/90 contre-épreuves**. Les tests existants ne sont pas désactivés. Le banc de
transport REST charge les nouveaux helpers réels dont dépend son extraction.
Le workflow CI ajoute le PostgreSQL de réception, sans secret de production.

Les 12 contrôles locaux du workflow ont le même bilan : **9 verts, 3 rouges** :
tractage collectif absent du baseline, référentiels déjà divergents (dont 17/18
ressources), prix Journal 109 divergences contre 103 déclarées. Rien n'a été
retouché pour les masquer. Le baseline n'a été ni édité ni régénéré.

Résultats détaillés : [`VERIFICATIONS-RECEPTION-20261016.json`](VERIFICATIONS-RECEPTION-20261016.json).
Aucun parcours authentifié réel, aucune lecture Supabase réelle et aucune migration
appliquée dans cette session. Résultat distant GitHub Actions non observé.

## 6. Avant le déploiement séparé, par l'agent autorisé

1. Exécuter les lectures de catalogue de `banc-reception-contrat-lecture.sql`, sans
   lire les données personnelles : vue, triggers, corps/signatures, ACL, héritages,
   contraintes, colonnes et écrivains d'inventaire. Vérifier les versions réelles,
   y compris les fonctions plus récentes et les éventuelles écritures dynamiques.
2. Confirmer les comportements PostgREST/GUC sur un environnement isolé authentifié,
   et les droits SELECT de file et RPC. Ne pas considérer les observations partielles
   fournies comme une validation complète RLS. Vérifier les types/defaults attendus.
3. Confirmer l'ordre de verrouillage des écrivains vivants. Les nouveaux actes font
   personnage → livraison ; aucune ligne d'un autre personnage n'est verrouillée.
4. Suivre `WORKFLOW-SUPABASE.md` : empreintes pertinentes avant/après, application
   enregistrée de **cette seule migration nouvelle**, vérification du registre,
   fonctions/triggers/droits, puis réextraction réglementaire par les outils.
   Ne pas rejouer la migration d'achat déjà appliquée ni l'histoire.
5. Vérifier les parcours authentifiés avec fixtures autorisées, le rechargement,
   deux onglets et les reçus réseau perdus. Pas d'achat ni de poste de joueur réel.

La migration vérifie schéma, types, unicités, versions exactes des fonctions
nouvelles déjà présentes, marqueurs de colonnes/table, ordre et forme du trigger,
ainsi que révocation des anciens accès. Une définition différente la fait échouer,
pas une adaptation automatique. Ces gardes ne remplacent pas les contrôles réels
ci-dessus. Aucun test métier n'est exécuté depuis la migration.

## 7. Fichiers et commits

Fichiers de production : `supabase.js`, `plateau-communication.js`,
`plateau-divers.js`, `plateau-commerce-pj.js`, `plateau-personnage.js`,
`plateau-politique.js`, `plateau-justice-economie.js`,
`plateau-actions-illegales-rumeurs.js`, `plateau-effort-guerre.js` et `plateau.html`.

Outillage : `.github/workflows/coherence-client.yml`, la migration citée plus haut,
`outils/auditer-ecrivains-inventaire.py`, les quatre bancs
`banc-reception-atomique-local.py`, `banc-reception-contrat-lecture.sql`,
`banc-reception-objets.cjs`, `banc-transport-rest.js`, et la cartographie JSON.
Documentation : ce rapport, `VERIFICATIONS-RECEPTION-20261016.json` et le renvoi
de mise à jour dans `SECURISATION-TRANSACTIONS-20261016.md`.

- Migration et banc PostgreSQL, requête de catalogue étendue, CI : `eeabccc3`.
- `supabase.js`, `plateau-communication.js` et adoptions d'inventaire des modules
  concernés ; versions des scripts dans `plateau.html` ; bancs client : `9e0c9695`.
- Jeton d'incarnation de livraison, conservation des anciens ID et tests : `edd5a730`.
- Cartographie reproductible et contre-épreuves de concurrence : `7c4e119f`.
- Vérification des postconditions après déclencheurs : `5a3ac99e`.

Le commit de ce rapport publie les preuves et la mise à jour du statut documentaire.
Le SHA final et le push sont confirmés dans le compte rendu de session.

**Verdict : réception atomique préparée et testée localement ; NON OPÉRATIONNELLE
EN PRODUCTION avant migration et vérifications réelles. Aucun feu vert global de
fiabilité du jeu ou de duplication des empires n'est déduit de ces tests.**
