/* ===========================
   RES PUBLICA — DATA.JS
   Toutes les donnees du jeu
   =========================== */

const COUNTRIES = {
  republic: {
    n:'Republia', col:'#4a9ade', cur:'FR', icon:'ti-building-community',
    desc:'Democratie fatiguee, elites consanguines, scandale mediatique comme sport national.',
    tags:['Democratie','Satirique'],
    bases:{INT:8,CHA:7,VOL:6,PER:7,DUP:7,ENT:7},
    cityName:'Luthecia'
  },
  narco: {
    n:'El Estado', col:'#cc6644', cur:'PS', icon:'ti-skull',
    desc:'Democratie de facade, cartels, elections achetees. La violence est une langue politique.',
    tags:['Violent','Corruption'],
    bases:{INT:6,CHA:7,VOL:8,PER:8,DUP:8,ENT:5},
    cityName:'Ciudad Roja'
  },
  soviet: {
    n:'Sovarka', col:'#cc4444', cur:'RP', icon:'ti-hammer',
    desc:'Parti unique en tension interne. Reformistes contre conservateurs. La paranoia est une vertu.',
    tags:['Parti unique','Factions'],
    bases:{INT:8,CHA:6,VOL:9,PER:8,DUP:7,ENT:6},
    cityName:'Novomirsk'
  },
  khalija: {
    n:'Al-Khalija', col:'#C9A84C', cur:'DR', icon:'ti-crown',
    desc:'Monarchie absolue, famille royale tentaculaire. La Grace Royale est la seule monnaie qui compte.',
    tags:['Monarchie','Theocratie'],
    bases:{INT:7,CHA:8,VOL:8,PER:7,DUP:8,ENT:8},
    cityName:'Al-Madina'
  }
};

const ORIGINS = [
  {
    id:'poor', icon:'ti-home-off', name:'Milieu defavorise', arg:200,
    desc:"L'ecole de la rue. La survie comme premiere lecon.",
    bonuses:{VOL:2,DUP:1}, malus:{CHA:-1}, trait:'Resilience brute'
  },
  {
    id:'worker', icon:'ti-tool', name:'Classe ouvriere', arg:500,
    desc:'Le merite par le travail. La solidarite comme valeur.',
    bonuses:{VOL:1,ENT:1}, malus:{}, trait:'Sens du collectif'
  },
  {
    id:'bourgeois', icon:'ti-building', name:'Petite bourgeoisie', arg:1200,
    desc:"L'ambition tranquille. Ni trop pauvre, ni trop riche.",
    bonuses:{INT:1,CHA:1}, malus:{}, trait:'Vernis social'
  },
  {
    id:'elite', icon:'ti-building-skyscraper', name:'Haute societe', arg:3000,
    desc:"Le reseau depuis le berceau. Les portes s'ouvrent seules.",
    bonuses:{ENT:2,CHA:1}, malus:{VOL:-1}, trait:"Carnet d'adresses ancestral"
  }
];

const SCHOOLS = [
  {
    id:'none', icon:'ti-x', name:"Pas d'ecole", compPts:20,
    desc:"Autodidacte. Ce que vous savez, la vie vous l'a appris.",
    bonuses:{DUP:2,VOL:1}, malus:{INT:-1},
    blocks:['civil','lawyer','magistrat','lobbyist','academic','doctor'],
    blockLabel:"Bloque : fonctionnaire, avocat, magistrat, lobbyiste, universitaire, medecin"
  },
  {
    id:'basic', icon:'ti-book', name:'Ecole basique', compPts:35,
    desc:'Le minimum obligatoire. Lecture, calcul, debrouille.',
    bonuses:{PER:1,ENT:1}, malus:{},
    blocks:['civil','magistrat','lobbyist'],
    blockLabel:'Bloque : haut fonctionnaire, magistrat, lobbyiste'
  },
  {
    id:'higher', icon:'ti-school', name:'Etudes superieures', compPts:50,
    desc:'Universite ou ecole professionnelle. Expertise reconnue.',
    bonuses:{INT:2,CHA:1}, malus:{},
    blocks:[], blockLabel:'Toutes carrieres accessibles'
  },
  {
    id:'elite', icon:'ti-award', name:'Hautes ecoles', compPts:65,
    desc:"Grandes ecoles, formation d'elite. Le sesame des cercles du pouvoir.",
    bonuses:{INT:3,CHA:1,ENT:1}, malus:{VOL:-1},
    blocks:[], blockLabel:'Toutes carrieres + acces reseau elite'
  }
];

