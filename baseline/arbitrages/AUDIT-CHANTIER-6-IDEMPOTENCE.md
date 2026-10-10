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
> - la **grève générale** prétendait en commentaire suivre « la même doctrine que
>   la grève ordinaire » : c'était faux depuis le correctif du 7 octobre, qui
>   n'avait touché que la grève ordinaire. Son marqueur était écrit en dernier,
>   dans un `.catch(() => {})`. **Corrigé le 9 octobre.**
>
> **SIX MÉCANIQUES SONT FERMÉES DEPUIS, PAR TROIS PATRONS — et le troisième dit
> quand ne PAS utiliser les deux premiers.**
>
> **Patron 1, la revendication par compare-and-swap**, quand l'effet vit en
> JavaScript : la garde du jour vit dans le *filtre* de l'écriture et son verdict
> est **lu** — une ligne touchée = journée acquise, zéro ligne = déjà prise,
> panne = on ne fait rien. Deux invocations simultanées ne peuvent pas prendre la
> même journée, ce qu'un marqueur relu dans une requête séparée ne garantit pas.
> Appliqué à la **grève générale** et aux **mensualités de prêts** (famille 9).
>
> **Patron 2, la brique `actes_nocturnes`**, quand l'effet peut descendre en SQL,
> et c'est le meilleur : `actes_nocturnes(pays, mecanisme, sujet, jour)` en clé
> primaire, et une revendication **qu'aucun rôle réseau ne peut appeler** —
> `EXECUTE` retiré à `anon`, `authenticated` **et** `service_role`. Revendiquer
> une journée hors de la transaction qui porte l'effet devient *structurellement
> impossible*. Appliqué aux **préemptions** (famille 6). L'**ardoise des loyers**
> (famille 4), elle, est descendue dans sa RPC existante, qui est atomique par
> nature.
>
> **Patron 3, ne rien forcer** : les compromis sont déjà sûrs par transition
> d'état, et un transfert au QHS n'a pas à être idempotent — c'est une action de
> jeu répétable. Voir §1 bis : la brique protège ce qu'une *journée* ne doit
> produire qu'une fois, pas ce qu'un *joueur* a le droit de refaire.
>
> Sept bancs les tiennent, chacun avec sa contre-épreuve contre la version
> précédente : `banc-greve-generale.js` (20 cas), `banc-prets-bancaires.js`
> (25 cas), `banc-preemptions.js` (20 + 3 cas), `banc-candidatures-nocturnes.js`
> (32 cas, 21 tombent sans le correctif), `banc-compromis-nocturnes.js` (34 cas,
> 23 tombent sans le correctif), les huit preuves en transaction annulée de la
> brique et de son client, les cinq de l'ardoise des loyers, les sept du tirage
> des candidatures et les douze du compromis.

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

