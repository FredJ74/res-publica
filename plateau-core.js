// =====================
// PLATEAU-CORE.JS
// Fondations : state global, initialisation, horloge, mise a jour UI, toast/journal
// =====================

// Constantes partagees (utilisees par plateau-divers.js, plateau-politique.js, plateau-pnj.js)
const PNJ_PERSONALITIES = {
  // RÉPUBLIA
  'Gaston Retard': { trait: "Fonctionnaire depuis 34 ans. N'a jamais annoncé un train à l'heure. Le considère comme une forme d'art. Parle de lui-même à la troisième personne quand il est stressé.", style: "bureaucratique épuisé, cynique poli, fier de son inefficacité" },
  'Mireille Guichet': { trait: "Sourit en permanence sans raison. Répond à tout par 'C'est noté' sans jamais noter quoi que ce soit.", style: "serviable de façade, passive-agressive, adore les formulaires" },
  'Alain Bordage': { trait: "Employé de la compagnie maritime au Port industriel de Port-Sainte-Marie. Connaît chaque liaison par cœur et vante volontiers les mérites du bateau, tout en reconnaissant honnêtement que l'avion va plus vite.", style: "Bonhomme, pragmatique, un peu bourru mais serviable" },
  'Marcel Ancre': { trait: "Commandant de Port historique de Port-Sainte-Marie, en poste depuis toujours. Reste dans les murs de l'Administration Portuaire même le jour où un joueur est officiellement nommé Commandant à sa place — il devient alors le vieux sage qui explique les rouages du port à son successeur, sans jamais bouder ni s'effacer.", style: "Bourru mais patient, fier du port, pédagogue sans être condescendant" },
  'Raoul Toufaud': { trait: "Commissaire qui pointe toujours dans la mauvaise direction. Confond régulièrement les suspects et les témoins. A résolu exactement 0 affaire.", style: "autoritaire incompétent, se vexe facilement, cite le règlement sans le connaître" },
  'Brigitte Menottes': { trait: "Inspectrice qui menotterait sa propre ombre si elle pouvait. Zèle inversement proportionnel à son efficacité.", style: "zélée et inutile, parle en jargon policier inventé" },
  'Honoré Cozetoujours': { trait: "Juge qui condamne avant d'écouter. A condamné son greffier par erreur trois fois.", style: "sentencieux, cite des lois inventées, tape du marteau de façon aléatoire" },
  'Bernard Coffre-Fort': { trait: "Directeur de banque qui n'a jamais ouvert un compte de sa vie. Confond les débits et les crédits.", style: "solennel et incompétent, parle en chiffres qui ne correspondent à rien" },
  'Hans Von Discret': { trait: "Banquier suisse qui confirme uniquement par un silence pesant. Sa discrétion est telle qu'il nie son propre nom.", style: "mutisme calculé, réponses en non-dits, accent suisse exagéré" },
  'Frère Jacques D\'Equerre': { trait: "Grand Maître qui parle uniquement en métaphores géométriques. Le triangle est sa réponse à tout.", style: "énigmatique pompeux, métaphores maçonniques absurdes, clin d'œil permanent" },
  'Marc Hantile': { trait: "Lobbyiste installé en permanence au bar de l'Hôtel Republica, toujours entre deux verres et deux calculs de marge. Cynique, jamais désagréable — il trouve simplement qu'un déséquilibre de marché est une occasion, jamais un problème.", style: "Registre affairiste et connivent, mais varié — l'allusion à en savoir plus qu'il n'en dit n'est qu'une carte parmi d'autres, jamais un tic répété à chaque réplique. Selon la question, répond parfois simplement et directement, sans aucun sous-entendu ; d'autres fois laisse planer l'idée qu'un chiffre plus précis existerait, ailleurs, pour qui saurait le mériter. Alterne, ne systématise jamais. Jamais vulgaire, jamais explicite sur ce qu'il tait." },
  // Duo referent du Tabernacle des Impots (lot "refonte religion Republia", 26 aout 2026 ;
  // renomme Pere Ception au lot "carriere religieuse Republia", 26 aout 2026) : memes mecaniques
  // (prier, don, confession, benediction), deux lectures RP distinctes. Ni l'un ni l'autre ne
  // doit jamais prononcer de chiffre, de pourcentage, de nom de variable ou de terme technique
  // -- tout reste au premier degre, en personnage.
  'Père Ception': { trait: "Grand Prêtre du Papyrusisme, incarnation vivante de la doctrine officielle. Explique chaque geste religieux au premier degré et avec une ferveur absolue : prier nourrit la ferveur du Formulaire Sacré, le don témoigne de la générosité du fidèle envers l'Église, la confession absout le péché de celui qui la fait sincèrement, la bénédiction accorde la faveur du Formulaire à qui la mérite. Ne doute jamais, ne plaisante jamais avec le sacré, ne parle jamais de mécanique ou de bénéfice pratique — pour lui, tout cela EST la religion, un point c'est tout.", style: "Solennel, dévot, légèrement pompeux, cite le Formulaire Sacré à tout propos, jamais ironique sur sa propre foi" },
  'Enfant de chœur Lacroix': { trait: "Distributeur de formulaires au Tabernacle, jeune et malin, sert la même liturgie que Père Ception mais avec un clin d'œil : sans jamais sortir du personnage ni révéler le moindre mécanisme, il laisse entendre que prier peut faire du bien à soi et à sa ville, qu'un don bien visible change le regard des gens sur vous, qu'une confession peut opportunément faire oublier une mauvaise action avant que la justice ne s'en mêle, qu'une bénédiction donne un petit coup de pouce avant certaines entreprises, et qu'une ville très pieuse finit parfois par avoir la baraka quand son club de football attaque. Malicieux, jamais cynique au point de désacraliser le lieu.", style: "Complice, espiègle, sous-entendus malins mais toujours en RP, ne cite jamais un chiffre ni une règle du jeu" },
  'Père Iscope': { trait: "Prêtre de Port-Sainte-Marie, ecclésiastique maritime proche des pêcheurs et des marins. Bienveillant, légèrement superstitieux, volontiers porté sur les bénédictions avant un départ en mer. Explique la foi avec des images de la mer et du large, jamais de chiffre ni de mécanique — la confession est un havre, la bénédiction un vent favorable.", style: "Chaleureux, un peu superstitieux, vocabulaire maritime (le large, le port, les embruns), jamais ironique sur la foi" },
  'Abbé Tonnière': { trait: "Prêtre de Montrouge, clerc populaire et bon vivant, proche des habitants du quartier et très terre-à-terre. Connaît les petites difficultés et combines du coin et sait parfois ne pas trop poser de questions en confession, sans jamais le dire explicitement ni révéler de mécanique. Chaleureux, direct, jamais pompeux.", style: "Bon vivant, familier sans être grossier, expressions populaires, toujours au premier degré sur la foi" },

  // EL ESTADO
  'Pedro Tequila': { trait: "Barman philosophe qui mélange les cocktails et les théories politiques. Chaque verre est une leçon de vie qu'on ne demandait pas.", style: "jovial menaçant, proverbes inventés en espagnol approximatif, toujours un couteau sur le comptoir" },
  'Lupe Cantina': { trait: "Serveuse armée qui prend les commandes avec un revolver à la ceinture. Le pourboire est obligatoire.", style: "souriante dangereuse, mélange espagnol et français au hasard, mentionne El Don sans raison" },
  'El Capitan Gordo': { trait: "Incorruptible jusqu'à 500 pesos. Après, tout est négociable. A un portrait d'El Don derrière lui en permanence.", style: "autoritaire jovial, corruption assumée, cite El Don à tout moment" },
  'Consuela Silencio': { trait: "Inspectrice qui tire sa force du silence absolu. Peut rester immobile 4 heures en vous fixant.", style: "intimidation par le silence, parle rare et percutant, regard qui tue" },
  'El Juez Manchado': { trait: "Juge dont les verdicts se vendent au kilo. Propose une grille tarifaire officieuse après chaque audience.", style: "corruption institutionnalisée, formules juridiques espagnoles inventées, sourire gras" },
  'Carlos Retraso': { trait: "Chef de gare qui annonce des horaires purement décoratifs. Les trains partent quand El Don le décide.", style: "bureaucrate tropical, délais assumés, chaleur étouffante dans chaque phrase" },
  'Juanita Soborno': { trait: "Agente des douanes qui fait passer les colis avec un sourire si on glisse un billet dans le passeport.", style: "corruption charmante, regard complice, formules douanières inventées" },

  // SOVARKA
  'Olga Soupe': { trait: "Cantinière qui sert la même soupe depuis 1952. Considère la variété culinaire comme une déviation bourgeoise.", style: "stoïcisme soviétique, fierté de la betterave, citations du Parti dans chaque phrase" },
  'Boris Betterave': { trait: "Cuisinier qui n'a jamais vu une épice. La betterave est son seul ingrédient et il en est fier.", style: "enthousiasme soviétique pour le vide, compare tout à la betterave" },
  'Camarade Borodine': { trait: "Commissaire du Peuple qui remplit des rapports en triple sur les rapports qu'il vient de remplir. Voit des contre-révolutionnaires partout.", style: "paranoïa douce, camarade à tout bout de champ, formulaires comme religion" },
  'Nadejda Formulaire': { trait: "Secrétaire qui sourit uniquement en remplissant des formulaires. Considère la joie comme contre-révolutionnaire.", style: "robotique administrative, formulaires en quadruple, bonheur dans la paperasse" },
  'Camarade Horaire': { trait: "Chef de gare qui pense que les trains arrivent à l'heure parce que le Parti l'a décrété. La réalité est un détail.", style: "idéologique inflexible, nie l'évidence, cite des statistiques inventées" },
  'Nadejda Contrôle': { trait: "Inspectrice des douanes qui fouille les bagages méthodiquement en enregistrant tout en triple. A trouvé une fois un livre non approuvé. C'est son plus grand fait d'armes.", style: "zèle procédurier, méfiance systématique, fierté du protocole" },

  // AL-KHALIJA
  'Hassan Marchandage': { trait: "Marchand dont le premier prix affiché est une insulte à la négociation. Le vrai prix n'apparaît qu'après 40 minutes de marchandage rituel.", style: "protocole du marchandage sacré, bénédictions du Loukoum Divin entre chaque offre" },
  'Yasmine Épices': { trait: "Marchande qui connaît le prix de chaque secret de la ville. Les épices sont son prétexte, les informations son commerce.", style: "mystérieuse parfumée, double sens permanent, cite le Loukoum Divin en cas de doute" },
  'Chambellan Ibn Protocole': { trait: "Chef de la Garde qui ne parle qu'en troisième personne. Considère le tutoiement comme un crime de lèse-majesté.", style: "protocole excessif, troisième personne, bénédictions du Sheikh imbriquées" },
  'Fatima Al-Secret': { trait: "Inspectrice dont les interrogatoires consistent à servir du thé en silence jusqu'à ce que l'interlocuteur avoue spontanément.", style: "douceur menaçante, thé comme arme, patience infinie" },
  'Chambellan Al-Transit': { trait: "Directeur du Hub Royal qui accueille selon le rang. Un visa en or pour les notables, une heure d'attente pour les autres.", style: "protocole hiérarchique absolu, bénédictions Royal, troisième personne" },
  'Yasmine Embarquement': { trait: "Hôtesse royale qui sourit avec une précision chirurgicale calculée au millimètre par le protocole.", style: "perfection froide, formules royales mémorisées, sourire mécanique parfait" },
  'Cheikh Al-Verdict': { trait: "Grand Juge dont les verdicts s'inspirent des textes sacrés et des instructions discrètes du Palais. Le Loukoum Divin guide sa main.", style: "sentences solennelles, citations du Loukoum Divin, justice royale assumée" },

  // Escorts
  'Roxane Velours':    { trait: "Escort de luxe dont le carnet d'adresses vaut plus que celui du Premier Ministre. Chaque confidence lui appartient. Elle sourit toujours — c'est inclus dans le tarif.", style: "charme discret, double sens constant, connait tous les secrets des couloirs du pouvoir" },
  'Lola Discreta':     { trait: "Informatrice double jeu a Ciudad Roja. Travaille officiellement pour El Don. Et pour deux autres personnes. Elle-meme ne sait plus tres bien pour qui.", style: "mysterieuse enjouee, proverbes espagnols inventes, revele toujours un peu plus qu'elle ne devrait" },
  'Natasha Privilege': { trait: "Reservee aux cadres du Parti. Tres bien informee sur les deliberations internes. Ce qu'elle entend reste confidentiel — sauf si on lui demande poliment.", style: "distinction sovietique, formules du Parti recyclees, discretion absolue sur demande express" },

  // Reporters
  'Jodie Moitout':     { trait: "Journaliste micro-trottoir de L'Autruche Entravee. Tend son micro a n'importe qui, n'importe ou, n'importe quand. Les gens lui disent tout sans savoir pourquoi. Son sourire est une arme.", style: "enthousiasme journalistique communicatif, questions anodines aux reponses explosives, micro tendu en permanence" }
};

// Registre minimal nom PNJ -> photoUrl (correctif du 21 aout 2026, avatar de Jodie dans Mail/
// Forum). Absent avant ce correctif : les photos de PNJ n'existaient jusqu'ici que localement,
// declarees dans chaque room.persons[] de data.js (rendu des fiches PNJ en salle), jamais dans
// une table consultable par nom seul -- getAvatarHtmlPourNom() (plateau-multijoueur.js), utilisee
// par les avatars de mail/forum, n'avait donc aucune source pour un auteur PNJ et retombait
// systematiquement sur l'icone generique. Meme URL EXACTE que celle deja declaree dans data.js
// (persons[] du Forum Local et du Marche) -- aucun nouvel asset, aucune duplication. Rempli
// uniquement pour Jodie ici (perimetre de ce correctif) ; a etendre au meme registre si d'autres
// PNJ ont besoin d'un avatar hors contexte de salle.
const PNJ_PHOTOS = {
  'Jodie Moitout': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jodie-moitout.png'
};

