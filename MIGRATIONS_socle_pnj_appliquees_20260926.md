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

## Bascule des lectures — `militaire_detachement_ici`

Migration `socle_pnj_bascule_lecture_detachement_ici`. La duplication OR/EXISTS qui résolvait
la présence à la main (soldat stationné par sa triade, soldat accompagnant par un `EXISTS` sur
la fiche de son chef) est remplacée par une jointure latérale sur `pnj_position_effective()`.

**Le piège évité, et il était grave.** L'ancienne version ne balayait que `data->'sections'`,
jamais `data->'reserve'`. Le socle, lui, contient les 96. Or Vince est à
`caserne / caserne-militaire / corps_garde` — **exactement là où sont les 72 réservistes**.
Sans le filtre explicite `sm.en_reserve = false`, la fonction aurait annoncé **96 soldats au
lieu de 24** dans « Personnes présentes ». Le filtre est donc posé, et l'équivalence prouvée :

```
ancienne logique : 1 ligne, effectif 24
nouvelle logique : 1 ligne, effectif 24
EXCEPT dans les deux sens : 0 | 0
```

Le partage socle/métier est net : le socle répond « qui est ici », le blob garde le nom du
Lieutenant de la section et sa mission — données purement militaires, qui n'ont rien à faire
dans `pnj_membres`.

## Double écriture — par déclencheur, non par retouche des 14 fonctions

Migration `socle_pnj_miroir_par_declencheur`. Retoucher 14 fonctions à la main laisse
exactement le risque que le brief interdit : qu'une quinzième apparaisse, ou qu'un chemin
m'échappe, et le socle dérive en silence. Un déclencheur `AFTER INSERT OR UPDATE` sur
`compagnies_militaires` est **exhaustif par construction** : toute écriture du blob, par
n'importe quelle fonction, présente ou future, resynchronise le socle dans **la même
transaction**. Un échec du miroir annule donc l'écriture métier — le fail-closed est gratuit.

Coût O(n) sur 96 lignes, sans conséquence : les fonctions militaires réécrivent déjà le tableau
entier à chaque mutation, elles sont déjà O(n).

**Anomalie rencontrée et corrigée.** J'avais laissé un identifiant fictif
(`ROW_COUNT_PLACEHOLDER_NON_UTILISE`) dans le corps de `pnj_miroir_compagnie`. PL/pgSQL ne
valide pas les identifiants à la création : la fonction a été acceptée et aurait échoué au
premier déclenchement. Remplacé par `GET DIAGNOSTICS v_sup = ROW_COUNT;` et vérifié.

**Miroir testé dans les deux sens, par une écriture réelle strictement réversible** :

```
blob reserve[0].pa 12 -> 11   =>  socle 202609-025 pa = 11   (miroir automatique)
restauration depuis le snapshot
  md5 du blob  = a107192a41d5cd1153808c302d60d0a9  (identique a l'origine)
  updated_at   = 2026-09-22 22:29:35.196405+00     (identique a l'origine)
  socle PA     = 12-12, 96 soldats
```

## Checkpoint 2

```
nb_blob 96, nb_socle 96, correspondances 96,
divergences 0, manquants 0, surnumeraires 0
```

## Appels client

Huit enveloppes ajoutées en fin de `supabase.js`, purement additives :
`sbPnjMembresIci`, `sbPnjPositionEffective`, `sbPnjQuitterGroupe`, `sbPnjTransferer`,
`sbPnjPrendre`, `sbPnjArgentTransferer`, `sbPnjObjetTransferer`, `sbPnjEvenementsLire`.

## Popup générique et garde de phase miroir

Migrations `socle_pnj_garde_phase_miroir_soldats`, `socle_pnj_lire_possessions`,
`socle_pnj_corriger_lecture_possessions`.

**La garde est en base, pas en convention cliente.** `pnj_quitter_groupe`, `pnj_transferer`,
`pnj_prendre` et `pnj_pa_debiter` refusent la famille `soldat` tant que le drapeau
`pnj_transitions.soldats_blob_autoritaire` est vrai. Sans elle, une action UI aurait paru
réussir puis se serait défaite seule au déclenchement suivant du miroir.

**Ce qui reste ouvert, et pourquoi c'est sûr** : DONNER et RETIRER de l'argent et des objets.
Ces deux axes **n'existent pas dans le blob** — un soldat n'avait ni bourse ni inventaire avant
le socle. Aucune divergence n'est possible, et le comparateur le confirme.

**Contrainte réelle rencontrée, non contournée** : les RPC militaires prennent un NOMBRE
(`p_nb integer`), jamais un soldat désigné. « Faire quitter le groupe à CE soldat » n'est donc
pas exprimable côté blob pendant la phase miroir. L'écran CONDUITE d'un soldat le dit en clair
et renvoie vers l'ordre de section.

### Deux anomalies rencontrées, du même piège PL/pgSQL

1. `ROW_COUNT_PLACEHOLDER_NON_UTILISE` laissé dans `pnj_miroir_compagnie` — corrigé avant tout
   usage.
