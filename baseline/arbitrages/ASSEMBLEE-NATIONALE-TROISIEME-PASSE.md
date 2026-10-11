# Assemblée nationale — troisième passe : l'élection de la présidence

**11 octobre 2026.** Registre Supabase 655 → 659 (quatre migrations).
**Le bâtiment n'est pas clos** : l'audit continue.

---

## 1. Les trois décisions qui manquaient sont rendues

| Arbitrage | État | Où |
|---|---|---|
| §2 **Aucune candidature** — les neuf députés éligibles d'office | **livré** | `assemblee_presidence_eligibles` |
| §3 Les députés PNJ **s'abstiennent systématiquement** | **livré** | aucun bulletin PNJ n'est écrit, et une preuve l'interdit |
| §4 Calendrier : convocation lundi 00h01, scrutin jusqu'à 23h00, un tour, décompte visible | **livré** | `assemblee_presidence_convoquer` / `_fenetre_convocation` / `_depouiller` |
| §5 **Courte paille** entre les seuls ex æquo en tête, tirée par le serveur | **livré** | `assemblee_presidence_depouiller` |
| §6 Joueur absent : révélation différée, **une seule fois**, état serveur | **livré** | `assemblee_presidence_tirage_vu` + 6ᵉ consommateur de l'événement d'entrée |
| §7 **Deux boycotts = nouvelle élection** | **livré** | `assemblee_recalculer_suspension` → `assemblee_presidence_dues` |
| §8 **Suspension présidentielle persistante** + « Reprendre la séance » | **livré** | `assemblee_suspendre_seance` / `assemblee_reprendre_seance` |
| §9 **Autorité serveur de l'appartenance aux partis** | **livré** | `trg_organisations_politique_autorite` |
| §10 Transition du titre et des pouvoirs | **livré** | le dépouillement écrit `postes_attribues`, et rien d'autre ne change |
| §11 **Vitrine 25 → 9 sièges** | **livré** | `consulterAnnuaireDeputes` lit la composition réelle |

---

## 2. Neuf députés, pas neuf plus un

La présidence **n'est pas un dixième siège** : c'est une fonction portée par l'un des neuf.
`assemblee_presidence_eligibles(pays)` dérive les neuf sièges et rien d'autre ; le scrutin comme
le dépouillement **refusent tout nom qui n'en vient pas**. Deux preuves structurelles vérifient
9 éligibles / 3 par ville à chaque migration future.

Un siège tenu par un **député joueur** n'est plus proposé sous le nom de son PNJ : le député
**remplace** son suppléant, il ne s'y ajoute pas. Sans cette règle il y aurait douze noms au
scrutin — le banc le vérifie (É5).

Le dépouillement écrit `postes_attribues` — **la seule ligne que la séance regarde** — donc les
pouvoirs de séance, de discipline, de report et de suspension changent de main immédiatement, et
l'ancien Président les perd dans la même transaction. Une preuve vérifie qu'il ne touche **ni**
`poste_depute` **ni** `assemblee_sieges` : **perdre la présidence n'est pas perdre son siège.**

---

## 3. La sous-partie ARRÊTÉE : le siège du Président Laroche

**Audit fait, et il est net.** Le Président Laroche n'existe que dans deux endroits :

| Source | Ce qu'elle dit |
|---|---|
| `data.js:2796` | un figurant de l'hémicycle : `{name:'President Laroche', role:"President de l'Assemblee (PNJ)", job:'president_assemblee'}` |
| `api/_pnj-referents.js:258` | un profil de dialogue : rôle, tempérament, style — **aucun lieu, aucune ville** |

**Et nulle part ailleurs.** Mesuré en base : aucune ligne dans `titulaires_pnj`, aucune dans
`postes_attribues`, aucune dans `assemblee_sieges`, aucune dans `pnj_membres`, aucune dans
`pnj_candidats_catalogue`. Sa ville d'origine **n'est pas déterminable par les données**.

