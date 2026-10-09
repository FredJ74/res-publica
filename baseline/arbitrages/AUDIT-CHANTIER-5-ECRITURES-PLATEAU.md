# Chantier 5 — les écritures de `plateau-*.js` qui avalent leur échec

> **Inventaire du 9 octobre 2026**, relu contre le code réel. Aucun accès à
> Supabase : c'est une lecture du dépôt. Il complète
> [`AUDIT-CHANTIER-5-FAIL-SILENT.md`](AUDIT-CHANTIER-5-FAIL-SILENT.md), qui
> comptait les **avaleurs d'erreur** toutes catégories ; celui-ci ne regarde que
> les **écritures**, et les classe par ce qu'elles peuvent détruire.
>
> **À lire avant de toucher à un fichier `plateau-*.js`.** C'est la liste de
> travail : elle dit où une écriture annonce un succès sans preuve, et dans quel
> ordre s'en occuper.

## Méthode, pour qu'elle soit rejouable

43 fichiers `plateau-*.js` à la racine, dont **22 écrivent**. Motifs cherchés :
`sbUpdate(`, `sbInsert(`, `sbUpsert(`, `sbDelete(`, `sbRpc(`, plus les helpers
de `supabase.js` préfixés `sbSave|sbSet|sbEcrire|sbAjouter|sbSupprimer|sbPatcher|sbCreer|sbAppliquer|sbDebiter|sbCrediter|sbPayer|sbVerser`.

| | |
|---|---:|
| correspondances hors commentaires | 411 |
| − définitions locales (`sbSaveCycleElectoral`, `sbCreerVoteConfiance` : définies **dans** `plateau-politique.js`) | −2 |
| − `sbRpc()` de pure lecture | −13 |
| **écritures classées** | **396** |

Deux conventions de comptage, qui changent le résultat et doivent donc être
dites : `.catch(() => null)` **suivi d'un test** compte comme TESTÉ — le `catch`
n'est alors qu'un convertisseur ; et `sbSaveChampionnat`/`sbSaveCompagnie`
n'apparaissent que dans des commentaires (fonctions retirées), donc hors compte.

> **Fait de cadrage, et il surprend : aucun fichier `plateau-*.js` n'appelle
> `sbInsertVerdict`, `sbUpdateVerdict`, `sbDeleteVerdict`, `sbUpsertVerdict` ni
> `sbTransportRest`.** Le socle à verdict existe depuis le 7 octobre et n'a, côté
> plateau, **aucun consommateur en écriture**. Les 87 « VERDICT » du tableau sont
> des `sbRpc()` dont l'appelant lit `.ok` — c'est-à-dire des portes serveur, pas
> la couche à verdict. La seule exception est
> `plateau-justice-economie.js:4833` (`sbRpcVerdict`).

## 1. Synthèse — sensibilité × traitement de l'échec

| Sensibilité | AVALE | TESTÉ | VERDICT | **Total** |
|---|---:|---:|---:|---:|
| **ARGENT** | **23** | 6 | 30 | 59 |
| **PROPRIÉTÉ** | **49** | 13 | 15 | 77 |
| **DROITS** | **52** | 4 | 12 | 68 |
| **SANCTION** | **32** | 0 | 16 | 48 |
| État de jeu | 116 | 14 | 14 | 144 |
| **Total** | **272** | **37** | **87** | **396** |

**La liste de travail, c'est les 156 écritures sensibles AVALÉES** (23 + 49 + 52 + 32).

Quatre lectures de cette grille :

- **SANCTION n'a aucun appel TESTÉ.** C'est soit une RPC à verdict, soit rien.
  Les 32 avalées écrivent toutes en direct dans `detentions`, `personnages`,
  `prisonniers_qhs`, `jugements`, `plaintes_en_cours` — une peine peut donc
  exister dans une table et pas dans l'autre.
- **PROPRIÉTÉ est le gisement le plus mécanique** : 25 des 49 sont le *même*
  appel, `sbSetTerrainState(...).catch(() => {})`.
- **DROITS a le pire ratio** (52 sur 68) : toute la chaîne électorale et les
  postes du Bureau National de l'Emploi y passent.
- **L'économie « moderne » est bien couverte** : 30 VERDICT en ARGENT, ce sont
  les RPC métier livrées depuis septembre. Les 23 avalées sont les restes
  clients — budgets nationaux, municipaux, de clubs, et les `sbSavePersonnage`
  qui suivent un débit.

## 2. Les cinq fichiers qui concentrent le travail

