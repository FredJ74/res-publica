// ===========================================================================
// BANC CLIENT — SOCLE D'EMBAUCHE DES AGENCES (5 octobre 2026)
// ---------------------------------------------------------------------------
// CE BANC EXISTE POUR UNE SEULE RAISON, et c'est la demande de Fred : « Le cout
// d'embauche et le cout journalier sont deux notions differentes et doivent
// etre stockes et utilises separement. »
//
// Il ne RELIT pas le code, il l'EXECUTE : on embauche pour de bon (RPC
// bouchonnee), puis on fait DORMIR le joueur, et on regarde ce qui est
// reellement preleve. Un banc qui se contenterait de chercher `cout_jour` dans
// le fichier passerait aussi sur la version buguee.
//
// LE TEMOIN DE REGRESSION (test 6) est la piece maitresse : il rejoue
// exactement l'ancien comportement -- mettre le prix d'embauche dans `cout` --
// et EXIGE que le prelevement nocturne devienne faux. Sans lui, les tests 4 et
// 5 passeraient meme si le correctif ne servait a rien.
//
// Lancement : jsc .scratch/banc_agence_emploi.js
// ===========================================================================
var OK = 0, KO = 0, LIGNES = [];
function verifier(nom, condition, detail) {
  if (condition) { OK++; LIGNES.push('  [OK]    ' + nom); }
  else { KO++; LIGNES.push('  [ECHEC] ' + nom + (detail ? ' -> ' + detail : '')); }
}

// ---------- ENVIRONNEMENT MINIMAL ----------
var window = this;
// data.js declare BUILDINGS, WORLD et COUNTRIES en `const` : les redeclarer
// ici serait une SyntaxError. On les prend tels quels, c'est le but -- le banc
// doit lire le VRAI data.js, pas une copie.
load('data.js');

var state = {
  char: { name: 'Testeur Republien' }, country: 'republic', day: 10, arg: 10000, pa: 12,
  currentCity: 'capitale', currentBuilding: 'centre-affaires', currentRoom: 'grobras_securite',
  employes: []
};

var TOASTS = [], JOURNAL = [];
function escapeHtmlText(s) { return String(s == null ? '' : s); }
function showToast(t, m) { TOASTS.push(String(t) + ' | ' + String(m)); }
function addJournalEntry(t) { JOURNAL.push(String(t)); }
function addMailNotification() {}
function updateUI() {}
function sauvegarderPersonnageImmediat() {}
function renderPersonsList() {}
function appliquerPaiementServeur(p) {
  // Le vrai applique le debit decide par le serveur. Ici on le reproduit
  // fidelement : c'est ce debit-la qui est le FRAIS D'EMBAUCHE.
  if (p && typeof p.montant === 'number') state.arg -= p.montant;
  if (p && typeof p.pa === 'number') state.pa -= p.pa;
}
function getEmployes() { return state.employes || []; }
var PNJ_AVATAR = { agent_securite: { icon: 'ti-shield', color: '#5a6a7a' },
                   maitre_chien:   { icon: 'ti-dog',    color: '#7a6a4a' },
                   default:        { icon: 'ti-user',   color: '#6a6060' } };

// Le DOM strictement necessaire au comptoir.
var ELEMENTS = {
  'postes-modal-title': { textContent: '' },
  'postes-body':        { innerHTML: '' },
  'modal-postes':       { classList: { add: function () {}, remove: function () {} } }
};
var document = { getElementById: function (id) { return ELEMENTS[id] || null; } };

load('plateau-agence-emploi.js');

// ===========================================================================
// 1. LES DEUX ORDRES SONT DECLARES DANS LA PIECE, AVEC LEUR EMPLOYEUR
// ===========================================================================
// C'est ce qui rattache le comptoir generique a une maison : sans `employeur`
// et `metier` sur l'ordre, agenceEmploiOrdreCourant rend null et le comptoir
// refuse de s'ouvrir. On le verifie sur le VRAI data.js.
var piece = BUILDINGS['centre-affaires'] && BUILDINGS['centre-affaires'].rooms
          ? BUILDINGS['centre-affaires'].rooms['grobras_securite'] : null;

