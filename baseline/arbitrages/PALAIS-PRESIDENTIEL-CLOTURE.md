# Palais présidentiel de Républia — arbitrages rendus et écarts fermés

*11 octobre 2026. Commit `f47d5fe`. Registre Supabase 638 → 640.*

**À lire avant de toucher au Palais présidentiel, à la Garde républicaine, ou au
canal de dialogue des PNJ.** Ce document dit ce qui a été **décidé**, ce qui a
été **fermé**, et surtout ce qui est un **état normal du jeu** et ne doit pas
être « réparé ».

---

## La Présidence est prestigieuse et mécaniquement sobre — c'est voulu

C'est l'arbitrage qui gouverne tout le reste. Le Président dispose de dix actes,
pas un de plus, et la liste de ce qu'il **ne peut pas** faire est donnée aux
trois référents du Palais au même titre que ce qu'il peut faire.

**Ne pas « compenser » cette faiblesse en inventant une prérogative.** Si une
question porte sur un pouvoir absent de la liste, la réponse est que ce pouvoir
n'existe pas — pas qu'il est difficile, pas qu'il faut une autorisation.

| Le Président | Le Président ne |
|---|---|
| nomme (2 PA) et révoque (1 PA) le Premier ministre | nomme **pas** les ministres — c'est le Premier ministre |
| crée un poste ou un comité par décret (3 PA) | vote **pas** les lois — c'est l'Assemblée |
| état d'urgence 3 PA, guerre 5 PA, dissolution 4 PA | lève **pas** l'impôt, ne fixe aucun taux |
| référendum 3 PA, deuil national 1 PA, décret 1 PA | commande **pas** la troupe au jour le jour |
| traite les grâces (2 PA) | se saisit **pas** d'une grâce — il faut une recommandation du min_just |
| effort national, par 3 jours (2 PA) | débite **aucune** autre caisse que celle de la Présidence |
| conférence 2 PA, propagande 3 PA + 500 FR, démenti 2 PA | — |
| réception 2 PA + 1 000 FR, banquet 3 PA + 2 000 FR | — |

Les 500 FR de la propagande sortent de **sa poche** ; les réceptions et banquets
sortent de **la caisse de la Présidence**. La distinction est réelle et
`ORDRES_BUDGET_INSTITUTION` (plateau-router.js) l'établit.

---

## Un référent n'est pas une autorité

Les trois référents du Palais — Huguette Papier, le Porte-parole, Gérard
Tamponneau — **n'ont aucun pouvoir du poste**. Un Président, ou un ministre, qui
leur ordonne d'ouvrir une prérogative inexistante n'obtient qu'une explication.
C'était le risque explicite de cet arbitrage, et il est écrit dans les `limites`
de chacun.

**Le découpage est tenu, et c'est ce qui les rend utiles** : chacun porte **un**
domaine et **envoie** vers les deux autres. Donner les trois domaines à Huguette
aurait fait d'elle la référente de tout le Palais et rendu les deux autres
décoratifs. Le banc vérifie l'exclusion dans les deux sens.

| Référent | Son domaine | Ce qu'il n'explique pas |
|---|---|---|
| **Huguette Papier**, Secrétaire générale | la Présidence, ses pouvoirs réels et leurs limites, la candidature, la caisse, les quatre lieux | la communication, le protocole |
| **Porte-parole** | conférence de presse, propagande d'État, démenti — coûts, risques, et quand se taire | les pouvoirs du Bureau, le protocole |
| **Gérard Tamponneau**, Chef du protocole | réceptions, banquets, audience, préséance, art de recevoir | la communication présidentielle |

**Gérard porte un seul titre, partout.** Il en avait deux dans le même bâtiment
— « Chef du protocole presidentiel » au Hall d'honneur et « Organisation des
evenements » en Salle de Réception — et sa fiche serveur ne connaissait que le
premier. C'est le premier qui fait foi.

### La postérité : trois angles, aucun score

