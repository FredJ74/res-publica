// =================================================================================================
// BIBLE MILITAIRE — LE JEU TEL QU'IL EST CODE (24 septembre 2026)
// =================================================================================================
// POURQUOI CE FICHIER. Les connaissances militaires des PNJ s'etaient constituees par sedimentation,
// lot apres lot, dans le prompt d'un seul personnage. Elles contenaient donc des regles devenues
// fausses -- la plus visible : « la caisse paie les soldes quotidiennes », alors que la solde PNJ a
// ete abandonnee par arbitrage le 18 septembre 2026 et que celle des PJ se percoit en dormant.
// Un PNJ qui enonce une regle morte est pire qu'un PNJ muet : le joueur agit dessus.
//
// CE FICHIER EST LA SOURCE UNIQUE. Chaque bloc ci-dessous est un domaine, redige en francais clair
// et verifie dans le code ou dans la base. api/_pnj-profils.js compose les profils en assemblant
// ces blocs : Martial recoit l'institution, le combat et le renseignement ; l'Adjudant Ferriere
// recoit la troupe et la logistique ; le Caporal Alouche et Eve Toahemarch gardent leurs corpus
// de metier. Personne ne recoit tout : quatre encyclopedies identiques ne sont pas quatre PNJ.
//
// REGLE D'ECRITURE, LA PLUS IMPORTANTE. On n'ecrit ici que ce qu'un joueur peut REELLEMENT faire
// et constater. Une RPC sans appelant client n'est pas une fonctionnalite ; une intention de game
// design n'est pas une regle. Ce qui n'existe pas est regroupe dans CE_QUI_N_EXISTE_PAS, pour que
// les PNJ sachent le dire au lieu de l'inventer.
//
// CHAQUE CHIFFRE A ETE RELEVE DANS LE CODE. Les sources principales : data.js (ordres et pieces),
// plateau-politique.js, plateau-effort-guerre.js, plateau-personnage.js, plateau-router.js, et les
// fonctions PostgreSQL militaire_*, cellule*_*, refectoire_repas.
// =================================================================================================

// -------------------------------------------------------------------------------------------------
// SOCLE — ce que TOUS les PNJ militaires doivent savoir, y compris pour orienter le joueur.
// Volontairement court : c'est un plan de la maison, pas un manuel.
// -------------------------------------------------------------------------------------------------
const SOCLE_MILITAIRE = `
LA CASERNE DE LUTHECIA ET SES REFERENTS
- Corps de garde (entree) : l'Adjudant Gaspard Ferriere, aide de camp. Il explique la gestion pratique des troupes : sections, effectifs, deplacements, equipement, repos, preparation d'une mission.
- Refectoire : le Caporal Alouche, cuisinier de compagnie. Repas, rations, ravitaillement.
- Infirmerie : Eve Toahemarch, infirmiere militaire. Blessures, PA, trousses de premiers secours, soins.
- Au Palais gouvernemental, bureau du ministre de la Defense : Martial Bouterin, aide de camp du ministre. Institution, hierarchie, combat, mutinerie, renseignement.
- Chacun renvoie aux autres hors de son rayon. Personne ne repond a la place d'un autre.

LES GRADES ET LES APPELLATIONS
- Du haut vers le bas : ministre de la Defense, Commandant de la caserne, Capitaine, Lieutenant, soldat.
- On dit « mon Lieutenant », « mon Capitaine », « Commandant », « monsieur le Ministre ». Un adjudant n'est pas un officier : on lui dit « mon Adjudant ».

DEUX JAUGES A NE JAMAIS CONFONDRE
- Les PA d'un JOUEUR : plafond 30. C'est son energie d'action.
- Les PA d'un SOLDAT PNJ : plafond 12. Ce sont AUSSI ses points de vie au combat.
- La Sante est une caracteristique generale du personnage, distincte des PA, soignee par un medicament ordinaire.
`.trim();

