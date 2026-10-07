# Chantier 5 — l'échec silencieux de la couche d'accès

> **Audit statique du 8 octobre 2026.** Aucun accès à Supabase. Tous les chiffres
> viennent du dépôt, par extraction, et sont donc reproductibles.
>
> Ce document ne propose aucune réécriture de masse. Son objet est inverse :
> montrer que la cible n'est pas 1 335 sites mais **dix-neuf interventions**, et
> que les 796 autres peuvent attendre indéfiniment sans que personne perde un
> franc.

---

## 1. La mesure, et le recadrage qu'elle impose

**1 335** avaleurs d'erreur dans le dépôt (`.catch(() => {})` : 616 ;
`.catch(() => null)` : 395 ; `.catch(() => [])` : 204 ; `catch {}` : 88 ;
`.catch(() => ({}))` : 16 ; `undefined` : 8 ; `false` : 8).

Mais **813 seulement** sont accolés à un appel de la couche `sb*` — dont 708 côté
navigateur et 105 dans `api/`. Les ~520 autres portent sur `JSON.parse`,
`localStorage`, l'audio, le DOM, des `await import()` : ce ne sont pas des
pannes de base de données et ils ne relèvent pas de ce chantier.

Détail utile pour l'outillage : la variante `.catch(e => null)` avec paramètre
nommé n'existe **nulle part**. La convention du dépôt est strictement `() =>`,
donc tout balayage mécanique par expression régulière est fiable.

Le commentaire de `supabase.js` estimait « les ~470 sites en
`.catch(() => null)` ». La mesure exacte aujourd'hui est **442** pour les deux
variantes `null` + `[]` sur la couche `sb*` : l'estimation documentée tenait.

---

## 2. Six familles, et une seule qui coûte de l'argent

### F4 — Effet partiel : une séquence d'écritures sans frontière transactionnelle

**La seule famille qui peut créer ou détruire de l'argent.** **19 paires**
d'écritures `sb*` séparées de huit lignes ou moins dans le même corps de
fonction (9 dans `plateau-justice-economie.js`, 5 dans `plateau-politique.js`,
2 dans `plateau-organisations-quetes.js`, 2 dans `forum.js`, 1 dans
`plateau-communication.js`).

Les cas chiffrés :

