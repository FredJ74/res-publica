# Assemblée nationale — correctif : la présidence suit la législature

**11 octobre 2026, au soir.** Registre Supabase 662 → 663 (une migration).
**Le bâtiment n'est pas clos.**

---

## 1. L'invariant

> **Un Président de l'Assemblée doit être l'un des 9 députés de la législature en cours.**
> Il ne doit jamais exister de période où un ancien député continue à présider la nouvelle
> Assemblée.

Le renouvellement est **intégral** : les neuf mandats finissent ensemble et commencent ensemble, et
la présidence sortante prend fin **au même instant**. Il n'existe **aucune conservation du siège**
de Laroche ni d'aucun Président sortant.

---

## 2. Ce que l'audit a trouvé — pire que le point signalé

La quatrième passe avait signalé un trou de 24 heures au plus. L'audit a trouvé **un trou sans
limite de durée**, et d'une autre nature.

Le siège d'un député joueur était dérivé de **`personnages.poste_depute` seul**. Or ce champ est
une valeur **posée sur la fiche**, et le déclencheur d'attestation ne la vérifie **qu'à
l'écriture**. Un mandat achevé y survivait donc tant que la fiche n'était pas réécrite — c'est-à-dire
**indéfiniment pour un joueur déconnecté**.

La remise à zéro existait… **côté navigateur seulement** (`reconcilierPosteElu`,
`plateau-politique.js`, au chargement). Un ancien député déconnecté restait donc assis, et s'il
présidait, il présidait la législature suivante. C'est exactement la période que l'arbitrage
interdit — et elle ne se refermait **jamais** toute seule.

---

## 3. La correction : deux lignes, et aucun calendrier

### (1) Un siège PJ n'existe que si le mandat est attesté

`assemblee_occupation_sieges` appelle désormais **`poste_est_atteste`** — la règle d'attestation
**unique** du projet, celle que le déclencheur de la fiche utilise déjà. Pour un député, cette
règle lit `cycles_electoraux.data -> 'elus' ? nom` : **la vérité du dépouillement**, et rien
d'autre.

Conséquence, et c'est tout l'arbitrage : les neuf mandats commencent et finissent **à l'instant où
le cycle de leur ville les liste ou cesse de les lister**. Le cycle est réécrit en **une** écriture
par ville, donc le renouvellement est **simultané par construction** — il n'existe aucun député
« en cours de sortie ».

### (2) La présidence est dérivée, pas stockée

`assemblee_president(pays)` ne rend le titulaire du registre **que s'il est l'un des neuf**
(`assemblee_est_des_neuf`, qui compte les PJ **et** les PNJ — un député PNJ peut légitimement
présider). Toute la séance lit cette fonction et elle seule : la présidence d'un ancien député
cesse **dans la même lecture** que son mandat.

### Pourquoi c'est mieux qu'un cron

Aucune tâche planifiée ne peut garantir « jamais » : un cron en retard, un redéploiement, une passe
manquée — et l'ancien Président présiderait quelques heures. Ici **il n'y a aucune fenêtre, parce
qu'il n'y a aucun instant à attendre**. La règle tient sous le calendrier actuel comme sous
n'importe quel autre.

### Ce que le cron fait quand même, et pourquoi

`assemblee_presidence_fin_de_legislature(pays)`, appelée par `cron-minuit` **avant** la convocation
du lundi, ne **crée** pas la fin de la présidence : elle l'**enregistre**, en retirant du registre
des postes une ligne devenue fausse. Sans elle, la **fiche** de l'ancien Président continuerait
d'afficher son titre — attestée par cette ligne périmée — alors qu'il n'a plus aucun pouvoir.
Idempotente par nature : elle ne retire que ce qui ne devrait plus être là.

---

## 4. Le rang n'est pas une protection — et rien ne l'avait implémenté

La quatrième passe justifiait le rang 3 de Laroche par « le dernier PNJ de Luthécia à céder sa
place ». **C'était faux en game design.** Le rang est l'ordre d'appariement des députés joueurs
élus, identique dans les trois villes depuis le 10 septembre ; il ne met personne à l'abri, parce
que le renouvellement est intégral et que la présidence ne survit pas au mandat.

**Aucune ligne de code n'avait implémenté cette protection** : c'était une justification écrite
dans un commentaire. Elle est retirée du dépôt, et deux garde-fous la gardent retirée :

- une **preuve structurelle** vérifie qu'aucune des quatre fonctions de l'invariant
  (`assemblee_president`, `assemblee_est_des_neuf`, `assemblee_occupation_sieges`,
  `assemblee_presidence_fin_de_legislature`) ne nomme un PNJ en dur ;
- deux **épreuves client** refusent le retour de la formulation et exigent la phrase qui la
  remplace.

---

## 5. Les preuves

