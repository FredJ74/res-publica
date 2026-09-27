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
- `pnj_membres` a reçu `liquide numeric` et les six colonnes de caractéristiques, absentes de la
  première esquisse. **Elles s'appellent depuis le 27/09 `car_int/cha/vol/per/dup/ent`** : la
  première version portait `car_for`, qui ne correspondait à aucun référentiel réel (cf. lot 1
  plus bas) ;
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

## Checkpoint possessions

Migrations `socle_pnj_comparateur_possessions`, `socle_pnj_miroir_possessions`.

### Cartographie exhaustive de `accessoires`

**Un seul porteur** : le soldat `202609-001`, section `…-s1` (celle de Vince). **Un seul objet** :
une trousse de premiers secours, `id = mil-39fe0df67eb54489968d1feccec29d46`, 11 clés
(`desc, icon, id, imageUrl, legal, name, origineMilitaire, produitMilitaire, sousType, type,
usageUnique`), `usageUnique: true`, **sans champ `quantite`**. Aucun réserviste n'en porte.

Surface de code, complète :
- **3 lectures** — `agent_garde_observer`, `militaire_entree_zone`, `militaire_observer` —
  toutes cherchant `produitMilitaire = 'tenue_camouflage'` pour le calcul de détection ;
- **2 écritures**, toutes deux réécrivant le blob : `militaire_equiper_accessoire` (client) et
  `militaire_gilet_absorber` (serveur). **Le déclencheur miroir les couvre donc déjà** : je n'ai
  eu à toucher ni l'une ni l'autre ;
- **1 lecture cliente** : `plateau-politique.js:10870`.

### Le comparateur étendu, et la preuve qu'il voyait le trou

Étendu **avant** la migration, exprès. Il compare les possessions par **objet entier** et par
rang d'occurrence — un attribut modifié ou un exemplaire en double est donc une divergence.

Avant migration, il a bien détecté :
```
ok: false, possessions_blob: 1, possessions_socle: 0
detail: { matricule 202609-001, objet « Trousse de premiers secours »,
          divergence possession_absente_du_socle }
```

Une distinction a été nécessaire, et ce n'est pas une règle inventée : `pnj_possessions.origine`
vaut `blob_accessoires` ou `socle`. Le comparateur ne confronte au blob que le premier
sous-ensemble — sinon tout objet légitimement **donné par un joueur** serait déclaré
surnuméraire, le blob ne le connaissant pas. Colonne destinée à disparaître à la bascule.

### Migration : le miroir *est* la migration

Le miroir a été étendu aux possessions, en **différentiel** et non en destruction-reconstruction.
Ce n'est pas une coquetterie : `pnj_possessions_lire` numérote par ordre d'id et
`pnj_objet_transferer('retirer')` désigne par cet index. Un miroir qui recréerait tout ferait
glisser les index entre la lecture et l'écriture.

L'appeler une fois a donc réalisé la migration, objet complet, **11 clés préservées**,
`exemplaire_unique` dérivé de `usageUnique`. Trois passes de plus : toujours **1 possession,
id inchangé (6)** — idempotent et sans churn.

Miroir éprouvé **dans les deux sens** par une écriture réelle strictement réversible :
```
ajout d'un accessoire dans le blob   -> possessions_blob 2, possessions_socle 2, 0 divergence
restauration depuis le snapshot      -> retour a 1, objet de banc retire automatiquement
                                        md5 du blob et updated_at identiques, id 6 intact
```

### Une seule source pour la popup

L'addition de deux sources est supprimée : la popup lit uniquement `pnj_possessions`. **Aucun
repli sur `accessoires` n'a été conservé** — le miroir garantit la complétude, et deux sources
tenues pour équivalentes finissent toujours par diverger.

Détail attrapé au passage : les objets du jeu nomment leur libellé tantôt `nom` (inventaire des
joueurs) tantôt `name` (équipement militaire). L'affichage accepte les deux ; rien n'est réécrit
en base.

## Les 8 lectures militaires sont basculées

| lecture | source | filtre réserve | équivalence |
|---|---|---|---|
| `militaire_detachement_ici` | socle | oui | prouvée (1 ligne, effectif 24, `EXCEPT` vide) |
| `mutinerie_camps_presents` | socle | oui | prouvée sur **5 positions** |
| `militaire_bataille_recruter` | socle | oui | prouvée, ensembles 24 = 24 |
| `militaire_observer` | socle | oui | prouvée sur **banc camouflage** |
| `agent_garde_observer` | socle | oui | prouvée sur **banc camouflage** |
| `militaire_entree_zone` | socle | oui | prouvée, **ses deux blocs** |
| `militaire_bataille_engager` | socle | oui | par construction (même motif, 3× prouvé) |
| `militaire_bataille_combattants` | socle | **non, et c'est correct** | par construction |

`militaire_bataille_combattants` n'a **pas** de filtre réserve, volontairement : ce n'est pas une
lecture de présence mais une recherche **par identité** de soldats déjà engagés. Y ajouter le
filtre aurait été inventer une règle.

Deux références au blob subsistent, **délibérées** : `militaire_bataille_recruter` et
`militaire_detachement_ici` joignent `compagnies_militaires` pour l'identifiant de compagnie et
pour le Lieutenant/mission de la section — du métier pur, qui n'a pas sa place dans le socle.

### Une subtilité qui allait à l'encontre du réflexe

