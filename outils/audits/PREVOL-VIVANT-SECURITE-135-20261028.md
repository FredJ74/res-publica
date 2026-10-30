# Prévol vivant #135 — 28 octobre 2026

Audit lecture seule de Supabase production `jxpwoosmmhohoihxpbuc`, effectué après le rapport Codex, **sans appliquer de migration**.

## Vérifications effectives

| Fonction en production | MD5 de pg_get_functiondef | Observation |
| --- | --- | --- |
| `pnj_position_effective` | `5a899b812b460a2887ee83d036e6a0ed` | Dans la branche PJ suiveur, `rue_noeud_id = NULL` : défaut S5 confirmé. |
| `pnj_prendre` | `c84eb827c4a4037cddf6cd20c4c42641` | Mise à jour `leader_pj` dans la boucle de validation : contrôle non atomique de l'ensemble avant la mutation, sujet S3 confirmé. |
| `pnj_quitter_groupe` | `d07eb86ea294b0afeb21a2bbfa33ffb0` | RPC commune existante, à préserver. |
| `police_detection_verifier` | `0b08bd0be584be4bf0d63373a304f05c` | Corps vivant 4 393 caractères ; calcul agrégé de tous les policiers, sans groupes explicites ni privé. Ancrages de patch Codex présents. |
| `police_combat_resoudre` | `732cef606f706a89db9811c0daf542f5` | Corps vivant 8 389 caractères ; ancrage de patch Codex présent. |
| `police_fuite_resoudre` | `38c9fa4ee7bb97c1769eeb485366a0be` | Corps vivant 4 208 caractères ; ancrage de patch Codex présent. |
| `police_reddition_resoudre` | `ee57e57f505edde2c589612c2e84ec25` | RPC présente. |

Sur `pnj_co_present`, l'ancien ancrage `current_room INTO a` est présent.

Le registre `police_interceptions` **n'a pas** la colonne `intervenants`. `pnj_membres` possède `leader_pj`, `leader_pnj_id`, `rue_noeud_id` mais **pas** `groupe_deploiement_id`. `chantier_vigiles_affectations` est absent. Les fonctions privées `securite_agents_prives_presents_interne`, `securite_ordre_detection_interne` et `pnj_deployer_unite` sont absentes en production. La RLS est activée sur `pnj_membres`, `police_detection_attempts` et `police_interceptions` ; les relevés ne montrent aucune politique sur ces tables.

## Conclusion technique

La branche corrigée de Codex s'appuie sur **les anciennes définitions réelles** et non sur une base déjà partiellement migrée ; ses ancrages principaux ont été retrouvés. **Cela ne suffit pas pour lancer les trois migrations :** le prévol des ancres internes de fuite/combat, l'analyse des droits effectifs, des triggers, la présence effective de groupes policiers, les modifications universelles des groupes PJ et la recette authentifiée sont encore nécessaires.

Les groupes de bataille militaires ne sont pas un groupe de patrouille persistant. Il faut raccorder au socle commun, sans réintroduire d'ID de groupe douanier, policier ou privé.

Aucune donnée de joueur touchée. Aucun effet en bêta. Rapport complémentaire à `outils/audits/AUDIT-CRITIQUE-SECURITE-GROUPES-135-20261028.md`.
