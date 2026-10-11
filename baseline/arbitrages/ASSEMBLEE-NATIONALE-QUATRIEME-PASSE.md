# Assemblée nationale — quatrième passe : Laroche député, et le seuil d'une heure

**11 octobre 2026.** Registre Supabase 659 → 662 (trois migrations).
**Le bâtiment n'est pas clos** : l'audit continue avec le lobbyiste, le journaliste et
l'archiviste.

---

## 1. Les six arbitrages de la passe

| Arbitrage | État | Où |
|---|---|---|
| §1 **Laroche est l'un des neuf**, député de Luthécia et Président | **livré** | `assemblee_sieges` rang 3 de la capitale + `ASSEMBLEE_SIEGES` |
| §2 **Zéro votant** : les neuf à égalité à zéro, courte paille entre les neuf | **confirmé, inchangé** | `assemblee_presidence_depouiller` |
| §3 **Un boycott ne ferme pas le débat** | **confirmé, inchangé** | seule `assemblee_suspendue_par_la_presidence` ferme les six portes |
| §4 **Suspension > 1 h → renvoi à la prochaine session**, suffrages annulés | **livré** | `assemblee_suspension_appliquer_seuil` |
| §5 **Vote présidentiel : présence physique dans l'hémicycle** | **livré** | `assemblee_presidence_voter` → `hors_hemicycle` |
| §6 Cumul « présidence + autre poste nommé » : **aucune règle créée** | **rapporté, rien créé** | voir §7 de ce document |
| §7 Asset de la courte paille : **aucun asset généré** | **respecté** | l'animation HTML/CSS reste celle de la troisième passe |

---

## 2. §1 — Qui a cédé son siège, et pourquoi celui-là

**C'est Benoît Delorme**, qui tenait le **rang 3 de Luthécia**. L'arbitrage dit que le choix
individuel n'a aucune importance — les neuf PNJ sont volontairement identiques, sans idéologie ni
loyauté. L'existant, lui, en avait une :

| PNJ de Luthécia | Rang | Nommé ailleurs dans le dépôt ? |
|---|---|---|
| Étienne Vauclerc | 1 | oui — `banc-assemblee-hall.js` (état de séance forgé) |
| Sophie Maréchal | 2 | oui — `banc-presidence-election.sql`, `banc-assemblee-regards.sql`, `banc-assemblee-hall.js` |
| **Benoît Delorme** | **3** | **nulle part**, hors la définition de son siège et sa ligne de statistiques |

Retirer Maréchal ou Vauclerc aurait obligé à réécrire des épreuves qui ne parlent pas d'eux.
Delorme est le remplacement **le moins bruyant** — pas un jugement sur le personnage.

> **Corrigé le 11 octobre au soir — cette passe avait tort sur ce point.** Elle justifiait le
> rang 3 par « le dernier PNJ de Luthécia à céder sa place », donc par une protection du Président
> en exercice. **C'est faux en game design, et l'arbitrage l'a tranché** : le renouvellement de
> l'Assemblée est **intégral**, et la présidence ne survit jamais au mandat qui la porte. Le rang
> n'est que l'ordre d'appariement des députés joueurs élus, identique dans les trois villes depuis
> le 10 septembre ; il ne met personne à l'abri. **Aucune ligne de code n'avait implémenté cette
> protection** — c'était une justification écrite dans un commentaire, et elle est retirée. Voir
> `ASSEMBLEE-NATIONALE-CORRECTIF-LEGISLATURE.md`.

### Composition finale des neuf sièges

| Ville | Rang 1 | Rang 2 | Rang 3 |
|---|---|---|---|
| **Luthécia** (`capitale`) | Étienne Vauclerc | Sophie Maréchal | **President Laroche** |
| **Montrouge** (`ville_b`) | Nathalie Charron | Gérard Pichon | Élodie Vasseur |
| **Port-Sainte-Marie** (`ville_a`) | Yann Legall | Maëlle Leroux | Loïc Kermeur |