// data.js charge BUILDINGS a plat ; la piece de Grobras vit dans roomsExtra de
// Luthecia. On applique la fusion comme le fait enterBuilding.
var ctxLuthecia = WORLD.republic.capitale.buildingContext['centre-affaires'];
var piecesExtra = ctxLuthecia ? ctxLuthecia.roomsExtra : null;
var pieceGrobras = piecesExtra ? piecesExtra['grobras_securite'] : null;

verifier('1a la piece Grobras existe dans roomsExtra de Luthecia', !!pieceGrobras);
var ordres = pieceGrobras ? (pieceGrobras.orders || []) : [];
verifier('1b elle porte exactement deux ordres', ordres.length === 2,
  'trouve ' + ordres.length);

var oAgent = ordres.filter(function (o) { return o.fn === 'embaucher_agent_securite'; })[0];
var oChien = ordres.filter(function (o) { return o.fn === 'embaucher_maitre_chien'; })[0];

verifier('1c agent de securite : 1 PA, 500 FR, employeur et metier declares',
  !!oAgent && oAgent.pa === 1 && oAgent.cost === 500
  && oAgent.employeur === 'grobras-securite' && oAgent.metier === 'agent_securite',
  JSON.stringify(oAgent));
verifier('1d maitre-chien : 1 PA, 700 FR, employeur et metier declares',
  !!oChien && oChien.pa === 1 && oChien.cost === 700
  && oChien.employeur === 'grobras-securite' && oChien.metier === 'maitre_chien',
  JSON.stringify(oChien));

// ===========================================================================
// 2. AUCUN NOM DE CANDIDAT N'EST CODE DANS LE NAVIGATEUR
// ===========================================================================
// « Je ne veux pas de catalogue JavaScript. Aucune liste de noms codee dans le
// navigateur. » Les douze identites doivent venir du serveur, et le fichier du
// comptoir ne doit en contenir aucune.
var SRC_COMPTOIR = readFile('plateau-agence-emploi.js');
// ON TESTE LE CODE, PAS LA PROSE. Le premier jet de ce banc interdisait le mot
// « Grobras » dans tout le fichier -- et echouait donc sur le commentaire
// d'en-tete qui explique precisement que l'agence n'y est jamais nommee. Les
// lignes de commentaire sont retirees avant la verification : ce qui compte est
// qu'aucune agence ne soit nommee dans une INSTRUCTION.
var CODE_COMPTOIR = SRC_COMPTOIR.split('\n')
  .filter(function (l) { return l.replace(/^\s+/, '').indexOf('//') !== 0; })
  .join('\n');
var NOMS_SERVEUR = ['Menvussa', 'Hagarde', 'Poigné', 'Guérite', 'Tourniquet',
                    'Barrage', 'Brigitte Ronde', 'Cadenas',
                    'Croquignol', 'Mordu', 'Molosse', 'Crocs'];
var fuites = NOMS_SERVEUR.filter(function (n) { return SRC_COMPTOIR.indexOf(n) !== -1; });
verifier('2a aucun des 12 noms du catalogue serveur n\'apparait dans le comptoir',
  fuites.length === 0, fuites.join(', '));
verifier('2b aucune agence n\'est nommee dans le code du comptoir',
  CODE_COMPTOIR.toLowerCase().indexOf('grobras') === -1);
// Temoin : le mot EST bien present dans le fichier, en commentaire. Si ce
// temoin tombait, c'est que le filtrage des commentaires avale tout et que le
// test 2b ne verifie plus rien.
verifier('2c temoin : le filtrage des commentaires ne vide pas le fichier',
  SRC_COMPTOIR.toLowerCase().indexOf('grobras') !== -1
  && CODE_COMPTOIR.indexOf('agenceEmploiEmbaucher') !== -1);