- **achat d'un lot de fret** — la bascule `statut: 'vendue'` est confirmée, puis
  trois écritures avalées suivent (crédit du vendeur, remise à zéro de la
  caisse, sauvegarde de l'acheteur). Le lot est vendu quoi qu'il arrive ;
- **`distribuerBudgetMunicipalVersBatiments`** — N crédits de caisses vérifiés
  et fail-closed, puis **une seule** écriture du blob municipal en
  `.catch(() => {})`. Si celle-là mord, l'argent est crédité aux bâtiments
  **et** reste dans la caisse municipale : création monétaire nette, répétée
  chaque nuit ;
- **couvre-feu** — lecture du blob `budgets_nationaux`, mutation locale,
  réécriture du blob entier sans verrou, retour jamais lu, toast de succès
  inconditionnel. Quatre sites du même motif.

Le dépôt a déjà réparé ce motif à onze endroits et l'a consigné à chaque fois :
la doctrine existe, elle n'a simplement pas fini son balayage.

### F2 — Écriture non confirmée : un succès annoncé sans preuve

**81 sites** où une écriture est suivie d'un `.catch` à valeur de repli, et
**201** en pur tire-et-oublie. Le plus massif : `sbSavePersonnage(...).catch(...)`
sur **92 sites**.

Le défaut le plus grave n'est pas dans les appelants mais dans **trois
primitives serveur** qui mentent :

- `api/_journal-generation.js` — `sbInsert` et `sbUpdate` rendent
  `{ ok: true }` dès que la réponse HTTP est 2xx. Or un `PATCH` qui ne touche
  **aucune ligne** rend 200 et un corps vide : le helper annonce un succès pour
  une écriture qui n'a rien écrit ;
- `api/cron-minuit.js` — `sbUpdate` rend `res.json()` et aucun appelant ne lit
  `.length`.

Corriger ces trois primitives corrige des centaines d'appelants en aval sans en
toucher un seul. C'est le meilleur rapport du chantier.

Le précédent de la bonne forme existe : un seul site du dépôt lit `maj.length`
pour refuser d'affirmer un succès sans ligne touchée.

### F3 — Refus métier confondu avec panne

**154 gardes** de la forme `if (!r || r.ok !== true)`. `sbRpc` rend `null` pour
toute panne, la garde ne distingue pas ce `null` d'un `{ ok:false, raison }`
métier, et le message affiché est celui du refus d'autorité.

Deux conséquences visibles pour un joueur :

- hors ligne, le Ministre de l'Intérieur en exercice lit **« Réservé au Ministre
  de l'Intérieur en exercice »** ;
- quand la lecture échoue, l'écran de fret affirme **« Ce lot vient d'être acheté
  par quelqu'un d'autre »** — une affirmation factuellement fausse sur un autre
  joueur.

### F1 — Lecture avalée affichée comme « vide »

**442 sites.** La plus nombreuse ; ne détruit rien, mais fait prendre des
décisions sur une liste fausse : « Aucune proposition en attente », « Aucun
ambassadeur », port vide, journal généré sur des sources manquantes.

Le dépôt a déjà nommé ce défaut **et écrit son antidote** —
`sbLoadForumTopicsVerdict`, né de « Le forum a affiché "Aucun sujet. Soyez le
premier à en créer un !" pendant une indisponibilité de Supabase ».

### F5 — Identifiant non vérifié

**58 sites** fabriquent un id client en `'préfixe-' + Date.now()` et n'en
relisent jamais la représentation renvoyée.

### F6 — `ReferenceError` synchrone, que le `.catch` accolé ne peut pas intercepter

Famille imposée par les faits : **une fonction absente ne crée aucune promesse**,
donc le `.catch` accolé ne s'exécute jamais. Deux sinistres documentés dans le
dépôt, tous deux dans `api/cron-minuit.js` :

- `sbUpdatePret` n'existait que dans `supabase.js` et était appelée à huit
  endroits du cron → **aucune mensualité prélevée depuis la mise en service**,
  sur de l'argent réellement crédité aux emprunteurs ;
- `sbGetBatimentEtat` / `sbSetBatimentEtat` → **aucune livraison d'entrepôt,
  caisse jamais alimentée**.

Les ~37 gardes `typeof sbX === 'function' ? ... : null` du navigateur sont le
symptôme défensif du même problème.

---

## 3. Ce que `sbRpc` écrase

Le corps entier tient en trois lignes : `sbTransportRpc` produit une enveloppe à
cinq champs (`etat`, `raison`, `http`, `code`, `envoyee`), et `sbRpc` en garde
**zéro**, aplatissant **quatre états en un seul `null`** :

| État perdu | Ce que l'appelant ne peut plus savoir |
|---|---|
| `envoyee: false` | **La requête n'est jamais partie.** Le seul cas où l'on peut affirmer au joueur que rien n'a eu lieu |
| HTTP 401 | Le serveur a refusé l'**identité**, pas la règle du jeu : il faut se reconnecter |
| `http` + `code` | RPC absente (404), RLS (403), colonne inconnue (400) — un bug de déploiement, pas un refus de jeu |
| `reseau` | **Indécidable** : l'écriture a pu aboutir. Il est interdit de dire « rien n'a été modifié » |

Les deux distinctions qui coûtent le plus cher tombent du même côté :
`envoyee: false` (on peut rassurer) et `reseau` (on ne peut rien affirmer)
deviennent le même `null`.

**Volumétrie : 310 appels `sbRpc(` contre 40 `sbRpcVerdict(` et 4
`sbTransportRpc(`** — 87,6 % du trafic RPC sur la porte aveugle, pour 278 RPC
distinctes. Côté REST : **751 appels** aux quatre primitives contre **10** aux
variantes verdict.

**Le fait qui commande tout le découpage : 167 des 310 appels `sbRpc` — 54 % —
sont dans `supabase.js` lui-même**, à l'intérieur de ses helpers métier. Ce ne
sont pas 310 chirurgies métier mais **167 appels d'un seul fichier**, plus 143
appels directs.

---

## 4. Les neuf fonctions serverless, et le module de transport qui n'existe pas

Les neuf handlers Vercel sont `assemblee-seblex`, `chat`, `cron-assemblee`,
`cron-minuit`, `journal-generer`, `journal-interview`, `redaction`,
`renseignements`, `upload-org-avatar`.

**Il n'existe aucun module de transport partagé dans `api/`.** Aucun
`api/_supabase.js`, aucun équivalent, aucun import croisé de transport.
Conséquences mesurées :

- **dix copies de la configuration** : huit fichiers redéfinissent chacun leur
  `SUPABASE_URL`, deux la reconstruisent dans le corps d'une fonction — dont une
  avec l'URL **et la clé anon en littéral non surchargeable** ;
- **quatre implémentations divergentes de `sbGet`**, même nom, trois sémantiques
  d'échec (`null`, `null`, `null`, `[]`) ;
- `api/cron-minuit.js` porte **son propre jeu de onze helpers**, et le dit :
  « Dupliqué de supabase.js » apparaît quatre fois dans ses commentaires ;
- `api/renseignements.js` fait **dix-huit appels `rest/v1` bruts** sans même
  factoriser localement.

C'est la cause racine de F6 : la duplication manuelle laisse des trous qui ne se
signalent pas.

---

## 5. La brique générique minimale — une fonction, et une copie de fichier

Tout est déjà là. Il manque **un adaptateur de six lignes** et **un fichier**.

### Brique A — un canal de remontée, sans toucher un seul des 813 sites

```js
let RP_DERNIER_ECHEC = null;   // { fn, etat, raison, http, code, envoyee, t }
function sbRpcDegrade(env, fn) {
  if (env.etat !== 'ok') RP_DERNIER_ECHEC = { fn, ...env, t: Date.now() };
  return env.etat === 'ok' ? env.donnees : null;
}
```

Branchée dans `sbRpc`, et symétriquement dans `sbRelancerSiReseau` qui est déjà
le point de passage unique des quatre primitives REST.

Ce qu'elle achète :

1. **le contrat historique est préservé à la lettre** — `null` reste `null`, et
   les 1 294 `if (!rows)` du jeu ne changent pas de sens. C'est la condition
   explicitement posée par `supabase.js` lui-même ;
2. la migration devient **additive** : on ne retire rien, on ajoute une question
   qu'un appelant **peut** poser, à son rythme, un par un ;
3. **F1 se traite par l'appelant seul** : `if (!rows) { const e = sbDernierEchec();
   afficher(e ? 'Je n'ai pas pu lire' : 'Aucun résultat'); }`. C'est ce que fait
   `sbLoadForumTopicsVerdict` pour un seul chemin — disponible pour les 442
   autres sans écrire 442 helpers ;
4. **F3 se ferme mécaniquement** : les 154 gardes peuvent consulter `envoyee`
   avant de choisir leur phrase ;
5. elle donne gratuitement le **compteur de régression** qui manque à ce
   chantier : un seul endroit sait combien d'échecs ont été avalés.

**Ce qu'elle ne fait pas, et ne doit pas faire : résoudre F4.** Un effet partiel
ne se répare pas côté navigateur, il se répare par une écriture atomique — et le
dépôt le sait déjà (« exige un compare-and-swap serveur »). La brique sert à
rendre les F4 restants **visibles** pour les prioriser, pas à les corriger.

### Brique B — `api/_supabase.js`, extrait de l'existant

Zéro invention : on copie `sbTransportRest` / `sbTransportRpc` en version Node
(clé de service au lieu du jeton joueur), on exporte les quatre primitives et
leurs quatre variantes verdict. Cela supprime d'un coup les dix copies de
configuration, les quatre sémantiques divergentes de `sbGet`, et **la famille F6
entière** — un helper absent devient une erreur d'import au déploiement au lieu
d'une `ReferenceError` muette.

---

## 6. Ordre de bataille

| Étape | Cible | Volume | Nature |
|---|---|---|---|
| 0 | Brique A + Brique B | 2 ajouts | additif, aucun site modifié |
| 1 | **F4 argent** : les 5 blobs budgétaires + les 9 paires de `plateau-justice-economie.js` | **14 sites** | demande une RPC par séquence |
| 2 | **F2 serveur** : les 3 primitives qui annoncent un succès sans ligne touchée | **3 primitives** | corrige des centaines d'appelants en aval |
| 3 | **F3** : les 154 gardes, en commençant par les 21 qui portent sur de l'argent | 154 sites | mécanique, une ligne par site |
| 4 | **F1** : les 442 lectures, écran par écran | 442 sites | mécanique, aucune urgence |

**Les étapes 0 à 2 représentent dix-neuf interventions et couvrent l'intégralité
de ce qui peut créer ou détruire de l'argent.** Les 796 sites restants ne
trompent que l'affichage.

---

## 7. Aucune décision de game design dans ce chantier

Rien ici ne touche à une règle du jeu : il s'agit uniquement de dire la vérité
sur ce qui a eu lieu. Les seuls arbitrages sont techniques et je les ai pris :
le contrat `null` est préservé, la migration est additive, et F4 passe par le
serveur.
