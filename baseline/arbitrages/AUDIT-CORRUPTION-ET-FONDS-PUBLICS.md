# Audit factuel — corruption, détournement de fonds publics, emplois fictifs

**13 octobre 2026. RAPPORT SEUL.** Aucune valeur n'est proposée, aucun seuil n'est inventé,
aucun barème n'est touché. Le cahier des charges de la tranche l'interdit explicitement, et ce
document s'y tient : il dit **ce qui existe**, **par quelle porte**, **ce qui est automatique**
et **ce qui n'existe pas du tout**.

Mesures prises en base le 13 octobre 2026 (lecture seule) et dans le dépôt au même jour.

---

## 1. Ce que le code pénal contient réellement

`public.infractions` porte **39 infractions**, réparties en **quatre catégories** plus une
infraction sans catégorie.

| catégorie | n | jours de référence | amende de référence | détectables | barème propre |
|---|---|---|---|---|---|
| `delit_mineur` | 13 | 1 à 2 | 500 | 13 | 1 |
| `delit` | 7 | 1 à 2 | 0 à 1 000 | **0** | 7 |
| `delit_grave` | 6 | 4 | 1 500 | 6 | 0 |
| `crime` | 12 | 2 à 8 | 1 500 à 5 000 | 9 | 7 |
| *(sans catégorie)* | 1 | 1 | 0 | 0 | 1 |

L'infraction sans catégorie est `justification_rejetee`, et c'est **volontaire** : elle n'est pas
plaidable en procédure simplifiée, et une contrainte de base interdit qu'elle hérite d'un barème.

### Les sept corruptions, exactement

| id | catégorie | jours | amende | détectable | taux de détection |
|---|---|---|---|---|---|
| `corrompre_fonct` | `delit_mineur` | 2 | 500 | oui | 30 |
| `corrompre_police` | `delit_mineur` | 2 | 500 | oui | 35 |
| `corrompre_gardien` | `delit_mineur` | 2 | 500 | oui | 35 |
| `corrompre_douanier` | `delit_mineur` | 2 | 500 | oui | 35 |
| `corrompre_journaliste` | `delit_mineur` | 2 | 500 | oui | 25 |
| `corrompre_juge` | `delit_grave` | 4 | 1 500 | oui | 40 |
| `corruption_fonctionnaire` | **`delit`** | 1 | **1 000** | **non** | — |

**La septième n'est pas une septième corruption : c'est une autre chose.** Les six premières sont
nommées d'après l'**ORDRE** que le joueur clique, elles portent le barème **générique** de leur
catégorie, et la police peut les découvrir d'elle-même. `corruption_fonctionnaire` est nommée
d'après le **FAIT**, elle a son **barème propre**, et elle n'est pas découvrable par patrouille.

## 2. Par quelle porte, et ce qui est automatique

### a) Les trois ordres de corruption ordinaires — `doCorruption` (client)

Routés depuis `plateau-router.js` : `corrompre_fonct`, `corrompre_police`, `corrompre_gardien`.
Déclarés dans quatre pièces de `data.js` (2 PA / 200 FR à la mairie ; 3 PA / 1 500 FR et
2 PA / 800 FR au QHS ; 3 PA / 500 FR pour la falsification de PV).

Mécanique mesurée dans `plateau-justice-economie.js` :

* les **PA sont prélevés d'avance**, l'**argent seulement à la réussite** — le comportement
  d'origine, conservé ;
* taux de réussite `max(5, 65 − getMalusISN())` ;
* à la réussite : **−5 DIS**, une trace `actions_tracables` de type **`corruption`**, et
  `checkDetection(fn, 'success')` ;
* à l'échec : **aucune dénonciation**, `checkDetection(fn, 'fail')` rend la main immédiatement
  (`if (resultType === 'fail') return;`).

**La détection est un second jet, et il est conditionnel.** `checkDetection` lit
`ACTES_ILLEGAUX[fn]`, applique `max(5, detectRate − DIS/10)`, et s'il passe inscrit un avis de
recherche par la porte `inscrireRecherche`. **Immunités mesurées** : le Président est
totalement immunisé ; les sept ministres le sont pour les `delit_mineur` — donc pour **cinq des
six corruptions**.

### b) La corruption du fonctionnaire de l'urbanisme — `doCorrompreFonctionnairePermis`

C'est **elle seule** qui produit `corruption_fonctionnaire`. Mécanique mesurée : **PA et FR
prélevés d'avance**, puis `random() < 0.25`. À la découverte : entrée dans `historiqueCrimes`
et **arrestation immédiate**. À la réussite : la durée d'instruction du permis est divisée par
deux, et **rien n'est inscrit**.

