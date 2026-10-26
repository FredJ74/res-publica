# Architecture de Human Gambit — état du socle

*26 octobre 2026. Référence commune à Codex, Claude et ChatGPT, pour coder les empires
suivants sans rien réinventer. À lire avec `CONSTITUTION.md`. Version illustrée : la page
« Architecture de Human Gambit » publiée par Claude pour Fred.*

**En chiffres** : 93 bâtiments, 249 pièces, 846 ordres dans les pièces (346 actions
différentes), 357 tables et 1 058 fonctions dans la base, 57 fichiers dans le navigateur.

## Les couches

À lire de bas en haut : chaque couche ne s'appuie que sur celles du dessous. Les couches 1
à 3 sont communes à tous les empires ; la couche 4 se réécrit pour chacun (Constitution,
article 7 : les mécaniques se partagent, les contenus jamais).

| Couche | Contenu |
|---|---|
| **5. Entre empires** (raccordé avec les autres empires) | ambassades (ouverture, ambassadeur, audience, asile, réception, mécénat) ; diplomatie (Indice Diplomatique par pays, négociations, traités) ; guerres (déclaration, trêve, cessez-le-feu, mobilisation) ; **voyage entre empires : n'existe pas** (bloque immunité, arrestation de l'expulsé, naturalisation, transfert de détenus) ; commerce international et tourisme prévus |
| **4. Contenu d'un empire** (jamais partagé) | géographie (3 villes, caserne, QHS, plans, rues, images) ; PNJ (noms, portraits, fiches de personnalité, référents, bibles) ; culture (monnaie, religion d'État, médias, clubs, scandales types) ; économie locale (entreprises, usines, chaînes, prix) ; institutions (noms des postes, grades d'organisations, sièges, calendrier électoral) ; énigmes de ville |
| **3. Mécaniques de jeu** (communes, paramétrées par empire) | vie du personnage, économie et travail, argent, territoire, pouvoir, justice et ordre, crime, armée, presse et opinion, organisations, foi, sport, renseignement, vie sociale |
| **2. Moteur** (socle technique, Constitution art. 4) | identité et autorité ; temps (jour de jeu par pays, passe de minuit, échéances) ; argent (paiement des ordres, comptes, caisses, fonds en transit) ; biens (inventaire) ; lieux et présence ; mémoire et messages (mails à boutons, forum, chat, journal, chronique) ; ordres (catalogue par pièce, coûts déclarés, routeur) ; intérim des PNJ ; indices |
| **1. Infrastructure** | navigateur (`plateau.html` et `plateau-*.js`, `data.js`, `supabase.js`, `forum.js`) ; base Supabase (fonctions `SECURITY DEFINER`, la seule vérité) ; serveur Vercel (`api/` : dialogues PNJ DeepSeek, journal, conférences, renseignements) ; tâches de nuit (`api/cron-minuit.js`, 26 traitements ; `api/cron-assemblee.js`) |
| *Transversal* | administration (incarnation, journal d'administration) ; offre premium (cosmétique et confort, jamais pay-to-win dans les empires non payants) ; traduction (prévue après Républia) |

## Inventaire des mécaniques

État au 26/10/2026, d'après `AUDIT_UNE_SEULE_VERITE.md` : **Serveur** = tenue par le
serveur ; **Mixte** = serveur, avec des parties décidées par l'écran ; **Écran** = décidée
surtout par le navigateur ; **À créer** = n'existe pas. Classement d'ensemble : une même
mécanique peut contenir des parties plus ou moins solides.

### Moteur

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Identité et autorité | Reconnaît le joueur, son poste, sa présence sur place ; refuse ce qu'il n'a pas le droit de faire. | Serveur | Rien : commun. |
| Temps | Jour de jeu par pays, passe de minuit, échéances en temps réel. | Mixte | Date de départ de l'empire ; l'ajouter à la passe de minuit. |
| Paiement des ordres | Prélève PA et francs selon le coût déclaré de chaque ordre. | Serveur | Coûts des ordres propres à l'empire. |
| Caisses | Caisses des bâtiments et des institutions ; un crédit doit venir d'un paiement réel. | Serveur | Caisses de ses institutions. |
| Inventaire | Objets possédés, donnés, consommés, confisqués. | Mixte | Objets propres (armes, reliques, produits). |
| Lieux et présence | Bâtiments, pièces, déplacements, qui est où. | Mixte | Plan, rues, bâtiments, images. |
| Messagerie | Mails à boutons d'action, forum, chat de pièce, salons. | Serveur | Rien : commun. |
| Mémoire publique | Journal personnel, chronique nationale, annonces publiques. | Mixte | Rien : commun. |
| Ordres | Catalogue des actions par pièce, routeur, ordre générique. | Mixte | Ordres adaptés à l'histoire de l'empire. |
| Intérim des PNJ | Un PNJ tient un poste vacant en attendant un joueur. | Mixte | Noms et portraits des titulaires PNJ. |
| Dialogues des PNJ | Conversations des PNJ par DeepSeek, avec fiches de personnalité. | Serveur | Fiches de personnalité, bibles de contexte. |
| Indices | Sécurité, économie, social, piété, moral par ville ; Indice Diplomatique par pays. | Mixte | Valeurs de départ. |

### Vie du personnage

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Création | Origine, école, archétype, carrière, caractéristiques. | Mixte | Origines et écoles du pays. |
| Santé, moral, popularité | Points de vie, moral, popularité, influence, discrétion. | Écran | Rien : commun. |
| Université | Cursus, jalons, seconde carrière, qualifications. | Serveur | Établissements et cursus. |
| État civil | Mariage, naissance, décès, succession, testament. | Mixte | Rien : commun. |
| Quêtes et énigmes | Quête d'accueil, quête de carrière, énigmes de ville. | Mixte | Énigmes et référents propres. |

### Économie et travail

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Entreprises et commerces | Commerces de joueurs, prix, stocks, ventes. | Serveur | Entreprises et commerces du pays. |
| Usines et chaînes | Production, matières, directeurs, ventes directes. | Serveur | Usines et chaînes du pays. |
| Entrepôts et ressources | Stocks régionaux, prix, matières premières. | Serveur | Ressources disponibles, prix. |
| Port et fret | Caisses de fret, douane, contrebande, lots non réclamés. | Écran | Ports et routes. |
| Bureau de l'Emploi | Postes à pourvoir, annonces, référentes. | Serveur | Agences et référentes. |
| Chantiers | Travail à l'heure, taux du propriétaire, ouvriers PNJ. | Serveur | Rien : commun. |

### Argent

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Banques | Comptes, virements simples et automatiques. | Serveur | Banques du pays. |
| Prêts | Prêts bancaires, mensualités, saisies. | Mixte | Banques et taux. |
| Fiscalité | Taxes locales et nationales, recettes, répartition. | Mixte | Déclarer le circuit national de l'empire. |
| Budgets publics | Budgets nationaux, municipaux, des clubs. | Mixte | Institutions et répartitions. |

### Territoire

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Terrains et construction | Achat, permis, chantier, réception, occupation. | Serveur | Terrains par ville. |
| Locations et logements | Baux, loyers, logement social. | Mixte | Parc de logements. |

### Pouvoir

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Postes et nominations | Candidatures, nomination, protection de 7 jours, révocation. | Serveur | Postes du pays et leurs recruteurs. |
| Élections | Cycles, candidatures, votes, fraudes. | Mixte | Calendrier, postes électifs. |
| Assemblée nationale | Sièges, lois, séances, votes. | Serveur | Sièges et calendrier ; fermée sans eux. |
| Gouvernement et présidence | Ministères, décrets, mesures d'exception, vote de confiance, banquets. | Mixte | Ministères, palais. |

### Justice et ordre

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Plaintes et enquêtes | Dépôt, enquête, transmission au tribunal. | Mixte | Rien : commun. |
| Police | Interception, contrôle, avis de recherche. | Mixte | Commissariats, profils de policiers. |
| Tribunal et greffe | Procès, juges, avocats, témoins, casier, archives. | Serveur | Tribunaux. |
| Prison et QHS | Détention, évasion, codétenus, haute sécurité. | Mixte | Établissements pénitentiaires. |
| Grâce | Recommandation du ministre, décision du président. | Mixte | Rien : commun. |

### Crime

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Actes illégaux | Vol, poison, assassinat, incendie, explosifs, contrebande, falsification. | Écran | Objets et lieux du marché noir. |
| Corruption | Douaniers, fonctionnaires, presse, greffe. | Écran | Rien : commun. |
| Organisations criminelles | Mise en relation, recrutement. | Serveur | Organisations du pays. |

### Armée

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Carrière militaire | Grades, unités, engagement, solde, désertion. | Serveur | Grades et unités. |
| Opérations | Missions, combats, armurerie, ravitaillement, effort de guerre. | Serveur | Matériel et casernes. |

### Presse et opinion

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Journal et rédaction | Journal du matin généré, articles, petites annonces, étouffement. | Mixte | Titres de presse du pays. |
| Communication officielle | Tribunes, conférences de presse, propagande. | Serveur | Tribunes et salles. |
| Rumeurs et scandales | Rumeurs, calomnies, scandales, démentis. | Écran | Scandales types. |

### Organisations

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Organisations | Cinq types, grades, adhésion, puissance. | Mixte | Grades par empire. |
| Grèves et manifestations | Grèves ordinaires et générales, manifestations, répression. | Mixte | Rien : commun. |

### Foi

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Cultes | Piété, dons, confession, bénédiction, excommunication. | Mixte | Religion d'État et lieux de culte. |

### Sport

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Football | Clubs, licences, entraînements, matchs en direct, championnat, transferts, supporters. | Mixte | Clubs et stades. |

### Renseignement et social

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Renseignement | Informateurs, cellules, rapports. | Mixte | Services du pays. |
| Vie sociale | Saluer, dîners, escortes, dons, contacts, débauchage. | Mixte | Agences et PNJ. |

### Entre empires

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Ambassades | Ouverture, ambassadeur, audience, asile, réception, mécénat. | Serveur | Ambassades et ambassadeurs PNJ. |
| Diplomatie et guerres | Indice Diplomatique, propositions, traités, guerres, trêves. | Serveur | Rien : commun. |
| Voyage entre empires | N'existe pas encore. | À créer | À créer une seule fois, pour tous. |

## Coder un nouvel empire

1. **Écrire le contenu, pas les mécaniques** : tout ce qui est en couche 4.
2. **Déclarer l'empire dans la donnée** : une mécanique ne tourne dans un empire que si sa
   configuration existe (fiscalité, Assemblée, circuit national). Aucun repli silencieux
   sur Républia (`baseline/arbitrages/AUDIT-FALLBACKS-REPUBLIC.md`).
3. **Retirer les « Républia par défaut »** : onze paramètres SQL `DEFAULT 'republic'` et le
   circuit national écrit en dur dans la passe de minuit (`baseline/arbitrages/AUDIT-EMPIRES-4G.md`).
4. **Adapter les ordres au contexte de l'empire** : mêmes mécaniques, libellés et ordres
   choisis selon l'histoire du pays.
5. **Raccorder les liens entre empires** : ambassades, guerres, traités, puis le voyage
   entre empires.

**Avant de dupliquer, finir le socle**, sinon chaque défaut sera recopié autant de fois
qu'il y aura d'empires : fermer les tables où tout joueur peut écrire ; verrouiller la fiche
du personnage ; faire passer l'ordre générique par le serveur ; déplacer au serveur ce que la
passe de minuit fait encore dans le navigateur ; faire écrire les annonces publiques par le
serveur.

**À noter** : le dépôt définit quatre empires à trois villes (Républia, El Estado, Sovarka,
Al-Khalija) ; la structure à huit empires (quatre non payants, quatre pay-to-win) voulue par
Fred n'y figure pas encore.

*Tenir ce fichier à jour à chaque mécanique ajoutée, retirée ou passée au serveur.*
