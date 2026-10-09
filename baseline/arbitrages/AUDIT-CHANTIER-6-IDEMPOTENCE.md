# Chantier 6 — ce qui rejoue dans la passe de minuit

> **Audit statique du 8 octobre 2026**, en contre-lecture de
> [`AUDIT-CRON-MINUIT.md`](AUDIT-CRON-MINUIT.md). Aucun accès à Supabase.
> `api/cron-minuit.js` : **6 304 lignes**, **18** `tacheQuotidienne(...)`.
>
> **REVALIDÉ LIGNE À LIGNE LE 9 OCTOBRE 2026**, cette fois contre le code réel
> et la base. Les dix constats du tableau ci-dessous tiennent. Trois précisions
> que la revalidation ajoute :
> - `tacheQuotidienne` est appelée **21 fois**, pas 18 ;
> - **les familles 1, 2, 4 et la plupart du groupe B ne sont PAS enveloppées**
>   par `tacheQuotidienne` : elles sont appelées nues dans le handler et n'ont
>   donc aucune protection de registre, seulement leurs gardes internes ;
> - la **grève générale** prétend en commentaire suivre « la même doctrine que
>   la grève ordinaire » : c'est faux depuis le correctif du 7 octobre, qui n'a
>   touché que la grève ordinaire. Son marqueur est écrit en dernier, dans un
>   `.catch(() => {})`.
>
> **Deux lignes sont fermées depuis.** La famille 4 (ardoise des loyers) et les
> mensualités Helvetia de la famille 9 — voir leurs entrées.

---

## 0. La ligne de fracture n'est pas celle qu'on croit

Le découpage naturel serait « marqueur dans un blob » contre « clé primaire
portant le jour ». **C'est le mauvais critère.** `douane_payer_effectifs` pose son
marqueur dans un champ de blob — `effectifsDouane.dernierPaiementJour` — et il
est pourtant **inperdable**, parce qu'il est écrit dans la **même transaction
PostgreSQL** que le débit.

> **La ligne de fracture est JS contre RPC, pas blob contre clé.** Un marqueur
> écrit par le cron en JavaScript est toujours perdable, quel que soit son
> support, parce qu'il voyage dans une requête HTTP distincte de l'effet qu'il
> atteste. Un marqueur écrit dans la transaction de l'effet est sûr, même dans un
> blob.

Ce critère seul réduit le chantier de moitié : huit mécaniques sortent du
périmètre sans qu'on y touche.

---

## 1. Groupe A — même défaut, dix familles

**Le défaut, identique partout et sans rapport avec le métier : l'effet et sa
preuve d'exécution sont dans deux requêtes HTTP distinctes. La fenêtre entre les
deux est un double débit en attente.**

Classées par **coût d'un rejeu**, ce qui est l'ordre d'attaque :

| # | Famille | Ce qu'un rejeu produit |
|---|---|---|
| 1 | **Candidatures aux postes nommés** | Les marqueurs `dossier.traitee` sont posés **en mémoire** et persistés **une seule fois pour toute la passe**. Un échec avalé annule le marquage de **tous** les dossiers. Or chacun a déjà produit un titulaire PNJ supprimé, un upsert dans `postes_attribues`, une fiche réécrite, un mail de nomination, et **la POP du nominateur divisée par deux**. Le rejeu retire au hasard → **autre gagnant**, et **redivise la POP par deux** : la sanction n'est pas idempotente, elle est **multiplicative** |
| 2 | **Compromis de vente / d'entreprise** | Trois scénarios : double crédit de prêt (le tirage `random()` est rejoué) ; argent sans dette (seul l'`INSERT prets` échoue) ; double remboursement d'acompte, avec une **seconde** ligne d'historique que la clé primaire ne refuse pas — elle porte un `Date.now()` |
| 3 | **Taxe foncière** | **Aucun marqueur par terrain**, registre seul. Une double exécution avance de deux crans dans avertissement → pénalité 10 % → **saisie municipale** |
| 4 | ~~**Ardoise d'impayé des loyers**~~ **FERMÉ le 9 octobre 2026** | Le constat était juste : la branche `expulsion_requise` était la seule sortie à effet à ne pas poser `jourPaiement`, et la dette doublait à chaque passe. **Corrigé par la migration 20261009005012 + `api/cron-minuit.js`, dans le même commit.** Et le correctif a appris quelque chose que l'audit n'avait pas vu : poser le marqueur **n'aurait pas suffi**, parce que l'appelant réécrivait le blob entier depuis une lecture antérieure à la RPC et l'aurait effacé dans la foulée. Le calcul de l'ardoise est donc **descendu dans la RPC**, où revendication et effet sont atomiques |
| 5 | **Votes de confiance** | Le dépouillement **tire au sort** les sièges PNJ ; la clôture `statut = 'termine'` est avalée. Si elle mord après que l'événement public et le mail au Premier ministre ont annoncé le verdict, le rejeu **re-tire** : le même vote passe de confiance à censure, **publiquement, deux fois** |
| 6 | **Remboursement des préemptions d'État** | **Aucun marqueur propre.** La caisse est débitée, puis `preemption.montantRestant` est écrit — deux requêtes. Une interruption entre les deux débite sans réduire la dette, et le registre, posé avant, **interdit la reprise** : l'argent est perdu silencieusement. Le pire des sept, parce qu'**aucun joueur ne se plaint d'une dette qui ne baisse pas assez vite** |
| 7 | **Successions** | Fenêtre étroite, montant élevé. Le code est par ailleurs bien construit (voir §3) |
| 8 | **Calendrier électoral** | `cycle.resultatsTraites` est un champ de blob écrit **en dernier**, sans vérification, après que `evenements_globaux` et `chronique_nationale` ont été insérés. Un échec → **re-dépouillement**, et `resoudreScrutinSimple` est aléatoire : deux proclamations contradictoires |
| 9 | **Mensualités de prêts** | Marqueur sur une **vraie colonne**, posé avant l'effet — mais en `.catch(() => {})` : l'échec de pose est avalé et le débit part quand même. C'est l'**inverse exact** de `tacheQuotidienne`, qui relit et renonce |
| 10 | **Cotisations d'organisation** | Réparé partiellement le 7 octobre (persisté après **chaque** membre). Le code reconnaît lui-même que ce n'est pas la réparation complète : « Débiter un personnage et marquer son adhésion sont deux écritures sur deux tables » |