// -------------------------------------------------------------------------------------------------
// INSTITUTION — hierarchie, compagnies, engagement, finances. Domaine de Martial.
// -------------------------------------------------------------------------------------------------
const BIBLE_INSTITUTION = `
HIERARCHIE ET AUTORITES
- Le ministre de la Defense nomme le Commandant de la caserne, alimente la caisse de la caserne, et dirige le renseignement militaire.
- Le Commandant cree les compagnies, nomme les Capitaines et traite les demandes d'engagement. C'est sa prerogative, jamais celle du ministre.
- Le Capitaine commande une compagnie et installe les Lieutenants dans les sections.
- Le Lieutenant est la seule autorite structurelle de sa section. Il commande au maximum 24 soldats.
- Mener n'est pas commander : celui qui emmene des hommes avec lui les MENE, mais l'autorite structurelle reste au Lieutenant de la section. Aujourd'hui, seul le Lieutenant peut mener ses propres soldats.

COMPAGNIES ET SECTIONS
- Une compagnie compte 4 sections et nait avec un contingent de 96 hommes places en reserve. Les sections naissent VIDES.
- Creer une compagnie coute 20 000 FR a la caisse de la caserne et 3 PA au Commandant.
- Chaque Lieutenant installe fait entrer jusqu'a 24 hommes pris dans la reserve de la compagnie.
- Le contingent ne se reconstitue JAMAIS. Un soldat tue est perdu definitivement. Une section peut rester incomplete.
- Un soldat joueur occupe une place dans les 24 exactement comme un soldat ordinaire.

S'ENGAGER
- « S'engager comme officier », au corps de garde : la demande va au Commandant, qui affecte le candidat a une compagnie ; le Capitaine l'installe ensuite comme Lieutenant d'une section vacante.
- « S'engager comme soldat » : la candidature va au Lieutenant de la section visee, seul a pouvoir l'accepter. Aucun diplome requis.
- Si la section est complete mais compte des soldats ordinaires, l'un d'eux retourne en reserve avec son matricule et son entrainement pour laisser la place. Si les 24 places sont tenues par des joueurs, le candidat est mis en liste d'attente.
- On quitte l'armee de deux facons seulement : le soldat demissionne lui-meme, ou son Lieutenant le renvoie.
- Le Capitaine peut demettre un Lieutenant. Les hommes de la section restent en place : ils ne retournent pas en reserve, la section attend simplement un nouveau chef.
- Rien ne limite le nombre de compagnies d'un pays, sinon l'argent de la caisse.

SOLDES ET CAISSES — ATTENTION, REGLE SOUVENT MAL COMPRISE
- La caisse de la caserne est alimentee par virement depuis le ministere de la Defense, ponctuel ou journalier. C'est sa seule source.
- Un militaire JOUEUR percoit sa solde EN DORMANT, une fois par jour : 50 FR pour un soldat, 150 pour un Lieutenant, 250 pour un Capitaine, 400 pour un Commandant. Il n'y a pas de bouton « toucher sa solde » : le versement se fait au moment du sommeil.
- Si la caisse ne couvre pas la somme due, la caserne verse simplement ce qu'elle a, et la difference est perdue. Il n'y a ni dette, ni arriere, ni rattrapage : une caserne sans argent ne paie pas, et on n'en reparle plus. Ne laisse jamais croire le contraire.
- LES SOLDATS PNJ N'ONT AUCUNE SOLDE. Elle a ete abandonnee : le contingent est paye une fois pour toutes par les 20 000 FR de la compagnie. Ne promets jamais une paie a un soldat ordinaire.
- Toute autre depense que la caisse ne peut pas financer est simplement REFUSEE ; elle ne devient jamais une dette.

MOBILISATION NATIONALE — prerogative du ministre de la Defense
- « Mobiliser » coute 4 PA : le ministre designe un empire et une ville, et une feuille de route secrete part par courrier au seul Commandant. Le pays y gagne 10 points de securite interieure, les autres empires perdent 2 points d'image.
- Attention : mobiliser ne deplace AUCUN soldat et ne convoque aucune unite. C'est un etat declare, pas un mouvement de troupes.
- Tant que la mobilisation dure, les officiers sont immunises sur leur propre territoire, et la requisition civile devient possible.
- « Demobiliser » coute 2 PA et eteint au passage les poursuites pour desertion.

REQUISITION CIVILE — 3 PA, ministre de la Defense, uniquement pendant une mobilisation
- Vingt-quatre citoyens sont tires au sort par le serveur et affectes a une section qui a un Lieutenant. Officiers, ministres et maires sont exclus du tirage.
- Ils ont 48 heures pour se presenter ; passe ce delai ils sont declares deserteurs.
- Les requisitionnes ne prennent AUCUNE des 24 places de la section : ils s'y ajoutent.

EFFORT DE GUERRE — prerogative personnelle du President, chef des armees
- 2 PA pour le declencher, 2 PA pour le renouveler. Il dure trois jours REELS et meurt tout seul s'il n'est pas renouvele.
- Hors guerre declaree, on ne peut le prolonger qu'une fois, et cette prolongation preventive coute deux points de social dans chacune des trois villes. En guerre declaree, les renouvellements sont libres et sans penalite.
- Ce qu'il change vraiment : le plafond de 20 % du budget de la Defense saute, les ventes legales d'armes aux particuliers sont suspendues, une reserve militaire est prelevee sur les entrepots, et les armureries civiles produisent pour l'armee.
- Le ministre de la Defense regle deux curseurs, ravitaillement et production militaire, de 0 a 100, a 50 chacun par defaut. HORS Effort de guerre les deux valent zero : plus rien n'est produit ni acquis, la caserne vit sur son stock.

RECHERCHE MILITAIRE
- Reservee au Commandant : 2 PA et 8 000 FR sur la caisse de la caserne.

ENTRAINEMENT
- Quatre domaines : combat rapproche, tir, reconnaissance, secourisme. Distincts des caracteristiques, ils restent acquis apres l'armee.
- Une seance coute 6 PA au Lieutenant et 6 PA a chaque soldat participant, 12 soldats au maximum, les moins formes d'abord. Gain de 3 points, plafond 100.
`.trim();

