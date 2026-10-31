# #219 — sort des 27 couples initialement restants

Deux couples sont conservés : **choisir_arme / 1 PA / 0 FR**, explicitement utilisé par les moteurs d’achat d’armes, et **donner_argent_pnj / 1 PA / 0 FR**, encore déclaré dans data.js. Le générateur les omettait. Aucun de ces coûts n’est supprimé.

Les 25 autres couples ci-dessous ne sont plus émis par les déclarations actives. Leur nettoyage est préparé, pas appliqué. Les 39 nouvelles déclarations proviennent des sources, non d’une copie de la capture. Cible testée : **452 triplets**, dont **413 communs** avec la capture de 438. La variation nette initiale de onze est ainsi entièrement détaillée dans le diff JSON, pas assimilée à onze lignes manquantes.

| Ancien triplet (ordre, PA, FR) | Origine retrouvée | Déclaration ou mécanisme actuel |
|---|---|---|
| `acheter_criee`, 1, 0 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Couples des sources : 0/0. Les variantes légitimes restent toutes conservées. |
| `acheter_ghb`, 1, 300 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Couples des sources : 0/300. Les variantes légitimes restent toutes conservées. |
| `acheter_gilet`, 0, 600 | Ajout exact non retrouvé ; présence attestée par la capture indépendante | Achat final fixé à **1 PA / 600 FR** dans confirmerAchatGilet ; le 0/600 permettait un achat sans PA (contre-épreuve SQL). |
| `acheter_relique`, 1, 500 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Couples des sources : 0/500. Les variantes légitimes restent toutes conservées. |
| `acheter_ressources_entrepot`, 1, 0 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Couples des sources : 0/0. Les variantes légitimes restent toutes conservées. |
| `acheter_vipere`, 1, 350 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Couples des sources : 0/350. Les variantes légitimes restent toutes conservées. |
| `boire_verre`, 0, 50 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Ancien ordre sans déclaration active ; moteur commun de tournée conservé, sans second mécanisme. |
| `choisir_accessoire_club`, 1, 0 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Couples des sources : 0/0. Les variantes légitimes restent toutes conservées. |
| `consulter_indices_locaux`, 0, 0 | `historique/registre-supabase/20260913182154_chantier_c_miroir_complet_et_fail_closed.sql:46` | Ancienne entrée sans ordre littéral actif dans les sources parcourues ; les routes de lecture/compatibilité ne sont pas supprimées. |
| `corrompre_fonct`, 2, 200 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Couples des sources : 3/500, 3/1500. Les variantes légitimes restent toutes conservées. |
| `corrompre_fonct#reussite`, 0, 200 | Projection du couple historique corrompre_fonct 2/200 (migration crimes_ordres_detection) | Couples des sources : 0/500, 0/1500. Les variantes légitimes restent toutes conservées. |
| `corrompre_fonct#tentative`, 2, 0 | Projection du couple historique corrompre_fonct 2/200 (migration crimes_ordres_detection) | Couples des sources : 3/0. Les variantes légitimes restent toutes conservées. |
| `demettre_lieutenant`, 2, 0 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Menu 0/0 ; action validée par le serveur militaire. Entraînement : ses 6 PA sont internes au moteur, pas ce vieux tarif de menu. |
| `entrainer_section`, 2, 0 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Menu 0/0 ; action validée par le serveur militaire. Entraînement : ses 6 PA sont internes au moteur, pas ce vieux tarif de menu. |
| `gerer_finances`, 1, 0 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Couples des sources : 0/0. Les variantes légitimes restent toutes conservées. |
| `investir`, 1, 0 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Ancienne entrée sans ordre littéral actif dans les sources parcourues ; les routes de lecture/compatibilité ne sont pas supprimées. |
| `nommer_capitaine`, 2, 0 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Menu 0/0 ; action validée par le serveur militaire. Entraînement : ses 6 PA sont internes au moteur, pas ce vieux tarif de menu. |
| `nommer_lieutenant`, 2, 0 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Menu 0/0 ; action validée par le serveur militaire. Entraînement : ses 6 PA sont internes au moteur, pas ce vieux tarif de menu. |
| `plainte`, 0, 0 | `historique/registre-supabase/20260913182154_chantier_c_miroir_complet_et_fail_closed.sql:46` | Ancienne route supprimée le 13 octobre (commentaires plateau-router.js). Les procédures judiciaires actuelles gardent leurs propres RPC. |
| `plainte`, 1, 0 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Ancienne route supprimée le 13 octobre (commentaires plateau-router.js). Les procédures judiciaires actuelles gardent leurs propres RPC. |
| `proposer_abrogation`, 1, 0 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Ordre retiré le 30 septembre, documenté dans data.js et plateau-router.js. |
| `renseignement`, 3, 500 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Cellule de renseignement : RPC cellule_renseignement_creer et coûts internes ; ancien tarif non utilisé par le chemin actuel. |
| `renseignement_transport_intl`, 0, 0 | `historique/registre-supabase/20260913182154_chantier_c_miroir_complet_et_fail_closed.sql:46` | Ancienne entrée sans ordre littéral actif dans les sources parcourues ; les routes de lecture/compatibilité ne sont pas supprimées. |
| `requete_avocat`, 1, 0 | `historique/registre-supabase/20260913134422_chantier_c_paiement_ordres_autoritaire.sql:68` | Ancienne route supprimée le 13 octobre (commentaires plateau-router.js). Les procédures judiciaires actuelles gardent leurs propres RPC. |
| `se_porter_candidat`, 0, 0 | `historique/registre-supabase/20260913182154_chantier_c_miroir_complet_et_fail_closed.sql:46` | Ancienne entrée sans ordre littéral actif dans les sources parcourues ; les routes de lecture/compatibilité ne sont pas supprimées. |

La migration refuse toute autre matrice que les 438 triplets capturés (empreinte complète), ne supprime que ces couples précis, insère les déclarations manquantes puis compare **tout le contenu** à la cible. La sentinelle n’est posée qu’après cette comparaison. Le rejeu est sans effet ; un écart vivant inconnu provoque un refus avant mutation. Aucune fiche ni banque n’est modifiée.

Les anciennes observations et empreintes versionnées du contrôle global ne sont pas réécrites pour annoncer une concordance de production. Le prévol actualisé à 1 008 migrations reste requis.
