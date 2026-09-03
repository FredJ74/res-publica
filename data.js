/* ===========================
   RES PUBLICA — DATA.JS v2
   =========================== */

const COUNTRIES = {
  republic: {
    n:'Republia', col:'#4a9ade', cur:'FR', icon:'ti-building-community',
    desc:'Democratie fatiguee, elites consanguines, scandale mediatique comme sport national.',
    tags:['Democratie','Satirique'],
    bases:{INT:8,CHA:7,VOL:6,PER:7,DUP:7,ENT:7},
    capitaleName:'Luthecia'
  },
    narco: {
    n:'El Estado', col:'#cc6644', cur:'PS', icon:'ti-skull',
    desc:'Democratie de facade, cartels, elections achetees. La violence est une langue politique.',
    tags:['Violent','Corruption'],
    bases:{INT:6,CHA:7,VOL:8,PER:8,DUP:8,ENT:5},
    capitaleName:'Ciudad Roja'
  },
  soviet: {
    n:'Sovarka', col:'#cc4444', cur:'RP', icon:'ti-hammer',
    desc:'Parti unique en tension interne. Reformistes contre conservateurs.',
    tags:['Parti unique','Factions'],
    bases:{INT:8,CHA:6,VOL:9,PER:8,DUP:7,ENT:6},
    capitaleName:'Novomirsk'
  },
  khalija: {
    n:'Al-Khalija', col:'#C9A84C', cur:'DR', icon:'ti-crown',
    desc:'Monarchie absolue, famille royale tentaculaire. La Grace Royale est la seule monnaie.',
    tags:['Monarchie','Theocratie'],
    bases:{INT:7,CHA:8,VOL:8,PER:7,DUP:8,ENT:8},
    capitaleName:'Al-Madina'
  }
};

// Rééquilibrage (bêta) : la richesse et la puissance statistique ne progressent plus
// systématiquement dans le même sens sur un même choix -- chaque origine a désormais un net de
// caractéristiques différent, corrélé négativement avec son capital (voir artefact "Refonte de
// la création de personnage" pour le détail du raisonnement).
const ORIGINS = [
  {id:'poor',     icon:'ti-home-off',           name:'Milieu defavorise',  arg:300,  bonuses:{VOL:2,DUP:2}, malus:{CHA:-1}, trait:'Resilience brute, rien a perdre'},
  {id:'worker',   icon:'ti-tool',               name:'Classe ouvriere',    arg:600,  bonuses:{VOL:1,PER:1}, malus:{DUP:-1}, trait:'Sens du collectif, mains calleuses, trop honnete pour bien mentir'},
  {id:'bourgeois',icon:'ti-building',           name:'Petite bourgeoisie', arg:1000, bonuses:{INT:1,CHA:1}, malus:{ENT:-1}, trait:"Vernis social, ambitions mesurees, pas encore le bon carnet d'adresses"},
  {id:'elite',    icon:'ti-building-skyscraper',name:'Haute societe',      arg:2200, bonuses:{ENT:2},       malus:{VOL:-2}, trait:"Carnet d'adresses ancestral, mais n'a jamais connu la difficulte reelle"}
];

// compPts retire (bêta) : jamais stocke ni relu, aucune mecanique reelle (voir audit). blocks
// mis a jour vers les 10 id de carriere actuels (voir CAREERS/MIGRATION_CAREER_IDS). "higher"
// bloque desormais aussi les professions intellectuelles (medecin/universitaire), reservees a
// "Hautes ecoles" -- la seule ecole a recevoir un bonus d'argent explicite (+400, prestige/
// reseau plutot que superiorite statistique pure : le net de caracteristiques reste +2 pour
// les 4 ecoles).
const SCHOOLS = [
  {id:'none',   icon:'ti-x',      name:"Pas d'ecole",        bonuses:{DUP:2,VOL:1}, malus:{INT:-1}, argBonus:0,   blocks:['magistrat','business','doctor'], blockLabel:'Bloque : justice, affaires, professions intellectuelles'},
  {id:'basic',  icon:'ti-book',   name:'Ecole basique',      bonuses:{PER:1,ENT:1}, malus:{},       argBonus:0,   blocks:['magistrat','business'],           blockLabel:'Bloque : justice, affaires'},
  {id:'higher', icon:'ti-school', name:'Etudes superieures', bonuses:{INT:1,CHA:1}, malus:{},       argBonus:0,   blocks:['doctor'],                         blockLabel:'Bloque : professions intellectuelles (reservees aux hautes ecoles)'},
  {id:'elite',  icon:'ti-award',  name:'Hautes ecoles',      bonuses:{INT:2,ENT:1}, malus:{VOL:-1}, argBonus:400, blocks:[],                                 blockLabel:'Toutes carrieres accessibles + bonus de reseau'}
];

// Seul le capital de depart est retouche (bêta) -- bonus/malus/desc inchanges, deja bien
// concus (voir artefact). Casse la correlation actuelle entre "meilleures stats sous le
// nouveau bareme" et "plus riche" (Capitaliste et Criminel, les deux natures DUP, etaient
// aussi les deux plus riches).
const ARCHETYPES = [
  {id:'politician',    icon:'ti-speakerphone',   name:'Ambitieux',               bonuses:{CHA:2,ENT:2}, malus:{DUP:-2}, argBonus:400,  infBonus:15, popBonus:20,  disBonus:-10, desc:"Seduction et persuasion. Le pouvoir est votre oxygene."},
  {id:'authoritarian', icon:'ti-sword',          name:'Ordre et discipline',     bonuses:{VOL:2,PER:2}, malus:{ENT:-2}, argBonus:600,  infBonus:20, popBonus:5,   disBonus:5,   desc:"La hierarchie et la force. L'ordre est la seule vraie valeur."},
  {id:'oligarch',      icon:'ti-briefcase',      name:'Capitaliste',             bonuses:{INT:2,DUP:2}, malus:{CHA:-2}, argBonus:900,  infBonus:10, popBonus:-5,  disBonus:5,   desc:"L'argent est la mesure de toutes choses."},
  {id:'informer',      icon:'ti-news',           name:"Diffuseur d'informations",bonuses:{PER:2,INT:2}, malus:{VOL:-2}, argBonus:350,  infBonus:5,  popBonus:15,  disBonus:-5,  desc:"L'information est votre arme et votre raison d'etre."},
  {id:'legalist',      icon:'ti-scale',          name:'Legaliste',               bonuses:{INT:2,VOL:2}, malus:{CHA:-2}, argBonus:700,  infBonus:15, popBonus:5,   disBonus:10,  desc:"Les regles, les textes, les procedures. Vous savez comment les plier."},
  {id:'believer',      icon:'ti-building-church',name:'Homme de foi',            bonuses:{CHA:2,ENT:2}, malus:{DUP:-2}, argBonus:300,  infBonus:10, popBonus:25,  disBonus:0,   desc:"Une conviction profonde vous anime. Elle mobilise les foules."},
  {id:'shadow',        icon:'ti-user-question',  name:"Homme de l'ombre",        bonuses:{DUP:2,PER:2}, malus:{CHA:-2}, argBonus:500,  infBonus:5,  popBonus:-10, disBonus:20,  desc:"Infiltration, manipulation, double jeu. Vous n'existez pas officiellement."},
  {id:'anticapitalist',icon:'ti-users-group',    name:'Anti-capitaliste',        bonuses:{CHA:2,VOL:2}, malus:{INT:-2}, argBonus:350,  infBonus:10, popBonus:20,  disBonus:-5,  desc:"Vous combattez le systeme. La justice sociale est votre etendard."},
  {id:'criminal',      icon:'ti-eye-off',        name:'Criminel',                bonuses:{DUP:2,VOL:2}, malus:{ENT:-2}, argBonus:1200, infBonus:5,  popBonus:-15, disBonus:15,  desc:"En dehors des lois. Vos propres regles, bien plus efficaces."}
];

// Consolidation 18->10 (bêta, arbitrage joueur) : chaque carrière fusionnée garde l'id interne
// de l'UNE de ses composantes (celle déjà référencée ailleurs dans le code par comparaison
// directe sur char.career -- voir MIGRATION_CAREER_IDS ci-dessous pour la table complète des
// anciens id vers les 10 actuels, utilisée par migrerCareerId() au chargement d'un personnage
// existant). contact/casserole retirés (purement décoratifs, jamais lus ailleurs que par
// l'écran de création lui-même -- voir audit). Argent/prérequis rééquilibrés selon les mêmes
// principes que les autres tables (origines/écoles/natures) : la carrière la mieux payée
// (Affaires) exige désormais un vrai prérequis scolaire, ce qui n'était pas le cas avant.
const CAREERS = [
  {id:'officer',   name:'Armée — Officier supérieur / Mercenaire',        icon:'ti-military-rank',   argBonus:700,  statKey:'VOL', comp:'Commandement, Intimidation',            blocks:[]},
  {id:'business',  name:'Affaires — Homme d\'affaires / Lobbyiste',        icon:'ti-chart-line',      argBonus:1200, statKey:'INT', comp:'Lobbying, Blanchiment, Negociation',    blocks:['none','basic']},
  {id:'magistrat', name:'Justice — Magistrat / Avocat',                    icon:'ti-gavel',           argBonus:800,  statKey:'INT', comp:'Droit, Procedure judiciaire, Negociation', blocks:['none','basic']},
  {id:'press',     name:'Médias & Communication — Grand journaliste / Influenceur', icon:'ti-pencil', argBonus:450,  statKey:'PER', comp:'Kompromat, Propagande, Reseaux sociaux',blocks:[]},
  {id:'clergy',    name:'Religion — Chef de culte',                        icon:'ti-star',            argBonus:150,  statKey:'CHA', comp:'Rhetorique, Mobilisation',              blocks:[]},
  {id:'doctor',    name:'Professions intellectuelles — Médecin / Universitaire', icon:'ti-stethoscope', argBonus:550, statKey:'INT', comp:'Reseau civil, Discretion, Rhetorique', blocks:['none','basic','higher']},
  {id:'worker',    name:'Monde ouvrier — Ouvrier / Syndicaliste',          icon:'ti-hammer',          argBonus:300,  statKey:'VOL', comp:'Force, Solidarite, Mobilisation',       blocks:[]},
  {id:'intel',     name:'Renseignement — Agent des services',              icon:'ti-spy',             argBonus:500,  statKey:'PER', comp:'Surveillance, Infiltration',            blocks:[]},
  {id:'criminal_c',name:'Crime organisé — Criminel organisé',              icon:'ti-lock-open',       argBonus:900,  statKey:'DUP', comp:'Milices, Blanchiment',                  blocks:[]}, // Accessible a tous
  {id:'escort',    name:'Prostitution — Prostitué(e)',                     icon:'ti-heart',           argBonus:450,  statKey:'CHA', comp:'Seduction, Kompromat',                  blocks:[]}
];

// Migration des anciens id de carrière (18 -> 10, bêta) pour les personnages déjà créés/
// sauvegardés. Appliquée au chargement (voir migrerCareerId(), plateau-core.js) -- ne modifie
// jamais les données en base directement, seulement la valeur lue en mémoire, pour rester
// cohérent avec le principe "ne casse rien silencieusement" sans réécrire l'historique.
// - Fusions vers l'id conservé : lawyer/civil/local_civil->magistrat (civil/local_civil
//   n'avaient pas de remplaçant direct ; magistrat est le plus proche, service de l'Etat/INT),
//   influencer->press, academic->doctor, lobbyist->business, union->worker.
// - unemployed n'a pas de remplaçant thématique évident (aucune des 10 carrières restantes ne
//   représente "sans emploi") ; mappé vers worker, la carrière la plus modeste restante.
const MIGRATION_CAREER_IDS = {
  civil: 'magistrat', local_civil: 'magistrat', lawyer: 'magistrat',
  influencer: 'press', academic: 'doctor', lobbyist: 'business',
  union: 'worker', unemployed: 'worker'
};

// Descriptions courtes (bêta) reprises telles quelles de l'artefact "Refonte de la création de
// personnage" -- pensées pour l'écran de création (creation.js), pas retouchées ailleurs.
const STAT_DEFS = [
  {k:'INT', n:'Intelligence', d:"Comprendre, analyser, anticiper : utile pour l'enquete, la finance, et dejouer les pieges les plus subtils.", i:'ti-brain'},
  {k:'CHA', n:'Charisme',     d:'Convaincre, seduire, apaiser : la cle de toute negociation, plaidoirie ou discours.',                          i:'ti-speakerphone'},
  {k:'VOL', n:'Volonte',      d:"Tenir bon : resister a la pression, a l'arrestation, a la torture -- et se battre quand il n'y a plus le choix.", i:'ti-flame'},
  {k:'PER', n:'Perception',   d:'Reperer ce qui vous echappe : detecter un mensonge, filer une cible, ne jamais etre surpris.',                  i:'ti-eye'},
  {k:'DUP', n:'Duplicite',    d:'Mentir, dissimuler, corrompre : la specialite de tous ceux qui vivent dans l\'illegalite.',                     i:'ti-masks-theater'},
  {k:'ENT', n:'Entregent',    d:'Construire et entretenir un reseau : peu spectaculaire dans l\'instant, decisif sur la duree.',                 i:'ti-network'}
];

// =====================
// WORLD MAP STRUCTURE
// =====================
const WORLD = {
  republic: {
    capitale: {
      name:'Luthecia',
      imageUrl:'https://images.unsplash.com/photo-1520939817895-060bdaf4fe1b?w=1200&q=80',
      desc:'Capitale de Republia. Centre du pouvoir politique, judiciaire et mediatique.',
      isCapitale: true,
      streetName: 'Avenue de la République',
      districts: ['centre','quartier-nord','quartier-sud'],
      buildings: ['palais-presidentiel','hotel-republica','palais-gouvernement','assemblee','tribunal','banque-nationale','banque-privee','clinique-privee','dispensaire-public','commissariat','la-tribune','loge-maconnique','universite','armurerie','marche','mairie-capitale','tabernacle-impots','centre-multinodal-luthecia','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-1','terrain-a-batir-2','terrain-a-batir-3','terrain-a-batir-4','terrain-a-batir-5','office-notarial','stade','quartier-ambassades','place-formulaire-liberte','musee-ville-luthecia','musee-national-republia','parc-botanique-national','entrepot-logistique-luthecia','usine-pharmaceutique-luthecia','bureau-national-emploi'],
      buildingContext: {
        'stade': {
          name: "Stade Gourgeot — Olympique de Luthécia",
          desc: "L'antre du club le plus titré de Republia. Ambiance electrique les soirs de match.",
          persons: [
            {name:'Jean-Pierre Taclojnou (PNJ)', role:'Entraineur', rel:'neutral', job:'entraineur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entraineur-jean-pierre-taclojnou.png'},
            {name:'Michel Parlotte (PNJ)', role:'Journaliste Sportif', rel:'neutral', job:'commentateur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/journaliste-michel-parlotte.png'}
          ],
          roomOverrides: {
            terrain: { name: "Terrain — Olympique de Luthécia", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/stade-olympique-luthecia.png" },
            vestiaires: { name: "Vestiaire — Olympique de Luthécia", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/vestiaires-luthecia.png",
              persons: [{name:'Alphonse Toudroit (PNJ)', role:'Entraineur Adjoint', rel:'neutral', job:'entraineur_adjoint', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entraineur-adjoint-alphonse-toudroit.png'}]
            },
            buvette: { name: "Boutique et Buvette — Olympique de Luthécia", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/buvette-boutique-luthecia.png",
              persons: [
                {name:'Justin Verre (PNJ)', role:'Tenancier de Buvette', rel:'neutral', job:'serveur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/buvette-scene-tenancier.png'},
                {name:'Jean Fourtout (PNJ)', role:'Vendeur de Produits Dérivés', rel:'neutral', job:'commercant', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/buvette-scene-vendeur.png'}
              ]
            },
            guichet_paris: { name: "Guichet des Paris Sportifs — Olympique de Luthécia", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/guichet-paris-luthecia.jpeg",
              persons: [{name:'Ricardo Pif (PNJ)', role:'Bookmaker Officiel', rel:'neutral', job:'bookmaker', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bookmaker-ricardo-pif.png'}]
            },
            siege_supporters: { name: "Les Vieilles Tuiles de Luthécia — Siège des Supporters", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/siege-supporters-luthecia.png",
              persons: [{name:'Alfredo Mifassole (PNJ)', role:'Meneur des Supporters', rel:'neutral', job:'meneur_supporters', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/meneur-supporters-alfredo-mifassole.png'}]
            },
            bureau_president: { name: "Bureau du Président — Olympique de Luthécia", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-president-luthecia.png" }
          }
        },
        'hotel-republica': {
          name: "Hôtel-Restaurant La Républia",
          desc: "Le grand hôtel de Luthecia. Gaston Sauceblanche règne sur la salle avec un mépris souverain."
        },
        'commissariat': {
          name: "Commissariat Central de Luthecia",
          desc: "Raoul Toufaud pointe toujours dans la mauvaise direction.",
          persons: [{"name": "Gardien de la Paix (PNJ)", "role": "Agent d'accueil", "rel": "neutral", "job": "gardien_paix", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-gardien-paix.png", "photoPos": "50% 15%"}]
        },
        'tribunal': {
          name: "Tribunal de Luthecia",
          desc: "Honoré Cozetoujours condamne avant d'écouter.",
          persons: [{"name": "Honoré Cozetoujours (PNJ)", "role": "Juge en chef", "rel": "neutral", "job": "juge"}, {"name": "Maître Plaidoyer (PNJ)", "role": "Avocat commis d'office", "rel": "neutral", "job": "avocat"}]
        },
        'banque-privee': {
          name: "Banque Privée Helvetia",
          desc: "Hans Von Discret ne confirme ni n'infirme rien.",
          persons: [{"name": "Hans Von Discret (PNJ)", "role": "Directeur", "rel": "neutral", "job": "banquier", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/banque-privee-helvetia-hans-von-discret.png", "photoPos": "50% 20%"}, {"name": "Ursula Offshore (PNJ)", "role": "Conseillère en optimisation fiscale", "rel": "neutral", "job": "conseiller", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/banque-privee-helvetia-ursula-offshore.png", "photoPos": "50% 15%"}]
        },
        'clinique-privee': {
          name: "Clinique Privée Saint-Luc",
          desc: "Docteur Bistouri opère dans l'ordre alphabétique du portefeuille.",
          persons: [{"name": "Docteur Bistouri (PNJ)", "role": "Chirurgien", "rel": "neutral", "job": "medecin"}, {"name": "Sophie Stiquay (PNJ)", "role": "Infirmière", "rel": "neutral", "job": "infirmier"}]
        },
        'dispensaire-public': {
          name: "Dispensaire Public de Luthecia",
          desc: "Docteur Aspirine prescrit du repos pour tout.",
          persons: [{"name": "Docteur Aspirine (PNJ)", "role": "Généraliste", "rel": "neutral", "job": "medecin"}, {"name": "Anne Tibiotique (PNJ)", "role": "Infirmière", "rel": "neutral", "job": "infirmier"}]
        },
        'la-tribune': {
          name: "L'Autruche Entravée",
          desc: "Le journal d'investigation de Républia.",
          persons: [{"name": "Gustave Encre (PNJ)", "role": "Imprimeur", "rel": "neutral", "job": "journaliste"}, {"name": "Rosalie Caractère (PNJ)", "role": "Libraire", "rel": "neutral", "job": "journaliste"}, {"name": "Jodie Moitout (PNJ)", "role": "Journaliste micro-trottoir", "rel": "neutral", "job": "journaliste", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jodie-moitout.png", "photoPos": "62% 20%"}],
          // Tracts calomnieux (24 aout 2026) : ajoute UNIQUEMENT a l'accueil de La Tribune de
          // Luthecia (republic/capitale) via roomOverrides.orders, fusion additive (voir
          // allOrders, plateau-politique.js) -- les 4 ordres de base (se_renseigner/
          // consulter_archives_presse/imprimer_tracts/vendre_bois_imprimerie) restent intacts,
          // rien retire. Handler unique imprimer_tracts_calomnieux (plateau-communication.js),
          // partage avec Montrouge/PSM -- aucune logique dupliquee. Ne touche pas redaction, ni
          // les autres empires partageant le buildingId 'la-tribune' (chacun a son propre
          // buildingContext, non modifie ici).
          roomOverrides: {
            accueil_tribune: {
              orders: [
                {fn:'imprimer_tracts_calomnieux', label:'Imprimer des tracts calomnieux', pa:1, cost:0, type:'illegal', icon:'ti-eye-off', successRate:100, desc:'Choisir une cible (répertoire). Campagne mensongère clandestine. Produit un lot de 10 tracts calomnieux. Coût : 1 PA + bois en stock personnel.'},
                // Petites annonces (chantier "La Tribune de Republia", 31 aout 2026) : gere en
                // dehors du pipeline PA/argent generique (doOrder), voir ouvrirFormulairePetiteAnnonce
                // (plateau-communication.js) -- cost:0 ici, le debit reel (30 FR) et la verification
                // "une annonce active a la fois" ont lieu dans ce flux dedie, jamais dans un jet.
                {fn:'deposer_petite_annonce', label:'Déposer une petite annonce', pa:1, cost:0, type:'legal', icon:'ti-ad', successRate:100, desc:"30 FR pour une parution de 3 jours dans La Tribune de Républia. Une seule annonce active à la fois."}
              ]
            }
          }
        },
        'loge-maconnique': {
          requiresMembership: 'loge',
          name: "Loge Maçonnique de Luthecia",
          desc: "Frère Jacques D'Equerre parle uniquement en métaphores géométriques.",
          persons: [{"name": "Frère Jacques D'Equerre (PNJ)", "role": "Grand Maître", "rel": "neutral", "job": "loge"}, {"name": "Frère Maurice Compas (PNJ)", "role": "Trésorier", "rel": "neutral", "job": "loge"}]
        },
        'universite': {
          name: "Université de Luthecia",
          desc: "Professeur Charabia donne des cours incompréhensibles même pour lui.",
          persons: [{"name": "Professeur Charabia (PNJ)", "role": "Doyen", "rel": "neutral", "job": "professeur"}, {"name": "Assistante Mémoire (PNJ)", "role": "Assistante", "rel": "neutral", "job": "professeur"}]
        },
        'armurerie': {
          name: "Armurerie Martinon",
          desc: "Roger Détente ne pose jamais trop de questions.",
          persons: [{"name": "Roger Détente (PNJ)", "role": "Armurier", "rel": "neutral", "job": "commercant"}, {"name": "Simone Calibre (PNJ)", "role": "Assistante", "rel": "neutral", "job": "commercant"}],
          orders: [
            {fn:'marche_noir', label:'Marché Noir', pa:1, cost:0, type:'illegal', icon:'ti-alert-triangle', successRate:100, desc:'Explosifs et le poison local de Roger Détente. Rien de tout cela n\'est enregistré.'}
          ]
        },
        'office-notarial': {
          name: "Office Notarial — Maître Dubois & Associés",
          desc: "Le notaire de la nation. Ventes de terrain, successions, contrats de mariage — tout ce qui doit rester ecrit, ici, pour toujours.",
          roomOverrides: {
            accueil_notaire: { imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/accueil-notaire-luthecia.png" },
            bureau_successions: { imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-successions-luthecia.png" },
            bureau_contrats: { imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-contrats-luthecia.png" },
            archives_notariales: { imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/archives-notariales-luthecia.png" }
          }
        },
        'marche': {
          name: "Marché Central de Luthecia",
          desc: "Marcel Bidoche vend de la viande et des informations. Ginette Légume sait tout sur tout le monde. Jodie Moitout tend son micro à n'importe qui.",
          persons: [{"name": "Jean-Pierre Bidoche (PNJ)", "role": "Boucher", "rel": "neutral", "job": "commercant", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marcel-bidoche.png", "photoPos": "65% 30%"}, {"name": "Ginette Légume (PNJ)", "role": "Maraîchère", "rel": "neutral", "job": "commercant", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/ginette-legume.png", "photoPos": "65% 25%"}, {"name": "Jodie Moitout (PNJ)", "role": "Journaliste micro-trottoir", "rel": "neutral", "job": "journaliste", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jodie-moitout.png", "photoPos": "62% 20%"}],
          // Lot Marche (21 aout 2026) : ordres commerce generiques additifs, propres a Luthecia
          // uniquement (roomOverrides.orders, fusion additive avec le template de base partage
          // avec Montrouge -- jamais un remplacement, voir renderRoomActions()). Pas de
          // gerer_commerce (meme choix que la buvette du stade : commerce institutionnel, jamais
          // rachetable, absent de PRIX_RACHAT_COMMERCE -- l'exposer afficherait un faux "reserve
          // au proprietaire" trompeur).
          roomOverrides: {
            marche_ext: {
              // se_nourrir masque UNIQUEMENT ici (excludeOrders, plateau-politique.js
              // renderRoomActions) : le template partage BUILDINGS['marche'] n'est pas modifie,
              // Khalija le conserve tel quel. Montrouge l'exclut desormais aussi via son propre
              // roomOverride (Lot 5A, voir buildingContext.marche ci-dessous dans ville_b).
              excludeOrders: ['se_nourrir'],
              // Lot 5A -- Faire des achats (24 aout 2026) : "Voir ce qu'il y a a manger"
              // (consulter_carte_commerce) retire, remplace par "Faire des achats"
              // (faire_achats_marche, categories aliment/souvenir/cartes postales) -- l'ancien
              // sandwich ne fait plus partie de la carte de ce marche (voir DOTATIONS_COMMERCE_
              // PILOTE['marche'], plateau-actions-illegales-rumeurs.js). Libelle de production
              // generalise ("Préparer des sandwiches" -> "Produire les articles du marché"),
              // desormais partage a l'identique par les 3 marches (Luthecia/Montrouge/PSM).
              orders: [
                {fn:'produire_commerce', label:'Produire les articles du marché', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Produire les articles en vente au marché (consomme les matières en stock, rémunéré en FR).'},
                {fn:'faire_achats_marche', label:'Faire des achats', pa:0, cost:0, type:'legal', icon:'ti-shopping-bag', successRate:100, desc:'Nourriture à emporter, souvenir local, cartes postales.'},
                {fn:'vendre_matiere_commerce', label:'Vendre des matières au marché', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les matières premières de votre inventaire à ce marché.'}
              ]
            }
          }
        }
      }
    },
    ville_a: {
      name:'Port-Sainte-Marie',
      imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie.png',
      desc:'Ville portuaire a l\'ouest. Commerce, contrebande et politique locale.',
      isCapitale: false,
      buildings: ['hotel-port','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','bar-des-pecheurs','imprimerie-librairie','centre-multinodal-port-sainte-marie','port-sainte-marie','port-plaisance-psm','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-8','terrain-a-batir-9','terrain-a-batir-10','terrain-a-batir-11','stade','zone-production','capitaine-sauvage','chasse-peche-psm','place-armes-psm','ecole-marine','chantier-naval','notre-dame-mer','phare-psm','marche-psm','musee-port-sainte-marie','pole-tabac-alcools-psm','entrepot-logistique-psm'],
      buildingContext: {
        // Rattrapage fonctionnel de la mairie de PSM (audit dedie, meme jour) : modele
        // structurel identique a celui deja utilise pour Montrouge (roomOverrides +
        // roomsExtra, BUILDINGS['mairie'] partage inchange). objet_trouve ajoute a
        // accueil_mairie (ordre generique deja utilise a Luthecia, aucune nouvelle
        // mecanique). salle_elections/salle_archives ajoutees via roomsExtra, memes
        // ordres/handlers que Montrouge -- consulter_mandats_maires volontairement absent
        // (contenu hardcode Luthecia, meme raison que Montrouge). Logements sociaux
        // volontairement absents (specifiques a Montrouge, non demandes ici). Aucun PNJ.
        // Visuels ajoutes plus tard (micro-lot dedie, meme jour) : imageUrl sur
        // salle_elections/salle_archives (emoji provisoire retire), imageBg conserve en repli.
        'mairie': {
          name: "Hôtel de Ville de Port-Sainte-Marie",
          roomOverrides: {
            accueil_mairie: {
              orders: [
                {fn:'objet_trouve', label:'Reclamer un objet trouve', pa:1, cost:0, type:'legal', icon:'ti-briefcase', successRate:100, desc:'Le service des objets trouves. On ne sait jamais ce qui finit dans une boite en carton...'}
              ]
            }
          },
          roomsExtra: {
            salle_elections: {
              name: "Salle des Élections",
              imageBg: "linear-gradient(135deg,#0f1810,#142014)",
              imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-mairie-salle-elections.png",
              desc: "La salle où sont gérés les scrutins et candidatures officielles de la ville.",
              persons: [],
              orders: [
                {fn:'consulter_elections',  label:'Voir les candidats',         pa:0, cost:0,    type:'legal',   icon:'ti-list',          successRate:100, desc:'Liste des candidats declares et sondages.'},
                {fn:'contester_resultats',  label:'Contester des resultats',    pa:3, cost:200,  type:'legal',   icon:'ti-alert-triangle',successRate:40,  desc:'Contester le resultat d\'une election. Long processus.'},
                {fn:'falsifier_docs',       label:'Falsifier une liste',        pa:3, cost:500,  type:'illegal', icon:'ti-file-x',        successRate:35,  desc:'Manipuler les listes electorales. Tres risque.'}
              ]
            },
            salle_archives: {
              name: "Salle des Archives",
              imageBg: "linear-gradient(135deg,#100c08,#181410)",
              imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-mairie-salle-archives.png",
              desc: "L'état-civil et les archives administratives de la ville. Poussiéreux, mais tout y est.",
              persons: [],
              orders: [
                {fn:'consulter_etat_civil', label:"Consulter l'état-civil", pa:0, cost:0, type:'legal', icon:'ti-file-search', successRate:100, desc:"Rechercher par nom ou par décennie dans le registre d'état-civil de Republia."}
              ]
            }
          }
        },
        // Dispensaire de PSM (lot du 24 aout 2026) : habillage propre a PSM sur le VRAI buildingId
        // navigable 'dispensaire-public-v' (template partage avec Montrouge, BUILDINGS
        // ['dispensaire-public-v'], inchange -- ce template porte en dur l'image et le texte EHPAD
        // de Montrouge, d'ou le besoin d'un roomOverrides complet ici, meme pattern deja utilise
        // pour commissariat-local/banque-locale/tribunal-local). persons top-level (hors
        // roomOverrides) reste le mecanisme deja en place pour la 1ere room (attente) -- Corinne
        // Titgoute (accueil) rejoint Betty Dine (infirmiere, conservee) plutot que de la
        // remplacer, meme convention que Docteur Aspirine + Anne Tibiotique a Luthecia. orders non
        // touches : soin_public/vendre_ressource_medicale restent sur la base partagee.
        'dispensaire-public-v': {
          roomOverrides: {
            attente: { imageUrl: "images/port-sainte-marie-dispensaire-accueil.png" },
            ehpad: {
              name: "Résidence des Embruns",
              desc: "EHPAD moderne de Port-Sainte-Marie avec vue sur le port de plaisance.",
              imageUrl: "images/port-sainte-marie-ehpad-residence-embruns.png"
            }
          },
          persons: [
            {name:'Corinne Titgoute (PNJ)', role:'Accueil du Dispensaire des Marins Mariannais', rel:'neutral', job:'hotesse', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-dispensaire-corinne-titgoute.png', photoPos:'50% 15%'},
            {name:'Betty Dine (PNJ)', role:'Infirmière', rel:'neutral', job:'infirmier'}
          ]
        },
        'zone-production': {
          name: "Scierie Guy Tarembois",
          desc: "Bois locaux, sciage et rabotage. Rachetee par un habitant de Montrouge, elle alimente le Chantier Naval en planches et en poutres.",
          persons: [
            {name:'Guy Tarembois (PNJ)', role:'PNJ - Proprietaire de la Scierie', rel:'neutral', job:'proprietaire', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/atelier-scierie-guy-tarembois-psm.png', photoPos:'68% 20%'}
          ],
          roomOverrides: {
            // excludeOrders (lot Scierie Guy Tarembois, 25 aout 2026, audit dedie) : masque
            // l'ordre generique herite du template partage BUILDINGS['zone-production']
            // ('Récolter' -> recolter_matiere), qui proposait du Poisson ici (republic.ville_a
            // dans MATIERES_PREMIERES_VILLE, plateau-justice-economie.js) sans aucun rapport
            // avec une scierie. Mecanisme deja existant et deja utilise ailleurs (Marche de
            // Luthecia, 21 aout 2026) -- ne touche jamais au template partage lui-meme, donc
            // aucun impact sur les autres villes utilisant 'zone-production' (Luthecia,
            // Montrouge) ni sur le systeme general recolter_matiere. La production automatique
            // de bois de la Scierie est desormais geree nationalement par le cron quotidien
            // (livrerEntrepotsQuotidien, api/cron-minuit.js) -- pas par un ordre joueur ici.
            zone_recolte: {
              name: "Atelier",
              imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/atelier-scierie-guy-tarembois-psm.png",
              excludeOrders: ['recolter_matiere'],
              // orders (lot "caisse et stock", 25 aout 2026) : fusion additive avec le template
              // partage (roomOverrides.orders, mecanisme deja existant -- voir data.js:198/247/612)
              // -- infrastructure economique propre a la Scierie (caisse + stock de matieres
              // premieres dans etat.usine, sbGetBatimentEtat('republic','ville_a','zone-production')).
              // vendre_matiere_usine est l'ordre GENERIQUE deja utilise par les 3 usines de
              // transformation (pharma/tabac-alcools/raffinerie) -- reutilise tel quel, aucun
              // nouveau handler ; seul matieresAccepteesParUsine() a ete etendu (plateau-justice-
              // economie.js) pour que ce buildingId, dans CETTE ville, accepte bois/minerai. Pas de
              // recette/production ici (l'Armoire a souvenirs fait l'objet d'un lot ulterieur).
              //
              // fabriquer_armoire_souvenirs/acheter_armoire_souvenirs (lot Armoire a souvenirs,
              // 25 aout 2026) : premier produit manufacture de la Scierie. Recette a 2 matieres
              // (2 bois + 2 minerai + 3 PA), geree par des fonctions dediees (plateau-justice-
              // economie.js) plutot que par CHAINES_PRODUCTION_USINE (qui ne supporte qu'une
              // seule matiere par chaine -- incompatibilite structurelle rapportee et contournee
              // sans modifier ce moteur existant). consulter_stock_usine (deja present) affiche
              // desormais aussi le stock de produits finis -- aucun 3e ordre de consultation
              // necessaire.
              orders: [
                {fn:'consulter_caisse_usine', label:'Consulter la caisse', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Voir le solde actuel de la caisse de la Scierie.'},
                {fn:'consulter_stock_usine', label:'Consulter le stock', pa:0, cost:0, type:'legal', icon:'ti-boxes', successRate:100, desc:'Voir les matières premières et les produits finis actuellement détenus par la Scierie.'},
                {fn:'vendre_matiere_usine', label:'Vendre des matières à l\'usine', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre à la Scierie, depuis votre inventaire, le bois ou le minerai que vous avez achetés à l\'Entrepôt Logistique.'},
                {fn:'fabriquer_armoire_souvenirs', label:'Fabriquer une Armoire à souvenirs', pa:3, cost:0, type:'legal', icon:'ti-hammer', successRate:100, desc:'Consomme 2 bois + 2 minerai du stock de la Scierie. +1 Armoire disponible à la vente.'},
                {fn:'acheter_armoire_souvenirs', label:'Acheter une Armoire à souvenirs', pa:0, cost:0, type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'390 FR. Fabriquée par la Scierie Guy Tarembois. Encombrement : 3.'}
              ]
            }
          }
        },
        'centre-affaires': {
          // Visuels propres a PSM (chantier "integration images/audio PSM", 30 aout 2026) : meme
          // mecanisme roomOverrides que Montrouge (voir plus bas dans ce fichier) sur ce meme
          // batiment partage -- uniquement imageUrl, aucune mecanique de location/presse/economie
          // touchee, aucun PNJ ajoute/modifie.
          roomOverrides: {
            hall: { imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-centre-affaires-accueil.png" },
            bureau_prestige: { imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-centre-affaires-bureau-prestige.png" },
            bureau_standard: { imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-centre-affaires-bureau-standard.png" },
            open_space:      { imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-centre-affaires-open-space.png" },
            tribune_republia: {
              imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-centre-affaires-tribune-republia.png",
              // Petites annonces (chantier "La Tribune de Republia", 31 aout 2026) : additif au
              // template partage BUILDINGS['centre-affaires'].rooms.tribune_republia (produire_fuite/
              // interview/article, inchanges) -- scope Republic uniquement (WORLD.republic.ville_a),
              // jamais narco/soviet/khalija qui partagent pourtant le meme buildingId.
              orders: [
                {fn:'deposer_petite_annonce', label:'Déposer une petite annonce', pa:1, cost:0, type:'legal', icon:'ti-ad', successRate:100, desc:"30 FR pour une parution de 3 jours dans La Tribune de Républia. Une seule annonce active à la fois."}
              ]
            }
          },
          // Annexe du Bureau National de l'Emploi, propre a PSM (voir roomsExtra,
          // plateau-navigation.js). Simple salle, pas de mecanique dediee pour l'instant.
          roomsExtra: {
            bureau_emploi_annexe: {
              name: "Bureau National de l'Emploi (Annexe)",
              imageBg: "linear-gradient(135deg,#0f1216,#161a20)",
              imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-emploi-annexe-psm.png",
              desc: "L'antenne locale du Bureau National de l'Emploi de Républia. Offres d'emploi, accompagnement, formation.",
              persons: [],
              orders: [
                {fn:'sinscrire_demandeur_emploi', label:"S'inscrire comme demandeur d'emploi", pa:1, cost:0, type:'legal', icon:'ti-user-plus', successRate:100, desc:"Ouvre l'accès aux offres du Bureau National de l'Emploi."},
                {fn:'consulter_offres_emploi', label:"Consulter les offres d'emploi", pa:0, cost:0, type:'legal', icon:'ti-list-search', successRate:100, desc:'Offres locales, nationales et internationales disponibles.'},
                {fn:'demissionner_emploi_bne', label:'Démissionner de mon emploi', pa:0, cost:0, type:'legal', icon:'ti-door-exit', successRate:100, desc:'Effet immédiat, sans coût. Libère la place pour un autre demandeur.'}
              ]
            }
          }
        },
        // Hall du Centre Commercial de PSM (complement au chantier images/audio PSM, 30 aout
        // 2026) : meme mecanisme roomOverrides que Montrouge sur ce meme batiment partage (voir
        // ville_b.buildingContext['centre-commercial'] plus bas dans ce fichier) -- uniquement
        // imageUrl sur le hall d'entree, aucune mecanique de location/economie touchee, aucun PNJ
        // ajoute/modifie. Les 4 locaux a louer (vitrine_principale/boutique_milieu/
        // arriere_boutique/cave_reserve) restent sur les visuels de la base partagee.
        'centre-commercial': {
          roomOverrides: {
            hall: { imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-centre-commercial-hall.png" }
          }
        },
        'stade': {
          name: "Stade de La Brise Mariannaise",
          desc: "Face a l'ocean. Le vent du large emporte parfois plus que les ballons.",
          persons: [
            {name:'Maurice Éhault (PNJ)', role:'Entraineur', rel:'neutral', job:'entraineur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entraineur-mariannaise-ehault.png'}
          ],
          roomOverrides: {
            terrain: { name: "Terrain — La Brise Mariannaise", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/stade-brise-mariannaise.png" },
            vestiaires: { name: "Vestiaire — La Brise Mariannaise", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/vestiaires-mariannaise.png",
              persons: [
                {name:'Thibault Gosse (PNJ)', role:'Entraineur Adjoint', rel:'neutral', job:'entraineur_adjoint', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entraineur-adjoint-mariannaise-gosse.png'}
              ]
            },
            buvette: { name: "Buvette et Magasin — La Brise Mariannaise", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/buvette-boutique-mariannaise.png" },
            guichet_paris: { name: "Guichet des Paris — La Brise Mariannaise", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/guichet-paris-mariannaise.jpeg" },
            siege_supporters: { name: "Siège des Supporters — La Brise Mariannaise", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/siege-supporters-mariannaise.png" },
            bureau_president: { name: "Bureau du Président — La Brise Mariannaise", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-president-mariannaise.png" }
          }
        },
        'hotel-republica': {
          name: "Hôtel du Port",
          desc: "Un hôtel modeste qui sent le poisson et l'iode.",
          persons: [{"name": "Raymond Ancre (PNJ)", "role": "Gérant", "rel": "neutral", "job": "serveur"}]
        },
        // NOTE (lot visuel commissariat PSM, 24 aout 2026) : cette entree 'commissariat' est du
        // code mort deja identifie par un audit anterieur -- PSM navigue reellement via le
        // buildingId 'commissariat-local' (voir buildings ci-dessus), jamais 'commissariat'
        // (reserve a Luthecia). "Inspecteur Morue (PNJ)" n'est donc JAMAIS affiche en jeu.
        // Conservee telle quelle, non modifiee, en attente d'arbitrage (voir rapport).
        'commissariat': {
          name: "Commissariat de Port-Sainte-Marie",
          desc: "Un petit commissariat de province.",
          persons: [{"name": "Inspecteur Morue (PNJ)", "role": "Inspecteur local", "rel": "neutral", "job": "commissaire"}]
        },
        // Images propres a PSM pour le VRAI buildingId navigable 'commissariat-local' (template
        // partage avec Montrouge, BUILDINGS['commissariat-local']) -- roomOverrides uniquement
        // sur imageUrl, meme pattern que Montrouge (armurerie/centre-commercial ci-dessus) :
        // ne touche jamais persons/orders de la base partagee, aucun impact sur Montrouge.
        'commissariat-local': {
          roomOverrides: {
            accueil_loc: { imageUrl: "images/port-sainte-marie-commissariat-accueil.png" },
            // Loic Karamel (PNJ), lot du 24 aout 2026 : detenu decoratif, meme precedent exact
            // que Tristan Cabane (BUILDINGS['commissariat'].prison, Luthecia) -- job:'detenu'
            // deja utilise la, aucun nouveau job cree. Purement narratif, ne remplace pas les
            // vrais detenus affiches dynamiquement (voir sbGetDetenusActifs, plateau-navigation.js).
            // Les mecaniques de detention (se_rebeller/tentative_evasion/requete_avocat)
            // fonctionnent desormais ici aussi (lot "ordres carceraux hors Luthecia", 26 aout
            // 2026) : herite les orders du template partage BUILDINGS['commissariat-local'].
            // rooms.geoles, ce roomOverride ne touchant que imageUrl/persons. PSM uniquement --
            // roomOverride scope a ville_a, Montrouge (aucun override ici) et Luthecia (batiment
            // distinct) restent inchanges.
            geoles: {
              imageUrl: "images/port-sainte-marie-commissariat-geoles.png",
              persons: [
                {name:'Loïc Karamel (PNJ)', role:'Prisonnier — Contrebandier', rel:'neutral', job:'detenu', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-commissariat-loic-karamel.png', photoPos:'50% 15%'}
              ]
            }
          },
          // Bureau du commissaire PROPRE A PSM (lot du 24 aout 2026), memes pattern/precedent que
          // salle_elections/salle_archives (mairie ci-dessus) ou bureau_emploi_annexe
          // (centre-affaires ci-dessus) : roomsExtra isole cette piece a PSM sans jamais toucher
          // BUILDINGS['commissariat-local'] (template partage avec Montrouge, inchange). orders
          // volontairement vide : mener_enquete/organiser_filature/organiser_chasse_homme sont
          // des mecaniques propres a Luthecia (bureau_commissaire de BUILDINGS['commissariat']),
          // recruter_policier/gerer_effectifs_police existent deja sur accueil_loc -- aucune
          // decision de game design prise ici sur d'eventuels ordres futurs pour ce bureau.
          roomsExtra: {
            bureau_commissaire: {
              name: "Bureau du Commissaire",
              imageBg: "linear-gradient(135deg,#0f1018,#151822)",
              imageUrl: "images/port-sainte-marie-commissariat-bureau-commissaire.png",
              desc: "Le bureau du commissaire de Port-Sainte-Marie. Vue sur le port.",
              persons: [
                {name:'Martial Morvan (PNJ)', role:'Commissaire de Port-Sainte-Marie', rel:'neutral', job:'commissaire', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-commissariat-martial-morvan.png', photoPos:'50% 20%'}
              ],
              orders: []
            }
          }
        },
        // Tribunal de PSM (lot du 24 aout 2026) : habillage propre a PSM sur le VRAI buildingId
        // navigable 'tribunal-local' (template partage avec Montrouge, BUILDINGS['tribunal-
        // local'], inchange -- roomOverride sur imageUrl/persons uniquement, meme pattern que
        // 'commissariat-local' ci-dessus). Les 3 orders (plainte/defense/rendre_sentence)
        // proviennent de la base partagee et restent strictement inchanges : aucun greffe, aucune
        // salle d'archives ajoutee -- ces services restent exclusifs a Luthecia (regle de game
        // design validee : historique judiciaire national centralise au greffe de la capitale).
        'tribunal-local': {
          roomOverrides: {
            salle_audience_locale: {
              imageUrl: "images/port-sainte-marie-tribunal-salle-audience.png",
              persons: [
                {name:'Mireille Sedlex (PNJ)', role:'Juge de Port-Sainte-Marie', rel:'neutral', job:'juge', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-tribunal-mireille-sedlex.png', photoPos:'50% 15%'}
              ]
            }
          }
        },
        // Banque de PSM (lot du 24 aout 2026) : habillage propre a PSM sur le VRAI buildingId
        // navigable 'banque-locale' (template partage avec Montrouge, BUILDINGS['banque-locale'],
        // inchange). Structure technique calquee sur 'banque-locale' de Montrouge ci-dessus
        // (roomOverrides.guichet.imageUrl + roomsExtra.bureau_directeur), contenu propre a PSM.
        // orders du guichet non touches (gerer_finances/emprunter restent sur la base partagee).
        // bureau_directeur : orders: [] volontairement, meme convention que Montrouge -- aucun
        // ordre generique existant prevu pour cette room, aucune decision de game design prise.
        // Aucune salle des coffres ajoutee : asymetrie volontaire avec Luthecia (seule ville a
        // disposer de coffre_privatif, BUILDINGS['banque-nationale']), non dupliquee ici.
        'banque-locale': {
          roomOverrides: {
            guichet: { imageUrl: "images/port-sainte-marie-banque-accueil.png" }
          },
          roomsExtra: {
            bureau_directeur: {
              name: "Bureau de Direction",
              imageBg: "linear-gradient(135deg,#0d0d08,#181808)",
              imageUrl: "images/port-sainte-marie-banque-bureau-direction.png",
              desc: "Le bureau de la directrice de l'agence. Vue sur le port.",
              persons: [
                {name:'Marie Le Roux (PNJ)', role:'Directrice de la banque de Port-Sainte-Marie', rel:'neutral', job:'directeur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-banque-marie-le-roux.png', photoPos:'50% 15%'}
              ],
              orders: []
            }
          }
        },
        'banque-nationale': {
          name: "Banque Locale de Port-Sainte-Marie",
          desc: "Une succursale modeste.",
          persons: [{"name": "Gérard Liasse (PNJ)", "role": "Directeur local", "rel": "neutral", "job": "banquier"}]
        },
        'dispensaire-public': {
          name: "Dispensaire de Port-Sainte-Marie",
          desc: "Le médecin vient deux fois par semaine.",
          persons: [{"name": "Docteur Iodé (PNJ)", "role": "Médecin itinérant", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: "Imprimerie-Librairie Gutenberg",
          desc: "Gustave Encre imprime n'importe quoi pour n'importe qui.",
          persons: [{"name": "Gustave Encre (PNJ)", "role": "Imprimeur", "rel": "neutral", "job": "journaliste"}]
        },
        'marche': {
          name: "Marché du Port",
          desc: "Poissons frais, rumeurs fraîches.",
          persons: [{"name": "Marinette Hareng (PNJ)", "role": "Poissonnière", "rel": "neutral", "job": "commercant", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marinette-hareng.png", "photoPos": "65% 35%"}]
        }
      }
    },
    ville_b: {
      name:'Montrouge',
      imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/montrouge.png',
      desc:'Ville industrielle au nord. Syndicats puissants, usines et tensions sociales.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-6','terrain-a-batir-montrouge-3','terrain-a-batir-montrouge-7','terrain-a-batir-montrouge-8','terrain-a-batir-montrouge-9','terrain-a-batir-montrouge-12','stade','zone-production','entrepot-logistique-montrouge','raffinerie-montrouge','armurerie','loge-maconnique','la-tribune','marche','cafe-gare-montrouge','brasserie-voyageurs-montrouge','musee-histoire-montrouge','eglise-montrouge','cinema-montrouge','jardins-ouvriers-montrouge','logements-montrouge','cafe-tabac-cheminots-montrouge','place-du-rail-montrouge'],
      buildingContext: {
        'stade': {
          name: "Stade Marcel Cazenave",
          desc: "Colle aux voies ferrees. Les Cheminots jouent avec la rage des quartiers ouvriers.",
          persons: [
            {name:'Jean-Philippe Hervitmonfute (PNJ)', role:'Entraineur', rel:'neutral', job:'entraineur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entraineur-montrouge-hervitmonfute.png'},
            {name:'Émilie Charbon (PNJ)', role:'Journaliste Sportive', rel:'neutral', job:'commentateur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/journaliste-montrouge-emilie-charbon.png'}
          ],
          roomOverrides: {
            terrain: { name: "Terrain — Union Cheminote de Montrouge", imageUrl: "images/montrouge/montrouge-stade-pelouse-accueil.jpg" },
            vestiaires: { name: "Vestiaire — Union Cheminote de Montrouge",
              persons: [{name:'Gérard Bricoleau (PNJ)', role:'Entraineur Adjoint', rel:'neutral', job:'entraineur_adjoint', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entraineur-adjoint-montrouge-bricoleau.png'}]
            },
            bureau_president: { name: "Bureau du Président — Union Cheminote de Montrouge", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-president-montrouge.png" }
          }
        },
        'hotel-republica': {
          name: "Hôtel des Mineurs",
          desc: "Un hôtel ouvrier. Les murs sont fins, les lits durs, la solidarité forte.",
          persons: [{"name": "Fernand Poussière (PNJ)", "role": "Gérant", "rel": "neutral", "job": "serveur"}]
        },
        'commissariat': {
          name: "Commissariat de Montrouge",
          desc: "En tension permanente avec le syndicat local.",
          persons: [{"name": "Commissaire Charbon (PNJ)", "role": "Commissaire local", "rel": "neutral", "job": "commissaire"}]
        },
        'banque-nationale': {
          name: "Banque Ouvrière de Montrouge",
          desc: "La banque des travailleurs. Prêts difficiles à obtenir.",
          persons: [{"name": "Hubert Billet (PNJ)", "role": "Directeur", "rel": "neutral", "job": "banquier"}]
        },
        'dispensaire-public': {
          name: "Dispensaire de Montrouge",
          desc: "Surpeuplé. L'attente est longue mais les soins sont gratuits.",
          persons: [{"name": "Docteur Silicose (PNJ)", "role": "Médecin du travail", "rel": "neutral", "job": "medecin"}]
        },
        // Images interieures (17 aout 2026, finition spatiale) : roomOverrides couvre les 2
        // rooms deja existantes (accueil_tribune/redaction, partagees avec La Tribune de
        // Republia a Luthecia -- seule l'image change ici, PNJ/ordres de la base restent
        // intacts, roomOverrides.imageUrl ne touche jamais persons/orders). roomsExtra ajoute
        // une 3e piece "Imprimerie" PROPRE A MONTROUGE (jamais ajoutee a Luthecia) -- vide de
        // PNJ/ordres, purement spatiale comme demande (aucune mecanique inventee ; Gustave
        // Rotative, deja "Chef d'atelier - imprimeur" dans accueil_tribune cote base, n'est pas
        // deplace : necessiterait de toucher au contenu existant, hors perimetre de ce lot).
        'la-tribune': {
          name: "Le Cheminot Informé (LCI)",
          desc: "Le journal syndical de Montrouge.",
          persons: [{"name": "Rédacteur Calame (PNJ)", "role": "Rédacteur en chef", "rel": "neutral", "job": "journaliste"}],
          roomOverrides: {
            accueil_tribune: { imageUrl: "images/montrouge/montrouge-lci-accueil.jpg" },
            redaction:       { imageUrl: "images/montrouge/montrouge-lci-redaction.jpg" }
          },
          roomsExtra: {
            // Tracts calomnieux (24 aout 2026) : ajoute dans cette room (deja creee, jusqu'ici
            // purement spatiale/vide) -- meme handler generique imprimer_tracts_calomnieux que
            // Luthecia (accueil_tribune) et PSM (atelier), aucune mecanique dupliquee. Room
            // roomsExtra propre a Montrouge (ville_b) uniquement : aucune propagation vers
            // Luthecia ni vers un autre empire partageant 'la-tribune'.
            imprimerie: {
              name: "Imprimerie / Reprographie",
              imageBg: "linear-gradient(135deg,#100808,#1c0c0c)",
              desc: "L'atelier d'impression du journal. Odeur d'encre et de papier.",
              imageUrl: "images/montrouge/montrouge-lci-imprimerie.jpg",
              persons: [],
              orders: [
                {fn:'imprimer_tracts_calomnieux', label:'Imprimer des tracts calomnieux', pa:1, cost:0, type:'illegal', icon:'ti-eye-off', successRate:100, desc:'Choisir une cible (répertoire). Campagne mensongère clandestine. Produit un lot de 10 tracts calomnieux. Coût : 1 PA + bois en stock personnel.'}
              ]
            }
          }
        },
        'marche': {
          name: "Marché de Montrouge",
          desc: "Légumes pas chers, grèves annoncées à voix haute.",
          persons: [{"name": "Josette Betterave (PNJ)", "role": "Marchande", "rel": "neutral", "job": "commercant"}],
          // Image de navigation interieure (distincte de la vue de rue 13, montrouge-place-marche-tabac-cafe.jpg,
          // qui n'est pas touchee). Le nom du fichier dit "exterieur" car la scene represente un marche en
          // plein air, mais c'est bien l'image affichee APRES entree dans le batiment.
          roomOverrides: {
            marche_ext: {
              imageUrl: "images/montrouge/montrouge-marche-exterieur.jpg",
              // Lot 5A -- Faire des achats (24 aout 2026) : Montrouge n'avait jusqu'ici AUCUN
              // bouton commerce (seul le template partage BUILDINGS['marche'] s'appliquait --
              // se_nourrir/pouls_populaire/distribuer_tract/lancer_rumeur_cible). Meme structure
              // que le roomOverride de Luthecia (excludeOrders + orders additifs) : se_nourrir
              // masque au profit du commerce, produire_commerce/faire_achats_marche/
              // vendre_matiere_commerce ajoutes a l'identique.
              excludeOrders: ['se_nourrir'],
              orders: [
                {fn:'produire_commerce', label:'Produire les articles du marché', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Produire les articles en vente au marché (consomme les matières en stock, rémunéré en FR).'},
                {fn:'faire_achats_marche', label:'Faire des achats', pa:0, cost:0, type:'legal', icon:'ti-shopping-bag', successRate:100, desc:'Nourriture à emporter, souvenir local, cartes postales.'},
                {fn:'vendre_matiere_commerce', label:'Vendre des matières au marché', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les matières premières de votre inventaire à ce marché.'}
              ]
            }
          }
        },

        // ---- Correctif de nomenclature (2026-08-16) : le nom affiche au joueur doit
        // correspondre au libelle valide sur les 13 vues urbaines. Overrides minimaux
        // (nom uniquement), aucune mecanique/PNJ/desc ajoutee pour ce lot. Les buildingId
        // techniques ne sont pas touches.
        'hotel-mineur':                 { name: "Hôtel de la Victoire" },
        'armurerie':                    { name: "Armurerie-Quincaillerie de Montrouge", roomOverrides: { magasin: { imageUrl: "images/montrouge/montrouge-armurerie-interieur.jpg" } } },
        'commissariat-local':           { name: "Commissariat de Montrouge" },
        'raffinerie-montrouge':         { name: "Raffinerie de Montrouge" },
        'centre-multinodal-montrouge':  { name: "Gare de Montrouge" },
        'entrepot-logistique-montrouge':{ name: "Entrepôt logistique de Montrouge" },
        'dispensaire-public-v':         { name: "Hôpital de Montrouge", persons: [{name:'Agnès Thésie (PNJ)', role:'Infirmière', rel:'neutral', job:'infirmier'}] },
        'centre-commercial':            { name: "Centre commercial de Montrouge", roomOverrides: { hall: { imageUrl: "images/montrouge/montrouge-centre-commercial-hall.jpg" } } },
        // Le BNE de Montrouge est une annexe du Centre d'Affaires, sur le meme modele que
        // PSM (ville_a.buildingContext['centre-affaires'].roomsExtra.bureau_emploi_annexe) :
        // memes 3 ordres generiques (aucune mecanique/PNJ invente), image propre a Montrouge.
        // L'ancien batiment autonome 'bureau-national-emploi-montrouge' est retire (voir plus
        // bas) : verifie sans autre reference dans tout le depot avant suppression.
        'centre-affaires': {
          name: "Centre d'affaires de Montrouge",
          // Images d'interieur (2026-08-16) : reutilise integralement les 3 categories de
          // bureaux a louer deja definies au niveau generique (BUILDINGS['centre-affaires'] :
          // bureau_prestige/bureau_standard/open_space), meme mecanique de location que PSM.
          // Correspondance retenue par ordre de gamme : grand=Prestige(1000FR/tier1),
          // moyen=Standard(500FR/tier2), petit=Open Space(200FR/tier3, "espace partage").
          roomOverrides: {
            // 2026-08-16 : versions corrigees des images (remplacent les anciens .png,
            // supprimes du depot). hall recoit en plus une liste de personnes propre a
            // Montrouge (persons ci-dessous) : le batiment 'centre-affaires' est partage
            // avec Luthecia/PSM, qui affichent toujours le trio generique (Gretta/Moshe/
            // Harry) du template BUILDINGS['centre-affaires'].rooms.hall -- inchange, non
            // touche, pour ne pas les modifier ailleurs.
            hall: {
              imageUrl: "images/montrouge/montrouge-centre-affaires-accueil.jpg",
              persons: [
                {name:'Gretta Délieu (PNJ)', role:'PNJ - Accueil', rel:'neutral', job:'hotesse', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-centre-affaires-luthecia.png', photoPos:'38% 45%'},
                {name:'Moshe Maychan (PNJ)', role:'PNJ', rel:'neutral', job:'criminel'},
                {name:'Harry Cover (PNJ)', role:'PNJ', rel:'neutral', job:'inspecteur'}
              ]
            },
            bureau_prestige: { imageUrl: "images/montrouge/montrouge-centre-affaires-grand-bureau.jpg" },
            bureau_standard: { imageUrl: "images/montrouge/montrouge-centre-affaires-moyen-bureau.jpg" },
            open_space:      { imageUrl: "images/montrouge/montrouge-centre-affaires-petit-bureau.jpg" },
            // Antenne locale de La Tribune de Republia (pas L'Autruche Entravee, un autre
            // journal) : image seule, aucune salle/ordre/PNJ ajoute, roomId deja existant
            // et unique dans tout le depot (seul le template generique le definit).
            tribune_republia: {
              imageUrl: "images/montrouge/tribune-redaction.jpg",
              // Petites annonces (chantier "La Tribune de Republia", 31 aout 2026) : meme ajout
              // additif que PSM ci-dessus (WORLD.republic.ville_b), meme raison.
              orders: [
                {fn:'deposer_petite_annonce', label:'Déposer une petite annonce', pa:1, cost:0, type:'legal', icon:'ti-ad', successRate:100, desc:"30 FR pour une parution de 3 jours dans La Tribune de Républia. Une seule annonce active à la fois."}
              ]
            }
          },
          roomsExtra: {
            bureau_emploi_annexe: {
              name: "Bureau National de l'Emploi (Annexe)",
              imageBg: "linear-gradient(135deg,#0f1216,#161a20)",
              imageUrl: "images/montrouge/montrouge-bne-accueil.jpg",
              desc: "L'antenne locale du Bureau National de l'Emploi de Républia. Offres d'emploi, accompagnement, formation.",
              persons: [],
              orders: [
                {fn:'sinscrire_demandeur_emploi', label:"S'inscrire comme demandeur d'emploi", pa:1, cost:0, type:'legal', icon:'ti-user-plus', successRate:100, desc:"Ouvre l'accès aux offres du Bureau National de l'Emploi."},
                {fn:'consulter_offres_emploi', label:"Consulter les offres d'emploi", pa:0, cost:0, type:'legal', icon:'ti-list-search', successRate:100, desc:'Offres locales, nationales et internationales disponibles.'},
                {fn:'demissionner_emploi_bne', label:'Démissionner de mon emploi', pa:0, cost:0, type:'legal', icon:'ti-door-exit', successRate:100, desc:'Effet immédiat, sans coût. Libère la place pour un autre demandeur.'}
              ]
            }
          }
        },
        // 2026-08-16 : accueil + bureau du maire raccordes. Salle des elections + archives
        // ajoutees via roomsExtra (BUILDINGS['mairie'] ne les definit pas -- seule
        // 'mairie-capitale', batiment distinct exclusif a Luthecia, les a). Audit prealable
        // du systeme electoral municipal (CYCLES_ELECTORAUX / cle = posteId+'_'+city / colonne
        // city sur votes_electoraux+candidatures+cycles_electoraux, cote client ET cron
        // api/cron-minuit.js VILLES_CASCADE) : deja correctement scope par ville partout,
        // aucune collision Luthecia/PSM/Montrouge trouvee -- aucun correctif necessaire.
        'mairie': {
          name: "Hôtel de Ville de Montrouge",
          roomOverrides: {
            accueil_mairie:      { imageUrl: "images/montrouge/montrouge-mairie-accueil.jpg" },
            bureau_maire_local:  { imageUrl: "images/montrouge/montrouge-mairie-bureau-maire.jpg" },
            // Logements sociaux (18 aout 2026, corrige suite a decision game design : les deux
            // demarches se font depuis CETTE room existante, jamais une nouvelle piece dediee).
            // 'orders' ici est fusionne par renderRoomActions() (plateau-politique.js) avec les
            // ordres de base de bureau_maire_adjoint (voir extension apportee a cette fonction),
            // exactement comme roomOverrides gere deja name/imageUrl/persons par ville -- jamais
            // ajoute au tableau orders de BUILDINGS['mairie'] lui-meme (base partagee par
            // plusieurs villes, ex. PSM/ville_a), pour ne jamais apparaitre ailleurs qu'a Montrouge.
            bureau_maire_adjoint:{
              imageUrl: "images/montrouge/montrouge-mairie-bureau-maire-adjoint.jpg",
              orders: [
                {fn:'demander_logement_social', label:'Déposer une demande de logement social', pa:1, cost:0, type:'legal', icon:'ti-home-plus', successRate:100, desc:"Réservé aux résidents officiels de Montrouge (domicile officiel). L'attribution est décidée par l'adjoint au maire — jamais automatique."},
                {fn:'traiter_demandes_logement_social', label:'Examiner les demandes de logement social', pa:1, cost:0, type:'legal', icon:'ti-home-check', successRate:100, requiresPost:'maire_adjoint', desc:'Voir les demandes en attente, l\'état des 4 logements, et attribuer un logement libre à un bénéficiaire.'}
              ]
            }
          },
          roomsExtra: {
            salle_elections: {
              name: "Salle des Élections",
              imageBg: "linear-gradient(135deg,#0f1810,#142014)",
              desc: "La salle où sont gérés les scrutins et candidatures officielles de la ville.",
              imageUrl: "images/montrouge/montrouge-mairie-salle-elections.jpg",
              persons: [
                {name:'Responsable Electoral (PNJ)', role:'PNJ - Commission electorale', rel:'neutral', job:'responsable_election'}
              ],
              orders: [
                {fn:'consulter_elections',  label:'Voir les candidats',         pa:0, cost:0,    type:'legal',   icon:'ti-list',          successRate:100, desc:'Liste des candidats declares et sondages.'},
                {fn:'contester_resultats',  label:'Contester des resultats',    pa:3, cost:200,  type:'legal',   icon:'ti-alert-triangle',successRate:40,  desc:'Contester le resultat d\'une election. Long processus.'},
                {fn:'falsifier_docs',       label:'Falsifier une liste',        pa:3, cost:500,  type:'illegal', icon:'ti-file-x',        successRate:35,  desc:'Manipuler les listes electorales. Tres risque.'}
              ]
            },
            // Archives : consulter_mandats_maires volontairement EXCLU (contenu reel mais
            // fige sur Luthecia : ENIGME1_REGISTRE_MANDATS + texte en dur "Maire de Luthecia"
            // dans plateau-enigme-portrait.js -- l'inclure aurait affiche les archives de
            // Luthecia dans la mairie de Montrouge). consulter_etat_civil conserve : registre
            // national ("Republia"), non lie a une ville, verifie sans dependance a Luthecia.
            salle_archives: {
              name: "Salle des Archives",
              imageBg: "linear-gradient(135deg,#100c08,#181410)",
              desc: "L'état-civil et les archives administratives de la ville. Poussiéreux, mais tout y est.",
              imageUrl: "images/montrouge/montrouge-mairie-archives.jpg",
              persons: [
                {name:'Archiviste Municipal (PNJ)', role:'PNJ - Archives', rel:'neutral', job:'archiviste'}
              ],
              orders: [
                {fn:'consulter_etat_civil', label:"Consulter l'état-civil", pa:0, cost:0, type:'legal', icon:'ti-file-search', successRate:100, desc:"Rechercher par nom ou par décennie dans le registre d'état-civil de Republia."}
              ]
            }
          }
        },
        // Images d'interieur (18 aout 2026, suite du chantier images Montrouge) : roomOverrides
        // couvre les rooms deja existantes (image seule, jamais persons/orders/mecanique).
        // banque-locale recoit en plus une room roomsExtra "bureau_directeur" -- purement
        // spatiale/visuelle (aucun ordre, aucun PNJ, aucune mecanique bancaire), meme principe
        // deja etabli que 'imprimerie' (la-tribune) ou 'salle_elections'/'salle_archives'
        // (mairie) ci-dessus. L'override mort 'banque-nationale' (ligne 355, jamais atteignable
        // car absent de la liste "buildings" de Montrouge) est laisse tel quel, hors perimetre.
        'banque-locale': {
          name: "Banque Cheminote de Montrouge",
          roomOverrides: {
            guichet: { imageUrl: "images/montrouge/montrouge-banque-accueil.jpg" }
          },
          roomsExtra: {
            bureau_directeur: {
              name: "Bureau du Directeur",
              imageBg: "linear-gradient(135deg,#0d0d08,#181808)",
              desc: "Le bureau du directeur de l'agence. Porte capitonnee, silence feutre.",
              imageUrl: "images/montrouge/montrouge-banque-bureau-directeur.jpg",
              persons: [],
              orders: []
            }
          }
        },
        // Tribunal de Montrouge (lot du 24 aout 2026) : habillage propre a Montrouge sur le VRAI
        // buildingId navigable 'tribunal-local' (template partage avec PSM, BUILDINGS['tribunal-
        // local'], inchange -- roomOverride sur imageUrl/persons uniquement, meme pattern que
        // 'banque-locale' ci-dessus). Les 3 orders (plainte/defense/rendre_sentence) proviennent
        // de la base partagee et restent strictement inchanges : aucun greffe, aucune salle
        // d'archives ajoutee -- ces services restent exclusifs a Luthecia.
        'tribunal-local': {
          roomOverrides: {
            salle_audience_locale: {
              imageUrl: "images/montrouge/montrouge-tribunal-salle-audience.png",
              persons: [
                {name:'Gérard Bretellewood (PNJ)', role:'Juge de Montrouge', rel:'neutral', job:'juge', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/montrouge/montrouge-tribunal-gerard-bretellewood.png', photoPos:'50% 15%'}
              ]
            }
          }
        },
        'loge-maconnique': {
          name: "Loge maçonnique de Montrouge",
          roomOverrides: {
            hall_loge:          { imageUrl: "images/montrouge/montrouge-loge-entree.jpg" },
            salle_reunion_loge: { imageUrl: "images/montrouge/montrouge-loge-salle-reunion.jpg" }
          }
        },
        // Correspondance par tier (18 aout 2026), meme logique deja validee pour centre-affaires
        // ci-dessus (grand=tier1/moyen=tier2/petit=tier3) : echoppe_facade (tier:1, 600FR/jour,
        // +12 POP) = grand, atelier_milieu (tier:2, 300FR/jour, +6 POP) = moyen, reserve_arriere
        // (tier:3, 100FR/jour, +2 POP) = petit. Aucun numero de box ni surface n'existe dans le
        // code (verifie) -- les mentions "Box n°X" / m² visibles sur les images sont du seul
        // decor graphique, jamais reproduites en donnees. Loyers/POP/tiers/ordres inchanges.
        'centre-artisanal': {
          name: "Centre artisanal de Montrouge",
          roomOverrides: {
            travees:         { imageUrl: "images/montrouge/montrouge-centre-artisanal-accueil.jpg" },
            echoppe_facade:  { imageUrl: "images/montrouge/montrouge-centre-artisanal-box-grand.jpg" },
            atelier_milieu:  { imageUrl: "images/montrouge/montrouge-centre-artisanal-box-moyen.jpg" },
            reserve_arriere: { imageUrl: "images/montrouge/montrouge-centre-artisanal-box-petit.jpg" }
          }
        },
        'terrain-a-batir-6':            { name: "Terrains à vendre" }
      }
    },
    caserne: {
      name:'Caserne Militaire de Republia',
      imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/caserne-luthecia-exterieur.png',
      desc:'La caserne principale de l\'armee de Republia.',
      isCapitale: false, isSpecial: true, travelCost: 1,
      buildings: ['caserne-militaire']
    },
    qhs: {
      name:'Quartier Haute Securite',
      imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/qhs-luthecia-exterieur.png',
      desc:'La prison de haute securite de Republia.',
      isCapitale: false, isSpecial: true, travelCost: 1,
      buildings: ['qhs-prison']
    }
  },

    narco: {
    capitale: {
      name:'Ciudad Roja',
      streetName: 'Avenida del Generalissimo',
      imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-el-estado.png',
      desc:'Capitale d\'El Estado. Chaleur étouffante, corruption omniprésente, Generalissimo Gordito règne sans partage.',
      isCapitale: true,
      buildings: ['palais-presidentiel','hotel-republica','palais-gouvernement','assemblee','tribunal','banque-nationale','banque-privee','clinique-privee','dispensaire-public','commissariat','la-tribune','loge-maconnique','universite','armurerie','marche','mairie-capitale','laboratoire-priere','centre-multinodal-luthecia','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-1','terrain-a-batir-4','terrain-a-batir-5','terrain-a-batir-6','terrain-a-batir-7','office-notarial','stade'],
      buildingContext: {
        'hotel-republica': {
          name: "Hôtel El Cartel",
          desc: "Le seul hôtel potable de Ciudad Roja. Les murs ont des oreilles.",
          persons: [{"name": "Pedro Tequila (PNJ)", "role": "Barman", "rel": "neutral", "job": "serveur"}, {"name": "Lupe Cantina (PNJ)", "role": "Serveuse armée", "rel": "neutral", "job": "serveur"}, {"name": "Lola Discreta (PNJ)", "role": "Informatrice double jeu", "rel": "neutral", "job": "escort"}]
        },
        'commissariat': {
          name: "Comisaria Central",
          desc: "La police d'El Estado. Corruptible mais imprévisible.",
          persons: [{"name": "El Capitan Gordo (PNJ)", "role": "Capitaine", "rel": "neutral", "job": "commissaire"}, {"name": "Consuela Silencio (PNJ)", "role": "Inspectrice", "rel": "neutral", "job": "inspecteur"}]
        },
        'tribunal': {
          name: 'Tribunal de Ciudad Roja',
          desc: "Les verdicts s'achètent au kilo.",
          persons: [{"name": "El Juez Manchado (PNJ)", "role": "Juge en chef", "rel": "neutral", "job": "juge"}, {"name": "Abogado Turbio (PNJ)", "role": "Avocat véreux", "rel": "neutral", "job": "avocat"}]
        },
        'banque-nationale': {
          name: 'Banco Nacional del Estado',
          desc: "Les billets sentent parfois le carburant d'avion.",
          persons: [{"name": "Don Billete (PNJ)", "role": "Directeur", "rel": "neutral", "job": "banquier"}, {"name": "Rosita Cuenta (PNJ)", "role": "Caissière", "rel": "neutral", "job": "caissier"}]
        },
        'banque-privee': {
          name: 'Banco Privado Offshore',
          desc: "Aucune question posée.",
          persons: [{"name": "Señor Offshore (PNJ)", "role": "Directeur", "rel": "neutral", "job": "banquier"}]
        },
        'clinique-privee': {
          name: 'Clínica Privada',
          desc: "Doctor Silencioso ne remplit aucun rapport.",
          persons: [{"name": "Doctor Silencioso (PNJ)", "role": "Médecin", "rel": "neutral", "job": "medecin"}]
        },
        'dispensaire-public': {
          name: 'Dispensario Popular',
          desc: "Bondé. Les médicaments manquent depuis six mois.",
          persons: [{"name": "Enfermera Esperanza (PNJ)", "role": "Infirmière", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: 'El Narco Times',
          desc: "Toutes les nouvelles qui méritent d'être blanchies.",
          persons: [{"name": "El Editor (PNJ)", "role": "Rédacteur en chef", "rel": "neutral", "job": "journaliste"}, {"name": "Periodista Miedo (PNJ)", "role": "Journaliste", "rel": "neutral", "job": "journaliste"}]
        },
        'loge-maconnique': {
          requiresMembership: 'loge',
          name: 'Club de los Elegidos',
          desc: "Membres non divulgués. Meetings non confirmés.",
          persons: [{"name": "El Gran Maestro (PNJ)", "role": "Grand Maître", "rel": "neutral", "job": "loge"}]
        },
        'universite': {
          name: 'Universidad del Partido',
          desc: "Le programme change selon les humeurs du Generalissimo.",
          persons: [{"name": "Profesor Obediente (PNJ)", "role": "Doyen", "rel": "neutral", "job": "professeur"}]
        },
        'armurerie': {
          name: 'Armería Gordito',
          desc: "L'armurerie officielle. Et non officielle. Les deux.",
          persons: [{"name": "Paco Gatillo (PNJ)", "role": "Armurier", "rel": "neutral", "job": "commercant"}]
        },
        'marche': {
          name: 'Mercado Central',
          desc: "Tout se vend ici, absolument tout.",
          persons: [{"name": "Maria Mercado (PNJ)", "role": "Marchande", "rel": "neutral", "job": "commercant"}, {"name": "Carlos Regateo (PNJ)", "role": "Marchand", "rel": "neutral", "job": "commercant"}],
          orders: [
            {fn:'marche_noir', label:'Marché Noir', pa:1, cost:0, type:'illegal', icon:'ti-alert-triangle', successRate:100, desc:'Explosifs et le poison local de Carlos. Rien de tout cela n\'est enregistré.'}
          ]
        },
        'palais-presidentiel': {
          name: 'Casa del Generalissimo',
          desc: 'La résidence du Don. On entre par invitation uniquement. Les non-invités ne ressortent pas toujours.',
          persons: []
        },
        'palais-gouvernement': {
          name: 'Palacio del Gobierno',
          desc: 'Le palais du gouvernement d\'El Estado. El Don surveille tout depuis son portrait au mur.',
          persons: []
        },
        'assemblee': {
          name: 'Asamblea Nacional',
          desc: 'L\'assemblée nationale. La voluntad divina es ley. Les débats sont courts.',
          persons: []
        },
        'mairie-capitale': {
          name: 'Alcaldia de Ciudad Roja',
          desc: 'La mairie. Bureau des permis d\'or, taxe de fidélité, service des secrets sur demande.',
          persons: []
        },
                'centre-multinodal-luthecia': {
          name: "Hall Principal",
          desc: "Taxis dorés, bus dorés, Trans-Gold Express. Carlos Retraso annonce des horaires purement décoratifs. Juanita Soborno surveille les entrées.",
          persons: [{"name": "Carlos Retraso (PNJ)", "role": "Chef de gare", "rel": "neutral", "job": "chef_gare"}, {"name": "Juanita Soborno (PNJ)", "role": "Agente de sécurité", "rel": "neutral", "job": "securite"}],
          rooms: {
          'hall_gare': {
            name: "Hall Principal — Terminal El Estado",
            desc: "Taxis dorés, bus dorés, Trans-Gold Express. Carlos Retraso annonce des horaires purement décoratifs. Juanita Soborno surveille les entrées.",
            persons: [{"name": "Carlos Retraso (PNJ)", "role": "Chef de gare", "rel": "neutral", "job": "chef_gare"}, {"name": "Juanita Soborno (PNJ)", "role": "Agente de sécurité", "rel": "neutral", "job": "securite"}]
          },
          'hall_douanes': {
            name: "Control de Fidelidad",
            desc: "Le contrôle douanier d\\'El Estado. Juanita Soborno vous sourit. Tout s\\'arrange avec un billet.",
            persons: [{"name": "Juanita Soborno (PNJ)", "role": "Agente des douanes", "rel": "neutral", "job": "douanier"}]
          },
          'zone_embarquement': {
            name: "Zona de Embarque",
            desc: "La zone d\\'embarquement. Vols vers les 4 empires. El Don te observe depuis l\\'affiche.",
            persons: []
          }
          }
        },        'commissariat': {
          name: "Puesto de Policía",
          desc: "Fermé le vendredi après-midi.",
          persons: [{"name": "Sargento Siesta (PNJ)", "role": "Sergent", "rel": "neutral", "job": "commissaire"}]
        },
        'banque-nationale': {
          name: "Sucursal Bancaria",
          desc: "Les fonds disparaissent parfois.",
          persons: [{"name": "Cajero Nervioso (PNJ)", "role": "Caissier", "rel": "neutral", "job": "banquier"}]
        },
        'dispensaire-public': {
          name: "Puesto Médico",
          desc: "Aspirine uniquement.",
          persons: [{"name": "Médico Rural (PNJ)", "role": "Médecin", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: "Imprenta Local",
          desc: "Tracts politiques et menus de restaurant.",
          persons: [{"name": "Impresor Manchado (PNJ)", "role": "Imprimeur", "rel": "neutral", "job": "journaliste"}]
        },
        'marche': {
          name: "Mercado del Puerto",
          desc: "Poissons et contrebande.",
          persons: [{"name": "Pescadora Carmen (PNJ)", "role": "Poissonnière", "rel": "neutral", "job": "commercant"}]
        }
      }
    },
    ville_a: {
      name:'Frontera Alta',
      imageUrl:'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=1200&q=80',
      desc:'Poste-frontiere perche dans les montagnes. Contrebande, douaniers corruptibles et sentiers connus des seuls inities.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-3','stade','zone-production'],
      buildingContext: {
        'hotel-republica': {
          name: "Posada de la Frontera",
          desc: "Une auberge de passage. On y dort peu, on y ecoute beaucoup.",
          persons: [{"name": "Posadero Silencioso (PNJ)", "role": "Gérant", "rel": "neutral", "job": "serveur"}]
        },
        'commissariat': {
          name: "Puesto Fronterizo",
          desc: "Les douaniers regardent ailleurs contre un billet.",
          persons: [{"name": "Cabo Vista Larga (PNJ)", "role": "Chef de poste", "rel": "neutral", "job": "commissaire"}]
        },
        'banque-nationale': {
          name: "Caja de Cambio",
          desc: "Change toutes les devises, sans poser de questions.",
          persons: [{"name": "Cambista Discreto (PNJ)", "role": "Changeur", "rel": "neutral", "job": "banquier"}]
        },
        'dispensaire-public': {
          name: "Clinica de Montana",
          desc: "L'altitude rend tout plus difficile, meme soigner.",
          persons: [{"name": "Medico de Altura (PNJ)", "role": "Médecin", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: "Radio Contrabando",
          desc: "Emet depuis un camion. Change de frequence chaque semaine.",
          persons: [{"name": "Locutor Fantasma (PNJ)", "role": "Animateur", "rel": "neutral", "job": "journaliste"}]
        },
        'marche': {
          name: "Mercado de Contrabando",
          desc: "Tout ce qui ne passe pas la frontiere legalement finit ici.",
          persons: [{"name": "Vendedora de Paso (PNJ)", "role": "Marchande", "rel": "neutral", "job": "commercant"}]
        }
      }
    },
    ville_b: {
      name:'La Selva',
      imageUrl:'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=1200&q=80',
      desc:'Ville de la jungle. Les laboratoires s\'étendent à perte de vue.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-2','stade','zone-production'],
      buildingContext: {
        'hotel-republica': {
          name: "Refugio de la Selva",
          desc: "Un refuge dans la jungle. Moustiques inclus.",
          persons: [{"name": "Jefe Selva (PNJ)", "role": "Gérant", "rel": "neutral", "job": "serveur"}]
        },
        'commissariat': {
          name: "Control Militar",
          desc: "Pas vraiment une police.",
          persons: [{"name": "Teniente Bruto (PNJ)", "role": "Lieutenant", "rel": "neutral", "job": "commissaire"}]
        },
        'banque-nationale': {
          name: "Caja Rural",
          desc: "Espèces uniquement.",
          persons: [{"name": "Tesorero Local (PNJ)", "role": "Trésorier", "rel": "neutral", "job": "banquier"}]
        },
        'dispensaire-public': {
          name: "Clínica de Campaña",
          desc: "Compétences variables.",
          persons: [{"name": "Curandero (PNJ)", "role": "Guérisseur", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: "Hoja Clandestina",
          desc: "Distribué de main en main.",
          persons: [{"name": "Redactor Anónimo (PNJ)", "role": "Rédacteur", "rel": "neutral", "job": "journaliste"}]
        },
        'marche': {
          name: "Tianguis de la Selva",
          desc: "Produits locaux et exotiques.",
          persons: [{"name": "Vendedor Selva (PNJ)", "role": "Vendeur", "rel": "neutral", "job": "commercant"}]
        }
      }
    },
    caserne: {
      name:'Cuartel General',
      imageUrl:'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=1200&q=80',
      desc:'La caserne militaire d\'El Estado.',
      isCapitale: false, isSpecial: true, travelCost: 1,
      buildings: ['caserne-militaire']
    },
    qhs: {
      name:'Prison Central',
      imageUrl:'https://images.unsplash.com/photo-1562564055-71e051d33c19?w=1200&q=80',
      desc:'La prison centrale d\'El Estado.',
      isCapitale: false, isSpecial: true, travelCost: 1,
      buildings: ['qhs-prison']
    }
  },

  soviet: {
    capitale: {
      name:'Novomirsk',
      streetName: 'Prospekt du Peuple',
      imageUrl:'https://images.unsplash.com/photo-1513326738677-b964603b136d?w=1200&q=80',
      desc:'Capitale de Sovarka. Gris acier, blocs soviétiques, surveillance permanente. Le Parti voit tout.',
      isCapitale: true,
      empireName: 'Sovarka',
      buildings: ['palais-presidentiel','hotel-republica','palais-gouvernement','assemblee','tribunal','banque-nationale','banque-privee','clinique-privee','dispensaire-public','commissariat','la-tribune','loge-maconnique','universite','armurerie','marche','mairie-capitale','kolkhoze-spirituel','centre-multinodal-luthecia','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-1','terrain-a-batir-4','terrain-a-batir-5','terrain-a-batir-6','terrain-a-batir-7','office-notarial','stade'],
      buildingContext: {
        'hotel-republica': {
          name: "Hôtel Kollektiv",
          desc: "Toutes les chambres sont identiques. Olga Soupe gère la cantine avec efficacité soviétique.",
          persons: [{"name": "Olga Soupe (PNJ)", "role": "Cantinière", "rel": "neutral", "job": "serveur"}, {"name": "Boris Betterave (PNJ)", "role": "Cuisinier", "rel": "neutral", "job": "serveur"}, {"name": "Natasha Privilege (PNJ)", "role": "Réservée aux cadres du Parti", "rel": "neutral", "job": "escort"}]
        },
        'commissariat': {
          name: "Commissariat du Peuple",
          desc: "Nadejda Formulaire remplit des rapports en triple exemplaire pour chaque incident.",
          persons: [{"name": "Camarade Borodine (PNJ)", "role": "Commissaire du Peuple", "rel": "neutral", "job": "commissaire"}, {"name": "Nadejda Formulaire (PNJ)", "role": "Secrétaire", "rel": "neutral", "job": "inspecteur"}]
        },
        'tribunal': {
          name: 'Tribunal Populaire',
          desc: "Les verdicts sont décidés avant l'audience.",
          persons: [{"name": "Camarade Juge Pravdine (PNJ)", "role": "Juge Populaire", "rel": "neutral", "job": "juge"}, {"name": "Défenseur Collectif (PNJ)", "role": "Avocat du Peuple", "rel": "neutral", "job": "avocat"}]
        },
        'banque-nationale': {
          name: 'Banque d\'État de Sovarka',
          desc: "Tout appartient à l'État, y compris votre argent.",
          persons: [{"name": "Camarade Ruble (PNJ)", "role": "Directeur", "rel": "neutral", "job": "banquier"}, {"name": "Natasha Compte (PNJ)", "role": "Caissière", "rel": "neutral", "job": "caissier"}]
        },
        'banque-privee': {
          name: 'Caisse Collective Spéciale',
          desc: "Officiellement pour les cadres du Parti.",
          persons: [{"name": "Camarade Privilège (PNJ)", "role": "Directeur", "rel": "neutral", "job": "banquier"}]
        },
        'clinique-privee': {
          name: 'Clinique du Parti',
          desc: "Réservée aux membres du Parti. Docteur Stakhanov soigne selon le rang.",
          persons: [{"name": "Docteur Stakhanov (PNJ)", "role": "Médecin du Parti", "rel": "neutral", "job": "medecin"}]
        },
        'dispensaire-public': {
          name: 'Dispensaire Populaire',
          desc: "Longues files d'attente. Aspirine et bonne volonté.",
          persons: [{"name": "Infirmière Stoïque (PNJ)", "role": "Infirmière", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: 'La Pravdovka',
          desc: "L'organe de vérité du Parti, vérifié trois fois.",
          persons: [{"name": "Rédacteur Vérité (PNJ)", "role": "Rédacteur en chef", "rel": "neutral", "job": "journaliste"}, {"name": "Correspondant Parti (PNJ)", "role": "Journaliste", "rel": "neutral", "job": "journaliste"}]
        },
        'loge-maconnique': {
          requiresMembership: 'loge',
          name: 'Cercle des Camarades',
          desc: "Officiellement un club de lecture. En réalité, le vrai pouvoir de Sovarka.",
          persons: [{"name": "Camarade Grand Maître (PNJ)", "role": "Président du Cercle", "rel": "neutral", "job": "loge"}]
        },
        'universite': {
          name: 'Université du Parti',
          desc: "Professeur Dialectique enseigne le marxisme-léninisme avec enthousiasme.",
          persons: [{"name": "Professeur Dialectique (PNJ)", "role": "Doyen", "rel": "neutral", "job": "professeur"}, {"name": "Assistante Propagande (PNJ)", "role": "Assistante", "rel": "neutral", "job": "professeur"}]
        },
        'armurerie': {
          name: 'Arsenal Collectif',
          desc: "Les armes appartiennent au Peuple. Accès sur autorisation du Parti.",
          persons: [{"name": "Camarade Kalachnikov (PNJ)", "role": "Responsable Arsenal", "rel": "neutral", "job": "commercant"}],
          orders: [
            {fn:'marche_noir', label:'Marché Noir', pa:1, cost:0, type:'illegal', icon:'ti-alert-triangle', successRate:100, desc:'Explosifs et le poison local de Camarade Kalachnikov. Rien de tout cela n\'est enregistré.'}
          ]
        },
        'marche': {
          name: 'Marché d\'État',
          desc: "Les rayons sont souvent vides. Olga propose parfois des produits sous le manteau.",
          persons: [{"name": "Vendeur d'État (PNJ)", "role": "Vendeur collectif", "rel": "neutral", "job": "commercant"}, {"name": "Olga Marché Noir (PNJ)", "role": "Revendeuse discrète", "rel": "neutral", "job": "commercant"}]
        },
        'palais-presidentiel': {
          name: 'Palais du Parti',
          desc: 'Le cœur du pouvoir de Sovarka. Camarade Borodine reçoit sur rendez-vous uniquement, après vérification de votre dossier de loyauté.',
          persons: []
        },
        'palais-gouvernement': {
          name: 'Siège du Comité Central',
          desc: 'Le vrai pouvoir de Sovarka. Chaque décision est votée à l\'unanimité — le Parti ne connaît pas le désaccord.',
          persons: []
        },
        'assemblee': {
          name: 'Soviet Suprême',
          desc: 'L\'assemblée du Peuple. Tous les votes sont unanimes. Camarade Président parle, les délégués approuvent.',
          persons: []
        },
        'mairie-capitale': {
          name: 'Soviet Municipal',
          desc: 'L\'administration locale du Parti. Formulaires en quadruple exemplaire.',
          persons: []
        },
                'centre-multinodal-luthecia': {
          name: "Hall Principal",
          desc: "Trans-Urals Express, taxis verts collectifs, bus du Parti. Camarade Horaire veille. Les trains arrivent à l\\'heure, c\\'est obligatoire.",
          persons: [{"name": "Camarade Horaire (PNJ)", "role": "Chef de gare", "rel": "neutral", "job": "chef_gare"}, {"name": "Agente Nadejda (PNJ)", "role": "Agente de contrôle", "rel": "neutral", "job": "securite"}],
          rooms: {
          'hall_gare': {
            name: "Hall Principal — Gare Centrale du Peuple",
            desc: "Trans-Urals Express, taxis verts collectifs, bus du Parti. Camarade Horaire veille. Les trains arrivent à l\\'heure, c\\'est obligatoire.",
            persons: [{"name": "Camarade Horaire (PNJ)", "role": "Chef de gare", "rel": "neutral", "job": "chef_gare"}, {"name": "Agente Nadejda (PNJ)", "role": "Agente de contrôle", "rel": "neutral", "job": "securite"}]
          },
          'hall_douanes': {
            name: "Contrôle des Camarades",
            desc: "Le contrôle douanier de Sovarka. Nadejda Contrôle fouille votre bagage méthodiquement. Tout est enregistré en triple.",
            persons: [{"name": "Nadejda Contrôle (PNJ)", "role": "Inspectrice des douanes", "rel": "neutral", "job": "douanier"}]
          },
          'zone_embarquement': {
            name: "Zone de Départ Collectif",
            desc: "La zone d\\'embarquement du Peuple. Vols vers les 4 empires. Loyauté obligatoire.",
            persons: []
          }
          }
        },        'commissariat': {
          name: "Milice de Stalinova",
          desc: "Très attentive aux comportements déviants.",
          persons: [{"name": "Milicien Vigilant (PNJ)", "role": "Chef de milice", "rel": "neutral", "job": "commissaire"}]
        },
        'banque-nationale': {
          name: "Caisse d'État de Stalinova",
          desc: "Transactions enregistrées en quadruple.",
          persons: [{"name": "Caissier Méticuleux (PNJ)", "role": "Caissier", "rel": "neutral", "job": "banquier"}]
        },
        'dispensaire-public': {
          name: "Poste Médical Collectif",
          desc: "Le médecin est là deux fois par semaine.",
          persons: [{"name": "Docteur Collectif (PNJ)", "role": "Médecin", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: "Bulletin du Parti Local",
          desc: "Nouvelles de production uniquement.",
          persons: [{"name": "Correspondant Local (PNJ)", "role": "Correspondant", "rel": "neutral", "job": "journaliste"}]
        },
        'marche': {
          name: "Distribution Collective",
          desc: "Files organisées par ordre alphabétique.",
          persons: [{"name": "Distributeur Équitable (PNJ)", "role": "Distributeur", "rel": "neutral", "job": "commercant"}]
        }
      }
    },
    ville_a: {
      name:'Sibirsk-9',
      imageUrl:'https://images.unsplash.com/photo-1483664852095-d6cc6870702d?w=1200&q=80',
      desc:'Ville miniere glaciale aux confins de l\'empire. Le froid mord, le charbon manque rarement.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-3','stade','zone-production'],
      buildingContext: {
        'hotel-republica': {
          name: "Baraquement Sibirsk-9",
          desc: "Le poele central chauffe a peine la piece la plus proche.",
          persons: [{"name": "Responsable Baraquement (PNJ)", "role": "Gérant", "rel": "neutral", "job": "serveur"}]
        },
        'commissariat': {
          name: "Poste de Vigilance Glaciale",
          desc: "Le registre des allees et venues est tenu avec zele.",
          persons: [{"name": "Sergent Gel (PNJ)", "role": "Sergent", "rel": "neutral", "job": "commissaire"}]
        },
        'banque-nationale': {
          name: "Caisse Miniere Collective",
          desc: "Les salaires arrivent, parfois en retard, jamais en avance.",
          persons: [{"name": "Comptable Sibirsk (PNJ)", "role": "Comptable", "rel": "neutral", "job": "banquier"}]
        },
        'dispensaire-public': {
          name: "Infirmerie du Froid",
          desc: "Engelures et poussiere de charbon, le quotidien du medecin.",
          persons: [{"name": "Infirmiere Frimas (PNJ)", "role": "Infirmière", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: "Gazette du Charbon",
          desc: "Un feuillet hebdomadaire, imprime a la mine.",
          persons: [{"name": "Redacteur Suie (PNJ)", "role": "Rédacteur", "rel": "neutral", "job": "journaliste"}]
        },
        'marche': {
          name: "Cooperative Miniere",
          desc: "Rations et outils, distribues selon le quota.",
          persons: [{"name": "Gerant Cooperative (PNJ)", "role": "Gérant", "rel": "neutral", "job": "commercant"}]
        }
      }
    },
    ville_b: {
      name:'Kolkhoz-7',
      imageUrl:'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=1200&q=80',
      desc:'Le kolkhoze collectif numéro 7. Production agricole pour la gloire du Parti.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-2','stade','zone-production'],
      buildingContext: {
        'hotel-republica': {
          name: "Baraquement Collectif N°7",
          desc: "Le logement collectif du kolkhoze. Confort spartiate garanti.",
          persons: [{"name": "Responsable Logement (PNJ)", "role": "Responsable", "rel": "neutral", "job": "serveur"}]
        },
        'commissariat': {
          name: "Surveillance du Kolkhoze",
          desc: "Il note tout dans son carnet.",
          persons: [{"name": "Agent Surveillance (PNJ)", "role": "Agent", "rel": "neutral", "job": "commissaire"}]
        },
        'banque-nationale': {
          name: "Caisse Kolkhozienne",
          desc: "Les bénéfices vont à l'État.",
          persons: [{"name": "Comptable Kolkhoze (PNJ)", "role": "Comptable", "rel": "neutral", "job": "banquier"}]
        },
        'dispensaire-public': {
          name: "Infirmerie du Kolkhoze",
          desc: "Pour les accidents de tracteur.",
          persons: [{"name": "Infirmier Rural (PNJ)", "role": "Infirmier", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: "Affichage Mural Collectif",
          desc: "Mises à jour hebdomadaires.",
          persons: [{"name": "Afficheur Officiel (PNJ)", "role": "Afficheur", "rel": "neutral", "job": "journaliste"}]
        },
        'marche': {
          name: "Entrepôt Collectif",
          desc: "On y prend sa ration hebdomadaire.",
          persons: [{"name": "Gérant Entrepôt (PNJ)", "role": "Gérant", "rel": "neutral", "job": "commercant"}]
        }
      }
    },
    caserne: {
      name:'Garnison du Peuple',
      imageUrl:'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=1200&q=80',
      desc:'La garnison militaire de Sovarka.',
      isCapitale: false, isSpecial: true, travelCost: 1,
      buildings: ['caserne-militaire']
    },
    qhs: {
      name:'Goulag de Novomirsk',
      imageUrl:'https://images.unsplash.com/photo-1562564055-71e051d33c19?w=1200&q=80',
      desc:'Le goulag de Sovarka. On y entre facilement.',
      isCapitale: false, isSpecial: true, travelCost: 1,
      buildings: ['qhs-prison']
    }
  },

  khalija: {
    capitale: {
      name:'Al-Madina',
      streetName: 'Boulevard Royal Al-Sultani',
      imageUrl:'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=1200&q=80',
      desc:'Capitale d\'Al-Khalija. Or, turquoise et sable. Le Palais Royal domine tout. Le protocole est une religion.',
      isCapitale: true,
      buildings: ['palais-presidentiel','hotel-republica','palais-gouvernement','assemblee','tribunal','banque-nationale','banque-privee','clinique-privee','dispensaire-public','commissariat','la-tribune','loge-maconnique','universite','armurerie','marche','mairie-capitale','patisserie-sacree','centre-multinodal-luthecia','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-1','terrain-a-batir-4','terrain-a-batir-5','terrain-a-batir-6','terrain-a-batir-7','office-notarial','stade'],
      buildingContext: {
        'hotel-republica': {
          name: "Hôtel Al-Nour Palace",
          desc: "Cinq étoiles. Marbre, or et silence. Hassan Marchandage règle les problèmes des clients fortunés.",
          persons: [{"name": "Hassan Marchandage (PNJ)", "role": "Concierge Royal", "rel": "neutral", "job": "serveur"}, {"name": "Yasmine Épices (PNJ)", "role": "Hôtesse", "rel": "neutral", "job": "serveur"}],
          roomOverrides: {
            'hall_hotel':   { name: "Grand Hall Al-Nour",    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-hotel-khalija.png' },
            'chambre':      { name: "Suite Royale",          imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/chambre-hotel-khalija.png' },
            'restaurant':   { name: "Restaurant Al-Nour",   imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-hotel-khalija.png' },
            'bar':          { name: "Salon des Hôtes",       imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-hotel-khalija.png' }
          }
        },
        'commissariat': {
          name: "Garde Royale",
          desc: "Ibn Protocole veille sur l'ordre avec une politesse glaciale.",
          persons: [{"name": "Chambellan Ibn Protocole (PNJ)", "role": "Chef de la Garde", "rel": "neutral", "job": "commissaire"}, {"name": "Fatima Al-Secret (PNJ)", "role": "Inspectrice", "rel": "neutral", "job": "inspecteur"}]
        },
        'tribunal': {
          name: 'Tribunal de la Charia',
          desc: "Cheikh Al-Verdict rend ses décisions après consultation des textes sacrés et du Palais.",
          persons: [{"name": "Cheikh Al-Verdict (PNJ)", "role": "Grand Juge", "rel": "neutral", "job": "juge"}, {"name": "Conseiller Juridique (PNJ)", "role": "Conseiller", "rel": "neutral", "job": "avocat"}],
          roomOverrides: {
            'audience':     { name: "Salle d'Audience de la Charia", imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tribunal-khalija.png' },
            'deliberation': { name: "Chambre de Délibération",       imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tribunal-khalija.png' },
            'archives':     { name: "Archives Juridiques Royales",   imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tribunal-khalija.png' }
          }
        },
        'banque-nationale': {
          name: 'Banque Royale Al-Khalija',
          desc: "Les intérêts sont conformes à la loi islamique, officiellement.",
          persons: [{"name": "Directeur Al-Or (PNJ)", "role": "Directeur", "rel": "neutral", "job": "banquier"}, {"name": "Caissière Voilée (PNJ)", "role": "Caissière", "rel": "neutral", "job": "caissier"}]
        },
        'banque-privee': {
          name: 'Banque Privée Al-Baraka',
          desc: "Discrétion absolue et thé à la menthe offert.",
          persons: [{"name": "Cheikh Al-Discret (PNJ)", "role": "Directeur privé", "rel": "neutral", "job": "banquier"}]
        },
        'clinique-privee': {
          name: 'Clinique Royale',
          desc: "Réservée aux proches du pouvoir et aux très fortunés.",
          persons: [{"name": "Docteur Al-Soin (PNJ)", "role": "Médecin Royal", "rel": "neutral", "job": "medecin"}]
        },
        'dispensaire-public': {
          name: 'Dispensaire Al-Madina',
          desc: "Pour le peuple. Moderne en apparence, sous-doté en réalité.",
          persons: [{"name": "Infirmière Al-Bien (PNJ)", "role": "Infirmière", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: 'Le Minaret Doré',
          desc: "La parole divine, édition spéciale. Rédacteur Al-Vérité ne publie que ce que le Palais approuve.",
          persons: [{"name": "Rédacteur Al-Vérité (PNJ)", "role": "Rédacteur en chef", "rel": "neutral", "job": "journaliste"}, {"name": "Correspondant Royal (PNJ)", "role": "Journaliste", "rel": "neutral", "job": "journaliste"}]
        },
        'loge-maconnique': {
          requiresMembership: 'loge',
          name: 'Cercle des Sages',
          desc: "Influence considérable sur les décisions royales.",
          persons: [{"name": "Sage Al-Ancien (PNJ)", "role": "Président du Cercle", "rel": "neutral", "job": "loge"}]
        },
        'universite': {
          name: 'Université Royale',
          desc: "Excellence académique et loyauté royale obligatoires.",
          persons: [{"name": "Professeur Al-Savoir (PNJ)", "role": "Doyen", "rel": "neutral", "job": "professeur"}, {"name": "Assistante Al-Studieuse (PNJ)", "role": "Assistante", "rel": "neutral", "job": "professeur"}]
        },
        'armurerie': {
          name: 'Arsenaux Royaux',
          desc: "Accès sur autorisation royale.",
          persons: [{"name": "Gardien Al-Arsenal (PNJ)", "role": "Responsable Arsenal", "rel": "neutral", "job": "commercant"}]
        },
        'marche': {
          name: 'Souk Al-Madina',
          desc: "Le prix affiché n'est jamais le vrai prix.",
          persons: [{"name": "Hassan Marchandage (PNJ)", "role": "Marchand principal", "rel": "neutral", "job": "commercant"}, {"name": "Yasmine Épices (PNJ)", "role": "Marchande", "rel": "neutral", "job": "commercant"}],
          orders: [
            {fn:'marche_noir', label:'Marché Noir', pa:1, cost:0, type:'illegal', icon:'ti-alert-triangle', successRate:100, desc:'Explosifs et le poison local de Hassan. Rien de tout cela n\'est enregistré.'}
          ]
        },
        'palais-presidentiel': {
          name: 'Palais Royal Al-Qasr',
          desc: 'La résidence du Sheikh. On n\'entre qu\'après triple vérification du protocole et des liens familiaux.',
          persons: [],
          roomOverrides: {
            'accueil_elysee':      { name: "Hall d'Honneur Royal",         imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-hotel-khalija.png' },
            'bureau_president':    { name: "Bureau du Sheikh",              imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-roi-khalija.png' },
            'salle_presse_elysee': { name: "Salle des Annonces Royales",    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-hotel-khalija.png' },
            'salle_reception':     { name: "Salle de Réception Royale",     imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-hotel-khalija.png' }
          }
        },
        'palais-gouvernement': {
          name: 'Diwan Gouvernemental',
          desc: 'Le gouvernement royal. Le protocole est une religion en soi.',
          persons: []
        },
        'assemblee': {
          name: 'Conseil Consultatif Royal',
          desc: 'Le conseil royal. Consultatif uniquement — les décisions appartiennent au Sheikh.',
          persons: [],
          roomOverrides: {
            'hemicycle':                { name: "Salle du Conseil Royal",      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/assemblee-khalija.png' },
            'couloirs':                 { name: "Couloirs du Conseil",         imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/couloirs-conseil-khalija.png' },
            'salle_archives_assemblee': { name: "Archives Royales",            imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/archives-an-republic.png' }
          }
        },
        'mairie-capitale': {
          name: 'Chambre Municipale Royale',
          desc: 'L\'administration de la capitale. Protocole royal obligatoire.',
          persons: []
        },
                'centre-multinodal-luthecia': {
          name: "Hall Principal",
          desc: "TGV doré, taxis vert et or, service des VIP. Chambellan Al-Transit accueille selon votre rang. Le protocole est une religion.",
          persons: [{"name": "Chambellan Al-Transit (PNJ)", "role": "Directeur du Hub", "rel": "neutral", "job": "chef_gare"}, {"name": "Yasmine Embarquement (PNJ)", "role": "Hôtesse royale", "rel": "neutral", "job": "hotesse"}],
          rooms: {
          'hall_gare': {
            name: "Hall Principal — Hub Royal",
            desc: "TGV doré, taxis vert et or, service des VIP. Chambellan Al-Transit accueille selon votre rang. Le protocole est une religion.",
            persons: [{"name": "Chambellan Al-Transit (PNJ)", "role": "Directeur du Hub", "rel": "neutral", "job": "chef_gare"}, {"name": "Yasmine Embarquement (PNJ)", "role": "Hôtesse royale", "rel": "neutral", "job": "hotesse"}]
          },
          'hall_douanes': {
            name: "Contrôle Douanier Royal",
            desc: "Le contrôle douanier royal. Le Chambellan Al-Transit incline la tête. Vos papiers sont vérifiés selon le protocole royal.",
            persons: [{"name": "Chambellan Al-Transit (PNJ)", "role": "Inspecteur royal", "rel": "neutral", "job": "douanier"}]
          },
          'zone_embarquement': {
            name: "Terminal Royal d\\'Embarquement",
            desc: "Le terminal d\\'embarquement royal. Vols vers les 4 empires. Service VIP disponible.",
            persons: [{"name": "Yasmine Embarquement (PNJ)", "role": "Hôtesse royale", "rel": "neutral", "job": "hotesse"}]
          }
          }
        },        'commissariat': {
          name: "Poste de Sécurité Royal",
          desc: "Courtois mais vigilant.",
          persons: [{"name": "Garde Al-Vigilant (PNJ)", "role": "Chef de poste", "rel": "neutral", "job": "commissaire"}]
        },
        'banque-nationale': {
          name: "Agence Bancaire Al-Zafar",
          desc: "Transactions en or acceptées.",
          persons: [{"name": "Agent Bancaire (PNJ)", "role": "Agent", "rel": "neutral", "job": "banquier"}]
        },
        'dispensaire-public': {
          name: "Centre Médical de l'Oasis",
          desc: "Bien équipé pour une ville de cette taille.",
          persons: [{"name": "Médecin Al-Zafar (PNJ)", "role": "Médecin", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: "Gazette de l'Oasis",
          desc: "Nouvelles de l'oasis et éloges royaux.",
          persons: [{"name": "Journaliste Local (PNJ)", "role": "Journaliste", "rel": "neutral", "job": "journaliste"}]
        },
        'marche': {
          name: "Souk de l'Oasis",
          desc: "Épices, tapis et informations.",
          persons: [{"name": "Marchand Al-Zafar (PNJ)", "role": "Marchand", "rel": "neutral", "job": "commercant"}]
        }
      }
    },
    ville_a: {
      name:'Oasis Al-Baraka',
      imageUrl:'https://images.unsplash.com/photo-1451337516015-6b6e9a44a8a3?w=1200&q=80',
      desc:'Oasis caravaniere au coeur du desert. Les marchands s\'y arretent depuis des siecles, les secrets aussi.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-3','stade','zone-production'],
      buildingContext: {
        'hotel-republica': {
          name: "Caravanserail Al-Baraka",
          desc: "Halte historique des routes caravanieres. Les murs ont vu passer bien des fortunes.",
          persons: [{"name": "Maitre Caravanserail (PNJ)", "role": "Gérant", "rel": "neutral", "job": "serveur"}]
        },
        'commissariat': {
          name: "Garde de l'Oasis",
          desc: "Surveille les puits autant que les caravanes.",
          persons: [{"name": "Capitaine Oasis (PNJ)", "role": "Capitaine", "rel": "neutral", "job": "commissaire"}]
        },
        'banque-nationale': {
          name: "Maison de Change du Desert",
          desc: "Toutes les monnaies du monde y trouvent leur valeur.",
          persons: [{"name": "Changeur du Desert (PNJ)", "role": "Changeur", "rel": "neutral", "job": "banquier"}]
        },
        'dispensaire-public': {
          name: "Tente de Soins",
          desc: "Herbes locales et remedes ancestraux.",
          persons: [{"name": "Guerisseuse Oasis (PNJ)", "role": "Guérisseuse", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: "Le Heraut du Desert",
          desc: "Les nouvelles voyagent aussi vite que les caravanes.",
          persons: [{"name": "Heraut Ambulant (PNJ)", "role": "Héraut", "rel": "neutral", "job": "journaliste"}]
        },
        'marche': {
          name: "Souk de l'Oasis",
          desc: "Epices, tissus et rumeurs venues de tres loin.",
          persons: [{"name": "Marchand de l'Oasis (PNJ)", "role": "Marchand", "rel": "neutral", "job": "commercant"}]
        }
      }
    },
    ville_b: {
      name:'Port Al-Nour',
      imageUrl:'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=1200&q=80',
      desc:'Port pétrolier d\'Al-Khalija. Les tankers et les dhows se croisent.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-2','stade','zone-production'],
      buildingContext: {
        'hotel-republica': {
          name: "Hôtel du Port Al-Nour",
          desc: "Vue sur les tankers pétroliers.",
          persons: [{"name": "Gérant Al-Nour (PNJ)", "role": "Gérant", "rel": "neutral", "job": "serveur"}]
        },
        'commissariat': {
          name: "Garde Portuaire Royale",
          desc: "Contrôle les entrées et sorties.",
          persons: [{"name": "Garde Portuaire (PNJ)", "role": "Garde", "rel": "neutral", "job": "commissaire"}]
        },
        'banque-nationale': {
          name: "Banque Pétrolière Al-Nour",
          desc: "Les chiffres sont impressionnants.",
          persons: [{"name": "Directeur Pétrolier (PNJ)", "role": "Directeur", "rel": "neutral", "job": "banquier"}]
        },
        'dispensaire-public': {
          name: "Dispensaire du Port",
          desc: "Pour les travailleurs du port. Bien équipé.",
          persons: [{"name": "Médecin du Port (PNJ)", "role": "Médecin", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: "Journal Pétrolier",
          desc: "Les nouvelles du secteur pétrolier.",
          persons: [{"name": "Journaliste Pétrole (PNJ)", "role": "Journaliste", "rel": "neutral", "job": "journaliste"}]
        },
        'marche': {
          name: "Souk du Port",
          desc: "Marchandises du monde entier.",
          persons: [{"name": "Marchand du Port (PNJ)", "role": "Marchand", "rel": "neutral", "job": "commercant"}]
        }
      }
    },
    caserne: {
      name:'Forteresse Royale',
      imageUrl:'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=1200&q=80',
      desc:'La forteresse militaire royale d\'Al-Khalija.',
      isCapitale: false, isSpecial: true, travelCost: 1,
      buildings: ['caserne-militaire']
    },
    qhs: {
      name:'Prison Royale',
      imageUrl:'https://images.unsplash.com/photo-1562564055-71e051d33c19?w=1200&q=80',
      desc:'La prison royale d\'Al-Khalija. Luxueuse en apparence.',
      isCapitale: false, isSpecial: true, travelCost: 1,
      buildings: ['qhs-prison']
    }
  }
};

// =====================
// BUILDINGS DEFINITION
// =====================

// =====================
// V31 — STATS PNJ PAR JOB (valeurs par défaut)
// =====================
const PNJ_STATS_PAR_JOB = {
  // FOR=Force/combat, CHA=Charisme, DUP=Duplicité, INT=Intelligence, loyaute=0-100
  serveur:          { FOR:2,  CHA:6,  DUP:4,  INT:5,  loyaute:50, recrutCout:100,  recrutLabel:'Serveur',         combatBonus:{ moral:2 } },
  hotelier:         { FOR:2,  CHA:7,  DUP:5,  INT:6,  loyaute:55, recrutCout:150,  recrutLabel:'Hôtelier',        combatBonus:{ moral:2 } },
  barman:           { FOR:4,  CHA:7,  DUP:5,  INT:6,  loyaute:40, recrutCout:120,  recrutLabel:'Barman',          combatBonus:{ inf:3 } },
  escort:           { FOR:2,  CHA:10, DUP:8,  INT:7,  loyaute:25, recrutCout:500,  recrutLabel:'Escort',          combatBonus:{ dis:-5, inf:5 } },
  commissaire:      { FOR:7,  CHA:5,  DUP:6,  INT:7,  loyaute:65, recrutCout:800,  recrutLabel:'Commissaire',     combatBonus:{ dis:-10 } },
  // PER/VOL ajoutes (24 aout 2026, lot policiers PNJ) : extension additive, verifiee sans risque
  // sur tous les consommateurs existants (getPnjStats fait un spread generique, aucun code ne
  // suppose exactement 4 proprietes). Valeurs fixes pour le policier PNJ standard recrutable par
  // un commissaire (voir chargerEffectifsPolice, plateau-justice-economie.js) -- distinct du
  // systeme d'emploi personnel generique (confirmerRecrutPnj, desactive, non reactive ici).
  policier:         { FOR:8,  CHA:4,  DUP:4,  INT:5,  PER:12, VOL:12, loyaute:60, recrutCout:400,  recrutLabel:'Policier',        combatBonus:{ for:5 } },
  inspecteur:       { FOR:6,  CHA:5,  DUP:5,  INT:8,  loyaute:55, recrutCout:600,  recrutLabel:'Inspecteur',      combatBonus:{ inf:5 } },
  militaire:        { FOR:9,  CHA:4,  DUP:3,  INT:5,  loyaute:80, recrutCout:500,  recrutLabel:'Militaire',       combatBonus:{ for:8 } },
  soldat:           { FOR:8,  CHA:3,  DUP:3,  INT:4,  loyaute:75, recrutCout:300,  recrutLabel:'Soldat',          combatBonus:{ for:6 } },
  garde:            { FOR:9,  CHA:3,  DUP:3,  INT:4,  loyaute:80, recrutCout:350,  recrutLabel:'Garde du corps',  combatBonus:{ for:7 } },
  general:          { FOR:8,  CHA:7,  DUP:5,  INT:8,  loyaute:70, recrutCout:2000, recrutLabel:'Général',         combatBonus:{ for:10, inf:5 } },
  journaliste:      { FOR:2,  CHA:7,  DUP:6,  INT:8,  loyaute:35, recrutCout:400,  recrutLabel:'Journaliste',     combatBonus:{ pop:5, inf:5 } },
  redacteur:        { FOR:2,  CHA:6,  DUP:6,  INT:8,  loyaute:40, recrutCout:350,  recrutLabel:'Rédacteur',       combatBonus:{ inf:5 } },
  medecin:          { FOR:2,  CHA:7,  DUP:4,  INT:9,  loyaute:60, recrutCout:800,  recrutLabel:'Médecin',         combatBonus:{ hp:15 } },
  infirmier:        { FOR:3,  CHA:6,  DUP:3,  INT:7,  loyaute:55, recrutCout:300,  recrutLabel:'Infirmier',       combatBonus:{ hp:8 } },
  avocat:           { FOR:2,  CHA:8,  DUP:7,  INT:9,  loyaute:45, recrutCout:1000, recrutLabel:'Avocat',          combatBonus:{ dis:8 } },
  juge:             { FOR:2,  CHA:6,  DUP:5,  INT:9,  loyaute:65, recrutCout:2000, recrutLabel:'Juge',            combatBonus:{ dis:10 } },
  banquier:         { FOR:2,  CHA:7,  DUP:7,  INT:9,  loyaute:50, recrutCout:1500, recrutLabel:'Banquier',        combatBonus:{ arg:500 } },
  commercant:       { FOR:3,  CHA:7,  DUP:6,  INT:6,  loyaute:40, recrutCout:200,  recrutLabel:'Commerçant',      combatBonus:{ pop:3 } },
  marchande:        { FOR:3,  CHA:7,  DUP:5,  INT:6,  loyaute:45, recrutCout:150,  recrutLabel:'Marchande',       combatBonus:{ inf:3 } },
  journaliste:      { FOR:2,  CHA:7,  DUP:6,  INT:8,  loyaute:35, recrutCout:400,  recrutLabel:'Journaliste',     combatBonus:{ pop:5, inf:5 } },
  professeur:       { FOR:2,  CHA:6,  DUP:4,  INT:10, loyaute:55, recrutCout:500,  recrutLabel:'Professeur',      combatBonus:{ inf:6 } },
  syndicaliste:     { FOR:5,  CHA:8,  DUP:5,  INT:7,  loyaute:50, recrutCout:300,  recrutLabel:'Syndicaliste',    combatBonus:{ pop:8 } },
  loge:             { FOR:3,  CHA:7,  DUP:8,  INT:8,  loyaute:60, recrutCout:1000, recrutLabel:'Membre de Loge',  combatBonus:{ inf:8, dis:5 } },
  venerable:        { FOR:2,  CHA:8,  DUP:8,  INT:9,  loyaute:70, recrutCout:2000, recrutLabel:'Vénérable',       combatBonus:{ inf:12, dis:8 } },
  grand_pretre:     { FOR:2,  CHA:9,  DUP:6,  INT:8,  loyaute:65, recrutCout:1500, recrutLabel:'Grand Prêtre',    combatBonus:{ moral:10, pop:8 } },
  douanier:         { FOR:5,  CHA:4,  DUP:6,  INT:5,  loyaute:45, recrutCout:300,  recrutLabel:'Douanier',        combatBonus:{ dis:5 } },
  docker:           { FOR:8,  CHA:4,  DUP:3,  INT:4,  loyaute:50, recrutCout:200,  recrutLabel:'Docker',          combatBonus:{ for:6 } },
  portier:          { FOR:7,  CHA:5,  DUP:3,  INT:4,  loyaute:65, recrutCout:250,  recrutLabel:'Portier',         combatBonus:{ for:5 } },
  secretaire:       { FOR:2,  CHA:7,  DUP:5,  INT:8,  loyaute:55, recrutCout:400,  recrutLabel:'Secrétaire',      combatBonus:{ inf:6 } },
  lobbyiste:        { FOR:2,  CHA:8,  DUP:8,  INT:7,  loyaute:30, recrutCout:800,  recrutLabel:'Lobbyiste',       combatBonus:{ inf:6, pop:4 } },
  hotesse:          { FOR:2,  CHA:8,  DUP:5,  INT:6,  loyaute:45, recrutCout:200,  recrutLabel:'Hôtesse',         combatBonus:{ cha:4 } },
  default:          { FOR:3,  CHA:5,  DUP:4,  INT:5,  loyaute:45, recrutCout:150,  recrutLabel:'PNJ',             combatBonus:{} },
};

// Stats spécifiques pour PNJ nommés (surcharge les valeurs du job)
const PNJ_STATS_NOMMES = {
  'Roxane Velours':         { FOR:2,  CHA:10, DUP:9,  INT:8,  loyaute:20 },
  'Marco (Barman)':         { FOR:5,  CHA:8,  DUP:6,  INT:7,  loyaute:45 },
  'Hans Von Discret':       { FOR:2,  CHA:7,  DUP:9,  INT:10, loyaute:70 },
  'Frère Jacques D\'Equerre': { FOR:3, CHA:8, DUP:8, INT:9,  loyaute:75 },
  'Raoul Toufaud':          { FOR:6,  CHA:6,  DUP:7,  INT:7,  loyaute:60 },
  'Brigitte Menottes':      { FOR:7,  CHA:6,  DUP:5,  INT:8,  loyaute:65 },
  'Docteur Bistouri':       { FOR:2,  CHA:7,  DUP:4,  INT:10, loyaute:65 },
  'Ginette Légume':         { FOR:3,  CHA:8,  DUP:6,  INT:6,  loyaute:40 },
  'Jean-Pierre Bidoche':    { FOR:5,  CHA:6,  DUP:5,  INT:5,  loyaute:50 },
  'Gaston Sauceblanche':    { FOR:3,  CHA:8,  DUP:6,  INT:7,  loyaute:55, recrutCout:120 },
  'Yvette Gratinée':        { FOR:2,  CHA:8,  DUP:5,  INT:6,  loyaute:50, recrutCout:100 },
  'Jean Dupont':            { FOR:2,  CHA:7,  DUP:6,  INT:8,  loyaute:45, recrutCout:300 },
  'Marie Leblanc':          { FOR:2,  CHA:8,  DUP:7,  INT:9,  loyaute:30, recrutCout:400 },
};

function getPnjStats(pnj) {
  const nomCourt = (pnj.name || '').replace(' (PNJ)', '').trim();
  const statsNom = PNJ_STATS_NOMMES[nomCourt];
  const statsJob = PNJ_STATS_PAR_JOB[pnj.job || 'default'] || PNJ_STATS_PAR_JOB.default;
  return { ...statsJob, ...(statsNom || {}) };
}

const BUILDINGS = {

  // ---- HOTEL-RESTAURANT LA REPUBLICA ----
  'hotel-republica': {
    name: "Hotel-Restaurant La Republica",
    shortName: "La Republica",
    cat: "Hotellerie - Restauration",
    icon: "ti-building-castle",
    bgColor: "#1a1208",
    desc: "L'etablissement le plus couru de la Capitale. Deputes, ministres et journalistes s'y croisent. On y mange, on y complote, on y trahit.",
    rooms: {
      accueil: {
        name: "Accueil",
        image: "🏨",
        imageBg: "linear-gradient(135deg,#1a1208,#2a1c0a)",
        desc: "Le hall d'entree de l'hotel. Le concierge connait tout le monde.",
        imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotel-republica.png',
        persons: [
          {name:'Nathalie Ondor (PNJ)', role:'Réceptionniste', rel:'neutral', job:'hotelier'},
          {name:'Isidore Trébien (PNJ)', role:'Bagagiste', rel:'neutral', job:'bagagiste'}
        ],
        orders: [
          {fn:'reserver_chambre_hotel', label:'Reserver une chambre', pa:0, cost:80,  type:'legal',   icon:'ti-key', successRate:100, desc:'Bonus de +2 PA et +3 Moral au prochain Dormir passe dans cette chambre.'},
          {fn:'choisir_suite', label:'Louer une suite', pa:1, cost:0, type:'legal', icon:'ti-crown', successRate:100, desc:'Choisir parmi les suites disponibles de l\'hotel.'}
        ]
      },
      restaurant: {
        name: "Salle du Restaurant",
        image: "🍽️",
        imageBg: "linear-gradient(135deg,#1a1005,#2a1a08)",
        desc: "La salle de restaurant est bondee le midi. Tables discretes en fond de salle pour conversations privees.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotel-republica-restaurant.png",
        persons: [
          {name:'Gaston Sauceblanche (PNJ)', role:'Maitre d\'hotel', rel:'neutral', job:'serveur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/paulo-maitre-hotel.png', photoPos:'50% 15%'},
          {name:'Régis Gondasse (PNJ)', role:'Sommelier', rel:'neutral', job:'serveur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gaston-sauceblanche.png', photoPos:'50% 15%'},
          {name:'Yvette Gratinée (PNJ)', role:'Serveuse', rel:'neutral', job:'serveur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/yvette-gratinee.png', photoPos:'50% 15%'},
          {name:'Jean Dupont (PNJ)',       role:'Depute - Parti du Centre', rel:'neutral', job:'commercant', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jean-dupont-marie-leblanc.png', photoPos:'20% 30%'},
          {name:'Marie Leblanc (PNJ)',    role:'Journaliste - La Tribune', rel:'enemy',  job:'journaliste', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jean-dupont-marie-leblanc.png', photoPos:'70% 30%'}
        ],
        orders: [
          {fn:'diner_affaires', label:'Diner d\'affaires', pa:2, cost:300, type:'legal', icon:'ti-wine', successRate:100, desc:'Invitez un PJ present dans la piece a diner, a vos frais. Si accepte : consomme 2 menus + 1 vin du restaurant. +10 Sante, +2 Moral, +5 INF, +3 PA au prochain Dormir pour chacun. Aucun cout si refuse ou si le restaurant n\'a pas de quoi servir.'},
          {fn:'ecouter_rumeurs', label:'Ecouter les tables',  pa:0, cost:0,   type:'grey',   icon:'ti-ear',      successRate:95,  desc:'Revele une rumeur vraie (action recente tracee) ou, a defaut, une information generee selon le contexte.'},
          {fn:'lancer_rumeur_cible', label:'Lancer une rumeur', pa:1, cost:0, type:'grey', icon:'ti-messages', successRate:75, desc:'Rediger une rumeur visant un PJ, une organisation, un local, un gouvernement ou un pays. Succes (75%) : effet selon la cible. Echec : retour de bâton limite + risque de detection.'},
          {fn:'produire_commerce', label:'Cuisiner', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Préparer un plat de la carte (consomme les matières en stock, rémunéré en FR).'},
          {fn:'consulter_carte_commerce', label:'Consulter la carte', pa:0, cost:0, type:'legal', icon:'ti-menu-2', successRate:100, desc:'Voir les plats disponibles et commander.'},
          {fn:'gerer_commerce', label:'Gérer mon commerce', pa:0, cost:0, type:'legal', icon:'ti-settings', successRate:100, desc:'Réservé au propriétaire : coûts de revient, fourchette de prix autorisée, ajustement.'},
          {fn:'vendre_matiere_commerce', label:'Vendre des matières au commerce', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les matières premières de votre inventaire à ce commerce.'}
        ]
      },
      bar: {
        name: "Bar",
        image: "🍺",
        imageBg: "linear-gradient(135deg,#120d05,#1e1508)",
        desc: "Le bar est ouvert jusqu'a l'aube. Langue qui se delie, secrets qui se vendent.",
        imageUrl: "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=1200&q=80",
        persons: [
          {name:'Marco (Barman)', role:'PNJ - Barman', rel:'neutral', job:'barman', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marco-barman.png', photoPos:'50% 20%'},
          {name:'Natacha (PNJ)', role:'Escort — Agence Roxane Velours', rel:'neutral', job:'escort', genre:'F', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-f-1-robe-verte.png', photoPos:'50% 15%'},
          {name:'Julien (PNJ)', role:'Escort — Agence Roxane Velours', rel:'neutral', job:'escort', genre:'H', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-h-1-costume-beige.png', photoPos:'50% 15%'},
          {name:'Marc Hantile', role:'Lobbyiste — Conseil en affaires et économie', rel:'neutral', job:'lobbyiste', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/luthecia-pnj-marc-hantile.jpg', photoPos:'55% 15%'}
        ],
        orders: [
          {fn:'boire_verre', label:'Offrir un verre', pa:0, cost:50, type:'legal', icon:'ti-glass', successRate:100, desc:'Invitez un PJ present a boire un verre, a vos frais. Si accepte : +5 Sante, +2 INF, +2 ENT pour chacun. Aucun cout si refuse.'},
          {fn:'ecouter_rumeurs', label:'Ecouter le barman',     pa:0, cost:0,   type:'grey',  icon:'ti-ear',      successRate:90,  desc:'Le barman entend tout. Revele une rumeur vraie ou generee selon le contexte.', sourceOverride:'Marco'},
          {fn:'recruter_informateur_pnj', label:'Recruter un informateur', pa:1, cost:150, type:'grey', icon:'ti-user-plus', successRate:100, desc:'1 PA, 150 FR puis 150 FR/jour. Un PNJ (PER 12-18) rejoint votre groupe en permanence tant que vous le payez : sa PER s\'ajoute a celle du groupe pour les recherches, enquetes et localisations.'},
          {fn:'escort_piege',    label:'Organiser une rencontre piège', pa:3, cost:800, type:'illegal', icon:'ti-spy', successRate:55, desc:'Piéger un adversaire politique. Risque de scandale.'},
          {fn:'produire_commerce', label:'Préparer les consommations', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Préparer boissons et snacks pour le service (consomme les matières en stock, rémunéré en FR).'},
          {fn:'consulter_carte_commerce', label:'Consulter la carte', pa:0, cost:0, type:'legal', icon:'ti-menu-2', successRate:100, desc:'Voir ce qui est disponible au bar et commander.'},
          {fn:'offrir_tournee', label:'Offrir une tournée', pa:0, cost:0, type:'legal', icon:'ti-glass-cocktail', successRate:100, desc:'Offrez une tournée (une seule boisson de la carte) à plusieurs personnes présentes, à vos frais. Chacun accepte ou refuse indépendamment ; vous ne buvez et ne payez que si au moins une personne accepte.'},
          {fn:'gerer_commerce', label:'Gérer mon commerce', pa:0, cost:0, type:'legal', icon:'ti-settings', successRate:100, desc:'Réservé au propriétaire : coûts de revient, fourchette de prix autorisée, ajustement.'},
          {fn:'vendre_matiere_commerce', label:'Vendre des matières au commerce', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les matières premières de votre inventaire à ce commerce.'}
        ]
      },
      chambres: {
        name: "Chambres",
        image: "🛏️",
        imageBg: "linear-gradient(135deg,#0d0a08,#181208)",
        desc: "Chambres confortables et discretes. Le meilleur endroit pour se reposer ou tenir une reunion privee.",
        imageUrl: "https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'dormir_chambre', label:'Dormir',                  pa:0, cost:0,   type:'legal', icon:'ti-moon',     successRate:100, desc:'Reservez une chambre a l\'accueil au prealable pour beneficier du bonus. Sans reservation, passez l\'ordre Dormir depuis votre fiche personnage.'},
          {fn:'service_etage',  label:'Faire appel au service d\'etage', pa:0, cost:150, type:'legal', icon:'ti-soup', successRate:100, desc:'Dejeuner servi en chambre. +10 Sante, +1 Moral immediats. +1 PA au prochain Dormir.'}
        ]
      },
      suite_privee: {
        name: "Suite Privée — Local à louer",
        imageBg: "linear-gradient(135deg,#1a0d10,#250f18)",
        desc: "📋 À LOUER — Suite luxueuse et très discrète. On y reçoit une clientèle triée sur le volet. Informations exclusives garanties.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotel-republica-suite-privee.png",
        isLocationRoom: true,
        locationData: { prix: 500, bonusPOP: 0, bonusINF: 8, bonusDIS: 10, label: 'Suite Privée', tier: 1, suiteChoice: true },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer cette suite (500 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Suite luxueuse et très discrète. +8 INF +10 DIS à votre organisation.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      },
      suite_presidentielle: {
        name: "Suite Présidentielle — Local à louer",
        imageBg: "linear-gradient(135deg,#181008,#20140a)",
        desc: "📋 À LOUER — Suite d'apparat au décor XIXe, vue sur les toits de la Capitale. Le nec plus ultra pour recevoir en grande pompe.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotel-republica-suite-presidentielle.png",
        isLocationRoom: true,
        locationData: { prix: 500, bonusPOP: 8, bonusINF: 8, bonusDIS: 2, label: 'Suite Présidentielle', tier: 1, suiteChoice: true },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer cette suite (500 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Suite d\'apparat au décor XIXe. +8 POP +8 INF +2 DIS à votre organisation.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      }
    }
  },

  // ---- PALAIS DU GOUVERNEMENT ----
  // ---- PALAIS PRESIDENTIEL ----
  'palais-presidentiel': {
    name: "Palais de l'Elysee de Republia",
    shortName: "Palais Presidentiel",
    cat: "Institutions - Presidence",
    icon: "ti-building-monument",
    bgColor: "#0f1408",
    capitaleOnly: true,
    desc: "La residence officielle du President de Republia. Symbole du pouvoir executif supreme.",
    rooms: {
      accueil_elysee: {
        name: "Hall d'honneur",
        imageBg: "linear-gradient(135deg,#0f1408,#182010)",
        desc: "Le grand hall du Palais. Gardes republicains en grande tenue. Portraits des presidents passes.",
        imageUrl: "https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80",
        persons: [
          {name:'Gérard Tamponneau (PNJ)', role:'PNJ - Chef du protocole presidentiel', rel:'neutral', job:'protocole', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gerard-tamponneau.png', photoPos:'50% 15%'},
          {name:'Garde Republicain (PNJ)', role:'PNJ - Securite presidentielle', rel:'neutral', job:'garde', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-republicain-palais-presidentiel.png', photoPos:'50% 15%'}
        ],
        orders: [
          {fn:'solliciter_audience_president', label:'Solliciter une audience', pa:0, cost:0, type:'legal', icon:'ti-users', successRate:100, desc:'0 PA. Aucun indice. Message automatique transmis au President par mail. Il vous repondra directement.'}
        ]
      },
      bureau_president: {
        name: "Bureau du President",
        imageBg: "linear-gradient(135deg,#0a1005,#12180a)",
        desc: "Le bureau oval de la Presidence. C'est ici que se prennent les decisions les plus importantes de Republia.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-president.png",
        locked: false,
        persons: [
          {name:'Le Président (PNJ)', role:'PNJ - Président de la République', rel:'neutral', job:'president'},
          {name:'Huguette Papier (PNJ)', role:'PNJ - Secretaire general de la presidence', rel:'neutral', job:'secretaire_general', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/huguette-papier.png', photoPos:'50% 15%'}
        ],
        orders: [
          {fn:'creer_poste_ministre',   label:'Creer un poste ministeriel',    pa:3, cost:0,    type:'legal',   icon:'ti-user-star',     successRate:100, requiresPost:'president', desc:'Creer un poste de ministre personnalise. Limite : 1 poste + 1 comite.'},
          {fn:'creer_comite',           label:'Creer un comite',               pa:3, cost:0,    type:'legal',   icon:'ti-users-group',   successRate:100, requiresPost:'president', desc:'Creer un comite special. Limite : 1 comite.'},
          {fn:'supprimer_poste_custom', label:'Supprimer un poste cree',       pa:0, cost:0,    type:'legal',   icon:'ti-trash',         successRate:100, requiresPost:'president', desc:'Supprimer un poste ou comite precedemment cree.'},
          {fn:'nommer_ministre',        label:'Nommer un Premier Ministre',            pa:2, cost:0,    type:'legal',   icon:'ti-crown',         successRate:100, requiresPost:'president', desc:'Nommer un PJ a un poste ministeriel. Envoie un mail au candidat.'},
          {fn:'revoquer_pm',             label:'Revoquer le Premier Ministre',          pa:1, cost:0,    type:'legal',   icon:'ti-crown-off',     successRate:100, requiresPost:'president', desc:'Retirer le poste au Premier Ministre actuel.'},
          {fn:'etat_urgence',           label:'Declarer l\'etat d\'urgence',  pa:3, cost:0,    type:'legal',   icon:'ti-alert-triangle',successRate:100, requiresPost:'president', desc:'Suspend certaines libertes. Fort impact sur INF et POP.'},
          {fn:'declarer_guerre',        label:'Declarer la guerre',            pa:5, cost:0,    type:'legal',   icon:'ti-sword',         successRate:100, requiresPost:'president', desc:'Declarer la guerre a un empire. Consequences majeures.'},
          {fn:'gracier',                label:'Traiter les demandes de grâce',           pa:2, cost:0,    type:'legal',   icon:'ti-heart-handshake',successRate:100,requiresPost:'president', desc:'Examiner les recommandations de grace du Ministre de la Justice — accepter ou refuser.'},
          {fn:'dissoudre_assemblee',    label:'Dissoudre l\'Assemblee',       pa:4, cost:0,    type:'legal',   icon:'ti-ban',           successRate:100, requiresPost:'president', desc:'Declenche de nouvelles elections legislatives. Risque politique majeur.'},
          {fn:'decret_referendum',      label:'Ordonner un referendum',        pa:3, cost:0,    type:'legal',   icon:'ti-checkbox',      successRate:100, requiresPost:'president', desc:'Soumettre une question au vote populaire.'},
          {fn:'jour_deuil',             label:'Decret de deuil national',      pa:1, cost:0,    type:'legal',   icon:'ti-flag',          successRate:100, requiresPost:'president', desc:'Symbolique fort. +POP si populaire, -POP si conteste.'},
          {fn:'decret_inutile',         label:'Signer un decret',              pa:1, cost:0,    type:'legal',   icon:'ti-file-certificate', successRate:100, requiresPost:'president', desc:'Decret absurde généré par IA. Effets parodiques sur POP et INF. Publiable sur le forum.'}
        ]
      },
      salle_presse_elysee: {
        name: "Salle de Presse",
        imageBg: "linear-gradient(135deg,#0f0f18,#181820)",
        desc: "La salle de presse presidentielle. Les journalistes accredites y attendent les declarations.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-presse-palais-presidentiel-luthecia.png",
        persons: [
          {name:'Porte-parole presidentiel (PNJ)', role:'PNJ - Porte-parole de la presidence', rel:'neutral', job:'porteparole', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/porte-parole-presidentiel.png', photoPos:'50% 15%'}
        ],
        orders: [
          {fn:'conference_presse',  label:'Conference de presse',  pa:2, cost:0,   type:'legal', icon:'ti-microphone',   successRate:100, requiresPost:'president', desc:'Annonce presidentielle. Fort impact POP et INF.'},
          {fn:'propagande_etat',    label:'Propagande d\'Etat',    pa:3, cost:500, type:'grey',  icon:'ti-broadcast',    successRate:75,  requiresPost:'president', desc:'Campagne de communication massive. +POP important.'},
          {fn:'dementi',            label:'Dementi officiel',       pa:2, cost:0,   type:'legal', icon:'ti-x',            successRate:80,  requiresPost:'president', desc:'Selectionner une rumeur active visant le president ou le gouvernement pour la dementir. Succes : rumeur effacee, POP retablie. Echec : perte de POP doublee.'}
        ]
      },
      salle_reception: {
        name: "Salle de Reception",
        imageBg: "linear-gradient(135deg,#100f08,#1a1808)",
        desc: "La somptueuse salle de reception du Palais. Receptions d'Etat, banquets diplomatiques.",
        imageUrl: "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=1200&q=80",
        persons: [
          {name:'Gérard Tamponneau (PNJ)', role:'PNJ - Organisation des evenements', rel:'neutral', job:'protocole', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gerard-tamponneau.png', photoPos:'50% 15%'}
        ],
        orders: [
          {fn:'reception_etat',    label:'Organiser une reception',  pa:2, cost:1000, type:'legal', icon:'ti-confetti',   successRate:100, requiresPost:'president', desc:'Reception officielle. +INF +POP +relations diplomatiques.'},
          {fn:'banquet_diplo',     label:'Banquet diplomatique',      pa:3, cost:2000, type:'legal', icon:'ti-wine',       successRate:100, requiresPost:'president', desc:'Inviter des representants etrangers. Ameliore les relations inter-empires.'}
        ]
      }
    }
  },

  'palais-gouvernement': {
    name: "Palais du Gouvernement",
    shortName: "Gouvernement",
    cat: "Institutions - Capitale uniquement",
    icon: "ti-building-bank",
    bgColor: "#141c10",
    capitaleOnly: true,
    desc: "Le coeur du pouvoir executif de Republia. Les ministres y travaillent, les carrieres s'y font et s'y defont.",
    rooms: {
      hall: {
        name: "Hall d'entree",
        imageBg: "linear-gradient(135deg,#141c10,#1e2a18)",
        desc: "Le hall monumental du Palais. Rotonde a coupole, escalier d'honneur, gardes republicains en faction.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-palais-gouvernement-republic.png",
        persons: [
          {name:'Garde Martineau',   role:'PNJ - Securite', rel:'neutral', job:'garde'},
          {name:'Secretaire Dupuis', role:'PNJ - Accueil officiel', rel:'neutral', job:'secretaire'}
        ],
        orders: [
          {fn:'postuler', label:'Postuler a un poste', pa:2, cost:0, type:'legal', icon:'ti-id-badge', successRate:100, desc:'Postes electifs (calendrier) et postes nommes (candidature aupres de l\'autorite competente).'},
          {fn:'organigramme', label:'Organigramme du pays', pa:0, cost:0, type:'legal', icon:'ti-sitemap', successRate:100, desc:'Voir qui occupe chaque poste dans votre empire.'}
        ]
      },
      bureaux: {
        name: "Bureau du Premier Ministre",
        imageBg: "linear-gradient(135deg,#0f1a0c,#182416)",
        desc: "Le bureau du Premier Ministre. Acces PM uniquement.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-premier-ministre.png",
        persons: [
          {name:'Chef de Cabinet (PNJ)', role:'PNJ - Chef de cabinet du PM', rel:'neutral', job:'chef_cabinet', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/chef-cabinet-pm.png', photoPos:'50% 15%'}
        ],
        orders: [
          {fn:'nommer_ministre_pm', label:'Nommer des ministres',       pa:2, cost:0,   type:'legal',   icon:'ti-crown',     successRate:100, requiresPost:'pm', desc:'Nommer un PJ a un poste ministeriel.'},
          {fn:'revoquer_ministre_pm', label:'Revoquer un ministre',       pa:1, cost:0,   type:'legal',   icon:'ti-crown-off', successRate:100, requiresPost:'pm', desc:'Retirer le poste a un ministre en fonction.'},
          {fn:'declencher_vote_confiance', label:'Déclencher un vote de confiance', pa:3, cost:0, type:'legal', icon:'ti-gavel', successRate:100, requiresPost:'pm', desc:'Engager la responsabilite du gouvernement devant l\'Assemblee Nationale. Resultat sous 48h.'}
        ]
      },
      salle_conseil: {
        name: "Salle du Conseil",
        imageBg: "linear-gradient(135deg,#0d1a0a,#152014)",
        desc: "La salle ou se prennent les decisions du gouvernement. Acces ministeriel uniquement.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/conseil-ministres-2.png",
        persons: [
          {name:'Premier Ministre (PNJ)', role:'Chef du gouvernement', rel:'neutral', job:'pm'}
        ],
        orders: []
      },
      salle_presse: {
        name: "Salle de Presse",
        imageBg: "linear-gradient(135deg,#0f0f18,#181820)",
        desc: "La salle de presse officielle du gouvernement. Microphones, cameras, journalistes accrédités.",
        imageUrl: "https://images.unsplash.com/photo-1588681664899-f142ff2dc9b1?w=1200&q=80",
        persons: [
          {name:'Porte-parole (PNJ)', role:'PNJ - Porte-parole du gouvernement', rel:'neutral', job:'porteparole'},
          {name:'Journalistes accredites', role:'PNJ - Presse nationale', rel:'neutral', job:'journaliste'}
        ],
        orders: [
          {fn:'conference_presse', label:'Conférence de presse',  pa:2, cost:0,    type:'legal',   icon:'ti-microphone',   successRate:100, requiresPost:true, desc:'Annonce officielle au pays entier. Fort impact POP et INF.'},
          {fn:'propagande_etat',   label:'Campagne de propagande', pa:3, cost:500,  type:'grey',    icon:'ti-broadcast',    successRate:75,  requiresPost:true, desc:'Influence massive de l\'opinion publique. +POP important.'},
          {fn:'dementi',           label:'Démenti officiel',       pa:2, cost:0,    type:'legal',   icon:'ti-x',            successRate:80,  requiresPost:true, desc:'Selectionner une rumeur active visant le president ou le gouvernement pour la dementir. Succes : rumeur effacee, POP retablie. Echec : perte de POP doublee.'}
        ]
      },
      archives_gouv: {
        name: "Archives Gouvernementales",
        imageBg: "linear-gradient(135deg,#100a08,#1a1208)",
        desc: "Les archives secretes du gouvernement. Dossiers classifies, rapports confidentiels, secrets d'Etat.",
        imageUrl: "https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80",
        persons: [
          {name:'Archiviste Legrand (PNJ)', role:'PNJ - Archiviste en chef', rel:'neutral', job:'archiviste'}
        ],
        orders: [
          {fn:'consulter_dossiers_gouv', label:'Consulter des dossiers',    pa:2, cost:0,    type:'legal',   icon:'ti-archive',        successRate:80,  requiresPost:true, desc:'Rapports confidentiels et notes de synthese classifiees du gouvernement.'},
          {fn:'fuite_info',         label:'Produire une fuite',        pa:3, cost:0,    type:'grey',    icon:'ti-leak',           successRate:60,  requiresPost:true, desc:'Faire fuiter un document secret.'}
        ]
      },

      // ---- BUREAUX MINISTERIELS ----
      bureau_min_int: {
        name: "Bureau - Ministre de l'Interieur",
        imageBg: "linear-gradient(135deg,#100a08,#1a1005)",
        desc: "Le bureau du Ministre de l'Interieur. Securite nationale, ordre public, police.",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        requiresPostId: 'min_int',
        persons: [{name:"Le Ministre de l'Intérieur (PNJ)", role:'PNJ - Ministre de l\'Interieur', rel:'neutral', job:'min_int'}],
        orders: [
          {fn:'mobiliser_police',     label:'Faire intervenir les forces de l\'ordre', pa:2, cost:0, type:'legal', icon:'ti-shield', successRate:100, requiresPost:'min_int', desc:'Choisir un type d\'intervention concrete (blocus, manifestation, quartier sensible).'},
          {fn:'traiter_manifestations', label:'Traiter les demandes de manifestation', pa:1, cost:0, type:'legal', icon:'ti-users-group', successRate:100, requiresPost:'min_int', desc:'Autoriser ou interdire un rassemblement declare.'},
          {fn:'demandes_naturalisation', label:'Demandes de naturalisation', pa:0, cost:0, type:'legal', icon:'ti-passport', successRate:100, requiresPost:'min_int', desc:'Examiner les demandes de naturalisation en attente (delai 48h avant traitement possible).'},
          {fn:'gerer_couvre_feu',    label:'Instaurer un couvre-feu',     pa:2, cost:0, type:'legal', icon:'ti-moon', successRate:100, requiresPost:'min_int', desc:'20h-6h, 2 jours maximum. Degrade IS et POP du gouvernement tant qu\'il dure.'},
          {fn:'subvention_min_int',  label:'Allouer une subvention',      pa:1, cost:0, type:'legal', icon:'ti-cash', successRate:100, requiresPost:'min_int', desc:'Subventionner le commissariat de n\'importe quelle ville, ou le QHS, depuis la caisse du Ministere.'},
          {fn:'interdire_manif',     label:'Interdire une manifestation', pa:2, cost:0, type:'legal', icon:'ti-ban', successRate:100, requiresPost:'min_int', desc:'Cible une ville precise. Baisse le Social local, facilite une repression ulterieure au meme endroit.'},
          {fn:'reprimer_manif',      label:'Reprimer une manifestation',  pa:3, cost:0, type:'legal', icon:'ti-shield-x', successRate:100, requiresPost:'min_int', desc:'Cible une ville precise. Baisse le Social local (bonus si une manifestation y a ete interdite recemment) ; blesse les PJ presents sur place.'},
          {fn:'nommer_chef_douanes',  label:'Nommer un Chef des Douanes', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_int', desc:'Nommer un PJ Chef des Douanes de Republia. Poste exclusif (sauf depute).'},
          {fn:'revoquer_chef_douanes', label:'Revoquer le Chef des Douanes', pa:1, cost:0, type:'legal', icon:'ti-user-x', successRate:100, requiresPost:'min_int', desc:'Retirer le poste au Chef des Douanes actuellement en fonction.'}
        ]
      },
      bureau_min_fin: {
        name: "Bureau - Ministre des Finances",
        imageBg: "linear-gradient(135deg,#0a0f08,#101508)",
        desc: "Le bureau du Ministre des Finances. Fiscalite, budget, politique economique.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-ministre-finances-luthecia.png",
        requiresPostId: 'min_fin',
        persons: [{name:'Le Ministre des Finances (PNJ)', role:'PNJ - Ministre des Finances', rel:'neutral', job:'min_fin'}],
        orders: [
          {fn:'fixer_impots_nationaux', label:'Fixer le taux d\'imposition national', pa:2, cost:0,   type:'legal',   icon:'ti-percentage',    successRate:100, requiresPost:'min_fin', desc:'Voir et modifier le taux d\'imposition national en vigueur.'},
          {fn:'redressement_fiscal',  label:'Ordonner un redressement',     pa:2, cost:0,   type:'legal',   icon:'ti-gavel',          successRate:80,  requiresPost:'min_fin', desc:'Cibler un citoyen, un club sportif, une entreprise ou une organisation. Genere des recettes pour l\'Etat mais cree des ennemis.'},
          {fn:'subvention',           label:'Accorder une subvention',      pa:2, cost:0, type:'legal',   icon:'ti-coins',          successRate:100, requiresPost:'min_fin', desc:'Cibler un citoyen, un club sportif, une entreprise ou une organisation. Montant a fixer ensuite (plafond 5000 FR).'},
          {fn:'fiscal',              label:'Repartition budgetaire',       pa:2, cost:0, type:'legal', icon:'ti-chart-pie',   successRate:100, requiresPost:'min_fin', desc:'Fixer la repartition des recettes fiscales entre les institutions. Prerogative exclusive du Ministre des Finances.'},
          {fn:'gerer_candidatures_directeurs', label:'Gérer les candidatures de directeurs', pa:1, cost:0, type:'legal', icon:'ti-user-search', successRate:100, requiresPost:'min_fin', desc:'Candidatures reçues pour les 3 directeurs d\'usine (Pharmaceutique, Tabac & Alcools, Raffinerie) — sans se déplacer.'},
          {fn:'virement_ministere_usine', label:'Virement vers une usine', pa:1, cost:0, type:'legal', icon:'ti-transfer', successRate:100, requiresPost:'min_fin', desc:"Verser un montant depuis la caisse du Ministere vers la caisse d'une usine nationale. Le ministre ne peut jamais prelever directement dans la caisse d'une usine."},
          {fn:'allegement_fiscal',   label:'Allegement fiscal sectoriel', pa:0, cost:0, type:'legal', icon:'ti-percentage', successRate:100, requiresPost:'min_fin', desc:'Pas encore disponible -- sera active une fois le systeme de taxation alimentant les caisses de l\'Etat finalise.'},
          {fn:'preempter_entreprise', label:'Droit de preemption sur une entreprise', pa:2, cost:0, type:'legal', icon:'ti-building-bank', successRate:100, requiresPost:'min_fin', desc:'Nationaliser une entreprise encore tenue par un PNJ, financee par un pret automatique de la Banque Nationale. Une seule preemption a la fois.'},
          {fn:'nommer_commandant_port',  label:'Nommer un Commandant du Port', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ Commandant du Port de Port-Sainte-Marie. Poste exclusif (sauf depute).'},
          {fn:'revoquer_commandant_port', label:'Revoquer le Commandant du Port', pa:1, cost:0, type:'legal', icon:'ti-user-x', successRate:100, requiresPost:'min_fin', desc:'Retirer le poste au Commandant du Port actuellement en fonction.'}
        ]
      },
      bureau_min_just: {
        name: "Bureau - Ministre de la Justice",
        imageBg: "linear-gradient(135deg,#0a0808,#140f08)",
        desc: "Le bureau du Ministre de la Justice. Magistrature, poursuites, grace presidentielle.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-ministre-justice-luthecia.png",
        requiresPostId: 'min_just',
        persons: [{name:'Le Ministre de la Justice (PNJ)', role:'PNJ - Ministre de la Justice', rel:'neutral', job:'min_just'}],
        orders: [
          {fn:'annuler_poursuites',   label:'Classer une plainte',          pa:2, cost:0,   type:'grey',    icon:'ti-file-x',         successRate:70,  requiresPost:'min_just', desc:'Classer une plainte en cours avant jugement. Cree une dette politique. Coute a la caisse du gouvernement.'},
          {fn:'ouvrir_enquete',       label:'Ouvrir une enquete',           pa:2, cost:0,   type:'legal',   icon:'ti-search',         successRate:90,  requiresPost:'min_just', desc:'Cibler un citoyen, un club sportif, une entreprise ou une organisation. Coute a la caisse du gouvernement.'},
          {fn:'proposer_grace',      label:'Proposer une grace',           pa:2, cost:0,   type:'legal',   icon:'ti-heart-handshake',successRate:100, requiresPost:'min_just', desc:'Recommander une grace au President — qui devra valider.'},
          {fn:'nommer_juge',          label:'Nommer un juge',               pa:3, cost:0,   type:'legal',   icon:'ti-gavel',          successRate:90,  requiresPost:'min_just', desc:'Nommer un magistrat favorable. Influence les verdicts futurs.'},
          {fn:'revoquer_juge',         label:'Revoquer un juge',              pa:1, cost:0,   type:'legal',   icon:'ti-gavel',          successRate:100, requiresPost:'min_just', desc:'Retirer le poste au juge actuellement en fonction.'},
          {fn:'gestion_qhs',          label:'Gestion du QHS',               pa:0, cost:0,   type:'legal',   icon:'ti-building-fortress', successRate:100, requiresPost:'min_just', desc:'Budget dedie et liste des detenus du QHS. Transferer, ameliorer les conditions, ou faire torturer.'}
        ]
      },
      bureau_min_def: {
        name: "Bureau - Ministre de la Defense",
        imageBg: "linear-gradient(135deg,#080f08,#0f1808)",
        desc: "Le bureau du Ministre de la Defense. Armee, securite nationale, renseignement militaire.",
        imageUrl: "https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80",
        requiresPostId: 'min_def',
        persons: [{name:'Le Ministre de la Défense (PNJ)', role:'PNJ - Ministre de la Defense', rel:'neutral', job:'min_def'}],
        orders: [
          {fn:'mobiliser_armee',      label:'Mobiliser l\'armee',          pa:4, cost:0,   type:'legal',   icon:'ti-military-rank',  successRate:100, requiresPost:'min_def', desc:'Choisir une destination et donner une feuille de route secrete au Commandant.'},
          {fn:'activer_cessez_le_feu', label:'Activer un cessez-le-feu',  pa:2, cost:0,   type:'legal',   icon:'ti-handshake',      successRate:100, requiresPost:'min_def', desc:'Activer une treve deja negociee par la diplomatie. Chaque camp doit le faire de son cote.'},
          {fn:'nommer_commandant',   label:'Nommer le Commandant',       pa:2, cost:0,   type:'legal',   icon:'ti-star',           successRate:100, requiresPost:'min_def', desc:'Designer le Commandant de la Caserne.'},
          {fn:'recruter_compagnie',  label:'Recruter une compagnie',     pa:3, cost:0,   type:'legal',   icon:'ti-users-group',    successRate:100, requiresPost:'min_def', desc:'100 soldats (4 sections). Coute a la caisse de la caserne.'},
          {fn:'renseignement',        label:'Lancer une operation de renseignement', pa:3, cost:500, type:'grey', icon:'ti-spy', successRate:70, requiresPost:'min_def', desc:'Espionner un empire etranger. (Substance a venir.)'},
          {fn:'requisition_civile',  label:'Réquisition civile',        pa:3, cost:0, type:'legal', icon:'ti-users', successRate:100, requiresPost:'min_def', desc:'Tirage au sort de 24 citoyens pour doubler l\'effectif d\'une section. Uniquement pendant une mobilisation nationale.'},
          {fn:'gerer_candidature_commandant', label:'Gérer les candidatures au Commandant', pa:1, cost:0, type:'legal', icon:'ti-user-search', successRate:100, requiresPost:'min_def', desc:'Candidatures reçues pour le poste de Commandant de la Caserne — sans se déplacer.'}
        ]
      },
      bureau_min_info: {
        name: "Bureau - Ministre de l'Information",
        imageBg: "linear-gradient(135deg,#0f0808,#180f08)",
        desc: "Le bureau du Ministre de l'Information. Medias, propagande, censure.",
        imageUrl: "https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=1200&q=80",
        requiresPostId: 'min_info',
        persons: [{name:"Le Ministre de l'Information (PNJ)", role:"PNJ - Ministre de l'Information", rel:'neutral', job:'min_info'}],
        orders: [
          {fn:'propagande_etat',      label:'Campagne de propagande',       pa:3, cost:500, type:'grey',    icon:'ti-broadcast',      successRate:75,  requiresPost:'min_info', desc:'Influencer massivement l\'opinion publique. +POP.'},
          {fn:'censurer_media',       label:'Censurer un media',            pa:2, cost:0,   type:'grey',    icon:'ti-eye-off',        successRate:70,  requiresPost:'min_info', desc:'Interdire un organe de presse. -liberte +controle.'},
          {fn:'commanditer_sondage',  label:'Commanditer un sondage',       pa:1, cost:200, type:'legal',   icon:'ti-chart-bar',      successRate:100, requiresPost:'min_info', desc:'Publier un sondage favorable. +INF si bien fait.'},
          {fn:'dementi',              label:'Dementi officiel',             pa:2, cost:0,   type:'legal',   icon:'ti-x',              successRate:80,  requiresPost:'min_info', desc:'Contredire une information defavorable.'}
        ]
      },
      bureau_min_ae: {
        name: "Bureau - Ministre des Affaires Etrangeres",
        imageBg: "linear-gradient(135deg,#080a10,#0f1018)",
        desc: "Le bureau du Ministre des AE. Diplomatie, traites, relations inter-empires.",
        imageUrl: "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=1200&q=80",
        requiresPostId: 'min_ae',
        persons: [{name:'Le Ministre des Affaires Étrangères (PNJ)', role:'PNJ - Ministre des Affaires Etrangeres', rel:'neutral', job:'min_ae'}],
        orders: [
          {fn:'proposer_treve',       label:'Proposer une trêve',           pa:3, cost:0, type:'legal', icon:'ti-handshake',     successRate:100, requiresPost:'min_ae', desc:'Proposer une treve a l\'homologue d\'un empire en guerre. Si acceptee, chaque MG devra ensuite activer le cessez-le-feu de son cote.'},
          {fn:'accord_diplomatique',  label:'Ouvrir des negociations diplomatiques', pa:2, cost:0, type:'legal', icon:'ti-building-bank', successRate:80, requiresPost:'min_ae', desc:'Etablir un canal diplomatique. +8 ID.'},
          {fn:'signer_traite',        label:'Signer un traite',             pa:3, cost:0,   type:'legal',   icon:'ti-file-certificate', successRate:70, requiresPost:'min_ae', desc:'Accord bilateral avec un empire etranger.'},
          {fn:'ouvrir_ambassade',     label:'Ouvrir une ambassade',         pa:2, cost:1000,type:'legal',   icon:'ti-building',       successRate:100, requiresPost:'min_ae', desc:'Etablir une representation diplomatique.'},
          {fn:'sanctions_diplo',      label:'Imposer des sanctions',        pa:3, cost:0,   type:'legal',   icon:'ti-ban',            successRate:85,  requiresPost:'min_ae', desc:'Sanctions economiques ou diplomatiques.'},
          {fn:'reponses_diplomatiques', label:'Répondre aux propositions', pa:1, cost:0,   type:'legal',   icon:'ti-inbox',          successRate:100, requiresPost:'min_ae', desc:'Consulter et repondre aux propositions diplomatiques recues (traites, negociations).'},
          {fn:'nommer_ambassadeur_cible', label:'Nommer un ambassadeur',   pa:1, cost:0,   type:'legal',   icon:'ti-user-plus',      successRate:100, requiresPost:'min_ae', desc:'Designer un contact comme ambassadeur aupres d\'un empire.'},
          {fn:'demettre_ambassadeur_cible', label:'Démettre un ambassadeur de son poste', pa:1, cost:0, type:'legal', icon:'ti-user-minus', successRate:100, requiresPost:'min_ae', desc:'Mettre fin, avec effet immediat, a la mission de son propre ambassadeur.'},
          {fn:'expulser_ambassadeur_cible', label:'Expulser un ambassadeur', pa:2, cost:0, type:'legal', icon:'ti-passport', successRate:100, requiresPost:'min_ae', desc:'Declarer persona non grata un ambassadeur etranger present sur le territoire (24h pour quitter le pays, sous peine d\'arrestation).'}
        ]
      }
    }
  },

  // ---- ASSEMBLEE NATIONALE (capitale uniquement) ----
  'assemblee': {
    name: "Assemblee Nationale",
    shortName: "Assemblee",
    cat: "Institutions - Capitale uniquement",
    icon: "ti-building-arch",
    bgColor: "#101820",
    capitaleOnly: true,
    desc: "Les 25 sieges de l\'Assemblee Nationale de Republia. Actuellement majoritairement occupes par des PNJ.",
    rooms: {
      accueil_assemblee: {
        name: "Accueil",
        imageBg: "linear-gradient(135deg,#181410,#1f1a14)",
        desc: "Le hall d'accueil de l'Assemblee Nationale. Fresque murale, marbre et personnel en faction.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/accueil-assemblee-republic.png",
        persons: [
          {name:'Garde Republicain (PNJ)', role:'PNJ - Securite', rel:'neutral', job:'garde', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-republicain-assemblee.png'},
          {name:'Hotesse Accueil (PNJ)', role:'PNJ - Accueil', rel:'neutral', job:'hotesse_accueil', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotesse-accueil-assemblee.png'},
          {name:'Agent Entretien (PNJ)', role:'PNJ - Femme de menage', rel:'neutral', job:'femme_menage', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/agent-entretien-assemblee.png'}
        ],
        orders: [
          {fn:'calendrier_elections', label:'Calendrier electoral', pa:0, cost:0, type:'legal', icon:'ti-calendar', successRate:100, desc:'Consulter le calendrier des elections en cours et a venir.'},
          {fn:'consulter_annuaire_deputes', label:'Consulter l\'annuaire des deputes', pa:0, cost:0, type:'legal', icon:'ti-address-book', successRate:100, desc:'Liste des 25 sieges et de leurs titulaires actuels (PJ ou PNJ).'}
        ]
      },
      hemicycle: {
        name: "Hemicycle",
        image: "🗳️",
        imageBg: "linear-gradient(135deg,#101820,#182030)",
        desc: "L'hemicycle principal. Les votes se font ici. Acces deputés uniquement pour les sessions.",
        imageUrl: "https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?w=1200&q=80",
        persons: [
          {name:'President Laroche', role:"President de l\'Assemblee (PNJ)", rel:'neutral', job:'president_assemblee', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/president-assemblee-laroche.png'},
          {name:'Depute Martin',     role:'Groupe majoritaire (PNJ)', rel:'neutral', job:'depute', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/depute-majorite-martin.png'},
          {name:'Depute Chen',       role:'Opposition (PNJ)', rel:'neutral', job:'depute', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/depute-opposition-chen.png'}
        ],
        orders: [
          {fn:'observer_debats',  label:'Observer les debats',   pa:1, cost:0,   type:'legal', icon:'ti-eye',      successRate:100, desc:'Revele les positions des deputes. +1 INF pour les journalistes.'},
          {fn:'voter_loi',         label:'Voter une loi',          pa:1, cost:0,   type:'legal', icon:'ti-check',    successRate:100, requiresPost:'depute', desc:'Mercredi jusqu\'a 20h seulement. Ouvre la liste des lois en attente de vote.'},
          {fn:'projet_loi',       label:'Deposer un projet',     pa:3, cost:0,   type:'legal', icon:'ti-file-text',successRate:70,  requiresPost:true, desc:'Deposer un projet de loi.'},
          {fn:'marchander_vote', label:'Marchander un vote', pa:0, cost:200, type:'grey', icon:'ti-arrows-exchange', successRate:40, desc:'Taux 40% + bonus INF. Ouvre la liste des votes en cours. 1 PA consomme en cas de succes uniquement.'}
        ]
      },
      couloirs: {
        name: "Couloirs",
        image: "🚶",
        imageBg: "linear-gradient(135deg,#0c1018,#141820)",
        desc: "Les couloirs de l\'Assemblee. C'est ici que se font vraiment les deals.",
        imageUrl: "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=1200&q=80",
        persons: [
          {name:'Lobbyiste Perrin', role:'Lobbyiste (PNJ)', rel:'neutral', job:'lobbyiste', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/lobbyiste-perrin.png'},
          {name:'Journaliste Blanc',role:'Correspondant parlementaire (PNJ)', rel:'neutral', job:'journaliste', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/journaliste-blanc.png'}
        ],
        orders: [
          {fn:'consulter_lobbyiste', label:'Consulter le Lobbyiste', pa:1, cost:300, type:'grey', icon:'ti-handshake', successRate:100, desc:'Contre paiement, le lobbyiste vous garantit un coup de pouce (+20% de reussite) sur votre prochaine tentative de marchandage de vote.'},
          {fn:'ecouter_rumeurs', label:'Ecouter les rumeurs', pa:1, cost:0, type:'grey', icon:'ti-ear', successRate:70, desc:'Revele une information aléatoire sur un PJ ou PNJ de la ville. Generee par IA selon le contexte politique. Tres utile pour journalistes et espions.'}
        ]
      },
      salle_archives_assemblee: {
        name: "Salle des Archives",
        imageBg: "linear-gradient(135deg,#0a0808,#120f08)",
        desc: "Les archives de l\'Assemblee Nationale. Toutes les lois votees y sont conservees pendant 3 mois.",
        imageUrl: "https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80",
        persons: [
          {name:'Archiviste Parlementaire (PNJ)', role:'PNJ - Archiviste de l\'Assemblee', rel:'neutral', job:'archiviste', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/archiviste-parlementaire.png'}
        ],
        orders: [
          {fn:'consulter_archives_lois', label:'Consulter les archives', pa:0, cost:0, type:'legal', icon:'ti-archive', successRate:100, desc:'Liste des lois votees : titre, date, resultat, votes nominatifs. Archivage 3 mois.'}
        ]
      }
    }
  },

  // ---- TRIBUNAL ----
  'office-notarial': {
    name: "Office Notarial",
    shortName: "Notaire",
    cat: "Services - Capitale uniquement",
    icon: "ti-stamp",
    bgColor: "#181410",
    capitaleOnly: true,
    desc: "Le notaire de la nation. Ventes de terrain, successions, contrats de mariage — tout ce qui doit rester ecrit, ici, pour toujours.",
    rooms: {
      accueil_notaire: {
        name: "Accueil",
        image: "🖋️",
        imageBg: "linear-gradient(135deg,#181410,#241c10)",
        desc: "Le hall d'attente de l'office notarial. Boiseries sombres, silence feutre.",
        persons: [
          {name:'Alain Dex (PNJ)', role:'Secrétaire', rel:'neutral', job:'secretaire_notaire'},
          {name:'Claire Delhune (PNJ)', role:'Clerc de notaire', rel:'neutral', job:'clerc_notaire'}
        ],
        orders: [
          {fn:'consulter_dossier_notarial', label:'Se renseigner sur un dossier', pa:0, cost:0, type:'legal', icon:'ti-file-search', successRate:100, desc:'Consulter les dossiers notariaux en cours enregistres au nom d\'un personnage, le votre ou un autre.'}
        ]
      },
      bureau_successions: {
        name: "Bureau des Successions",
        image: "📜",
        imageBg: "linear-gradient(135deg,#14100c,#1c1610)",
        desc: "Le bureau ou se traitent les heritages. Les dossiers s'empilent, les familles se dechirent.",
        persons: [
          {name:'Claire Delhune (PNJ)', role:'Clerc de notaire', rel:'neutral', job:'clerc_notaire'}
        ],
        // redaction_testament/consulter_succession (ancien faux gameplay a jet) retires le 20
        // aout 2026 -- remplaces par un veritable acte notarial deterministe (chantier
        // testament/succession). Cout 1 PA/200 FR propose par analogie avec demander_divorce
        // (meme registre : acte administratif personnel majeur, deterministe, pas de jet) --
        // aucun cout canonique existant pour un testament specifiquement, a valider (voir rapport).
        orders: [
          {fn:'gerer_testament', label:'Rédiger / modifier son testament', pa:1, cost:200, type:'legal', icon:'ti-file-certificate', successRate:100, desc:'Désigner un ou plusieurs bénéficiaires pour vos terrains, entreprises et votre argent. Un acte déterministe : aucun jet, aucun échec possible.'},
          {fn:'reclamer_heritage', label:'Réclamer un héritage', pa:0, cost:0, type:'legal', icon:'ti-file-import', successRate:100, desc:'Consulter les successions ouvertes ou vous êtes concerné, et répondre aux dispositions qui vous concernent. Gratuit, déterministe : aucun jet.'}
        ]
      },
      bureau_contrats: {
        name: "Bureau des Contrats",
        image: "📝",
        imageBg: "linear-gradient(135deg,#100e0a,#181410)",
        desc: "Ventes de terrain, contrats de mariage — tout ce qui engage, se signe ici.",
        persons: [
          {name:'Notaire Fontenelle (PNJ)', role:'Notaire Officiel', rel:'neutral', job:'notaire'}
        ],
        orders: [
          {fn:'acte_vente_terrain', label:'Officialiser une vente de terrain', pa:1, cost:300, type:'legal', icon:'ti-home-check', successRate:100, desc:'Le notaire authentifie la transaction. Acte de propriete delivre.'},
          {fn:'racheter_entreprise', label:'Racheter une entreprise', pa:0, cost:0, type:'legal', icon:'ti-building-store', successRate:100, desc:'Signer un compromis (1000 FR d\'acompte, 7 jours) sur une entreprise encore tenue par un PNJ (Armurerie, et d\'autres a l\'avenir).'},
          {fn:'acte_rachat_entreprise', label:'Officialiser le rachat d\'une entreprise', pa:1, cost:0, type:'legal', icon:'ti-building-store', successRate:100, desc:'Finalise un compromis de rachat actif : paiement du solde, transfert de propriete. Acte authentifie par le notaire.'},
          {fn:'acte_rachat_entreprise_preemption', label:'Officialiser une preemption d\'Etat', pa:1, cost:0, type:'legal', icon:'ti-building-bank', successRate:100, requiresPost:'min_fin', desc:'Finalise une preemption en attente : transfert de propriete a l\'Etat. Aucun paiement ici, deja couvert par le pret.'},
          {fn:'transferer_compromis', label:'Transférer un compromis', pa:1, cost:0, type:'legal', icon:'ti-transfer', successRate:100, desc:'Céder votre compromis en cours à un autre joueur, qui devra venir valider.'},
          {fn:'valider_transfert_compromis', label:'Valider un transfert de compromis', pa:1, cost:0, type:'legal', icon:'ti-checkbox', successRate:100, desc:'Accepter un compromis qu\'un autre joueur vous a proposé de reprendre.'},
          {fn:'demander_divorce', label:'Demander le divorce', pa:1, cost:200, type:'legal', icon:'ti-heart-broken', successRate:100, desc:'Dissout votre mariage actuel. Votre conjoint en sera informé par mail.'}
        ]
      },
      archives_notariales: {
        name: "Archives Notariales",
        image: "🏛️",
        imageBg: "linear-gradient(135deg,#0c0a08,#141008)",
        desc: "La memoire ecrite de la nation. Chaque acte de propriete, chaque mariage, chaque succession, depuis l'origine. Rien ne s'efface jamais ici.",
        persons: [
          {name:'Archiviste Notarial (PNJ)', role:'PNJ - Gardien des Archives', rel:'neutral', job:'archiviste_notaire'}
        ],
        orders: [
          {fn:'consulter_archives_notariales', label:'Consulter les archives notariales', pa:0, cost:0, type:'legal', icon:'ti-archive', successRate:100, desc:'Historique complet et permanent des biens, mariages et successions. Recherche par nom de personnage.'}
        ]
      }
    }
  },
  'stade': {
    name: "Stade Municipal",
    shortName: "Stade",
    cat: "Sport & Loisirs",
    icon: "ti-ball-football",
    bgColor: "#101812",
    capitaleOnly: false,
    desc: "Le stade de la ville. Le club local y joue, y gagne, y perd — et ses supporters ne l'oublient jamais.",
    rooms: {
      terrain: {
        name: "Terrain",
        image: "⚽",
        imageBg: "linear-gradient(135deg,#0e1810,#12201a)",
        desc: "La pelouse principale. Vide en semaine, pleine a craquer les jours de match.",
        persons: [
          {name:'Entraineur Local (PNJ)', role:'PNJ - Entraineur', rel:'neutral', job:'entraineur'},
          {name:'Commentateur Sportif (PNJ)', role:'PNJ - Commentateur', rel:'neutral', job:'commentateur'}
        ],
        orders: [
          {fn:'observer_match', label:'Consulter le calendrier et le classement', pa:0, cost:0, type:'legal', icon:'ti-eye', successRate:100, desc:'Calendrier complet de la saison, resultats, et classement du championnat.'},
          {fn:'regarder_live', label:'Suivre le foot', pa:0, cost:0, type:'legal', icon:'ti-device-tv', successRate:100, desc:'Match en cours : rejoint le direct, synchronise pour tous les spectateurs. Sinon : resume du dernier match joue. Gratuit.'}
        ]
      },
      vestiaires: {
        name: "Vestiaires",
        image: "👕",
        imageBg: "linear-gradient(135deg,#0c0e10,#141818)",
        desc: "Reserve aux membres du club sportif. Odeur de liniment et de victoire (ou de defaite).",
        persons: [
          {name:'Entraineur Local (PNJ)', role:'PNJ - Entraineur', rel:'neutral', job:'entraineur'}
        ],
        orders: [
          {fn:'prendre_licence_sportive', label:'Prendre sa licence sportive', pa:1, cost:150, type:'legal', icon:'ti-license', successRate:100, desc:'Seule condition pour s\'entrainer ou jouer. 150 FR. Valable une saison, renouvelée tacitement dans le même club (voir "Ne pas renouveler ma licence" pour s\'y opposer).'},
          {fn:'demander_non_renouvellement_licence', label:'Ne pas renouveler ma licence', pa:1, cost:0, type:'legal', icon:'ti-license-off', successRate:100, desc:'Vous terminez normalement la saison dans votre club. Au changement de saison, votre licence expire sans frais, suivie d\'une année blanche sans club.'},
          {fn:'annuler_non_renouvellement_licence', label:'Annuler la demande de non-renouvellement', pa:0, cost:0, type:'legal', icon:'ti-license', successRate:100, desc:'Votre licence sera de nouveau renouvelée tacitement au changement de saison.'},
          {fn:'tenue_entrainement', label:"Mettre la tenue d'entraînement", pa:2, cost:0, type:'legal', icon:'ti-run', successRate:100, desc:'S\'entrainer (Defense/Technique/Endurance). Maximum 2 par jour. Risque de blessure legere.'},
          {fn:'tenue_match', label:'Mettre la tenue de match', pa:0, cost:0, type:'legal', icon:'ti-shirt-sport', successRate:100, desc:'Repartir librement ses points de performance avant le prochain match.'},
          {fn:'conseil_entraineur_adjoint', label:"Demander conseil à l'entraîneur adjoint", pa:0, cost:0, type:'legal', icon:'ti-message-2', successRate:100, desc:'Ce qu\'il vous manque pour integrer les quinze, et sur quelle qualite se concentrer.'}
        ]
      },
      buvette: {
        name: "Buvette",
        image: "🍺",
        imageBg: "linear-gradient(135deg,#141008,#1c1608)",
        desc: "On y refait le match d'avant en attendant le suivant. Biere tiede, ambiance chaude.",
        persons: [
          {name:'Tenancier de Buvette (PNJ)', role:'PNJ - Buvette', rel:'neutral', job:'serveur'}
        ],
        orders: [
          {fn:'consommer_buvette', label:'Prendre un verre', pa:1, cost:50, type:'legal', icon:'ti-beer', successRate:100, desc:'Un moment convivial entre supporters. Leger gain de popularite.'},
          {fn:'produire_commerce', label:'Servir', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Preparer bieres, boissons et snacks pour le service (consomme le stock, remunere en FR).'},
          {fn:'consulter_carte_commerce', label:'Consulter la carte', pa:1, cost:0, type:'legal', icon:'ti-menu-2', successRate:100, desc:'Voir ce qui est disponible au comptoir et commander.'},
          {fn:'vendre_matiere_commerce', label:'Vendre des matières au commerce', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les matières premières de votre inventaire à ce commerce.'},
          {fn:'choisir_accessoire_club', label:'Acheter un accessoire', pa:1, cost:0, type:'legal', icon:'ti-shirt', successRate:100, desc:'Echarpe, casquette ou maillot du club — a choisir.'},
          {fn:'acheter_accessoire_personnalise', label:'Acheter un accessoire personnalisé', pa:0, cost:0, type:'legal', icon:'ti-lock', successRate:100, desc:'Personnalisation (nom, numero) — reserve aux comptes premium. Bientot disponible.'}
        ]
      },
      guichet_paris: {
        name: "Guichet de Paris",
        image: "🎫",
        imageBg: "linear-gradient(135deg,#100c14,#181020)",
        desc: "Ici, on parie sur tout : le score, le premier but, le carton rouge. Legal, mais pas toujours honnete.",
        persons: [
          {name:'Bookmaker Officiel (PNJ)', role:'PNJ - Paris Sportifs', rel:'neutral', job:'bookmaker'}
        ],
        orders: [
          {fn:'parier_match', label:'Parier sur un match', pa:1, cost:0, type:'legal', icon:'ti-coin', successRate:100, desc:'Consultation gratuite -- vous choisirez ensuite votre mise (100 FR minimum).'},
          {fn:'consulter_classement_joueurs_club', label:'Connaître le classement des joueurs du club', pa:0, cost:75, type:'legal', icon:'ti-list-numbers', successRate:100, desc:'Classement complet des joueurs licencies de CE club. Deplacement necessaire pour consulter un club adverse.'}
        ]
      },
      siege_supporters: {
        name: "Siege des Supporters",
        image: "🧣",
        imageBg: "linear-gradient(135deg,#0e1218,#141c24)",
        desc: "Le QG du club de supporters. Banderoles, chants appris par coeur, et une memoire collective qui ne s'efface jamais.",
        persons: [
          {name:'Meneur des Supporters (PNJ)', role:'PNJ - Chef de Tribune', rel:'neutral', job:'meneur_supporters'}
        ],
        orders: [
          {fn:'rejoindre_club_supporters', label:'Rejoindre le club de supporters', pa:1, cost:50, type:'legal', icon:'ti-users-group', successRate:100, desc:'Adherer au club de supporters de la ville (50 FR, renouvele automatiquement a chaque nouveau championnat).'},
          {fn:'consulter_palmares', label:'Consulter le palmares du championnat', pa:0, cost:0, type:'legal', icon:'ti-archive', successRate:100, desc:'Historique complet et permanent du championnat (les 12 clubs de Republia et des autres nations) : chaque saison couronnee reste consultable ici, quel que soit le club depuis lequel vous consultez.'},
          {fn:'consulter_organigramme_supporters', label:'Consulter l\'organigramme', pa:0, cost:0, type:'legal', icon:'ti-sitemap', successRate:100, desc:'Composition complete du club de supporters, visible de tous.'},
          {fn:'declencher_election_club', label:'Déclencher une élection', pa:1, cost:0, type:'legal', icon:'ti-ballot', successRate:100, desc:'Reserve aux membres. 3 jours de candidatures puis 3 jours de vote.'},
          {fn:'organiser_manifestation', label:'Organiser une manifestation', pa:2, cost:0, type:'legal', icon:'ti-megaphone', successRate:100, desc:'Reserve au president. Pour ou contre le maire. Intensite liee au nombre de membres.'},
          {fn:'organiser_boycott', label:'Organiser un boycott', pa:2, cost:0, type:'legal', icon:'ti-ban', successRate:100, desc:'Reserve au president. Boycotte le prochain match a domicile.'}
        ]
      },
      bureau_president: {
        name: "Bureau du Président",
        image: "🏢",
        imageBg: "linear-gradient(135deg,#10120e,#181c14)",
        desc: "Le bureau du president du club sportif. Vacant si personne n'a ete elu.",
        persons: [],
        orders: [
          {fn:'postuler_president_club', label:'Postuler au poste de président', pa:2, cost:0, type:'legal', icon:'ti-briefcase', successRate:100, desc:'Vote a 3 (chef supporters, maire, capitaine). 48h, silence = accord.'},
          {fn:'consulter_bureau_president', label:'Consulter le bureau', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100, desc:'President actuel, election en cours, voter si concerne.'},
          {fn:'proposer_transfert', label:'Proposer un transfert', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100, desc:'Reserve au president. Debaucher un joueur d\'un autre club.'},
          {fn:'gerer_offres_transfert', label:'Gérer les offres reçues', pa:0, cost:0, type:'legal', icon:'ti-inbox', successRate:100, desc:'Reserve au president. Accepter, refuser ou contre-offrir.'},
          {fn:'sponsoriser_club', label:'Sponsoriser le club', pa:1, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Associer votre nom au club en echange d\'un soutien financier. Trois paliers.'},
          {fn:'consulter_budget_club', label:'Consulter le budget du club', pa:0, cost:0, type:'legal', icon:'ti-report-money', successRate:100, desc:'Caisse et dernieres operations financieres du club.'},
          {fn:'gerer_salaires_club', label:'Gérer les salaires des joueurs', pa:0, cost:0, type:'legal', icon:'ti-cash-banknote', successRate:100, desc:'Reserve au president. Forfait titulaire/remplacant, prime de victoire.'}
        ]
      }
    }
  },
  'zone-production': {
    name: "Zone de Production",
    shortName: "Production",
    cat: "Économie - Matières premières",
    icon: "ti-tractor",
    bgColor: "#0e1208",
    capitaleOnly: false,
    desc: "Le lieu ou la ville produit ses richesses naturelles.",
    rooms: {
      zone_recolte: {
        name: "Zone de Récolte",
        image: "🌾",
        imageBg: "linear-gradient(135deg,#0e1208,#141c0a)",
        desc: "Champs, mines ou forets selon la vocation de la ville. Les matieres premieres locales s'y recoltent.",
        persons: [],
        orders: [
          {fn:'recolter_matiere', label:'Récolter', pa:2, cost:0, type:'legal', icon:'ti-shovel', successRate:100, desc:'Recolter une matiere premiere locale. Maximum 2 fois par jour.'}
        ]
      }
    }
  },
  'tribunal': {
    name: "Tribunal de la Capitale",
    shortName: "Tribunal",
    cat: "Justice - Capitale uniquement",
    icon: "ti-gavel",
    bgColor: "#1a1408",
    capitaleOnly: true,
    desc: "La justice de Republia est formellement independante. Ce qui ne veut pas dire incorruptible.",
    rooms: {
      salle_audience: {
        name: "Salle d'audience",
        image: "⚖️",
        imageBg: "linear-gradient(135deg,#1a1408,#24180a)",
        desc: "La salle d'audience principale. Solennelle et intimidante.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tribunal-salle-audience.png",
        persons: [
          {name:'Juge Fontaine',  role:'Presidente du Tribunal (PNJ)', rel:'neutral', job:'juge'},
          {name:'Procureur Saad', role:'Ministere public (PNJ)', rel:'neutral', job:'procureur'}
        ],
        orders: [
          {fn:'plainte',   label:'Consulter les affaires en cours', pa:1, cost:0,   type:'legal',   icon:'ti-gavel',   successRate:100, desc:'Voir le statut des affaires en cours : en attente de traitement, enquete en cours, transmise au tribunal, jugee.'},
          {fn:'defense',   label:'Se defendre',           pa:2, cost:300, type:'legal',   icon:'ti-shield',  successRate:50, desc:'Taux : 50% de base + CHA - malus si preuve reelle contre vous. Reussite eclatante = affaire classee ; reussite simple = circonstance attenuante ; echec flagrant = aggravation.'}
        ]
      },
      greffe: {
        name: "Greffe",
        image: "📋",
        imageBg: "linear-gradient(135deg,#141008,#1c1608)",
        desc: "Les archives judiciaires. Tout y est consigne.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tribunal-greffe.png",
        persons: [
          {name:'Greffier Petit', role:'PNJ - Greffe', rel:'neutral', job:'greffier'}
        ],
        orders: [
          {fn:'archives',       label:'Consulter les archives', pa:1, cost:0,   type:'legal',   icon:'ti-archive', successRate:100},
          {fn:'falsifier_document', label:'Falsifier un document', pa:3, cost:300, type:'illegal', icon:'ti-file-x', successRate:45, desc:'Liste : fausse identite, faux casier vierge, faux permis construire, faux contrat. Cree un objet en inventaire.'},
          {fn:'demander_juge_instruction', label:'Demander à parler à un juge', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Présenter votre dossier d\'enquête à un juge.'}
        ]
      }
    }
  },

  // ---- BANQUE NATIONALE ----
  'banque-nationale': {
    name: "Banque Nationale de Republia",
    shortName: "Banque Nationale",
    cat: "Finance",
    icon: "ti-building-bank",
    bgColor: "#100f08",
    desc: "La banque centrale officielle. Toutes les transactions sont tracables et fiscalisees.",
    rooms: {
      accueil_banque: {
        name: "Accueil",
        image: "🏦",
        imageBg: "linear-gradient(135deg,#100f08,#1a1a0a)",
        desc: "L'accueil de la banque nationale. Propre, froid, officiel.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/banque-nationale-accueil.png",
        persons: [
          {name:'Laurent Barre', role:"PNJ - Directeur d'agence", rel:'neutral', job:'directeur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/laurent-barre.png', photoPos:'65% 30%'}
        ],
        orders: [
          {fn:'gerer_finances', label:'Gerer mon compte',    pa:0, cost:0,    type:'legal', icon:'ti-chart-bar',   successRate:100, desc:'Deposer ou retirer de l\'argent. Voir son solde.'},
          {fn:'investir',       label:'Investir',            pa:1, cost:0,  type:'legal', icon:'ti-trending-up', successRate:100, desc:'Placer un montant libre (min. 500 FR). Immobilise 7 jours, rendement entre -12% et +12% selon la conjoncture economique locale.'},
          {fn:'emprunter',      label:'Emprunter',           pa:1, cost:0,    type:'legal', icon:'ti-credit-card', successRate:70,  desc:'Contracter un pret. Taux selon dossier.'},
          {fn:'fiscal',         label:'Optimisation fiscale',pa:1, cost:200,  type:'grey',  icon:'ti-calculator',  successRate:85,  desc:'Reduire sa fiscalite. Semi-legal.'},
          {fn:'presenter_autorisation_coffre', label:'Présenter une autorisation judiciaire', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Accéder à un coffre grâce à une autorisation du juge.'}
        ]
      },
      coffre_privatif: {
        name: "Coffre Privatif — Local à louer",
        imageBg: "linear-gradient(135deg,#050810,#0a0f15)",
        desc: "📋 À LOUER — Espace sécurisé dans les sous-sols de la banque. Accès biométrique, surveillance 24h. Le Directeur Barre ne pose jamais de questions sur le contenu.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/banque-nationale-coffres.png",
        isLocationRoom: true,
        locationData: { prix: 600, bonusPOP: 0, bonusINF: 4, bonusDIS: 12, label: 'Coffre Privatif', tier: 1 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce coffre (600 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+12 DIS +4 INF. Vos secrets en sécurité absolue.'},
          {fn:'gerer_finances', label:'Gérer mes finances', pa:1, cost:0, type:'legal', icon:'ti-chart-bar', successRate:100},
          {fn:'gerer_local', label:'Gérer mon coffre', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      }
    }
  },

  // ---- BANQUE PRIVEE ----
  'banque-privee': {
    name: "Banque Privee Helvetia",
    shortName: "Banque Privee",
    cat: "Finance discrete",
    icon: "ti-safe",
    bgColor: "#0d0d08",
    desc: "Discrete, efficace, pas de questions posees. Pour les operations que la banque nationale ne ferait pas.",
    rooms: {
      bureau_prive: {
        name: "Bureau prive",
        image: "🔐",
        imageBg: "linear-gradient(135deg,#0d0d08,#181408)",
        desc: "Un bureau feutre ou tout se passe dans la plus grande discret.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/banque-privee-helvetia-bureau.png",
        persons: [
          {name:'M. Fischer', role:'PNJ - Gestionnaire de patrimoine', rel:'neutral', job:'banquier'}
        ],
        orders: [
          {fn:'gerer_finances',    label:'Gerer mon compte',      pa:0, cost:0,    type:'legal',   icon:'ti-chart-bar',    successRate:100, desc:'Compte, depot, retrait et placements Helvetia.'},
          {fn:'compte_offshore',   label:'Placements et optimisation fiscale', pa:0, cost:0, type:'legal', icon:'ti-world', successRate:100, desc:'Placements declares et offshore avec Ursula Offshore.'},
          {fn:'emprunter_prive',   label:'Emprunter (sans verification)', pa:1, cost:0, type:'grey', icon:'ti-credit-card', successRate:100, desc:'Aucune verification. Taux eleve. Methode de recouvrement... directe en cas d\'impaye.'},
          {fn:'blanchiment',       label:'Blanchir des fonds',     pa:0, cost:0,    type:'illegal', icon:'ti-refresh',      successRate:100, desc:'Service a l\'etude. Pas encore disponible.'},
          {fn:'societe_ecran',     label:'Creer une societe ecran',pa:0, cost:0,    type:'illegal', icon:'ti-building-off', successRate:100, desc:'Service a l\'etude. Pas encore disponible.'}
        ]
      }
    }
  },

  // ---- CLINIQUE PRIVEE ----
  'clinique-privee': {
    name: "Clinique Privee Saint-Luc",
    shortName: "Clinique Privee",
    cat: "Sante (premium)",
    icon: "ti-heart-rate-monitor",
    bgColor: "#080f10",
    desc: "Soins rapides, discrets et efficaces. Prix en consequence.",
    rooms: {
      reception_clinique: {
        name: "Reception",
        image: "🏥",
        imageBg: "linear-gradient(135deg,#080f10,#0c1618)",
        desc: "Reception moderne et discrete. Personnel forme a la confidentialite.",
        imageUrl: "images/luthecia-clinique-accueil.jpg",
        persons: [
          {name:'Dr. Vidal', role:'PNJ - Medecin chef', rel:'neutral', job:'medecin'}
        ],
        orders: [
          {fn:'vendre_ressource_medicale', label:'Fournir des ressources médicales', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre à la clinique, depuis votre inventaire, du desinfectant ou des medicaments.'},
          {fn:'ouvrir_chambres_clinique', label:'Chambres', pa:0, cost:0, type:'legal', icon:'ti-door-enter', successRate:100, desc:'Rejoindre votre chambre, ou rendre visite a un patient qui accepte les visites.'}
        ]
      },
      // Pool de 10 chambres individuelles (lot chambres, 20 aout 2026) -- remplace l'unique
      // room generique "chambre" du lot precedent. Chacune est une room distincte
      // (chambre_1..chambre_10) attribuee a UN SEUL patient a la fois via locations_actives
      // (doTransfertCliniquePrivee, plateau-personnage.js) : deux patients simultanes ne
      // partagent jamais le meme roomId.
      // Les 5 soins deplaces depuis reception_clinique (finalisation chambres clinique, 31 aout
      // 2026, demande explicite de Fred) : fn/pa/cost/type/icon/successRate/desc strictement
      // inchanges (aucun rééquilibrage), identiques sur les 10 chambres. Reservés au patient
      // auquel la chambre est attribuee -- verifie par estOrdreMedicalReserveAuPatient
      // (plateau-personnage.js), applique a la fois en affichage (plateau-politique.js) et en
      // execution (plateau-router.js), jamais dans data.js.
      chambre_1:  { name: "Chambre 1",  image: "🛏️", imageBg: "linear-gradient(135deg,#080f10,#0c1618)", desc: "Une chambre privee, calme et confortable, reservee aux patients pris en charge.", imageUrl: "images/luthecia-clinique-chambre.jpg", persons: [], orders: [
        {fn:'gerer_visites_chambre', label:'Autoriser / Interdire les visites', pa:0, cost:0, type:'legal', icon:'ti-door', successRate:100, desc:'Choisir si les autres joueurs peuvent vous rendre visite dans cette chambre.'},
        {fn:'soins',          label:'Soin standard',              pa:0, cost:100, type:'legal', icon:'ti-stethoscope', successRate:100, desc:'+30 Sante, +2 PA immediats. 1 fois par jour. Consomme 1 desinfectant + 1 medicament du stock de la clinique.'},
        {fn:'soins_urgence',  label:'Soins acceleres (urgence)',   pa:0, cost:500, type:'legal', icon:'ti-urgent',      successRate:100, desc:'+40 Sante immediatement.'},
        {fn:'soins_discrets', label:'Soins sans trace',            pa:1, cost:800, type:'grey',  icon:'ti-eye-off',     successRate:95,  desc:'+30 Sante. Aucune trace medicale.'},
        {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:150, type:'legal', icon:'ti-vaccine', successRate:85, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
        {fn:'se_nourrir', label:'Manger', pa:1, cost:30, type:'legal', icon:'ti-soup', successRate:100, desc:'Un repas de qualite, servi au chevet.'}
      ] },
      chambre_2:  { name: "Chambre 2",  image: "🛏️", imageBg: "linear-gradient(135deg,#080f10,#0c1618)", desc: "Une chambre privee, calme et confortable, reservee aux patients pris en charge.", imageUrl: "images/luthecia-clinique-chambre.jpg", persons: [], orders: [
        {fn:'gerer_visites_chambre', label:'Autoriser / Interdire les visites', pa:0, cost:0, type:'legal', icon:'ti-door', successRate:100, desc:'Choisir si les autres joueurs peuvent vous rendre visite dans cette chambre.'},
        {fn:'soins',          label:'Soin standard',              pa:0, cost:100, type:'legal', icon:'ti-stethoscope', successRate:100, desc:'+30 Sante, +2 PA immediats. 1 fois par jour. Consomme 1 desinfectant + 1 medicament du stock de la clinique.'},
        {fn:'soins_urgence',  label:'Soins acceleres (urgence)',   pa:0, cost:500, type:'legal', icon:'ti-urgent',      successRate:100, desc:'+40 Sante immediatement.'},
        {fn:'soins_discrets', label:'Soins sans trace',            pa:1, cost:800, type:'grey',  icon:'ti-eye-off',     successRate:95,  desc:'+30 Sante. Aucune trace medicale.'},
        {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:150, type:'legal', icon:'ti-vaccine', successRate:85, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
        {fn:'se_nourrir', label:'Manger', pa:1, cost:30, type:'legal', icon:'ti-soup', successRate:100, desc:'Un repas de qualite, servi au chevet.'}
      ] },
      chambre_3:  { name: "Chambre 3",  image: "🛏️", imageBg: "linear-gradient(135deg,#080f10,#0c1618)", desc: "Une chambre privee, calme et confortable, reservee aux patients pris en charge.", imageUrl: "images/luthecia-clinique-chambre.jpg", persons: [], orders: [
        {fn:'gerer_visites_chambre', label:'Autoriser / Interdire les visites', pa:0, cost:0, type:'legal', icon:'ti-door', successRate:100, desc:'Choisir si les autres joueurs peuvent vous rendre visite dans cette chambre.'},
        {fn:'soins',          label:'Soin standard',              pa:0, cost:100, type:'legal', icon:'ti-stethoscope', successRate:100, desc:'+30 Sante, +2 PA immediats. 1 fois par jour. Consomme 1 desinfectant + 1 medicament du stock de la clinique.'},
        {fn:'soins_urgence',  label:'Soins acceleres (urgence)',   pa:0, cost:500, type:'legal', icon:'ti-urgent',      successRate:100, desc:'+40 Sante immediatement.'},
        {fn:'soins_discrets', label:'Soins sans trace',            pa:1, cost:800, type:'grey',  icon:'ti-eye-off',     successRate:95,  desc:'+30 Sante. Aucune trace medicale.'},
        {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:150, type:'legal', icon:'ti-vaccine', successRate:85, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
        {fn:'se_nourrir', label:'Manger', pa:1, cost:30, type:'legal', icon:'ti-soup', successRate:100, desc:'Un repas de qualite, servi au chevet.'}
      ] },
      chambre_4:  { name: "Chambre 4",  image: "🛏️", imageBg: "linear-gradient(135deg,#080f10,#0c1618)", desc: "Une chambre privee, calme et confortable, reservee aux patients pris en charge.", imageUrl: "images/luthecia-clinique-chambre.jpg", persons: [], orders: [
        {fn:'gerer_visites_chambre', label:'Autoriser / Interdire les visites', pa:0, cost:0, type:'legal', icon:'ti-door', successRate:100, desc:'Choisir si les autres joueurs peuvent vous rendre visite dans cette chambre.'},
        {fn:'soins',          label:'Soin standard',              pa:0, cost:100, type:'legal', icon:'ti-stethoscope', successRate:100, desc:'+30 Sante, +2 PA immediats. 1 fois par jour. Consomme 1 desinfectant + 1 medicament du stock de la clinique.'},
        {fn:'soins_urgence',  label:'Soins acceleres (urgence)',   pa:0, cost:500, type:'legal', icon:'ti-urgent',      successRate:100, desc:'+40 Sante immediatement.'},
        {fn:'soins_discrets', label:'Soins sans trace',            pa:1, cost:800, type:'grey',  icon:'ti-eye-off',     successRate:95,  desc:'+30 Sante. Aucune trace medicale.'},
        {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:150, type:'legal', icon:'ti-vaccine', successRate:85, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
        {fn:'se_nourrir', label:'Manger', pa:1, cost:30, type:'legal', icon:'ti-soup', successRate:100, desc:'Un repas de qualite, servi au chevet.'}
      ] },
      chambre_5:  { name: "Chambre 5",  image: "🛏️", imageBg: "linear-gradient(135deg,#080f10,#0c1618)", desc: "Une chambre privee, calme et confortable, reservee aux patients pris en charge.", imageUrl: "images/luthecia-clinique-chambre.jpg", persons: [], orders: [
        {fn:'gerer_visites_chambre', label:'Autoriser / Interdire les visites', pa:0, cost:0, type:'legal', icon:'ti-door', successRate:100, desc:'Choisir si les autres joueurs peuvent vous rendre visite dans cette chambre.'},
        {fn:'soins',          label:'Soin standard',              pa:0, cost:100, type:'legal', icon:'ti-stethoscope', successRate:100, desc:'+30 Sante, +2 PA immediats. 1 fois par jour. Consomme 1 desinfectant + 1 medicament du stock de la clinique.'},
        {fn:'soins_urgence',  label:'Soins acceleres (urgence)',   pa:0, cost:500, type:'legal', icon:'ti-urgent',      successRate:100, desc:'+40 Sante immediatement.'},
        {fn:'soins_discrets', label:'Soins sans trace',            pa:1, cost:800, type:'grey',  icon:'ti-eye-off',     successRate:95,  desc:'+30 Sante. Aucune trace medicale.'},
        {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:150, type:'legal', icon:'ti-vaccine', successRate:85, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
        {fn:'se_nourrir', label:'Manger', pa:1, cost:30, type:'legal', icon:'ti-soup', successRate:100, desc:'Un repas de qualite, servi au chevet.'}
      ] },
      chambre_6:  { name: "Chambre 6",  image: "🛏️", imageBg: "linear-gradient(135deg,#080f10,#0c1618)", desc: "Une chambre privee, calme et confortable, reservee aux patients pris en charge.", imageUrl: "images/luthecia-clinique-chambre.jpg", persons: [], orders: [
        {fn:'gerer_visites_chambre', label:'Autoriser / Interdire les visites', pa:0, cost:0, type:'legal', icon:'ti-door', successRate:100, desc:'Choisir si les autres joueurs peuvent vous rendre visite dans cette chambre.'},
        {fn:'soins',          label:'Soin standard',              pa:0, cost:100, type:'legal', icon:'ti-stethoscope', successRate:100, desc:'+30 Sante, +2 PA immediats. 1 fois par jour. Consomme 1 desinfectant + 1 medicament du stock de la clinique.'},
        {fn:'soins_urgence',  label:'Soins acceleres (urgence)',   pa:0, cost:500, type:'legal', icon:'ti-urgent',      successRate:100, desc:'+40 Sante immediatement.'},
        {fn:'soins_discrets', label:'Soins sans trace',            pa:1, cost:800, type:'grey',  icon:'ti-eye-off',     successRate:95,  desc:'+30 Sante. Aucune trace medicale.'},
        {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:150, type:'legal', icon:'ti-vaccine', successRate:85, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
        {fn:'se_nourrir', label:'Manger', pa:1, cost:30, type:'legal', icon:'ti-soup', successRate:100, desc:'Un repas de qualite, servi au chevet.'}
      ] },
      chambre_7:  { name: "Chambre 7",  image: "🛏️", imageBg: "linear-gradient(135deg,#080f10,#0c1618)", desc: "Une chambre privee, calme et confortable, reservee aux patients pris en charge.", imageUrl: "images/luthecia-clinique-chambre.jpg", persons: [], orders: [
        {fn:'gerer_visites_chambre', label:'Autoriser / Interdire les visites', pa:0, cost:0, type:'legal', icon:'ti-door', successRate:100, desc:'Choisir si les autres joueurs peuvent vous rendre visite dans cette chambre.'},
        {fn:'soins',          label:'Soin standard',              pa:0, cost:100, type:'legal', icon:'ti-stethoscope', successRate:100, desc:'+30 Sante, +2 PA immediats. 1 fois par jour. Consomme 1 desinfectant + 1 medicament du stock de la clinique.'},
        {fn:'soins_urgence',  label:'Soins acceleres (urgence)',   pa:0, cost:500, type:'legal', icon:'ti-urgent',      successRate:100, desc:'+40 Sante immediatement.'},
        {fn:'soins_discrets', label:'Soins sans trace',            pa:1, cost:800, type:'grey',  icon:'ti-eye-off',     successRate:95,  desc:'+30 Sante. Aucune trace medicale.'},
        {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:150, type:'legal', icon:'ti-vaccine', successRate:85, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
        {fn:'se_nourrir', label:'Manger', pa:1, cost:30, type:'legal', icon:'ti-soup', successRate:100, desc:'Un repas de qualite, servi au chevet.'}
      ] },
      chambre_8:  { name: "Chambre 8",  image: "🛏️", imageBg: "linear-gradient(135deg,#080f10,#0c1618)", desc: "Une chambre privee, calme et confortable, reservee aux patients pris en charge.", imageUrl: "images/luthecia-clinique-chambre.jpg", persons: [], orders: [
        {fn:'gerer_visites_chambre', label:'Autoriser / Interdire les visites', pa:0, cost:0, type:'legal', icon:'ti-door', successRate:100, desc:'Choisir si les autres joueurs peuvent vous rendre visite dans cette chambre.'},
        {fn:'soins',          label:'Soin standard',              pa:0, cost:100, type:'legal', icon:'ti-stethoscope', successRate:100, desc:'+30 Sante, +2 PA immediats. 1 fois par jour. Consomme 1 desinfectant + 1 medicament du stock de la clinique.'},
        {fn:'soins_urgence',  label:'Soins acceleres (urgence)',   pa:0, cost:500, type:'legal', icon:'ti-urgent',      successRate:100, desc:'+40 Sante immediatement.'},
        {fn:'soins_discrets', label:'Soins sans trace',            pa:1, cost:800, type:'grey',  icon:'ti-eye-off',     successRate:95,  desc:'+30 Sante. Aucune trace medicale.'},
        {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:150, type:'legal', icon:'ti-vaccine', successRate:85, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
        {fn:'se_nourrir', label:'Manger', pa:1, cost:30, type:'legal', icon:'ti-soup', successRate:100, desc:'Un repas de qualite, servi au chevet.'}
      ] },
      chambre_9:  { name: "Chambre 9",  image: "🛏️", imageBg: "linear-gradient(135deg,#080f10,#0c1618)", desc: "Une chambre privee, calme et confortable, reservee aux patients pris en charge.", imageUrl: "images/luthecia-clinique-chambre.jpg", persons: [], orders: [
        {fn:'gerer_visites_chambre', label:'Autoriser / Interdire les visites', pa:0, cost:0, type:'legal', icon:'ti-door', successRate:100, desc:'Choisir si les autres joueurs peuvent vous rendre visite dans cette chambre.'},
        {fn:'soins',          label:'Soin standard',              pa:0, cost:100, type:'legal', icon:'ti-stethoscope', successRate:100, desc:'+30 Sante, +2 PA immediats. 1 fois par jour. Consomme 1 desinfectant + 1 medicament du stock de la clinique.'},
        {fn:'soins_urgence',  label:'Soins acceleres (urgence)',   pa:0, cost:500, type:'legal', icon:'ti-urgent',      successRate:100, desc:'+40 Sante immediatement.'},
        {fn:'soins_discrets', label:'Soins sans trace',            pa:1, cost:800, type:'grey',  icon:'ti-eye-off',     successRate:95,  desc:'+30 Sante. Aucune trace medicale.'},
        {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:150, type:'legal', icon:'ti-vaccine', successRate:85, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
        {fn:'se_nourrir', label:'Manger', pa:1, cost:30, type:'legal', icon:'ti-soup', successRate:100, desc:'Un repas de qualite, servi au chevet.'}
      ] },
      chambre_10: { name: "Chambre 10", image: "🛏️", imageBg: "linear-gradient(135deg,#080f10,#0c1618)", desc: "Une chambre privee, calme et confortable, reservee aux patients pris en charge.", imageUrl: "images/luthecia-clinique-chambre.jpg", persons: [], orders: [
        {fn:'gerer_visites_chambre', label:'Autoriser / Interdire les visites', pa:0, cost:0, type:'legal', icon:'ti-door', successRate:100, desc:'Choisir si les autres joueurs peuvent vous rendre visite dans cette chambre.'},
        {fn:'soins',          label:'Soin standard',              pa:0, cost:100, type:'legal', icon:'ti-stethoscope', successRate:100, desc:'+30 Sante, +2 PA immediats. 1 fois par jour. Consomme 1 desinfectant + 1 medicament du stock de la clinique.'},
        {fn:'soins_urgence',  label:'Soins acceleres (urgence)',   pa:0, cost:500, type:'legal', icon:'ti-urgent',      successRate:100, desc:'+40 Sante immediatement.'},
        {fn:'soins_discrets', label:'Soins sans trace',            pa:1, cost:800, type:'grey',  icon:'ti-eye-off',     successRate:95,  desc:'+30 Sante. Aucune trace medicale.'},
        {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:150, type:'legal', icon:'ti-vaccine', successRate:85, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
        {fn:'se_nourrir', label:'Manger', pa:1, cost:30, type:'legal', icon:'ti-soup', successRate:100, desc:'Un repas de qualite, servi au chevet.'}
      ] }
    }
  },

  // ---- DISPENSAIRE PUBLIC ----
  'dispensaire-public': {
    name: "Dispensaire Public",
    shortName: "Dispensaire",
    cat: "Sante (public)",
    icon: "ti-first-aid-kit",
    bgColor: "#081008",
    desc: "Soins gratuits mais lents. Files d'attente, moyens limites, mais accessible a tous.",
    rooms: {
      salle_attente: {
        name: "Salle d'attente",
        image: "⏳",
        imageBg: "linear-gradient(135deg,#081008,#0c180c)",
        desc: "La salle d'attente est bondee. Comptez plusieurs heures.",
        imageUrl: "https://images.unsplash.com/photo-1584515933487-779824d29309?w=1200&q=80",
        imageUrl: "https://images.unsplash.com/photo-1584515933487-779824d29309?w=1200&q=80",
        persons: [
          {name:'Infirmiere Dupre', role:'PNJ - Soignante', rel:'neutral', job:'infirmier'}
        ],
        orders: [
          {fn:'soin_public', label:'Soin standard', pa:0, cost:25, type:'legal', icon:'ti-bandage', successRate:100, desc:'+10 Sante, +1 PA immediat. 1 fois par jour. Consomme 1 desinfectant du stock du dispensaire.'},
          {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:60, type:'legal', icon:'ti-vaccine', successRate:65, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
          {fn:'transfert_clinique_privee', label:'Être transféré en clinique privée', pa:0, cost:1000, type:'legal', icon:'ti-ambulance', successRate:100, desc:'Meilleure prise en charge, convalescence plus rapide. 1000 FR.'},
          {fn:'vendre_ressource_medicale', label:'Fournir des ressources médicales', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre au dispensaire, depuis votre inventaire, du desinfectant.'}
        ]
      },
      ehpad_tilleuls: {
        name: "EHPAD — Résidence Les Tilleuls",
        imageBg: "linear-gradient(135deg,#141008,#1c1810)",
        desc: "Un salon commun paisible. Fauteuils usés, photos de famille, et des pensionnaires toujours prêts à raconter le passé de Luthécia — à condition qu'on prenne le temps de les écouter.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/ehpad-residence-tilleuls.png",
        persons: [
          {name:'Jeanine Dubois (PNJ)', role:'Ancienne institutrice', rel:'neutral', job:'pensionnaire_ehpad', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jeanine-dubois-ehpad.png', photoPos:'50% 15%'},
          {name:'Louis Chevillard (PNJ)', role:'Policier en retraite', rel:'neutral', job:'pensionnaire_ehpad', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/louis-chevillard-ehpad.png', photoPos:'50% 15%'},
          {name:'Noël Chauchay (PNJ)', role:'Agriculteur à la retraite', rel:'neutral', job:'pensionnaire_ehpad', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/noel-chauchay-ehpad.png', photoPos:'50% 15%'}
        ],
        orders: []
      }
    }
  },

  // ---- COMMISSARIAT ----
  'commissariat': {
    name: "Commissariat Central",
    shortName: "Commissariat",
    cat: "Securite",
    icon: "ti-shield-lock",
    bgColor: "#0f1018",
    desc: "Le centre nevralgique de la police de la Capitale. Theoriquement integres.",
    rooms: {
      accueil_police: {
        name: "Accueil",
        imageBg: "linear-gradient(135deg,#0f1018,#151822)",
        desc: "L'accueil du commissariat. Atmosphere froide et surveillee.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-accueil.png",
        persons: [
          {name:'Gardien de la Paix (PNJ)', role:'Agent d\'accueil', rel:'neutral', job:'gardien_paix', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-gardien-paix.png', photoPos:'50% 15%'}
        ],
        orders: [
          {fn:'plainte_police',   label:'Porter plainte',         pa:1, cost:0,   type:'legal',   icon:'ti-file-text', successRate:100, desc:'Contre une personne identifiee ou contre X. Reponse sous 24h.'},
          {fn:'consulter_caisse_commissariat', label:'Consulter la caisse', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Voir le solde actuel de la caisse du commissariat.'},
          {fn:'cambrioler_caisse_commissariat', label:'Cambrioler la caisse', pa:3, cost:0, type:'illegal', icon:'ti-lock-open', successRate:20, desc:"Tentative risquee de voler dans la caisse. Echec critique = demasque immediatement."},
          {fn:'archives_police',  label:'Consulter les archives', pa:1, cost:0,   type:'legal',   icon:'ti-archive',   successRate:100, desc:'Registre des detentions passees et en cours, consultable par tous.'},
          {fn:'arreter',          label:"Faire arreter quelqu'un",pa:3, cost:500, type:'illegal', icon:'ti-handcuffs', successRate:50,  desc:'Necessite un dossier. Mise en garde a vue 24h.'},
          {fn:'se_justifier',     label:'Se justifier (convocation)', pa:2, cost:0, type:'legal', icon:'ti-message-question', successRate:100, desc:'Se presenter suite a une convocation recue par mail. Leve l\'avis de recherche associe.'}
        ]
      },
      prison: {
        name: "Cellules de garde a vue",
        desc: "Les cellules de garde à vue du commissariat. Froid, humide, déprimant.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cellule-garde-a-vue-luthecia.png",
        persons: [
          {name:'Gardien Dubois', role:'PNJ - Gardien de cellule', rel:'neutral', job:'gardien', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-gardien-dubois.png', photoPos:'50% 15%'},
          {name:'Tristan Cabane (PNJ)', role:'Detenu', rel:'neutral', job:'detenu', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-tristan-cabane.png', photoPos:'50% 15%'}
        ],
        orders: [
          {fn:'requete_avocat',  label:'Requérir les services d\'un avocat', pa:1, cost:0,    type:'legal',   icon:'ti-scale',      successRate:100, desc:'Contacte votre avocat. Reduit les risques de condamnation.'},
          {fn:'se_rebeller',     label:'Se rebeller',                        pa:2, cost:0,    type:'illegal', icon:'ti-flame',      successRate:30,  desc:'Reserve aux emprisonnes. Defi bruyant aux gardiens : succes = +DIS mais peine allongee, echec = transfert au QHS. Endommage les grilles dans tous les cas.'},
          {fn:'tentative_evasion',label:'Tenter de s\'evader',               pa:3, cost:0,    type:'illegal', icon:'ti-run',        successRate:10,  desc:'Tres risque, une tentative par jour. Succes : liberte. Echec : transferement en prison.'}
        ]
      },
      bureau_commissaire: {
        name: "Bureau du Commissaire",
        desc: "Dossiers, rapports de filature et avis de recherche s'y accumulent. Acces reserve.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-bureau-commissaire.png",
        persons: [
          {name:'Raoul Toufaud (PNJ)', role:'Commissaire Central', rel:'neutral', job:'commissaire', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-raoul-toufaud.png', photoPos:'50% 15%'},
          {name:'Brigitte Menottes (PNJ)', role:'Inspectrice', rel:'neutral', job:'inspecteur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-brigitte-menottes.png', photoPos:'50% 10%'}
        ],
        orders: [
          {fn:'mener_enquete',          label:"Mener l'enquete",             pa:2, cost:250, type:'legal', icon:'ti-search',       successRate:35,  requiresPost:'commissaire', desc:"Enqueter sur une personne ou un lieu suite a une plainte deposee. Taux ajuste par PER, influence et securite locale."},
          {fn:'organiser_filature',     label:'Organiser une filature',       pa:2, cost:150, type:'legal', icon:'ti-eye',          successRate:50,  requiresPost:'commissaire', desc:"Obtenir un rapport des deplacements d'un PJ sur les dernieres 24h."},
          {fn:'organiser_chasse_homme', label:"Organiser une chasse a l'homme", pa:3, cost:300, type:'legal', icon:'ti-target-arrow', successRate:100, requiresPost:'commissaire', desc:'Localiser et arreter un PJ recherche.'},
          {fn:'recruter_policier',      label:'Recruter un policier',         pa:1, cost:0,   type:'legal', icon:'ti-user-plus',    successRate:100, requiresPost:'commissaire', desc:'PER 12, VOL 12. Entretien : 50 FR/jour preleves sur la caisse du commissariat.'},
          {fn:'recruter_policier_cynophile', label:'Recruter une unite cynophile', pa:1, cost:0, type:'legal', icon:'ti-dog', successRate:100, requiresPost:'commissaire', desc:'Maitre-chien + chien anti-stupefiants. Membre normal du groupe (memes regles PER/VOL). Entretien : 100 FR/jour preleves sur la caisse du commissariat.'},
          {fn:'gerer_effectifs_police', label:'Gerer mes effectifs',          pa:0, cost:0,   type:'legal', icon:'ti-users-group',  successRate:100, requiresPost:'commissaire', desc:'Affecter ou rappeler vos policiers (piece ou rue de votre ville).'}
        ]
      }
    }
  },

  // ---- LA TRIBUNE ----
  'la-tribune': {
    name: "La Tribune de Republia",
    shortName: "La Tribune",
    cat: "Medias",
    icon: "ti-news",
    bgColor: "#100808",
    desc: "Le journal le plus influent de la Capitale. Marie Leblanc y officie. Elle ne vous aime pas.",
    rooms: {
      accueil_tribune: {
        name: "Accueil",
        imageBg: "linear-gradient(135deg,#100808,#1c0c0c)",
        desc: "Le hall d'entree du journal et de l'imprimerie. Une reception marbree, l'atelier d'impression visible au fond.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/la-tribune-accueil.png",
        persons: [
          {name:'Nadège Standard (PNJ)', role:'PNJ - Standardiste', rel:'neutral', job:'hotesse', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/la-tribune-accueil.png', photoPos:'50% 35%'},
          {name:'Camille Édito (PNJ)', role:'PNJ - Journaliste', rel:'neutral', job:'journaliste', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/la-tribune-accueil.png', photoPos:'20% 40%'},
          {name:'Gustave Rotative (PNJ)', role:'PNJ - Chef d\'atelier', rel:'neutral', job:'imprimeur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/la-tribune-accueil.png', photoPos:'80% 40%'}
        ],
        orders: [
          {fn:'se_renseigner', label:'Se renseigner',            pa:0, cost:0, type:'legal', icon:'ti-info-circle', successRate:100},
          {fn:'consulter_archives_presse', label:'Consulter les archives de presse', pa:0, cost:0, type:'legal', icon:'ti-news', successRate:100, desc:'Articles archivés publiés par le journal au fil des décennies.'},
          {fn:'imprimer_tracts',  label:'Faire imprimer des tracts',  pa:2, cost:150, type:'legal', icon:'ti-file-description', successRate:100, desc:'Choisir pour/contre + cible (repertoire) + quantite. Necessite assez de bois en stock chez Gustave.'},
          {fn:'vendre_bois_imprimerie', label:'Vendre du bois à Gustave', pa:1, cost:0, type:'legal', icon:'ti-trees', successRate:100, desc:'Prix = cours actuel du bois à l\'entrepôt +10%. Plafonné par la caisse de l\'imprimerie.'}
        ]
      },
      redaction: {
        name: "Redaction",
        image: "📰",
        imageBg: "linear-gradient(135deg,#100808,#1c0c0c)",
        desc: "La redaction en ebullition permanente. Telephones, claviers, tension.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-redaction-autruche-entravee.png",
        persons: [
          {name:'Romain Castel', role:'PNJ - Redacteur en chef', rel:'neutral', job:'redacteur'},
          {name:'Marie Leblanc', role:'Journaliste d\'investigation', rel:'enemy', job:'journaliste'}
        ],
        orders: [
          {fn:'produire_fuite',   label:'Produire une fuite',           pa:3, cost:0,   type:'illegal', icon:'ti-leak',           successRate:55,  desc:'Choisir une cible dans le repertoire. Rumeur IA dans journal. Mail a la cible. -10 INF -10 POP.'},
          {fn:'fabriquer_scandale', label:'Fabriquer un scandale',          pa:3, cost:800, type:'illegal', icon:'ti-alert-triangle',  successRate:35,  desc:'Choisir une cible. Rediger le contenu. Bonus journaliste +15%. Si decouvert : Recherche pour diffamation.'},
          {fn:'interview',             label:'Donner une interview',          pa:1, cost:0,   type:'legal',   icon:'ti-microphone', successRate:100, desc:'Impact sur la popularite.'},
          {fn:'article',               label:'Placer un article favorable',   pa:2, cost:300, type:'grey',    icon:'ti-pencil',     successRate:70},
          {fn:'corrompre_journaliste', label:'Corrompre un journaliste',      pa:2, cost:500, type:'illegal', icon:'ti-cash',       successRate:55},
          {fn:'etouffer',              label:'Etouffer un article',           pa:3, cost:800, type:'illegal', icon:'ti-eye-off',    successRate:45}
        ]
      }
    }
  },

  // ---- LOGE MACONNIQUE ----
  'loge-maconnique': {
    requiresMembership: 'loge',
    name: "Loge Maconnique",
    shortName: "La Loge",
    cat: "Reseau secret",
    icon: "ti-hexagon",
    bgColor: "#0f0808",
    locked: false,
    desc: "Les cercles les plus puissants de Republia s'y reunissent. L'acces complet est sur invitation uniquement.",
    rooms: {
      portail: {
        name: "Portail de la Loge",
        imageBg: "linear-gradient(135deg,#0f0808,#180f0f)",
        desc: "Une lourde porte en bois sculpte. Un portier vous observe a travers un judas.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/loge.png",
        persons: [
          {name:'Le Portier', role:'PNJ - Gardien de la Loge', rel:'neutral', job:'portier'}
        ],
        orders: [
          {fn:'demander_parler_loge', label:'Demander a parler a quelqu\'un', pa:1, cost:0, type:'legal', icon:'ti-door-enter', successRate:95, desc:'Frapper a la porte et demander une audience. Reussite a 95%.'}
        ]
      },
      hall_loge: {
        name: "Hall d'accueil",
        imageBg: "linear-gradient(135deg,#100808,#1a1010)",
        desc: "Un hall sobre et severe. Portraits de membres illustres aux murs. Vous etes surveille.",
        imageUrl: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=1200&q=80",
        persons: [
          {name:'Frere Gardien', role:'PNJ - Membre de la Loge', rel:'neutral', job:'membre_loge'}
        ],
        // Ordre 'demander_adhesion' retire le 9 aout 2026 : aucun systeme de membres de la Loge
        // n'existe dans le code (pas de flag d'adhesion, pas de parrain, pas d'avantage) — le bouton
        // promettait un effet qui n'a jamais ete implemente. A reintroduire lors de l'audit Ordres
        // avec un vrai systeme de parrainage/adhesion.
        orders: []
      },
      bureau_venerable: {
        name: "Bureau du Venerable Maitre",
        imageBg: "linear-gradient(135deg,#0a0808,#14100a)",
        desc: "Le bureau du chef de la Loge. Acces membres confirmes uniquement.",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        locked: true,
        persons: [
          {name:'Venerable Maitre Duval', role:'PNJ - Chef de la Loge', rel:'neutral', job:'venerable'}
        ],
        orders: [
          {fn:'recruter_informateur_2', label:'Recruter un informateur (Niv.2)', pa:1, cost:400, type:'grey', icon:'ti-user-search', successRate:100, desc:'400 FR/jour. Localisation précise, intentions vote, voyages récents.'},
          {fn:'recruter_info_4', label:'Recruter une Taupe N4', pa:3, cost:0, type:'grey', icon:'ti-spy', successRate:50, desc:'1500 FR/jour. Confessions, transactions, ordres passés 24h.'},
          {fn:'consulter_info_4', label:'Consulter la Taupe N4', pa:1, cost:0, type:'grey', icon:'ti-eye', successRate:100, desc:'Obtenir une information de votre taupe niveau 4.'},
          {fn:'gerer_informateurs', label:'Gérer mes informateurs', pa:0, cost:0, type:'legal', icon:'ti-users', successRate:100, desc:'Voir et gérer vos informateurs actifs.'}
        ]
      },
      salle_reunion_loge: {
        name: "Salle de Reunion",
        imageBg: "linear-gradient(135deg,#080808,#120808)",
        desc: "La salle ou se tiennent les rituels et deliberations secretes.",
        imageUrl: "https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=1200&q=80",
        locked: true,
        persons: [],
        orders: [
          {fn:'voter_loi', label:'Participer aux deliberations', pa:2, cost:0, type:'legal', icon:'ti-check', successRate:100, requiresPost:false}
        ]
      }
    }
  },

  // ---- UNIVERSITE ----
  'universite': {
    name: "Universite de Luthecia",
    shortName: "Universite",
    cat: "Formation - Reseau intellectuel",
    icon: "ti-school",
    bgColor: "#080d10",
    desc: "L'universite forme les elites de demain et abrite des militants d'aujourd'hui.",
    rooms: {
      amphi: {
        name: "Amphitheatre",
        image: "🎓",
        imageBg: "linear-gradient(135deg,#080d10,#0c1418)",
        desc: "Les conferences publiques attirent journalistes et politiques.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/universite-amphi-v2.png",
        persons: [
          {name:'Professeur Blanc', role:'PNJ - Economiste influent', rel:'neutral', job:'professeur'}
        ],
        orders: [
          {fn:'se_former',      label:'Suivre une formation',   pa:2, cost:100, type:'legal', icon:'ti-book',        successRate:100, desc:'Choisir une caracteristique : +2 jusqu\'au prochain sommeil. 1 formation/jour.'},
          {fn:'donner_conf',    label:'Donner une conference',  pa:2, cost:0,   type:'legal', icon:'ti-microphone',  successRate:100, desc:'Soutenir un candidat en campagne (3 electeurs convertis) OU sensibiliser sur un theme (+2 indice, utilisable hors campagne).'},
          {fn:'recruter_etud',  label:'Recruter des militants', pa:2, cost:0,   type:'grey',  icon:'ti-users-group', successRate:100, desc:'Reserve aux membres d\'un syndicat etudiant actif. 1/jour, plafond 2 militants par joueur. Prepare les manifestations.'}
        ]
      },
      salle_reunion: {
        name: "Salle de Réunion — Local à louer",
        imageBg: "linear-gradient(135deg,#080d18,#0f1520)",
        desc: "📋 À LOUER — Salle de réunion équipée, tableau blanc, projecteur. Idéal pour réunions politiques, formations militantes ou conférences discrètes.",
        imageUrl: "https://images.unsplash.com/photo-1517502884422-41eaead166d4?w=1200&q=80",
        isLocationRoom: true,
        locationData: { prix: 180, bonusPOP: 4, bonusINF: 4, bonusDIS: 2, label: 'Salle de Réunion', tier: 2 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer cette salle (180 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+4 POP +4 INF +2 DIS. Recrutement militant facilité.'},
          {fn:'recruter_etud', label:'Recruter des militants', pa:2, cost:0, type:'grey', icon:'ti-users', successRate:100, desc:'Reserve aux membres d\'un syndicat etudiant actif. 1/jour, plafond 2 militants par joueur. Prepare les manifestations.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      }
    }
  },

  // ---- ARMURERIE ----
  'armurerie': {
    name: "Armurerie Legale Martinon",
    shortName: "Armurerie",
    cat: "Securite - Equipement",
    icon: "ti-shield",
    bgColor: "#100a08",
    desc: "Vente d'armes legales et equipements de securite. Un registre consigne toutes les ventes.",
    rooms: {
      magasin: {
        name: "Magasin",
        imageBg: "linear-gradient(135deg,#100a08,#181008)",
        desc: "Presentoirs d'armes. Le vendeur verifie les papiers pour les ventes legales.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/armurerie-martinon-comptoir.png",
        persons: [
          {name:'Gerard (Armurier)', role:'PNJ - Vendeur', rel:'neutral', job:'armurier'}
        ],
        orders: [
          {
            fn:'choisir_arme',
            label:'Acheter une arme',
            pa:1, cost:0, type:'grey', icon:'ti-sword', successRate:100,
            desc:'Couteau, revolver ou carabine — achat légal (enregistré) ou marché noir (3x le prix), au choix pour chaque arme.'
          },
          {
            fn:'acheter_gilet',
            label:'Acheter un gilet pare-balles',
            pa:1, cost:600, type:'legal', icon:'ti-shield-check', successRate:100,
            desc:'Protection physique. Enregistre dans le registre.',
            imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-gilet-republic.png'
          },
          {
            fn:'consulter_registre_armes',
            label:'Consulter le registre de vente',
            pa:1, cost:0, type:'legal', icon:'ti-book', successRate:100,
            desc:'Acces libre : Commissaire, Juge. Sinon : soudoyer l\'armurier (30%, 100 FR, +/-5 INF et POP). Ventes des 6 derniers mois.'
          },
          {fn:'produire_arme', label:'Produire une arme', pa:0, cost:0, type:'legal', icon:'ti-hammer', successRate:100, desc:'Fabrication contre salaire fixe : 2 PA, 100 FR par arme. Necessite des matieres en stock et une caisse suffisante.'}
        ]
      }
    }
  },

  // ---- MARCHE ----
  'marche': {
    name: "Marche Central",
    shortName: "Marche",
    cat: "Commerce - Vie quotidienne",
    icon: "ti-building-store",
    bgColor: "#0d0d08",
    desc: "Le marche central de Luthecia. Vivres, informations et contacts populaires.",
    rooms: {
      marche_ext: {
        name: "Etals du marche",
        imageBg: "linear-gradient(135deg,#0d0d08,#181808)",
        desc: "Bruyant, colore, vivant. Tout le monde passe par le marche.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marche.png",
        persons: [
          {name:'Fernande (Marchande)', role:'PNJ - Commercante', rel:'neutral', job:'marchande'},
          {name:'Marcel',               role:'PNJ - Habitant du quartier', rel:'neutral', job:'citoyen'},
          {name:'Yvonne',               role:'PNJ - Retraitee', rel:'neutral', job:'citoyen'}
        ],
        orders: [
          {fn:'se_nourrir',          label:'Acheter a manger',          pa:0, cost:8,  type:'legal',   icon:'ti-shopping-cart', successRate:100, desc:'Repas economique. +5 Sante.'},
          {fn:'pouls_populaire',     label:'Prendre le pouls',          pa:0, cost:0,  type:'legal',   icon:'ti-ear',           successRate:100, desc:'Sondage sur l\'election locale en cours dans cette ville (maire/depute), a partir des votes reellement enregistres.'},
          {fn:'distribuer_tract',    label:'Distribuer un tract',       pa:1, cost:0,  type:'legal',   icon:'ti-file-description',successRate:70, desc:'Necessite un tract en inventaire. Donne un vote au candidat du tract.', requiresTract:true},
          {fn:'lancer_rumeur_cible', label:'Lancer une rumeur', pa:1, cost:0, type:'grey', icon:'ti-messages', successRate:75, desc:'Rediger une rumeur visant un PJ, une organisation, un local, un gouvernement ou un pays. Succes (75%) : effet selon la cible. Echec : retour de bâton limite + risque de detection.'}
        ]
      }
    }
  },

  // ---- TERRAIN A BATIR ----
  // ---- MAIRIE CAPITALE ----
  'mairie-capitale': {
    name: "Hotel de Ville de Luthecia",
    shortName: "Hotel de Ville",
    cat: "Administration - Candidatures",
    icon: "ti-building-community",
    bgColor: "#121810",
    capitaleOnly: true,
    desc: "L'hotel de ville de la capitale. C'est ici que se deposent les candidatures aux elections et que s'effectuent les actes officiels.",
    rooms: {
      hall_mairie: {
        name: "Hall d'accueil",
        imageBg: "linear-gradient(135deg,#121810,#1a2016)",
        desc: "Le hall de l'hotel de ville. Guichets, formulaires, fonctionnaires municipaux.",
        imageUrl: "https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80",
        persons: [
          {name:'Secretaire Municipal Petit', role:'PNJ - Secretariat general', rel:'neutral', job:'secretaire', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/secretaire-petit-mairie.png'},
          {name:'Le Maire (PNJ)',             role:'Maire de Luthecia', rel:'neutral', job:'maire'},
          {name:'Hotesse Objets Trouves (PNJ)', role:'PNJ - Service des objets trouves', rel:'neutral', job:'hotesse_objets_trouves', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotesse-objets-trouves-mairie.png'}
        ],
        orders: [
          {fn:'calendrier_elections', label:'Calendrier electoral',       pa:0, cost:0, type:'legal', icon:'ti-calendar', successRate:100, desc:'Consulter le calendrier des elections en cours et a venir.'},
          {fn:'organigramme', label:'Organigramme du pays', pa:0, cost:0, type:'legal', icon:'ti-sitemap', successRate:100, desc:'Voir qui occupe chaque poste dans votre empire. PJ en vert, PNJ en gris.'},
          {fn:'deposer_candidature', label:'Deposer une candidature',    pa:2, cost:0,   type:'legal', icon:'ti-id-badge',   successRate:100, desc:'Vous inscrire comme candidat a une election en cours.'},
          {fn:'consulter_elections', label:'Consulter les elections',     pa:0, cost:0,   type:'legal', icon:'ti-chart-bar',  successRate:100, desc:'Voir les elections en cours et les candidats declares.'},
          {fn:'acte_officiel',       label:'Demander un acte officiel',  pa:1, cost:50,  type:'legal', icon:'ti-file-certificate', successRate:100, desc:'Naissance, mariage, document administratif.'},
          {fn:'demander_naturalisation', label:'Demander la naturalisation', pa:2, cost:0, type:'legal', icon:'ti-passport', successRate:100, desc:'Deposer une demande de naturalisation vers un autre empire. Validee par le Ministre de l\'Interieur concerne.'},
          {fn:'demander_mariage', label:'Demander en mariage', pa:1, cost:0, type:'legal', icon:'ti-heart', successRate:100, desc:'Envoyer une demande en mariage a un autre PJ. Necessitera une ceremonie a la mairie pour officialiser.'},
          {fn:'officialiser_mariage', label:'Officialiser un mariage', pa:2, cost:200, type:'legal', icon:'ti-heart-handshake', successRate:100, desc:'Celebrer le mariage. Les deux futurs epoux doivent etre presents.'},
          {fn:'consulter_indices_locaux', label:'Consulter les caisses communales', pa:0, cost:0, type:'legal', icon:'ti-chart-histogram', successRate:100, desc:'Voir le solde reel des caisses du Commissariat, Centre Multimodal, Stade, Marche, Dispensaire et Tribunal.'},
          {fn:'objet_trouve', label:'Reclamer un objet trouve', pa:1, cost:0, type:'legal', icon:'ti-briefcase', successRate:100, desc:'Le service des objets trouves. On ne sait jamais ce qui finit dans une boite en carton...'},
          {fn:'consulter_organigramme_mairie', label:'Consulter l\'organigramme', pa:0, cost:0, type:'legal', icon:'ti-sitemap', successRate:100, desc:'Organigramme national ou municipal, en temps reel. Public et gratuit, aucun poste requis.'}
        ]
      },
      bureau_maire: {
        name: "Bureau du Maire",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        desc: "Le bureau du maire de Luthecia. Acces sur rendez-vous.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-maire.png",
        persons: [
          {name:'Le Maire de Luthecia (PNJ)', role:'Maire de la Capitale', rel:'neutral', job:'maire'}
        ],
        orders: [
          {fn:'fixer_impots_locaux',   label:'Fixer les impôts locaux',       pa:2, cost:0, type:'legal', icon:'ti-receipt-tax',  successRate:100, requiresPost:'maire', desc:'Definir le taux de taxation locale. Impact direct sur les recettes et la popularite.'},
          {fn:'repartition_budget_local', label:'Repartir le budget municipal', pa:2, cost:0, type:'legal', icon:'ti-chart-pie',    successRate:100, requiresPost:'maire', desc:'Repartir les recettes fiscales locales entre Commissariat, Centre Multimodal, Stade, Marche, Dispensaire et Tribunal. Applique chaque nuit, credite directement leur caisse reelle.'},
          {fn:'campagne_securite',     label:'Lancer une campagne de securite',pa:2, cost:500, type:'legal', icon:'ti-shield',     successRate:80,  requiresPost:'maire', desc:'+10 ISN local. Deploiement de forces de l\'ordre supplementaires. Preleve sur budget mairie.'},
          {fn:'contester_resultats',   label:'Contester des resultats',       pa:2, cost:0, type:'legal', icon:'ti-alert-triangle', successRate:70, desc:'Deposer un recours dans le sous-forum Tribunal. Delai 48h. Decision du juge.'},
          {fn:'nommer_commissaire',    label:'Nommer un commissaire',         pa:3, cost:0, type:'legal', icon:'ti-shield-lock', successRate:100, requiresPost:'maire', desc:'Nommer un PJ habitant de la ville comme commissaire. Poste exclusif (sauf depute).'},
          {fn:'revoquer_commissaire',   label:'Revoquer le commissaire',      pa:1, cost:0, type:'legal', icon:'ti-shield-x', successRate:100, requiresPost:'maire', desc:'Retirer le poste de commissaire au titulaire actuel de la ville.'},
          {fn:'gerer_candidature_maire_adjoint', label:'Gérer les candidatures au Maire Adjoint', pa:1, cost:0, type:'legal', icon:'ti-user-search', successRate:100, requiresPost:'maire', desc:'Candidatures reçues pour le poste de Maire Adjoint de cette ville — sans se déplacer.'}
        ]
      },
      bureau_maire_adjoint: {
        name: "Bureau du Maire Adjoint",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        desc: "Le bureau de l'adjoint au maire de Luthecia. Acces sur rendez-vous.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-maire.png",
        persons: [],
        orders: [
          {fn:'traiter_demandes_permis', label:'Traiter les demandes de permis', pa:1, cost:0, type:'legal', icon:'ti-stamp', successRate:100, requiresPost:'maire_adjoint', desc:'Valider ou refuser les permis de construire arrives a instruction terminee, dans cette ville uniquement.'},
          {fn:'acte_officiel_mairie',  label:'Delivrer un acte officiel',     pa:1, cost:0, type:'legal', icon:'ti-file-certificate', successRate:100, requiresPost:'maire_adjoint', desc:'Choisir le type d\'acte a delivrer a un administre.'},
          {fn:'financer_communal',       label:'Financer un batiment communal', pa:1, cost:0, type:'legal', icon:'ti-cash', successRate:100, requiresPost:'maire_adjoint', desc:'Virement instantane depuis la caisse municipale vers un batiment de la ville.'},
          {fn:'gerer_candidature_directeur_entrepot', label:"Gérer les candidatures au Directeur d'Entrepôt", pa:1, cost:0, type:'legal', icon:'ti-user-search', successRate:100, requiresPost:'maire_adjoint', desc:"Candidatures reçues pour le Directeur de l'Entrepôt Logistique de cette ville — sans se déplacer."},
          {fn:'nommer_directeur_entrepot', label:'Nommer un directeur d\'entrepôt', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'maire_adjoint', desc:"Nommer un PJ directeur de l'entrepôt de cette ville. Poste exclusif (sauf député)."},
          {fn:'revoquer_directeur_entrepot', label:"Revoquer le directeur d'entrepôt", pa:1, cost:0, type:'legal', icon:'ti-shield-x', successRate:100, requiresPost:'maire_adjoint', desc:"Retirer le poste de directeur d'entrepôt au titulaire actuel de la ville."}
        ]
      },
      salle_elections: {
        name: "Salle des Elections",
        imageBg: "linear-gradient(135deg,#0f1810,#142014)",
        desc: "La salle ou sont geres les scrutins et candidatures officielles de la ville.",
        imageUrl: "https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?w=1200&q=80",
        persons: [
          {name:'Responsable Electoral (PNJ)', role:'PNJ - Commission electorale', rel:'neutral', job:'responsable_election'}
        ],
        orders: [
          {fn:'consulter_elections',  label:'Voir les candidats',         pa:0, cost:0,    type:'legal',   icon:'ti-list',          successRate:100, desc:'Liste des candidats declares et sondages.'},
          {fn:'contester_resultats',  label:'Contester des resultats',    pa:3, cost:200,  type:'legal',   icon:'ti-alert-triangle',successRate:40,  desc:'Contester le resultat d\'une election. Long processus.'},
          {fn:'falsifier_docs',       label:'Falsifier une liste',        pa:3, cost:500,  type:'illegal', icon:'ti-file-x',        successRate:35,  desc:'Manipuler les listes electorales. Tres risque.'}
        ]
      },
      salle_archives: {
        name: "Salle des Archives",
        imageBg: "linear-gradient(135deg,#100c08,#181410)",
        desc: "L'état-civil, le cadastre et les résumés de mandats des maires successifs. Poussiéreux, mais tout y est.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-archives-mairie-luthecia.png",
        persons: [
          {name:'Christophe Bouquin (PNJ)', role:'Archiviste Municipal', rel:'neutral', job:'archiviste', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/christophe-bouquin-archiviste.png', photoPos:'50% 15%'}
        ],
        orders: [
          {fn:'consulter_etat_civil', label:"Consulter l'état-civil", pa:0, cost:0, type:'legal', icon:'ti-file-search', successRate:100, desc:"Rechercher par nom ou par décennie dans le registre d'état-civil de Republia."},
          {fn:'consulter_mandats_maires', label:'Consulter les résumés de mandats', pa:0, cost:0, type:'legal', icon:'ti-book', successRate:100, desc:'Grands chantiers et actes majeurs des maires successifs de Luthécia.'}
        ]
      }
    }
  },

  // =====================
  // MUSEE DE PORT SAINTE MARIE
  // =====================

  'musee-port-sainte-marie': {
    name: "Musée de Port Sainte Marie",
    shortName: "Musée",
    cat: "Culture",
    icon: "ti-building-monument",
    bgColor: "#1c160c",
    desc: "Le musee dedie a l'histoire de Port-Sainte-Marie et de ses grandes figures. Chaque salle immortalise une categorie de Mariannais celebres, pour le meilleur et pour le pire.",
    rooms: {
      hall: {
        name: "Hall d'accueil",
        imageBg: "linear-gradient(135deg,#1c160c,#241c10)",
        desc: "Le hall d'accueil du musee. Rosace en marqueterie au sol, maquettes de navires, vitrines d'instruments de navigation. Soizic Le Gall tient l'accueil ; Yvon Le Gall, le conservateur, veille sur les collections.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-musee-port-sainte-marie.png",
        persons: [
          {name:'Soizic Le Gall (PNJ)', role:'PNJ - Accueil du musee', rel:'neutral', job:'hotesse', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-musee-port-sainte-marie.png', photoPos:'18% 30%'},
          {name:'Yvon Le Gall (PNJ)', role:'PNJ - Conservateur du musee', rel:'neutral', job:'conservateur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-musee-port-sainte-marie.png', photoPos:'42% 22%'},
          {name:'Marcel Kermeur (PNJ)', role:'PNJ - Guide benevole du musee', rel:'neutral', job:'guide', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marcel-kermeur-guide-musee.png', photoPos:'50% 25%'}
        ],
        orders: []
      },
      // audioUrl (chantier "integration images/audio PSM", 30 aout 2026) : assets recuperes
      // depuis le dossier Telechargements de Fred (deja produits, jamais re-generes), copies dans
      // le depot sans toucher aux images deja en place (comparees octet pour octet -- identiques,
      // aucun remplacement necessaire). Bouton "Ecouter l'audioguide" deja generique
      // (plateau-politique.js, room.audioUrl) -- aucune nouvelle mecanique.
      salle_criminels: {
        name: "Salle des Grands Criminels Mariannais",
        imageBg: "linear-gradient(135deg,#1a0d0d,#241010)",
        desc: "Portraits et affaires des malfrats les plus tristement celebres de Port-Sainte-Marie. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-criminels-musee-psm.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/port-sainte-marie/salle-criminels-musee-psm-audio.mp3",
        persons: [ {name:'Marcel Kermeur (PNJ)', role:'PNJ - Guide benevole du musee', rel:'neutral', job:'guide', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marcel-kermeur-guide-musee.png', photoPos:'50% 25%'} ],
        orders: []
      },
      salle_maires: {
        name: "Salle des Maires de Port-Sainte-Marie",
        imageBg: "linear-gradient(135deg,#181408,#221c0c)",
        desc: "L'histoire municipale de la ville, ses meilleurs et ses pires edeciles reunis dans la meme salle. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-maires-musee-psm.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/port-sainte-marie/salle-maires-musee-psm-audio.mp3",
        persons: [ {name:'Marcel Kermeur (PNJ)', role:'PNJ - Guide benevole du musee', rel:'neutral', job:'guide', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marcel-kermeur-guide-musee.png', photoPos:'50% 25%'} ],
        orders: []
      },
      salle_personnalites: {
        name: "Salle des Personnalites Mariannaises",
        imageBg: "linear-gradient(135deg,#14181c,#1c2228)",
        desc: "Les figures les plus populaires et aimees de la ville, toutes generations confondues. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-personnalites-musee-psm.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/port-sainte-marie/salle-personnalites-musee-psm-audio.mp3",
        persons: [ {name:'Marcel Kermeur (PNJ)', role:'PNJ - Guide benevole du musee', rel:'neutral', job:'guide', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marcel-kermeur-guide-musee.png', photoPos:'50% 25%'} ],
        orders: []
      },
      salle_entrepreneurs: {
        name: "Salle des Grands Entrepreneurs Mariannais",
        imageBg: "linear-gradient(135deg,#141c14,#1c2818)",
        desc: "Les batisseurs economiques de Port-Sainte-Marie, du petit commerce a l'empire industriel. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-entrepreneurs-musee-psm.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/port-sainte-marie/salle-entrepreneurs-musee-psm-audio.mp3",
        persons: [ {name:'Marcel Kermeur (PNJ)', role:'PNJ - Guide benevole du musee', rel:'neutral', job:'guide', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marcel-kermeur-guide-musee.png', photoPos:'50% 25%'} ],
        orders: []
      },
      salle_organisations: {
        name: "Salle des Organisations Mariannaises",
        imageBg: "linear-gradient(135deg,#0e1418,#141c22)",
        desc: "Clubs, syndicats et organisations locales : leurs plus grands representants, toutes disciplines confondues. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-organisations-musee-psm.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/port-sainte-marie/salle-organisations-musee-psm-audio.mp3",
        persons: [ {name:'Marcel Kermeur (PNJ)', role:'PNJ - Guide benevole du musee', rel:'neutral', job:'guide', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marcel-kermeur-guide-musee.png', photoPos:'50% 25%'} ],
        orders: []
      },
      salle_plumes: {
        name: "Salle des Plumes Mariannaises",
        imageBg: "linear-gradient(135deg,#181018,#221824)",
        desc: "Les plus belles diatribes, lettres ouvertes et recits qui ont marque la vie forumiale de Port-Sainte-Marie. Contenu a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-plumes-musee-psm.png",
        // Premier export ("PSM musee salle plumes.mp3", 30 aout 2026) etait un fichier de 0 octet
        // (echec AudioFileOpenURL) -- non raccorde a l'epoque, signale a Fred. Remplace le meme
        // jour par un nouvel export valide (152s, verifie via afinfo), copie et raccorde ci-dessous.
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/port-sainte-marie/salle-plumes-musee-psm-audio.mp3",
        persons: [ {name:'Marcel Kermeur (PNJ)', role:'PNJ - Guide benevole du musee', rel:'neutral', job:'guide', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marcel-kermeur-guide-musee.png', photoPos:'50% 25%'} ],
        orders: []
      },
      salle_honneur_militaire: {
        name: "Salle d'Honneur Militaire",
        imageBg: "linear-gradient(135deg,#141410,#201f18)",
        desc: "Les faits d'armes et les soldats les plus decores originaires de Port-Sainte-Marie. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-honneur-militaire-musee-psm.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/port-sainte-marie/salle-honneur-militaire-musee-psm-audio.mp3",
        persons: [ {name:'Marcel Kermeur (PNJ)', role:'PNJ - Guide benevole du musee', rel:'neutral', job:'guide', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marcel-kermeur-guide-musee.png', photoPos:'50% 25%'} ],
        orders: []
      },
      salle_unions: {
        name: "Salle des Unions Celebres",
        imageBg: "linear-gradient(135deg,#1c1414,#281c1c)",
        desc: "Les mariages et alliances les plus marquants de l'histoire de la ville. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-unions-musee-psm.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/port-sainte-marie/salle-unions-musee-psm-audio.mp3",
        persons: [ {name:'Marcel Kermeur (PNJ)', role:'PNJ - Guide benevole du musee', rel:'neutral', job:'guide', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marcel-kermeur-guide-musee.png', photoPos:'50% 25%'} ],
        orders: []
      },
      // salle_dynasties retiree du parcours (commit b202acd, 30 aout 2026, decision de game
      // design de Fred) : le theme Le Gall/Le Roux est deja suffisamment present ailleurs.
      salle_scandales: {
        name: "Salle des Scandales et Affaires",
        imageBg: "linear-gradient(135deg,#100c10,#181018)",
        desc: "Les grandes crises politiques et affaires qui ont secoue Port-Sainte-Marie. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-scandales-musee-psm.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/port-sainte-marie/salle-scandales-musee-psm-audio.mp3",
        persons: [ {name:'Marcel Kermeur (PNJ)', role:'PNJ - Guide benevole du musee', rel:'neutral', job:'guide', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marcel-kermeur-guide-musee.png', photoPos:'50% 25%'} ],
        orders: []
      }
    }
  },

  // =====================
  // V28A — CENTRES COMMERCIAUX / ARTISANAUX / AFFAIRES
  // =====================

  'centre-commercial': {
    name: "Centre Commercial",
    shortName: "Centre Commercial",
    cat: "Commerce",
    icon: "ti-building-store",
    bgColor: "#0a0d10",
    desc: "Le grand centre commercial de la ville. Boutiques, cafés, bureaux. Les affaires s'y font à la vue de tous — ou pas.",
    rooms: {
      hall: {
        name: "Hall d'Entrée",
        imageBg: "linear-gradient(135deg,#0a0d10,#12151a)",
        desc: "Le grand hall du centre commercial. Vitrines, passants pressés, musique d'ambiance en boucle.",
        imageUrl: "https://images.unsplash.com/photo-1519567241046-7f570eee3ce6?w=1200&q=80",
        persons: [
          {name:'Francisca Brel', role:'Voleuse', rel:'neutral', job:'criminel'},
          {name:'Edgar Simore', role:'Magicien saltimbanque', rel:'neutral', job:'artiste'}
        ],
        orders: [
          {fn:'se_renseigner', label:'Se renseigner', pa:0, cost:0, type:'legal', icon:'ti-info-circle', successRate:100}
        ]
      },
      vitrine_principale: {
        name: "Vitrine Principale — Local à louer",
        imageBg: "linear-gradient(135deg,#0a0d10,#12151a)",
        desc: "📋 À LOUER — Emplacement premium en façade. Visibilité maximale. Prix élevé, impact fort sur la réputation de votre organisation.",
        imageUrl: "https://images.unsplash.com/photo-1567449303078-57ad995bd17f?w=1200&q=80",
        imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-republic.png',
        isLocationRoom: true,
        locationData: { prix: 800, bonusPOP: 10, bonusINF: 5, bonusDIS: 0, label: 'Vitrine Principale', tier: 1 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce local (800 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Emplacement premium. +10 POP +5 INF à votre organisation.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100, desc:'Gérer votre location.'}
        ]
      },
      boutique_milieu: {
        name: "Boutique Milieu — Local à louer",
        imageBg: "linear-gradient(135deg,#0a0d10,#12151a)",
        desc: "📋 À LOUER — Boutique bien située, bon passage. Rapport qualité/prix intéressant.",
        imageUrl: "https://images.unsplash.com/photo-1441984904996-e0b6ba687e04?w=1200&q=80",
        isLocationRoom: true,
        locationData: { prix: 400, bonusPOP: 5, bonusINF: 3, bonusDIS: 0, label: 'Boutique Milieu', tier: 2 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce local (400 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+5 POP +3 INF à votre organisation.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      },
      arriere_boutique: {
        name: "Arrière-Boutique — Local à louer",
        imageBg: "linear-gradient(135deg,#0a0d10,#12151a)",
        desc: "📋 À LOUER — Arrière-boutique discrète. Pas très visible mais suffisante pour démarrer.",
        imageUrl: "https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=1200&q=80",
        isLocationRoom: true,
        locationData: { prix: 150, bonusPOP: 2, bonusINF: 1, bonusDIS: 0, label: 'Arrière-Boutique', tier: 3 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce local (150 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+2 POP +1 INF à votre organisation.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      },
      cave_reserve: {
        name: "Cave / Réserve — Local à louer",
        imageBg: "linear-gradient(135deg,#080a08,#0f120f)",
        desc: "📋 À LOUER — Sous-sol discret, sans fenêtre. Idéal pour les activités qu'on préfère garder secrètes.",
        imageUrl: "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=1200&q=80",
        isLocationRoom: true,
        locationData: { prix: 80, bonusPOP: 0, bonusINF: 1, bonusDIS: 5, label: 'Cave / Réserve', tier: 4 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce local (80 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+5 DIS à votre organisation. Très discret.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      }
    }
  },

  'centre-artisanal': {
    name: "Centre Artisanal",
    shortName: "Centre Artisanal",
    cat: "Commerce",
    icon: "ti-tools",
    bgColor: "#0d0a08",
    desc: "Le marché couvert artisanal. Ambiance populaire, clientèle fidèle. Idéal pour ancrer une organisation dans le quartier.",
    rooms: {
      travees: {
        name: "Travées",
        imageBg: "linear-gradient(135deg,#0d0a08,#151008)",
        desc: "Les travées du marché couvert artisanal. Odeurs de bois, de cuir et de café, bruit de fond permanent.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/travees-centre-artisanal.png",
        persons: [
          {name:'Sabri Coledur', role:'Mécanicien', rel:'neutral', job:'commercant'},
          {name:'Céd\' Labone', role:'Dealer', rel:'neutral', job:'criminel'},
          {name:'Henrico Stot', role:'Sécurité', rel:'neutral', job:'agent_securite'}
        ],
        orders: [
          {fn:'se_renseigner', label:'Se renseigner', pa:0, cost:0, type:'legal', icon:'ti-info-circle', successRate:100}
        ]
      },
      echoppe_facade: {
        name: "Échoppe Facade — Local à louer",
        imageBg: "linear-gradient(135deg,#0d0a08,#151008)",
        desc: "📋 À LOUER — Échoppe en façade du marché. Fort passage, clientèle populaire. Bonus popularité.",
        imageUrl: "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1200&q=80",
        imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-republic.png',
        isLocationRoom: true,
        locationData: { prix: 600, bonusPOP: 12, bonusINF: 2, bonusDIS: 0, label: 'Échoppe Facade', tier: 1 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce local (600 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+12 POP +2 INF. Fort ancrage populaire.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      },
      atelier_milieu: {
        name: "Atelier Central — Local à louer",
        imageBg: "linear-gradient(135deg,#0d0a08,#151008)",
        desc: "📋 À LOUER — Atelier au cœur du marché. Ambiance authentique, bons contacts locaux.",
        imageUrl: "https://images.unsplash.com/photo-1606107557195-0e29a4b5b4aa?w=1200&q=80",
        isLocationRoom: true,
        locationData: { prix: 300, bonusPOP: 6, bonusINF: 2, bonusDIS: 0, label: 'Atelier Central', tier: 2 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce local (300 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+6 POP +2 INF.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      },
      reserve_arriere: {
        name: "Réserve Arrière — Local à louer",
        imageBg: "linear-gradient(135deg,#0d0a08,#12100a)",
        desc: "📋 À LOUER — Petite réserve en fond de marché. Pas cher, discret, suffisant pour démarrer.",
        imageUrl: "https://images.unsplash.com/photo-1587293852726-70cdb56c2866?w=1200&q=80",
        isLocationRoom: true,
        locationData: { prix: 100, bonusPOP: 2, bonusINF: 1, bonusDIS: 2, label: 'Réserve Arrière', tier: 3 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce local (100 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+2 POP +1 INF +2 DIS.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      }
    }
  },

  'centre-affaires': {
    name: "Centre d'Affaires",
    shortName: "Centre d'Affaires",
    cat: "Affaires",
    icon: "ti-building-skyscraper",
    bgColor: "#080a10",
    desc: "Le centre d'affaires de la ville. Bureaux feutrés, discrétion absolue, réseau huppé. On ne vient pas ici pour être vu — on vient pour avoir du pouvoir.",
    rooms: {
      hall: {
        name: "Hall d'Entrée",
        imageBg: "linear-gradient(135deg,#080a10,#0f1218)",
        desc: "Un hall feutré, marbre noir et lumière tamisée. On y croise beaucoup de monde important qui prétend ne connaître personne.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-centre-affaires-luthecia.png",
        persons: [
          {name:'Gretta Délieu (PNJ)', role:'PNJ - Accueil', rel:'neutral', job:'hotesse', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-centre-affaires-luthecia.png', photoPos:'38% 45%'},
          {name:'Moshe Maychan', role:'Assassin', rel:'neutral', job:'criminel'},
          {name:'Harry Cover', role:'Detective prive', rel:'neutral', job:'inspecteur'}
        ],
        orders: [
          {fn:'se_renseigner', label:'Se renseigner',       pa:0, cost:0, type:'legal', icon:'ti-info-circle', successRate:100}
        ]
      },
      bureau_prestige: {
        name: "Bureau Prestige — Local à louer",
        imageBg: "linear-gradient(135deg,#080a10,#0f1218)",
        desc: "📋 À LOUER — Bureau avec vue, mobilier luxueux, accès VIP. Le summum du centre d'affaires. Influence et discrétion maximales.",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-republic.png',
        isLocationRoom: true,
        locationData: { prix: 1000, bonusPOP: 3, bonusINF: 12, bonusDIS: 8, label: 'Bureau Prestige', tier: 1 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce local (1000 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+12 INF +8 DIS +3 POP. Le bureau qui impressionne.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      },
      bureau_standard: {
        name: "Bureau Standard — Local à louer",
        imageBg: "linear-gradient(135deg,#080a10,#0f1218)",
        desc: "📋 À LOUER — Bureau fonctionnel et discret. Bon rapport influence/coût.",
        imageUrl: "https://images.unsplash.com/photo-1497366754035-f200968a6e72?w=1200&q=80",
        isLocationRoom: true,
        locationData: { prix: 500, bonusPOP: 1, bonusINF: 6, bonusDIS: 5, label: 'Bureau Standard', tier: 2 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce local (500 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+6 INF +5 DIS +1 POP.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      },
      open_space: {
        name: "Open Space — Local à louer",
        imageBg: "linear-gradient(135deg,#080a10,#0f1218)",
        desc: "📋 À LOUER — Espace partagé, ambiance start-up. Moins cher, mais moins discret.",
        imageUrl: "https://images.unsplash.com/photo-1527192491265-7e15c55b1ed2?w=1200&q=80",
        isLocationRoom: true,
        locationData: { prix: 200, bonusPOP: 2, bonusINF: 3, bonusDIS: 1, label: 'Open Space', tier: 3 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce local (200 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+3 INF +2 POP +1 DIS.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      },
      tribune_republia: {
        name: "La Tribune de Republia — Antenne Locale",
        imageBg: "linear-gradient(135deg,#100808,#1c0c0c)",
        desc: "L'antenne locale du grand journal national d'opposition. Petite rédaction, mais grande influence.",
        persons: [
          {name:'Correspondant Local (PNJ)', role:'PNJ - Journaliste', rel:'neutral', job:'journaliste'}
        ],
        orders: [
          {fn:'produire_fuite', label:'Produire une fuite', pa:3, cost:0, type:'illegal', icon:'ti-leak', successRate:55, desc:"Choisir une cible dans le répertoire. Rumeur IA dans le journal. Mail à la cible. -10 INF -10 POP."},
          {fn:'interview', label:'Donner une interview', pa:1, cost:0, type:'legal', icon:'ti-microphone', successRate:100, desc:'Impact sur la popularité.'},
          {fn:'article', label:'Placer un article favorable', pa:2, cost:300, type:'grey', icon:'ti-pencil', successRate:70}
        ]
      }
    }
  },

  'terrain-a-batir-4': {
    name: "Terrain a batir - Lot 4 (La Châtaigneraie)", shortName: "Lot 4 — Châtaigneraie", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Autrefois un seul grand domaine agricole en périphérie de Luthécia — la Châtaigneraie — ce terrain a été loti en cinq parcelles distinctes, aujourd'hui proposées séparément à la vente.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Le plus petit lot de la Châtaigneraie (1850 m²), en fond de parcelle.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain (1850 m² — 22 200 FR)', pa:2, cost:22200, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'corrompre_rdv_notaire', label:'Accélérer le rendez-vous (corruption)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant avant le rendez-vous notarial d\'un achat direct.'},{fn:'payer_versement_chantier', label:'Payer le versement du chantier', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Régler le versement en attente pour que le chantier reprenne.'},{fn:'corrompre_chantier', label:'Accélérer le chantier (corruption)', pa:2, cost:1500, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant du chantier.'},{fn:'voler_materiel_chantier', label:'Voler du matériel de chantier', pa:2, cost:0, type:'illegal', icon:'ti-truck', successRate:0, desc:'Même le propriétaire peut se voler lui-même — mise en scène parodique, bonus de sympathie publique.'},{fn:'diviser_construction', label:'Diviser / gérer les lots', pa:0, cost:0, type:'legal', icon:'ti-grid-dots', successRate:100, desc:'Réservé aux Commerces Premium et Buildings construits.'},{fn:'louer_lot_ici', label:'Louer un lot ici', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Louer un lot disponible, si ce terrain a été divisé par son propriétaire.'},{fn:'gerer_lot_loue', label:'Gérer mon local loué', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:'Voir/accepter les propositions du propriétaire concernant votre lot loué ici.'},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-5': {
    name: "Terrain a batir - Lot 5 (La Châtaigneraie)", shortName: "Lot 5 — Châtaigneraie", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Autrefois un seul grand domaine agricole en périphérie de Luthécia — la Châtaigneraie — ce terrain a été loti en cinq parcelles distinctes, aujourd'hui proposées séparément à la vente.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Le plus vaste lot de la Châtaigneraie (2750 m²), comprenant l'ancien verger.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain (2750 m² — 33 000 FR)', pa:2, cost:33000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'corrompre_rdv_notaire', label:'Accélérer le rendez-vous (corruption)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant avant le rendez-vous notarial d\'un achat direct.'},{fn:'payer_versement_chantier', label:'Payer le versement du chantier', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Régler le versement en attente pour que le chantier reprenne.'},{fn:'corrompre_chantier', label:'Accélérer le chantier (corruption)', pa:2, cost:1500, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant du chantier.'},{fn:'voler_materiel_chantier', label:'Voler du matériel de chantier', pa:2, cost:0, type:'illegal', icon:'ti-truck', successRate:0, desc:'Même le propriétaire peut se voler lui-même — mise en scène parodique, bonus de sympathie publique.'},{fn:'diviser_construction', label:'Diviser / gérer les lots', pa:0, cost:0, type:'legal', icon:'ti-grid-dots', successRate:100, desc:'Réservé aux Commerces Premium et Buildings construits.'},{fn:'louer_lot_ici', label:'Louer un lot ici', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Louer un lot disponible, si ce terrain a été divisé par son propriétaire.'},{fn:'gerer_lot_loue', label:'Gérer mon local loué', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:'Voir/accepter les propositions du propriétaire concernant votre lot loué ici.'},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-6': {
    name: "Terrain a batir - Lot 6", shortName: "Terrain Lot 6", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain disponible. Quartier Sud.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:25000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'corrompre_rdv_notaire', label:'Accélérer le rendez-vous (corruption)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant avant le rendez-vous notarial d\'un achat direct.'},{fn:'payer_versement_chantier', label:'Payer le versement du chantier', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Régler le versement en attente pour que le chantier reprenne.'},{fn:'corrompre_chantier', label:'Accélérer le chantier (corruption)', pa:2, cost:1500, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant du chantier.'},{fn:'voler_materiel_chantier', label:'Voler du matériel de chantier', pa:2, cost:0, type:'illegal', icon:'ti-truck', successRate:0, desc:'Même le propriétaire peut se voler lui-même — mise en scène parodique, bonus de sympathie publique.'},{fn:'diviser_construction', label:'Diviser / gérer les lots', pa:0, cost:0, type:'legal', icon:'ti-grid-dots', successRate:100, desc:'Réservé aux Commerces Premium et Buildings construits.'},{fn:'louer_lot_ici', label:'Louer un lot ici', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Louer un lot disponible, si ce terrain a été divisé par son propriétaire.'},{fn:'gerer_lot_loue', label:'Gérer mon local loué', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:'Voir/accepter les propositions du propriétaire concernant votre lot loué ici.'},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-7': {
    name: "Terrain a batir - Lot 7", shortName: "Terrain Lot 7", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain disponible. Quartier Ouest.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:25000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'corrompre_rdv_notaire', label:'Accélérer le rendez-vous (corruption)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant avant le rendez-vous notarial d\'un achat direct.'},{fn:'payer_versement_chantier', label:'Payer le versement du chantier', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Régler le versement en attente pour que le chantier reprenne.'},{fn:'corrompre_chantier', label:'Accélérer le chantier (corruption)', pa:2, cost:1500, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant du chantier.'},{fn:'voler_materiel_chantier', label:'Voler du matériel de chantier', pa:2, cost:0, type:'illegal', icon:'ti-truck', successRate:0, desc:'Même le propriétaire peut se voler lui-même — mise en scène parodique, bonus de sympathie publique.'},{fn:'diviser_construction', label:'Diviser / gérer les lots', pa:0, cost:0, type:'legal', icon:'ti-grid-dots', successRate:100, desc:'Réservé aux Commerces Premium et Buildings construits.'},{fn:'louer_lot_ici', label:'Louer un lot ici', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Louer un lot disponible, si ce terrain a été divisé par son propriétaire.'},{fn:'gerer_lot_loue', label:'Gérer mon local loué', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:'Voir/accepter les propositions du propriétaire concernant votre lot loué ici.'},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },

  // Cinq nouveaux terrains de Montrouge (Lot 2D, 19 aout 2026) -- id scopes 'terrain-a-batir-
  // montrouge-N' pour eviter toute collision avec les id generiques 'terrain-a-batir-N' deja
  // utilises par d'autres villes/empires (voir le commentaire historique pres de
  // TERRAINS_PAR_VILLE, plateau-justice-economie.js, sur la collision Luthecia/Montrouge du 10
  // aout 2026 qui a motive ce meme choix pour le lot 6). Superficie et prix (12 FR/m², regle
  // deja appliquee aux lots 1-5 de la Chataigneraie) valides par Fred le 19 aout 2026. Ces 5
  // terrains ne sont accessibles que via l'ecran "Terrains a batir de Montrouge" (voir
  // ouvrirTerrainsMontrouge, plateau-rue-centrale.js) ; ne jamais les ajouter a un onclick direct
  // dans une scene de rue.
  'terrain-a-batir-montrouge-3': {
    name: "Terrain a batir - Lot 3 (Montrouge)", shortName: "Terrain — Lot 3", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain à bâtir de Montrouge, Lot 3 (1500 m²).",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche (1500 m²).", imageUrl: "images/montrouge/montrouge-terrain-lot-3.jpg", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain (1500 m² — 18 000 FR)', pa:2, cost:18000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'corrompre_rdv_notaire', label:'Accélérer le rendez-vous (corruption)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant avant le rendez-vous notarial d\'un achat direct.'},{fn:'payer_versement_chantier', label:'Payer le versement du chantier', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Régler le versement en attente pour que le chantier reprenne.'},{fn:'corrompre_chantier', label:'Accélérer le chantier (corruption)', pa:2, cost:1500, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant du chantier.'},{fn:'voler_materiel_chantier', label:'Voler du matériel de chantier', pa:2, cost:0, type:'illegal', icon:'ti-truck', successRate:0, desc:'Même le propriétaire peut se voler lui-même — mise en scène parodique, bonus de sympathie publique.'},{fn:'diviser_construction', label:'Diviser / gérer les lots', pa:0, cost:0, type:'legal', icon:'ti-grid-dots', successRate:100, desc:'Réservé aux Commerces Premium et Buildings construits.'},{fn:'louer_lot_ici', label:'Louer un lot ici', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Louer un lot disponible, si ce terrain a été divisé par son propriétaire.'},{fn:'gerer_lot_loue', label:'Gérer mon local loué', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:'Voir/accepter les propositions du propriétaire concernant votre lot loué ici.'},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-montrouge-7': {
    name: "Terrain a batir - Lot 7 (Montrouge)", shortName: "Terrain — Lot 7", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain à bâtir de Montrouge, Lot 7 (1800 m²).",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche (1800 m²).", imageUrl: "images/montrouge/montrouge-terrain-lot-7.jpg", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain (1800 m² — 21 600 FR)', pa:2, cost:21600, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'corrompre_rdv_notaire', label:'Accélérer le rendez-vous (corruption)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant avant le rendez-vous notarial d\'un achat direct.'},{fn:'payer_versement_chantier', label:'Payer le versement du chantier', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Régler le versement en attente pour que le chantier reprenne.'},{fn:'corrompre_chantier', label:'Accélérer le chantier (corruption)', pa:2, cost:1500, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant du chantier.'},{fn:'voler_materiel_chantier', label:'Voler du matériel de chantier', pa:2, cost:0, type:'illegal', icon:'ti-truck', successRate:0, desc:'Même le propriétaire peut se voler lui-même — mise en scène parodique, bonus de sympathie publique.'},{fn:'diviser_construction', label:'Diviser / gérer les lots', pa:0, cost:0, type:'legal', icon:'ti-grid-dots', successRate:100, desc:'Réservé aux Commerces Premium et Buildings construits.'},{fn:'louer_lot_ici', label:'Louer un lot ici', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Louer un lot disponible, si ce terrain a été divisé par son propriétaire.'},{fn:'gerer_lot_loue', label:'Gérer mon local loué', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:'Voir/accepter les propositions du propriétaire concernant votre lot loué ici.'},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-montrouge-8': {
    name: "Terrain a batir - Lot 8 (Montrouge)", shortName: "Terrain — Lot 8", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain à bâtir de Montrouge, Lot 8 (2200 m²).",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche (2200 m²).", imageUrl: "images/montrouge/montrouge-terrain-lot-8.jpg", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain (2200 m² — 26 400 FR)', pa:2, cost:26400, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'corrompre_rdv_notaire', label:'Accélérer le rendez-vous (corruption)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant avant le rendez-vous notarial d\'un achat direct.'},{fn:'payer_versement_chantier', label:'Payer le versement du chantier', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Régler le versement en attente pour que le chantier reprenne.'},{fn:'corrompre_chantier', label:'Accélérer le chantier (corruption)', pa:2, cost:1500, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant du chantier.'},{fn:'voler_materiel_chantier', label:'Voler du matériel de chantier', pa:2, cost:0, type:'illegal', icon:'ti-truck', successRate:0, desc:'Même le propriétaire peut se voler lui-même — mise en scène parodique, bonus de sympathie publique.'},{fn:'diviser_construction', label:'Diviser / gérer les lots', pa:0, cost:0, type:'legal', icon:'ti-grid-dots', successRate:100, desc:'Réservé aux Commerces Premium et Buildings construits.'},{fn:'louer_lot_ici', label:'Louer un lot ici', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Louer un lot disponible, si ce terrain a été divisé par son propriétaire.'},{fn:'gerer_lot_loue', label:'Gérer mon local loué', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:'Voir/accepter les propositions du propriétaire concernant votre lot loué ici.'},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-montrouge-9': {
    name: "Terrain a batir - Lot 9 (Montrouge)", shortName: "Terrain — Lot 9", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain à bâtir de Montrouge, Lot 9 (2500 m²).",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche (2500 m²).", imageUrl: "images/montrouge/montrouge-terrain-lot-9.jpg", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain (2500 m² — 30 000 FR)', pa:2, cost:30000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'corrompre_rdv_notaire', label:'Accélérer le rendez-vous (corruption)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant avant le rendez-vous notarial d\'un achat direct.'},{fn:'payer_versement_chantier', label:'Payer le versement du chantier', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Régler le versement en attente pour que le chantier reprenne.'},{fn:'corrompre_chantier', label:'Accélérer le chantier (corruption)', pa:2, cost:1500, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant du chantier.'},{fn:'voler_materiel_chantier', label:'Voler du matériel de chantier', pa:2, cost:0, type:'illegal', icon:'ti-truck', successRate:0, desc:'Même le propriétaire peut se voler lui-même — mise en scène parodique, bonus de sympathie publique.'},{fn:'diviser_construction', label:'Diviser / gérer les lots', pa:0, cost:0, type:'legal', icon:'ti-grid-dots', successRate:100, desc:'Réservé aux Commerces Premium et Buildings construits.'},{fn:'louer_lot_ici', label:'Louer un lot ici', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Louer un lot disponible, si ce terrain a été divisé par son propriétaire.'},{fn:'gerer_lot_loue', label:'Gérer mon local loué', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:'Voir/accepter les propositions du propriétaire concernant votre lot loué ici.'},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-montrouge-12': {
    name: "Terrain a batir - Lot 12 (Montrouge)", shortName: "Terrain — Lot 12", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain à bâtir de Montrouge, Lot 12 (3000 m²).",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche (3000 m²).", imageUrl: "images/montrouge/montrouge-terrain-lot-12.jpg", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain (3000 m² — 36 000 FR)', pa:2, cost:36000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'corrompre_rdv_notaire', label:'Accélérer le rendez-vous (corruption)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant avant le rendez-vous notarial d\'un achat direct.'},{fn:'payer_versement_chantier', label:'Payer le versement du chantier', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Régler le versement en attente pour que le chantier reprenne.'},{fn:'corrompre_chantier', label:'Accélérer le chantier (corruption)', pa:2, cost:1500, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant du chantier.'},{fn:'voler_materiel_chantier', label:'Voler du matériel de chantier', pa:2, cost:0, type:'illegal', icon:'ti-truck', successRate:0, desc:'Même le propriétaire peut se voler lui-même — mise en scène parodique, bonus de sympathie publique.'},{fn:'diviser_construction', label:'Diviser / gérer les lots', pa:0, cost:0, type:'legal', icon:'ti-grid-dots', successRate:100, desc:'Réservé aux Commerces Premium et Buildings construits.'},{fn:'louer_lot_ici', label:'Louer un lot ici', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Louer un lot disponible, si ce terrain a été divisé par son propriétaire.'},{fn:'gerer_lot_loue', label:'Gérer mon local loué', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:'Voir/accepter les propositions du propriétaire concernant votre lot loué ici.'},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-1': {
    name: "Terrain a batir - Lot 1 (La Châtaigneraie)",
    shortName: "Lot 1 — Châtaigneraie",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Autrefois un seul grand domaine agricole en périphérie de Luthécia — la Châtaigneraie — ce terrain a été loti en cinq parcelles distinctes, aujourd'hui proposées séparément à la vente.",
    rooms: {
      terrain: {
        name: "Terrain vague",
        image: "🏗️",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Le lot central de la Châtaigneraie (2150 m²), en léger retrait de la route.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},
          {fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},
          {fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},
          {fn:'donner_argent_pnj', label:'Donner de l\'argent', pa:1, cost:0, type:'legal', icon:'ti-coins', successRate:0, desc:'Offrir une somme a un PNJ present. Effet immediat selon sa personnalite.'},
          {fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},
          {fn:'acheter_terrain', label:'Acheter ce terrain (2150 m² — 25 800 FR)', pa:2, cost:25800, type:'legal', icon:'ti-home-plus', successRate:100},
          {fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'corrompre_rdv_notaire', label:'Accélérer le rendez-vous (corruption)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant avant le rendez-vous notarial d\'un achat direct.'},{fn:'payer_versement_chantier', label:'Payer le versement du chantier', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Régler le versement en attente pour que le chantier reprenne.'},{fn:'corrompre_chantier', label:'Accélérer le chantier (corruption)', pa:2, cost:1500, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant du chantier.'},{fn:'voler_materiel_chantier', label:'Voler du matériel de chantier', pa:2, cost:0, type:'illegal', icon:'ti-truck', successRate:0, desc:'Même le propriétaire peut se voler lui-même — mise en scène parodique, bonus de sympathie publique.'},{fn:'diviser_construction', label:'Diviser / gérer les lots', pa:0, cost:0, type:'legal', icon:'ti-grid-dots', successRate:100, desc:'Réservé aux Commerces Premium et Buildings construits.'},{fn:'louer_lot_ici', label:'Louer un lot ici', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Louer un lot disponible, si ce terrain a été divisé par son propriétaire.'},{fn:'gerer_lot_loue', label:'Gérer mon local loué', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:'Voir/accepter les propositions du propriétaire concernant votre lot loué ici.'},
          {fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},
          {fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}
        ]
      }
    }
  },

  // ---- MAIRIE (villes hors capitale) ----
  'mairie': {
    name: "Mairie",
    shortName: "Mairie",
    cat: "Institutions locales",
    icon: "ti-building-community",
    bgColor: "#121810",
    desc: "La mairie locale. Poste de maire accessible. Centre administratif de la ville.",
    rooms: {
      accueil_mairie: {
        name: "Accueil",
        image: "🏫",
        imageBg: "linear-gradient(135deg,#121810,#1a2016)",
        desc: "L'accueil de la mairie. Guichets, formulaires et fonctionnaires.",
        imageUrl: "https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80",
        persons: [
          {name:'Secretaire Municipal', role:'PNJ - Administration', rel:'neutral', job:'secretaire'}
        ],
        orders: [
          {fn:'postuler',      label:'Postuler a un poste',   pa:2, cost:0,  type:'legal', icon:'ti-id-badge',   successRate:100},
          {fn:'gerer_finances',label:'Gerer les finances locales',pa:1,cost:0,type:'legal', icon:'ti-chart-bar',  successRate:100, requiresPost:true},
          {fn:'corrompre_fonct',label:'Corrompre un employ',   pa:2, cost:200,type:'illegal',icon:'ti-coins',     successRate:65},
          {fn:'demander_naturalisation', label:'Demander la naturalisation', pa:2, cost:0, type:'legal', icon:'ti-passport', successRate:100, desc:'Deposer une demande de naturalisation vers un autre empire. Validee par le Ministre de l\'Interieur concerne.'},
          {fn:'demander_mariage', label:'Demander en mariage', pa:1, cost:0, type:'legal', icon:'ti-heart', successRate:100, desc:'Envoyer une demande en mariage a un autre PJ. Necessitera une ceremonie a la mairie pour officialiser.'},
          {fn:'officialiser_mariage', label:'Officialiser un mariage', pa:2, cost:200, type:'legal', icon:'ti-heart-handshake', successRate:100, desc:'Celebrer le mariage. Les deux futurs epoux doivent etre presents.'},
          {fn:'consulter_indices_locaux', label:'Consulter les caisses communales', pa:0, cost:0, type:'legal', icon:'ti-chart-histogram', successRate:100, desc:'Voir le solde reel des caisses du Commissariat, Centre Multimodal, Stade, Marche, Dispensaire et Tribunal.'},
          {fn:'consulter_organigramme_mairie', label:'Consulter l\'organigramme', pa:0, cost:0, type:'legal', icon:'ti-sitemap', successRate:100, desc:'Organigramme national ou municipal, en temps reel. Public et gratuit, aucun poste requis.'}
        ]
      },
      bureau_maire_local: {
        name: "Bureau du Maire",
        image: "🏛",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        desc: "Le bureau du maire. Acces reserve.",
        imageUrl: "https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80",
        persons: [
          {name:'Le Maire (PNJ)', role:'Maire de la ville', rel:'neutral', job:'maire'}
        ],
        orders: [
          {fn:'fixer_impots_locaux',   label:'Fixer les impôts locaux',       pa:2, cost:0, type:'legal', icon:'ti-receipt-tax',  successRate:100, requiresPost:'maire', desc:'Definir le taux de taxation locale.'},
          {fn:'repartition_budget_local', label:'Répartir le budget municipal', pa:2, cost:0, type:'legal', icon:'ti-chart-pie',    successRate:100, requiresPost:'maire', desc:'Repartir les recettes fiscales locales entre Commissariat, Centre Multimodal, Stade, Marche, Dispensaire et Tribunal. Applique chaque nuit, credite directement leur caisse reelle.'},
          {fn:'campagne_securite',     label:'Lancer une campagne de securite',pa:2, cost:500, type:'legal', icon:'ti-shield',     successRate:80,  requiresPost:'maire', desc:'+10 ISN local. Preleve sur budget mairie.'},
          {fn:'nommer_commissaire',    label:'Nommer un commissaire',         pa:3, cost:0, type:'legal', icon:'ti-shield-lock', successRate:100, requiresPost:'maire', desc:'Nommer un PJ habitant de la ville comme commissaire. Poste exclusif (sauf depute).'},
          {fn:'revoquer_commissaire',   label:'Revoquer le commissaire',      pa:1, cost:0, type:'legal', icon:'ti-shield-x', successRate:100, requiresPost:'maire', desc:'Retirer le poste de commissaire au titulaire actuel de la ville.'},
          {fn:'gerer_candidature_maire_adjoint', label:'Gérer les candidatures au Maire Adjoint', pa:1, cost:0, type:'legal', icon:'ti-user-search', successRate:100, requiresPost:'maire', desc:'Candidatures reçues pour le poste de Maire Adjoint de cette ville — sans se déplacer.'}
        ]
      },
      bureau_maire_adjoint: {
        name: "Bureau du Maire Adjoint",
        image: "🏛",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        desc: "Le bureau de l'adjoint au maire. Acces reserve.",
        imageUrl: "https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'traiter_demandes_permis', label:'Traiter les demandes de permis', pa:1, cost:0, type:'legal', icon:'ti-stamp', successRate:100, requiresPost:'maire_adjoint', desc:'Valider ou refuser les permis de construire arrives a instruction terminee, dans cette ville uniquement.'},
          {fn:'acte_officiel_mairie',  label:'Delivrer un acte officiel',     pa:1, cost:0, type:'legal', icon:'ti-file-certificate', successRate:100, requiresPost:'maire_adjoint', desc:'Choisir le type d\'acte a delivrer a un administre.'},
          {fn:'financer_communal',       label:'Financer un batiment communal', pa:1, cost:0, type:'legal', icon:'ti-cash', successRate:100, requiresPost:'maire_adjoint', desc:'Virement instantane depuis la caisse municipale vers un batiment de la ville.'},
          {fn:'gerer_candidature_directeur_entrepot', label:"Gérer les candidatures au Directeur d'Entrepôt", pa:1, cost:0, type:'legal', icon:'ti-user-search', successRate:100, requiresPost:'maire_adjoint', desc:"Candidatures reçues pour le Directeur de l'Entrepôt Logistique de cette ville — sans se déplacer."},
          {fn:'nommer_directeur_entrepot', label:'Nommer un directeur d\'entrepôt', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'maire_adjoint', desc:"Nommer un PJ directeur de l'entrepôt de cette ville. Poste exclusif (sauf député)."},
          {fn:'revoquer_directeur_entrepot', label:"Revoquer le directeur d'entrepôt", pa:1, cost:0, type:'legal', icon:'ti-shield-x', successRate:100, requiresPost:'maire_adjoint', desc:"Retirer le poste de directeur d'entrepôt au titulaire actuel de la ville."}
        ]
      }
    }
  },

  // ---- AUTRES BATIMENTS (versions simplifiees) ----
  'hotel-port': {
    name: "Hotel du Port",
    shortName: "Hotel du Port",
    cat: "Hotellerie",
    icon: "ti-building-castle",
    bgColor: "#0d1018",
    desc: "Hotel modeste mais bien situe. Vue sur le port.",
    rooms: {
      hall_port: {
        name: "Hall",
        imageBg: "linear-gradient(135deg,#0d1018,#141820)",
        desc: "Hall de l'hotel. Matelots, commercants et gens de passage.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotel-du-port-accueil.png",
        persons: [{name:'Jeanine Debré (PNJ)', role:'Gérante', rel:'neutral', job:'hotelier', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-hotel-jeanine-debre.png', photoPos:'45% 25%'}],
        // Raccorde au moteur commerce generique (audit dedie puis correctif du meme jour) :
        // remplace le reliquat se_nourrir (jamais migre -- doSeReposer('se_nourrir'), ancien
        // chemin generique ignorant meme le cost declare ici, ne creditait aucune caisse) par
        // exactement le meme quatuor d'ordres deja deploye a l'Hotel des Mineurs de Montrouge
        // (produire_commerce/consulter_carte_commerce "Petit-dejeuner"/gerer_commerce/
        // vendre_matiere_commerce -- voir BUILDING_COMMERCE_TYPE['hotel-port|hall_port'] et
        // DOTATIONS_COMMERCE_PILOTE['hotel-port|hall_port'], plateau-actions-illegales-
        // rumeurs.js). reserver_chambre_hotel inchange (PA/cout/desc), moteur reservation/
        // sommeil non touche.
        orders: [
          {fn:'produire_commerce', label:'Préparer le petit-déjeuner', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Pas de restaurant ici — juste une petite offre de petit-déjeuner (consomme les matières en stock, rémunéré en FR).'},
          {fn:'consulter_carte_commerce', label:'Petit-déjeuner', pa:1, cost:0, type:'legal', icon:'ti-coffee', successRate:100, desc:'Voir l\'offre de petit-déjeuner et commander.'},
          {fn:'gerer_commerce', label:'Gérer mon commerce', pa:0, cost:0, type:'legal', icon:'ti-settings', successRate:100, desc:'Réservé au propriétaire : coûts de revient, fourchette de prix autorisée, ajustement.'},
          {fn:'vendre_matiere_commerce', label:'Vendre des matières au commerce', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les matières premières de votre inventaire à ce commerce.'},
          {fn:'reserver_chambre_hotel', label:'Réserver une chambre d\'hôtel', pa:0, cost:60, type:'legal', icon:'ti-key', successRate:100, desc:'Bonus de +2 PA et +3 Moral au prochain Dormir passe dans cette chambre.'}
        ]
      },
      chambre_port: {
        name: "Chambre",
        imageBg: "linear-gradient(135deg,#0d1018,#141820)",
        desc: "Une chambre modeste mais propre, avec vue sur le port.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotel-du-port-chambre.png",
        persons: [],
        orders: [
          {fn:'dormir_chambre', label:'Dormir',       pa:0, cost:0,  type:'legal', icon:'ti-moon',  successRate:100, desc:'Necessite une chambre reservee a l\'accueil pour beneficier du bonus.'}
        ]
      }
    }
  },

  'bar-des-pecheurs': {
    name: "Bar des Pecheurs",
    shortName: "Bar des Pecheurs",
    cat: "Restauration",
    icon: "ti-fish",
    bgColor: "#0a0d10",
    desc: "Bar populaire du port. Les pecheurs et contrebandiers s'y retrouvent.",
    // Lot finitions (24 aout 2026, meme jour) : arriere_salle (local a louer) retiree --
    // decision game design, le Bar des Pecheurs ne doit plus avoir de local a louer. Aucune
    // reference codee en dur a cette room ailleurs (moteur de location generique, lit
    // BUILDINGS[...].rooms dynamiquement via isLocationRoom -- verifie plateau-organisations-
    // quetes.js/plateau-justice-economie.js) ; un bail deja actif en base continuerait a etre
    // paye normalement (payerLocations() n'utilise que les valeurs deja stockees sur le bail,
    // jamais une relecture de BUILDINGS), simplement plus visible/gerable depuis ce batiment.
    rooms: {
      salle_bar: {
        name: "Salle du bar",
        imageBg: "linear-gradient(135deg,#0a0d10,#101518)",
        desc: "Atmosphere enfumee, bruit de fond. Tout se negocie ici.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-bar-pecheurs-salle.png",
        persons: [
          {name:'Marin Dulac (PNJ)', role:'Patron du bar', rel:'neutral', job:'barman', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-bar-pecheurs-marin-dulac.png', photoPos:'50% 20%'},
          {name:'René Seigne (PNJ)', role:'Habitué du bar — Informateur', rel:'neutral', job:null, photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-bar-pecheurs-rene-seigne.png', photoPos:'55% 20%'}
        ],
        // Raccordement au moteur bar generique (audit dedie) : reutilise a l'identique les
        // ordres du Bar du Republica (produire_commerce/consulter_carte_commerce/
        // vendre_matiere_commerce/gerer_commerce/boire_verre/offrir_tournee/
        // recruter_informateur_pnj). ecouter_rumeurs raccorde a Marin Dulac via sourceOverride
        // (meme mecanisme que Marco au Bar du Republica). Nettoyage informateurs (24 aout 2026,
        // meme jour) : recruter_informateur_3/recruter_info_3/consulter_info_3 (ancien systeme
        // state.informateurs, bug pre-existant non corrige) retires de CETTE interface
        // uniquement -- fonctions globales (consulterInformateur/ouvrirRecruterInformateur,
        // plateau-actions-illegales-rumeurs.js) et niveaux 1/2/4 ailleurs dans le jeu non
        // touches, INFORMATEUR_NIVEAUX non modifie. recruter_informateur_pnj (systeme moderne
        // PNJ compagnon) conserve. René Seigne reste un figurant narratif, non raccorde a
        // recruter_informateur_pnj dans ce lot.
        orders: [
          {fn:'produire_commerce', label:'Préparer les consommations', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Préparer boissons et snacks pour le service (consomme les matières en stock, rémunéré en FR).'},
          {fn:'consulter_carte_commerce', label:'Consulter la carte', pa:0, cost:0, type:'legal', icon:'ti-menu-2', successRate:100, desc:'Voir ce qui est disponible au bar et commander.'},
          {fn:'boire_verre', label:'Offrir un verre', pa:0, cost:50, type:'legal', icon:'ti-glass', successRate:100, desc:'Invitez un PJ present a boire un verre, a vos frais. Si accepte : +5 Sante, +2 INF, +2 ENT pour chacun. Aucun cout si refuse.'},
          {fn:'offrir_tournee', label:'Offrir une tournée', pa:0, cost:0, type:'legal', icon:'ti-glass-cocktail', successRate:100, desc:'Offrez une tournée (une seule boisson de la carte) à plusieurs personnes présentes, à vos frais. Chacun accepte ou refuse indépendamment ; vous ne buvez et ne payez que si au moins une personne accepte.'},
          {fn:'gerer_commerce', label:'Gérer mon commerce', pa:0, cost:0, type:'legal', icon:'ti-settings', successRate:100, desc:'Réservé au propriétaire : coûts de revient, fourchette de prix autorisée, ajustement.'},
          {fn:'vendre_matiere_commerce', label:'Vendre des matières au commerce', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les matières premières de votre inventaire à ce commerce.'},
          {fn:'ecouter_rumeurs', label:'Ecouter le patron', pa:0, cost:0, type:'grey', icon:'ti-ear', successRate:85, desc:'Marin Dulac entend tout ce qui se dit au bar. Revele une rumeur vraie ou generee selon le contexte.', sourceOverride:'Marin Dulac'},
          // Repris a l'identique du template BUILDINGS['marche'].rooms.marche_ext (meme
          // pa/cost/successRate/desc) -- meme principe que marche-psm : un nouveau point d'acces
          // au meme ordre, aucune variante specifique au bar (audit dedie, 30 aout 2026).
          {fn:'lancer_rumeur_cible', label:'Lancer une rumeur', pa:1, cost:0, type:'grey', icon:'ti-messages', successRate:75, desc:'Rediger une rumeur visant un PJ, une organisation, un local, un gouvernement ou un pays. Succes (75%) : effet selon la cible. Echec : retour de bâton limite + risque de detection.'},
          {fn:'recruter_informateur_pnj', label:'Recruter un informateur', pa:1, cost:150, type:'grey', icon:'ti-user-plus', successRate:100, desc:'1 PA, 150 FR puis 150 FR/jour. Un PNJ (PER 12-18) rejoint votre groupe en permanence tant que vous le payez : sa PER s\'ajoute a celle du groupe pour les recherches, enquetes et localisations.'}
          // "Contacter reseau" (fn:'contrebande') retire (30 aout 2026, ordre abandonne sur
          // demande de Fred). Handler generique (executerOrdreGenerique) et entree ORDER_EFFECTS.
          // contrebande (data.js, table ORDER_EFFECTS) laisses en place : signales comme code mort
          // dans le rapport, hors perimetre de ce lot (pas de nettoyage transversal demande).
        ]
      }
    }
  },

  'siege-syndical': {
    name: "Siege Syndical",
    shortName: "Siege Syndical",
    cat: "Organisations",
    icon: "ti-users-group",
    bgColor: "#100808",
    desc: "Le siege du syndicat ouvrier de Montrouge. Puissant et militant.",
    rooms: {
      bureau_syndical: {
        name: "Bureau syndical",
        image: "✊",
        imageBg: "linear-gradient(135deg,#100808,#180c0c)",
        desc: "Affiches militantes, reunions permanentes.",
        imageUrl: "https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=1200&q=80",
        persons: [{name:'Delegue Morel (PNJ)', role:'Secretaire general du syndicat', rel:'neutral', job:'syndicaliste'}],
        orders: [
          {fn:'mobiliser',    label:'Mobiliser les membres', pa:2, cost:0,   type:'legal', icon:'ti-speakerphone',successRate:70},
          {fn:'greve',        label:'Lancer une greve',      pa:3, cost:0,   type:'grey',  icon:'ti-ban',         successRate:55, desc:'Paralyse l\'economie locale.'}
        ]
      }
    }
  },

  'usine-principale': {
    name: "Usine Principale",
    shortName: "Usine",
    cat: "Industrie - Ressource",
    icon: "ti-building-factory",
    bgColor: "#0a0808",
    desc: "L'usine principale de Montrouge. Rachetable. Genere des revenus passifs.",
    rooms: {
      direction_usine: {
        name: "Direction",
        image: "🏭",
        imageBg: "linear-gradient(135deg,#0a0808,#121010)",
        desc: "Bureau de direction de l'usine.",
        imageUrl: "https://images.unsplash.com/photo-1565793298595-6a879b1d9492?w=1200&q=80",
        persons: [{name:'Directeur Fabre (PNJ)', role:'Directeur usine', rel:'neutral', job:'directeur'}],
        orders: [
          {fn:'acheter_entreprise', label:'Racheter l\'usine', pa:3, cost:8000, type:'legal', icon:'ti-building-factory', successRate:80, desc:'Genere 200 FR/jour en revenus passifs.'}
        ]
      }
    }
  },

  'hotel-mineur': {
    // Nom canonique/generique (partage par 7 villes sur 4 empires -- Montrouge, Frontera Alta,
    // La Selva, Sibirsk-9, Kolkhoz-7, Oasis Al-Baraka, Port Al-Nour). NE PAS renommer en "Hotel
    // de la Victoire" ici : ce nom est specifique a l'override Montrouge/republic (ligne ~411),
    // le poser au niveau canonique le ferait fuiter dans les 6 autres villes. Voir correctif
    // cible dans getCommercesAlimentairesRachetables() (plateau-actions-illegales-rumeurs.js).
    name: "Hotel des Mineurs",
    shortName: "Hotel des Mineurs",
    cat: "Hotellerie",
    icon: "ti-bed",
    bgColor: "#0a0808",
    desc: "Hotel modeste de Montrouge. Clientele ouvriere.",
    rooms: {
      hall_mineur: {
        name: "Hall",
        image: "🏨",
        imageBg: "linear-gradient(135deg,#0a0808,#121010)",
        desc: "Hall simple mais propre.",
        imageUrl: "images/montrouge/montrouge-hotel-victoire-hall.jpg",
        persons: [{name:'Receptionniste (PNJ)', role:'Accueil', rel:'neutral', job:'hotelier'}],
        orders: [
          {fn:'produire_commerce', label:'Préparer le petit-déjeuner', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Pas de restaurant ici — juste une petite offre de petit-déjeuner (consomme les matières en stock, rémunéré en FR).'},
          {fn:'consulter_carte_commerce', label:'Petit-déjeuner', pa:1, cost:0, type:'legal', icon:'ti-coffee', successRate:100, desc:'Voir l\'offre de petit-déjeuner et commander.'},
          {fn:'gerer_commerce', label:'Gérer mon commerce', pa:0, cost:0, type:'legal', icon:'ti-settings', successRate:100, desc:'Réservé au propriétaire : coûts de revient, fourchette de prix autorisée, ajustement.'},
          {fn:'vendre_matiere_commerce', label:'Vendre des matières au commerce', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les matières premières de votre inventaire à ce commerce.'},
          {fn:'reserver_chambre_hotel', label:'Réserver une chambre d\'hôtel', pa:0, cost:60, type:'legal', icon:'ti-key', successRate:100, desc:'Bonus de +2 PA et +3 Moral au prochain Dormir passe dans cette chambre.'}
        ]
      },
      // Salle ajoutee le 2026-08-16 pour aligner l'Hotel de la Victoire sur l'architecture
      // hall+chambre de hotel-port (meme fn 'dormir_chambre', memes mecanismes de
      // plateau-personnage.js:doReserverChambreHotel/doDormirChambre -- confortMap y a deja
      // une entree 'hotel-mineur' identique a 'hotel-port', aucun code JS modifie).
      chambre_mineur: {
        name: "Chambre",
        imageBg: "linear-gradient(135deg,#0a0808,#121010)",
        desc: "Une chambre modeste mais propre.",
        imageUrl: "images/montrouge/montrouge-hotel-victoire-chambre.jpg",
        persons: [],
        orders: [
          {fn:'dormir_chambre', label:'Dormir', pa:0, cost:0, type:'legal', icon:'ti-moon', successRate:100, desc:'Necessite une chambre reservee a l\'accueil pour beneficier du bonus.'}
        ]
      }
    }
  },

  'banque-locale': {
    name: "Banque Locale",
    shortName: "Banque Locale",
    cat: "Finance",
    icon: "ti-building-bank",
    bgColor: "#0d0d08",
    desc: "Succursale bancaire locale. Services de base.",
    rooms: {
      guichet: {
        name: "Guichet",
        image: "🏦",
        imageBg: "linear-gradient(135deg,#0d0d08,#181808)",
        desc: "Guichet unique. Files d'attente raisonnables.",
        imageUrl: "https://images.unsplash.com/photo-1501167786227-4cba60f6d58f?w=1200&q=80",
        persons: [{name:'Guichetier (PNJ)', role:'Employe bancaire', rel:'neutral', job:'banquier'}],
        orders: [
          {fn:'gerer_finances', label:'Gerer mon compte', pa:0, cost:0,   type:'legal', icon:'ti-chart-bar',   successRate:100},
          {fn:'emprunter',      label:'Emprunter',        pa:1, cost:0,   type:'legal', icon:'ti-credit-card', successRate:65}
        ]
      }
    }
  },

  'dispensaire-public-v': {
    name: "Dispensaire Public",
    shortName: "Dispensaire",
    cat: "Sante",
    icon: "ti-first-aid-kit",
    bgColor: "#081008",
    desc: "Soins gratuits. File d'attente.",
    rooms: {
      attente: {
        name: "Salle d'attente",
        image: "⏳",
        imageBg: "linear-gradient(135deg,#081008,#0c180c)",
        desc: "Salle bondee. Patience requise.",
        imageUrl: "images/montrouge/montrouge-hopital-accueil.jpg",
        persons: [{name:'Infirmiere (PNJ)', role:'Soignante', rel:'neutral', job:'infirmier'}],
        orders: [
          {fn:'soin_public', label:'Soin standard', pa:0, cost:25, type:'legal', icon:'ti-bandage', successRate:100, desc:'+10 Sante, +1 PA immediat. 1 fois par jour (commun aux 3 dispensaires publics de Republia). Consomme 1 desinfectant du stock local.'},
          {fn:'vendre_ressource_medicale', label:'Fournir des ressources médicales', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre au dispensaire, depuis votre inventaire, du desinfectant.'}
        ]
      },
      // Salle minimale ajoutee le 2026-08-16, meme principe que ehpad_tilleuls a Luthecia
      // (BUILDINGS['dispensaire-public'].rooms.ehpad_tilleuls) : l'EHPAD est une salle du
      // dispensaire, pas un batiment separe. orders:[] comme a Luthecia ; aucun PNJ invente.
      ehpad: {
        name: "EHPAD de Montrouge",
        imageBg: "linear-gradient(135deg,#141008,#1c1810)",
        desc: "Le salon commun de l'EHPAD, rattache au dispensaire de Montrouge.",
        imageUrl: "images/montrouge/montrouge-ehpad-salle-commune.jpg",
        persons: [],
        orders: []
      }
    }
  },

  'commissariat-local': {
    name: "Commissariat Local",
    shortName: "Commissariat",
    cat: "Securite",
    icon: "ti-shield-lock",
    bgColor: "#0f1018",
    desc: "Commissariat de ville. Moins de moyens que la capitale.",
    rooms: {
      accueil_loc: {
        name: "Accueil",
        image: "🚔",
        imageBg: "linear-gradient(135deg,#0f1018,#151822)",
        desc: "Accueil du commissariat.",
        imageUrl: "images/montrouge/montrouge-commissariat-accueil.jpg",
        persons: [{name:'Brigadier Local (PNJ)', role:'Officier de garde', rel:'neutral', job:'policier'}],
        // Lot policiers PNJ (24 aout 2026) : ordres partages Montrouge/PSM via ce meme template
        // (commissariat-local), memes fn/handlers qu'a Luthecia (recruter_policier/
        // gerer_effectifs_police, plateau-justice-economie.js) -- aucun handler duplique par
        // ville, isolation garantie par (pays, ville) a l'interieur des fonctions elles-memes.
        orders: [
          {fn:'plainte_police',   label:'Porter plainte',      pa:1, cost:0,   type:'legal',   icon:'ti-file-text', successRate:100},
          {fn:'recruter_policier',      label:'Recruter un policier', pa:1, cost:0, type:'legal', icon:'ti-user-plus',   successRate:100, requiresPost:'commissaire', desc:'PER 12, VOL 12. Entretien : 50 FR/jour preleves sur la caisse du commissariat.'},
          {fn:'recruter_policier_cynophile', label:'Recruter une unite cynophile', pa:1, cost:0, type:'legal', icon:'ti-dog', successRate:100, requiresPost:'commissaire', desc:'Maitre-chien + chien anti-stupefiants. Membre normal du groupe (memes regles PER/VOL). Entretien : 100 FR/jour preleves sur la caisse du commissariat.'},
          {fn:'gerer_effectifs_police', label:'Gerer mes effectifs',  pa:0, cost:0, type:'legal', icon:'ti-users-group', successRate:100, requiresPost:'commissaire', desc:'Affecter ou rappeler vos policiers (piece ou rue de votre ville).'}
        ]
      },
      // Salle ajoutee le 2026-08-16, orders raccordes le 26 aout 2026 (lot "ordres carceraux
      // hors Luthecia") : les mecaniques de detention etaient jusque-la codees en dur sur
      // buildingId === 'commissariat' (Luthecia uniquement), alors que la chaine judiciaire
      // permet desormais une incarceration reelle a Montrouge/PSM. Memes fn/handlers qu'a
      // Luthecia (BUILDINGS['commissariat'].rooms.prison, plateau-justice-economie.js,
      // plateau-router.js) -- aucun handler duplique, partages tels quels via ce meme template
      // (commissariat-local) entre Montrouge et PSM, meme principe que les orders policiers
      // d'accueil_loc ci-dessus. Les fonctions elles-memes (doSeRebeller/doTentativeEvasion/
      // doRequeteAvocat) agissent deja sur state.estEmprisonne, l'etat carceral REEL du
      // personnage courant, jamais sur un batiment/une ville supposee.
      geoles: {
        name: "Geôles",
        imageBg: "linear-gradient(135deg,#0f1018,#151822)",
        desc: "Les cellules de garde à vue du commissariat de Montrouge.",
        imageUrl: "images/montrouge/montrouge-commissariat-geoles.jpg",
        persons: [],
        orders: [
          {fn:'requete_avocat',  label:'Requérir les services d\'un avocat', pa:1, cost:0,    type:'legal',   icon:'ti-scale',      successRate:100, desc:'Contacte votre avocat. Reduit les risques de condamnation.'},
          {fn:'se_rebeller',     label:'Se rebeller',                        pa:2, cost:0,    type:'illegal', icon:'ti-flame',      successRate:30,  desc:'Reserve aux emprisonnes. Defi bruyant aux gardiens : succes = +DIS mais peine allongee, echec = transfert au QHS. Endommage les grilles dans tous les cas.'},
          {fn:'tentative_evasion',label:'Tenter de s\'evader',               pa:3, cost:0,    type:'illegal', icon:'ti-run',        successRate:10,  desc:'Tres risque, une tentative par jour. Succes : liberte. Echec : transferement en prison.'}
        ]
      }
    }
  },

  'tribunal-local': {
    name: "Tribunal Municipal",
    shortName: "Tribunal",
    cat: "Justice",
    icon: "ti-gavel",
    bgColor: "#1a1408",
    desc: "Le tribunal de la ville. Plus modeste que celui de la capitale, mais tout aussi solennel.",
    rooms: {
      salle_audience_locale: {
        name: "Salle d'audience",
        image: "⚖️",
        imageBg: "linear-gradient(135deg,#1a1408,#24180a)",
        desc: "La salle d'audience municipale.",
        imageUrl: "https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=1200&q=80",
        persons: [
          {name:'Juge Local (PNJ)', role:'President du Tribunal Municipal', rel:'neutral', job:'juge'}
        ],
        orders: [
          {fn:'plainte',   label:'Consulter les affaires', pa:0, cost:0,   type:'legal',   icon:'ti-gavel',   successRate:100, desc:'Voir les affaires transmises par la police, en attente de jugement.'},
          {fn:'defense',   label:'Se defendre',           pa:2, cost:300, type:'legal',   icon:'ti-shield',  successRate:50, desc:'Taux : 50% de base + CHA - malus si preuve reelle contre vous. Reussite eclatante = affaire classee ; reussite simple = circonstance attenuante ; echec flagrant = aggravation.'},
          {fn:'rendre_sentence', label:'Rendre la sentence', pa:2, cost:0, type:'legal', icon:'ti-scale', successRate:100, requiresPost:'juge', desc:'Juger une affaire transmise par le commissariat. Amende, prison, amenagement ou QHS.'}
        ]
      }
    }
  },

  // ---- IMPRIMERIE-LIBRAIRIE ----
  'imprimerie-librairie': {
    name: "Imprimerie-Librairie Gutenberg",
    shortName: "Imprimerie",
    cat: "Medias - Information",
    icon: "ti-printer",
    bgColor: "#0f0d08",
    desc: "La seule imprimerie de Port-Sainte-Marie. On y imprime livres, journaux et tracts. Discrets ou non.",
    rooms: {
      accueil_imprimerie: {
        name: "Accueil / Bureau",
        imageBg: "linear-gradient(135deg,#0f0d08,#1a1608)",
        desc: "Le bureau d'accueil de l'imprimerie. Odeur d'encre et de papier.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-imprimerie-accueil.png",
        persons: [
          {name:'Annie Talique-Legall (PNJ)', role:'PNJ - Proprietaire imprimerie', rel:'neutral', job:'imprimeur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-imprimerie-annie-talique-legall.png', photoPos:'50% 25%'}
        ],
        // Lot tracts electoraux/calomnieux (24 aout 2026) : imprimer_tracts (partage avec
        // la-tribune) retire d'ici, remplace par imprimer_tracts_electoraux, fn dediee et
        // PROPRE A PSM (aucun risque de toucher Luthecia/Montrouge, qui continuent d'utiliser
        // imprimer_tracts/ouvrirModalImprimerTracts/confirmerImpression a l'identique). Cout
        // reel : 1 PA + bois en stock personnel (voir BOIS_PAR_LOT_TRACTS_PSM,
        // plateau-communication.js) -- pas de systeme caisse/stock institutionnel comme Gustave.
        // imprimer_tracts_sportifs retire (mecanique abandonnee, voir plateau-organisations-
        // quetes.js). imprimer_livre retire (abandonne, jamais eu d'effet reel utile).
        orders: [
          {fn:'imprimer_tracts_electoraux', label:'Imprimer des tracts électoraux', pa:1, cost:0, type:'legal', icon:'ti-file-description', successRate:100, desc:'Choisir un candidat en campagne. Produit un lot de 10 tracts en sa faveur. Coût : 1 PA + bois en stock personnel.'}
        ]
      },
      atelier: {
        name: "Atelier d'Imprimerie",
        imageBg: "linear-gradient(135deg,#0a0a08,#141208)",
        desc: "L'atelier en activite permanente. Presses, rouleaux d'encre, odeur caracteristique.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-imprimerie-atelier.png",
        // Ouvrier typographe (PNJ) conserve tel quel, purement visuel -- aucune mecanique dediee
        // dans ce lot (aucun autre atelier du jeu n'a de PNJ avec fonction mecanique reelle).
        persons: [
          {name:'Ouvrier typographe (PNJ)', role:'PNJ - Typographe', rel:'neutral', job:'typographe'}
        ],
        // imprimer_clandestin renomme imprimer_tracts_calomnieux (24 aout 2026) : devient une
        // vraie mecanique (campagne mensongere ciblee, -5 POP a la distribution). Reutilise le
        // mecanisme de detection existant a l'impression (checkDetection/ACTES_ILLEGAUX, cle
        // renommee a l'identique dans plateau-core.js). Cout reel : 1 PA + bois en stock
        // personnel, meme principe que le tract electoral.
        orders: [
          {fn:'imprimer_tracts_calomnieux', label:'Imprimer des tracts calomnieux', pa:1, cost:0, type:'illegal', icon:'ti-eye-off', successRate:100, desc:'Choisir une cible (répertoire). Campagne mensongère clandestine. Produit un lot de 10 tracts calomnieux. Coût : 1 PA + bois en stock personnel.'}
        ]
      }
    }
  },

  'marche-psm': {
    name: "Marche de Port-Sainte-Marie",
    shortName: "Marche",
    cat: "Commerce",
    icon: "ti-shopping-cart",
    bgColor: "#0a0c08",
    desc: "Etals de poissonniers, marchands de legumes et creperies, dans la ruelle qui remonte vers l'Hotel de Ville.",
    rooms: {
      etals: {
        name: "Les Etals",
        image: "\ud83e\udd6c",
        imageBg: "linear-gradient(135deg,#0a0c08,#10140c)",
        desc: "Poissons frais, legumes de saison et l'odeur du pain chaud de la boulangerie.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-marche.png",
        // Lot 5B (24 aout 2026) : 2 PNJ de presence/personnalisation, meme structure que les
        // marches de Luthecia/Montrouge (Jean-Pierre Bidoche/Ginette Legume/Josette Betterave --
        // job:'commercant', pas le job:'marchande' du template generique BUILDINGS['marche']).
        // Aucun ordre ni mecanique individuelle : les achats passent uniquement par le bouton
        // generique "Faire des achats". photoUrl relatif + photoPos, meme convention que Marine
        // Leroux (Capitaine Sauvage, ajoutee la meme journee) -- images decoupees depuis le
        // composite source (~/Downloads/PSM vendeurs marche.png, jamais modifie), un fichier par
        // PNJ.
        persons: [
          {name:'Mireille Legall (PNJ)', role:'Marchande de poisson', rel:'neutral', job:'commercant', photoUrl:'images/port-sainte-marie-marche-mireille-legall.png', photoPos:'50% 15%'},
          {name:'Bastien Leroux (PNJ)', role:'Vendeur de souvenirs', rel:'neutral', job:'commercant', photoUrl:'images/port-sainte-marie-marche-bastien-leroux.png', photoPos:'50% 15%'}
        ],
        // Lot 5A -- Faire des achats (24 aout 2026) : premier raccordement reel de ce marche
        // (orders vide jusqu'ici, jamais visite). Pas de se_nourrir/pouls_populaire a masquer --
        // ce batiment n'herite d'aucun template partage (buildingId propre 'marche-psm', pas
        // 'marche'), ces deux ordres n'y ont jamais existe. distribuer_tract/lancer_rumeur_cible
        // repris a l'identique du template BUILDINGS['marche'] (memes pa/cost/successRate/desc)
        // pour rester coh\u00e9rents avec Luthecia/Montrouge.
        orders: [
          {fn:'produire_commerce', label:'Produire les articles du march\u00e9', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Produire les articles en vente au march\u00e9 (consomme les mati\u00e8res en stock, r\u00e9mun\u00e9r\u00e9 en FR).'},
          {fn:'faire_achats_marche', label:'Faire des achats', pa:0, cost:0, type:'legal', icon:'ti-shopping-bag', successRate:100, desc:'Nourriture \u00e0 emporter, souvenir local, cartes postales.'},
          {fn:'vendre_matiere_commerce', label:'Vendre des mati\u00e8res au march\u00e9', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les mati\u00e8res premi\u00e8res de votre inventaire \u00e0 ce march\u00e9.'},
          {fn:'distribuer_tract', label:'Distribuer un tract', pa:1, cost:0, type:'legal', icon:'ti-file-description', successRate:70, desc:'Necessite un tract en inventaire. Donne un vote au candidat du tract.', requiresTract:true},
          {fn:'lancer_rumeur_cible', label:'Lancer une rumeur', pa:1, cost:0, type:'grey', icon:'ti-messages', successRate:75, desc:'Rediger une rumeur visant un PJ, une organisation, un local, un gouvernement ou un pays. Succes (75%) : effet selon la cible. Echec : retour de bâton limite + risque de detection.'}
        ]
      }
    }
  },
  'capitaine-sauvage': {
    name: "Le Capitaine Sauvage",
    shortName: "Capitaine Sauvage",
    cat: "Restauration",
    icon: "ti-anchor",
    bgColor: "#0a0806",
    desc: "Bar-restaurant face au port, ambiance marine et maritime.",
    rooms: {
      salle_principale: {
        name: "Salle Principale",
        image: "\u2693",
        imageBg: "linear-gradient(135deg,#0a0806,#12100a)",
        desc: "Tables en terrasse face aux bateaux de pêche. L'ambiance du Capitaine Sauvage.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-resto-capitaine-sauvage.png",
        persons: [
          {name:'Marine Leroux (PNJ)', role:'Serveuse', rel:'neutral', job:'serveur', photoUrl:'images/port-sainte-marie-pnj-marine-leroux.png', photoPos:'50% 15%'}
        ],
        // Memes 7 ordres que hotel-republica.restaurant (Luthecia), raccordes au meme moteur
        // generique -- fn/label/pa/cost/desc repris a l'identique, aucun recalibrage (audit du
        // 23 aout 2026). Voir BUILDING_COMMERCE_TYPE/DOTATIONS_COMMERCE_PILOTE
        // (plateau-actions-illegales-rumeurs.js) pour le raccordement du commerce lui-meme.
        // Correctif du 23 aout 2026 : diner_affaires passe de 300 a 150 FR -- les 300 FR
        // avaient ete herites de Luthecia lors de la copie initiale des ordres (audit dedie),
        // mais la carte definitive de PSM est volontairement moins chere (menus a ~20-21 FR
        // contre 120 FR a Luthecia) -- le diner d'affaires doit suivre. Rien d'autre change :
        // memes bonus, meme cout PA, meme consommation (2 menus + 1 vin), meme fiscalite/caisse,
        // aucune recette modifiee. hotel-republica|restaurant (Luthecia) reste a 300 FR,
        // inchange.
        orders: [
          {fn:'diner_affaires', label:'Diner d\'affaires', pa:2, cost:150, type:'legal', icon:'ti-wine', successRate:100, desc:'Invitez un PJ present dans la piece a diner, a vos frais. Si accepte : consomme 2 menus + 1 vin du restaurant. +10 Sante, +2 Moral, +5 INF, +3 PA au prochain Dormir pour chacun. Aucun cout si refuse ou si le restaurant n\'a pas de quoi servir.'},
          {fn:'ecouter_rumeurs', label:'Ecouter les tables',  pa:0, cost:0,   type:'grey',   icon:'ti-ear',      successRate:95,  desc:'Revele une rumeur vraie (action recente tracee) ou, a defaut, une information generee selon le contexte.'},
          {fn:'lancer_rumeur_cible', label:'Lancer une rumeur', pa:1, cost:0, type:'grey', icon:'ti-messages', successRate:75, desc:'Rediger une rumeur visant un PJ, une organisation, un local, un gouvernement ou un pays. Succes (75%) : effet selon la cible. Echec : retour de bâton limite + risque de detection.'},
          {fn:'produire_commerce', label:'Cuisiner', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Préparer un plat de la carte (consomme les matières en stock, rémunéré en FR).'},
          {fn:'consulter_carte_commerce', label:'Consulter la carte', pa:0, cost:0, type:'legal', icon:'ti-menu-2', successRate:100, desc:'Voir les plats disponibles et commander.'},
          {fn:'gerer_commerce', label:'Gérer mon commerce', pa:0, cost:0, type:'legal', icon:'ti-settings', successRate:100, desc:'Réservé au propriétaire : coûts de revient, fourchette de prix autorisée, ajustement.'},
          {fn:'vendre_matiere_commerce', label:'Vendre des matières au commerce', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les matières premières de votre inventaire à ce commerce.'}
        ]
      }
    }
  },
  'chasse-peche-psm': {
    name: "Maison Le Gall — Chasse et Pêche",
    shortName: "Chasse &amp; Pêche",
    cat: "Commerce",
    icon: "ti-fish",
    bgColor: "#0a0c08",
    desc: "Armurerie locale specialisee chasse et peche. Armes, munitions, appats et vetements.",
    rooms: {
      boutique: {
        name: "Boutique",
        image: "\ud83c\udfaf",
        imageBg: "linear-gradient(135deg,#0a0c08,#10140c)",
        desc: "Rateliers d'armes, cannes a peche et equipements de chasse.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/armurerie-port-sainte-marie-maison-le-gall.png",
        // Victor Legall (PNJ), meme jour : job 'commercant' reutilise (deja le job fonctionnel
        // de Roger Detente, role "Armurier" a l'Armurerie Martinon de Luthecia -- 'armurier'
        // n'existe pas dans PNJ_STATS_PAR_JOB, seul 'commercant' y resout de vraies stats).
        persons: [{name:'Victor Legall (PNJ)', role:'Armurier', rel:'neutral', job:'commercant', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-armurerie-victor-legall.png', photoPos:'50% 30%'}],
        // Raccordement au moteur armurerie generique existant (audit dedie du 24 aout 2026,
        // confirme : entreprise/caisse/stock/registre 'armurerie-republic-ville_a' deja isoles
        // par ville, aucune migration necessaire). 4 ordres standards, memes libelles/PA/couts
        // que BUILDINGS['armurerie'] -- jamais marche_noir, reste specifique a Luthecia
        // (buildingContext.armurerie.orders, capitale uniquement). Personnalisation d'affichage
        // des armes (nom/image locale) geree par ARMES_OVERRIDES_VILLE/resoudreArmeAffichage,
        // plateau-actions-illegales-rumeurs.js -- jamais par un nouvel ordre ici.
        orders: [
          {
            fn:'choisir_arme',
            label:'Acheter une arme',
            pa:1, cost:0, type:'grey', icon:'ti-sword', successRate:100,
            desc:'Couteau, revolver ou carabine — achat légal (enregistré) ou marché noir (3x le prix), au choix pour chaque arme.'
          },
          {
            fn:'acheter_gilet',
            label:'Acheter un gilet pare-balles',
            pa:1, cost:600, type:'legal', icon:'ti-shield-check', successRate:100,
            desc:'Protection physique. Enregistre dans le registre.',
            imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-gilet-republic.png'
          },
          {
            fn:'consulter_registre_armes',
            label:'Consulter le registre de vente',
            pa:1, cost:0, type:'legal', icon:'ti-book', successRate:100,
            desc:'Acces libre : Commissaire, Juge. Sinon : soudoyer l\'armurier (30%, 100 FR, +/-5 INF et POP). Ventes des 6 derniers mois.'
          },
          {fn:'produire_arme', label:'Produire une arme', pa:0, cost:0, type:'legal', icon:'ti-hammer', successRate:100, desc:'Fabrication contre salaire fixe : 2 PA, 100 FR par arme. Necessite des matieres en stock et une caisse suffisante.'}
        ]
      }
    }
  },
  'place-armes-psm': {
    name: "Place d'Armes de Port-Sainte-Marie",
    shortName: "Place d'Armes",
    cat: "Institutions",
    icon: "ti-flag",
    bgColor: "#0a0a0c",
    desc: "L'ancienne place fortifiee de la ville, face a la mer.",
    rooms: {
      place: {
        name: "Place d'Armes",
        image: "\ud83c\udff0",
        imageBg: "linear-gradient(135deg,#0a0a0c,#101014)",
        desc: "Le vent souffle sur les remparts. Vue degagee sur la mer.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-place.png",
        persons: [],
        orders: []
      }
    }
  },
  // Ecole de Marine Mariannaise de PSM (lot du 24 aout 2026) : buildingId et hotspot rue
  // (psm-ecole-phare, plateau-rue-centrale.js, meme scene que le phare) deja existants et deja
  // correctement raccordes -- aucune navigation touchee. Room 'hall' deja existante (orders:[]
  // deja vide, rien a signaler/preserver) simplement rebaptisee et habillee. Nouvelle room
  // 'salle_cours' ajoutee. persons:[] dans les deux rooms pour l'instant : le directeur visible
  // sur l'image du hall n'a pas encore de nom arrete (voir rapport), aucun PNJ generique cree en
  // attendant l'arbitrage. orders:[] dans les deux : aucune mecanique de formation/diplome/
  // brevet cette fois-ci, volontairement reporte.
  'ecole-marine': {
    name: "Ecole de Marine de Port-Sainte-Marie",
    shortName: "Ecole de Marine",
    cat: "Education",
    icon: "ti-school",
    bgColor: "#08090c",
    desc: "Formation des futurs marins et officiers de la marine marchande.",
    rooms: {
      hall: {
        name: "Hall d'accueil",
        imageBg: "linear-gradient(135deg,#08090c,#0d0f14)",
        desc: "Maquettes de navires, sextant et portraits d'anciens capitaines sous une grande verriere.",
        imageUrl: "images/port-sainte-marie-ecole-marine-hall.png",
        persons: [
          {name:'Maxime Bonvent (PNJ)', role:'Directeur de l\'École de Marine Mariannaise', rel:'neutral', job:'directeur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-ecole-marine-maxime-bonvent.png', photoPos:'50% 15%'}
        ],
        orders: []
      },
      salle_cours: {
        name: "Salle de cours",
        imageBg: "linear-gradient(135deg,#08090c,#0d0f14)",
        desc: "Les eleves y apprennent aussi bien la navigation traditionnelle que les techniques maritimes contemporaines.",
        imageUrl: "images/port-sainte-marie-ecole-marine-salle-cours.png",
        persons: [],
        orders: []
      }
    }
  },
  'chantier-naval': {
    name: "Chantier Naval de Port-Sainte-Marie",
    shortName: "Chantier Naval",
    cat: "Economie - Matieres premieres",
    icon: "ti-anchor",
    bgColor: "#0a0a08",
    desc: "Construction et reparation de bateaux de peche et de plaisance.",
    rooms: {
      hall: {
        name: "Entrée du Chantier",
        imageBg: "linear-gradient(135deg,#0a0a08,#10100c)",
        desc: "L'entree du chantier naval de Port-Sainte-Marie, entre coques en reparation et bateaux en cale.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-chantier-naval-psm.png",
        persons: [],
        orders: []
      },
      bureau: {
        name: "Bureau",
        imageBg: "linear-gradient(135deg,#141008,#1c160c)",
        desc: "Le bureau du Chantier Naval Le Roux, fonde par Yves Le Roux (1932-1987). Plans de coques, devis, souvenirs de la Brise Mariannaise aux murs.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-chantier-naval-psm.png",
        persons: [
          {name:'Pierrick Le Roux (PNJ)', role:'PNJ - Chef d\'entreprise du Chantier Naval', rel:'neutral', job:'chef_entreprise', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-chantier-naval-psm.png', photoPos:'62% 22%'}
        ],
        orders: []
      }
    }
  },
  'notre-dame-mer': {
    name: "Notre-Dame de la Mer & Cimetière Marin",
    shortName: "Notre-Dame de la Mer",
    cat: "Religion",
    icon: "ti-building-church",
    bgColor: "#08080a",
    desc: "Chapelle des marins et son cimetiere attenant, sur une avancee rocheuse dominant la mer.",
    rooms: {
      hall: {
        name: "Accueil",
        imageBg: "linear-gradient(135deg,#08080a,#0d0d10)",
        desc: "Vestibule commun a la chapelle et au cimetiere, sur la pointe rocheuse dominant la mer.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-notre-dame-mer-psm.png",
        persons: [],
        orders: []
      },
      // Socle religieux (lot "carriere religieuse Republia", 26 aout 2026) : actions de lieu
      // (prier/don) memes fn/handlers qu'a Luthecia (aucun handler duplique). Pere Iscope,
      // religieux local de reference et titulaire PNJ initial de la charge de Pretre de
      // Port-Sainte-Marie, rend desormais confession/benediction/consulter la regle disponibles
      // ici (voir openPnjModal, plateau-pnj.js -- job:'pretre' ajoute a la liste habilitee).
      nef: {
        name: "Nef",
        image: "\u26ea",
        imageBg: "linear-gradient(135deg,#08080a,#0d0d10)",
        desc: "Ex-voto de marins accroches aux murs. Silence et recueillement.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/notre-dame-mer-nef.png",
        persons: [
          {name:'P\u00e8re Iscope (PNJ)', role:'Pr\u00eatre de Port-Sainte-Marie', rel:'neutral', job:'pretre'}
        ],
        orders: [
          {fn:'prier',     label:'Prier le Formulaire Sacr\u00e9',  pa:1, cost:0,   type:'legal', icon:'ti-star',  successRate:100, desc:'Vous priez pour vous-m\u00eame (+2 Moral) tout en nourrissant la ferveur religieuse de Port-Sainte-Marie (+3 pi\u00e9t\u00e9 locale).'},
          {fn:'faire_don', label:'Faire un don a l\'Eglise',   pa:1, cost:200, type:'legal', icon:'ti-coins', successRate:100, desc:'200 FR pris sur votre argent personnel. +3 popularit\u00e9 pour vous, +5 pi\u00e9t\u00e9 locale pour Port-Sainte-Marie.'}
        ]
      },
      tombe: {
        name: "Tombe de Yann Le Goff",
        image: "\u2693",
        imageBg: "linear-gradient(135deg,#08080a,#0c0c0e)",
        desc: "Une sobre pierre tombale, tournee vers l'horizon. Une inscription discrete rappelle qu'il croyait en la justice des hommes et en la bonte de leurs intentions.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tombe-yann-le-goff-psm.png",
        persons: [],
        orders: []
      }
    }
  },
  // Phare de PSM (lot du 24 aout 2026) : buildingId et hotspot rue (psm-ecole-phare, plateau-
  // rue-centrale.js) deja existants et deja correctement raccordes -- aucune navigation touchee.
  // Unique room repurposee (anciennement 'base'/"Base du Phare" avec un gardien decoratif jamais
  // fonctionnel, job 'gardien_phare' sans entree PNJ_STATS_PAR_JOB) en 'sommet'/"Sommet du
  // phare", conformement au principe valide : un seul batiment accessible, une seule room, le
  // joueur arrive directement au sommet. persons:[] volontairement (aucun PNJ pour l'instant).
  // orders:[] volontairement : Allumer/Eteindre le phare et Observer au large sont reportes,
  // aucun bouton/handler cree en anticipation.
  'phare-psm': {
    name: "Phare de Port-Sainte-Marie",
    shortName: "Phare",
    cat: "Transport",
    icon: "ti-lighthouse",
    bgColor: "#08090c",
    desc: "Le phare qui guide les bateaux depuis des generations.",
    rooms: {
      sommet: {
        name: "Sommet du phare",
        imageBg: "linear-gradient(135deg,#08090c,#0d0f14)",
        desc: "La lanterne du phare domine Port-Sainte-Marie et offre une vue panoramique sur la ville, les ports et le large.",
        imageUrl: "images/port-sainte-marie-phare-sommet.png",
        persons: [],
        orders: []
      }
    }
  },
  // Port de plaisance de PSM (lot du 24 aout 2026) : buildingId deja existant, exclusif a PSM
  // (seule occurrence dans tous les "buildings" du jeu, aucun risque de partage/heritage avec
  // Montrouge ou Luthecia -- modifie donc directement ici, sans buildingContext/roomOverrides).
  // Room 'quai' renommee en 'port_plaisance' (aucune reference codee en dur a l'ancienne cle
  // 'quai' trouvee ailleurs dans le jeu, aucun risque) pour correspondre au nom affiche demande.
  // Nouvelle room 'capitainerie' ajoutee avec Patrice Lecap. orders: [] dans les deux rooms,
  // aucune mecanique portuaire (anneaux, bateaux, navigation, taxes...) : volontairement reporte.
  'port-plaisance-psm': {
    name: "Port de Plaisance de Port-Sainte-Marie",
    shortName: "Port de Plaisance",
    cat: "Port",
    icon: "ti-sailboat",
    bgColor: "#050810",
    desc: "Voiliers et bateaux de plaisance, face au retour de facade de la banque.",
    rooms: {
      port_plaisance: {
        name: "Port de plaisance",
        image: "\u26f5",
        imageBg: "linear-gradient(135deg,#050810,#0a0f18)",
        desc: "Voiliers et bateaux de plaisance amarres le long du quai, grande ouverture sur la mer.",
        imageUrl: "images/port-sainte-marie-port-plaisance.png",
        persons: [],
        orders: []
      },
      capitainerie: {
        name: "Capitainerie",
        imageBg: "linear-gradient(135deg,#050810,#0a0f18)",
        desc: "Le poste de vigie du port : radios, cartographie et vue sur l'entree du chenal.",
        imageUrl: "images/port-sainte-marie-capitainerie.png",
        persons: [
          {name:'Patrice Lecap (PNJ)', role:'Chef de la capitainerie', rel:'neutral', job:null, photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-capitainerie-patrice-lecap.png', photoPos:'50% 15%'}
        ],
        orders: []
      }
    }
  },
  'terrain-a-batir-8': {
    name: "Terrain a batir - Lot 8",
    shortName: "Terrain Lot 8",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Terrain a Port-Sainte-Marie.",
    rooms: {
      terrain8: {
        name: "Terrain",
        image: "\ud83c\udfd7\ufe0f",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Terrain de 1500m2 a Port-Sainte-Marie.",
        persons: [],
        orders: [
          {fn:'acheter_terrain',  label:'Acheter ce terrain',       pa:2, cost:3500, type:'legal',   icon:'ti-home-plus', successRate:100},
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'}
        ]
      }
    }
  },
  'terrain-a-batir-9': {
    name: "Terrain a batir - Lot 9",
    shortName: "Terrain Lot 9",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Terrain a Port-Sainte-Marie.",
    rooms: {
      terrain9: {
        name: "Terrain",
        image: "\ud83c\udfd7\ufe0f",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Terrain de 1500m2 a Port-Sainte-Marie.",
        persons: [],
        orders: [
          {fn:'acheter_terrain',  label:'Acheter ce terrain',       pa:2, cost:3500, type:'legal',   icon:'ti-home-plus', successRate:100},
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'}
        ]
      }
    }
  },
  'terrain-a-batir-10': {
    name: "Terrain a batir - Lot 10",
    shortName: "Terrain Lot 10",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Terrain a Port-Sainte-Marie.",
    rooms: {
      terrain10: {
        name: "Terrain",
        image: "\ud83c\udfd7\ufe0f",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Terrain de 1500m2 a Port-Sainte-Marie.",
        persons: [],
        orders: [
          {fn:'acheter_terrain',  label:'Acheter ce terrain',       pa:2, cost:3500, type:'legal',   icon:'ti-home-plus', successRate:100},
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'}
        ]
      }
    }
  },
  'terrain-a-batir-11': {
    name: "Terrain a batir - Lot 11",
    shortName: "Terrain Lot 11",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Terrain a Port-Sainte-Marie.",
    rooms: {
      terrain11: {
        name: "Terrain",
        image: "\ud83c\udfd7\ufe0f",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Terrain de 1500m2 a Port-Sainte-Marie.",
        persons: [],
        orders: [
          {fn:'acheter_terrain',  label:'Acheter ce terrain',       pa:2, cost:3500, type:'legal',   icon:'ti-home-plus', successRate:100},
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'}
        ]
      }
    }
  },
  'terrain-a-batir-2': {
    name: "Terrain a batir - Lot 2 (La Châtaigneraie)",
    shortName: "Lot 2 — Châtaigneraie",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Autrefois un seul grand domaine agricole en périphérie de Luthécia — la Châtaigneraie — ce terrain a été loti en cinq parcelles distinctes, aujourd'hui proposées séparément à la vente.",
    rooms: {
      terrain2: {
        name: "Terrain",
        image: "🏗️",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Lot d'angle de la Châtaigneraie (2300 m²), exposition dégagée sur deux côtés.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'acheter_terrain',  label:'Acheter ce terrain (2300 m² — 27 600 FR)',       pa:2, cost:27600, type:'legal',   icon:'ti-home-plus', successRate:100},
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'}
        ]
      }
    }
  },

  'terrain-a-batir-3': {
    name: "Terrain a batir - Lot 3 (La Châtaigneraie)",
    shortName: "Lot 3 — Châtaigneraie",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Autrefois un seul grand domaine agricole en périphérie de Luthécia — la Châtaigneraie — ce terrain a été loti en cinq parcelles distinctes, aujourd'hui proposées séparément à la vente.",
    rooms: {
      terrain3: {
        name: "Terrain",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Lot de la Châtaigneraie (2300 m²) en bordure de la route principale, bonne visibilité.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'acheter_terrain',   label:'Acheter ce terrain (2300 m² — 27 600 FR)',          pa:2, cost:27600, type:'legal',   icon:'ti-home-plus', successRate:100},
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'}
        ]
      }
    }
  },

  // ---- CASERNE MILITAIRE ----
  'caserne-militaire': {
    name: "Caserne Militaire de Republia",
    shortName: "Caserne",
    cat: "Militaire - Acces restreint",
    icon: "ti-military-rank",
    bgColor: "#081008",
    desc: "La caserne principale des forces armees de Republia. Acces reserve aux militaires et officiers.",
    rooms: {
      corps_garde: {
        name: "Corps de Garde",
        imageBg: "linear-gradient(135deg,#081008,#0f1a0a)",
        desc: "L'entree de la caserne. Militaires en faction. Verification des acces.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/caserne-luthecia-corps-de-garde.png",
        persons: [
          {name:'Sergent Dubois (PNJ)', role:'PNJ - Sous-officier de garde', rel:'neutral', job:'militaire'},
          {name:'Soldat Martin (PNJ)',  role:'PNJ - Faction',                 rel:'neutral', job:'militaire'}
        ],
        orders: [
          {fn:'nommer_lieutenant', label:'Nommer un Lieutenant', pa:2, cost:0, type:'legal', icon:'ti-star', successRate:100, requiresPost:'capitaine', desc:'Reserve aux Capitaines. Designer un lieutenant pour une section de sa compagnie.'},
          {fn:'affecter_engage',    label:'Affecter un engagé à une section', pa:2, cost:0, type:'legal', icon:'ti-user-plus', successRate:100, requiresPost:'capitaine', desc:'Reserve aux Capitaines. Installer un engage valide par le Commandant comme lieutenant d\'une section.'},
          {fn:'engager_officier',   label:'S\'engager comme officier',  pa:2, cost:0, type:'legal', icon:'ti-flag', successRate:100, desc:'Envoyer une demande d\'engagement au Commandant de la Caserne.'},
          {fn:'demettre_lieutenant', label:'Démettre un Lieutenant', pa:2, cost:0, type:'legal', icon:'ti-user-x', successRate:100, requiresPost:'capitaine', desc:'Reserve aux Capitaines. Retirer un lieutenant juge responsable d\'un echec.'},
          {fn:'se_presenter_affectation', label:'Se présenter à mon affectation', pa:1, cost:0, type:'legal', icon:'ti-door-enter', successRate:100, desc:'Reserve aux civils requisitionnes, avant expiration du delai.'},
          {fn:'stage_caserne', label:'Stage à la Caserne', pa:3, cost:0, type:'legal', icon:'ti-heart-bolt', successRate:100, desc:'Ouvert a tout le monde. +5 Volonte. 1 fois par jour, maximum 3 jours consecutifs puis 7 jours de repos obligatoire.'}
        ]
      },
      salle_commandement: {
        name: "Salle de Commandement",
        imageBg: "linear-gradient(135deg,#060f06,#0a180a)",
        desc: "Le centre nerveux operationnel. Cartes, ecrans, officiers. Acces officiers superieurs.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/caserne-luthecia-salle-commandement.png",
        requiresPostId: 'min_def',
        persons: [
          {name:'General Faure (PNJ)', role:'PNJ - Chef d\'etat-major', rel:'neutral', job:'general'}
        ],
        orders: [
          {fn:'nommer_capitaine',    label:'Nommer un Capitaine',        pa:2, cost:0,    type:'legal',   icon:'ti-star',          successRate:100, requiresPost:'commandant', desc:'Reserve au Commandant. Designer un capitaine pour une compagnie.'},
          {fn:'traiter_engagements', label:'Traiter les engagements',   pa:1, cost:0,    type:'legal',   icon:'ti-clipboard-list', successRate:100, requiresPost:'commandant', desc:'Reserve au Commandant. Affecter les demandes d\'engagement a une compagnie.'},
          {fn:'recherche_militaire', label:'Lancer une recherche sur l\'armement', pa:2, cost:0, type:'legal', icon:'ti-flask', successRate:100, requiresPost:'commandant', desc:'En collaboration avec un chercheur civil. Ameliore le coefficient de tir d\'une arme pour tout le pays.'},
          {fn:'repartir_armement', label:'Repartir l\'armement', pa:1, cost:0, type:'legal', icon:'ti-transfer', successRate:100, requiresPost:'capitaine', desc:'Reserve aux Capitaines. Transferer des armes entre le stock de l\'Armurerie Militaire et les sections de sa compagnie.'},
          {fn:'recruter_section',   label:'Recompléter une section',    pa:2, cost:0,    type:'legal',   icon:'ti-user-plus',     successRate:100, requiresPost:'commandant', desc:'Recompléter une section anéantie. Les nouvelles recrues n\'ont aucune experience.'},
          {fn:'gerer_detachement',   label:'Gérer mon détachement',      pa:0, cost:0,    type:'legal',   icon:'ti-users',         successRate:100, requiresPost:'lieutenant', desc:'Deposer ou recuperer des soldats dans cette piece.'},
          {fn:'assigner_mission',    label:'Attribuer une mission',      pa:1, cost:0,    type:'legal',   icon:'ti-target',        successRate:100, requiresPost:'lieutenant', desc:'Donner une consigne au detachement present dans cette piece.'},
          {fn:'voir_ma_section',     label:'Voir ma section',            pa:0, cost:0,    type:'legal',   icon:'ti-list',          successRate:100, requiresPost:'lieutenant', desc:'Fiche individuelle de vos 24 soldats (matricule, formation, equipement).'},
          {fn:'entrainer_section',   label:'Entrainer la section',       pa:2, cost:0,    type:'legal',   icon:'ti-barbell',       successRate:100, requiresPost:'lieutenant', desc:'Force, Endurance ou Tir. 12 soldats max par session.'},
          {fn:'equiper_section',     label:'Gerer l\'equipement de ma section', pa:1, cost:0, type:'legal', icon:'ti-sword', successRate:100, requiresPost:'lieutenant', desc:'Equiper ou desequiper individuellement les soldats de sa section, selon le stock d\'armes attribue par le Capitaine.'},
          {fn:'remonter_renseignement', label:'Faire remonter un renseignement', pa:1, cost:0, type:'legal', icon:'ti-report', successRate:100, requiresPost:'lieutenant', desc:'Transmettre un rapport de renseignement recu a votre Capitaine.'},
          {fn:'inspecter_troupes',   label:'Inspecter les troupes',      pa:1, cost:0,    type:'legal',   icon:'ti-eye',           successRate:100, requiresPost:'min_def', desc:'+INF aupres de l\'armee. Renforce la loyaute.'},
          {fn:'gerer_budget_caserne', label:'Gérer le budget militaire', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, requiresPost:'min_def', desc:'Virement journalier ou ponctuel vers la caserne, ou financer directement la recherche militaire.'}
        ]
      },
      armurerie_militaire: {
        name: "Armurerie Militaire",
        imageBg: "linear-gradient(135deg,#080808,#121008)",
        desc: "L'armurerie de la caserne. Armes lourdes, equipements tactiques, explosifs reglementaires.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/caserne-luthecia-armurerie-militaire.png",
        requiresPostId: 'min_def',
        persons: [
          {name:'Armurier Militaire (PNJ)', role:'PNJ - Sergent armurier', rel:'neutral', job:'armurier_mil'}
        ],
        orders: [
          {fn:'acheter_arme_militaire', label:'Acheter de l\'armement', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100, requiresPost:'min_def', desc:'Achat institutionnel d\'armes pour l\'armee, alimente le stock de l\'Armurerie Militaire (a repartir ensuite par les Capitaines).'},
          {fn:'acheter_bombe_mil',      label:'Obtenir des explosifs',        pa:2, cost:0,   type:'legal',   icon:'ti-bomb',      successRate:100, requiresPost:'min_def', desc:'Explosifs reglementaires. Tracables. Ajoutes a l\'inventaire.'},
          {fn:'acheter_bombe_illegale', label:'Subtiliser des explosifs',     pa:2, cost:0,   type:'illegal', icon:'ti-eye-off',   successRate:35,  desc:'Taux 35%. Echec partiel : -30 HP. Echec critique : -80 HP + alerte.'}
        ]
      },
      salle_faits_armes: {
        name: "Salle des Faits d'Armes",
        imageBg: "linear-gradient(135deg,#0a0806,#14100a)",
        desc: "Les trophees et etendards des sections. Chaque numero de section porte la memoire de ses combats, transmise d'un lieutenant a l'autre.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/caserne-luthecia-salle-faits-armes.png",
        persons: [
          {name:'Archiviste Militaire (PNJ)', role:'PNJ - Gardien de la memoire', rel:'neutral', job:'archiviste_mil'}
        ],
        orders: [
          {fn:'consulter_faits_armes', label:'Consulter les faits d\'armes', pa:0, cost:0, type:'legal', icon:'ti-medal', successRate:100, desc:'L\'histoire des combats menes par chaque section.'}
        ]
      },
      quartier_troupes: {
        name: "Quartier des Troupes",
        imageBg: "linear-gradient(135deg,#080a08,#0f120a)",
        desc: "Les dortoirs et salles de repos des soldats. Ambiance de camaraderie et discipline.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/caserne-luthecia-dortoir.png",
        persons: [
          {name:'Caporal Lefebvre (PNJ)', role:'PNJ - Soldat', rel:'neutral', job:'soldat'},
          {name:'Soldat Nguyen (PNJ)',    role:'PNJ - Soldat', rel:'neutral', job:'soldat'}
        ],
        orders: [
          {fn:'recruter_etud',     label:'Recruter pour un groupe',     pa:2, cost:0, type:'grey',  icon:'ti-user-plus',     successRate:65,  desc:'Constituer une milice ou un groupe arme.'}
        ]
      }
    }
  },

  // ---- QHS - QUARTIER HAUTE SECURITE ----
  // =====================
  // MUSEE DE LA VILLE DE LUTHECIA
  // =====================

  'musee-ville-luthecia': {
    name: "Musée de la Ville de Luthécia",
    shortName: "Musée de la Ville",
    cat: "Culture",
    icon: "ti-building-monument",
    bgColor: "#1c160c",
    desc: "Le musee dedie a l'histoire de Luthecia et de ses grandes figures. Chaque salle immortalise une categorie de citoyens celebres, pour le meilleur et pour le pire.",
    rooms: {
      hall: {
        name: "Hall d'accueil",
        imageBg: "linear-gradient(135deg,#1c160c,#241c10)",
        desc: "Le hall d'accueil du musee de la ville de Luthecia.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-musee-ville-luthecia.png",
        persons: [
          {name:'Gérard Poinçon (PNJ)', role:'Gardien du musée', rel:'neutral', job:'gardien_musee', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gerard-poincon-gardien-musee.png', photoPos:'50% 15%'},
          {name:'Valérie Loisillon (PNJ)', role:'Hôtesse d\'accueil', rel:'neutral', job:'hotesse', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-musee-ville-luthecia.png', photoPos:'20% 30%'}
        ],
        orders: []
      },
      salle_criminels: {
        name: "Salle des Grands Criminels",
        imageBg: "linear-gradient(135deg,#1a0d0d,#241010)",
        desc: "Portraits et affaires des malfrats les plus tristement celebres de Luthecia. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-criminels-musee-luthecia.png",
        persons: [],
        orders: []
      },
      salle_maires: {
        name: "Salle des Maires de Luthécia",
        imageBg: "linear-gradient(135deg,#181408,#221c0c)",
        desc: "L'histoire municipale de la ville, ses meilleurs et ses pires edeciles reunis dans la meme salle. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-maires-musee-luthecia.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-ville-audio-salle-maires.mp3",
        persons: [],
        orders: []
      },
      salle_personnalites: {
        name: "Salle des Personnalités Luthéciennes",
        imageBg: "linear-gradient(135deg,#14181c,#1c2228)",
        desc: "Les figures les plus populaires et aimees de la ville, toutes generations confondues. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/musee-ville-luthecia-salle-personnalites.png",
        persons: [],
        orders: []
      },
      salle_entrepreneurs: {
        name: "Salle des Grands Entrepreneurs",
        imageBg: "linear-gradient(135deg,#141c14,#1c2818)",
        desc: "Les batisseurs economiques de Luthecia, du petit commerce a l'empire industriel. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/musee-ville-luthecia-salle-entrepreneurs.png",
        persons: [],
        orders: []
      },
      salle_organisations: {
        name: "Salle des Organisations",
        imageBg: "linear-gradient(135deg,#0e1418,#141c22)",
        desc: "Clubs, syndicats et organisations locales : leurs plus grands representants, toutes disciplines confondues. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/musee-ville-luthecia-salle-organisations.png",
        persons: [],
        orders: []
      },
      salle_plumes: {
        name: "Salle des Plumes",
        imageBg: "linear-gradient(135deg,#181018,#221824)",
        desc: "Les plus belles diatribes, lettres ouvertes et recits qui ont marque la vie forumiale de Luthecia. Contenu a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-plumes-musee-luthecia.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-ville-audio-salle-plumes.mp3",
        persons: [],
        orders: []
      },
      salle_honneur_militaire: {
        name: "Salle d'Honneur Militaire",
        imageBg: "linear-gradient(135deg,#141410,#201f18)",
        desc: "Les faits d'armes et les soldats les plus decores originaires de Luthecia. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/musee-ville-luthecia-salle-honneur-militaire.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-ville-audio-salle-honneur-militaire-v2.mp3",
        persons: [],
        orders: []
      },
      salle_unions: {
        name: "Salle des Unions Célèbres",
        imageBg: "linear-gradient(135deg,#1c1414,#281c1c)",
        desc: "Les mariages et alliances les plus marquants de l'histoire de la ville. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/musee-ville-luthecia-salle-unions-celebres.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-ville-audio-salle-unions-celebres.mp3",
        persons: [],
        orders: []
      },
      salle_dynasties: {
        name: "Salle des Grandes Dynasties",
        imageBg: "linear-gradient(135deg,#181410,#241c14)",
        desc: "Arbre genealogique vivant des familles historiques de Luthecia. Contenu a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/musee-ville-luthecia-salle-dynasties.png",
        persons: [],
        orders: []
      },
      salle_scandales: {
        name: "Salle des Scandales et Affaires",
        imageBg: "linear-gradient(135deg,#100c10,#181018)",
        desc: "Les grandes crises politiques et affaires qui ont secoue Luthecia. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/musee-ville-luthecia-salle-scandales.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-ville-audio-salle-scandales.mp3",
        persons: [],
        orders: []
      },
      debarras: {
        name: "Débarras",
        imageBg: "linear-gradient(135deg,#0a0806,#100c08)",
        desc: "Une porte fermée à clé, discrète, au fond du musée. Personne ne semble jamais y entrer.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/porte-debarras-musee-luthecia.png",
        locked: true,
        persons: [],
        orders: []
      }
    }
  },

  // =====================
  // MUSEE NATIONAL DE REPUBLIA
  // =====================

  'musee-national-republia': {
    name: "Musée National de Republia",
    shortName: "Musée National",
    cat: "Culture",
    icon: "ti-building-monument",
    bgColor: "#14100a",
    desc: "Le grand musee national de Republia, ou se joue la memoire de la nation toute entiere.",
    rooms: {
      hall: {
        name: "Hall d'accueil",
        imageBg: "linear-gradient(135deg,#14100a,#1c1610)",
        desc: "L'immense hall d'accueil du musee national, sous sa verriere et son escalier monumental.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-musee-national-republia.png",
        persons: [],
        orders: []
      },
      salle_presidents: {
        name: "Salle des Présidents de Republia",
        imageBg: "linear-gradient(135deg,#181408,#221c0c)",
        desc: "L'histoire presidentielle de la nation, ses meilleurs et ses pires chefs d'Etat. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-presidents-musee-national.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-ville-luthecia-audio-salle-presidents.mp3",
        persons: [],
        orders: []
      },
      expositions_temporaires: {
        name: "Expositions Temporaires",
        imageBg: "linear-gradient(135deg,#14181c,#1c2228)",
        desc: "Une salle dediee aux expositions ponctuelles du musee. Contenu a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/expositions-temporaires-musee-national.png",
        persons: [],
        orders: []
      },
      salle_honneur_militaire_nationale: {
        name: "Salle d'Honneur Militaire Nationale",
        imageBg: "linear-gradient(135deg,#141410,#201f18)",
        desc: "Les plus grands faits d'armes a l'echelle du pays.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-militaires-musee-national.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-audio-salle-honneur-militaire.mp3",
        persons: [],
        orders: [
          {fn:'consulter_personnalites_musee', label:'Consulter les personnalités', pa:0, cost:0, type:'legal', icon:'ti-users', successRate:100, desc:'Voir les figures marquantes de cette salle.'}
        ]
      },
      salle_politiques: {
        name: "Salle des Personnalités Politiques",
        imageBg: "linear-gradient(135deg,#181408,#221c0c)",
        desc: "Ministres, députés et diplomates ayant marqué l'histoire nationale (hors présidents et maires).",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-politiques-musee-national.png",
        persons: [],
        orders: [
          {fn:'consulter_personnalites_musee', label:'Consulter les personnalités', pa:0, cost:0, type:'legal', icon:'ti-users', successRate:100, desc:'Voir les figures marquantes de cette salle.'}
        ]
      },
      salle_civils_intellectuels: {
        name: "Salle des Personnalités Civiles et Intellectuelles",
        imageBg: "linear-gradient(135deg,#14100c,#1c1810)",
        desc: "Universitaires, philosophes, journalistes et chercheurs ayant marqué le pays.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-civils-intellectuels-musee-national.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-national-audio-salle-personnalites-civiles.mp3",
        persons: [],
        orders: [
          {fn:'consulter_personnalites_musee', label:'Consulter les personnalités', pa:0, cost:0, type:'legal', icon:'ti-users', successRate:100, desc:'Voir les figures marquantes de cette salle.'}
        ]
      },
      salle_organisations: {
        name: "Salle des Responsables d'Organisations Syndicales ou Religieuses",
        imageBg: "linear-gradient(135deg,#181008,#221408)",
        desc: "Figures religieuses, syndicales et de loges ayant marqué le pays.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-organisations-musee-national.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-national-audio-salle-responsables-organisations.mp3",
        persons: [],
        orders: [
          {fn:'consulter_personnalites_musee', label:'Consulter les personnalités', pa:0, cost:0, type:'legal', icon:'ti-users', successRate:100, desc:'Voir les figures marquantes de cette salle.'}
        ]
      },
      salle_artistes_sportifs: {
        name: "Salle des Artistes et Sportifs",
        imageBg: "linear-gradient(135deg,#101418,#181c22)",
        desc: "Compositeurs, sculpteurs, champions et figures populaires du sport national.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-artistes-sportifs-musee-national.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-national-audio-salle-artistes-sportifs.mp3",
        persons: [],
        orders: [
          {fn:'consulter_personnalites_musee', label:'Consulter les personnalités', pa:0, cost:0, type:'legal', icon:'ti-users', successRate:100, desc:'Voir les figures marquantes de cette salle.'}
        ]
      },
      salle_tresor_national: {
        name: "Salle du Trésor National",
        imageBg: "linear-gradient(135deg,#181008,#221408)",
        desc: "Regalia, objets d'Etat et symboles du pouvoir. Acces strictement interdit — zone sous haute protection, surveillance 24h/24.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tresor-national-musee-national.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-national-audio-salle-tresor-national.mp3",
        persons: [],
        orders: []
      },
      salle_reussites_economiques: {
        name: "Salle des Grandes Réussites Économiques",
        imageBg: "linear-gradient(135deg,#141c14,#1c2818)",
        desc: "Les plus grandes fortunes et entreprises a l'echelle nationale.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-economie-musee-national.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-national-audio-salle-reussites-economiques.mp3",
        persons: [],
        orders: [
          {fn:'consulter_personnalites_musee', label:'Consulter les personnalités', pa:0, cost:0, type:'legal', icon:'ti-users', successRate:100, desc:'Voir les figures marquantes de cette salle.'}
        ]
      },
      salle_grandes_villes: {
        name: "Salle des Grandes Villes de Republia",
        imageBg: "linear-gradient(135deg,#181410,#241c14)",
        desc: "Les maires des differentes villes du pays entrent en competition pour la reconnaissance nationale de leur cite. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/musee-national-salle-grandes-villes.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-national-audio-salle-grandes-villes.mp3",
        persons: [],
        orders: []
      },
      salle_criminels_pays: {
        name: "Salle des Plus Grands Criminels du Pays",
        imageBg: "linear-gradient(135deg,#1a0d0d,#241010)",
        desc: "Les plus grands criminels de chaque ville du pays entrent en competition pour le titre de plus grand criminel de la nation. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-criminels-musee-national.png",
        audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/luthecia/musee-national-audio-salle-grands-criminels.mp3",
        persons: [],
        orders: [
          {fn:'consulter_personnalites_musee', label:'Consulter les personnalités', pa:0, cost:0, type:'legal', icon:'ti-users', successRate:100, desc:'Voir les figures marquantes de cette salle.'}
        ]
      }
    }
  },

  'parc-botanique-national': {
    name: "Parc Botanique National de Républia",
    shortName: "Parc Botanique",
    cat: "Lieu public",
    icon: "ti-leaf",
    bgColor: "#0c140c",
    desc: "Fondé en 1897, le parc botanique national accueille étangs, allées ombragées et une grande serre tropicale.",
    rooms: {
      parc: {
        name: "Parc Botanique",
        imageBg: "linear-gradient(135deg,#0c140c,#141c14)",
        desc: "Étangs, cygnes, allées gravillonnées et pelouses (interdites). Un lieu paisible au cœur de la ville.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/parc-botanique-national.png",
        persons: [
          {name:'Florian Grès (PNJ)', role:'Jardinier', rel:'neutral', job:'jardinier', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/florian-gres-jardinier.png', photoPos:'50% 20%'}
        ],
        orders: []
      },
      serre: {
        name: "Serre Tropicale",
        imageBg: "linear-gradient(135deg,#0a1410,#101c18)",
        desc: "Plantes exotiques fragiles, orchidées et bassin d'ornement sous verrière. Merci de ne pas toucher les végétaux.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/serre-botanique-luthecia.png",
        persons: [
          {name:'Jean-Pierre Ciseaux (PNJ)', role:'Conservateur', rel:'neutral', job:'conservateur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jean-pierre-ciseaux-conservateur.png', photoPos:'50% 15%'}
        ],
        orders: []
      }
    }
  },

  'place-formulaire-liberte': {
    name: "Place du Formulaire de la Liberté",
    shortName: "Place",
    cat: "Lieu public",
    icon: "ti-file-text",
    bgColor: "#12100a",
    desc: "Une place publique, au sud du Stade. Prevue pour accueillir de futures manifestations — contenu a developper.",
    rooms: {
      place: {
        name: "Place du Formulaire de la Liberté",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/place-formulaire-liberte.png",
        desc: "Une vaste place pavee, encore silencieuse. Ce lieu est prevu pour accueillir de futurs rassemblements.",
        persons: [
          {name:'Pat Hounette', role:'Dealer', rel:'neutral', job:'criminel', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/pat-hounette.png', photoPos:'45% 30%'}
        ],
        orders: []
      }
    }
  },

  'quartier-ambassades': {
    name: "Quartier des Ambassades",
    shortName: "Ambassades",
    cat: "Diplomatie",
    icon: "ti-flag",
    bgColor: "#12100a",
    desc: "Le quartier diplomatique de Luthecia. Trois bureaux reserves aux ambassadeurs etrangers, ouverts selon les ambassades reellement etablies.",
    rooms: {
      accueil_ambassades: {
        name: "Accueil du Quartier des Ambassades",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/accueil-quartier-ambassades.png",
        desc: "Le hall d'accueil du quartier diplomatique. Trois bureaux d'ambassadeurs, ouverts selon les relations en cours.",
        persons: [
          {name:'Hôtesse d\'Accueil (PNJ)', role:'PNJ - Accueil', rel:'neutral', job:'hotesse'},
          {name:'Agent de Sécurité (PNJ)', role:'PNJ - Sécurité', rel:'neutral', job:'agent_securite'}
        ],
        orders: [
          {fn:'demander_audience_ambassadeur', label:'Demander audience à l\'ambassadeur', pa:1, cost:0, type:'legal', icon:'ti-door-enter', successRate:70, desc:'Tenter de rencontrer un ambassadeur present.'},
          {fn:'demander_asile_politique',       label:'Demander l\'asile politique',       pa:2, cost:0, type:'legal', icon:'ti-shield-check', successRate:100, desc:'Deposer une demande d\'asile politique aupres de cette ambassade.'},
          {fn:'reserver_salle_reception',       label:'Réserver la Salle de Réception',    pa:1, cost:0, type:'legal', icon:'ti-calendar-event', successRate:100, desc:'Reserver la salle pour aujourd\'hui (reserve aux ambassadeurs en poste ici).'}
        ]
      },
      salle_reception: {
        name: "Salle de Réception",
        imageBg: "linear-gradient(135deg,#14100a,#1c1610)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/ambassades-salle-reception.png",
        desc: "Une salle commune aux trois ambassades, reservee aux receptions diplomatiques organisees par les ambassadeurs.",
        persons: [],
        orders: []
      },
      bureau_al_khalija: {
        name: "Ambassade d'Al-Khalija",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-ambassadeur-al-khalija.png",
        desc: "Le bureau de l'ambassadeur d'Al-Khalija. Ferme tant qu'Al-Khalija n'a pas ouvert d'ambassade a Luthecia.",
        persons: [],
        orders: [
          {fn:'relations_bilaterales',            label:'Consulter les relations bilatérales', pa:0, cost:0,    type:'legal', icon:'ti-file-analytics', successRate:100, requiresPost:'ambassadeur_local', desc:'Etat des relations avec Al-Khalija.'},
          {fn:'corrompre_homologue_local',         label:'Corrompre un homologue local',        pa:2, cost:800,  type:'illegal', icon:'ti-cash-banknote', successRate:65,  requiresPost:'ambassadeur_local', desc:'Obtenir une faveur, au risque d\'un scandale.'},
          {fn:'organiser_reception_diplomatique',  label:'Organiser une réception diplomatique',pa:2, cost:1200, type:'legal', icon:'ti-glass-champagne', successRate:100, requiresPost:'ambassadeur_local', desc:'Reserver la Salle de Reception commune.'},
          {fn:'financer_oeuvre_culturelle',        label:'Financer une œuvre culturelle',        pa:1, cost:600,  type:'legal', icon:'ti-palette', successRate:100, requiresPost:'ambassadeur_local', desc:'Soft power local.'}
        ]
      },
      bureau_sovarka: {
        name: "Ambassade de Sovarka",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-ambassadeur-sovarka.png",
        desc: "Le bureau de l'ambassadeur de Sovarka. Ferme tant que Sovarka n'a pas ouvert d'ambassade a Luthecia.",
        persons: [],
        orders: [
          {fn:'relations_bilaterales',            label:'Consulter les relations bilatérales', pa:0, cost:0,    type:'legal', icon:'ti-file-analytics', successRate:100, requiresPost:'ambassadeur_local', desc:'Etat des relations avec Sovarka.'},
          {fn:'corrompre_homologue_local',         label:'Corrompre un homologue local',        pa:2, cost:800,  type:'illegal', icon:'ti-cash-banknote', successRate:65,  requiresPost:'ambassadeur_local', desc:'Obtenir une faveur, au risque d\'un scandale.'},
          {fn:'organiser_reception_diplomatique',  label:'Organiser une réception diplomatique',pa:2, cost:1200, type:'legal', icon:'ti-glass-champagne', successRate:100, requiresPost:'ambassadeur_local', desc:'Reserver la Salle de Reception commune.'},
          {fn:'financer_oeuvre_culturelle',        label:'Financer une œuvre culturelle',        pa:1, cost:600,  type:'legal', icon:'ti-palette', successRate:100, requiresPost:'ambassadeur_local', desc:'Soft power local.'}
        ]
      },
      bureau_el_estado: {
        name: "Ambassade d'El Estado",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-ambassadeur-el-estado.png",
        desc: "Le bureau de l'ambassadeur d'El Estado. Ferme tant qu'El Estado n'a pas ouvert d'ambassade a Luthecia.",
        persons: [],
        orders: [
          {fn:'relations_bilaterales',            label:'Consulter les relations bilatérales', pa:0, cost:0,    type:'legal', icon:'ti-file-analytics', successRate:100, requiresPost:'ambassadeur_local', desc:'Etat des relations avec El Estado.'},
          {fn:'corrompre_homologue_local',         label:'Corrompre un homologue local',        pa:2, cost:800,  type:'illegal', icon:'ti-cash-banknote', successRate:65,  requiresPost:'ambassadeur_local', desc:'Obtenir une faveur, au risque d\'un scandale.'},
          {fn:'organiser_reception_diplomatique',  label:'Organiser une réception diplomatique',pa:2, cost:1200, type:'legal', icon:'ti-glass-champagne', successRate:100, requiresPost:'ambassadeur_local', desc:'Reserver la Salle de Reception commune.'},
          {fn:'financer_oeuvre_culturelle',        label:'Financer une œuvre culturelle',        pa:1, cost:600,  type:'legal', icon:'ti-palette', successRate:100, requiresPost:'ambassadeur_local', desc:'Soft power local.'}
        ]
      }
    }
  },

  'qhs-prison': {
    name: "Quartier Haute Securite",
    shortName: "QHS",
    cat: "Penitentiaire - Acces restreint",
    icon: "ti-lock",
    bgColor: "#080808",
    desc: "La prison de haute securite de Republia. Les criminels les plus dangereux y sont detenus. Evasion quasi impossible.",
    rooms: {
      entree_qhs: {
        name: "Entree Securisee",
        imageBg: "linear-gradient(135deg,#080808,#101010)",
        desc: "L'entree du QHS. Trois sas de securite. Gardes armes en permanence.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/qhs-luthecia-entree-controle.png",
        persons: [
          {name:'Dominique Cruel (PNJ)', role:'PNJ - Directeur du QHS', rel:'neutral', job:'directeur_qhs'},
          {name:'Philippe Cognedur (PNJ)', role:'PNJ - Gardien Chef',     rel:'neutral', job:'gardien_qhs'}
        ],
        orders: [
          {fn:'visiter_prisonnier', label:'Visiter un detenu',          pa:1, cost:0,   type:'legal',   icon:'ti-users',    successRate:70,  desc:'Rendre visite a un detenu du QHS. Necessite autorisation.'},
          {fn:'corrompre_fonct',   label:'Corrompre le directeur',      pa:3, cost:1500, type:'illegal', icon:'ti-coins',    successRate:25,  desc:'Taux tres faible. Consequence severe si echec.'},
          {fn:'archives_police',   label:'Consulter le registre',       pa:1, cost:0,   type:'legal',   icon:'ti-archive',  successRate:100, requiresPost:'magistrat', desc:'Liste des detenus actuels. Acces magistrats/commissaires.'}
        ]
      },
      cellules_qhs: {
        name: "Cellules",
        imageBg: "linear-gradient(135deg,#050505,#0a0808)",
        desc: "Les cellules du QHS. Isolement total. Acces interdit sauf pour les detenus et gardiens.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/qhs-luthecia-aile-a-cellules.png",
        persons: [
          {name:'Jean Terre (PNJ)', role:'PNJ - Gardien de couloir', rel:'neutral', job:'gardien_qhs'},
          {name:'Patrick Coule (PNJ)', role:'PNJ - Gardien de couloir', rel:'neutral', job:'gardien_qhs'}
        ],
        orders: [
          {fn:'requete_avocat',     label:'Requérir un avocat',          pa:1, cost:0,    type:'legal',   icon:'ti-scale',    successRate:100, desc:'Contacter votre defenseur. Reduit risques de condamnation.'},
          {fn:'greve_faim',         label:'Greve de la faim',            pa:0, cost:0,    type:'legal',   icon:'ti-ban',      successRate:100, desc:'-5 HP/jour mais +POP et pression politique.'},
          {fn:'corrompre_gardien',  label:'Corrompre un gardien',        pa:2, cost:800,  type:'illegal', icon:'ti-coins',    successRate:20,  desc:'Tres difficile. Obtenir des privileges ou informations.'},
          {fn:'tentative_evasion',  label:'Tenter de s\'evader',        pa:3, cost:0,    type:'illegal', icon:'ti-run',      successRate:10,   desc:'Quasi impossible, une tentative par jour. Echec = peine aggravee de 7 jours.'}
        ]
      },
      salle_interrogatoire: {
        name: "Salle d'Interrogatoire",
        imageBg: "linear-gradient(135deg,#050808,#0a1010)",
        desc: "La salle d'interrogatoire. Lumiere crue, table metallique. Acces enqueteurs autorises.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/qhs-luthecia-salle-interrogatoire.png",
        persons: [],
        orders: [
          {fn:'interroger',        label:'Interroger un detenu',        pa:2, cost:0,    type:'legal',   icon:'ti-message-circle', successRate:75, requiresPost:'commissaire', desc:'Obtenir des informations. +INF si succes.'},
          {fn:'corrompre_fonct',   label:'Falsifier un proces-verbal',  pa:3, cost:500,  type:'illegal', icon:'ti-file-x',         successRate:35, desc:'Modifier les declarations. Tres risque.'}
        ]
      },
      promenoir: {
        name: "Promenoir",
        imageBg: "linear-gradient(135deg,#080808,#0f0f0f)",
        desc: "La cour de promenade. Une heure par jour. Sous surveillance constante.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/qhs-luthecia-promenoir.png",
        persons: [],
        orders: [
          {fn:'se_reposer',        label:'Prendre l\'air',              pa:0, cost:0,    type:'legal',   icon:'ti-walk',     successRate:100, desc:'+2 Moral. La seule liberte qui reste.'}
        ]
      },
      salle_commune_qhs: {
        name: "Salle Commune",
        imageBg: "linear-gradient(135deg,#0a0a0a,#101010)",
        desc: "L'espace de detente des detenus. Echecs, baby-foot, quelques journaux. Sous l'oeil des cameras.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/qhs-luthecia-salle-commune.png",
        persons: [],
        orders: []
      }
    }
  }
,

  // ---- LIEUX DE CULTE ----

  'tabernacle-impots': {
    name: "Le Tabernacle des Impôts",
    shortName: "Tabernacle",
    cat: "Religion - Papyrusisme",
    icon: "ti-building-church",
    bgColor: "#0a0808",
    desc: "Temple sacré du Papyrusisme. On y vénère le Formulaire Sacré en 12 exemplaires. L'odeur d'encre et de tampon encreur y est divine.",
    rooms: {
      nef_principale: {
        name: "Nef des Formulaires",
        imageBg: "linear-gradient(135deg,#0a0808,#150f0a)",
        desc: "La grande nef où les fidèles remplissent leurs actes de foi administratifs. Des piles de formulaires s'élèvent jusqu'au plafond.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tabernacle-impots-nef-formulaires.png",
        persons: [
          {name:'Père Ception (PNJ)', role:'Grand Prêtre du Papyrusisme', rel:'neutral', job:'grand_pretre'},
          {name:'Enfant de chœur Lacroix (PNJ)', role:'PNJ - Distributeur de formulaires', rel:'neutral', job:'clerc'}
        ],
        // Refonte religion Republia (26 aout 2026) : actions de lieu uniquement (prier, don).
        // Confession et benediction sont devenues des services de contact avec un religieux
        // habilite present (voir openPnjModal, plateau-pnj.js), plus des ordres de salle -- se
        // confesser/demander_benediction retires d'ici. Pelerin supprime (plus de contrepartie
        // mecanique retenue). fn/handlers doPrier/doFaireDon inchanges, partages avec les 3
        // autres empires -- seuls label/desc republic sont retouches ici.
        orders: [
          {fn:'prier',           label:'Prier le Formulaire Sacré',    pa:1, cost:0,   type:'legal', icon:'ti-star',      successRate:100, desc:'Vous priez pour vous-même (+2 Moral) tout en nourrissant la ferveur religieuse de votre ville (+3 piété locale).'},
          {fn:'faire_don',       label:'Faire un don a l\'Eglise',     pa:1, cost:200, type:'legal', icon:'ti-coins',     successRate:100, desc:'200 FR pris sur votre argent personnel. +3 popularité pour vous, +5 piété locale pour votre ville.'}
        ]
      },
      sacristie: {
        name: "Sacristie Administrative",
        imageBg: "linear-gradient(135deg,#080808,#100a08)",
        desc: "La pièce secrète du Grand Prêtre. Archives des confessions. Formulaires rares et tampons bénis.",
        imageUrl: "https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80",
        persons: [
          {name:'Père Ception (PNJ)', role:'Grand Prêtre du Papyrusisme', rel:'neutral', job:'grand_pretre'}
        ],
        // Masques, non supprimes (lot "refonte religion Republia", 26 aout 2026) : les 3 ordres
        // ci-dessous (excommunier/benediction_etat/consulter_confessions) dependent du poste
        // grand_pretre, structurellement inatteignable par un joueur (absent de
        // POSTES_NOMMES_EXCLUSIFS) -- restaient donc de faux boutons visibles mais jamais
        // utilisables. Retires de cette liste (donc invisibles) en attendant une decision sur le
        // role institutionnel du Grand Pretre ; handlers (doBenedictionEtat, doConsulterConfessions,
        // le stub d'executerOrdreContact pour excommunier) et donnees intacts, reutilisables tels
        // quels le jour venu -- rien de destructif.
        orders: []
      }
    }
  },

  'laboratoire-priere': {
    name: "Le Laboratoire de Prière",
    shortName: "Labo de Prière",
    cat: "Religion - Cocaïsme",
    icon: "ti-building-church",
    bgColor: "#080a05",
    desc: "Temple sacré du Cocaïsme à El Estado. On y vénère la Feuille Sacrée. L'ambiance y est... très énergique.",
    rooms: {
      salle_communion: {
        name: "Salle de Communion",
        imageBg: "linear-gradient(135deg,#080a05,#0f1208)",
        desc: "La salle principale du culte. Les fidèles communient dans une atmosphère très animée.",
        imageUrl: "https://images.unsplash.com/photo-1548625149-fc4a29cf7092?w=1200&q=80",
        persons: [
          {name:'Padre Cocaïno (PNJ)', role:'Grand Prêtre du Cocaïsme', rel:'neutral', job:'grand_pretre'},
          {name:'Hermano Poudre (PNJ)', role:'PNJ - Enfant de chœur très énergique', rel:'neutral', job:'clerc'}
        ],
        orders: [
          {fn:'prier',           label:'Communier avec la Feuille',    pa:1, cost:0,   type:'legal', icon:'ti-star',      successRate:100, desc:'+3 IP +2 Moral. Attention aux effets secondaires.'},
          {fn:'se_confesser',    label:'Se confesser',                  pa:2, cost:0,   type:'legal', icon:'ti-message',   successRate:100, desc:'+5 Moral. Le Padre sait tout.'},
          {fn:'faire_don',       label:'Faire une offrande',           pa:1, cost:200, type:'legal', icon:'ti-coins',     successRate:100, desc:'+5 IP +3 POP.'},
          {fn:'pelerin',         label:'Se déclarer pèlerin',          pa:2, cost:0,   type:'legal', icon:'ti-walk',      successRate:100, desc:'+10 DIS pendant 1 jour.'}
        ]
      }
    }
  },

  'kolkhoze-spirituel': {
    name: "Le Kolkhoze Spirituel",
    shortName: "Kolkhoze Spirituel",
    cat: "Religion - Tractorisme",
    icon: "ti-building-church",
    bgColor: "#080808",
    desc: "Temple sacré du Tractorisme à Sovarka. On y vénère le Tracteur Collectif. Les hymnes à la production résonnent en permanence.",
    rooms: {
      grange_sainte: {
        name: "La Grange Sainte",
        imageBg: "linear-gradient(135deg,#080808,#0f0f08)",
        desc: "La grange principale du culte. Un tracteur trône au centre, entouré de bougies.",
        imageUrl: "https://images.unsplash.com/photo-1548625149-fc4a29cf7092?w=1200&q=80",
        persons: [
          {name:'Camarade Pontife Tractorenko (PNJ)', role:'Grand Prêtre du Tractorisme', rel:'neutral', job:'grand_pretre'},
          {name:'Frère Kolkhoze (PNJ)', role:'PNJ - Enfant de chœur laborieux', rel:'neutral', job:'clerc'}
        ],
        orders: [
          {fn:'prier',           label:'Chanter l\'hymne au Tracteur', pa:1, cost:0,   type:'legal', icon:'ti-star',      successRate:100, desc:'+3 IP +2 Moral. Glorifier la production collective.'},
          {fn:'se_confesser',    label:'Se confesser',                  pa:2, cost:0,   type:'legal', icon:'ti-message',   successRate:100, desc:'+5 Moral. Avouer ses propriétés privées.'},
          {fn:'faire_don',       label:'Donner au Kolkhoze',           pa:1, cost:200, type:'legal', icon:'ti-coins',     successRate:100, desc:'+5 IP +3 POP.'},
          {fn:'pelerin',         label:'Se déclarer pèlerin',          pa:2, cost:0,   type:'legal', icon:'ti-walk',      successRate:100, desc:'+10 DIS pendant 1 jour.'}
        ]
      }
    }
  },

  'patisserie-sacree': {
    name: "La Pâtisserie Sacrée",
    shortName: "Pâtisserie Sacrée",
    cat: "Religion - Loukoumisme",
    icon: "ti-building-church",
    bgColor: "#0a0808",
    desc: "Temple sacré du Loukoumisme à Al-Khalija. On y vénère le Loukoum Divin. L'odeur de rose et de pistache y est envoûtante.",
    rooms: {
      salle_degustation: {
        name: "Salle de Dégustation Divine",
        imageBg: "linear-gradient(135deg,#0a0808,#150f08)",
        desc: "La salle principale du culte. Des plateaux de loukoums s'étendent à perte de vue.",
        imageUrl: "https://images.unsplash.com/photo-1548625149-fc4a29cf7092?w=1200&q=80",
        persons: [
          {name:'Grand Confiseur Abdul Loukoum (PNJ)', role:'Grand Prêtre du Loukoumisme', rel:'neutral', job:'grand_pretre'},
          {name:'Novice Baklava (PNJ)', role:'PNJ - Enfant de chœur en formation', rel:'neutral', job:'clerc'}
        ],
        orders: [
          {fn:'prier',           label:'Communier avec le Loukoum',    pa:1, cost:0,   type:'legal', icon:'ti-star',      successRate:100, desc:'+3 IP +2 Moral. Goût pistache ou rose au choix.'},
          {fn:'se_confesser',    label:'Se confesser',                  pa:2, cost:0,   type:'legal', icon:'ti-message',   successRate:100, desc:'+5 Moral. Le Grand Confiseur garde vos secrets... la plupart du temps.'},
          {fn:'faire_don',       label:'Offrir des loukoums',          pa:1, cost:200, type:'legal', icon:'ti-coins',     successRate:100, desc:'+5 IP +3 POP. Péché mortel de refuser un loukoum.'},
          {fn:'pelerin',         label:'Se déclarer pèlerin',          pa:2, cost:0,   type:'legal', icon:'ti-walk',      successRate:100, desc:'+10 DIS pendant 1 jour.'},
          {fn:'acheter_relique', label:'Acheter une relique du Loukoum',pa:1, cost:500, type:'legal', icon:'ti-package',  successRate:100, desc:'Objet rare. +10 IP. Accès facilité aux zones réservées Al-Khalija.'}
        ]
      }
    }
  },

  // ---- CENTRES MULTINODAUX ----

  'entrepot-logistique-montrouge': {
    name: "Entrepôt Logistique de Montrouge",
    shortName: "Entrepôt Logistique",
    cat: "Économie",
    icon: "ti-building-warehouse",
    bgColor: "#141210",
    desc: "L'entrepôt public de Montrouge. Réceptionne les livraisons quotidiennes de matières premières et les revend aux commerces de la ville.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#141210,#1c1815)",
        imageUrl: "images/montrouge/montrouge-entrepot-halle-logistique.jpg",
        desc: "Le quai de chargement et la salle des ventes. Le stock et les prix varient selon les livraisons du jour.",
        persons: [],
        orders: [{fn:'acheter_ressources_entrepot', label:'Acheter des ressources', pa:1, cost:0, type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'Choisir les ressources et quantités à acheter, selon le stock et le prix du moment.'}]
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "images/montrouge/montrouge-entrepot-bureau-direction.jpg",
        desc: "Le bureau du directeur de l'entrepôt. Accès sur rendez-vous.",
        persons: [{name:'Norbert Charton (PNJ)', role:"Directeur de l'Entrepôt Logistique", rel:'neutral', job:'directeur_entrepot'}],
        orders: [
          {fn:'fixer_prix_achat_entrepot', label:"Fixer les prix d'achat", pa:1, cost:0, type:'legal', icon:'ti-tag', successRate:100, requiresPost:'directeur_entrepot', desc:"Fixer le prix de chaque ressource vendue à l'entrepôt, dans la fourchette autorisée (±40% du prix de base)."}
        ]
      }
    }
  },

  'raffinerie-montrouge': {
    name: "Raffinerie Impériale de Montrouge",
    shortName: "Raffinerie",
    cat: "Économie",
    icon: "ti-droplet",
    bgColor: "#181410",
    desc: "L'entreprise stratégique pétrolière de Montrouge. Raffine le pétrole brut en carburant, sous contrôle de l'État.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#181410,#221c15)",
        imageUrl: "https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=1200&q=80",
        desc: "L'accueil et la salle de vente directe du carburant produit sur place.",
        persons: [],
        orders: [{fn:'vente_directe_usine', label:'Vente directe', pa:0, cost:0, type:'legal', icon:'ti-cash-register', successRate:100, desc:'Acheter la production locale, disponible en quantité limitée.'}]
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "images/montrouge/montrouge-raffinerie-bureau-direction.jpg",
        desc: "Le bureau du directeur de la raffinerie. Accès sur rendez-vous.",
        persons: [{name:'Gustave Baril (PNJ)', role:'Directeur de la Raffinerie', rel:'neutral', job:'directeur_raffinerie'}],
        orders: [
          {fn:'nommer_directeur_raffinerie', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ directeur de la raffinerie. Poste exclusif (sauf député).'},
          {fn:'fixer_prix_vente_directe', label:'Fixer les prix de vente', pa:1, cost:0, type:'legal', icon:'ti-tag', successRate:100, requiresPost:'directeur_raffinerie', desc:'Fixer le prix de chaque produit vendu en vente directe, dans la fourchette autorisée (±40% du prix de base).'},
          {fn:'fixer_repartition_production', label:'Répartir la production', pa:1, cost:0, type:'legal', icon:'ti-adjustments', successRate:100, requiresPost:'directeur_raffinerie', desc:'Choisir la part de la production quotidienne envoyée aux entrepôts publics (le reste part en vente directe sur place).'},
          {fn:'virement_usine_ministere', label:'Virement vers le Ministère', pa:1, cost:0, type:'legal', icon:'ti-transfer', successRate:100, requiresPost:'directeur_raffinerie', desc:'Verser un montant depuis la caisse de la raffinerie vers la caisse du Ministère des Finances.'}
        ]
      },
      salle_production: {
        name: "Salle de Production",
        imageBg: "linear-gradient(135deg,#0a0d10,#12161a)",
        imageUrl: "images/montrouge/montrouge-raffinerie-usine-production.jpg",
        desc: "Les installations de raffinage. Le pétrole brut livré y est transformé en carburant.",
        persons: [],
        orders: [
          {fn:'produire_carburant', label:'Produire du carburant', pa:1, cost:0, type:'legal', icon:'ti-gas-station', successRate:100, desc:'Fabrication contre salaire fixe : 1 PA, 70 FR. Consomme 5 pétrole du stock de matières de l\'usine, produit 10 carburants.'}
        ]
      }
    }
  },

  'bureau-national-emploi': {
    name: "Bureau National de l'Emploi",
    shortName: "Bureau de l'Emploi",
    cat: "Économie",
    icon: "ti-briefcase",
    bgColor: "#0f1216",
    desc: "L'office national qui recense les demandeurs d'emploi et les offres disponibles. Votre avenir, notre mission.",
    rooms: {
      accueil: {
        name: "Accueil",
        imageBg: "linear-gradient(135deg,#0f1216,#161a20)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-national-emploi-luthecia.png",
        desc: "Le hall d'accueil du Bureau National de l'Emploi. Offres d'emploi, accompagnement, formation, création d'activité.",
        persons: [
          {name:'Jean-Lou Zeure', role:'Ancien Maire de Luthécia', rel:'neutral', job:'citoyen', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jean-lou-zeure.png', photoPos:'63% 30%'}
        ],
        orders: [
          {fn:'sinscrire_demandeur_emploi', label:"S'inscrire comme demandeur d'emploi", pa:1, cost:0, type:'legal', icon:'ti-user-plus', successRate:100, desc:"Ouvre l'accès aux offres du Bureau National de l'Emploi."},
          {fn:'consulter_offres_emploi', label:"Consulter les offres d'emploi", pa:0, cost:0, type:'legal', icon:'ti-list-search', successRate:100, desc:'Offres locales, nationales et internationales disponibles.'},
          {fn:'demissionner_emploi_bne', label:'Démissionner de mon emploi', pa:0, cost:0, type:'legal', icon:'ti-door-exit', successRate:100, desc:'Effet immédiat, sans coût. Libère la place pour un autre demandeur.'}
        ]
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur de l'office. Accès sur rendez-vous.",
        persons: [],
        orders: []
      }
    }
  },

  'pole-tabac-alcools-psm': {
    name: "Pôle Tabac & Alcools Sainte-Mariannaise",
    shortName: "Pôle Tabac & Alcools",
    cat: "Économie",
    icon: "ti-glass-full",
    bgColor: "#181410",
    desc: "L'entreprise stratégique de Port-Sainte-Marie. Distille l'alcool et manufacture le tabac, sous contrôle de l'État.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#181410,#221c15)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-pole-tabac-psm.png",
        desc: "L'accueil et la salle de vente directe, alcools et tabac confondus.",
        persons: [],
        orders: [{fn:'vente_directe_usine', label:'Vente directe', pa:0, cost:0, type:'legal', icon:'ti-cash-register', successRate:100, desc:'Acheter la production locale, disponible en quantité limitée.'}]
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur du pôle. Accès sur rendez-vous.",
        persons: [{name:'Fernand Cendrier (PNJ)', role:'Directeur du Pôle Tabac & Alcools', rel:'neutral', job:'directeur_tabac_alcools'}],
        orders: [
          {fn:'nommer_directeur_tabac_alcools', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ directeur du Pôle Tabac & Alcools. Poste exclusif (sauf député).'},
          {fn:'fixer_prix_vente_directe', label:'Fixer les prix de vente', pa:1, cost:0, type:'legal', icon:'ti-tag', successRate:100, requiresPost:'directeur_tabac_alcools', desc:'Fixer le prix de chaque produit vendu en vente directe, dans la fourchette autorisée (±40% du prix de base).'},
          {fn:'fixer_repartition_production', label:'Répartir la production', pa:1, cost:0, type:'legal', icon:'ti-adjustments', successRate:100, requiresPost:'directeur_tabac_alcools', desc:'Choisir la part de la production quotidienne envoyée aux entrepôts publics (le reste part en vente directe sur place).'},
          {fn:'virement_usine_ministere', label:'Virement vers le Ministère', pa:1, cost:0, type:'legal', icon:'ti-transfer', successRate:100, requiresPost:'directeur_tabac_alcools', desc:'Verser un montant depuis la caisse du pôle vers la caisse du Ministère des Finances.'}
        ]
      },
      distillerie: {
        name: "Distillerie",
        imageBg: "linear-gradient(135deg,#0a0d10,#12161a)",
        imageUrl: "https://images.unsplash.com/photo-1569529465841-dfecdab7503b?w=1200&q=80",
        desc: "Les alambics. Céréales et fruits livrés y sont distillés en alcool.",
        persons: [],
        orders: [
          {fn:'produire_alcool', label:"Produire de l'alcool", pa:1, cost:0, type:'legal', icon:'ti-glass-full', successRate:100, desc:'Fabrication contre salaire fixe : 1 PA, 55 FR. Consomme 5 céréales du stock de matières de l\'usine, produit 10 alcools.'}
        ]
      },
      manufacture_tabac: {
        name: "Manufacture de Tabac",
        imageBg: "linear-gradient(135deg,#100d0a,#1a1512)",
        imageUrl: "https://images.unsplash.com/photo-1519669417670-68775a50919f?w=1200&q=80",
        desc: "Les lignes de manufacture. Les plantes livrées y sont transformées en tabac.",
        persons: [],
        orders: [
          {fn:'produire_tabac', label:'Produire du tabac', pa:1, cost:0, type:'legal', icon:'ti-cigarette', successRate:100, desc:'Fabrication contre salaire fixe : 1 PA, 66 FR. Consomme 5 plantes du stock de matières de l\'usine, produit 10 tabacs.'}
        ]
      }
    }
  },

  'entrepot-logistique-psm': {
    name: "Entrepôt Logistique de Sainte-Marie",
    shortName: "Entrepôt Logistique",
    cat: "Économie",
    icon: "ti-building-warehouse",
    bgColor: "#141210",
    desc: "L'entrepôt public de Port-Sainte-Marie. Réceptionne les livraisons quotidiennes de matières premières et les revend aux commerces de la ville.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#141210,#1c1815)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-pole-tabac-psm.png",
        desc: "Le quai de chargement et la salle des ventes. Le stock et les prix varient selon les livraisons du jour.",
        persons: [],
        orders: [{fn:'acheter_ressources_entrepot', label:'Acheter des ressources', pa:1, cost:0, type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'Choisir les ressources et quantités à acheter, selon le stock et le prix du moment.'}]
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur de l'entrepôt. Accès sur rendez-vous.",
        persons: [{name:'Yvon Paletier (PNJ)', role:"Directeur de l'Entrepôt Logistique", rel:'neutral', job:'directeur_entrepot'}],
        orders: [
          {fn:'fixer_prix_achat_entrepot', label:"Fixer les prix d'achat", pa:1, cost:0, type:'legal', icon:'ti-tag', successRate:100, requiresPost:'directeur_entrepot', desc:"Fixer le prix de chaque ressource vendue à l'entrepôt, dans la fourchette autorisée (±40% du prix de base)."}
        ]
      }
    }
  },

  'entrepot-logistique-luthecia': {
    name: "Entrepôt Logistique de Luthécia",
    shortName: "Entrepôt Logistique",
    cat: "Économie",
    icon: "ti-building-warehouse",
    bgColor: "#141210",
    desc: "L'entrepôt public de Luthécia. Réceptionne les livraisons quotidiennes de matières premières et les revend aux commerces de la ville.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#141210,#1c1815)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-ventes-entrepot-luthecia.png",
        desc: "Le quai de chargement et la salle des ventes. Le stock et les prix varient selon les livraisons du jour.",
        persons: [],
        orders: [{fn:'acheter_ressources_entrepot', label:'Acheter des ressources', pa:1, cost:0, type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'Choisir les ressources et quantités à acheter, selon le stock et le prix du moment.'}]
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-direction-entrepot-luthecia.png",
        desc: "Le bureau du directeur de l'entrepôt. Accès sur rendez-vous.",
        persons: [{name:'Marcel Silo (PNJ)', role:"Directeur de l'Entrepôt Logistique", rel:'neutral', job:'directeur_entrepot'}],
        orders: [
          {fn:'fixer_prix_achat_entrepot', label:"Fixer les prix d'achat", pa:1, cost:0, type:'legal', icon:'ti-tag', successRate:100, requiresPost:'directeur_entrepot', desc:"Fixer le prix de chaque ressource vendue à l'entrepôt, dans la fourchette autorisée (±40% du prix de base)."}
        ]
      }
    }
  },

  'usine-pharmaceutique-luthecia': {
    name: "Usine Pharmaceutique Impériale de Républia",
    shortName: "Usine Pharmaceutique",
    cat: "Économie",
    icon: "ti-vaccine",
    bgColor: "#101418",
    desc: "L'entreprise stratégique pharmaceutique de Républia. Transforme les plantes récoltées en médicaments, sous contrôle de l'État.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#101418,#161c22)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-ventes-usine-pharma-luthecia.png",
        desc: "L'accueil et la salle de vente directe des médicaments produits sur place.",
        persons: [],
        orders: [{fn:'vente_directe_usine', label:'Vente directe', pa:0, cost:0, type:'legal', icon:'ti-cash-register', successRate:100, desc:'Acheter la production locale, disponible en quantité limitée.'}]
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-direction-usine-pharma-luthecia.png",
        desc: "Le bureau du directeur de l'usine. Accès sur rendez-vous.",
        persons: [{name:'Bernard Piluler (PNJ)', role:"Directeur de l'Usine Pharmaceutique", rel:'neutral', job:'directeur_pharma'}],
        orders: [
          {fn:'nommer_directeur_pharma', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ directeur de l\'Usine Pharmaceutique. Poste exclusif (sauf député).'},
          {fn:'fixer_prix_vente_directe', label:'Fixer les prix de vente', pa:1, cost:0, type:'legal', icon:'ti-tag', successRate:100, requiresPost:'directeur_pharma', desc:'Fixer le prix de chaque produit vendu en vente directe, dans la fourchette autorisée (±40% du prix de base).'},
          {fn:'fixer_repartition_production', label:'Répartir la production', pa:1, cost:0, type:'legal', icon:'ti-adjustments', successRate:100, requiresPost:'directeur_pharma', desc:'Choisir la part de la production quotidienne envoyée aux entrepôts publics (le reste part en vente directe sur place).'},
          {fn:'virement_usine_ministere', label:'Virement vers le Ministère', pa:1, cost:0, type:'legal', icon:'ti-transfer', successRate:100, requiresPost:'directeur_pharma', desc:"Verser un montant depuis la caisse de l'usine vers la caisse du Ministère des Finances."}
        ]
      },
      salle_production: {
        name: "Salle de Production",
        imageBg: "linear-gradient(135deg,#0a0d10,#12161a)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-production-usine-pharma-luthecia.png",
        desc: "Les lignes de production. Les plantes livrées y sont transformées en médicaments.",
        persons: [],
        orders: [
          {fn:'produire_medicaments', label:'Produire des médicaments', pa:1, cost:0, type:'legal', icon:'ti-vaccine', successRate:100, desc:'Fabrication contre salaire fixe : 1 PA, 84 FR. Consomme 5 plantes du stock de matières de l\'usine, produit 10 médicaments.'},
          {fn:'produire_desinfectant', label:'Produire du désinfectant', pa:1, cost:0, type:'legal', icon:'ti-droplet', successRate:100, desc:'Fabrication contre salaire fixe : 1 PA, 70 FR. Consomme 5 alcool du stock de matières de l\'usine, produit 10 désinfectants.'},
          {fn:'vendre_matiere_usine', label:'Vendre des matières à l\'usine', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre à l\'usine, depuis votre inventaire, les matières premières dont ses chaînes de production ont besoin.'}
        ]
      }
    }
  },

  'centre-multinodal-luthecia': {
    name: "Centre Multinodal de Luthecia",
    shortName: "Centre Multinodal",
    cat: "Transport",
    icon: "ti-building-arch",
    bgColor: "#080a10",
    desc: "Gare, aéroport international et station de bus et taxis. Le carrefour de tous les déplacements de Républia.",
    rooms: {
      hall_gare: {
        name: "Hall Principal",
        imageBg: "linear-gradient(135deg,#08090f,#101520)",
        desc: "Le hall principal. Gaston Retard annonce comme chaque matin un retard indéterminé sur la ligne Nord. Mireille Guichet sourit sans savoir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-centre-multimodal-luthecia.png",
        persons: [
          {name:'Gaston Retard (PNJ)', role:'Chef de gare', rel:'neutral', job:'chef_gare'},
          {name:'Mireille Guichet (PNJ)', role:'Hôtesse d\'accueil', rel:'neutral', job:'hotesse'}
        ],
        orders: [
          {fn:'prendre_train', label:'Prendre le train', pa:2, cost:75, type:'legal', icon:'ti-train', successRate:100, desc:'75 FR. 2 PA. Transport intra-empire vers une autre ville.'},
          {fn:'prendre_bus_taxi', label:'Prendre un bus ou taxi', pa:1, cost:150, type:'legal', icon:'ti-bus', successRate:100, desc:'150 FR. 1 PA. Transport intra-empire uniquement.'},
          {fn:'aller_douanes_aeroport', label:'Prendre l\'avion', pa:0, cost:0, type:'legal', icon:'ti-plane', successRate:100, desc:'Vous conduit au Hall des Douanes — contrôle obligatoire avant tout vol international.'},
          {fn:'taxi_caserne', label:'Taxi vers la Caserne', pa:1, cost:200, type:'legal', icon:'ti-military-rank', successRate:100, desc:'200 FR. 1 PA. Accès conditionné sur place.'},
          {fn:'taxi_qhs', label:'Taxi vers le QHS', pa:1, cost:200, type:'legal', icon:'ti-lock', successRate:100, desc:'200 FR. 1 PA. Accès conditionné sur place.'},
          {fn:'renseignement_transport_intl', label:'Demander conseil à Mireille', pa:0, cost:0, type:'legal', icon:'ti-info-circle', successRate:100, desc:'Se renseigner sur les moyens de transport internationaux.'}
        ]
      },
      hall_douanes: {
        name: "Hall des Douanes",
        imageBg: "linear-gradient(135deg,#08090f,#101215)",
        desc: "Le contrôle douanier. Obligatoire avant tout vol international. L\'Inspecteur Prosper Tampon veille avec son tampon béni.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-douanes-luthecia.png",
        persons: [
          {name:'Inspecteur Prosper Tampon (PNJ)', role:'Inspecteur des douanes', rel:'neutral', job:'douanier'}
        ],
        orders: [
          {fn:'passer_douanes_aeroport', label:'Passer le contrôle douanier', pa:0, cost:0, type:'legal', icon:'ti-shield-check', successRate:100, desc:'Obligatoire pour accéder à la zone d\'embarquement.'},
          {fn:'corrompre_douanier', label:'Corrompre l\'agent des douanes', pa:1, cost:300, type:'illegal', icon:'ti-coin', successRate:55, desc:'Éviter le contrôle. DUP/10 + INF/10. +20% zone transport.'}
        ]
      },
      zone_embarquement: {
        name: "Zone d\'Embarquement",
        imageBg: "linear-gradient(135deg,#05080f,#080c18)",
        desc: "La zone d\'embarquement internationale. Accès réservé aux voyageurs ayant passé les douanes.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-embarquement-luthecia.png",
        locked: false,
        requiresDouane: true,
        persons: [],
        orders: [
          {fn:'prendre_avion', label:'Prendre l\'avion', pa:2, cost:300, type:'legal', icon:'ti-plane', successRate:100, desc:'300 FR. 2 PA. Vol vers un autre empire.'}
        ]
      }
    }
  },

  'centre-multinodal-port-sainte-marie': {
    name: "Centre Multinodal de Port-Sainte-Marie",
    shortName: "Centre Multinodal",
    cat: "Transport",
    icon: "ti-building-arch",
    bgColor: "#080a10",
    desc: "Gare et station de bus. Sans aéroport. Pour rejoindre la capitale ou Montrouge.",
    rooms: {
      hall_gare_psm: {
        name: "Hall de la Gare",
        imageBg: "linear-gradient(135deg,#08090f,#101520)",
        desc: "Une petite gare de province. Calme. Le prochain train est dans 2 heures.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-centre-multimodal-accueil.png",
        persons: [
          {name:'Chef de Gare Local (PNJ)', role:'Chef de gare', rel:'neutral', job:'chef_gare'}
        ],
        orders: [
          {fn:'prendre_train', label:'Prendre le train', pa:2, cost:75, type:'legal', icon:'ti-train', successRate:100, desc:'75 FR. 2 PA. Vers Luthecia ou Montrouge.'},
          {fn:'prendre_bus_taxi', label:'Prendre un bus ou taxi', pa:1, cost:150, type:'legal', icon:'ti-bus', successRate:100, desc:'150 FR. 1 PA. Intra-empire uniquement.'}
        ]
      }
    }
  },

  'centre-multinodal-montrouge': {
    name: "Centre Multinodal de Montrouge",
    shortName: "Centre Multinodal",
    cat: "Transport",
    icon: "ti-building-arch",
    bgColor: "#080a10",
    desc: "Gare ouvrière et station de bus. Les dockers et mineurs y passent chaque matin.",
    rooms: {
      hall_gare_montrouge: {
        name: "Hall de la Gare",
        imageBg: "linear-gradient(135deg,#08090f,#101520)",
        desc: "Une gare industrielle. Bruyante. Les syndicats y ont leur table d\'information permanente.",
        imageUrl: "images/montrouge/montrouge-gare-hall.jpg",
        persons: [
          {name:'Chef de Gare Syndiqué (PNJ)', role:'Chef de gare', rel:'neutral', job:'chef_gare'},
          {name:'Délégué Syndical (PNJ)', role:'Délégué permanent', rel:'neutral', job:'syndicaliste'}
        ],
        orders: [
          {fn:'prendre_train', label:'Prendre le train', pa:2, cost:75, type:'legal', icon:'ti-train', successRate:100, desc:'75 FR. 2 PA. Vers Luthecia ou Port-Sainte-Marie.'},
          {fn:'prendre_bus_taxi', label:'Prendre un bus ou taxi', pa:1, cost:150, type:'legal', icon:'ti-bus', successRate:100, desc:'150 FR. 1 PA. Intra-empire uniquement.'}
        ]
      }
    }
  },

  // ---- MONTROUGE — fiches minimales pour la navigation par vues (2026-08-16) ----
  // Volontairement strictement minimales : nom, salle unique, aucun PNJ/ordre/mecanique
  // inventes. A enrichir plus tard si Fred le demande (voir dette signalee dans le rapport).
  'cafe-gare-montrouge': {
    name: "Café de la Gare",
    shortName: "Café de la Gare",
    cat: "Commerce",
    icon: "ti-coffee",
    bgColor: "#100c08",
    desc: "Un café en face de la gare de Montrouge.",
    rooms: { salle: { name: "Salle", desc: "Quelques tables, l'odeur du café.", imageBg: "linear-gradient(135deg,#100c08,#181008)", imageUrl: "images/montrouge/montrouge-cafe-gare-interieur.jpg", persons: [], orders: [
      {fn:'produire_commerce', label:'Produire', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Choisir un plat ou une boisson de la carte a preparer pour le service (consomme les matieres en stock, remunere en FR).'},
      {fn:'consulter_carte_commerce', label:'Consulter la carte', pa:0, cost:0, type:'legal', icon:'ti-menu-2', successRate:100, desc:'Voir les plats et boissons disponibles et commander.'},
      // 'consommer_boisson' retire (30 aout 2026, audit dedie) : redondant avec 'Consulter la
      // carte', qui liste deja toutes les boissons avec un bouton Commander (meme mecanisme,
      // commanderProduitCommerce). doConsommerBoisson/confirmerConsommerBoissonUI laisses en
      // place (partages/inoffensifs), simplement plus exposes ici.
      {fn:'offrir_tournee', label:'Offrir une tournée', pa:0, cost:0, type:'legal', icon:'ti-glass-cocktail', successRate:100, desc:'Offrez une tournee (une seule boisson de la carte) a plusieurs personnes presentes, a vos frais. Chacun accepte ou refuse independamment ; vous ne buvez et ne payez que si au moins une personne accepte. Cout reel : 1 PA + le prix de la boisson x (nombre d\'acceptants + vous).'},
      {fn:'gerer_commerce', label:'Gérer mon commerce', pa:0, cost:0, type:'legal', icon:'ti-settings', successRate:100, desc:'Réservé au propriétaire : coûts de revient, fourchette de prix autorisée, ajustement.'},
      {fn:'vendre_matiere_commerce', label:'Vendre des matières au commerce', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les matières premières de votre inventaire à ce commerce.'},
      // Repris a l'identique du template BUILDINGS['marche'].rooms.marche_ext (audit dedie, 30
      // aout 2026 -- duplication du marche vers les bars de Republia).
      {fn:'lancer_rumeur_cible', label:'Lancer une rumeur', pa:1, cost:0, type:'grey', icon:'ti-messages', successRate:75, desc:'Rediger une rumeur visant un PJ, une organisation, un local, un gouvernement ou un pays. Succes (75%) : effet selon la cible. Echec : retour de bâton limite + risque de detection.'}
    ] } }
  },
  'brasserie-voyageurs-montrouge': {
    name: "Brasserie des Voyageurs",
    shortName: "Brasserie des Voyageurs",
    cat: "Commerce",
    icon: "ti-beer",
    bgColor: "#100c08",
    desc: "Une brasserie pres de la gare de Montrouge.",
    rooms: { salle: { name: "Salle", desc: "Comptoir et banquettes.", imageBg: "linear-gradient(135deg,#100c08,#181008)", imageUrl: "images/montrouge/montrouge-brasserie-voyageurs.jpg", persons: [], orders: [
      {fn:'produire_commerce', label:'Cuisiner', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Préparer un plat de la carte (consomme les matières en stock, rémunéré en FR).'},
      {fn:'consulter_carte_commerce', label:'Consulter la carte', pa:1, cost:0, type:'legal', icon:'ti-menu-2', successRate:100, desc:'Voir les plats disponibles et commander.'},
      {fn:'gerer_commerce', label:'Gérer mon commerce', pa:0, cost:0, type:'legal', icon:'ti-settings', successRate:100, desc:'Réservé au propriétaire : coûts de revient, fourchette de prix autorisée, ajustement.'},
      {fn:'vendre_matiere_commerce', label:'Vendre des matières au commerce', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les matières premières de votre inventaire à ce commerce.'},
      // Repris a l'identique du template BUILDINGS['marche'].rooms.marche_ext (audit dedie, 30
      // aout 2026 -- duplication du marche vers les bars de Republia).
      {fn:'lancer_rumeur_cible', label:'Lancer une rumeur', pa:1, cost:0, type:'grey', icon:'ti-messages', successRate:75, desc:'Rediger une rumeur visant un PJ, une organisation, un local, un gouvernement ou un pays. Succes (75%) : effet selon la cible. Echec : retour de bâton limite + risque de detection.'}
    ] } }
  },
  // Structure a 6 salles + accueil (17 aout 2026, implantation des images preparees) --
  // remplace l'ancien placeholder a une seule salle sans image. montrouge-musee-memoire-
  // ouvriere.jpg (planche a plusieurs concepts) reste DELIBEREMENT en reserve, jamais reference
  // ici. Les anciennes idees "Les gens de Montrouge"/"Une vie a l'usine"/"Les cites ouvrieres"/
  // "Les grandes catastrophes" sont integrees transversalement aux 6 salles existantes (salle_
  // ville et salle_luttes notamment), pas de salle supplementaire creee.
  'musee-histoire-montrouge': {
    name: "Musée de l'Histoire de Montrouge — Autour du Rail",
    shortName: "Musée de Montrouge",
    cat: "Culture",
    icon: "ti-building-monument",
    bgColor: "#0c0a06",
    desc: "Musée consacré à l'histoire cheminote de Montrouge.",
    rooms: {
      accueil: { name: "Accueil", desc: "L'accueil du musée, consacré à l'histoire cheminote de Montrouge.", imageBg: "linear-gradient(135deg,#0c0a06,#14100a)", imageUrl: "images/montrouge/montrouge-musee-accueil.jpg", persons: [], orders: [] },
      salle_terre: { name: "Salle 1 — La terre", desc: "Montrouge avant l'Homme : géologie du bassin, charbon, roche ferrugineuse, origine du nom de Montrouge.", imageBg: "linear-gradient(135deg,#0c0a06,#14100a)", imageUrl: "images/montrouge/montrouge-musee-prehistoire.jpg", audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/montrouge/montrouge-musee-terre.mp3", persons: [], orders: [] },
      salle_industrie: { name: "Salle 2 — L'industrie", desc: "Le fer et le charbon, matières premières de l'essor industriel de Montrouge.", imageBg: "linear-gradient(135deg,#0c0a06,#14100a)", imageUrl: "images/montrouge/montrouge-musee-fer-charbon.jpg", audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/montrouge/montrouge-musee-fer-charbon.mp3", persons: [], orders: [] },
      salle_rail: { name: "Salle 3 — Le rail", desc: "Le train et le rail : du fer et du charbon au chemin de fer, moteur du développement de Montrouge.", imageBg: "linear-gradient(135deg,#0c0a06,#14100a)", imageUrl: "images/montrouge/montrouge-musee-train-rail.jpg", audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/montrouge/montrouge-musee-rail.mp3", persons: [], orders: [] },
      salle_ville: { name: "Salle 4 — La ville et ses habitants", desc: "Urbanisation et vie ouvrière : cités ouvrières, quotidien des travailleurs, travail à l'usine.", imageBg: "linear-gradient(135deg,#0c0a06,#14100a)", imageUrl: "images/montrouge/montrouge-musee-urbanisation.jpg", audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/montrouge/montrouge-musee-habitants.mp3", persons: [], orders: [] },
      salle_luttes: { name: "Salle 5 — Les luttes", desc: "Montrouge en lutte : syndicalisme, grèves, solidarité ouvrière et conquêtes sociales.", imageBg: "linear-gradient(135deg,#0c0a06,#14100a)", imageUrl: "images/montrouge/montrouge-musee-luttes.jpg", audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/montrouge/montrouge-musee-luttes.mp3", persons: [], orders: [] },
      salle_loisirs: { name: "Salle 6 — Les loisirs", desc: "La détente des ouvriers : cafés, vie associative, et une large place donnée au football et à l'UCM.", imageBg: "linear-gradient(135deg,#0c0a06,#14100a)", imageUrl: "images/montrouge/montrouge-musee-detente.jpg", audioUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/audio/montrouge/montrouge-musee-loisirs.mp3", persons: [], orders: [] }
    }
  },
  'eglise-montrouge': {
    name: "Église",
    shortName: "Église",
    cat: "Cultes",
    icon: "ti-cross",
    bgColor: "#0c0a06",
    desc: "L'église de Montrouge.",
    // Socle religieux (lot "carriere religieuse Republia", 26 aout 2026) : actions de lieu
    // (prier/don) memes fn/handlers qu'a Luthecia (aucun handler duplique). Abbe Tonniere,
    // religieux local de reference et titulaire PNJ initial de la charge de Pretre de Montrouge,
    // rend desormais confession/benediction/consulter la regle disponibles ici (voir
    // openPnjModal, plateau-pnj.js -- job:'pretre' ajoute a la liste habilitee).
    rooms: { salle: { name: "Nef", desc: "Un lieu de recueillement.", imageBg: "linear-gradient(135deg,#0c0a06,#14100a)", imageUrl: "images/montrouge/montrouge-eglise-nef.jpg", persons: [
      {name:'Abbé Tonnière (PNJ)', role:'Prêtre de Montrouge', rel:'neutral', job:'pretre'}
    ], orders: [
      {fn:'prier',     label:'Prier le Formulaire Sacré',  pa:1, cost:0,   type:'legal', icon:'ti-star',  successRate:100, desc:'Vous priez pour vous-même (+2 Moral) tout en nourrissant la ferveur religieuse de Montrouge (+3 piété locale).'},
      {fn:'faire_don', label:'Faire un don a l\'Eglise',   pa:1, cost:200, type:'legal', icon:'ti-coins', successRate:100, desc:'200 FR pris sur votre argent personnel. +3 popularité pour vous, +5 piété locale pour Montrouge.'}
    ] } }
  },
  // Lieu purement environnemental (2026-08-16) : la locomotive et la place au centre de la
  // vue 7, distinctes de la facade de la mairie. Aucun ordre/PNJ/mecanique, meme patron
  // minimal que eglise-montrouge/cinema-montrouge.
  'place-du-rail-montrouge': {
    name: "Place du Rail",
    shortName: "Place du Rail",
    cat: "Lieux publics",
    icon: "ti-train",
    bgColor: "#0c0c0e",
    desc: "La place centrale de Montrouge, dominee par la locomotive-monument.",
    rooms: { place: { name: "Place du Rail", desc: "La locomotive-monument trone au centre de la place.", imageBg: "linear-gradient(135deg,#0c0c0e,#141418)", imageUrl: "images/montrouge/montrouge-place-du-rail.jpg", persons: [], orders: [] } }
  },
  // Salle 1/Salle 2 ajoutees (17 aout 2026, implantation des images preparees) -- le Hall
  // existant (accueil/guichet) est conserve tel quel, roomId 'salle' inchange (verifie sans
  // autre reference dans le depot). Simple image de fond pour chaque salle de projection --
  // aucune mecanique de diffusion/propagande ajoutee, hors perimetre de ce lot.
  'cinema-montrouge': {
    name: "Cinéma de Montrouge",
    shortName: "Cinéma",
    cat: "Loisirs",
    icon: "ti-movie",
    bgColor: "#100810",
    desc: "Le cinéma de Montrouge.",
    rooms: {
      salle: { name: "Hall", desc: "Affiches de films, guichet.", imageBg: "linear-gradient(135deg,#100810,#180c18)", imageUrl: "images/montrouge/montrouge-cinema-accueil.jpg", persons: [], orders: [] },
      salle_1: { name: "Salle 1", desc: "Une des deux salles de projection du cinéma de Montrouge.", imageBg: "linear-gradient(135deg,#100810,#180c18)", imageUrl: "images/montrouge/montrouge-cinema-salle-1.jpg", persons: [], orders: [] },
      salle_2: { name: "Salle 2", desc: "L'autre salle de projection du cinéma de Montrouge.", imageBg: "linear-gradient(135deg,#100810,#180c18)", imageUrl: "images/montrouge/montrouge-cinema-salle-2.jpg", persons: [], orders: [] }
    }
  },
  'jardins-ouvriers-montrouge': {
    name: "Jardins ouvriers",
    shortName: "Jardins ouvriers",
    cat: "Espaces verts",
    icon: "ti-plant-2",
    bgColor: "#0a1008",
    desc: "Des parcelles cultivées par les ouvriers de Montrouge.",
    rooms: { salle: { name: "Parcelles", desc: "Rangs de légumes et cabanons.", imageBg: "linear-gradient(135deg,#0a1008,#0e1810)", imageUrl: "images/montrouge/montrouge-jardins-ouvriers-interieur.jpg", persons: [], orders: [] } }
  },
  'logements-montrouge': {
    name: "Logements",
    shortName: "Logements",
    cat: "Habitat",
    icon: "ti-home",
    bgColor: "#0a0a08",
    desc: "Immeubles de logements de Montrouge.",
    // Logements sociaux (18 aout 2026) : batiment exclusif a Montrouge (jamais partage avec
    // une autre ville), donc les 4 appartements sont ajoutes directement ici, sans passer par
    // buildingContext/roomsExtra (reserve aux batiments generiques partages entre villes).
    // Aucun ordre 'louer_local' sur ces rooms : l'attribution n'est jamais en self-service,
    // uniquement via le bureau de l'adjoint au maire (buildingContext['mairie'].roomOverrides.
    // bureau_maire_adjoint.orders, Montrouge uniquement -- voir plus haut dans ce fichier).
    // Le hall (salle) reste purement spatial, sans ordre administratif.
    // locationData.logementSocial:true + orgaAutorisee:false identifient ces 4 rooms pour les
    // regles specifiques (residence Montrouge, resiliation au depart, bonus de sommeil,
    // interdiction d'organisation) sans toucher aux locations commerciales existantes.
    rooms: {
      salle: {
        // Hall pur : navigation vers les 4 appartements uniquement (via les onglets de pieces,
        // deja automatiques puisque ce sont de vraies rooms ci-dessous). Aucun ordre administratif
        // ici -- deplaces dans le bureau de l'adjoint au maire (buildingContext['mairie'] ci-dessus),
        // decision game design du 18 aout 2026 : ce batiment n'est pas un guichet.
        name: "Hall d'immeuble",
        desc: "Boîtes aux lettres, escalier.",
        imageBg: "linear-gradient(135deg,#0a0a08,#100f0c)",
        imageUrl: "images/montrouge/montrouge-immeuble-hall.jpg",
        persons: [],
        orders: []
      },
      petit_appartement_1: {
        name: "Petit appartement n°1",
        desc: "Un studio modeste, propriété de la mairie.",
        imageBg: "linear-gradient(135deg,#0a0a08,#100f0c)",
        imageUrl: "images/montrouge/montrouge-appartement-petit.jpg",
        isLocationRoom: true,
        locationData: { type: 'petit', prix: 30, bonusPOP: 0, bonusINF: 0, bonusDIS: 0, label: 'Petit appartement n°1', logementSocial: true, orgaAutorisee: false, bonusMoralSommeil: 3, bonusSanteSommeil: 4 },
        persons: [],
        orders: [
          {fn:'gerer_logement_social', label:'Mon logement', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:"Voir les conditions de votre bail, si vous êtes le locataire de cet appartement."}
        ]
      },
      petit_appartement_2: {
        name: "Petit appartement n°2",
        desc: "Un studio modeste, propriété de la mairie.",
        imageBg: "linear-gradient(135deg,#0a0a08,#100f0c)",
        imageUrl: "images/montrouge/montrouge-appartement-petit.jpg",
        isLocationRoom: true,
        locationData: { type: 'petit', prix: 30, bonusPOP: 0, bonusINF: 0, bonusDIS: 0, label: 'Petit appartement n°2', logementSocial: true, orgaAutorisee: false, bonusMoralSommeil: 3, bonusSanteSommeil: 4 },
        persons: [],
        orders: [
          {fn:'gerer_logement_social', label:'Mon logement', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:"Voir les conditions de votre bail, si vous êtes le locataire de cet appartement."}
        ]
      },
      grand_appartement_1: {
        name: "Grand appartement n°1",
        desc: "Un logement familial, propriété de la mairie.",
        imageBg: "linear-gradient(135deg,#0a0a08,#100f0c)",
        imageUrl: "images/montrouge/montrouge-appartement-grand.jpg",
        isLocationRoom: true,
        locationData: { type: 'grand', prix: 60, bonusPOP: 0, bonusINF: 0, bonusDIS: 0, label: 'Grand appartement n°1', logementSocial: true, orgaAutorisee: false, bonusMoralSommeil: 5, bonusSanteSommeil: 7 },
        persons: [],
        orders: [
          {fn:'gerer_logement_social', label:'Mon logement', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:"Voir les conditions de votre bail, si vous êtes le locataire de cet appartement."}
        ]
      },
      grand_appartement_2: {
        name: "Grand appartement n°2",
        desc: "Un logement familial, propriété de la mairie.",
        imageBg: "linear-gradient(135deg,#0a0a08,#100f0c)",
        imageUrl: "images/montrouge/montrouge-appartement-grand.jpg",
        isLocationRoom: true,
        locationData: { type: 'grand', prix: 60, bonusPOP: 0, bonusINF: 0, bonusDIS: 0, label: 'Grand appartement n°2', logementSocial: true, orgaAutorisee: false, bonusMoralSommeil: 5, bonusSanteSommeil: 7 },
        persons: [],
        orders: [
          {fn:'gerer_logement_social', label:'Mon logement', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:"Voir les conditions de votre bail, si vous êtes le locataire de cet appartement."}
        ]
      }
    }
  },
  'cafe-tabac-cheminots-montrouge': {
    name: "Café des Cheminots — Bar-Tabac",
    shortName: "Café des Cheminots",
    cat: "Commerce",
    icon: "ti-cigarette",
    bgColor: "#100c08",
    desc: "Le café-tabac des cheminots de Montrouge. Un seul et même établissement.",
    // lancer_rumeur_cible repris a l'identique du template BUILDINGS['marche'].rooms.marche_ext
    // (meme pa/cost/successRate/desc) -- nouveau point d'acces au meme ordre, audit dedie du
    // 30 aout 2026 (duplication du marche vers les bars de Republia).
    // Ordres commerciaux (30 aout 2026, alignement sur le Cafe de la Gare) : repris a l'identique
    // (fn/label/pa/cost/type/icon/successRate/desc inchanges) du template BUILDINGS['cafe-gare-
    // montrouge'].rooms.salle.orders -- meme moteur generique (BUILDING_COMMERCE_TYPE/
    // DOTATIONS_COMMERCE_PILOTE, plateau-actions-illegales-rumeurs.js), stock et caisse
    // independants du Cafe de la Gare car scopes par ce buildingId distinct (getCommerceId()).
    rooms: { salle: { name: "Salle", desc: "Comptoir, tabac, quelques tables.", imageBg: "linear-gradient(135deg,#100c08,#181008)", imageUrl: "images/montrouge/montrouge-bar-tabac-interieur.jpg", persons: [], orders: [
      {fn:'produire_commerce', label:'Produire', pa:0, cost:0, type:'legal', icon:'ti-tools-kitchen-2', successRate:100, desc:'Choisir un plat ou une boisson de la carte a preparer pour le service (consomme les matieres en stock, remunere en FR).'},
      {fn:'consulter_carte_commerce', label:'Consulter la carte', pa:0, cost:0, type:'legal', icon:'ti-menu-2', successRate:100, desc:'Voir les plats et boissons disponibles et commander.'},
      // 'consommer_boisson' retire (30 aout 2026, meme audit que le Cafe de la Gare) : redondant
      // avec 'Consulter la carte'.
      {fn:'offrir_tournee', label:'Offrir une tournée', pa:0, cost:0, type:'legal', icon:'ti-glass-cocktail', successRate:100, desc:'Offrez une tournee (une seule boisson de la carte) a plusieurs personnes presentes, a vos frais. Chacun accepte ou refuse independamment ; vous ne buvez et ne payez que si au moins une personne accepte. Cout reel : 1 PA + le prix de la boisson x (nombre d\'acceptants + vous).'},
      {fn:'gerer_commerce', label:'Gérer mon commerce', pa:0, cost:0, type:'legal', icon:'ti-settings', successRate:100, desc:'Réservé au propriétaire : coûts de revient, fourchette de prix autorisée, ajustement.'},
      {fn:'vendre_matiere_commerce', label:'Vendre des matières au commerce', pa:0, cost:0, type:'legal', icon:'ti-package-export', successRate:100, desc:'Vendre les matières premières de votre inventaire à ce commerce.'},
      {fn:'lancer_rumeur_cible', label:'Lancer une rumeur', pa:1, cost:0, type:'grey', icon:'ti-messages', successRate:75, desc:'Rediger une rumeur visant un PJ, une organisation, un local, un gouvernement ou un pays. Succes (75%) : effet selon la cible. Echec : retour de bâton limite + risque de detection.'}
    ] } }
  },

  // ---- PORTS ----

  'port-sainte-marie': {
    name: "Port Industriel de Port-Sainte-Marie",
    shortName: "Port Industriel",
    cat: "Port",
    icon: "ti-anchor",
    bgColor: "#050810",
    desc: "Le grand port de Républia. Commerce maritime, syndicats puissants et réseaux de contrebande discrets.",
    // Restructuration du port industriel (lot du 24 aout 2026) : les 3 anciennes rooms
    // administratives (bureau_port, bureau_directeur_port, bureau_commandant_port) sont
    // fusionnees en une seule 'administration_portuaire' -- aucune reference codee en dur a ces
    // 3 anciens ids trouvee ailleurs dans le code (verifie avant fusion), aucun risque. Les
    // orders de bureau_port (consulter_manifeste/falsifier_manifeste) sont reportes a l'identique
    // (fn/cout/desc/handler inchanges) ; bureau_directeur_port/bureau_commandant_port n'avaient
    // aucun order. Marcel Ancre et Ginette Conteneur, precedemment dupliques sur plusieurs rooms,
    // n'apparaissent plus que dans administration_portuaire (identite/role/job inchanges).
    // Aucun order deplace/modifie/ajoute ailleurs ; aucune mecanique syndicale/douaniere creee.
    rooms: {
      quai_principal: {
        name: "Quai Principal",
        imageBg: "linear-gradient(135deg,#050810,#0a0f18)",
        desc: "Les grues bleues s\'activent.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-port-industriel.png",
        // Alain Bordage (lot du 24 aout 2026, order dedie supprime le 25 aout 2026) : employe de
        // la compagnie maritime, renseigne desormais les voyageurs directement via le dialogue
        // PNJ standard (talkToPnj, voir PNJ_PERSONALITIES/PNJ_PROFILS dans plateau-core.js) --
        // plus d'order separe, il repond comme n'importe quel PNJ conversationnel de la room.
        // Sans rapport avec le fret v68 (caisses_fret) ni avec Pascal Paguevite (douanes/fret,
        // room separee). Aucun portrait adapte trouve dans Downloads au moment de sa creation --
        // toujours pas de photoUrl invente/reutilise.
        persons: [
          {name:'Alain Bordage (PNJ)', role:'Employé de la compagnie maritime', rel:'neutral', job:'agent_maritime'}
        ],
        orders: [
          {fn:'prendre_bateau', label:'Prendre le bateau', pa:5, cost:100, type:'legal', icon:'ti-ship', successRate:100, desc:'100 FR. 5 PA. Transport inter-empire. Plus lent mais moins cher que l\'avion.'},
          {fn:'inspecter_cargaisons', label:'Inspecter les cargaisons', pa:2, cost:0, type:'legal', icon:'ti-search', successRate:80, requiresPost:'min_def', desc:'Révèle contrebandes en cours. INT/10 + ISN/10. Prérogative min_def ou commissaire.'}
        ]
      },
      criee: {
        name: "Criée",
        imageBg: "linear-gradient(135deg,#08100c,#0c1810)",
        desc: "La grande criée industrielle du port : lots de poisson pesés et vendus chaque matin, cours affichés en direct.",
        imageUrl: "images/port-sainte-marie-port-industriel-criee.png",
        persons: [],
        orders: [
          {fn:'acheter_criee', label:'Acheter à la Criée', pa:1, cost:0, type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'Poisson pêché quotidiennement, vendu directement aux joueurs (4 FR/unité).'}
        ]
      },
      // isLocationRoom/locationData retires ici (lot du 25 aout 2026, §13-14) : l'ancien bail
      // EXCLUSIF (350 FR/jour, +6 DIS +3 INF, un seul locataire possible pour toute la piece) est
      // remplace par un service de box INDIVIDUELS multi-tenant. Correctif UX du 25 aout 2026 :
      // louer_box/gerer_box (fonctions dediees plateau-justice-economie.js, mecanique v75/v76
      // totalement inchangee) vivent desormais dans leur propre room 'box_a_louer' (ci-dessous),
      // un onglet normal du batiment -- exactement le meme precedent que suite_privee/
      // suite_presidentielle (hotel-republica) : une piece distincte avec son propre titre/image/
      // description, PAS un ordre de gameplay affiche parmi les actions de l'entrepot. L'entrepot
      // reste reserve au fret prive (expedier_colis/receptionner_commande) et aux marchandises
      // non reclamees ; le box n'y vit plus du tout, ni en action ni en texte.
      entrepot: {
        name: "Entrepôts",
        imageBg: "linear-gradient(135deg,#050810,#08100a)",
        desc: "Immenses entrepôts de stockage et zones frigorifiques pour denrées périssables et exotiques.",
        imageUrl: "images/port-sainte-marie-port-industriel-entrepots.png",
        persons: [],
        orders: [
          {fn:'marchandises_non_reclamees', label:'Marchandises non réclamées', pa:0, cost:0, type:'legal', icon:'ti-truck-loading', successRate:100, desc:'Caisses de fret jamais vidées par leur destinataire (15 jours après arrivée), en vente au profit du port.'},
          // Deplaces depuis quai_principal (lot du 25 aout 2026, §6) : deplacement UX uniquement,
          // moteur caisses_fret (v68) totalement inchange -- voir ROOM_CHARGEMENT_FRET,
          // plateau-justice-economie.js, mis a jour en meme temps pour que la garde de presence
          // physique (jeSuisPresentDansRoomFret) continue de correspondre a la room reelle des
          // boutons. Fonctionne independamment de la location d'un entrepot/box ci-dessus --
          // aucune dependance introduite entre les deux.
          {fn:'expedier_colis', label:'Réserver une caisse de fret', pa:2, cost:200, type:'legal', icon:'ti-package-export', successRate:100, desc:'Réserve une caisse persistante (500 unités max) où vous et vos chargeurs autorisés pouvez déposer des marchandises avant de la fermer et l\'expédier vers un PJ d\'un autre empire. Délai 1 jour.'},
          {fn:'receptionner_commande', label:'Réceptionner une caisse', pa:1, cost:0, type:'legal', icon:'ti-package-import', successRate:100, desc:'Consulter et dédouaner les caisses arrivées à votre nom. Droits de douane et gardiennage éventuel dus avant tout retrait.'}
        ]
      },
      // Piece dediee du box portuaire (correctif UX du 25 aout 2026, 2e passe) : onglet NORMAL et
      // visible du batiment, comme n'importe quelle autre piece (Criee, Douanes, Entrepots...) --
      // PAS de flag hiddenTab (retire de la 1ere passe, qui affichait Box à louer comme un simple
      // bouton vert dans les actions de l'entrepot, presentation rejetee). Le joueur y accede en
      // cliquant l'onglet "Box à louer" et en revient en cliquant l'onglet "Entrepôts", exactement
      // comme il navigue entre n'importe quelle autre paire de pieces du jeu -- aucun ordre de
      // retour dedie necessaire. isLocationRoom/locationData volontairement absents : ce n'est PAS
      // le moteur de location exclusif (Option B toujours valide), seulement une piece dont les
      // deux SEULS ordres sont les fonctions dediees louer_box/gerer_box (plateau-justice-
      // economie.js, mecanique v75/v76 totalement inchangee -- getMaBoxPortuaire/resilierBox/
      // sbSaveLocationBox/sbSupprimerLocationBox/payerLocations/tarif 15 FR/jour/absence de bonus
      // DIS/INF ne dependent d'aucune facon de la piece ou vit l'ordre, voir leur commentaire
      // dedie). imageUrl volontairement absent : aucune image dediee "box portuaire" trouvee dans
      // le depot au moment de ce lot -- chemin attendu si l'utilisateur en fournit une plus tard :
      // images/port-sainte-marie-port-industriel-box-a-louer.png (imageBg sert de repli en
      // attendant, meme convention que les autres rooms sans photo dediee).
      box_a_louer: {
        name: "Box à louer",
        imageBg: "linear-gradient(135deg,#050810,#08100a)",
        desc: "Une rangée de box individuels grillagés, chacun fermé par son propre cadenas. Aucun bonus de discrétion ou d'influence : juste du stockage.",
        persons: [],
        orders: [
          {fn:'louer_box', label:'Louer un box (15 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Box individuel de stockage, indépendant des autres locataires. Aucun bonus DIS/INF.'},
          {fn:'gerer_box', label:'Gérer mon box', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      },
      // Pascal Paguevite (PNJ), lot du 24 aout 2026 : titulaire initial du poste Chef des
      // Douanes (POSTES_NOMMES_EXCLUSIFS ci-dessus + cascade PNJ du cron). Portrait ajoute le
      // meme jour (generation la plus recente de ~/Downloads, version corrigee au drapeau gris
      // de Republia, verifiee visuellement) -- image utilisee telle quelle, aucun crop/retouche
      // du visage, photoPos cadre juste le buste comme les autres PNJ. Les effectifs de
      // douaniers recrutes par le Chef sont rattaches en dur a cette room
      // (buildingId:'port-sainte-marie', roomId:'douanes'), jamais affiches individuellement ici
      // (meme convention que les policiers : affichage minimal via getAffichage*Piece, voir
      // plateau-justice-economie.js).
      douanes: {
        name: "Douanes",
        imageBg: "linear-gradient(135deg,#050810,#0a0f18)",
        desc: "Le bureau des douaniers du port : contrôle documentaire, dossiers de cargaisons et va-et-vient incessant entre dockers et agents.",
        imageUrl: "images/port-sainte-marie-port-industriel-douanes.png",
        persons: [
          {name:'Pascal Paguevite (PNJ)', role:'Chef des Douanes', rel:'neutral', job:'chef_douanes', photoUrl:'images/port-sainte-marie-port-industriel-pascal-paguevite.png', photoPos:'50% 20%'}
        ],
        orders: [
          {fn:'consulter_effectifs_douane', label:'Consulter les effectifs', pa:0, cost:0, type:'legal', icon:'ti-users', successRate:100, desc:'Liste publique des douaniers en service (information administrative, sans détail de compétences).'},
          {fn:'recruter_douanier', label:'Recruter un douanier', pa:1, cost:0, type:'legal', icon:'ti-user-plus', successRate:100, requiresPost:'chef_douanes', desc:'PER 12, VOL 12. Paye directement par le Ministere de l\'Interieur -- aucune caisse propre aux douanes.'},
          {fn:'recruter_douanier_cynophile', label:'Recruter une unité cynophile', pa:1, cost:0, type:'legal', icon:'ti-dog', successRate:100, requiresPost:'chef_douanes', desc:'Maitre-chien + chien anti-stupefiants. Compte comme un douanier normal, avec un bonus specialise lors des controles. Paye directement par le Ministere de l\'Interieur, au double du tarif d\'un douanier standard.'},
          {fn:'gerer_effectifs_douane', label:'Gérer les effectifs douaniers', pa:0, cost:0, type:'legal', icon:'ti-users-group', successRate:100, requiresPost:'chef_douanes', desc:'Recruter ou licencier des douaniers, tous rattachés au service des douanes du port.'},
          {fn:'controler_caisse_douane', label:'Contrôler une caisse de fret', pa:1, cost:0, type:'legal', icon:'ti-search', successRate:100, requiresPost:'chef_douanes', desc:'Cible une caisse precise (arrivee ou en instance de depart) via le manifeste et ordonne son controle par le service. Le contenu reel n\'est jamais revele avant le resultat.'}
        ]
      },
      // blocus_portuaire deplace ici depuis quai_principal (lot du 25 aout 2026, correctif
      // production : n'importe quel PJ pouvait le declencher depuis le quai). Etienne Dantafasse
      // etait jusqu'ici purement decoratif (job:null, aucune organisation reelle ne le
      // referencait) -- une organisation reelle de type 'syndicale' (TYPES_ORGANISATIONS, meme
      // systeme que les clubs de supporters) est desormais creee paresseusement a la premiere
      // visite de cette room (getSyndicatDockersPSM/chargerOuCreerSyndicatDockersPSM,
      // plateau-organisations-quetes.js), avec Etienne comme chef PNJ par defaut, remplacable
      // plus tard par election via le mecanisme generique deja existant
      // (verifierElectionsOrganisations, type-agnostique). requiresChefSyndicatDockers:true est
      // un nouveau flag, verifie dans renderRoomActions (plateau-politique.js) -- garde UI
      // uniquement ; doBlocusPortuaire() revalide independamment le chef reel cote handler.
      bureau_syndical_dockers: {
        name: "Bureau Syndical des Dockers",
        imageBg: "linear-gradient(135deg,#100a08,#180e0a)",
        desc: "Le local du Syndicat des Dockers de Port-Sainte-Marie : affiches de mobilisation, tableau d'annonces et permanence syndicale.",
        imageUrl: "images/port-sainte-marie-port-industriel-syndicat-dockers.png",
        persons: [
          {name:'Dédé le Docker (PNJ)', role:'Docker syndiqué', rel:'neutral', job:'docker'},
          {name:'Étienne Dantafasse (PNJ)', role:'Président du Syndicat des Dockers de Port-Sainte-Marie', rel:'neutral', job:null, photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-port-industriel-etienne-dantafasse.png', photoPos:'50% 12%'}
        ],
        orders: [
          {fn:'se_syndiquer', label:'Se syndiquer', pa:1, cost:50, type:'legal', icon:'ti-users-group', successRate:100, desc:'Adhérer au Syndicat des Dockers de Port-Sainte-Marie (50 FR).'},
          {fn:'consulter_organigramme_syndicat', label:'Consulter l\'organigramme', pa:0, cost:0, type:'legal', icon:'ti-list-details', successRate:100, desc:'Chef actuel et membres du Syndicat des Dockers.'},
          {fn:'declencher_election_syndicat', label:'Déclencher une élection', pa:1, cost:0, type:'legal', icon:'ti-ballot', successRate:100, desc:'Réservé aux membres. 3 jours de candidatures puis 3 jours de vote.'},
          {fn:'organiser_manifestation_syndicat', label:'Organiser une manifestation', pa:2, cost:0, type:'legal', icon:'ti-megaphone', successRate:100, requiresChefSyndicatDockers:true, desc:'Réservé au chef du Syndicat des Dockers.'},
          {fn:'blocus_portuaire', label:'Blocus portuaire', pa:3, cost:0, type:'grey', icon:'ti-barrier-block', successRate:60, requiresChefSyndicatDockers:true, desc:'Paralyse les importations/exportations 24h. VOL/10 + ENT/10. -IE. Réservé au chef du Syndicat des Dockers.'}
        ]
      },
      administration_portuaire: {
        name: "Administration Portuaire",
        imageBg: "linear-gradient(135deg,#0a0c10,#0e1218)",
        desc: "La salle opérationnelle de l'administration du port, avec vue sur les quais et les grues du port industriel.",
        imageUrl: "images/port-sainte-marie-port-industriel-administration.png",
        persons: [
          {name:'Marcel Ancre (PNJ)', role:'Commandant de Port', rel:'neutral', job:'capitaine_port', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-port-industriel-marcel-ancre.png', photoPos:'50% 15%'},
          {name:'Ginette Conteneur (PNJ)', role:'Agente de fret', rel:'neutral', job:'agent_fret', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-port-industriel-ginette-conteneur.png', photoPos:'50% 15%'}
        ],
        orders: [
          {fn:'consulter_manifeste', label:'Consulter le manifeste', pa:0, cost:0, type:'legal', icon:'ti-file-search', successRate:100, desc:'Registre administratif persistant : cargaisons de fret privé déclarées (sans révéler leur contenu réel) et flux institutionnels du port. Consultation publique, gratuite.'},
          {fn:'consulter_administration_port', label:'Administration du port', pa:0, cost:0, type:'legal', icon:'ti-anchor', successRate:100, desc:'Stock institutionnel, répartition entre Luthécia/Port-Sainte-Marie/Montrouge, arrivages récents, stocks des 3 entrepôts, caisse du port et situation des exportations. Consultation publique, gratuite.'},
          {fn:'gerer_logistique_port', label:'Gérer la logistique nationale', pa:0, cost:0, type:'legal', icon:'ti-adjustments', successRate:100, requiresPost:'capitaine_port', desc:'Réservé au Commandant du Port : modifier la répartition de la logistique nationale entre Luthécia, Port-Sainte-Marie et Montrouge.'}
        ]
      }
    }
  },

  'port-novomirsk': {
    name: "Port de Novomirsk",
    shortName: "Port Novomirsk",
    cat: "Port",
    icon: "ti-anchor",
    bgColor: "#050810",
    desc: "Le port collectif de Sovarka. Tout est catalogué, tout est surveillé. Camarade Grue note chaque conteneur.",
    rooms: {
      quai_sovarka: {
        name: "Quai du Peuple",
        imageBg: "linear-gradient(135deg,#050810,#0a0f15)",
        desc: "Des grues rouillées s\'activent sous un ciel gris acier. Camarade Grue surveille. Boris Docker compte les boîtes pour le troisième rapport de la journée.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sovarka.png",
        persons: [
          {name:'Camarade Grue (PNJ)', role:'Directeur du port', rel:'neutral', job:'capitaine_port'},
          {name:'Boris Docker (PNJ)', role:'Docker du Parti', rel:'neutral', job:'docker'}
        ],
        orders: [
          {fn:'prendre_bateau', label:'Prendre le bateau', pa:5, cost:100, type:'legal', icon:'ti-ship', successRate:100, desc:'100 FR. 5 PA. Transport inter-empire.'},
          {fn:'expedier_colis', label:'Expédier un colis', pa:2, cost:200, type:'legal', icon:'ti-package-export', successRate:100, desc:'Envoyer un objet à un PJ autre empire. Délai 24h.'},
          {fn:'receptionner_commande', label:'Réceptionner une commande', pa:1, cost:0, type:'legal', icon:'ti-package-import', successRate:100, desc:'Récupérer un objet commandé.'},
          {fn:'contrebande_port', label:'Contrebande portuaire', pa:3, cost:0, type:'illegal', icon:'ti-package-off', successRate:35, desc:'Très risqué à Sovarka. DIS/10 + DUP/10. -20% modificateur Sovarka.'},
          {fn:'acheter_polonium', label:'Obtenir du Polonium', pa:2, cost:600, type:'illegal', icon:'ti-radioactive', successRate:50, desc:'Objet poison de Sovarka. Usage unique. DUP/10 + DIS/10. Disponible uniquement ici.'},
          {fn:'inspecter_cargaisons', label:'Inspecter les cargaisons', pa:2, cost:0, type:'legal', icon:'ti-search', successRate:90, requiresPost:'min_def', desc:'Révèle contrebandes. Sovarka +25% efficacité surveillance.'}
        ]
      }
    }
  },

  'port-ciudad-roja': {
    name: "Port de Ciudad Roja",
    shortName: "Port Ciudad Roja",
    cat: "Port",
    icon: "ti-anchor",
    bgColor: "#050810",
    desc: "Le port chaotique d\'El Estado. Zona Restringida. El Capitan Turbio ne pose jamais de questions.",
    rooms: {
      quai_el_estado: {
        name: "Quai de la Contrebande",
        imageBg: "linear-gradient(135deg,#100505,#180a08)",
        desc: "Barques rouillées, conteneurs tagués, odeur de diesel et de corruption. El Capitan Turbio fume un cigare en regardant ailleurs.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-el-estado.png",
        persons: [
          {name:'El Capitan Turbio (PNJ)', role:'Capitaine de port', rel:'neutral', job:'capitaine_port'},
          {name:'Paco Cargaison (PNJ)', role:'Docker spécialiste', rel:'neutral', job:'docker'}
        ],
        orders: [
          {fn:'prendre_bateau', label:'Prendre le bateau', pa:5, cost:100, type:'legal', icon:'ti-ship', successRate:100, desc:'100 FR. 5 PA. Transport inter-empire.'},
          {fn:'expedier_colis', label:'Expédier un colis', pa:2, cost:200, type:'legal', icon:'ti-package-export', successRate:100, desc:'Envoyer un objet à un PJ autre empire.'},
          {fn:'receptionner_commande', label:'Réceptionner une commande', pa:1, cost:0, type:'legal', icon:'ti-package-import', successRate:100, desc:'Récupérer un objet commandé.'},
          {fn:'contrebande_port', label:'Contrebande portuaire', pa:3, cost:0, type:'illegal', icon:'ti-package-off', successRate:75, desc:'Très facile à El Estado. DIS/10 + DUP/10. +25% modificateur El Estado.'},
          {fn:'acheter_ghb', label:'Acheter du GHB', pa:1, cost:300, type:'illegal', icon:'ti-flask', successRate:80, desc:'Objet poison El Estado. Usage unique. DIS/10. Disponible uniquement ici.'},
          {fn:'blocus_portuaire', label:'Blocus portuaire', pa:3, cost:0, type:'grey', icon:'ti-barrier-block', successRate:65, desc:'Paralyse commerce 24h. VOL/10 + ENT/10.'}
        ]
      }
    }
  },

  'port-al-madina': {
    name: "Port d\'Al-Madina",
    shortName: "Port Al-Madina",
    cat: "Port",
    icon: "ti-anchor",
    bgColor: "#050810",
    desc: "Le port ultramoderne d\'Al-Khalija. Tout reluit. Cheikh Ibn Fret gère les conteneurs royaux en priorité.",
    rooms: {
      quai_al_khalija: {
        name: "Terminal Royal",
        imageBg: "linear-gradient(135deg,#080608,#0f0a10)",
        desc: "Immense, propre, désertique. Les grues dorées s\'activent. Hassan Docker fait passer les conteneurs du Cheikh en premier, comme toujours.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-al-khalija.png",
        persons: [
          {name:'Cheikh Ibn Fret (PNJ)', role:'Directeur du port', rel:'neutral', job:'capitaine_port'},
          {name:'Hassan Docker (PNJ)', role:'Chef docker', rel:'neutral', job:'docker'}
        ],
        orders: [
          {fn:'prendre_bateau', label:'Prendre le bateau', pa:5, cost:100, type:'legal', icon:'ti-ship', successRate:100, desc:'100 FR. 5 PA. Transport inter-empire.'},
          {fn:'expedier_colis', label:'Expédier un colis', pa:2, cost:200, type:'legal', icon:'ti-package-export', successRate:100, desc:'Envoyer un objet à un PJ autre empire.'},
          {fn:'receptionner_commande', label:'Réceptionner une commande', pa:1, cost:0, type:'legal', icon:'ti-package-import', successRate:100, desc:'Récupérer un objet commandé.'},
          {fn:'contrebande_port', label:'Contrebande portuaire', pa:3, cost:0, type:'illegal', icon:'ti-package-off', successRate:60, desc:'Possible mais discret. DIS/10 + DUP/10. +10% Al-Khalija.'},
          {fn:'acheter_vipere', label:'Acheter une Vipère des sables', pa:1, cost:350, type:'grey', icon:'ti-bug', successRate:85, desc:'Objet poison Al-Khalija. Usage unique. Disponible uniquement ici.'},
          {fn:'inspecter_cargaisons', label:'Inspecter les cargaisons', pa:2, cost:0, type:'legal', icon:'ti-search', successRate:80, requiresPost:'min_def', desc:'Révèle contrebandes en cours.'}
        ]
      }
    }
  }
};

// Images de pieces par empire
const ROOM_IMAGES_EMPIRE = {
  republic: {
    'centre-multinodal-luthecia': {
      'hall_gare':        'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-multinodal-republic.png',
      'hall_douanes':     'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-multinodal-republic.png',
      'zone_embarquement':'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-multinodal-republic.png'
    },
    'assemblee': {
      'hemicycle':                'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?w=1200&q=80',
      'couloirs':                 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/couloirs-an-republic.png',
      'salle_archives_assemblee': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/archives-an-republic.png'
    },
    'palais-presidentiel': {
      'accueil_elysee':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/accueil-palais-president-republic.png',
      'bureau_president':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-president.png'
    },
    'palais-gouvernement': {
      'archives_gouv':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/archives-gouv-republic.png',
      'bureau_min_int':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-min-int-republic.png',
      'bureau_min_ae':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-min-ae-republic.png',
      'bureau_min_def':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-min-def-republic.png'
    },
    'mairie-capitale': {
      'hall_mairie':      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mairie-luthecia.png',
      'bureau_maire':     'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-maire-luthecia.png',
      'salle_elections':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-elections-luthecia.png'
    },
    'mairie': {
      'accueil_mairie':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mairie-port-sainte-marie.png'
    },
    'terrain-a-batir-1': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-republic.png' },
    'terrain-a-batir-2': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-republic.png' },
    'terrain-a-batir-3': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-republic.png' },
    'terrain-a-batir-4': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-republic.png' },
    'terrain-a-batir-5': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-republic.png' },
    'terrain-a-batir-6': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-republic.png' },
    'terrain-a-batir-7': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-republic.png' },
    'centre-commercial': {
      'vitrine_principale': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-republic.png',
      'boutique_milieu':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-republic.png',
      'arriere_boutique':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-republic.png',
      'cave_reserve':       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-republic.png'
    },
    'centre-artisanal': {
      'echoppe_facade':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-republic.png',
      'atelier_milieu':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-republic.png',
      'reserve_arriere': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-republic.png'
    },
    'centre-affaires': {
      'bureau_prestige': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-republic.png',
      'bureau_standard': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-republic.png',
      'open_space':      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-republic.png'
    },
  },
  narco: {
    'centre-multinodal-luthecia': {
      'hall_gare':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gare-el-estado.png',
      'aeroport':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-multinodal-el-estado.png'
    },
    'palais-presidentiel': {
      'accueil_elysee':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/accueil-prez-el-estado.png',
      'bureau_president': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-prez-el-estado.png',
      'salle_presse_elysee': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-presse-el-estado.png'
    },
    'palais-gouvernement': {
      'hall':          'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/accueil-prez-el-estado.png',
      'salle_conseil': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/conseil-el-estado.png',
      'salle_presse':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-presse-el-estado.png',
      'archives_gouv': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/archives-el-estado.png',
      'bureau_min_int':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mint-el-estado.png',
      'bureau_min_fin':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/archives-el-estado.png',
      'bureau_min_just': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mjust-el-estado.png',
      'bureau_min_def':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mdef-el-estado.png',
      'bureau_min_info': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/minfo-el-estado.png',
      'bureau_min_ae':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mae-el-estado.png'
    },
    'assemblee': {
      'hemicycle': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/an-salle-el-estado.png',
      'couloirs':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/an-el-estado.png'
    },
    'commissariat': {
      'accueil_police': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-el-estado.png',
      'prison':         'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cellule-el-estado.png'
    },
    'mairie-capitale': {
      'hall_mairie':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mairie-el-estado.png'
    },
    'centre-multinodal-luthecia': {
      'hall_gare':      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-multinodal-el-estado.png',
      'aeroport':       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-multinodal-el-estado.png'
    },
    'terrain-a-batir-1': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-narco.png' },
    'terrain-a-batir-2': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-narco.png' },
    'terrain-a-batir-3': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-narco.png' },
    'terrain-a-batir-4': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-narco.png' },
    'terrain-a-batir-5': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-narco.png' },
    'terrain-a-batir-6': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-narco.png' },
    'terrain-a-batir-7': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-narco.png' },
    'centre-commercial': {
      'vitrine_principale': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-narco.png',
      'boutique_milieu':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-narco.png',
      'arriere_boutique':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-narco.png',
      'cave_reserve':       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-narco.png'
    },
    'centre-artisanal': {
      'echoppe_facade':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-narco.png',
      'atelier_milieu':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-narco.png',
      'reserve_arriere': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-narco.png'
    },
    'centre-affaires': {
      'bureau_prestige': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-narco.png',
      'bureau_standard': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-narco.png',
      'open_space':      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-narco.png'
    },
  },
  soviet: {
    'centre-multinodal-luthecia': {
      'hall_gare':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gare-sovarka.png',
      'aeroport':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-multinodal-sovarka.png'
    },
    'palais-presidentiel': {
      'accueil_elysee':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-parti-sovarka.png',
      'bureau_president':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-gouv-sovarka.png'
    },
    'palais-gouvernement': {
      'hall':              'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-parti-sovarka.png',
      'bureaux':           'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-gouv-sovarka.png',
      'salle_conseil':     'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/conseil-ministres-sovarka.png',
      'bureau_min_fin':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/meco-sovarka.png',
      'bureau_min_def':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mdef-sovarka.png'
    },
    'tribunal': {
      'salle_audience': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tribunal-sovarka.png',
      'greffe':         'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tribunal-sovarka.png'
    },
    'mairie-capitale': {
      'hall_mairie':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mairie-sovarka.png',
      'bureau_maire':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mairie-sovarka.png',
      'salle_elections':'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mairie-sovarka.png'
    },
    'terrain-a-batir-1': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-soviet.png' },
    'terrain-a-batir-2': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-soviet.png' },
    'terrain-a-batir-3': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-soviet.png' },
    'terrain-a-batir-4': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-soviet.png' },
    'terrain-a-batir-5': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-soviet.png' },
    'terrain-a-batir-6': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-soviet.png' },
    'terrain-a-batir-7': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-soviet.png' },
    'centre-commercial': {
      'vitrine_principale': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-soviet.png',
      'boutique_milieu':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-soviet.png',
      'arriere_boutique':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-soviet.png',
      'cave_reserve':       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-soviet.png'
    },
    'centre-artisanal': {
      'echoppe_facade':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-soviet.png',
      'atelier_milieu':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-soviet.png',
      'reserve_arriere': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-soviet.png'
    },
    'centre-affaires': {
      'bureau_prestige': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-soviet.png',
      'bureau_standard': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-soviet.png',
      'open_space':      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-soviet.png'
    },
  },
  khalija: {
    'centre-multinodal-luthecia': {
      'hall_gare': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gare-al-khalija.png',
      'aeroport':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gare-al-khalija.png'
    },
    'assemblee': {
      'hemicycle':              'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/assemblee-khalija.png',
      'couloirs':               'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/couloirs-conseil-khalija.png',
      'salle_archives_assemblee': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/archives-an-republic.png'
    },
    'tribunal': {
      'salle_audience': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tribunal-khalija.png',
      'greffe':         'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tribunal-khalija.png'
    },
    'palais-presidentiel': {
      'accueil_elysee':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-hotel-khalija.png',
      'bureau_president':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-roi-khalija.png'
    },
    'hotel-republica': {
      'hall_hotel':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-hotel-khalija.png',
      'chambre':       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/chambre-hotel-khalija.png',
      'restaurant':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-hotel-khalija.png'
    },
    'marche': {
      'marche_ext': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/souk-al-khalija.png'
    },
    'mairie-capitale': {
      'hall_mairie':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mairie-al-khalija.png',
      'bureau_maire':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mairie-al-khalija.png',
      'salle_elections':'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/mairie-al-khalija.png'
    },
    'terrain-a-batir-1': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-khalija.png' },
    'terrain-a-batir-2': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-khalija.png' },
    'terrain-a-batir-3': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-khalija.png' },
    'terrain-a-batir-4': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-khalija.png' },
    'terrain-a-batir-5': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-khalija.png' },
    'terrain-a-batir-6': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-khalija.png' },
    'terrain-a-batir-7': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-khalija.png' },
    'centre-commercial': {
      'vitrine_principale': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-khalija.png',
      'boutique_milieu':    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-khalija.png',
      'arriere_boutique':   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-khalija.png',
      'cave_reserve':       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-commercial-khalija.png'
    },
    'centre-artisanal': {
      'echoppe_facade':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-khalija.png',
      'atelier_milieu':  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-khalija.png',
      'reserve_arriere': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-artisanal-khalija.png'
    },
    'centre-affaires': {
      'bureau_prestige': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-khalija.png',
      'bureau_standard': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-khalija.png',
      'open_space':      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-affaires-khalija.png'
    },
  }
};


// =====================
// PNJ ALÉATOIRES SUR LES TERRAINS À BÂTIR
// =====================
const TERRAIN_PNJ_PROFILES = {
  republic: [
    { id:'promoteur',   name:'Gérard Spéculos',      role:'Promoteur immobilier',   job:'commercant',  rel:'neutral', prob:0.20, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/promoteur-republic.png', photoPos: '45% 18%',
      trait:'Costume brillant, dents plus brillantes encore. Propose toujours 20% sous le prix du marché en souriant.' },
    { id:'agent',       name:'Nathalie Parpaing',     role:'Agent immobilière',      job:'commercant',  rel:'neutral', prob:0.15, agressif:false,
      trait:'Porte des talons hauts sur un chantier. A vendu le même terrain trois fois cette année.' },
    { id:'squatter_cool',name:'Les Gars du Bas',      role:'Squatteurs sympas',      job:'citoyen',     rel:'ally',    prob:0.18, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/squatteur-cool-republic.png', photoPos: '40% 25%',
      trait:'Ont installé un barbecue, un canapé et une télé sur le terrain. Très accueillants.' },
    { id:'squatter_agr', name:'La Bande à Rotule',    role:'Squatteurs menaçants',   job:'citoyen',     rel:'enemy',   prob:0.12, agressif:true,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/squatteur-agressif-republic.png', photoPos: '45% 20%',
      trait:'Regardent fixement. Le plus grand tient un tuyau. Pas le genre à parlementer.' },
    { id:'inspecteur',  name:'Maurice Formulaire',    role:'Inspecteur municipal',   job:'inspecteur',  rel:'neutral', prob:0.15, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/inspecteur-republic.png', photoPos: '50% 20%',
      trait:'Venu vérifier 47 points de conformité. En a trouvé 43 manquants. Souriant mais intransigeant.' },
    { id:'gardien',     name:'Robert Cadenas',        role:'Gardien de chantier',    job:'gardien',     rel:'neutral', prob:0.10, agressif:false,
      trait:'Dort debout. Peut être soudoyé pour 150 FR. Après il dort ailleurs.' },
    { id:'inspecteur_police', name:'L\'Inspecteur Lardasse', role:'Inspecteur de police',   job:'commissaire', rel:'neutral', prob:0, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/inspecteur-police-republic.png', photoPos: '50% 15%',
      trait:'Arrive quand on l\'appelle. Cigare aux lèvres. Peut accélérer l\'expulsion contre un petit arrangement.' },
    { id:'cadavre',     name:'Individu non identifié',role:'Cadavre mystérieux',     job:'default',     rel:'neutral', prob:0.04, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadavre-republic.png', photoPos: '50% 40%',
      trait:'Personne ne sait qui c\'est ni comment il est arrivé là. Les formalités vont prendre du temps.' },
    { id:'vide',        name:null,                    role:null,                     job:null,          rel:'neutral', prob:0.06, agressif:false, trait:null },
  ],
  narco: [
    { id:'promoteur',   name:'Don Ladrillo',          role:'Promoteur (blanchiment)', job:'commercant', rel:'neutral', prob:0.22, agressif:false, photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/promoteur-narco.png', photoPos:'50% 10%',
      trait:'Propose cash. Beaucoup de cash. Ne pose pas de questions. Déconseille d\'en poser.' },
    { id:'agent',       name:'Consuelo Escritura',    role:'Agente immobilière',     job:'commercant',  rel:'neutral', prob:0.10, agressif:false,
      trait:'Ses contrats ont des clauses en petits caractères très petits. Très, très petits.' },
    { id:'squatter_cool',name:'Los Relajados',        role:'Squatteurs détendus',    job:'citoyen',     rel:'ally',    prob:0.14, agressif:false,
      trait:'Font des grillades permanentes. Offrent une bière et une côtelette. Savent des choses.' },
    { id:'squatter_agr', name:'Los Violentos',        role:'Squatteurs armés',       job:'citoyen',     rel:'enemy',   prob:0.22, agressif:true,
      trait:'Armés. Territorieux. El Don lui-même les évite. Jet CHA difficile.' },
    { id:'inspecteur',  name:'Oficial Mordida',       role:'Inspecteur corruptible', job:'inspecteur',  rel:'neutral', prob:0.08, agressif:false, photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/inspecteur-narco.png', photoPos:'50% 10%',
      trait:'Venu vérifier. Repart avec une enveloppe. Tout est conforme.' },
    { id:'gardien',     name:'Paco Vigilancia',       role:'Gardien armé',           job:'gardien',     rel:'neutral', prob:0.12, agressif:false,
      trait:'Armé. Sérieux. Travaille pour quelqu\'un. On ne sait pas trop qui.' },
    { id:'cadavre',     name:'Deux Inconnus',          role:'Cadavres (banal ici)',   job:'default',     rel:'neutral', prob:0.08, photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadavre-narco.png', photoPos:'50% 40%', agressif:false,
      trait:'Troisième cette semaine sur ce terrain. La police est blasée. Les formalités aussi.' },
    { id:'vide',        name:null,                    role:null,                     job:null,          rel:'neutral', prob:0.04, agressif:false, trait:null },
  ],
  soviet: [
    { id:'promoteur',   name:'Camarade Bâtissov',     role:'Directeur de construction', job:'commercant', rel:'neutral', prob:0.08, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/promoteur-soviet.png', photoPos: '50% 18%',
      trait:'Construit pour le Parti. Uniquement pour le Parti. Vous pouvez toujours demander.' },
    { id:'agent',       name:'Nadejda Attribution',   role:'Agente d\'attribution',  job:'commercant',  rel:'neutral', prob:0.05, agressif:false,
      trait:'Le terrain est déjà attribué. Par le Parti. Formulaire B-12 en quadruple.' },
    { id:'squatter_cool',name:'Famille Kolkhozov',    role:'Occupants collectifs',   job:'citoyen',     rel:'ally',    prob:0.08, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/squatteur-cool-soviet.png', photoPos: '45% 22%',
      trait:'Ont obtenu une autorisation provisoire du soviet local. En triple exemplaire.' },
    { id:'squatter_agr', name:'Miliciens Zélés',      role:'Miliciens territoriaux', job:'commissaire', rel:'enemy',   prob:0.05, agressif:true,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/squatteur-agressif-soviet.png', photoPos: '45% 18%',
      trait:'Défendent le terrain au nom du Parti. Toute présence non autorisée est contre-révolutionnaire.' },
    { id:'inspecteur',  name:'Camarade Conformité',   role:'Inspecteur du Parti',    job:'inspecteur',  rel:'neutral', prob:0.35, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/inspecteur-soviet.png', photoPos: '50% 20%',
      trait:'Vérifie 127 points de conformité idéologique. Systématique. Inévitable.' },
    { id:'gardien',     name:'Sentinelle du Peuple',  role:'Gardien collectif',      job:'gardien',     rel:'neutral', prob:0.25, agressif:false,
      trait:'Surveille au nom du Parti. Incorruptible. Ou presque, avec beaucoup de roubles.' },
    { id:'inspecteur_police', name:'Milicien Grisov',      role:'Milice du Parti',        job:'commissaire', rel:'neutral', prob:0, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/inspecteur-police-soviet.png', photoPos: '50% 15%',
      trait:'Arrive quand on l\'appelle. Regarde le cadavre. Note quelque chose. Repart. Peut accélérer pour des roubles.' },
    { id:'cadavre',     name:'Camarade Inconnu',      role:'Incident classifié',     job:'default',     rel:'neutral', prob:0.02, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadavre-soviet.png', photoPos: '50% 40%',
      trait:'Le Parti nie. Les formulaires d\'enquête existent en 8 exemplaires. Délai : indéterminé.' },
    { id:'vide',        name:null,                    role:null,                     job:null,          rel:'neutral', prob:0.12, agressif:false, trait:null },
  ],
  khalija: [
    { id:'promoteur',   name:'Cheikh Al-Bâtisseur',  role:'Promoteur royal',        job:'commercant',  rel:'neutral', prob:0.25, agressif:false,
      trait:'Représente un membre de la famille royale. Offre généreuse mais conditions opaques.' },
    { id:'agent',       name:'Yasmine Al-Vente',      role:'Agente immobilière',     job:'commercant',  rel:'neutral', prob:0.20, agressif:false,
      trait:'Élégante, efficace, commission à 15%. Connaît tous les membres influents de la cour.' },
    { id:'squatter_cool',name:'Famille Al-Bédouin',  role:'Bédouins de passage',    job:'citoyen',     rel:'ally',    prob:0.06, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bedouin-khalija.png', photoPos: '45% 25%',
      trait:'Campent ici depuis des générations. Très hospitaliers. Offrent du thé et des dattes. Bougent si on leur demande poliment.' },
    { id:'squatter_agr', name:'Clan Al-Résistant',   role:'Bédouins territoriaux',  job:'citoyen',     rel:'enemy',   prob:0.03, agressif:true,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bedouin-agressif-khalija.png', photoPos: '45% 20%',
      trait:'Ce terrain appartient à leur clan depuis 400 ans. Ils ont des arguments historiques et des épées.' },
    { id:'inspecteur',  name:'Chambellan Al-Permis',  role:'Inspecteur royal',       job:'inspecteur',  rel:'neutral', prob:0.18, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/inspecteur-khalija.png', photoPos: '50% 15%',
      trait:'Vérifie la conformité avec le plan d\'urbanisme royal. Très courtois. Très exigeant.' },
    { id:'gardien',     name:'Garde Al-Terrain',      role:'Garde royal',            job:'gardien',     rel:'neutral', prob:0.20, agressif:false,
      trait:'Posté par le Palais. Peut être contourné avec le bon protocole — ou le bon billet.' },
    { id:'cadavre',     name:'Inconnu',               role:'Affaire discrète',       job:'default',     rel:'neutral', prob:0.01, agressif:false,
      photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadavre-khalija.png', photoPos: '50% 35%',
      trait:'Le Palais préfère que ça reste discret. Les formalités seront expéditives — dans un sens ou dans l\'autre.' },
    { id:'vide',        name:null,                    role:null,                     job:null,          rel:'neutral', prob:0.07, agressif:false, trait:null },
  ]
};


// =====================
// SYSTÈME ÉLECTORAL
// =====================

// Postes électifs par empire et ville

// =====================
// ORGANISATIONS — DÉFINITIONS COMPLÈTES
// =====================

const ORGANISATIONS_DEF = {
  criminelle: {
    label: 'Organisation Criminelle',
    labelCourt: 'Crime',
    secret: true,
    icon: 'ti-skull',
    color: '#8a3a2a',
    requis: { dis: 60 },
    maxParEmpire: null,
    grades: {
      republic: ['Affilié', 'Soldat', 'Capo', 'Parrain'],
      narco:    ['Sicario', 'Teniente', 'Comandante', 'El Jefe'],
      soviet:   ['Homme de main', 'Brigadier', 'Vor', 'Pakhan'],
      khalija:  ['Sbire', 'Lieutenant de l\'ombre', 'Émir Noir', 'Sultan des Ombres'],
    },
    bonus: [
      { grade: 0, stat: 'dis',    valeur: 5,  desc: '+5 DIS passive' },
      { grade: 1, stat: 'dis',    valeur: 10, desc: '+10 DIS passive' },
      { grade: 2, stat: 'dis',    valeur: 15, desc: '+15 DIS passive' },
      { grade: 3, stat: 'dis',    valeur: 20, desc: '+20 DIS passive' },
      { grade: 1, stat: 'corruption_bonus', valeur: 15, desc: '+15% réussite corruption' },
      { grade: 2, stat: 'corruption_bonus', valeur: 25, desc: '+25% réussite corruption' },
      { grade: 3, stat: 'corruption_bonus', valeur: 35, desc: '+35% réussite corruption' },
      { grade: 2, stat: 'info_cost',        valeur: -30, desc: '-30% coût informateurs' },
      { grade: 3, stat: 'arrest_resist',    valeur: 30, desc: '+30% résistance arrestation' },
      { grade: 3, stat: 'tracking',         valeur: true, desc: 'Suivi des mouvements PJ' },
    ]
  },
  religieuse: {
    label: 'Organisation Religieuse',
    labelCourt: 'Religion',
    secret: false,
    icon: 'ti-star',
    color: '#C9A84C',
    requis: { inf: 20, pop: 15 },
    maxParEmpire: null,
    grades: {
      republic: ['Novice', 'Diacre', 'Prêtre', 'Grand Pontife'],
      narco:    ['Croyant', 'Révérend', 'Archevêque', 'El Profeta'],
      soviet:   ['Initié du Kolkhoze', 'Lecteur', 'Prophète', 'Grand Oracle'],
      khalija:  ['Étudiant', 'Imam', 'Grand Mufti', 'Ayatollah Suprême'],
    },
    bonus: [
      { grade: 0, stat: 'pop',          valeur: 5,   desc: '+5 POP passive' },
      { grade: 1, stat: 'pop',          valeur: 10,  desc: '+10 POP passive' },
      { grade: 2, stat: 'pop',          valeur: 15,  desc: '+15 POP passive' },
      { grade: 3, stat: 'pop',          valeur: 20,  desc: '+20 POP passive' },
      { grade: 0, stat: 'moral_drain',  valeur: -50, desc: 'Perte de Moral réduite de 50%' },
      { grade: 1, stat: 'forum_inf',    valeur: 2,   desc: '+2 INF par post forum' },
      { grade: 2, stat: 'forum_inf',    valeur: 4,   desc: '+4 INF par post forum' },
      { grade: 2, stat: 'soin_gratuit', valeur: true,desc: 'Soins gratuits au dispensaire' },
      { grade: 3, stat: 'benedir',      valeur: 10,  desc: 'Bénédiction candidat : +10 POP' },
      { grade: 3, stat: 'forum_inf',    valeur: 6,   desc: '+6 INF par post forum' },
    ]
  },
  economique: {
    label: 'Organisation Économique',
    labelCourt: 'Économie',
    secret: false,
    icon: 'ti-building-bank',
    color: '#4a8a4a',
    requis: { inf: 15, arg: 10000 },
    maxParEmpire: null,
    grades: {
      republic: ['Actionnaire', 'Directeur', 'PDG', 'Président du Conseil'],
      narco:    ['Investisseur', 'Gérant', 'Patron', 'El Patrón Económico'],
      soviet:   ['Coopérateur', 'Dir. de Plan', 'Commissaire Éco.', 'Min. de l\'Abondance'],
      khalija:  ['Associé', 'Directeur', 'Cheikh des Affaires', 'Sultan Économique'],
    },
    bonus: [
      { grade: 0, stat: 'revenus_passifs', valeur: 100,  desc: '+100 FR/jour passif' },
      { grade: 1, stat: 'revenus_passifs', valeur: 300,  desc: '+300 FR/jour passif' },
      { grade: 2, stat: 'revenus_passifs', valeur: 700,  desc: '+700 FR/jour passif' },
      { grade: 3, stat: 'revenus_passifs', valeur: 1500, desc: '+1500 FR/jour passif' },
      { grade: 1, stat: 'terrain_discount',valeur: 15,   desc: '-15% prix terrains et permis' },
      { grade: 2, stat: 'terrain_discount',valeur: 25,   desc: '-25% prix terrains et permis' },
      { grade: 1, stat: 'nego_cha',        valeur: 10,   desc: '+10% jets de négociation' },
      { grade: 2, stat: 'nego_cha',        valeur: 20,   desc: '+20% jets de négociation' },
      { grade: 3, stat: 'nego_cha',        valeur: 30,   desc: '+30% jets de négociation' },
      { grade: 2, stat: 'market_info',     valeur: true, desc: 'Prix terrains en temps réel' },
      { grade: 3, stat: 'finance_campagne',valeur: true, desc: 'Financement campagne électorale' },
    ]
  },
  syndicale: {
    label: 'Organisation Syndicale',
    labelCourt: 'Syndicat',
    secret: false,
    icon: 'ti-users-group',
    color: '#4a6aaa',
    requis: { inf: 10, pop: 20 },
    maxParEmpire: null,
    grades: {
      republic: ['Adhérent', 'Secrétaire Général Adjoint', 'Secrétaire Général', 'Confédéral'],
      narco:    ['Miembro', 'Secretario Adjunto', 'Secretario', 'El Capo Sindical'],
      soviet:   ['Travailleur Uni', 'Commissaire Adjoint', 'Commissaire Syndical', 'Grand Camarade'],
      khalija:  ['Membre', 'Directeur Adjoint', 'Directeur Syndical', 'Grand Cheikh Ouvrier'],
    },
    bonus: [
      { grade: 0, stat: 'pop_pnj',      valeur: 5,   desc: '+5 POP auprès des PNJ travailleurs' },
      { grade: 1, stat: 'pop_pnj',      valeur: 10,  desc: '+10 POP auprès des PNJ travailleurs' },
      { grade: 2, stat: 'pop_pnj',      valeur: 15,  desc: '+15 POP auprès des PNJ travailleurs' },
      { grade: 3, stat: 'pop_pnj',      valeur: 20,  desc: '+20 POP auprès des PNJ travailleurs' },
      { grade: 1, stat: 'nego_cha',     valeur: 15,  desc: '+15% jets négociation squatteurs/travailleurs' },
      { grade: 2, stat: 'nego_cha',     valeur: 25,  desc: '+25% jets négociation' },
      { grade: 2, stat: 'greve',        valeur: true,desc: 'Peut déclencher une grève (-IE empire)' },
      { grade: 2, stat: 'postes_info',  valeur: true,desc: 'Réseau : postes disponibles visibles' },
      { grade: 3, stat: 'motion',       valeur: true,desc: 'Motion de mécontentement auto sur forum' },
      { grade: 3, stat: 'vote_bonus',   valeur: 5,   desc: '+5 votes PNJ automatiques aux élections' },
    ]
  },
  loge: {
    label: 'Loge Maçonnique',
    labelCourt: 'Loge',
    secret: false,
    icon: 'ti-hexagon',
    color: '#8a6aaa',
    requis: { inf: 25 },
    maxParEmpire: 1,
    cycleElection: 30,
    grades: {
      republic: ['Apprenti', 'Compagnon', 'Maître', 'Grand Maître'],
      narco:    ['Iniciado', 'Hermano', 'Maestro', 'Gran Maestro'],
      soviet:   ['Apprenti Collectif', 'Frère du Plan', 'Maître Soviétique', 'Grand Architecte'],
      khalija:  ['Murid', 'Ikhwan', 'Sheikh', 'Grand Sheikh'],
    },
    bonus: [
      { grade: 0, stat: 'admin_delay',  valeur: -20, desc: '-20% délais administratifs' },
      { grade: 1, stat: 'admin_delay',  valeur: -35, desc: '-35% délais administratifs' },
      { grade: 2, stat: 'admin_delay',  valeur: -50, desc: '-50% délais administratifs' },
      { grade: 3, stat: 'admin_delay',  valeur: -70, desc: '-70% délais administratifs' },
      { grade: 1, stat: 'inf',          valeur: 5,   desc: '+5 INF passive' },
      { grade: 2, stat: 'inf',          valeur: 10,  desc: '+10 INF passive' },
      { grade: 3, stat: 'inf',          valeur: 15,  desc: '+15 INF passive' },
      { grade: 2, stat: 'dis',          valeur: 10,  desc: '+10 DIS passive' },
      { grade: 2, stat: 'pol_info',     valeur: true,desc: 'Infos politiques exclusives' },
      { grade: 3, stat: 'cooptation',   valeur: true,desc: 'Cooptation : accès poste sans élection' },
      { grade: 3, stat: 'vote_bonus',   valeur: 3,   desc: '+3 votes PNJ coalitions électorales' },
    ]
  }
};

// =====================
// SYNERGIES D'ORGANISATIONS
// =====================
const SYNERGIES_ORGA = [
  {
    combo: ['criminelle', 'economique'],
    label: 'Blanchiment',
    desc: 'Crime + Économie : revenus passifs doublés, -50% risque détection transactions louches',
    bonus: { revenus_passifs_mult: 2, detection_risk: -50 }
  },
  {
    combo: ['criminelle', 'loge'],
    label: 'Réseau de l\'Ombre',
    desc: 'Crime + Loge : +15 DIS supplémentaire, accès aux informations politiques secrètes',
    bonus: { dis: 15, pol_info_secret: true }
  },
  {
    combo: ['economique', 'loge'],
    label: 'Capitalisme Discret',
    desc: 'Économie + Loge : délais administratifs réduits à zéro pour les terrains, +500 FR/jour',
    bonus: { terrain_delay: 0, revenus_passifs: 500 }
  },
  {
    combo: ['religieuse', 'syndicale'],
    label: 'Front Populaire',
    desc: 'Religion + Syndicat : +15 POP supplémentaire, prospectus comptent double aux élections',
    bonus: { pop: 15, prospectus_mult: 2 }
  },
  {
    combo: ['religieuse', 'loge'],
    label: 'Ordre Mystique',
    desc: 'Religion + Loge : moral jamais en dessous de 50, +10 INF permanente',
    bonus: { moral_floor: 50, inf: 10 }
  },
  {
    combo: ['syndicale', 'economique'],
    label: 'Partenariat Social',
    desc: 'Syndicat + Économie : grèves impossibles contre vos entreprises, +10 POP travailleurs',
    bonus: { greve_immune: true, pop_pnj: 10 }
  },
  {
    combo: ['criminelle', 'syndicale'],
    label: 'Syndicat Mafieux',
    desc: 'Crime + Syndicat : intimidation des PNJ sans jet, squatteurs partent toujours au 1er tour',
    bonus: { intimidation_auto: true, squatter_exit: true }
  },
  {
    combo: ['criminelle', 'religieuse'],
    label: 'Mafia Pieuse',
    desc: 'Crime + Religion : corruption acceptée sans jet si PNJ est croyant, +10 POP malgré activités illicites',
    bonus: { corruption_croyant: true, pop: 10 }
  },
  {
    combo: ['economique', 'syndicale'],
    label: 'Oligarque Bienveillant',
    desc: 'Économie + Syndicat : -20% coût terrains supplémentaire, votes PNJ travailleurs automatiques',
    bonus: { terrain_discount: 20, vote_travailleur_auto: true }
  },
  {
    combo: ['criminelle', 'economique', 'loge'],
    label: 'Maître du Monde',
    desc: 'Crime + Économie + Loge : triple synergie — +30 DIS, revenus x3, cooptation garantie',
    bonus: { dis: 30, revenus_passifs_mult: 3, cooptation_garanti: true },
    triple: true
  },
  {
    combo: ['religieuse', 'syndicale', 'loge'],
    label: 'Mouvement Populaire',
    desc: 'Religion + Syndicat + Loge : triple synergie — +30 POP, victoire électorale facilitée, motion auto',
    bonus: { pop: 30, election_bonus: 10, motion_auto: true },
    triple: true
  },
];

// Documents falsifiables au greffe du Tribunal (voir ouvrirFalsifierDocument)
const DOCUMENTS_FALSIFIABLES = [
  { id:'fausse_identite',   name:'Fausse identite',          desc:'Change votre nom affiche dans le jeu temporairement.',     icon:'ti-id-badge' },
  { id:'faux_casier',       name:'Faux casier judiciaire vierge', desc:'Efface vos antecedents judiciaires dans les archives.', icon:'ti-file-x' },
  { id:'faux_permis',       name:'Faux permis de construire', desc:'Permet de construire sans passer par la mairie.',          icon:'ti-building' },
  { id:'faux_contrat',      name:'Faux contrat commercial',   desc:'Legitime une transaction illegale ou un transfert.',       icon:'ti-file-text' },
  { id:'fausse_convocation',name:'Fausse convocation officielle', desc:'Attire un PJ dans un lieu de votre choix.',           icon:'ti-mail' }
];

const POSTES_ELECTIFS = {
  national: [
    { id: 'president',      name: 'Président',           niveau: 'national', mandatSemaines: 5, deputesRequis: 0,  minInf: 10 },
    { id: 'chef_syndicat',  name: 'Chef Syndical',        niveau: 'national', mandatSemaines: 5, deputesRequis: 0,  minInf: 5  },
  ],
  departemental: [
    { id: 'depute',         name: 'Député',               niveau: 'ville',    mandatSemaines: 5, deputesRequis: 0,  minInf: 5,  nbParVille: 3 },
  ],
  local: [
    { id: 'maire',          name: 'Maire',                niveau: 'ville',    mandatSemaines: 5, deputesRequis: 0,  minInf: 3  },
  ]
};

// Cycle électoral — état global par empire
// Structure : CYCLES_ELECTORAUX[country][posteId] = { phase, dateDebut, dateFin, candidats, votes, tour }
const CYCLES_ELECTORAUX = {};

// Phases du cycle
const PHASES_ELECTORALES = {
  MANDAT:        'mandat',        // Poste occupé, mandat en cours
  CANDIDATURES:  'candidatures',  // Ouverture des candidatures (J-7 avant campagne)
  CAMPAGNE:      'campagne',      // Campagne électorale (1 semaine)
  VOTE:          'vote',          // Jour du vote (dimanche 20h-24h)
  SECOND_TOUR:   'second_tour',   // Campagne second tour (1 semaine)
  VOTE2:         'vote2',         // Second tour
  VACANT:        'vacant',        // Poste vacant — PNJ administrateur nommé
};

// Résultats électoraux archivés
const HISTORIQUE_ELECTIONS = {};

// =====================
// DOMICILIATION
// =====================
// Stockée dans state.domicile = { country, city, depuis (jour) }
// Modifiable à la mairie

// =====================
// ORGANISATIONS
// =====================
const TYPES_ORGANISATIONS = {

  // ---- POLITIQUE ----
  politique: {
    label: 'Organisation Politique',
    icon: 'ti-flag',
    secret: false,
    requis: { pop: 20, inf: 15 },
    grades: {
      republic: ['Sympathisant', 'Militant', 'Cadre', 'Secrétaire Général'],
      narco:    ['Seguidor', 'Activista', 'Líder Local', 'Jefe Supremo'],
      soviet:   ['Camarade', 'Activiste', 'Commissaire', 'Secrétaire du Parti'],
      khalija:  ['Partisan', 'Conseiller', 'Vizir', 'Grand Vizir'],
    },
    maxParCreation: 1,
    maxAdhesion: 1,
    ordres: [
      { fn: 'orga_petition',      label: 'Lancer une pétition',        pa: 2, cost: 0,    icon: 'ti-pencil',       desc: 'Mobilise des soutiens. +POP si succes.' },
      { fn: 'orga_financer_cand', label: 'Financer un candidat',       pa: 2, cost: 5000, icon: 'ti-coin',         desc: 'Finance la campagne d\'un PJ allie. +votes.' },
      { fn: 'orga_torpiller',     label: 'Torpiller un adversaire',     pa: 3, cost: 1000, icon: 'ti-bomb',         desc: 'Campagne de denigrement. -POP cible.' },
      { fn: 'orga_meeting',       label: 'Organiser un meeting',        pa: 3, cost: 500,  icon: 'ti-speakerphone', desc: 'Rassemblement public. +POP membres +INF.' },
      { fn: 'orga_coalition',     label: 'Proposer une coalition',      pa: 1, cost: 0,    icon: 'ti-handshake',    desc: 'Alliance avec une autre orga politique.' },
      { fn: 'demander_autorisation_manifester', label: 'Demander une autorisation de manifester', pa: 1, cost: 0, icon: 'ti-walk', desc: 'Reserve au chef. Depot 24h avant minimum, validee automatiquement 12h avant si le Ministre de l\'Interieur ne l\'a pas interdite.' },
    ]
  },

  // ---- RELIGIEUSE ----
  religieuse: {
    label: 'Organisation Religieuse',
    icon: 'ti-star',
    secret: false,
    requis: { inf: 20, pop: 15 },
    grades: {
      republic: ['Novice', 'Diacre', 'Pretre', 'Grand Pontife'],
      narco:    ['Croyant', 'Reverend', 'Archeveque', 'El Profeta'],
      soviet:   ['Camarade Croyant', 'Lecteur du Parti', 'Prophete du Kolkhoze', 'Grand Oracle'],
      khalija:  ['Etudiant', 'Imam', 'Grand Mufti', 'Ayatollah Supreme'],
    },
    maxParCreation: 1,
    maxAdhesion: 1,
    ordres: [
      { fn: 'orga_benediction',   label: 'Ceremonie de benediction',   pa: 2, cost: 200,  icon: 'ti-sun',          desc: 'Benit un PJ membre ou non. +Moral +POP cible.' },
      { fn: 'orga_anatheme',      label: 'Ceremonie d\'anatheme',      pa: 2, cost: 200,  icon: 'ti-moon-off',     desc: 'Maudit un PJ. -Moral -POP cible. Risque retour de flamme.' },
      { fn: 'orga_collecte',      label: 'Collecte de dons',           pa: 2, cost: 0,    icon: 'ti-heart-handshake', desc: 'Collecte aupres des fideles. +arg orga.' },
      { fn: 'orga_pelerinage',    label: 'Organiser un pelerinage',    pa: 3, cost: 1000, icon: 'ti-road',         desc: 'Grand rassemblement. +POP tous membres +IP.' },
      { fn: 'orga_excommunier',   label: 'Excommunier un membre',      pa: 1, cost: 0,    icon: 'ti-user-x',       desc: 'Exclure un membre. -Moral exclu. Reserve au chef.' },
      { fn: 'demander_autorisation_manifester', label: 'Demander une autorisation de manifester', pa: 1, cost: 0, icon: 'ti-walk', desc: 'Reserve au chef. Depot 24h avant minimum, validee automatiquement 12h avant si le Ministre de l\'Interieur ne l\'a pas interdite.' },
    ]
  },

  syndicale: {
    label: 'Organisation Syndicale',
    icon: 'ti-users',
    secret: false,
    requis: { inf: 15, pop: 10 },
    grades: {
      republic: ['Adherent', 'Delegue', 'Secretaire Adjoint', 'Secretaire General'],
      narco:    ['Adherent', 'Delegue', 'Secretaire Adjoint', 'Secretaire General'],
      soviet:   ['Camarade', 'Delegue Ouvrier', 'Commissaire Syndical', 'Secretaire General'],
      khalija:  ['Adherent', 'Delegue', 'Secretaire Adjoint', 'Secretaire General'],
    },
    maxParCreation: 1,
    maxAdhesion: 1,
    ordres: [
      { fn: 'demander_autorisation_manifester', label: 'Demander une autorisation de manifester', pa: 1, cost: 0, icon: 'ti-walk', desc: 'Reserve au chef. Depot 24h avant minimum, validee automatiquement 12h avant si le Ministre de l\'Interieur ne l\'a pas interdite.' },
      { fn: 'greve_lancer', label: 'Lancer une grève', pa: 1, cost: 0, icon: 'ti-flag-3', chefOnly: true,
        desc: 'Réservé au chef. Nécessite au moins ' + GREVE_MEMBRES_MIN + ' membres. Revendications libres, cible au choix (PJ, gouvernement, entreprise, organisation, pays). Reste active jusqu\'à ce que vous y mettiez fin.',
        visibleSi: (orga) => !orga.greve?.actif },
      { fn: 'greve_terminer', label: 'Mettre fin à la grève', pa: 0, cost: 0, icon: 'ti-flag-off', chefOnly: true,
        desc: 'Arrêt immédiat de la grève en cours. Réservé au chef. Aucun vote, aucune fin automatique.',
        visibleSi: (orga) => !!orga.greve?.actif },
      { fn: 'greve_generale_appeler', label: 'Appeler à une grève générale', pa: 1, cost: 0, icon: 'ti-users-group', chefOnly: true,
        desc: 'Réservé au chef. N\'engage aucune grève immédiatement : ouvre une consultation intersyndicale nationale (mail à chaque chef de syndicat éligible + sujet public sur le Forum National).',
        visibleSi: (orga) => !orga.greveGeneraleEnCoursId },
      { fn: 'greve_generale_retirer', label: 'Retirer le syndicat de la grève générale', pa: 0, cost: 0, icon: 'ti-door-exit', chefOnly: true,
        desc: 'Retrait immédiat et définitif de la grève générale en cours. Réservé au chef. Vos adhérents cessent de compter dans sa puissance.',
        visibleSi: (orga) => orga.greveGeneraleEnCoursId && orga.greveGeneraleStatut === 'actif' },
    ]
  },

  // ---- ECONOMIQUE ----
  economique: {
    label: 'Organisation Economique',
    icon: 'ti-briefcase',
    secret: false,
    requis: { inf: 15, arg: 10000 },
    grades: {
      republic: ['Actionnaire', 'Directeur', 'PDG', 'President du Conseil'],
      narco:    ['Investisseur', 'Gerant', 'Patron', 'El Patron Economico'],
      soviet:   ['Cooperateur', 'Directeur de Plan', 'Commissaire Economique', 'Ministre de l\'Abondance'],
      khalija:  ['Associe', 'Directeur', 'Cheikh des Affaires', 'Sultan Economique'],
    },
    maxParCreation: 1,
    maxAdhesion: 1,
    ordres: [
      { fn: 'orga_contrat',       label: 'Contrat exclusif',           pa: 2, cost: 2000, icon: 'ti-file-invoice', desc: 'Monopole temporaire sur un secteur. +arg passif membres.' },
      { fn: 'orga_blocus',        label: 'Blocus commercial',          pa: 3, cost: 1000, icon: 'ti-lock',         desc: 'Bloquer les revenus d\'une orga adverse.' },
      { fn: 'orga_dividendes',    label: 'Verser des dividendes',      pa: 1, cost: 0,    icon: 'ti-coins',        desc: 'Distribuer les benefices aux membres selon rang.' },
      { fn: 'orga_fusion',        label: 'Proposer une fusion',        pa: 2, cost: 5000, icon: 'ti-git-merge',    desc: 'Absorber une orga economique alliee.' },
      { fn: 'orga_audit',         label: 'Auditer un concurrent',      pa: 2, cost: 500,  icon: 'ti-search',       desc: 'Revele les finances d\'une orga. +INF.' },
    ]
  },

  // ---- CRIMINELLE ----
  criminelle: {
    label: 'Organisation Criminelle',
    icon: 'ti-skull',
    secret: true,
    requis: { dis: 60 },
    grades: {
      republic: ['Affilie', 'Soldat', 'Capo', 'Parrain'],
      narco:    ['Sicario', 'Teniente', 'Comandante', 'El Jefe'],
      soviet:   ['Homme de main', 'Brigadier', 'Vor', 'Pakhan'],
      khalija:  ['Sbire', 'Lieutenant', 'Emir de l\'ombre', 'Calife de l\'obscurite'],
    },
    maxParCreation: 1,
    maxAdhesion: 1,
    ordres: [
      { fn: 'orga_racket',        label: 'Racket',                     pa: 2, cost: 0,    icon: 'ti-hand-stop',    desc: 'Extorquer un commerce ou PJ. +arg, risque arrestation.' },
      { fn: 'orga_contrebande',   label: 'Contrebande',                pa: 3, cost: 500,  icon: 'ti-package-import', desc: 'Faire passer une cargaison illicite. +arg +DIS.' },
      { fn: 'orga_intimidation',  label: 'Intimidation',               pa: 2, cost: 0,    icon: 'ti-user-exclamation', desc: 'Faire pression sur un PJ. -Moral cible, risque conflit.' },
      { fn: 'orga_blanchiment',   label: 'Blanchiment',                pa: 2, cost: 0,    icon: 'ti-wash',         desc: 'Convertir des fonds sales en fonds propres. -DIS risque.' },
      { fn: 'orga_coup_force',    label: 'Coup de force',              pa: 4, cost: 2000, icon: 'ti-bolt',         desc: 'Action violente coordonnee. Risque eleve, impact fort.' },
    ]
  },

  // ---- LOGE ----
  loge: {
    label: 'Loge Maconnique',
    icon: 'ti-triangle',
    secret: true,
    requis: { inf: 25 },
    grades: {
      republic: ['Apprenti', 'Compagnon', 'Maitre', 'Grand Maitre'],
      narco:    ['Iniciado', 'Hermano', 'Maestro', 'Gran Maestro'],
      soviet:   ['Apprenti du Parti', 'Frere Collectif', 'Maitre Sovietique', 'Grand Architecte'],
      khalija:  ['Murid', 'Ikhwan', 'Sheikh', 'Grand Sheikh'],
    },
    maxParCreation: 1,
    maxAdhesion: 1,
    maxParEmpire: 1,
    cycleElection: 30,
    ordres: [
      { fn: 'orga_cooptation',    label: 'Cooptation discrete',        pa: 2, cost: 1000, icon: 'ti-user-check',   desc: 'Proposer un poste a un PJ sans election. Reserve Grand Maitre.' },
      { fn: 'orga_rituel',        label: 'Rituel d\'initiation',       pa: 2, cost: 500,  icon: 'ti-eye',          desc: 'Initier un nouveau membre. +INF nouveau +loyalty.' },
      { fn: 'orga_kompromat_loge',label: 'Kompromat collectif',        pa: 3, cost: 0,    icon: 'ti-file-shredder',desc: 'Utiliser les secrets de la Loge contre un PJ. -DIS cible.' },
      { fn: 'orga_election_loge', label: 'Election du Grand Maitre',   pa: 1, cost: 0,    icon: 'ti-crown',        desc: 'Organiser l\'election interne. Tous les 30 jours.' },
      { fn: 'orga_reseau',        label: 'Activer le reseau',          pa: 2, cost: 300,  icon: 'ti-network',      desc: 'Obtenir une information exclusive via le reseau. +INF.' },
    ]
  },

  // ---- MEDIATIQUE ----
  mediatique: {
    label: 'Organisation Mediatique',
    icon: 'ti-news',
    secret: false,
    requis: { inf: 30, pop: 10 },
    grades: {
      republic: ['Correspondant', 'Journaliste', 'Redacteur en chef', 'Directeur de Publication'],
      narco:    ['Informateur', 'Reporter', 'Editeur', 'Patron des Medias'],
      soviet:   ['Propagandiste', 'Redacteur', 'Chef de la Pravda', 'Commissaire a l\'Information'],
      khalija:  ['Conteur', 'Chroniqueur', 'Editorialiste', 'Grand Orateur du Sheikh'],
    },
    maxParCreation: 1,
    maxAdhesion: 1,
    ordres: [
      { fn: 'orga_campagne_presse',label: 'Campagne de presse',        pa: 2, cost: 500,  icon: 'ti-speakerphone', desc: 'Article favorable sur un PJ allie. +POP +INF cible.' },
      { fn: 'orga_fake_news',      label: 'Fake news',                 pa: 2, cost: 300,  icon: 'ti-news-off',     desc: 'Rumeur contre un PJ. -POP cible. Risque retournement.' },
      { fn: 'orga_rehabilitation', label: 'Rehabilitation d\'image',   pa: 3, cost: 1000, icon: 'ti-refresh',      desc: 'Redorer le blason d\'un PJ. +POP +DIS cible.' },
      { fn: 'orga_scoop',          label: 'Publier un scoop',          pa: 2, cost: 0,    icon: 'ti-alert',        desc: 'Reveler un secret. +INF orga, scandale public.' },
      { fn: 'orga_silence',        label: 'Etouffer une affaire',      pa: 3, cost: 2000, icon: 'ti-eye-off',      desc: 'Supprimer une information nuisible. +DIS beneficiaire.' },
    ]
  },

  sportive: {
    label: 'Club Sportif',
    icon: 'ti-ball-football',
    secret: false,
    requis: { pop: 10 },
    liePAVille: true,
    grades: {
      republic: ['Junior', 'Titulaire', 'Capitaine', 'Legende'],
      narco:    ['Cadete', 'Titular', 'Capitan', 'Leyenda'],
      soviet:   ['Espoir du Peuple', 'Titulaire', 'Capitaine du Kolkhoze', 'Legende Sportive'],
      khalija:  ['Espoir', 'Titulaire', 'Capitaine', 'Legende du Sheikh'],
    },
    maxParCreation: 0,
    maxAdhesion: 1,
    ordres: []
  },
  supporters: {
    label: 'Club de Supporters',
    icon: 'ti-flag-3',
    secret: false,
    requis: { pop: 5 },
    liePAVille: true,
    grades: {
      republic: ['Sympathisant', 'Membre', 'Ultra', 'Meneur'],
      narco:    ['Simpatizante', 'Miembro', 'Ultra', 'Cabecilla'],
      soviet:   ['Sympathisant', 'Membre du Kop', 'Ultra', 'Meneur de Foule'],
      khalija:  ['Sympathisant', 'Membre', 'Ultra', 'Meneur'],
    },
    maxParCreation: 0,
    maxAdhesion: 1,
    ordres: [
      { fn: 'orga_motion_supporters', label: 'Publier un communique',   pa: 1, cost: 0,   icon: 'ti-speakerphone', desc: "Prise de position du club de supporters. Vote_bonus aux elections locales." },
      { fn: 'orga_hooliganisme',      label: 'Organiser des echauffourees', pa: 3, cost: 0, icon: 'ti-alert-triangle', desc: 'Reserve aux Meneurs. Impact sur la securite locale. Risque penal.' },
      { fn: 'demander_autorisation_manifester', label: 'Demander une autorisation de manifester', pa: 1, cost: 0, icon: 'ti-walk', desc: 'Reserve au chef. Depot 24h avant minimum, validee automatiquement 12h avant si le Ministre de l\'Interieur ne l\'a pas interdite.' },
    ]
  },

};


// Rang minimum pour certains ordres (index dans le tableau grades)
// =====================
// CHAMPIONNAT SPORTIF — 12 clubs, un par ville
// =====================
// Correctif d'identite ville/club (28 aout 2026) : seuls les libelles affiches (nom) sont
// corriges ici pour correspondre aux villes/empires canoniques desormais fixes -- id/country/
// city/stadeBuilding/valeurBase/vedettes INCHANGES (cles persistees dans championnat.data,
// budgets_clubs, presidents_clubs, licence_sportive.clubId, paris_sportifs -- voir l'audit
// prealable). Independiente de Villa Sangre porte le surnom d'univers "Los Sangrilleros" --
// donnee de lore uniquement, aucune mecanique associee dans ce lot.
//
// Identite visuelle (28 aout 2026, chantier animations football) : champ `identite` ajoute a
// chacun des 12 clubs -- couleurs principale/secondaire, eventuel accent, type de maillot
// (uni / rayures_verticales), finition visuelle si pertinente (mate / metallique / irisee).
// Republia : reprend les couleurs deja canoniques des produits derives/boutiques de stade
// existants (produit-tshirt-luthecia.png, produit-casquette-luthecia.png,
// produits-casquette-echarpe-montrouge.png, produit-polo-mariannaise.png, logo du club de
// supporters de Luthecia) -- aucune couleur inventee. Etrangers : reprend exactement les
// couleurs/elements specifies pour ce lot. Aucun champ rempli par une valeur fictive quand
// l'information n'a pas ete fournie (ex. pas de colorSecondaire pour Oasis City FC, pas
// d'accent pour les clubs ou aucune touche supplementaire n'a ete decrite).
const CLUBS_SPORTIFS = [
  { id:'olympique-luthecia',    nom:'Olympique de Luthécia',            country:'republic', city:'capitale', stadeBuilding:'stade', valeurBase:72, vedettes:['Marco Frappesec','Julien Contrapied'],
    identite: { colorPrimaire:'#182544', colorSecondaire:'#C9A84C', colorAccent:'#b3312c', maillot:'uni' } },
  { id:'brise-mariannaise',     nom:'La Brise Mariannaise',             country:'republic', city:'ville_a',  stadeBuilding:'stade', valeurBase:60, vedettes:['Yann Ecume','Loic Maree'],
    identite: { colorPrimaire:'#3d5a74', colorSecondaire:'#eee6d2', colorAccent:'#2f7d6b', maillot:'uni' } },
  { id:'cheminote-montrouge',   nom:'Union Cheminote de Montrouge',     country:'republic', city:'ville_b',  stadeBuilding:'stade', valeurBase:63, vedettes:['Momo Charbon','Sami Rail'],
    identite: { colorPrimaire:'#28395c', colorSecondaire:'#C9A84C', colorAccent:'#7a1f24', maillot:'uni' } },
  { id:'rojos-cartel',          nom:'Estudiantes de la Ciudad',         country:'narco',    city:'capitale', stadeBuilding:'stade', valeurBase:68, vedettes:['El Pistolero','Diego Gatillo'],
    identite: { colorPrimaire:'#4a90d9', colorSecondaire:'#ffffff', colorAccent:'#1a3a6b', maillot:'rayures_verticales' } },
  { id:'fronterizos-unidos',    nom:'Atlético Puerto Negro',            country:'narco',    city:'ville_a',  stadeBuilding:'stade', valeurBase:58, vedettes:['Chuy Frontera','Beto Contrabando'],
    identite: { colorPrimaire:'#111111', colorSecondaire:'#ffffff', maillot:'rayures_verticales' } },
  { id:'jaguares-selva',        nom:'Independiente de Villa Sangre',    country:'narco',    city:'ville_b',  stadeBuilding:'stade', valeurBase:61, vedettes:['Jaguar Rios','Tigre Verde'],
    identite: { colorPrimaire:'#8b0000', colorSecondaire:'#111111', maillot:'rayures_verticales' } },
  { id:'dynamo-novomirsk',      nom:'Dynamo Novomirsk',                 country:'soviet',   city:'capitale', stadeBuilding:'stade', valeurBase:74, vedettes:['Ivan Marteau','Boris Faucille'],
    identite: { colorPrimaire:'#0047ab', colorSecondaire:'#ffffff', maillot:'uni' } },
  { id:'spartak-sibirsk',       nom:'Partizan de Starovka',             country:'soviet',   city:'ville_a',  stadeBuilding:'stade', valeurBase:57, vedettes:['Yuri Glacon','Piotr Frimas'],
    identite: { colorPrimaire:'#111111', colorSecondaire:'#ffffff', colorAccent:'#c0392b', maillot:'rayures_verticales' } },
  { id:'kolkhoze-ouvrier',      nom:'Étoile Rouge de Krasnov',          country:'soviet',   city:'ville_b',  stadeBuilding:'stade', valeurBase:59, vedettes:['Sacha Tracteur','Vania Recolte'],
    identite: { colorPrimaire:'#8b0000', colorSecondaire:'#ffffff', colorAccent:'#d4af37', maillot:'uni' } },
  { id:'nadi-al-madina',        nom:'Shabab Al Madina',                 country:'khalija',  city:'capitale', stadeBuilding:'stade', valeurBase:70, vedettes:['Karim Falcon','Youssef Sable'],
    identite: { colorPrimaire:'#0b1220', colorSecondaire:'#708090', maillot:'uni', finition:'mate' } },
  { id:'al-baraka-fc',          nom:'Oasis City FC',                    country:'khalija',  city:'ville_a',  stadeBuilding:'stade', valeurBase:56, vedettes:['Malik Oasis','Rashid Caravane'],
    identite: { colorPrimaire:'#046a52', maillot:'uni', finition:'irisee' } },
  { id:'sharq-al-nour',         nom:'Al-Petrol United FC',              country:'khalija',  city:'ville_b',  stadeBuilding:'stade', valeurBase:62, vedettes:['Tarek Petrole','Hamza Tanker'],
    identite: { colorPrimaire:'#d4af37', colorSecondaire:'#0b1a1a', maillot:'uni', finition:'metallique' } }
];

const ORGA_ORDRE_RANG_MIN = {
  orga_cooptation:    3, // Grand Maitre seulement
  orga_election_loge: 3, // Grand Maitre seulement
  orga_excommunier:   3, // Chef seulement
  orga_fusion:        3, // President seulement
  orga_coup_force:    2, // Capo/Comandante minimum
  orga_blanchiment:   1, // Soldat minimum
  orga_hooliganisme:  3, // Meneur seulement
};

// =====================
// GREVES, GREVE GENERALE ET CONTRE-POUVOIRS (audit valide + implementation, 3 septembre 2026)
// =====================
// "chefOnly" (nouveau, additif) : gate generique complementaire a ORGA_ORDRE_RANG_MIN ci-dessus
// -- ORGA_ORDRE_RANG_MIN gate par grade/rang, jamais utilisable pour "chef seulement" (le chef
// n'est pas forcement le membre au grade le plus eleve dans tous les cas). Verifie par
// ouvrirOrdresOrga/executerOrdreOrga (plateau-organisations-quetes.js) via orga.chef ===
// state.char?.name, meme doctrine que partout ailleurs dans ce fichier pour les organisations.
const GREVE_MEMBRES_MIN = 5;

// Paliers de la greve ORDINAIRE, par nombre de membres du syndicat greviste (cahier des charges
// §2, valide 3 septembre 2026). Le malus Social reste fixe (-1) quel que soit le palier -- seuls
// POP/pourcentage d'activite/INF scalent avec la taille du syndicat.
const GREVE_PALIERS = [
  { min: 5,   max: 24,       pop: 10, social: 1, entrepriseReduction: 0.10, orgaInf: 1 },
  { min: 25,  max: 49,       pop: 20, social: 1, entrepriseReduction: 0.20, orgaInf: 2 },
  { min: 50,  max: 74,       pop: 30, social: 1, entrepriseReduction: 0.30, orgaInf: 3 },
  { min: 75,  max: 99,       pop: 40, social: 1, entrepriseReduction: 0.40, orgaInf: 4 },
  { min: 100, max: Infinity, pop: 50, social: 1, entrepriseReduction: 0.50, orgaInf: 5 },
];
function palierGreveOrdinaire(nbMembres) {
  return GREVE_PALIERS.find(p => nbMembres >= p.min && nbMembres <= p.max) || GREVE_PALIERS[0];
}
const GREVE_USURE_JOUR_DEBUT = 15; // a partir du 15e jour REEL de greve : usure INF du syndicat
const GREVE_USURE_INF_JOUR = 2;    // -2 INF/jour a partir de ce seuil, plancher 0
const GREVE_ACTIVITE_PLANCHER = 0.40; // une greve ne fait jamais tomber l'activite sous 40% du normal
const GREVE_SOCIAL_PLANCHER = -10;    // plancher structurel specifique aux effets de greve (Social
                                       // peut descendre sous 0 ici, a la difference du plancher 0
                                       // habituel des autres indices -- decision validee, cahier §2/§6)

// Entreprises reellement ciblables par une greve ("activite economique reelle" -- decision du
// 3 septembre 2026 : restreint aux 3 transformateurs de Republia, qui ont une formule de
// production isolee par batiment (VOLUME_MATIERE_PAR_CHAINE_JOUR, api/cron-minuit.js). Les
// entrepots/le port sont exclus de cette premiere version : leur logique de redistribution est
// partagee/proportionnelle entre les 3 villes a la fois (traiterExportationsPortQuotidien),
// un coefficient par batiment isole n'y serait pas sur sans une refonte plus large. Les
// commerces/armureries (moteur PJ pur, plateau-actions-illegales-rumeurs.js) n'ont pas de
// production PNJ/cron de reference a reduire -- egalement hors perimetre de cette version.
const GREVE_ENTREPRISES_CIBLABLES = [
  { id: 'usine-pharmaceutique-luthecia', label: 'Usine Pharmaceutique (Luthécia)', country: 'republic', city: 'capitale', buildingId: 'usine-pharmaceutique-luthecia' },
  { id: 'pole-tabac-alcools-psm',        label: 'Pôle Tabac & Alcools (Port-Sainte-Marie)', country: 'republic', city: 'ville_a', buildingId: 'pole-tabac-alcools-psm' },
  { id: 'raffinerie-montrouge',          label: 'Raffinerie (Montrouge)', country: 'republic', city: 'ville_b', buildingId: 'raffinerie-montrouge' },
];

// Paliers de la greve GENERALE, par nombre d'adherents UNIQUES des syndicats participants
// (cahier des charges §6). "autresElusPop" ne s'applique jamais aux membres du gouvernement
// (voir appliquerEffetsGreveGenerale, api/cron-minuit.js -- pas de double comptage).
const GREVE_GENERALE_NIVEAUX = [
  { min: 100, max: 199,      niveau: 1, gouvernementPop: 2,  autresElusPop: 1, social: 1, economieReduction: 0.10, retournementJour: 11 },
  { min: 200, max: 299,      niveau: 2, gouvernementPop: 4,  autresElusPop: 2, social: 1, economieReduction: 0.20, retournementJour: 9  },
  { min: 300, max: 399,      niveau: 3, gouvernementPop: 6,  autresElusPop: 3, social: 1, economieReduction: 0.30, retournementJour: 7  },
  { min: 400, max: 499,      niveau: 4, gouvernementPop: 8,  autresElusPop: 4, social: 2, economieReduction: 0.40, retournementJour: 6  },
  { min: 500, max: Infinity, niveau: 5, gouvernementPop: 10, autresElusPop: 5, social: 2, economieReduction: 0.50, retournementJour: 5  },
];
function palierGreveGenerale(adherentsUniques) {
  if (adherentsUniques < GREVE_GENERALE_ADHERENTS_MIN) return null;
  return GREVE_GENERALE_NIVEAUX.find(p => adherentsUniques >= p.min && adherentsUniques <= p.max) || GREVE_GENERALE_NIVEAUX[GREVE_GENERALE_NIVEAUX.length - 1];
}
const GREVE_GENERALE_ADHERENTS_MIN = 100; // en-dessous : jamais adoptee, ou fin automatique si deja active
const GREVE_GENERALE_RETOURNEMENT_INF_JOUR = 5; // -5 INF/jour/syndicat participant, a partir du retournement

// Valeurs possibles pour organisations.data.corpsMetier (syndicats uniquement, optionnel,
// declare par le fondateur a la creation -- §9 du cahier des charges : "ne jamais hardcoder un
// nom du type Syndicat des policiers", d'ou un TAG STRUCTUREL plutot qu'une detection par nom.
// Liste fermee (pas de texte libre) pour que la consequence mecanique associee (blocage de la
// repression policiere, voir plateau-politique.js) reste un choix deliberement assume a la
// creation, jamais un hasard de nommage.
const GREVE_CORPS_METIER_OPTIONS = [
  { id: '', label: 'Aucun (générique)' },
  { id: 'police', label: 'Forces de l\'ordre (bloque la répression policière en cas de grève de ce syndicat)' },
];

// POSTES (table statique, holders codes en dur, jamais persistee) retiree le 9 aout 2026 —
// refonte du systeme de postes. Remplacee par POSTES_ELECTIFS (postes elus) et
// POSTES_NOMMES_EXCLUSIFS (postes nommes) plus bas dans ce fichier, seuls systemes desormais
// utilises. NOTE : "Maire Adjoint" (x3 villes) n'existait que dans cette table, jamais lu
// nulle part ailleurs dans le code (aucun requiresPost, aucune nomination) — poste orphelin
// depuis toujours, disparait avec elle. A reintroduire explicitement dans
// POSTES_NOMMES_EXCLUSIFS si un vrai role est voulu pour lui.

// =====================
// ECONOMIE — ENTREPOTS LOGISTIQUES ET TRANSFORMATEURS (modele economique V1, theorie
// validee avec Fred le 6-7 aout 2026, calibree pour ~20 PJ actifs a Luthecia en beta)
// =====================
// - prixBase : prix de vente aux joueurs, au taux de remplissage "moyen" (50%)
// - prixAchatFournisseur : prix paye par l'entrepot a la livraison (moitie du prix de vente)
// - plafond : capacite maximale de stockage de cette categorie, par entrepot
// - source : 'livraison' (tiree aleatoirement aux 6 livraisons/jour) ou 'transformation'
//   (n'arrive dans l'entrepot que via la redistribution 20% d'un transformateur — jamais
//   tiree directement lors d'une livraison de matieres premieres)
// Charbon (17 aout 2026) : matiere distincte du carburant, propre a l'identite economique de
// Montrouge (MATIERES_PREMIERES_VILLE.republic.ville_b) -- aucune valeur ne peut etre deduite
// de l'existant (premiere matiere ajoutee depuis la V1), donc exposee ici en constante isolee,
// facilement ajustable : prix/plafond calibres par analogie avec minerai/bois (matiere premiere
// brute, tier moyen, gros volume de stockage).
const CHARBON_PRIX_BASE = 7;
const CHARBON_PRIX_ACHAT_FOURNISSEUR = 3.5;
const CHARBON_PLAFOND = 400;

const RESSOURCES_ECONOMIE = {
  // --- Matieres premieres (livrees) ---
  cereales:     { label: 'Céréales & légumes', icon: 'ti-wheat',  prixBase: 3,  prixAchatFournisseur: 1.5, plafond: 150, source: 'livraison' },
  poisson:      { label: 'Poisson',      icon: 'ti-fish',        prixBase: 4,  prixAchatFournisseur: 2,   plafond: 125, source: 'livraison' },
  viande:       { label: 'Viande',       icon: 'ti-meat',        prixBase: 5,  prixAchatFournisseur: 2.5, plafond: 125, source: 'livraison' },
  bois:         { label: 'Bois',         icon: 'ti-trees',       prixBase: 5,  prixAchatFournisseur: 2.5, plafond: 750, source: 'livraison' },
  charbon:      { label: 'Charbon',      icon: 'ti-flame',       prixBase: CHARBON_PRIX_BASE, prixAchatFournisseur: CHARBON_PRIX_ACHAT_FOURNISSEUR, plafond: CHARBON_PLAFOND, source: 'livraison' },
  petrole:      { label: 'Pétrole',      icon: 'ti-droplet',     prixBase: 8,  prixAchatFournisseur: 4,   plafond: 200, source: 'livraison' },
  minerai:      { label: 'Minerai',      icon: 'ti-mountain',    prixBase: 10, prixAchatFournisseur: 5,   plafond: 500, source: 'livraison' },
  metal:        { label: 'Métal',        icon: 'ti-bolt',        prixBase: 15, prixAchatFournisseur: 7.5, plafond: 200, source: 'livraison' },
  plantes:      { label: 'Plantes',      icon: 'ti-leaf',        prixBase: 6,  prixAchatFournisseur: 3,   plafond: 300, source: 'livraison' },
  // Lot boissons (20 aout 2026) : deux nouvelles matieres premieres livrees, parametres valides
  // par Fred. Ne touche a aucune ressource existante.
  fruits_legumes:    { label: 'Fruits & légumes', icon: 'ti-apple',   prixBase: 4, prixAchatFournisseur: 2, plafond: 150, source: 'livraison' },
  produits_exotiques:{ label: 'Produits exotiques',icon: 'ti-package',prixBase: 6, prixAchatFournisseur: 3, plafond: 125, source: 'livraison' },
  // Lot socle marches (23 aout 2026) : matiere premiere generique pour les futurs objets
  // d'integration locale (echarpe/casquette/T-shirt, Lot 3) -- audit dedie prealable : aucune
  // matiere textile n'existait, aucun mapping ailleurs n'enumere RESSOURCES_ECONOMIE a la main
  // (toutes les listes reelles trouvees -- Salle des Ventes de l'entrepot, plafond total,
  // vente/achat de matieres par un commerce -- iterent deja Object.keys/entries/values, donc
  // cette seule entree suffit, aucun autre fichier a toucher). Valeurs choisies par analogie
  // avec les autres matieres premieres brutes livrees de tier moyen (poisson/viande/produits_
  // exotiques), meme convention prixAchatFournisseur = prixBase/2 deja verifiee sur toutes les
  // entrees existantes -- ajustables, aucune recette ne les utilise encore dans ce lot.
  textile:            { label: 'Textile',         icon: 'ti-shirt',   prixBase: 5, prixAchatFournisseur: 2.5, plafond: 125, source: 'livraison' },

  // --- Produits transformes (redistribution 20% des transformateurs, jamais livres directement) ---
  medicaments:  { label: 'Médicaments',  icon: 'ti-pill',        prixBase: 22, prixAchatFournisseur: 11,  plafond: 100, source: 'transformation' },
  alcool:       { label: 'Alcool',       icon: 'ti-glass-full',  prixBase: 14, prixAchatFournisseur: 7,   plafond: 100, source: 'transformation' },
  tabac:        { label: 'Tabac',        icon: 'ti-cigarette',   prixBase: 18, prixAchatFournisseur: 9,   plafond: 100, source: 'transformation' },
  carburant:    { label: 'Carburant',    icon: 'ti-gas-station', prixBase: 20, prixAchatFournisseur: 10,  plafond: 100, source: 'transformation' },
  // Filiere alcool->desinfectant (20 aout 2026) : valeurs validees par Fred. Aucun debouche
  // medical/effet de soin ajoute pour l'instant -- une ressource transformee comme les autres.
  desinfectant: { label: 'Désinfectant', icon: 'ti-droplet',     prixBase: 18, prixAchatFournisseur: 9,   plafond: 100, source: 'transformation' }
};

// Prix effectif d'une ressource selon le taux de remplissage du stock (stock eleve = prix
// bas, stock faible = prix haut), variation +/-40% autour du prix de base a 50% de
// remplissage. tauxRemplissage attendu entre 0 (vide) et 1 (plein).
function getPrixRessource(cle, quantiteEnStock) {
  const res = RESSOURCES_ECONOMIE[cle];
  if (!res) return 0;
  const tauxRemplissage = Math.max(0, Math.min(1, quantiteEnStock / res.plafond));
  // 0% rempli -> +40% ; 50% rempli -> prix de base ; 100% rempli -> -40%
  const variation = (0.5 - tauxRemplissage) * 0.8;
  return Math.round(res.prixBase * (1 + variation) * 100) / 100;
}

// Prix automatique PNJ des ENTREPOTS MUNICIPAUX uniquement (arbitrage du 24 aout 2026) : marge
// fixe de 50% du prix de vente, donc prix = 2 x prixAchatFournisseur -- deja exactement egal a
// res.prixBase pour toutes les ressources du catalogue (verifie une a une), sans variation liee
// au niveau de stock. Remplace getPrixRessource() UNIQUEMENT pour les entrepots (achat PJ, prix
// affiche au directeur, vente de bois a l'imprimerie qui suit le cours de l'entrepot) ;
// getPrixRessource() elle-meme reste inchangee et continue de servir la vente directe des
// usines (doOuvrirVenteDirecteUsine) -- voir rapport : le "cout reel" des produits manufactures
// n'a pas ete valide pour cette regle, aucune extension aux usines dans ce lot.
function getPrixRessourceEntrepot(cle) {
  const res = RESSOURCES_ECONOMIE[cle];
  if (!res) return 0;
  return Math.round(res.prixBase * 100) / 100;
}

// Quantite maximale livrable pour combler un entrepot vide a son plafond (dotation de
// depart en debut de partie, ou reference pour le calcul des livraisons).
function getPlafondTotalEntrepot() {
  return Object.values(RESSOURCES_ECONOMIE).reduce((s, r) => s + r.plafond, 0);
}

// =====================
// ORDER EFFECTS
// =====================
const ORDER_EFFECTS = {
  se_nourrir:         {hp:5,   moral:1,  successRate:100},
  repas_gastronomique: {hp:10,  moral:1,  successRate:100},
  service_etage:       {hp:10,  moral:1,  successRate:100},
  dormir:             {moral:5,          successRate:100, paBonus:0},
  se_reposer:         {moral:3,          successRate:100},
  // soins (clinique-privee) / soin_public (les 3 dispensaires publics de Republia) -- 20 aout
  // 2026, filiere alcool->desinfectant : desormais des fonctions dediees
  // (doSoinCliniquePrivee/doSoinPublic, plateau-personnage.js), hors du chemin generique
  // doOrder()/applyEffects() -- gain Sante/PA strictement fixe, jamais de jet ni de multiplicateur
  // crit. Aucune entree ici pour "soins"/"soin_public"/"soins_basiques" : plus aucun batiment ne
  // reference ces 3 fn via le chemin generique (soins_basiques etait le dernier, utilise par
  // dispensaire-public-v -- desormais branche sur soin_public comme les 2 autres dispensaires).
  soins_urgence:      {hp:40,            successRate:100},
  soins_discrets:     {hp:30,  dis:-2,   successRate:95},
  rencontrer:         {inf:2,            successRate:100},
  diner_affaires:     {inf:5,  moral:2,  successRate:100},
  ecouter:            {},
  rumeur:             {pop:5,            successRate:80},
  parler_pnj:         {moral:1,          successRate:100},
  se_renseigner:      {},
  reserver:           {},
  reunion_privee:     {dis:2,            successRate:100},
  assister_session:   {inf:1,            successRate:100},
  voter_loi:          {inf:3,            successRate:100},
  projet_loi:         {inf:4,            successRate:70},
  marchander:         {inf:5,            successRate:60},
  postuler:           {inf:2,            successRate:80},
  negocier:           {inf:3,            successRate:70},
  se_presenter:       {inf:1,            successRate:100},
  gerer_finances:     {},
  investir:           {},
  emprunter:          {arg:2000,         successRate:70},
  fiscal:             {arg:300,          successRate:85},
  compte_offshore:    {dis:3,            successRate:80},
  blanchiment:        {dis:-5,           successRate:55},
  societe_ecran:      {dis:3,            successRate:60},
  interview:          {pop:5,            successRate:100},
  article:            {pop:8,            successRate:70},
  plainte:            {inf:2,            successRate:100},
  plainte_police:     {inf:1,            successRate:100},
  archives:           {},
  archives_police:    {},
  defense:            {},
  corrompre_fonct:    {inf:5,  dis:-3,   successRate:65},
  corrompre_juge:     {dis:-5,           successRate:45},
  corrompre_police:   {dis:-3,           successRate:55},
  corrompre_journaliste:{dis:-4,         successRate:55},
  corrompre_fonct_v:  {inf:3,  dis:-4,   successRate:65},
  recruter_info:      {},
  arreter:            {inf:3,  dis:-8,   successRate:50},
  etouffer:           {dis:-5,           successRate:45},
  falsifier_docs:     {dis:-8,           successRate:40},
  introduction_loge:  {inf:2,            successRate:100},
  se_former:          {},
  donner_conf:        {pop:5,  inf:3,    successRate:75},
  recruter_etud:      {inf:3,            successRate:70},
  acheter_arme:       {},
  acheter_gilet:      {},
  acheter_terrain:    {},
  permis_construire:  {},
  permis_corrompu:    {dis:-5,           successRate:60},
  acheter_entreprise: {},
  mobiliser:          {inf:5,  pop:3,    successRate:70},
  greve:              {inf:8,  pop:5,    successRate:55},
  contrebande:        {dis:-3,           successRate:55},
  deplacer:           {successRate:100}
};

// =====================
// POPULATION PNJ
// =====================
const CITY_POPULATION = {
  republic: {
    capitale: {
      total: 850000,
      classes: { pauvre: 0.25, ouvriere: 0.35, bourgeoisie: 0.28, elite: 0.12 },
      taxRate: 0.18,
      dailyTaxRevenue: 42000, // FR par jour pour l'Etat
      unemployment: 0.09
    },
    ville_a: {
      total: 120000,
      classes: { pauvre: 0.20, ouvriere: 0.40, bourgeoisie: 0.30, elite: 0.10 },
      taxRate: 0.18,
      dailyTaxRevenue: 6000,
      unemployment: 0.07
    },
    ville_b: {
      total: 95000,
      classes: { pauvre: 0.30, ouvriere: 0.50, bourgeoisie: 0.15, elite: 0.05 },
      taxRate: 0.18,
      dailyTaxRevenue: 4200,
      unemployment: 0.14
    }
  },
  // Correctif du 24 aout 2026 (audit fiscal) : une seconde cle 'republic' (urls d'images de
  // batiments -- palais-presidentiel/palais-gouvernement/mairie-capitale/mairie/terrains a
  // batir) ecrasait silencieusement le bloc demographique/fiscal ci-dessus. Ce contenu image
  // etait un doublon exact (jusqu'a la virgule finale) d'un extrait deja present et deja
  // utilise dans ROOM_IMAGES_EMPIRE.republic (voir plus haut dans ce fichier, palais-
  // presidentiel a terrain-a-batir-7) -- structure existante deja lue en runtime par
  // plateau-navigation.js (ROOM_IMAGES_EMPIRE[state.country]?.[buildingId]?.[roomId]). Rien
  // n'est perdu : ces images restent accessibles exactement ou elles etaient deja reellement
  // utilisees. Supprime ici uniquement l'exemplaire orphelin qui neutralisait CITY_POPULATION.
  narco: {
    capitale: { total: 620000, taxRate: 0.08, dailyTaxRevenue: 18000, unemployment: 0.28 },
    ville_a:  { total: 85000,  taxRate: 0.08, dailyTaxRevenue: 2400,  unemployment: 0.32 },
    ville_b:  { total: 70000,  taxRate: 0.08, dailyTaxRevenue: 1800,  unemployment: 0.35 }
  },
  soviet: {
    capitale: { total: 1200000, taxRate: 0.35, dailyTaxRevenue: 28000, unemployment: 0.02 },
    ville_a:  { total: 180000,  taxRate: 0.35, dailyTaxRevenue: 4200,  unemployment: 0.02 },
    ville_b:  { total: 150000,  taxRate: 0.35, dailyTaxRevenue: 3500,  unemployment: 0.02 }
  },
  khalija: {
    capitale: { total: 320000, taxRate: 0.00, dailyTaxRevenue: 0, unemployment: 0.03, oilRevenue: 85000 },
    ville_a:  { total: 45000,  taxRate: 0.00, dailyTaxRevenue: 0, unemployment: 0.04, oilRevenue: 12000 },
    ville_b:  { total: 38000,  taxRate: 0.00, dailyTaxRevenue: 0, unemployment: 0.04, oilRevenue: 18000 }
  }
};

// Salaires journaliers par poste (verses lors de l\'ordre Dormir)
const SALAIRES = {
  president:   5000,
  pm:          3500,
  min_int:     2800,
  min_fin:     2800,
  min_just:    2800,
  min_def:     2800,
  min_info:    2800,
  min_ae:      2800,
  depute:      1200,
  senateur:    1200,
  juge:        1800,
  commissaire: 1000,
  maire:       800,
  adj_maire:   500,
  gouverneur:  1500,
  prefet:      900,
  default:     150  // Citoyen sans poste
};

// =====================
// BUREAU NATIONAL DE L'EMPLOI (BNE) — catalogue des offres, 9 aout 2026
// =====================
// Contenu statique (comme PNJ_STATS_PAR_JOB) : le "qui occupe quelle offre" reel est stocke
// dans Supabase, table generique batiments_etat, sous une seule entree partagee
// (country + '_national_bne') plutot qu'une nouvelle table dediee (voir sbGetEtatBNE/
// sbSetEtatBNE, supabase.js). Salaire verse comme un salaire de poste classique, a l'ordre
// Dormir (voir calculerSalaireDormir, plateau-personnage.js). Incompatible avec un poste
// politique (state.poste) — un seul des deux a la fois.
// portee : 'locale' (restreinte a une ville, champ ville obligatoire), 'nationale' (visible
// depuis n'importe quel Bureau de Republia), 'internationale' (visible aussi au Quartier des
// Ambassades — pour l'instant juste une etiquette/du contenu jouable, pas de vraie mecanique
// inter-empire derriere).
const OFFRES_EMPLOI_BNE = {
  serveur_luthecia:     { job:'serveur',    label:'Serveur — Hôtel Républica',                       portee:'locale',         ville:'capitale', salaire:200, places:2 },
  docker_psm:           { job:'docker',     label:'Docker — Port Industriel de Port-Sainte-Marie',   portee:'locale',         ville:'ville_a',  salaire:220, places:2 },
  hotelier_montrouge:   { job:'hotelier',   label:'Hôtelier — Hôtel du Mineur',                       portee:'locale',         ville:'ville_b',  salaire:250, places:1 },
  secretaire_nationale: { job:'secretaire', label:'Secrétaire administratif (poste itinérant)',       portee:'nationale',      salaire:300, places:3 },
  commercant_national:  { job:'commercant', label:'Commerçant itinérant',                             portee:'nationale',      salaire:220, places:3 },
  banquier_national:    { job:'banquier',   label:'Conseiller bancaire',                              portee:'nationale',      salaire:450, places:1 },
  hotesse_ambassade:    { job:'hotesse',    label:"Hôtesse d'accueil diplomatique",                   portee:'internationale', salaire:280, places:2 }
};

// Postes nommes (non electifs) avec regles de cumul strictes
// 'depute' est le SEUL poste compatible avec juge/commissaire
const POSTES_NOMMES_EXCLUSIFS = {
  juge:        { label: 'Juge',        nommePar: 'min_just', scope: 'pays',  compatibles: ['depute'] },
  commissaire: { label: 'Commissaire', nommePar: 'maire',    scope: 'ville', compatibles: ['depute'] },
  commandant:  { label: 'Commandant de la Caserne', nommePar: 'min_def', scope: 'pays', compatibles: ['depute'] },
  pm:          { label: 'Premier Ministre',              nommePar: 'president', scope: 'pays', compatibles: ['depute'] },
  min_int:     { label: "Ministre de l'Interieur",       nommePar: 'pm',        scope: 'pays', compatibles: ['depute'] },
  min_fin:     { label: 'Ministre des Finances',         nommePar: 'pm',        scope: 'pays', compatibles: ['depute'] },
  min_just:    { label: 'Ministre de la Justice',        nommePar: 'pm',        scope: 'pays', compatibles: ['depute'] },
  min_def:     { label: 'Ministre de la Defense',        nommePar: 'pm',        scope: 'pays', compatibles: ['depute'] },
  min_info:    { label: "Ministre de l'Information",     nommePar: 'pm',        scope: 'pays', compatibles: ['depute'] },
  min_ae:      { label: 'Ministre des Affaires Etrangeres', nommePar: 'pm',     scope: 'pays', compatibles: ['depute'] },

  // Directeurs des entreprises stategiques — nommes par le Ministre des Finances, portee
  // nationale (comme les ministres/juge), meme si physiquement rattaches a une ville precise.
  directeur_pharma:        { label: "Directeur de l'Usine Pharmaceutique", nommePar: 'min_fin', scope: 'pays', compatibles: ['depute'] },
  directeur_tabac_alcools: { label: 'Directeur du Pôle Tabac & Alcools',   nommePar: 'min_fin', scope: 'pays', compatibles: ['depute'] },
  directeur_raffinerie:    { label: 'Directeur de la Raffinerie',          nommePar: 'min_fin', scope: 'pays', compatibles: ['depute'] },

  // Directeur de l'entrepot logistique — nomme par le Maire ADJOINT depuis le 10 aout 2026
  // (transfert complet de la prerogative, voir maire_adjoint ci-dessous), portee locale, un
  // titulaire distinct par ville. Meme mecanique que le commissaire. Ne change rien au
  // remplissage PNJ automatique du cron (verifierPostesVacantsEtAutoPourvoir, api/cron-minuit.js),
  // qui a sa propre boucle par ville cablee sur estOccupe('maire', ville), independante de ce champ.
  directeur_entrepot:      { label: "Directeur de l'Entrepôt Logistique",  nommePar: 'maire_adjoint', scope: 'ville', compatibles: ['depute'] },

  // Maire Adjoint (10 aout 2026) — nomme par le Maire, portee locale. Pas de repli PNJ
  // automatique dans la cascade du cron (deliberement pas construit, reflexion a venir sur une
  // eventuelle cohabitation liee au score electoral) : le poste reste simplement vacant tant
  // qu'aucun joueur ne postule.
  maire_adjoint:           { label: 'Maire Adjoint',                      nommePar: 'maire',         scope: 'ville', compatibles: ['depute'] },

  // Chef des Douanes (lot du 24 aout 2026) — nomme par le Ministre de l'Interieur, portee
  // nationale (comme juge/commandant), meme si l'unique service douanier existant est
  // physiquement rattache au port de PSM. Repli PNJ (Pascal Paguevite) ajoute a la cascade
  // nationale du cron (api/cron-minuit.js, CASCADE_NATIONALE/PNJ_PAR_DEFAUT_POSTE), meme
  // mecanique que les 3 directeurs d'usine/juge/commandant -- aucun nouveau moteur de nomination.
  chef_douanes:            { label: 'Chef des Douanes',                   nommePar: 'min_int',       scope: 'pays',  compatibles: ['depute'] },

  // Commandant du Port (lot logistique portuaire, 25 aout 2026) — nomme par le Ministre des
  // Finances, portee nationale, meme mecanique que chef_douanes/directeur_raffinerie. A la
  // difference de chef_douanes, Marcel Ancre (PNJ titulaire par defaut, voir PNJ_PAR_DEFAUT_POSTE
  // et CASCADE_NATIONALE, api/cron-minuit.js) doit rester visible dans administration_portuaire
  // meme une fois qu'un PJ occupe reellement le poste : capitaine_port n'est PAS ajoute a
  // POSTES_UNIQUES_A_MASQUER (plateau-multijoueur.js), choix deliberement different du
  // chef_douanes/Pascal Paguevite qui, lui, disparait.
  capitaine_port:          { label: 'Commandant du Port',                 nommePar: 'min_fin',       scope: 'pays',  compatibles: ['depute'] }
};

// Priorite PJ sur postes nommes (lot du 25 aout 2026, apres audit dedie) : "le PNJ a priorite
// sur le vide, le PJ a priorite sur le PNJ, l'autorite politique choisit entre les PJ". Delai
// laisse a une autorite PJ pour choisir entre les candidats avant traitement automatique
// (tirage au sort + sanction du nominateur passif), et duree de protection d'un PJ fraichement
// nomme contre la revocation/le remplacement politique arbitraire. Generique a TOUS les
// POSTES_NOMMES_EXCLUSIFS ci-dessus, aucune exception par poste (voir plateau-politique.js/
// api/cron-minuit.js). Duree en millisecondes reelles (Date.now()), jamais en jours de jeu.
const DELAI_DECISION_CANDIDATURE_MS = 48 * 3600 * 1000; // 48h reelles
const DUREE_PROTECTION_POSTE_NOMME_MS = 7 * 24 * 3600 * 1000; // 7 jours reels

// Nouveaux ordres v6
Object.assign(ORDER_EFFECTS, {
  se_cacher:          {dis:5,            successRate:70},
  organiser_blocus:   {inf:8,            successRate:40},
  incendier:          {dis:-10,          successRate:30},
  tentative_evasion:  {dis:-5,           successRate:15},
  se_rebeller:        {moral:5,          successRate:30},
  requete_avocat:     {inf:2,            successRate:100},
  imprimer_tracts:    {pop:5,  inf:3,    successRate:100},
  conference_presse:  {pop:15, inf:10,   successRate:100},
  annonce_officielle: {pop:5,  inf:5,    successRate:100},
  propagande_etat:    {pop:20,           successRate:75},
  dementi:            {pop:8,            successRate:80},
  consulter_dossiers: {inf:5,            successRate:80},
  fuite_info:         {pop:10, inf:5,    successRate:60},
  fabriquer_scandale: {pop:15, dis:-10,  successRate:45},
  plainte_police:     {successRate:100},
  archives_police:    {successRate:95}
});

// Ordres v12 — assassinat, budget institutions, population dynamique
Object.assign(ORDER_EFFECTS, {
  assassiner_mains:   {hp:-30, dis:-5,  successRate:20},
  assassiner_arme:    {hp:-60, dis:-8,  successRate:40},
  assassiner_feu:     {hp:-80, dis:-20, successRate:60},
  greve_faim:         {hp:-5,  pop:3,   successRate:100},
  visiter_prisonnier: {inf:2,           successRate:70},
  interroger:         {inf:5,           successRate:75},
  inspecter_troupes:  {inf:3,           successRate:100},
  planifier_operation:{inf:4,           successRate:80},
  reception_etat:     {pop:10, inf:8,   successRate:100},
  banquet_diplo:      {inf:12, pop:5,   successRate:100}
});

// =====================
// BUDGETS INSTITUTIONS
// =====================
const BUDGETS_INSTITUTIONS = {
  republic: {
    capitale: {
      commissariat: { budget: 5000, coutEnquete: 500, salairesJour: 800 },
      tribunal:     { budget: 4000, coutEnquete: 600, salairesJour: 700 },
      mairie:       { budget: 8000, coutServices: 1000, salairesJour: 1200 }
    },
    ville_a: {
      commissariat: { budget: 2000, coutEnquete: 300, salairesJour: 400 },
      mairie:       { budget: 3000, coutServices: 500, salairesJour: 600 }
    },
    ville_b: {
      commissariat: { budget: 2500, coutEnquete: 300, salairesJour: 450 },
      mairie:       { budget: 3500, coutServices: 600, salairesJour: 700 }
    }
  }
};

// =====================
// PJ SIMULATION (mode test multijoueur)
// =====================
// Les 3 profils de demonstration (Alexandre Moreau/Sophie Leroux/Viktor Krasov) retires ici
// (lot de nettoyage beta) : ils apparaissaient comme de vrais PJ "[SIM]" dans les pieces de la
// capitale aux yeux des vrais joueurs. L'infrastructure de simulation (initSimulation/
// getSimulesPresents/ouvrirPanneauSimulation/deplacerSimule*, plateau-pnj.js) reste intacte et
// fonctionnelle -- elle lit simplement un tableau vide desormais, aucun PJ simule ne s'affiche
// plus nulle part. Reajouter ici de futurs profils de test si necessaire.
const PJ_SIMULES = [];

// =====================
// INDICES NATIONAUX V13
// =====================
const INDICES_NATIONAUX = {
  republic: { ISN: 30, IE: 50, ID: 40, IS: 45 },
  narco:    { ISN: 15, IE: 30, ID: 20, IS: 25 },
  soviet:   { ISN: 70, IE: 40, ID: 30, IS: 35 },
  khalija:  { ISN: 60, IE: 65, ID: 50, IS: 40 }
};

function getMalusIllegal(country) {
  const isn = typeof getIndiceNationalCalcule === 'function' ? getIndiceNationalCalcule(country, 'isn') : (INDICES_NATIONAUX[country]?.ISN || 30);
  if (isn <= 20) return 0;
  if (isn <= 40) return 5;
  if (isn <= 60) return 10;
  if (isn <= 80) return 15;
  return 25;
}

function getMultDetection(country) {
  const isn = typeof getIndiceNationalCalcule === 'function' ? getIndiceNationalCalcule(country, 'isn') : (INDICES_NATIONAUX[country]?.ISN || 30);
  if (isn <= 60) return 1;
  if (isn <= 80) return 2;
  return 3;
}

const MEDIAS = {
  republic: ['La Tribune de Republia', 'Radio Nationale', 'Tele Publia', 'Le Moniteur Regional', 'Info-Presse Independante']
};

const ENTREPRISES_PRIVEES = { republic: [] };

const SECTEURS = ['Commerce', 'Industrie lourde', 'Agriculture', 'Services financiers', 'Immobilier', 'Technologie', 'Sante privee', 'Media et communication'];

// PJ SIMULATION




// Ordres v13
Object.assign(ORDER_EFFECTS, {
  solliciter_audience_president:{successRate:100},
  etat_nation:        {successRate:100},
  forum_president_conference:{pop:15,inf:10,successRate:100},
  forum_president_annonce:{pop:5,inf:5,successRate:100},
  forum_president_propagande:{pop:20,successRate:100},
  forum_president_dementi:{pop:8,successRate:100},
  reception_etat:     {pop:10,inf:8,successRate:80},
  banquet_diplo:      {inf:12,pop:5,successRate:80},
  nommer_pm:          {successRate:100},
  nommer_ministre_pm: {successRate:100},
  declarer_guerre_empire:{successRate:100},
  gracier_condamne:   {successRate:100},
  decret_referendum:  {successRate:100},
  nationaliser_entreprise:{successRate:80},
  jour_deuil:         {pop:5,successRate:100}
});

// =====================
// INDICE DE PIETE (IP)
// =====================
if (typeof INDICES_NATIONAUX !== 'undefined') {
  Object.keys(INDICES_NATIONAUX).forEach(pays => {
    if (!INDICES_NATIONAUX[pays].IP) INDICES_NATIONAUX[pays].IP = 40;
  });
}

// =====================
// OBJETS HUMORISTIQUES
// =====================
const OBJETS_SPECIAUX = [
  { id:'formulaire_2847', name:'Formulaire 2847-B tamponné', icon:'ti-file-certificate', legal:true, effet:'admin+20', desc:'Augmente de 20% la réussite des ordres administratifs. En triple exemplaire.', lieu:'Mairie' },
  { id:'loukoum_contrebande', name:'Loukoum de contrebande (pistache)', icon:'ti-package', legal:false, effet:'moral+5,dis-5', desc:'+5 Moral. -5 DIS. Goût suspect mais irrésistible.', lieu:'Bar des Pêcheurs, Marché noir' },
  { id:'photo_compromettante', name:'Photo compromettante (sujet flou)', icon:'ti-camera', legal:false, effet:'chantage', desc:'Permet l\'ordre Chantage sur n\'importe quel PJ. Sujet identifiable malgré le flou artistique.', lieu:'La Tribune' },
  { id:'medaille_merite', name:'Médaille du Mérite Administratif', icon:'ti-award', legal:true, effet:'inf+10_audience', desc:'+10 INF lors des audiences officielles. Bruit de cliquetis à chaque pas.', lieu:'Décernée par le Président' },
  { id:'mallette_diplo', name:'Mallette diplomatique', icon:'ti-briefcase', legal:true, effet:'mae+15', desc:'+15% réussite ordres MAE. Fermée à double tour. Contenu mystérieux.', lieu:'Banque Privée Helvetia' },
  { id:'faux_nez', name:'Faux nez et moustache (kit complet)', icon:'ti-mood-happy', legal:true, effet:'dis+15', desc:'+15 DIS pendant 24h. Discrétion garantie... ou presque.', lieu:'Marché Central' },
  { id:'champagne_parlement', name:'Bouteille de Champagne Parlementaire', icon:'ti-bottle', legal:true, effet:'moral+8_groupe', desc:'+8 Moral pour tout le groupe. À consommer avant le vote.', lieu:'Hôtel-Restaurant La Républia' },
  { id:'carnet_contacts', name:'Carnet de contacts froissé', icon:'ti-address-book', legal:true, effet:'contact_aleatoire', desc:'Révèle un contact aléatoire. Certaines pages sont tachées de café.', lieu:'Loge Maçonnique' },
  { id:'tracteur_miniature', name:'Tracteur miniature (souvenir)', icon:'ti-tractor', legal:true, effet:'pop+5_sovarka', desc:'+5 popularité à Sovarka. Vendu à la boutique du Kolkhoze.', lieu:'Marché de Novomirsk' },
  { id:'relique_loukoum', name:'Relique du Loukoum Sacré', icon:'ti-star', legal:true, effet:'ip+10', desc:'+10 IP. Accès facilité aux zones réservées d\'Al-Khalija.', lieu:'Patisserie Sacree' }
];

// =====================
// SCANDALES PREDEFINIS
// =====================
const SCANDALES_PREDEFINIS = [
  "Le Ministre des Finances a été surpris à frauder sa propre déclaration d'impôts. Il invoque 'une erreur de formulaire en triple exemplaire'.",
  "Le Premier Ministre a été aperçu au Laboratoire de Prière d'El Estado. Il parle d'un 'voyage diplomatique culturel intensif'.",
  "Le Président refuse de signer un décret car il manque le tampon numéro 7. Le pays est paralysé depuis 48 heures.",
  "Le Grand Prêtre du Papyrusisme a été surpris sans ses formulaires. Le Tabernacle est en état de choc.",
  "Un député s'est endormi pendant le vote d\'une loi et a voté Pour et Contre simultanément. La loi est en suspens.",
  "Le Commissaire Raoul Toufaud a perdu ses menottes. Il s'est menotté lui-même par erreur en cherchant à les retrouver.",
  "Le Ministre de l'Information a censuré son propre communiqué de presse par inadvertance.",
  "Un loukoum contaminé sème la panique à Al-Khalija. Le Grand Confiseur Abdul Loukoum est introuvable.",
  "Le Camarade Pontife Tractorenko a béni un tracteur privé par erreur. L'hérésie est totale.",
  "Le Juge Honoré Cozetoujours a condamné son propre greffier avant d'entendre l'affaire. Il 'assume pleinement'."
];