La **Salle des Présidents** du Musée National existe, et elle garde les
meilleurs **et les pires**. Il n'existe **aucun score de prestige, aucun
classement** — la salle affiche elle-même « classement à venir ». Les trois
référents en parlent avec un angle différent (les décisions / une phrase et une
image / les cérémonies) et **aucun ne promet une place**.

---

## Ce qu'un PNJ sait de son interlocuteur

`pnj_contexte_public()` est le **troisième canal** du dialogue. Les trois sont de
natures différentes et ne doivent pas être fusionnés :

| Canal | Nature | Qui l'a |
|---|---|---|
| `pnj_contexte_public` | un **fait du monde** — tout le monde sait qui est ministre | presque tous |
| `pnj_social_contexte` | une **relation** — elle se construit, elle peut ne pas exister | les PNJ sociaux |
| `referent_pedagogie_contexte` | un **historique d'explications** | les référents |

Il rend **le nom et les fonctions officielles attestées, et rien d'autre** :
exactement trois clefs. La liste de ce qu'il ne rendra jamais sans un arbitrage
explicite est écrite dans le corps de la fonction, pour qu'un ajout se voie dans
un diff. Le député est une **seconde** fonction, pas un remplacement.

Un poste auto-déclaré ne passe pas : le déclencheur d'attestation remet
silencieusement l'ancienne valeur, donc le canal ne voit rien.

**La correction est générique.** Les 211 profils serveur reçoivent le bloc —
Martial Bouterin comme le Président PNJ. Ce n'était pas un défaut du Palais.

---

## La Garde républicaine

Trois halls affichaient un garde qui n'existait **nulle part** : ni ligne en
base, ni arme, ni caractéristique, ni effet. On volait dans une pièce gardée
sans que personne s'y oppose.

- **septième famille PNJ** `garde_republicain`, classe bêta, les cinq axes au
  socle dès sa naissance — elle n'a aucun magasin historique à basculer ;
- **caractéristiques d'élite** : INT 10, CHA 8, VOL 16, PER 16, DUP 8, ENT 12.
  Aucune valeur inventée : VOL 16 et PER 16 sont les maximums **déjà en
  service** (agent de sécurité Grobras, maître-chien), le reste est recopié du
  profil policier. Même méthode que le 5 octobre ;
- **arme de service** `arme_de_poing`, déjà connue du jeu. Elle vit dans
  `pnj_possessions`, donc `militaire_arme_operationnelle` la trouve sans qu'on
  touche à cette fonction, et `pnj_mourir` la fait tomber au sol en objet
  abandonné : la neutralisation est **réelle** et l'arme **récupérable** ;
- **institution** `garde_republicaine`, périmètre = le pays, autorité = le
  ministre de la Défense. La Garde appartient à l'État, pas au ministre du
  moment : il décide des renforts, il ne possède pas les hommes ;
- **trois postes déclarés dans une table**, pas codés. Ouvrir un quatrième poste
  — ou un poste en Narcovie — est une ligne, pas une modification de code.

### Les horloges, et ce qu'elles interdisent

| Règle | Détail |
|---|---|
| le garde **permanent** | un par poste, **gratuit**, et il **revient 4 h** après être tombé |
| le **renfort national** | ×2 à ×5, **24 h**, 50 FR par garde supplémentaire sur la caisse de la Défense, **tout ou rien** |
| les **pertes** | un renfort tombé **n'est jamais remplacé** — et sa chute n'ouvre aucune vacance |
| le **poste décimé** | regarni de ses **renforts** seulement, à l'échéance **nationale** déjà posée |

**L'échéance appartient au pays, pas aux gardes.** C'est ce qui empêche de
prolonger la Garde en la tuant : un garde neuf arrivé sur un poste décimé hérite
de l'heure déjà posée.

> **Un poste décimé compte deux hommes, pas trois, et c'est juste.** Le permanent
> purge ses quatre heures. La règle du permanent et l'exception du poste décimé
> sont deux règles distinctes qui **se composent sans s'annuler**. Ne pas
> « corriger » ce compte.