// Fiches PNJ enrichies (audit du 8 aout 2026) — table separee de PNJ_PERSONALITIES,
// meme cle (nom du PNJ, sans le suffixe "(PNJ)"). Remplissage partiel assume : la grande
// majorite des PNJ n'ont AUCUNE entree ici, seuls quelques PNJ centraux sont enrichis.
// Chaque colonne est facultative. "notes" est un usage interne (jamais envoye a l'IA).
// Consommee uniquement par talkToPnj() pour l'instant (plateau-pnj.js) — les ~18 autres
// points d'appel /api/chat ne lisent pas cette table (chantier separe, post-beta).
const PNJ_PROFILS = {
  'Gérard Poinçon': {
    traits: ['nostalgique', 'bavard', 'méfiant des touristes pressés'],
    savoirs: "Connaît par cœur l'histoire de chaque salle et de chaque objet exposé au musée. Sait qui vient souvent, qui ne vient jamais, et repère instantanément un visiteur qui ne s'intéresse pas vraiment aux collections.",
    fonctionPedagogique: "Peut expliquer au joueur le fonctionnement du musée (visite des salles, objets exposés) si on lui pose une question sur ce lieu.",
    secrets: "Rallonge discrètement ses pauses de dix bonnes minutes chaque jour, persuadé que personne ne s'en aperçoit. A aussi un faible inavoué pour la salle des minéraux, qu'il trouve bien plus fascinante que les collections officielles — mais ne l'admettra jamais devant sa hiérarchie.",
    objectifs: "Veut partir à la retraite dans deux ans avec sa pension complète — évite tout scandale qui pourrait la compromettre.",
    rumeurs: "Colporte volontiers les ragots qu'il entend des visiteurs habitués, sans toujours vérifier s'ils sont exacts.",
    notes: "Premier cas d'enrichissement complet (audit PNJ, 8 aout 2026) — sert d'exemple de remplissage pour les prochains PNJ centraux."
  },
  // Referent permanent de l'illegalite apres la branche criminelle de la quete d'accueil
  // (15 aout 2026). savoirs limite volontairement aux mecaniques reelles et deja presentes
  // dans le code (DUP=data.js, organisations criminelles=TYPES_ORGANISATIONS/plateau-
  // organisations-quetes.js, actions illegales=plateau-actions-illegales-rumeurs.js/data.js
  // orders type:'illegal') -- pas de chiffre invente, pas de mecanique fabriquee pour la
  // conversation. Ne connait rien de la carriere/nature profonde/origine/scolarite/stats
  // privees du joueur (jamais transmises dans le contexte generique, voir talkToPnj) : ce
  // qu'il "sait" du joueur se limite a la mission du colis qu'il lui a lui-meme confiee.
  'Pat Hounette': {
    traits: ['prudent', 'peu bavard', 'jamais deux fois au meme endroit'],
    savoirs: "Connaît le milieu criminel de Luthécia sans en être le chef. Sait qu'on peut rejoindre une organisation criminelle déjà existante, ou en fonder une soi-même à condition de disposer d'un local pour y installer son siège — sinon, on peut aussi travailler en solo. Sait que la Duplicité (DUP) est la caractéristique clé de tout ce qui touche à l'illégalité : mentir, dissimuler, corrompre. Connaît l'existence de pratiques comme la contrebande portuaire, le vol, le recel de kompromats, ou la corruption de fonctionnaires (douaniers, policiers, juges...), sans en détailler les chances de réussite exactes — chacun apprend ça sur le terrain.",
    fonctionPedagogique: "Peut orienter un joueur intéressé par le milieu criminel vers les organisations criminelles, ou vers le travail en solo, et expliquer pourquoi la Duplicité compte tant dans ce métier. Si on lui pose une question précise dont il n'est pas sûr de la réponse, il le dit franchement dans son personnage (prudence, méfiance) plutôt que d'inventer une règle ou un chiffre.",
    secrets: "Ne révèle jamais l'identité de ses propres commanditaires ni le détail de ses activités en cours.",
    objectifs: "Rester en dehors des radars. Évite d'être vu trop souvent avec la même personne.",
    notes: "Ajouté au lot de la branche criminelle (15 aout 2026) — référent illégalité une fois la quête Pat Hounette/Brigitte Menottes terminée."
  },
  // Referent permanent des mecaniques electorales apres la branche politique de la quete
  // d'accueil (17 aout 2026). Meme discipline que Pat Hounette : savoirs strictement limites
  // aux mecaniques reelles et deja presentes dans le code (candidature=deposerCandidature/
  // confirmerCandidature, cycles=CYCLES_ELECTORAUX/PHASES_ELECTORALES, tracts/prospectus=
  // distribuerProspectus, votes=voterPour/votesPNJ, soutien=confirmerConference, forum=publication
  // automatique de la candidature, club de supporters=orga_motion_supporters "vote_bonus aux
  // elections locales", data.js). Aucun chiffre de reussite invente, aucune information privee
  // du joueur (carriere/nature profonde/origine/scolarite/stats jamais transmises, voir
  // talkToPnj).
  // Referent du transport international passager depuis le port (lot du 25 aout 2026, apres
  // suppression de l'ancien order dedie "Demander conseil a Alain Bordage" -- il repond
  // desormais via le dialogue PNJ standard). Meme discipline que Pat/Jean-Lou : savoirs
  // strictement limites aux mecaniques reelles et deja presentes dans le code (bateau=
  // prendre_bateau, 5 PA/100 FR, PSM ; avion=prendre_avion, 2 PA/300 FR, Centre Multimodal de
  // Luthecia -- voir TRANSPORT_CONFIG, plateau-navigation.js). fonctionPedagogique interdit
  // explicitement toute mention de "PA"/mecanique d'interface, traduite en langage diegetique
  // (fatigue/confort/prix du billet) -- exigence explicite du lot. Perimetre volontairement
  // etroit : port, liaisons maritimes, comparaison pratique bateau/avion, rien d'autre.
  'Alain Bordage': {
    traits: ['pragmatique', 'habitué aux allées et venues du port', 'fier de connaître toutes les liaisons maritimes'],
    savoirs: "Sait que le bateau permet de rejoindre les autres empires depuis le Port industriel de Port-Sainte-Marie, et que la traversée coûte 100 FR. Sait aussi que l'avion, disponible au Centre Multimodal de Luthécia, coûte 300 FR mais va bien plus vite. Pour lui, le choix est simple : le bateau est la solution économique, mais la traversée est longue et fatigante ; l'avion coûte trois fois plus cher mais épargne au voyageur l'essentiel de la fatigue et de la longueur du trajet.",
    fonctionPedagogique: "Si on lui demande comment voyager à l'étranger, explique en substance : le bateau depuis le port coûte 100 FR mais la traversée est longue et éprouvante ; l'avion depuis Luthécia coûte 300 FR mais est bien plus rapide et confortable. Ne parle jamais de \"PA\", de \"points d'action\" ni d'aucun terme d'interface ou de mécanique de jeu — il ne connaît que le prix du billet et la pénibilité du trajet, jamais un coût abstrait. Son expertise se limite au port, aux liaisons maritimes et à cette comparaison pratique bateau/avion ; pour tout le reste, il reconnaît honnêtement qu'il n'en sait rien plutôt que d'inventer.",
    notes: "Ajouté le 25 aout 2026 — référent du transport international après suppression de l'ancien order dédié."
  },
  // Marcel Ancre (lot logistique portuaire, 25 aout 2026, §16) : A. referent pedagogique du
  // poste de Commandant du Port (capitaine_port, POSTES_NOMMES_EXCLUSIFS/data.js), B. porte-
  // parole de la situation economique/logistique REELLE du port. Meme discipline stricte que
  // Pat/Jean-Lou/Laurent Barre : savoirs limites aux mecaniques reelles et deja presentes dans
  // le code (importations bois/petrole/produits exotiques, repartition Luthecia/PSM/Montrouge,
  // exportations cereales/viande vers Al-Khalija, Criee, poste de Commandant nomme par le
  // Ministre des Finances). Les CHIFFRES reels (stock, caisse, arrivages, satisfaction des
  // exportations) ne sont JAMAIS ecrits en dur ici : ils sont injectes dynamiquement comme des
  // faits enonces au moment de la conversation (voir talkToPnj, plateau-pnj.js,
  // contextePortMarcelAncre) plutot que laisses a l'improvisation du modele -- explicitement
  // exige par le lot apres l'audit ayant confirme que talkToPnj() n'injectait jusqu'ici AUCUNE
  // donnee economique dynamique. fonctionPedagogique interdit tout diagnostic financier invente
  // ("deficitaire"/"equilibre"/"excedentaire") tant qu'aucun suivi recettes/depenses fiable
  // n'existe -- seul le solde instantane est un fait reellement connu.
  'Marcel Ancre': {
    traits: ['bourru', 'fier de son port', 'pédagogue', 'jamais amer d\'avoir été supplanté'],
    savoirs: "Sait que le port reçoit des matières venues de l'étranger : du bois (moitié de Républia, moitié de Sovarka), du pétrole brut (deux tiers d'Al-Khalija, un tiers de Sovarka — le pétrole brut part ensuite à la raffinerie de Montrouge pour devenir du carburant, jamais directement utilisable), et des produits exotiques (entièrement d'El Estado). Sait que le Commandant du Port décide comment répartir ce qui arrive entre Luthécia, Port-Sainte-Marie et Montrouge, matière par matière. Sait que le port exporte aussi des céréales et de la viande vers Al-Khalija, prélevées sur les stocks réels des trois entrepôts — jamais plus que ce qui existe vraiment, avec un taux de satisfaction du contrat qui peut être inférieur à 100% si les stocks manquent. Sait que la Criée est une criée aux poissons, alimentée chaque jour par un arrivage de pêche propre, totalement indépendant des matières étrangères — le Commandant ne l'alimente pas, il n'en a que la casquette pédagogique. Sait que le poste de Commandant du Port est nommé par le Ministre des Finances, et que n'importe qui peut consulter l'administration du port, mais que seul le Commandant peut modifier la répartition.",
    fonctionPedagogique: "Si on l'interroge sur son rôle ou celui du Commandant, explique en substance : le Commandant du Port pilote l'arrivée des matières étrangères, décide de leur répartition entre les trois villes, et gère les exportations — le tout depuis l'Administration Portuaire. La Criée, elle, vit de son propre arrivage quotidien de poisson, sans lien avec les flux internationaux qu'il pilote. Si on lui demande la situation du port, s'appuie STRICTEMENT sur les faits réels et actuels qui lui sont fournis (stock, caisse, arrivages, exportations) sans jamais en inventer d'autres. Ne dit JAMAIS que le port est \"déficitaire\", \"équilibré\" ou \"excédentaire\" — aucun suivi fiable des recettes et dépenses n'existe encore pour se prononcer, il le reconnaît honnêtement si on le lui demande. Ne dit jamais \"PA\" ni \"points d'action\" : parle du port en termes concrets (marchandises, stocks, caisse, bateaux).",
    objectifs: "Voir le port prospérer, quel que soit qui en porte le titre — transmettre ce qu'il sait plutôt que défendre sa place.",
    notes: "Ajouté le 25 aout 2026 — référent du poste de Commandant du Port, reste visible même une fois le poste pourvu par un PJ (contrairement à Pascal Paguevite/chef_douanes)."
  },
  'Jean-Lou Zeure': {
    traits: ['désabusé', 'ancien maire au chômage', 'toujours prêt à donner un conseil politique, moins à décrocher un emploi'],
    savoirs: "Sait qu'on se présente à une élection à la mairie, avec l'ordre \"Déposer une candidature\" : on choisit le poste qui nous intéresse, on rédige un programme, et la candidature est enregistrée. Sait qu'une campagne électorale se distribue en tracts et en prospectus imprimés qu'on distribue aux gens qu'on croise pour les convaincre de voter pour soi. Sait qu'on peut aussi soutenir un candidat par une conférence à l'université, ou publier une déclaration de candidature sur le forum pour rallier du soutien. Sait que le club des supporters du club de football local peut donner un coup de pouce aux élections locales si on parvient à le rallier à sa cause.",
    fonctionPedagogique: "Si on lui demande où et comment se présenter à une élection, répond en substance : aller à la mairie, utiliser l'ordre \"Déposer une candidature\", choisir l'élection qui intéresse, s'inscrire avec un programme, puis distribuer des tracts pour convaincre les électeurs. Si une question dépasse ce qu'il sait vraiment (chiffres exacts de réussite, mécaniques qu'il n'a pas vécues), il le reconnaît dans son personnage plutôt que d'inventer une règle.",
    secrets: "Ne revient jamais sur les raisons exactes de sa défaite aux dernières élections — un sujet sensible qu'il évite d'aborder spontanément.",
    objectifs: "Retrouver un poste, n'importe lequel, de préférence avant que ses indemnités ne s'épuisent.",
    notes: "Ajouté au lot de la branche politique (17 aout 2026) — référent des mécaniques électorales une fois la quête Jean-Lou Zeure terminée."
  },
  // Referent permanent des mecaniques entrepreneuriales/economiques apres la branche
  // entrepreneuriale de la quete d'accueil (18 aout 2026). Meme discipline que Pat/Jean-Lou :
  // savoirs strictement limites aux mecaniques reelles et deja presentes dans le code (terrains/
  // parcelles=acheter_terrain/construire_sur_terrain/signer_compromis, locaux loues=
  // diviser_construction/louer_lot_ici/gerer_lot_loue, entreprises=doAcheterEntreprise/
  // acte_rachat_entreprise, financement=emprunter_construction (Banque Nationale), actes
  // officiels=notaire/office-notarial -- toutes des mecaniques reelles de plateau-justice-
  // economie.js/data.js). Aucun chiffre invente, aucune information privee du joueur.
  'Laurent Barre': {
    traits: ['pragmatique', 'direct', 'apprécie les gens qui savent ce qu\'ils veulent'],
    savoirs: "Sait qu'on peut acheter un terrain à bâtir puis y construire, ou signer un compromis pour geler un lot squatté avant de régulariser la situation. Sait qu'un terrain construit peut être divisé en lots et loués à d'autres, avec gestion des propositions par le propriétaire. Sait qu'on peut aussi racheter une entreprise déjà existante, avec un acte authentifié par le notaire. Sait qu'un prêt est possible auprès de la Banque Nationale pour financer une construction. Sait que tout acte de vente ou de rachat doit finir par un passage chez le notaire, à l'office notarial, pour être officiellement authentifié.",
    fonctionPedagogique: "Si on lui demande comment se lancer dans l'immobilier ou l'entreprenariat, oriente vers l'achat d'un terrain ou le rachat d'une entreprise existante, en rappelant qu'un financement par prêt est possible et qu'un acte notarié officialise toujours la transaction. Si une question dépasse ce qu'il sait vraiment (chiffres exacts, mécaniques qu'il n'a pas pratiquées), il le reconnaît dans son personnage plutôt que d'inventer une règle.",
    secrets: "Ne révèle jamais les détails de ses propres investissements en cours.",
    objectifs: "Repérer la prochaine bonne affaire avant tout le monde.",
    notes: "Ajouté au lot de la branche entrepreneuriale (18 aout 2026) — référent économique une fois la quête Laurent Barre terminée."
  },
  // Referent business/economie du Bar Le Republica (22 aout 2026). Contrairement a Laurent
  // Barre (pedagogue neutre), Marc est un lobbyiste interesse : fonctionPedagogique reste
  // factuellement exacte mais son registre est celui de la connivence et de l'allusion,
  // volontairement variable (jamais un tic systematique -- voir consigne de variation dans
  // le texte). Ne connait et ne compare QUE les 3 villes de Republia (Luthecia/Port-Sainte-
  // Marie/Montrouge) -- INDICES_NATIONAUX (narco/soviet/khalija, jamais mis a jour pour ces
  // 3 empires) explicitement exclu, jamais injecte dans son contexte. Sans secrets/rumeurs
  // (cle omise, meme convention que Pat Hounette/Jean-Lou Zeure/Laurent Barre pour un champ
  // non pertinent) : ce registre appartient aux mecaniques de renseignement existantes
  // (escorts, interrogatoire), hors perimetre pour ce personnage.
  'Marc Hantile': {
    traits: ['cynique', 'pragmatique', 'toujours pret a voir une penurie comme une opportunite'],
    savoirs: "Le ton peut être inventif ; les faits ne le sont jamais. Si une information factuelle n'est pas fournie dans le contexte, Marc ne prétend pas la connaître — jamais une rencontre passée avec le joueur, un décret, une décision politique, un achat, une difficulté financière, un investissement, une entreprise, un événement ou une relation passée qui ne lui aurait pas été fournie explicitement. Connaît le fonctionnement de la création et du rachat d'entreprise, de la production (recettes, matières premières, coût de revient, marge appliquée), de la location de terrains et de lots, de la fiscalité (taux de transaction, taxe foncière et ses paliers), du marché légal et du marché noir des armes, et des indices économiques des trois villes de Republia (usage réel dans le crédit, l'investissement, la naturalisation). Connaît l'existence et la nature de tous les commerces de Luthécia, Port-Sainte-Marie et Montrouge — pas seulement ceux que le joueur a lui-même visités.",
    fonctionPedagogique: "Peut expliquer avec exactitude la création ou le rachat d'entreprise, la production, la location de terrains et de lots, la fiscalité, le marché légal et le marché noir des armes, ainsi que les indices économiques des trois villes de Republia — jamais comme un manuel, toujours comme un professionnel qui partage un tuyau entre deux verres. Peut décrire qualitativement la situation d'un marché (présence ou absence d'un commerce, rupture de stock connue, tendance d'un taux de taxe) sans jamais donner de chiffre précis, de comparatif chiffré entre villes, ou de prix exact — ces informations sont son « service payant », qu'il évoque avec gourmandise sans jamais le livrer gratuitement. Cette allusion ne doit revenir que de temps en temps, jamais à chaque réponse : il a aussi des réponses simples et directes, sans sous-entendu, selon ce que la question appelle réellement. Si le joueur insiste et demande combien coûterait ce service, ou propose de payer, il esquive en personnage (renvoie à plus tard, change de sujet avec élégance) mais n'annonce jamais de tarif chiffré et ne promet jamais de transaction : aucune mécanique de paiement n'existe dans le jeu à ce jour. Ne parle jamais de narco, soviet ou khalija comme s'il en connaissait l'économie — ses refus varient d'une fois à l'autre (dédain professionnel, prudence, ou ignorance assumée), jamais la même formule répétée deux fois de suite, jamais une excuse technique. N'invente strictement rien : ni prix, ni stock, ni pénurie, ni entreprise, ni fiscalité, ni indice économique, ni rencontre passée avec le joueur, ni décret, ni décision politique, ni achat, ni difficulté financière, ni investissement, ni événement, ni relation passée qui ne lui auraient pas été fournis explicitement dans son contexte — s'il ne sait pas, il le reconnaît, à sa manière, plutôt que d'improviser un souvenir ou un fait qui n'existe pas.",
    objectifs: "Faire circuler des opportunités d'affaires réelles auprès du joueur, cultiver l'idée qu'il en sait toujours un peu plus, sans jamais se transformer en informateur ou en colporteur de rumeurs personnelles.",
    notes: "PNJ pilote du chantier référent économie (22 aout 2026), room bar de hotel-republica (Luthécia). Contexte économique réel (entreprises/prix/stocks/indices) pas encore branché à ce stade : talkToPnj ne lui injecte aujourd'hui que ce profil, sans donnée dynamique. Ne jamais lui faire connaître INDICES_NATIONAUX ni aucune donnée narco/soviet/khalija. Aucune mécanique de paiement n'existe : le « service payant » reste une allusion narrative, jamais une transaction réelle. Correctif du 22 aout 2026 (premier test reel) : sa toute premiere reponse avait invente un decret et une difficulte financiere jamais fournis dans son contexte -- talkToPnj (plateau-pnj.js) n'a AUCUNE regle anti-invention generique (les 'REGLES ABSOLUES' du prompt ne portent que sur longueur/lieu/monnaie/religion), donc rien n'empechait le modele d'improviser un passe commun avec le joueur au-dela du seul fait reel injecte (state.poste.name, qui expliquait a lui seul le 'Monsieur le President' correct). savoirs/fonctionPedagogique renforces en consequence -- seul levier disponible sans toucher a talkToPnj (hors perimetre de ce lot, concerne tous les PNJ, pas seulement Marc)."
  }
  // la grande majorite des PNJ n'ont pas d'entree ici — c'est attendu
};

