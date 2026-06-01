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

const ORIGINS = [
  {id:'poor',     icon:'ti-home-off',          name:'Milieu defavorise',  arg:200,  bonuses:{VOL:2,DUP:1}, malus:{CHA:-1}, trait:'Resilience brute'},
  {id:'worker',   icon:'ti-tool',              name:'Classe ouvriere',    arg:500,  bonuses:{VOL:1,ENT:1}, malus:{},       trait:'Sens du collectif'},
  {id:'bourgeois',icon:'ti-building',          name:'Petite bourgeoisie', arg:1200, bonuses:{INT:1,CHA:1}, malus:{},       trait:'Vernis social'},
  {id:'elite',    icon:'ti-building-skyscraper',name:'Haute societe',     arg:3000, bonuses:{ENT:2,CHA:1}, malus:{VOL:-1}, trait:"Carnet d'adresses ancestral"}
];

const SCHOOLS = [
  {id:'none',   icon:'ti-x',      name:"Pas d'ecole",        compPts:20, bonuses:{DUP:2,VOL:1}, malus:{INT:-1}, blocks:['civil','lawyer','magistrat','lobbyist','academic','doctor'], blockLabel:"Bloque : fonctionnaire, avocat, magistrat, lobbyiste, universitaire, medecin"},
  {id:'basic',  icon:'ti-book',   name:'Ecole basique',      compPts:35, bonuses:{PER:1,ENT:1}, malus:{},       blocks:['civil','magistrat','lobbyist'],                              blockLabel:'Bloque : haut fonctionnaire, magistrat, lobbyiste'},
  {id:'higher', icon:'ti-school', name:'Etudes superieures', compPts:50, bonuses:{INT:2,CHA:1}, malus:{},       blocks:[],                                                           blockLabel:'Toutes carrieres accessibles'},
  {id:'elite',  icon:'ti-award',  name:'Hautes ecoles',      compPts:65, bonuses:{INT:3,CHA:1,ENT:1}, malus:{VOL:-1}, blocks:[],                                                   blockLabel:'Toutes carrieres + acces reseau elite'}
];

const ARCHETYPES = [
  {id:'politician',    icon:'ti-speakerphone',   name:'Ambitieux',               bonuses:{CHA:2,ENT:2}, malus:{DUP:-2}, argBonus:300,  infBonus:15, popBonus:20,  disBonus:-10, desc:"Seduction et persuasion. Le pouvoir est votre oxygene."},
  {id:'authoritarian', icon:'ti-sword',          name:'Ordre et discipline',     bonuses:{VOL:2,PER:2}, malus:{ENT:-2}, argBonus:500,  infBonus:20, popBonus:5,   disBonus:5,   desc:"La hierarchie et la force. L'ordre est la seule vraie valeur."},
  {id:'oligarch',      icon:'ti-briefcase',      name:'Capitaliste',             bonuses:{INT:2,DUP:2}, malus:{CHA:-2}, argBonus:2000, infBonus:10, popBonus:-5,  disBonus:5,   desc:"L'argent est la mesure de toutes choses."},
  {id:'informer',      icon:'ti-news',           name:"Diffuseur d'informations",bonuses:{PER:2,INT:2}, malus:{VOL:-2}, argBonus:200,  infBonus:5,  popBonus:15,  disBonus:-5,  desc:"L'information est votre arme et votre raison d'etre."},
  {id:'legalist',      icon:'ti-scale',          name:'Legaliste',               bonuses:{INT:2,VOL:2}, malus:{CHA:-2}, argBonus:600,  infBonus:15, popBonus:5,   disBonus:10,  desc:"Les regles, les textes, les procedures. Vous savez comment les plier."},
  {id:'believer',      icon:'ti-building-church',name:'Homme de foi',            bonuses:{CHA:2,ENT:2}, malus:{DUP:-2}, argBonus:100,  infBonus:10, popBonus:25,  disBonus:0,   desc:"Une conviction profonde vous anime. Elle mobilise les foules."},
  {id:'shadow',        icon:'ti-user-question',  name:"Homme de l'ombre",        bonuses:{DUP:2,PER:2}, malus:{CHA:-2}, argBonus:400,  infBonus:5,  popBonus:-10, disBonus:20,  desc:"Infiltration, manipulation, double jeu. Vous n'existez pas officiellement."},
  {id:'anticapitalist',icon:'ti-users-group',    name:'Anti-capitaliste',        bonuses:{CHA:2,VOL:2}, malus:{INT:-2}, argBonus:200,  infBonus:10, popBonus:20,  disBonus:-5,  desc:"Vous combattez le systeme. La justice sociale est votre etendard."},
  {id:'criminal',      icon:'ti-eye-off',        name:'Criminel',                bonuses:{DUP:2,VOL:2}, malus:{ENT:-2}, argBonus:1500, infBonus:5,  popBonus:-15, disBonus:15,  desc:"En dehors des lois. Vos propres regles, bien plus efficaces."}
];

