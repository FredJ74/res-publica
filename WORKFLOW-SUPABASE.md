# Faire évoluer Supabase — le processus

> **À lire avant de toucher à la base.** Ce fichier est la seule description du
> processus ; les autres `README` y renvoient plutôt que de le répéter.

Jusqu'au 5 octobre 2026, le schéma n'était plus reproductible : 84 des 252
tables n'avaient leur `CREATE TABLE` nulle part, ni dans le registre Supabase ni
dans le dépôt. On ne pouvait donc pas reconstruire le jeu, et chaque évolution
creusait l'écart. Le chantier 2E a remplacé l'histoire perdue par un **état
canonique**, et ce fichier dit comment ne plus le reperdre.

## Les quatre choses, et une seule règle pour les distinguer

| | Rôle | Qui l'écrit |
|---|---|---|
| **`baseline/`** | l'**état canonique** du schéma et du contenu initial, extrait des catalogues PostgreSQL | **personne** — il est *généré* |
| **`migrations/`** | les **évolutions futures**, une par fichier, dans l'ordre | un agent, à la main |
| **`baseline/seeds/`** | le **contenu avec lequel un monde naît** | généré par `seeds.py` |
| **`historique/`** | l'**archive**, documentaire, non rejouable | personne — c'est clos |

**La règle qui les sépare : le baseline SUIT la base, il ne la précède jamais.**
On applique une migration, *puis* on réextrait le baseline. Jamais l'inverse. Un
baseline en avance sur la base est un mensonge, et un baseline en retard est une
dette silencieuse.

## Le processus, en cinq temps

### 1. Partir du baseline, en lecture

```
baseline/domaines/<domaine>/<phase>_<catégorie>.sql
```

Les fichiers `.sql` du baseline sont **générés**. Ne jamais les éditer à la
main : `verifier-baseline.py` réhache chaque définition et le verrait.

### 2. Écrire la migration

```
migrations/<AAAAMMJJHHMMSS>_<nom_en_minuscules>.sql
```

L'horodatage est celui du moment où on l'écrit, en UTC. Il donne l'ordre
d'application, et il doit être **postérieur au point de coupe du baseline**
(`baseline/CONTROLE-GLOBAL.json`, clé `releve_le`).

Une migration doit être **idempotente** : `CREATE ... IF NOT EXISTS`,
`CREATE OR REPLACE FUNCTION`, `DROP POLICY IF EXISTS` avant `CREATE POLICY`. Une
migration rejouée ne doit rien casser.

### 3. L'éprouver SANS l'appliquer

PostgreSQL sait faire du DDL transactionnel. On ouvre une transaction, on joue la
migration, on lève une exception, et tout disparaît — mais les erreurs de
syntaxe, de type et de dépendance, elles, se sont déjà manifestées :

```sql
BEGIN;
  -- la migration, telle quelle
  RAISE EXCEPTION 'banc : rien ne doit rester';
ROLLBACK;
```

Pour une bascule lourde, le banc va plus loin : monter l'ensemble dans un
**schéma jetable** et jouer les cas dessus. `historique/sql-racine/non-appliquees/`
en garde trois exemples écrits de cette façon.

> **C'est ICI, et nulle part ailleurs, qu'on fait tourner le mécanisme.** Le banc
> est annulé : il peut créer un prêt témoin, appeler la RPC quatre fois, vérifier
> que la deuxième ne prélève rien. La **migration**, elle, commite — donc elle ne
> doit prouver que du **structurel** : le corps d'une fonction contient la garde,
> l'ordre des blocs est le bon, un droit a disparu, une contrainte tient.
>
> La raison est coûteuse : `idempotence_prets_helvetia` (registre 562) a prouvé
> son effet en appelant la RPC pour de vrai depuis la migration. Cette RPC
> crédite aussi la caisse de la banque privée à chaque prélèvement — une table
> à laquelle les preuves ne pensaient pas. 1 000 FR sont restés en bêta après la
> suppression du prêt témoin. Détectés par l'empreinte des caisses, restitués
> dans la minute. **Un mécanisme touche presque toujours plus de tables que
> celles qu'on surveille.**
>
> Corollaire pratique : avant d'appliquer, prendre l'**empreinte** des tables de
> données que le mécanisme pourrait toucher, et la recomparer après. C'est ce qui
> a permis de voir l'écart tout de suite au lieu de le découvrir des semaines
> plus tard.

