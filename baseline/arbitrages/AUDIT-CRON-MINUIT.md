# Audit du cron de minuit — cartographie et découpage proposé

> **Chantier 6, audit préalable. 7 octobre 2026.**
> `api/cron-minuit.js`, 6 202 lignes, un seul endpoint. Cadence `0 23 * * *`
> (23 h UTC), `maxDuration: 120 s`. Journée canonique : `jourParisISO()`.
> Deux portes fail-closed en tête : `CRON_SECRET` puis
> `SUPABASE_SERVICE_ROLE_KEY`.
>
> **Aucune réécriture n'a été faite.** Ce document existe pour qu'un découpage
> soit possible sans perdre ce qui tient le fichier debout.

---

## Les trois invariants qu'un découpage ne doit jamais perdre

Ils ne sont écrits nulle part ailleurs, et ils sont la raison pour laquelle ce
fichier est resté monolithique.

### 1. Le registre `joursCron` est une seule ligne, réécrite sans atomicité

`batiments_etat`, id `republic_global_cron-minuit`, champ
`joursCron: { <tâche>: 'AAAA-MM-JJ' }`. Le marqueur est posé **avant** l'effet,
puis **relu** pour vérifier qu'il a bien été persisté — si non, la tâche ne
tourne pas. C'est un vrai fail-closed, et c'est le **seul** garde-fou
d'idempotence de **dix-sept** tâches.

La lecture-fusion-écriture n'est pas atomique. **Deux lots extraits qui
tourneraient en parallèle s'écraseraient leurs marqueurs** — donc double
prélèvement. Prérequis absolu à toute parallélisation : une ligne de registre par
lot, ou une RPC `cron_marquer_tache(nom, jour)` atomique.

### 2. Cinq tâches font du read-modify-write sur `terrains_etat.data`

Taxe foncière, les deux résolutions de compromis, l'instruction des permis, la
progression des chantiers et le prélèvement des prêts rechargent **toute** la
table et réécrivent la colonne `data` en `JSON.parse`/`JSON.stringify`. Deux
endpoints concurrents s'écraseraient. **Elles partent ensemble, séquentielles, ou
pas du tout.**

### 3. `ECHECS_PASSE` + HTTP 500 est le seul signal que la plateforme voit

Les cinq primitives passent par `signalerEchec`. Chaque lot extrait doit avoir
son propre entonnoir et son propre endpoint surveillé — sinon un échec devient
invisible.

---

## Ce qui est mort, et doit partir d'abord

| Objet | Preuve |
|---|---|
| `payerSoldeServeur` | corps réduit à `return;` — la solde des soldats a été supprimée le 18/09/2026, l'appel subsiste |
| `COUT_SOLDE_PAR_SOLDAT_SERVEUR` | constante du précédent, plus lue |
| branche `phase === 'vote_3e_siege'` | ~40 lignes inatteignables : `resoudreScrutinDepute` rend toujours `egalite3eSiege: null` depuis le tour unique du 12/09/2026, et **aucun** code n'affecte jamais cette phase |
| `resultats.expires` de `traiterSouvenirsAccueil` | déclaré, jamais incrémenté — le « nettoyage des souvenirs expirés » annoncé par le nom de la tâche **n'existe pas** |
| `aujourdHui` dans la même fonction | calculée, jamais utilisée |
| `DUREE_EFFORT_GUERRE_MS_SERVEUR`, `DUREE_MAX_EXCEPTION_MS_SERVEUR`, `CANDIDATURES_MIN_MS`, `cur = 'FR'` | déclarées mortes ou assignées sans lecteur |

---

## Les tâches non idempotentes — classées par ce qu'une double exécution coûte

### Aucun garde-fou du tout

**`traiterSouvenirsAccueil`** est la seule tâche du fichier hors registre **et**
sans marqueur. Chaque passe retire 5–10 % de probabilité de fuite **par
souvenir**. Deux exécutions = deux tirages. Chaque fuite insère un
`evenements_globaux` « SCANDALE » nominatif et pose `revele: true` —
irréversible. Pire : le `PATCH` est un `fetch` brut **sans contrôle de
`res.ok`**, donc la fuite peut être annoncée publiquement sans que le souvenir
soit marqué, et re-tirée la nuit suivante.

### Marqueur présent, mais son écriture est avalée

Le motif est toujours le même : l'effet est appliqué, puis le marqueur est
persisté par un `sbUpdate(...).catch(() => {})`. Si cette écriture échoue,
l'effet se reproduit la nuit suivante.

