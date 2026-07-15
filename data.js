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
      buildings: ['palais-presidentiel','hotel-republica','palais-gouvernement','assemblee','tribunal','banque-nationale','banque-privee','clinique-privee','dispensaire-public','commissariat','la-tribune','loge-maconnique','universite','armurerie','marche','mairie-capitale','tabernacle-impots','centre-multinodal-luthecia','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-1','terrain-a-batir-4','terrain-a-batir-5','terrain-a-batir-6','terrain-a-batir-7','office-notarial','stade','quartier-ambassades','place-formulaire-liberte'],
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
          desc: "Le grand hôtel de Luthecia. Gaston Sauceblanche règne sur la salle avec un mépris souverain.",
          persons: [{"name": "Gaston Sauceblanche (PNJ)", "role": "Maître d'hôtel", "rel": "neutral", "job": "serveur", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gaston-sauceblanche.png", "photoPos": "50% 15%"}, {"name": "Yvette Gratinée (PNJ)", "role": "Serveuse", "rel": "neutral", "job": "serveur", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/yvette-gratinee.png", "photoPos": "50% 15%"}]
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
          persons: [{"name": "Gustave Encre (PNJ)", "role": "Imprimeur", "rel": "neutral", "job": "journaliste"}, {"name": "Rosalie Caractère (PNJ)", "role": "Libraire", "rel": "neutral", "job": "journaliste"}, {"name": "Jodie Moitout (PNJ)", "role": "Journaliste micro-trottoir", "rel": "neutral", "job": "journaliste", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jodie-moitout.png", "photoPos": "62% 20%"}]
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
            {fn:'acheter_poison_parapluie', label:'Parapluie républien', pa:1, cost:400, type:'illegal', icon:'ti-umbrella', successRate:100, desc:'Un accessoire élégant. La pointe contient... quelque chose. Usage unique.', imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/parapluie-republicain.png'}
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
          persons: [{"name": "Jean-Pierre Bidoche (PNJ)", "role": "Boucher", "rel": "neutral", "job": "commercant", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marcel-bidoche.png", "photoPos": "65% 30%"}, {"name": "Ginette Légume (PNJ)", "role": "Maraîchère", "rel": "neutral", "job": "commercant", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/ginette-legume.png", "photoPos": "65% 25%"}, {"name": "Jodie Moitout (PNJ)", "role": "Journaliste micro-trottoir", "rel": "neutral", "job": "journaliste", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jodie-moitout.png", "photoPos": "62% 20%"}]
        }
      }
    },
    ville_a: {
      name:'Port-Sainte-Marie',
      imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie.png',
      desc:'Ville portuaire a l\'ouest. Commerce, contrebande et politique locale.',
      isCapitale: false,
      buildings: ['hotel-port','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','bar-des-pecheurs','imprimerie-librairie','centre-multinodal-port-sainte-marie','port-sainte-marie','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-2','stade','zone-production'],
      buildingContext: {
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
          persons: [{"name": "Marinette Hareng (PNJ)", "role": "Poissonnière", "rel": "neutral", "job": "commercant", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marinette-hareng.png", "photoPos": "65% 35%"}]
        }
      }
    },
    ville_b: {
      name:'Montrouge',
      imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/montrouge.png',
      desc:'Ville industrielle au nord. Syndicats puissants, usines et tensions sociales.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-3','stade','zone-production'],
      buildingContext: {
        'stade': {
          name: "Stade Marcel Cazenave — Union Cheminote de Montrouge",
          desc: "Colle aux voies ferrees. Les Cheminots jouent avec la rage des quartiers ouvriers.",
          persons: [
            {name:'Jean-Philippe Hervitmonfute (PNJ)', role:'Entraineur', rel:'neutral', job:'entraineur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entraineur-montrouge-hervitmonfute.png'},
            {name:'Émilie Charbon (PNJ)', role:'Journaliste Sportive', rel:'neutral', job:'commentateur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/journaliste-montrouge-emilie-charbon.png'}
          ],
          roomOverrides: {
            terrain: { name: "Terrain — Union Cheminote de Montrouge", imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/stade-union-cheminote-montrouge.png" },
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
            {fn:'acheter_poison_ghb', label:'GHB de contrebande', pa:1, cost:300, type:'illegal', icon:'ti-flask', successRate:100, desc:'Inodore, incolore. Carlos vous glisse le flacon sans un mot. Usage unique.', imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/ghb-narco.png'}
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
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-3','stade','zone-production'],
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
            {fn:'acheter_poison_polonium', label:'Fiole de Polonium', pa:1, cost:600, type:'illegal', icon:'ti-radioactive', successRate:100, desc:'Ne pas ouvrir sans combinaison. Camarade Kalachnikov la sort d\'un tiroir blindé. Usage unique.', imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/polonium-sovarka.png'}
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
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-3','stade','zone-production'],
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
            {fn:'acheter_poison_vipere', label:'Vipère des sables', pa:1, cost:350, type:'illegal', icon:'ti-bug', successRate:100, desc:'Une petite boîte percée. On entend un léger sifflement. Hassan sourit. Usage unique.', imageUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/vipere-des-sables-khalija.png'}
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
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-3','stade','zone-production'],
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
  policier:         { FOR:8,  CHA:4,  DUP:4,  INT:5,  loyaute:60, recrutCout:400,  recrutLabel:'Policier',        combatBonus:{ for:5 } },
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
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotel-republica-restaurant.png",
        persons: [
          {name:'Paulo (Maitre d\'hotel)', role:'PNJ - Service', rel:'neutral', job:'serveur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gaston-sauceblanche.png', photoPos:'50% 15%'},
          {name:'Jean Dupont (PNJ)',       role:'Depute - Parti du Centre', rel:'neutral', job:'commercant', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jean-dupont-marie-leblanc.png', photoPos:'20% 30%'},
          {name:'Marie Leblanc (PNJ)',    role:'Journaliste - La Tribune', rel:'enemy',  job:'journaliste', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jean-dupont-marie-leblanc.png', photoPos:'70% 30%'}
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
          {name:'Marco (Barman)', role:'PNJ - Barman', rel:'neutral', job:'barman', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marco-barman.png', photoPos:'50% 20%'},
          {name:'Roxane Velours (PNJ)', role:'Escort de luxe', rel:'neutral', job:'escort'},
          {name:'Un lobbyiste',   role:'Inconnu - Discretion de mise', rel:'neutral', job:null}
        ],
        orders: [
          {fn:'se_nourrir',      label:'Boire un verre',        pa:0, cost:10,  type:'legal', icon:'ti-glass',    successRate:100, desc:'Consommation. +1 Moral.'},
          {fn:'ecouter',         label:'Ecouter le barman',     pa:0, cost:0,   type:'grey',  icon:'ti-ear',      successRate:90,  desc:'Le barman entend tout.'},
          {fn:'recruter_info',   label:'Recruter un informateur N1',pa:1,cost:150, type:'grey',  icon:'ti-user-plus',successRate:75,  desc:'150 FR/jour. Localisation approximative, rumeurs locales.'},
          {fn:'escort_infos',    label:'Recueillir des informations', pa:2, cost:300, type:'grey', icon:'ti-ear', successRate:75, desc:'Roxane collecte des confidences. Génère un kompromat sur une cible.'},
          {fn:'escort_piege',    label:'Organiser une rencontre piège', pa:3, cost:800, type:'illegal', icon:'ti-spy', successRate:55, desc:'Piéger un adversaire politique. Risque de scandale.'}
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
      },
      suite_privee: {
        name: "Suite Privée — Local à louer",
        imageBg: "linear-gradient(135deg,#1a0d10,#250f18)",
        desc: "📋 À LOUER — Suite luxueuse et très discrète. Roxane y reçoit une clientèle triée sur le volet. Informations exclusives garanties.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotel-republica-suite-privee.png",
        isLocationRoom: true,
        locationData: { prix: 500, bonusPOP: 0, bonusINF: 8, bonusDIS: 10, label: 'Suite Privée', tier: 1 },
        persons: [
          {name:'Roxane Velours (PNJ)', role:'Escort de luxe', rel:'neutral', job:'escort', photoUrl:'', trait:'Son carnet d\'adresses vaut plus que celui du Premier Ministre.'}
        ],
        orders: [
          {fn:'louer_local', label:'Louer cette suite (500 FR/jour)', pa:1, cost:0, type:'grey', icon:'ti-key', successRate:100, desc:'+8 INF +10 DIS. Clients très discrets, informations très utiles.'},
          {fn:'escort_infos', label:'Recueillir des informations', pa:2, cost:300, type:'grey', icon:'ti-ear', successRate:75, desc:'Roxane collecte des confidences. Génère un kompromat.'},
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
        imageUrl: "https://images.unsplash.com/photo-1588681664899-f142ff2dc9b1?w=1200&q=80",
        persons: [
          {name:'Porte-parole presidentiel (PNJ)', role:'PNJ - Porte-parole de la presidence', rel:'neutral', job:'porteparole'}
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
        desc: "Le hall monumental du Palais. Rotonde a coupole, escalier d'honneur, gardes republicains en faction.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-palais-gouvernement-republic.png",
        persons: [
          {name:'Garde Martineau',   role:'PNJ - Securite', rel:'neutral', job:'garde'},
          {name:'Secretaire Dupuis', role:'PNJ - Accueil officiel', rel:'neutral', job:'secretaire'}
        ],
        orders: [
          {fn:'postuler', label:'Postuler a un poste', pa:2, cost:0, type:'legal', icon:'ti-id-badge', successRate:85, desc:'PNJ : automatique. PM/President PJ : impossible.'},
          {fn:'organigramme', label:'Organigramme du pays', pa:0, cost:0, type:'legal', icon:'ti-sitemap', successRate:100, desc:'Voir qui occupe chaque poste dans votre empire.'}
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
        persons: [],
        orders: [
          {fn:'mobiliser_police',     label:'Faire intervenir les forces de l\'ordre', pa:2, cost:0, type:'legal', icon:'ti-shield', successRate:100, requiresPost:'min_int', desc:'Choisir un type d\'intervention concrete (blocus, manifestation, quartier sensible).'},
          {fn:'traiter_manifestations', label:'Traiter les demandes de manifestation', pa:1, cost:0, type:'legal', icon:'ti-users-group', successRate:100, requiresPost:'min_int', desc:'Autoriser ou interdire un rassemblement declare.'},
          {fn:'demandes_naturalisation', label:'Demandes de naturalisation', pa:0, cost:0, type:'legal', icon:'ti-passport', successRate:100, requiresPost:'min_int', desc:'Examiner les demandes de naturalisation en attente (delai 48h avant traitement possible).'},
          {fn:'gerer_couvre_feu',    label:'Instaurer un couvre-feu',     pa:2, cost:0, type:'legal', icon:'ti-moon', successRate:100, requiresPost:'min_int', desc:'20h-6h, 2 jours maximum. Degrade IS et POP du gouvernement tant qu\'il dure.'}
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
          {fn:'fixer_impots_nationaux', label:'Fixer le taux d\'imposition national', pa:2, cost:0,   type:'legal',   icon:'ti-percentage',    successRate:100, requiresPost:'min_fin', desc:'Voir et modifier le taux d\'imposition national en vigueur.'},
          {fn:'redressement_fiscal',  label:'Ordonner un redressement',     pa:2, cost:0,   type:'legal',   icon:'ti-gavel',          successRate:80,  requiresPost:'min_fin', desc:'Cibler un citoyen, un club sportif, une entreprise ou une organisation. Genere des recettes pour l\'Etat mais cree des ennemis.'},
          {fn:'subvention',           label:'Accorder une subvention',      pa:2, cost:0, type:'legal',   icon:'ti-coins',          successRate:100, requiresPost:'min_fin', desc:'Cibler un citoyen, un club sportif, une entreprise ou une organisation. Montant a fixer ensuite (plafond 5000 FR).'},
          {fn:'fiscal',              label:'Repartition budgetaire',       pa:2, cost:0, type:'legal', icon:'ti-chart-pie',   successRate:100, requiresPost:'min_fin', desc:'Fixer la repartition des recettes fiscales entre les institutions. Prerogative exclusive du Ministre des Finances.'}
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
          {fn:'annuler_poursuites',   label:'Classer une plainte',          pa:2, cost:0,   type:'grey',    icon:'ti-file-x',         successRate:70,  requiresPost:'min_just', desc:'Classer une plainte en cours avant jugement. Cree une dette politique. Coute a la caisse du gouvernement.'},
          {fn:'ouvrir_enquete',       label:'Ouvrir une enquete',           pa:2, cost:0,   type:'legal',   icon:'ti-search',         successRate:90,  requiresPost:'min_just', desc:'Cibler un citoyen, un club sportif, une entreprise ou une organisation. Coute a la caisse du gouvernement.'},
          {fn:'proposer_grace',      label:'Proposer une grace',           pa:2, cost:0,   type:'legal',   icon:'ti-heart-handshake',successRate:100, requiresPost:'min_just', desc:'Recommander une grace au President — qui devra valider.'},
          {fn:'nommer_juge',          label:'Nommer un juge',               pa:3, cost:0,   type:'legal',   icon:'ti-gavel',          successRate:90,  requiresPost:'min_just', desc:'Nommer un magistrat favorable. Influence les verdicts futurs.'},
          {fn:'gestion_qhs',          label:'Gestion du QHS',               pa:0, cost:0,   type:'legal',   icon:'ti-building-fortress', successRate:100, requiresPost:'min_just', desc:'Budget dedie et liste des detenus du QHS. Transferer, ameliorer les conditions, ou faire torturer.'}
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
          {fn:'mobiliser_armee',      label:'Mobiliser l\'armee',          pa:4, cost:0,   type:'legal',   icon:'ti-military-rank',  successRate:100, requiresPost:'min_def', desc:'Choisir une destination et donner une feuille de route secrete au Commandant.'},
          {fn:'activer_cessez_le_feu', label:'Activer un cessez-le-feu',  pa:2, cost:0,   type:'legal',   icon:'ti-handshake',      successRate:100, requiresPost:'min_def', desc:'Activer une treve deja negociee par la diplomatie. Chaque camp doit le faire de son cote.'},
          {fn:'nommer_commandant',   label:'Nommer le Commandant',       pa:2, cost:0,   type:'legal',   icon:'ti-star',           successRate:100, requiresPost:'min_def', desc:'Designer le Commandant de la Caserne.'},
          {fn:'recruter_compagnie',  label:'Recruter une compagnie',     pa:3, cost:0,   type:'legal',   icon:'ti-users-group',    successRate:100, requiresPost:'min_def', desc:'100 soldats (4 sections). Coute a la caisse de la caserne.'},
          {fn:'renseignement',        label:'Lancer une operation de renseignement', pa:3, cost:500, type:'grey', icon:'ti-spy', successRate:70, requiresPost:'min_def', desc:'Espionner un empire etranger. (Substance a venir.)'},
          {fn:'requisition_civile',  label:'Réquisition civile',        pa:3, cost:0, type:'legal', icon:'ti-users', successRate:100, requiresPost:'min_def', desc:'Tirage au sort de 24 citoyens pour doubler l\'effectif d\'une section. Uniquement pendant une mobilisation nationale.'}
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
          {name:'President Laroche', role:"President de l\'Assemblee (PNJ)", rel:'neutral', job:'president', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/president-assemblee-laroche.png'},
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
          {name:'Notaire Fontenelle (PNJ)', role:'Notaire Officiel', rel:'neutral', job:'notaire'},
          {name:'Clerc Delahaye (PNJ)', role:'Clerc de notaire', rel:'neutral', job:'clerc_notaire'}
        ],
        orders: [
          {fn:'presentation_office_notarial', label:'Se renseigner sur les services', pa:0, cost:0, type:'legal', icon:'ti-info-circle', successRate:100, desc:'Ventes de terrain, successions, contrats de mariage, archives — presentation des services du notaire.'}
        ]
      },
      bureau_successions: {
        name: "Bureau des Successions",
        image: "📜",
        imageBg: "linear-gradient(135deg,#14100c,#1c1610)",
        desc: "Le bureau ou se traitent les heritages. Les dossiers s'empilent, les familles se dechirent.",
        persons: [
          {name:'Clerc Delahaye (PNJ)', role:'Clerc de notaire', rel:'neutral', job:'clerc_notaire'}
        ],
        orders: [
          {fn:'redaction_testament', label:'Rediger un testament', pa:2, cost:500, type:'legal', icon:'ti-file-text', successRate:100, desc:'Designer un heritier de son choix, plutot que la devolution par defaut.'},
          {fn:'consulter_succession', label:'Consulter une succession', pa:1, cost:100, type:'legal', icon:'ti-search', successRate:100, desc:'Verifier qui a herite de qui, et de quoi.'}
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
          {fn:'contrat_mariage', label:'Negocier un contrat de mariage', pa:2, cost:400, type:'legal', icon:'ti-heart-handshake', successRate:100, desc:'Choisir le regime matrimonial (communaute, separation de biens) plutot que la copropriete par defaut.'}
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
          {fn:'consulter_archives_notariales', label:'Consulter les archives notariales', pa:1, cost:0, type:'legal', icon:'ti-archive', successRate:100, desc:'Historique complet et permanent des biens, mariages et successions. Recherche par nom de personnage.'}
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
          {fn:'regarder_live', label:'Regarder le live', pa:1, cost:0, type:'legal', icon:'ti-device-tv', successRate:100, desc:'Suivre le deroule minute par minute du match de votre choix parmi la derniere journee jouee.'}
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
          {fn:'prendre_licence_sportive', label:'Prendre sa licence sportive', pa:1, cost:300, type:'legal', icon:'ti-license', successRate:100, desc:'Seule condition pour s\'entrainer ou jouer. 300 FR.'},
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
          {fn:'rejoindre_club_supporters', label:'Rejoindre le club de supporters', pa:1, cost:150, type:'legal', icon:'ti-users-group', successRate:100, desc:'Adherer au club de supporters de la ville (150 FR/saison).'},
          {fn:'consulter_palmares', label:'Consulter le palmares du club', pa:0, cost:0, type:'legal', icon:'ti-archive', successRate:100, desc:'Historique complet et permanent : resultats de chaque championnat, articles de presse marquants. Rien ne s\'efface jamais ici.'},
          {fn:'consulter_organigramme_supporters', label:'Consulter l\'organigramme', pa:0, cost:0, type:'legal', icon:'ti-sitemap', successRate:100, desc:'Composition complete du club de supporters, visible de tous.'},
          {fn:'declencher_election_club', label:'Déclencher une élection', pa:1, cost:0, type:'legal', icon:'ti-ballot', successRate:100, desc:'Reserve aux membres. 3 jours de candidatures puis 3 jours de vote.'},
          {fn:'organiser_manifestation', label:'Organiser une manifestation', pa:2, cost:0, type:'legal', icon:'ti-megaphone', successRate:100, desc:'Reserve au president. Pour ou contre le maire. Intensite liee au nombre de membres.'},
          {fn:'organiser_boycott', label:'Organiser un boycott', pa:2, cost:0, type:'legal', icon:'ti-ban', successRate:100, desc:'Reserve au president. Boycotte le prochain match a domicile.'},
          {fn:'distribuer_tracts_match', label:'Distribuer des tracts avant le match', pa:2, cost:0, type:'legal', icon:'ti-flag', successRate:100, desc:'Reserve aux candidats declares. Efficacite liee a la frequentation et au classement du club.'}
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
        imageUrl: "https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=1200&q=80",
        persons: [
          {name:'Juge Fontaine',  role:'Presidente du Tribunal (PNJ)', rel:'neutral', job:'juge'},
          {name:'Procureur Saad', role:'Ministere public (PNJ)', rel:'neutral', job:'procureur'}
        ],
        orders: [
          {fn:'plainte',   label:'Consulter les affaires en cours', pa:1, cost:0,   type:'legal',   icon:'ti-gavel',   successRate:100, desc:'Voir le statut des affaires en cours : en attente de traitement, enquete en cours, transmise au tribunal, jugee.'},
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
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/banque-nationale-accueil.png",
        persons: [
          {name:'Directeur Mercier', role:"PNJ - Directeur d'agence", rel:'neutral', job:'directeur'}
        ],
        orders: [
          {fn:'gerer_finances', label:'Gerer mon compte',    pa:0, cost:0,    type:'legal', icon:'ti-chart-bar',   successRate:100, desc:'Deposer ou retirer de l\'argent. Voir son solde.'},
          {fn:'investir',       label:'Investir',            pa:2, cost:500,  type:'legal', icon:'ti-trending-up', successRate:75,  desc:'Placer des fonds. Rendement dans 24h.'},
          {fn:'emprunter',      label:'Emprunter',           pa:1, cost:0,    type:'legal', icon:'ti-credit-card', successRate:70,  desc:'Contracter un pret. Taux selon dossier.'},
          {fn:'fiscal',         label:'Optimisation fiscale',pa:1, cost:200,  type:'grey',  icon:'ti-calculator',  successRate:85,  desc:'Reduire sa fiscalite. Semi-legal.'}
        ]
      },
      coffre_privatif: {
        name: "Coffre Privatif — Local à louer",
        imageBg: "linear-gradient(135deg,#050810,#0a0f15)",
        desc: "📋 À LOUER — Espace sécurisé dans les sous-sols de la banque. Accès biométrique, surveillance 24h. Le Directeur Mercier ne pose jamais de questions sur le contenu.",
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
        imageUrl: "https://images.unsplash.com/photo-1553729459-efe14ef6055d?w=1200&q=80",
        persons: [
          {name:'M. Fischer', role:'PNJ - Gestionnaire de patrimoine', rel:'neutral', job:'banquier'}
        ],
        orders: [
          {fn:'gerer_finances',    label:'Gerer mon compte',      pa:0, cost:0,    type:'legal',   icon:'ti-chart-bar',    successRate:100, desc:'Depot ou retrait discret.'},
          {fn:'compte_offshore',   label:'Ouvrir compte offshore', pa:2, cost:1000, type:'grey',    icon:'ti-world',        successRate:80,  desc:'Compte hors Republia. Moins tracable.'},
          {fn:'emprunter_prive',   label:'Emprunter (sans verification)', pa:1, cost:0, type:'grey', icon:'ti-credit-card', successRate:100, desc:'Aucune verification. Taux eleve. Methode de recouvrement... directe en cas d\'impaye.'},
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
          {fn:'soins_discrets', label:'Soins sans trace',            pa:1, cost:800, type:'grey',  icon:'ti-eye-off',     successRate:95,  desc:'+30 Sante. Aucune trace medicale.'},
          {fn:'parler_pnj', label:'Parler', pa:1, cost:0, type:'legal', icon:'ti-message-circle', successRate:100, desc:'Discuter avec le personnel soignant.'},
          {fn:'se_nourrir', label:'Manger', pa:1, cost:30, type:'legal', icon:'ti-soup', successRate:100, desc:'Un repas de qualite, servi au chevet.'}
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
          {fn:'soins',          label:'Consultation medecin',    pa:0, cost:20,  type:'legal', icon:'ti-stethoscope',successRate:100, desc:'+15 Sante.'},
          {fn:'transfert_clinique_privee', label:'Être transféré en clinique privée', pa:0, cost:1000, type:'legal', icon:'ti-ambulance', successRate:100, desc:'Meilleure prise en charge, convalescence plus rapide. 1000 FR.'},
          {fn:'parler_pnj', label:'Parler', pa:1, cost:0, type:'legal', icon:'ti-message-circle', successRate:100, desc:'Discuter avec le personnel soignant.'},
          {fn:'se_nourrir', label:'Manger', pa:1, cost:15, type:'legal', icon:'ti-soup', successRate:100, desc:'Un repas simple, servi au chevet.'}
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
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-accueil.png",
        persons: [
          {name:'Commissaire Gros', role:'PNJ - Chef de la police', rel:'neutral', job:'commissaire'},
          {name:'Agent Petit',      role:'PNJ - Officier de garde', rel:'neutral', job:'policier'}
        ],
        orders: [
          {fn:'plainte_police',   label:'Porter plainte',         pa:1, cost:0,   type:'legal',   icon:'ti-file-text', successRate:100, desc:'Contre une personne identifiee ou contre X. Reponse sous 24h.'},
          {fn:'archives_police',  label:'Consulter les archives', pa:1, cost:0,   type:'legal',   icon:'ti-archive',   successRate:95,  desc:'Succes (95%) : liste des personnes emprisonnees les 30 derniers jours.'},
          {fn:'arreter',          label:"Faire arreter quelqu'un",pa:3, cost:500, type:'illegal', icon:'ti-handcuffs', successRate:50,  desc:'Necessite un dossier. Mise en garde a vue 24h.'},
          {fn:'se_justifier',     label:'Se justifier (convocation)', pa:2, cost:0, type:'legal', icon:'ti-message-question', successRate:100, desc:'Se presenter suite a une convocation recue par mail. Leve l\'avis de recherche associe.'}
        ]
      },
      prison: {
        name: "Cellules de garde a vue",
        desc: "Les cellules de garde à vue du commissariat. Froid, humide, déprimant.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cellule-garde-a-vue-luthecia.png",
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
          {fn:'parler_pnj',    label:'Parler à la standardiste', pa:0, cost:0, type:'legal', icon:'ti-message', successRate:100},
          {fn:'se_renseigner', label:'Se renseigner',            pa:0, cost:0, type:'legal', icon:'ti-info-circle', successRate:100}
        ]
      },
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
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/universite-amphi-v2.png",
        persons: [
          {name:'Professeur Blanc', role:'PNJ - Economiste influent', rel:'neutral', job:'professeur'}
        ],
        orders: [
          {fn:'se_former',      label:'Suivre une formation',   pa:2, cost:100, type:'legal', icon:'ti-book',        successRate:100, desc:'+XP competences intellectuelles.'},
          {fn:'donner_conf',    label:'Donner une conference',  pa:2, cost:0,   type:'legal', icon:'ti-microphone',  successRate:75,  desc:'+POP +INF selon audience.'},
          {fn:'recruter_etud',  label:'Recruter des militants', pa:2, cost:0,   type:'grey',  icon:'ti-users-group', successRate:70,  desc:'Constituer un reseau militant.'}
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
          {fn:'recruter_etud', label:'Recruter des militants', pa:2, cost:0, type:'legal', icon:'ti-users', successRate:70, desc:'Recruter depuis l\'université. +INF.'},
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
          {
            fn:'acheter_bombe_illegale',
            label:'Acheter des explosifs (marche noir)',
            pa:2, cost:1200, type:'illegal', icon:'ti-bomb', successRate:40,
            desc:'ILLEGAL. Non enregistre. Taux de reussite 40%. Echec : le vendeur alerte la police, vous devenez recherche(e).'
          },
          {fn:'produire_arme', label:'Produire une arme', pa:0, cost:0, type:'legal', icon:'ti-hammer', successRate:100, desc:'Fabrication contre salaire (Unites de Temps). Necessite des materiaux en stock.'},
          {fn:'acheter_produit_stock', label:'Acheter en stock (fabrication maison)', pa:1, cost:0, type:'legal', icon:'ti-package', successRate:100, desc:'Armes produites par de vrais joueurs, au prix fixe par le proprietaire.'},
          {fn:'vendre_matiere_armurerie', label:'Vendre des matieres premieres', pa:1, cost:0, type:'legal', icon:'ti-truck-delivery', successRate:100, desc:'Metal, bois — au prix fixe par le proprietaire de l\'armurerie.'},
          {fn:'racheter_armurerie', label:'Racheter cette entreprise', pa:0, cost:130000, type:'legal', icon:'ti-building-store', successRate:100, desc:'Devenir proprietaire de l\'armurerie (actuellement tenue par un PNJ).'},
          {fn:'gerer_armurerie', label:'Gérer mon armurerie', pa:0, cost:0, type:'legal', icon:'ti-settings', successRate:100, desc:'Reserve au proprietaire. Tarifs, prix des matieres, prix de vente, stock maximum.'}
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
          {fn:'consulter_indices_locaux', label:'Consulter les indices locaux', pa:0, cost:0, type:'legal', icon:'ti-chart-histogram', successRate:100, desc:'Securite, vie associative, education, cadre de vie de la ville.'},
          {fn:'objet_trouve', label:'Reclamer un objet trouve', pa:1, cost:0, type:'legal', icon:'ti-briefcase', successRate:100, desc:'Le service des objets trouves. On ne sait jamais ce qui finit dans une boite en carton...'}
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
          {fn:'traiter_demandes_permis', label:'Traiter les demandes de permis', pa:1, cost:0, type:'legal', icon:'ti-stamp', successRate:100, requiresPost:'maire', desc:'Valider ou refuser les permis de construire arrives a instruction terminee.'},
          {fn:'campagne_securite',     label:'Lancer une campagne de securite',pa:2, cost:500, type:'legal', icon:'ti-shield',     successRate:80,  requiresPost:'maire', desc:'+10 ISN local. Deploiement de forces de l\'ordre supplementaires. Preleve sur budget mairie.'},
          {fn:'acte_officiel_mairie',  label:'Delivrer un acte officiel',     pa:1, cost:0, type:'legal', icon:'ti-file-certificate', successRate:100, requiresPost:'maire', desc:'Choisir le type d\'acte a delivrer a un administre.'},
          {fn:'contester_resultats',   label:'Contester des resultats',       pa:2, cost:0, type:'legal', icon:'ti-alert-triangle', successRate:70, desc:'Deposer un recours dans le sous-forum Tribunal. Delai 48h. Decision du juge.'},
          {fn:'nommer_commissaire',    label:'Nommer un commissaire',         pa:3, cost:0, type:'legal', icon:'ti-shield-lock', successRate:100, requiresPost:'maire', desc:'Nommer un PJ habitant de la ville comme commissaire. Poste exclusif (sauf depute).'}
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

  'terrain-a-batir-4': {
    name: "Terrain a batir - Lot 4",
    shortName: "Terrain Lot 4",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Terrain disponible a la construction. Quartier Est.",
    rooms: {
      terrain: {
        name: "Terrain vague",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Un terrain en friche. Enormes possibilites.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:5000, type:'legal', icon:'ti-home-plus', successRate:100},
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'}
        ]
      }
    }
  },
  'terrain-a-batir-5': {
    name: "Terrain a batir - Lot 5", shortName: "Terrain Lot 5", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain disponible. Quartier Nord.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},{fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},{fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:25000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-6': {
    name: "Terrain a batir - Lot 6", shortName: "Terrain Lot 6", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain disponible. Quartier Sud.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},{fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},{fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:25000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
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
      }
    }
  },

  'terrain-a-batir-7': {
    name: "Terrain a batir - Lot 7", shortName: "Terrain Lot 7", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain disponible. Quartier Ouest.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},{fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},{fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:25000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-4': {
    name: "Terrain a batir - Lot 4", shortName: "Terrain Lot 4", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain disponible. Quartier Est.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},{fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},{fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:25000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-5': {
    name: "Terrain a batir - Lot 5", shortName: "Terrain Lot 5", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain disponible. Quartier Nord.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},{fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},{fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:25000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-6': {
    name: "Terrain a batir - Lot 6", shortName: "Terrain Lot 6", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain disponible. Quartier Sud.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},{fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},{fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:25000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-7': {
    name: "Terrain a batir - Lot 7", shortName: "Terrain Lot 7", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain disponible. Quartier Ouest.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},{fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},{fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:25000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
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
          {fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},
          {fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},
          {fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},
          {fn:'donner_argent_pnj', label:'Donner de l\'argent', pa:1, cost:0, type:'legal', icon:'ti-coins', successRate:0, desc:'Offrir une somme a un PNJ present. Effet immediat selon sa personnalite.'},
          {fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'},
          {fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:5000, type:'legal', icon:'ti-home-plus', successRate:100},
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
          {fn:'postuler',      label:'Postuler comme maire',   pa:2, cost:0,  type:'legal', icon:'ti-id-badge',   successRate:80},
          {fn:'gerer_finances',label:'Gerer les finances locales',pa:1,cost:0,type:'legal', icon:'ti-chart-bar',  successRate:100, requiresPost:true},
          {fn:'corrompre_fonct',label:'Corrompre un employ',   pa:2, cost:200,type:'illegal',icon:'ti-coins',     successRate:65},
          {fn:'demander_naturalisation', label:'Demander la naturalisation', pa:2, cost:0, type:'legal', icon:'ti-passport', successRate:100, desc:'Deposer une demande de naturalisation vers un autre empire. Validee par le Ministre de l\'Interieur concerne.'},
          {fn:'demander_mariage', label:'Demander en mariage', pa:1, cost:0, type:'legal', icon:'ti-heart', successRate:100, desc:'Envoyer une demande en mariage a un autre PJ. Necessitera une ceremonie a la mairie pour officialiser.'},
          {fn:'officialiser_mariage', label:'Officialiser un mariage', pa:2, cost:200, type:'legal', icon:'ti-heart-handshake', successRate:100, desc:'Celebrer le mariage. Les deux futurs epoux doivent etre presents.'},
          {fn:'consulter_indices_locaux', label:'Consulter les indices locaux', pa:0, cost:0, type:'legal', icon:'ti-chart-histogram', successRate:100, desc:'Securite, vie associative, education, cadre de vie de la ville.'}
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
          {fn:'repartition_budget_local', label:'Répartir le budget municipal', pa:2, cost:0, type:'legal', icon:'ti-chart-pie',    successRate:100, requiresPost:'maire', desc:'Allouer le budget entre Securite, Associations sportives et culturelles, Ecoles et Espaces verts. Chaque poste alimente son indice local correspondant.'},
          {fn:'traiter_demandes_permis', label:'Traiter les demandes de permis', pa:1, cost:0, type:'legal', icon:'ti-stamp', successRate:100, requiresPost:'maire', desc:'Valider ou refuser les permis de construire arrives a instruction terminee.'},
          {fn:'campagne_securite',     label:'Lancer une campagne de securite',pa:2, cost:500, type:'legal', icon:'ti-shield',     successRate:80,  requiresPost:'maire', desc:'+10 ISN local. Preleve sur budget mairie.'},
          {fn:'nommer_commissaire',    label:'Nommer un commissaire',         pa:3, cost:0, type:'legal', icon:'ti-shield-lock', successRate:100, requiresPost:'maire', desc:'Nommer un PJ habitant de la ville comme commissaire. Poste exclusif (sauf depute).'}
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
      arriere_salle: {
        name: "Arrière-Salle — Local à louer",
        imageBg: "linear-gradient(135deg,#0a0d10,#080c0f)",
        desc: "📋 À LOUER — L'arrière-salle du bar. Idéal pour un tripot, des réunions discrètes ou un quartier général criminel. Personne ne pose de questions ici.",
        imageUrl: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=1200&q=80",
        isLocationRoom: true,
        locationData: { prix: 120, bonusPOP: 0, bonusINF: 2, bonusDIS: 8, label: 'Arrière-Salle du Bar', tier: 2, usages: ['tripot','reunion_secrete','orga_criminelle'] },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer cette arrière-salle (120 FR/jour)', pa:1, cost:0, type:'grey', icon:'ti-key', successRate:100, desc:'+8 DIS +2 INF. Personne ne sait ce qui se passe là-dedans.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      },
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
          {fn:'defense',   label:'Se defendre',           pa:2, cost:300, type:'legal',   icon:'ti-shield',  successRate:75},
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
        imageUrl: "https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=1200&q=80",
        persons: [
          {name:'Gutenberg (Imprimeur)', role:'PNJ - Proprietaire imprimerie', rel:'neutral', job:'imprimeur'}
        ],
        orders: [
          {fn:'imprimer_tracts',  label:'Faire imprimer des tracts',  pa:2, cost:150, type:'legal',   icon:'ti-file-description', successRate:100, desc:'Choisir pour/contre + cible (repertoire) + quantite. Tracts en inventaire.'},
          {fn:'imprimer_livre',   label:'Faire imprimer un livre',    pa:3, cost:500, type:'legal',   icon:'ti-book',             successRate:100, desc:'Publication d\'un ouvrage. Augmente la notoriete intellectuelle.'},
          {fn:'imprimer_clandestin', label:'Impression clandestine',  pa:2, cost:300, type:'illegal', icon:'ti-eye-off',          successRate:70,  desc:'Documents non officiels, faux papiers, tracts interdits.'},
          {fn:'imprimer_tracts_sportifs', label:'Imprimer des tracts pour un match', pa:1, cost:0, type:'legal', icon:'ti-file-description', successRate:100, desc:'A distribuer lors d\'un prochain match. Achat par lot de 50.'}
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
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\'etait pas justifie par le zonage, le maire en subit les consequences.'}
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
        imageUrl: "https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=1200&q=80",
        persons: [
          {name:'Sergent Dubois (PNJ)', role:'PNJ - Sous-officier de garde', rel:'neutral', job:'militaire'},
          {name:'Soldat Martin (PNJ)',  role:'PNJ - Faction',                 rel:'neutral', job:'militaire'}
        ],
        orders: [
          {fn:'nommer_lieutenant', label:'Nommer un Lieutenant', pa:2, cost:0, type:'legal', icon:'ti-star', successRate:100, requiresPost:'capitaine', desc:'Reserve aux Capitaines. Designer un lieutenant pour une section de sa compagnie.'},
          {fn:'affecter_engage',    label:'Affecter un engagé à une section', pa:2, cost:0, type:'legal', icon:'ti-user-plus', successRate:100, requiresPost:'capitaine', desc:'Reserve aux Capitaines. Installer un engage valide par le Commandant comme lieutenant d\'une section.'},
          {fn:'engager_officier',   label:'S\'engager comme officier',  pa:2, cost:0, type:'legal', icon:'ti-flag', successRate:100, desc:'Envoyer une demande d\'engagement au Commandant de la Caserne.'},
          {fn:'demettre_lieutenant', label:'Démettre un Lieutenant', pa:2, cost:0, type:'legal', icon:'ti-user-x', successRate:100, requiresPost:'capitaine', desc:'Reserve aux Capitaines. Retirer un lieutenant juge responsable d\'un echec.'},
          {fn:'se_presenter_affectation', label:'Se présenter à mon affectation', pa:1, cost:0, type:'legal', icon:'ti-door-enter', successRate:100, desc:'Reserve aux civils requisitionnes, avant expiration du delai.'}
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
          {fn:'nommer_capitaine',    label:'Nommer un Capitaine',        pa:2, cost:0,    type:'legal',   icon:'ti-star',          successRate:100, requiresPost:'commandant', desc:'Reserve au Commandant. Designer un capitaine pour une compagnie.'},
          {fn:'traiter_engagements', label:'Traiter les engagements',   pa:1, cost:0,    type:'legal',   icon:'ti-clipboard-list', successRate:100, requiresPost:'commandant', desc:'Reserve au Commandant. Affecter les demandes d\'engagement a une compagnie.'},
          {fn:'recherche_militaire', label:'Lancer une recherche sur l\'armement', pa:2, cost:0, type:'legal', icon:'ti-flask', successRate:100, requiresPost:'commandant', desc:'En collaboration avec un chercheur civil. Ameliore le coefficient de tir d\'une arme pour tout le pays.'},
          {fn:'recruter_section',   label:'Recompléter une section',    pa:2, cost:0,    type:'legal',   icon:'ti-user-plus',     successRate:100, requiresPost:'commandant', desc:'Recompléter une section anéantie. Les nouvelles recrues n\'ont aucune experience.'},
          {fn:'gerer_detachement',   label:'Gérer mon détachement',      pa:0, cost:0,    type:'legal',   icon:'ti-users',         successRate:100, requiresPost:'lieutenant', desc:'Deposer ou recuperer des soldats dans cette piece.'},
          {fn:'assigner_mission',    label:'Attribuer une mission',      pa:1, cost:0,    type:'legal',   icon:'ti-target',        successRate:100, requiresPost:'lieutenant', desc:'Donner une consigne au detachement present dans cette piece.'},
          {fn:'voir_ma_section',     label:'Voir ma section',            pa:0, cost:0,    type:'legal',   icon:'ti-list',          successRate:100, requiresPost:'lieutenant', desc:'Fiche individuelle de vos 24 soldats (matricule, formation, equipement).'},
          {fn:'entrainer_section',   label:'Entrainer la section',       pa:2, cost:0,    type:'legal',   icon:'ti-barbell',       successRate:100, requiresPost:'lieutenant', desc:'Force, Endurance ou Tir. 12 soldats max par session.'},
          {fn:'equiper_section',     label:'Equiper les soldats ici',    pa:1, cost:0,    type:'legal',   icon:'ti-sword',         successRate:100, requiresPost:'lieutenant', desc:'Equiper les soldats presents dans cette piece.'},
          {fn:'remonter_renseignement', label:'Faire remonter un renseignement', pa:1, cost:0, type:'legal', icon:'ti-report', successRate:100, requiresPost:'lieutenant', desc:'Transmettre un rapport de renseignement recu a votre Capitaine.'},
          {fn:'inspecter_troupes',   label:'Inspecter les troupes',      pa:1, cost:0,    type:'legal',   icon:'ti-eye',           successRate:100, requiresPost:'min_def', desc:'+INF aupres de l\'armee. Renforce la loyaute.'},
          {fn:'gerer_budget_caserne', label:'Gérer le budget militaire', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, requiresPost:'min_def', desc:'Virement journalier ou ponctuel vers la caserne, ou financer directement la recherche militaire.'}
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
      salle_faits_armes: {
        name: "Salle des Faits d'Armes",
        imageBg: "linear-gradient(135deg,#0a0806,#14100a)",
        desc: "Les trophees et etendards des sections. Chaque numero de section porte la memoire de ses combats, transmise d'un lieutenant a l'autre.",
        imageUrl: "https://images.unsplash.com/photo-1569163139394-de44cb5894c8?w=1200&q=80",
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
        persons: [],
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
        imageUrl: "https://images.unsplash.com/photo-1562564055-71e051d33c19?w=1200&q=80",
        persons: [
          {name:'Dominique Cruel (PNJ)', role:'PNJ - Directeur du QHS', rel:'neutral', job:'directeur_qhs'},
          {name:'Philippe Cognedur (PNJ)', role:'PNJ - Gardien Chef',     rel:'neutral', job:'gardien_qhs'}
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
          {name:'Jean Terre (PNJ)', role:'PNJ - Gardien de couloir', rel:'neutral', job:'gardien_qhs'},
          {name:'Patrick Coule (PNJ)', role:'PNJ - Gardien de couloir', rel:'neutral', job:'gardien_qhs'}
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
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/port-sainte-marie-centre-multimodal.png",
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
      },
      entrepot: {
        name: "Entrepôt — Local à louer",
        imageBg: "linear-gradient(135deg,#050810,#08100a)",
        desc: "📋 À LOUER — Entrepôt portuaire de 300m². Idéal pour stocker des marchandises... officielles ou non. Marcel Ancre ne regarde pas trop dans les caisses.",
        imageUrl: "https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=1200&q=80",
        isLocationRoom: true,
        locationData: { prix: 350, bonusPOP: 0, bonusINF: 3, bonusDIS: 6, label: 'Entrepôt Portuaire', tier: 2, usages: ['stockage','contrebande','logistique'] },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer cet entrepôt (350 FR/jour)', pa:1, cost:0, type:'grey', icon:'ti-key', successRate:100, desc:'+6 DIS +3 INF. Stockage discret garanti.'},
          {fn:'gerer_local', label:'Gérer mon entrepôt', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
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
      republic: ['Adhérent', 'Délégué', 'Secrétaire Général', 'Confédéral'],
      narco:    ['Miembro', 'Delegado', 'Secretario', 'El Capo Sindical'],
      soviet:   ['Travailleur Uni', 'Délégué du Peuple', 'Commissaire Syndical', 'Grand Camarade'],
      khalija:  ['Membre', 'Représentant', 'Directeur Syndical', 'Grand Cheikh Ouvrier'],
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
const CLUBS_SPORTIFS = [
  { id:'olympique-luthecia',    nom:'Olympique de Luthécia',        country:'republic', city:'capitale', stadeBuilding:'stade', valeurBase:72, vedettes:['Marco Frappesec','Julien Contrapied'] },
  { id:'brise-mariannaise',     nom:'La Brise Mariannaise',         country:'republic', city:'ville_a',  stadeBuilding:'stade', valeurBase:60, vedettes:['Yann Ecume','Loic Maree'] },
  { id:'cheminote-montrouge',   nom:'Union Cheminote de Montrouge', country:'republic', city:'ville_b',  stadeBuilding:'stade', valeurBase:63, vedettes:['Momo Charbon','Sami Rail'] },
  { id:'rojos-cartel',          nom:'Rojos del Cartel',             country:'narco',    city:'capitale', stadeBuilding:'stade', valeurBase:68, vedettes:['El Pistolero','Diego Gatillo'] },
  { id:'fronterizos-unidos',    nom:'Fronterizos Unidos',           country:'narco',    city:'ville_a',  stadeBuilding:'stade', valeurBase:58, vedettes:['Chuy Frontera','Beto Contrabando'] },
  { id:'jaguares-selva',        nom:'Jaguares de la Selva',         country:'narco',    city:'ville_b',  stadeBuilding:'stade', valeurBase:61, vedettes:['Jaguar Rios','Tigre Verde'] },
  { id:'dynamo-novomirsk',      nom:'Dynamo Novomirsk',             country:'soviet',   city:'capitale', stadeBuilding:'stade', valeurBase:74, vedettes:['Ivan Marteau','Boris Faucille'] },
  { id:'spartak-sibirsk',       nom:'Spartak Sibirsk-9',            country:'soviet',   city:'ville_a',  stadeBuilding:'stade', valeurBase:57, vedettes:['Yuri Glacon','Piotr Frimas'] },
  { id:'kolkhoze-ouvrier',      nom:'Kolkhoze Ouvrier FC',          country:'soviet',   city:'ville_b',  stadeBuilding:'stade', valeurBase:59, vedettes:['Sacha Tracteur','Vania Recolte'] },
  { id:'nadi-al-madina',        nom:'Nadi Al-Madina',               country:'khalija',  city:'capitale', stadeBuilding:'stade', valeurBase:70, vedettes:['Karim Falcon','Youssef Sable'] },
  { id:'al-baraka-fc',          nom:'Al-Baraka FC',                 country:'khalija',  city:'ville_a',  stadeBuilding:'stade', valeurBase:56, vedettes:['Malik Oasis','Rashid Caravane'] },
  { id:'sharq-al-nour',         nom:'Sharq Al-Nour',                country:'khalija',  city:'ville_b',  stadeBuilding:'stade', valeurBase:62, vedettes:['Tarek Petrole','Hamza Tanker'] }
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
  republic: {
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
    'terrain-a-batir-7': { 'terrain': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/terrain-a-vendre-republic.png' }
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
  juge:        1800,
  commissaire: 1000,
  maire:       800,
  adj_maire:   500,
  gouverneur:  1500,
  prefet:      900,
  default:     150  // Citoyen sans poste
};

// Postes nommes (non electifs) avec regles de cumul strictes
// 'depute' est le SEUL poste compatible avec juge/commissaire
const POSTES_NOMMES_EXCLUSIFS = {
  juge:        { label: 'Juge',        nommePar: 'min_just', scope: 'pays',  compatibles: ['depute'] },
  commissaire: { label: 'Commissaire', nommePar: 'maire',    scope: 'ville', compatibles: ['depute'] },
  commandant:  { label: 'Commandant de la Caserne', nommePar: 'min_def', scope: 'pays', compatibles: ['depute'] }
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