| Rang | Fichier | Sensibles avalées | ARGENT | PROPRIÉTÉ | DROITS | SANCTION |
|---|---|---:|---:|---:|---:|---:|
| 1 | `plateau-justice-economie.js` | **70** | 6 | 25 | 17 | 22 |
| 2 | `plateau-politique.js` | **43** | 4 | 0 | 32 | 7 |
| 3 | `plateau-organisations-quetes.js` | **14** | 8 | 5 | 1 | 0 |
| 4 | `plateau-pnj.js` | **6** | 0 | 6 | 0 | 0 |
| 5 | `plateau-actions-illegales-rumeurs.js` | **5** | 3 | 2 | 0 | 0 |

Ces cinq fichiers portent **138 des 156** entrées (88 %) ; les deux premiers, 113
(72 %). **C'est l'ordre d'attaque**, et il ne coïncide pas avec la taille des
fichiers : c'est la densité d'écritures sensibles qui compte.

## 3. Le vrai sujet : les écritures en chaîne sans atomicité

Une écriture avalée isolée fait perdre un effet. **Deux écritures enchaînées dont
l'une est avalée font perdre de l'argent ou créent un état impossible.** Ce sont
celles-ci qu'il faut fermer d'abord, et presque toujours par une RPC — pas par un
test supplémentaire.

### Argent qui disparaît entre deux écritures

| # | Où | Ce qui se passe |
|---|---|---|
| 1 | ~~`plateau-politique.js` redressement fiscal~~ **FERMÉ le 9/10** | Le débit de la cible était sous verdict, le crédit du Trésor avalé, et le toast annonçait « prélevés pour le Trésor ». **Et le même acte existait en deux exemplaires, un seul réparé** — voir §5 |
| 2 | ~~`plateau-politique.js` demande de grâce~~ **FERMÉ le 9/10** | 300 FR débités de la caisse de la Justice sous verdict, puis `sbCreerDemandeGrace` sans test : frais prélevés, dossier inexistant, Président notifié d'un dossier fantôme |
| 3 | ~~`plateau-organisations-quetes.js` offre de transfert~~ **FERMÉ le 9/10** | PA et coût prélevés, puis `sbCreerTransfert` dont l'identifiant n'était jamais relu : courrier chiffré au président du club vendeur pour une offre qui n'existait dans aucune table |
| 4 | `plateau-justice-economie.js:283-287` | Acceptation de rachat de terrain : `sbSetTerrainState(… proprietaire: acheteur).catch(() => {})` **puis** crédit du vendeur. Les deux toasts sont inconditionnels et le mail de transfert part : l'acheteur peut payer sans recevoir, ou le vendeur encaisser sans céder |
| 5 | `plateau-justice-economie.js:6701/7193 → 6718/7211` | Approvisionnement de chantier : la RPC `approvisionner_chantier` **débite l'entrepôt côté serveur**, la trésorerie du chantier est persistée par un `sbSetTerrainState` avalé. Et le repli `\|\| { depense: 0 }` fait passer un échec de RPC pour un « rien à acheter » |
| 6 | `plateau-actions-illegales-rumeurs.js:5728-5734` | Tournée : trois tables (`invitations_diner`, `tournees`, `personnages`), deux écritures avalées, un toast « Tournée servie ! −montant FR » |
| 7 | `plateau-organisations-quetes.js:8226 puis 8292` | `budgets_clubs` crédité par upsert, **puis réécrit depuis une copie lue avant le crédit**. Les deux avalées : le crédit peut être écrasé. Inoffensif aujourd'hui (`montantTotal = 0` en dur), mais le chemin est en place |
| 8 | `plateau-justice-economie.js:12277-12309` | Taux d'imposition national et local : read-modify-write **sans** condition de version, contrairement aux autres blobs du projet passés en compare-and-swap. Ni test, ni catch, et le toast « Impôts locaux fixés » est inconditionnel |

### Dossier judiciaire éclaté sur plusieurs tables

