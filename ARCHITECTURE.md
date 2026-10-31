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
| Élections | Cycles, candidatures, votes, fraudes, contestation (tout par le serveur depuis le 27/10). | Serveur | Calendrier, postes électifs. |
| Assemblée nationale | Sièges, lois, séances, votes. | Serveur | Sièges et calendrier ; fermée sans eux. |
| Gouvernement et présidence | Ministères, décrets, mesures d'exception, vote de confiance (par le serveur depuis le 27/10), banquets. | Mixte | Ministères, palais. |

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
| Actes illégaux | Vol, neutralisation, empoisonnement, incendie, explosifs, falsification, contrebande (jet, effets, détection et découverte de nuit par le serveur depuis le 27/10 ; restent à l'écran « Se cacher », la neutralisation d'un député, tracts calomnieux et fausse rumeur). Achat de poisons et contrebande : seulement dans les ports des autres empires. | Mixte | Objets et lieux du marché noir. |
| Corruption | Douaniers, fonctionnaires, presse, greffe (douanier et fonctionnaires par le serveur depuis le 27/10). | Mixte | Rien : commun. |
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
| Rumeurs et scandales | Rumeurs, calomnies, scandales, démentis (démenti, rumeurs politiques, « lancer une rumeur » et scandale de la nuit par le serveur depuis le 27/10). | Mixte | Scandales types (table `scandales_predefinis`). |

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
| Renseignement | Informateurs (loge, hôtel, bar ; tenus par le serveur depuis le 27/10, interroger coûte 1 PA), cellules de renseignement à l'étranger, renseignement militaire. | Mixte | Services du pays. |
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


### Note d'audit #135 — 28 octobre 2026, non déployée

Les liens de suivi `pnj_membres.leader_pj/leader_pnj_id`, la position effective,
la dépose/reprise commune et les commandes militaires existent déjà. Les groupes
`batailles_engagements.groupe_id` sont propres à une bataille. `state.group` possède
ses ordres clients, mais aucun raccordement serveur complet du groupe universel
PJ+PNJ n'a été retrouvé dans les sources auditées : ne pas le présenter comme livré.
L'audit retire l'identifiant de détachement supplémentaire proposé dans #212 et
réutilise les liens PNJ existants. Ce correctif préparé n'est pas une migration
appliquée ; voir `outils/audits/AUDIT-CRITIQUE-SECURITE-GROUPES-135-20261028.md`.

### Préparation des groupes universels — Codex, 28 octobre 2026

La reprise #217 sur `codex/groupes-universels-20261028` prépare l'adhésion PJ
persistée et son hydratation, durcit les portes PNJ communes (prêt, prise,
séparation), le rappel radio et les projections de présence. Aucun moteur de
combat ou de déplacement supplémentaire. **Non déployé et non terminé** :
déplacement collectif PJ, projections police/douanes et recrutement du groupe
mixte dans les rounds restent à raccorder ; catalogue vivant et recette
authentifiée indispensables. Rapport et résultats :
`outils/audits/FINALISATION-GROUPES-UNIVERSELS-20261028.md`.

### Reprise #219 — pont militaire préparé, 28 octobre 2026

Les soldats rejoignent les portes communes de prise, séparation, prêt et radio
dans les tests PostgreSQL jetables, avec l'autorité de section et le miroir
militaire existants. Les trois ordres historiques par nombre délèguent à ces
portes ; les capacités serveur pilotent le menu. **Préparé, non déployé** :
le déplacement collectif PJ, les policiers/douaniers et le recrutement des
groupes mixtes en combat/interception restent ouverts. Les corrections de main
`c10c1083` (transport, création et sorties) sont conservées. État et limites :
`outils/audits/FINALISATION-GROUPES-UNIVERSELS-20261028.md`, section reprise #219.

### Reprise #219 — projections publiques et rue collective préparées