const ARCHETYPES = [
  {
    id:'politician', icon:'ti-speakerphone', name:'Ambitieux',
    bonuses:{CHA:2,ENT:2}, malus:{DUP:-2},
    argBonus:300, infBonus:15, popBonus:20, disBonus:-10,
    desc:"Seduction et persuasion. Vous vivez pour convaincre, rallier, seduire. Le pouvoir est votre oxygene."
  },
  {
    id:'authoritarian', icon:'ti-sword', name:'Ordre et discipline',
    bonuses:{VOL:2,PER:2}, malus:{ENT:-2},
    argBonus:500, infBonus:20, popBonus:5, disBonus:5,
    desc:"La hierarchie, les regles, la force. Vous croyez que l'ordre est la seule vraie valeur."
  },
  {
    id:'oligarch', icon:'ti-briefcase', name:'Capitaliste',
    bonuses:{INT:2,DUP:2}, malus:{CHA:-2},
    argBonus:2000, infBonus:10, popBonus:-5, disBonus:5,
    desc:"L'argent est la mesure de toutes choses. Discret, methodique, vous transformez tout en actif."
  },
  {
    id:'informer', icon:'ti-news', name:"Diffuseur d'informations",
    bonuses:{PER:2,INT:2}, malus:{VOL:-2},
    argBonus:200, infBonus:5, popBonus:15, disBonus:-5,
    desc:"Vous observez, analysez, diffusez. L'information est votre arme et votre raison d'etre."
  },
  {
    id:'legalist', icon:'ti-scale', name:'Legaliste',
    bonuses:{INT:2,VOL:2}, malus:{CHA:-2},
    argBonus:600, infBonus:15, popBonus:5, disBonus:10,
    desc:"Les regles, les textes, les procedures. Vous croyez en la loi, ou savez comment la plier."
  },
  {
    id:'believer', icon:'ti-building-church', name:'Homme de foi',
    bonuses:{CHA:2,ENT:2}, malus:{DUP:-2},
    argBonus:100, infBonus:10, popBonus:25, disBonus:0,
    desc:"Une conviction profonde vous anime. Elle mobilise les foules."
  },
  {
    id:'shadow', icon:'ti-user-question', name:"Homme de l'ombre",
    bonuses:{DUP:2,PER:2}, malus:{CHA:-2},
    argBonus:400, infBonus:5, popBonus:-10, disBonus:20,
    desc:"Vous n'existez pas officiellement. Infiltration, manipulation, double jeu."
  },
  {
    id:'anticapitalist', icon:'ti-users-group', name:'Anti-capitaliste',
    bonuses:{CHA:2,VOL:2}, malus:{INT:-2},
    argBonus:200, infBonus:10, popBonus:20, disBonus:-5,
    desc:"Vous combattez le systeme. La justice sociale est votre etendard."
  },
  {
    id:'criminal', icon:'ti-eye-off', name:'Criminel',
    bonuses:{DUP:2,VOL:2}, malus:{ENT:-2},
    argBonus:1500, infBonus:5, popBonus:-15, disBonus:15,
    desc:"En dehors des lois, des codes, des convenances. Vos propres regles, bien plus efficaces."
  }
];

