# Calendrier électoral commun — une succession ne vacance plus le poste

**11 octobre 2026, au soir. Registre Supabase 663 → 667.**
Commune aux **quatre** postes électifs : Président de Républia, Chef Syndical, Maire, Député.

---

## 1. L'arbitrage, tel qu'il a été rendu

1. un mandat dure normalement **5 semaines** ;
2. s'il faut un **second tour**, le mandat en cours est **prolongé** jusqu'au résultat de ce second
   tour : il dure donc **6 semaines** ;
3. il ne doit **JAMAIS** y avoir de vacance institutionnelle entre deux mandats **uniquement**
   parce qu'une élection est en cours ;
4. le titulaire sortant reste titulaire et **conserve ses pouvoirs** jusqu'au moment exact où le
   résultat définitif désigne son successeur ;
5. à cet instant, la succession est **immédiate** : sortant → entrant, sans période intermédiaire.

Et pour les candidatures :

- ouvertes **dès le commencement** du mandat ;
- ouvertes pendant les **4 premières semaines** ;
- **gelées** au début de la dernière semaine précédant le scrutin ;
- aucune période post-mandat dédiée aux candidatures.

---

## 2. Ce que l'audit avait mesuré, et qui est supprimé

Au passage de `dateFinMandat`, le cron remplaçait le blob du cycle par un cycle de candidatures
frais. Comme `poste_est_atteste` ne lit que `eluId` / `elus`, **cette seule écriture faisait
disparaître le titulaire** — et le successeur n'était proclamé que **quatorze jours** plus tard, à
la fin du scrutin que ce même bloc venait d'ouvrir.

Mesuré sur les données réelles du cycle présidentiel de Républia : mandat terminé le lundi
14 septembre 2026 à 00:00, successeur proclamé le lundi 28 septembre. **Quatorze jours exacts.**
Un mandat de 5 semaines revenait donc toutes les **7 semaines**, et le poste était vide **deux
semaines sur sept** — pour les quatre postes électifs, à chaque alternance.

Les deux blocs qui le produisaient sont **retirés** de `api/cron-minuit.js` :

- le **renouvellement d'un mandat échu**, qui écrasait le blob ;
- la **relance d'un cycle vacant**, qui n'agissait que si le cycle portait `relancePossibleApres`
  — un cycle vacant sans ce champ ne repartait **jamais**.

Il n'y a plus rien à renouveler ni à relancer : un mandat ne se termine plus seul.

---

## 3. Le contrat du blob — le mandat et son scrutin coexistent

`phase` ne décrit plus que le **SCRUTIN DE SUCCESSION**. Le mandat en exercice vit à côté, dans le
même blob, et **rien de ce que lit l'attestation n'est touché** quand le scrutin s'ouvre.

| Champ | Ce qu'il porte |
|---|---|
| `eluId` / `elus` | **le ou les titulaires EN EXERCICE**. Seule source d'autorité, lue par `poste_est_atteste`. Jamais effacée avant la proclamation d'un successeur |
| `dateDebutMandatTs` | début du mandat en exercice — posé à `dateResultats`, **jamais à l'heure de la passe de cron** |
| `dateFinMandat` | fin du mandat = `dateResultats`. **Les deux sont le même nombre, par règle** |
| `phase` | `candidatures` → `second_tour`. **`mandat` et `vacant` ne sont plus jamais écrites** |
| `dateDebutCandidatures` | = début du mandat. Les candidatures sont ouvertes dès cet instant |
| `dateDebutCampagne` | **le GEL** : lundi 00:01 de la dernière semaine du mandat |
| `dateVote` | le **dernier dimanche** du mandat, 00:01 |
| `dateResultats` | lundi 00:00 qui clôt le mandat et ouvre le suivant |
| `dernierResultatTs` | instant du dernier résultat réellement arrêté — porte la fenêtre de contestation de 24 h, que `resultatsTraites` ne pouvait plus porter |