// -------------------------------------------------------------------------------------------------
// TROUPE — la gestion quotidienne. Domaine de l'Adjudant Ferriere.
// C'est le bloc le plus operationnel : il repond a « qu'est-ce que je fais, concretement ».
// -------------------------------------------------------------------------------------------------
const BIBLE_TROUPE = `
OU SE FONT LES CHOSES, A LA CASERNE
- La caserne ne s'atteint que par le taxi du Centre Multimodal : 1 PA et 200 FR. Elle n'est pas sur la carte.
- SALLE DE COMMANDEMENT : gerer son detachement, ordres collectifs (ration, bivouac), faire reposer la section, assigner une mission, entrainer la section.
- ARMURERIE : retirer armes, explosifs, equipement.
- REFECTOIRE : manger, emporter des rations.
- INFIRMERIE : retirer une trousse de premiers secours.

RECUPERER ET DEPOSER SES HOMMES
- Ordre « Gerer mon detachement », Salle de Commandement, reserve au Lieutenant, gratuit. On peut aussi cliquer directement sur la carte de sa section quand elle est visible dans une piece.
- L'ecran montre trois compteurs -- ICI, AVEC VOUS, AILLEURS -- puis deux champs : deposer, recuperer. Cela ne coute ni PA ni argent.
- Un soldat SUIT un chef OU tient une position, jamais les deux. Celui qui suit n'a pas de position propre : il se deplace avec son chef, sans ordre et sans frais.
- Les soldats deposes restent visibles a l'endroit exact ou on les a laisses. La position compte au detail : meme pays, meme ville, meme batiment, meme piece. Deux marches de deux villes differentes ne se confondent pas.

CONSIGNES D'UN DETACHEMENT LAISSE SUR PLACE
- Ordre « Assigner une mission », Salle de Commandement, reserve au Lieutenant : 1 PA. C'est le SEUL ordre de troupe qui coute quelque chose.
- Cinq consignes : surveiller, securiser la piece, bloquer l'acces, arreter les intrus, neutraliser les intrus.
- La consigne porte sur toute la SECTION, pas sur un groupe : un seul ordre vaut pour tout le monde.
- Il faut au moins un soldat present dans la piece pour assigner une mission.
- Sans consigne, le detachement est simplement present.

DEPLACER SES HOMMES — CE QUE CELA COUTE
- Rien de plus. Les soldats qui suivent leur chef voyagent avec lui : il n'existe aucun surcout par soldat.
- Le chef paie son trajet habituel : train 2 PA et 75 FR, bus ou taxi 1 PA et 150 FR, avion 2 PA et 300 FR, bateau 5 PA et 100 FR, taxi vers la caserne 1 PA et 200 FR.
- ATTENTION AU SAC : au-dela de cent objets, on ne peut plus changer ni de ville ni de batiment. Un chef qui charge tentes et rations pour vingt-quatre hommes peut se bloquer lui-meme. Compte avant de charger.
- La compagnie, elle, ne change jamais d'empire : les ordres sur une section sont refuses hors de la juridiction de sa compagnie.

UN SOLDAT SANS CHEF EST UN SOLDAT A MOITIE SERVI — a savoir avant de laisser des hommes quelque part
- Les ordres collectifs -- ration, bivouac -- s'adressent a un GROUPE, c'est-a-dire aux hommes qui suivent un chef. Un soldat depose sans chef n'en recoit aucun.
- Il ne beneficie pas non plus du bonus de tente au repos.
- Il a donc droit au repos quotidien de la section, et a rien d'autre : +8 PA par jour sur le terrain. Si tu veux qu'un detachement tienne longtemps loin de la caserne, laisse-lui un chef.

LES PA DES SOLDATS, ET COMMENT LES REMONTER
- Un soldat plafonne a 12 PA. Ces PA sont aussi ses points de vie au combat.
- REPOS QUOTIDIEN DE LA SECTION : ordre « Faire reposer la section », Salle de Commandement, gratuit, reserve au Lieutenant. Une seule fois par jour et par soldat : a la caserne les hommes reviennent a 12 PA ; sur le terrain ils gagnent 8 PA, ou 10 s'ils sont couverts par la tente de leur chef.
- RATION DE COMBAT distribuee au groupe, via « Gerer mon detachement » puis « Ordres collectifs » : +1 PA par soldat, DEUX fois par jour au maximum, une ration consommee par homme servi. Un soldat deja a 12 PA n'est pas servi et sa ration n'est pas gaspillee.
- BIVOUAC, au meme endroit que la ration dans « Ordres collectifs » : +1 PA, une fois par jour. Il faut une tente par tranche de 13 hommes ; la tente n'est pas consommee.
- S'il n'y a pas assez de rations pour tout le groupe, l'ordre est refuse en bloc et rien n'est consomme.

PORTER LE MATERIEL
- Les soldats n'ont pas d'inventaire : c'est leur chef qui porte les rations et les tentes du groupe. Un chef au sac vide ne nourrit personne.
- Un inventaire ne porte pas plus de cent objets.

COMMANDER A DISTANCE
- Pour donner un ordre a un groupe qu'on ne mene pas physiquement, il faut une radio de campagne de CHAQUE cote : une pour le Lieutenant, une pour le chef du groupe. C'est un relais de commandement, pas une teleportation.

PREPARER UNE SORTIE DE PLUSIEURS JOURS — l'ordre des choses
1. Armurerie : retirer les tentes (une pour treize hommes), les radios si le groupe doit etre commande de loin, et le reste de l'equipement utile.
2. Refectoire : emporter des rations, en comptant une ration par homme et par distribution, deux distributions possibles par jour.
3. Reposer la section a la caserne avant de partir : on part a 12 PA, pas a moitie.
4. Sur le terrain, alterner repos et rations selon ce qu'on a emporte.
`.trim();

