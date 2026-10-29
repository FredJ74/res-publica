# Transmission immobilier à Claude — 29 octobre 2026

Référence d'autorité : `main` **9e8901b792580554e348c896457f8401a602c409**, début de `RELAIS.md`. Claude reprend les cinq terrains et l'ensemble du parcours immobilier. **Codex n'entreprend aucun nouveau développement immobilier.** Ce document transmet des travaux existants ; il n'autorise aucune application SQL ou fusion globale.

## Références sauvegardées sur GitHub

Les têtes ci-dessous ont été vérifiées par `git ls-remote --heads origin` le 29/10. Certaines branches sont anciennes, derrière main ou déjà intégrées partiellement. Une référence conservée n'est pas un correctif restant à fusionner.

| Branche distante | SHA vérifié |
|---|---|
| `codex/cloture-immobilier-135-20261027` | [`3498ad71`](https://github.com/FredJ74/res-publica/commit/3498ad71ce1567baaea9569904f8ee753397bea5) |
| `codex/recette-immobilier-135-20261025` | [`0d39d744`](https://github.com/FredJ74/res-publica/commit/0d39d744b8df9a4cd0719aab4e746bb37f9c0e38) |
| `codex/parcelles-gabarit-135-20261024` | [`aa240adb`](https://github.com/FredJ74/res-publica/commit/aa240adb52bd75a63cd1e1b4a6d857968406e48b) |
| `codex/construction-moteur-94-20261023` | [`04dd1788`](https://github.com/FredJ74/res-publica/commit/04dd17880f6acfaf482e84e153a8b2c50cc8c247) |
| `codex/construction-permis-94-20261023` | [`f4674115`](https://github.com/FredJ74/res-publica/commit/f467411512dd6977680f2c0386662dfd7397a6e4) |
| `codex/terrains-occupation-94-20261023` | [`98aa5420`](https://github.com/FredJ74/res-publica/commit/98aa54204d70c890e38c43347d93f1bf7571c558) |
| `codex/occupation-fiabilisation-94-20261023` | [`a56b12ef`](https://github.com/FredJ74/res-publica/commit/a56b12efcab5f8bcfff66225641ae8a428ce3696) |
| `codex/lots-reamenagement-94-20261023` | [`cc3a18bb`](https://github.com/FredJ74/res-publica/commit/cc3a18bbc922b720b9056cb9a0994ed78504bb91) |
| `codex/immobilier-fonds-murs-66` | [`ec9ea8d7`](https://github.com/FredJ74/res-publica/commit/ec9ea8d79912f6a9c3fa216821246f2a63c82307) |
| `codex/finalisation-construction-coffres-20261022` | [`f459aeea`](https://github.com/FredJ74/res-publica/commit/f459aeeabf50963e5c76d25917dccc31988b6257) |

La dernière branche générale contient aussi coffres/successions/ventes : **ne pas la fusionner en bloc**. Le repère ancien `e9f918140e629740b24fd7960a0b07f9d2a28811` est toujours conservé localement ; la tête distante ci-dessus est plus récente. La branche permis distante est `f4674115`, différente de l'ancienne tête locale `59471137` : reprendre la référence distante vérifiée.

## PR et rapports à reprendre

- [#57](https://github.com/FredJ74/res-publica/issues/57), [#94](https://github.com/FredJ74/res-publica/issues/94), [#135](https://github.com/FredJ74/res-publica/issues/135) : arbitrages et parcours historiques ; financement [#65](https://github.com/FredJ74/res-publica/issues/65), fonds/murs [#66](https://github.com/FredJ74/res-publica/issues/66), PR [#71](https://github.com/FredJ74/res-publica/pull/71).
- PR [#112](https://github.com/FredJ74/res-publica/pull/112) : dépôt atomique du permis. Rapport `outils/bancs/CONSTRUCTION-94-PERMIS-20261023.md`.
- PR [#156](https://github.com/FredJ74/res-publica/pull/156) : banc SQL complet des cinq terrains ; PR [#161](https://github.com/FredJ74/res-publica/pull/161) : accès au permis après achat sans permis et dépendance Acorn. Leur intégration a été confirmée dans les consignes de Fred ; ne pas les reconstruire.
- PR [#167](https://github.com/FredJ74/res-publica/pull/167) : diagnostic du pilote Arnie et des positions. Les campagnes et limites d'autorisation sont dans les rapports de recette ; ne pas utiliser Arnie pour payer, signer ou construire.
- PR [#174](https://github.com/FredJ74/res-publica/pull/174), [#175](https://github.com/FredJ74/res-publica/pull/175), [#178](https://github.com/FredJ74/res-publica/pull/178), [#188](https://github.com/FredJ74/res-publica/pull/188) : références conservées par la recette du 27/10. Consulter `outils/audits/CLOTURE-IMMOBILIER-135-20261027.md` et ses preuves `outils/audits/cloture-135-20261027/`.
- `outils/bancs/CONSTRUCTION-MOTEUR-94-20261023.md`, `outils/bancs/OCCUPATION-94-20261023.md` et `outils/audits/RECETTE-IMMOBILIER-135-20261025.md` : code, dépendances, arbitrages, limites.

Les statuts GitHub actuels de ces anciennes PR n'ont pas été relus via l'API (Forbidden dans cette session). Les liens sont des références historiques, pas une affirmation de leur état actuel. Le correctif de vol de matériaux `736ab07` est conservé dans le rapport du 27 : exception de constante corrigée, pas une preuve d'atomicité complète du vol. L'inventaire/les réceptions restent au socle Codex/ChatGPT.

## Migrations déjà présentes à examiner, pas à rejouer aveuglément

L'inventaire ci-dessous est issu des fichiers du dépôt repris. **Présence dans migrations/ ne prouve pas absence du registre vivant**, et présence dans historique/ ne remplace pas le contrôle du registre. Claude et ChatGPT doivent vérifier les versions réellement installées et les fonctions actuelles avant toute application. Aucun SQL immobilier n'est appliqué ou modifié dans cette transmission.

- `historique/migrations-appliquees/20261010004339_taxe_fonciere_un_terrain_une_journee_une_transaction.sql`
- `historique/migrations-appliquees/20261010080015_terrain_un_seul_point_de_mutation_de_propriete.sql`
- `historique/migrations-appliquees/20261010080337_terrain_proprietaire_muter_preuves_structurelles.sql`
- `historique/migrations-appliquees/20261010081020_chantier_l_approvisionnement_lit_la_tresorerie_en_base.sql`
- `historique/migrations-appliquees/20261010122516_terrain_un_seul_ecrivain_interne_et_la_porte_du_compromis.sql`
- `historique/migrations-appliquees/20261010122711_terrain_la_porte_du_permis_et_sa_liste_de_cles.sql`
- `historique/migrations-appliquees/20261010123004_terrain_la_porte_du_chantier_calcule_sa_progression.sql`
- `historique/migrations-appliquees/20261010123828_terrain_la_porte_du_decoupage_en_lots.sql`
- `historique/migrations-appliquees/20261010123910_terrain_chaque_acte_declare_ses_cles.sql`
- `historique/migrations-appliquees/20261010124442_terrain_le_gel_successoral_a_enfin_son_jumeau.sql`
- `historique/migrations-appliquees/20261010152035_terrain_reamenagement_et_le_proprietaire_du_depot.sql`
- `historique/migrations-appliquees/20261010191907_le_navigateur_perd_l_ecriture_sur_les_terrains_et_les_plaintes.sql`
- `migrations/20261019012000_rue_terrains_lots_liaisons_bidirectionnelles.sql`
- `migrations/20261020214955_construction_materiaux_prix_et_dons.sql`
- `migrations/20261020222029_construction_lancement_priorite_bancaire.sql`
- `migrations/20261022123319_chantier_financeurs_et_appels.sql`
- `migrations/20261022123320_chantier_jour_transactionnel.sql`
- `migrations/20261022123321_chantier_approvisionnement_caisse_unique.sql`
- `migrations/20261022124055_chantier_autorite_et_recus.sql`
- `migrations/20261022124056_chantier_commandes_et_reception.sql`
- `migrations/20261022125121_chantier_recu_relecture.sql`
- `migrations/20261022125728_chantier_fermer_commandes_non_versionnees.sql`
- `migrations/20261022125942_chantier_plan_initial.sql`
- `migrations/20261022125943_chantier_plan_raccordement.sql`
- `migrations/20261022130417_chantier_gardes_legacy_et_travail.sql`
- `migrations/20261022130418_chantier_travail_versionne.sql`
- `migrations/20261022130419_chantier_prix_representants.sql`
- `migrations/20261022143001_construction_delais_quatre_empires.sql`
- `migrations/20261022220516_permis_depot_transactionnel.sql`
- `migrations/20261022222907_terrain_occupation_visites.sql`
- `migrations/20261024123600_terrains_referentiel_acquisition.sql`
- `migrations/20261024123700_terrain_acquisition_commandes.sql`
- `migrations/20261024123800_terrain_banque_relecture_recus.sql`
- `migrations/20261024133310_terrain_vente_archive_reference_acte.sql`
- `migrations/20261024134528_permis_instruction_transactionnelle_acquisitions.sql`
- `migrations/20261024140140_permis_instruction_compatibilite_archives.sql`
- `migrations/20261025070000_chantier_taux_horaire.sql`
- `migrations/20261027104800_terrain_visites_fermeture_changement_ville.sql`

## Tests existants et portée des preuves

Les résultats ci-dessous sont **historiques, datés dans leurs rapports**, pas de nouveaux tests de production exécutés le 29/10 :

- Cinq parcours sur PostgreSQL jetable : **324 assertions**, avec acquisition, permis, financement, appels 35/35/30, matériaux, progression, lots, réception, relecture, concurrence et rollback ; 61 assertions bancaires sous-jacentes (ne pas les additionner comme scénarios distincts).
- Permis atomique : **56 assertions** ; négociation des occupants : **59** ; occupation/visites/fermetures : **30** ; progression/salaire : **62 + 15**. Les décors et horloges sont fictifs.
- Recette du 27 : **105/105 pilote**, **105/105 bancs clients**, 60 cas de navigation inclus, quatre tests ciblant le vol, trois mutants SQL détectés. Les nombres se recouvrent.
- Les contrôles Workflow ont été réparés ensuite par la PR #214 : fixtures déplacées sans changer leurs corps. Consulter `outils/vercel/FIABILISATION-20261028.md` et les preuves de rangement. Ne pas remettre les anciens chemins SQL.
- La recette authentifiée immobilière complète n'est **pas** démontrée par ces tests. Les autorisations de consultation d'Arnie n'incluent pas d'opération financière ou irréversible. Aucun nouveau déplacement du personnage réalisé ici.

## Frontière entre les équipes

Claude garde occupation/négociation, permis, banque/financement fonctionnels, matériaux et livraison immobilière. Leurs appels à police, groupes, PNJ, inventaire ou sécurité doivent utiliser les moteurs communs livrés par Codex ; ne pas importer l'ancienne table d'affectations de vigiles de #196 ni un combat parallèle.

Codex poursuit sur `codex/groupes-universels-20261028` / PR #219, avec sauvegardes `d2682feb` et `d44665a5` puis les lots suivants. Ces migrations sont **non déployées**. Le socle navigation, transports et justice sera fourni à l'intégration [#230](https://github.com/FredJ74/res-publica/pull/230) par lots testés, avec prévol ; ChatGPT conserve application, rapprochement SQL, fusion et livraison. Les adaptations d'accès aux lots déjà préparées restent des adaptateurs de navigation ; aucun nouveau permis, prix, superficie ou chantier immobilier n'est modifié après l'arbitrage.
