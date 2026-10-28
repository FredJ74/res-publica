# Audit « une seule vérité, celle du serveur » — 25-26 octobre 2026

Commande de Fred (25/10, chantier de nuit) : *« Audite tout le jeu pour trouver où il
peut y avoir deux vérités, celle du serveur et celle du navigateur, afin de mettre en
conformité avec ma décision d'avoir une seule vérité, celle du serveur. »*

Lecture retenue par Claude : **cet audit inventorie et classe** ; il ne corrige pas le
code des chantiers des autres (Codex y travaille, et l'ordre des corrections est une
décision de Fred). Seuls les écarts restants dans les chantiers de Claude (ambassades,
Bureau de l'Emploi) sont corrigés la même nuit (voir la fin).

Méthode : lecture des droits réels de la base (qui peut écrire quoi), lecture des
déclencheurs qui protègent la fiche du personnage, recherche dans tout le code du
navigateur des tirages au sort, des horloges, des effets appliqués en mémoire et des
écritures directes. Chaque constat cite son fichier. Les fonctions sans appelant ont été
écartées (code mort, listé à part).

---

## En bref, pour Fred

Le jeu a déjà fait une grande partie du chemin : **l'argent, les PA, les comptes en
banque, les caisses des bâtiments, l'inventaire, les postes, les guerres, les ambassades
et le Bureau de l'Emploi** sont tenus par le serveur. Le navigateur ne peut ni se donner
de l'argent, ni des PA, ni un poste, ni un objet.

Il reste **quatre familles de « deux vérités »** :

1. **Des portes ouvertes** (le plus grave) : une quarantaine de tables de la base acceptent qu'*importe
   quel joueur connecté* y écrive *n'importe quoi* — budgets, partis, prêts, mariages,
   successions, indices des villes, niveaux de prison, élections… Et trois fonctions du
   serveur créent de l'argent dans une caisse sur simple demande du navigateur. Un
   joueur qui sait ouvrir la console de son navigateur peut réécrire ces données.
2. **La fiche du personnage** : le navigateur la renvoie entière à chaque sauvegarde, et
   le serveur accepte encore tels quels la santé, le moral, la position, la prison,
   l'hôpital, les employés, le domicile, les effets actifs, la réputation criminelle…
   et les variations de popularité et d'influence décidées par l'écran.
3. **Le navigateur décide** : environ **95 tirages au sort** sont faits par l'écran
   (vols, assassinats, douanes, corruption, élections truquées, fuite, football…), ainsi
   que **l'ordre générique** qui sert à des dizaines d'ordres (jusqu'à 149 décrits) : le
   jet de réussite et ses effets sont calculés par l'écran. Le passage de minuit fait
   encore une partie du travail dans le navigateur du joueur connecté.
4. **Deux affichages** : des choses n'existent que sur l'écran du joueur et disparaissent
   au rechargement (objets ajoutés par l'écran, gains d'argent de l'ordre générique,
   traités, référendums, guerres du vieux dispatcheur) ; et **153 annonces publiques**
   (« GUERRE DÉCLARÉE », « SCANDALE »…) sont écrites par le navigateur, que le serveur ait
   constaté quelque chose ou non.

**Ma recommandation d'ordre** : 1) fermer les portes ouvertes ; 2) verrouiller la fiche ;
3) remplacer l'ordre générique par un jet serveur unique (un seul chantier règle des
dizaines d'ordres) ; 4) passer les tirages restants famille par famille ; 5) faire écrire
les annonces publiques par le serveur. Chaque point peut être un chantier séparé.

---

## 1. Portes ouvertes : le serveur accepte l'écriture de n'importe quel joueur

### 1.1 Tables écrites par tout joueur connecté, sur toute ligne

La règle d'accès de ces tables est `acteur_identifie()` : il suffit d'être connecté.
Aucune vérification de poste, de propriétaire ou de montant. (I = créer, U = modifier,
D = supprimer.)

| Domaine | Tables | Ce qu'un joueur peut faire |
|---|---|---|
| Finances publiques | `budgets_nationaux` (I,U), `budgets_municipaux` (I,U), `budgets_clubs` (I,U) | réécrire un budget. `budgets_nationaux` est en partie protégé (champs réservés à un poste, stocks de l'armurerie, marqueurs de nuit) ; les deux autres ne le sont pas |
| Prêts | `prets` (I,U) | créer ou modifier un prêt (une protection existe sur les écritures « versionnées » seulement) |
| Élections | `cycles_electoraux` (I,U), `fraudes_electorales` (I,U), `votes_confiance` (I,U), `votes_electoraux` (D) | modifier un cycle, effacer une fraude, supprimer des votes |
| Organisations | `organisations` (I,U,D) | créer, modifier, supprimer toute organisation qui n'est pas un parti (les partis sont protégés) |
| État civil | `mariages` (I,U), `demandes_mariage` (I,U), `successions` (I,U), `etat_civil_deces` (I), `etat_civil_naissances` (I), `demandes_naturalisation` (I,U) | marier, déclarer un décès ou une naissance, modifier une succession |
| Justice, ordre public | `niveaux_prison` (I,U), `etats_urgence` (I,U), `greves_generales` (I,U), `demandes_manifestation` (I,U), `rumeurs_actives` (U sur toute ligne), `rapports_renseignement` (I) | changer le niveau d'une prison, déclarer un état d'urgence ou une grève |
| Territoire | `indices_villes` (I,U), `dossiers_urbanisme` (I), `terrains_historique_ventes` (I), `logements_demandes` (I,U), `logements_attributions_historique` (I) | réécrire les indices de sécurité ou d'économie d'une ville |
| Commerce, fret | `caisses_fret` (I,U), `contenu_caisses_fret` (I,U), `petites_annonces` (I,U), `registre_ventes_armes` (I), `objets_abandonnes` (I,D) | modifier une caisse de fret ou son contenu |
| Football | `transferts_clubs` (I,U), `championnat` (I,U hors ligne 1) | modifier un transfert, le championnat |
| Récits publics | `evenements_globaux` (I), `chronique_nationale` (I, hors faits judiciaires), `chat_piece` (I), `contributions_piete` (I), `tribune_articles_etouffes` (I), `quetes_actives` (I,U), `souvenirs_accueil` (I,U), `dons_en_attente` (D) | publier un faux événement national ou mondial, une fausse chronique |
| Postes PNJ | `titulaires_pnj` (I,U,D pour les postes sans règle de nomination) | changer qui tient un poste PNJ |

Les autres tables écrivables par les joueurs sont limitées à **leurs propres lignes**
(mails, forum, présences, testaments, invitations, candidatures, salons…) : c'est
conforme.

**Remède** : pour chaque table, retirer le droit d'écriture des joueurs et passer par
une fonction du serveur qui vérifie l'autorité, comme cela a été fait pour les guerres,
les ambassades ou les caisses. Commencer par les budgets, les prêts, les élections,
les organisations, l'état civil et les indices des villes.

### 1.2 Fonctions du serveur qui croient le navigateur sur un montant

| Fonction | Ce qu'elle accepte | Gravité |
|---|---|---|
| `batiment_caisse_mouvement(p_delta)` | tout joueur connecté peut ajouter ou retirer **n'importe quel montant** dans la caisse de n'importe quel bâtiment (le code le dit : l'autorité sur le montant est « laissée ouverte ») | création d'argent |
| `caisse_institution_mouvement(p_delta)` | un **crédit** (montant positif) envoyé par un joueur n'est soumis à aucune autorité : n'importe quelle caisse d'institution peut être remplie à volonté. Les retraits, eux, sont contrôlés | création d'argent |
| `caisse_client_mouvement(p_delta)` | même chose pour les caisses du pays du joueur : un crédit passe sans contrôle | création d'argent |
| `impact_deposer(p_delta)` | les dégâts d'une agression sont fixés par le navigateur ; seule garde : être au même endroit (le code le dit : « ne remplace pas un jet serveur ») | santé d'autrui |
| `personnage_ajuster_pop_inf(…, p_cause)` | registre de causes bornées, mais c'est le navigateur qui choisit la cause et le moment | popularité d'autrui, bornée |

**Remède** : un crédit de caisse ne doit naître que d'une recette réelle connue du
serveur (vente, impôt, paiement d'un ordre) ; les dégâts d'une agression se tirent au
serveur.

---

## 2. La fiche du personnage

À chaque sauvegarde, le navigateur renvoie la fiche entière (`sbSavePersonnage`). Le
serveur la filtre (`personnages_vue_modifier` et ses déclencheurs).

**Déjà tenu par le serveur** : caractéristiques, points libres, qualifications,
banque, argent liquide et compte (toute hausse est ignorée), inventaire (le navigateur
n'y écrit plus), PA (ne peuvent que baisser), poste et poste de député (doivent être
attestés), jour (+1 au plus, jamais en arrière), convocations, casier et avis de
recherche (ne peuvent pas être effacés), refuge d'ambassade.

**Encore accepté tel quel du navigateur** :
- **santé** (une hausse est seulement notée dans un journal, pas refusée), **moral** ;
- **popularité et influence** : le navigateur annonce une variation, le serveur
  l'ajoute — c'est donc l'écran qui décide de chaque +10 ou −20 ;
- **position** (ville, bâtiment, pièce) ;
- **prison** (`est_emprisonne`, hors réfugiés), **quartier de haute sécurité**,
  **hospitalisation**, **poison actif**, **stats affaiblies** ;
- **employés**, **informateurs**, **contacts**, **escorte**, **domicile**, **locations** ;
- **réputation criminelle**, **enquêtes en cours**, **effets actifs**, **réquisition** ;
- **excommunication**, licence et performance sportives, quêtes et énigmes, salaire
  touché, dernier sommeil, réservation d'hôtel.

**Remède** : ne plus laisser la sauvegarde écrire ces champs ; chacun ne change que par
l'action du serveur qui en est la cause (soin, condamnation, embauche, déplacement…).
C'est le chantier le plus structurant : il oblige à passer en serveur les actions qui
modifient ces champs.

---

## 3. Le navigateur décide

### 3.1 L'ordre générique (`plateau-router.js`, `executerOrdreGenerique`)

Tout ordre qui n'a pas de traitement dédié passe par lui. **Rectifié le 27/10** : mesure faite,
seuls cinq ordres réels y arrivaient (soins de la clinique, fuite, loge, interrogatoire), et non
« des dizaines » ; `ORDER_EFFECTS` décrit 93 ordres mais la plupart ont leur propre traitement. Le paiement est fait par le
serveur, mais **le jet de réussite (réussite critique, réussite, partielle, échec,
échec critique) est tiré par l'écran**, et ses effets (santé, moral, influence,
popularité, discrétion, gain d'argent) sont appliqués par l'écran à partir de
`ORDER_EFFECTS` (`data.js`, jusqu'à 149 ordres décrits). Le remboursement d'un échec,
lui, est déjà attesté par le serveur.

**Remède** : un seul chantier — une fonction serveur « exécuter un ordre » qui paie,
tire et applique les effets déclarés — règle d'un coup tous ces ordres.

### 3.2 Les tirages au sort de l'écran (environ 95)

Recensés dans 11 fichiers (liste complète en annexe A). Les principales familles :
- **crimes et clandestinité** : vol, assassinat, empoisonnement, incendie, explosifs,
  se cacher, corruption d'un registre, d'un fonctionnaire, d'un gardien, d'un douanier,
  falsification, contrebande, découverte des crimes passés, détection d'un acte illégal ;
- **police et justice** : fuite, résistance, fuite devant la police, contrôle
  automatique, enquêtes, convocations, codétenus ;
- **douanes et transport** : contrôle de douane, passage à l'aéroport, inspection des
  cargaisons, transport, syndicat du port ;
- **politique** : bourrer les urnes, falsifier les listes, truquer le dépouillement,
  contester les résultats, démenti, état d'urgence, décret, censure, couvre-feu,
  mobilisation (événement à 15 %), ordre fiscal ciblé ;
- **vie sociale et religion** : bénédiction, confession, loge, piété, rumeurs,
  escortes, débauchage, recrutement d'un codétenu, objets trouvés, antipoison ;
- **football** : buts, blessures, entraînement en direct ;
- **organisations et quêtes** : effets des ordres d'organisation, blocus, revendication,
  génération des quêtes.

Certains ne jouent que pour les autres empires (exemple : l'arrestation au réveil ou au
déplacement est désactivée à Républia) : ils seront à reprendre avec ces empires.

**Remède** : chaque tirage passe au serveur avec son action (comme l'audience
d'ambassade, l'asile ou le banquet). Regrouper par famille : un chantier « crimes », un
« police et justice », un « douanes », un « fraudes électorales », un « football »…

### 3.3 Le passage de minuit dans le navigateur (`plateau-core.js`, `runMidnightUpdate`)

Si un joueur est connecté à minuit, son navigateur traite encore : plaintes, enquêtes,
convocations, découverte des crimes passés, population, effets du couvre-feu,
recherche militaire, scandale, effacement des crimes, paiement des informateurs. Si
personne n'est connecté, rien ne se passe pour ces points ; si quelqu'un l'est, c'est
son écran qui décide. Le message « recettes fiscales versées au trésor » est un simple
texte : le versement réel est fait par le serveur.

**Remède** : déplacer chaque traitement dans la passe de nuit du serveur
(`api/cron-minuit.js`), comme cela a déjà été fait pour les budgets, les désertions et
les expulsions d'ambassadeurs.

### 3.4 Horloge du navigateur pour des échéances enregistrées

- couvre-feu et recherche militaire : `dateFin = Date.now() + …` écrit dans le budget
  national (`plateau-politique.js` 14107, 14230, 14723) ;
- clôture d'un vote à 48 h (`plateau-politique.js` 10397) ;
- suspicion après un cadavre, 24 h (`plateau-pnj.js` 3944) ;
- expiration des convocations (`plateau-personnage.js` 1182, 1209) ;
- étouffement d'un article, 7 jours (`supabase.js` 5584).

**Remède** : l'échéance est posée par le serveur, à son heure (comme pour l'expulsion
d'un ambassadeur).

---

## 4. Deux affichages

- **Objets ajoutés par l'écran seul** : `addToInventory` (28 appels) et une vingtaine
  de `state.inventory.push` ajoutent un objet sur l'écran, mais la sauvegarde ne
  transmet plus l'inventaire : si l'action n'a pas aussi un passage serveur, l'objet
  disparaît au rechargement (exemples à vérifier : achat d'arme, de poison, de gilet,
  d'explosifs, récolte, reliques, tracts, actes d'état civil, documents d'urbanisme,
  caisses de fret, contrebande, accessoires de club).
- **Gains d'argent de l'ordre générique** (`crediterFondsOrdinaires`) : l'écran affiche
  le gain, le serveur l'ignore à la sauvegarde ; il disparaît au rechargement.
- **Listes qui ne vivent que dans l'écran** : `state.traites` (traités),
  `state.referendums`, `state.guerres` et `state.ambassades` (vieux dispatcheur),
  `state.prisonniers`, `state.assassinats`, `state.archivesJugements`,
  `state.plaintesEnCours` (en partie rechargées du serveur).
- **Annonces publiques** : `addExternalEvent` (153 appels) publie dans
  `evenements_globaux` ce que l'écran a décidé (« GUERRE DÉCLARÉE », « SCANDALE », « réception
  donnée »…), et la table accepte n'importe quel texte de n'importe quel joueur.
- **Cache local** : la fiche est gardée dans le navigateur (`respublica_char_…`) et
  affichée le temps que le serveur réponde ; c'est un affichage provisoire, sans
  conséquence tant que la valeur du serveur l'écrase ensuite.
- **Copies d'affichage** : `INDICES_NATIONAUX` (ISN, IE, IS) reste une constante en
  mémoire, modifiée par l'écran (`plateau-politique.js`, `plateau-justice-economie.js`,
  `plateau-navigation.js`, `plateau-organisations-quetes.js`) ; seul l'Indice
  Diplomatique est désormais tenu par le serveur (25/10).

---

## 5. Code mort (aucun appelant), à supprimer

- écritures vers des tables fermées, qui échoueraient : `sbSaveCompagnie`,
  `sbCreerEngagement`, `sbCreerFaitArmes`, `sbArchiverLoi`, `sbCreerPari`,
  `sbSavePresidentClub` (`supabase.js`) ;
- tirages sans appelant : `calculerResultatElection`, `doCorrompreGardien`,
  `doFalsifierDocs`, `interagirPnjTerrain` (**rectifié le 27/10** : `confirmerBourrerUrnes` et
  `confirmerFalsifierListes` sont appelées par leur nom depuis `htmlChoixCandidatFraude` ; elles
  sont bien en service) ;
- `executerOrdreEmpire` (branches guerre, cessez-le-feu, sanctions) et `signerTraite`.

---

## 6. Corrigé la même nuit dans les chantiers de Claude

- **Annonces publiques des ambassades** (réception, mécénat, accord diplomatique) :
  écrites désormais par le serveur, dans la même opération que l'action
  (`annonce_publique_interne`) ; le navigateur ne les écrit plus.
- **Traités** : « Relations bilatérales » lit les traités réellement acceptés sur le
  serveur (`diplomatie_traites_lire`) au lieu de la liste personnelle du lecteur.
- Bureau de l'Emploi : aucun écart restant trouvé.
- Migration `20261026010000` (registre 20261025223724), éprouvée en transaction annulée.

---

## Annexe A — tirages au sort décidés par le navigateur

Fichier (sans le préfixe `plateau-`), fonction englobante, ligne. Les identifiants
tirés au hasard et les effets purement visuels sont exclus.

- **actions-illegales-rumeurs** : butin (l.214), checkScandale (l.3241), confirmerAchatExplosifs (l.2142), confirmerAssassinatArme (l.481), confirmerCorruptionRegistre (l.1817), confirmerEmpoisonnement (l.2541), confirmerIncendier (l.2208), confirmerRecolte (l.7044), doSeCacher (l.2858), ecouterRumeurs (l.710), explosifIdx (l.2299), isPays (l.1706), jetFinal (l.152), repere (l.2238)
- **communication** : calculerResultatElection (l.1418), doLogePortail (l.1204), election (l.1407)
- **divers** : doDemanderBenedictionContact (l.888), doSeConfeser (l.685), genererEvenementAleatoire (l.21), pieteVille (l.800), reclamerObjetTrouve (l.966)
- **justice-economie** : candidats (l.12001), checkArrestationAuDeplacement (l.1016), checkArrestationAuReveil (l.1024), checkDetection (l.991), codetenu (l.2530), confirmerDonArgent (l.66), confirmerFalsification (l.2950), convocation (l.1113), cur (l.1232), detection (l.11254), disCaisse (l.10575), doCorrompreFonctionnairePermis (l.8918), doCorrompreGardien (l.4433), doCorruption (l.2303), doFalsifierDocs (l.4455), doTenterFuitePolice (l.11336), isn (l.2434), isnVille (l.12139), jet (l.13016), r (l.4285), resoudreControlePoliceAutomatique (l.11275), tenterFuite (l.1520), tenterResistance (l.1538), traiterEnquetes (l.796), verifierDecouverteCrimesPasses (l.2383)
- **multijoueur** : confirmerDebauchage (l.1403), confirmerRecrutementCodetenu (l.65)
- **navigation** : confirmerTransport (l.2680), doContrebandePort (l.2864), doControlDouanes (l.2800), doCorrompreDoanier (l.2827), doInspecterCargaisons (l.2951), doPasserDouanesAeroport (l.1405), syndicat (l.2923)
- **organisations-quetes** : b (l.2893), buts (l.1867), confirmerEntrainement (l.4062), doForcerBlocus (l.3760), gele (l.328), lancerNouvelleQuete (l.171), notifierCompositionsEtBlessures (l.2612), ordre (l.1271), proba (l.2782), revendication (l.3662)
- **personnage** : doCentreAntiPoison (l.2692), jeterObjetInventaire (l.3818)
- **pnj** : appliquerEffetRumeur (l.2349), confirmerEscortPiege (l.3556), doExpulsionAcceleree (l.3874), doFaireDisparaitreCadavre (l.3915), etouffementActif (l.2710), interagirPnjTerrain (l.3644), lot (l.615), pnjInfo (l.2939), repondreNegociationParcelle (l.731), texteEchappe (l.2429)
- **politique** : actifs (l.8451), censurer (l.9163), confirmerBourrerUrnes (l.2665), confirmerContesterResultats (l.2866), confirmerDementi (l.10210), confirmerEtatUrgence (l.7081), confirmerFalsifierListes (l.2599), confirmerMobilisation (l.12772), confirmerTruquerDepouillement (l.2759), executerOrdreFiscalCible (l.7825), jourSurv (l.12862), pnjInfoMariage (l.6882), rang (l.2603), signerDecretInutile (l.4691), taux (l.9999), verifierCouvreFeu (l.14151)
- **router** : executerOrdreGenerique (l.873)

---

## Suivi des corrections

- **26/10 (soir) — §1.2, création d'argent : réglé.** Un crédit de caisse demandé par le
  navigateur ne peut verser que l'argent que le joueur vient réellement de payer (ordre) ou
  de prélever avec autorité (registre `fonds_en_transit`, 15 minutes) ; sinon il est refusé et
  journalisé (`credit_non_adosse`). `caisse_institution_mouvement`, sa variante plafonnée et
  `batiment_caisse_mouvement` ne sont plus appelables par un navigateur. Virements usine ↔
  ministère et vente de bois à une imprimerie entièrement par le serveur (la vente de bois
  perdait l'argent du vendeur et lui laissait son bois). Migrations `20261026020000` et
  `020100`. Reste du §1.2 : `impact_deposer` (dégâts) et `personnage_ajuster_pop_inf`.
- **26/10 (soir) — correctif** : le débit des fonds ordinaires alimente aussi le registre
  (migration `20261026030000`), sinon la recette de plusieurs achats (box du port, sels,
  petite annonce, lobbying, sponsoring) aurait été refusée.
- **Constaté en passant, à reprendre** : l'achat d'un lot de fret non réclamé
  (`acheterLotNonReclameeFret`) se fait entièrement dans le navigateur — l'acheteur n'est pas
  débité (le serveur ignore la baisse de son argent), les objets n'arrivent que sur son écran ;
  sa recette est désormais refusée. Il faut une fonction serveur d'achat de lot.
- **Tables ouvertes, budgets des clubs** : la caisse d'un club (`budgets_clubs.caisse`) est
  écrite par le navigateur (cotisations, sponsoring, boutique, transferts entre clubs,
  subvention ou redressement du ministère). Fermer la table suppose de passer ces cinq chemins
  au serveur, dont les transferts (table `transferts_clubs`, elle aussi ouverte).
- **27/10 (nuit)** — §3.1 réglé : l'ordre générique passe par le serveur
  (`ordre_generique_executer`, table `ordres_generiques`) ; « Racheter l'usine », qui faisait
  payer 8 000 FR pour rien, est en « bientôt » (Constitution art. 15). §3.3 en partie : couvre-feu
  et recherche militaire dans la passe de nuit du serveur (`minuit_couvre_feu_recherche`) ;
  la croissance locale de la population supprimée. §5 : code mort supprimé (`sbSaveCompagnie`,
  `sbCreerEngagement`, `sbCreerFaitArmes`, `sbArchiverLoi`, `sbCreerPari`, `sbSavePresidentClub`,
  `calculerResultatElection`, `doCorrompreGardien`, `doFalsifierDocs`) ; `interagirPnjTerrain`
  laissé (testé par un banc du chantier terrains de Codex).
- **27/10 (matin)** — §1.1 en partie : ramasser un objet trouvé passe par le serveur
  (`objet_abandonne_ramasser`), l'objet arrive dans l'inventaire réel ; `objets_abandonnes` n'est
  plus écrite par les joueurs ; plus aucun joueur ne peut supprimer les votes électoraux ni les
  dons en attente des autres (migration `20261027030000`).
- **27/10 (matin)** — §1.1 en partie : la carrière religieuse de Républia passe par le serveur
  (`religion_agir` : prière, don, piété de la ville, grade, charge de prêtre, Grand Prêtre). Les
  joueurs n'écrivent plus `contributions_piete` ni `titulaires_pnj` ; la piété d'une ville est
  toujours recalculée depuis le registre (déclencheur sur `indices_villes`), les autres indices
  de ville restent écrits par le navigateur (à reprendre). Révocation d'un PNJ non municipal :
  passait par une suppression refusée en silence, désormais par `poste_revoquer`. Popularité et
  influence rendues par le serveur : la sauvegarde suivante les comptait une seconde fois,
  corrigé (`adopterJaugeServeur`). Migrations `20261027040000` et `040100`. Les trois autres
  empires gardent l'ancien fonctionnement (feuille de route).
- **27/10 (fin de matinée)** — **Défaut grave trouvé et corrigé** : le garde-fou qui empêche le
  navigateur de fixer sa popularité ou son influence annulait aussi, en silence, celles écrites
  par une fonction du serveur appelée par un joueur (don à l'église, ordre générique, dîner au
  restaurant, tournée, tirage d'une candidature, torture au QHS...). Il ne vise plus que les
  écritures directes de la fiche (migration `20261027050000`, éprouvée au rôle joueur).
  Leçon pour les bancs SQL : se placer au rôle `authenticated` (`set_config('role', ...)`),
  sinon le garde-fou croit à un appel du serveur.
- **27/10** — §1.1 : `rumeurs_actives` n'est plus écrite par les joueurs. Le démenti officiel
  (jet, ampleur, résolution) passe par `dementi_executer` ; la rumeur et la sanction du Ministre
  après une torture au QHS sont posées par `qhs_pouvoir` (migration `20261027060000`). Reste
  dans le même registre : les rumeurs entre joueurs (causes `rumeur_pj`, `rumeur_gouvernement`,
  ampleur tirée par l'écran dans une fourchette) et `football_match`.
- **27/10 (midi)** — §1.1, **faille majeure fermée** : `cycles_electoraux` était écrite par tout
  joueur, y compris `eluId` / `elus`, que `poste_est_atteste` lit pour reconnaître un Président,
  un maire, un chef syndical ou un député. Les trois écritures légitimes passent par le serveur :
  engendrer un scrutin absent (`cycle_electoral_initialiser`, sans jamais écraser un scrutin
  existant), relance des législatives à la dissolution (`assemblee_dissoudre`), contestation
  (`election_contester`). La contestation ne pouvait rien révéler (elle cherchait les fraudes
  dans le scrutin suivant, déjà rouvert) : la passe de nuit garde désormais une photographie du
  scrutin proclamé (`dernierScrutin`), et le serveur y recompte. `fraude_electorale_sanctionner`
  n'est plus appelable seule. Migrations `20261027070000` et `070100`. Reste :
  `fraudes_electorales` encore écrite par l'écran (création des fraudes).
- **27/10 (midi)** — §1.1 : `fraudes_electorales` n'est plus écrite par les joueurs. Falsifier
  les listes, bourrer les urnes, truquer le dépouillement : poste, fenêtre, jet, nombre de voix,
  détectabilité, prison et fait public par `fraude_electorale_tenter` (migration
  `20261027080000`). Tout joueur pouvait inscrire une « fraude » de n'importe quelle ampleur, que
  le dépouillement appliquait. Les fraudes non révélées ne sont plus lisibles par les autres
  joueurs (auteur compris).
- **27/10** — §1.1 : `votes_confiance` n'est plus écrite par les joueurs (tout joueur pouvait
  réécrire statut et résultat, et la passe de nuit mettait alors à zéro la popularité du
  gouvernement). Déclenchement et bulletins par `vote_confiance_declencher` et
  `vote_confiance_voter` ; mails aux députés et annonce posés par le serveur (migration
  `20261027090000`).
- **État au 27/10 (midi), ce qui reste ouvert** :
  - `organisations` et `prets` : non touchées, chantiers en cours de Codex (contrat serveur des
    organisations ; prêts liés aux successions) ;
  - `indices_villes` (sécurité, économie, social, moral ; la piété est désormais imposée par le
    serveur) : 8 écritures de l'écran (manifestations, répression, rumeurs) ;
  - `budgets_municipaux` (taux foncier, interdiction de manifester) et `niveaux_prison`
    (rébellion des détenus, dont la mécanique entière est encore à l'écran) ;
  - `evenements_globaux` : environ 140 annonces publiques écrites par l'écran ; chaque action
    passée au serveur reprend la sienne (`annonce_publique_interne`) ;
  - registre de `personnage_ajuster_pop_inf` : causes `rumeur_pj`, `rumeur_gouvernement`,
    `excommunication`, `football_match` dont l'ampleur est encore tirée par l'écran.
- **27/10 (après-midi)** — §3.3, passe de minuit cliente, **trois failles fermées** :
  - `recherche_retirer` : un joueur recherché effaçait lui-même ses motifs. Retrait admis
    seulement juste après un écrou (détention ouverte depuis moins de 15 min) ou pour la
    désertion qui s'éteint ; `procederArrestation` attend désormais l'ouverture de la détention ;
  - `enquete_garde_a_vue` : garde à vue de n'importe qui, sur la foi d'une « enquête » écrite par
    l'appelant sur sa propre fiche. Plus appelable (le chemin légitime n'avait plus de bouton) ;
    `traiterEnquetes` supprimée ; ouverture d'enquête du Ministre par `enquete_ouvrir` ;
  - convocations : échéance réelle (24 h) et statut « traitée » imposés par le serveur ; la
    justification par `convocation_se_justifier` ; la non-présentation sanctionnée par la passe
    de nuit (`minuit_convocations`) ; `traiterConvocations` supprimée.
  Migrations `20261027100000`, `100100`, `100200`. Reste de la passe cliente :
  `verifierDecouverteCrimesPasses`, `checkScandale`, `checkEffacementCrimes`, `payerInformateurs`
  — liées à l'historique des crimes, que l'écran écrit encore (famille « Crime »).
- **27/10 (fin d'après-midi)** — famille « Crime », **premier lot** :
  - socle pénal du serveur (`20261027110000`) : table `actes_illegaux` (taux de détection,
    peine, amende), détection (`crime_detecter_interne`, règles de `checkDetection`), trace dans
    l'historique, avis de recherche, et **découverte différée des crimes par la passe de nuit**
    (`minuit_decouverte_crimes`, appelée par le cron) ;
  - neutraliser (mains, arme blanche, arme à feu), incendier, explosifs (`20261027110100`) :
    jet, dégâts, fermeture du bâtiment, détection et trace par `crime_neutraliser`,
    `crime_incendier`, `crime_explosifs`. Ils étaient d'ailleurs inutilisables (ordre non déclaré) ;
  - **deux portes fermées** : `impact_deposer('hp_set')` (mettre à terre quiconque dans la pièce,
    sans jet ni PA) et l'écriture directe de `batiments_fermes` (fermer n'importe quel bâtiment).
  Reste : vol, empoisonnement, corruption, falsification, contrebande, tracts, fausse rumeur
  (détection encore par l'écran) ; neutralisation d'un député (`assemblee_neutraliser_depute`,
  détection cliente) ; `checkScandale`, `checkEffacementCrimes`, `payerInformateurs`.
- **27/10 (soir)** — famille « Crime », **second lot** (`20261027120000`/`120100`) :
  - **vol** par `crime_voler` : jet, butin lu sur la fiche réelle de la victime, sanction d'échec
    de l'empire, crédit du voleur, courrier selon le palier ; 2 PA enfin prélevés. **Faille
    fermée** : `vols_en_attente` acceptait n'importe quel montant déclaré par le voleur (vider une
    victime, ou s'offrir de l'argent par un montant négatif) ; la victime ne peut plus que marquer
    « traité » ;
  - **empoisonnement** par `crime_empoisonner` ; l'effet atteint enfin la victime (`poison_start`
    avec `details`) et l'empoisonnement en cours est persisté (`poison_actif`) ;
  - neutraliser et explosifs déposent de nouveau l'impact `hp_set` (hospitalisation de la victime).
  Restent à l'écran : « Se cacher », la bénédiction, les suites chez la victime (sommeil, centre
  anti-poison), et le retrait différé du butin chez la victime.
- **27/10 (soir)** — famille « Crime », **troisième lot** (`20261027130000`) : la **détection**
  n'est plus tirée par l'écran après coup (un tricheur s'en dispensait) mais dans la fonction
  serveur de l'acte : ordres génériques illégaux (`ordre_generique_executer`), corruption de
  fonctionnaire / police / gardien (`crime_corrompre`), douanier (`crime_corrompre_douanier`),
  contrebande (`crime_contrebande`), falsification (`crime_falsifier`, objet déposé par le
  serveur). L'alerte « repéré » n'est plus publiée dans le fil public (elle l'était par erreur).
  Reste à l'écran : tracts calomnieux et fausse rumeur (chantier des rumeurs), neutralisation
  d'un député, `checkScandale`, `checkEffacementCrimes`, `payerInformateurs`.
- **27/10 (soir)** — passe de minuit cliente : **le scandale de la nuit** est tiré par le serveur
  (`minuit_scandale`, une fois par pays et par date de Paris, 15 %, `20261027140000`) ; avant,
  chaque navigateur connecté tirait le sien. Liste déplacée dans `scandales_predefinis`. Correctif
  (`20261027130100`) : les fonctions de crime rendent `inventory` et `revision`, sans quoi l'écran
  d'un inventaire versionné refusait d'adopter le nouvel inventaire. Restent à l'écran :
  `checkEffacementCrimes` et `verifierDecouverteCrimesPasses` (traces d'achats d'armes et
  d'explosifs, corruption de permis, hooliganisme encore écrites par l'écran), `payerInformateurs`.
- **27/10 (soir)** — **informateurs tenus par le serveur** (`20261027150000`/`150100`) : la liste
  n'est plus écrite par l'écran (déclencheur), recrutement par `informateur_recruter`, salaires
  prélevés chaque nuit par `minuit_informateurs` sur l'argent réel (et non plus sur le total
  affiché, par le seul navigateur connecté). **Interroger coûte 1 PA (décision de Fred)** : c'était
  une source d'influence illimitée. « Consulter la Taupe N4 » recrutait par erreur ; c'est désormais
  l'interrogation. Les informations données restent des textes d'ambiance tirés par l'écran.
- **27/10 (soir)** — **marché noir** par le serveur (`20261027160000`) : achat d'arme
  (`crime_acheter_arme_noire` : jet, dénonciation, convocation, vente au triple, trace) et
  d'explosifs (`crime_acheter_explosifs`). **Faille fermée** : `commerce_vendre_produit` en mode
  `marche_noir` s'achetait directement, sans jet ni risque. Neutralisation d'un député : trace,
  détection et avis de recherche par `assemblee_neutraliser_depute` (`20261027160100`).
  Traces encore écrites par l'écran : corruption de permis (terrains) et hooliganisme
  (organisations), chantiers de Codex — d'où `verifierDecouverteCrimesPasses` et
  `checkEffacementCrimes` maintenues pour elles.
- **27/10 (soir)** — **lancer une rumeur** par le serveur (`rumeur_lancer`, `20261027170000`).
  **Faille fermée** : les causes `rumeur_pj` (-5 à -20) et `rumeur_gouvernement` (-1 à -5) de
  `personnage_ajuster_pop_inf` permettaient à n'importe quel joueur de retirer de la popularité à
  n'importe qui, sans PA ni jet, à volonté. Reste à l'écran : l'influence d'une organisation visée
  (table du chantier organisations, perte tirée par le serveur).
- **Constat à corriger (27/10)** : le §2 dit « inventaire (le navigateur n'y écrit plus) ». C'est
  inexact : `inventaire_sauver_revision` accepte du navigateur **n'importe quel inventaire** dès
  que la révision correspond. Un joueur peut donc se fabriquer armes, explosifs, poisons,
  documents. C'est le prochain grand chantier « une seule vérité » : chaque ajout d'objet doit
  avoir son passage serveur, puis la sauvegarde de l'inventaire ne doit plus accepter que des
  retraits (ou disparaître).
- **27/10 (nuit)** — **chantier inventaire, lot 1 (achats)** (`20261027180000`) : dépôt serveur
  unique (`inventaire_deposer_interne`), catalogue serveur des objets (`objets_modeles`), achats
  d'armes au comptoir (`arme_acheter`) et au marché noir, gilet, poisons et relique
  (`objet_acheter`) déposent l'objet par le serveur. Reste (lots suivants) : récolte, tracts,
  objets trouvés, fret, employés, état civil, énigmes, missions de PNJ, effort de guerre,
  sels de l'Assemblée, puis le verrou final de `inventaire_sauver_revision`.
  Lots 2 et 3 (`20261027180100`-`180300`) : récolte (`recolte_effectuer`, limite de 2 par date
  de Paris tenue par le serveur), produits du marché non alimentaires (déposés par
  `commerce_vendre_produit_interne`), tracts électoraux et calomnieux (`tracts_imprimer`,
  détection des calomnieux par le serveur).


- **27/10 — reprise Codex, lot 4 préparé NON appliqué** : branche
  `codex/inventaire-serveur-20261027`. `sels_ammoniaque_acheter` lie paiement exact de la
  quantité réellement déposée (30 FR), caisse pharma et dépôt commun ; `objet_trouve_reclamer`
  porte le tirage, la limite quotidienne et le souvenir. Réponses versionnées adoptées telles
  quelles ; reçus protégés contre le rejeu. Le dépôt commun ne crédite plus toutes les anciennes
  piles d'une même clé et refuse les fractions d'unité. Migrations `20261027210800`/`210810`
  préparées, **aucune version de registre**, aucun prévol vivant accessible. Banc SQL annulé :
  29 assertions sous authenticated ; 12 tests Node. Fret et autres sites restent à traiter.
  `inventaire_sauver_revision` reste inchangée, conformément à Fred.

- **27/10 — lot fret préparé NON appliqué** (`20261027213520`) : dépôt, reprise,
  retrait et achat du lot indivisible rejoignent les reçus et le dépôt commun. L'index d'inventaire
  est lié à sa révision ; caisse, paiement, objets et lignes sont dans une seule transaction.
  Les contenus ne sont plus créables/augmentables par REST ; la diminution douanière existante
  reste possible. 47 assertions SQL (29 du lot précédent incluses), rôle authenticated,
  transaction annulée. Prévol vivant impératif des transitions et autorisations de caisse ;
  le calendrier de fret et les contrôles douaniers historiques ne sont pas remplacés.

- **27/10 — lot raccordements/nettoyage** : `delivrerDocumentUrbanisme` passe aussi par
  `objet_sas_deposer` pour soi, sans ajout local ni repli permissif. Huit tests des vrais handlers
  couvrent les quatre routes fret, les deux destinataires du sas, refus/panne et les routes actives
  conservées. `poserObjetMilitaire` n'avait plus d'appelant depuis le retrait serveur ;
  `doImprimerLivre` correspond à un ordre retiré, `doImprimerClandestin` à un ordre remplacé,
  `doAcheterEntreprise` à un ancien handler non raccordé (l'ordre usine reste bientôt).
  Ces quatre producteurs morts sont retirés sans inventer de nouvelles actions serveur.

- **27/10 — lot employés/groupe préparé NON appliqué** (`20261027213521`) :
  extension de `pnj_objet_transferer`, réutilisation du lecteur et du dépôt commun. Sélection
  versionnée côté PJ, identifiant stable côté PNJ, quantité partielle, protection des objets
  de quête et des équipements miroirs, reçus et rollback. Les quatre boutons concernés ne
  modifient plus les inventaires à l'écran. Banc SQL : 48 assertions, dont 29 communes.
  **Dépendance ouverte** : rapprochement des charges historiques du profil avec les possessions
  PNJ. Elles sont conservées, les transferts concernés refusés, jamais convertis silencieusement.
  Le lot ne doit pas être activé avant ce rapprochement et la protection de ses anciennes écritures.

- **27/10 — accessoires de club préparés NON appliqués** (`20261027213522`) :
  modèles de catalogue, prix historiques 80/60/150, club réel de la ville, loi, capacité,
  paiement, budget existant et dépôt dans une seule transaction avec reçu. Banc : 40 assertions
  SQL dont 29 communes, au rôle authenticated, transaction annulée. Les anciens écrivains de
  budget restent une dépendance de déploiement ; ils ne sont pas réputés sûrs par ce lot.
  Relevé statique des écritures et prévol vivant en lecture seule sous `outils/inventaire/`.
  **Le verrou final n'est ni préparé ni appliqué : les autres réceptions et changements
  d'objets ne sont pas encore tous passés sous autorité serveur.**

- **27/10 — état civil préparé NON appliqué** (`20261027214000`) : actes de naissance,
  mariage/dissolution, décès d'un PJ absent et successions définitivement réglées établis depuis
  les tables existantes, poste attesté (pas le seul libellé affiché), coût du site, unicité,
  dépôt et reçu. Les textes d'acte ne sont plus envoyés par le navigateur. Fiches historiques
  copiées dans le catalogue, fiches PJ produites depuis leurs événements réels ; aucun mariage,
  décès ou dossier de succession créé pour livrer un objet. 46 assertions PostgreSQL, dont 29
  communes, transaction annulée sous authenticated. Le verrou final reste inchangé.

- **27/10 — missions et énigme préparées NON appliquées** (`20261027214213`) :
  Pat et Jean-Lou déposent objets et étapes ensemble depuis leur emplacement réel ; calepin,
  variante et relance selon l'horloge serveur (72/144 heures réelles), clé et ouverture du
  coffre dans la transaction de présentation existante. Pas de second moteur de quête.
  Reçus empêchant une ancienne sauvegarde de réémettre colis/clé. 46 assertions PostgreSQL,
  dont 29 communes, authenticated et rollback. **Les autres écritures de progression restent
  legacy** ; leur autorité complète n'est pas déclarée vérifiée et reste un préalable au verrou.
  Le type réel de created_at est sans fuseau : interprétation UTC explicite, anciens producteurs
  à confirmer au prévol. Les échanges IA/escort et récompenses générales restent à traiter.

- **27/10 — récompenses objets et dons de tracts préparés NON appliqués** :
  `20261027215214` lie dépôt et résolution de la quête existante ; le dossier contient seulement
  les traces réelles encore valides de la ville. Les autres récompenses ne sont pas modifiées.
  **La création/progression des quêtes reste legacy**, donc ce transfert ne prouve pas leur
  autorité globale. `20261027215539` prolonge `tracts_donner_joueur` : retrait du vrai lot sous
  révision et émission dans `objets_recus`, sans objet dicté ni compensation cliente. La collecte
  atomique existante reste seule voie de réception. Aucun objet réel pour les PJ de simulation.
  Dépôt commun : format historique illisible conservé/refusé, jamais remplacé silencieusement.

- **Bilan de reprise Codex, 27/10 — non déployé** : rapport et ordre exact des dix
  migrations sous `outils/inventaire/REPRISE-20261027.md`, avec preuves brutes. Le socle
  de reçus est éprouvé sous RLS malgré des privilèges de table larges ; huit assertions à
  deux sessions vérifient l'exclusion et l'absence d'état intermédiaire, actes annulés.
  État civil scindé en `20261027214000`/`214001` pour respecter la limite MCP.
  Restent **quatre réceptions actives locales** : vol de chantier et trois remises IA.
  Charges anciennes, écrivains de budgets/caisses, progressions et sas restent des
  dépendances ouvertes ; aucun verrou final, aucune migration appliquée, aucune fusion.

- Contrôle Workflow de cette reprise : **rouge comme main**, six signalements de classement
  des cinq anciennes fixtures SQL. Chemins et sorties sous les preuves, aucun contrôle modifié
  pour les cacher. Le nouveau prévol est rangé dans `outils/bancs/`, sous transaction READ ONLY
  annulée, conformément au workflow.

- **28/10 — inventaire, Claude : plus aucun objet ajouté par l'écran.** Les dix migrations de la
  reprise Codex sont appliquées et estampillées (registre `20261028204032` → `20261028205317`,
  trois correctifs : caisses de l'usine et du port créées au besoin, acte citoyen à 50). Les quatre
  réceptions locales restantes sont fermées : `kompromat_fabriquer`, `escort_piege_tenter`,
  `crime_voler_materiaux` (jet, stock, dépôt, traces serveur), texte de l'IA posé une seule fois par
  `kompromat_rediger` ; `doEscortInfos` supprimé (aucun menu). Relevé statique refait : les seuls
  ajouts restants passent par la réponse du serveur. **PR #213 prête, fusion suspendue par Fred
  (livraison groupée).** Après la livraison : `20261028210000`, `210500`, `210600`, `210700` (anciennes
  portes, garde du fret, ancien acte de vol terrain, ancienne distribution calomnieuse).
- **Encore ouvert avant le verrou final de `inventaire_sauver_revision`** : plus aucun ajout ni
  retrait d'objet décidé par l'écran (28/10 : vol entre joueurs, tracts calomnieux et tracts de
  Jean-Lou passés au serveur ; anciennes charges d'employés : aucune en base). Le verrou lui-même
  attend l'accord de Fred. Hors inventaire : quêtes, budgets de club et autorisations de l'énigme
  encore écrits par l'écran ; voix « conférence » passée au serveur (`conference_soutenir`,
  `20261028226000`).
- Après la livraison de la PR #213 : `20261028210000`, `210500`, `210600`, `210700`, `210800`, `210900`.