`militaire_observer`, `militaire_entree_zone` et `militaire_bataille_engager` ne veulent **pas**
la position effective : elles exigent une position **propre** (`ville <> ''`, ou
`leaderCourant IS NULL`). Un soldat qui suit son chef est donc volontairement **invisible** — on
ne repère pas une troupe en mouvement derrière son officier comme un campement. Utiliser
`pnj_position_effective` y aurait **ajouté des cibles** : un changement de gameplay. Ces
lectures lisent donc les colonnes propres, sans passer par la primitive.

### Le banc camouflage

Les données de production ne permettaient pas de prouver l'équivalence : aucun soldat ne porte de
tenue de camouflage, et les 24 suivent Vince (donc sans position propre). Banc construit par
écriture réelle du blob, strictement réversible :

```
4 soldats de section stationnes a capitale/stade, dont 1 en tenue de camouflage
  militaire_observer      : 1 groupe des deux cotes, republic/capitale/stade n=4 camo=1
                            reco identique, EXCEPT vide dans les deux sens
  agent_garde_observer    : 1 = 1, capitale/soviet -> republic/capitale/stade n=4 camo=1
                            et correctement VIDE pour capitale/republic et pour caserne
  militaire_entree_zone   : bloc « mes soldats » 20 = 20 camo 0 = 0
                            bloc « ennemi »      4 = 4  camo 1 = 1
restauration depuis le snapshot :
  md5 a107192a... et updated_at 2026-09-22 identiques, 24 sous Vince, 72 en reserve,
  1 possession (la trousse), 0 residu de banc, PA 12-12
```

Le camouflage est compté sur `origine = 'blob_accessoires'` uniquement, volontairement :
l'ancienne lecture ne voyait que `accessoires`, et compter une tenue **donnée par un joueur**
ferait entrer dans le calcul de détection un objet que le code historique ignorait. La
restriction tombera d'elle-même à la bascule.

### `nom` reste NULL

Consigne respectée à la lettre dans `militaire_bataille_combattants` : les soldats du blob n'ont
aucune clé `nom`, l'ancienne lecture rendait donc toujours NULL, et la nouvelle rend
explicitement `NULL::text` — et non le matricule, dont le socle disposerait.

---

# 27 septembre 2026 — Propriété / autorité / leader, puis la mort

Ce qui suit corrige les défauts que l'audit hostile avait nommés. Chaque correction est vérifiée
par exécution, jamais par relecture : **PL/pgSQL ne valide le corps d'une requête qu'à
l'exécution**, une migration qui « réussit » ne prouve donc rien.

## Le modèle, et ce que le socle refuse de savoir

| Concept | Où il vit | Qui le résout |
|---|---|---|
| **Propriété** personnelle | `pnj_membres.proprietaire_pj` | le socle |
| **Propriété** institutionnelle | `proprietaire_institution` + `proprietaire_perimetre`, deux chaînes **opaques** | le socle les stocke, ne les interprète jamais |
| **Autorité** | registre `pnj_institutions` → fonction fournie par le métier | **le métier**, jamais le socle |
| **Leader** | `leader_pj` / `leader_pnj_id` | le socle |

`militaire_autorite_de_perimetre` est **le seul endroit** où le mot « lieutenant » a le droit
d'exister. Elle reproduit la porte historique `militaire_section_de_moi` — pays de la compagnie
et `section.lieutenantNom` — **sans la durcir** : pas de contrôle du poste porté, parce que la
porte historique ne le fait pas et que l'ajouter serait inventer une règle.

**Propriété institutionnelle n'implique pas autorité humaine.** Les 72 réservistes appartiennent
à l'institution militaire ; **personne** ne les administre. C'est un état valide, pas une erreur,
et aucune fonction ne désigne de dépositaire par défaut.

## Les défauts fermés

**L'autorité était fausse.** `pnj_administrateur` résolvait `proprietaire_poste='lieutenant'`
par un `LIMIT 1` **sans `ORDER BY`** : avec deux Lieutenants le propriétaire d'un soldat devenait
non déterministe, et vérifié en base, `pnj_peut_commander('Vince Kubrick', <réserviste>)`
renvoyait `TRUE`. Le socle avait perdu le lien périmètre ↔ autorité que le blob tient.

**Le prédicat unique mélangeait deux droits.** `pnj_peut_commander` est supprimée, remplacée par
`pnj_peut_administrer` (patrimoine : inventaire, argent, cession — **plus la co-présence
physique**) et `pnj_peut_conduire` (mouvement et groupe, leader courant inclus). Aucun des trois
verbes de conduite ne touche `proprietaire_*` : un leader transporte, il n'acquiert rien.

**Défaut trouvé par les tests, pas par relecture.** Les prédicats rendaient `NULL` — et non
`false` — quand l'autorité est à personne. Or `NOT NULL` vaut `NULL`, la branche de refus n'était
donc pas prise et **la garde s'ouvrait précisément dans le cas qu'elle devait fermer**. Les
prédicats sont rendus totaux (`IS TRUE`). C'est la correction du défaut précédent qui a armé
celui-ci : avant, la résolution renvoyait toujours un nom.

**Le comparateur testait une constante.** `s.proprietaire_poste IS DISTINCT FROM 'lieutenant'`
était faux pour les 96 soldats, réservistes compris : le test ne pouvait rien détecter. Il compare
désormais le périmètre réel, et sa sensibilité est **prouvée** (déplacer un soldat en `-s2` produit
`divergence: perimetre`).

**La duplication d'objets (B1).** Reprendre une possession d'`origine='blob_accessoires'` la
copiait dans l'inventaire du joueur tandis que le blob la gardait, puis le déclencheur recréait la
ligne miroir : deux objets pour un. Ces objets ne sont plus cessibles (`objet_non_cessible`), et
l'interface n'en propose plus le bouton.

