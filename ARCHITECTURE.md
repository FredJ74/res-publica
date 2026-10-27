# Architecture de Human Gambit — état du socle

*26 octobre 2026, précisé le 27. Référence commune à Codex, Claude et ChatGPT : l'état du
socle, pour finir Républia proprement puis coder les empires suivants sans rien réinventer. À lire avec `CONSTITUTION.md`. Version illustrée : la page
« Architecture de Human Gambit » publiée par Claude pour Fred.*

**En chiffres** : 93 bâtiments, 249 pièces, 846 ordres dans les pièces (346 actions
différentes), 357 tables et 1 058 fonctions dans la base, 57 fichiers dans le navigateur.

## Les couches

À lire de bas en haut : chaque couche ne s'appuie que sur celles du dessous. Les couches 1
à 3 sont communes à tous les empires. Dans la couche 4, **ce sont les contenus qui diffèrent
d'un empire à l'autre, pas leurs formats ni leurs outils** : une fiche de PNJ, un bâtiment,
une religion ou un club ont le même format, les mêmes écrans de gestion et les mêmes fonctions
dans tous les empires ; seul ce qu'ils contiennent est propre à chacun (Constitution,
article 7 : les mécaniques se partagent, les contenus jamais).

| Couche | Contenu |
|---|---|
| **5. Entre empires** (raccordé avec les autres empires) | ambassades (ouverture, ambassadeur, audience, asile, réception, mécénat) ; diplomatie (Indice Diplomatique par pays, négociations, traités) ; guerres (déclaration, trêve, cessez-le-feu, mobilisation) ; **voyage entre empires : n'existe pas** (bloque immunité, arrestation de l'expulsé, naturalisation, transfert de détenus) ; commerce international et tourisme prévus |
| **4. Contenu d'un empire** (contenus propres ; formats, outils et écrans communs) | géographie (3 villes, caserne, QHS, plans, rues, images) ; PNJ (noms, portraits, fiches de personnalité, référents, bibles) ; culture (monnaie, religion d'État, médias, clubs, scandales types) ; économie locale (entreprises, usines, chaînes, prix) ; institutions (noms des postes, grades d'organisations, sièges, calendrier électoral) ; énigmes de ville |
| **3. Mécaniques de jeu** (communes, paramétrées par empire) | vie du personnage, économie et travail, argent, territoire, pouvoir, justice et ordre, crime, armée, presse et opinion, organisations, foi, sport, renseignement, vie sociale |
| **2. Moteur** (socle technique, Constitution art. 4) | identité et autorité ; temps (**une horloge commune** : heure de Paris, bascule à minuit pour tous ; échéances en temps réel) ; argent (paiement des ordres, comptes, caisses, fonds en transit) ; biens (inventaire) ; lieux et présence ; mémoire et messages (mails à boutons, forum, chat, journal, chronique) ; ordres (catalogue par pièce, coûts déclarés, routeur) ; intérim des PNJ ; indices |
| **1. Infrastructure** | navigateur (`plateau.html` et `plateau-*.js`, `data.js`, `supabase.js`, `forum.js`) ; base Supabase (fonctions `SECURITY DEFINER`, la seule vérité) ; serveur Vercel (`api/` : dialogues PNJ DeepSeek, journal, conférences, renseignements) ; tâches de nuit (`api/cron-minuit.js`, 26 traitements ; `api/cron-assemblee.js`) |
| *Transversal* | administration (incarnation, journal d'administration) ; offre premium (cosmétique et confort, jamais pay-to-win dans les empires non payants) ; traduction (prévue après Républia) |

## Le temps : une seule horloge

Décision en vigueur : **une horloge commune à tous les joueurs et à tous les empires**,
l'heure de Paris, avec une bascule à minuit pour tout le monde (passe de nuit du serveur).
Les délais qui concernent des joueurs se comptent en temps réel (Constitution, article 12).

Ce qui peut exister par pays n'est **pas une autre horloge**, seulement des paramètres posés
sur l'horloge commune. Aujourd'hui, un seul : la fonction `jour_de_jeu_pays` numérote les
jours à partir d'une date d'origine lue dans `rp_epoques` (Républia : 13/09/2026 ; tout pays
sans ligne retombe sur la même date). **Ne créer aucune autre date d'origine, ni aucun
compteur de jours propre à un pays ou à un personnage, sans décision de Fred** : ce serait
réintroduire plusieurs systèmes de temps.

## Inventaire des mécaniques

État au 26/10/2026, d'après `AUDIT_UNE_SEULE_VERITE.md` : **Serveur** = tenue par le
serveur ; **Mixte** = serveur, avec des parties décidées par l'écran ; **Écran** = décidée
surtout par le navigateur ; **À créer** = n'existe pas. Classement d'ensemble : une même
mécanique peut contenir des parties plus ou moins solides.

**Ce tableau ne liste que ce qui est disponible dans le jeu, pas l'historique du
développement.** **Vérifié ligne par ligne le 27/10** : chaque mécanique a au moins un point
d'entrée réel dans le jeu (bouton d'un lieu, fiche d'un joueur ou panneau de fonction) ;
« saluer », supprimé des interactions avec les PNJ, a été retiré, et les limites constatées
(boutons en « bientôt », actions réservées aux autres empires) sont dites dans la ligne. Toute
ligne trouvée fausse se corrige ici.

### Moteur

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Identité et autorité | Reconnaît le joueur, son poste, sa présence sur place ; refuse ce qu'il n'a pas le droit de faire. | Serveur | Rien : commun. |
| Temps | Horloge commune (heure de Paris), bascule à minuit pour tous, échéances en temps réel. | Mixte | Rien : l'horloge est commune. Pas de date d'origine propre sans décision. |
| Paiement des ordres | Prélève PA et francs selon le coût déclaré de chaque ordre. | Serveur | Coûts des ordres propres à l'empire. |
| Caisses | Caisses des bâtiments et des institutions ; un crédit doit venir d'un paiement réel. | Serveur | Caisses de ses institutions. |
| Inventaire | Objets possédés, donnés, consommés, confisqués. | Mixte | Objets propres (armes, reliques, produits). |
| Lieux et présence | Bâtiments, pièces, déplacements, qui est où. | Mixte | Plan, rues, bâtiments, images. |
| Messagerie | Mails à boutons d'action, forum, chat de pièce, salons. | Serveur | Rien : commun. |
| Mémoire publique | Journal personnel, chronique nationale, annonces publiques. | Mixte | Rien : commun. |
| Ordres | Catalogue des actions par pièce et routeur ; l'ordre générique (cinq ordres) est tiré par le serveur depuis le 27/10. | Serveur | Ordres adaptés à l'histoire de l'empire. |
| Intérim des PNJ | Un PNJ tient un poste vacant en attendant un joueur. | Mixte | Noms et portraits des titulaires PNJ. |
| Dialogues des PNJ | Conversations des PNJ par DeepSeek, avec fiches de personnalité. | Serveur | Fiches de personnalité, bibles de contexte. |
| Indices | Sécurité, économie, social, piété, moral par ville ; Indice Diplomatique par pays. | Mixte | Valeurs de départ. |

### Vie du personnage

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Création | Origine, école, archétype, carrière, caractéristiques. | Mixte | Origines et écoles du pays. |
| Santé, moral, popularité | Points de vie, moral, popularité, influence, discrétion. | Écran | Rien : commun. |
| Université | Inscription à un cursus, jalons, seconde carrière ; syndicats étudiants, conférences. Le bouton « Suivre une formation » est en « bientôt ». | Serveur | Établissements et cursus. |
| État civil | Demande en mariage (depuis la fiche d'un joueur), divorce, testament, héritage, actes à la mairie. | Mixte | Rien : commun. |
| Quêtes et énigmes | Quête d'accueil, quête de carrière, énigmes de ville. | Mixte | Énigmes et référents propres. |

### Économie et travail

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Entreprises et commerces | Commerces de joueurs, prix, stocks, ventes. | Serveur | Entreprises et commerces du pays. |
| Usines et chaînes | Production, matières, directeurs, ventes directes. | Serveur | Usines et chaînes du pays. |
| Entrepôts et ressources | Stocks régionaux, prix, matières premières. | Serveur | Ressources disponibles, prix. |
| Port et fret | Bateau, colis, box, douane, criée, marchandises non réclamées (achat d'un lot encore décidé par l'écran). | Mixte | Ports et routes. |
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
| Actes illégaux | Vol, assassinat, empoisonnement, incendie, explosifs, falsification. Achat de poisons et contrebande : seulement dans les ports des autres empires. | Écran | Objets et lieux du marché noir. |
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
| Cultes | Prière, dons, confession, pèlerinage, reliques ; excommunication par le Grand Prêtre. La bénédiction n'a pas de bouton dans les lieux de culte (seulement par un contact). | Mixte (prière, don, piété, grades et charges par le serveur depuis le 27/10 pour Républia) | Religion d'État et lieux de culte. |

### Sport

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Football | Clubs, licences, entraînements, matchs en direct, championnat, transferts, supporters. | Mixte | Clubs et stades. |

### Renseignement et social

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Renseignement | Informateurs (loge, hôtel, bar), cellules de renseignement à l'étranger, renseignement militaire. | Mixte | Services du pays. |
| Vie sociale | Dîners d'affaires, tournées offertes, escortes, dons d'objets, contacts, débauchage d'employés PNJ. | Mixte | Agences et PNJ. |

### Entre empires

| Mécanique | Ce qu'elle fait | État | Pour un nouvel empire |
|---|---|---|---|
| Ambassades | Ouverture, ambassadeur, audience, asile, réception, mécénat. | Serveur | Ambassades et ambassadeurs PNJ. |
| Diplomatie et guerres | Indice Diplomatique, propositions, traités, guerres, trêves. | Serveur | Rien : commun. |
| Voyage entre empires | N'existe pas encore. | À créer | À créer une seule fois, pour tous. |

## Coder un nouvel empire

> **Référence technique pour plus tard, pas une invitation à commencer.** La feuille de
> route reste : terminer Luthécia, puis Port-Sainte-Marie et Montrouge (fin de Républia),
> puis l'internationalisation, puis seulement les autres empires. Aucun travail sur Sovarka,
> El Estado ou un autre empire ne commence avant cela.

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