**`'mandat'` et `'vacant'` sont conservées dans `PHASES_ELECTORALES`** (data.js) pour relire un
blob antérieur et pour les libellés ; elles ne sont plus produites. Une phase neuve,
`DEPOUILLEMENT`, remplace le `Vacant` que le navigateur affichait à tort entre la clôture du vote
et la passe du serveur.

---

## 4. Chronologie finale d'un mandat normal — 5 semaines

Dates réelles du cycle présidentiel de Républia après transition. Heures de Paris.

| Semaine | Du lundi | Phase du scrutin | Candidatures | Titulaire |
|---|---|---|---|---|
| **S1** | 28 sep 00:00 | `candidatures` | **ouvertes** | le nouveau, dès 00:00 |
| **S2** | 5 oct | `candidatures` | **ouvertes** | en fonction |
| **S3** | 12 oct | `candidatures` | **ouvertes** | en fonction |
| **S4** | 19 oct | `candidatures` | **ouvertes** | en fonction |
| **S5** | **26 oct 00:01 — GEL** | `campagne` | **fermées** (les déposées restent valides) | en fonction |
| — | **dim 1er nov 00:01 → lun 2 nov 00:00** | `vote` | fermées | **toujours en fonction** |
| — | **lun 2 nov 00:00** | **résultat définitif** | — | sortant → entrant, **même instant** |
| **S1'** | 2 nov 00:00 | `candidatures` du mandat suivant | **ouvertes** | le nouveau |

**Aucun instant sans titulaire.** La proclamation est l'unique événement qui termine un mandat, et
c'est le même qui commence le suivant.

---

## 5. Chronologie avec second tour — 6 semaines

| Semaine | Du lundi | Ce qui se passe | Titulaire |
|---|---|---|---|
| S1 → S4 | | candidatures ouvertes | sortant |
| S5 | gel le lundi 00:01 | campagne | sortant |
| — | dimanche de S5 | **premier tour** | sortant |
| — | lundi 00:00 | **pas de majorité absolue** → second tour annoncé, `tour = 2`, `dateFinMandat` repoussée d'une semaine | **sortant, pleinement en fonction** |
| **S6** | | campagne de second tour, **aucune candidature** (la liste est réduite aux deux qualifiés par le serveur) | **sortant** |
| — | dimanche de S6 | **second tour** | sortant |
| — | lundi 00:00 | **résultat définitif** | sortant → entrant, immédiat |

Le mandat sortant est prolongé **par la pose de `dateFinMandat = dateResultats` du second tour**.
Aucun champ d'attestation n'est touché à ce moment-là, et c'est délibéré : c'est exactement ce qui
garantit qu'il n'existe aucun instant sans titulaire entre les deux tours.

Les **législatives sont à UN SEUL TOUR** depuis le 12 septembre 2026 : ce cas ne les concerne pas.

---

## 6. Un scrutin qui ne désigne personne PROLONGE, il ne vacance pas

| Branche | Effet sur le mandat | Effet sur le scrutin |
|---|---|---|
| **vainqueur** | se termine, successeur en fonction au même instant | un scrutin neuf de 5 semaines s'ouvre |
| **pas de majorité absolue** | **prolongé d'une semaine** | second tour, le dimanche suivant |
| **vote blanc majoritaire** | **prolongé de 2 semaines** | scrutin rejoué : 1 semaine de candidatures, 1 de campagne et de vote |
| **aucun bulletin exprimé** | **prolongé de 2 semaines** | idem |
| **exprimé mais sans verdict ni second tour possible** | **prolongé de 2 semaines** | idem |

**Pourquoi deux semaines et pas une.** C'est la durée minimale qui permette de **rejouer un
scrutin complet** : un seul dimanche de plus ne laisserait aucune place à une candidature, et le
scrutin suivant serait désert **par construction**. Une épreuve du banc le démontre en appelant
`calendrierSuccession(debut, 1)` et en constatant que le gel tombe dans la minute.

