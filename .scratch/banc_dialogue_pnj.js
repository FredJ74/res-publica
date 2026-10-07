ObjC.import('Foundation');
function lire(p){ return $.NSString.stringWithContentsOfFileEncodingError(p, 4, null).js; }
function ecrire(p, s){ $.NSString.alloc.initWithUTF8String(s).writeToFileAtomicallyEncodingError(p, true, 4, null); }
var R = [];
function dit(s){ R.push(s); }

// --- DOM minimal ------------------------------------------------------------
var NOEUDS = {};
function noeud(id){
  if (!NOEUDS[id]) NOEUDS[id] = { id:id, textContent:'', innerHTML:'', value:'',
    classes:{}, classList:{ add:function(){}, remove:function(){}, contains:function(){return false;} } };
  return NOEUDS[id];
}
['pnj-speech','pnj-actions','modal-pnj','postes-body','postes-modal-title'].forEach(noeud);
var document = { getElementById:function(id){ return NOEUDS[id] || null; },
  querySelector:function(s){ return noeud(s); }, querySelectorAll:function(){ return []; },
  createElement:function(){ return { style:{}, classList:{add:function(){}}, appendChild:function(){} }; },
  body:{ appendChild:function(){} } };
var window = { location:{ href:'' }, addEventListener:function(){}, removeEventListener:function(){},
  setTimeout:function(){}, clearTimeout:function(){}, innerWidth:1400, innerHeight:900 };
document.addEventListener = function(){};
document.removeEventListener = function(){};
document.querySelectorAll = function(){ return []; };
function requestAnimationFrame(){ return 0; }
function alert(){} function confirm(){ return false; } function prompt(){ return null; }
var localStorage = { getItem:function(){ return null; }, setItem:function(){}, removeItem:function(){} };
var navigator = { userAgent:'sonde' };

// --- RESEAU TRACE : on note ce qui part, et on repond comme le vrai endpoint -
var REQUETES = [];
var REPONSE_FETCH = null;
function fetch(url, opts){
  REQUETES.push({ url:url, opts:opts });
  if (REPONSE_FETCH) return Promise.resolve(REPONSE_FETCH);
  return Promise.resolve({ ok:true, status:200,
    json:function(){ return Promise.resolve({ reponse:'REPONSE DE TEST DEEPSEEK' }); },
    clone:function(){ return this; } });
}