**Deux décisions vous appartiennent donc :**

1. **Quelle ville ?** Luthécia, Montrouge ou Port-Sainte-Marie.
2. **Quel PNJ remplace-t-il ?** Les neuf sièges sont tous occupés — il faut en libérer un :

| Ville | Siège 1 | Siège 2 | Siège 3 |
|---|---|---|---|
| **Luthécia** (`capitale`) | Étienne Vauclerc | Sophie Maréchal | Benoît Delorme |
| **Montrouge** (`ville_a`) | Yann Legall | Maëlle Leroux | Loïc Kermeur |
| **Port-Sainte-Marie** (`ville_b`) | Nathalie Charron | Gérard Pichon | Élodie Vasseur |

Le choix a une incidence de game design : ces neuf noms sont ceux que les joueurs voient depuis
un mois, et trois d'entre eux ont déjà reçu des voix dans les bancs de cette passe. Je n'en ai
donc supprimé aucun.

**Ce qui est déjà prêt pour la bascule** : le jour où la ville et le PNJ seront choisis, le
changement est **une ligne de `ASSEMBLEE_SIEGES` et une ligne de seed** — toute la machinerie
(éligibilité, double titre, élection) lit déjà les neuf sièges sans savoir qui les occupe.

**Conséquence en attendant** : l'hémicycle affiche toujours les 9 cartes de députés **plus**
Laroche, soit dix parlementaires — et son étiquette annonce une présidence que le registre ne lui
accorde pas (`postes_attribues` ne contient aucune ligne `president_assemblee`). Je n'ai pas
touché son étiquette : la changer serait traiter son identité, ce que cette passe exclut.

---

## 4. La courte paille

- **Le serveur tire, et personne d'autre.** `ORDER BY random() LIMIT 1` sur les seuls ex æquo
  **en tête**, à 23h00, écrit dans `elu` et `egalite`. Une preuve vérifie que le tirage se borne
  aux ex æquo (`= v_max`).
- **Le navigateur rejoue, il ne tire pas.** Pas un seul `Math.random` dans
  `plateau-assemblee-presidence.js` — le banc client le vérifie. Le halo atterrit sur
  `pailles.indexOf(gagnant)` : le nombre de pas est calculé pour finir là, il n'est pas tiré.
- **Animation** : main stylisée + une paille par ex æquo, halo qui circule et **ralentit**
  (`Math.pow(t, 2.4)`), arrêt sur la paille du vainqueur, **puis** cette paille se révèle courte
  — jamais avant. Seconde popup annonçant le Président ; la fermer ferme tout, rafraîchit la pièce
  et les titres de la liste latérale.
- **Aucun asset graphique n'a été inventé** : tout est en HTML/CSS, et une preuve de banc
  vérifie qu'aucune image n'est référencée. **Une vraie illustration de main tenant des pailles
  serait plus belle** — c'est la seule demande d'asset de cette passe.
- **Absent à 23h** : popup « Assister au tirage » à son retour à l'Assemblée (6ᵉ consommateur de
  `declencherEntreeZone`, on ne pose pas un crochet de plus). **Une seule fois par joueur et par
  scrutin**, état en base — il survit à un rafraîchissement, à un changement de machine et à un
  onglet fermé trop vite. Le banc vérifie aussi qu'un joueur qui a vu ne prive pas l'autre.

---

## 5. Zéro votant : une conséquence, pas une règle neuve

La bêta peut n'avoir **aucun député joueur**. Les règles arbitrées disent : « candidat seul en
tête ⇒ élu ; égalité en tête ⇒ tirage ». Avec zéro bulletin, **les neuf sont à égalité à zéro
voix**, et la courte paille les départage tous les neuf.

C'est la **conséquence mécanique** des règles rendues, pas une règle ajoutée — et c'est aussi la
seule lecture qui ne crée pas d'état bloqué : une présidence vacante rendrait la séance
entièrement muette, puisque tout y passe par le Président. Les deux dernières épreuves du banc
de l'élection la mesurent. **Si cette conséquence ne vous convient pas, c'est un arbitrage à
rendre** — elle vit à un seul endroit.

