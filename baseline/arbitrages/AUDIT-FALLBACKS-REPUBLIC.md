# Chantier 4G — les replis implicites vers Républia, recensés et classés

> **8 octobre 2026.** Règle de socle appliquée : *Républia est le premier empire
> implémenté, jamais le repli implicite d'un pays absent ou inconnu.*
> Configuration ou pays absent = **fail-closed**, sauf là où une valeur par
> défaut est une règle métier démontrée.
>
> Le recensement porte sur le SQL, le navigateur, `api/`, le cron, les
> résolveurs et les générateurs. **287 sites** au départ en JavaScript, **11**
> en SQL.

---

## 1. Le fait qui réduit l'inventaire de 287 à 32

**253 des 287 sites JavaScript sont `state.country || 'republic'`** — ou sa
variante `COUNTRIES[state.country || 'republic']`. Tous sont **en aval d'une
seule ligne** : `applyCharToState` (`plateau-core.js`), qui écrivait

```js
state.country = char.country || 'republic';
```

Ces 253 sites ne *décident* rien : ils propagent ce que cette ligne a décidé.
Les remplacer mécaniquement aurait été 253 modifications pour un seul défaut —
et dans au moins un cas, un resserrement naïf aurait **ouvert** une faille (§4).

**La correction est donc à la racine, en deux endroits :**

| | Où | Quoi |
|---|---|---|
| navigateur | `applyCharToState` | un personnage sans empire déclaré n'est plus naturalisé : **l'hydratation est refusée**, bruyamment |
| base | `personnages_donnees` | un déclencheur refuse un pays vide ou absent du référentiel `villes` — **migration écrite, non appliquée** (§6) |

Après ces deux gardes, les 253 replis sont **inatteignables pour un personnage
chargé**. Ils restent en place, intacts : c'est une garde, pas un balayage.

---

## 2. Inventaire par classe

### A — repli réellement actif et dangereux → **corrigé**

| Site | Ce qu'il faisait |
|---|---|
| `plateau-core.js` `applyCharToState` | **la racine.** Un `country` absent ou illisible devenait Républia, et le personnage héritait de l'Assemblée de Républia, de ses lois d'interdiction et de son circuit fiscal |
| `supabase.js` `sbSavePlainte` | `plainte.country \|\| 'republic'` — le pays d'une plainte **est sa juridiction**, et il est gelé à la création précisément pour ne plus bouger. Une plainte sans pays était déposée devant les tribunaux de Républia |
| `api/cron-minuit.js` `archiverEvenementUrbanismeServeur` | `doc.pays \|\| 'republic'` — un dossier d'urbanisme archivé dans la commune de Républia, quel que soit le terrain. Une archive *append-only* ne se corrige pas après coup |
| `api/cron-minuit.js` `titulaireMursDuBail` | lisait `terrains_etat` avec `data.country \|\| 'republic'`. Les identifiants de bâtiment sont **partagés entre les quatre empires** : le propriétaire trouvé pouvait être un joueur de Républia, à qui le cron envoyait le courrier de loyer d'un bail étranger |
| **SQL — les 11 `DEFAULT 'republic'`** | voir §3 |
| `supabase.js` — 6 helpers d'Assemblée | `country \|\| 'republic'` à la frontière : un appel sans pays interrogeait l'Assemblée de Républia, et appliquait **ses** lois d'interdiction à un joueur d'ailleurs |

### B — repli actif mais volontaire et démontré → **rendu explicite, pas supprimé**

| Site | Pourquoi il est légitime |
|---|---|
| cron : le circuit national | Républia est le **seul** empire doté d'un circuit national. `traiterQuotidienNationalServeur('republic')` n'était pas un oubli — mais c'était un littéral là où il fallait une déclaration. Devient `EMPIRES_CIRCUIT_NATIONAL = ['republic']`, avec écrit noir sur blanc que **cette liste n'active rien par symétrie** |
| cron + `cron-assemblee` : l'Assemblée | fermée **par la donnée** chez les autres empires — aucun siège déclaré. Devient `EMPIRES_AVEC_ASSEMBLEE = ['republic']` |
| `assembleeControlerVenteLegale` : « un autre empire autorise » | §37 : l'Assemblée est propre à Républia, donc aucune loi d'interdiction n'existe ailleurs. Autoriser y est **la bonne réponse**, et c'est une règle de jeu — à ne pas confondre avec l'indétermination (§4) |

### C — repli mort, grâce à un garde-fou prouvé → **laissé intact**

**253 sites** `state.country || 'republic'`, plus les paramètres `pays` /
`country` des fonctions qui les reçoivent de `state.country`
(`plateau-effort-guerre.js`, `plateau-actions-illegales-rumeurs.js`,
`plateau-justice-economie.js`, `plateau-alimentaire.js`…).

