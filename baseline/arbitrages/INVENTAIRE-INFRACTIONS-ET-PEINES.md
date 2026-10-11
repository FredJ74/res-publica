# Inventaire exhaustif — infractions et peines de référence

**Relevé le 12 octobre 2026.** Lecture seule : aucun fichier de jeu modifié pour produire ce document.
Reproductible par la commande en fin de document.

---

## 1. Réponse directe à la question du game designer

> « Le game designer pense qu'il existe déjà possiblement des durées automatiques/de référence pour
> les infractions, mais cela doit être vérifié. »

**OUI, elles existent, et elles couvrent TOUTES les infractions.** Il y a trois tables et une
fonction de résolution, toutes dans `plateau-core.js` :

| Table | Lignes | Rôle |
|---|---|---|
| `ACTES_ILLEGAUX` (ligne 376) | **28** | le catalogue des actes : `type` (catégorie) + `detectRate` (% de détection) |
| `PEINES_ACTES.republic` (ligne 337) | **16** | barème **spécifique** par acte : `jours` + `amende` + `label` |
| `PEINES` (ligne 320) | **4** | barème **par catégorie** : `jours` + `amendeBase` |
| `getPeineParActe(acte, demasque)` (ligne 364) | — | résolution : spécifique → sinon catégorie → sinon `delit_mineur` |

```js
function getPeineParActe(acte, demasque) {
  const specifique = PEINES_ACTES[pays]?.[acte];
  if (specifique) { const mult = demasque ? 2 : 1;
    return { jours: specifique.jours * mult, amende: specifique.amende * mult, label: specifique.label }; }
  const type = ACTES_ILLEGAUX[acte]?.type || acte || 'delit_mineur';
  const peine = PEINES[type] || PEINES.delit_mineur;
  return { jours: peine.jours, amende: peine.amendeBase, label: peine.label };
}
```

**`demasque = true` DOUBLE jours et amende** — un acte réussi puis découvert après coup coûte le
double d'un flagrant délit. Ce multiplicateur n'existe que sur la branche spécifique : un acte qui
retombe sur sa catégorie **n'est jamais doublé**. C'est une incohérence, elle est listée en §5.

**Conséquence pour la règle ±50 %** : elle est **implémentable immédiatement**, sans inventer une
seule durée. La référence d'une infraction est `getPeineParActe(acte, false).jours`. Il n'y a
**aucune** infraction sans durée de référence.

---

## 2. Les 34 identifiants d'infraction

L'union des deux catalogues donne **34 identifiants distincts** : 28 dans `ACTES_ILLEGAUX`,
16 dans `PEINES_ACTES.republic`, dont **5 communs**.

### A. Les 5 identifiants complets (acte + barème spécifique)

| Identifiant | Catégorie | Référence | Amende | Détection |
|---|---|---|---|---|
| `vol` | delit_mineur | **1 j** | 500 FR | 30 % |
| `acheter_bombe_illegale` | crime | **2 j** | 2 000 FR | 55 % |
| `empoisonnement` | crime | **2 j** | 2 000 FR | 25 % |
| `incendier` | crime | **2 j** | 2 000 FR | 70 % |
| `utiliser_explosifs` | crime | **2 j** | 2 000 FR | 65 % |

### B. Les 23 actes qui retombent sur leur catégorie

Ils ont une référence, mais **héritée**. Le GD voudra peut-être leur donner une valeur propre.