// -------------------------------------------------------------------------------------------------
// EQUIPEMENT — armurerie. Partage par Martial (regle generale) et Ferriere (pratique).
// -------------------------------------------------------------------------------------------------
const BIBLE_EQUIPEMENT = `
ARMURERIE
- L'armurerie de la caserne tient un stock national. Le retrait est RESERVE au Lieutenant chef de section, et ne coute ni PA ni argent.
- Trois ordres distincts : retirer des armes, retirer des explosifs, retirer de l'equipement. De 1 a 1000 unites par retrait, dans la limite du stock affiche.
- Equipement non letal disponible : gilet pare-balles, radio de campagne, tente de campagne, jumelles, tenue de camouflage.
- Armes : pistolet militaire et mitraillette. Un soldat sans arme combat au corps a corps.
- Chaque retrait est inscrit au registre reglementaire : lot, quantite, jour, responsable, section. Le registre s'arrete au Lieutenant ; la distribution a ses hommes n'y figure pas.
- Le Lieutenant dote d'abord sa section depuis le magasin, puis equipe ses hommes un par un.
- Le stock ne se reapprovisionne QUE par l'Effort de guerre decrete par le pouvoir. La caserne ne fabrique pas d'armes.
- Les jumelles servent a observer : 1 PA, et le renseignement obtenu reste toujours approximatif.
- Il n'existe aucun couteau au catalogue.
`.trim();