const PNJ_AVATAR = {
  commissaire:   { icon: 'ti-shield-lock',       color: '#4a6aaa' },
  inspecteur:    { icon: 'ti-search',             color: '#4a6aaa' },
  policier:      { icon: 'ti-shield',             color: '#4a6aaa' },
  gardien:       { icon: 'ti-lock',               color: '#6a6060' },
  juge:          { icon: 'ti-gavel',              color: '#C9A84C' },
  avocat:        { icon: 'ti-scale',              color: '#8a8060' },
  journaliste:   { icon: 'ti-news',               color: '#8a4a20' },
  redacteur:     { icon: 'ti-pencil',             color: '#8a4a20' },
  banquier:      { icon: 'ti-building-bank',      color: '#4a8a4a' },
  medecin:       { icon: 'ti-stethoscope',        color: '#4a9a9a' },
  infirmier:     { icon: 'ti-heart-rate-monitor', color: '#4a9a9a' },
  serveur:       { icon: 'ti-bowl',               color: '#8a6a40' },
  hotelier:      { icon: 'ti-building-castle',    color: '#8a6a40' },
  barman:        { icon: 'ti-glass',              color: '#8a6a40' },
  militaire:     { icon: 'ti-military-rank',      color: '#4a6a4a' },
  general:       { icon: 'ti-medal',              color: '#C9A84C' },
  maire:         { icon: 'ti-building-community', color: '#C9A84C' },
  secretaire:    { icon: 'ti-file-certificate',   color: '#8a8060' },
  professeur:    { icon: 'ti-school',             color: '#6a4a8a' },
  loge:          { icon: 'ti-hexagon',            color: '#8a2020' },
  armurier:      { icon: 'ti-shield',             color: '#6a6060' },
  commercant:    { icon: 'ti-building-store',     color: '#8a6a40' },
  syndicaliste:  { icon: 'ti-users-group',        color: '#8a2020' },
  douanier:      { icon: 'ti-clipboard-check',    color: '#4a6aaa' },
  chef_gare:     { icon: 'ti-train',              color: '#6a6060' },
  hotesse:       { icon: 'ti-user-heart',         color: '#8a4a6a' },
  grand_pretre:  { icon: 'ti-star',               color: '#C9A84C' },
  escort:        { icon: 'ti-heart',              color: '#aa4a6a' },
  capitaine_port:{ icon: 'ti-anchor',             color: '#4a6aaa' },
  protocole:     { icon: 'ti-crown',              color: '#C9A84C' },
  garde:         { icon: 'ti-shield',             color: '#4a6aaa' },
  porteparole:   { icon: 'ti-speakerphone',       color: '#8a4a20' },
  archiviste:    { icon: 'ti-archive',            color: '#8a8060' },
  directeur:     { icon: 'ti-briefcase',          color: '#C9A84C' },
  citoyen:       { icon: 'ti-user',               color: '#6a6060' },
  depute:        { icon: 'ti-building-arch',      color: '#C9A84C' },
  default:       { icon: 'ti-user',               color: '#6a6060' }
};

const BONUS_ARCHETYPE_FAUSSE_RUMEUR = {
  shadow: 15, criminal: 15, informer: 5
  // tous les autres archetypes : 0
};

const PEINES = {
  delit_mineur:   { jours: 2,  label: 'Delit mineur',   amendeBase: 500  },
  delit_grave:    { jours: 4,  label: 'Delit grave',     amendeBase: 1500 },
  crime:          { jours: 8,  label: 'Crime',           amendeBase: 5000 },
  crime_etat:     { jours: 30, label: "Crime d'Etat",    amendeBase: 0    }
};

// Baremes specifiques par acte et par empire — remplacent PEINES/ACTES_ILLEGAUX quand presents.
// Valeurs "echec" (flagrant delit / recherche). Si demasque (decouvert apres coup via enquete), doublees automatiquement.
// Batiments consideres comme centres de pouvoir : malus important a l'incendie et aux explosifs
const BATIMENTS_CENTRES_POUVOIR = [
  'palais-presidentiel', 'palais-gouvernement', 'assemblee', 'tribunal',
  'commissariat', 'banque-nationale', 'banque-privee', 'mairie-capitale', 'mairie'
];
const MALUS_CENTRE_POUVOIR = 30;

const PEINES_ACTES = {
  republic: {
    violation_couvre_feu:     { jours: 1, amende: 200,  label: 'Violation du couvre-feu' },
    vol:                      { jours: 1, amende: 500,  label: 'Vol' },
    achat_arme_illegal:       { jours: 1, amende: 500,  label: "Achat d'arme non enregistree" },
    possession_illegale_douane: { jours: 1, amende: 500, label: "Possession d'objets prohibes au controle douanier" },
    diffamation:              { jours: 1, amende: 500,  label: 'Diffamation' },
    tentative_assassinat:     { jours: 2, amende: 1500, label: "Tentative d'assassinat" },
    assassinat:               { jours: 2, amende: 1500, label: 'Assassinat' },
    tentative_empoisonnement: { jours: 2, amende: 2000, label: "Tentative d'empoisonnement" },
    empoisonnement:           { jours: 2, amende: 2000, label: 'Empoisonnement' },
    acheter_bombe_illegale:   { jours: 2, amende: 2000, label: "Achat d'explosifs non enregistres" },
    utiliser_explosifs:       { jours: 2, amende: 2000, label: "Usage d'explosifs" },
    incendier:                { jours: 2, amende: 2000, label: 'Incendie volontaire' },
    hooliganisme:             { jours: 1, amende: 500,  label: 'Trouble a l\'ordre public (hooliganisme)' },
    corruption_fonctionnaire: { jours: 1, amende: 1000, label: 'Corruption de fonctionnaire' }
  }
};

// Calcule la peine applicable pour un acte donne. demasque=true double jours et amende
// (acte reussi et decouvert apres coup, plutot qu'un echec immediat).
function getPeineParActe(acte, demasque) {
  const pays = state.country || 'republic';
  const specifique = PEINES_ACTES[pays]?.[acte];
  if (specifique) {
    const mult = demasque ? 2 : 1;
    return { jours: specifique.jours * mult, amende: specifique.amende * mult, label: specifique.label };
  }
  const type = ACTES_ILLEGAUX[acte]?.type || acte || 'delit_mineur';
  const peine = PEINES[type] || PEINES.delit_mineur;
  return { jours: peine.jours, amende: peine.amendeBase, label: peine.label };
}

