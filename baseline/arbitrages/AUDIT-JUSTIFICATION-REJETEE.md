# `justification_rejetee` — audit factuel avant toute modification

**13 octobre 2026.** Cet audit répond à une consigne précise : *« AUDIT FACTUEL AVANT TOUTE
MODIFICATION. NE PAS lui attribuer arbitrairement une catégorie. »* Rien n'a été modifié dans
cette mécanique. Ce document dit ce qu'elle **est**, pas ce qu'elle devrait être.

---

## A. Qu'est-ce que `justification_rejetee` ?

Une **infraction du catalogue pénal**, au même titre que `vol` ou `diffamation` :

| champ | valeur |
|---|---|
| `id` | `justification_rejetee` |
| `libelle` | « Justification rejetée (marchandise interdite) » |
| `categorie` | **NULL** |
| `jours_reference` | 1 |
| `amende_reference` | **0** |
| `bareme_propre` | `true` |
| `detectable` | `false` |
| `detect_rate` | NULL |

Elle vient du **chantier Assemblée du 10 septembre 2026**, §42 du cahier des charges : le circuit
des marchandises interdites. Son barème vit dans `plateau-core.js`, `PEINES_ACTES.republic`, et le
commentaire d'origine y est explicite : *« Amendes à 0 : le cahier des charges ne prévoit AUCUNE
amende sur ce circuit, seulement de la détention et la confiscation. Ne pas en inventer une. »*

## B. Qui la produit, et à quel moment exactement ?

**UN SEUL producteur, côté navigateur** : `plateau-justice-economie.js`, dans le traitement d'une
convocation douanière. La séquence réelle est :

1. le joueur est convoqué (marchandise interdite détectée) ;
2. il se présente et **tente de se justifier** — un ordre payé, une seule tentative, §42 ;
3. le navigateur calcule `taux = 50 + (CHA + DUP) / 2`, tire un d100, et compare ;
4. **si le jet échoue**, il appelle `procederArrestation('justification_rejetee', false, false)`.

La confiscation a lieu **dans les deux cas** (§42 : se justifier évite la prison, jamais la saisie).

## C. Est-ce une infraction ou une procédure ?

**Les deux, et c'est le fait le plus important de cet audit.** Le nom désigne le **rejet d'une
justification**, c'est-à-dire l'issue d'une procédure — pas un acte commis. La personne n'est pas
poursuivie pour « avoir rejeté une justification » : elle est détenue un jour **parce que son
explication n'a pas été retenue**.

## D. Passe-t-elle par le parquet ? Par un juge ? Par le greffe ?

**Non, à aucun des trois.** `procederArrestation` ouvre une **détention de flagrant délit** :

- aucune ligne dans `plaintes_en_cours` ;
- donc **aucun dossier judiciaire**, aucune chronologie, aucun acte au registre ;
- donc ni Procureur, ni juge, ni audience, ni appel, ni archive au greffe, ni publication au
  journal — les douze faits judiciaires publics passent tous par un acte de dossier.

Elle produit **une ligne de `detentions`** avec le motif « Justification rejetée (marchandise
interdite) », qui apparaît au registre carcéral du commissariat comme n'importe quelle détention.

## E. Pourquoi sa catégorie pénale est-elle NULL ?

Parce que le **générateur du code pénal** la déduit de `ACTES_ILLEGAUX[acte].type`, et que
`justification_rejetee` n'est **pas** dans `ACTES_ILLEGAUX` — cette table-là décrit ce que la
POLICE peut découvrir (`detectRate`), et une justification rejetée n'est pas un acte dissimulé :
elle se produit au guichet, devant l'autorité. Son absence de catégorie n'est donc pas un oubli de
saisie, c'est la **conséquence mécanique** de sa place dans le canon.

## F. Que change cette catégorie NULL, concrètement ?

Trois consommateurs lisent `infractions.categorie`, et **un seul la voit jamais** :