Les policiers et douaniers utilisent les portes communes de conduite, avec
projection transactionnelle dans leurs registres métier et droit administratif
séparé du commandement. Le menu commun propose aussi la consultation des unités
à distance, sans reconstruire leur bourse ni leur inventaire. Tous ces ordres
transmettent au transport existant leur garde de session/personnage.
Le corps historique du moteur de rue, dont le MD5 de définition reproduit le
relevé communiqué, est factorisé en moteur privé et porte collective : contrôle
de tous les membres avant toute mutation, projections et rollback communs.
**Préparation non déployée :** entrées/pièces, autres écrivains de position,
rounds mixtes et interception du groupe recherché restent à terminer. Les essais
de détecteur historique et du calcul de coup ne prouvent pas leur branchement
complet ni le catalogue vivant. Voir le rapport de finalisation #219.

### #219 — intérieurs et positions, préparation du 28/10

Le même moteur de composition/verrous sert désormais à la rue et aux pièces,
avec la référence des bâtiments issue de WORLD/BUILDINGS et un lecteur privé
commun des participants (identités PJ/PNJ explicites). Les sauvegardes générales
ne sont plus autorité de position dans la préparation ; un garde de table les
neutralise, les autres champs de fiche ne sont pas réécrits. Le client attend
le verdict avant rendu et n'active ce contrat que sur capacité serveur.
**Non déployable :** embarquement, bureaux d'ambassades par membre, locaux
dynamiques et transports restent à raccorder ; recrutement/rounds et interception
universels restent ouverts. Des rounds militaires complets ont tourné sur des
identités fictives : ce n'est pas une preuve de combat universel ni de production.

### #219 — transports et accès particuliers, préparation non déployée

Train/bus réutilisent l'encaissement existant avec tarif unitaire validé puis
quantité des participants serveur : le leader paie tous les PJ/PNJ, PA de l'ordre
inchangés (Fred, 28/10). Reçu technique dans la transaction des positions et des
projections ; rejeu sans second débit. Bureaux d'ambassades : contrôle audience/
asile existant par identité, sans substitution JWT. Lots dynamiques : lecture de
`terrain_etat_lire`, pas un catalogue parallèle. 141 scénarios locaux éprouvent
la chaîne ; aucune production. Douanes/international, déplacements spéciaux,
combats et interceptions universels restent inachevés : ne pas activer la garde
des positions isolément. Voir RELAIS et le rapport #219 pour l'état le plus récent.

### #219 — transport international, préparation du 29/10

Le même `transport_effectuer` couvre désormais train/bus/avion/bateau dans la
préparation. Contrôle de tous les voyageurs, attestation serveur par PJ, saisie
existante et exécution judiciaire réutilisées derrière des adaptateurs privés ;
convocations uniquement aux PJ. Le passage expire en quittant le terminal.
Corruption individuelle avec reçu, coût/jets existants ; ancien appel sans reçu
refusé avant paiement. L'écrou et le QHS enregistrent aussi leur position réelle,
les sauvegardes clientes ne terminent plus ce déplacement. 167 scénarios locaux,
aucun déploiement ; recrutement/combats et interception universels restent ouverts.
Le 29/10, Fred transfère tout l'immobilier à Claude ; références dans la transmission
versionnée, Codex poursuit seulement les socles et ChatGPT orchestre l'intégration #230.

Préparation #219 du 29/10 : miroirs police/douane conservant morts/détenus et PA canoniques ; import historique unique, dégâts des rounds policiers préexistants écrits au socle avant projection. 173 scénarios PostgreSQL jetable ; non installé, comparaison des corps vivants et fermeture des anciens écrivains encore nécessaires. Référence : `FINALISATION-GROUPES-UNIVERSELS-20261028.md`.

Préparation #219, sélection/composition du 29/10 : `groupe_combattants_interne` réutilise le groupe canonique et ses lieux/états ; gardes de recomposition pendant une confrontation ; recrutement militaire distinguant camp national et pays physique ; round policier gardé par l'état réel. 200 cas natifs locaux, sans déploiement ni clôture des rounds universels.

Préparation #219 29/10, non appliquée : écrou et séparation partagent la primitive de position PNJ existante extraite ; le même round policier recrute les deux groupes réels (PJ/policiers/soldats/agents) avec composition figée et PA individuels, sans deuxième combat. Les compagnons non condamnés ne sont pas emprisonnés. 209 cas SQL jetables ; autres raccordements de l'interception encore en cours.