**Le miroir ne rattrapait ni le périmètre ni le statut.** Son `ON CONFLICT` ignorait la propriété :
un réserviste versé dans une section neuve restait administré par personne. Et `statut` était
absent : un soldat marqué mort dans le socle y restait mort contre l'avis du blob.

**`pnj_membres_ici` croyait le client.** Elle filtrait sur les coordonnées transmises par le
navigateur. Elle emploie la position serveur et **le même prédicat de co-présence que les verbes**,
de sorte que *listé ⟺ actionnable*. Des coordonnées mensongères renvoient la même liste.

## Les quatre compteurs anti-rejeu

`dernier_ration`, `nb_ration`, `dernier_bivouac`, `dernier_sommeil` entrent dans
`pnj_soldats_metier` — pas dans `pnj_membres` : « ne pas rejouer un ordre militaire le même jour »
n'a aucun sens générique. **Aucun des 96 soldats ne les portait**, ce qui rendait le trou
invisible : la copie paraissait fidèle parce qu'il n'y avait rien à perdre. Au premier ordre de
ration le socle aurait divergé en silence, et un soldat aurait pu manger deux fois.

Stockés en **texte**, pas en `date` : le socle miroite, il ne réinterprète pas. La comparaison
reste exacte et totale, sans cast susceptible d'échouer. `nb_ration` reste **séparé** de son
marqueur, parce que le métier applique « ancien marqueur sans compteur vaut 1 ».

Vérifié par exécution : écriture du blob → le déclencheur porte les quatre valeurs → comparateur
vert ; puis en cassant `nb_ration` et `dernier_sommeil`, le comparateur les **nomme**.

## La mort générique, et le combat qui la contournait

À 0 PA, `militaire_bataille_appliquer` appelait `militaire_soldat_supprimer`, qui retire l'homme
du blob ; le déclencheur constatait son absence et supprimait la ligne du socle en cascade. Donc :
`pnj_mourir` **jamais appelé**, aucun avis au propriétaire, rien au sol, et les `accessoires` du
soldat **détruits sans trace** — la trousse de premiers secours d'un des 96 hommes de Vince
disparaissait purement et simplement.

Le chemin passe désormais par le cycle : `pnj_mourir(id, 'degats')` **d'abord**, retrait du blob
**ensuite**. Dans cet ordre seulement — après le retrait il n'y aurait plus ni possessions à poser
ni propriétaire à prévenir. L'avis est **inconditionnel** : aucune radio, aucune co-présence.
`pnj_evenements` n'a aucune clé étrangère, l'avis survit donc à la suppression de la ligne.

Prouvé de bout en bout : la trousse atterrit à `caserne/caserne-militaire/corps_garde`, l'avis
porte `objets_deposes=1` et `argent_du_defunt=37`, l'effectif passe à 23, et le comparateur reste
vert à 95/95 avec 0/0 possessions — ni duplication ni perte.

### L'argent au sol : une lacune que je ne comble pas seul

La règle dit « objets **et argent** déposés au sol ». Or le jeu n'a **aucune** mécanique d'argent
au sol : `objets_abandonnes` ne transporte que des objets, et le vol transfère l'argent de main à
main sans jamais le poser. Fabriquer un objet « bourse » créerait un objet ramassable qu'aucun
chemin ne sait reconvertir en liquide — une mécanique nouvelle, donc une décision de game design.
Le montant est donc **inscrit dans l'avis de mort** (`argent_du_defunt`), visible du propriétaire :
rien n'est inventé, rien ne disparaît sans trace. Les 96 soldats portent 0 aujourd'hui.

## Deux gardes fail-closed — après preuve métier, pas avant

J'ai d'abord recensé tous les chemins qui retirent un soldat PNJ du blob. Il y en a **exactement
un** : `militaire_soldat_supprimer`, appelée uniquement par la bataille, uniquement à 0 PA. Les
trois suspects sont innocents — `militaire_desertions_verifier` et
`militaire_presentation_affectation` ne touchent que `civilsRequisitionnes`,
`militaire_soldat_retirer` que les soldats **PJ** que le miroir ignore déjà. **Sans cette
vérification, une garde stricte aurait cassé la désertion.**

- `trg_pnj_garde_suppression` (BEFORE DELETE sur `pnj_membres`) refuse de supprimer un PNJ
  `actif` : le cycle de mort n'a pas eu lieu.
- `trg_pnj_garde_dissolution_compagnie` (BEFORE DELETE sur `compagnies_militaires`) refuse tant
  que des PNJ du socle en dépendent — sinon leur périmètre désignerait une compagnie disparue et
  l'autorité se résoudrait à personne pour toujours, dégradation sans danger mais **silencieuse**.

Ce sont des gardes, pas des règles de dissolution : elles n'inventent aucun comportement, elles
exigent seulement qu'on passe par celui qui existe.

## Les quatre tests obligatoires, et les autres

Exécutés sous identité réelle (`request.jwt.claims`), écritures de mise en situation **annulées** :
aucune donnée de Vince modifiée, blob `md5 a107192a41d5cd1153808c302d60d0a9` et `updated_at` du
22/09 inchangés.

```
Vince + soldat de SA section       administrer = t     <- exigé OUI
Vince + réserviste                 administrer = f     <- exigé NON
Vince + soldat d'une autre section administrer = f     <- exigé NON
second Lieutenant + section Vince  administrer = f     <- exigé NON
Arnie (min_def) + soldat de Vince  administrer = f        le socle ignore « min_def »
autorité(section s1) = Vince Kubrick ; autorité(réserve) = NULL = PERSONNE
leader non propriétaire : conduire = t, administrer = f, argent refusé, consultation refusée
RPC réelles : consultation d'un réserviste refusée (autorite_insuffisante), la sienne acceptée
duplication : cessible=false, retrait refusé (objet_non_cessible), inventaire de Vince intact
gardes : suppression d'un vivant refusée, dissolution refusée (96 PNJ)
```