Neuf au total, trois par ville, et **sept preuves structurelles** le vérifient dans la migration :
neuf sièges exactement, trois villes à trois sièges, Laroche parmi les trois de Luthécia, un seul
siège pour `dep_laroche`, aucun nom de PNJ en double, `dep_delorme` absent, et le siège
`republic:capitale:3` toujours au rang 3.

### Il n'existe plus de dixième parlementaire — trois preuves indépendantes

1. **La carte statique est retirée.** `BUILDINGS.assemblee.rooms.hemicycle.persons` est désormais
   un tableau **vide**. Les neuf arrivent tous par `appliquerDeputesAssemblee`, Laroche compris,
   et sa photo voyage avec la ligne de son siège. Une épreuve client refuse toute carte statique
   dans l'hémicycle, et une autre balaie **tous** les bâtiments à la recherche d'une carte
   `president_assemblee` ou d'un nom contenant « Laroche » : zéro.
2. **Les éligibles à la présidence sont exactement les titulaires des neuf sièges.** Le banc le
   prouve par un `EXCEPT` : la liste des éligibles moins les occupants des neuf sièges donne
   l'ensemble vide.
3. **La porte de vote refuse tout nom hors des neuf figés à l'ouverture** (`pas_eligible`), règle
   héritée de la troisième passe et toujours éprouvée.

### Le nom reste « President Laroche » — et ce n'est pas un oubli

Son profil de dialogue serveur est la clé `president_laroche`, **dérivée de son nom affiché** par
`slugPnj()`. Le renommer le rendrait muet, et six autres PNJ renvoient vers « le Président
Laroche, à l'Assemblée » dans leurs sujets d'orientation.

> **Point à arbitrer, consigné et non tranché.** Son NOM affirme une fonction qu'il peut perdre.
> Le jour où un autre député est élu Président, l'hémicycle affichera « President Laroche (PNJ) —
> Député de Luthécia » à côté d'un autre « Président de l'Assemblée nationale ». Le renommer
> demande soit un alias dans `PNJ_PROFILS_SERVEUR`, soit un arbitrage sur son identité — et
> l'arbitrage de cette passe réserve explicitement le corpus et la personnalité de Laroche.

### Un défaut de la troisième passe, trouvé en l'intégrant

`appliquerDeputesAssemblee` comparait le titulaire du registre (`RP_PRESIDENCE_ETAT.president`)
au nom **affiché** de la carte, suffixe « (PNJ) » compris. Or le serveur rend le nom **nu** :
`assemblee_occupation_sieges` renvoie `pnj_nom` tel quel, et c'est ce nom nu que le dépouillement
inscrit dans `postes_attribues`. **La double qualité ne pouvait donc s'afficher pour aucun
Président PNJ** — défaut invisible jusqu'à cette passe, puisqu'aucun PNJ ne pouvait être assis et
Président à la fois. Corrigé, et une épreuve client le garde.

---

## 3. §2 — Zéro votant : confirmé, et rien n'a été touché

Le comportement découvert à la troisième passe est **validé tel quel** : les neuf à zéro voix sont
tous ex æquo, le serveur tire la courte paille entre les neuf, le gagnant devient Président.
**Aucun quorum minimal, aucun vote PNJ fabriqué, aucune vacance créée.** Le banc de la quatrième
passe le remesure et ajoute deux garanties : **un seul gagnant**, et il est l'un des neuf ; **le
résultat est stable** — un second dépouillement rend le même élu, la paille ne se retire pas deux
fois ; et **aucun bulletin n'a été fabriqué** pour les PNJ.

---

## 4. §3 — Le boycott laisse parler ceux qui restent

L'asymétrie est **validée**, et c'était déjà le comportement implémenté — aucune ligne de règle
n'a été écrite pour §3, seulement des épreuves pour l'empêcher de dériver.

