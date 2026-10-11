# Assemblée nationale — deuxième passe : la séance parlementaire

**11 octobre 2026.** Registre Supabase 648 → 655 (sept migrations).
**Le bâtiment n'est pas clos** : l'audit continue.

---

## 1. Ce qui est livré

| Arbitrage | État | Où |
|---|---|---|
| §3 Report d'un vote par le Président — une semaine, une seule fois par texte | **livré** | `assemblee_reporter_vote` |
| §4 Séance : file de parole, parole donnée au premier, retrait, intervention sans autorisation | **livré** | `assemblee_paroles`, `assemblee_debats`, 4 portes |
| §5 Rappel au règlement — illimité, discrétionnaire, −15 POP, motif verbatim | **livré** | `assemblee_rappeler` |
| §6 Sanction — après rappel, −20 POP + 100 FR, consomme son rappel | **livré** | `assemblee_sanctionner` |
| §7 Protestation et solidarité de parti — déplacement réel, qualification serveur | **livré** | `assemblee_protester`, `assemblee_revenir` |
| §8 Suspension par boycott — 5 qualifiés, épisodes distincts, report d'une semaine | **livré** | `assemblee_recalculer_suspension`, `assemblee_reporter_si_suspendue` |
| §10 Suspension volontaire du Président — −20 POP, jamais un boycott | **livré comme ACTE** (voir §3 ci-dessous) | `assemblee_suspendre_seance` |
| §11 Autorité serveur, atomicité, concurrence | **livré** | 6 tables RLS sans policy, 4 index de règle, clefs d'idempotence |
| §12 Presse : des faits, le motif verbatim, aucune qualification | **livré** | `assemblee_discipline_matiere`, 2 types de chronique |

Côté client : **un écran plein de séance** (`plateau-assemblee-seance.js`), posé comme un ordre
à 0 PA / 0 FR dans l'hémicycle **et dans le hall** — le hall parce qu'un député sorti en
protestation s'y trouve, et que c'est de là qu'il doit pouvoir revenir.

**Toute la séance est isolée derrière une seule fonction**, `assemblee_president(pays)`, qui lit
le registre `postes_attribues`. Le jour où l'élection sera arbitrée, elle écrira cette ligne et
rien d'autre ne changera. Le poste n'a demandé **aucune plomberie neuve** : `poste_est_atteste`
traite déjà tout poste nommé par sa branche fail-closed.

---

## 2. Ce qui n'est PAS livré, faute d'arbitrage

### §1 — L'élection du Président de l'Assemblée

Le calendrier est arbitré et clair : renouvellement le dimanche à 00:00, convocation des neuf
députés le lundi à 00:01, scrutin ouvert jusqu'au lundi 23:00, dépouillement à 23:00, un seul
tour, décompte visible en direct. **Trois décisions manquent, et elles ne se devinent pas :**

1. **La mécanique de candidature.** L'existant ne tranche pas. `cycles_electoraux` porte des
   candidatures pour les postes électifs ordinaires, mais la présidence de l'Assemblée est un
   poste **nommé** (registre `postes_attribues`), élu par un collège de neuf, et aucune mécanique
   du jeu ne combine les deux. Faut-il une candidature **explicite** (un acte, un coût ?), ou
   les neuf députés sont-ils **candidats d'office** ?
2. **Le comportement électoral des neuf députés PNJ.** Six des neuf sièges peuvent être tenus par
   leur PNJ. Votent-ils ? Au hasard, par affinité de parti, pour le sortant, jamais ? Le jeu a un
   précédent — le vote PNJ POUR/CONTRE des scrutins législatifs — mais il porte sur un **texte**,
   pas sur une **personne**, et rien n'autorise à le transposer.
3. **Le cas où aucun joueur ne se présente.** La présidence reste-t-elle vacante — et alors toute
   la séance est muette, puisque tout passe par le Président ? Un PNJ la prend-il ? Le sortant
   est-il prorogé ?

### §2 — Le tirage à la courte paille