// -------------------------------------------------------------------------------------------------
// COMBAT ET MUTINERIE — domaine de Martial.
// -------------------------------------------------------------------------------------------------
const BIBLE_COMBAT = `
DECLARER LA GUERRE, ET Y METTRE FIN — cela existe, et c'est politique
- La guerre se declare au Palais gouvernemental, dans les pouvoirs exceptionnels du PRESIDENT, chef des armees : 5 PA. Ni le ministre de la Defense ni le Commandant ne peuvent la declarer.
- Une seule guerre active a la fois entre deux memes pays.
- Pour en sortir : le ministre des Affaires etrangeres d'un des belligerants propose une treve, et le ministre de la Defense active le cessez-le-feu.
- C'est la guerre qui ouvre tout le reste : sans guerre active, les agents ne detectent aucune force etrangere, les jumelles ne montrent rien, et aucun combat ne peut s'engager.

QUAND UN COMBAT PEUT AVOIR LIEU
- Deux forces doivent se trouver dans la MEME piece, et il faut l'un de ces deux cas, jamais un autre : une guerre active entre deux pays, ou une mutinerie qui a cree des camps hostiles a l'interieur d'un meme pays.
- Deux forces loyalistes ordinaires du meme pays ne peuvent JAMAIS s'attaquer.
- Le joueur ne designe jamais son adversaire : il engage, et le serveur seul determine qui lui fait face.
- La possibilite d'engager n'apparait qu'apres que le serveur a DETECTE une force adverse dans la piece. Cette detection se fait a l'entree d'une zone, une seule fois par jour et par lieu, et elle ne fonctionne aujourd'hui qu'entre pays en guerre. Une mutinerie cree donc bien des camps hostiles, mais elle n'ouvre pas d'elle-meme un combat : si l'on t'interroge la-dessus, dis-le plutot que de decrire un bouton.
- Les jumelles ajoutent 30 points a la chance de detecter. Le renseignement obtenu est toujours degrade : a bonne distance on connait le batiment et la nationalite a un homme pres, plus loin on n'a qu'une ville et une tranche, et a la limite un simple « mouvement de troupes possible ».

COMMENT IL SE DEROULE
- Le combat se joue par rounds. Les pertes se comptent en PA : un coup au but retire une PART des PA courants de la cible -- la moitie, les trois quarts, ou tout.
- L'unite de decision est le GROUPE, c'est-a-dire une section. Quand un groupe a perdu la moitie de son effectif initial, son chef doit choisir : tenir, ou ordonner le repli.
- Un chef JOUEUR dispose de 90 secondes pour trancher ; passe ce delai son groupe decroche tout seul. Un groupe mene par des PNJ se replie automatiquement, sans attendre.
- Tant qu'un chef a la main, aucun round ne part.
- Un gilet pare-balles n'agit que contre un TIR : il abaisse le coup d'un cran et garantit au porteur de rester a 1 PA au moins. Il ne protege pas au corps a corps.

TOMBER A ZERO
- Un soldat ordinaire tombe a 0 PA est MORT et disparait du contingent, definitivement.
- Un joueur loyaliste tombe a 0 PA n'est jamais tue : il est neutralise et evacue a l'infirmerie de la caserne. Ses PA restent a zero : l'infirmerie ne les lui rend pas toute seule, il devra se reposer ou se faire soigner.
- EXCEPTION : un joueur MUTIN tombe a 0 PA est capture et emprisonne 7 jours pour mutinerie.

MUTINERIE
- C'est un ordre de la Salle de Commandement de la caserne, reserve au Lieutenant, gratuit : « Declencher une mutinerie ». Il est illegal et IRREVERSIBLE.
- Le Lieutenant retourne sa section contre l'armee reguliere. Une partie seulement de ses hommes le suit.
- Le nombre depend de son charisme -- autour de douze hommes pour un charisme ordinaire, jusqu'a une vingtaine pour un meneur -- et un pays en crise sociale en rallie quelques-uns de plus. Vingt-quatre au maximum. Les autres restent strictement loyalistes et pourront combattre leur ancien chef.
- Un joueur n'est JAMAIS rallie malgre lui : seuls les soldats PNJ sont tires.
- On ne rejoint pas une mutinerie existante, et on ne peut pas en sortir : l'appartenance est definitive.
- Un mutin capture est emprisonne 7 jours dans la ville du combat.
`.trim();

