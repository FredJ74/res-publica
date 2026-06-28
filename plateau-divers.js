// =====================
// PLATEAU-DIVERS.JS
// Evenements aleatoires, sondages, indices imperiaux, religion, objet trouve/interroger
// =====================

// ÉVÉNEMENTS ALÉATOIRES
// =====================
const EVENEMENTS_TYPES = [
  { id: 'scandale', label: 'Scandale', prob: 0.25 },
  { id: 'greve', label: 'Grève surprise', prob: 0.15 },
  { id: 'visite', label: 'Visite diplomatique', prob: 0.10 },
  { id: 'panne', label: 'Panne administrative', prob: 0.20 },
  { id: 'bonne_nouvelle', label: 'Bonne nouvelle', prob: 0.15 },
  { id: 'rumeur', label: 'Rumeur persistante', prob: 0.15 },
];

async function genererEvenementAleatoire() {
  if (sessionStorage.getItem('event_done_' + (state.day || 1))) return;

  // Probabilité globale de 40% d'avoir un événement
  if (Math.random() > 0.4) return;

  const roll = Math.random();
  let cumul = 0;
  let type = EVENEMENTS_TYPES[0];
  for (const e of EVENEMENTS_TYPES) {
    cumul += e.prob;
    if (roll <= cumul) { type = e; break; }
  }

  const co = COUNTRIES[state.country];
  const empireStyle = EMPIRE_STYLES?.[state.country] || { tone: 'parodique', religion: 'la Foi Locale', leader: 'le Chef' };

  const prompts = {
    scandale: 'Génère un titre de scandale politique absurde et parodique dans ' + (co?.n || 'l\'empire') + '. Style : ' + empireStyle.tone + '. 1 phrase. Pas de vrais dieux.',
    greve: 'Génère une annonce de grève surprise absurde dans ' + (co?.n || 'l\'empire') + '. Corps de métier inattendu. Style : ' + empireStyle.tone + '. 1 phrase.',
    visite: 'Génère une annonce de visite diplomatique absurde dans ' + (co?.n || 'l\'empire') + '. Visiteur improbable. Style : ' + empireStyle.tone + '. 1 phrase.',
    panne: 'Génère une annonce de panne administrative absurde dans ' + (co?.n || 'l\'empire') + '. Service inattendu en panne. Style : ' + empireStyle.tone + '. 1 phrase.',
    bonne_nouvelle: 'Génère une bonne nouvelle politique absurde dans ' + (co?.n || 'l\'empire') + '. Style : ' + empireStyle.tone + '. 1 phrase. Religion locale : ' + empireStyle.religion + '.',
    rumeur: 'Génère une rumeur politique absurde qui circule dans ' + (co?.n || 'l\'empire') + '. Style : ' + empireStyle.tone + '. 1 phrase.',
  };

  const emojis = { scandale: '🔥', greve: '✊', visite: '🤝', panne: '⚠️', bonne_nouvelle: '🎉', rumeur: '👂' };

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 100, messages: [{ role: 'user', content: prompts[type.id] }] })
    });
    const data = await resp.json();
    const texte = data.content?.[0]?.text;
    if (texte) {
      const emoji = emojis[type.id] || '📢';
      addJournalEntry(emoji + ' ' + type.label.toUpperCase() + ' : ' + texte, 'event-' + (type.id === 'bonne_nouvelle' ? 'good' : type.id === 'scandale' ? 'bad' : 'info'));
      addExternalEvent(emoji + ' ' + texte);
      sessionStorage.setItem('event_done_' + (state.day || 1), '1');
    }
  } catch(e) {}
}

// =====================