const CAREERS = [
  {id:'civil',      name:'Haut fonctionnaire',        icon:'ti-id-badge',        argBonus:800,  statKey:'INT', comp:'Droit, Negociation',       contact:'Un ministre en poste',          casserole:'Dossier fiscal sensible',           blocks:['none','basic']},
  {id:'local_civil',name:'Fonctionnaire local',        icon:'ti-building-estate', argBonus:350,  statKey:'ENT', comp:'Administration, Entregent',  contact:'Un elu local complaisant',       casserole:'Favoritisme avere',                 blocks:[]},
  {id:'officer',    name:'Officier sup. / Mercenaire', icon:'ti-military-rank',   argBonus:700,  statKey:'VOL', comp:'Commandement, Intimidation', contact:'Un general loyal',               casserole:'Bavure classifiee',                 blocks:[]},
  {id:'business',   name:"Homme d'affaires",           icon:'ti-chart-line',      argBonus:2000, statKey:'INT', comp:'Lobbying, Blanchiment',     contact:'Un banquier discret',            casserole:'Paradis fiscal exposable',          blocks:[]},
  {id:'magistrat',  name:'Magistrat',                  icon:'ti-gavel',           argBonus:750,  statKey:'INT', comp:'Droit, Procedure judiciaire',contact:'Un procureur influent',          casserole:'Jugement partial avere',            blocks:['none','basic']},
  {id:'lawyer',     name:'Avocat',                     icon:'ti-scale',           argBonus:900,  statKey:'INT', comp:'Droit, Negociation',        contact:'Reseau judiciaire',              casserole:'Client douteux defend',             blocks:['none','basic']},
  {id:'press',      name:'Grand journaliste',          icon:'ti-pencil',          argBonus:400,  statKey:'PER', comp:'Kompromat, Propagande',     contact:'Un redacteur en chef',           casserole:'Ennemi puissant cree',              blocks:['none']},
  {id:'influencer', name:'Influenceur',                icon:'ti-device-mobile',   argBonus:300,  statKey:'CHA', comp:'Reseaux sociaux, Image',    contact:'Communaute de followers',        casserole:'Scandale en ligne archive',         blocks:[]},
  {id:'clergy',     name:'Chef de culte',              icon:'ti-star',            argBonus:100,  statKey:'CHA', comp:'Rhetorique, Mobilisation',  contact:'Communaute de fideles',          casserole:'Scandale moral',                    blocks:[]},
  {id:'lobbyist',   name:'Lobbyiste',                  icon:'ti-arrows-exchange', argBonus:1100, statKey:'ENT', comp:'Lobbying, Negociation',     contact:'Un directeur de cabinet',        casserole:"Conflit d'interets documente",      blocks:['none','basic']},
  {id:'doctor',     name:'Medecin',                    icon:'ti-stethoscope',     argBonus:700,  statKey:'INT', comp:'Reseau civil, Discretion',  contact:'Patients influents',             casserole:'Prescription douteuse',             blocks:['none','basic']},
  {id:'academic',   name:'Universitaire',              icon:'ti-book-2',          argBonus:300,  statKey:'INT', comp:'Rhetorique, Propagande',    contact:'Etudiants militants',            casserole:'These controversee',                blocks:['none','basic']},
  {id:'union',      name:'Syndicaliste',               icon:'ti-affiliate',       argBonus:200,  statKey:'VOL', comp:'Mobilisation, Negociation', contact:'Milliers de membres syndiques',  casserole:'Greve sauvage passee',              blocks:['none']},
  {id:'intel',      name:'Agent des services',         icon:'ti-spy',             argBonus:500,  statKey:'PER', comp:'Surveillance, Infiltration', contact:'Ancien superieur classe',        casserole:'Operation classifiee compromettante',blocks:[]},
  {id:'criminal_c', name:'Criminel organise',          icon:'ti-lock-open',       argBonus:1200, statKey:'DUP', comp:'Milices, Blanchiment',      contact:'Reseau criminel actif',          casserole:"Mandat d'arret latent",             blocks:['higher','elite']},
  {id:'worker',     name:'Ouvrier',                    icon:'ti-hammer',          argBonus:250,  statKey:'VOL', comp:'Force, Solidarite',         contact:"Camarades d'atelier",            casserole:'Accident du travail cache',         blocks:[]},
  {id:'unemployed', name:'Sans emploi',                icon:'ti-mood-sad',        argBonus:50,   statKey:'DUP', comp:'Survie, Systeme D',         contact:'Reseau de la rue',               casserole:'Casier judiciaire mineur',          blocks:[]},
  {id:'escort',     name:'Prostitue(e)',                icon:'ti-heart',           argBonus:400,  statKey:'CHA', comp:'Seduction, Kompromat',      contact:'Clients haut places',            casserole:'Temoignage compromettant possible', blocks:[]}
];