### 4. L'appliquer

**L'agent applique, jamais le game designer.** Fred n'exécute pas de SQL : lui
demander de lancer une migration à la main est hors processus.

L'application passe par le canal technique (MCP `apply_migration`), et **jamais
par une écriture directe** : une migration appliquée hors registre creuse
exactement le trou que ce chantier a rebouché. Le registre Supabase est la seule
trace d'application qui compte.

### 5. Réextraire le baseline, et commiter les deux ensemble

```
python3 outils/baseline/requetes.py --exports             # les 4 exports à rejouer
python3 outils/baseline/requetes.py --export export_droits
python3 outils/baseline/requetes.py --controle-global     # imprime la requête
python3 outils/baseline/rendre.py <répertoire_des_exports>
python3 outils/baseline/seeds.py  --rendre <répertoire> <résultat>
python3 outils/baseline/controler-tout.py                 # les 10 contrôles
```

**Les quatre requêtes d'extraction sont dans `requetes.py`, et il faut les
jouer telles quelles.** Elles n'y étaient pas jusqu'au 6 octobre 2026 :
l'une a dû être reconstituée, les séquences y manquaient, et le rendu a
tranquillement supprimé 102 lignes de droits de séquence — de quoi décrire une
base où plus aucun rôle client ne peut appeler `nextval()`. Aucun contrôle ne
l'a vu ; c'est la relecture du diff qui l'a attrapé. **Relire le diff du
baseline après chaque réextraction** : le nombre de lignes changées doit
s'expliquer par la migration, et rien d'autre.

La migration **et** le baseline réextrait vont dans le **même commit**. Séparés,
ils laisseraient un instant où le dépôt dit autre chose que la base.

Puis la migration **quitte `migrations/`** pour
`historique/migrations-appliquees/`. Son effet n'est plus dans le fichier, il
est dans le baseline ; la laisser là ferait rougir l'invariant 4 du garde-fou,
et il aurait raison — une migration antérieure au point de coupe est au mieux
inutile à rejouer. C'est ce qui rend `migrations/` lisible : ce qu'il contient
reste à faire.

Le détail de l'extraction en deux temps — pourquoi l'outil imprime le SQL au
lieu de l'exécuter, et les douze pièges rencontrés — est dans
`outils/baseline/README.md`.

## Où vivent les outils

| | |
|---|---|
| `outils/baseline/` | l'outillage du baseline : extraction, rendu, contrôles, reconstruction |
| `outils/generateurs/` | les 9 générateurs : 8 pour les tables miroir de `data.js`, 1 pour le module serveur `api/_referentiels-generes.js` — un miroir se **régénère**, il ne se recopie pas |
| `outils/` | les outils transverses (conversion WebP, vérifications ponctuelles) |
| `historique/patchs-ponctuels/` | 342 correctifs à usage unique, archivés — ils ne sont pas des outils |

**Aucun script technique à la racine.** 342 `patch_*.py` et `fix_*.py` y
vivaient ; ils sont archivés, et l'invariant 8 du garde-fou refuse qu'ils
reviennent. Les générateurs, eux, vivaient dans `.scratch/` alors que le projet
en dépend : un outil dont le projet dépend n'a pas sa place dans un brouillon.

## Ce qu'on ne fait plus

**Plus aucun `.sql` à la racine du dépôt.** C'est là que vivaient les 184
migrations dispersées, et c'est ce qui a rendu l'histoire illisible : des
fichiers sans ordre, sans garantie d'application, impossibles à distinguer des
brouillons. Ils sont archivés dans `historique/sql-racine/`, et
`verifier-workflow.py` refuse qu'un `.sql` réapparaisse à la racine.

**Plus de rejeu de l'histoire.** `historique/` est documentaire. Les 539 entrées
du registre et les 184 fichiers racine ne sont **pas rejouables** et ne doivent
jamais l'être : 162 des 184 dépendent d'une table qu'aucun d'eux ne crée.

**Plus de baseline édité à la main.** Une correction passe par une migration,
puis par une réextraction. Jamais par un `.sql` du baseline retouché.

## Les dix contrôles

Une seule commande les enchaîne :

```
python3 outils/baseline/controler-tout.py
```