| Identifiant | Catégorie | Référence héritée | Amende | Détection |
|---|---|---|---|---|
| `acheter_arme_illegale` | delit_mineur | 2 j | 500 | 20 % |
| `contrebande_port` | delit_mineur | 2 j | 500 | 20 % |
| `corrompre_douanier` | delit_mineur | 2 j | 500 | 35 % |
| `corrompre_fonct` | delit_mineur | 2 j | 500 | 30 % |
| `corrompre_gardien` | delit_mineur | 2 j | 500 | 35 % |
| `corrompre_journaliste` | delit_mineur | 2 j | 500 | 25 % |
| `corrompre_police` | delit_mineur | 2 j | 500 | 35 % |
| `fausse_rumeur` | delit_mineur | 2 j | 500 | 35 % |
| `imprimer_tracts_calomnieux` | delit_mineur | 2 j | 500 | 30 % |
| `se_rebeller` | delit_mineur | 2 j | 500 | 60 % |
| `societe_ecran` | delit_mineur | 2 j | 500 | 25 % |
| `vol_materiel_chantier` | delit_mineur | 2 j | 500 | 30 % |
| `arreter` | delit_grave | 4 j | 1 500 | 40 % |
| `blanchiment` | delit_grave | 4 j | 1 500 | 35 % |
| `corrompre_juge` | delit_grave | 4 j | 1 500 | 40 % |
| `fabriquer_scandale` | delit_grave | 4 j | 1 500 | 45 % |
| `falsifier_document` | delit_grave | 4 j | 1 500 | 40 % |
| `fuite_info` | delit_grave | 4 j | 1 500 | 40 % |
| `assassiner_arme` | crime | 8 j | 5 000 | 40 % |
| `assassiner_feu` | crime | 8 j | 5 000 | 60 % |
| `assassiner_mains` | crime | 8 j | 5 000 | 30 % |
| `fabriquer_bombe` | crime | 8 j | 5 000 | 60 % |
| `tentative_evasion` | crime | 8 j | 5 000 | 90 % |

### C. Les 11 barèmes sans acte — JAMAIS DÉTECTABLES

Ils ont une peine mais **n'existent pas dans `ACTES_ILLEGAUX`**, donc `checkDetection()` est un
**no-op silencieux** pour eux : ils ne peuvent **jamais** produire un statut « recherché ».

| Identifiant | Référence | Amende | Libellé |
|---|---|---|---|
| `violation_couvre_feu` | 1 j | 200 | Violation du couvre-feu |
| `achat_arme_illegal` | 1 j | 500 | Achat d'arme non enregistrée |
| `possession_illegale_douane` | 1 j | 500 | Possession d'objets prohibés au contrôle douanier |
| `diffamation` | 1 j | 500 | Diffamation |
| `hooliganisme` | 1 j | 500 | Trouble à l'ordre public (hooliganisme) |
| `corruption_fonctionnaire` | 1 j | 1 000 | Corruption de fonctionnaire |
| `justification_rejetee` | 1 j | 0 | Justification rejetée (marchandise interdite) |
| `tentative_assassinat` | 2 j | 1 500 | Tentative d'assassinat |
| `assassinat` | 2 j | 1 500 | Assassinat |
| `tentative_empoisonnement` | 2 j | 2 000 | Tentative d'empoisonnement |
| `non_presentation_convocation` | 2 j | 0 | Non-présentation à convocation |

### D. Les 4 catégories génériques

| Catégorie | Référence | Amende de base |
|---|---|---|
| `delit_mineur` | 2 j | 500 FR |
| `delit_grave` | 4 j | 1 500 FR |
| `crime` | **8 j** | 5 000 FR |
| `crime_etat` | **30 j** | 0 FR |

---

## 3. Où ces identifiants sont produits et consommés

| Lieu | Ce qu'il fait |
|---|---|
| `getPeineParActe` (`plateau-core.js:364`) | la résolution. **Seul point de vérité** |
| `checkDetection(fn, resultType)` | lit `ACTES_ILLEGAUX[fn]` ; **sort en silence si l'identifiant est absent** |
| `confirmerArrestation` (`plateau-justice-economie.js:1172`) | flagrant délit : `peineCalc.jours` + 2 j si résistance |
| `plateau-justice-economie.js:11592` | garde à vue sur trace découverte : **2 j en dur**, jamais `getPeineParActe` |
| `plateau-justice-economie.js:1929` | évasion : **2 j en dur** |
| `plateau-justice-economie.js:2008` | rébellion en cellule : **1 j en dur** |
| `plateau-justice-economie.js:2029` | rébellion matée → QHS : **30 j en dur** |
| `ouvrirRendreSentence` → `justice_rendre_sentence` | **la peine du juge est une somme LIBRE** de `motifs[].jours`, fournie par le client. Elle ne lit **jamais** `getPeineParActe` |
| `justice_executer_condamnation` | somme des `motifs[].jours`, **repli 3 j** si la somme vaut 0 |
| `actions_tracables.type_action` | 5 valeurs seulement : `subtilisation_explosif`, `tentative_subtilisation_explosif`, `vol_materiel_chantier`, `tentative_vol_materiel_chantier`, `condamnation_torture`. **0 ligne en base** |