// ===========================================================================
// 3. LE COMPTOIR AFFICHE LES DEUX COUTS SEPAREMENT
// ===========================================================================
// Le serveur rend cout_embauche et cout_jour distincts ; l'ecran doit les
// montrer tous les deux, sans en deduire l'un de l'autre.
var CAT_FEINT = {
  ok: true, employeur_id: 'test-agence', employeur: 'Agence de test',
  pays: 'republic', plafond_employes: 10, employes_actuels: 0,
  metiers: [{ metier: 'agent_securite', libelle: 'Agent de sécurité', recrutable: true,
              cout_embauche: 500, cout_jour: 0, pa: 1, quota: 4, employes: 0,
              caracteristiques: { PER: 12, VOL: 16 } }],
  candidats: [
    { candidat_id: 'c1', metier: 'agent_securite', nom: 'Untel Premier', genre: 'H',
      accroche: 'Une ligne.', portrait: null, vignette: null, cadrage: null,
      deja_employe: false },
    { candidat_id: 'c2', metier: 'agent_securite', nom: 'Untel Second', genre: 'F',
      accroche: null, portrait: null, vignette: null, cadrage: null,
      deja_employe: true }
  ]
};
var ORDRE_FEINT = { fn: 'embaucher_agent_securite', employeur: 'test-agence',
                    metier: 'agent_securite', pa: 1, cost: 500 };
var html = agenceEmploiRendu(CAT_FEINT, ORDRE_FEINT, escapeHtmlText);

verifier('3a le frais d\'embauche est affiche (500 FR)',
  html.indexOf('500 FR') !== -1 && html.indexOf('Frais d\'embauche') !== -1);
verifier('3b l\'absence de salaire est DITE, pas deduite',
  html.indexOf('Aucun salaire journalier') !== -1);
verifier('3c le cout d\'embauche n\'est jamais presente comme un tarif journalier',
  html.indexOf('500 FR par jour') === -1 && html.indexOf('500 FR/jour') === -1);
verifier('3d les deux candidats sont presentes, le deuxieme marque pris',
  html.indexOf('Untel Premier') !== -1 && html.indexOf('Untel Second') !== -1
  && html.indexOf('à votre service') !== -1 && html.indexOf('disponible') !== -1);
verifier('3e le quota du metier est annonce avant le clic (3 sur 4 restants)',
  html.indexOf('poste(s) de ce type encore ouvert(s) sur 4') !== -1);
verifier('3f un candidat deja employe n\'est pas cliquable',
  html.indexOf('agenceEmploiEmbaucher(\'c2\'') === -1
  && html.indexOf('agenceEmploiEmbaucher(\'c1\'') !== -1);

// Quota atteint : plus aucun candidat cliquable, et la raison est dite.
var CAT_PLEIN = JSON.parse(JSON.stringify(CAT_FEINT));
CAT_PLEIN.metiers[0].employes = 4;
var htmlPlein = agenceEmploiRendu(CAT_PLEIN, ORDRE_FEINT, escapeHtmlText);
verifier('3g quota atteint : aucun candidat cliquable et la limite est expliquee',
  htmlPlein.indexOf('agenceEmploiEmbaucher(') === -1
  && htmlPlein.indexOf('c\'est le maximum') !== -1);

// Le metier peut avoir PLUSIEURS representants : le moteur ne doit pas
// supposer le contraire. Trois employes sur quatre laissent une place.
var CAT_TROIS = JSON.parse(JSON.stringify(CAT_FEINT));
CAT_TROIS.metiers[0].employes = 3;
var htmlTrois = agenceEmploiRendu(CAT_TROIS, ORDRE_FEINT, escapeHtmlText);
verifier('3h trois employes sur un quota de quatre : le recrutement reste ouvert',
  htmlTrois.indexOf('agenceEmploiEmbaucher(\'c1\'') !== -1
  && htmlTrois.indexOf('1 poste(s) de ce type encore ouvert(s) sur 4') !== -1);