| Outil | Ce qu'il vérifie |
|---|---|
| `verifier-workflow.py` | les **huit invariants** du processus : rien à la racine, archives intactes, migrations bien nommées, outils à leur place |
| `verifier-baseline.py` | la fidélité au catalogue, en quatre familles séparées |
| `verifier-autorite.py` | les **treize invariants** d'autorité : qui peut écrire quoi depuis un navigateur, et par quelle porte |
| `verifier-referentiels.py` | que le serveur dit la même chose que le jeu, sur ses **trois** chemins : `data.js` confronté aux ressaisies de `api/` en chargeant le vrai code, `data.js` confronté aux tables miroir par empreinte, et l'artefact serveur généré confronté à sa regénération |
| `verifier-monde-neuf.py` | ni donnée de bêta, ni vestige, dans les seeds |
| `assembler.py` | les dépendances, à vide |
| `reconstruire.py` | la grammaire réelle de PostgreSQL, et la simulation d'application |
| `verifier-classification.py` | la classification des 252 tables |
| `verifier.py communication` | non-régression du domaine pilote 2B |
| `verifier-archive-registre.py` | non-régression de l'archive 2D |

Aucun n'accède à la base. Ils sont tous rejouables hors ligne, et c'est voulu :
un contrôle qui a besoin de la production n'est pas un contrôle, c'est une
dépendance.

## Le serveur ne recopie plus les référentiels du jeu

Le chantier 4B a ajouté une seconde règle. `api/*.js` ne peut pas importer
`data.js` ni les modules `plateau-*.js` — ils n'ont pas d'`export`, et surtout
ils mêlent données et comportement : `plateau-core.js` pose deux écouteurs dès
son chargement. Les faire exécuter par le serverless serait un couplage faux.

Les constantes dont le cron a besoin sont donc **générées**, jamais ressaisies :

```
python3 outils/generateurs/generer_referentiels_serveur.py            # vérifie
python3 outils/generateurs/generer_referentiels_serveur.py --ecrire   # regénère
```

`api/_referentiels-generes.js` est un **artefact**. Une valeur corrigée là-bas
serait perdue à la prochaine génération, après avoir fait diverger le serveur du
jeu : on corrige dans la source canonique, puis on regénère. Le 10e contrôle
rejoue la génération et refuse si le fichier du disque ne correspond plus.

**Une copie serveur n'est remplacée que si son équivalence est prouvée.** Celles
qui divergent de leur canon restent écrites à la main, et la divergence est
déclarée dans `outils/generateurs/referentiels-serveur.json`. Régénérer une
copie divergente trancherait un arbitrage de game design en le faisant passer
pour de l'outillage.

## Écrire depuis le navigateur : une déclaration, pas un réflexe

Le chantier 3 a ajouté une règle au processus. Toute mutation qu'un fichier
chargé par `index.html` adresse directement à PostgREST — `sbInsert`,
`sbUpdate`, `sbDelete`, ou un `fetch` brut — doit être déclarée dans
`outils/baseline/autorite.json`, clé `surface_cliente`. Sinon
`verifier-autorite.py` refuse.

**La bonne réaction à ce refus n'est presque jamais d'ajouter la ligne.** Une
écriture cliente directe signifie que le serveur n'a pas de porte pour cette
action ; la porte manquante est le vrai sujet. Le socle en a déjà :
`mon_personnage()` dit qui parle, `exiger_acteur()` le vérifie,
`est_appel_serveur()` distingue le cron du joueur, `acteur_identifie()` exige
simplement qu'il y ait quelqu'un, et 316 fonctions `SECURITY DEFINER` font le
travail. La liste des écritures directes ne doit que **rétrécir**.

Pourquoi ce fichier vit dans `outils/` et non dans `baseline/` : il est écrit à
la main, et `baseline/` est généré. La déclaration précède la base ; le baseline
la suit. Quand une migration d'autorité attend son application, les invariants
qu'elle ferme sont listés dans `en_attente_d_application` — le contrôle les
rapporte sans échouer, et refuse qu'on y laisse un invariant déjà satisfait.

## Une tâche de minuit revendique sa journée avant d'agir

Règle ajoutée par le chantier 6, le 9 octobre 2026. Toute tâche nocturne qui
produit un effet **non idempotent** — un débit, un crédit, un `+1` sur un
compteur, un cran d'escalade — doit **revendiquer sa journée avant de l'ap­pli­quer**,
et lire le verdict de cette revendication.

**Deux formes, et il faut choisir la bonne.**

