# Bancs — éprouver une fonction réelle, hors ligne

Un banc charge le **vrai fichier du dépôt**, en extrait la fonction à tester, et
l'exécute dans JavaScriptCore avec des dépendances simulées. Il ne teste jamais
une copie : le texte évalué est celui qui part en production.

## Lancer un banc

**Un seul nom suffit, et c'est nouveau.**

```bash
python3 outils/bancs/lancer-banc.py outils/bancs/banc-patcher-blob.js
```

Le lanceur lit dans l'en-tête du banc la ligne `SOURCES:` qui dit de quels
fichiers du jeu il a besoin — `SOURCES: aucune` quand le banc les lit lui-même
par `readFile`. On peut toujours les donner à la main
(`lancer-banc.py <banc> supabase.js`), ce qui sert à éprouver un banc contre une
**version antérieure** d'une source.

Les cinq bancs JavaScript en une commande :

```bash
for b in outils/bancs/banc-*.js; do
  python3 outils/bancs/lancer-banc.py "$b" >/dev/null || echo "ROUGE : $b"
done
```

> **Deux défauts du lanceur, trouvés le 9 octobre 2026 en voulant simplement
> rejouer les bancs, et corrigés.**
>
> **1. Aucun banc ne disait de quelle source il avait besoin.** Un seul des
> quatre avait une enveloppe (`banc-api-supabase.py`). Lancés sans source, les
> trois autres affichaient leur titre puis s'arrêtaient — `jsc` rend **0** quand
> une exception meurt dans une promesse. Le lanceur refusait bien de les
> déclarer verts, mais personne ne pouvait deviner comment les relancer. La
> déclaration vit désormais **dans le banc**, et un banc sans déclaration est
> refusé en nommant ce qui manque.
>
> **2. Le lanceur cherchait le mot `ECHEC` n'importe où dans la sortie.** Le
> libellé de cas « la panne est un ECHEC » du banc du transport REST suffisait à
> le déclarer rouge alors que ses 24 cas passaient. Le verdict est maintenant
> une **ligne** : `LES N EPREUVES SONT VERTES.` ou une ligne qui *commence* par
> `ECHEC`. Un banc a le droit de parler d'un échec sans en être un. Les quatre
> bancs formulent désormais leur verdict de la même façon.
>
> Les deux corrections ont leurs contre-épreuves : un banc dont on retire le
> verdict rend un code non nul, et un banc dont un cas casse rend 1.