### L'effet de groupe n'a pas été inventé — et l'audit s'était trompé

L'audit avait conclu que la « logique de groupe existante » n'existait pas hors
du moteur de bataille abandonné. **C'était faux.**
`Math.min(40, 10 + nombre)` est déjà le malus appliqué au jet de **tout** ordre
quand un détachement militaire en mission `securiser` occupe la pièce — posé
dans `plateau-politique.js`, appliqué dans `plateau-router.js:811`.

La Garde étant un groupe d'hommes armés dont la mission **est** de sécuriser, le
client **additionne les hommes** et applique la formule **une seule fois**. Ni
empilement de deux malus, ni règle du plus grand des deux : les deux auraient
été des règles neuves.

Le champ `malus` rendu par `garde_republicaine_piece` sert à l'affichage d'une
pièce gardée prise seule ; c'est `gardes` que le point de décision consomme, pour
qu'il n'y ait **qu'une seule autorité** sur le chiffre final.

### Le contrôle à l'entrée

La Garde **constate** qu'une personne sous jugement non exécuté se présente
devant des gardes **réellement présents**. Elle n'arrête personne elle-même :
elle remet le joueur à `verifierArrestationRecherchePolice`, le mécanisme de la
patrouille de police, qui calcule la peine, incarcère et journalise. **La Garde
fournit l'occasion, la justice fournit la suite** — écrire une seconde
arrestation aurait créé deux mécaniques concurrentes pour un seul fait de jeu.

**Un poste décimé laisse entrer.** Le malus suit les hommes, pas le panneau sur
la porte : c'est ce qui rend la neutralisation utile.

---

## Les six écarts techniques fermés

| Écart | Fermeture |
|---|---|
| aucun PNJ ne recevait la fonction de son interlocuteur | `pnj_contexte_public()`, troisième canal, générique aux 211 profils |
| `candidature_deposer` ne vérifiait ni influence, ni domiciliation, ni cumul | les trois contrôles, repris à la lettre de `candidature_publier`, **avant toute écriture** |
| `president`, `secretaire_general`, `porteparole`, `protocole` n'étaient dans aucune ligne de `pnj_fonctions` | déclarés, gamma, non recrutables |
| les trois référents du Palais n'étaient pas dans la liste fermée | inscrits — sans leur ligne, ils auraient eu une voix et **aucun souvenir** de ce qu'ils avaient expliqué |
| Gérard Tamponneau portait deux titres dans le même bâtiment | un seul, partout |
| `garde_republicaine_synchroniser` était mutante et ouverte à tout joueur (invariant 10) | la porte **supprimée**, pas gardée : le contrôle d'entrée est la porte unique |

---

## Deux leçons de méthode, gardées parce qu'elles coûtent cher

**Une preuve ne se prouve pas sur de la prose.** La preuve P2 vérifie que le
contexte public ne **lit** aucune donnée interdite, en relisant
`pg_proc.prosrc`. Or `prosrc` rend le source **commentaires compris** : le
commentaire qui énumère justement les champs interdits faisait échouer la preuve
sur sa propre documentation. Les lignes de commentaire sont désormais ôtées avant
la comparaison.

**Une épreuve qui se valide toute seule est la plus dangereuse d'un banc.** À sa
première exécution, le banc de la Garde a « réussi » un test d'interception parce
que le hall était **désert** : aucune interception, donc aucun échec. Le banc
pose et **vérifie** désormais sa prémisse avant de tester le contrôle.

Et `pnj_possessions.origine` nomme **l'axe d'autorité** de la possession, pas sa
provenance narrative : la liste fermée n'admet que `socle` et
`blob_accessoires`.

---

## La mémoire des mandats — livrée le 11 octobre 2026

C'était le dernier reliquat, et il est fermé. Huguette Papier dispose d'une
**mémoire narrative des présidences**, et une seule règle la gouverne : *elle ne
contient que des faits attestés par le serveur.*