**Chaque prolongation est annoncée publiquement** — huit annonces couvrent les huit états du
dépouillement, et une épreuve structurelle refuse qu'une branche reste muette.

Les règles de **majorité**, de **second tour**, de **vote blanc** et le **filet PNJ** ne sont
touchés en rien au-delà de ce que l'invariant exigeait.

---

## 7. Minuit de Paris, et les changements d'heure

**Aucune date n'est calculée en `+N × 24 h`.** Tout passe par les dates calendaires de Paris
(`dateCalendairePlusJours`, `instantHeureParis`), donc le vote reste un dimanche et minuit reste
minuit à travers les changements d'heure. Quatre épreuves du banc l'encadrent :

- un mandat du 2026-10-12 au 2026-11-16 **enjambe le passage à l'heure d'hiver** : il dure 35 jours
  calendaires, soit 35 × 24 h **plus une heure réelle** ;
- un mandat du 2026-03-09 au 2026-04-13 enjambe le passage à l'heure d'été : 35 jours calendaires,
  **moins une heure réelle** ;
- dans les deux cas, le gel reste un lundi 00:01 et le vote un dimanche 00:01.

**Ce qui reste imparfait, et c'est dit.** La **règle** est exacte à la minute de Paris :
`dateResultats` est un lundi 00:00 de Paris, hiver comme été, et la fenêtre de vote est fermée au
serveur à cet instant précis. En revanche la **proclamation** est écrite par la passe de cron, et
la plateforme déclenche `/api/cron-minuit` dans l'heure qui suit `0 23 * * *` UTC — mesuré à
23:59 UTC sur les douze cycles, soit **lundi 00:59 Paris en hiver et 01:59 en été**. Le changement
de titulaire a donc un **retard borné de 1 à 2 heures** sur minuit.

**Ce retard ne peut produire ni vacance ni résultat différent**, et c'est pour cela qu'il est
acceptable :

- le vote est **fermé** depuis `dateResultats` — personne ne peut plus voter pendant le retard, et
  le dépouillement est **déterministe** (aucun `Math.random` dans les deux résolveurs) ;
- le **sortant reste pleinement attesté** pendant ce retard, ce qui est exactement la règle
  arbitrée — l'attestation ne lit **aucune date**, seulement `eluId` / `elus` ;
- `dateDebutMandatTs` du nouveau mandat est posé à **`dateResultats`**, pas à l'heure de la passe :
  la **durée** des mandats est donc exacte et ne dérive pas, passe après passe.

Autrement dit : la règle institutionnelle ne dépend d'aucune heure UTC. Seule l'écriture a un
retard, et pendant ce retard personne ne gagne ni ne perd un pouvoir.

> **Pour supprimer ce retard il faudrait un second déclencheur** — par exemple `0 22,23 * * *` sur
> un point d'entrée dédié à la seule passe électorale, l'une des deux heures tombant sur minuit de
> Paris selon la saison. Ce n'est **pas fait** : la passe électorale est un bloc *inline* du
> gestionnaire de minuit, et l'extraire est un chantier à part. **Point rapporté, non comblé.**

---

## 8. Deux colonnes neuves — la conséquence la plus silencieuse

`candidatures` et `votes_electoraux` ne portaient que `(pays, poste, ville)` : elles identifiaient
un **POSTE**, jamais un **SCRUTIN**. Tant que le cron détruisait le blob à chaque renouvellement, le
rapprochement restait approximativement juste. Maintenant qu'un cycle traverse les scrutins,
`syncCyclesDepuisSupabase` réinjecterait dans le scrutin **en cours** les candidats et les bulletins
des scrutins précédents — et le dépouillement les compterait.

| Colonne | Valeur | Posée par |
|---|---|---|
| `candidatures.cle_scrutin` | `dateDebutCandidatures` du cycle, en ms | le déclencheur `candidatures_cloture`, qui **relit le cycle** — jamais le client |
| `votes_electoraux.tour` | `dateVote` du cycle, en ms — même clé que `elections_tracts_pnj.tour` | `election_voter` |