---

## 6. La suspension présidentielle

Elle **persiste** maintenant que sa sortie est arbitrée.

**Ce qu'elle suspend** : demander, donner et retirer la parole ; le débat (y compris pour le
Président, qui a « Reprendre la séance ») ; le rappel et la sanction — la police d'une séance qui
ne siège pas n'a rien à policer. Six portes, six preuves.

**Ce qu'elle ne suspend pas, et c'est délibéré** : quitter l'hémicycle et y revenir restent des
actes **physiques** — une suspension n'enferme personne — donc le seuil de boycott continue de se
compter ; et le report d'un vote reste une prérogative sur le **calendrier**, pas un acte de séance.

**Elle n'est jamais un boycott** : `assemblee_suspendue` continue de ne regarder que les boycotts,
et deux preuves vérifient que le report automatique du mercredi l'ignore.

### ⚠ Le point non arbitré, non deviné

**Un scrutin qui arrive à échéance pendant une suspension présidentielle.** Le boycott a sa règle
explicite — le vote part d'une semaine. La suspension présidentielle **n'en a aucune**. Le
comportement est donc **inchangé** : le dépouillement du mercredi se tient. Créer un report
supplémentaire aurait été inventer une règle. **À arbitrer.**

**Asymétrie signalée** : pendant un boycott, la parole continue (l'arbitrage ne dit que « aucun
vote ne peut conclure ») ; pendant une suspension présidentielle, elle s'arrête. C'est fidèle aux
deux arbitrages, mais c'est une asymétrie à valider.

---

## 7. L'autorité de l'appartenance aux partis

**La faille de la deuxième passe est fermée à la source.**

`organisations` est un blob ouvert à l'écriture de tout joueur identifié
(`organisations_maj_acteur`, `UPDATE USING acteur_identifie()`, sans contrôle de propriété). Un
député pouvait s'inscrire dans le parti d'un député sanctionné pour devenir « protestataire
qualifié », contribuer à suspendre la séance, et au deuxième épisode remettre la présidence en jeu.

**La policy n'a PAS été fermée**, et l'audit dit pourquoi : `sbSaveOrganisation` écrit le blob
**entier** depuis le navigateur, depuis six endroits du jeu, et la table mélange création,
demandes d'adhésion, invitations, grades, élections internes, caisse, influence et statut de grève
générale. Deux organisations sont même créées **avec un PNJ pour fondateur**, depuis le navigateur
d'un joueur ; et les élections internes se résolvent dans le navigateur de **n'importe quel**
joueur. Une fermeture aveugle aurait cassé tout cela.

**C'est donc la vérité qui est gardée, pas la porte.** Un déclencheur, pour les organisations
**politiques** et les seules écritures **clientes** :

| Acte | Qui peut |
|---|---|
| Ajouter un membre | le **chef** ; ou soi-même **si le chef a posé une invitation** ; ou un **PNJ recruté** par un membre |
| Poser une invitation | le **chef** seul — sans quoi la règle du dessus ne vaudrait rien |
| Retirer un membre | le **chef** ; ou soi-même (on quitte un parti quand on veut) |
| Changer la direction | le **chef** ; ou une **élection interne réellement en cours**, vers un membre **déjà présent** |
| Dissoudre | le **chef** ou le fondateur |

La distinction joueur / PNJ se fait sur une **lecture de `personnages_donnees`**, jamais sur un
drapeau du blob — qu'un client pourrait poser lui-même. Et les appels **serveur** passent toujours :
la cotisation nocturne retire un membre qui n'a pas payé, et elle ne doit pas tomber chaque nuit.

### Dette restante, assumée et nommée