const STAT_DEFS = [
  {k:'INT', n:'Intelligence', d:'Analyse, strategie, manipulation intellectuelle', i:'ti-brain'},
  {k:'CHA', n:'Charisme',     d:'Seduction, eloquence, leadership naturel',        i:'ti-speakerphone'},
  {k:'VOL', n:'Volonte',      d:'Resistance a la pression, tenacite',              i:'ti-flame'},
  {k:'PER', n:'Perception',   d:'Lire les situations, detecter les trahisons',     i:'ti-eye'},
  {k:'DUP', n:'Duplicite',    d:'Mentir, dissimuler, jouer un role',               i:'ti-masks-theater'},
  {k:'ENT', n:'Entregent',    d:'Creer et maintenir des liens sociaux',            i:'ti-network'}
];

const BUILDINGS = {
  gouvernement: {
    name:'Palais du Gouvernement', cat:'Institutions',
    desc:"Le coeur du pouvoir executif. Les ministres y travaillent, les carrieres s'y font et s'y defont.",
    persons:[
      {name:'Le Prefet Moreau', role:'Prefet de la Capitale', rel:'neutral'},
      {name:'Secretaire Dupuis', role:'PNJ - Secretariat general', rel:'neutral'}
    ],
    services:[
      {name:'Postuler a un poste',          cost:'0 FR - 3 PA',    type:'legal',   fn:'postuler'},
      {name:'Prendre ses fonctions',        cost:'0 FR - 2 PA',    type:'legal',   fn:'fonctions'},
      {name:'Negocier un accord',           cost:'50 FR - 4 PA',   type:'legal',   fn:'negocier'},
      {name:'Corrompre un fonctionnaire',   cost:'500 FR - 3 PA',  type:'illegal', fn:'corrompre_fonct'}
    ],
    actions:[
      {label:'Postuler',  pa:3, type:'legal',   icon:'ti-id-badge',   fn:'postuler'},
      {label:'Negocier',  pa:4, type:'legal',   icon:'ti-handshake',  fn:'negocier'},
      {label:'Corrompre', pa:3, type:'illegal', icon:'ti-coins',      fn:'corrompre_fonct'}
    ]
  },
  assemblee: {
    name:'Assemblee Nationale', cat:'Institutions',
    desc:"Les 25 sieges de l'Assemblee Nationale. Actuellement occupes par des PNJ.",
    persons:[{name:'President Laroche', role:"President de l'Assemblee", rel:'neutral'}],
    services:[
      {name:'Assister a une session',   cost:'0 FR - 2 PA',    type:'legal', fn:'assister'},
      {name:'Voter une loi',            cost:'0 FR - 1 PA',    type:'legal', fn:'voter'},
      {name:'Deposer un projet de loi', cost:'0 FR - 4 PA',    type:'legal', fn:'projet_loi'},
      {name:'Marchander un vote',       cost:'200 FR - 3 PA',  type:'grey',  fn:'marchander'}
    ],
    actions:[
      {label:'Assister',        pa:2, type:'legal', icon:'ti-building',          fn:'assister'},
      {label:'Voter',           pa:1, type:'legal', icon:'ti-check',             fn:'voter'},
      {label:'Marchander vote', pa:3, type:'grey',  icon:'ti-arrows-exchange',   fn:'marchander'}
    ]
  },
  tribunal: {
    name:'Tribunal de la Capitale', cat:'Justice',
    desc:"La justice de Republia est formellement independante. Ce qui ne veut pas dire incorruptible.",
    persons:[
      {name:'Juge Fontaine',   role:'Presidente du Tribunal', rel:'neutral'},
      {name:'Procureur Saad',  role:'Ministere public',       rel:'neutral'}
    ],
    services:[
      {name:'Porter plainte',          cost:'0 FR - 2 PA',     type:'legal',   fn:'plainte'},
      {name:'Consulter les archives',  cost:'0 FR - 1 PA',     type:'legal',   fn:'archives'},
      {name:'Se defendre en justice',  cost:'300 FR - 3 PA',   type:'legal',   fn:'defense'},
      {name:'Corrompre un juge',       cost:'1000 FR - 5 PA',  type:'illegal', fn:'corrompre_juge'}
    ],
    actions:[
      {label:'Porter plainte',   pa:2, type:'legal',   icon:'ti-gavel',   fn:'plainte'},
      {label:'Archives',         pa:1, type:'legal',   icon:'ti-archive', fn:'archives'},
      {label:'Corrompre juge',   pa:5, type:'illegal', icon:'ti-scale',   fn:'corrompre_juge'}
    ]
  },
  bar: {
    name:'Le Bar du Senat', cat:'Restauration - Rencontres',
    desc:"Le bar le plus politique de la Capitale. Deputes, journalistes et lobbyistes s'y croisent.",
    persons:[
      {name:'Jean Dupont',  role:'Depute - Parti du Centre',   rel:'neutral'},
      {name:'Marie Leblanc',role:'Journaliste - La Tribune',   rel:'enemy'},
      {name:'Paulo',        role:'PNJ - Barman',               rel:'neutral'}
    ],
    services:[
      {name:'Se nourrir',                  cost:'20 FR - 2 PA',   type:'legal', fn:'manger'},
      {name:"Rencontrer quelqu'un",         cost:'0 FR - 2 PA',    type:'legal', fn:'rencontrer'},
      {name:'Inviter a diner',             cost:'80 FR - 3 PA',   type:'legal', fn:'diner'},
      {name:'Ecouter les conversations',   cost:'0 FR - 1 PA',    type:'grey',  fn:'ecouter'},
      {name:'Faire circuler une rumeur',   cost:'0 FR - 2 PA',    type:'grey',  fn:'rumeur'},
      {name:'Recruter un informateur',     cost:'150 FR - 2 PA',  type:'grey',  fn:'recruter_info'}
    ],
    actions:[
      {label:'Se nourrir',  pa:2, type:'legal', icon:'ti-soup',       fn:'manger'},
      {label:'Rencontrer',  pa:2, type:'legal', icon:'ti-users',      fn:'rencontrer'},
      {label:'Diner',       pa:3, type:'legal', icon:'ti-wine',       fn:'diner'},
      {label:'Ecouter',     pa:1, type:'grey',  icon:'ti-ear',        fn:'ecouter'},
      {label:'Rumeur',      pa:2, type:'grey',  icon:'ti-messages',   fn:'rumeur'}
    ]
  },
  banque: {
    name:'Banque Nationale de Republia', cat:'Finance',
    desc:"La banque centrale officielle. Toutes les transactions sont tracables.",
    persons:[{name:'Directeur Mercier', role:"PNJ - Directeur d'agence", rel:'neutral'}],
    services:[
      {name:'Gerer ses finances',      cost:'0 FR - 2 PA',    type:'legal', fn:'finances'},
      {name:'Investir',                cost:'500 FR - 3 PA',  type:'legal', fn:'investir'},
      {name:'Emprunter',               cost:'0 FR - 2 PA',    type:'legal', fn:'emprunter'},
      {name:'Optimisation fiscale',    cost:'200 FR - 2 PA',  type:'grey',  fn:'fiscal'}
    ],
    actions:[
      {label:'Gerer finances', pa:2, type:'legal', icon:'ti-chart-bar',    fn:'finances'},
      {label:'Investir',       pa:3, type:'legal', icon:'ti-trending-up',  fn:'investir'},
      {label:'Optimisation',   pa:2, type:'grey',  icon:'ti-calculator',   fn:'fiscal'}
    ]
  },
  clinique: {
    name:'Clinique Privee Saint-Luc', cat:'Sante',
    desc:"Soins rapides, discrets et efficaces. Pour oublier blessures et nuits difficiles.",
    persons:[{name:'Dr. Vidal', role:'PNJ - Medecin chef', rel:'neutral'}],
    services:[
      {name:'Consultation et soins',          cost:'200 FR - 3 PA',   type:'legal', fn:'soins'},
      {name:'Soins acceleres (urgence)',       cost:'500 FR - 2 PA',   type:'legal', fn:'soins_urgence'},
      {name:'Soins sans trace',               cost:'800 FR - 3 PA',   type:'grey',  fn:'soins_discrets'}
    ],
    actions:[
      {label:'Se soigner',     pa:3, type:'legal', icon:'ti-stethoscope', fn:'soins'},
      {label:'Soins urgence',  pa:2, type:'legal', icon:'ti-urgent',      fn:'soins_urgence'},
      {label:'Soins discrets', pa:3, type:'grey',  icon:'ti-eye-off',     fn:'soins_discrets'}
    ]
  },
  police: {
    name:'Commissariat Central', cat:'Securite',
    desc:"Le centre nevralgique de la police. Les officiers sont theoriquement integres.",
    persons:[{name:'Commissaire Gros', role:'PNJ - Chef de la police', rel:'neutral'}],
    services:[
      {name:'Porter plainte',                cost:'0 FR - 2 PA',    type:'legal',   fn:'plainte_police'},
      {name:'Archives criminelles',          cost:'0 FR - 1 PA',    type:'legal',   fn:'archives_police'},
      {name:'Corrompre un policier',         cost:'300 FR - 3 PA',  type:'illegal', fn:'corrompre_police'},
      {name:"Faire arreter quelqu'un",       cost:'500 FR - 4 PA',  type:'illegal', fn:'arreter'}
    ],
    actions:[
      {label:'Porter plainte',    pa:2, type:'legal',   icon:'ti-file-text', fn:'plainte_police'},
      {label:'Archives',          pa:1, type:'legal',   icon:'ti-archive',   fn:'archives_police'},
      {label:'Corrompre policier',pa:3, type:'illegal', icon:'ti-badge',     fn:'corrompre_police'}
    ]
  },
  presse: {
    name:'La Tribune de Republia', cat:'Medias',
    desc:"Le journal le plus influent de la Capitale. Marie Leblanc y officie. Elle ne vous aime pas.",
    persons:[
      {name:'Romain Castel', role:'PNJ - Redacteur en chef', rel:'neutral'},
      {name:'Marie Leblanc', role:'Journaliste',              rel:'enemy'}
    ],
    services:[
      {name:'Donner une interview',           cost:'0 FR - 2 PA',    type:'legal',   fn:'interview'},
      {name:'Placer un article favorable',    cost:'300 FR - 3 PA',  type:'grey',    fn:'article'},
      {name:'Corrompre un journaliste',       cost:'500 FR - 3 PA',  type:'illegal', fn:'corrompre_journaliste'},
      {name:'Etouffer un article defavorable',cost:'800 FR - 4 PA',  type:'illegal', fn:'etouffer'}
    ],
    actions:[
      {label:'Interview',            pa:2, type:'legal',   icon:'ti-microphone', fn:'interview'},
      {label:'Placer article',       pa:3, type:'grey',    icon:'ti-pencil',     fn:'article'},
      {label:'Corrompre journaliste',pa:3, type:'illegal', icon:'ti-cash',       fn:'corrompre_journaliste'}
    ]
  },
  loge: {
    name:'Loge Maconnique', cat:'Reseau secret',
    desc:"L'acces est sur invitation uniquement. Vous n'etes pas encore membre.",
    locked:true, persons:[],
    services:[{name:'Demander une introduction', cost:'0 FR - 2 PA', type:'legal', fn:'introduction_loge'}],
    actions:[{label:"Demander introduction", pa:2, type:'legal', icon:'ti-key', fn:'introduction_loge'}]
  }
};