**La preuve du garde-fou amont, mesurée en lecture seule le 8 octobre :**

- `personnages_donnees.country` est `text NOT NULL`, sans valeur par défaut ;
- **0 ligne** sans pays ; 8 lignes, toutes `republic` ;
- **0 pays hors référentiel** ;
- la vue `personnages` expose `country` **sans masquage** — le navigateur le lit
  donc toujours tel quel.

**Ce que la mesure a aussi montré, et qui manquait à la preuve :** `NOT NULL`
n'interdit **pas la chaîne vide**, et la colonne n'a **aucun CHECK**. Or les deux
fonctions de la vue — `personnages_vue_inserer` et `personnages_vue_modifier`,
seul chemin d'écriture ouvert aux clients — passent `NEW.country` **tel quel,
sans validation**. La classe C n'était donc pas encore acquise : elle l'est par
la refonte de `applyCharToState` (côté client, effective dès ce commit) et le
sera structurellement par la migration en attente.

### D — affichage ou confort, sans conséquence métier → **laissé intact**

| Site | Nature |
|---|---|
| `plateau-navigation.js` `'empire-' + (country \|\| 'republic')` | une classe CSS |
| `supabase.js` clé de cache de présence, `plateau-immobilier.js` clés de cache et identifiants de dossier | composition de clés locales |

### E — indéterminé → **nommé, pas corrigé**

| Site | Pourquoi il reste indéterminé |
|---|---|
| `supabase.js` `sbLoadPlaintes(country)` | sans pays, lit les plaintes de **tous** les empires (`select=*`). Ce n'est pas un repli vers Républia — c'est une absence de cloisonnement, qui relève de la confidentialité inter-empires et non de ce lot |
| `plateau-organisations-quetes.js` `o.country_origine \|\| o.country \|\| 'republic'` | `organisations` porte **0 ligne** : aucun cas réel à observer, et la colonne n'est pas contrainte. À reprendre quand le mécanisme de rattachement des loges existera |

---

## 3. Les onze `DEFAULT 'republic'` en SQL

**Les onze sont du domaine de l'Assemblée** — dix `assemblee_*` plus
`depute_presence`. C'est cohérent : elles datent du chantier où Républia était le
seul empire concerné, et le défaut était une commodité, pas une règle.

**Aucun appel ne s'appuie dessus aujourd'hui, et c'est vérifié :** les neuf
appels SQL internes passent tous le pays explicitement (`v_row.country`,
`v_perso.country`, `v_siege.country`, `p_country`), et les appels du cron comme
ceux de `supabase.js` passent `p_country`.

**Deux sont ouvertes aux clients, et ce sont les plus sensibles :**
`assemblee_verifier_vente` et `assemblee_peut_deposer` (anon + authenticated).
La première est le contrôle d'**interdiction commerciale** : appelée sans pays,
elle appliquait la loi de Républia à un joueur d'un autre empire.

La migration les retire **par réécriture dynamique** : chaque fonction est relue
par `pg_get_functiondef()`, son en-tête privé du défaut, et le résultat rejoué.
Recopier onze corps à la main aurait été onze occasions de les altérer. **La
signature ne change pas** — retirer un défaut ne touche ni le nom ni les types —
donc les droits `EXECUTE` sont préservés, ce que la preuve 3 vérifie plutôt que
de le supposer.

---

## 4. Le piège de l'interdiction commerciale, et pourquoi « fail-closed » n'est pas « return false »

`assembleeControlerVenteLegale` **autorise** la vente quand la loi ne s'applique
pas — ce qui est juste pour un autre empire (§37).

Resserrer naïvement `(state.country || 'republic') === 'republic'` en
`state.country === 'republic'` aurait rendu `false` sur un pays absent, donc
**autorisé la vente sans aucune vérification** : un fail-**open** sur
l'application de la loi, obtenu en croyant durcir. Le `|| 'republic'` était
accidentellement du bon côté.

**Trois états remplacent les deux, et ils sont désormais nommés :**

| `assembleeLoiPortee()` | Sens | Conséquence sur la vente |
|---|---|---|
| `'republic'` | l'Assemblée existe, ses lois s'appliquent | le serveur est interrogé |
| `'hors_assemblee'` | empire **déclaré** sans Assemblée (§37) | autorisée — **règle de jeu** |
| `'indetermine'` | on ne sait pas où l'on est | **refusée**, et le joueur le lit |

`assembleeLoiApplicable()` reste vrai pour `'republic'` **et** pour
`'indetermine'` : évaluer la loi est le sens **restrictif**, et c'est celui qu'on
veut par défaut pour une interdiction. `assembleeLoiDecidable()` est la question
que doit poser le seul chemin qui autorise.