1. **`plainte_defendre`** (procédure simplifiée) refuse `categorie IS NULL OR categorie = 'crime'`.
   Une affaire qualifiée `justification_rejetee` serait donc **exclue** de la procédure simplifiée.
   Mais pour qu'une affaire porte cette qualification, il faudrait qu'un Procureur la retienne —
   or elle est bien au catalogue, donc `infraction_canonique` l'accepte : **le cas est possible,
   et il n'est pas atteignable par le circuit normal.**
2. **`affaire_categorie_publique`** (registre public du greffe) rendrait NULL → le greffe
   n'afficherait aucune catégorie. Même remarque : il faut une affaire.
3. **`infraction_peine_bornes`** la rend telle quelle, à titre informatif.

Le circuit réel (convocation → jet → détention) **ne consulte pas la catégorie**.

## G. Y a-t-il une anomalie purement technique à corriger ?

**Non.** Rien dans cette chaîne n'est cassé : le barème est celui du cahier des charges, la
confiscation a lieu dans les deux cas, la détention s'ouvre par la porte serveur
`detention_ouvrir_interne` via `enregistrerDetention`, et la trace est au registre carcéral. Aucune
écriture n'est avalée, aucun refus n'est silencieux.

Le seul reproche techniquement démontrable est **un libellé de refus trompeur**, et il est
hypothétique : si un Procureur qualifiait une affaire `justification_rejetee`, le prévenu qui
tenterait la procédure simplifiée recevrait le motif `procedure_simplifiee_exclut_les_crimes` —
alors que ce n'est pas un crime, c'est une infraction **sans catégorie**. Le refus est juste
(fail-closed), son nom ne l'est pas. Ce n'est pas corrigé ici : renommer un motif de refus touche
aux messages du navigateur, et le cas n'est pas atteignable aujourd'hui.

## H. Ce qui relève du GAME DESIGN, et n'a donc pas été touché

**H1 — UN JET DÉCIDE SI LE COMMISSAIRE VOUS CROIT.** C'est le point central, et il contredit
frontalement le §0 de la doctrine : *« Aucune IA et aucun jet automatique ne doit décider […] si
quelqu'un dit vrai. »* Ici, `Math.random()` contre `50 + (CHA + DUP)/2` décide si une explication a
convaincu. La mécanique est **exactement de la même famille** que la requête d'avocat supprimée le
même jour — à une différence près : la requête d'avocat n'avait **aucun** interlocuteur humain
possible, alors que la justification en a un (le Chef des Douanes, le Commissaire). Remplacer ce
jet par une décision humaine est **un arbitrage de game design**, et il n'est pas pris ici.

**H2 — SA CATÉGORIE PÉNALE.** L'arbitrage du 13 octobre classe dix infractions et **ne la nomme
pas**. Lui donner `delit` « parce que les autres l'ont » serait exactement ce que la consigne
interdit. Elle reste NULL, donc du côté fermé.

**H3 — EST-CE UNE INFRACTION DU CODE PÉNAL ?** Si la réponse est non — si c'est une **sanction
administrative douanière** et pas une infraction —, alors sa place n'est pas dans `infractions`
mais ailleurs, et la question de sa catégorie disparaît avec elle.

## I. Ce qui est désormais verrouillé par un banc

`outils/bancs/banc-defense-simplifiee.sql`, épreuve **T26** (ajoutée le 13 octobre) :

- `justification_rejetee` **n'a pas de catégorie** — l'épreuve rougit si une catégorie lui arrive
  par distraction ;
- une affaire qualifiée `justification_rejetee` **n'est pas plaidable** en procédure simplifiée.

L'état audité est donc **gelé par la mesure**, pas par la mémoire.

## J. Résumé en une phrase

`justification_rejetee` est une **issue de procédure douanière** rangée dans le catalogue des
infractions, sans catégorie parce qu'elle n'est pas un acte dissimulable, qui ouvre une détention
d'un jour sans jamais passer par un dossier judiciaire — et dont la seule véritable question
ouverte n'est pas sa catégorie, mais **le dé qui décide si on vous croit**.