const ACTES_ILLEGAUX = {
  corrompre_fonct:    { type: 'delit_mineur',  detectRate: 30 },
  corrompre_police:   { type: 'delit_mineur',  detectRate: 35 },
  corrompre_juge:     { type: 'delit_grave',   detectRate: 40 },
  corrompre_journaliste:{ type: 'delit_mineur',detectRate: 25 },
  blanchiment:        { type: 'delit_grave',   detectRate: 35 },
  societe_ecran:      { type: 'delit_mineur',  detectRate: 25 },
  falsifier_document: { type: 'delit_grave',   detectRate: 40 },
  acheter_arme_illegale:{ type: 'delit_mineur',detectRate: 20 },
  acheter_bombe_illegale:{ type: 'crime',      detectRate: 55 },
  fabriquer_bombe:    { type: 'crime',         detectRate: 60 },
  incendier:          { type: 'crime',         detectRate: 70 },
  utiliser_explosifs: { type: 'crime',         detectRate: 65 },
  arreter:            { type: 'delit_grave',   detectRate: 40 },
  fabriquer_scandale: { type: 'delit_grave',   detectRate: 45 },
  fuite_info:         { type: 'delit_grave',   detectRate: 40 },
  imprimer_tracts_calomnieux:{ type: 'delit_mineur',  detectRate: 30 },
  tentative_evasion:  { type: 'crime',         detectRate: 90 },
  se_rebeller:        { type: 'delit_mineur',  detectRate: 60 },
  fausse_rumeur:      { type: 'delit_mineur',  detectRate: 35 },
  vol:                { type: 'delit_mineur',  detectRate: 30 },
  assassiner_mains:   { type: 'crime',         detectRate: 30 },
  assassiner_arme:    { type: 'crime',         detectRate: 40 },
  assassiner_feu:     { type: 'crime',         detectRate: 60 },
  empoisonnement:     { type: 'crime',         detectRate: 25 },
  // Ajoutes le 25 aout 2026 (audit dedie, lot douanes PSM) : ces deux fn appelaient deja
  // checkDetection(fn, resultType) depuis leur creation, mais etant absentes d'ici la fonction
  // rendait tout appel un no-op silencieux (const acte = ACTES_ILLEGAUX[fn]; if (!acte) return;)
  // -- aucun risque de statut Recherche n'a jamais existe pour elles. blocus_portuaire
  // deliberement PAS ajoute (arbitrage separe, distinct conceptuellement des actes individuels
  // ci-dessus). Precedents retenus, memes categories thematiques deja existantes :
  // corrompre_douanier -> memes type/detectRate que corrompre_police (agent d'autorite
  // soudoye, le plus proche thematiquement d'un douanier parmi les corruptions existantes).
  // contrebande_port -> memes type/detectRate que acheter_arme_illegale (acquisition/detention
  // de marchandise prohibee via un canal semi-legitime, pas un acte violent).
  corrompre_douanier: { type: 'delit_mineur',  detectRate: 35 },
  contrebande_port:   { type: 'delit_mineur',  detectRate: 20 },
  // corrompre_gardien ajoute le 27 aout 2026 (reprise ciblee audit architecture) : meme trou que
  // corrompre_douanier ci-dessus avant son propre correctif du 25 aout -- fn deja routee vers
  // doCorruption() (qui appelle checkDetection(fn, resultType) sans condition), mais absente
  // d'ici, rendait la corruption d'un gardien du QHS totalement indetectable. Memes type/
  // detectRate que corrompre_police (agent d'autorite/de securite soudoye, le plus proche
  // thematiquement parmi les corruptions existantes -- meme raisonnement deja retenu pour
  // corrompre_douanier).
  corrompre_gardien:  { type: 'delit_mineur',  detectRate: 35 }
};

const BUDGET_DEFAULT = {
  presidence: { solde: 50000, coutOrdre: 500 },
  min_int:    { solde: 30000, coutOrdre: 400 },
  min_fin:    { solde: 25000, coutOrdre: 300 },
  min_just:   { solde: 20000, coutOrdre: 350 },
  min_def:    { solde: 40000, coutOrdre: 600 },
  min_info:   { solde: 15000, coutOrdre: 250 },
  min_ae:     { solde: 20000, coutOrdre: 300 },
  assemblee:  { solde: 35000, coutOrdre: 200 },
  tribunal:   { solde: 20000, coutOrdre: 400 },
  commissariat:{ solde: 25000, coutOrdre: 350 },
  mairie:     { solde: 30000, coutOrdre: 250 }
};

const REPARTITION_DEFAULT = {
  presidence: 15, pm: 8, min_int: 8, min_fin: 6, min_just: 6,
  min_def: 10, min_info: 5, min_ae: 6,
  assemblee: 8, tribunal: 6, commissariat: 8, mairie: 12, reserve: 2
};

const EMPIRE_STYLES = {
  republic: { tone: "bureaucratique français épuisé, cynique poli", religion: "le Papyrusisme", currency: "FR", leader: "le Président" },
  narco:    { tone: "jovial menaçant, corruption assumée, espagnol de bazar", religion: "le Laboratoire de Prière", currency: "PS", leader: "El Don" },
  soviet:   { tone: "idéologique soviétique, formulaires sacrés, Camarade partout", religion: "le Kolkhoze Spirituel", currency: "RP", leader: "le Parti" },
  khalija:  { tone: "protocole royal excessif, Loukoum Divin omniprésent, bénédictions imbriquées", religion: "la Pâtisserie Sacrée", currency: "DR", leader: "le Sheikh" }
};

const JOURNALISTES_PNJ = {
  republic: {
    name: 'Gustave Encre',
    journal: "L'Autruche Entravée",
    trait: "Journaliste d'investigation alcoolique. Déterre les scandales par accident en cherchant ses clés. A une source dans chaque ministère mais ne sait plus lequel.",
    style: "cynique désabusé, métaphores journalistiques épuisées, boit du café tiède depuis 1987"
  },
  narco: {
    name: 'El Editor',
    journal: 'El Narco Times',
    trait: "Rédacteur en chef qui blanchit les nouvelles comme El Don blanchit l'argent. Chaque article est une œuvre de fiction assumée.",
    style: "propagandiste jovial, español aproximativo, cite El Don dans chaque paragraphe"
  },
  soviet: {
    name: 'Rédacteur Vérité',
    journal: 'La Pravdovka',
    trait: "Journaliste du Parti qui vérifie trois fois si une information est approuvée avant de la publier. A publié le même article depuis 1973 avec des noms différents.",
    style: "zèle idéologique mécanique, vérité = ce que dit le Parti, enthousiasme performatif"
  },
  khalija: {
    name: 'Rédacteur Al-Vérité',
    journal: 'Le Minaret Doré',
    trait: "Journaliste royal qui ne publie que ce que le Palais approuve. Ses éditoriaux commencent tous par une bénédiction du Sheikh et finissent par une autre.",
    style: "déférence royale absolue, Loukoum Divin dans chaque titre, vérité = volonté du Sheikh"
  }
};

/* ===========================
   RES PUBLICA — PLATEAU.JS v2
   =========================== */

// =====================
// STATE
// =====================
const TEST_MODE = false; // PA illimites

// Plafond de reserve PA (Lot 1, 18 aout 2026) : constante fonctionnelle unique, remplace
// l'ancien state.paMax variable (recalcule a chaque Dormir selon l'hotel, jamais persiste
// cote Supabase -- voir audit). Toute lecture de plafond doit desormais utiliser PA_MAX,
// jamais state.paMax ni une valeur recalculee localement.
const PA_MAX = 30;

// Horloge artificielle par PA (Lot 2A, 19 aout 2026) : decouplee de TEST_MODE. TEST_MODE ne
// doit plus gouverner que la disponibilite/deduction des PA -- l'ancien mecanisme ou depenser
// des PA faisait avancer l'heure de jeu (advanceTime() ci-dessous) est desormais gate par ce
// second interrupteur, dedie et distinct, et non par TEST_MODE. Volontairement laisse a false :
// le plateau est aujourd'hui resynchronise sur l'heure reelle (syncRealTime()), qui reste la
// seule autorite sur state.hour/state.minute. Reactiver cette horloge artificielle exigerait au
// prealable un arbitrage produit sur la coexistence des deux modeles (voir audit du 19 aout
// 2026) -- ne pas basculer cette constante sans cet arbitrage. syncRealTime()/le cron/les
// elections (basees sur Date.now(), pas sur state.day) restent inchanges et hors de ce
// perimetre.
const HORLOGE_PA_ACTIVE = false;

let state = {
  pa: 999, paMax: PA_MAX,
  arg: 4250, liquide: 500, banque: 3750,
  // Lot 2 (chantier fiscalite/Helvetia) : defauts avant toute hydratation -- comptesBancaires
  // (cle = banque : 'nationale'/'helvetia') et placementsBancaires (tableau) sont peuples par
  // loadCharacter(), jamais ici. banque (racine, ci-dessus) reste un champ legacy, plus jamais
  // utilise comme source de verite (voir applyCharToState) mais laisse en place, non supprime.
  comptesBancaires: {}, placementsBancaires: [],
  inf: 25, pop: 30, dis: 85, hp: 92, moral: 78,
  day: 1, hour: 8,
  country: 'republic',
  currentCity: 'capitale',
  currentBuilding: null,
  currentRoom: null,
  char: null,
  inventory: [],
  poste: null,
  employees: [],
  employes: [],
  escortActive: [],
  tracesEnquete: [],
  dernierDormir: 0
};