const CAREERS = [
  {id:'civil',       name:'Haut fonctionnaire',        icon:'ti-id-badge',        argBonus:800,  statKey:'INT', comp:'Droit, Negociation',        contact:'Un ministre en poste',         casserole:'Dossier fiscal sensible',            blocks:['none','basic']},
  {id:'local_civil', name:'Fonctionnaire local',        icon:'ti-building-estate', argBonus:350,  statKey:'ENT', comp:'Administration, Entregent',  contact:'Un elu local complaisant',      casserole:'Favoritisme avere',                  blocks:[]},
  {id:'officer',     name:'Officier sup. / Mercenaire', icon:'ti-military-rank',   argBonus:700,  statKey:'VOL', comp:'Commandement, Intimidation', contact:'Un general loyal',              casserole:'Bavure classifiee',                  blocks:[]},
  {id:'business',    name:"Homme d'affaires",           icon:'ti-chart-line',      argBonus:2000, statKey:'INT', comp:'Lobbying, Blanchiment',      contact:'Un banquier discret',           casserole:'Paradis fiscal exposable',           blocks:[]},
  {id:'magistrat',   name:'Magistrat',                  icon:'ti-gavel',           argBonus:750,  statKey:'INT', comp:'Droit, Procedure judiciaire',contact:'Un procureur influent',         casserole:'Jugement partial avere',             blocks:['none','basic']},
  {id:'lawyer',      name:'Avocat',                     icon:'ti-scale',           argBonus:900,  statKey:'INT', comp:'Droit, Negociation',         contact:'Reseau judiciaire',             casserole:'Client douteux defend',              blocks:['none','basic']},
  {id:'press',       name:'Grand journaliste',          icon:'ti-pencil',          argBonus:400,  statKey:'PER', comp:'Kompromat, Propagande',      contact:'Un redacteur en chef',          casserole:'Ennemi puissant cree',               blocks:['none']},
  {id:'influencer',  name:'Influenceur',                icon:'ti-device-mobile',   argBonus:300,  statKey:'CHA', comp:'Reseaux sociaux, Image',     contact:'Communaute de followers',       casserole:'Scandale en ligne archive',          blocks:[]},
  {id:'clergy',      name:'Chef de culte',              icon:'ti-star',            argBonus:100,  statKey:'CHA', comp:'Rhetorique, Mobilisation',   contact:'Communaute de fideles',         casserole:'Scandale moral',                     blocks:[]},
  {id:'lobbyist',    name:'Lobbyiste',                  icon:'ti-arrows-exchange', argBonus:1100, statKey:'ENT', comp:'Lobbying, Negociation',      contact:'Un directeur de cabinet',       casserole:"Conflit d'interets documente",       blocks:['none','basic']},
  {id:'doctor',      name:'Medecin',                    icon:'ti-stethoscope',     argBonus:700,  statKey:'INT', comp:'Reseau civil, Discretion',   contact:'Patients influents',            casserole:'Prescription douteuse',              blocks:['none','basic']},
  {id:'academic',    name:'Universitaire',              icon:'ti-book-2',          argBonus:300,  statKey:'INT', comp:'Rhetorique, Propagande',     contact:'Etudiants militants',           casserole:'These controversee',                 blocks:['none','basic']},
  {id:'union',       name:'Syndicaliste',               icon:'ti-affiliate',       argBonus:200,  statKey:'VOL', comp:'Mobilisation, Negociation',  contact:'Milliers de membres syndiques', casserole:'Greve sauvage passee',               blocks:['none']},
  {id:'intel',       name:'Agent des services',         icon:'ti-spy',             argBonus:500,  statKey:'PER', comp:'Surveillance, Infiltration', contact:'Ancien superieur classe',       casserole:'Operation classifiee compromettante', blocks:[]},
  {id:'criminal_c',  name:'Criminel organise',          icon:'ti-lock-open',       argBonus:1200, statKey:'DUP', comp:'Milices, Blanchiment',       contact:'Reseau criminel actif',         casserole:"Mandat d'arret latent",              blocks:[]}, // Accessible a tous
  {id:'worker',      name:'Ouvrier',                    icon:'ti-hammer',          argBonus:250,  statKey:'VOL', comp:'Force, Solidarite',          contact:"Camarades d'atelier",           casserole:'Accident du travail cache',          blocks:[]},
  {id:'unemployed',  name:'Sans emploi',                icon:'ti-mood-sad',        argBonus:50,   statKey:'DUP', comp:'Survie, Systeme D',          contact:'Reseau de la rue',              casserole:'Casier judiciaire mineur',           blocks:[]},
  {id:'escort',      name:'Prostitue(e)',                icon:'ti-heart',           argBonus:400,  statKey:'CHA', comp:'Seduction, Kompromat',       contact:'Clients haut places',           casserole:'Temoignage compromettant possible',  blocks:[]}
];

const STAT_DEFS = [
  {k:'INT', n:'Intelligence', d:'Analyse, strategie, manipulation intellectuelle', i:'ti-brain'},
  {k:'CHA', n:'Charisme',     d:'Seduction, eloquence, leadership naturel',        i:'ti-speakerphone'},
  {k:'VOL', n:'Volonte',      d:'Resistance a la pression, tenacite',              i:'ti-flame'},
  {k:'PER', n:'Perception',   d:'Lire les situations, detecter les trahisons',     i:'ti-eye'},
  {k:'DUP', n:'Duplicite',    d:'Mentir, dissimuler, jouer un role',               i:'ti-masks-theater'},
  {k:'ENT', n:'Entregent',    d:'Creer et maintenir des liens sociaux',            i:'ti-network'}
];