// ===========================================================================
// 4. EMBAUCHER UN AGENT : LE DEBIT EST LE FRAIS, LE STOCK EST LE SALAIRE
// ===========================================================================
// On embauche vraiment, avec un ecart maximal entre les deux notions :
// 500 FR a l'embauche, 0 FR par jour. C'est le cas qui faisait tomber
// l'ancien code.
RP_AGENCES_EMPLOI = {};
RP_AGENCES_EMPLOI_PAYS = null;
var REPONSE_EMBAUCHE = {
  ok: true, pnj_id: 'emp-agent_securite-abc', candidat_id: 'c1',
  metier: 'agent_securite', nom: 'Untel Premier', genre: 'H', accroche: 'Une ligne.',
  portrait: null, vignette: null, cadrage: null,
  role_libelle: 'Agent de sécurité — Agence de test',
  employeur_id: 'test-agence', employeur: 'Agence de test',
  cout_embauche: 500, cout_jour: 0, pa: 1,
  caracteristiques: { INT: 10, CHA: 8, VOL: 16, PER: 12, DUP: 8, ENT: 10 },
  paiement: { ok: true, montant: 500, pa: 1 },
  employes: 1, plafond: 10, quota: 4, employes_metier: 1
};
// LES BOUCHONS RENDENT DES PROMESSES, pas des objets : le code appelant fait
// `.catch(...)` sur le retour, et un objet nu le ferait tomber sur un
// TypeError -- ce qui a failli faire passer ce banc pour vert.
function sbEmployeurCandidats() { return Promise.resolve(CAT_FEINT); }
function sbEmployeurEmbaucher() { return Promise.resolve(REPONSE_EMBAUCHE); }

var argAvant = state.arg, paAvant = state.pa;
// `fn` volontairement absent : la piece de test n'est pas Grobras, et on veut
// verifier que l'embauche aboutit meme si le rafraichissement ne trouve rien.
//
// agenceEmploiEmbaucher est ASYNC : son corps s'arrete au premier `await` et
// reprend dans une micro-tache. Auditer state.employes juste apres l'appel
// aurait mesure l'etat d'AVANT l'embauche -- et tous les tests 4 auraient
// echoue sans que le code soit en cause. On vide donc la file.
agenceEmploiEmbaucher('c1', null);
drainMicrotasks();

verifier('4a un employe est entre dans state.employes', state.employes.length === 1,
  JSON.stringify(state.employes));
var ag = state.employes[0] || {};
verifier('4b le frais d\'embauche a bien ete preleve une fois (-500 FR, -1 PA)',
  state.arg === argAvant - 500 && state.pa === paAvant - 1,
  'arg ' + argAvant + '->' + state.arg + ', pa ' + paAvant + '->' + state.pa);
verifier('4c LE CHAMP `cout` PORTE LE SALAIRE (0), PAS LE FRAIS (500)',
  ag.cout === 0, 'cout = ' + JSON.stringify(ag.cout));
verifier('4d le metier, le libelle et les caracteristiques viennent du serveur',
  ag.job === 'agent_securite' && ag.role === 'Agent de sécurité — Agence de test'
  && ag.stats && ag.stats.VOL === 16 && ag.stats.PER === 12);
verifier('4e il rejoint le groupe', ag.inGroupe === true);
verifier('4f l\'identite de catalogue est conservee', ag.candidatId === 'c1');
verifier('4g le message distingue les deux montants',
  TOASTS.join(' ').indexOf('500 FR de frais d\'embauche') !== -1
  && TOASTS.join(' ').indexOf('Aucun salaire journalier') !== -1,
  TOASTS.join(' || '));

// ===========================================================================
// 5. LA NUIT PASSE : UN AGENT A SALAIRE NUL NE COUTE RIEN ET RESTE
// ===========================================================================
// payerEmployes() est le payeur reel. On le charge pour de vrai depuis
// plateau-multijoueur.js plutot que de le reecrire : un banc qui reimplemente
// ce qu'il teste ne prouve rien.
var MAX_EMPLOYES = 10;
function sbEmployeLiberer() { return Promise.resolve({ ok: true }); }
var SRC_MJ = readFile('plateau-multijoueur.js');
var i0 = SRC_MJ.indexOf('function payerEmployes()');
var i1 = SRC_MJ.indexOf('\n}', SRC_MJ.indexOf('toFire.reverse()', i0)) + 2;
// On isole la fonction par ses bornes reelles plutot que de charger les 2 000
// lignes du fichier (qui attendent tout le DOM du plateau). Le corps execute
// est donc, au caractere pres, celui qui tourne en production.
verifier('5a payerEmployes a pu etre isolee de plateau-multijoueur.js',
  i0 > 0 && i1 > i0, 'i0=' + i0 + ' i1=' + i1);