| # | Où | Ce qui se passe |
|---|---|---|
| 9 | ~~`plateau-justice-economie.js:10806 → 10847`~~ **FERMÉ le 9/10** | `sbCreerDetention` (retour **lu mais jamais testé**) puis `personnages.est_emprisonne` avalé. Un détenu pouvait exister dans une table et pas dans l'autre — et `detentionId: null` était alors écrit dans `est_emprisonne`. `enregistrerDetention` passe par **`detention_ouvrir_soi`**, septième porte de `detention_ouvrir_interne` ; `sbCreerDetention` est **supprimée** |
| 10 | ~~`plateau-justice-economie.js:1893 → 1897 → 1900`~~ **FERMÉ le 9/10** | Transfert au QHS : `detentions`, `prisonniers_qhs`, `personnages`. **Trois tables, trois `.catch(() => {})`** — et une quatrième écriture pour la nouvelle peine. **`detention_transferer_qhs`** fait les quatre en une transaction, chaînées par `detention_precedente_id` |
| 11 | ~~`plateau-justice-economie.js:1300 → 1310`~~ **FERMÉ le 9/10** | Fin de détention : `mode_fin='purgee'` puis `detention_qhs=false`, les deux avalées. **Et l'inventaire avait manqué le pire : `est_emprisonne = null` n'était JAMAIS persisté** — seul `state.estEmprisonne` était vidé. Un joueur libéré qui fermait son onglet restait incarcéré en base. **`detention_clore_purgee`** fait les quatre écritures ensemble |
| 12 | ~~`plateau-justice-economie.js:10950 → 10959`~~ **FERMÉ le 9/10** | Prolongation de peine : `detentions` puis `personnages`, les deux avalées, `return true` final. Et les motifs étaient relus avec `.catch(() => [])` : **un échec de lecture écrasait tous les motifs existants**. **`detention_prolonger_soi`** partage le moteur `detention_prolonger_interne` avec la porte du juge, qui avait divergé |
| 13 | ~~`plateau-justice-economie.js:2494 → 2506`~~ **FERMÉ le 9/10** | `jugements` (insert avalé) puis `plaintes_en_cours` (upsert avalé), et `addExternalEvent('JUGEMENT : …')` partait ensuite sans condition. L'affaire était en outre écrite **deux fois**, dont une en tête de fonction. **`justice_rendre_sentence`** archive et clôt en une transaction, sous `affaire_autorite_de(ville)` — et **nomme elle-même le magistrat**, que le navigateur dictait |
| 14 | `plateau-justice-economie.js:10996` | Avis de recherche écrit en direct sur `personnages.recherche` — et le commentaire du code note lui-même que `sbSavePersonnage` republie `state.recherche` **en bloc** : deux écrivains concurrents de la même colonne |
| 15 | `plateau-politique.js:12473+12475` et `12569+12571` | `sbSavePersonnage` (48 colonnes) immédiatement suivi d'un `sbUpdate('personnages', …)` ciblé, les deux avalés : deux écritures en course sur la même ligne |

### Chaîne électorale

| # | Où | Ce qui se passe |
|---|---|---|
| 16 | ~~`plateau-politique.js:1878-1879`~~ **FERMÉ le 9/10** | **C'était le pire de l'inventaire.** `sbVoterPour` (`votes_electoraux`) était enveloppé dans un `try { } catch(e) {}` **vide, sans aucun retour**, puis `sbSaveCycleElectoral` avalé, puis toast « Vote enregistré ! » — la fonction n'était même pas `async`. **`election_voter`** écrit le bulletin ET le blob du cycle dans une transaction, sous verrou du cycle. `sbVoterPour` est **supprimée** |
| 17 | `plateau-politique.js:5479/5504/5673 → 5663` | Nomination confirmée par RPC (bien), **puis** révocation de l'ancien titulaire (`poste: null`) avalée : deux personnes peuvent porter le même poste |
| 18 | `plateau-politique.js:5911-5954` | Dissolution : cycle électoral, puis `poste_depute = null` en boucle, puis relance par circonscription. Trois vagues, aucune preuve |
| 19 | `plateau-politique.js:1797 → 1817` | Candidature : `sbDeposerCandidature` **testé** (bien) puis `sbSaveCycleElectoral` avalé. Le code assume explicitement le blob comme « cache best-effort » — **c'est le cas le mieux documenté de l'inventaire**, et il reste acceptable tel quel |

### Postes et emploi

| # | Où | Ce qui se passe |
|---|---|---|
| 20 | `plateau-justice-economie.js:12496/12507/12533/12545/12565 + 12551` | Bureau de l'emploi : `sbSetEtatBNE` (table `batiments_etat`) puis `sbSavePersonnage` (`emploiBNE`), **aucun des deux testé**. Le poste peut être pris en base sans que le personnage le porte, ou l'inverse |

## 4. Ce qui a été fermé le 9 octobre 2026

Trois chaînes, choisies parce qu'elles étaient les seules où **de l'argent déjà
prélevé** pouvait rester sans contrepartie :

