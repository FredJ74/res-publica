# Arbitrages — Assemblée, interdictions et portée des lois

> **Registre de décisions de game design.**
> Décisions prises par Fred le 6 octobre 2026, à l'issue de l'audit 4D des
> catégories d'interdiction.
>
> **ÉTAT : IMPLÉMENTÉES le 7 octobre 2026, commit `b3d10a3`.** Les décisions 1 à 6
> sont en production ; les cinq défauts techniques du § 7 sont corrigés, à
> l'exception notée en fin de ce fichier. Ce registre reste la trace du *pourquoi* :
> il dit ce qui a été décidé et sur quels constats, ce qu'aucun diff ne raconte.

---

## 1. La source canonique des catégories est la base

**`public.assemblee_categories_interdiction` fait foi.** `CATEGORIES_INTERDICTION`
(`plateau-assemblee.js:90`) est une **copie périmée** et ne doit pas constituer
une seconde source de vérité.

Mesuré le 6 octobre 2026 : 21 lignes en base, 15 dans la constante cliente. Les
15 sont incluses à l'identique dans les 21. La copie date du 11 septembre 2026 ;
les 6 manquantes ont été ajoutées en base le 30 septembre, par un chantier qui a
déplacé la source de vérité vers la base sans mettre le client à jour.

Les 6 : `cereales`, `desinfectant`, `fruits_legumes`, `metal`, `minerai`,
`plantes`. Toutes des matières simples, aucune ne porte de type d'objet.

---

## 2. Une catégorie ne porte pas de portée politique implicite

**Une catégorie ne doit PAS imposer au joueur une portée cachée ou
automatiquement élargie.** Les PJ doivent pouvoir choisir précisément ce que
leur projet de loi interdit, et Seb Lex doit traduire ce choix en une portée
exploitable par le moteur législatif.

---

## 3. Médicaments

**Ne pas créer artificiellement un type d'objet `medicament`** dans le seul but
de satisfaire la branche morte existante.

Constat de l'audit : `CATEGORIES_INTERDICTION.medicaments` porte
`typesObjet: ['medicament']`, et la ligne en base porte le même
`types_objet: ["medicament"]`. **Aucun objet de ce type n'est créé nulle part**
dans le code, et aucun n'existe en base — les types réellement présents dans les
inventaires sont `equipement`, `soin`, `poison`, `arme` et `null`. Les soins
produits sont `type:'soin'`. Le bras « objet » de cette catégorie ne peut donc
produire aucun effet ; le bras « matière » (`matieres: ['medicaments']`), lui,
fonctionne.

**Décision :** lors d'un projet concernant les médicaments, les PJ doivent
pouvoir choisir la portée — la matière économique `medicaments`, les
produits/objets de soin concernés, ou les deux. La portée résulte du choix
politique, pas d'un encodage dans la catégorie.

---

## 4. Armes

**Même principe.** Une interdiction des armes à feu ne doit pas décider
automatiquement, à la place des PJ, du sort de l'armement militaire.

Constat de l'audit : les armes produites par l'effort de guerre portent
`sousType: 'militaire'`, absent de `armes_blanches` et `armes_a_feu` (qui ne
listent que `blanche`, `poing`, `carabine`). Seule la catégorie large `armes`
les atteint aujourd'hui.

**Décision :** les PJ doivent pouvoir choisir explicitement si leur interdiction
vise les armes à feu civiles concernées, l'armement militaire concerné, ou les
deux.

---

## 5. Principe générique

**Le moteur législatif doit permettre aux PJ de déterminer la portée concrète
d'une interdiction parmi les éléments couverts par la catégorie, plutôt que
d'encoder implicitement une portée politique dans la catégorie elle-même.**

*Point d'ancrage pour l'implémentation :* ce mécanisme **existe déjà**.
`assemblee_portee_valider(jsonb)` valide une portée sur une **liste fermée**, qui
ne contient aujourd'hui qu'une seule dimension, `transformation_stock_interdite`
(booléen, défaut `false`). Son commentaire porte déjà la doctrine des décisions
2 à 5 :