// =====================
// INIT
// =====================
// Encode un objet PNJ en toute securite pour l'injection dans des attributs HTML —
// encodeURIComponent seul ne touche pas aux apostrophes, ce qui casse les onclick="...('...')"
// quand un nom de PNJ contient une apostrophe (ex: "Agent d'Entretien")
function encodePnjSafe(obj) {
  return encodeURIComponent(JSON.stringify(obj)).replace(/'/g, '%27');
}

// =====================
// DETECTION DE NOUVELLE VERSION CLIENT (correctif, 20 aout 2026)
// =====================
// version.json est un simple marqueur statique {"v": N}, a bumper manuellement en meme temps
// que les ?v= de cache-busting a chaque lot deploye (meme geste, un fichier de plus) -- jamais
// deduit du HTML/JS deja charge (aucun parsing de plateau.html). La version chargee au demarrage
// de CETTE session est figee une fois pour toutes (_versionInitialeClient, premiere lecture
// reussie), puis comparee a chaque verification a la version distante relue a neuf.
// Suspension temporaire (20 aout 2026, decision de Fred) : deploiements trop frequents pendant
// cette phase de developpement, le bandeau apparaissait a chaque joueur bien trop souvent.
// Flag unique -- repasser a true reactive tout le mecanisme instantanement, aucune autre
// modification necessaire. Rien n'est demonte : verifierNouvelleVersion()/fetchVersionJson()/
// afficherBandeauNouvelleVersion() restent intactes, seulement dormantes (le seul point de garde
// est le tout debut de verifierNouvelleVersion() ci-dessous, qui est le point d'entree UNIQUE de
// toutes les planifications -- demarrage, poll 5 min, visibilitychange). sbSauvegardeUrgenceDechargement()/
// pagehide/beforeunload/sbAutoSave() ne sont pas concernes par ce flag, le filet de sauvegarde
// reste totalement actif.
const DETECTION_NOUVELLE_VERSION_ACTIVE = false;

let _versionInitialeClient = null;
let _bandeauNouvelleVersionAffiche = false;

async function fetchVersionJson() {
  try {
    // cache:'no-store' (intention navigateur) + parametre d'URL unique (contourne aussi un
    // eventuel cache intermediaire cote CDN, qui ne respecte pas toujours les en-tetes de
    // requete) : les deux ensembles, pas l'un ou l'autre, pour une fraicheur reellement garantie.
    const res = await fetch('version.json?t=' + Date.now(), { cache: 'no-store' });
    if (!res.ok) return null;
    const data = await res.json();
    return data && typeof data.v !== 'undefined' ? data.v : null;
  } catch (e) {
    return null;
  }
}

async function verifierNouvelleVersion() {
  if (!DETECTION_NOUVELLE_VERSION_ACTIVE) return; // suspension temporaire, voir le flag ci-dessus
  const v = await fetchVersionJson();
  if (v === null) return; // echec reseau/format -- ne jamais declencher sur une incertitude
  if (_versionInitialeClient === null) {
    _versionInitialeClient = v; // premiere lecture reussie de la session = reference
    return;
  }
  if (v === _versionInitialeClient) return; // rien de nouveau
  if (_bandeauNouvelleVersionAffiche) return; // deja signale par un poll precedent, pas de doublon
  _bandeauNouvelleVersionAffiche = true;

  // Sauvegarde/flush avant d'interrompre le joueur -- reutilise integralement le mecanisme deja
  // en place pour pagehide/beforeunload (supabase.js), jamais duplique ici.
  if (typeof sbSauvegardeUrgenceDechargement === 'function') sbSauvegardeUrgenceDechargement();
  afficherBandeauNouvelleVersion();
}

// Bandeau persistant injecte dynamiquement (pas de nouveau markup dans plateau.html) -- ne se
// masque jamais tout seul, contrairement a showToast() (auto-masque 3,8s, inadapte ici).
// location.reload() UNIQUEMENT au clic sur le bouton, jamais automatique.
function afficherBandeauNouvelleVersion() {
  if (document.getElementById('bandeau-nouvelle-version')) return;
  const bandeau = document.createElement('div');
  bandeau.id = 'bandeau-nouvelle-version';
  bandeau.style.cssText = 'position:fixed;top:0;left:0;right:0;z-index:300;background:#1a1005;border-bottom:1px solid #8a6a20;color:#f0ead6;padding:.7rem 1rem;display:flex;align-items:center;justify-content:center;gap:1rem;flex-wrap:wrap;font-size:.85rem;font-family:inherit';
  bandeau.innerHTML =
    '<span>🔄 Une nouvelle version de Res Publica est disponible.</span>' +
    '<button id="bandeau-nouvelle-version-btn" style="font-family:\'Bebas Neue\',sans-serif;font-size:.8rem;letter-spacing:.08em;padding:.4rem 1rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Recharger</button>';
  document.body.appendChild(bandeau);
  document.getElementById('bandeau-nouvelle-version-btn').addEventListener('click', () => { window.location.reload(); });
}

window.addEventListener('DOMContentLoaded', () => {
  loadCharacter();
  // Restaurer dernierDormir depuis localStorage
  try {
    const dormirData = JSON.parse(localStorage.getItem('respublica_dormir_' + (state.char?.name || 'default')) || '{}');
    if (dormirData.dernierDormir) state.dernierDormir = dormirData.dernierDormir;
    if (dormirData.day) state.day = Math.max(state.day, dormirData.day);
  } catch(e) {}
  if (!state.currentCity) state.currentCity = 'capitale';
  if (!state.country) state.country = 'republic';

  // Ancien repli "nouveau personnage -> hall de la mairie" retire le 31 juillet 2026 :
  // obsolete et en conflit avec la quete d'accueil, qui place desormais le nouveau
  // personnage dans la rue devant le Palais Presidentiel (voir plateau-quete-accueil.js).

  applyEmpireTheme(state.country);
  // Sauvegarder la position courante
  if (state.char) {
    state.char.country = state.country;
    state.char.currentCity = state.currentCity;
    // Inclure poste et données importantes dans state.char avant sauvegarde
    if (state.char) {
      state.char.poste = state.poste || null;
      state.char.currentCity = state.currentCity || 'capitale';
      state.char.arg = state.arg || 0;
      state.char.resources = { inf: state.inf||0, pop: state.pop||0, dis: state.dis||50 };
      state.char.currentBuilding = state.currentBuilding || null;
      state.char.currentRoom = state.currentRoom || null;
    }
    try {
      localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
      localStorage.setItem('respublica_char', JSON.stringify(state.char));
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
  }
  buildCityTabs();
  updateUI();
  updateLocationDisplay();
  startClock();
  // Init Supabase
  if (typeof sbInit === 'function') sbInit();

  // Synchroniser les cycles électoraux depuis Supabase
  setTimeout(() => {
    syncCyclesDepuisSupabase().then(() => verifierPostesVacants());
  }, 2000);

  // Vérification mails toutes les minutes (réduit de 2 min à 1 min, correctif latence des
  // voyants du 21 aout 2026 -- ce polling redevient un filet de sécurité en arrière-plan, la
  // réactivité réelle vient désormais des déclenchements immédiats à l'ouverture de la
  // messagerie, à la lecture d'un mail et au retour sur l'onglet, voir forum.js/plus haut).
  verifierNouveauxMails();
  setInterval(verifierNouveauxMails, 60000);

  // Voyant d'activité forum (17 août 2026) — même cadence que la vérification des mails, même
  // raison de réduction
  if (typeof verifierActiviteForumNonVue === 'function') {
    verifierActiviteForumNonVue();
    setInterval(verifierActiviteForumNonVue, 60000);
  }

  // Vérification des objets reçus (dons d'un autre joueur) toutes les 2 minutes
  verifierObjetsRecus();
  setInterval(verifierObjetsRecus, 120000);

  // Batiments fermes (incendie/explosifs) — au chargement puis toutes les 2 minutes
  setTimeout(() => chargerBatimentsFermes(), 1000);
  setInterval(chargerBatimentsFermes, 120000);

  // Championnat sportif — verifie/avance la saison au chargement puis toutes les 5 minutes
  // (n'importe quel joueur connecte peut declencher le rattrapage, l'etat est partage sur Supabase)
  setTimeout(() => { if (typeof verifierEtJouerJournees === 'function') verifierEtJouerJournees(); }, 2500);
  setInterval(() => { if (typeof verifierEtJouerJournees === 'function') verifierEtJouerJournees(); }, 300000);
  setTimeout(() => { if (typeof verifierElectionsOrganisations === 'function') verifierElectionsOrganisations(); }, 3000);
  setInterval(() => { if (typeof verifierElectionsOrganisations === 'function') verifierElectionsOrganisations(); }, 300000);

  // Événements partagés (journal global) — au chargement puis toutes les 90 secondes
  setTimeout(() => chargerEvenementsPartages(), 1500);
  setTimeout(() => chargerOrganisations(), 1800);
  setTimeout(() => { if (typeof chargerLocations === 'function') chargerLocations(); }, 1900);
  setTimeout(() => { if (typeof demarrerPollingNotificationChat === 'function') demarrerPollingNotificationChat(); }, 2000);
  setTimeout(() => { if (typeof demarrerPollingInvitationsDiner === 'function') demarrerPollingInvitationsDiner(); }, 2000);
  setTimeout(() => appliquerNaturalisationAcceptee(), 2100);
  setTimeout(() => { if (typeof appliquerVictoireElectorale === 'function') appliquerVictoireElectorale(); }, 2350);
  setTimeout(() => recupererDonsEnAttente(), 2000);
  setTimeout(() => recupererVolsEnAttente(), 2200);
  setTimeout(() => recupererImpactsEnAttente(), 2400);
  setTimeout(() => verifierLancementQuete(), 2600);
  setInterval(chargerEvenementsPartages, 90000);
  setInterval(recupererDonsEnAttente, 90000);
  setInterval(recupererVolsEnAttente, 90000);
  setInterval(recupererImpactsEnAttente, 90000);

  // Présence en pièce — re-publier + rafraîchir les joueurs visibles toutes les 30 secondes
  setInterval(() => {
    if (typeof sbUpdatePresence === 'function' && state.char?.name && state.currentBuilding && state.currentRoom) {
      sbUpdatePresence(state.char.name, state.country, state.currentCity, state.currentBuilding, state.currentRoom, typeof getMonGroupePNJ === 'function' ? getMonGroupePNJ() : []).catch(() => {});
    }
    if (typeof chargerVraisJoueursPresents === 'function') chargerVraisJoueursPresents();
    if (typeof rafraichirTitulairesPostesElectifs === 'function') rafraichirTitulairesPostesElectifs();
    // Sauvegarde automatique periodique -- filet de securite pour rattraper tout gain
    // (INF, HP, etc.) qu'une fonction particuliere aurait omis de sauvegarder elle-meme.
    // Correctif du 25 aout 2026 (bug production confirme par instrumentation : un onglet
    // oublie republiait aveuglement son etat perime toutes les 30s, ecrasant une correction
    // serveur ou une autre session plus recente) : passe par sbVerifierEtSauvegarderPersonnage
    // (supabase.js) plutot que sbSavePersonnage direct -- seul CE minuteur purement temporel
    // est concerne, tous les autres appelants (actions explicites du joueur) restent inchanges.
    if (typeof sbVerifierEtSauvegarderPersonnage === 'function' && state.char?.name) {
      sbVerifierEtSauvegarderPersonnage(state).catch(() => {});
    } else if (typeof sbSavePersonnage === 'function' && state.char?.name) {
      sbSavePersonnage(state).catch(() => {});
    }
  }, 30000);
  if (typeof rafraichirTitulairesPostesElectifs === 'function') rafraichirTitulairesPostesElectifs();

  // Filet de secours au dechargement de la page (correctif, 20 aout 2026) : sbAutoSave() debounce
  // 3s -- un refresh/fermeture pendant cette fenetre perdait toute mutation pas encore ecrite
  // (inventory en particulier, sans repli localStorage). pagehide ET beforeunload declenchent le
  // meme flush (sbSauvegardeUrgenceDechargement, supabase.js) : la fiabilite vient de son
  // fetch(..., {keepalive:true}), pas de l'evenement choisi -- les deux sont donc couverts plutot
  // que de parier sur un seul, sans pretendre qu'un `await` classique dans beforeunload serait
  // fiable (il ne l'est pas).
  if (typeof window !== 'undefined') {
    window.addEventListener('pagehide', () => { if (typeof sbSauvegardeUrgenceDechargement === 'function') sbSauvegardeUrgenceDechargement(); });
    window.addEventListener('beforeunload', () => { if (typeof sbSauvegardeUrgenceDechargement === 'function') sbSauvegardeUrgenceDechargement(); });
  }

  // Detection de nouvelle version (correctif, 20 aout 2026) : verification au demarrage, toutes
  // les 5 min (meme cadence que le championnat/les elections d'organisations ci-dessus), et
  // immediatement quand l'onglet redevient visible (le cas le plus frequent en pratique : un
  // onglet reste ouvert en arriere-plan pendant un deploiement).
  setTimeout(() => { if (typeof verifierNouvelleVersion === 'function') verifierNouvelleVersion(); }, 2700);
  setInterval(() => { if (typeof verifierNouvelleVersion === 'function') verifierNouvelleVersion(); }, 300000);
  if (typeof document !== 'undefined') {
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState !== 'visible') return;
      if (typeof verifierNouvelleVersion === 'function') verifierNouvelleVersion();
      // Correctif latence des voyants Mail/Forum (audit du 21 aout 2026) : reutilise ce MEME
      // ecouteur deja existant (jamais un second addEventListener) -- resynchronise les deux
      // voyants immediatement au retour sur l'onglet, plutot que de laisser l'ecart s'accumuler
      // jusqu'au prochain passage du polling de fond (qui reste actif, en filet de securite).
      if (typeof verifierNouveauxMails === 'function') verifierNouveauxMails();
      if (typeof verifierActiviteForumNonVue === 'function') verifierActiviteForumNonVue();
    });
  }

  // Séquence de chargement espacée pour éviter les conflits de modaux
  setTimeout(() => genererMeteoPolitique(), 1000);
  setTimeout(() => genererEvenementAleatoire(), 3000);
  setTimeout(() => {
    if (!sessionStorage.getItem('journaliste_done')) {
      afficherReactionJournaliste();
      sessionStorage.setItem('journaliste_done', '1');
    }
  }, 5000);
  // Journal du jour en dernier — après tous les autres
  setTimeout(() => afficherJournalDuJour(), 8000);

  // Forcer le rendu complet au chargement
  setTimeout(() => {
    forceRenderCity(state.currentCity || 'capitale');
  }, 300);
});

async function chargerBatimentsFermes() {
  if (typeof sbChargerBatimentsFermes !== 'function') return;
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  try {
    const rows = await sbChargerBatimentsFermes(pays, ville);
    state.batimentsFermesCache = (rows || []).filter(r => r.jour_fin > (state.day || 1));
  } catch(e) {}
}

function batimentEstFerme(buildingId) {
  const ferme = (state.batimentsFermesCache || []).find(r =>
    r.batiment_id === buildingId && r.pays === (state.country||'republic') && r.ville === (state.currentCity||'capitale') && r.jour_fin > (state.day||1)
  );
  return ferme || null;
}