| | Boycott (5 protestataires qualifiés) | Suspension présidentielle |
|---|---|---|
| Demander / donner / retirer la parole | **fonctionne** | refusé (`seance_suspendue`) |
| Parler au débat | **fonctionne** | refusé |
| Rappel au règlement, sanction | **fonctionne** | refusé |
| Un scrutin échu peut-il être conclu ? | **non** — l'échéance part d'une semaine | voir §5 |
| Les suffrages déjà exprimés | **conservés** | annulés au-delà d'une heure |

Le banc l'éprouve **dans les deux sens avec le même député**, pour qu'on ne puisse pas croire que
c'est une particularité du votant : Arnie parle pendant le boycott, et le même Arnie se voit
refuser la parole dès que le Président suspend.

Un boycott **repousse**, une suspension longue **annule** : c'est toute la différence, et l'écran
la dit en deux phrases distinctes.

---

## 5. §4 — Le seuil d'une heure

### Ce que « prochaine session parlementaire » veut dire, et où c'était déjà écrit

L'arbitrage interdit de remplacer cette notion par « +7 jours » si l'existant en possède une plus
précise. **Il en possède une, complète, et c'est le RENVOI du §27** :

1. une proposition renvoyée porte `statut='renvoyee'`, `cloture_ts=NULL`, `session_ouverte_ts=NULL`
   — exactement ce qu'écrit `assemblee_cloturer` sur une égalité ;
2. `assemblee_ouvrir_sessions_eligibles` la reprend à la **prochaine fenêtre d'ouverture** —
   mercredi à partir de 22 h de Paris, et tout le jeudi (`assemblee_fenetre_ouverture`) ;
3. `assemblee_ouvrir_session` lui donne alors un `session_num` **neuf**, **efface** les votes des
   sessions précédentes, retire de nouvelles intentions PNJ, et recalcule `cloture_ts` au prochain
   mercredi 22 h de Paris.

Le moteur de session fait donc **déjà** « reporter à la prochaine session, annuler les suffrages,
repartir de zéro ». Cette passe n'a construit **aucun calendrier parallèle** : elle pose le statut
de renvoi et consigne la cause. Une preuve structurelle refuse tout `7 days` et tout appel à
`assemblee_prochaine_cloture` dans la porte de renvoi.

### Les deux règles, et ce qu'elles font exactement

**A. Suspension ≤ 1 heure : aucun effet.** L'échéance initiale demeure, le texte reste en session,
les bulletins déjà déposés sont intacts. Éprouvé à 40 minutes, puis à la reprise : la porte ne
trouve rien et n'écrit rien.

**B. Suspension > 1 heure**, pour chaque scrutin qui était ouvert pendant elle :