### Ce qu'elle refuse d'enregistrer

| Refus | Pourquoi il compte |
|---|---|
| aucun Président **joueur** | c'est ce qui garantit que la mémoire commence au premier mandat réellement exercé. Au 11 octobre 2026, la bêta n'en a jamais connu, et **toutes** les tables d'événements nationaux étaient vides (0 grève, 0 guerre, 0 manifestation, 0 scandale) : il n'y avait rien à reconstruire |
| source non déclarée | liste fermée. On ne peut pas inventer un fait sans d'abord déclarer, **dans une migration**, d'où il vient |
| genre contredisant sa source | une guerre subie ne peut pas être maquillée en réaction présidentielle |
| réaction dont l'acteur n'est pas le Président | la conférence de presse d'un **ministre** n'entre pas dans la mémoire présidentielle — les deux salles de presse portent les mêmes noms d'ordre |

### Les quatre panneaux du Bureau n'y sont pas, et c'est la décision centrale

`pouvoirs_exceptionnels`, `adresse_a_la_nation`, `gestion_premier_ministre` et
`postes_par_decret` sont déclarés au miroir des coûts à **(0 PA, 0 FR)** : ce qui
franchit `payer_ordre`, c'est **l'ouverture du panneau**, pas l'acte. Les
enregistrer aurait écrit « le Président a déclaré la guerre » quand il a ouvert
une fenêtre.

Les sources non raccordables vivent donc dans une **table** que le banc relit —
`presidence_memoire_sources_absentes` — et non dans un commentaire que personne
ne vérifie. Une source en sort le jour où elle obtient une porte serveur.

### Ce qui l'alimente réellement

| Source | Genre | Comment elle est attestée |
|---|---|---|
| `chronique_nationale` | contexte | **la source générale.** Écrite par exactement trois portes serveur — dépouillement, publication d'une fuite, publication d'un scandale — et par rien d'autre. Un fait n'y entre qu'une fois **publié** : la question « Huguette pourrait-elle être au courant ? » s'y répond toute seule. Un déclencheur la reprend, donc un quatrième producteur serait couvert sans qu'on y revienne |
| `ordre_presidentiel` | réaction | les six actes réellement payés : grâce, conférence, propagande, démenti, réception, banquet. Le triplet (fn, pa, cost) est celui que `payer_ordre` valide contre le miroir |
| `guerre_declaree` / `guerre_subie` | réaction / contexte | le même fait dans les deux sens, écrit dans la mémoire des **deux** pays |

> **L'inaction n'est jamais écrite, elle est déduite à la lecture.** Écrire « il
> n'a pas réagi » exigerait de décider au bout de combien de temps l'absence
> devient notable — un seuil que personne n'a arbitré. La lecture rattache à
> chaque contexte la **première réaction qui l'a suivi dans le même mandat**, ou
> rien. « Rien » est une observation, et le corpus le dit à Huguette en ces
> termes. **Il n'existe aucun score, aucun classement, aucun bilan.**

**La séparation des mandats est structurelle, pas calculée.** La clef est le
couple `(titulaire, depuis)` de `postes_attribues` : deux présidences du **même**
joueur à deux époques ne se confondent pas, et les faits déjà écrits gardent leur
échéance quand `depuis` change.

### Ce qui reste à raccorder, nommé en base

Dix sujets attendent une porte serveur, et la table dit pourquoi pour chacun. Les
deux plus parlants : **grève** et **manifestation** sont écrites depuis le
navigateur (y puiser ferait entrer un fait déclaré par un client) ; et
l'**ouverture d'un mandat** par le dépouillement se rattacherait au mandat
*sortant*, parce que `postes_attribues` n'est pas encore à jour quand
`election_resultats_consigner` s'exécute.

Aucun de ces dix points n'est bloquant : la mémoire fonctionne, et la séparation
des mandats ne dépend pas d'eux.
