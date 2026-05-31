/* ===========================
   RES PUBLICA — IMAGES.JS
   Photos Unsplash par lieu
   =========================== */

const PLACE_IMAGES = {

  // RUES par ville
  rue: {
    capitale:  'https://images.unsplash.com/photo-1431274172761-fca41d930114?w=1200&q=80', // Paris boulevard haussmannien
    ville_a:   'https://images.unsplash.com/photo-1504893524553-b855bce32c67?w=1200&q=80', // Port mediterraneen
    ville_b:   'https://images.unsplash.com/photo-1565793298595-6a879b1d9492?w=1200&q=80', // Ville industrielle
  },

  // HOTEL-RESTAURANT LA REPUBLICA
  'hotel-republica': {
    accueil:    'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=1200&q=80', // Hall hotel luxe
    restaurant: 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=1200&q=80', // Restaurant elegant
    bar:        'https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=1200&q=80', // Bar feutré
    chambres:   'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=1200&q=80', // Chambre hotel
  },

  // PALAIS DU GOUVERNEMENT
  'palais-gouvernement': {
    hall:          'https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80', // Hall monumental
    bureaux:       'https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80', // Bureaux officiels
    salle_conseil: 'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=1200&q=80', // Salle conseil
  },

  // ASSEMBLEE NATIONALE
  assemblee: {
    hemicycle: 'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?w=1200&q=80', // Parlement
    couloirs:  'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=1200&q=80', // Couloirs institution
  },

  // TRIBUNAL
  tribunal: {
    salle_audience: 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=1200&q=80', // Salle audience
    greffe:         'https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80', // Archives
  },

  // BANQUE NATIONALE
  'banque-nationale': {
    accueil_banque: 'https://images.unsplash.com/photo-1501167786227-4cba60f6d58f?w=1200&q=80', // Banque classique
  },

  // BANQUE PRIVEE
  'banque-privee': {
    bureau_prive: 'https://images.unsplash.com/photo-1553729459-efe14ef6055d?w=1200&q=80', // Bureau discret luxe
  },

  // CLINIQUE PRIVEE
  'clinique-privee': {
    reception_clinique: 'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=1200&q=80', // Clinique moderne
  },

  // DISPENSAIRE PUBLIC
  'dispensaire-public': {
    salle_attente: 'https://images.unsplash.com/photo-1584515933487-779824d29309?w=1200&q=80', // Hopital public
  },

  // COMMISSARIAT
  commissariat: {
    accueil_police: 'https://images.unsplash.com/photo-1601158935942-52255782d322?w=1200&q=80', // Commissariat
  },

  // LA TRIBUNE
  'la-tribune': {
    redaction: 'https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=1200&q=80', // Redaction journal
  },

  // LOGE MACONNIQUE
  'loge-maconnique': {
    antichambre: 'https://images.unsplash.com/photo-1555099962-4199c345e5dd?w=1200&q=80', // Salle secrete sombre
  },

  // UNIVERSITE
  universite: {
    amphi: 'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=1200&q=80', // Amphi universite
  },

  // ARMURERIE
  armurerie: {
    magasin: 'https://images.unsplash.com/photo-1595590424283-b8f17842773f?w=1200&q=80', // Armurerie
  },

  // MARCHE
  marche: {
    marche_ext: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1200&q=80', // Marche couvert
  },

  // TERRAINS
  'terrain-a-batir-1': {
    terrain: 'https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80', // Terrain vague ville
  },
  'terrain-a-batir-2': {
    terrain2: 'https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80',
  },
  'terrain-a-batir-3': {
    terrain3: 'https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80',
  },

  // VILLES SECONDAIRES
  'hotel-port': {
    hall_port: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=1200&q=80', // Hotel bord de mer
  },
  'bar-des-pecheurs': {
    salle_bar: 'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=1200&q=80', // Bar de port
  },
  'siege-syndical': {
    bureau_syndical: 'https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=1200&q=80', // Bureau syndical
  },
  'usine-principale': {
    direction_usine: 'https://images.unsplash.com/photo-1565793298595-6a879b1d9492?w=1200&q=80', // Usine
  },
  'hotel-mineur': {
    hall_mineur: 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=1200&q=80', // Hotel modeste
  },
  'banque-locale': {
    guichet: 'https://images.unsplash.com/photo-1501167786227-4cba60f6d58f?w=1200&q=80',
  },
  'commissariat-local': {
    accueil_loc: 'https://images.unsplash.com/photo-1601158935942-52255782d322?w=1200&q=80',
  },
  'dispensaire-public-v': {
    attente: 'https://images.unsplash.com/photo-1584515933487-779824d29309?w=1200&q=80',
  },
  mairie: {
    accueil_mairie: 'https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80',
  },
};