| Banc | Ce qu'il établit |
|---|---|
| `banc-transport-rest.js` | Les cinq états de `sbTransportRest` (supabase.js) sont nommés et distincts ; un **vide réel** (2xx avec `[]`) n'est plus confondu avec une **panne** ; le contrat historique des quatre primitives `sbGet`/`sbInsert`/`sbUpdate`/`sbDelete` est intact, rejet réseau compris ; `sbUpsert` ne fait plus de lecture de contrôle. 24 cas. |
| `banc-api-supabase.js` | Les **six états** que le socle serverless (`api/_supabase.js`) doit distinguer ; les trois identités (anon, jeton du joueur, service) et leur exclusion mutuelle ; l'absence de clé service **échoue au lieu de se rabattre**. 28 cas. |
| `banc-patcher-blob.js` | `sbPatcherBlob` **n'émet aucun PATCH** dès que la relecture du blob n'a pas abouti — la preuve porte sur l'absence de requête, pas sur la valeur de retour, parce qu'une fonction qui rend `null` après avoir écrit n'a rien corrigé. 24 cas. |
| `banc-solde-personnage.js` | `sbEcrireSoldePersonnage` est une **écriture conditionnelle** : solde attendu illisible refusé, garde `arg=eq.<lu>` posée, zéro ligne touchée signalé comme `solde_modifie_entre_temps`, et aucun succès annoncé sans preuve. 23 cas. |
| `banc-greve-generale.js` | `appliquerEffetsGreveGenerale` **revendique la journée avant tout effet**, par compare-and-swap : la garde du jour est dans le **filtre** et pas seulement dans le corps, la revendication est la **première écriture** de la passe, et **zéro requête** la suit quand elle n'aboutit pas — journée déjà prise comme panne de transport. 20 cas. |
| `banc-prets-bancaires.js` | `preleverPretsBancairesServeur` n'émet **aucun débit sans sa garde**. La preuve porte sur l'absence de `PATCH` sur `personnages`, pas sur un compteur : un compteur à zéro n'empêche pas un débit déjà parti. Vérifie aussi que le gel des prêts d'avant le 14 septembre tient toujours. 25 cas. |
| `banc-preemptions.js` | `preleverPreemptionsServeur` n'émet plus **aucune écriture directe** : tout passe par une RPC atomique. Vérifie l'identité serveur, la consommation de chaque verdict, et qu'une panne n'est jamais comptée comme un prélèvement. **Deux modes** — avec et sans le décor d'identité serveur, le second exigeant zéro requête. 20 + 3 cas. |
| `banc-mail-systeme.js` | `envoyerMailSysteme` **ne lève jamais** — c'est par là qu'un courrier perdu ne peut plus annuler un acte économique — **et ne perd jamais l'échec en silence** : chaque panne nomme le courrier dans `ECHECS_PASSE`. Éprouvé sur HTTP non-2xx, rejet de promesse et levée **synchrone** de `fetch`. Depuis le 9 octobre, prouve aussi que la brique passe **par la porte des courriers et jamais par la table**. 21 cas. |
| `banc-candidatures-nocturnes.js` | `traiterCandidaturesPostesExpirees` **ne tire plus au sort** et n'émet **aucune écriture directe** : registre des postes, titulaires PNJ, fiches et courriers sont descendus dans `candidature_poste_tirage_appliquer`. Prouve que chaque verdict est consommé, que le drapeau `traitee` est persisté **dossier par dossier**, et qu'une panne ne pose **ni drapeau ni sanction**. 32 cas — **21 tombent** sur la version précédente. |
| `banc-compromis-nocturnes.js` | `resoudreCompromisExpires` et `resoudreCompromisEntreprisesExpires` passent par une **porte unique pour les deux familles**, et le tirage du prêt est dedans. Prouve l'absence totale d'écriture directe, le bon comptage de chaque verdict, et que le cas Helvetia garde **sa** RPC. 34 cas — **23 tombent** sur la version précédente. |
| `banc-detention-plateau.js` | Les **cinq chaînes judiciaires** de `plateau-justice-economie.js` (ouverture, prolongation, fin de peine, transfert au QHS, sentence). Extrait les **vraies fonctions** du fichier de production par `readFile` : on n'éprouve pas une copie. Prouve qu'il ne reste **aucune écriture cliente** sur `detentions`, `personnages`, `prisonniers_qhs`, `jugements` ni `plaintes_en_cours`, et que **chaque verdict est consommé** — sans verdict, le jeu n'annonce rien et ne pose aucun état local. 61 cas. |
| `banc-vote-electoral.js` | `voterPour` **n'annonce jamais « Vote enregistré ! » sans écriture autoritaire**. Les sept motifs de refus sont dits honnêtement, les trois pannes qui faisaient annoncer un succès sont couvertes, et les gardes clientes subsistantes n'ajoutent **aucune** règle électorale. 39 cas. |
| `banc-desertion-liberation.js` | Les **deux libérations de désertion** de `plateau-politique.js` vidaient `state.estEmprisonne` sans jamais clore la ligne `detentions` : le registre carcéral déclarait détenu, indéfiniment, un personnage libre. Prouve qu'une seule porte est appelée, avec le **bon mode de fin**, et que son verdict est consommé — sans lui, personne n'est libéré et personne n'est conduit à la caserne. 32 cas. |
| `banc-taxe-fonciere.js` | `preleverTaxeFonciere` n'émet plus **aucune écriture directe** et ne relit ni le budget municipal ni la fiche du propriétaire. Les cinq refus « rien à faire » ne sont **pas** signalés comme des échecs, un refus inconnu l'est, et **aucun verdict n'est jamais une collecte**. 29 cas — **25 tombent** sur la version précédente. |
| `banc-calendrier-electoral.js` | Banc **structurel** : le dépouillement est un bloc inline dans le gestionnaire du cron, qu'on ne peut extraire sans rejouer la passe entière. Prouve qu'il n'y a plus aucune annonce écrite en direct, exactement **une** consignation, que chaque branche **décide sans écrire**, et que `resoudreScrutinSimple` / `resoudreScrutinDepute` ne tirent **rien** au sort — ce que l'audit affirmait à tort. Depuis le calendrier de succession (11 octobre 2026) il prouve aussi qu'il ne reste qu'**une seule** écriture directe de `cycles_electoraux` — la cascade PNJ : les deux autres étaient celles qui effaçaient le titulaire. 22 cas. |
| `banc-calendrier-succession.js` | **Mi-comportemental, mi-structurel.** `calendrierSuccession` et `ouvrirSuccessionSurCycle` sont des fonctions pures : elles sont APPELÉES, sur des dates réelles de Paris, et confrontées à des instants écrits en clair. Prouve le mandat de 5 semaines (4 de candidatures, gel au lundi 00:01 de la 5ᵉ, vote le dernier dimanche), la prolongation de 2 semaines et **pourquoi une seule ne marcherait pas**, les deux changements d'heure de 2026 dans les **deux** sens, et surtout qu'**ouvrir une succession ne touche NI `eluId` NI `elus` NI `dateDebutMandatTs`** — le cœur du correctif. Prouve enfin que le casting électoral des neuf députés PNJ est celui de l'hémicycle, qu'aucun des neuf fantômes ne subsiste, et que `MANDAT_SEMAINES` concorde avec les quatre `mandatSemaines` de `data.js`. 91 cas. |
| `banc-universite-et-pnj-client.js` | Les **deux blocs du 12 octobre 2026**, dans un seul banc parce qu'ils partagent une méthode : lire les fichiers de production par `readFile` et mesurer ce qui **n'y est plus**. Côté Université, prouve que `se_former`, `ORDER_EFFECTS.se_former`, sa route, `doSeFormer`, `appliquerFormation` et **toute** lecture de `bonusFormation` ont quitté le code — commentaires exclus, parce qu'un commentaire qui explique ce qu'il supprime ne doit pas faire échouer l'épreuve qui le vérifie — et que la remise à zéro au sommeil est partie avec eux. Côté PNJ, prouve que « Saluer » et son +2 INF quotidien n'existent plus, qu'il ne reste **qu'un** bouton « Donner », que « Ajouter au répertoire » ne subsiste que derrière la porte des **quatre** PNJ d'accueil, que « Voler » demande explicitement argent **ou** objet et **ne révèle jamais** qu'un PNJ est vide, et que « Neutraliser » générique est refusé à un gamma — un député gamma gardant, lui, une entrée **distincte** vers la mécanique spécifique de l'Assemblée, gardée par le **même prédicat** que le routage du gestionnaire, qui retourne avant la première ligne de l'ordre générique. 63 cas. |
| `banc-justice-peine-client.js` | Banc **structurel**, et il ne pouvait pas être autre chose : ce que ce lot change côté navigateur n'est pas un calcul, c'est **qui décide**. Il ne reste donc rien à calculer qu'on pourrait appeler. Prouve que le « 3 jours en dur » de la prison, les 30 jours du QHS, le 500 FR de l'amende et le comptage client du cumul de torture ont tous quitté `appliquerSentence` ; que la porte ne reçoit plus **ni** `p_affaire` **ni** `p_peine` mais un identifiant, une infraction canonique et des nombres ; que les cinq boutons de sentence ouvrent désormais la **qualification** et plus la sanction ; que la plage de modulation est **lue au serveur** et jamais recalculée localement (ni `* 0.5` ni `* 1.5` dans l'écran) ; que le prononcé **relit** cette plage avant d'appliquer quoi que ce soit ; et que `soumettrePlaynte` n'appelle plus `deduireCoutOrdre` ni ne reçoit de montant. Vérifie enfin que ce qui ne devait pas bouger n'a pas bougé : les gardes QHS/torture, le pré-contrôle d'autorité, et le code pénal de `plateau-core.js` — **c'est lui le canon**. 33 cas. |
| `banc-cotisations-organisations.js` | `renouvellerCotisationsOrganisations` n'émet plus aucune écriture directe et ne relit plus la fiche du membre. Prouve surtout que la **règle d'échéance est inchangée** — saison pour les supporters, trois mois calendaires pour le Syndicat des Dockers, jamais pour les autres organisations — et qu'un membre qui n'est pas dû n'est même pas présenté à la porte. 33 cas — **24 tombent** sur la version précédente. |
| `banc-successions-reglement.js` | `reglerSuccession` n'émet plus aucune écriture de règlement, mais **garde** la persistance de la phase de décision — et le banc l'exige, écrite **avant** l'appel : la supprimer ferait muter des actifs sur une décision jamais enregistrée. Prouve qu'un règlement partiel n'est pas un succès silencieux : l'étape refusée est nommée même quand le reste a abouti. 25 cas — **18 tombent** sur la version précédente. |
| `banc-taux-imposition.js` | Les deux chemins de fixation d'un taux n'appellent plus **aucune** ancienne primitive, ne transmettent **aucune clé de budget** ni aucun pays, et le taux annoncé est **celui rendu par le serveur**, jamais celui du curseur. Les cinq refus propres à l'acte sont nommés, les motifs de paiement délégués au nommeur déjà en place. Prouve aussi que le **doublon mort** a disparu du fichier. 42 cas. |
| `banc-tournee-cloture.js` | Les **quatre sorties** de `resoudreTournee` passent par **une** porte, avec le bon drapeau `servie`. Prouve que sans clôture confirmée la tournée n'est **pas** annoncée servie et que le gain local n'est pas posé — le joueur est averti que la reprise automatique s'en chargera. Prouve enfin que les trois anciennes primitives ont quitté le fichier. 34 cas. |
| `banc-mutation-terrain.js` | `finaliserAchatTerrain` transmet un **patch** et un **titre**, jamais un blob de cache — avec un **témoin que seul le serveur connaît**, sans quoi l'épreuve du cache ne prouverait rien. La **purge de la réservation** voyage dans le même patch : c'était la seconde moitié du défaut, et sa perte faisait repayer le solde. Sans verdict, l'acheteur n'est pas annoncé propriétaire et le cache n'est pas touché. 46 cas. |
| `banc-appro-chantier.js` | Banc **structurel** : les deux approvisionnements vivent au milieu de deux fonctions de plus de cent lignes. Prouve que le moteur de l'entrepôt n'est plus appelé par le navigateur, que ni la trésorerie ni le stock du chantier ne sont plus transmis, que le repli `|| { depense: 0 }` a disparu, et que la **dette restante est consignée dans le code** à l'endroit où elle subsiste. 23 cas — **22 tombent** sur la version précédente. |

> **`decor-env-serveur.js` n'est pas un banc**, c'est un décor : il pose une identité serveur
> **avant** le chargement des modules de `api/`, parce que `cron-minuit.js` lit sa clé au
> chargement (`const SUPABASE_SERVICE_ROLE = process.env...`). Un banc qui la poserait depuis son
> propre corps arriverait trop tard, et toutes les passes à identité serveur se rabattraient sur
> leur repli fail-closed sans émettre une seule requête. Il doit être la **première** source.
> Le retirer est précisément la façon d'éprouver le chemin fail-closed.
| `banc-budget-cascade.sql` | La cascade budgétaire ne perd aucun FR à l'arrondi, ne boucle pas sur le répartiteur, n'invente aucune part là où le pourcentage n'est pas arbitré, et **ne peut pas distribuer deux fois le même jour**. L'autorité et les bornes sont relues en base, pas dans le formulaire. 3 épreuves. |

## Le banc SQL : un banc qui écrit, et qu'une exception annule

> **`banc-succession-sans-vacance.sql` (11 octobre 2026) — 34 épreuves.** Il joue un mandat entier, son scrutin de succession, un second tour et une alternance, et exige que le titulaire reste attesté **à tous les instants du calendrier, proclamation échue comprise** — l'état exact où le cron n'a pas encore tourné, et que l'ancien moteur transformait en vacance. Il prouve aussi que les candidatures passent **pendant** le mandat et sont refusées après le gel, qu'on vote le dernier dimanche **alors qu'un titulaire est en fonction** (le court-circuit retiré), qu'un électeur du premier tour peut voter au **second**, que la succession des neuf est **une seule écriture** et fait tomber la présidence sortante au même instant, et qu'un rejeu de la proclamation ne proclame pas deux fois. Il laisse **exprès** trois fiches `poste_depute` périmées en base : si le siège en dépendait encore, tout le reste serait vert pour la mauvaise raison.

> **`banc-universite-socle.sql` (12 octobre 2026) — 21 épreuves.** Il éprouve le COMPORTEMENT des huit portes du socle universitaire, que les 12 preuves de la migration ne pouvaient pas atteindre : une preuve de migration est **structurelle**, elle lit un catalogue, elle ne joue pas un cursus. Il pose un cursus de test, inscrit deux personnages, et exige qu'un jalon de rang 3 soit **refusé** tant que sa semaine n'est pas ouverte puis accepté ensuite, qu'un second accomplissement du même jalon ne compte pas, qu'on ne puisse pas se diplômer avant la fin théorique même avec tous les jalons faits, qu'un cursus **expiré** n'accepte plus rien, et surtout que **l'abandon et l'expiration laissent le slot à vie disponible** alors que le diplôme le consomme définitivement. Il vieillit **l'inscription entière** pour simuler le temps — déplacer la seule `limite_le` violerait `universite_limite_apres_fin_theorique`, et la contrainte avait raison contre le banc. Il assère sur l'**identifiant** de l'inscription et non sur `ORDER BY clos_le DESC LIMIT 1` : `now()` est constant dans une transaction, donc deux clôtures y partagent leur horodatage et le tri est indécidable.

> **`banc-justice-peine-serveur.sql` (12 octobre 2026) — 22 épreuves.** Les 25 preuves des deux migrations du barème sont **structurelles** : elles lisent des catalogues, comptent des droits, vérifient l'ordre de deux instructions dans un corps de fonction. Aucune ne peut prouver qu'une peine hors bornes est **refusée**, ni qu'une plainte impayée ne laisse **rien** — ça se joue, et ça se joue en écrivant pour de vrai. Il nomme un juge (en l'inscrivant d'abord au registre des postes, sinon le déclencheur d'attestation refuse la fiche — et c'est la garde qu'on veut laisser en place), dépose des plaintes, et exige : que le dépôt prélève **exactement** le coût déclaré au miroir ; qu'un paiement refusé laisse zéro dossier ; qu'un doublon ne coûte rien ; qu'une infraction inconnue, un nom de **catégorie**, un genre inconnu, une durée sous la borne, au-dessus de la borne, et une amende hors plage soient tous refusés ; que le QHS soit **imposé** à 30 jours et la torture à 3 × (n+1) **compté par le serveur** ; que l'accusé et le motif de l'affaire ne puissent plus être réécrits au jugement ; et qu'un second jugement soit refusé.
>
> **Une épreuve a dû être réécrite, et ce qu'elle a appris vaut d'être noté.** Sa première version redéposait une plainte contre la même cible et attendait un refus pour doublon — qui n'est pas venu. Ce n'est pas un défaut : l'anti-spam ne mord que tant que le dossier porte le statut `deposee`, or dans une ville **sans commissaire joueur** le commissaire PNJ instruit immédiatement au dépôt, donc le premier dossier était déjà `classee` à la ligne suivante. La garde est beaucoup plus étroite qu'elle n'en a l'air. Fait rapporté, non corrigé : en changer la portée serait un arbitrage.