// =====================
// WORLD MAP STRUCTURE
// =====================
const WORLD = {
  republic: {
    capitale: {
      name:'Luthecia',
      imageUrl:'https://images.unsplash.com/photo-1431274172761-fca41d930114?w=1200&q=80',
      desc:'Capitale de Republia. Centre du pouvoir politique, judiciaire et mediatique.',
      isCapitale: true,
      districts: ['centre','quartier-nord','quartier-sud'],
      buildings: ['hotel-republica','palais-gouvernement','assemblee','tribunal','banque-nationale','banque-privee','clinique-privee','dispensaire-public','commissariat','la-tribune','loge-maconnique','universite','armurerie','marche','terrain-a-batir-1']
    },
    ville_a: {
      name:'Port-Sainte-Marie',
      imageUrl:'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=1200&q=80',
      desc:'Ville portuaire a l\'ouest. Commerce, contrebande et politique locale.',
      isCapitale: false,
      buildings: ['hotel-port','mairie','banque-locale','dispensaire-public-v','commissariat-local','bar-des-pecheurs','terrain-a-batir-2']
    },
    ville_b: {
      name:'Montrouge',
      imageUrl:'https://images.unsplash.com/photo-1486325212027-8081e485255e?w=1200&q=80',
      desc:'Ville industrielle au nord. Syndicats puissants, usines et tensions sociales.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','siege-syndical','usine-principale','terrain-a-batir-3']
    }
  }
};