| Preuve demandée | Où | Comment |
|---|---|---|
| 1. Renouvellement **simultané** des 9 mandats | banc E7–E9, E20 | le champ périmé est **laissé en base** ; zéro siège PJ survit, et les entrants entrent seuls |
| 2. Fin **immédiate** de la présidence sortante | banc E10–E11 | `assemblee_president()` est NULL, **et la ligne du registre est encore là** — la présidence n'a pas cessé parce qu'on l'a nettoyée |
| 3. **Aucune** présidence entre le renouvellement et l'élection | banc E12–E14 | suspension, discipline et état de séance refusent l'ancien Président |
| 4. Seuls les **9 entrants** sont éligibles | banc E21–E22 | les sortants ne sont pas éligibles, et voter pour eux est refusé `pas_eligible` |
| 5. **Laroche sans protection** | banc E3–E4 | 3 députés PJ à Luthécia le sortent des neuf ; au registre, il ne préside rien |
| 6. **Aucun dixième** parlementaire | banc E5–E6 | éligibles **moins** titulaires des neuf = ensemble vide ; 9 exactement |
| 7. Nouveau Président **toujours** l'un des 9 | banc E24 | l'élu du scrutin préside, et `assemblee_est_des_neuf` le confirme |
| 8. Tests existants **verts** | voir ci-dessous | |

### Migration

| Registre | Nom | md5 | Caractères |
|---|---|---|---|
| `20261011182306` | `assemblee_presidence_suit_la_legislature` | `4b780a0772b07ce23569587ca615e267` | 15 885 |

**9 preuves structurelles.** Catalogue : **+2 fonctions**, +1 commentaire, +5 droits de fonction.
**Aucun objet structurel** — les empreintes colonnes, contraintes, index, vues, déclencheurs,
policies et privilèges par défaut sont **inchangées**, ce qui prouve que la migration n'a touché que
la logique.

### Bancs

| Banc | Épreuves |
|---|---|
| `banc-renouvellement-legislature.sql` (neuf) | **24** |
| `banc-quatrieme-passe.sql` | 53 |
| `banc-presidence-election.sql` | 35 |
| `banc-presidence-suspension-partis.sql` | 37 |
| `banc-seance-parole-discipline.sql` | 35 |
| `banc-seance-protestation-suspension.sql` | 29 |
| `banc-assemblee-regards.sql` | 26 |
| `banc-quatrieme-passe-client.js` | 42 (35 → 42) |
| Les 42 bancs JS, les 11 contrôles du baseline | verts |

**Trois décors de banc ont dû être corrigés**, et c'est le signe que l'invariant mord : ils
forgeaient un Président **sans siège** (Arnie, au registre mais sans mandat). C'est un état que
l'arbitrage interdit. Arnie reçoit un siège à Montrouge — on a corrigé le décor, **pas la règle**.

---

## 6. Un écart de calendrier, remonté et non comblé

L'arbitrage décrit un renouvellement **hebdomadaire, le dimanche à 00:00**. L'existant implémente
autre chose, et l'aligner réécrirait le moteur électoral de la mairie, de la présidence de la
République et du syndicat :

| | Arbitré | Implémenté |
|---|---|---|
| Durée du mandat | une semaine | **5 semaines** (`MANDAT_SEMAINES = 5`, commun aux 4 postes électifs) |
| Instant du renouvellement | dimanche 00:00 | **lundi 00:00** (`dateResultats`) |
| Entre fin de mandat et nouveaux élus | aucun intervalle | **≈ 2 semaines** (candidatures ≥ 6 jours + campagne), pendant lesquelles l'Assemblée est **entièrement PNJ** |

**L'invariant ne dépend d'aucun de ces choix** : il tient sous l'un comme sous l'autre, puisqu'il
est dérivé et non planifié. Le correctif est donc complet **tel qu'il est**, et le calendrier reste
une décision de game design à prendre séparément.

> État réel en production au moment du correctif : les trois cycles de député sont en
> `candidatures`, résultats au **lundi 19 octobre 00:00**, `elus` absent — donc **zéro député
> joueur**, et les neuf sièges tenus par leurs PNJ. Le cycle de Port-Sainte-Marie est `vacant`
> depuis le 30 août.

---

## 7. Ce que ce correctif ne laisse pas derrière lui

**Aucun point technique bloquant issu de cette modification.** Les deux fonctions remplacées l'ont
été à signature identique, aucun appelant n'a changé de contrat, les six bancs SQL de l'Assemblée et
les 42 bancs JS sont verts, et les 11 contrôles du baseline aussi.

Ce qui reste ouvert appartient au game design, et était déjà consigné :

| Point | Nature |
|---|---|
| Le **calendrier** du renouvellement (ci-dessus) | game design |
| Le **cumul affiché** présidence + autre poste nommé (`state.poste` unique) | game design |
| Le **nom** « President Laroche », qui affirme une fonction qu'il peut perdre | identité — passe Laroche |
| Le vote **législatif** lit la présence sans passer par `acteur_present_sur_site` | dette technique, sans conséquence aujourd'hui |

**Le bâtiment n'est pas clos.**