**Et le tour dans la clé du bulletin ferme un défaut PRÉALABLE.** L'identifiant valait
`pays_cle_votant`, sans aucune composante de tour. Un électeur ayant voté au premier tour obtenait
donc `deja_vote` au **second** — le blob remettait `votes` à zéro, mais la ligne survivait.
**Personne n'avait jamais pu voter à un second tour.** Une épreuve du banc SQL le démontre dans les
deux sens.

---

## 9. Le casting des neuf députés PNJ — une seule réalité

L'audit avait trouvé **deux castings entièrement disjoints, sans un seul nom commun** : celui que
le dépouillement inscrivait dans `cycle.elus` pour compléter les sièges manquants, et
`assemblee_sieges`, le registre réellement affiché dans l'hémicycle.

**Le casting officiel est celui de l'hémicycle**, et c'est lui que le moteur électoral emploie
désormais, dans l'ordre des rangs :

| Ville | Rang 1 | Rang 2 | Rang 3 |
|---|---|---|---|
| **Luthécia** | Étienne Vauclerc | Sophie Maréchal | President Laroche |
| **Port-Sainte-Marie** | Yann Legall | Maëlle Leroux | Loïc Kermeur |
| **Montrouge** | Nathalie Charron | Gérard Pichon | Élodie Vasseur |

L'ancien casting fantôme — Marchand / Fontaine / Rousseau / Lecoq / Girard / Ambroise / Ferraille /
Charbonnier / Houiller — est **supprimé**. Il ne représente plus aucun député, nulle part.
Quatorze épreuves le vérifient : neuf noms dans l'ordre, aucun fantôme, et aucun suffixe « (PNJ) »
— ce sont des personnes de l'hémicycle.

Il reste **une ressaisie surveillée** : `api/` ne peut pas lire une table au chargement du module,
donc ces neuf noms sont une copie de `assemblee_sieges.pnj_nom`. Le banc JavaScript les confronte à
la liste écrite en clair, et le banc SQL confronte cette même liste au **registre en base**. Une
divergence d'un côté ou de l'autre rougit.

---

## 10. La succession de l'Assemblée

- les 9 sortants restent députés **jusqu'au résultat définitif** ;
- au résultat définitif, les 9 nouveaux remplacent les sortants — **en une seule écriture par
  ville**, donc simultanément par construction ;
- la présidence de l'ancienne législature **prend fin au même instant**, parce qu'elle est
  **dérivée** des neuf (`assemblee_president` ne rend le titulaire du registre que s'il est l'un
  des neuf) et non planifiée ;
- **aucun Président de transition n'est créé** ;
- le lundi suivant, les neuf nouveaux élisent leur Président selon le système déjà validé —
  convocation du lundi, aucune candidature, présence dans l'hémicycle exigée, clôture à 23:00.

`assemblee_presidence_fin_de_legislature` ne **crée** pas la fin de la présidence : elle
l'**enregistre**, en retirant du registre des postes une ligne devenue fausse. Une épreuve du banc
vérifie que la ligne du registre survit à la succession et que la présidence est déjà tombée —
c'est la preuve que l'invariant ne dépend d'aucune tâche planifiée.

---

## 11. Transition des cycles vivants — ne jamais raccourcir un mandat

| Cas | Lignes | Traitement |
|---|---|---|
| **(a)** pas de titulaire, scrutin à venir | **8** | **intactes**. Rien à protéger, calendrier devant |
| **(b)** un titulaire | **2** | scrutin de succession reposé sur le mandat **existant**. Fin = premier **lundi 00:00 de Paris à ou après** la fin déjà annoncée |
| **(c)** pas de titulaire, scrutin échu ou figé | **1** | scrutin neuf de 2 semaines à partir du prochain lundi |

- `republic_president` : fin au lundi **2026-11-02 00:00** — elle **n'a pas bougé d'une seconde**.
  Gel le 2026-10-26 00:01, vote le dimanche 2026-11-01.
