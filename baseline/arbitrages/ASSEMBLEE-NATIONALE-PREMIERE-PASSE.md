# Assemblée nationale — première passe : les PNJ du hall

*11 octobre 2026. **Ce bâtiment n'est PAS clos** : l'audit continue. Ce document
enregistre ce qui a été livré sur les trois PNJ du hall, ce que les données
permettent réellement d'attester, et ce qu'elles ne permettent pas.*

Migration : registre **20261011130112** (`assemblee_ce_que_renee_a_vu`).

---

## 1. Le garde — la mécanique était déjà générique, le dialogue était faux

**Rien à raccorder côté mécanique, et c'est le bon résultat.** L'audit montre que
le socle de la Garde républicaine couvrait déjà ce hall, sans aucune variante :

- `garde_republicaine_postes` déclare **trois** postes nationaux, et l'Assemblée
  en est un (`assemblee` / `accueil_assemblee`, Luthécia) ;
- un garde **réel** y est en faction (`garde_republicaine_effectifs`, 1 ligne,
  plus sa ligne dans `pnj_membres`) ;
- le contrôle d'entrée passe par `sbGardeControle(buildingId, roomId)`, appelé
  pour **toute** pièce dans `declencherEntreeZone` — aucun nom de bâtiment en dur ;
- le malus de groupe lit `sbGardePiece(state.currentBuilding, state.currentRoom)`
  et additionne soldats + gardes dans **la formule unique** du jeu.

**Ce qui était faux, en revanche, c'était son profil de dialogue.** Sa fiche le
décrivait comme *« PNJ - Sécurité présidentielle »*, travaillant *« au Palais de
l'Élysée de Républia »*. Or le **même nom affiché** — « Garde Republicain (PNJ) » —
est en faction dans les **trois** halls, et l'identifiant de profil se dérive du
nom : les trois gardes tombaient donc sur cette unique fiche. **Deux faits faux
sur trois postes.**

Il est désormais **institutionnel et sans lieu déclaré** : sa fiche n'a plus de
champ `lieu`, il dit « ici », « ce hall », « mon poste », et il sait qu'il est en
faction « à l'un des trois ». C'est la seule forme honnête — le serveur reçoit un
identifiant de profil, pas une pièce, et il ne peut pas savoir lequel des trois.

Son savoir est le socle réel de son corps : trois postes nationaux, un garde
permanent **gratuit** qui revient **quatre heures** après avoir été mis hors de
combat, un renfort **national** de **24 h** décidé par le ministre de la Défense à
**50 FR par homme** sur la **caisse du Ministère**, et un renfort tombé qui n'est
**pas** remplacé. Il n'est pas référent : il garde, il n'enseigne pas, et il
renvoie la procédure à l'hôtesse.

---

## 2. L'hôtesse d'accueil — référente pédagogique de l'institution

Elle répondait avec le repli des figurants : *« tu connais ton métier et l'endroit
où tu travailles. Rien d'autre. »* Pour quelqu'un dont le métier **est** de rendre
l'institution compréhensible, c'était le pire profil possible.

Elle est désormais la **référente pédagogique de l'Assemblée**, inscrite dans
`pnj_referents`, et **tout son savoir a été relevé dans le code** : les ordres de
`data.js`, les `COMMENT` des fonctions serveur, et `api/cron-assemblee.js` pour
l'échéance. Rien ne vient d'une description théorique d'un parlement réel.

Ce qu'elle sait, et qui est vrai :

