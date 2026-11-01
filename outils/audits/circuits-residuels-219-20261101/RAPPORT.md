# #219 — Circuits résiduels de déplacement (Claude, 01/11/2026)

Base : tête `bf06a27` de `codex/groupes-universels-20261028`. Branche indépendante
`claude/circuits-residuels-219-20261101`, PR dédiée vers la branche de #219. **Aucune fusion,
aucune migration appliquée, aucun déploiement, aucune donnée de production modifiée** (production
consultée en lecture seule pour l'inventaire des fonctions vivantes).

Non touchés (mission Codex en cours) : `migrations/`, catalogue 1015, 95 migrations, 27 tests HTTP,
étape 43 de la CI. Le correctif serveur est donc livré **hors de `migrations/`** :
`migration-a-integrer-circuits-residuels-positions.sql`, à placer par l'intégrateur après les 95.

## Pourquoi ces circuits sont cassés avec #219

`navigation_positions_garder` (migration `…115801`) ignore toute position envoyée par une
sauvegarde générale, et la navigation commune (`navigation_interieure`, `…115759/800`) refuse :
un PJ hospitalisé (`acteur_incapacite`), une entrée de bâtiment hors de la rue
(`entree_non_accessible`), un membre non chef (`chef_de_groupe_requis`), un groupe dont les PJ ne
sont pas au même endroit (`groupe_disperse`). Côté écran, `enterBuilding`/`enterRoom` recommandent
`navigation_interieure` dès que la position locale diffère de la cible, sauf si
`navigationInterieureRendu` marque une position déjà confirmée.

## 1. Anciens circuits réellement encore actifs — corrigés

| # | Circuit | Défaut démontré | Correction |
|---|---|---|---|
| 1 | Restauration après F5 (`restaurerPositionApresChargement`, `restaurerPieceDynamiqueDifferee`) | la position relue au serveur était **recommandée** : `navigation_interieure` vers la 1re pièce du bâtiment, donc un F5 déplaçait le PJ (et tout son groupe s'il est chef) ; un membre recevait un refus | `representerPositionServeur` : même marqueur que `afficherPositionNavigationConfirmee` |
| 2 | Camion militaire (`camionEntrerDansLaPiece`, `camionNaviguerVers`) | après `camion_monter`, l'écran recommandait `navigation_interieure('camion-militaire', id)` (refusée), puis la « réconciliation » appelait `camion_descendre` : impossible de rester à bord | idem 1 (tous les appelants passent une position rendue par le serveur) |
| 3 | `assemblee_protester` / `assemblee_revenir` (serveur, hors #219) | déplacent le seul acteur : le groupe restait dans l'autre pièce et tout déplacement suivant échouait en `groupe_disperse` | patch en place : l'acteur passe par la porte existante `groupe_pj_quitter()` ; verrou du graphe avant celui de la fiche |
| 4 | Libération purgée au QHS avec lieu de retour | l'écran téléportait le PJ dans sa ville de retour ; le serveur le laissait en cellule (F5 = retour au QHS) | `detention_clore_interne` (mode `purgee` seulement) dépose au terminal de la ville, même règle d'arrivée que `transport_effectuer` ; l'écran relit la fiche |
| 5 | Incorporation d'un déserteur détenu | l'écran le conduisait au corps de garde ; le serveur le laissait aux geôles | `detention_clore_motif_eteint('incorporation')` dépose au corps de garde ; l'écran relit la fiche |
| 6 | Hospitalisation automatique (`declencherHospitalisation`, agression/empoisonnement) | navigation écran vers le dispensaire refusée (`acteur_incapacite`) : victime bloquée où elle était, sans pouvoir bouger jusqu'à la fin ; de plus le dispensaire visé était toujours celui de Luthécia (`dispensaire-public`), faux en province | porte `hospitalisation_lieu_rejoindre('dispensaire')` : dispensaire de la ville réelle lu dans `navigation_lieux_regles`, sortie du groupe |
| 7 | Transfert en clinique privée (`doTransfertCliniquePrivee`) | 1 000 FR payés **avant** une navigation refusée (hospitalisé, autre bâtiment, et depuis le 01/11 autre ville) | même porte, `p_lieu='clinique'` : vérification sans écriture, puis paiement par `payer_ordre_interne` et déplacement dans la même transaction ; chambre rendue si refus |

Nouvelle porte réseau : `hospitalisation_lieu_rejoindre(p_lieu, p_chambre, p_verifier)`,
`authenticated` seulement. Elle réutilise `navigation_disponibilite_interne` (mêmes interdits,
hospitalisation exceptée), `navigation_lieux_regles`, `payer_ordre_interne` et la règle de
`groupe_pj_quitter`. Ce n'est pas une mécanique parallèle : c'est le raccordement serveur du
déplacement d'hospitalisation, qui n'existait qu'à l'écran.

Tous les changements d'écran ne s'activent qu'avec `state._navigationServeur === true` : avant
activation de #219, les anciens chemins restent identiques (cas client 11).

## 2. Circuits vérifiés et conformes

- **Transports** (train, bus, avion, bateau, taxis Caserne/QHS) : `executerVoyage`, transport
  inter-empire et `doTaxiSpecial` passent par `commanderTransportServeur` en mode serveur.
- **Douanes / embarquement** : `checkZoneEmbarquementAcces` → `commanderDouanesServeur`,
  corruption → `commanderCorruptionDouanesServeur`.
- **Écrou** : `detention_ouvrir_interne` / `detention_qhs_poser_interne` posent la cellule
  (`…115817`) et séparent le groupe (`…115823`) ; `teleporterVersCellule` ne fait que
  représenter (même table de cellules que le serveur, `celluleDeDetention`).
- **Fuite / interception** : `police_fuite_resoudre` (`…115828`) ; l'écran adopte `frais`.
- **Camions** : `camion_monter/descendre/deplacer` redéfinies par `…115854` (le défaut 2 était
  côté écran seulement).
- **Batailles** : `militaire_bataille_appliquer` (`…115840`), `militaire_bataille_decrocher_groupe`
  (`…115834/851`) — périmètre combats de Codex, non repris.
- **PNJ** : `pnj_prendre`, `pnj_quitter_groupe`, `pnj_transferer` redéfinies par #219 ;
  `militaire_deposer_soldats` lit la position serveur du chef ; `militaire_recuperer_soldats`,
  `militaire_terminal_rejoindre`, `employe_liberer`, `pnj_mourir` ne posent que « suit son chef »,
  « disparu » ou la position effective — aucune position reçue du navigateur.
- **Rue** : `rue_position_enregistrer` redéfinie (`…115752/800`) ; sortie de bâtiment par
  `confirmerSortieBatimentServeur`.
- **Assemblée côté écran** : `seanceNaviguerVers` pose la pièce rendue avant `enterRoom`
  (aucune commande).
- **Sortie déclarée** (`room.sortieVers`) : seul usage, l'open space du centre d'affaires de
  Luthécia, reste dans le même bâtiment (`navigation_interieure` ordinaire).

Inventaire serveur (production, lecture seule, 01/11) : fonctions écrivant
`current_city/building/room` = `assemblee_protester`, `assemblee_revenir`, `camion_*`,
`militaire_bataille_appliquer`, `militaire_bataille_decrocher_groupe`, `police_fuite_resoudre`,
`rue_position_enregistrer`, `personnages_vue_modifier` (porte de la vue, neutralisée par le garde).
Toutes sont redéfinies par #219 sauf les deux de l'assemblée (corrigées ici).

## 3. Points relevés, non corrigés ici (hors périmètre ou décision requise)

- **Règle d'hospitalisation divergente** (fichier Codex `…115759`) : le serveur refuse tout
  déplacement jusqu'à `dateFinParis`, l'écran n'immobilise que le 1er jour (« Verrou :
  hospitalisation — jour 1 uniquement »). À trancher par l'intégrateur ou le game designer ;
  la porte livrée ici ne dépend pas de ce choix.
- **Naturalisation** (`appliquerNaturalisationAcceptee`) pose `state.country` localement ;
  inatteignable tant que les fonctions inter-empires sont grisées (décision de Fred).
- **Accès collectifs à raccorder** (`acces_collectif_a_raccorder` : loges hors membres,
  zone d'embarquement, bureaux d'ambassade) : déjà listés comme bloquants par Codex.
- **Libération du QHS par grâce ou appel** : le PJ reste au QHS comme aujourd'hui (aucun ancien
  circuit ne le déplaçait) ; seule la peine purgée avait une téléportation écran.

## 4. Preuves

- `preuve-sql.log` : **14/14** cas sur PostgreSQL 16 jetable (`monter-base-jetable.sh` :
  baseline + migrations de #219), correctif appliqué deux fois (idempotent).
- `preuve-sql-contre-epreuve.log` : sans correctif, **12 défauts dénoncés** ; les 2 cas encore
  verts décrivent un comportement inchangé (grâce sans déplacement, refus de l'ancien circuit).
- `preuve-client.log` : **11/11** cas client ; contre-épreuve sur `bf06a27` : **9 échecs**
  (F5 : 2 commandes de navigation ; camion : 1 commande puis redescente ; etc.).
- Non-régression : bancs clients #219 existants verts (arrestation 10, transports 8, batailles
  28, contrôles 10, interception 41, douanes 12, retours acteur 23, rues 21) et
  `node --test outils/bancs/test-*.mjs` (23).

Rejouer : `outils/bancs/banc-circuits-residuels-219.sh [--contre]` (root, PostgreSQL 16) ;
`node --test outils/bancs/banc-circuits-residuels-219-client.cjs` (contre-épreuve :
`CONTRE=<sha> node --test …`).
