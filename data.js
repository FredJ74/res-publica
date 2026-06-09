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
      imageUrl:'https://images.unsplash.com/photo-1520939817895-060bdaf4fe1b?w=1200&q=80',
      desc:'Capitale de Republia. Centre du pouvoir politique, judiciaire et mediatique.',
      isCapitale: true,
      streetName: 'Avenue de la République',
      districts: ['centre','quartier-nord','quartier-sud'],
      buildings: ['palais-presidentiel','hotel-republica','palais-gouvernement','assemblee','tribunal','banque-nationale','banque-privee','clinique-privee','dispensaire-public','commissariat','la-tribune','loge-maconnique','universite','armurerie','marche','mairie-capitale','tabernacle-impots','centre-multinodal-luthecia','terrain-a-batir-1'],
      buildingContext: {
        'hotel-republica': {
          name: "Hôtel-Restaurant La Républia",
          desc: "Le grand hôtel de Luthecia. Gaston Sauceblanche règne sur la salle avec un mépris souverain.",
          persons: [{"name": "Gaston Sauceblanche (PNJ)", "role": "Maître d'hôtel", "rel": "neutral", "job": "serveur"}, {"name": "Yvette Gratinée (PNJ)", "role": "Serveuse", "rel": "neutral", "job": "serveur"}]
        },
        'commissariat': {
          name: "Commissariat Central de Luthecia",
          desc: "Raoul Toufaud pointe toujours dans la mauvaise direction.",
          persons: [{"name": "Raoul Toufaud (PNJ)", "role": "Commissaire Central", "rel": "neutral", "job": "commissaire"}, {"name": "Brigitte Menottes (PNJ)", "role": "Inspectrice", "rel": "neutral", "job": "inspecteur"}]
        },
        'tribunal': {
          name: "Tribunal de Luthecia",
          desc: "Honoré Cozetoujours condamne avant d'écouter.",
          persons: [{"name": "Honoré Cozetoujours (PNJ)", "role": "Juge en chef", "rel": "neutral", "job": "juge"}, {"name": "Maître Plaidoyer (PNJ)", "role": "Avocat commis d'office", "rel": "neutral", "job": "avocat"}]
        },
        'banque-nationale': {
          name: "Banque Nationale de Républia",
          desc: "Bernard Coffre-Fort n'a jamais ouvert un compte de sa vie.",
          persons: [{"name": "Bernard Coffre-Fort (PNJ)", "role": "Directeur", "rel": "neutral", "job": "banquier"}, {"name": "Simone Intérêt (PNJ)", "role": "Caissière", "rel": "neutral", "job": "caissier"}]
        },
        'banque-privee': {
          name: "Banque Privée Helvetia",
          desc: "Hans Von Discret ne confirme ni n'infirme rien.",
          persons: [{"name": "Hans Von Discret (PNJ)", "role": "Directeur", "rel": "neutral", "job": "banquier"}, {"name": "Ursula Offshore (PNJ)", "role": "Conseillère", "rel": "neutral", "job": "conseiller"}]
        },
        'clinique-privee': {
          name: "Clinique Privée Saint-Luc",
          desc: "Docteur Bistouri opère dans l'ordre alphabétique du portefeuille.",
          persons: [{"name": "Docteur Bistouri (PNJ)", "role": "Chirurgien", "rel": "neutral", "job": "medecin"}, {"name": "Infirmière Piqûre (PNJ)", "role": "Infirmière", "rel": "neutral", "job": "infirmier"}]
        },
        'dispensaire-public': {
          name: "Dispensaire Public de Luthecia",
          desc: "Docteur Aspirine prescrit du repos pour tout.",
          persons: [{"name": "Docteur Aspirine (PNJ)", "role": "Généraliste", "rel": "neutral", "job": "medecin"}]
        },
        'la-tribune': {
          name: "L'Autruche Entravée",
          desc: "Le journal d'investigation de Républia.",
          persons: [{"name": "Gustave Encre (PNJ)", "role": "Imprimeur", "rel": "neutral", "job": "journaliste"}, {"name": "Rosalie Caractère (PNJ)", "role": "Libraire", "rel": "neutral", "job": "journaliste"}]
        },
        'loge-maconnique': {
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
          persons: [{"name": "Roger Détente (PNJ)", "role": "Armurier", "rel": "neutral", "job": "commercant"}, {"name": "Simone Calibre (PNJ)", "role": "Assistante", "rel": "neutral", "job": "commercant"}]
        },
        'marche': {
          name: "Marché Central de Luthecia",
          desc: "Marcel Bidoche vend de la viande et des informations. Ginette Légume sait tout sur tout le monde.",
          persons: [{"name": "Marcel Bidoche (PNJ)", "role": "Boucher", "rel": "neutral", "job": "commercant"}, {"name": "Ginette Légume (PNJ)", "role": "Maraîchère", "rel": "neutral", "job": "commercant"}]
        }
      }
    },
    ville_a: {
      name:'Port-Sainte-Marie',
      imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie.png',
      desc:'Ville portuaire a l\'ouest. Commerce, contrebande et politique locale.',
      isCapitale: false,
      buildings: ['hotel-port','mairie','banque-locale','dispensaire-public-v','commissariat-local','bar-des-pecheurs','imprimerie-librairie','centre-multinodal-port-sainte-marie','port-sainte-marie','terrain-a-batir-2'],
      buildingContext: {
        'hotel-republica': {
          name: "Hôtel du Port",
          desc: "Un hôtel modeste qui sent le poisson et l'iode.",
          persons: [{"name": "Raymond Ancre (PNJ)", "role": "Gérant", "rel": "neutral", "job": "serveur"}]
        },
        'commissariat': {
          name: "Commissariat de Port-Sainte-Marie",
          desc: "Un petit commissariat de province.",
          persons: [{"name": "Inspecteur Morue (PNJ)", "role": "Inspecteur local", "rel": "neutral", "job": "commissaire"}]
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
          persons: [{"name": "Marinette Hareng (PNJ)", "role": "Poissonnière", "rel": "neutral", "job": "commercant"}]
        }
      }
    },
    ville_b: {
      name:'Montrouge',
      imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/montrouge.png',
      desc:'Ville industrielle au nord. Syndicats puissants, usines et tensions sociales.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','siege-syndical','usine-principale','centre-multinodal-montrouge','terrain-a-batir-3'],
      buildingContext: {
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
        'la-tribune': {
          name: "La Voix du Mineur",
          desc: "Le journal syndical de Montrouge.",
          persons: [{"name": "Rédacteur Calame (PNJ)", "role": "Rédacteur en chef", "rel": "neutral", "job": "journaliste"}]
        },
        'marche': {
          name: "Marché Ouvrier de Montrouge",
          desc: "Légumes pas chers, grèves annoncées à voix haute.",
          persons: [{"name": "Josette Betterave (PNJ)", "role": "Marchande", "rel": "neutral", "job": "commercant"}]
        }
      }
    },
    caserne: {
      name:'Caserne Militaire de Republia',
      imageUrl:'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=1200&q=80',
      desc:'La caserne principale de l\'armee de Republia.',
      isCapitale: false, isSpecial: true, travelCost: 1,
      buildings: ['caserne-militaire']
    },
    qhs: {
      name:'Quartier Haute Securite',
      imageUrl:'https://images.unsplash.com/photo-1562564055-71e051d33c19?w=1200&q=80',
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
      buildings: ['palais-presidentiel','hotel-republica','palais-gouvernement','assemblee','tribunal','banque-nationale','banque-privee','clinique-privee','dispensaire-public','commissariat','la-tribune','loge-maconnique','universite','armurerie','marche','mairie-capitale','laboratoire-priere','centre-multinodal-luthecia','terrain-a-batir-1'],
      buildingContext: {
        'hotel-republica': {
          name: "Hôtel El Cartel",
          desc: "Le seul hôtel potable de Ciudad Roja. Les murs ont des oreilles.",
          persons: [{"name": "Pedro Tequila (PNJ)", "role": "Barman", "rel": "neutral", "job": "serveur"}, {"name": "Lupe Cantina (PNJ)", "role": "Serveuse armée", "rel": "neutral", "job": "serveur"}]
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
          persons: [{"name": "Maria Mercado (PNJ)", "role": "Marchande", "rel": "neutral", "job": "commercant"}, {"name": "Carlos Regateo (PNJ)", "role": "Marchand", "rel": "neutral", "job": "commercant"}]
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
    ville_b: {
      name:'La Selva',
      imageUrl:'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=1200&q=80',
      desc:'Ville de la jungle. Les laboratoires s\'étendent à perte de vue.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','siege-syndical','usine-principale','centre-multinodal-montrouge','terrain-a-batir-3'],
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
      buildings: ['palais-presidentiel','hotel-republica','palais-gouvernement','assemblee','tribunal','banque-nationale','banque-privee','clinique-privee','dispensaire-public','commissariat','la-tribune','loge-maconnique','universite','armurerie','marche','mairie-capitale','kolkhoze-spirituel','centre-multinodal-luthecia','terrain-a-batir-1'],
      buildingContext: {
        'hotel-republica': {
          name: "Hôtel Kollektiv",
          desc: "Toutes les chambres sont identiques. Olga Soupe gère la cantine avec efficacité soviétique.",
          persons: [{"name": "Olga Soupe (PNJ)", "role": "Cantinière", "rel": "neutral", "job": "serveur"}, {"name": "Boris Betterave (PNJ)", "role": "Cuisinier", "rel": "neutral", "job": "serveur"}]
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
          persons: [{"name": "Camarade Kalachnikov (PNJ)", "role": "Responsable Arsenal", "rel": "neutral", "job": "commercant"}]
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
    ville_b: {
      name:'Kolkhoz-7',
      imageUrl:'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=1200&q=80',
      desc:'Le kolkhoze collectif numéro 7. Production agricole pour la gloire du Parti.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','siege-syndical','usine-principale','centre-multinodal-montrouge','terrain-a-batir-3'],
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
      buildings: ['palais-presidentiel','hotel-republica','palais-gouvernement','assemblee','tribunal','banque-nationale','banque-privee','clinique-privee','dispensaire-public','commissariat','la-tribune','loge-maconnique','universite','armurerie','marche','mairie-capitale','patisserie-sacree','centre-multinodal-luthecia','terrain-a-batir-1'],
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
          persons: [{"name": "Hassan Marchandage (PNJ)", "role": "Marchand principal", "rel": "neutral", "job": "commercant"}, {"name": "Yasmine Épices (PNJ)", "role": "Marchande", "rel": "neutral", "job": "commercant"}]
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
    ville_b: {
      name:'Port Al-Nour',
      imageUrl:'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=1200&q=80',
      desc:'Port pétrolier d\'Al-Khalija. Les tankers et les dhows se croisent.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','siege-syndical','usine-principale','centre-multinodal-montrouge','terrain-a-batir-3'],
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
          {fn:'ecouter',         label:'Ecouter le barman',     pa:0, cost:0,   type:'grey',  icon:'ti-ear',      successRate:90,  desc:'Le barman entend tout.'},
          {fn:'recruter_info',   label:'Recruter un informateur N1',pa:1,cost:150, type:'grey',  icon:'ti-user-plus',successRate:75,  desc:'150 FR/jour. Localisation approximative, rumeurs locales.'}
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
          {name:'Gérard Tamponneau (PNJ)', role:'PNJ - Chef du protocole presidentiel', rel:'neutral', job:'protocole'},
          {name:'Garde Republicain (PNJ)', role:'PNJ - Securite presidentielle', rel:'neutral', job:'garde'}
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
          {name:'Huguette Papier (PNJ)', role:'PNJ - Secretaire general de la presidence', rel:'neutral', job:'secretaire_general'}
        ],
        orders: [
          {fn:'creer_poste_ministre',   label:'Creer un poste ministeriel',    pa:3, cost:0,    type:'legal',   icon:'ti-user-star',     successRate:100, requiresPost:'president', desc:'Creer un poste de ministre personnalise. Limite : 1 poste + 1 comite.'},
          {fn:'creer_comite',           label:'Creer un comite',               pa:3, cost:0,    type:'legal',   icon:'ti-users-group',   successRate:100, requiresPost:'president', desc:'Creer un comite special. Limite : 1 comite.'},
          {fn:'supprimer_poste_custom', label:'Supprimer un poste cree',       pa:0, cost:0,    type:'legal',   icon:'ti-trash',         successRate:100, requiresPost:'president', desc:'Supprimer un poste ou comite precedemment cree.'},
          {fn:'nommer_ministre',        label:'Nommer un Premier Ministre',            pa:2, cost:0,    type:'legal',   icon:'ti-crown',         successRate:100, requiresPost:'president', desc:'Nommer un PJ a un poste ministeriel. Envoie un mail au candidat.'},
          {fn:'etat_urgence',           label:'Declarer l\'etat d\'urgence',  pa:3, cost:0,    type:'legal',   icon:'ti-alert-triangle',successRate:100, requiresPost:'president', desc:'Suspend certaines libertes. Fort impact sur INF et POP.'},
          {fn:'declarer_guerre',        label:'Declarer la guerre',            pa:5, cost:0,    type:'legal',   icon:'ti-sword',         successRate:100, requiresPost:'president', desc:'Declarer la guerre a un empire. Consequences majeures.'},
          {fn:'gracier',                label:'Gracier un condamne',           pa:2, cost:0,    type:'legal',   icon:'ti-heart-handshake',successRate:100,requiresPost:'president', desc:'Liberer un prisonnier. +POP +INF selon popularite du condamne.'},
          {fn:'dissoudre_assemblee',    label:'Dissoudre l\'Assemblee',       pa:4, cost:0,    type:'legal',   icon:'ti-ban',           successRate:100, requiresPost:'president', desc:'Declenche de nouvelles elections legislatives. Risque politique majeur.'},
          {fn:'decret_referendum',      label:'Ordonner un referendum',        pa:3, cost:0,    type:'legal',   icon:'ti-checkbox',      successRate:100, requiresPost:'president', desc:'Soumettre une question au vote populaire.'},
          {fn:'jour_deuil',             label:'Decret de deuil national',      pa:1, cost:0,    type:'legal',   icon:'ti-flag',          successRate:100, requiresPost:'president', desc:'Symbolique fort. +POP si populaire, -POP si conteste.'}
        ]
      },
      salle_presse_elysee: {
        name: "Salle de Presse",
        imageBg: "linear-gradient(135deg,#0f0f18,#181820)",
        desc: "La salle de presse presidentielle. Les journalistes accredites y attendent les declarations.",
        imageUrl: "https://images.unsplash.com/photo-1588681664899-f142ff2dc9b1?w=1200&q=80",
        persons: [
          {name:'Porte-parole presidentiel (PNJ)', role:'PNJ - Porte-parole de la presidence', rel:'neutral', job:'porteparole'}
        ],
        orders: [
          {fn:'conference_presse',  label:'Conference de presse',  pa:2, cost:0,   type:'legal', icon:'ti-microphone',   successRate:100, requiresPost:'president', desc:'Annonce presidentielle. Fort impact POP et INF.'},
          {fn:'annonce_officielle', label:'Annonce officielle',     pa:1, cost:0,   type:'legal', icon:'ti-speakerphone', successRate:100, requiresPost:'president', desc:'Declaration formelle au nom de la presidence.'},
          {fn:'propagande_etat',    label:'Propagande d\'Etat',    pa:3, cost:500, type:'grey',  icon:'ti-broadcast',    successRate:75,  requiresPost:'president', desc:'Campagne de communication massive. +POP important.'},
          {fn:'dementi',            label:'Dementi officiel',       pa:2, cost:0,   type:'legal', icon:'ti-x',            successRate:80,  requiresPost:'president', desc:'Dementir un scandale ou une rumeur.'}
        ]
      },
      salle_reception: {
        name: "Salle de Reception",
        imageBg: "linear-gradient(135deg,#100f08,#1a1808)",
        desc: "La somptueuse salle de reception du Palais. Receptions d'Etat, banquets diplomatiques.",
        imageUrl: "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=1200&q=80",
        persons: [
          {name:'Gérard Tamponneau (PNJ)', role:'PNJ - Organisation des evenements', rel:'neutral', job:'protocole'}
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
        desc: "Le hall monumental du Palais. Gardes republicains en faction. Acces controle.",
        imageUrl: "https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80",
        persons: [
          {name:'Garde Martineau',   role:'PNJ - Securite', rel:'neutral', job:'garde'},
          {name:'Secretaire Dupuis', role:'PNJ - Accueil officiel', rel:'neutral', job:'secretaire'}
        ],
        orders: [
          {fn:'postuler', label:'Postuler a un poste', pa:2, cost:0, type:'legal', icon:'ti-id-badge', successRate:85, desc:'PNJ : automatique. PM/President PJ : impossible.'}
        ]
      },
      bureaux: {
        name: "Bureau du Premier Ministre",
        imageBg: "linear-gradient(135deg,#0f1a0c,#182416)",
        desc: "Le bureau du Premier Ministre. Acces PM uniquement.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-premier-ministre.png",
        persons: [
          {name:'Chef de Cabinet (PNJ)', role:'PNJ - Chef de cabinet du PM', rel:'neutral', job:'chef_cabinet'}
        ],
        orders: [
          {fn:'nommer_ministre_pm', label:'Nommer des ministres',       pa:2, cost:0,   type:'legal',   icon:'ti-crown',     successRate:100, requiresPost:'pm', desc:'Nommer un PJ a un poste ministeriel.'},
          {fn:'corrompre_fonct',    label:'Corrompre un fonctionnaire', pa:2, cost:500, type:'illegal', icon:'ti-coins',     successRate:65,  desc:'Acheter un service administratif.'}
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
        orders: [
          {fn:'voter_loi',    label:'Participer au conseil',     pa:2, cost:0, type:'legal', icon:'ti-check',      successRate:100, requiresPost:true, desc:'Voter sur les propositions en cours.'},
          {fn:'projet_loi',   label:'Soumettre une proposition', pa:3, cost:0, type:'legal', icon:'ti-file-text',  successRate:70,  requiresPost:true, desc:'Proposer une loi avec intitule et duree de vote.'}
        ]
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
          {fn:'annonce_officielle',label:'Annonce officielle',     pa:1, cost:0,    type:'legal',   icon:'ti-speakerphone', successRate:100, requiresPost:true, desc:'Declaration formelle au nom du gouvernement.'},
          {fn:'propagande_etat',   label:'Campagne de propagande', pa:3, cost:500,  type:'grey',    icon:'ti-broadcast',    successRate:75,  requiresPost:true, desc:'Influence massive de l\'opinion publique. +POP important.'},
          {fn:'dementi',           label:'Démenti officiel',       pa:2, cost:0,    type:'legal',   icon:'ti-x',            successRate:80,  requiresPost:true, desc:'Dementir une rumeur ou un scandale. Reduit l\'impact d\'un kompromat.'}
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
          {fn:'consulter_dossiers', label:'Consulter des dossiers',    pa:2, cost:0,    type:'legal',   icon:'ti-archive',        successRate:80,  requiresPost:true, desc:'Acceder a des informations confidentielles.'},
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
        persons: [],
        orders: [
          {fn:'mobiliser_police',     label:'Mobiliser les forces de l\'ordre', pa:2, cost:0, type:'legal', icon:'ti-shield',        successRate:100, requiresPost:'min_int', desc:'Deploiement massif de police. +securite -liberte.'},
          {fn:'interdire_manif',      label:'Interdire une manifestation',  pa:2, cost:0,   type:'legal',   icon:'ti-ban',            successRate:100, requiresPost:'min_int', desc:'Interdire un rassemblement. -POP important.'},
          {fn:'autoriser_manif',      label:'Autoriser une manifestation',  pa:1, cost:0,   type:'legal',   icon:'ti-check',          successRate:100, requiresPost:'min_int', desc:'Lever une interdiction. +POP.'},
          {fn:'repression_manif',     label:'Ordonner la repression',       pa:3, cost:0,   type:'grey',    icon:'ti-flame',          successRate:80,  requiresPost:'min_int', desc:'Disperser de force. -POP fort mais +autorite.'}
        ]
      },
      bureau_min_fin: {
        name: "Bureau - Ministre des Finances",
        imageBg: "linear-gradient(135deg,#0a0f08,#101508)",
        desc: "Le bureau du Ministre des Finances. Fiscalite, budget, politique economique.",
        imageUrl: "https://images.unsplash.com/photo-1553729459-efe14ef6055d?w=1200&q=80",
        requiresPostId: 'min_fin',
        persons: [],
        orders: [
          {fn:'augmenter_impots',     label:'Augmenter les impots',         pa:2, cost:0,   type:'legal',   icon:'ti-trending-up',    successRate:100, requiresPost:'min_fin', desc:'Augmenter la fiscalite nationale. +recettes -POP.'},
          {fn:'baisser_impots',       label:'Baisser les impots',           pa:2, cost:0,   type:'legal',   icon:'ti-trending-down',  successRate:100, requiresPost:'min_fin', desc:'Reduire la fiscalite. -recettes +POP.'},
          {fn:'redressement_fiscal',  label:'Ordonner un redressement',     pa:2, cost:0,   type:'legal',   icon:'ti-gavel',          successRate:80,  requiresPost:'min_fin', desc:'Cibler un contribuable. Genere des recettes mais cree des ennemis.'},
          {fn:'subvention',           label:'Accorder une subvention',      pa:2, cost:500, type:'legal',   icon:'ti-coins',          successRate:100, requiresPost:'min_fin', desc:'Financer un secteur ou une association. +POP ciblé.'},
          {fn:'fiscal',              label:'Repartition budgetaire',       pa:2, cost:0, type:'legal', icon:'ti-chart-pie',   successRate:100, requiresPost:'min_fin', desc:'Fixer la repartition des recettes fiscales entre les institutions. Prerogative exclusive du Ministre des Finances.'},
          {fn:'allegemement_fiscal',  label:'Allegement fiscal sectoriel',  pa:2, cost:0,   type:'legal',   icon:'ti-receipt-tax',    successRate:100, requiresPost:'min_fin', desc:'Reduire les taxes d\'un secteur. +INF aupres des lobbies.'}
        ]
      },
      bureau_min_just: {
        name: "Bureau - Ministre de la Justice",
        imageBg: "linear-gradient(135deg,#0a0808,#140f08)",
        desc: "Le bureau du Ministre de la Justice. Magistrature, poursuites, grace presidentielle.",
        imageUrl: "https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=1200&q=80",
        requiresPostId: 'min_just',
        persons: [],
        orders: [
          {fn:'annuler_poursuites',   label:'Annuler des poursuites',       pa:2, cost:0,   type:'grey',    icon:'ti-file-x',         successRate:70,  requiresPost:'min_just', desc:'Classer une affaire judiciaire. Cree une dette politique.'},
          {fn:'ouvrir_enquete',       label:'Ouvrir une enquete',           pa:2, cost:0,   type:'legal',   icon:'ti-search',         successRate:90,  requiresPost:'min_just', desc:'Declencher une enquete judiciaire sur un individu.'},
          {fn:'gracier',              label:'Proposer une grace',           pa:2, cost:0,   type:'legal',   icon:'ti-heart-handshake',successRate:100, requiresPost:'min_just', desc:'Recommander une grace au President.'},
          {fn:'nommer_juge',          label:'Nommer un juge',               pa:3, cost:0,   type:'legal',   icon:'ti-gavel',          successRate:90,  requiresPost:'min_just', desc:'Nommer un magistrat favorable. Influence les verdicts futurs.'}
        ]
      },
      bureau_min_def: {
        name: "Bureau - Ministre de la Defense",
        imageBg: "linear-gradient(135deg,#080f08,#0f1808)",
        desc: "Le bureau du Ministre de la Defense. Armee, securite nationale, renseignement militaire.",
        imageUrl: "https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80",
        requiresPostId: 'min_def',
        persons: [],
        orders: [
          {fn:'mobiliser_armee',      label:'Mobiliser l\'armee',          pa:4, cost:0,   type:'legal',   icon:'ti-military-rank',  successRate:100, requiresPost:'min_def', desc:'Mise en alerte des forces armees. Tres impactant diplomatiquement.'},
          {fn:'cessez_le_feu',        label:'Negocier un cessez-le-feu',   pa:3, cost:0,   type:'legal',   icon:'ti-handshake',      successRate:60,  requiresPost:'min_def', desc:'Mettre fin a un conflit en cours.'},
          {fn:'renseignement',        label:'Lancer une operation de renseignement', pa:3, cost:500, type:'grey', icon:'ti-spy', successRate:70, requiresPost:'min_def', desc:'Espionner un empire etranger.'}
        ]
      },
      bureau_min_info: {
        name: "Bureau - Ministre de l'Information",
        imageBg: "linear-gradient(135deg,#0f0808,#180f08)",
        desc: "Le bureau du Ministre de l'Information. Medias, propagande, censure.",
        imageUrl: "https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=1200&q=80",
        requiresPostId: 'min_info',
        persons: [],
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
        persons: [],
        orders: [
          {fn:'negocier_paix',        label:'Negocier un accord de paix',           pa:3, cost:0, type:'legal', icon:'ti-handshake',     successRate:65, requiresPost:'min_ae', desc:'Choisir un empire en guerre. +12 ID si succes.'},
          {fn:'accord_diplomatique',  label:'Ouvrir des negociations diplomatiques', pa:2, cost:0, type:'legal', icon:'ti-building-bank', successRate:80, requiresPost:'min_ae', desc:'Etablir un canal diplomatique. +8 ID.'},
          {fn:'signer_traite',        label:'Signer un traite',             pa:3, cost:0,   type:'legal',   icon:'ti-file-certificate', successRate:70, requiresPost:'min_ae', desc:'Accord bilateral avec un empire etranger.'},
          {fn:'ouvrir_ambassade',     label:'Ouvrir une ambassade',         pa:2, cost:1000,type:'legal',   icon:'ti-building',       successRate:100, requiresPost:'min_ae', desc:'Etablir une representation diplomatique.'},
          {fn:'sanctions_diplo',      label:'Imposer des sanctions',        pa:3, cost:0,   type:'legal',   icon:'ti-ban',            successRate:85,  requiresPost:'min_ae', desc:'Sanctions economiques ou diplomatiques.'}
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
      hemicycle: {
        name: "Hemicycle",
        image: "🗳️",
        imageBg: "linear-gradient(135deg,#101820,#182030)",
        desc: "L'hemicycle principal. Les votes se font ici. Acces deputés uniquement pour les sessions.",
        imageUrl: "https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?w=1200&q=80",
        persons: [
          {name:'President Laroche', role:"President de l\'Assemblee (PNJ)", rel:'neutral', job:'president'},
          {name:'Depute Martin',     role:'Groupe majoritaire (PNJ)', rel:'neutral', job:'depute'},
          {name:'Depute Chen',       role:'Opposition (PNJ)', rel:'neutral', job:'depute'}
        ],
        orders: [
          {fn:'calendrier_elections', label:'Calendrier electoral',       pa:0, cost:0, type:'legal', icon:'ti-calendar', successRate:100, desc:'Consulter le calendrier des elections en cours et a venir.'},
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
          {name:'Lobbyiste Perrin', role:'Lobbyiste (PNJ)', rel:'neutral', job:'lobbyiste'},
          {name:'Journaliste Blanc',role:'Correspondant parlementaire (PNJ)', rel:'neutral', job:'journaliste'}
        ],
        orders: [
          {fn:'marchander',  label:'Proposer un accord',  pa:2, cost:100, type:'grey',  icon:'ti-handshake',successRate:65},
          {fn:'ecouter_rumeurs', label:'Ecouter les rumeurs', pa:1, cost:0, type:'grey', icon:'ti-ear', successRate:70, desc:'Revele une information aléatoire sur un PJ ou PNJ de la ville. Generee par IA selon le contexte politique. Tres utile pour journalistes et espions.'}
        ]
      },
      salle_archives_assemblee: {
        name: "Salle des Archives",
        imageBg: "linear-gradient(135deg,#0a0808,#120f08)",
        desc: "Les archives de l\'Assemblee Nationale. Toutes les lois votees y sont conservees pendant 3 mois.",
        imageUrl: "https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80",
        persons: [
          {name:'Archiviste Parlementaire (PNJ)', role:'PNJ - Archiviste de l\'Assemblee', rel:'neutral', job:'archiviste'}
        ],
        orders: [
          {fn:'consulter_archives_lois', label:'Consulter les archives', pa:0, cost:0, type:'legal', icon:'ti-archive', successRate:100, desc:'Liste des lois votees : titre, date, resultat, votes nominatifs. Archivage 3 mois.'}
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
          {fn:'defense',   label:'Se defendre',           pa:2, cost:300, type:'legal',   icon:'ti-shield',  successRate:75}
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
          {fn:'falsifier_document', label:'Falsifier un document', pa:3, cost:300, type:'illegal', icon:'ti-file-x', successRate:45, desc:'Liste : fausse identite, faux casier vierge, faux permis construire, faux contrat. Cree un objet en inventaire.'}
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
        imageBg: "linear-gradient(135deg,#0f1018,#151822)",
        desc: "L'accueil du commissariat. Atmosphere froide et surveillee.",
        imageUrl: "https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=1200&q=80",
        persons: [
          {name:'Commissaire Gros', role:'PNJ - Chef de la police', rel:'neutral', job:'commissaire'},
          {name:'Agent Petit',      role:'PNJ - Officier de garde', rel:'neutral', job:'policier'}
        ],
        orders: [
          {fn:'plainte_police',   label:'Porter plainte',         pa:1, cost:0,   type:'legal',   icon:'ti-file-text', successRate:100, desc:'Contre une personne identifiee ou contre X. Reponse sous 24h.'},
          {fn:'archives_police',  label:'Consulter les archives', pa:1, cost:0,   type:'legal',   icon:'ti-archive',   successRate:95,  desc:'Succes (95%) : liste des personnes emprisonnees les 30 derniers jours.'},
          {fn:'arreter',          label:"Faire arreter quelqu'un",pa:3, cost:500, type:'illegal', icon:'ti-handcuffs', successRate:50,  desc:'Necessite un dossier. Mise en garde a vue 24h.'}
        ]
      },
      prison: {
        name: "Cellules de garde a vue",
        imageBg: "linear-gradient(135deg,#0a0a10,#101018)",
        desc: "Les cellules de garde a vue du commissariat. Froid, humide, deprimant.",
        imageUrl: "https://images.unsplash.com/photo-1562564055-71e051d33c19?w=1200&q=80",
        persons: [
          {name:'Gardien Dubois', role:'PNJ - Gardien de cellule', rel:'neutral', job:'gardien'}
        ],
        orders: [
          {fn:'requete_avocat',  label:'Requérir les services d\'un avocat', pa:1, cost:0,    type:'legal',   icon:'ti-scale',      successRate:100, desc:'Contacte votre avocat. Reduit les risques de condamnation.'},
          {fn:'se_rebeller',     label:'Se rebeller',                        pa:2, cost:0,    type:'illegal', icon:'ti-flame',      successRate:30,  desc:'Tentative de rebellion. Risque d\'allonger la detention.'},
          {fn:'tentative_evasion',label:'Tenter de s\'evader',               pa:3, cost:0,    type:'illegal', icon:'ti-run',        successRate:15,  desc:'Tres risque. Succes : liberte. Echec : transferement en prison.'}
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
        orders: [
          {fn:'demander_adhesion', label:'Demander a rejoindre la Loge', pa:2, cost:0, type:'legal', icon:'ti-user-plus', successRate:50, desc:'Necessite un parrain. Sans parrain, refus automatique.'}
        ]
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
          {fn:'demander_info_loge', label:'Demander des informations', pa:2, cost:0,   type:'legal',   icon:'ti-info-circle',successRate:70},
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
    desc: "Vente d'armes legales et equipements de securite. Un registre consigne toutes les ventes.",
    rooms: {
      magasin: {
        name: "Magasin",
        imageBg: "linear-gradient(135deg,#100a08,#181008)",
        desc: "Presentoirs d'armes. Le vendeur verifie les papiers pour les ventes legales.",
        imageUrl: "https://images.unsplash.com/photo-1595590424283-b8f17842773f?w=1200&q=80",
        persons: [
          {name:'Gerard (Armurier)', role:'PNJ - Vendeur', rel:'neutral', job:'armurier'}
        ],
        orders: [
          {
            fn:'acheter_arme_legale',
            label:'Acheter une arme (legalement)',
            pa:1, cost:400, type:'legal', icon:'ti-shield', successRate:100,
            desc:'Vente enregistree dans le registre officiel. Tracable. Arme ajoutee a votre inventaire.'
          },
          {
            fn:'acheter_arme_illegale',
            label:'Acheter une arme (sans registre)',
            pa:1, cost:800, type:'illegal', icon:'ti-eye-off', successRate:50,
            desc:'Taux de reussite : 50%. 2x plus cher. Non enregistre. Echec : gratuit mais devez dormir avant de retenter.'
          },
          {
            fn:'acheter_gilet',
            label:'Acheter un gilet pare-balles',
            pa:1, cost:600, type:'legal', icon:'ti-shield-check', successRate:100,
            desc:'Protection physique. Enregistre dans le registre.'
          },
          {
            fn:'consulter_registre_armes',
            label:'Consulter le registre de vente',
            pa:1, cost:0, type:'legal', icon:'ti-book', successRate:100,
            desc:'Acces libre : Commissaire, Juge. Sinon : soudoyer l\'armurier (30%, 100 FR, +/-5 INF et POP). Ventes des 6 derniers mois.'
          },
          {
            fn:'acheter_bombe_illegale',
            label:'Acheter des explosifs (marche noir)',
            pa:2, cost:1200, type:'illegal', icon:'ti-bomb', successRate:40,
            desc:'ILLEGAL. Taux 40%. Non enregistre. 2x prix. Echec : gratuit mais doit dormir avant retenter. Echec critique : alerte police.'
          }
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
          {fn:'pouls_populaire',     label:'Prendre le pouls',          pa:0, cost:0,  type:'legal',   icon:'ti-ear',           successRate:85,  desc:'Sondage sur les elections ou popularite des PJ. Resultat genere par IA.'},
          {fn:'distribuer_tract',    label:'Distribuer un tract',       pa:1, cost:0,  type:'legal',   icon:'ti-file-description',successRate:70, desc:'Necessite un tract en inventaire. Donne un vote au candidat du tract.', requiresTract:true},
          {fn:'lancer_rumeur_cible', label:'Lancer une rumeur',         pa:1, cost:0,  type:'grey',    icon:'ti-messages',      successRate:50,  desc:'Sur une personne du repertoire. Succes : +/-5 POP sur la cible.'}
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
          {name:'Secretaire Municipal Petit', role:'PNJ - Secretariat general', rel:'neutral', job:'secretaire'},
          {name:'Le Maire (PNJ)',             role:'Maire de Luthecia', rel:'neutral', job:'maire'}
        ],
        orders: [
          {fn:'calendrier_elections', label:'Calendrier electoral',       pa:0, cost:0, type:'legal', icon:'ti-calendar', successRate:100, desc:'Consulter le calendrier des elections en cours et a venir.'},
          {fn:'deposer_candidature', label:'Deposer une candidature',    pa:2, cost:0,   type:'legal', icon:'ti-id-badge',   successRate:100, desc:'Vous inscrire comme candidat a une election en cours.'},
          {fn:'consulter_elections', label:'Consulter les elections',     pa:0, cost:0,   type:'legal', icon:'ti-chart-bar',  successRate:100, desc:'Voir les elections en cours et les candidats declares.'},
          {fn:'acte_officiel',       label:'Demander un acte officiel',  pa:1, cost:50,  type:'legal', icon:'ti-file-certificate', successRate:100, desc:'Naissance, mariage, document administratif.'}
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
          {fn:'repartition_budget_local', label:'Repartition du budget local', pa:2, cost:0, type:'legal', icon:'ti-chart-pie',    successRate:100, requiresPost:'maire', desc:'Allouer le budget entre commissariat, dispensaire, voirie et services municipaux.'},
          {fn:'campagne_securite',     label:'Lancer une campagne de securite',pa:2, cost:500, type:'legal', icon:'ti-shield',     successRate:80,  requiresPost:'maire', desc:'+10 ISN local. Deploiement de forces de l\'ordre supplementaires. Preleve sur budget mairie.'},
          {fn:'acte_officiel_mairie',  label:'Delivrer un acte officiel',     pa:1, cost:0, type:'legal', icon:'ti-file-certificate', successRate:100, requiresPost:'maire', desc:'Choisir le type d\'acte a delivrer a un administre.'},
          {fn:'contester_resultats',   label:'Contester des resultats',       pa:2, cost:0, type:'legal', icon:'ti-alert-triangle', successRate:70, desc:'Deposer un recours dans le sous-forum Tribunal. Delai 48h. Decision du juge.'}
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
      }
    }
  },

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
          {fn:'dormir',     label:'Dormir',          pa:0, cost:60, type:'legal', icon:'ti-moon',  successRate:100, desc:'+3 PA bonus demain.', paBonus:3}
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
          {fn:'contrebande',label:'Contacter reseau',pa:2, cost:100, type:'illegal',icon:'ti-package', successRate:55},
          {fn:'recruter_informateur_3', label:'Recruter un informateur (Niv.3)', pa:1, cost:700, type:'grey', icon:'ti-user-search', successRate:100, desc:'700 FR/jour. Indice empire origine d\'un crime, contrebandes en cours.'},
          {fn:'recruter_info_3', label:'Recruter informateur N3', pa:2, cost:0, type:'grey', icon:'ti-user-secret', successRate:60, desc:'700 FR/jour. Indice empire origine d\'un crime, contrebandes en cours.'},
          {fn:'consulter_info_3', label:'Consulter informateur N3', pa:1, cost:0, type:'grey', icon:'ti-eye', successRate:100, desc:'Obtenir une information de votre informateur niveau 3.'},
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
        imageUrl: "https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=1200&q=80",
        persons: [{name:'Brigadier Local (PNJ)', role:'Officier de garde', rel:'neutral', job:'policier'}],
        orders: [
          {fn:'plainte_police',   label:'Porter plainte',      pa:1, cost:0,   type:'legal',   icon:'ti-file-text', successRate:100}
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
        imageUrl: "https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=1200&q=80",
        persons: [
          {name:'Gutenberg (Imprimeur)', role:'PNJ - Proprietaire imprimerie', rel:'neutral', job:'imprimeur'}
        ],
        orders: [
          {fn:'imprimer_tracts',  label:'Faire imprimer des tracts',  pa:2, cost:150, type:'legal',   icon:'ti-file-description', successRate:100, desc:'Choisir pour/contre + cible (repertoire) + quantite. Tracts en inventaire.'},
          {fn:'imprimer_livre',   label:'Faire imprimer un livre',    pa:3, cost:500, type:'legal',   icon:'ti-book',             successRate:100, desc:'Publication d\'un ouvrage. Augmente la notoriete intellectuelle.'},
          {fn:'imprimer_clandestin', label:'Impression clandestine',  pa:2, cost:300, type:'illegal', icon:'ti-eye-off',          successRate:70,  desc:'Documents non officiels, faux papiers, tracts interdits.'}
        ]
      },
      atelier: {
        name: "Atelier d'Imprimerie",
        imageBg: "linear-gradient(135deg,#0a0a08,#141208)",
        desc: "L'atelier en activite permanente. Presses, rouleaux d'encre, odeur caracteristique.",
        imageUrl: "https://images.unsplash.com/photo-1598300042247-d088f8ab3a91?w=1200&q=80",
        persons: [
          {name:'Ouvrier typographe (PNJ)', role:'PNJ - Typographe', rel:'neutral', job:'typographe'}
        ],
        orders: []
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
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Terrain de 3000m2 en zone industrielle.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'acheter_terrain',   label:'Acheter ce terrain',          pa:2, cost:4000, type:'legal',   icon:'ti-home-plus', successRate:100},
          {fn:'permis_construire', label:'Demander un permis',          pa:2, cost:200,  type:'legal',   icon:'ti-file-text', successRate:65},
          {fn:'permis_corrompu',   label:'Permis accelere (corruption)',pa:2, cost:800,  type:'illegal', icon:'ti-coins',     successRate:55}
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
        imageUrl: "https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=1200&q=80",
        persons: [
          {name:'Sergent Dubois (PNJ)', role:'PNJ - Sous-officier de garde', rel:'neutral', job:'militaire'},
          {name:'Soldat Martin (PNJ)',  role:'PNJ - Faction',                 rel:'neutral', job:'militaire'}
        ],
        orders: [
          {fn:'recruter_etud',   label:'Recruter des soldats',   pa:2, cost:500, type:'legal',   icon:'ti-user-plus',     successRate:70,  requiresPost:'min_def', desc:'Renforcer les effectifs militaires.'}
        ]
      },
      salle_commandement: {
        name: "Salle de Commandement",
        imageBg: "linear-gradient(135deg,#060f06,#0a180a)",
        desc: "Le centre nerveux operationnel. Cartes, ecrans, officiers. Acces officiers superieurs.",
        imageUrl: "https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=1200&q=80",
        requiresPostId: 'min_def',
        persons: [
          {name:'General Faure (PNJ)', role:'PNJ - Chef d\'etat-major', rel:'neutral', job:'general'}
        ],
        orders: [
          {fn:'mobiliser_armee',     label:'Mobiliser les troupes',      pa:4, cost:0,    type:'legal',   icon:'ti-military-rank', successRate:100, requiresPost:'min_def', desc:'Mise en alerte maximale. Gros impact diplomatique.'},
          {fn:'planifier_operation', label:'Planifier une operation',    pa:3, cost:0,    type:'legal',   icon:'ti-map',           successRate:80,  requiresPost:'min_def', desc:'Preparer une operation militaire ou de maintien de l\'ordre.'},
          {fn:'renseignement',       label:'Operation de renseignement', pa:3, cost:500,  type:'grey',    icon:'ti-spy',           successRate:65,  requiresPost:'min_def', desc:'Espionnage d\'un empire etranger ou d\'un suspect.'},
          {fn:'cessez_le_feu',       label:'Negocier un cessez-le-feu',  pa:3, cost:0,    type:'legal',   icon:'ti-handshake',     successRate:60,  requiresPost:'min_def', desc:'Mettre fin a un conflit en cours.'},
          {fn:'inspecter_troupes',   label:'Inspecter les troupes',      pa:1, cost:0,    type:'legal',   icon:'ti-eye',           successRate:100, requiresPost:'min_def', desc:'+INF aupres de l\'armee. Renforce la loyaute.'}
        ]
      },
      armurerie_militaire: {
        name: "Armurerie Militaire",
        imageBg: "linear-gradient(135deg,#080808,#121008)",
        desc: "L'armurerie de la caserne. Armes lourdes, equipements tactiques, explosifs reglementaires.",
        imageUrl: "https://images.unsplash.com/photo-1595590424283-b8f17842773f?w=1200&q=80",
        requiresPostId: 'min_def',
        persons: [
          {name:'Armurier Militaire (PNJ)', role:'PNJ - Sergent armurier', rel:'neutral', job:'armurier_mil'}
        ],
        orders: [
          {fn:'acheter_arme_militaire', label:'Obtenir equipement militaire', pa:1, cost:0,   type:'legal',   icon:'ti-shield',    successRate:100, requiresPost:'min_def', desc:'Armes et equipements reserves aux militaires.'},
          {fn:'acheter_bombe_mil',      label:'Obtenir des explosifs',        pa:2, cost:0,   type:'legal',   icon:'ti-bomb',      successRate:100, requiresPost:'min_def', desc:'Explosifs reglementaires. Tracables. Ajoutes a l\'inventaire.'},
          {fn:'acheter_bombe_illegale', label:'Subtiliser des explosifs',     pa:2, cost:0,   type:'illegal', icon:'ti-eye-off',   successRate:35,  desc:'Taux 35%. Echec partiel : -30 HP. Echec critique : -80 HP + alerte.'}
        ]
      },
      quartier_troupes: {
        name: "Quartier des Troupes",
        imageBg: "linear-gradient(135deg,#080a08,#0f120a)",
        desc: "Les dortoirs et salles de repos des soldats. Ambiance de camaraderie et discipline.",
        imageUrl: "https://images.unsplash.com/photo-1544717305-2782549b5136?w=1200&q=80",
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
        imageUrl: "https://images.unsplash.com/photo-1562564055-71e051d33c19?w=1200&q=80",
        persons: [
          {name:'Directeur Penitentiaire (PNJ)', role:'PNJ - Directeur du QHS', rel:'neutral', job:'directeur_qhs'},
          {name:'Gardien Chef (PNJ)',             role:'PNJ - Securite QHS',     rel:'neutral', job:'gardien_qhs'}
        ],
        orders: [
          {fn:'visiter_prisonnier', label:'Demander une visite',         pa:1, cost:0,   type:'legal',   icon:'ti-users',    successRate:70,  desc:'Rendre visite a un detenu du QHS. Necessite autorisation.'},
          {fn:'corrompre_fonct',   label:'Corrompre le directeur',      pa:3, cost:1500, type:'illegal', icon:'ti-coins',    successRate:25,  desc:'Taux tres faible. Consequence severe si echec.'},
          {fn:'archives_police',   label:'Consulter le registre',       pa:1, cost:0,   type:'legal',   icon:'ti-archive',  successRate:100, requiresPost:'magistrat', desc:'Liste des detenus actuels. Acces magistrats/commissaires.'}
        ]
      },
      cellules_qhs: {
        name: "Cellules",
        imageBg: "linear-gradient(135deg,#050505,#0a0808)",
        desc: "Les cellules du QHS. Isolement total. Acces interdit sauf pour les detenus et gardiens.",
        imageUrl: "https://images.unsplash.com/photo-1562564055-71e051d33c19?w=1200&q=80",
        persons: [
          {name:'Gardien de couloir (PNJ)', role:'PNJ - Surveillance', rel:'neutral', job:'gardien_qhs'}
        ],
        orders: [
          {fn:'requete_avocat',     label:'Requérir un avocat',          pa:1, cost:0,    type:'legal',   icon:'ti-scale',    successRate:100, desc:'Contacter votre defenseur. Reduit risques de condamnation.'},
          {fn:'greve_faim',         label:'Greve de la faim',            pa:0, cost:0,    type:'legal',   icon:'ti-ban',      successRate:100, desc:'-5 HP/jour mais +POP et pression politique.'},
          {fn:'corrompre_gardien',  label:'Corrompre un gardien',        pa:2, cost:800,  type:'illegal', icon:'ti-coins',    successRate:20,  desc:'Tres difficile. Obtenir des privileges ou informations.'},
          {fn:'tentative_evasion',  label:'Tenter de s\'evader',        pa:3, cost:0,    type:'illegal', icon:'ti-run',      successRate:5,   desc:'Quasi impossible. Echec = peine aggravee de 7 jours.'}
        ]
      },
      salle_interrogatoire: {
        name: "Salle d'Interrogatoire",
        imageBg: "linear-gradient(135deg,#050808,#0a1010)",
        desc: "La salle d'interrogatoire. Lumiere crue, table metallique. Acces enqueteurs autorises.",
        imageUrl: "https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=1200&q=80",
        persons: [
          {name:'Inspecteur Raoul Toufaud (PNJ)', role:'PNJ - Inspecteur principal', rel:'neutral', job:'inspecteur'}
        ],
        orders: [
          {fn:'interroger',        label:'Interroger un detenu',        pa:2, cost:0,    type:'legal',   icon:'ti-message-circle', successRate:75, requiresPost:'commissaire', desc:'Obtenir des informations. +INF si succes.'},
          {fn:'corrompre_fonct',   label:'Falsifier un proces-verbal',  pa:3, cost:500,  type:'illegal', icon:'ti-file-x',         successRate:35, desc:'Modifier les declarations. Tres risque.'}
        ]
      },
      promenoir: {
        name: "Promenoir",
        imageBg: "linear-gradient(135deg,#080808,#0f0f0f)",
        desc: "La cour de promenade. Une heure par jour. Sous surveillance constante.",
        imageUrl: "https://images.unsplash.com/photo-1562564055-71e051d33c19?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'se_reposer',        label:'Prendre l\'air',              pa:0, cost:0,    type:'legal',   icon:'ti-walk',     successRate:100, desc:'+2 Moral. La seule liberte qui reste.'}
        ]
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
        imageUrl: "https://images.unsplash.com/photo-1548625149-fc4a29cf7092?w=1200&q=80",
        persons: [
          {name:'Percepteur Suprême Adolphe Taxe (PNJ)', role:'Grand Prêtre du Papyrusisme', rel:'neutral', job:'grand_pretre'},
          {name:'Enfant de chœur Timide (PNJ)', role:'PNJ - Distributeur de formulaires', rel:'neutral', job:'clerc'}
        ],
        orders: [
          {fn:'prier',           label:'Prier le Formulaire Sacré',    pa:1, cost:0,   type:'legal', icon:'ti-star',      successRate:100, desc:'+3 IP +2 Moral. Remplir un formulaire en 12 exemplaires.'},
          {fn:'se_confesser',    label:'Se confesser',                  pa:2, cost:0,   type:'legal', icon:'ti-message',   successRate:100, desc:'Révèle des informations au Grand Prêtre. +5 Moral mais risque de fuite.'},
          {fn:'faire_don',       label:'Faire un don a l\'Eglise',     pa:1, cost:200, type:'legal', icon:'ti-coins',     successRate:100, desc:'+5 IP +3 POP. Le Percepteur Suprême bénit votre don.'},
          {fn:'demander_benediction', label:'Demander une bénédiction', pa:1, cost:0,  type:'legal', icon:'ti-sparkles',  successRate:80,  desc:'+5 à un ordre de votre choix pour 24h.'},
          {fn:'pelerin',         label:'Se déclarer pèlerin',          pa:2, cost:0,   type:'legal', icon:'ti-walk',      successRate:100, desc:'+10 DIS pendant 1 jour. Accès facilité aux lieux saints des autres empires.'}
        ]
      },
      sacristie: {
        name: "Sacristie Administrative",
        imageBg: "linear-gradient(135deg,#080808,#100a08)",
        desc: "La pièce secrète du Grand Prêtre. Archives des confessions. Formulaires rares et tampons bénis.",
        imageUrl: "https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80",
        persons: [
          {name:'Percepteur Suprême Adolphe Taxe (PNJ)', role:'Grand Prêtre du Papyrusisme', rel:'neutral', job:'grand_pretre'}
        ],
        orders: [
          {fn:'excommunier',      label:'Excommunier un fidèle',       pa:3, cost:0,   type:'legal', icon:'ti-ban',       successRate:75, requiresPost:'grand_pretre', desc:'Cible perd -15 IP -10 POP dans l\'empire. Acte irréversible.'},
          {fn:'benediction_etat', label:'Bénir un acte d\'Etat',      pa:2, cost:0,   type:'legal', icon:'ti-crown',     successRate:100, requiresPost:'grand_pretre', desc:'+10 IP national. +5 popularité du chef d\'Etat.'},
          {fn:'consulter_confessions', label:'Consulter les confessions', pa:2, cost:0, type:'grey', icon:'ti-eye',      successRate:85, requiresPost:'grand_pretre', desc:'Révèle les derniers secrets confiés par les fidèles.'}
        ]
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
        imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/centre-multinodal-republic.png',
        desc: "Le hall principal. Gaston Retard annonce comme chaque matin un retard indéterminé sur la ligne Nord. Mireille Guichet sourit sans savoir.",
        imageUrl: "https://images.unsplash.com/photo-1517760444937-f6397edcbbcd?w=1200&q=80",
        persons: [
          {name:'Gaston Retard (PNJ)', role:'Chef de gare', rel:'neutral', job:'chef_gare'},
          {name:'Mireille Guichet (PNJ)', role:'Hôtesse d\'accueil', rel:'neutral', job:'hotesse'}
        ],
        orders: [
          {fn:'prendre_train', label:'Prendre le train', pa:2, cost:75, type:'legal', icon:'ti-train', successRate:100, desc:'75 FR. 2 PA. Transport intra-empire vers une autre ville.'},
          {fn:'prendre_bus_taxi', label:'Prendre un bus ou taxi', pa:1, cost:150, type:'legal', icon:'ti-bus', successRate:100, desc:'150 FR. 1 PA. Transport intra-empire uniquement.'},
          {fn:'prendre_bateau', label:'Prendre le bateau', pa:4, cost:100, type:'legal', icon:'ti-ship', successRate:100, desc:'100 FR. 4 PA. Inter-empire. Disponible depuis le port.'},
          {fn:'taxi_caserne', label:'Taxi vers la Caserne', pa:1, cost:200, type:'legal', icon:'ti-military-rank', successRate:100, desc:'200 FR. 1 PA. Accès conditionné sur place.'},
          {fn:'taxi_qhs', label:'Taxi vers le QHS', pa:1, cost:200, type:'legal', icon:'ti-lock', successRate:100, desc:'200 FR. 1 PA. Accès conditionné sur place.'}
        ]
      },
      hall_douanes: {
        name: "Hall des Douanes",
        imageBg: "linear-gradient(135deg,#08090f,#101215)",
        desc: "Le contrôle douanier. Obligatoire avant tout vol international. L\'Inspecteur Prosper Tampon veille avec son tampon béni.",
        imageUrl: "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=1200&q=80",
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
        imageUrl: "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=1200&q=80",
        locked: false,
        requiresDouane: true,
        persons: [],
        orders: [
          {fn:'prendre_avion', label:'Prendre l\'avion', pa:3, cost:250, type:'legal', icon:'ti-plane', successRate:100, desc:'250 FR. 3 PA. Vol vers un autre empire.'}
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
        imageUrl: "https://images.unsplash.com/photo-1517760444937-f6397edcbbcd?w=1200&q=80",
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
        imageUrl: "https://images.unsplash.com/photo-1517760444937-f6397edcbbcd?w=1200&q=80",
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

  // ---- PORTS ----

  'port-sainte-marie': {
    name: "Port de Port-Sainte-Marie",
    shortName: "Port PSM",
    cat: "Port",
    icon: "ti-anchor",
    bgColor: "#050810",
    desc: "Le grand port de Républia. Commerce maritime, syndicats puissants et réseaux de contrebande discrets.",
    rooms: {
      quai_principal: {
        name: "Quai Principal",
        imageBg: "linear-gradient(135deg,#050810,#0a0f18)",
        desc: "Les grues bleues s\'activent. Marcel Ancre surveille les entrées. Dédé le Docker discute d\'une éventuelle grève avec ses camarades.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-republia.png",
        persons: [
          {name:'Marcel Ancre (PNJ)', role:'Capitaine de port', rel:'neutral', job:'capitaine_port'},
          {name:'Dédé le Docker (PNJ)', role:'Docker syndiqué', rel:'neutral', job:'docker'},
          {name:'Ginette Conteneur (PNJ)', role:'Agente de fret', rel:'neutral', job:'agent_fret'}
        ],
        orders: [
          {fn:'prendre_bateau', label:'Prendre le bateau', pa:4, cost:100, type:'legal', icon:'ti-ship', successRate:100, desc:'100 FR. 4 PA. Transport inter-empire. Plus lent mais moins cher que l\'avion.'},
          {fn:'expedier_colis', label:'Expédier un colis', pa:2, cost:200, type:'legal', icon:'ti-package-export', successRate:100, desc:'Envoyer un objet de son inventaire à un PJ dans un autre empire. Délai 24h.'},
          {fn:'receptionner_commande', label:'Réceptionner une commande', pa:1, cost:0, type:'legal', icon:'ti-package-import', successRate:100, desc:'Récupérer un objet commandé depuis un autre empire.'},
          {fn:'contrebande_port', label:'Contrebande portuaire', pa:3, cost:0, type:'illegal', icon:'ti-package-off', successRate:55, desc:'Importer un objet illégal. DIS/10 + DUP/10. Zone port +15%. El Estado +25%.'},
          {fn:'blocus_portuaire', label:'Blocus portuaire', pa:3, cost:0, type:'grey', icon:'ti-barrier-block', successRate:60, desc:'Paralyse les importations/exportations 24h. VOL/10 + ENT/10. -IE. Prérogative syndicaliste.'},
          {fn:'inspecter_cargaisons', label:'Inspecter les cargaisons', pa:2, cost:0, type:'legal', icon:'ti-search', successRate:80, requiresPost:'min_def', desc:'Révèle contrebandes en cours. INT/10 + ISN/10. Prérogative min_def ou commissaire.'}
        ]
      },
      bureau_port: {
        name: "Bureau du Port",
        imageBg: "linear-gradient(135deg,#050810,#080d15)",
        desc: "Le bureau administratif. Formulaires d\'entrée en 3 exemplaires. Ginette sait tout ce qui transite.",
        imageUrl: "https://images.unsplash.com/photo-1578575437130-527eed3abbec?w=1200&q=80",
        persons: [
          {name:'Ginette Conteneur (PNJ)', role:'Agente de fret', rel:'neutral', job:'agent_fret'}
        ],
        orders: [
          {fn:'consulter_manifeste', label:'Consulter le manifeste', pa:1, cost:0, type:'grey', icon:'ti-file-search', successRate:75, desc:'Liste des cargaisons déclarées. INT/10. Révèle possibles contrebandes.'},
          {fn:'falsifier_manifeste', label:'Falsifier le manifeste', pa:2, cost:200, type:'illegal', icon:'ti-file-x', successRate:40, desc:'Faire disparaître une cargaison des registres. DUP/10.'}
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
          {fn:'prendre_bateau', label:'Prendre le bateau', pa:4, cost:100, type:'legal', icon:'ti-ship', successRate:100, desc:'100 FR. 4 PA. Transport inter-empire.'},
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
          {fn:'prendre_bateau', label:'Prendre le bateau', pa:4, cost:100, type:'legal', icon:'ti-ship', successRate:100, desc:'100 FR. 4 PA. Transport inter-empire.'},
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
          {fn:'prendre_bateau', label:'Prendre le bateau', pa:4, cost:100, type:'legal', icon:'ti-ship', successRate:100, desc:'100 FR. 4 PA. Transport inter-empire.'},
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
      'hemicycle':                'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/couloirs-an-republic.png',
      'couloirs':                 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/couloirs-an-republic.png',
      'salle_archives_assemblee': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/archives-an-republic.png'
    }
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
    }
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
    }
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
    }
  }
};

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
      {id:'min_ae',       name:'Ministre des AE',             niveau:5, unique:true,  holder:'PNJ-Durand',   isCapitale:true}
    ],
    assemblee: Array.from({length:9}, (_,i) => ({
      id:`depute_${i+1}`, name:`Depute Siege ${i+1}`, niveau:2,
      unique:true, holder: i < 7 ? `PNJ-Depute${i+1}` : null, isCapitale:true
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
  maire:       800,
  adj_maire:   500,
  gouverneur:  1500,
  prefet:      900,
  default:     150  // Citoyen sans poste
};

// Nouveaux ordres v6
Object.assign(ORDER_EFFECTS, {
  se_cacher:          {dis:5,            successRate:70},
  organiser_blocus:   {inf:8,            successRate:40},
  incendier:          {dis:-10,          successRate:30},
  tentative_evasion:  {dis:-5,           successRate:15},
  se_rebeller:        {moral:5,          successRate:30},
  requete_avocat:     {inf:2,            successRate:100},
  imprimer_tracts:    {pop:5,  inf:3,    successRate:100},
  imprimer_livre:     {pop:8,  inf:5,    successRate:100},
  imprimer_clandestin:{dis:-4,           successRate:70},
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
const PJ_SIMULES = [
  {
    name: 'Alexandre Moreau',
    archetype: 'politician',
    career: 'civil',
    poste: { id: 'depute_1', name: 'Depute' },
    stats: { INT:12, CHA:13, VOL:10, PER:11, DUP:9, ENT:12 },
    resources: { inf:45, pop:38, dis:70, hp:90, moral:75 },
    arg: 8500,
    country: 'republic',
    currentCity: 'capitale',
    currentBuilding: null,
    isPJ: true,
    isSimule: true,
    rel: 'neutral',
    role: 'Depute — Parti du Centre'
  },
  {
    name: 'Sophie Leroux',
    archetype: 'informer',
    career: 'press',
    poste: null,
    stats: { INT:13, CHA:11, VOL:9, PER:14, DUP:12, ENT:10 },
    resources: { inf:30, pop:55, dis:80, hp:95, moral:85 },
    arg: 3200,
    country: 'republic',
    currentCity: 'capitale',
    currentBuilding: null,
    isPJ: true,
    isSimule: true,
    rel: 'neutral',
    role: 'Journaliste — La Tribune'
  },
  {
    name: 'Viktor Krasov',
    archetype: 'shadow',
    career: 'intel',
    poste: null,
    stats: { INT:11, CHA:8, VOL:12, PER:13, DUP:15, ENT:9 },
    resources: { inf:20, pop:10, dis:95, hp:88, moral:60 },
    arg: 12000,
    country: 'republic',
    currentCity: 'capitale',
    currentBuilding: null,
    isPJ: true,
    isSimule: true,
    rel: 'neutral',
    role: 'Agent — Services secrets'
  }
];

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
  const isn = INDICES_NATIONAUX[country]?.ISN || 30;
  if (isn <= 20) return 0;
  if (isn <= 40) return 5;
  if (isn <= 60) return 10;
  if (isn <= 80) return 15;
  return 25;
}

function getMultDetection(country) {
  const isn = INDICES_NATIONAUX[country]?.ISN || 30;
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