function loadCharacter() {
  try {
    // Lire le dernier personnage actif, puis sa clé propre
    const lastName = localStorage.getItem('respublica_last_char');
    const saved = lastName
      ? (localStorage.getItem('respublica_char_' + lastName) || localStorage.getItem('respublica_char'))
      : localStorage.getItem('respublica_char');
    if (saved) {
      const char = JSON.parse(saved);
      applyCharToState(char);
      console.log('Personnage charge (local):', char.name, '| Pays:', state.country);
      // Precharge le cache des indices de ville de Republia (chantier "refonte des ordres") --
      // fire-and-forget, les lecteurs (getIndiceVille etc.) ont deja des valeurs par defaut
      // en attendant que ca revienne.
      if (typeof chargerIndicesRepublia === 'function') chargerIndicesRepublia().catch(() => {});
      // Garde de bootstrap (lot du 25 aout 2026, correctif generique de concurrence client/
      // serveur) : tant que la reconciliation Supabase ci-dessous n'est pas terminee,
      // state.personnageChargeDepuisServeur reste explicitement false -- sbSavePersonnage
      // (supabase.js, SEUL point d'ecriture reellement inhibe par ce flag, tous les appelants y
      // passent) refuse toute sauvegarde tant qu'il vaut false. La restauration de position
      // ci-dessous continue d'AFFICHER la bonne piece immediatement (aucun changement de
      // comportement d'affichage) -- seule l'ECRITURE serveur qu'elle declenche via enterRoom()
      // est retardee. Sans cette garde, restaurerPositionApresChargement(char) (ligne suivante,
      // a partir du SEUL localStorage, potentiellement perime) pouvait ecraser en base un etat
      // serveur plus recent avant meme que sbLoadPersonnage() ci-dessous n'ait eu le temps de
      // repondre -- bug de concurrence confirme en production (licence sportive ecrasee malgre
      // une correction serveur directe, aucun rapport avec le football en soi).
      state.personnageChargeDepuisServeur = false;
      // Restaurer la position exacte (piece) ou la personne se trouvait avant le rafraichissement
      restaurerPositionApresChargement(char);
      // Reinjecter le journal personnel persiste (rapide, depuis le cache local)
      restaurerJournal(char);
      // Synchroniser depuis Supabase en arrière-plan
      if (char.name && typeof sbLoadPersonnage === 'function') {
        // Lot 2 (hydratation financiere) : comptes_bancaires/placements_bancaires du personnage
        // sont charges dans la MEME phase async que sbLoadPersonnage (Promise.all), comme
        // demande -- jamais un second aller-retour reseau separe, jamais une donnee bancaire
        // exposee au reste du jeu avant que le personnage lui-meme ne le soit. Chaque fetch a
        // son propre .catch(()=>[]) : une panne reseau sur les comptes/placements ne doit
        // jamais faire echouer le chargement du personnage lui-meme (deja protege par le
        // .catch() global de la chaine plus bas).
        Promise.all([
          sbLoadPersonnage(char.name),
          (typeof sbGetComptesBancaires === 'function' ? sbGetComptesBancaires(char.name).catch(() => []) : Promise.resolve([])),
          (typeof sbGetPlacementsBancaires === 'function' ? sbGetPlacementsBancaires(char.name).catch(() => []) : Promise.resolve([]))
        ]).then(([sbState, comptesRows, placementsRows]) => {
          // Applique quel que soit l'issue de sbState (rare, sbState absent) : ne jamais perdre
          // une donnee bancaire reellement recuperee.
          state.comptesBancaires = construireMapComptesBancaires(comptesRows);
          state.placementsBancaires = placementsRows || [];
          if (sbState) {
            // La position (bâtiment/pièce/ville/pays) locale est toujours écrite immédiatement et de
            // façon fiable dès qu'on change de pièce ou de ville (voir enterRoom/confirmerTransport).
            // La sauvegarde Supabase, elle, est asynchrone : un rafraîchissement rapide après un
            // déplacement (y compris un voyage inter-villes) peut arriver avant qu'elle n'ait fini de
            // se propager. On garde donc toujours la position locale plutôt que celle de Supabase --
            // correctif (20 aout 2026) : ce garde-fou ne couvrait jusqu'ici que currentBuilding/
            // currentRoom, jamais country/currentCity, laissant un voyage inter-villes revenir a
            // l'ancienne ville/pays sur un refresh rapide malgre une position batiment/piece correcte.
            const positionLocaleBuilding = state.char?.currentBuilding;
            const positionLocaleRoom = state.char?.currentRoom;
            const positionLocaleCountry = state.char?.country;
            const positionLocaleVille = state.char?.currentCity;

            // Fusionner les données Supabase (plus récentes pour tout le reste : argent, inventaire, etc.)
            Object.assign(state, sbState);
            // Repere de fraicheur (lot du 25 aout 2026, correctif filet de securite 30s) :
            // memorise le updated_at serveur connu au moment de cette reconciliation -- voir
            // sbVerifierEtSauvegarderPersonnage (supabase.js).
            state._dernierUpdatedAtConnu = sbState.updatedAt || null;

            // applyCharToState() ci-dessous recalcule inf/pop/dis (et arg) a partir de char.resources/char.arg --
            // il faut donc synchroniser char.resources/char.arg avec les valeurs fraiches qu'on vient de
            // fusionner, sinon le second appel ecraserait silencieusement ces valeurs avec les
            // anciennes valeurs restees sur l'objet char (c'etait le bug : gains perdus au F5,
            // et pour arg specifiquement, l'objet char de sbLoadPersonnage n'a meme jamais de champ
            // arg du tout -> reset systematique au defaut 4250 code en dur, trouve le 9 aout 2026).
            // pa exactement le meme bug, jamais corrige pour ce champ precis (urgence du 26 aout
            // 2026) : sbLoadPersonnage() (supabase.js) porte pa comme un champ RACINE de l'objet
            // retourne (pa: r.pa), jamais sur son sous-objet char -- Object.assign(state, sbState)
            // deux lignes plus haut fixe donc deja correctement state.pa, mais remplace aussi
            // state.char par sbState.char qui n'a JAMAIS eu de propriete pa. Le second
            // applyCharToState(state.char) plus bas lit char.pa (absent -> undefined) et retombe
            // sur son repli 10 (voir son propre commentaire, plateau-core.js:858), ecrasant la
            // valeur pourtant correcte que Object.assign venait d'ecrire dans state.pa -- observe
            // en production comme "10 PA a chaque rafraichissement" alors que Supabase contenait
            // la bonne valeur. Meme remede que pour arg : re-synchroniser char.pa AVANT le second
            // appel, a partir de state.pa qui est deja juste a ce point.
            if (state.char) {
              state.char.resources = { inf: state.inf, pop: state.pop, dis: state.dis };
              state.char.arg = state.arg;
              state.char.pa = state.pa;
            }

            if (positionLocaleBuilding) {
              state.currentBuilding = positionLocaleBuilding;
              if (state.char) state.char.currentBuilding = positionLocaleBuilding;
            }
            if (positionLocaleRoom) {
              state.currentRoom = positionLocaleRoom;
              if (state.char) state.char.currentRoom = positionLocaleRoom;
            }
            if (positionLocaleCountry) {
              state.country = positionLocaleCountry;
              if (state.char) state.char.country = positionLocaleCountry;
            }
            if (positionLocaleVille) {
              state.currentCity = positionLocaleVille;
              if (state.char) state.char.currentCity = positionLocaleVille;
            }

            applyCharToState(state.char);
            updateUI();
            restaurerPositionApresChargement(state.char);
            // Reconcilie avec la version Supabase (potentiellement plus a jour, ex. joueur
            // actif sur un autre appareil) -- vide et repeuple #journal en consequence.
            restaurerJournal(state.char);
            if (typeof enigme1VerifierDeclenchement === 'function') enigme1VerifierDeclenchement();
            // Portrait de Jodie Moitout ("Un jour, un portrait", lot du 21 aout 2026) : meme
            // point d'ancrage que l'enigme ci-dessus, une seule fois par chargement de session --
            // voir jodiePortraitVerifierProposition() (plateau-communication.js) pour la garantie
            // d'unicite. Remplace l'ancien mecanisme jodieVerifierMailAccueil() (jamais actif en
            // production, retire integralement -- voir plateau-communication.js).
            if (typeof jodiePortraitVerifierProposition === 'function') jodiePortraitVerifierProposition();
            // Emploi BNE : pas de colonne dediee sur personnages (voir plateau-justice-economie.js),
            // le cache local state.emploiBNE doit etre rafraichi explicitement depuis Supabase.
            if (typeof rafraichirCacheEmploiBNE === 'function') rafraichirCacheEmploiBNE();
            console.log('Personnage synchronisé depuis Supabase:', char.name);
          }
          // Coherence financiere (Lot 2) : APRES que liquide (via sbState/Object.assign),
          // comptesBancaires et placementsBancaires soient tous a jour -- jamais avant. Aligne
          // arg sur la somme reelle des poches, ne modifie jamais liquide/comptes/placements
          // eux-memes (voir verifierCoherenceFortune ci-dessous).
          if (typeof verifierCoherenceFortune === 'function') verifierCoherenceFortune();
          // Reconciliation terminee (reussie ou sbState vide) : les sauvegardes redeviennent
          // normales des cet instant, y compris pour la navigation qui vient de se produire
          // pendant l'attente ci-dessus (enterRoom l'a deja affichee sans la sauvegarder).
          state.personnageChargeDepuisServeur = true;
        }).catch(() => { state.personnageChargeDepuisServeur = true; }); // echec reseau : ne jamais bloquer les sauvegardes indefiniment
      } else {
        // Pas de nom ou sbLoadPersonnage indisponible : aucune reconciliation ne viendra jamais,
        // rien a attendre -- autoriser les sauvegardes immediatement (comportement inchange par
        // rapport a avant ce correctif dans ce cas precis).
        state.personnageChargeDepuisServeur = true;
      }
    }
  } catch(e) { console.warn('Erreur chargement personnage', e); }
}

// Si le joueur etait dans un batiment/piece avant de rafraichir, on l'y replace directement.
// Correctif du 21 aout 2026 (bug generique "refresh renvoie dans la rue", tous batiments/pieces
// confondus, pas specifique au notaire) : le DOMContentLoaded (plus bas dans ce fichier) ecrit
// state.char.currentBuilding/currentRoom = state.currentBuilding/currentRoom (encore null a cet
// instant, avant que le setTimeout ci-dessous n'ait eu la moindre chance de s'executer) --
// char etant LA MEME reference que state.char (voir applyCharToState), cette ecriture pollue
// aussi l'objet que ce setTimeout s'appretait a lire 300ms plus tard, faisant systematiquement
// avorter la restauration (garde-fou !char.currentBuilding a la relecture). Correctif : capturer
// la cible dans des variables locales INDEPENDANTES de l'objet char/state.char des la validation
// ci-dessus, avant de rendre la main -- le callback differe n'utilise plus jamais char directement.
function restaurerPositionApresChargement(char) {
  if (!char.currentBuilding || !char.currentRoom) return;
  if (!BUILDINGS[char.currentBuilding] || !BUILDINGS[char.currentBuilding].rooms?.[char.currentRoom]) return;
  const buildingCible = char.currentBuilding, roomCible = char.currentRoom;
  setTimeout(() => {
    try {
      enterBuilding(buildingCible, true);
      enterRoom(buildingCible, roomCible, null);
    } catch(e) { console.warn('Erreur restauration position', e); }
  }, 300);
}

// Migration des anciens id de carrière (18 -> 10, bêta) -- voir MIGRATION_CAREER_IDS (data.js)
// pour la table complète et le raisonnement de chaque mappage. Mutation en mémoire uniquement
// (jamais d'écriture directe en base) : la prochaine sauvegarde normale du personnage (au
// premier appel de sbSavePersonnage, qui se produit tres vite en jeu) persiste naturellement
// l'id corrige, sans backfill explicite necessaire.
function migrerCareerId(char) {
  if (!char || !char.career) return;
  if (typeof MIGRATION_CAREER_IDS === 'undefined') return;
  const nouvelId = MIGRATION_CAREER_IDS[char.career];
  if (nouvelId) char.career = nouvelId;
}

function applyCharToState(char) {
  if (!char) return;
  migrerCareerId(char);
  state.char = char;
  state.country = char.country || 'republic';
  state.currentCity = char.currentCity || 'capitale';
  state.arg = char.arg || 4250;
  if (char.poste) state.poste = char.poste;
  if (char.posteDepute) state.posteDepute = char.posteDepute;
  // Lot 2 (hydratation financiere, chantier fiscalite/Helvetia) : le recalcul 15%/85% de
  // liquide/banque a partir de arg, execute ici a CHAQUE hydratation depuis des mois, est
  // supprime -- c'etait la cause du bug d'ecrasement des vrais soldes (meme famille que les
  // bugs pa/arg deja corriges). liquide n'est plus jamais recalcule ici : sa valeur reelle
  // (personnages.liquide) est deja posee sur state.liquide en amont (Object.assign(state,
  // sbState) dans loadCharacter(), sbState.liquide etant un champ racine -- meme rail que pa/
  // arg). state.banque (l'ancien champ plat) n'est plus ni lu ni ecrit du tout : legacy, voir
  // le rapport d'audit -- les soldes reels vivent desormais dans state.comptesBancaires
  // (charges par loadCharacter(), pas ici, cette fonction reste synchrone). Le 15%/85% ne
  // subsiste que comme repartition INITIALE, une seule fois, a la creation d'un personnage
  // (creation.js) -- jamais recalcule ensuite.
  state.inf = char.resources?.inf || 25;
  state.pop = char.resources?.pop || 30;
  state.dis = char.resources?.dis || 85;
  // Restauration des PA depuis le cache local (audit du 20 aout 2026) : state.pa restait bloque
  // a la valeur par defaut du litteral d'etat initial (999, plateau-core.js:324) le temps que la
  // synchronisation Supabase asynchrone (loadCharacter -> sbLoadPersonnage) ecrase la valeur --
  // fenetre transitoire avec un compteur de PA irrealiste et non plafonne. char.pa || 10 aurait
  // ete errone : 0 est une valeur normale (PA epuises) qui doit rester 0, pas retomber a 10. Le
  // fallback 10 (PA initiaux d'un nouveau personnage, voir creation.js) ne s'applique desormais
  // que si char.pa est reellement absent (undefined/null), jamais si char.pa vaut 0.
  state.pa = (typeof char.pa === 'number') ? char.pa : 10;

  // UI
  const nameEl = document.getElementById('char-name-display');
  if (nameEl) nameEl.textContent = char.name || 'Mon Personnage';
  const ar = ARCHETYPES.find(x => x.id === char.archetype);
  const ca = CAREERS.find(x => x.id === char.career);
  const roleEl = document.getElementById('char-role-display');
  const posteLabel = state.poste?.name || null;
  if (roleEl) roleEl.textContent = posteLabel
    ? `${posteLabel} · ${ar?.name||'?'}`
    : `${ar?.name||'?'} · ${ca?.name||'?'}`;
  const fullnameEl = document.getElementById('char-fullname-left');
  if (fullnameEl) fullnameEl.textContent = char.name || 'Mon Personnage';
  const co = COUNTRIES[char.country];
  const archEl = document.getElementById('char-arch-left');
  const posteStr = state.poste?.name ? `${state.poste.name} · ` : '';
  if (archEl) archEl.textContent = `${posteStr}${ar?.name||'?'} · ${co?.n||'?'}`;

  // Photo
  try {
    const photoSaved = localStorage.getItem('respublica_photo_' + (state.char?.name || 'default')) || localStorage.getItem('respublica_photo');
    const photoUrl = photoSaved || char.photoUrl;
    if (photoUrl && photoUrl.length > 10) {
      const imgTag = `<img src="${photoUrl}" alt="Photo" style="width:100%;height:100%;object-fit:cover;border-radius:50%"/>`;
      const photoEl = document.getElementById('char-photo-left');
      const avatarEl = document.getElementById('char-avatar-top');
      if (photoEl) photoEl.innerHTML = imgTag;
      if (avatarEl) avatarEl.innerHTML = imgTag;
    }
  } catch(photoErr) { console.warn('Photo non chargee:', photoErr); }

  if (char.stats) {
    const statGrid = document.getElementById('stat-mini-grid');
    // Correctif d'affichage cible (Lot 2, objets d'integration locale, 23 aout 2026) : SEULE la
    // ligne ENT gagne un suffixe "(+1)" quand bonusEntIntegrationLocale() est actif -- les 5
    // autres caracteristiques restent affichees telles quelles (valeur brute char.stats[k]),
    // strictement inchangees. Volontairement PAS getStatEffective('ENT') ici : cette fonction
    // inclut aussi la moyenne de groupe, ce qui produirait un delta trompeur si un groupe est
    // actif -- bonusEntIntegrationLocale() est un calcul independant, purement personnel.
    if (statGrid) statGrid.innerHTML = STAT_DEFS.map(({k}) => {
      const brut = char.stats[k] || 8;
      const suffixeEnt = (k === 'ENT' && typeof bonusEntIntegrationLocale === 'function' && bonusEntIntegrationLocale())
        ? ' <span style="color:#6ab858">(+1)</span>' : '';
      return `
      <div class="stat-mini">
        <div class="stat-mini-name">${k}</div>
        <div class="stat-mini-val">${brut}${suffixeEnt}</div>
      </div>`;
    }).join('');
  }

  const cur = co?.cur || 'FR';
  const argEl = document.getElementById('r-arg');
  if (argEl) argEl.textContent = state.arg.toLocaleString('fr-FR') + ' ' + cur;
}