Préparation #219 29/10, non appliquée : détection/round/reprise distinguent cible judiciaire et commandeur du groupe, reçus conservés après séparation. Fuite par le moteur de navigation commun ; taxis spéciaux par transport_effectuer, tarifs d'ordres existants multipliés par voyageurs, zones spéciales et entrées/sorties publiques conservées. 224 scénarios locaux, clôture des anciens écrivains encore en cours.

Préparation #219 du 29/10, complément : les rounds policiers utilisent les deux groupes canoniques, les sanctions et l'écrou restent personnels, la séparation conserve les autres positions, la fuite/taxis réutilisent la navigation transactionnelle. Recrutement/licenciement police/douane passent par `force_publique_effectif_acte` (mandat officiel, paiement et miroir, reçu), les anciennes écritures de listes sont fermées. Les gardes ne réactivent plus un soldat mort/détenu et conservent son identité. Toujours non déployé ; 243 scénarios SQL et 121 bancs clients après intégration de main 4648840e. Les batailles militaires restent à généraliser à tous les types de compagnons ; prévol vivant et protections générales de fiche à ChatGPT.

Complément #219 du 29/10 : batailles militaires mixtes raccordées aux identités PNJ réelles (sans créer une carrière militaire), mêmes coups/gilets/décès/replis et rapports. Portes existantes à reçus et round attendu, exclusion des indisponibles à chaque round, observation/poursuite historique distincte du commandement. 272 scénarios SQL jetables et 122 bancs clients ; non déployé. Adaptateur d'issue réelle de squatteurs préparé avec dépendance #233, sans score final ; leur amorçage/profils et les contrôles policiers ordinaires restent à terminer. Rapport de finalisation et prévol listent les blocages, pas d'activation globale.

État #219 faisant foi après main cbae23ff (29/10) : dix-sept migrations préparées, 273 scénarios SQL jetables réussis deux fois, 124 bancs clients ; contres neuf et deux échecs attendus. Installation partielle des batailles verrouillée jusqu'au contrat à reçus. Contrat textuel squatteurs de Claude repris depuis main. Aucun déploiement ; amorçage de leur combat et contrôle policier ordinaire incomplets. Globaux 5/12 sur branche et main ; preuves finales dans `outils/audits/preuves-groupes-219-main-cbae-20261029/`. PR #219 non prête.

Préparation #219, reprise après main 416f275b : contrôle ordinaire raccordé au détecteur commun et aux dossiers/reçus policiers existants. Détection puis DUP/PER, choix soumission/fuite, saisie avec convocation ou peine avec le jour supplémentaire atomiques ; disparition des décisions locales de ce contrôle. Arrestation historique : attente de confirmation et relecture, plus de téléportation ni conséquence anticipée. Deux migrations 20261029220000/220100 non appliquées ; 291 cas SQL jetables, 18 cas clients ciblés. Squatteurs toujours incomplets, prévol vivant et articulation #213/#235 non réalisés ; PR #219 non prête.

### Groupes et combats — complément #219 préparé le 29/10, non déployé

Les compléments `20261029223000` à `20261029223200` réutilisent les rounds militaires,
les reçus et l’écrou existants pour la règle des cinq rounds et du chef unique.
La neutralisation du chef n’emporte plus immédiatement ses compagnons à l’infirmerie.
La fuite géographique et le PNJ unique squatteurs restent à raccorder : ce lot ne
constitue pas une activation du combat universel en production. État actuel dans `RELAIS.md`.

Le complément `20261029223300` étend la table existante `rue_noeuds_serveur`
avec les directions dérivées du même catalogue que l’écran. Le générateur
`outils/generateurs/navigation-directions.cjs --verifier` en contrôle la fidélité.
La provenance est conservée sur le personnage par un trigger serveur, après la
garde de sauvegarde des positions. `223500/223600` réutilisent cette lecture pour
la fuite policière, les contrôles collectifs et leur reprise. Aucun nouveau moteur
ni déplacement de fuite militaire ajouté par ce complément.