### La brique générique — elle existe déjà dans le dépôt

`repartitions_versements(pays, source, beneficiaire, jour)` en clé primaire est
le patron, et son commentaire énonce la doctrine : « L'idempotence vit dans la
clé primaire. Un second passage lève une violation d'unicité et ne verse rien.
Ce n'est plus un champ qu'une écriture avalée peut perdre. »

Généralisée :

```
actes_nocturnes(pays, mecanisme, sujet, jour)   PRIMARY KEY
```

et une convention : **toute RPC nocturne commence par un `INSERT INTO
actes_nocturnes` et laisse la violation d'unicité annuler sa propre
transaction.** Le rejeu ne devient pas « détecté », il devient **impossible** —
et impossible sans que personne ait à se souvenir de poser un marqueur.

**Mais une clé primaire ne protège que ce qui commit avec elle.** La brique est
donc en deux temps : (1) la table et la convention, communes ; (2) **une RPC par
famille**, dont `resoudre_compromis_helvetia_expire` est le patron de référence —
déjà écrit, déjà déployé, et faisant exactement ce que les neuf autres doivent
faire (`SELECT … FOR UPDATE`, crédit, `INSERT`, mutation du blob et archive dans
un seul `BEGIN`).

**Et le tirage aléatoire doit entrer dans la RPC.** Partout où un rejeu re-tire
— compromis, candidatures, votes de confiance, élections — laisser `random()`
dans le JS garantit qu'un rejeu donnera un autre résultat, même avec un marqueur
correct.

---

## 2. Groupe B — rien à faire, et il faut l'écrire pour ne pas y revenir

Toutes déjà transactionnelles, par transition d'état ou par clé portant le jour.
**Les toucher serait une régression.** Elles s'extraient telles quelles dans leur
lot :

candidatures militaires · affectations militaires · paye de la douane · paye de
la police · transits d'entrepôts · cellules et rapports de renseignement ·
détentions PNJ · collecte des agents · Journal du jour · Assemblée
(`cron-assemblee.js`) · redistribution fiscale nationale.

Deux formes exemplaires à citer en référence :

- **le Journal du jour** : le verrou **est** l'`INSERT` lui-même contre
  `UNIQUE (journal_id, date_edition)`. Pas de lecture préalable, et le
  commentaire explique pourquoi. Un 409 signifie « ce titre a déjà une ligne pour
  ce jour » ;
- **l'Assemblée** : `assemblee_cloturer_echues` « est idempotente — un scrutin
  déjà clos renvoie son archive sans rien remodifier ». **Le modèle que les
  votes de confiance doivent copier est à côté d'eux, dans le fichier voisin.**

---

## 3. Deux affirmations de l'audit du 7 octobre qui étaient fausses

### Les successions ne sont pas une passoire

L'audit disait « huit écritures non atomiques, toutes en `.catch(() => null)` ».
C'est faux. `reglerSuccession` : garde par disposition (`if (d.regle) continue;`),
**chaque** écriture vérifiée (`if (!r) return false;`), marqueur posé **par
disposition** immédiatement après la mutation **et relu**, deux marqueurs fiscaux
indépendants également vérifiés, séparation explicite décision/règlement avec
persistance intermédiaire vérifiée.