`banc-budget-cascade.sql` n'est pas un banc JavaScriptCore. La brique qu'il
éprouve vit **en base**, et la seule base joignable depuis cette machine est la
production, interdite en écriture. Chaque épreuve est donc un bloc `DO` qui écrit
pour de vrai, mesure, puis **lève une exception dont le message porte le
rapport** : l'exception annule la transaction, et le résultat revient quand même.
Le succès attendu se présente comme une erreur `P0001`.

C'est la même technique que le dry-run des migrations, décrite dans
`WORKFLOW-SUPABASE.md`. Après chaque bloc, on vérifie que rien n'a bougé — les
deux requêtes de contrôle sont en tête du fichier.

## Les deux pièges de JavaScriptCore

1. **Il n'a pas de `console`.** Une fonction qui journalise une erreur lèvera au
   lieu de rendre son résultat, et le banc testera le banc. Poser un
   `var console = { error(){}, warn(){}, log(){} };`.
2. **Les promesses ne se résolvent pas toutes seules.** Un banc synchrone doit
   appeler `drainMicrotasks()` en boucle, jamais une boucle d'attente vide.

## Ce qu'un banc doit refuser de faire

Passer alors que le correctif est absent. Un banc qui reste vert sans la
correction qu'il prétend vérifier ne prouve rien — c'est la leçon du banc de
mise en page de Chrome.

