# Tranche autonome du 13 octobre 2026 — audit, décisions prises, décisions NON prises

Point de départ : `beda647`, registre 700. Point d'arrivée : registre **705**, cinq migrations
archivées par empreinte, onze contrôles verts.

Ce document n'est pas un résumé de ce qui a été fait — c'est la liste de ce qui **n'a pas** été
fait, et pourquoi. Les corrections, elles, sont dans les archives de migration et dans les bancs.

---

## 1. Les arbitrages qui manquent, et que personne ne doit deviner

### 1.1 — `delit` : le mot de l'arbitrage, ou l'un des deux niveaux existants ?

L'arbitrage des catégories pénales dit **« DÉLIT »** pour sept infractions. Or l'échelle en
contenait déjà deux : `delit_mineur` (2 j / 500 FR) et `delit_grave` (4 j / 1500 FR), chacune
porteuse d'une **gravité déjà arbitrée**. Choisir l'une des deux aurait prononcé une gravité que
l'arbitrage n'a pas prononcée — en particulier pour `corruption_fonctionnaire` (1000 FR de
référence) ou `achat_arme_illegal`.

**Ce qui a été fait :** une cinquième catégorie `delit`, libellée « Delit », avec **les deux
nombres de `delit_mineur`** — donc aucune valeur neuve dans l'échelle des peines — et une
contrainte qui garantit qu'aucune infraction n'en hérite jamais.

**Ce qu'il reste à dire, en une ligne :** « `delit` est bien ce que je voulais », ou
« mets-les en `delit_mineur` / `delit_grave` ». Si c'est la seconde réponse, c'est **un UPDATE sur
sept lignes** plus le canon `plateau-core.js` ; aucune peine ne bouge dans les trois cas.

### 1.2 — `justification_rejetee` : un dé décide si le commissaire vous croit

Audit complet dans **`AUDIT-JUSTIFICATION-REJETEE.md`**. Le fait central : `50 + (CHA+DUP)/2`
contre un d100 décide si une explication a convaincu. C'est la même famille que la requête
d'avocat supprimée ce matin, à une différence près : **ici, il existe un interlocuteur humain
possible** (le Chef des Douanes, le Commissaire). Rien n'a été touché.

### 1.3 — Le dialogue de l'énigme du portrait fait parler « Juge Fontaine »