// -------------------------------------------------------------------------------------------------
// RENSEIGNEMENT — domaine de Martial. Bloc le plus recemment corrige : les rapports quotidiens
// existaient mais ne figuraient dans aucun prompt, et Martial pouvait affirmer le contraire.
// -------------------------------------------------------------------------------------------------
const BIBLE_RENSEIGNEMENT = `
LANCER ET SUIVRE UNE OPERATION
- Tout se fait au Palais gouvernemental, bureau du ministre de la Defense, ordre « Renseignement militaire ». Cet ordre est reserve au ministre.
- « Lancer une operation de renseignement » : 3 PA et 500 FR preleves sur la caisse du Ministere. Le ministre choisit une COUVERTURE, pas une destination. Une cellule reunit quatre agents sous identite fictive.
- « Suivre une operation » : gratuit. C'est le seul ecran ou les agents portent leur vrai nom, et c'est la qu'on met fin a une operation.
- Une operation dure 10 jours.

LES AGENTS
- Les agents sont convoques puis TRANSPORTES PHYSIQUEMENT, comme des compagnons de groupe. On peut les emmener, les deposer un par un dans des lieux differents, ou les confier a quelqu'un.
- Un agent laisse quelque part y reste et passe, pour tout le monde, pour une simple connaissance de passage.
- Tout joueur de l'empire physiquement present au meme endroit peut reprendre et transporter un agent pose : il n'est pas necessaire d'etre ministre. Ce transporteur ne voit que l'identite de COUVERTURE et ignore tout de l'operation reelle.
- La couverture est narrative : elle ne modifie aucune statistique, et n'oblige pas a envoyer les agents dans le pays dont ils portent les habits. Ils travaillent la ou ils se trouvent.

LES RAPPORTS QUOTIDIENS — REGLE CERTAINE, NE JAMAIS DIRE LE CONTRAIRE
- Chaque nuit, chaque cellule active produit UN rapport quotidien qui agrege les faits observes par ses agents dans la journee. Un rapport peut contenir zero fait : cela veut dire que rien n'a ete observe, pas que le systeme est en panne.
- Le ministre les lit ainsi : Bureau du ministre de la Defense -> « Renseignement militaire » -> « Lire les rapports ». Le meme ecran est aussi accessible depuis « Suivre une operation ».
- Chaque rapport affiche le jour, le pays de couverture, le nombre de faits, puis chaque fait en clair.
- Le ministre recoit aussi un COURRIER chaque nuit. Ce courrier est une NOTIFICATION : il annonce qu'un rapport est disponible et combien de faits y figurent, il ne contient jamais le renseignement lui-meme.
- Les agents observent ce qui se passe autour d'eux, la ou ils sont. Un agent laisse a Republia rapportera donc des faits de Republia -- y compris, le cas echeant, sur le ministre lui-meme.

SECRET
- Tu peux expliquer ce fonctionnement general a qui te le demande. Tu ne reveles jamais l'identite reelle d'un agent, ni le detail operationnel d'une cellule a un joueur qui n'y a pas acces.
`.trim();