// SONDAGES ABSURDES
// =====================
async function commanderSondage() {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';

  if (state.arg < 200) {
    showToast('Fonds insuffisants', '200 ' + cur + ' requis.', false);
    return;
  }
  state.arg -= 200;

  const sujets = [
    'la popularité du fromage local comme symbole national',
    'l\'opportunité de renommer la capitale',
    'l\'instauration d\'une journée nationale obligatoire de sieste',
    'la privatisation de la météo',
    'l\'élection du PNJ le plus sympathique de la ville',
    'l\'interdiction des réunions de plus de 3 personnes le lundi matin',
    'la construction d\'une statue du fondateur de l\'empire',
    'la légalisation du troc comme monnaie officielle',
    'l\'obligation de porter un chapeau dans les institutions',
    'la semaine de travail à 2 jours'
  ];
  const sujet = sujets[Math.floor(Math.random() * sujets.length)];
  const empireStyle = EMPIRE_STYLES?.[state.country] || { tone: 'parodique', religion: 'la Foi Locale', leader: 'le Chef' };

  const prompt = 'Tu travailles dans un institut de sondage parodique dans l\'empire ' + (co?.n || 'inconnu') + '. ' +
    'Style : ' + empireStyle.tone + '. Religion locale : ' + empireStyle.religion + '. Chef suprême : ' + empireStyle.leader + '. ' +
    'Génère un sondage absurde et parodique sur : ' + sujet + '. ' +
    'Format : 1 question + 4 choix de réponse + 1 résultat fictif avec pourcentages. ' +
    'Maximum 6 lignes. Très drôle et dans le style de l\'empire. Pas de vrais dieux.';

  document.getElementById('postes-modal-title').textContent = 'Sondage en cours...';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">Institut de Sondage au travail...</div>';
  document.getElementById('modal-postes').classList.add('open');

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 250, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const resultat = data.content?.[0]?.text || 'Sondage indisponible.';

    document.getElementById('postes-modal-title').textContent = '📊 Sondage Officiel';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem">' +
      '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.6rem;font-style:italic">Commandé par ' + (state.char?.name || 'Anonyme') + ' · Coût : 200 ' + cur + '</div>' +
      '<div style="font-size:.85rem;color:#c0a060;line-height:1.8;white-space:pre-line;font-family:Crimson Pro,Georgia,serif">' + resultat + '</div>' +
      '<div style="margin-top:.8rem;display:flex;gap:.5rem">' +
      '<button onclick="publierSondage(this.dataset.txt)" data-txt="' + resultat.replace(/"/g, '&quot;') + '"" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-news" style="font-size:.7rem"></i> Publier sur le forum</button>' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #3a2a10;background:transparent;color:#6a5a30;cursor:pointer">Fermer</button>' +
      '</div></div>';

    state.inf = Math.min(100, (state.inf || 0) + 3);
    updateUI();
    addJournalEntry('Sondage commandé sur : ' + sujet + '. -200 ' + cur, 'event-info');

  } catch(e) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a3a20">Erreur lors de la génération du sondage.</div>';
  }
}

async function publierSondage(texte) {
  document.getElementById('modal-postes').classList.remove('open');
  if (typeof sbCreateTopic === 'function') {
    const from = state.char?.name || 'Anonyme';
    await sbCreateTopic('local', '📊 Sondage : ' + texte.substring(0, 50) + '...', texte, from);
    showToast('Sondage publié !', 'Visible sur le forum local.', true);
    addJournalEntry('Sondage publié sur le forum.', 'event-info');
  } else {
    showToast('Forum indisponible', 'Impossible de publier.', false);
  }
}

// =====================

// =====================