- `republic_maire_ville_b` : mandat d'une génération antérieure au calendrier du dimanche, annoncé
  jusqu'au **vendredi 2026-10-16 01:59**. Ré-ancré au **lundi 2026-10-19 00:00** — trois jours de
  **plus**, jamais un de moins. **Conséquence assumée et rapportée** : son gel tombe le
  2026-10-12 00:01, donc la fenêtre de candidature restante est courte. Un mandat déjà dans ses
  derniers jours ne peut pas offrir quatre semaines de candidatures sans être prolongé, et le
  prolonger de dix jours serait un changement plus grand que celui-là.
- `republic_depute_ville_a` : figé en vacance depuis le **13 septembre 2026** sans
  `relancePossibleApres`, donc **sans relance possible** — les trois sièges de Port-Sainte-Marie
  n'avaient plus de scrutin du tout. Un scrutin neuf est posé : candidatures ouvertes jusqu'au
  2026-10-19 00:01, vote le dimanche 2026-10-25, résultat le lundi 2026-10-26 00:00.

Trois preuves de la migration portent sur les **données** et non sur le texte : aucun cycle n'est
plus sans scrutin à venir, aucun ne porte un état de l'ancien contrat, et **les deux titulaires en
exercice sont toujours là** — une migration qui les perdrait trahirait l'arbitrage qu'elle applique.

---

## 12. Corrections connexes demandées

| Point | État |
|---|---|
| `republic_depute_ville_a` bloqué définitivement | **corrigé** — et la cause structurelle (`relancePossibleApres`) a disparu avec le bloc qui la lisait |
| décalage client « Vacant » alors que le serveur atteste encore | **corrigé** — `getPhaseActuelle` ne rend plus `VACANT` après la clôture du vote mais `DEPOUILLEMENT`, et `VACANT` est désormais **dérivé du titulaire**, pas d'une date. `detailCalendrierCycle` affiche « Mandat en cours » **à côté** du scrutin, et non à sa place |
| anciens cycles non alignés (maire de Montrouge) | **corrigé par la migration de transition**, sans raccourcir le mandat |
| `chef_syndicat` correctement nommé/configuré | **corrigé** — ajouté à `POSTE_NOMS` (« Chef Syndical ») et à `POSTE_SCOPE` (`national`). Ses annonces publiques affichaient l'identifiant brut. Il reste le seul poste électif que la cascade PNJ ne pourvoit **jamais**, par arbitrage explicite |
| dépendance aux champs `personnages.poste` / `poste_depute` périmés | **aucune n'a été réintroduite**. Une preuve de la migration refuse que `poste_est_atteste` mentionne `poste_depute`, et le banc SQL laisse **exprès** trois fiches périmées en base après la succession : si le siège en dépendait encore, l'ancienne législature siégerait toujours |
| la durée du mandat ne doit pas dériver de `data.js` | **surveillée** — une épreuve confronte `MANDAT_SEMAINES` du serveur aux quatre `mandatSemaines: 5` de `data.js`. L'audit avait trouvé que ce champ n'était **lu par personne** : une dérive n'aurait rien rougi |

---

## 12 bis. Un seul fabricant de titulaire — vérification du 11 octobre au soir

**Le ré-ancrage du maire de Montrouge est une opération de données, et rien d'autre.** Il vit
exclusivement dans le bloc `DO $transition$` de la migration `20261011195123`, enregistrée au
registre et jamais rejouée. Mesure en base : **zéro fonction vivante** ne porte cette logique ni
`relancePossibleApres`. Il n'existe plus de notion d'« ancienne génération » : après la transition,
les douze cycles sont sur le socle, et le mot n'existe que dans l'archive de la migration.

