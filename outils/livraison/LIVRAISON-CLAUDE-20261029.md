# Livraison du périmètre Claude — 29/10/2026 (pour ChatGPT, intégration)

Rien n'est fusionné ni déployé par Claude. État vérifié le 29/10 à 19 h : `main` = `4648840` (#238).
Les quatre PR ci-dessous sont à jour avec `main` et ne touchent pas aux fichiers de #238.

## 1. Les PR, dans cet ordre

| Ordre | PR | Branche | Contenu | Écran |
|---|---|---|---|---|
| 1 | **#234** | `claude/verif-luthecia-20261029` | Repas et boissons sur place ; relevé de vérification | aucun changement d'écran |
| 2 | **#233** | `claude/terrains-immobilier-20261029` | Terrains, permis, loyers des lots, placements, notaire, corruption, décision du maire adjoint, prêt à la signature, alerte matériaux, squatteurs (préparé) | `plateau-justice-economie.js`, `plateau-politique.js`, `plateau-pnj.js`, `plateau.html` |
| 3 | **#240** | `claude/centres-villes-20261029` | Location des locaux à loyer fixe des trois villes par le serveur ; Premium généralisé | `plateau-justice-economie.js`, `plateau.html` |
| — | **#231** | `claude/pnj-profils-luthecia-20261029` | **À fermer** : contenu déjà livré par #232 | — |

**Conflits attendus (essai de fusion fait)** :
- `RELAIS.md` (#234/#233/#240) : garder toutes les sections.
- `plateau.html`, entre #233 et #240 : une seule ligne, la version de `plateau-justice-economie.js`. Mettre une valeur **nouvelle** (par exemple `?v=livraison-20261029`), pas l'une des deux, pour que les navigateurs rechargent le fichier fusionné.
- Aucun autre conflit. `plateau-justice-economie.js` fusionne sans conflit.

## 2. Migrations

**Déjà appliquées (registre)** — rien à faire :
`20261029094119` terrains_permis_loyers · `094135` placement_national_serveur · `094215` placements_nationaux_multiples · `095142` rdv_notaire_accelerer_serveur · `095808` repas_boissons_sur_place · `121752` pret_immobilier_verse_a_la_signature · `122005` chantier_alerte_materiaux · `122342` permis_corruption_serveur · `122748` permis_decision_serveur.

**À appliquer MAINTENANT (avant la livraison, compatibles avec l'écran en ligne, répétées à blanc)** :
1. `20261029180000_anciens_actes_acceleration_neutralises.sql` (#233) — raccorde les anciens actes notaire / corruption à la règle serveur.
2. `20261029190000_location_locaux_par_serveur.sql` (#240) — référentiel des loyers, porte `local_louer`, garde des prix.

**À appliquer JUSTE APRÈS le déploiement** (elles ferment les anciens circuits encore utilisés par l'écran actuel ; les appliquer avant casserait des boutons en ligne) :
3. `20261029160000_fermer_ancien_acte_rdv_notaire.sql` (#233) — ferme `achat_direct_accelerer`, `permis_accelerer`, `permis_decider`.
4. `20261029190100_location_locaux_fermer_ecran.sql` (#240) — l'écran ne crée plus les baux des locaux de centre (box portuaire exclu).

**À appliquer plus tard** :
5. `20261029181000_squatteurs_issue_combat.sql` (#233) — quand le combat collectif de Codex sera prêt (crée les actes pénaux `agression` et `meurtre`, décision de Fred).

Méthode : `apply_migration` avec le corps du fichier, puis renommer le fichier avec la version réellement attribuée au registre (comme pour les migrations déjà appliquées).

## 3. Contrôles après déploiement (lecture seule)

- `has_function_privilege('authenticated', …)` : `terrain_rdv_notaire_accelerer`, `terrain_permis_corrompre`, `terrain_permis_decider`, `terrain_lot_loyer_fixer`, `local_louer` = vrai ; `creer_placement_national` (ancienne) = faux ; `terrain_squatteurs_issue_interne` = faux.
- `terrain_compromis_acte(…,'achat_direct_accelerer',…)` et `terrain_permis_acte(…,'permis_accelerer'|'permis_decider',…)` rendent `acte_inconnu` (après l'étape 3).
- Aucun bail récent à `prix` différent du référentiel : `SELECT l.id FROM locations_actives l JOIN locaux_loyers_referentiel r ON r.batiment=l.data->>'buildingId' AND r.piece=l.data->>'roomId' AND r.ville IN (l.data->>'city','*') WHERE (l.data->>'prix')::int<>r.prix`.
- Le navigateur charge bien les nouvelles versions de `plateau-justice-economie.js`, `plateau-politique.js`, `plateau-pnj.js`.

## 4. Recettes en jeu (personnages connectés)

1. Acheter un terrain (dépôt puis notaire) ; déposer un permis ; « Construire » refusé tant que le permis n'est pas accordé.
2. Accélérer le rendez-vous chez le notaire (2 PA + 800 FR, délai divisé par deux, payé une fois).
3. Corrompre un fonctionnaire pour un permis (découvert ou accéléré, payé une fois).
4. Maire adjoint : accepter et refuser un permis (motif obligatoire au refus).
5. Après réception d'un commerce premium : fixer le loyer d'un lot dans « Information sur les locaux », le faire louer par un autre joueur, vérifier le crédit du loyer ; réorganiser un lot libre.
6. Banque nationale : deux placements ; prêt immobilier sous compromis versé seulement à la signature.
7. Chez SLAVA (Angie) : fontaine de chocolat et chocolat chaud sur place ; ballotin à emporter ; journal des ventes.
8. Louer un local dans chaque centre de Montrouge et de PSM ; y installer un commerce ; Option Commerce visible pour le titulaire seulement.

## 5. Ce qui reste hors de ce lot

- Combat des squatteurs : attend la résolution de combat collectif de Codex (PJ + gros bras contre un groupe de PNJ, score 0-100, jusqu'à 0 PA d'un camp).
- PR #213 (inventaire serveur, Codex/ChatGPT) et ses six fermetures post-livraison (`20261028210000` → `210900`) : non appliquées à ce jour.