1. **Redressement fiscal** — voir §5, c'était un doublon autant qu'un défaut.
2. **Demande de grâce** — le verdict de `sbCreerDemandeGrace` est lu. En cas
   d'échec, on ne peut **pas** rembourser : `caisse_ministere_mouvement` refuse
   les montants négatifs *par construction*, pour qu'une caisse ne soit pas
   créditable depuis le navigateur. Inventer un chemin de remboursement
   ouvrirait exactement la faille que cette porte ferme. On dit donc la vérité,
   avec le montant et le nom, pour que l'écart soit réparable.
3. **Offre de transfert** — l'identifiant est relu. Les PA ne sont pas rendus, et
   ce n'est pas un oubli : `deduireCoutOrdre` est le point d'exécution
   irréversible de l'ordre, par doctrine du projet.

**Dans les trois cas, le chemin nominal est inchangé au caractère près.** Seul le
chemin d'échec cesse de mentir. C'est la seule façon de corriger ce défaut sans
toucher au game design : un succès annoncé à tort n'est pas une fonctionnalité.

## 4 bis. Le second lot du 9 octobre 2026 — les cinq chaînes judiciaires et le vote

Les six chaînes 9 à 13 et 16 sont fermées. Elles l'ont été **par factorisation,
pas par correctif** : `detention_ouvrir_interne` existait déjà et portait
exactement la séquence « ligne de détention + état du personnage, en une
transaction, avec sa garde de rejeu ». Il lui manquait une porte d'autorité pour
le cas « sur soi-même ». On n'a donc pas écrit une primitive de plus : on lui a
ouvert sa septième porte.

| Chaîne | Porte serveur | Ce que la fermeture a révélé en plus |
|---|---|---|
| 9 — ouverture | `detention_ouvrir_soi` | la primitive ne savait pas porter six métadonnées judiciaires du client (`ville_condamnation` distincte, `jour_affaire`, `detention_precedente_id`, `reliquat_jours`, `retour_ville`). Un seul paramètre `p_extras` les transporte, au lieu de six |
| 10 — transfert au QHS | `detention_transferer_qhs` | le drapeau partait en `JSON.stringify` sur une colonne **jsonb** : un scalaire de type string, que `pa_repos_nocturne` ne sait pas lire. **Le plafond de PA du quartier ne s'est jamais appliqué aux QHS posés par un navigateur** |
| 11 — fin de peine | `detention_clore_purgee` | `est_emprisonne = null` n'était **jamais** persisté. Une peine purgée se « relibérait » à chaque session, et la ligne du registre du QHS restait « détenu » |
| 12 — prolongation | `detention_prolonger_soi` | les deux chemins (juge / soi-même) avaient **divergé** : la RPC posait le drapeau QHS et le registre, le client non. Un moteur partagé, `detention_prolonger_interne`, les réunit |
| 13 — sentence | `justice_rendre_sentence` | le **nom du juge** était une chaîne composée par le navigateur et inscrite telle quelle au registre. Et la peine était appliquée sans que son verdict soit lu : le registre pouvait porter « Prison 3 jours » sans aucune peine prolongée |
| 16 — vote | `election_voter` | **les deux écritures comptent**, et c'est le point le moins évident du mécanisme : le client reconstruit `cycle.votes` depuis la table, mais le dépouillement de minuit ne lit **que le blob**. Un bulletin écrit sans son blob disparaissait du décompte |

**Et le drapeau QHS n'a plus qu'un seul écrivain au moment de l'acte** :
`detention_qhs_poser_interne`. L'ensemble des fonctions qui assignent
`detention_qhs` est désormais connu, nommé et éprouvé par la migration
elle-même : le poseur, `qhs_pouvoir` (les actes du ministre),
`pa_repos_nocturne` (qui consomme `paLimite1Jour`) et
`personnages_vue_modifier` (le déclencheur de la vue, qui recopie toutes les
colonnes).

**Bancs** : `outils/bancs/banc-detention-plateau.js` (61 épreuves) et
`banc-vote-electoral.js` (39 épreuves) extraient les **vraies fonctions** des
fichiers de production par `readFile` et leur donnent un faux `sbRpc` — on
n'éprouve pas une copie. `outils/bancs/contre-epreuves-chantier5.py` réinjecte
douze régressions dans une **copie** du fichier et exige que le banc rougisse sur
l'épreuve attendue : un banc qui passerait aussi sans le correctif ne prouverait
rien.