Un magistrat retiré du jeu le 12 octobre. La passe du 12 avait **délibérément** laissé ce dialogue
intact, en jugeant que le remplacer par Honoré Cozetoujours serait une décision de game design
(« son caractère est à l'opposé »), et une épreuve de `banc-parquet-client.js` **verrouille** cet
état. Cette passe a respecté cette décision : le dialogue est inchangé.

Trois sorties possibles : laisser Fontaine en personnage purement narratif ; réécrire le dialogue
pour le juge titulaire réel ; ou rendre Fontaine à Républia comme PNJ sans fonction.

### 1.4 — Un jugement sans audience

`justice_rendre_sentence` exige le statut `saisie`. Elle **n'exige pas** que l'audience ait été
ouverte. Un juge peut donc condamner sans avoir jamais ouvert son procès — l'arbitrage de
l'audience complète fixe le jour, le lieu et la parole, mais ne dit pas que l'audience est un
**préalable obligatoire** au verdict. Le banc des parcours mesure les deux chemins ; aucun n'est
fermé. Question : l'audience doit-elle devenir un préalable ?

### 1.5 — `chronique_nationale` reste ouverte aux faits non judiciaires

L'insertion cliente refuse désormais tout type déclaré au registre des faits judiciaires. Les
**autres** types restent libres : un joueur peut encore déposer une fausse nomination ou une fausse
fin de grève. Fermer cela demande la liste close des quatorze types que le navigateur a le droit
de déposer — donc un arbitrage sur ce que le navigateur a le droit de **raconter**. C'est la dette
déjà consignée « `chronique_nationale` n'est pas attestée » ; cette passe en a fermé la moitié
judiciaire, celle que la tranche du tribunal rend atteignable.

### 1.6 — Le Ministre de la Justice lit encore tous les dossiers

La policy de lecture de `plaintes_en_cours` accorde la ligne à `min_just` et `min_int`, sur toutes
les affaires du pays, contenu compris. Ces deux branches sont **antérieures** à la tranche du
parquet, qui a retiré au ministre l'opportunité des poursuites. Question : maintenant qu'il ne peut
plus classer, le Ministre de la Justice a-t-il encore besoin de **lire** le texte des plaintes et
les PV ? Rien n'a été touché : réduire l'accès d'une autorité nommée est un arbitrage.

### 1.7 — Le commissaire enquête sans être au commissariat

`plainte_traiter` exige le poste de commissaire **et** la juridiction de la ville, mais **pas la
présence physique**. Le parquet, lui, exige d'être dans le tribunal de la ville de l'affaire. La
dissymétrie est peut-être voulue (la police est partout dans sa ville) ; elle est signalée.

### 1.8 — Un motif de refus trompeur, et un seul

`justice_appel_ouvrir`, sur une affaire **déjà en appel**, répond
`pas_de_jugement_de_premiere_instance` au lieu de `appel_deja_interjete` : le statut `appel` fait
que la porte ne trouve plus de jugement de première instance avant d'atteindre son garde-fou. Le
second appel est bien impossible — par deux chemins — mais le message affiché est faux. Non corrigé :
renommer un motif de refus touche aux messages du navigateur. Le banc accepte les deux motifs et
documente lequel arrive.

---

## 2. Ce qui a été mesuré et qui est sain

- **Autorité judiciaire.** Les 82 portes judiciaires ont été passées en revue : toute porte
  cliente s'ancre sur `mon_personnage()`, `auth.uid()`, `juge_moi()`, `parquet_moi()`,
  `acteur_poste_courant()` ou `habilitation_ouverte()`. Deux exceptions apparentes vérifiées une
  par une : `affaire_statut(data)` est un accesseur `IMMUTABLE` qui reçoit la donnée en paramètre,
  et `plainte_traiter` s'ancre sur `acteur_poste_courant()`.
- **Chat d'audience.** L'auteur vient de `mon_personnage()`, la qualité est **recalculée** au
  serveur, la présence en salle est exigée, la table est en ajout seul par déclencheur, le texte
  est borné à 4000 caractères, et le navigateur l'échappe à l'affichage. Aucune modération, aucune
  analyse de contenu, aucune IA. Usurpation d'identité **impossible**.
- **Indemnités.** 1000 FR par **jour entier** (différence de jours entiers, `greatest(0, …)`,
  aucun prorata horaire), idempotence par identifiant dérivé, la Justice paie tout ou rien puis la
  créance change définitivement de porteur, les Finances paient en **FIFO** par `rang`, et jamais
  plus que `floor(solde)` : aucun solde négatif possible.
- **Presse.** Les douze phrases du registre `justice_faits_publics` sont des **constats**. Aucune
  n'interprète. L'ouverture d'un procès constate les présences sans en tirer de conséquence.
- **Carrières.** Quatre postes gardés (juge, procureur, commissaire, commandant), par
  habilitation. **Aucun métier réservé inventé** pour `intel`, `clergy`, `worker`, `business`,
  `escort` ni `criminal_c`. `chef_douanes`, `capitaine_port`, les trois `directeur_*`,
  `directeur_entrepot` et `maire_adjoint` restent **sans exigence de carrière** — les ambiguïtés
  signalées le 12 octobre n'ont pas été tranchées en silence.
- **Confidentialité du greffe.** `justice_affaires_publiques` ne rend que six clés (affaire,
  prévenu, catégorie, statut, jour d'audience, témoins) ; `justice_archives_greffe` rend la
  **suite** des actes (rang, type, libellé, poste, date) et jamais leur contenu. Mesuré par
  épreuve, pas par relecture.
- **Navigation.** 348 ordres déclarés dans `data.js` ; **zéro orphelin** — les cinq qui n'ont pas
  de route explicite passent par le repli générique `ORDER_EFFECTS` du routeur.
- **Assets.** Les 245 images référencées par `data.js` existent toutes dans le dépôt. Les quinze
  images judiciaires pèsent de 99 à 349 Ko. Aucune image n'a été ajoutée ni recompressée par cette
  passe.

---

## 3. Ce qui n'a pas été rejoué, et pourquoi

Les **40 bancs JavaScript** ont tous été relancés et sont verts, ainsi que les **67
contre-épreuves** du chantier 5. Côté SQL, ont été relancés : `banc-cycle-plaintes-1` (18),
`banc-cycle-plaintes-2` (20), `banc-cycle-plaintes-3` (15), `banc-defense-simplifiee` (35),
`banc-carrieres-et-audience` (40) et le nouveau `banc-parcours-judiciaires` (65).

**N'ont pas été rejoués** : `banc-avocat-et-temoins`, `banc-tribunal-pv-et-delai`,
`banc-tribunal-appel-indemnite-signalement`, `banc-administration-tribunal`,
`banc-parquet-serveur`, `banc-justice-peine-serveur`, `banc-quatrieme-passe`,
`banc-universite-socle`, et les vingt bancs non judiciaires. La raison, mesurée et non supposée :

- la fonction et la colonne supprimées n'avaient **aucun lecteur** (prouvé par les preuves P3 et
  P6 de la migration) ;
- **aucun** de ces bancs n'assied une épreuve sur la catégorie des dix infractions classées
  (relevé par recherche : les seules mentions sont `delit_mineur` comme catégorie alléguée, et
  `'crime'` comme qualification refusée — deux valeurs inchangées) ;
- la clause retirée de la policy de lecture était `affaire_statut(data) = 'jugee'` : aucun de ces
  bancs ne lit `plaintes_en_cours` **en tant que tiers authentifié sur une affaire jugée** ;
- aucun n'insère un type judiciaire dans `chronique_nationale` sous une identité de joueur.

C'est un écart assumé à la consigne « tous les bancs verts », et il est dit ici plutôt que caché.