| Tâche | Ce qu'une répétition produit |
|---|---|
| **cotisations** (branche Syndicat des Dockers) | `derniereCotisationDate` avalée après un débit réel de 50 FR → **prélèvement récurrent infini**, et `resultats.renouvellements` compte des succès |
| **les deux moteurs de grève** | POP de tous les élus et Social du pays **re-débités**. Le marqueur est posé **après** l'effet — l'inverse de la doctrine appliquée par les prêts et la fiscalité |
| **compromis de vente / d'entreprise** | le crédit du prêt est appliqué, `statut = 'accorde'` n'est pas persisté → **double crédit** avec un nouveau tirage ; et si c'est l'`INSERT` dans `prets` qui échoue seul, le joueur garde l'argent **sans dette** |
| **votes de confiance** | clôture avalée → **re-dépouillement avec un nouveau tirage aléatoire**, pouvant inverser confiance et censure, après que l'événement public et les mails ont annoncé le premier verdict |
| **candidatures expirées** | un seul `.catch(() => {})` annule le marquage de **tous** les dossiers de la passe → nouveau tirage, nouveau gagnant, nouvelles sanctions POP |
| **successions** | huit écritures non atomiques, toutes en `.catch(() => null)` → bénéficiaire crédité, part de l'État non prélevée, marqueur non posé → **re-crédit** |
| **ardoise d'impayé des loyers** | le prélèvement est protégé en base, mais le branchement `expulsion_requise` est du JavaScript sans clé de journée : `jours + 1` et `montantDu + prix` **doublent** — et cette ardoise est la pièce du dossier de récupération du local |

### Protégées par le seul registre

Taxe foncière, effets de blocus, livraisons d'entrepôts, exportations du port,
arrivage de la criée, production des usines, préemptions d'État, effort de
guerre. **Aucune n'a de garde interne.** La taxe foncière est le cas le plus
lourd : une double exécution avance de deux crans d'un coup dans
avertissement → pénalité 10 % → **saisie et mise en vente par la mairie**.

---

## Dépendances temporelles — vraies, et vérifiées par rien

- **La production des usines lit le coefficient de grève sans contrôler sa
  date.** Si la tâche des grèves est sautée ou si son écriture échoue, la
  production applique le coefficient **de la veille**, silencieusement.
- **L'effort de guerre suppose que la fiscalité nationale a alimenté la caserne
  aujourd'hui.** Aucune vérification : si elle a échoué, le ravitaillement
  échoue « faute de budget », sans se distinguer d'un budget réellement vide.
- **Les candidatures expirées supposent que la cascade de nomination a tourné**,
  sinon la fenêtre de 48 h est réarmée à chaque passe : un poste sans autorité PJ
  ni PNJ **ne se pourvoit jamais**.
- **Les livraisons supposent que les transits ont été livrés**, sinon le cron
  rachète ce qui est déjà en route.
- **La taxe foncière crédite `budgets_municipaux`, les livraisons le débitent.**
  L'ordre actuel garnit la caisse avant de la ponctionner. L'inverser assèche les
  entrepôts.

---

## Portée par empire

**Déjà sur les quatre empires** : préemptions d'État, créances Helvetia, paye de
la douane, paye de la police, et le Journal du jour (via `PAYS_JEU`).

**Multi-empire par les données** (table lue sans filtre, `row.country` utilisé) :
taxe foncière, compromis, permis, chantiers, blocus, prêts, loyers, détentions,
mails, successions, fret, licences, cotisations, grèves, votes de confiance,
placements. Avec deux biais : le titulaire des murs d'un bail **retombe sur
`'republic'`** si `data.country` est absent, et les chantiers d'un autre empire ne
s'approvisionnent jamais (la table des entrepôts ne connaît que Républia).

**Républia uniquement, en dur** : les trois RPC de l'Assemblée, la cascade de
nomination, les candidatures expirées, les souvenirs d'accueil, le quotidien
national, les livraisons d'entrepôts, les exportations du port, la criée, les
usines, les achats inter-usines, l'effort de guerre, les conflits d'emploi BNE,
les investissements legacy.

> **Conséquence pour le découpage** : toute l'économie réelle (entrepôts, usines,
> port, criée, effort de guerre, fiscalité nationale) est **mono-empire**. Un lot
> « économie » reste mono-empire ; un lot « institutions » aussi. Seuls les lots
> financiers, de service et le Journal sont déjà à quatre empires.

---

## Règles métier recopiées

### Identiques au caractère près — duplication pure