**`dateFinMandat` n'a que DEUX écrivains dans tout le code exécuté** — `ouvrirSuccessionSurCycle`
(le socle) et la branche du second tour (prolongation d'une semaine) — et **zéro** au navigateur.
Une épreuve les compte.

**Un survivant a été trouvé et supprimé : le PNJ administrateur client.**
`PNJ_ADMINISTRATEURS` + `nommerAdministrateurSiVacant` + `verifierPostesVacants`, appelés depuis
`plateau-core.js` au chargement — 73 lignes. Il posait `cycle.eluId = '<nom> (Admin)'`, donc un
titulaire, **sans `dateDebutMandatTs`, sans `dateFinMandat` et sans scrutin de succession** : un
mandat sans fin et sans élection suivante. Il était en outre purement local (aucune persistance,
donc effacé à la synchronisation suivante) et à moitié cassé (`city` n'était ni paramètre ni
variable locale ; les clés du cache sont `maire_capitale`, jamais `maire`).

Ce qui le remplace existait déjà, au serveur, et il est complet :
`verifierPostesVacantsEtAutoPourvoir` → `pourvoirCycleElu` installe le PNJ par défaut, l'ancre au
**lundi 00:00 de Paris** et ouvre son scrutin de succession par `ouvrirSuccessionSurCycle` — le
socle. Zéro cycle de la base ne portait `administrateur` au moment du retrait.

**`construireNouveauCycleElectoral` subsiste, et il ne fabrique aucun mandat.** C'est le générateur
de **genèse** d'un poste qui n'a jamais eu de titulaire (`initCycleElectoral`) et le relanceur de la
**dissolution présidentielle** — règle distincte, qui coupe un mandat court volontairement. Son
produit ne porte ni `eluId`, ni `elus`, ni `dateFinMandat` ; trois épreuves le vérifient. Et quand
ce scrutin de genèse se résout, c'est `prendreFonctions()` qui agit : mandat de 5 semaines du socle.

**Réponse aux trois questions** : (1) oui, ponctuel ; (2) un seul survivant, supprimé ; (3) oui —
le prochain cycle du maire de Montrouge sera créé par `prendreFonctions()` si le scrutin désigne
quelqu'un, par `prolonger()` sinon, tous deux appelant `ouvrirSuccessionSurCycle`, exactement comme
les trois autres postes.

---

## 13. Ce qui reste à arbitrer

1. **La fenêtre de candidature d'un scrutin rejoué.** Un mandat prolongé de deux semaines offre
   **une** semaine de candidatures, pas quatre. C'est le minimum qui rende le scrutin jouable, pas
   une règle arbitrée. Si quatre semaines sont voulues même après un vote blanc, la prolongation
   doit passer à 5 semaines — ce qui revient à offrir un mandat complet au sortant.
2. **La fenêtre de candidature d'un mandat ré-ancré.** Le maire de Montrouge n'a qu'un jour. Cas
   unique et transitoire, mais la règle générale (« ré-ancrer sans raccourcir ») le reproduira
   chaque fois qu'un mandat de l'ancienne génération sera repris.
3. **Le retard de 1 à 2 heures de la proclamation** (§7). Supprimable par un second déclencheur,
   au prix de l'extraction de la passe électorale du cron de minuit.
4. **`chef_syndicat` n'a aucun filet PNJ.** Un scrutin syndical désert prolonge un mandat
   inexistant : le poste reste sans titulaire et le scrutin se rejoue toutes les deux semaines,
   indéfiniment. C'est l'arbitrage existant (« jamais de PNJ pour le syndicat »), mais il produit
   désormais une boucle visible.
5. **L'ancre du mandat d'un PNJ de secours.** `pourvoirCycleElu` ancre au **lundi 00:00 de la
   semaine en cours**, donc dans le passé si la cascade tourne un mercredi : la grille du socle est
   respectée (gel en S5, vote le dernier dimanche, résultat le lundi), mais ce premier mandat dure
   **moins** de 5 semaines réelles — jusqu'à 6 jours de moins. L'ancrer au lundi **suivant** le
   rendrait plus long que 5 semaines. Aucun des deux n'est 5 semaines exactes : c'est un choix, et
   il n'a pas été fait à votre place.