// =====================
// RUNTIME BANCAIRE (Lot 2, chantier fiscalite/Helvetia) — hydratation uniquement, aucune
// logique fiscale/Helvetia ici.
// =====================

// Format runtime retenu pour state.comptesBancaires : objet clé par identifiant de banque
// ('nationale'|'helvetia'), pas un tableau -- un personnage n'a jamais plus d'un compte courant
// par banque (contrainte d'unicite (personnage, banque) deja en base), donc une cle directe
// evite un .find() a chaque lecture partout ailleurs dans le jeu. Absence de cle = pas de
// compte dans cette banque (jamais un objet a solde 0 invente).
function construireMapComptesBancaires(rows) {
  const map = {};
  (rows || []).forEach(r => { if (r && r.banque) map[r.banque] = r; });
  return map;
}

// Agregat "solde bancaire total" (toutes banques confondues), remplace les anciennes lectures
// de state.banque (champ legacy, plus jamais mis a jour depuis ce lot) partout ou le
// comportement est non ambigu -- voir le rapport d'audit pour le detail des sites.
function totalComptesBancaires() {
  return Object.values(state.comptesBancaires || {}).reduce((s, c) => s + (c?.solde || 0), 0);
}

// Coherence financiere (Lot 2) : STRICTEMENT DIAGNOSTIC. Hotfix (28 aout 2026) : la version
// precedente alignait arg sur liquide+Σcomptes+Σplacements des qu'une divergence etait
// constatee -- errone, car les ~107 consommateurs existants qui modifient encore state.arg
// directement (cf. audit) ne mettent jamais a jour liquide/comptes/placements en meme temps.
// Consequence reelle : une depense ou un revenu legacy (ex. state.arg -= 1000 sans toucher aux
// poches) etait silencieusement annule au refresh suivant, arg revenant a l'ancienne somme des
// poches. Tant que la couche de compatibilite des anciennes ecritures arg n'existe pas (chantier
// ulterieur, non commence ici), personnages.arg reste TEMPORAIREMENT l'autorite de compatibilite
// sur la fortune globale : cette fonction se contente donc de logger toute divergence (avec assez
// de contexte pour diagnostiquer), sans jamais modifier arg, liquide, comptesBancaires ni
// placementsBancaires.
function verifierCoherenceFortune() {
  const comptesTotal = Object.values(state.comptesBancaires || {}).reduce((s, c) => s + (c?.solde || 0), 0);
  const placementsTotal = (state.placementsBancaires || [])
    .filter(p => p && p.statut === 'actif')
    .reduce((s, p) => s + (p.montant || 0), 0);
  const sommePoches = (state.liquide || 0) + comptesTotal + placementsTotal;
  if (state.arg !== sommePoches) {
    console.warn(
      'Incoherence fortune detectee au chargement (diagnostic uniquement, rien n\'est modifie) : ' +
      'personnage=' + (state.char?.name || '?') +
      ', arg=' + state.arg +
      ', liquide=' + (state.liquide || 0) +
      ', totalComptes=' + comptesTotal +
      ', totalPlacements=' + placementsTotal +
      ', somme des poches=' + sommePoches +
      ', ecart=' + (state.arg - sommePoches)
    );
  }
}

// =====================
// FONDS ORDINAIRES (Lot 3, chantier fiscalite/Helvetia) — primitives canoniques pour les
// depenses/revenus courants du joueur. "Ordinaire" = liquide + compte Banque nationale
// UNIQUEMENT, jamais Helvetia, jamais un placement, jamais automatiquement (regle validee).
// Objectif de ce lot : faire converger les chokepoints DEJA PARTAGES (deduireCoutOrdre,
// executerOrdreGenerique/applyEffects, la garde amont de doOrder) vers ces primitives, sans
// reecrire individuellement les ~95 sites qui font encore state.arg -= X en direct dans leur
// propre corps (ceux-la continueront de diverger, detecte par verifierCoherenceFortune,
// jusqu'a leur propre migration future).
// =====================

// Fonds reellement et immediatement mobilisables pour une depense ordinaire -- PAS arg (qui
// inclut aussi Helvetia/placements une fois ces derniers vivants). C'est cette fonction, pas
// arg, qui doit gater toute depense migree vers ces primitives.
function getFondsDisponiblesOrdinaires() {
  return (state.liquide || 0) + (state.comptesBancaires?.nationale?.solde || 0);
}

// Debit atomique (au niveau runtime, synchrone jusqu'a la premiere persistance) des fonds
// ordinaires : liquide d'abord, complete par la Banque nationale si besoin, jamais de debit
// partiel si le total des deux est insuffisant -- dans ce cas, retour {ok:false} SANS AUCUNE
// mutation, a l'appelant de refuser l'effet associe (invariant "paiement reussi -> effet /
// paiement refuse -> aucun effet", jamais d'etat intermediaire). Persistance immediate (jamais
// le debounce de 3s de sbAutoSave) pour un paiement qui vient d'avoir lieu : sauvegarderPersonnageImmediat()
// couvre arg+liquide (memes champs racine, un seul appel sbSavePersonnage) ; le solde du compte
// Banque nationale est persiste separement (table distincte, aucune transaction croisee possible
// via l'API REST -- meme limite deja documentee ailleurs dans le projet), en best-effort trace.
async function debiterFondsOrdinaires(montant) {
  if (!(montant > 0)) return { ok: true, preleveLiquide: 0, preleveNational: 0 };
  const compteNational = state.comptesBancaires?.nationale;
  const soldeNational = compteNational?.solde || 0;
  const disponible = (state.liquide || 0) + soldeNational;
  if (disponible < montant) return { ok: false, raison: 'fonds_insuffisants' };

  const preleveLiquide = Math.min(state.liquide || 0, montant);
  const preleveNational = montant - preleveLiquide;

  state.liquide = (state.liquide || 0) - preleveLiquide;
  if (preleveNational > 0 && compteNational) {
    compteNational.solde -= preleveNational;
  }
  state.arg = (state.arg || 0) - montant;
  if (state.char) state.char.arg = state.arg;

  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  if (preleveNational > 0 && compteNational?.id && typeof sbMajCompteBancaire === 'function') {
    sbMajCompteBancaire(compteNational.id, { solde: compteNational.solde }).catch(() => {
      console.error('Echec de persistance du debit sur le compte Banque nationale (solde local deja modifie, id=' + compteNational.id + ')');
    });
  }

  return { ok: true, preleveLiquide, preleveNational };
}

// Credit generique (salaire, remboursement, effet de resultat positif...) : atterrit
// integralement en liquide, jamais automatiquement sur un compte bancaire -- meme regle que
// doDormir() (Lot 2). Pas de persistance immediate forcee ici : comportement inchange par
// rapport a tous les credits generiques deja existants, qui s'appuient sur le prochain
// updateUI()/sbAutoSave() (debounce 3s) de l'appelant -- un credit n'a jamais la meme urgence
// qu'un paiement qui vient de reussir.
function crediterFondsOrdinaires(montant) {
  if (!(montant > 0)) return;
  state.liquide = (state.liquide || 0) + montant;
  state.arg = (state.arg || 0) + montant;
  if (state.char) state.char.arg = state.arg;
}

// =====================
// CLOCK
// =====================
function startClock() {
  syncRealTime();
  updateClock();
  // Mise a jour toutes les minutes
  setInterval(() => {
    syncRealTime();
    updateClock();
    checkMidnight();
  }, 60000);
}