> # CHANTIER 6 — CLOS LE 10 OCTOBRE 2026
>
> **LES DIX FAMILLES DU GROUPE A SONT FERMÉES.** Six le 9 octobre (candidatures,
> compromis, ardoise des loyers, préemptions d'État, mensualités de prêts — et le
> vote électoral, hors de cette table), cinq le 10 (taxe foncière, votes de
> confiance, successions, calendrier électoral, cotisations d'organisation).
>
> **ET LES TROIS RELIQUATS DE §4 ET §5 SONT FERMÉS LE MÊME JOUR.**
>
> 1. **Souvenirs d'accueil** (registre 600) — `jour_tirage` est désormais la
>    frontière exacte que §4 réclamait : « la frontière devrait être LE SOUVENIR
>    […] pas la passe ». `souvenir_accueil_tirer` tire, marque et annonce dans
>    une transaction, sous verrou de ligne, avec un compare-and-swap sur `revele`.
>    L'épreuve que §5 décrivait comme **rouge** — « deux appels en ignorant le
>    registre → même nombre de lignes SCANDALE » — est **verte** : vingt rejeux
>    du même jour ne tirent rien et n'annoncent rien.
> 2. **`UNIQUE` sur `compromis_historique`** (registre 601) — sur
>    (pays, bien, **résultat**, journée de Paris). `résultat` entre dans la clé
>    parce qu'un bien peut légitimement produire deux actes distincts le même
>    jour ; un rejeu, lui, reproduit le même résultat.
> 3. **`UNIQUE` sur la chronique électorale** (registre 601) — sur la clé
>    **logique** (pays, ville, scrutin), et non sur la clé technique : la clé
>    primaire protégeait déjà un rejeu à l'identique, mais rien n'empêchait une
>    seconde proclamation du même scrutin sous un autre identifiant.
>
> **UN DÉFAUT DE PLUS A ÉTÉ TROUVÉ EN POSANT CES CONTRAINTES** (registre 602), et
> aucun des deux inventaires ne le nommait : `nettoyerAchatsDirectsManques` est le
> **second écrivain** de `compromis_historique`, avec un `Date.now()` dans son
> identifiant et ses deux écritures avalées. C'est exactement le défaut que la
> migration 575 avait fermé sur l'autre écrivain, non propagé jusqu'ici.
> `achat_direct_manque_resoudre` le ferme.
>
> **§2 (groupe B) dit « rien à faire » et §6 dit « aucune décision de game
> design ».** Il ne subsiste donc aucun défaut connu relevant du périmètre de ce
> chantier.

**Le défaut, identique partout et sans rapport avec le métier : l'effet et sa
preuve d'exécution sont dans deux requêtes HTTP distinctes. La fenêtre entre les
deux est un double débit en attente.**

Classées par **coût d'un rejeu**, ce qui est l'ordre d'attaque :

| # | Famille | Ce qu'un rejeu produit |
|---|---|---|
| 1 | ~~**Candidatures aux postes nommés**~~ **FERMÉ le 9 octobre 2026** | Le constat était juste jusqu'au dernier mot : les marqueurs `dossier.traitee` étaient posés en mémoire et persistés **une seule fois pour toute la passe**, et le rejeu retirait au hasard → autre gagnant, POP **re**divisée par deux. **Corrigé par la migration `candidature_poste_tirage_appliquer` + `api/cron-minuit.js`, dans le même commit.** Le tirage est descendu **dans** la transaction, revendiquée par `acte_nocturne_revendiquer('candidature_poste_tirage', '<poste>|<ville>')` : un rejeu n'atteint plus le `ORDER BY random()`. Et le drapeau est désormais persisté **dossier par dossier**. Un détail d'ordre compte : le poste déjà tenu par un joueur est vérifié **avant** la revendication — ce n'est pas « déjà fait aujourd'hui », c'est « il n'y a rien à faire », donc la journée reste ouverte. Banc `banc-candidatures-nocturnes.js`, 32 cas ; contre-épreuve : **21 tombent** sur la version précédente |
| 2 | ~~**Compromis de vente / d'entreprise**~~ **FERMÉ le 9 octobre 2026** | Les trois scénarios étaient tous atteignables, et ils sont fermés par la migration `compromis_expire_resoudre` + `api/cron-minuit.js`. **Une seule fonction pour les deux familles** : les deux passes JavaScript ne différaient que par la table, l'encodage du blob (`terrains_etat.data` est du texte portant du JSON, `entreprises.data` est du jsonb natif), la clause « permis du maire » propre au terrain et la source du pays — le reste était deux fois le même code. Les deux identifiants deviennent **datés** (`compromis-<bien>-<jour>`, `pret-<type>-<bien>-<jour>`) avec `ON CONFLICT DO NOTHING` : une horloge produisait un identifiant neuf à chaque rejeu, une date n'en produit qu'un par jour. **La brique `actes_nocturnes` n'est volontairement PAS utilisée ici** — voir §1 bis. Banc en transaction annulée : 12 épreuves ; banc `banc-compromis-nocturnes.js`, 34 cas, dont **23 tombent** sur la version précédente |
| 3 | ~~**Taxe foncière**~~ **FERMÉ le 10 octobre 2026** | Le constat était juste au mot près. `taxe_fonciere_prelever` (registre 587) revendique un acte nocturne par (pays, terrain, jour) **puis** fait tout dans une transaction. Ici la brique est le bon verrou : une journée ne prélève qu'une fois, et un terrain n'est pas un acte qu'un joueur refait. 29 épreuves de banc, dont 25 tombent sur la version précédente. Constat d'origine : **aucun marqueur par terrain**, registre seul. Une double exécution avance de deux crans dans avertissement → pénalité 10 % → **saisie municipale** |
| 4 | ~~**Ardoise d'impayé des loyers**~~ **FERMÉ le 9 octobre 2026** | Le constat était juste : la branche `expulsion_requise` était la seule sortie à effet à ne pas poser `jourPaiement`, et la dette doublait à chaque passe. **Corrigé par la migration 20261009005012 + `api/cron-minuit.js`, dans le même commit.** Et le correctif a appris quelque chose que l'audit n'avait pas vu : poser le marqueur **n'aurait pas suffi**, parce que l'appelant réécrivait le blob entier depuis une lecture antérieure à la RPC et l'aurait effacé dans la foulée. Le calcul de l'ardoise est donc **descendu dans la RPC**, où revendication et effet sont atomiques |
| 5 | ~~**Votes de confiance**~~ **FERMÉ le 10 octobre 2026** | Le constat était juste. `vote_confiance_resoudre` (registre 588) tire le hasard **DANS** la transaction qui en porte les conséquences, et refuse ce qui n'est pas échu ou déjà résolu. **Pas d'acte nocturne** : la transition `en_cours` → `termine` est déjà le verrou juste, et la brique y serait un second verrou pour le même travail. Constat d'origine : le dépouillement **tire au sort** les sièges PNJ ; la clôture `statut = 'termine'` est avalée. Si elle mord après que l'événement public et le mail au Premier ministre ont annoncé le verdict, le rejeu **re-tire** : le même vote passe de confiance à censure, **publiquement, deux fois** |
| 6 | ~~**Remboursement des préemptions d'État**~~ **FERMÉ le 9 octobre 2026** | Le constat était juste, et c'était bien le pire des sept. **Corrigé par les migrations 20261009093112 (la brique) + 20261009130649 (la RPC) et `api/cron-minuit.js`, dans le même commit.** Les quatre allers-retours deviennent une transaction unique, ouverte par une revendication d'acte nocturne ; la fonction JavaScript n'écrit plus rien elle-même. **La preuve qui compte** : au banc, une exception levée après l'acquisition ramène la caisse, la dette *et* la ligne de revendication — un état économique partiel n'est plus représentable |
| 7 | ~~**Successions**~~ **FERMÉ le 10 octobre 2026** | Le constat était juste, §3 compris. `succession_regler` (registre 593) met chaque mutation et son marqueur dans la même transaction — et **préserve l'indépendance des dispositions**, qui était la valeur de l'architecture v4, par une **sous-transaction par étape** : un terrain introuvable annule sa seule étape et laisse les autres acquises. Une transaction unique tout ou rien aurait détruit cette propriété. 40 épreuves vertes en base. Constat d'origine : fenêtre étroite, montant élevé. Le code est par ailleurs bien construit (voir §3) |
| 8 | ~~**Calendrier électoral**~~ **FERMÉ le 10 octobre 2026** | Le constat était juste sur le mécanisme et **faux sur une affirmation** : le dépouillement n'est PAS aléatoire — `resoudreScrutinSimple` et `resoudreScrutinDepute` ne contiennent aucun `Math.random`, vérifié fonction par fonction, et l'égalité est départagée par l'ancienneté. Ce qu'un rejeu dupliquait, c'était l'**annonce**. `election_resultats_consigner` (registre 589) fait de `resultatsTraites` un compare-and-swap **dans le filtre** de l'UPDATE et pose les deux annonces dans la même transaction. Constat d'origine : `cycle.resultatsTraites` est un champ de blob écrit **en dernier**, sans vérification, après que `evenements_globaux` et `chronique_nationale` ont été insérés. Un échec → **re-dépouillement**, et `resoudreScrutinSimple` est aléatoire : deux proclamations contradictoires |
| 9 | ~~**Mensualités de prêts**~~ **FERMÉ le 9 octobre 2026** | Le constat était juste : marqueur sur une vraie colonne, posé avant l'effet, mais en `.catch(() => {})` — l'échec de pose était avalé et le débit partait quand même. **Les deux chemins sont désormais sûrs** : le chemin Helvetia par la migration 20261008235521 (marqueur dans la transaction de la RPC), le chemin *legacy* par une **revendication conditionnelle** dont le verdict est lu — garde dans le filtre, donc compare-and-swap. Banc `banc-prets-bancaires.js`, 25 cas, dont la preuve qui compte : **aucun `PATCH` sur `personnages`** quand la revendication n'aboutit pas |
| 10 | ~~**Cotisations d'organisation**~~ **FERMÉ le 10 octobre 2026** | `cotisation_renouveler` (registres 590-592) verrouille l'organisation et la fiche, puis débite, marque et crédite **ensemble, ou rien**. Tout l'échafaudage qui bornait la perte — instantané de la liste, `persistanceRompue` — disparaît avec sa cause. **Pas d'acte nocturne** : le marqueur métier était déjà le verrou d'idempotence. Deux faits ont corrigé deux hypothèses en route : `pg_get_function_identity_arguments` rend les NOMS des paramètres, et `clubs_sportifs_regles` est un doublon sans générateur — la porte lit `clubs_football`. Constat d'origine : réparé partiellement le 7 octobre (persisté après **chaque** membre). Le code reconnaît lui-même que ce n'est pas la réparation complète : « Débiter un personnage et marquer son adhésion sont deux écritures sur deux tables » |

### 1 bis. Quand la brique `actes_nocturnes` ne doit PAS être utilisée

**La brique empêche le rejeu d'une TÂCHE DE NUIT. Elle n'est pas un vernis
d'idempotence à passer partout.** Deux cas rencontrés le 9 octobre le montrent, et
ils tirent dans des directions opposées :

- **Les compromis n'en ont pas besoin, et elle leur nuirait.** Le rejeu y est déjà
  impossible *par transition d'état* : le drapeau `compromis` disparaît du blob
  dans la même transaction que ses conséquences. Ajouter une revendication par jour
  empêcherait en plus de résoudre deux compromis du **même bien** à deux jours
  différents — une règle de jeu inventée par un garde-fou technique.
- **Le transfert au QHS n'est pas idempotent, et il ne doit pas l'être.** Un second
  appel n'est pas un rejeu : c'est une seconde rébellion, et le jeu la permet. Ce
  qu'il faut tenir là n'est pas l'unicité mais la **cohérence** : quel que soit le
  nombre d'appels, exactement une peine en cours, chaînée à la précédente, aucune
  ligne à demi fermée, une seule ligne au registre du QHS.

> **Le critère : la brique protège ce qu'une JOURNÉE ne doit produire qu'une fois.
> Elle n'a rien à dire sur ce qu'un JOUEUR a le droit de refaire.**

### La brique générique — ÉCRITE ET BRANCHÉE LE 9 OCTOBRE 2026

> **Cette section était une proposition. Elle décrit maintenant ce qui existe :
> migrations `20261009093112` (la brique) et `20261009130649` (son premier
> consommateur, les préemptions). Ce qui suit a été conservé parce que le
> raisonnement d'origine était juste — mais trois choses ont changé en le
> réalisant, et elles sont signalées en place.**

`repartitions_versements(pays, source, beneficiaire, jour)` en clé primaire était
le patron, et son commentaire énonce la doctrine : « L'idempotence vit dans la
clé primaire. Un second passage lève une violation d'unicité et ne verse rien.
Ce n'est plus un champ qu'une écriture avalée peut perdre. »

Généralisée :

```
actes_nocturnes(pays, mecanisme, sujet, jour)   PRIMARY KEY
```

et une convention : **toute RPC nocturne commence par revendiquer son acte et
renonce si la journée est déjà prise.** Le rejeu ne devient pas « détecté », il
devient **impossible** — et impossible sans que personne ait à se souvenir de
poser un marqueur.

> **Trois écarts entre la proposition et ce qui a été construit.**
>
> **1. La revendication ne lève pas, elle rend un booléen.** La proposition
> disait « laisse la violation d'unicité annuler sa propre transaction ».
> `acte_nocturne_revendiquer()` fait un `ON CONFLICT DO NOTHING` et rend `false`
> : une journée déjà prise est un **fait métier normal**, pas une erreur. Laisser
> lever aurait annulé la transaction entière — y compris les effets *idempotents*
> qui doivent tourner chaque nuit, comme l'expiration d'un accord de
> rééchelonnement. La leçon vient de l'ardoise des loyers : on protège ce qui
> n'est pas idempotent, on laisse passer ce qui l'est.
>
> **2. Il a fallu une seconde table.** `actes_nocturnes_mecanismes`, liste
> blanche reliée par clé étrangère. Sans elle, un mécanisme mal orthographié
> ouvre un second espace de noms en silence — et ne protège donc plus rien.
> Ajouter un mécanisme devient une migration, ce qui rend la liste des tâches de
> minuit lisible en un endroit au lieu de se reconstituer depuis 6 400 lignes.
>
> **3. Le point qui compte n'est pas dans la table, il est dans les droits.**
> `acte_nocturne_revendiquer()` n'a `EXECUTE` **pour personne d'autre que son
> propriétaire** : retiré à `anon`, `authenticated` *et* `service_role`. Sans
> cela, le cron aurait pu revendiquer par PostgREST dans un aller-retour et
> produire l'effet dans un autre — le défaut d'origine, avec une table de plus.
> **L'architecture n'est pas une convention qu'on documente, c'est un droit qu'on
> retire.**

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
| Souvenirs | ~~deux appels **en ignorant le registre**~~ **VERTE le 10 octobre 2026** — l'épreuve est exactement celle décrite : vingt rejeux du même jour sur le même souvenir, en ignorant le registre, et le nombre de lignes « SCANDALE » ne bouge pas. C'est `jour_tirage` qui la rend verte, pas le registre. |
| Prêts, préemptions, cotisations, taxe foncière | deux appels, un seul mouvement, et le second appel **lève une violation d'unicité** plutôt que de renvoyer poliment zéro. La violation est préférable : elle apparaît dans `ECHECS_PASSE`, donc dans le code 500 de la passe |

~~Contraintes à ajouter~~ **POSÉES LE 10 OCTOBRE 2026 (registre 601).** Les deux
y sont, avec une précision que l'écriture de l'audit ne pouvait pas avoir : sur
`compromis_historique`, la clé est (pays, bien, **résultat**, journée) — « par
bien et par jour » seul aurait interdit un acte de jeu légitime, un compromis
remboursé et un dépôt d'achat direct perdu le même jour sur le même bien. Sur la
chronique, la contrainte porte sur la clé **logique** (pays, ville, scrutin), car
la clé primaire couvrait déjà le rejeu à l'identique ; ce qui manquait, c'était
l'interdiction d'une seconde proclamation sous un autre identifiant.

---

## 6. Décisions de game design

**Aucune.** Tout ce document porte sur la question « cette mécanique peut-elle
s'appliquer deux fois », qui n'est jamais une règle de jeu. Les seuls arbitrages
sont techniques et ils sont pris ci-dessus : la frontière est le sujet (le bien,
le dossier, la disposition, le bail) et non la passe ; le tirage aléatoire entre
dans la transaction ; la clé primaire porte le jour.
