# Clôture fonctionnelle de Luthécia — cinq anomalies (Claude, 01/11/2026)

Branche `claude/cloture-fonctionnelle-luthecia-20261101`, issue de `main` `df67186a773f77fad58389d35c28c0c3a69443c9`.
Aucune migration, aucune écriture en production (deux lectures seules du catalogue et des ventes), aucune
modification des moteurs de déplacement, de groupe, de détention ou d'hospitalisation (#219, #318, #324).

| Domaine | État démontré |
|---|---|
| 1. Interview de Jodie | **Corrigé et testé.** La pagination (une question par page) était déjà sur `main` (`aaa0ba5`, 30/10) mais sans test. Deux défauts restants, reproduits : double clic sur « Envoyer » = deux rédactions IA ; réponse tardive qui écrase l'écran où le joueur est allé entre-temps. |
| 2. Caisses communales | **Déjà conforme** (PR #275). |
| 3a. Fontaine de chocolat | **Déjà conforme** : refus à emporter côté serveur et écran, consommation sur place par le moteur commun. |
| 3b. Alertes de ventes | **Déjà conforme** (#96) ; trois ventes historiques sans alerte, voir plus bas. |
| 4. Multimodal de PSM | **Déjà conforme** (`77d9436`, 28/10) ; banc propre à PSM ajouté. |
| 5. Position après F5 | **Non reproductible sur `main`** : position serveur seule. Dépendance #219/#318 documentée et testée. |

## 1. Interview de Jodie Moitout

- Correctif (`plateau-communication.js`) : verrou `_jodieApercuEnCours` (un seul appel `apercu`) ; à la réponse,
  l'écran n'est redessiné que si le joueur est toujours dans l'interview ; sinon un message nommé l'avertit, et
  l'aperçu rédigé est retrouvé en rouvrant la proposition. Une réouverture ne vide plus les réponses déjà saisies.
  Le refus efface aussi le jeton d'aperçu.
- Côté serveur, déjà en place et vérifié : `api/jodie-portrait` (authentification, propriété, invitation, refus,
  signature de l'aperçu, anti-doublon) — `banc-jodie-portrait-api.cjs` 10/10, `banc-jodie-confirmation.cjs` 10/10.
- Nouveau banc `banc-jodie-interview-navigateur.cjs` (Chromium, vrai `style.css`, vraies fonctions) : 5/5 —
  cinq pages à 390 et 1280 px, réponses conservées en avant/arrière, « Envoyer » visible et cliquable, réponse vide
  refusée sans appel, refus serveur nommé avec réponses intactes, double clic, réponse tardive.
  Contre-épreuve `CONTRE=df67186` : le cas du double clic échoue (2 appels).

## 2. Caisses des bâtiments communaux

`banc-caisses-accueil-communal.cjs` 9/9 : plus d'ordre « Consulter les caisses communales » ; caisse affichée à
l'accueil des 21 bâtiments communaux des trois villes (mairies comprises), pas dans les salles intérieures.
L'affichage passe par la lecture existante (`sbGetCaisseBatiment`, politique « lecture publique hors commissariat »,
commissariat par `lireCaisseCommissariat` côté serveur) et ne contient ni écriture ni bouton. Aucune règle
budgétaire ni permission changée.

## 3. Commerces

- **Fontaine** (production, lecture seule) : la référence « fontaine » de SLAVA porte `venteSurPlaceUniquement`
  (générique `boisson`). En production, `acheter_produit_commerce` la refuse (`consommation_sur_place_uniquement`) ;
  `consommer_sur_place_commerce` passe par `acheter_produit_commerce_interne` (paiement, stock, reçu dans la même
  transaction). Migrations enregistrées : `fontaine_exclusivite_sur_place`, `repas_boissons_sur_place`… L'écran
  masque quantité et « Acheter » pour cette référence. CI de `main` (`df67186`) : `banc-fontaine-110-local.py`
  OK (refusée à emporter, acceptée sur place) ; `test-fontaine-antenne-luthecia.mjs` 2/2.
- **Journal des ventes** : mécanisme #96 en production depuis le 23/10 (`journal_ventes_commerces`, déclencheur
  `vente_journal_snapshot`, `journal_ventes_lire` réservé à `authenticated`). CI de `main` :
  `banc-journal-ventes-local.py` 14 contrôles OK (rejeu sans doublon, ventes hors connexion conservées, un seul
  accès acquitte dix ventes sans effacer l'historique, tiers et UID forgé refusés, vente annulée sans alerte,
  acquittement concurrent) ; `banc-journal-ventes-navigateur.cjs` OK. Reçu unique par requête
  (`ventes_snapshots_requete_key`).
- **Constat** : les trois ventes de SLAVA en production (dont Arnie, 22/10) datent d'avant l'installation du
  journal ; la migration a choisi de ne pas les reprendre. Aucune vente depuis, dans tout le jeu. L'exemple cité
  n'apparaîtra donc pas chez Angie ; la prochaine vente réelle, oui. Une reprise de ces trois reçus (même règle
  vendeur = propriétaire) est possible mais n'a pas été préparée : à décider.

## 4. Centre multimodal de Port-Sainte-Marie

La liste « vide » était l'affichage de `ville.name`, propriété absente (libellés vides) ; corrigé le 28/10
(`77d9436`), comme le retrait de « Demander conseil à Mireille ». Nouveau banc `banc-multimodal-psm-20261101.cjs` 4/4 :
depuis PSM, train et bus proposent Luthécia et Montrouge, nommées ; ordres du hall alignés sur le moteur
(train 2 PA/75 FR, bus 1 PA/150 FR) ; aucun centre ne propose l'ordre de Mireille. Contre-épreuve `77d9436^` : 3 échecs.
Le moteur de voyage (`executerVoyage`) écrit encore la position à l'écran puis la sauvegarde : c'est le périmètre
de #219 (`transport_effectuer`), non modifié.

## 5. Positions après F5

Sur `main` : bâtiment et pièce ne viennent jamais du cache local (restauration unique après la réponse serveur,
26/09) ; la rue de Républia est relue par `rue_position_lire` ; la sauvegarde générique fusionne la position à
trois voies (#258, en production), donc un onglet ancien ne la défait pas. Chemins anciens restant actifs :
`restaurerPositionApresChargement` rejoue `enterBuilding`/`enterRoom`, qui republient la même position, sans effet
tant que le serveur ne refuse pas l'entrée. Sur la pile #219, ce rejeu devient une commande de navigation (refusée
ou déplaçant le groupe) : corrigé par #318 (`representerPositionServeur`).
Banc `banc-position-f5-luthecia-20261101.cjs` : 4/4 + 1 test en attente (`todo`) qui passera quand
`navigation_positions_garder` (#219) et `representerPositionServeur` (#318) seront dans `main`.
Contre-épreuve `d5be731^` : le test de fusion échoue.

## Tests de l'ensemble

`controler-client.py` : 141/142 (seul échec : `@vercel/node` absent de cet environnement). Bancs Python
`*-local.py` non exécutables ici (`pgserver`, `psycopg2`) : leurs résultats viennent de la CI de `main`.

## À vérifier en production (par les PJ)

- Interview de Jodie : recevoir la proposition, répondre aux cinq questions sur téléphone, Envoyer, publier.
- Une vente réelle dans un commerce de PJ : alerte au journal du propriétaire, disparition à l'ouverture.
- Fontaine de SLAVA : « Consommer sur place » seulement.
- Train depuis PSM : Luthécia et Montrouge affichées.