Le défaut résiduel est **une fenêtre, pas une passoire** : entre le crédit réel
et la pose du marqueur il reste deux requêtes HTTP. Un dépassement du
`maxDuration: 120` ou un crash dans cet intervalle laisse un bénéficiaire
crédité sans `regle` → re-crédit la nuit suivante. Probabilité faible, montant
élevé : un héritage entier.

### Il n'y a pas d'usure de confiance dans le cron

La colonne existe (`pnj_social_relations.confiance`) et est lue par le socle PNJ.
Mais **aucune** des dix-sept occurrences du mot « confiance » dans
`api/cron-minuit.js` ne la concerne : elles portent toutes sur `votes_confiance`.
Ni `cron-minuit.js` ni `cron-assemblee.js` ne recalcule, décrémente ou érode un
indice de confiance.

**Il n'y a donc rien à rendre idempotent ici, et rien à inclure dans le
chantier 6.** Si une usure nocturne est un jour construite, elle devra **naître**
avec sa clé de journée, pas la recevoir après.

---

## 4. Le registre `joursCron` reste le prérequis absolu

`tacheQuotidienne` fait ce qu'il faut : marqueur posé **avant** l'effet, **relu**
pour vérifier la persistance, tâche **refusée** si le marqueur n'a pas pris.

Mais il protège **huit tâches qui n'ont aucune garde interne** — taxe foncière,
effets de blocus, livraisons d'entrepôts, exportations du port, criée,
production des transformateurs, effort de guerre, préemptions — et il est une
**ligne unique**, lue-fusionnée-réécrite sans atomicité, écrite **et relue** 18
fois par nuit.

> **Aucune parallélisation de lots avant** une RPC `cron_marquer_tache(nom, jour)`
> atomique, ou une ligne de registre par lot. **La brique du groupe A ne doit pas
> servir de permis de paralléliser.**

Le même point a une conséquence sur les scandales : les fuites de souvenirs
d'accueil sont correctement ordonnées (marquage `revele: true` vérifié **avant**
l'annonce), mais leur seul rempart contre un double tirage est le registre. Si
deux lots écrivaient `joursCron` en parallèle, chaque passe relancerait un tirage
par souvenir, et chaque fuite est un événement global « SCANDALE » **nominatif et
irréversible**. La frontière devrait être **le souvenir** — une colonne
`jour_tirage` — pas la passe.

---

## 5. Les preuves à exiger, famille par famille

Toutes sur le modèle de `outils/bancs/banc-budget-cascade.sql` : un bloc `DO` qui
écrit, mesure, puis lève pour annuler la transaction. Et toutes avec la même
forme : **deux appels, un seul effet.**

| Famille | L'épreuve qui échoue aujourd'hui et qui est la seule qui compte |
|---|---|
| Candidatures aux postes | `resources.pop` du nominateur divisée **une seule** fois |
| Compromis | `prets` ne contient **qu'une** ligne, `arg` n'a bougé que d'un montant, `compromis_historique` n'a **qu'une** ligne pour ce bien |
| Loyers | bail insolvable **avec `avertissement = true`**, deux appels → `jours = 1` et `montantDu = prix`, pas 2 et 2 × prix |
| Votes de confiance | `resultat` identique aux deux appels, **une seule** ligne `evenements_globaux`, second appel `deja_cloture` |
| Successions | `arg` n'a bougé que d'un `part_nette`, `reserveJour` qu'une fois — **et** relecture établissant que la mutation d'actif et la pose de `regle` sont dans la **même fonction SQL** |
| Élections | **un test d'égalité sur les 170 lignes de calendrier avant tout déplacement**, puis une seule ligne `chronique_nationale` |
| Souvenirs | deux appels **en ignorant le registre** — tout l'intérêt est de prouver que la fonction se défend seule → même nombre de lignes « SCANDALE ». Ce banc est rouge aujourd'hui |
| Prêts, préemptions, cotisations, taxe foncière | deux appels, un seul mouvement, et le second appel **lève une violation d'unicité** plutôt que de renvoyer poliment zéro. La violation est préférable : elle apparaît dans `ECHECS_PASSE`, donc dans le code 500 de la passe |

Contraintes à ajouter, pour que la protection soit structurelle et non
disciplinaire : `UNIQUE` sur `compromis_historique` par bien et par jour, et
`UNIQUE` sur l'identifiant de chronique électorale, qui est déjà stable mais que
rien ne protège.

---

## 6. Décisions de game design

**Aucune.** Tout ce document porte sur la question « cette mécanique peut-elle
s'appliquer deux fois », qui n'est jamais une règle de jeu. Les seuls arbitrages
sont techniques et ils sont pris ci-dessus : la frontière est le sujet (le bien,
le dossier, la disposition, le bail) et non la passe ; le tirage aléatoire entre
dans la transaction ; la clé primaire porte le jour.