| | |
|---|---|
| **Les sièges** | 9 sièges, **3 par ville** ; députés élus **au niveau de la ville**, mandat **5 semaines**, **5 INF** minimum pour se présenter |
| **Le dépôt** | 1 PA, réservé aux **députés, au Premier ministre et aux ministres** — le **Président n'est PAS éligible** — et il faut être **présent dans l'hémicycle** |
| **L'amendement** | gratuit, et il s'ajoute **sous** le texte original sans jamais le remplacer |
| **Le vote** | gratuit, réservé aux députés, **modifiable** jusqu'à la clôture |
| **L'échéance** | **mercredi 22 h**. Un vote arrivé après est refusé **même si le dépouillement n'a pas encore eu lieu** |
| **Le marchandage** | 1 PA + 100 FR, 50 % + (CHA+ENT)/2, prélevé **même en cas d'échec**, et **légal** à Républia |
| **Trois natures** | `mécanique`, `abrogation`, `rp` — une loi **RP est terminée dès son adoption** |
| **Adoptée ≠ en vigueur** | une loi mécanique n'a **aucun effet** avant sa mise en application par le **ministre de l'Intérieur en fonction**, dans **36 h réelles** ; le chrono appartient à la loi et aucun changement de gouvernement ne le remet à zéro |
| **La sanction** | **−20 POP** au palier H+36, puis **−10** à chaque palier suivant, frappant le Président, le PM et **tous** les ministres **à l'instant du palier** |
| **La portée** | liste **fermée** de dimensions ; elle **restreint**, elle n'élargit jamais |
| **L'indemnité** | **250 FR par jour**, une seule fois par jour, pour un député en siège |

Et elle dit **ce qui n'existe pas** : ni commission, ni séance des questions, ni
motion de censure, ni navette. Le **vote de confiance** appartient au Premier
ministre, la **dissolution** au Président — elle y envoie.

**Elle ne commente jamais politiquement, ne juge ni les députés ni les joueurs, et
n'a accès à aucune information privée.** Les trois interdits sont dans son prompt
et vérifiés par le banc.

**Elle n'a pas de nom propre, et ce n'est pas un oubli** : l'arbitrage ne lui en a
donné aucun, et en inventer un serait une décision de game design. Son identifiant
reste `hotesse_accueil`.

---

## 3. Renée Toitout — elle constate, elle n'enquête pas

L'agente d'entretien est nommée **Renée Toitout**. Le jeu de mots n'est **expliqué
nulle part** : ni dans son prompt, ni dans l'interface. Le banc vérifie qu'aucune
consigne ne le mentionne.

Elle reçoit un **cinquième canal de dialogue**, `assemblee_regards`, qui est la
partie la plus sensible de cette passe.

### Ce canal ne crée aucune surveillance

**Aucune table neuve, aucune journalisation neuve, aucun mouchard.** La porte est
`STABLE` — PostgreSQL lui interdit donc d'écrire — et une preuve structurelle
vérifie qu'aucun `INSERT`, `UPDATE` ni `DELETE` n'y figure. Elle **lit** trois
sources qui existaient déjà :

- `historique_deplacements` — le journal des passages ;
- `assemblee_sieges` — les neuf sièges et l'état `endormi` ;
- `assemblee_scrutins` — le dépouillement nominatif des scrutins **clos**.

### La source est attestée, et c'est ce qui change tout

`historique_deplacements` est **sous RLS sans aucune policy**, et **sans aucun
droit accordé à `anon` ni à `authenticated`** : le navigateur ne peut ni l'écrire
ni la lire. Et `deplacement_enregistrer` dérive l'identité de `mon_personnage()` —
un joueur ne peut inscrire que **son** passage, jamais celui d'un autre.

C'est exactement ce qui manquait à `chronique_nationale`, débranchée de la mémoire
présidentielle le matin même. Le banc le vérifie par contre-épreuve : un joueur qui
tente de lire la table en direct obtient un refus de privilège.

### Ce qu'elle rend, et ce qu'elle ne rend jamais

| ce que la porte rend | ce qu'elle ne rend jamais |
|---|---|
| qui est passé, combien de fois, dans quelles pièces, quand | une négociation de vote |
| qui s'est trouvé là **en même temps** | une corruption |
| le poste occupé **aujourd'hui** par le visiteur | un complot |
| s'il a une **raison institutionnelle** de venir | le contenu d'une conversation |
| les neuf sièges et qui dort | un score, une note, un classement d'assiduité |