**1. L'effet peut descendre en SQL → `actes_nocturnes`.** C'est la forme forte,
celle à préférer. Une RPC par mécanisme, qui verrouille son sujet
(`SELECT … FOR UPDATE`), appelle `acte_nocturne_revendiquer(pays, mecanisme,
sujet)`, renonce si elle rend `false`, puis produit l'effet — le tout dans sa
seule transaction. Deux conditions pour que ce soit vrai :

- le mécanisme doit être **déclaré** dans `actes_nocturnes_mecanismes`, par une
  migration, avec une `note` disant ce qu'un rejeu produirait. Un nom non
  déclaré lève ;
- la revendication n'est **appelable par aucun rôle réseau** — `EXECUTE` retiré à
  `anon`, `authenticated` et `service_role`. Ne jamais le lui rendre : c'est ce
  qui interdit de revendiquer dans une requête HTTP et d'agir dans une autre.

**2. L'effet reste en JavaScript → l'écriture conditionnelle.** La garde du jour
va dans le **filtre** de l'écriture, pas seulement dans son corps :

```js
const cible = `id=eq.${id}&or=(col.is.null,col.neq.${jour})`;
const revendique = await sbUpdate(table, cible, { col: jour }).catch(() => null);
if (revendique === null) { /* panne : on ne fait rien */ }
if (!Array.isArray(revendique) || revendique.length !== 1) { /* déjà pris */ }
```

`or=(… .is.null, … .neq.jour)` et non `neq` seul : dans PostgREST, **`neq`
exclut les NULL**, donc un sujet jamais traité ne serait jamais revendiqué.

**Ce qu'on échange, et il faut l'assumer :** si la revendication aboutit et qu'un
effet échoue ensuite, l'effet du jour est perdu. C'est le bon côté — perdre une
journée de prélèvement est sans commune mesure avec la rejouer indéfiniment. Avec
la forme 1, l'échange disparaît même : une panne annule l'effet *et* la
revendication, et la journée reste à prendre.

**Ce qui ne compte pas comme une protection :** un marqueur écrit **après**
l'effet ; un marqueur dont l'échec d'écriture est avalé par un `.catch(() => {})` ;
un marqueur relu dans une requête séparée de celle qui l'écrit.

## Un courrier n'est pas l'autorité de l'acte

Autre règle du 9 octobre. L'échec d'une notification ne doit **ni** annuler une
opération métier correctement acquise, **ni** être avalé.

- En SQL, l'`INSERT` d'un courrier vit dans son propre bloc
  `BEGIN … EXCEPTION WHEN others`, qui consigne l'incident dans
  `mails_envois_systeme.echec` avec son SQLSTATE. Un bloc `EXCEPTION` ouvre une
  **sous-transaction** : l'insert est annulé, la transaction de l'appelant reste
  vivante. C'est ce qui permet aux deux moitiés de la règle d'être vraies en même
  temps.
- En JavaScript, la brique d'envoi **ne lève pas**, rend un verdict explicite, et
  signale l'échec elle-même — une fois, dans la brique, plutôt que dans chaque
  appelant.

**Et il n'y a plus qu'un seul écrivain de `public.mails`** :
`mail_systeme_poser_interne`. Deux chemins y mènent, et la différence entre eux
est le point à comprendre :

| Chemin | Qui l'emprunte | Contrôle d'expéditeur |
|---|---|---|
| `mail_systeme_envoyer` | le navigateur, le cron | identité **et** liste blanche `mails_expediteurs_systeme` |
| `mail_systeme_poser_interne` | les fonctions SQL `SECURITY DEFINER` | **aucun** |

Ce n'est pas une porte dérobée. Les identités institutionnelles des fonctions
métier — « Commissariat », « État-major », « Service de renseignement »,
« Banque Nationale » — **ne figurent pas** dans la liste blanche, et plusieurs de
ces fonctions sont appelées par un navigateur. Les router vers la porte réseau
aurait refusé leurs courriers en silence ; inscrire ces identités en « libre »
aurait donné à n'importe quel joueur le droit d'écrire « État-major ». Le moteur
n'a donc aucun contrôle d'expéditeur **parce que son appelant a déjà vérifié sa
propre autorité pour faire son acte** — et il n'a `EXECUTE` pour personne d'autre
que son propriétaire, `service_role` compris.

## Modifier une grosse fonction : patcher en place, jamais retaper