var payerEmployes = (new Function('state', 'COUNTRIES', 'getEmployes', 'addJournalEntry',
    'addMailNotification', 'showToast', 'sbEmployeLiberer',
    SRC_MJ.slice(i0, i1) + '\n; return payerEmployes;'))(
  state, COUNTRIES, getEmployes, addJournalEntry, addMailNotification, showToast, sbEmployeLiberer);

var argNuit = state.arg;
payerEmployes();
verifier('5b aucun prelevement nocturne pour un salaire nul',
  state.arg === argNuit, 'arg ' + argNuit + ' -> ' + state.arg);
verifier('5c l\'agent est toujours en poste apres la nuit',
  state.employes.length === 1);

// ===========================================================================
// 6. TEMOIN DE REGRESSION — L'ANCIEN COMPORTEMENT DOIT ETRE FAUX
// ===========================================================================
// On remet volontairement le prix d'embauche dans `cout`, comme le faisait
// doRecruterInformateurPNJ, et on exige que la nuit devienne ruineuse. Si ce
// test echouait, c'est que le banc ne mesure rien.
state.employes[0].cout = 500;
var argTemoin = state.arg;
payerEmployes();
verifier('6a temoin : avec le frais d\'embauche dans `cout`, la nuit preleve 500 FR',
  state.arg === argTemoin - 500, 'arg ' + argTemoin + ' -> ' + state.arg);
state.employes[0].cout = 0;

// Et le cas de la fuite : un joueur sans fonds perdait son agent chaque nuit.
state.employes[0].cout = 500;
state.arg = 100;
payerEmployes();
verifier('6b temoin : fonds insuffisants, l\'agent quittait le groupe des la 1re nuit',
  state.employes.length === 0);

// ===========================================================================
// 7. L'INFORMATEUR N'A RIEN PERDU
// ===========================================================================
// Sa correction est invisible par construction (150 FR a l'embauche ET 150 FR
// par jour), et c'est pourquoi le defaut a survecu. On verifie que la source
// lue est bien `cout_jour` et que, pour lui, le resultat est inchange.
var SRC_INF = SRC_MJ.slice(SRC_MJ.indexOf('async function doRecruterInformateurPNJ'),
                           SRC_MJ.indexOf('function isEmploye(nomPnj)'));
verifier('7a doRecruterInformateurPNJ lit resEmp.cout_jour',
  SRC_INF.indexOf('resEmp.cout_jour') !== -1);
verifier('7b et ne pousse plus le prix de l\'ordre dans `cout`',
  SRC_INF.indexOf('\n    cout, inGroupe') === -1
  && SRC_INF.indexOf('cout: coutJour') !== -1);
// L'apostrophe est ECHAPPEE dans le source (`l\\'embauche`) : chercher la forme
// non echappee ne trouvait rien, et le premier jet de ce banc s'est cru en
// echec alors que le code etait juste.
verifier('7c le message nomme le frais d\'embauche et le salaire separement',
  SRC_INF.indexOf('embauche, puis') !== -1
  && SRC_INF.indexOf('+ coutJour +') !== -1);

// Execution reelle : 150/150 doit donner exactement 150 par nuit.
state.employes = [{ nom: 'Momo Fouine (PNJ)', job: 'informateur', cout: 150, inGroupe: true }];
state.arg = 10000;
payerEmployes();
verifier('7d l\'informateur coute toujours 150 FR par nuit, inchange',
  state.arg === 9850, 'arg = ' + state.arg);

// ===========================================================================
// 8. L'ESCORT RESTE HORS DE payerEmployes (non-regression du 26 septembre)
// ===========================================================================
state.employes = [{ nom: 'Une Escort', job: 'escort', cout: 800, inGroupe: true }];
state.arg = 10000;
payerEmployes();
verifier('8a une escort n\'est pas facturee deux fois : payerEmployes la saute',
  state.arg === 10000, 'arg = ' + state.arg);

// ---------- RAPPORT ----------
print('');
print('=== BANC SOCLE D\'EMBAUCHE DES AGENCES ===');
print(LIGNES.join('\n'));
print('');
print(OK + ' OK, ' + KO + ' ECHEC');
if (KO > 0) throw new Error(KO + ' assertion(s) en echec');