Dépouillement d'un scrutin, décompte des voix avec tracts et fraudes,
législatives à un tour, départage des candidats, effets des tracts, **calendrier
du dimanche** (le commentaire le déclare « COPIE IDENTIQUE »), construction d'un
cycle, échéance du régime d'exception, paliers de progression financée, taux
horaire de chantier, fraction de travail, fraction de matériaux, panier de
matériaux du jour, seuil des deux tiers et verrou du plan, capacité d'entrepôt
(miroir d'une **fonction SQL**), répartition au plus fort reste.

> Trois commentaires du fichier disent textuellement : « AUCUN TEST NE LE VERIFIE
> AUJOURD'HUI — constaté le 6 octobre 2026 : le test annoncé n'existe nulle part
> dans le dépôt. » **Rien ne détecterait une divergence.**

### Les deux versions ne calculent PAS la même chose

1. **La réserve stratégique militaire est sans effet sur les chantiers.** Le
   client calcule `dispo = présent − réserve` ; le serveur ignore la réserve, et
   le site d'appel ne la passe pas. Or la progression quotidienne des chantiers
   est **exclusivement serveur**. Second écart : le client honore le prix
   réellement pratiqué par l'entrepôt, le serveur impose le prix de base.
2. **`getPrixRessource` existe en trois versions**, dont une fausse :
   `api/_journal-collecte.js` a sa propre table dont `prixBase` contient en
   réalité `prixAchatFournisseur` — **la moitié de la vraie valeur, sur toutes
   les entrées**. Le Journal publie donc des prix deux fois trop bas. Divergence
   déjà déclarée dans `outils/baseline/referentiels.json`.
3. **Le prix d'achat diffère selon le canal** : le cron achète au prix dynamique,
   la RPC `entrepot_commander` au `prix_base` de la table SQL. Troisième copie du
   référentiel des ressources, dans un support différent.
4. **Les recettes fiscales du serveur sont un miroir figé d'une valeur mutée en
   RAM** côté client et jamais persistée.
5. **La règle de crédit du compromis n'existe QUE dans le cron** :
   `risque = arg < montant × 0,10`, puis `accordé = !risque || random() < 0,5`.
   Ni client, ni SQL.
6. **Le barème de la taxe foncière n'existe que dans le cron**, et il est voisin
   mais distinct de celui des prêts bancaires — deux barèmes de contentieux non
   factorisés dans le même fichier.

---

## Découpage proposé, du plus sûr au plus risqué

| Lot | Contenu | Pourquoi c'est sûr | Ce qu'il faut réparer AVANT |
|---|---|---|---|
| **1 — Ménage** | suppression du code mort listé plus haut | rien n'est extrait | décider du sort du libellé client de `vote_3e_siege` |
| **2 — Maintenance** | purge des mails, libération des détentions, souvenirs d'accueil, RDV notariaux manqués, blocus (lever **puis** effets), conflits BNE, fret maritime | aucune ne lit le résultat d'une autre, aucune n'écrit dans une table lue par une autre | **donner un garde-fou aux souvenirs d'accueil** et contrôler `res.ok` sur ses deux `fetch` bruts |
| **3 — Tout-RPC** | renseignement, militaire, douane, police, transits, détentions PNJ | zéro métier en JavaScript, idempotence en base | conserver deux ordres imposés ; faire remonter `rpc_indisponible` dans `ECHECS_PASSE` ; **les transits doivent rester avant le lot 6** |
| **4 — Finance** | Helvetia, placements nationaux, investissements legacy, créances | tout en RPC, idempotence par `statut` | pousser la formule de rendement dans la RPC, qui est déjà l'autorité |
| **5 — Élections et postes** | Assemblée, boucle électorale, cascade de nomination, candidatures, votes de confiance | bloc auto-contenu ; la chaîne de dépendances est **interne** au lot | **réparer les deux `.catch(() => {})` des votes de confiance** ; poser un test d'égalité sur les 170 lignes de calendrier **avant** de les déplacer |
| **6 — Économie Républia** | livraisons, exportations, criée, usines, achats inter-usines (~550 lignes) | mono-empire, mono-table, ordre interne déjà documenté | **contrôler la date du coefficient de grève**, ou garder les grèves dans le lot ; instrumenter les dix `.catch(() => {})` sur le stock |
| **7 — Immobilier** | taxe foncière, compromis, permis, chantiers, prêts (~340 lignes de formules) | — | **extraire en bloc, jamais tâche par tâche** (invariant 2) ; réparer les doubles crédits de prêt et la matière créée/détruite ; poser les tests d'égalité que le code réclame lui-même ; trancher la réserve stratégique |
| **8 — Social et national** | loyers, quotidien national, grèves, préemptions, successions, cotisations, licences | — | réparer le marquage des cotisations, l'ordre marqueur/effet des grèves, le découpage des successions ; pousser l'ardoise des loyers dans la RPC |
| **9 — Effort de guerre et Journal** | — | — | l'effort de guerre a **trois** dépendances temporelles vérifiées par rien : un lot dédié doit contrôler les marqueurs du jour et refuser de tourner sinon |

Le bénéfice le plus immédiat du découpage n'est pas la lisibilité : c'est la
libération de `maxDuration: 120 s`, qui couvre aujourd'hui les soixante lots
militaires **et** le Journal **et** tout le reste.