// =====================
// BUILDINGS DEFINITION
// =====================
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
        imageUrl: "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=1200&q=80",
        persons: [
          {name:'Gustave (Concierge)', role:'PNJ - Gestionnaire', rel:'neutral', job:'concierge'},
          {name:'Beatrice Aumont',     role:'Deputee - Parti Liberal', rel:'neutral', job:null}
        ],
        orders: [
          {fn:'parler_pnj',    label:'Parler au concierge',  pa:0, cost:0,   type:'legal',   icon:'ti-message', successRate:100},
          {fn:'se_renseigner', label:'Se renseigner',        pa:0, cost:0,   type:'legal',   icon:'ti-info-circle', successRate:100},
          {fn:'reserver',      label:'Reserver une chambre', pa:1, cost:80,  type:'legal',   icon:'ti-key', successRate:100}
        ]
      },
      restaurant: {
        name: "Salle du Restaurant",
        image: "🍽️",
        imageBg: "linear-gradient(135deg,#1a1005,#2a1a08)",
        desc: "La salle de restaurant est bondee le midi. Tables discretes en fond de salle pour conversations privees.",
        imageUrl: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=1200&q=80",
        persons: [
          {name:'Paulo (Maitre d\'hotel)', role:'PNJ - Service', rel:'neutral', job:'serveur'},
          {name:'Jean Dupont',            role:'Depute - Parti du Centre', rel:'neutral', job:null},
          {name:'Marie Leblanc',          role:'Journaliste - La Tribune', rel:'enemy', job:null}
        ],
        orders: [
          {fn:'se_nourrir',   label:'Se nourrir',          pa:0, cost:25,  type:'legal',  icon:'ti-soup',     successRate:100, desc:'Repas standard. Sante maintenue.'},
          {fn:'diner_affaires',label:'Diner d\'affaires',  pa:2, cost:120, type:'legal',  icon:'ti-wine',     successRate:100, desc:'Invitation d\'un contact. +Relation.'},
          {fn:'rencontrer',   label:'Rencontrer',          pa:1, cost:0,   type:'legal',  icon:'ti-users',    successRate:100, desc:'Engager la conversation.'},
          {fn:'ecouter',      label:'Ecouter les tables',  pa:0, cost:0,   type:'grey',   icon:'ti-ear',      successRate:95,  desc:'Collecter des informations ambiantes.'},
          {fn:'rumeur',       label:'Lancer une rumeur',   pa:1, cost:0,   type:'grey',   icon:'ti-messages', successRate:80,  desc:'Faire circuler une information.'}
        ]
      },
      bar: {
        name: "Bar",
        image: "🍺",
        imageBg: "linear-gradient(135deg,#120d05,#1e1508)",
        desc: "Le bar est ouvert jusqu'a l'aube. Langue qui se delie, secrets qui se vendent.",
        imageUrl: "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=1200&q=80",
        persons: [
          {name:'Marco (Barman)', role:'PNJ - Barman', rel:'neutral', job:'barman'},
          {name:'Un lobbyiste',   role:'Inconnu - Discretion de mise', rel:'neutral', job:null}
        ],
        orders: [
          {fn:'se_nourrir',      label:'Boire un verre',        pa:0, cost:10,  type:'legal', icon:'ti-glass',    successRate:100, desc:'Consommation. +1 Moral.'},
          {fn:'rencontrer',      label:'Aborder quelqu\'un',    pa:1, cost:0,   type:'legal', icon:'ti-users',    successRate:100, desc:'Entrer en contact avec un inconnu.'},
          {fn:'ecouter',         label:'Ecouter le barman',     pa:0, cost:0,   type:'grey',  icon:'ti-ear',      successRate:90,  desc:'Le barman entend tout.'},
          {fn:'recruter_info',   label:'Recruter un informateur',pa:1,cost:150, type:'grey',  icon:'ti-user-plus',successRate:75,  desc:'Faire du barman un contact regulier.'}
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
          {fn:'dormir',         label:'Dormir (nuit complete)', pa:0, cost:80,  type:'legal', icon:'ti-moon',     successRate:100, desc:'Recuperation complete. +5 PA bonus demain.', paBonus:5},
          {fn:'se_reposer',     label:'Se reposer (sieste)',    pa:0, cost:0,   type:'legal', icon:'ti-zzz',      successRate:100, desc:'+2 Moral.'},
          {fn:'reunion_privee', label:'Reunion privee',         pa:2, cost:50,  type:'grey',  icon:'ti-lock',     successRate:100, desc:'Rencontre discrete sans temoins.'}
        ]
      }
    }
  },

  // ---- PALAIS DU GOUVERNEMENT ----
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
        image: "🏛️",
        imageBg: "linear-gradient(135deg,#141c10,#1e2a18)",
        desc: "Le hall monumental du Palais. Gardes republicains en faction. Acces controle.",
        imageUrl: "https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80",
        persons: [
          {name:'Garde Martineau',   role:'PNJ - Securite', rel:'neutral', job:'garde'},
          {name:'Secretaire Dupuis', role:'PNJ - Accueil officiel', rel:'neutral', job:'secretaire'}
        ],
        orders: [
          {fn:'parler_pnj',  label:'Parler au secretaire', pa:0, cost:0, type:'legal', icon:'ti-message',    successRate:100},
          {fn:'se_presenter',label:'Se presenter',          pa:1, cost:0, type:'legal', icon:'ti-id-badge',   successRate:100}
        ]
      },
      bureaux: {
        name: "Bureaux ministeriels",
        image: "💼",
        imageBg: "linear-gradient(135deg,#0f1a0c,#182416)",
        desc: "Les bureaux des ministres et de leurs cabinets. Acces selon poste et relations.",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        persons: [
          {name:'Prefet Moreau',    role:'Prefet de la Capitale', rel:'neutral', job:'prefet'},
          {name:'Ministre Leroux',  role:'Ministre des Finances (PNJ)', rel:'neutral', job:'ministre'}
        ],
        orders: [
          {fn:'postuler',        label:'Postuler a un poste', pa:2, cost:0,   type:'legal',   icon:'ti-id-badge',  successRate:85, desc:'Voir les postes disponibles et postuler.'},
          {fn:'negocier',        label:'Negocier un accord',  pa:3, cost:50,  type:'legal',   icon:'ti-handshake', successRate:70, desc:'Proposer un accord politique.'},
          {fn:'corrompre_fonct', label:'Corrompre un fonctionnaire', pa:2, cost:500, type:'illegal', icon:'ti-coins', successRate:65, desc:'Acheter un service administratif.'}
        ]
      },
      salle_conseil: {
        name: "Salle du Conseil",
        image: "🗳️",
        imageBg: "linear-gradient(135deg,#0d1a0a,#152014)",
        desc: "La salle ou se prennent les decisions du gouvernement. Acces ministeriel uniquement.",
        imageUrl: "https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=1200&q=80",
        persons: [
          {name:'Premier Ministre (PNJ)', role:'Chef du gouvernement', rel:'neutral', job:'pm'}
        ],
        orders: [
          {fn:'voter_loi',    label:'Participer au conseil', pa:2, cost:0, type:'legal',   icon:'ti-check',      successRate:100, requiresPost:true, desc:'Accessible uniquement si vous etes ministre.'},
          {fn:'projet_loi',   label:'Soumettre une proposition', pa:3, cost:0, type:'legal', icon:'ti-file-text', successRate:70,  requiresPost:true, desc:'Proposer une loi au gouvernement.'}
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
    desc: "Les 25 sieges de l'Assemblee Nationale de Republia. Actuellement majoritairement occupes par des PNJ.",
    rooms: {
      hemicycle: {
        name: "Hemicycle",
        image: "🗳️",
        imageBg: "linear-gradient(135deg,#101820,#182030)",
        desc: "L'hemicycle principal. Les votes se font ici. Acces deputés uniquement pour les sessions.",
        imageUrl: "https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?w=1200&q=80",
        persons: [
          {name:'President Laroche', role:"President de l'Assemblee (PNJ)", rel:'neutral', job:'president'},
          {name:'Depute Martin',     role:'Groupe majoritaire (PNJ)', rel:'neutral', job:'depute'},
          {name:'Depute Chen',       role:'Opposition (PNJ)', rel:'neutral', job:'depute'}
        ],
        orders: [
          {fn:'assister_session', label:'Assister a la session', pa:1, cost:0,   type:'legal', icon:'ti-building', successRate:100, desc:'Observer les debats. +1 INF.'},
          {fn:'voter_loi',        label:'Voter une loi',         pa:1, cost:0,   type:'legal', icon:'ti-check',    successRate:100, requiresPost:true, desc:'Voter uniquement si vous etes depute.'},
          {fn:'projet_loi',       label:'Deposer un projet',     pa:3, cost:0,   type:'legal', icon:'ti-file-text',successRate:70,  requiresPost:true, desc:'Deposer un projet de loi.'},
          {fn:'marchander',       label:'Marchander un vote',    pa:2, cost:200, type:'grey',  icon:'ti-arrows-exchange', successRate:60, desc:'Negocier le vote d\'un depute.'}
        ]
      },
      couloirs: {
        name: "Couloirs",
        image: "🚶",
        imageBg: "linear-gradient(135deg,#0c1018,#141820)",
        desc: "Les couloirs de l'Assemblee. C'est ici que se font vraiment les deals.",
        imageUrl: "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=1200&q=80",
        persons: [
          {name:'Lobbyiste Perrin', role:'Lobbyiste (PNJ)', rel:'neutral', job:'lobbyiste'},
          {name:'Journaliste Blanc',role:'Correspondant parlementaire (PNJ)', rel:'neutral', job:'journaliste'}
        ],
        orders: [
          {fn:'rencontrer',  label:'Aborder un depute',   pa:1, cost:0,   type:'legal', icon:'ti-users',    successRate:100},
          {fn:'marchander',  label:'Proposer un accord',  pa:2, cost:100, type:'grey',  icon:'ti-handshake',successRate:65},
          {fn:'ecouter',     label:'Ecouter les rumeurs', pa:0, cost:0,   type:'grey',  icon:'ti-ear',      successRate:90}
        ]
      }
    }
  },

  // ---- TRIBUNAL ----
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
        imageUrl: "https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=1200&q=80",
        persons: [
          {name:'Juge Fontaine',  role:'Presidente du Tribunal (PNJ)', rel:'neutral', job:'juge'},
          {name:'Procureur Saad', role:'Ministere public (PNJ)', rel:'neutral', job:'procureur'}
        ],
        orders: [
          {fn:'plainte',   label:'Porter plainte',        pa:1, cost:0,   type:'legal',   icon:'ti-gavel',   successRate:100},
          {fn:'defense',   label:'Se defendre',           pa:2, cost:300, type:'legal',   icon:'ti-shield',  successRate:75},
          {fn:'corrompre_juge', label:'Corrompre le juge',pa:3, cost:1000,type:'illegal', icon:'ti-coins',   successRate:45}
        ]
      },
      greffe: {
        name: "Greffe",
        image: "📋",
        imageBg: "linear-gradient(135deg,#141008,#1c1608)",
        desc: "Les archives judiciaires. Tout y est consigne.",
        imageUrl: "https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80",
        persons: [
          {name:'Greffier Petit', role:'PNJ - Greffe', rel:'neutral', job:'greffier'}
        ],
        orders: [
          {fn:'archives',       label:'Consulter les archives', pa:1, cost:0,   type:'legal',   icon:'ti-archive', successRate:100},
          {fn:'falsifier_docs', label:'Falsifier un document',  pa:3, cost:500, type:'illegal', icon:'ti-file-x',  successRate:40}
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
        imageUrl: "https://images.unsplash.com/photo-1501167786227-4cba60f6d58f?w=1200&q=80",
        persons: [
          {name:'Directeur Mercier', role:"PNJ - Directeur d'agence", rel:'neutral', job:'directeur'}
        ],
        orders: [
          {fn:'gerer_finances', label:'Gerer mon compte',    pa:0, cost:0,    type:'legal', icon:'ti-chart-bar',   successRate:100, desc:'Deposer ou retirer de l\'argent. Voir son solde.'},
          {fn:'investir',       label:'Investir',            pa:2, cost:500,  type:'legal', icon:'ti-trending-up', successRate:75,  desc:'Placer des fonds. Rendement dans 24h.'},
          {fn:'emprunter',      label:'Emprunter',           pa:1, cost:0,    type:'legal', icon:'ti-credit-card', successRate:70,  desc:'Contracter un pret. Taux selon dossier.'},
          {fn:'fiscal',         label:'Optimisation fiscale',pa:1, cost:200,  type:'grey',  icon:'ti-calculator',  successRate:85,  desc:'Reduire sa fiscalite. Semi-legal.'}
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
        imageUrl: "https://images.unsplash.com/photo-1553729459-efe14ef6055d?w=1200&q=80",
        persons: [
          {name:'M. Fischer', role:'PNJ - Gestionnaire de patrimoine', rel:'neutral', job:'banquier'}
        ],
        orders: [
          {fn:'gerer_finances',    label:'Gerer mon compte',      pa:0, cost:0,    type:'legal',   icon:'ti-chart-bar',    successRate:100, desc:'Depot ou retrait discret.'},
          {fn:'compte_offshore',   label:'Ouvrir compte offshore', pa:2, cost:1000, type:'grey',    icon:'ti-world',        successRate:80,  desc:'Compte hors Republia. Moins tracable.'},
          {fn:'blanchiment',       label:'Blanchir des fonds',     pa:3, cost:0,    type:'illegal', icon:'ti-refresh',      successRate:55,  desc:'Transformer des fonds douteux en argent propre.'},
          {fn:'societe_ecran',     label:'Creer une societe ecran',pa:3, cost:500,  type:'illegal', icon:'ti-building-off', successRate:60,  desc:'Structure pour masquer des transactions.'}
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
        imageUrl: "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=1200&q=80",
        persons: [
          {name:'Dr. Vidal', role:'PNJ - Medecin chef', rel:'neutral', job:'medecin'}
        ],
        orders: [
          {fn:'soins',          label:'Consultation et soins',       pa:0, cost:200, type:'legal', icon:'ti-stethoscope', successRate:100, desc:'+20 Sante.'},
          {fn:'soins_urgence',  label:'Soins acceleres (urgence)',   pa:0, cost:500, type:'legal', icon:'ti-urgent',      successRate:100, desc:'+40 Sante immediatement.'},
          {fn:'soins_discrets', label:'Soins sans trace',            pa:1, cost:800, type:'grey',  icon:'ti-eye-off',     successRate:95,  desc:'+30 Sante. Aucune trace medicale.'}
        ]
      }
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
          {fn:'soins_basiques', label:'Soins basiques (gratuit)', pa:0, cost:0,  type:'legal', icon:'ti-bandage',    successRate:100, desc:'+10 Sante. Lent mais gratuit.'},
          {fn:'soins',          label:'Consultation medecin',    pa:0, cost:20,  type:'legal', icon:'ti-stethoscope',successRate:100, desc:'+15 Sante.'}
        ]
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
        image: "🚔",
        imageBg: "linear-gradient(135deg,#0f1018,#151822)",
        desc: "L'accueil du commissariat. Atmosphere froide et surveillee.",
        imageUrl: "https://images.unsplash.com/photo-1543589077-47d81606c1bf?w=1200&q=80",
        persons: [
          {name:'Commissaire Gros', role:'PNJ - Chef de la police', rel:'neutral', job:'commissaire'},
          {name:'Agent Petit',      role:'PNJ - Officier de garde', rel:'neutral', job:'policier'}
        ],
        orders: [
          {fn:'plainte_police',    label:'Porter plainte',          pa:1, cost:0,   type:'legal',   icon:'ti-file-text', successRate:100},
          {fn:'archives_police',   label:'Consulter les archives',  pa:1, cost:0,   type:'legal',   icon:'ti-archive',   successRate:90},
          {fn:'corrompre_police',  label:'Corrompre un policier',   pa:2, cost:300, type:'illegal', icon:'ti-coins',     successRate:55},
          {fn:'arreter',           label:"Faire arreter quelqu'un", pa:3, cost:500, type:'illegal', icon:'ti-handcuffs', successRate:50}
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
      redaction: {
        name: "Redaction",
        image: "📰",
        imageBg: "linear-gradient(135deg,#100808,#1c0c0c)",
        desc: "La redaction en ebullition permanente. Telephones, claviers, tension.",
        imageUrl: "https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=1200&q=80",
        persons: [
          {name:'Romain Castel', role:'PNJ - Redacteur en chef', rel:'neutral', job:'redacteur'},
          {name:'Marie Leblanc', role:'Journaliste d\'investigation', rel:'enemy', job:'journaliste'}
        ],
        orders: [
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
    name: "Loge Maconnique",
    shortName: "La Loge",
    cat: "Reseau secret",
    icon: "ti-hexagon",
    bgColor: "#0f0808",
    locked: true,
    desc: "Acces sur invitation uniquement. Les cercles les plus puissants de Republia s'y reunissent.",
    rooms: {
      antichambre: {
        name: "Antichambre",
        image: "🔮",
        imageBg: "linear-gradient(135deg,#0f0808,#180f0f)",
        desc: "L'antichambre de la Loge. Vous n'etes pas encore membre.",
        imageUrl: "https://images.unsplash.com/photo-1555099962-4199c345e5dd?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'introduction_loge', label:"Demander une introduction", pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100}
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
        imageUrl: "https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=1200&q=80",
        persons: [
          {name:'Professeur Blanc', role:'PNJ - Economiste influent', rel:'neutral', job:'professeur'}
        ],
        orders: [
          {fn:'se_former',      label:'Suivre une formation',   pa:2, cost:100, type:'legal', icon:'ti-book',        successRate:100, desc:'+XP competences intellectuelles.'},
          {fn:'donner_conf',    label:'Donner une conference',  pa:2, cost:0,   type:'legal', icon:'ti-microphone',  successRate:75,  desc:'+POP +INF selon audience.'},
          {fn:'recruter_etud',  label:'Recruter des militants', pa:2, cost:0,   type:'grey',  icon:'ti-users-group', successRate:70,  desc:'Constituer un reseau militant.'}
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
    desc: "Vente d'armes legales et equipements de securite. Tout est tracable.",
    rooms: {
      magasin: {
        name: "Magasin",
        image: "🔫",
        imageBg: "linear-gradient(135deg,#100a08,#181008)",
        desc: "Presentoirs d'armes legales. Le vendeur verifie les papiers.",
        imageUrl: "https://images.unsplash.com/photo-1595590424283-b8f17842773f?w=1200&q=80",
        persons: [
          {name:'Gerard (Armurier)', role:'PNJ - Vendeur', rel:'neutral', job:'armurier'}
        ],
        orders: [
          {fn:'acheter_arme',  label:'Acheter une arme (legale)',  pa:1, cost:400, type:'legal', icon:'ti-shield', successRate:100, desc:'Ajoute une arme a votre inventaire.'},
          {fn:'acheter_gilet', label:'Acheter un gilet pare-balles',pa:1,cost:600, type:'legal', icon:'ti-shield', successRate:100, desc:'Protection physique +20.'}
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
        image: "🛒",
        imageBg: "linear-gradient(135deg,#0d0d08,#181808)",
        desc: "Bruyant, colore, vivant. Tout le monde passe par le marche.",
        imageUrl: "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1200&q=80",
        persons: [
          {name:'Fernande (Marchande)', role:'PNJ - Commercante', rel:'neutral', job:'marchande'},
          {name:'Habitant du quartier', role:'Citoyen', rel:'neutral', job:null}
        ],
        orders: [
          {fn:'se_nourrir',   label:'Acheter de la nourriture',  pa:0, cost:8,  type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'Repas economique. Sante maintenue.'},
          {fn:'ecouter',      label:'Prendre le pouls populaire',pa:0, cost:0,  type:'legal', icon:'ti-ear',           successRate:100, desc:'Sentiment de la population.'},
          {fn:'rencontrer',   label:'Rencontrer un habitant',    pa:0, cost:0,  type:'legal', icon:'ti-users',         successRate:100}
        ]
      }
    }
  },

  // ---- TERRAIN A BATIR ----
  'terrain-a-batir-1': {
    name: "Terrain a batir - Lot 1",
    shortName: "Terrain Lot 1",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Terrain vague en plein centre de Luthecia. A acheter, a construire... ou a speculer.",
    rooms: {
      terrain: {
        name: "Terrain vague",
        image: "🏗️",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Un terrain de 2000m2 en friche. Enormes possibilites.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'acheter_terrain', label:'Acheter ce terrain',      pa:2, cost:5000, type:'legal', icon:'ti-home-plus',   successRate:100, desc:'Acquerir le terrain. Permis requis pour construire.'},
          {fn:'permis_construire',label:'Demander un permis',     pa:2, cost:200,  type:'legal', icon:'ti-file-text',   successRate:70,  desc:'Obtenir l\'autorisation de construire.'},
          {fn:'permis_corrompu', label:'Obtenir permis rapidement',pa:2,cost:1000, type:'illegal',icon:'ti-coins',      successRate:60,  desc:'Corrompre pour obtenir le permis en 24h.'}
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
          {fn:'postuler',      label:'Postuler comme maire',   pa:2, cost:0,  type:'legal', icon:'ti-id-badge',   successRate:80},
          {fn:'gerer_finances',label:'Gerer les finances locales',pa:1,cost:0,type:'legal', icon:'ti-chart-bar',  successRate:100, requiresPost:true},
          {fn:'corrompre_fonct',label:'Corrompre un employ',   pa:2, cost:200,type:'illegal',icon:'ti-coins',     successRate:65}
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
        image: "🏨",
        imageBg: "linear-gradient(135deg,#0d1018,#141820)",
        desc: "Hall de l'hotel. Matelots, commercants et gens de passage.",
        imageUrl: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=1200&q=80",
        persons: [{name:'Patrone (PNJ)', role:'Gérante', rel:'neutral', job:'hotelier'}],
        orders: [
          {fn:'se_nourrir', label:'Se nourrir',     pa:0, cost:20, type:'legal', icon:'ti-soup',  successRate:100},
          {fn:'dormir',     label:'Dormir',          pa:0, cost:60, type:'legal', icon:'ti-moon',  successRate:100, desc:'+3 PA bonus demain.', paBonus:3},
          {fn:'rencontrer', label:'Rencontrer',      pa:1, cost:0,  type:'legal', icon:'ti-users', successRate:100}
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
    rooms: {
      salle_bar: {
        name: "Salle du bar",
        image: "🍺",
        imageBg: "linear-gradient(135deg,#0a0d10,#101518)",
        desc: "Atmosphere enfumee, bruit de fond. Tout se negocie ici.",
        imageUrl: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=1200&q=80",
        imageUrl: "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=1200&q=80",
        persons: [{name:'Marin (PNJ)', role:'Client habitue', rel:'neutral', job:null}],
        orders: [
          {fn:'se_nourrir', label:'Boire et manger', pa:0, cost:15,  type:'legal', icon:'ti-glass',    successRate:100},
          {fn:'ecouter',    label:'Ecouter',         pa:0, cost:0,   type:'grey',  icon:'ti-ear',      successRate:85},
          {fn:'rencontrer', label:'Aborder',         pa:1, cost:0,   type:'legal', icon:'ti-users',    successRate:100},
          {fn:'contrebande',label:'Contacter reseau',pa:2, cost:100, type:'illegal',icon:'ti-package', successRate:55}
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
          {fn:'rencontrer',   label:'Rencontrer le delegue', pa:1, cost:0,   type:'legal', icon:'ti-users',      successRate:100},
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
          {fn:'acheter_entreprise', label:'Racheter l\'usine', pa:3, cost:8000, type:'legal', icon:'ti-building-factory', successRate:80, desc:'Genere 200 FR/jour en revenus passifs.'},
          {fn:'negocier',           label:'Negocier contrat',  pa:2, cost:0,    type:'legal', icon:'ti-handshake',        successRate:70}
        ]
      }
    }
  },

  'hotel-mineur': {
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
        imageUrl: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=1200&q=80",
        persons: [{name:'Receptionniste (PNJ)', role:'Accueil', rel:'neutral', job:'hotelier'}],
        orders: [
          {fn:'se_nourrir', label:'Se nourrir',  pa:0, cost:15, type:'legal', icon:'ti-soup', successRate:100},
          {fn:'dormir',     label:'Dormir',      pa:0, cost:40, type:'legal', icon:'ti-moon', successRate:100, desc:'+2 PA bonus demain.', paBonus:2}
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
        imageUrl: "https://images.unsplash.com/photo-1584515933487-779824d29309?w=1200&q=80",
        persons: [{name:'Infirmiere (PNJ)', role:'Soignante', rel:'neutral', job:'infirmier'}],
        orders: [
          {fn:'soins_basiques', label:'Soins basiques (gratuit)', pa:0, cost:0, type:'legal', icon:'ti-bandage', successRate:100, desc:'+10 Sante.'}
        ]
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
        imageUrl: "https://images.unsplash.com/photo-1543589077-47d81606c1bf?w=1200&q=80",
        persons: [{name:'Brigadier Local (PNJ)', role:'Officier de garde', rel:'neutral', job:'policier'}],
        orders: [
          {fn:'plainte_police',   label:'Porter plainte',      pa:1, cost:0,   type:'legal',   icon:'ti-file-text', successRate:100},
          {fn:'corrompre_police', label:'Corrompre un policier',pa:2, cost:200, type:'illegal', icon:'ti-coins',     successRate:65}
        ]
      }
    }
  },

  'terrain-a-batir-2': {
    name: "Terrain a batir - Lot 2",
    shortName: "Terrain Lot 2",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Terrain en bord de port. Ideal pour commerce ou entrepot.",
    rooms: {
      terrain2: {
        name: "Terrain",
        image: "🏗️",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Terrain de 1500m2 en bord de port.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'acheter_terrain',  label:'Acheter ce terrain',       pa:2, cost:3500, type:'legal',   icon:'ti-home-plus', successRate:100},
          {fn:'permis_construire',label:'Demander un permis',        pa:2, cost:200,  type:'legal',   icon:'ti-file-text', successRate:65},
          {fn:'permis_corrompu',  label:'Permis accelere (corruption)',pa:2,cost:800, type:'illegal', icon:'ti-coins',     successRate:55}
        ]
      }
    }
  },

  'terrain-a-batir-3': {
    name: "Terrain a batir - Lot 3",
    shortName: "Terrain Lot 3",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Terrain industriel a Montrouge. Adjacent a l'usine.",
    rooms: {
      terrain3: {
        name: "Terrain",
        image: "🏗️",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Terrain de 3000m2 en zone industrielle.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'acheter_terrain',  label:'Acheter ce terrain',       pa:2, cost:4000, type:'legal',   icon:'ti-home-plus', successRate:100},
          {fn:'permis_construire',label:'Demander un permis',        pa:2, cost:200,  type:'legal',   icon:'ti-file-text', successRate:65},
          {fn:'permis_corrompu',  label:'Permis accelere (corruption)',pa:2,cost:800, type:'illegal', icon:'ti-coins',     successRate:55}
        ]
      }
    }
  }
};

// =====================
// POSTES POLITIQUES
// =====================
const POSTES = {
  republic: {
    capitale: [
      {id:'president',    name:'President de la Republique', niveau:7, unique:true,  holder:null, isCapitale:true},
      {id:'pm',           name:'Premier Ministre',            niveau:6, unique:true,  holder:'PNJ-Bertrand', isCapitale:true},
      {id:'min_int',      name:'Ministre de l\'Interieur',   niveau:5, unique:true,  holder:'PNJ-Lacroix',  isCapitale:true},
      {id:'min_fin',      name:'Ministre des Finances',       niveau:5, unique:true,  holder:'PNJ-Leroux',   isCapitale:true},
      {id:'min_just',     name:'Ministre de la Justice',      niveau:5, unique:true,  holder:'PNJ-Morin',    isCapitale:true},
      {id:'min_def',      name:'Ministre de la Defense',      niveau:5, unique:true,  holder:'PNJ-Bernard',  isCapitale:true},
      {id:'min_info',     name:'Ministre de l\'Information',  niveau:5, unique:true,  holder:'PNJ-Simon',    isCapitale:true},
      {id:'min_ae',       name:'Ministre des AE',             niveau:5, unique:true,  holder:'PNJ-Durand',   isCapitale:true},
    ],
    assemblee: Array.from({length:25}, (_,i) => ({
      id:`depute_${i+1}`, name:`Depute Siege ${i+1}`, niveau:2,
      unique:true, holder: i < 20 ? `PNJ-Depute${i+1}` : null, isCapitale:true
    })),
    ville_a: [
      {id:'maire_a',    name:'Maire de Port-Sainte-Marie', niveau:3, unique:true, holder:'PNJ-Maire-A'},
      {id:'adj_maire_a',name:'Maire Adjoint',              niveau:2, unique:true, holder:'PNJ-Adj-A'}
    ],
    ville_b: [
      {id:'maire_b',    name:'Maire de Montrouge',         niveau:3, unique:true, holder:'PNJ-Maire-B'},
      {id:'adj_maire_b',name:'Maire Adjoint',              niveau:2, unique:true, holder:'PNJ-Adj-B'}
    ]
  }
};

// =====================
// ORDER EFFECTS
// =====================
const ORDER_EFFECTS = {
  se_nourrir:         {hp:5,   moral:1,  successRate:100},
  dormir:             {moral:5,          successRate:100, paBonus:0},
  se_reposer:         {moral:3,          successRate:100},
  soins:              {hp:20,            successRate:100},
  soins_urgence:      {hp:40,            successRate:100},
  soins_basiques:     {hp:10,            successRate:100},
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

// Salaires journaliers par poste (verses lors de l'ordre Dormir)
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
  maire:       800,
  adj_maire:   500,
  gouverneur:  1500,
  prefet:      900,
  default:     150  // Citoyen sans poste
};