**Les tables `assemblee_catalogue_illegal` (7 lignes) et `assemblee_categories_interdiction`
(22 lignes) ne sont PAS un code pénal** : la première liste les marchandises dont l'Assemblée peut
fermer le circuit (3 armes, 4 poisons), la seconde les 22 catégories de matière sur lesquelles elle
peut légiférer. Aucune ne porte de peine.

---

## 4. Ce qu'il faut pour appliquer le ±50 %

| Élément | État |
|---|---|
| référence par infraction | **disponible pour les 34** |
| borne basse (−50 %) | `Math.max(1, Math.round(ref * 0.5))` — à arbitrer : **1 jour plancher ou 0 ?** |
| borne haute (+50 %) | `Math.round(ref * 1.5)` |
| garde serveur | **à écrire** : la peine est aujourd'hui une somme libre fournie par le client |
| cas `demasque` | la référence double-t-elle avant ou après le ±50 % ? **à arbitrer** |

Avec `ref = 1 j` (7 infractions), −50 % donne 0,5 j : **le plancher est la seule valeur à arbitrer
pour rendre la règle applicable partout.**

---

## 5. Anomalies et doublons constatés

1. **`crime` générique = 8 jours, mais tout crime spécifique = 2 jours.** Les quatre crimes qui ont
   un barème propre (`acheter_bombe_illegale`, `empoisonnement`, `incendier`, `utiliser_explosifs`)
   sont **quatre fois moins punis** que les cinq crimes qui retombent sur la catégorie
   (`assassiner_*`, `fabriquer_bombe`, `tentative_evasion`). Un assassinat à mains nues coûte 8 j,
   un empoisonnement 2 j.
2. **`assassinat` / `tentative_assassinat` (barème) vs `assassiner_mains|arme|feu` (actes).** Deux
   nomenclatures pour le même fait. Les barèmes nommés ne sont jamais atteints par la détection ;
   les actes le sont, mais retombent sur la catégorie.
3. **`corruption_fonctionnaire` (barème) vs `corrompre_fonct` (acte).** Même doublon.
4. **`achat_arme_illegal` (barème) vs `acheter_arme_illegale` (acte).** Même doublon, orthographe
   différente.
5. **`empoisonnement` existe des deux côtés mais `tentative_empoisonnement` n'a pas d'acte** : la
   tentative n'est jamais détectable, le fait accompli l'est.
6. **`corrompre_juge`** (delit_grave, 40 %) : **aucun ordre, aucune route, aucun handler**. La
   corruption d'un juge n'existe pas dans le jeu.
7. **`falsifier_document`** (delit_grave, 40 %) : l'ordre existe mais **refuse toujours** — il paie
   en deux temps `(3,0)` puis `(0,300)` contre une seule ligne déclarée `(3,300)` dans
   `ordres_couts`, donc `payer_ordre` rend `cout_non_declare`.
8. **`PEINES_ACTES` ne contient que `republic`.** Les trois autres empires retombent intégralement
   sur les catégories — donc 2/4/8/30 jours, sans aucun barème propre.
9. **`crime_etat` (30 j) n'est porté par AUCUN acte.** La catégorie existe, rien ne la déclenche.
10. **Les peines du juge ignorent tout ce barème.** `justice_rendre_sentence` accepte la somme que
    le client envoie, sans la confronter à `getPeineParActe`.

---

## Reproduire cet inventaire

```bash
/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc -e '
var src = readFile("plateau-core.js");
function bloc(n){var i=src.indexOf("const "+n+" = {");return "("+src.slice(src.indexOf("{",i), src.indexOf("\n};",i)+2)+")";}
var PEINES=eval(bloc("PEINES")), PA=eval(bloc("PEINES_ACTES")), AI=eval(bloc("ACTES_ILLEGAUX"));
/* croisement des trois tables */'
```