// INDICES IMPERIAUX - CORRIGE
// =====================
function ouvrirIndicesImperiaux() {
  // Ouvrir dans un modal simple pour eviter les problemes de vue
  const empires = [
    { key:'republic', name:'Républia',   col:'#4a9ade' },
    { key:'narco',    name:'El Estado',  col:'#cc4444' },
    { key:'soviet',   name:'Sovarka',    col:'#cc2020' },
    { key:'khalija',  name:'Al-Khalija', col:'#C9A84C' }
  ];

  document.getElementById('postes-modal-title').textContent = 'Indices Imperiaux';
  let html = '<div style="padding:1rem">';

  empires.forEach(emp => {
    const idx = (typeof INDICES_NATIONAUX !== 'undefined') ? (INDICES_NATIONAUX[emp.key] || {ISN:30,IE:50,ID:40,IS:45}) : {ISN:30,IE:50,ID:40,IS:45};
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
    html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:' + emp.col + ';margin-bottom:.5rem">' + emp.name + '</div>';
    html += '<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:.3rem">';
    [['ISN','Securite','#4a8a4a'],['IE','Eco','#C9A84C'],['ID','Diplo','#4a6aaa'],['IS','Social','#aa6a4a'],['IP','Piété','#8a4a8a']].forEach(([k,label,col]) => {
      const val = idx[k] || 0;
      html += '<div style="text-align:center;padding:.3rem;background:#0a0805;border:1px solid #1a1810">';
      html += '<div style="font-size:.58rem;color:#4a4030">' + label + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.2rem;color:' + col + '">' + val + '</div>';
      html += '<div style="height:3px;background:#0a0a05;margin-top:.15rem"><div style="height:100%;width:' + val + '%;background:' + col + ';opacity:.6"></div></div>';
      html += '</div>';
    });
    html += '</div></div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =====================

// SYSTEME RELIGIEUX
// =====================
function getIP() {
  const pays = state.country || 'republic';
  if (typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]) {
    if (!INDICES_NATIONAUX[pays].IP) INDICES_NATIONAUX[pays].IP = 40;
    return INDICES_NATIONAUX[pays].IP;
  }
  return 40;
}

function modifierIP(delta) {
  const pays = state.country || 'republic';
  if (typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]) {
    INDICES_NATIONAUX[pays].IP = Math.max(0, Math.min(100, (INDICES_NATIONAUX[pays].IP || 40) + delta));
  }
}

const RELIGIONS = {
  republic: { nom: 'Papyrusisme', grandPretre: 'Percepteur Suprême', temple: 'Tabernacle des Impôts', peche: 'rendre un formulaire incomplet' },
  narco:    { nom: 'Cocaïsme',   grandPretre: 'Parrain Céleste',     temple: 'Laboratoire de Prière', peche: 'refuser la communion' },
  soviet:   { nom: 'Tractorisme',grandPretre: 'Camarade Pontife',    temple: 'Kolkhoze Spirituel',    peche: 'posséder un tracteur privé' },
  khalija:  { nom: 'Loukoumisme',grandPretre: 'Grand Confiseur',     temple: 'Pâtisserie Sacrée',     peche: 'refuser un loukoum offert' }
};

function doPrier() {
  const pays = state.country || 'republic';
  const religion = RELIGIONS[pays];
  modifierIP(3);
  state.moral = Math.min(100, state.moral + 2);
  updateUI();
  const msgs = {
    republic: 'Vous remplissez un formulaire en 12 exemplaires. La grâce administrative vous envahit. +3 IP +2 Moral.',
    narco:    'Vous communiez avec la Feuille Sacrée. Vous vous sentez soudainement très... éveillé. +3 IP +2 Moral.',
    soviet:   'Vous chantez l\'hymne au Tracteur Collectif. Vos camarades vous applaudissent. +3 IP +2 Moral.',
    khalija:  'Vous dégustez un loukoum divin. Goût pistache. C\'est une révélation. +3 IP +2 Moral.'
  };
  showToast('Prière accomplie', msgs[pays] || '+3 IP +2 Moral', true);
  addJournalEntry('Prière au ' + (religion?.temple || 'temple'), 'event-info');
}

function doSeConfeser() {
  const pays = state.country || 'republic';
  const religion = RELIGIONS[pays];
  state.moral = Math.min(100, state.moral + 5);
  updateUI();
  // Le pretre apprend des informations (simulation)
  const secrets = [
    'Vous avouez avoir corrompu un fonctionnaire. Le ' + religion?.grandPretre + ' note soigneusement.',
    'Vous confessez vos activités illégales. Le ' + religion?.grandPretre + ' hoche la tête d\'un air entendu.',
    'Vous révélez vos plans politiques secrets. "Intéressant", dit le ' + religion?.grandPretre + '.',
    'Vous avouez n\'avoir jamais rempli tous vos formulaires. Le ' + religion?.grandPretre + ' est scandalisé.'
  ];
  const secret = secrets[Math.floor(Math.random() * secrets.length)];
  showToast('Confession', secret + ' +5 Moral.', true);
  addJournalEntry('Confession au ' + (religion?.temple || 'temple') + '. +5 Moral.', 'event-info');
  // Risque de fuite (20%)
  if (Math.random() < 0.2) {
    setTimeout(() => addExternalEvent('RUMEUR : Des confidences faites au ' + (religion?.temple||'temple') + ' auraient été divulguées...'), 2000);
  }
}

function doFaireDon(cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (!verifierBudgetInstitution('presidence')) {
    if (state.arg < (cost || 200)) { showToast('Fonds insuffisants', '', false); return; }
    state.arg -= (cost || 200);
  }
  modifierIP(5);
  state.pop = Math.min(100, state.pop + 3);
  updateUI();
  showToast('Don effectué', '+5 IP +3 POP. Le ' + (RELIGIONS[state.country]?.grandPretre||'Grand Prêtre') + ' vous bénit.', true);
}

function doDemanderBenediction() {
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 80) {
    if (!state.benediction) state.benediction = {};
    state.benediction.actif = true;
    state.benediction.expire = state.day + 1;
    showToast('Béni !', 'Vous bénéficiez d\'un bonus de +5% sur votre prochain ordre pendant 24h.', true, true);
    addJournalEntry('Bénédiction reçue. +5% prochain ordre.', 'event-good');
  } else {
    showToast('Pas de réponse', 'Le Très-Haut est occupé. Revenez demain.', false);
  }
}