// Date/heure reelle formatee, a utiliser partout a la place de "Jour X" (peu parlant pour le joueur)
function formatDateHeureJeu() {
  const now = new Date();
  const frNow = new Date(now.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  const dateStr = frNow.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const h = String(state.hour ?? frNow.getHours()).padStart(2, '0');
  const m = String(state.minute ?? frNow.getMinutes()).padStart(2, '0');
  return `${dateStr} · ${h}h${m}`;
}

// Date reelle du jour (Europe/Paris), format JJ/MM/AAAA -- factorise le meme calcul que
// formatDateHeureJeu()/formatDateAffichage() ci-dessus, reutilise par les plafonds quotidiens
// (Lot 4, cartes postales, 23 aout 2026) : state.day est un compteur PROPRE A CHAQUE
// PERSONNAGE (avance par sa propre horloge PA, plateau-core.js) et ne peut donc jamais servir a
// comparer "le meme jour" entre deux joueurs differents (lecteur/expediteur) -- seule l'horloge
// reelle, commune a tous, convient ici. Jamais l'horloge PA/le jour du jeu (meme regle que
// DUREE_FRAICHEUR_ALIMENT_MS, plateau-personnage.js).
function dateReelleParisStr() {
  const frNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  return frNow.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

// Affiche "Aujourd'hui" a la place de la date si elle correspond a la date du jour.
// Les anciens messages au format "Jour X" restent affiches tels quels (retrocompatibilite).
function formatDateAffichage(dateHeureStr) {
  if (!dateHeureStr) return '';
  const sep = ' · ';
  const idx = dateHeureStr.indexOf(sep);
  const datePart = idx >= 0 ? dateHeureStr.substring(0, idx) : dateHeureStr;
  const restePart = idx >= 0 ? dateHeureStr.substring(idx) : '';
  const now = new Date();
  const frNow = new Date(now.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  const todayStr = frNow.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
  if (datePart === todayStr) return "Aujourd'hui" + restePart;
  return dateHeureStr;
}

function syncRealTime() {
  // Calage sur l'heure reelle francaise
  const now = new Date();
  const frTime = new Date(now.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  state.hour = frTime.getHours();
  state.minute = frTime.getMinutes();
  state.day = state.day || 1; // Le jour de jeu est incremente a minuit
}

// Horloge de la barre superieure (#game-time, plateau.html) -- element UNIQUE partage par toutes
// les vues (rue, batiments, pieces : ce n'est pas duplique par vue, aucun autre reliquat a
// corriger ailleurs). Correctif du 21 aout 2026 : affichait auparavant "Jour N" (compteur de
// jours de jeu, sans utilite propre ici -- state.hour/state.minute sont deja synchronises sur
// l'heure reelle de Paris via syncRealTime(), seul le prefixe "Jour N" restait fictif). Reutilise
// formatDateHeureJeu() (deja la date reelle utilisee partout ailleurs dans le jeu pour les
// horodatages), appelee chaque minute par startClock() -- pas de nouvelle logique temporelle.
function updateClock() {
  const el = document.getElementById('game-time');
  if (el) el.textContent = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
}

function advanceTime(pa) {
  // Chaque PA consomme environ 30 minutes de temps de jeu -- gate desormais uniquement par
  // HORLOGE_PA_ACTIVE (Lot 2A), plus du tout par TEST_MODE : cette mecanique reste inerte tant
  // que HORLOGE_PA_ACTIVE est a false, quel que soit l'etat de TEST_MODE.
  if (HORLOGE_PA_ACTIVE && pa > 0) {
    state.minute = (state.minute || 0) + (pa * 30);
    while (state.minute >= 60) {
      state.minute -= 60;
      state.hour = (state.hour + 1) % 24;
      if (state.hour === 0) {
        state.day = (state.day || 1) + 1;
        state.midnightDone = false;
      }
    }
    updateClock();
  }
}

// =====================
// PRIMITIVE CENTRALISEE DE DEDUCTION PA / COUT (Phase K, 13/08/2026)
// =====================
// Prealable a toute deduction dans un handler dedie (route par un cas special de doOrder, voir
// plateau-router.js) : ces handlers ne beneficient PAS de la deduction generique de doOrder(),
// qui ne s'applique qu'aux ordres sans cas special. Audit complet : .scratch/audit-pa-couts-phase-j.csv
//
// Separation stricte des responsabilites (valable pour toutes les phases de migration a venir) :
//   - deduireCoutOrdre() ne connait AUCUNE regle metier (reussite/echec/acceptation/refus).
//     Elle verifie et preleve, point final. C'est au handler de decider QUAND l'appeler :
//     avant un jet si le cout est du meme en cas d'echec, a l'interieur de la branche succes
//     si le cout n'est du qu'en cas de reussite/acceptation, etc.
//   - advanceTime() reste totalement independante : elle avance l'horloge de jeu, jamais les
//     ressources. Un ordre qui doit faire les deux appelle les deux fonctions explicitement.
//   - Les PA restent TOUJOURS personnels (state.pa), meme quand le cout financier est
//     institutionnel (caisse d'un batiment). Le parametre `payeur` ne concerne que l'argent.
//
// Retour :
//   succes : { ok: true, paPreleves, montantPreleve }
//     (paPreleves vaut 0 si TEST_MODE, puisque state.pa n'est alors pas touche -- valeur
//     honnete refletant ce qui a reellement ete preleve, pas la valeur declarative de l'ordre)
//   echec  : { ok: false, raison: 'pa_insuffisants' | 'fonds_insuffisants' | 'caisse_institution_insuffisante' }
//     aucune ressource n'est modifiee en cas d'echec.
async function deduireCoutOrdre({ pa = 0, cost = 0, payeur = 'joueur' } = {}) {
  // A. PA : toujours personnels, ignores sous TEST_MODE (comme partout ailleurs dans le jeu)
  if (!TEST_MODE && (state.pa || 0) < pa) {
    return { ok: false, raison: 'pa_insuffisants' };
  }

  // B. Cout financier : jamais ignore par TEST_MODE (convention existante de doOrder())
  // Lot 3 (chantier fiscalite/Helvetia) : la verification porte desormais sur les fonds
  // ORDINAIRES (liquide + Banque nationale), jamais sur arg seul -- arg inclura un jour
  // Helvetia/placements, qui ne doivent jamais couvrir automatiquement une depense courante.
  if (cost > 0) {
    if (payeur === 'joueur') {
      const fondsDispo = typeof getFondsDisponiblesOrdinaires === 'function' ? getFondsDisponiblesOrdinaires() : (state.arg || 0);
      if (fondsDispo < cost) {
        return { ok: false, raison: 'fonds_insuffisants' };
      }
    } else if (payeur && payeur.type === 'institution') {
      // Verification + prelevement atomique en un seul appel : si la caisse ne couvre pas le
      // montant en entier, rien n'est preleve (voir diagnostic Phase K sur
      // debiterCaisseBatimentPlafonne, qui elle tolere le partiel pour d'autres usages).
      const montantVerse = typeof debiterCaisseBatimentAtomique === 'function'
        ? await debiterCaisseBatimentAtomique(payeur.pays, payeur.buildingId, cost)
        : 0;
      if (montantVerse < cost) {
        return { ok: false, raison: 'caisse_institution_insuffisante' };
      }
    }
  }

  // D. Deduction des PA (apres verification ET apres prelevement institutionnel reussi, pour
  // qu'un echec du prelevement financier ne laisse jamais les PA ampute pour rien)
  let paPreleves = 0;
  if (!TEST_MODE) {
    state.pa = Math.max(0, (state.pa || 0) - pa);
    paPreleves = pa;
  }

  // E. Deduction du cout personnel (le cas institutionnel a deja ete preleve atomiquement en B)
  // Lot 3 : via la primitive canonique (liquide d'abord, Banque nationale en complement,
  // jamais Helvetia/placements). La suffisance a deja ete verifiee en B avec la meme regle
  // (getFondsDisponiblesOrdinaires) -- ce debit ne peut donc pas echouer ici en pratique ; le
  // garde-fou {ok:false} n'est qu'une securite defensive, jamais attendue en conditions
  // normales.
  if (cost > 0 && payeur === 'joueur') {
    if (typeof debiterFondsOrdinaires === 'function') {
      const debit = await debiterFondsOrdinaires(cost);
      if (!debit.ok) {
        console.error('debiterFondsOrdinaires a echoue apres verification de suffisance -- etat incoherent possible', { cost, fondsDisponibles: typeof getFondsDisponiblesOrdinaires === 'function' ? getFondsDisponiblesOrdinaires() : null });
        return { ok: false, raison: 'fonds_insuffisants' };
      }
    } else {
      state.arg = Math.max(0, (state.arg || 0) - cost);
    }
  }

  return { ok: true, paPreleves, montantPreleve: cost };
}

function checkMidnight() {
  if (state.hour === 0 && state.minute < 2) {
    if (!state.midnightDone) {
      state.midnightDone = true;
      runMidnightUpdate();
    }
  } else {
    state.midnightDone = false;
  }
}

async function runMidnightUpdate() {
  state.day++;
  state.salaireTouche = false;
  // Traiter les plaintes et enquetes en cours
  traiterPlaintes();
  traiterEnquetes();
  traiterConvocations();
  verifierLiberationPrisonniers();
  verifierDecouverteCrimesPasses();
  // Budget institutions et population
  mettreAJourBudgets();
  mettreAJourPopulation();
  await alimenterBudgets();
  if (typeof verifierEffetsEtDistributionFiscale === 'function') await verifierEffetsEtDistributionFiscale();
  if (typeof traiterVirementJournalierCaserne === 'function') await traiterVirementJournalierCaserne(state.country || 'republic').catch(() => {});
  if (typeof payerSoldeQuotidienne === 'function') await payerSoldeQuotidienne(state.country || 'republic').catch(() => {});
  if (typeof verifierEffetsCouvreFeuQuotidien === 'function') await verifierEffetsCouvreFeuQuotidien(state.country || 'republic').catch(() => {});
  if (typeof verifierRechercheMilitaireQuotidien === 'function') await verifierRechercheMilitaireQuotidien(state.country || 'republic').catch(() => {});
  if (typeof verifierDesertionsQuotidien === 'function') await verifierDesertionsQuotidien(state.country || 'republic').catch(() => {});
  checkScandale();
  checkEffacementCrimes();
  payerInformateurs();
  // Revenus fiscaux
  const pop = CITY_POPULATION[state.country]?.[state.currentCity];
  if (pop) {
    const taxRevenue = pop.dailyTaxRevenue || 0;
    const oilRevenue = pop.oilRevenue || 0;
    const totalRevenue = taxRevenue + oilRevenue;
    if (totalRevenue > 0 && state.poste && ['president','pm','min_fin'].includes(state.poste.id)) {
      addJournalEntry(`Mise a jour minuit : recettes fiscales de ${totalRevenue.toLocaleString('fr-FR')} versees au tresor national.`, 'event-info');
    }
  }
  // Regeneration naturelle des PV si le joueur a ete agresse
  // "Jour N" retire du texte (correctif du 21 aout 2026) : addJournalEntry() prefixe deja chaque
  // entree d'un horodatage reel (formaterHorodatageJournal) -- redondant et fictif ici, sans
  // utilite propre au-dela de celui deja affiche par le journal lui-meme.
  addJournalEntry(`Nouveau jour. La ville s'eveille.`, 'event-info');
  updateClock();
}

// =====================

// =====================
// UI UPDATE
// =====================
function updateUI() {
  verifierObjectifs();
  const cur = state.char ? (COUNTRIES[state.char.country]?.cur || 'FR') : 'FR';
  // Sauvegarde auto Supabase
  if (typeof sbAutoSave === 'function' && state?.char?.name) sbAutoSave();
  renderEmployesPanel();
  if (typeof renderInventory === 'function') renderInventory();
  // Sauvegarde localStorage — sync état complet
  if (state.char?.name) {
    state.char.poste       = state.poste || null;
    state.char.currentCity = state.currentCity || 'capitale';
    // IMPORTANT : state.currentBuilding est toujours la verite vivante (mise a jour a
    // chaque entree/sortie de batiment ou changement de ville). Le repli vers l'ancienne
    // valeur cachee de char.currentBuilding empechait null (= dans la rue) d'etre jamais
    // reellement sauvegarde, ce qui faisait ressurgir un ancien batiment (parfois d'une
    // autre ville) au moindre rafraichissement de page.
    state.char.currentBuilding = state.currentBuilding || null;
    state.char.currentRoom     = state.currentRoom || null;
    state.char.arg         = state.arg || 0;
    state.char.resources   = { inf: state.inf||0, pop: state.pop||0, dis: state.dis||50 };
    state.char.hp          = state.hp || 100;
    state.char.pa          = (typeof state.pa === 'number') ? state.pa : 10;
    state.char.moral       = state.moral || 75;
    try {
      localStorage.setItem('respublica_char_' + state.char.name, JSON.stringify(state.char));
      localStorage.setItem('respublica_char', JSON.stringify(state.char));
    } catch(e) {}
  }
  document.getElementById('r-pa').textContent   = TEST_MODE ? '∞' : state.pa;
  document.getElementById('b-pa').style.width   = TEST_MODE ? '100%' : (Math.min(state.pa, PA_MAX) / PA_MAX * 100) + '%';
  document.getElementById('r-arg').textContent  = state.arg.toLocaleString('fr-FR') + ' ' + cur;
  document.getElementById('r-inf').textContent  = state.inf;
  document.getElementById('b-inf').style.width  = state.inf + '%';
  document.getElementById('r-pop').textContent  = state.pop;
  document.getElementById('b-pop').style.width  = state.pop + '%';
  document.getElementById('r-dis').textContent  = state.dis;
  document.getElementById('b-dis').style.width  = state.dis + '%';
  document.getElementById('r-hp').textContent   = state.hp;
  document.getElementById('b-hp').style.width   = state.hp + '%';
  document.getElementById('r-moral').textContent = state.moral;
  document.getElementById('b-moral').style.width  = state.moral + '%';

  // Badge mail
  const unread = (state.mails || []).filter(m => !m.read).length;
  const badge = document.getElementById('mail-badge');
  if (badge) {
    badge.textContent = unread;
    badge.style.display = unread > 0 ? 'inline' : 'none';
  }

  // Indices nationaux dans topbar (calcules -- moyenne des villes pour Republia)
  const pays = state.country || 'republic';
  const idx = (typeof getIndiceNationalCalcule === 'function')
    ? { ISN: getIndiceNationalCalcule(pays,'isn'), IE: getIndiceNationalCalcule(pays,'ie'), ID: INDICES_NATIONAUX?.[pays]?.ID ?? 40 }
    : ((typeof INDICES_NATIONAUX !== 'undefined') ? (INDICES_NATIONAUX[pays] || {ISN:30,IE:50,ID:40,IS:45}) : {ISN:30,IE:50,ID:40,IS:45});
  const setIdx = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
  setIdx('idx-isn', idx.ISN);
  setIdx('idx-ie',  idx.IE);
  setIdx('idx-id',  idx.ID);
  setIdx('idx-is',  idx.IS);
  // Nom de l'empire
  const indicesBar = document.getElementById('indices-bar');
  if (indicesBar) {
    const nomSpan = indicesBar.querySelector('span');
    if (nomSpan) nomSpan.textContent = COUNTRIES[pays]?.n || 'Republia';
    indicesBar.title = 'Indices de ' + (COUNTRIES[pays]?.n || 'Republia') + ' — cliquer pour details';
  }

  // Inventaire
  document.getElementById('inv-liquide').textContent = state.liquide.toLocaleString('fr-FR') + ' ' + cur;
  document.getElementById('inv-banque').textContent  = totalComptesBancaires().toLocaleString('fr-FR') + ' ' + cur;
  if (typeof renderInventory === 'function') renderInventory();
}

function updateLocationDisplay() {
  const world = WORLD[state.country];
  const city = world?.[state.currentCity];
  const co = COUNTRIES[state.country];

  document.getElementById('loc-city').textContent = `${city?.name || ''}, ${co?.n || ''}`;

  if (!state.currentBuilding) {
    document.getElementById('loc-name').textContent = 'Dans la rue';
    document.getElementById('loc-sub').textContent = 'Selectionnez un batiment';
  }
}

// =====================
// TOAST & JOURNAL
// =====================
function showToast(result, msg, success, isCrit) {
  const t = document.getElementById('result-toast');
  t.className = isCrit ? 'toast-crit' : success ? 'toast-success' : 'toast-fail';
  document.getElementById('toast-result').textContent = result;
  document.getElementById('toast-sub').textContent = msg;
  t.style.display = 'block';
  clearTimeout(window._toastTimer);
  window._toastTimer = setTimeout(() => { t.style.display = 'none'; }, 3800);
}

const MOIS_FR_JOURNAL = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];

// Formate un horodatage reel (ISO, ex. created_at Supabase ou Date.now() local capture a
// l'insertion) en "18 août 2026 · 16h00". Retourne null si aucun horodatage exploitable --
// ne JAMAIS deriver cet affichage de state.day (doctrine "Confort de lecture", 18 aout 2026 :
// state.day est une convention de jeu, pas une date reelle, et ne doit jamais servir a afficher
// une date au joueur).
function formaterHorodatageJournal(iso) {
  if (!iso) return null;
  const d = new Date(iso);
  if (isNaN(d.getTime())) return null;
  const h = String(d.getHours()).padStart(2, '0');
  const m = String(d.getMinutes()).padStart(2, '0');
  return `${d.getDate()} ${MOIS_FR_JOURNAL[d.getMonth()]} ${d.getFullYear()} · ${h}h${m}`;
}

function addJournalEntry(text, cls) {
  const j = document.getElementById('journal');
  const ts = new Date().toISOString();
  const div = document.createElement('div');
  div.className = 'journal-entry';
  div.innerHTML = `<span class="journal-time">${formaterHorodatageJournal(ts)}</span>
    <span class="journal-text ${cls||''}">${text}</span>`;
  j.insertBefore(div, j.firstChild);

  // Persistance (10 aout 2026) : conserve les 120 dernieres entrees, la plus recente en tete
  // (unshift). Vit uniquement sur state.char.journal, jamais de miroir state.journal separe --
  // deliberement, pour ne pas reproduire le bug de state.arg (valeur correcte ecrasee par un
  // defaut faute d'etre resynchronisee vers state.char avant sauvegarde).
  if (state.char) {
    if (!Array.isArray(state.char.journal)) state.char.journal = [];
    state.char.journal.unshift({ day: state.day, hour: state.hour, text, cls: cls || '', ts });
    if (state.char.journal.length > 120) state.char.journal.length = 120;
  }

  // Signaler les evenements importants (mauvaises nouvelles, événements externes)
  const important = ['event-bad', 'event-secret', 'event-external'];
  if (important.includes(cls) && typeof signalerEvenementJournal === 'function') {
    signalerEvenementJournal();
  }
}

// Reinjecte les entrees de journal personnel persistees (state.char.journal, jusqu'a 120)
// dans le panneau #journal au chargement -- appelee a la fois apres la restauration rapide
// depuis localStorage et apres la fusion Supabase (voir loadCharacter), pour refleter la
// version la plus a jour dans les deux cas.
function restaurerJournal(char) {
  const j = document.getElementById('journal');
  if (!j || !Array.isArray(char?.journal)) return;
  j.innerHTML = '';
  char.journal.forEach(entry => {
    // entry.ts n'existe que pour les entrees creees apres l'introduction de l'horodatage reel
    // (18 aout 2026) -- repli honnete sur "Jour X" pour les entrees anciennes, sans rien inventer.
    const h = String(entry.hour ?? 0).padStart(2, '0');
    const horodatage = formaterHorodatageJournal(entry.ts) || `Jour ${entry.day} · ${h}h00`;
    const div = document.createElement('div');
    div.className = 'journal-entry';
    div.innerHTML = `<span class="journal-time">${horodatage}</span>
      <span class="journal-text ${entry.cls || ''}">${entry.text}</span>`;
    j.appendChild(div);
  });
}

// Close modals on overlay click