`raison_institutionnelle` **n'est pas un jugement** : c'est la réponse à une
question factuelle, et la liste est celle que `assemblee_peut_deposer` applique
réellement (député, PM, ministres), plus l'appartenance à un groupe de presse — le
titre du correspondant parlementaire. Le Président n'y figure pas : il n'est pas
éligible au dépôt.

Le couple d'une co-présence est **ordonné**, pour qu'une rencontre ne soit pas
comptée deux fois. Et le `poste_actuel` est annoncé comme celui d'**aujourd'hui**,
pas celui du jour-là : le journal des passages ne garde pas la fonction du moment.

### Et surtout : elle dit ce qu'elle ne sait pas

C'est le point central de l'arbitrage, et il est porté par **deux drapeaux
serveur** :

- **`rien_a_signaler`** — aucun passage, aucune rencontre, aucun scrutin. Le bloc
  de prompt l'écrit alors noir sur blanc : *« RIEN. (…) DIS-LE SIMPLEMENT —
  n'invente ni visite, ni nom, ni anecdote. »*
- **`aucun_scrutin`** — le bloc interdit explicitement de conclure à une
  assiduité : *« tu ne peux dire de PERSONNE qu'il est assidu ou absent : il n'y a
  rien à comparer. »*

Sans ces drapeaux, un silence se raconterait comme une anecdote inventée. Le banc
éprouve les trois cas : tout vide, partiellement vide, et plein.

---

## 4. L'audit des données : ce qui est attestable, et ce qui ne l'est pas

C'était la condition de cette passe — ne rien simuler. Voici l'état réel.

### Attestable aujourd'hui

| donnée demandée | source réelle | état en bêta |
|---|---|---|
| **quels PJ ont été vus dans l'Assemblée** | `historique_deplacements`, filtré sur `building_id='assemblee'` et le pays de l'acteur | **oui** — 8 passages, 2 personnes (Arnie, Vince Kubrick) |
| **présences inhabituelles** | le même journal, avec la granularité de la **pièce** (hall, hémicycle, couloirs, archives) | **oui** |
| **PJ sans raison institutionnelle évidente** | jointure sur le poste réel + `presse_membres` | **oui** — Vince Kubrick, lieutenant, vu au hall : `raison_institutionnelle: false` |
| **groupes / rencontres observables** | co-présence même jour + même heure + même bâtiment | **oui, structurellement** — 0 cas attesté à ce jour |
| **quels députés sont venus voter** | `assemblee_scrutins.pour / contre / abstention` | **la donnée existe, l'historique est vide** |
| **l'état des neuf sièges, et qui dort** | `assemblee_sieges.endormi` | **oui** — 9 sièges, aucun endormi |

### Non attestable aujourd'hui — signalé, pas simulé

1. **L'assiduité des députés.** `assemblee_scrutins` archive `non_votants` et
   `endormis` à chaque clôture, donc la donnée **existerait**. Mais **aucun scrutin
   n'a jamais été clos** : `assemblee_scrutins`, `assemblee_votes`,
   `assemblee_propositions` et `assemblee_intentions` sont **à 0 ligne**. Renée dit
   qu'elle n'a pas encore vu voter. **Rien n'a été simulé pour combler ce vide.**
2. **La présence physique des PNJ.** `historique_deplacements` n'enregistre que les
   joueurs. Les députés PNJ **ne se déplacent pas** : ils occupent un siège. Renée
   les voit à leur place et ne peut pas raconter leurs allées et venues — c'est
   écrit dans son prompt.
3. **Le contenu de ce qui se dit.** Il n'existe **aucune** donnée de conversation
   entre PJ dans un bâtiment. Renée ne peut donc jamais rapporter des propos, même
   à demi-mot.
4. **La durée d'une co-présence.** Le journal donne le **jour** et l'**heure**
   (`'10h'`, `'22h'`), pas une plage : deux personnes « là en même temps » signifie
   « la même heure de jeu », rien de plus fin.