### c) La corruption du greffier — `greffe_corrompre_dossier` / `greffe_corrompre_faux_casier`

Ajoutées le 13 octobre 2026, **au serveur**. Elles réemploient exactement le précédent ci-dessus
— coûts d'avance, 25 % de découverte — et la découverte **dénonce** par
`greffe_denoncer_corruption`, qui inscrit `{acte:'corruption_fonctionnaire', type:'delit'}` à
l'avis de recherche. C'est **la seule porte serveur du dépôt** qui nomme
`corruption_fonctionnaire`.

### d) Le circuit judiciaire, une fois l'acte inscrit

Il n'y a **aucun circuit propre à la corruption**. Un avis de recherche mène à une arrestation,
puis au tribunal par la chaîne ordinaire ; une plainte mène au parquet. Deux faits à retenir :

* le **seuil de la procédure simplifiée est de 2 jours de référence**
  (`justice_seuil_procedure_simplifiee_jours()`), donc **les cinq corruptions `delit_mineur` et
  `corruption_fonctionnaire` sont toutes plaidables en dix secondes**, tandis que
  `corrompre_juge` (4 jours) ne l'est pas ;
* les 7 infractions de catégorie `delit` sont **toutes `detectable = false`** : elles
  n'atteignent la justice que par une **plainte** ou une **dénonciation serveur explicite**.
  Aucune patrouille ne les trouve.

## 3. Le trou : deux infractions n'existent pas

**`detournement_fonds_publics` et `emplois_fictifs` n'existent dans AUCUN des deux côtés.**
Ni comme infraction de `public.infractions`, ni dans `PEINES_ACTES` / `ACTES_ILLEGAUX` de
`plateau-core.js`, ni comme ordre, ni comme porte serveur. Ce ne sont pas des mécaniques
incomplètes : elles sont **absentes**.

### Ce qui existe à leur place, et pourquoi ce n'en est pas

**Aucune porte ne verse l'argent d'une caisse publique dans une poche.** `caisse_client_mouvement`
est la seule porte client vers une caisse d'institution. Elle refuse tout débit dont l'appelant
n'est pas l'autorité (`caisse_refus_autorite`), **ne crédite jamais un portefeuille**, et
journalise **chaque tentative, acceptée ou refusée**, dans `caisses_mouvements_clients` avec
l'acteur, la caisse, le montant, le motif et la raison du refus. Un débit réussi fait donc
**disparaître** l'argent : il ne va nulle part. Un détournement au sens d'un enrichissement est
**structurellement impossible aujourd'hui**, et la table des mouvements est le registre de preuves
tout prêt si la mécanique était un jour arbitrée.

**Le seul flux caisse → portefeuille d'un PJ est la solde militaire.** `militaire_solde_percevoir`
verse un montant **fixé par le grade** (soldat 50, lieutenant 150, capitaine 250, commandant 400),
**une fois par jour calendaire et par personne** (clé primaire `personnage:jour`), **plafonné par
le solde de la caserne**, et la dette est inscrite si la caisse ne suit pas. Personne ne choisit
le montant, et personne ne perçoit à la place d'un autre : le grade est **dérivé**
(`militaire_grade_effectif`). Un « emploi fictif » exigerait donc de **promouvoir** quelqu'un, ce
qui passe par la filière de recrutement, elle-même serveur-autoritaire.

## 4. Ce qu'il resterait à décider — et que ce document ne décide pas

1. **Le détournement de fonds publics est-il un acte de jeu ?** Si oui, il faut une porte qui
   déplace de la caisse vers une poche, et donc une infraction, une catégorie, un barème et une
   règle de découverte. Aucune des quatre n'existe, et aucune n'est proposée ici.
2. **L'emploi fictif est-il un acte de jeu ?** Il supposerait un salaire versé à quelqu'un qui ne
   sert pas, donc un contrôle de service rendu qui n'existe nulle part.
3. **`corruption_fonctionnaire` doit-elle rester distincte des six `corrompre_*` ?** Sept
   corruptions pour deux conceptions coexistent aujourd'hui : l'une nommée d'après l'ordre et
   découvrable, l'autre nommée d'après le fait et non découvrable. Les deux fonctionnent ; ce
   n'est pas un défaut technique, c'est un choix non formulé.
4. **La trace `actions_tracables` de type `corruption` ne prouve rien.** `justice_preuve_reelle`
   apparie le `type_action` à la **qualification retenue** : une trace de type `corruption` ne
   correspond à aucune des sept infractions, donc elle n'apparaît jamais comme preuve réelle au
   dossier de l'avocat. **Ce n'est pas un bug au sens de la doctrine** — une trace n'est jamais
   une condition de culpabilité — mais c'est une trace qui ne sert à rien, et le dire est utile.