function doPelerin() {
  state.dis = Math.min(100, state.dis + 10);
  if (!state.pelerinExpire) state.pelerinExpire = state.day + 1;
  updateUI();
  showToast('Pèlerin déclaré', '+10 DIS pendant 24h. Accès facilité aux lieux saints des autres empires.', true);
  addJournalEntry('Statut de pèlerin déclaré.', 'event-info');
}

function doBenedictionEtat() {
  modifierIP(10);
  state.pop = Math.min(100, state.pop + 5);
  updateUI();
  showToast('Bénédiction d\'État', '+10 IP national. +5 POP pour le chef d\'État.', true, true);
  addExternalEvent('RELIGION : Un acte d\'État a reçu la bénédiction du ' + (RELIGIONS[state.country]?.grandPretre||'Grand Prêtre') + '.');
}

function doConsulterConfessions() {
  const confessions = [
    'Un haut fonctionnaire a avoué détourner des fonds depuis 3 ans.',
    'Un ministre a confessé ses contacts avec un empire étranger.',
    'Un député a avoué avoir vendu son vote lors du dernier scrutin.',
    'Un officier de police a confessé avoir falsifié des preuves.'
  ];
  const secret = confessions[Math.floor(Math.random() * confessions.length)];
  state.inf = Math.min(100, state.inf + 8);
  updateUI();
  document.getElementById('postes-modal-title').textContent = 'Archives des Confessions';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem"><div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7">"' + secret + '"</div><div style="font-size:.7rem;color:#4a4030;margin-top:.6rem">Source : confessions scellées · +8 INF</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function doAcheterRelique() {
  if (!state.inventory) state.inventory = [];
  state.inventory.push({ type:'relique', name:'Relique du Loukoum Sacré', icon:'ti-star', legal:true, effet:'ip+10', desc:'Accès facilité aux zones réservées d\'Al-Khalija.' });
  modifierIP(10);
  state.arg -= 500;
  updateUI();
  showToast('Relique acquise !', 'Relique du Loukoum Sacré ajoutée à votre inventaire. +10 IP.', true, true);
}

// =====================

// OBJET TROUVE (Accueil Assemblee) — 50% de chance, kompromat potentiel
// =====================
const OBJETS_TROUVES_ASSEMBLEE = [
  { name: 'Parapluie a tete de mort', icon: 'ti-umbrella', desc: 'Un parapluie noir orne de tetes de mort doreees, la pointe etrangement acereee. Rappelle furieusement certaines methodes d\'un service secret de l\'Est, jadis tres efficace pour faire taire les genants.', compromettant: true, imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/objet-parapluie.png' },
  { name: 'Dossier de presse périmé', icon: 'ti-file-text', desc: 'Un dossier marque "PRESS", rempli de coupures de journaux sur "l\'Affaire du Sphinx" et de cliches compromettants. Quelqu\'un voulait visiblement etouffer cette histoire.', compromettant: true, imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/objet-dossier-presse.png' },
  { name: 'Petite culotte en dentelle', icon: 'ti-shirt', desc: 'Une petite culotte en dentelle noire, avec une carte de visite d\'escort glissée dedans.', compromettant: true, imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/objet-culotte-dentelle.png' },
  { name: 'Enveloppe administrative suspecte', icon: 'ti-package', desc: 'Une enveloppe officielle mal refermée, laissant voir un sachet de poudre blanche.', compromettant: true, imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/objet-sachet-poudre.png' },
  { name: 'Boîte de préservatifs entamée', icon: 'ti-heart', desc: 'Une boîte de préservatifs entamée, un numéro de téléphone griffonné au marqueur.', compromettant: true, imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/objet-preservatifs.png' },
  { name: 'Agenda à codes ridicules', icon: 'ti-notebook', desc: 'Un petit carnet relié de cuir, ferme par un cadenas et un cachet de cire. A l\'interieur, des rendez-vous notes sous des noms de code grotesques et des symboles que personne ne saurait expliquer.', compromettant: true, imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/objet-agenda.png' },
  { name: 'Bouteille de whisky entamée', icon: 'ti-bottle', desc: 'Une bouteille de whisky bon marché, à moitié vide, planquée derrière un radiateur.', compromettant: false, imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/objet-whisky.png' }
];

function reclamerObjetTrouve() {
  // Limite a 1 essai par jour, peu importe le resultat
  if (state.dernierObjetTrouveJour === state.day) {
    showToast('Deja fait aujourd\'hui', 'Vous avez deja consulte le service des objets trouves aujourd\'hui. Revenez demain.', false);
    return;
  }
  state.dernierObjetTrouveJour = state.day;

  const reussite = Math.random() < 0.5;
  if (!reussite) {
    showToast('Service des objets trouvés', 'Rien d\'intéressant aujourd\'hui. "Repassez demain", lâche l\'hôtesse des objets trouvés.', true);
    addJournalEntry('Vous avez fouillé le service des objets trouvés. Rien à signaler.', '');
    return;
  }

  const objet = OBJETS_TROUVES_ASSEMBLEE[Math.floor(Math.random() * OBJETS_TROUVES_ASSEMBLEE.length)];
  const id = 'objet-trouve-' + Date.now();

  addToInventory({
    id,
    name: objet.name,
    icon: objet.icon,
    desc: objet.desc,
    type: objet.compromettant ? 'kompromat' : 'objet',
    cible: null,
    legal: !objet.compromettant,
    imageUrl: objet.imageUrl || null
  });

  // Enregistrer le souvenir du PNJ d'accueil (qui sait que CE PJ a recupere CET objet)
  if (!state.souvenirsAccueil) state.souvenirsAccueil = [];
  const souvenir = {
    id: 'souv-' + Date.now(),
    pjNom: state.char?.name || 'Anonyme',
    objetNom: objet.name,
    jourCreation: state.day || 1,
    jourExpiration: (state.day || 1) + 12,
    revele: false
  };
  state.souvenirsAccueil.push(souvenir);

  // Persister le souvenir sur Supabase pour que les autres PJ puissent l'interroger
  if (typeof sbAjouterSouvenirAccueil === 'function') {
    sbAjouterSouvenirAccueil(souvenir).catch(() => {});
  }

  showToast('Objet trouvé !', 'Vous récupérez : ' + objet.name + '. L\'hôtesse des objets trouvés note discrètement votre nom dans son carnet...', true, true);
  addJournalEntry('Objet trouvé réclamé : ' + objet.name + '.', objet.compromettant ? 'event-bad' : 'event-good');
}

// =====================
// MODAL DE SELECTION POUR INTERROGER L'ACCUEIL
// =====================
async function ouvrirModalInterrogerAccueil() {
  document.getElementById('postes-modal-title').textContent = 'Demander des confidences';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Recherche des habitants...</div>';
  document.getElementById('modal-postes').classList.add('open');

  let habitants = [];
  if (typeof sbListPersonnages === 'function') {
    try { habitants = (await sbListPersonnages() || []).filter(h => h.name !== state.char?.name); } catch(e) {}
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">"Dites-moi, qui vous intéresse ?" murmure l\'agent d\'entretien avec un sourire entendu.</div>';
  if (habitants.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucun habitant connu pour le moment.</div>';
  } else {
    html += '<select id="interroger-accueil-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    habitants.forEach(h => { html += '<option value="' + h.name + '">' + h.name + '</option>'; });
    html += '</select>';
    html += '<button onclick="interrogerAccueilSurObjets(document.getElementById(\'interroger-accueil-cible\').value);document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Demander</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// =====================
// INTERROGER LE PERSONNEL D'ACCUEIL SUR LES OBJETS TROUVES
// =====================
async function interrogerAccueilSurObjets(cibleNom) {
  if (typeof sbGetSouvenirsAccueilPour !== 'function') {
    showToast('Indisponible', 'Service indisponible pour le moment.', false);
    return;
  }
  const souvenirs = await sbGetSouvenirsAccueilPour(cibleNom).catch(() => []);
  const valides = (souvenirs || []).filter(s => s.jour_expiration >= (state.day || 1));

  if (valides.length === 0) {
    showToast('Aucun souvenir', 'L\'agent d\'entretien ne se souvient de rien de particulier sur ' + cibleNom + '.', false);
    return;
  }

  const liste = valides.map(s => '— ' + s.objet_nom + ' (Jour ' + s.jour_creation + ')').join('<br>');
  showToast('Confidence obtenue', cibleNom + ' a récupéré : ' + valides.map(s => s.objet_nom).join(', '), true, true);
  addJournalEntry('L\'agent d\'entretien vous confie que ' + cibleNom + ' a récupéré ces objets :<br>' + liste, 'event-info');
}

function addToInventory(item) {
  state.inventory.push(item);
  renderInventory();
}
function renderInventory() {
  const el = document.getElementById('inv-items');
  if (!el) return;
  if (state.inventory.length === 0) {
    el.innerHTML = '<div class="inv-item-empty">Aucun objet</div>';
    return;
  }
  el.innerHTML = state.inventory.map((item, idx) => {
    const legal = item.legal === false ? '<span style="color:#cc4444;font-size:.6rem"> ⚠ Illégal</span>' : '';
    const expiry = item.expireDay ? '<div style="font-size:.6rem;color:#6a5030">Expire jour ' + item.expireDay + '</div>' : '';
    return '<div class="inv-item" style="display:flex;align-items:center;justify-content:space-between;gap:.4rem">' +
      '<div style="display:flex;align-items:center;gap:.4rem;flex:1;min-width:0;cursor:pointer" onclick="ouvrirDetailObjetInventaire(' + idx + ')">' +
        '<i class="ti ' + (item.icon||'ti-package') + '" style="font-size:.85rem;color:#8a6a20;flex-shrink:0"></i>' +
        '<div style="min-width:0">' +
          '<div style="font-size:.78rem;color:#c0b090;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + item.name + legal + '</div>' +
          (item.desc ? '<div style="font-size:.62rem;color:#4a4030;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + item.desc.substring(0,60) + (item.desc.length>60?'...':'') + '</div>' : '') +
          expiry +
        '</div>' +
      '</div>' +
      '<button onclick="supprimerItemInventaire(' + idx + ')" title="Supprimer" style="flex-shrink:0;background:none;border:1px solid #3a1a1a;color:#6a3a2a;cursor:pointer;padding:.15rem .35rem;font-size:.65rem;font-family:Bebas Neue,sans-serif">✕</button>' +
    '</div>';
  }).join('');
}




// =====================
// METEO POLITIQUE QUOTIDIENNE (complement)
// =====================

async function genererMeteoPolitique() {
  if (sessionStorage.getItem('meteo_done_' + (state.day || 1))) return;

  const co = COUNTRIES[state.country];
  const empireStyle = EMPIRE_STYLES?.[state.country] || { tone: 'parodique', religion: 'la Foi Locale', leader: 'le Chef' };
  const president = POSTES[state.country]?.capitale?.find(p => p.id === 'president');
  const presidentNom = president?.holder || 'Personne';
  const topics = (typeof FORUM_TOPICS !== 'undefined' ? (FORUM_TOPICS['local'] || []) : []).slice(0, 2).map(t => t.title).join(', ');

  const prompt = 'Tu es le météorologue politique de ' + (co?.n || 'l\'empire') + ' dans Res Publica, jeu parodique. ' +
    'Style : ' + empireStyle.tone + '. Religion : ' + empireStyle.religion + '. Chef : ' + empireStyle.leader + '. ' +
    'Président actuel : ' + presidentNom + '. ' +
    (topics ? 'Actualités récentes : ' + topics + '. ' : '') +
    'Génère un bulletin météo POLITIQUE absurde et drôle pour aujourd\'hui (Jour ' + (state.day || 1) + '). ' +
    '3 lignes max. Style bulletin météo détourné. Ex: "Risque d\'orage institutionnel au nord, prévoir parapluie et avocat." ' +
    'Pas de vrais dieux. Répondre UNIQUEMENT avec le bulletin, sans introduction.';

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 120, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const meteo = data.content?.[0]?.text;
    if (meteo) {
      addJournalEntry('🌦 MÉTÉO POLITIQUE — Jour ' + (state.day || 1) + ' : ' + meteo, 'event-info');
      sessionStorage.setItem('meteo_done_' + (state.day || 1), '1');
    }
  } catch(e) {}
}