2. `jsonb_agg` contenant `row_number() OVER (...)` dans `pnj_possessions_lire` — SQL invalide,
   **accepté à la création** et découvert à l'appel réel :
   `42803 aggregate function calls cannot contain window function calls`.

Les deux illustrent la même leçon : **PL/pgSQL ne valide le corps des requêtes qu'à
l'exécution**. Une migration qui « réussit » ne prouve rien ; seule une exécution réelle le fait.

### Recette navigateur — compte jetable, jamais celui de Vince

```
1.  chargement, personnage de banc                              OK
2.  lecture du socle : 3 PNJ, 3 miens, familles employe,employe,soldat  OK
3.  popup : titre « Groupe PNJ », 3 cartes, bourse 40 affichee   OK
4.  possessions chargees : « Matraque de banc », 2 « aucune »    OK
5.  ecran DONNER : inventaire REEL du joueur (Cle a molette, Pain), liquide 500  OK
6.  DONNER un objet                                             ok
7.  DONNER 25                                                   ok
8.  RETIRER 25                                                  ok
9.  RETIRER l'objet                                             ok
10. RETIRER plus que la bourse            -> refus fonds_insuffisants
11. quitter le groupe sur un SOLDAT       -> refus soldat_axe_blob_autoritaire
12. quitter le groupe sur un EMPLOYE      -> ok, detache
13. entrainement d'un VRAI soldat : 24 matricules lus, formation resolue  OK
14. F5 : position stable, 2 cartes = 2 miens, aucune duplication  OK
```

État après recette, avant nettoyage : le joueur de banc retrouve `liquide 500`, `arg 500` et
ses 2 objets — **aller-retour parfaitement réversible**, invariant `arg = liquide` tenu. Le PNJ
détaché est **matérialisé sur place, sans leader**, à `stade/terrain`.

Comparateur après la recette : **96 / 96 / 96, 0 divergence.**

Banc entièrement supprimé : 96 PNJ (tous soldats), 0 possession, 0 événement, quatre PJ réels
seulement, blob `md5 = a107192a…` et `updated_at = 2026-09-22 22:29:35` inchangés.

## Bascule des lectures — 3 sur 8, puis ARRÊT motivé

Migrations `socle_pnj_metier_mutin`, `socle_pnj_bascule_lecture_mutinerie_camps`,
`socle_pnj_bascule_lecture_bataille_recruter`.

### Le champ `mutin` manquait

Trois des sept lectures restantes le lisent (`mutinerie_camps_presents`,
`militaire_bataille_engager`, `militaire_bataille_recruter`) et je ne l'avais pas copié.
Aucun soldat ne le porte aujourd'hui — mais une équivalence vraie aujourd'hui et fausse au
premier soulèvement n'est pas une équivalence. Ajouté à `pnj_soldats_metier` (métier, pas
socle : « mutin » est le camp d'un révolté), porté par le miroir, **et désormais comparé** —
sans quoi une divergence sur ce champ serait passée inaperçue.

### Deux lectures basculées et prouvées

`mutinerie_camps_presents` — équivalence sur **5 positions** (position de Vince, autre pièce de
la caserne, stade, hôtel, pays étranger) : identiques partout.

`militaire_bataille_recruter` — elle lit le blob mais écrit `batailles_engagements`, jamais le
blob : basculer sa lecture ne peut créer aucune divergence. Équivalence des ensembles
sélectionnés : 24 = 24, `EXCEPT` vide dans les deux sens.

Le filtre réserve est **actif et discriminant**, mesuré : `24` avec, `96` sans.

### ARRÊT sur les 5 autres — un champ non copié les invalide

En lisant `militaire_bataille_combattants`, j'ai découvert une clé que je n'avais pas vue :
**`accessoires`**. Un soldat en porte un en production — une trousse de premiers secours,
objet complet avec `produitMilitaire`, `usageUnique`, image. **Ce sont ses possessions**, et le
socle ne les a pas : `pnj_possessions` est vide pour les soldats.

Conséquences, toutes deux réelles :

1. **Cinq fonctions lisent `accessoires`**, dont **trois des cinq lectures restantes** :
   `agent_garde_observer`, `militaire_entree_zone`, `militaire_observer`. Les basculer sans
   porter ce champ aurait été une régression sémantique silencieuse — exactement le piège
   `en_reserve`, une seconde fois.
2. **Ma popup mentait** : elle affichait « possessions : aucune » pour le soldat qui porte la
   trousse, parce qu'elle ne lisait que `pnj_possessions`. Corrigé : pour un soldat, elle
   additionne les deux sources — le socle (ce que le joueur lui a donné) et `accessoires` du
   blob (équipement militaire d'origine, pas encore migré) — plutôt que d'en taire une.

Autre constat, noté sans le « corriger » : les soldats n'ont **aucune clé `nom`**.
`militaire_bataille_combattants` fait `sol->>'nom'`, qui vaut donc toujours NULL. Basculer cette
lecture sur le socle changerait cette valeur en matricule — un changement de comportement,
même s'il paraît meilleur. Je ne l'ai pas fait.

Le comparateur ne compare pas les possessions : il est resté vert pendant tout ce temps alors
que ce trou existait. C'est une limite du comparateur à corriger avant la bascule d'autorité.