Vérifié pour `banc-transport-rest.js` le 7 octobre 2026 : exécuté contre le
`supabase.js` du commit précédent, il **ne se charge même pas**
(`Error: introuvable : sbTransportRest`). La manière de refaire ce contrôle :

```bash
git show HEAD~1:supabase.js > /tmp/avant.js
sed 's#.*/supabase.js#/tmp/avant.js#' outils/bancs/banc-transport-rest.js > /tmp/banc-avant.js
$JSC /tmp/banc-avant.js    # doit échouer
```

## Les contre-épreuves comme outil, pas comme geste manuel

Depuis le 9 octobre 2026, les contre-épreuves sont **automatisées** :

```
python3 outils/bancs/contre-epreuves-chantier5.py
```

Ce script réinjecte **trente-huit régressions** nommées, en **huit séries** —
détention, vote électoral, libérations de désertion, cotisations d'organisation,
règlement des successions, taux d'imposition, clôture de tournée et mutation de
propriété d'un terrain. Chacune est exactement le défaut que le lot a fermé. Il
les pose dans une **copie temporaire** du fichier de production, relance le banc
sur cette copie, et exige non seulement qu'il rougisse, mais qu'il rougisse
**sur l'épreuve attendue**. Un banc qui tombe ailleurs est signalé comme ne
prouvant pas ce qu'il prétend.

Le fichier de production n'est jamais modifié. Deux mécanismes de substitution
coexistent, parce que les bancs ne chargent pas leur source de la même manière :

- les bancs qui **extraient** les fonctions par `readFile` acceptent une
  variable `CHEMIN_SOURCE` que le script leur pose (`lancer()`) ;
- les bancs du cron **chargent** leur fichier comme un module : la copie patchée
  leur est donnée en **dernière source** sur la ligne de commande
  (`lancer_sources()`), à la place du fichier de production.

Un détail qui a coûté une fausse alerte : les deux familles de bancs ne
préfixent pas leurs échecs de la même façon — `  *** ` pour les uns, `  NON `
pour les autres. Le script reconnaît les deux.

Pour un banc dont on veut la contre-épreuve **complète** plutôt qu'une
régression ciblée, la ligne de commande suffit, parce que la version d'avant est
déjà dans Git :

```bash
git show HEAD:api/cron-minuit.js > /tmp/avant.js
python3 outils/bancs/lancer-banc.py outils/bancs/banc-compromis-nocturnes.js \
        outils/bancs/decor-env-serveur.js api/_referentiels-generes.js /tmp/avant.js
```