Les organisations **non politiques** — syndicats, loges, clubs, supporters — **restent forgeables
de la même manière**. Elles ne sont pas protégées parce que leurs flux n'ont pas été audités un par
un. **Aucune règle institutionnelle ne dépend aujourd'hui de leur composition** — c'est ce qui rend
cette dette tenable. Le jour où l'une en dépendra (le décompte d'adhérents d'une grève générale est
le candidat le plus proche), il faudra l'étendre.

---

## 8. La vitrine

L'« Annuaire des Députés » annonçait **25 sièges** et en listait 25, lus sur
`state.postes['depute_1'..25]` — des clés **décoratives** que rien n'alimentait, jamais connectées
au système électoral. Il affichait donc « Occupé par un PNJ » vingt-cinq fois.

Il lit désormais la **composition réelle**, par la **même fonction de rang** que l'hémicycle
(`assembleeCalculerOccupation`), groupée par ville, et marque le Président — avec la mention
explicite que **la présidence est une fonction, pas un siège de plus**. La description du bâtiment
dans `data.js` annonce les neuf sièges.

---

## 9. Ce qui reste à arbitrer

1. **La ville de Laroche** et **le PNJ qu'il remplace** (§3 ci-dessus) — sous-partie arrêtée.
2. **Un scrutin à échéance pendant une suspension présidentielle** (§6) — comportement inchangé
   faute de règle.
3. **L'asymétrie parole / boycott** (§6) — fidèle aux arbitrages, mais à valider.
4. **Zéro votant ⇒ tirage entre les neuf** (§5) — conséquence mécanique, à confirmer.
5. **Le cumul** présidence + autre poste nommé : `state.poste` est un emplacement unique, et
   l'adoption du titre n'écrase jamais un poste existant. Un député-Président qui serait aussi
   ministre ne verrait donc qu'un seul de ses deux titres sur sa fiche.
6. **Le vote présidentiel n'exige pas la présence** dans l'hémicycle — l'arbitrage ne le demande
   pas, le vote législatif si. À harmoniser ou à laisser.
7. La **forgeabilité des organisations non politiques** (§7).

---

## 10. Les bancs

| Banc | Épreuves | Ce qu'il tient |
|---|---|---|
| `banc-presidence-election.sql` | **35** | 9 éligibles / 3 par ville, le PNJ d'un siège tenu par un PJ cesse d'être éligible, aucune candidature, vote pour soi / pour un PNJ, double vote refusé et voix conservée, aucun bulletin PNJ, décompte en direct sans révéler qui a voté pour qui, bulletin tardif refusé, courte paille bornée aux ex æquo en tête, résultat stable, registre écrit, mandat intact, révélation différée une seule fois par joueur, une voix suffit, **zéro votant n'ouvre pas de vacance** |
| `banc-presidence-suspension-partis.sql` | **37** | suspension −20 POP et persistante, pas deux fois, six portes muettes pendant la suspension, actes physiques préservés, aucun report, reprise sans coût, rejeu propre, 5→4→5 et 5→3→1→5 = même épisode, retour à 0 puis 5 = second épisode ⇒ élection due, présidence inchangée hors élection, **l'attaque du parti est fermée** (6 épreuves), flux légitimes intacts, organisations non politiques libres, serveur toujours autorisé |
| `banc-presidence-client.js` | **64** | aucune candidature, **aucun `Math.random`**, le halo atterrit sur l'index de l'élu, aucun asset image, état « vu » serveur et jamais en `localStorage`, fermeture qui rafraîchit, vote par le socle avec clef de requête, aucune qualification, `textContent` partout et **aucun `innerHTML`**, 9 sièges et non 25, double qualité, **aucun nom codé en dur** |

Et un décor neuf, `outils/bancs/decor-window.js`, sur le modèle de `decor-env-serveur.js` : plusieurs
modules du plateau touchent `window` **au chargement**, et un banc qui le posait depuis son propre
corps arrivait trop tard.

Les **41 bancs JS** du dépôt sont verts. Les **11 contrôles** du baseline sont verts.