| | |
|---|---|
| `statut` | `'session'` → **`'renvoyee'`** |
| `cloture_ts` | → **NULL** (aucune date fabriquée) |
| `session_ouverte_ts` | → NULL |
| `assemblee_votes` de la session annulée | **supprimés** |
| `assemblee_intentions` de la session annulée | supprimées (rerollées à l'ouverture suivante) |
| `assemblee_reports_suspension` | une ligne : texte, suspension, session annulée, bulletins et intentions annulés, échéance initiale, durée |
| `assemblee_reports` (report volontaire) | **rien** |

**Les suffrages ne sont pas rendus inertes, ils sont retirés.** Le numéro de session suffisait à
les neutraliser ; les supprimer est délibéré — un député qui revient sur l'écran doit voir un
scrutin **vide**, pas sa propre voix dans un décompte qui ne compte plus.

### Le calcul est serveur, et il ne dépend de personne

La durée est lue sur les deux colonnes de la suspension : `ouverte_le` et `close_le`. **Aucun
navigateur ouvert, aucun minuteur client, aucune présence requise** — ni celle du Président, ni
celle des députés. La porte de renvoi n'accepte qu'**un seul paramètre, le pays** : un client ne
peut pas déclarer depuis quand il attend, et une preuve structurelle vérifie sa signature.

Une **suspension déjà close** est mesurée sur sa durée réelle. C'est ce qui interdit de suspendre
une heure et demie puis de reprendre juste avant le passage du cron pour effacer la trace —
éprouvé avec une suspension close ayant duré 100 minutes.

**L'effet est posé à quatre occasions**, toutes serveur :

| Occasion | Quand |
|---|---|
| `assemblee_reprendre_seance` | immédiatement, à la reprise — la durée devient définitive |
| `cron-minuit` | chaque nuit |
| `cron-assemblee` | lundi et mercredi, 21 h et 22 h UTC, **avant le dépouillement** |

Le dernier point est celui qui compte : **un scrutin ne peut pas se conclure sans que le seuil ait
été regardé**, parce que l'application précède `assemblee_cloturer_echues` et
`assemblee_reporter_si_suspendue` dans la même passe. Deux épreuves client vérifient cet **ordre**
dans le fichier du cron — c'est l'ordre qui *est* la règle.

### Ce renvoi n'est pas la prérogative présidentielle

| | `assemblee_reports` | `assemblee_reports_suspension` |
|---|---|---|
| Nature | décision volontaire du Président | conséquence d'une suspension longue |
| Verrou | **une fois par TEXTE** (`deja_reporte_une_fois`), quel que soit le numéro de session | une fois par (suspension, texte, session) |
| Écrit par le renvoi ? | **non, jamais** — preuve structurelle par expression régulière | oui |

Donc : le renvoi **ne consomme pas** le droit de report volontaire (éprouvé : après un renvoi, le
Président peut encore reporter), et il **ne le rend pas une seconde fois** — `assemblee_reports`
est verrouillé par `proposition_id` seul, pas par `(proposition_id, session_num)`, si bien que
changer de numéro de session n'ouvre aucun second report. Une preuve refuse d'ailleurs que
`assemblee_reporter_vote` regarde un jour le numéro de session.

### Un point d'audit honnête

**La porte de vote législatif n'est pas bloquée par une suspension présidentielle.** Les six
portes qui refusent `seance_suspendue` sont la parole (demander / donner / retirer), le débat, le
rappel et la sanction — exactement l'énumération du §3 de l'arbitrage, qui demande de conserver
cette différence. Le scénario décrit en §4 (« suspendre avant que l'opposition puisse voter »)
est donc partiellement théorique : techniquement, l'opposition *peut* encore déposer son bulletin
pendant la suspension. **La règle du seuil le neutralise entièrement quand même**, et c'est pour
cela qu'elle est écrite telle quelle : une Assemblée suspendue plus d'une heure ne conclut aucun
scrutin, que le vote ait été matériellement possible ou non.

---

## 6. §5 — On n'élit pas son Président depuis le hall

`assemblee_presidence_voter` refuse `hors_hemicycle`. La **convocation du lundi prend un sens
physique** : il faut venir.

| Où se trouve le député | Verdict |
|---|---|
| Hall de l'Assemblée (`accueil_assemblee`) | **refusé** |
| Autre ville, autre bâtiment | **refusé** |
| Hémicycle | **accepté**, si les autres conditions sont réunies |

**La position est lue en base, jamais déclarée.** `acteur_present_sur_site` est la règle de
localisation unique du projet ; `assemblee_dans_hemicycle` n'en est que l'application nommée
(capitale / assemblee / hemicycle). **La signature de la porte n'a pas bougé** — deux paramètres,
le nom voté et l'identifiant de requête — donc il n'y a aucune pièce à falsifier, et deux preuves
le vérifient (signature exacte, et **une seule** signature : une surcharge sans contrôle de
présence survivrait).

**L'ordre des refus est une information, pas un hasard** — et il est prouvé par la position des
motifs dans le corps de la fonction :

1. **garde de rejeu** d'abord : un bulletin déposé puis une réponse perdue doit se retrouver, même
   si le député a quitté l'hémicycle entre-temps ;
2. **mandat** ensuite (`pas_depute`) : un non-député présent s'entend dire qu'il n'est pas député,
   pas qu'il est mal placé ;
3. **présence** enfin.

**La règle vaut pour l'élection exceptionnelle** déclenchée par deux boycotts, et sans traitement
particulier : c'est la **même porte**. Une preuve vérifie qu'elle ne regarde pas la cause du
scrutin, et le banc rejoue le refus puis l'acceptation sur un scrutin de cause `deux_boycotts`.

L'écran **explique avant de refuser** : hors de l'hémicycle, le bouton « Voter » n'est pas proposé
et le député lit pourquoi. Cette lecture n'autorise rien — la vérité reste la porte, et
`hors_hemicycle` a sa phrase pour le cas où le refus arrive quand même.

> **Note d'audit.** Le vote **législatif** contrôle déjà la présence, mais par une lecture directe
> de `personnages` (`current_building` / `current_room`) et non par `acteur_present_sur_site` : il
> ne vérifie pas `current_city`. Sans conséquence aujourd'hui — un seul hémicycle existe — mais
> les deux plomberies diffèrent. Signalé, non modifié : hors du périmètre de cette passe.

---

## 7. §6 — Le cumul, et la limitation de `state.poste`

**Aucune règle de game design n'a été créée.** Aucune incompatibilité, aucun mandat retiré, aucun
choix arbitraire sur le poste à conserver.

### Le cumul obligatoire fonctionne vraiment

| | |
|---|---|
| Le Président reste député | **oui** — `postes_attribues` (la fonction) et `poste_depute` + `assemblee_sieges` (le mandat) sont deux registres distincts |
| Changer de Président détruit un siège ? | **non** — neuf sièges avant, neuf après |
| L'écran de présidence touche-t-il `state.posteDepute` ? | **jamais** — une épreuve l'interdit par expression régulière |
| Perdre la présidence | le titre tombe, **le siège reste** |

### Le scénario concret qui existe aujourd'hui, et sa limitation

**`state.poste` est un emplacement UNIQUE.** `plateau-politique.js` le dit en une ligne :
`const champ = posteId === 'depute' ? 'posteDepute' : 'poste';` — tout poste nommé autre que
député va dans ce seul emplacement.

**Le cas** : un député qui détient par ailleurs un poste nommé — un ministère, une mairie, une
direction — et qui est élu Président de l'Assemblée.

| | |
|---|---|
| Ses **pouvoirs** de Président | **intacts.** Toute la séance lit `assemblee_president()`, qui lit `postes_attribues` au serveur. La fiche n'autorise rien. |
| Son **mandat de député** | **intact.** `poste_depute` est un champ séparé. |
| Sa **fiche** | affiche l'autre poste. `presidenceAdopterLeTitre` **n'écrase jamais** un poste nommé existant. |

C'est donc une limitation **d'affichage seulement**. Les données concernées :
`state.poste` (scalaire, un seul objet `{id, name, city}`), `state.posteDepute` (scalaire, séparé),
et `postes_attribues` (la seule vérité).

**Ce qui a changé, et c'est tout** : le jeu ne se tait plus. Jusqu'ici
`presidenceAdopterLeTitre` faisait `if (state.poste) return;` — un retour **silencieux**. Le
joueur voyait sa fiche inchangée sans savoir pourquoi. Il reçoit maintenant, une fois par session,
un message qui dit les trois faits : ses pouvoirs de président sont actifs, sa fiche ne porte
qu'un titre nommé à la fois, son siège est inchangé. **Informer n'est pas trancher** : aucune
incompatibilité n'est créée, et le jeu ne choisit pas à sa place.

À comparer avec ce que l'existant fait déjà pour les postes **élus** : `reconcilierPosteElu`
refuse d'écraser un poste différent et affiche « Élu(e), mais... Démissionnez d'abord pour prendre
vos nouvelles fonctions. » La présidence de l'Assemblée n'est pas un poste de cycle électoral, et
ne passait donc pas par ce chemin.

> **Point à arbitrer si le cumul doit un jour s'afficher** : il faut soit un second emplacement de
> titre nommé, soit une liste, soit une règle de priorité d'affichage. Aucun des trois n'est
> arbitré, et aucun n'a été inventé ici.

### Un autre point, trouvé en §1 — **arbitré et fermé le même soir**

Si **trois députés joueurs** sont élus à Luthécia, les trois sièges PNJ de la ville sont pris —
celui de Laroche compris — et l'invariant « le Président est obligatoirement l'un des neuf
députés » tombait s'il présidait à ce moment-là. Cette passe laissait le point ouvert.

**Il est arbitré** : la présidence ne survit pas au mandat. `assemblee_president` ne rend le
titulaire du registre que s'il est l'un des neuf de la législature en cours — il n'existe donc
aucune période, pas même une seconde. Et l'audit du correctif a trouvé **pire** que le cas
signalé : le siège d'un député joueur était dérivé d'un champ de fiche que rien ne nettoyait côté
serveur. Voir `ASSEMBLEE-NATIONALE-CORRECTIF-LEGISLATURE.md`.

---

## 8. §7 — Aucun asset généré

L'animation de la courte paille reste celle de la troisième passe : HTML/CSS, neuf pailles, un
halo qui atterrit sur l'index de l'élu **déjà écrit en base**. Aucun fichier image n'a été créé.
Un asset graphique fourni séparément pourra être intégré sans toucher à la logique serveur du
tirage, qui ne dépend d'aucun rendu.

---

## 9. Migrations, tests, et ce qui reste

### Les trois migrations

| Registre | Nom | md5 | Caractères |
|---|---|---|---|
| `20261011171445` | `assemblee_laroche_neuvieme_depute` | `269c50ee41279408a73b16ecba1cdb27` | 5 703 |
| `20261011172314` | `assemblee_suspension_seuil_une_heure` | `ef52fa29db9af8f99a8f0ba4606ab5da` | 28 392 |
| `20261011172435` | `assemblee_presidence_vote_dans_l_hemicycle` | `81fdb3b201f85422334f22336434aa6b` | 12 197 |

Registre 659 → **662**. Les trois sont archivées sous `historique/migrations-appliquees/`, corps
relu **depuis le registre** et empreinte revérifiée contre celle que la base a calculée.
**24 preuves structurelles** au total (7 + 10 + 7).

### Les bancs

| Banc | Épreuves |
|---|---|
| `banc-quatrieme-passe.sql` (neuf) | **53** |
| `banc-quatrieme-passe-client.js` (neuf) | **35** |
| `banc-presidence-election.sql` | 35 |
| `banc-presidence-suspension-partis.sql` | 37 |
| `banc-seance-protestation-suspension.sql` | 29 |
| `banc-seance-parole-discipline.sql` | 35 |
| `banc-assemblee-regards.sql` | 26 |
| `banc-presidence-client.js` | 69 (64 → 69) |

**Un banc était rouge avant cette passe**, et personne ne l'avait vu :
`banc-seance-protestation-suspension.sql` E26 cherchait une suspension présidentielle **close**.
La troisième passe a rendu cette suspension **persistante** — elle reste ouverte jusqu'à la
reprise — sans mettre l'épreuve à jour. Elle vérifie désormais la vérité d'aujourd'hui, et elle
est plus forte : persistance **et** non-comptage dans les épisodes de boycott.

### Ce qui reste ouvert

| Point | Nature |
|---|---|
| Le **nom** « President Laroche » affirme une fonction qu'il peut perdre | identité — appartient à la passe Laroche |
| Le **cumul affiché** (présidence + autre poste nommé) | game design — `state.poste` est un emplacement unique |
| ~~Un **Président évincé de son siège** par trois députés PJ de sa ville~~ | **arbitré et fermé le 11 octobre au soir** |
| Le **calendrier du renouvellement** : hebdomadaire arbitré contre 5 semaines implémenté | game design — remonté, non implémenté |
| Le vote **législatif** lit la présence sans passer par `acteur_present_sur_site` | dette technique, sans conséquence aujourd'hui |
| Seb Lex, Lobbyiste Perrin, Journaliste Blanc, Archiviste parlementaire | **non traités**, réservés par l'arbitrage |

**Le bâtiment n'est pas clos.**