// --- SOCLE ------------------------------------------------------------------
function escapeHtmlText(s){ return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;')
  .replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
function showToast(){} function addJournalEntry(){}
// PIEGE DU HARNAIS, A NE PAS RECHERCHER DEUX FOIS : JXA expose un objet `console`
// mais SANS warn ni error. Le code du jeu journalise ses pannes avec console.warn ;
// sans ces deux stubs, l'appel leve dans le bloc catch lui-meme, le catch ne finit
// pas son travail, et le banc conclut a tort que le joueur reste bloque.
console.warn  = function(){};
console.error = function(){};
console.log   = console.log || function(){};
function rpAuthAssurerSession(){ return Promise.resolve(); }
function rpAuthJeton(){ return 'jeton-de-test'; }
function sbSavePersonnage(){ return Promise.resolve(); }
var i18next = { language:'fr', isInitialized:false, exists:function(){return false;}, t:function(k){return k;} };

// --- LE JEU : data.js puis plateau-pnj.js -----------------------------------
// UN SEUL eval POUR LES DEUX FICHIERS. `const COUNTRIES` de data.js n'est pas
// visible depuis un second eval -- les declarations lexicales ne franchissent pas
// cette frontiere. Le navigateur, lui, partage un unique environnement global entre
// tous les <script>. Concatener reproduit donc la condition reelle ; deux eval
// fabriquaient une fausse panne.
// ORDRE REEL DE plateau.html, ET UN SEUL eval. Les declarations lexicales
// (const/let) ne franchissent pas la frontiere d'un eval : charger chaque fichier
// separement fabrique de fausses ReferenceError. Le navigateur partage un unique
// environnement global entre tous les <script> -- c'est cette condition qu'on
// reproduit en concatenant, dans l'ordre exact de la page.
var FICHIERS = ['data.js','forum.js','plateau-core.js','plateau-pnj.js'];
var CHARGEMENT = FICHIERS.join(' + ');
try {
  var src = FICHIERS.map(function(f){
    return lire('/Users/fredericjasseron/ResPublica/' + f);
  }).join('\n;\n');
  // `const PNJ_PROFILS` ne franchit pas la frontiere de l'eval ; une declaration
  // `var`, elle, fuit vers la portee englobante. C'est le seul moyen de lire la
  // table depuis le banc sans la recopier -- et recopier serait tester une copie.
  eval(src + '\n;\nvar __PROFILS = PNJ_PROFILS; var __PERSOS = PNJ_PERSONALITIES;');
  dit('[OK] charges dans un seul contexte : ' + CHARGEMENT);
} catch (e) {
  dit('!!! CHARGEMENT IMPOSSIBLE (' + CHARGEMENT + ') : ' + e.message);
  ecrire('/tmp/sonde_pnj.txt', R.join('\n'));
  throw e;
}

var state = {
  country:'republic', currentCity:'caserne', currentBuilding:'caserne-militaire',
  currentRoom:'infirmerie', day:3, pa:10, arg:500, liquide:500, inf:10, pop:10,
  inventory:[], contacts:[], pnjConversations:{},
  poste:{ id:'lieutenant' },
  char:{ name:'Vince Kubrick', archetype:'militaire', career:'militaire',
         origin:'republia', school:'aucune', stats:{}, bio:'', age:30,
         queteAccueil:null, maxence:null, succesMaxence:null }
};

var OK=0, KO=0;
function verifie(nom, cond, det){
  if (cond) { OK++; dit('  [OK]    ' + nom + (det ? '  — ' + det : '')); }
  else      { KO++; dit('  [ECHEC] ' + nom + (det ? '  — ' + det : '')); }
}

// Un tour de dialogue complet, et ce que le joueur voit a la fin.
async function tour(nom, job, reponseFetch){
  var pnj = { name: nom + ' (PNJ)', role:'PNJ', rel:'neutral', job: job || 'citoyen' };
  noeud('pnj-speech').innerHTML = ''; noeud('pnj-speech').textContent = '';
  REQUETES = []; REPONSE_FETCH = reponseFetch || null;
  var leve = null;
  try { await talkToPnj(encodeURIComponent(JSON.stringify(pnj)), 'Bonjour, une question.'); }
  catch (e) { leve = e && e.message; }
  REPONSE_FETCH = null;
  var sp = noeud('pnj-speech');
  var vu = String(sp.textContent || sp.innerHTML || '');
  return { leve: leve, requetes: REQUETES.length, vu: vu,
           bloque: vu.indexOf('En train de repondre') !== -1,
           payload: REQUETES.length ? JSON.parse(REQUETES[0].opts.body) : null };
}

(async function(){
  dit('');
  dit('=== 1. traitsLisibles accepte les deux formes reelles de PNJ_PROFILS ===');
  verifie('tableau -> liste separee par des virgules',
    traitsLisibles({ traits:['bourru','fier'] }) === 'bourru, fier');
  verifie('phrase -> rendue telle quelle (aucun texte de personnalite reecrit)',
    traitsLisibles({ traits:'Infirmiere militaire. Seche, precise.' })
      === 'Infirmiere militaire. Seche, precise.');
  verifie('absent -> chaine vide, aucune exception',
    traitsLisibles({}) === '' && traitsLisibles(null) === '' && traitsLisibles({traits:null}) === '');
  verifie('tableau avec trous -> les trous sont ecartes',
    traitsLisibles({ traits:['a', null, '', 'b'] }) === 'a, b');

  dit('');
  dit('=== 2. TOUS les PNJ de PNJ_PROFILS aboutissent (c\'est le test qui manquait) ===');
  var noms = Object.keys(__PROFILS);
  dit('  ' + noms.length + ' fiches dans PNJ_PROFILS, dont ' +
      noms.filter(function(n){ return typeof __PROFILS[n].traits === 'string'; }).length +
      ' a traits en PHRASE et ' +
      noms.filter(function(n){ return Array.isArray(__PROFILS[n].traits); }).length +
      ' a traits en TABLEAU');
  var bloques = [], sansReseau = [];
  for (var i = 0; i < noms.length; i++) {
    var r = await tour(noms[i]);
    if (r.bloque) bloques.push(noms[i] + ' (' + r.leve + ')');
    if (r.requetes !== 1) sansReseau.push(noms[i]);
  }
  verifie('aucune fiche ne laisse le joueur bloque sur « En train de repondre... »',
    bloques.length === 0, bloques.length ? bloques.join(' | ') : 'les ' + noms.length + ' fiches passent');
  verifie('chacune declenche exactement UN appel a /api/chat',
    sansReseau.length === 0, sansReseau.length ? sansReseau.join(' | ') : 'les ' + noms.length + ' fiches');

  dit('');
  dit('=== 3. les trois PNJ de la caserne, nommement ===');
  var caserne = ['Ève Toahémarch', 'Adjudant Gaspard Ferrière', 'Caporal Alouche'];
  for (var k = 0; k < caserne.length; k++) {
    var rc = await tour(caserne[k]);
    verifie(caserne[k] + ' : atteint le serveur et affiche la reponse',
      !rc.bloque && rc.requetes === 1 && rc.vu.length > 0 && !rc.leve,
      'profil=' + (rc.payload && rc.payload.profil) + ' vu=' + JSON.stringify(rc.vu.slice(0,40)));
  }

  dit('');
  dit('=== 4. un PNJ SANS fiche PNJ_PROFILS fonctionne toujours ===');
  var rs = await tour('Zzz Personnage Inexistant');
  verifie('PNJ sans fiche : un appel part, rien n\'est bloque',
    !rs.bloque && rs.requetes === 1, 'profil=' + (rs.payload && rs.payload.profil));

  dit('');
  dit('=== 5. la panne reseau reste VISIBLE (le catch n\'a pas ete casse) ===');
  var rp = await tour('Ève Toahémarch', null,
    { ok:false, status:502, json:function(){ return Promise.resolve({ error:'x' }); },
      clone:function(){ return this; } });
  verifie('502 du serveur : message clair au joueur, plus d\'attente infinie',
    !rp.bloque && rp.vu.indexOf('Discussion impossible') !== -1, JSON.stringify(rp.vu.slice(0,60)));

  dit('');
  dit(OK + ' verts, ' + KO + ' echec(s).');
  ecrire('/tmp/banc_pnj.txt', R.join('\n'));
})().catch(function(e){
  dit('!!! BANC INTERROMPU : ' + e.message + '\n' + (e.stack||''));
  ecrire('/tmp/banc_pnj.txt', R.join('\n'));
});
'lance'