**Deux défauts trouvés par les bancs eux-mêmes**, et corrigés :
`Number(null)` vaut 0, qui est fini — la garde « une peine sans terme est
refusée » laissait donc passer une peine de zéro jour ; et un rejet de transport
sur `election_voter` ne donnait **aucun** message à l'électeur, ni succès ni
refus, faute d'un `.catch`. Un silence n'est pas un verdict.

## 5. Le doublon du redressement fiscal — à lire, le motif se reproduira

Deux portes menaient au même acte :

- `redressement_fiscal`, depuis le panneau du gouvernement →
  `executerOrdreFiscalCible`, **réparé le 17 septembre 2026** : autorité
  `min_fin` exigée par le serveur, montant hors de portée du navigateur, débit et
  versement au Trésor dans **une** transaction, et **refus explicite** de la
  cible « citoyen » ;
- `redressement_cible`, depuis le répertoire de contacts →
  `executerOrdreContact`, **resté dans l'état que cette réparation condamnait** :
  aucun contrôle d'autorité, montant 2000 décidé par le navigateur, débit et
  versement en deux écritures clientes dont la seconde était avalée.

**Et les deux se contredisaient sur un arbitrage explicitement pendant.** Le
chemin réparé dit au joueur « le prélèvement sur la fortune d'un particulier
n'est pas en vigueur », et son commentaire précise que l'activer « serait un
choix de game design, pas un correctif : l'arbitrage reste à rendre ». L'autre
annonçait un prélèvement, le portait au journal et en notifiait la cible par
courrier.

**Ce que le prélèvement faisait réellement : rien.** La vue `personnages` masque
la colonne `arg` d'un tiers — lue `null`, ramenée à 0 — et son déclencheur
`INSTEAD OF` refuse l'écriture. Le toast annonçait donc « 0 FR prélevés », le
journal « +0 FR pour l'État », et la cible recevait un courrier lui notifiant un
redressement de 0 FR.

La porte fautive est désormais alignée sur celle qui a été arbitrée. **Zéro franc
bougeait avant, zéro franc bouge après** : ce qui change est le discours, et la
disparition d'une écriture de blob avalée sur `budgets_nationaux`. L'arbitrage
reste entier — et le jour où il sera rendu, il n'y aura plus qu'**un** endroit à
ouvrir.

> **La leçon de méthode, qui vaut au-delà de ce cas :** quand on répare un
> mécanisme, chercher ses autres portes d'entrée. Ici, `plateau-router.js`
> déclare les deux (`redressement_fiscal` et `redressement_cible`) à huit lignes
> d'intervalle, et la réparation de septembre n'en a vu qu'une. Un `grep` sur le
> nom de l'action aurait suffi.

## 6. Ce qui reste, et dans quel ordre

1. **Les chaînes 4 à 8** (argent sur deux tables) — chacune demande une RPC, pas
   un test. Les plus simples d'abord : les taux d'imposition (#8), qui n'ont
   besoin que d'un compare-and-swap, le patron existant dans ce dépôt.
2. ~~**Les chaînes 9 à 13** (dossier judiciaire)~~ — **FAIT le 9/10**, voir §4 bis.
   Le pari était juste : une porte d'ouverture et une de clôture ferment les cinq
   d'un coup, et c'était bien le meilleur rapport effort/effet de la liste. Ce que
   le pari n'avait pas vu, c'est qu'il n'y avait **pas de primitive à écrire** —
   elle existait déjà, sans appelant.
3. ~~**La chaîne 16** (le vote électoral sans aucune preuve)~~ — **FAIT le 9/10**.
4. **Les 25 `sbSetTerrainState(...).catch(() => {})`** — mécanique, mais à faire
   après les chaînes : seul, un test n'empêche pas l'incohérence entre deux
   tables.
5. **Le socle à verdict n'a toujours aucun consommateur en écriture côté
   plateau.** Les trois corrections du 9 octobre lisent des retours existants
   (`null` / `.ok`) ; aucune n'utilise `sbUpdateVerdict`. C'est cohérent — ces
   helpers ne lèvent pas et rendent déjà `null` — mais il faut le savoir : la
   couche à verdict sert aujourd'hui `api/` et `supabase.js`, pas `plateau-*`.

## Reproduire cet inventaire

Les motifs et les conventions de comptage sont en tête de ce document. Il n'y a
pas d'outil : l'inventaire a été fait à la lecture, parce que la colonne
« traitement de l'échec » demande de suivre ce que l'appelant fait du retour —
ce qu'un `grep` ne sait pas dire. Le refaire coûte une relecture des 22 fichiers
qui écrivent ; les compteurs ci-dessus permettent de vérifier qu'on n'a rien
manqué.