## Ce qui reste ouvert

- **Argent au sol** : mécanique inexistante, arbitrage nécessaire (objet ramassable ? crédit au
  propriétaire ? perte ?).
- `banc_socle_pnj.sql` encode encore l'ancien modèle (`proprietaire_poste`) : à refaire avec le
  banc de bataille.
- Deux PNJ de banc (`zzaut-mien`, `zzaut-autre`) et le personnage `zzAut` restent en production,
  volontairement : ils servent aux recettes navigateur à venir. À retirer à la clôture.

## Compagnie explicite, et deux arbitrages ration / bivouac

**Le rattachement à la compagnie était une convention de chaîne.** `m.id LIKE p_compagnie || '-%'`,
employé par le miroir, le comparateur, l'outil de copie et les gardes. `pnj_soldats_metier` porte
désormais `compagnie_id` — **donnée métier**, pas générique : le socle n'a pas à savoir ce qu'est
une compagnie. Écrite à la source (le miroir la reçoit déjà en paramètre, il n'a rien à déduire) et
surveillée par le comparateur. Les `LIKE` existants restent en place : les changer en même temps
que le modèle d'autorité aurait mêlé deux risques.

**Ration : la ration du soldat passait après celle du chef, en fait jamais.**
`militaire_ordre_collectif` ne regardait que l'inventaire du leader. Un soldat portant sa propre
ration — de l'armurerie (blob `accessoires`) ou de la main d'un joueur (`pnj_possessions`) — ne la
mangeait jamais. Ordre appliqué : la sienne d'abord, celle du chef ensuite. Le chef ne complète que
le reste.

**Bivouac : la tente comptait 13 soldats au lieu de 13 personnes.** La règle est « 1 tente =
13 PERSONNES, le leader compte » : 1 leader + 12 PNJ. Pour 13 soldats il faut désormais 2 tentes.

**J'ai étendu l'arbitrage à l'ordre DORMIR**, où la capacité était écrite une seconde fois
(`militaire_reposer_section`). N'en corriger qu'une laisserait la même tente abriter 13 dormeurs et
12 bivouaqueurs, le même soir, sur le même objet. Pour révoquer : remettre 13 dans
`c_pnj_par_tente` de cette fonction, rien d'autre n'a changé.

**Le prédicat d'éligibilité était écrit deux fois** dans `militaire_ordre_collectif` — une fois pour
compter, une fois pour appliquer, « à l'identique » disait le commentaire. Deux copies d'une même
règle finissent toujours par divergier. Il est désormais évalué une seule fois, en passe 1, et
mémorisé.

**L'ordre individuel n'est pas une seconde fonction.** Servir un homme désigné obéit aux mêmes
règles que servir le groupe : on ajoute un simple filtre de bénéficiaires (`p_matricules`, NULL =
tout le groupe, comportement historique inchangé). `militaire_ordre_pnj(pnj_id, action)` traduit un
identifiant de PNJ en compagnie/section — premier usage concret de `compagnie_id` — et délègue. Le
client n'envoie ni compagnie, ni section, ni leader.

### Bancs exécutés, tous en transaction annulée

```
BANC DE BATAILLE (compagnie jetable, jamais celle de Vince)
  declencheur           : 3 PNJ + 1 possession, perimetre et compagnie corrects
  autorite              : Marsault t / Vince f / Arnie f
  degats partielle_1    : 12 PA -> 3 PA, comparateur vert
  degats critique       : 0 PA -> cycle de mort, gourde au sol a capitale/stade/terrain,
                          avis objets=1 argent=19, comparateur vert 2/2 poss 0/0
  dissolution           : refusee (2 PNJ en dependent)
  compagnie de Vince    : md5 et comparateur inchanges

BANC RATION / BIVOUAC
  bivouac 13 PNJ / 1 tente  : refus tentes_insuffisantes requis=2 pnj_par_tente=12
                              capacite_personnes=13, AUCUN PA touche (tous a 5)
  bivouac 13 PNJ / 2 tentes : 13 servis, PA 5->6, 2 tentes toujours la
  bivouac rejoue            : aucun_soldat_concerne
  ration 13 / 1 au chef     : refus, requis=11 (13 - 2 qui ont la leur), propres=2
  ration 13 / 11 au chef    : 13 servis, propres=2 du_chef=11, PA 6->7,
                              ration blob consommee, ration socle consommee, chef a 0
  plafond 2/jour            : 1re et 2e servies (nb_ration 1 puis 2), 3e refusee,
                              exactement 4 rations consommees, compteurs miroites

ORDRE INDIVIDUEL
  E-002 seul servi (E-001 et E-003 inchanges a 4 PA), 1 ration du chef
  bivouac individuel : 1 tente requise
  sur un reserviste  : soldat_en_reserve
  par un autre officier : autorite_insuffisante
```

### Recette navigateur (compte jetable zzAut, aucune donnée de joueur touchée)

Premier passage **contre le site déployé**, donc l'ancien client : il a prouvé les refus serveur
(`autorite_insuffisante` en lecture ET en retrait d'argent sur le PNJ d'Arnie) et **aucune écriture
hors RPC** — 8 appels réseau, 0 `POST/PATCH/DELETE` sur une table. Il a aussi montré que l'ancien
client offrait encore « Retirer » sur un objet non cessible : c'est ce que le nouveau corrige.

---

# LOT 1 — Le contenant générique des six caractéristiques (27 septembre 2026)

Premier lot du plan de convergence. **Portée strictement limitée au contenant** : aucune valeur
métier n'est posée, aucun gameplay n'est touché, et rien n'est introduit qui créerait une
dépendance vers les objets ou les effets — ceux-ci appartiennent au lot 10.

## Ce qui était faux

Le socle portait `car_for` (Force) et n'avait pas `car_ent` (Entregent). Or les six
caractéristiques du jeu sont **INT, CHA, VOL, PER, DUP, ENT** : `FOR` n'est la caractéristique
d'aucun personnage joueur — elle ne venait que d'une table de PNJ héritée. Le socle décrivait donc
un référentiel qui n'était celui de personne.

## Pourquoi maintenant, et pas plus tard

Recensement exhaustif fait **avant** d'écrire la migration : aucune fonction, aucune vue, aucun
index, aucune valeur par défaut, aucune policy et aucun déclencheur ne lisait `car_for` ; la seule
référence était la contrainte de bornes ; et les 96 lignes avaient leurs six colonnes à NULL. Le
renommage ne pouvait donc casser aucun comportement.

Dès qu'une valeur métier y sera écrite — lots 2 et 5 — ce ne sera plus vrai. **C'est précisément
pour cela que le référentiel est corrigé avant la première valeur**, et non après.

## Ce qui a été appliqué

- `car_for` renommée en `car_ent`, avec un commentaire sur chacune des six colonnes ;
- contrainte `pnj_car_bornes` reprise à l'identique sur les six noms cibles — mêmes bornes, même
  sémantique : NULL reste autorisé (caractéristique non encore posée), toute valeur présente reste
  dans 0..100 ;
- trois primitives de lecture de la **valeur de base uniquement**, fermées au client :
  - `pnj_caracteristiques_cles()` — le référentiel écrit une seule fois, pour que rien ne recopie
    six noms à la main ;
  - `pnj_caracteristiques_base(pnj_id)` — les six valeurs écrites dans la ligne ;
  - `pnj_caracteristique_base(pnj_id, cle)` — une valeur ; **une clé inconnue lève** au lieu de
    rendre NULL en silence, pour qu'une faute de frappe dans une formule se voie tout de suite.

Ces primitives ne composent rien. Le jour où une valeur **effective** existera, ce sera une
fonction distincte construite par-dessus celles-ci — jamais une modification de celles-ci, pour
qu'on puisse toujours lire la base sans composition.

## Preuves, toutes par exécution

```
colonnes                    car_ent, car_cha, car_dup, car_int, car_per, car_vol
référentiel                 INT, CHA, VOL, PER, DUP, ENT
lecture base d'un soldat    les six clés, toutes à NULL
PNJ inexistant              NULL (et non une erreur)
clé « FOR »                 REFUSÉE, message nommant le référentiel
clé « per » en minuscules   REFUSÉE (sensible à la casse)
bornes 0 et 100             acceptées
borne 101                   refusée par pnj_car_bornes
borne -1                    refusée par pnj_car_bornes
```

État après migration : **96 soldats actifs**, PA 12, 1 possession, **0 ligne renseignée**,
comparateur **96/96 et 1/1, 0 divergence**, blob `md5 a107192a41d5cd1153808c302d60d0a9` et
`updated_at` du 22/09 **inchangés**. Aucune fonction ne lit plus `car_for`. Les trois primitives
sont fermées à `authenticated`.

Les essais de bornes ont été faits en **transaction annulée** : aucune caractéristique n'est
restée écrite.

## Rollback

Aucune donnée à restaurer, les colonnes sont vides. L'inverse exact est consigné en tête de la
migration `socle_pnj_caracteristiques_referentiel_cible` : supprimer les trois primitives,
renommer `car_ent` en `car_for`, restaurer la contrainte d'origine.

## Ce que ce lot ne fait pas

Il ne renseigne aucune valeur, ne touche à aucun métier, n'introduit ni objet ni effet, et ne
modifie aucun comportement de jeu. **Le lot 2 (première famille Bêta, les douaniers) nécessite un
arbitrage de game design : les quatre caractéristiques manquantes du douanier.**

---

# LOT 2 — Douanier, première famille Bêta raccordée (27 septembre 2026)

Valeurs métier arbitrées par le concepteur : **INT 10, CHA 8, VOL 12, PER 12, DUP 8, ENT 10**.
PER et VOL reprennent exactement les valeurs historiques des fiches.

## La couche CLASSE, qui manquait

L'architecture est SOCLE → CLASSE → MÉTIER, mais rien en base ne distinguait un PNJ qui consomme
ses PA d'un PNJ qui n'en consomme pas. « Bêta ne consomme pas de PA » n'était qu'une intention.

**Une table, pas une colonne.** Une colonne `classe` sur `pnj_membres` aurait obligé à retoucher
tous les chemins d'écriture des soldats — le déclencheur miroir, l'outil de copie — alors que ce
lot doit les laisser strictement intacts. Or la classe n'est pas une propriété de l'individu :
c'est une propriété de sa **famille**. `pnj_familles_classes` dit exactement cela et ne touche
aucun chemin existant. Une famille **absente** de la table n'a pas de classe et les gardes la
refusent — on ne peut donc pas oublier de la déclarer.

`pnj_pa_debiter` contrôle désormais la classe **avant toute écriture** : seule `alpha` dépense ses
PA. Un lot mixte est refusé **en entier**, jamais appliqué à moitié.

## L'institution Douanes

`douane_autorite_de_perimetre` reproduit la porte historique sans la durcir : l'autorité est le PJ
portant le poste `chef_douanes` dans ce pays. Un périmètre inconnu n'ouvre aucune autorité. Et
**un titulaire PNJ du poste n'est pas une autorité** — tant qu'aucun PJ ne le porte, l'autorité est
à personne, même doctrine que la réserve militaire.

La liste blanche serveur des caractéristiques s'élargit aux six **pour les douaniers seulement** ;
la branche police reste strictement inchangée.

## Le piège évité, et il aurait cassé la paye chaque nuit

Le miroir des soldats **supprime** les lignes absentes du blob. Impossible ici :
`trg_pnj_garde_suppression` refuse de supprimer un PNJ `actif`, et un douanier retiré faute de
budget **n'est pas mort** — il quitte le service. Copier le patron militaire aurait fait échouer la
tâche de paye nocturne à chaque nuit où la caisse est vide.

Le miroir ne supprime donc pas : il marque `disparu`. C'est aussi plus juste, et cela garde une
trace. Le comparateur ne regarde que les lignes `actif`.

## Première bascule de lecture

L'équivalence prouvée, une lecture bascule — délibérément la **moins conséquente** : la
consultation publique des effectifs, un pur affichage ouvert à tous, sans effet de jeu. Même
démarche que `militaire_detachement_ici` pour les soldats.

Ne basculent **pas** : la paye, le recrutement, le licenciement et le contrôle de fret continuent
de lire et d'écrire `effectifsDouane`. Le blob reste l'autorité.

Effet de bord assumé et bénéfique : la consultation ne déclenche plus l'amorçage éphémère de
4 douaniers que l'audit avait relevé. En production la clé existe, la liste est donc identique.

## Preuves, toutes par exécution

```
CLASSE ET PA
  classe du douanier                     beta      PA 12
  débit de PA sur un Bêta                REFUSÉ    classe_sans_consommation_de_pa
  PA après la tentative                  12
  lot mixte Bêta + soldat                REFUSÉ en entier

LES SIX CARACTÉRISTIQUES
  {INT 10, CHA 8, VOL 12, PER 12, DUP 8, ENT 10}      4 lignes complètes sur 4

AUTORITÉ
  aujourd'hui                            NULL (aucun PJ ne porte le poste)
  avec un PJ Chef des Douanes            résolue vers lui
  administrer : Chef t · Vince f · Arnie f
  consultation par le Chef à distance    pas_co_presents
  périmètre inconnu                      NULL

PAYE ET MIROIR
  paye normale                           200 FR = 4 × 50, caisse 68740 → 68540
                                         comparateur 4/4
  caisse insuffisante (120 FR)           versé 120, 2 agents partis,
                                         LE MIROIR NE LÈVE PAS
                                         socle 2 actifs + 2 disparus, comparateur vert
  lecture basculée                       IDENTIQUE au blob, au caractère près

AUCUNE RÉGRESSION
  soldats 96/96, comparateur vert, blob md5 a107192a inchangé, updated_at du 22/09
```

Les essais de paye ont tourné en **transaction annulée** : aucune caisse n'a été débitée, aucun
douanier n'a réellement quitté le service, aucun poste n'a été attribué. Seule la copie initiale
des 4 douaniers est réelle.

## État après lot

100 PNJ au socle : **96 soldats (alpha) + 4 douaniers (bêta)**. Deux institutions enregistrées,
deux classes déclarées. Toutes les fonctions techniques fermées au client ; seule
`douane_effectifs_publics` est ouverte, et c'est une lecture publique.

## Rollback

Le blob `effectifsDouane` n'a pas été modifié. Pour revenir : rétablir l'ancienne
`ouvrirConsulterEffectifsDouane`, supprimer le déclencheur `trg_pnj_miroir_douane`, puis
`DELETE FROM pnj_membres WHERE famille='douanier'` après avoir passé leur `statut` à `disparu`
(la garde refuse la suppression d'un PNJ actif — c'est son rôle).

**Le lot 3 (police) nécessitera un arbitrage : ses quatre caractéristiques manquantes, et le
déplacement de sa paye du navigateur vers le cron.**

---

# LOT 3 — Policier, deuxième famille Bêta (27 septembre 2026)

Valeurs métier arbitrées : **INT 10, CHA 8, VOL 12, PER 12, DUP 8, ENT 10**. PER et VOL reprennent
exactement les valeurs historiques des fiches.

## La différence de fond avec le douanier : la police est multi-ville

Le périmètre porte donc la ville — `<ville>:<batiment>` — et l'autorité est le Commissaire **de
cette ville**, pas n'importe quel Commissaire du pays. C'est ce que la garde d'écriture des
effectifs exigeait déjà ; c'est l'autorité de **caisse** qui ne le vérifiait pas.

Vérifié : un Commissaire de la capitale n'a **aucune** autorité sur un policier de `zztest-ville`
(autorité `NULL`, `administrer = f`).

## La fuite financière, et sa double correction

La paye était prélevée par le `doDormir()` de **n'importe quel joueur présent dans la ville**. Or
le débit de la caisse du commissariat n'exige que le **poste** (`{commissaire, min_int}`), jamais
la **ville**, alors que l'écriture des effectifs exige le commissaire de cette ville. Un
commissaire d'une autre ville, ou le ministre de l'Intérieur, qui dormait là : le débit passait,
l'écriture était refusée. **Argent sorti de la caisse, `dernierPaiementJour` non avancé, aucun
policier payé ni retiré.**

Deux corrections complémentaires :

1. **La paye devient une tâche de cron** (`paye_police`), comme la douane. Le chemin client
   disparaît, donc la fuite n'a plus d'occasion de se produire.
2. **L'autorité de caisse apprend la ville**, pour que la même fuite ne revienne pas par une autre
   porte. Les caisses locales s'appellent `<pays>_<catégorie>_<ville>` : la ville était déjà dans
   l'identifiant, il suffisait de la lire. Règle volontairement minimale — un poste **national**
   (sans ville) conserve son accès, un poste **de ville** ne peut agir que sur la sienne. Un
   séparateur `_` désigne une ville, un `-` n'en désigne pas une : `commissariat-local` reste un
   bâtiment.

Le refus est journalisé sous un motif distinct, `autorite_insuffisante_hors_ville`, pour qu'on
puisse le distinguer d'un simple défaut de poste.

**Portée de cette correction, et ce qui reste.** Elle est appliquée à
`caisse_institution_mouvement_plafonne`, la porte qu'emprunte la paye et que l'audit avait
exercée. Les deux fonctions sœurs — `caisse_institution_mouvement` et `caisse_client_mouvement` —
partagent le même défaut et servent la mairie, le tribunal, l'entrepôt : les corriger mérite un
lot de sécurité dédié, avec ses propres tests. C'est consigné, pas fait ici.

## Preuves, toutes par exécution

```
AUTORITÉ DE CAISSE PAR VILLE   (sous SET ROLE authenticated -- sinon la branche cliente
                                n'est pas empruntée et le test ne prouve rien)
  contexte                          est_appel_serveur = f, mon_personnage = zzAut
  commissaire de capitale → caisse de ville_a     REFUSÉ
  motif journalisé                  autorite_insuffisante_hors_ville
  commissaire de capitale → sa caisse             accepté, 10 versés
  min_int (poste national) → ville_a et capitale  accepté  (aucune régression)

SOCLE ET CLASSE
  caractéristiques    {INT 10, CHA 8, VOL 12, PER 12, DUP 8, ENT 10}
  classe beta, PA 12, institution police, périmètre zztest-ville:commissariat-local
  débit de PA                       REFUSÉ  classe_sans_consommation_de_pa, PA reste 12

AUTORITÉ
  aujourd'hui                       NULL (aucun PJ commissaire)
  commissaire DE la ville           autorité résolue, administrer = t
  commissaire d'UNE AUTRE ville     autorité NULL, administrer = f

LES TROIS FORMES DE POSITION
  non affecté        bâtiment NULL, pièce NULL, rue NULL
  affecté à une pièce  commissariat-local / accueil          comparateur vert
  affecté à la rue     rue-n3                                comparateur vert

PAYE
  caisse approvisionnée   50 FR pour 1 agent standard, caisse 200 → 150, comparateur vert
  second appel le même jour   versé 0, caisse inchangée      un seul prélèvement
  caisse vide                 1 agent parti, blob 0, socle 0 actif + 1 disparu,
                              LE MIROIR NE LÈVE PAS, comparateur vert

AUCUNE RÉGRESSION
  douane 4/4 · soldats 96/96 · blob militaire md5 a107192a inchangé
```

Tous les essais de paye et d'autorité ont tourné **en transaction annulée** : aucune caisse
débitée, aucun poste réellement attribué, aucun policier réellement retiré. Seule la copie du
policier dans le socle est réelle.

## État après lot

**101 PNJ au socle : 96 soldats (alpha) + 4 douaniers (bêta) + 1 policier (bêta).** Trois
institutions enregistrées, trois classes déclarées.

## Un point qui demande votre décision

Le **seul** effectif policier de la production est **1 agent dans `zztest-ville`**, une ville de
test — et la caisse `republic_commissariat_zztest-ville` **n'existe pas**. Au premier passage du
cron, la règle d'impayé s'appliquera donc : versé 0, l'agent quitte le service, le miroir le marque
`disparu`. Ce n'est pas une régression, c'est la règle qui s'applique enfin — le chemin client ne
s'était jamais déclenché faute de joueur dormant dans cette ville. Si vous préférez conserver cet
agent de test, il faut créer sa caisse ; sinon, laisser faire, ou supprimer la ville de test.

## Rollback

Les blobs `effectifsPolice` n'ont pas été modifiés. Pour revenir : retirer la tâche `paye_police`
du cron, rétablir l'appel client dans `doDormir` et retirer le `return;` de
`payerEffectifsPoliceQuotidien`, supprimer le déclencheur `trg_pnj_miroir_police`, puis passer les
policiers du socle en `disparu` avant de les supprimer. La correction d'autorité de caisse se
défait en retirant la clause de ville de `caisse_institution_mouvement_plafonne`.

**Le lot 4 portera sur la bascule par axe de la famille soldat.**

---

# LOT 4 — Bascule par axes de la famille Soldat (27 septembre 2026)

## Le vrai contenu du lot : séparer deux choses qu'un seul verrou disait à la fois

`pnj_axe_partage_verrouille` mélangeait :

- **(a) un état de MIGRATION** — « le blob fait encore autorité pour cette donnée », temporaire ;
- **(b) une règle de JEU** — « on ne déplace pas un soldat un par un », permanente : le modèle
  militaire opère par **nombre**, pas par soldat désigné.

Les confondre rendait la bascule tout-ou-rien : libérer (a) aurait libéré (b), c'est-à-dire changé
le gameplay. Deux tables les séparent désormais — `pnj_axes_autorite` pour (a),
`pnj_mouvement_individuel` pour (b) — et c'est ce qui rend l'incrémental possible. L'ancien verrou
est supprimé plutôt que laissé dormant.

## Défaut fermé au passage, introduit par le lot 2

Depuis que les douaniers ont une ligne au socle, **un Chef des Douanes co-présent au port les
voyait dans le popup de groupe et pouvait les PRENDRE** : il en est l'administrateur, donc
`pnj_peut_conduire` disait oui. Rien dans le jeu n'a jamais permis d'embarquer un douanier dans son
groupe. L'ancien verrou ne couvrait que la famille soldat et ne pouvait pas l'attraper ; la règle
de jeu, elle, couvre les trois familles.

## La matrice des axes, à la clôture

```
soldat    argent=socle   propriete=socle   possessions=socle   position_leader=blob   pa=blob
douanier  argent=socle   propriete=socle   possessions=socle   position_leader=blob   pa=socle
policier  argent=socle   propriete=socle   possessions=socle   position_leader=blob   pa=socle
```

### Axes déclarés au socle sans migration — ils y étaient déjà

- **argent** : le blob militaire n'a **aucune** notion d'argent. Cet axe n'a jamais eu de
  concurrent. Vérifié : 0 FR sur les 96, aucun écrivain concurrent.
- **propriété / autorité** : résolues par le socle et le registre des institutions depuis le
  27/09. Le blob ne décide que le **périmètre** — section ou réserve — qui est une donnée métier
  et le reste.

### Axe basculé : possessions

Les **lectures** étaient au socle depuis le 26/09. Seules les **écritures** restaient dans
`soldat.accessoires`. Recensement avant d'écrire : trois écrivains, et trois seulement —
`militaire_equiper_accessoire`, `militaire_gilet_absorber`, `militaire_ordre_collectif`.

**Le point le plus dangereux, traité explicitement.** Sans arrêter le miroir de cet axe, la
prochaine écriture du blob pour une toute autre raison — une ration, un entraînement — aurait
rappelé `pnj_miroir_possessions` et **écrasé le socle avec un tableau périmé**. Le miroir est donc
devenu conditionnel **avant** que l'axe ne bascule ; tant que l'axe disait « blob », le
comportement restait strictement celui d'avant.

Le dernier lecteur client — l'écran « Équiper les soldats » — a été basculé et **déployé avant**
la bascule de l'axe, dans cet ordre précis : tant que le socle est le miroir exact du blob, la
nouvelle lecture rend le même résultat. Vérifié identique au caractère près.

La valeur `origine = 'blob_accessoires'` est **conservée à dessein** : trois lectures de détection
s'en servent pour distinguer l'équipement réglementaire d'un objet donné par un joueur. La
renommer obligerait à réécrire ces trois fonctions volumineuses pour un gain cosmétique, au prix
d'un risque de transcription. Le nom est historique, son sens est fixé par un commentaire de
colonne, et la dette est consignée.

### Axe laissé sous autorité historique : position / leader

**Position et leader sont indivisibles.** Trois des cinq écrivains les posent dans la **même**
écriture (`militaire_deposer_soldats`, `militaire_recuperer_soldats`), et la contrainte
`pnj_position_deux_etats` porte sur les deux à la fois : les séparer créerait un état
intermédiaire invalide.

Et surtout, **cet axe est couplé à celui que ce lot doit laisser tranquille**. Les lecteurs de
`leaderCourant` hors écrivains sont `militaire_ordre_collectif` et `militaire_reposer_section` —
c'est-à-dire **les deux fonctions qui écrivent les PA**. Basculer le leader oblige donc à les
modifier, alors que le lot interdit explicitement de toucher à l'axe PA. La bascule
position/leader est un lot à part entière, avec son propre banc : cinq écrivains, deux lecteurs
PA, le miroir et le comparateur — neuf fonctions.

## Preuves, toutes par exécution

```
SÉPARATION DES DEUX PRÉOCCUPATIONS
  prendre un soldat        REFUSÉ  mouvement_individuel_interdit
  prendre un douanier      REFUSÉ  affectation_par_le_service   (défaut du lot 2, fermé)
  prendre un policier      REFUSÉ  affectation_par_le_service
  détacher / transférer    REFUSÉS de même
  débit PA d'un soldat     REFUSÉ  axe_pa_hors_socle            (état de migration)
  débit PA d'un douanier   REFUSÉ  classe_sans_consommation_de_pa (classe)
  PA inchangés : 12 partout

BASCULE DE L'AXE POSSESSIONS
  équiper                  objet retiré de l'inventaire, posé au socle
  LE BLOB N'A PAS BOUGÉ pendant l'équipement        md5 identique
  écriture du blob pour une autre raison            possessions INCHANGÉES
  déséquiper               objet rendu à l'inventaire
  gilet                    se fragilise dans le socle
  ration propre            consommée dans le socle
  écran d'équipement       lecture identique au caractère près, refus hors autorité conservé
```

Toutes les mises en situation ont tourné **en transaction annulée**. Seule la bascule de l'axe est
réelle.

## État à la clôture

96 soldats · **24 sous Vince, 72 en réserve** · PA tous à 12 · 1 possession · 0 FR ·
comparateur soldats **96/96 sans divergence** · douane **4/4** · police **verte** ·
blob militaire `md5 a107192a41d5cd1153808c302d60d0a9` et `updated_at` du 22/09 **inchangés** ·
`soldats_blob_autoritaire` toujours en place.

## Rollback, indépendant par axe

Remettre `pnj_axes_autorite` à `blob` pour l'axe concerné suffit à réactiver le miroir. Pour
l'axe possessions il faut en outre rétablir les trois écrivains dans leurs versions blob et
l'écran d'équipement dans sa lecture d'origine — le blob n'a pas été modifié, il porte donc encore
l'état d'avant la bascule.

**Le lot 5 portera sur l'axe PA. Le lot 6 sur position/leader.**