**Aucune trace serveur supplémentaire n'a été créée.** Si une de ces quatre
catégories doit devenir attestable, c'est un arbitrage à rendre — pas une
implémentation à improviser.

---

## 5. Écarts trouvés pendant l'audit, hors périmètre de cette passe

1. **La description du bâtiment annonce 25 sièges.** `BUILDINGS['assemblee'].desc`
   dit « Les 25 sieges de l'Assemblee Nationale » ; l'hémicycle dit « Neuf sieges :
   trois par ville », la base en contient **9**, et `POSTES_ELECTIFS` déclare
   `nbParVille: 3`. **Le texte de vitrine est faux** — non corrigé ici, l'audit du
   bâtiment continue.
2. **Seb Lex n'existe pas.** Le retrait de `proposer_abrogation` renvoie le joueur
   au *« juriste de l'Assemblée »* — « c'est Seb Lex qui qualifie l'abrogation » —
   et l'asset `images/assemblee-juriste-seb-lex.webp` **est dans le dépôt**. Mais
   **aucun PNJ Seb Lex n'est déclaré** dans `data.js`, et aucun profil serveur ne
   porte ce nom. La porte d'abrogation existe côté serveur ; le personnage qui doit
   y conduire, non.
3. **Trois autres PNJ de l'Assemblée restent des figurants** : le Lobbyiste Perrin
   et le Journaliste Blanc (couloirs), l'Archiviste parlementaire (archives). Ils
   ont une fiche mince `{nom, role, lieu}` et le savoir de repli. Hors périmètre de
   cette passe, qui portait sur le **hall**.
4. **Le Président Laroche n'a aucun corpus.** Il est référent « institutions et
   État » mais n'est pas dans `CORPUS_REFERENT` : son savoir se limite à son domaine
   déclaré. Ce n'est pas un défaut — un référent sans corpus oriente au lieu
   d'inventer — mais c'est à savoir avant de l'interroger sur la procédure.

---

## Ce qui a été éprouvé

- **`banc-assemblee-hall.js` — 94 épreuves** : les trois PNJ sont là et nommés,
  chaque nom se **normalise exactement** en son identifiant de profil, le garde ne
  déclare plus aucun lieu de travail, l'hôtesse porte les 17 règles réelles de la
  procédure, Renée porte ses interdits, **chacune ignore le domaine de l'autre**, et
  le bloc du cinquième canal est éprouvé **vide**, **plein** et **partiellement
  vide** — y compris le fait qu'une liste vide se dise « personne » au lieu d'un
  blanc.
- **`banc-assemblee-regards.sql` — 26 épreuves** : la porte est `STABLE`, `anon` ne
  peut pas l'appeler, un joueur ne peut pas lire le journal en direct,
  `rien_a_signaler` se lève sur un bâtiment vide, le compte des passages et des
  pièces est juste, la co-présence n'est pas comptée deux fois, les champs rendus
  sont **exactement** ceux qui sont attestés, un passage dans un **autre bâtiment**
  ou dans l'Assemblée d'un **autre empire** n'est pas rendu, et `aucun_scrutin`
  tombe dès qu'un scrutin est réellement clos.
- **Les 11 contrôles du baseline** et les **38 bancs JavaScript** sont verts.
  Cinq bancs ont dû déclarer la nouvelle bible dans leur en-tête `SOURCES:` — c'est
  le piège connu depuis le Palais présidentiel, et il s'est reproduit à l'identique.

---

## Ce qui reste ouvert

1. **L'audit de l'Assemblée continue** : ce bâtiment n'est pas clos.
2. **Les 25 sièges de la vitrine** contre les 9 réels (point 5.1).
3. **Seb Lex** : la porte existe, le personnage non (point 5.2).
4. **Les trois figurants des couloirs et des archives** (point 5.3).
5. **Quatre catégories de connaissance non attestables** à arbitrer si elles
   doivent exister (section 4).