Compléments #219 préparés `20261029223700/223800` : les replis militaires suivent
la navigation et la géométrie communes, y compris les unités PNJ autonomes.
Les trois corps vivants communiqués le 29/10 sont conservés en fixture attribuée,
avec leurs empreintes exactes ; ils ne remplacent pas un prévol d’installation.

Complément #219 préparé `20261029223900` : même doctrine pour les choix automatiques
adverses, rattrapage par le calendrier quotidien existant, sans nouveau polling.
Ne pas assimiler ce passage quotidien à une garantie de traitement à 90 secondes.
Le rendu des replis reprend la vue de rue existante, pas un faux bâtiment nul.

Complément #219 préparé `20261030001000` : les actes historiques des camions
utilisent la composition canonique pour embarquer, débarquer et évincer les groupes.
Les coûts, priorités et grades du moteur camion restent inchangés ; ses refus tardifs
annulent aussi les positions et embarquements. Aucun nouveau moteur de transport.

Complément #219 préparé `20261030001100` : provenance des PNJ sur leur ligne existante,
conservée lors d’une dépose ; position personnelle ajoutée à la lecture commune déjà
utilisée. La restauration des rues réemploie cette lecture et garde les quatre vues PSM,
sans nouvelle interrogation périodique. Les valeurs nulles de bâtiment restent nulles.

### #219 — ouverture civile commune préparée le 30 octobre, non déployée

`combat_ouvrir` ouvre les mêmes batailles/engagements que l'armée, avec son reçu
par acteur et paramètres dans `navigation_requetes`. La préparation de
`crime_neutraliser` fournit seulement ses préconditions, coût PA et bruit ; son
ancien jet final est fermé. `combat_bataille_completer_groupes_interne` contient
l'unique parcours d'accompagnement extrait du recrutement militaire, désormais
appelé par les deux contextes. Les profils validés des squatteurs alimentent un
PNJ bêta unique par occupation ; famille technique employé sans poste, contrat,
salaire ou propriétaire fictif. END utilise ENT. Les mêmes rounds constatent
fuite, reddition, neutralisation et décès ; l'adaptateur du terrain n'effectue
ni second jet ni second paiement. Les sanctions financières restent les
contrats de Claude, jamais un nouveau circuit de caisse.

Le courrier système et l'historique existant rendent les affrontements
consultables depuis le journal. Aucun minuteur navigateur. La reprise d'un
combat à une interaction et les relectures après round restent liées au
personnage/session. Le calendrier nocturne rattrape les batailles ; il ne
promet pas une tâche exécutée exactement à la 90e seconde.

Versions préparées renumérotées uniquement pour éviter les collisions avec les
mairies appliquées : correspondance dans
`outils/audits/VERSIONS-GROUPES-219-20261030.json`, puis compléments civils
`20261030202300` à `20261030202700`. Avant activation : prévol réel des corps,
triggers, droits et registre, et recette authentifiée autorisée. Les bancs
PostgreSQL jetables ne démontrent pas le fonctionnement en production.

### #219 — preuve intégrée du 31 octobre, production non livrée

Les 95 versions sélectionnées (5 contrats organisations, prérequis et 88 versions
universelles, rapprochement des tarifs) ont été exécutées ensemble sur PostgreSQL
17.6 jetable : rollback tardif complet, rejeu refusé sans mutation, 30 scénarios
catalogue et trois commandes d'organisations. Après les deux migrations de caisses
#300, ces scénarios passent encore. Le décor reste explicitement le schéma privé
1003 plus les tarifs capturés ; il ne certifie pas la coupe vivante plus récente.

La recette supplémentaire utilise GoTrue et PostgREST natifs sur loopback/socket
Unix, avec trois comptes créés uniquement dans cette base jetable : 26 scénarios
HTTP authentifiés (groupes, PNJ, radio, combat mixte, concurrence/rejeu, fonds et
indisponibilités). Ce n'est pas une recette de l'interface du jeu en production.
Aucun moteur métier remplacé ; aucun joueur réel utilisé. État et limites :
`outils/audits/INTEGRATION95-ET-CAISSES300-219-20261031.md`. Le payeur est compatible :
ne pas confondre l'empreinte de son corps et celle de sa définition complète.