> « Absente ou vide : CAS A par defaut — interdiction economique sans
> interdiction de transformation. **Le moins-disant, jamais le plus-disant.** »
> « LISTE FERMEE. Toute cle inconnue est un refus, jamais un silence : c'est ce
> qui empeche l'IA d'inventer un effet que le moteur n'applique pas. »

Les décisions ci-dessus se traduisent donc par l'ajout de dimensions à cette
liste fermée et par leur prise en compte dans `assemblee_objet_vise`, et non par
la création d'une mécanique parallèle. La liste doit rester fermée : c'est elle
qui empêche Seb Lex de promettre un effet que le moteur n'applique pas.

---

## 6. Une loi adoptée n'est pas une loi appliquée

**Le client doit s'aligner sur la règle serveur, fondée sur `appliquee_ts`.**

Constat de l'audit : `assemblee_loi_en_vigueur` exige
`appliquee_ts IS NOT NULL AND appliquee_ts <= instant`, alors que le cache
client (`sbGetAssembleeInterdictions`) ne filtre que
`type=eq.mecanique&statut=eq.adoptee` et ne lit même pas `appliquee_ts`. Entre
l'adoption et la mise en application par le Ministre de l'Intérieur, **le client
est plus strict que la loi** : il affiche comme interdit ce que le serveur
autorise encore.

---

## 7. Défauts techniques constatés, à corriger dans le lot approprié

Aucun n'est corrigé aujourd'hui. Tous sont mesurés, pas supposés.

| # | Défaut | Conséquence constatée |
|---|---|---|
| 7.1 | Copie cliente à 15 catégories contre 21 canoniques | Aucune synchronisation n'existe ; le navigateur ne lit jamais la table |
| 7.2 | Affichage brut des 6 catégories manquantes | Le registre, la fiche et **le corps du sujet forum** affichent `[metal]` au lieu de « Métal », et la ligne « Concerne : … » disparaît. Le texte du forum est persisté définitivement |
| 7.3 | Préfiltrage client empêchant la confiscation | `objetsSaisissables()` filtre avec la constante ; si la liste est vide, `inventaire_confisquer` — qui saurait saisir via la base — **n'est jamais appelée**. Douane, fouille policière et convocation répondent « rien d'illégal trouvé » |
| 7.4 | UI non alignée sur la légalité serveur | À la Salle des Ventes, une matière interdite par l'une des 6 n'est ni grisée ni annoncée : le joueur saisit sa quantité et n'apprend le refus qu'après avoir cliqué. L'argent est sauf (le serveur refuse), l'écran ment |
| 7.5 | Code et commentaires morts | `sbAssembleeDeposer` (zéro appelant) ; `SEBLEX.projet.label_categorie` (transporté, jamais lu) ; route `deposer_projet` ; quatre commentaires décrivant encore le formulaire de dépôt supprimé le 30 septembre 2026 |

**Aucun risque rétroactif** : `assemblee_propositions` et `lois_assemblee` sont
vides. Aucune interdiction n'a jamais été déposée ni votée.

---

## Ce qui a été fait, et ce qui ne l'a pas été

Les sept décisions sont implémentées (`b3d10a3`), avec une réserve honnête sur le
§ 7.5 : les trois éléments morts nommés — `sbAssembleeDeposer`,
`SEBLEX.projet.label_categorie` et la route `deposer_projet` — **n'ont pas été
retirés**. Ils ne sont pas touchés par cette correction, et les enlever aurait
élargi le lot sans rien prouver. Les quatre commentaires faux, eux, ont été
rectifiés parce qu'ils décrivaient précisément le mécanisme corrigé.

## Ce qui n'est PAS décidé ici

Ce registre n'arbitre **que** les points ci-dessus. Il ne dit rien du reste du
chantier 4D, ni des autres divergences déclarées dans
`outils/baseline/referentiels.json`.