Dépend de §1 : sans élection, il n'y a pas d'égalité à départager. L'arbitrage de l'animation
(main tenant les pailles, halo qui ralentit, popup d'annonce, rattrapage différé pour les absents)
est **complet et implémentable tel quel** dès que §1 sera tranché.

### §9 — Deux suspensions = nouvelle élection

Le **compteur existe et il est exact** : `assemblee_seance` rend
`episodes_sous_cette_presidence`, et le banc vérifie qu'il vaut bien 2 après deux épisodes
distincts. **Rien ne se déclenche**, parce que déclencher une élection qui n'existe pas
ouvrirait une vacance sans moyen de la combler — un état bloqué, que l'arbitrage interdit
explicitement (§10). La valeur est donc rendue comme un fait, visible à l'écran.

### §10 — La durée et la reprise d'une suspension volontaire

L'arbitrage donne le coût (−20 POP), la décision (le Président seul), et le fait qu'elle ne compte
jamais parmi les deux. Il ne dit **ni combien de temps elle dure, ni comment la séance reprend**.

Et le jeu n'a **aucun objet « séance » porteur d'un état** : une session est l'ensemble des
propositions au statut `session`, et le registre ne connaît pas d'état « suspendue ». Inventer une
durée serait inventer une règle ; créer un état sans condition de sortie serait créer l'état bloqué
que le prompt interdit.

**La suspension est donc enregistrée comme un ACTE et non comme un ÉTAT** : le coût est prélevé,
le motif est conservé verbatim, l'épisode est horodaté et clos dans la même seconde, et il porte
`cause = 'presidence'` pour n'être jamais confondu avec un boycott. **Le point reste à arbitrer.**

---

## 3. Les lectures que j'ai dû faire, et qu'il faut valider

### Les « épisodes distincts » d'un boycott

L'arbitrage dit : 5 qualifiés dehors → suspension ; retour à 4 → la suspension cesse ; et
*« un même boycott ne doit pas pouvoir être artificiellement comptabilisé plusieurs fois par un
député faisant hall → hémicycle → hall »*. Les deux premières règles sont explicites, la troisième
est une interdiction sans méthode.

**Lecture retenue** : un nouvel épisode ne peut s'ouvrir qu'après **dissolution complète** du
groupe — plus aucun protestataire qualifié dehors. Sans cela, un seul député faisant l'aller-retour
ferait passer le compte de 5 à 4 puis à 5 et fabriquerait un second épisode en dix secondes, donc
une nouvelle élection présidentielle. C'est la seule lecture qui satisfait l'interdiction.

Elle vit à **un seul endroit** : `assemblee_recalculer_suspension`. Si elle ne convient pas, c'est
là et nulle part ailleurs qu'il faudra la changer. Le banc la couvre en trois épreuves (E14, E15, E16).

### La discipline ne s'adresse qu'aux députés JOUEURS

Ce n'est pas un choix, c'est un constat : **les neuf députés PNJ des sièges n'ont aucune fiche de
personnage**. Leur nom ne figure pas dans `personnages_donnees` — mesuré. Ils n'ont donc ni position
physique, ni popularité, ni argent. Un rappel contre eux ne pourrait ni vérifier leur présence dans
l'hémicycle, ni retirer 15 points ; une sanction ne pourrait pas prélever 100 FR.

Si un jour les députés PNJ doivent pouvoir être rappelés au règlement, **il leur faudra d'abord une
fiche**, et c'est un arbitrage séparé.

---

## 4. Les écarts découverts

### a) `organisations` est écrite par le navigateur

Le parti d'un député est **relu au serveur** (`assemblee_parti_de`), comme l'arbitrage l'exige.
Mais la table `organisations` est un blob ouvert à l'écriture de **tout joueur identifié** :
policy `organisations_maj_acteur`, `UPDATE USING acteur_identifie()`, **sans aucun contrôle de
propriété**. La liste des membres est donc lue au serveur et écrite par le client : un député
déterminé pourrait s'y inscrire pour se qualifier.

Fermer cette policy casserait tout le jeu des organisations. **Arbitrage séparé, signalé, non
tranché ici.** Consigné dans le commentaire de `assemblee_parti_de`.

### b) Trois défauts trouvés par les bancs, dont deux hors de cette passe

1. **Les cinq portes à effet n'avaient pas de clef d'idempotence** (défaut de ma propre première
   migration). Le socle client rejoue une action dont la réponse s'est perdue, avec le même
   identifiant : un rappel rejoué retirait **30 points** au lieu de 15, une sanction **40 points et
   200 FR**. Corrigé par une garde double — garde explicite avant toute écriture, et identifiant
   dérivé de l'empreinte de la requête, si bien qu'une course violerait la clé primaire et serait
   annulée entièrement.

2. **La discipline écrivait par la vue `personnages`**, dont le trigger refuse la fiche d'autrui
   hors appel serveur. **En production, le premier rappel au règlement de l'histoire aurait levé
   `personnage_non_possede` et rien ne se serait passé.** Corrigé en passant par le **registre des
   causes** (`personnage_ajuster_pop_inf` à cinq arguments), où trois causes neuves déclarent leur
   autorité et une amplitude **exacte** ; et l'amende passe par `helvetia_debiter_fonds_ordinaires`,
   la primitive générique de débit d'un tiers.

3. **ET LE REGISTRE DES CAUSES LUI-MÊME NE MARCHAIT POUR PERSONNE.** Défaut **préexistant**, sans
   rapport avec l'Assemblée. La porte écrivait une valeur **absolue** de popularité sans annoncer
   `popBase`, et le trigger `personnages_fusionner_pop` la restaurait en silence — tout en laissant
   la porte répondre `{ok: true}`. **Mesure faite avant correction : une rumeur de −10 points
   laissait la cible à 50.** Sept causes étaient inertes : `rumeur_pj`, `rumeur_gouvernement`,
   `excommunication`, `dementi_reussi`, `dementi_rate`, `sentence_torture`, `football_match`.

   La porte annonce désormais la base lue sous verrou — le trigger applique donc la **différence**,
   ce qui la rend aussi robuste à la concurrence — et **vérifie son propre effet** : un ajustement
   annulé répond `ecriture_annulee`. C'est la leçon de ce défaut : **il a survécu parce que la porte
   répondait que tout allait bien.**

### c) `helvetia_debiter_fonds_ordinaires` est générique et mal nommée

C'est la primitive du jeu pour prélever les fonds ordinaires d'un **tiers** (liquide puis Banque
nationale, écriture directe, refus sans effet si les fonds manquent). Son comportement est générique ;
son **nom** désigne une seule mécanique. Un futur arbitrage sur Helvetia pourrait donc changer en
silence le prélèvement d'une amende parlementaire.

**Dette consignée, hors de cette passe** : le bon correctif est un renommage en
`debiter_fonds_ordinaires` avec ses appelants. La recopier ici aurait été pire — une 43ᵉ copie
exécutée de la même cascade.

### d) `ordres_couts` : l'écran de séance n'y entre pas, et la déclaration a dérivé

`seance_parlementaire` coûte 0 PA / 0 FR. `deduireCoutOrdre` n'appelle `payer_ordre` que si
`pa > 0 || cost > 0` : l'écran ne traverse donc **jamais** la vérification du miroir, et y déclarer
un coût serait déclarer un coût qui n'existe pas. Il rejoint les ordres gratuits non déclarés.

**Écart de comptabilité signalé au passage** : le champ `lignes` de la déclaration annonce 407, la
base contient 406 lignes, et le générateur comptait 405 triplets avant cette passe. Les trois
nombres divergent, et la prose des mesures précédentes a dérivé avec eux. Le champ n'est pas
contrôlé — seul `data_js` l'est. **Recaler l'ensemble reviendrait à entamer la réparation du miroir,
qui est le travail du lot 4D.**

### e) Les six horodatages d'ordre étaient sur `now()`

`now()` rend l'heure de **début de transaction**. Trois demandes de parole posées dans la même
transaction portaient donc le même horodatage à la microseconde : **la file n'avait plus d'ordre**,
et la règle « le Président donne la parole au premier » devenait indémontrable. Le test de
dissolution complète d'un boycott avait le même problème — `close_le` valait exactement `sorti_le`.
Passés à `clock_timestamp()`. Les dates **métier** restent sur `now()`.

---

## 5. Points NON traités dans cette passe, par consigne

Les quatre écarts de la première passe sont intacts et attendent leur audit séparé :
vitrine 25 sièges / réalité 9 ; Seb Lex ; Lobbyiste Perrin / Journaliste Blanc / Archiviste
parlementaire ; corpus et personnalité du Président Laroche.

Le PNJ `President Laroche` porte `job: 'president_assemblee'` dans `data.js`. Il n'a **pas** été
touché : la transition PNJ → référent quand un PJ occupe le poste relève du même audit.

---

## 6. Les bancs

| Banc | Épreuves | Ce qu'il tient |
|---|---|---|
| `banc-seance-parole-discipline.sql` | **35** | rôles, file chronologique, le Président ne choisit pas son orateur, retour en fin de file après retrait, parler sans la parole sans aucune conséquence, rappel −15 et motif verbatim, sanction impossible sans rappel, atomicité des 100 FR, rejeu sans double coût, presse réservée et sans qualification |
| `banc-seance-protestation-suspension.sql` | **29** | déplacement réel, qualification serveur (soi-même / parti / rien), parti borné au pays, seuil 4 puis 5, retour à 4, **l'aller-retour ne fabrique pas d'épisode**, dissolution complète, report automatique qui ne consomme pas la prérogative, une seule fois par texte, suspension présidentielle jamais comptée comme boycott, portes système fermées aux joueurs |
| `banc-seance-client.js` | **57** | l'écran ne décide rien, ne qualifie rien, annonce le prix avant le clic, passe par le socle existant, et ne met jamais un texte joueur en `innerHTML` |

Les 39 bancs JS du dépôt sont verts. Les 11 contrôles du baseline sont verts.

---

## 7. À arbitrer pour continuer

1. **La mécanique de candidature** à la présidence de l'Assemblée (§1).
2. **Le comportement électoral des neuf députés PNJ** (§1).
3. **Le cas où aucun joueur ne se présente** (§1).
4. **La durée et la reprise d'une suspension volontaire** du Président (§10).
5. La lecture retenue des **« épisodes distincts »** d'un boycott (§3 ci-dessus) : à valider ou à
   remplacer.
6. La **forgeabilité du parti** par écriture cliente sur `organisations` (§4a).