---

## 5. Les centres multimodaux des autres empires — diagnostic complet

### Ce que le référentiel déclare vraiment

Mesuré dans `data.js`, et c'est l'inverse de ce que le code supposait :

- les capitales de **soviet** et de **khalija** déclarent elles-mêmes
  `centre-multinodal-luthecia` dans leur liste `buildings`, et chacune en
  surcharge le nom dans son `buildingContext` ;
- leurs villes secondaires déclarent `centre-multinodal-montrouge` — **la même
  pour les deux**.

### Verdict sur les trois caisses

**Elles sont légitimes, et il n'y a rien à supprimer.** Chaque empire a bien, au
référentiel, un bâtiment dont l'identifiant est `centre-multinodal-luthecia` dans
sa capitale ; sa caisse est préfixée par l'empire
(`soviet_centre-multinodal-luthecia`), donc l'argent reste territorial. Ce
n'était **pas** un repli vers les données de Républia.

Ce qui est anormal, c'est le **nom** — un bâtiment appelé « Luthécia » planté à
Novomirsk — et c'est la dette du **décor partagé entre les quatre empires**, déjà
consignée. C'est du contenu, pas un défaut de résolution.

Leur dotation d'amorçage de 200 FR date du 11 septembre 2026 à 15 h 57, le même
horodatage que toutes les autres caisses à 200 FR, et elle n'a pas bougé depuis.

### Le résolveur devient générique, et trouve un troisième défaut

`getBuildingIdCentreMultimodal` superposait deux règles codées en dur :
`ville === 'capitale'` rendait toujours l'identifiant de Luthécia, et
`if (pays && pays !== 'republic') return null` fermait les villes secondaires aux
autres empires — alors que le référentiel **leur en donne un**. Ce garde-fou était
fail-closed, mais **faux**.

Il demande désormais au référentiel : le hub de **cette** ville de **cet** empire,
dans sa liste `buildings`. Absent → `null`, et `null` est une réponse.

**Et le banc a trouvé ce que ni le code ni l'audit ne voyaient** : chez soviet,
narco et khalija, `ville_a` **et** `ville_b` déclarent le même identifiant.
Résoudre les deux donnerait **une seule caisse pour deux villes** — la fusion de
trésoreries entre villes, exactement le défaut que le lot « caisses locales » du
16 août 2026 avait corrigé pour Républia. Le résolveur **refuse** donc quand le
référentiel est ambigu pour cet empire, en nommant les villes concurrentes, et
sans rien inventer : aucun nom de bâtiment n'est fabriqué, aucune ville n'est
privilégiée.

### Résultat du banc, exécuté contre le vrai référentiel

```
republic  capitale=centre-multinodal-luthecia  ville_a=centre-multinodal-port-sainte-marie  ville_b=centre-multinodal-montrouge
soviet    capitale=centre-multinodal-luthecia  ville_a=null  ville_b=null   (ambiguïté nommée)
narco     capitale=centre-multinodal-luthecia  ville_a=null  ville_b=null   (ambiguïté nommée)
khalija   capitale=centre-multinodal-luthecia  ville_a=null  ville_b=null   (ambiguïté nommée)

pays absent -> null   pays inconnu -> null   ville inconnue -> null   zone hors ville -> null
```

### Les autres résolveurs par rôle

`getBuildingIdCommissariat`, `...Dispensaire`, `...Tribunal`, `...Mairie`
délèguent tous à `caisseTerritorialeId(categorie, ville)`, qui compose
`categorie_ville`. Ils sont **suffixés par la ville** et ne peuvent donc pas
fusionner deux villes — le défaut est confiné à la famille multimodale, seule à
utiliser des identifiants de bâtiment bruts.

---

## 6. Reliquat 4G

**Une migration en attente**, et c'est le seul reliquat :
`migrations/20261008104500_pays_declare_et_retrait_des_defauts_republic.sql`.
Écrite, grammaire validée localement par pglast, **non appliquée** — l'instance
Supabase est redevenue injoignable pendant le lot (trois échecs consécutifs, dont
deux `SELECT 1` nus en *connection timeout*). Son banc en transaction annulée n'a
**pas** pu rendre son rapport : rien n'est prouvé contre la base réelle, et rien
n'est affirmé à ce sujet.

**Elle est sans danger à laisser en attente** : les corrections JavaScript du même
lot passent déjà le pays explicitement, donc les onze défauts ne sont plus
exercés par aucun appelant. Ce sont des portes ouvertes que personne n'emprunte.

Deux points de classe E restent nommés et non corrigés (§2), parce qu'ils ne sont
pas des replis vers Républia : le non-cloisonnement de `sbLoadPlaintes` et la
table `organisations`, vide.