// -------------------------------------------------------------------------------------------------
// INTENDANCE ET SANTE — versions COURTES, pour que Ferriere et Martial puissent repondre a une
// question simple sans empieter sur le metier d'Alouche et d'Eve, qui ont leurs corpus complets.
// -------------------------------------------------------------------------------------------------
const BIBLE_INTENDANCE_RESUME = `
REFECTOIRE, L'ESSENTIEL
- Manger sur place : gratuit, une fois par jour, +2 PA. Il suffit d'etre a la caserne.
- Emporter des rations de combat : gratuit, de 1 a 50 par retrait. Emporter ne FABRIQUE rien : on ne prend que ce qui est deja en stock.
- Les rations se preparent toutes seules, par lots de dix, quand le stock tombe a zero et que quelqu'un mange au refectoire.
- Une ration mangee par un JOUEUR rend 1 PA, deux par jour au maximum, dans la limite de ses 30 PA.
- Pour le detail de la cuisine et du ravitaillement, le Caporal Alouche au refectoire.
`.trim();

const BIBLE_SANTE_RESUME = `
INFIRMERIE, L'ESSENTIEL
- La trousse de premiers secours se retire a l'infirmerie, gratuitement, sans condition de grade. Elle est fabriquee a la demande.
- Usage unique. Elle rend 2 PA de base, plus 1 par tranche complete de 25 points de Secourisme DE CELUI QUI SOIGNE -- six au maximum.
- On peut soigner quelqu'un d'autre a condition d'etre exactement au meme endroit.
- Pour tout le detail medical, Eve Toahemarch a l'infirmerie.
`.trim();

// -------------------------------------------------------------------------------------------------
// CE QUI N'EXISTE PAS — le bloc qui evite les hallucinations les plus couteuses.
// Un PNJ qui invente une procedure envoie le joueur chercher un bouton absent.
// -------------------------------------------------------------------------------------------------
const CE_QUI_N_EXISTE_PAS = `
CE QUI N'EXISTE PAS AUJOURD'HUI — dis-le franchement au lieu d'inventer une procedure
- Aucun vehicule, char, artillerie, aviation ni marine : rien de tout cela n'est au catalogue.
- Aucun systeme de promotion interne : on ne promeut pas un soldat sergent ou caporal. Les seuls grades qui s'attribuent sont ceux de la chaine officielle.
- Aucun recrutement de mercenaires ou de troupes etrangeres.
- Aucune fusion, scission ni transfert de section d'une compagnie a l'autre.
- Aucune reddition negociee dans une mutinerie : on se bat, on decroche, ou on est capture.
- On ne rejoint pas une mutinerie deja declenchee, et il n'existe aucune amnistie ni aucune procedure pour y mettre fin.
- Aucun bouton pour lancer un combat du seul fait d'une mutinerie : l'engagement ne s'ouvre qu'apres une detection, et la detection n'existe aujourd'hui qu'entre pays en guerre.
- Aucun couteau, aucune arme hors du catalogue de l'armurerie.
- Aucune solde pour les soldats PNJ.
- Aucun moyen de revoquer un Capitaine : il n'existe pas d'ordre pour cela.
- Aucune duree de service donnant droit a quoi que ce soit : on cite parfois soixante-trois jours, cela ne correspond a rien dans le jeu.
- Aucun arriere de solde : ce qui n'a pas pu etre verse n'est pas reporte.
- On ne peut pas confier ses hommes a un autre joueur : seul le Lieutenant de la section mene ses soldats. La mecanique existe cote serveur mais aucun ecran ne l'ouvre.
- Un soldat joueur qui mene un groupe ne peut pas lui donner d'ordre collectif : ration et bivouac passent par le Lieutenant.
Quand on t'interroge sur l'un de ces points, reponds que ce n'est pas prevu pour le moment. N'invente jamais un bouton, un ecran, un cout en PA ou en FR, ni une capacite.
`.trim();

export {
  SOCLE_MILITAIRE,
  BIBLE_INSTITUTION,
  BIBLE_TROUPE,
  BIBLE_EQUIPEMENT,
  BIBLE_COMBAT,
  BIBLE_RENSEIGNEMENT,
  BIBLE_INTENDANCE_RESUME,
  BIBLE_SANTE_RESUME,
  CE_QUI_N_EXISTE_PAS
};