// Order effects configuration
const ORDER_EFFECTS = {
  manger:         {hp:5,  moral:2},
  rencontrer:     {inf:3},
  diner:          {inf:5, arg:-80, moral:3},
  ecouter:        {},
  rumeur:         {pop:5},
  soins:          {hp:20, arg:-200},
  soins_urgence:  {hp:30, arg:-500},
  soins_discrets: {hp:30, arg:-800},
  investir:       {arg:-500},
  interview:      {pop:5},
  postuler:       {inf:2},
  voter:          {inf:3},
  assister:       {inf:1},
  negocier:       {inf:4, arg:-50},
  finances:       {},
  fiscal:         {arg:200},
  plainte:        {inf:2},
  plainte_police: {},
  archives:       {},
  archives_police:{},
  defense:        {arg:-300},
  emprunter:      {arg:1000},
  projet_loi:     {inf:3},
  marchander:     {arg:-200, inf:5},
  article:        {arg:-300, pop:8},
  etouffer:       {arg:-800},
  corrompre_fonct:{arg:-500, inf:5,  dis:-3},
  corrompre_juge: {arg:-1000,       dis:-5},
  corrompre_police:{arg:-300,       dis:-3},
  corrompre_journaliste:{arg:-500,  dis:-4},
  recruter_info:  {arg:-150},
  arreter:        {arg:-500, inf:5, dis:-8},
  introduction_loge:{inf:2},
  deplacer:       {}
};