Le canal MCP refuse une migration au-delà d'environ **12 500 caractères** —
« Invalid or expired requestState ». Or `traiter_prets_helvetia_quotidien` fait
**16 039 caractères** à elle seule, et sept de ses lignes devaient changer. Un
`CREATE OR REPLACE` complet est impossible, et retaper un corps de cette taille
est une erreur en attente.

**La migration ne porte alors que le patch, pas le corps :**

```sql
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.ma_fonction(text,integer)'::regprocedure);
  v_new := replace(v_def, $ancien$<fragment exact>$ancien$,
                          $nouveau$<remplacement>$nouveau$);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique : le fragment ne correspond pas';
  END IF;
  EXECUTE v_new;
END $mig$;
```

Trois propriétés, et c'est la première qui compte :

1. **Un fragment inexact fait échouer la migration bruyamment.** Il ne corrompt
   rien, il ne passe pas en silence. C'est l'inverse d'un corps retapé, où une
   faute de frappe s'applique sans broncher.
2. **Le corps n'est jamais retranscrit**, donc jamais altéré par accident. Le
   diff de l'archive montre le patch, ce qui est exactement ce qu'un relecteur
   veut voir.
3. **`CREATE OR REPLACE` préserve les droits** — vérifié par une preuve qui
   compare l'ACL relevée avant le patch, en dur, triée.

Dix-sept `INSERT` répartis dans onze fonctions ont été routés ainsi le 9 octobre
2026, sans qu'un seul libellé de courrier bouge.

> **Et un inventaire par motif textuel doit être insensible à la casse, ou il
> mentira.** Le relevé disait dix fonctions ; il y en avait onze. La onzième
> écrivait `insert into public.mails` en minuscules, et `INSERT INTO` ne
> l'attrapait pas. Balayer avec `~*`, toujours.

## Une porte d'autorité, un moteur sans autorité

Règle d'architecture, dégagée trois fois en une journée — détention, courriers,
prolongation de peine — et c'est la même chaque fois.

**Quand deux chemins font le même acte sous deux autorités différentes, ils
partagent un MOTEUR et portent chacun leur PORTE.** Le moteur fait l'acte et n'a
aucun contrôle ; la porte vérifie qui agit et délègue. Trois raisons, dans
l'ordre de nos priorités :

1. **Architecture.** `justice_prolonger_peine` (un juge, sur un tiers) et
   `detention_prolonger_soi` (le détenu, sur lui-même) avaient *divergé* : la
   première posait le drapeau QHS et le registre, la seconde non. Deux copies
   d'une séquence divergent toujours, et le jour où elles divergent, personne ne
   le remarque.
2. **Lisibilité.** Une porte de dix lignes dit *qui a le droit*. Un moteur de
   cinquante dit *ce qui se passe*. Mélangés, ni l'un ni l'autre ne se lit.
3. **Un droit, pas une convention.** Le moteur n'est pas « à ne pas appeler
   directement » : il est **injoignable** depuis le réseau. `EXECUTE` retiré à
   `anon`, `authenticated` et `service_role`. Les portes l'atteignent parce
   qu'elles sont `SECURITY DEFINER` et s'exécutent sous son propriétaire.

**Le piège à connaître** : `exiger_poste()` rend `NULL` **sans lever** pour un
appel serveur — « le serveur traverse ». Un refus d'autorité ne s'observe donc
jamais depuis `postgres`. Pour l'éprouver, le banc doit se poser en client :

```sql
PERFORM set_config('request.jwt.claims',
  '{"sub":"<uuid>","role":"authenticated"}', true);
PERFORM set_config('role', 'authenticated', true);
```

`affaire_autorite_de()`, elle, s'appuie sur `auth.uid()` : elle est fermée
*aussi* pour un appel serveur. Les deux comportements sont légitimes, mais ils
sont **opposés** — vérifier lequel on utilise avant d'écrire la preuve.

## Ce qui reste à faire une fois

Appliquer le baseline sur un **vrai moteur PostgreSQL neuf**. Aucun n'est
joignable depuis la machine de développement — ni serveur local, ni conteneur,
ni second projet — et la production est interdite en écriture. Le script est
prêt :

```
python3 outils/baseline/reconstruire.py --ecrire monde-neuf.sql
```

C'est un verrou d'environnement, pas de baseline : il se lèvera le jour où un
projet jetable sera disponible.
