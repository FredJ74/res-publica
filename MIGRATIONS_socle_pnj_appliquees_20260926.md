# Socle PNJ / groupes / leaders — migrations appliquées le 26 septembre 2026

Feu vert explicite du concepteur. **Le blob militaire reste autoritaire** pendant toute la
phase miroir : `compagnies_militaires.updated_at` est resté `2026-09-22 22:29:35.196405+00`
du début à la fin de cette bascule.

## Migrations appliquées, dans l'ordre

| # | nom de la migration | contenu |
|---|---|---|
| 1 | `socle_pnj_snapshot_militaire_avant_bascule` | `compagnies_militaires_snapshot_20260926` — copie exacte de la ligne autoritaire, md5 du blob identique au vivant, 96 soldats complets (PA, entraînement, arme, matricule). Droits révoqués au client. |
| 2 | `socle_pnj_schema` | `pnj_membres`, `pnj_possessions`, `pnj_evenements`, `pnj_soldats_metier`, `pnj_employes_metier`, `pnj_force_publique_metier`, `pnj_militants_metier` + 9 CHECK sur `pnj_membres` + le déclencheur anti-sous-hiérarchie + RLS activée sans aucune policy et **aucun droit client**. |
| 3 | `socle_pnj_primitives` | `pnj_position_effective`, `pnj_titulaire_du_poste`, `pnj_administrateur`, `pnj_mourir`, `pnj_pa_debiter`, `pnj_membres_ici`. |
| 4 | `socle_pnj_primitives_mutations` | `pnj_peut_commander`, `pnj_quitter_groupe`, `pnj_transferer`, `pnj_prendre`, `pnj_argent_transferer`, `pnj_objet_transferer`, `pnj_evenements_lire`. |
| 5 | `socle_pnj_outillage_migration_soldats` | `pnj_copier_soldats`, `pnj_comparer_soldats`, `pnj_rollback_soldats`. |

Le SQL intégral de chacune est enregistré dans l'historique de migrations Supabase sous ces
noms exacts, et relisible par `pg_get_functiondef()` pour chaque fonction. La conception et la
justification ligne à ligne sont dans `PROPOSITION_socle_pnj_groupes.sql` et
`PROPOSITION_socle_pnj_migration_soldats.sql`, qui restent les documents de référence.

**Écarts entre la proposition et ce qui a été appliqué**, pour que la lecture des deux ne
trompe personne :
- `pnj_membres` a reçu `liquide numeric` et les six colonnes `car_for/cha/dup/int/per/vol`
  (l'ensemble fermé des caractéristiques PNJ), absentes de la première esquisse ;
- `pnj_soldats_metier` a été ajoutée (matricule, section, réserve, arme, formation) — c'est
  elle qui garde l'entraînement **hors** du socle ;
- les primitives de mutation résolvent l'acteur par `mon_personnage()` et vérifient
  `pnj_peut_commander` : être l'administrateur du PNJ ou son leader courant.

## Le modèle PA, définitif

Le socle **stocke** les PA, en fournit 12 à la création, expose `pnj_pa_debiter` **appelée par
le métier**, interdit les valeurs négatives et déclenche la mort générique à 0. Il ne débite
jamais de lui-même : ni au suivi du leader, ni à un déplacement, ni à un transfert, ni à un
changement de groupe. `pnj_suivre_leader()` n'est jamais `pnj_perdre_pa()`.

## Banc sur le schéma réellement appliqué

19 cas, 19 réussis, 0 échec — dont les **sept invariants effectivement refusés** par les
contraintes réelles : contrat à deux états, leader unique, pas d'auto-conduite, PA non
négatifs, propriété exclusive, pas de sous-hiérarchie, un mort ne suit plus personne.
Plus : position dérivée d'un PJ réel, aucun PA débité par le socle, débit métier volontaire,
coût négatif refusé, mort à 0 PA, possessions au sol, événement au propriétaire, double mort
sans effet, mort institutionnelle pendant une vacance adressée au poste.

Les PNJ de banc (`zzb-*`) et les objets qu'ils avaient déposés au sol ont été supprimés :
aucun résidu.

## Copie des 96 — checkpoint 1

```
copie       -> ok, 96 : 24 en section, 72 en reserve, 4 sections
comparateur -> nb_blob 96, nb_socle 96, correspondances 96,
               divergences 0, manquants 0, surnumeraires 0
```

État du socle après copie : 96 soldats, 96 matricules distincts, **24 suivant Vince Kubrick**
(position dérivée, tous portés, tous à `caserne-militaire/corps_garde`), 72 stationnés en
réserve, 96 en propriété institutionnelle `lieutenant`, PA tous à 12.

## Rollback

`pnj_rollback_soldats('compagnie-republic-1790116175239')` supprime **uniquement** les lignes
de cette compagnie, sans toucher aucune autre famille ni laisser de métier orphelin. Éprouvé
en schéma jetable : copie → divergences injectées → détectées → rollback → recopie 96/96.
Restauration du blob si jamais nécessaire :

```sql
UPDATE compagnies_militaires c SET data = s.data, updated_at = s.updated_at
  FROM compagnies_militaires_snapshot_20260926 s WHERE s.id = c.id;
```

**Point de non-retour : aucun à ce stade.** Le blob n'a pas été modifié et reste l'autorité.
Il n'apparaîtra qu'au basculement d'autorité des 14 écritures.
