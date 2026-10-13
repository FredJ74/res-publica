// BANC DU DIALOGUE DES PNJ DE REPUBLIA (13 octobre 2026)
// SOURCES: aucune -- ce banc lit les fichiers du depot lui-meme, par readFile.
//
// LA QUESTION POSEE, ET ELLE N'AVAIT JAMAIS ETE POSEE AINSI : un PNJ qu'un joueur VOIT dans une
// piece de Republia obtient-il une reponse quand on lui parle ?
//
// Deux conditions doivent tenir ENSEMBLE, et les mesurer separement ne prouve rien :
//
//   1. COTE NAVIGATEUR -- `talkToPnj` doit aboutir : soit une reponse deterministe ecrite pour ce
//      PNJ, soit UN appel a /api/chat. Une exception levee avant le try/catch laisse le joueur
//      bloque sur « En train de repondre... » pour toujours ; c'est arrive le 29 septembre 2026 a
//      trois PNJ de la caserne, et aucun banc ne l'avait vu.
//
//   2. COTE SERVEUR -- l'identifiant de profil envoye doit EXISTER dans la table fermee de
//      `api/_pnj-profils.js`. Sinon `/api/chat` repond 400 « Profil inconnu » et le joueur lit
//      « Discussion impossible momentanement » -- ce qu'un testeur decrit, tres exactement,
//      comme « ce personnage n'est pas connecte ».
//
// LES DEUX COTES SONT CHARGES DANS LE MEME CONTEXTE, et c'est ce qui rend la mesure possible
// sans reseau : le navigateur calcule le slug, le serveur declare la table, et le banc confronte
// les deux. Un PNJ qui passe la premiere condition et echoue la seconde est MUET -- et il a l'air
// d'une panne technique, pas d'un personnage taciturne.
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-dialogue-pnj-republia.js
//   Il doit finir sur « LES N EPREUVES SONT VERTES. »

var RACINE = '/Users/fredericjasseron/ResPublica/';
// SUBSTITUTIONS laisse une contre-epreuve remplacer UN SEUL fichier par une copie patchee, sans
// jamais toucher le depot. En exploitation la variable n'existe pas, donc rien ne change : c'est
// le banc qui doit rougir sur la copie, et un banc qu'on ne peut pas faire rougir ne prouve rien.
function lire(f) {
  if (typeof SUBSTITUTIONS !== 'undefined' && SUBSTITUTIONS && SUBSTITUTIONS[f]) {
    return readFile(SUBSTITUTIONS[f]);
  }
  return readFile(RACINE + f);
}
// Les mots-cles de module ne sont pas evaluables ici : on les retire comme le fait
// outils/bancs/lancer-banc.py, en preservant le nombre de lignes pour que les numeros
// d'erreur restent justes.
function sansModules(src) {
  return src.replace(/^import\s+[^;]*?;/gm, function (m) { return Array(m.split('\n').length).join('\n'); })
            .replace(/^export\s+default\s+/gm, 'var __def = ')
            .replace(/^export\s+(const|let|var|function|async\s+function|class)\s/gm, '$1 ')
            .replace(/^export\s*\{[^}]*?\}\s*;?/gm, function (m) { return Array(m.split('\n').length).join('\n'); });
}

var STUBS = [
  'var NOEUDS = {};',
  'function noeud(id){ if(!NOEUDS[id]) NOEUDS[id] = { id:id, textContent:"", innerHTML:"", value:"",',
  '  style:{}, dataset:{}, parentNode:{ insertBefore:function(){} },',
  '  classList:{ add:function(){}, remove:function(){}, contains:function(){return false;} },',
  '  appendChild:function(){}, insertBefore:function(){} }; return NOEUDS[id]; }',
  'var document = { getElementById:function(id){ return noeud(id); },',
  '  querySelector:function(s){ return noeud(s); }, querySelectorAll:function(){ return []; },',
  '  createElement:function(){ return noeud("neuf-" + Math.random()); },',
  '  addEventListener:function(){}, removeEventListener:function(){}, body:{ appendChild:function(){} } };',
  'var window = { location:{ href:"", hash:"" }, addEventListener:function(){},',
  '  removeEventListener:function(){}, innerWidth:1400, innerHeight:900 };',
  'function requestAnimationFrame(){ return 0; }',
  'function setTimeout(f){ return 0; } function clearTimeout(){} function setInterval(){ return 0; }',
  'function clearInterval(){}',
  'function alert(){} function confirm(){ return false; } function prompt(){ return null; }',
  'var localStorage = { getItem:function(){ return null; }, setItem:function(){}, removeItem:function(){} };',
  'var sessionStorage = localStorage;',
  'var navigator = { userAgent:"banc" };',
  'var REQUETES = [];',
  'var REPONSE_FETCH = null;',
  'function fetch(url, opts){ REQUETES.push({ url:url, opts:opts });',
  '  if (REPONSE_FETCH) return Promise.resolve(REPONSE_FETCH);',
  '  return Promise.resolve({ ok:true, status:200, clone:function(){ return this; },',
  '    json:function(){ return Promise.resolve({ reponse:"REPONSE DE BANC" }); } }); }',
  'function escapeHtmlText(s){ return String(s == null ? "" : s); }',
  'function showToast(){} function addJournalEntry(){} function addExternalEvent(){}',
  'function updateUI(){} function renderEmployesPanel(){} function renderPersonsList(){}',
  'function rpAuthAssurerSession(){ return Promise.resolve(); }',
  'function rpAuthJeton(){ return "jeton-de-banc"; }',
  'function sbSavePersonnage(){ return Promise.resolve(); }',
  'function sbGetMariageActif(){ return Promise.resolve(null); }',
  'function getQueteActivePourPnj(){ return Promise.resolve(null); }',
  'function pnjSocialNoterConversation(){} ',
  'var i18next = { language:"fr", isInitialized:false, exists:function(){ return false; }, t:function(k){ return k; } };'
  // `state` EST DECLARE PAR LE JEU (plateau-core.js, `let state`), et un second `var state`
  // ferait lever « Cannot declare a let variable twice ». On ne le stube donc pas : on complete
  // l'objet REEL apres chargement. C'est d'ailleurs plus juste -- on mesure l'etat du jeu.
].join('\n');

// L'ORDRE EST CELUI DE plateau.html, ET IL COMPTE : `forum.js` y est charge AVANT
// `plateau-pnj.js`, et `talkToPnj` lit `FORUM_TOPICS` HORS de tout try/catch. Charger ces
// fichiers dans un autre ordre fabriquerait une fausse panne -- ou en masquerait une vraie.
var CLIENT = ['data.js', 'forum.js', 'plateau-core.js', 'plateau-pnj.js'];
var SERVEUR = ['api/_bible-militaire.js', 'api/_bible-presidence.js', 'api/_bible-gouvernement.js',
               'api/_bible-assemblee.js', 'api/_pnj-personnalites.js', 'api/_pnj-referents.js',
               'api/_pnj-profils.js'];

var src = STUBS + '\n;\n'
  + CLIENT.map(function (f) { return lire(f); }).join('\n;\n') + '\n;\n'
  + SERVEUR.map(function (f) { return sansModules(lire(f)); }).join('\n;\n')
  // Les declarations lexicales ne franchissent pas la frontiere d'un eval : on expose par `var`
  // ce que le banc doit lire. Recopier ces tables serait mesurer une copie.
  + '\n;\nvar __TOUS = TOUS_PROFILS; var __WORLD = WORLD; var __BUILD = BUILDINGS;'
  + ' var __talk = talkToPnj; var __profilDe = profilServeurDuPnj;'
  + ' var __noeud = noeud; var __req = function(){ return REQUETES; };'
  + ' var __vide = function(){ REQUETES = []; };'
  + ' var __getBC = function(b){ var c = WORLD[state.country][state.currentCity];'
  + '   return (c && c.buildingContext && c.buildingContext[b]) || null; };'
  + ' var __prompt = construirePromptSysteme; var __state = state;';

eval(src);

// L'ETAT REEL DU JEU, complete comme celui d'une joueuse qui vient d'arriver. On ne remplace pas
// l'objet -- il est `let` dans plateau-core.js -- on pose seulement ce que le dialogue lit.
__state.country = 'republic';
__state.currentCity = 'capitale';
__state.currentBuilding = 'hotel-republica';
__state.currentRoom = 'accueil';
__state.day = 3;
__state.pnjConversations = {};
__state.employes = [];
__state.recherche = [];
__state.poste = null;
__state.char = { name: 'Testeuse Nouvelle', archetype: 'citoyen', career: 'worker', stats: {},
                 queteAccueil: null, maxence: null, succesMaxence: null };

// ----------------------------------------------------------------------------------------------
var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}

// L'INVENTAIRE EST CALCULE, JAMAIS RECOPIE. La liste des personnes d'une piece suit la meme regle
// que l'affichage : une surcharge de ville REMPLACE la liste du gabarit, et la surcharge sans
// piece remplace celle de la PREMIERE piece. S'en ecarter ferait mesurer des PNJ que personne ne
// voit, et manquer ceux que tout le monde voit.
function personnesDeLaPiece(bid, rid) {
  var b = __BUILD[bid], ctx = __getBC(bid);
  var extra = ctx && ctx.roomsExtra;
  var room = (b && b.rooms && b.rooms[rid]) || (extra && extra[rid]);
  var premiere = Object.keys((b && b.rooms) || {})[0] === rid;
  var ov = ctx && ctx.roomOverrides && ctx.roomOverrides[rid];
  if (ov && ov.persons && ov.persons.length > 0) return ov.persons;
  if (premiere && ctx && ctx.persons && ctx.persons.length > 0) return ctx.persons;
  return (room && room.persons) || [];
}

var VILLES = ['capitale', 'ville_a', 'ville_b'];
var PNJ = [];
VILLES.forEach(function (v) {
  __state.currentCity = v;
  (__WORLD.republic[v].buildings || []).forEach(function (bid) {
    var b = __BUILD[bid], ctx = __getBC(bid);
    var pieces = Object.keys((b && b.rooms) || {});
    if (ctx && ctx.roomsExtra) Object.keys(ctx.roomsExtra).forEach(function (r) {
      if (pieces.indexOf(r) < 0) pieces.push(r);
    });
    pieces.forEach(function (rid) {
      personnesDeLaPiece(bid, rid).forEach(function (p) {
        if (!p || !p.name) return;
        // Ni un cadavre ni un comptoir d'agence ne sont des interlocuteurs : openPnjModal les
        // detourne AVANT toute fiche, et leur demander de parler n'aurait aucun sens.
        if (p.terrainPnjId === 'cadavre' || p.job === 'escort_agence') return;
        if (p.isPJ === true) return;
        PNJ.push({ ville: v, bat: bid, piece: rid, p: p });
      });
    });
  });
});

print('');
print('1. L INVENTAIRE DES PNJ VISIBLES DE REPUBLIA');
att('les trois villes de Republia sont lues', VILLES.length === 3);
att('l inventaire n est pas vide', PNJ.length > 100, PNJ.length + ' presences');
var noms = {};
PNJ.forEach(function (x) { noms[x.p.name] = x; });
print('      ' + PNJ.length + ' presences, ' + Object.keys(noms).length + ' PNJ distincts');

print('');
print('2. CHAQUE PNJ VISIBLE A-T-IL UN PROFIL SERVEUR ?');
// UN PNJ VISIBLE SANS PROFIL EST MUET, ET IL A L'AIR D'UNE PANNE. C'est l'epreuve qui manquait :
// le navigateur calcule un slug, le serveur tient une table fermee, et rien ne les confrontait.
// LES SIX MUETS SONT DECLARES ICI, NOMMEMENT, ET C'EST TOUT LE PRINCIPE. Aucun des six n'a de
// personnalite ecrite nulle part -- ni dans PNJ_PERSONALITIES, ni dans PNJ_PROFILS, ni en base --
// et le cahier des charges du 13 octobre 2026 est explicite : on ne leur en invente pas sans
// arbitrage de game design. Ils sont donc ATTENDUS muets, et l'interface ne leur propose plus de
// boite de question (voir le chapitre 6).
//
// CE QUE CETTE LISTE PROTEGE : un PNJ muet de PLUS fait rougir le banc. C'est la seule facon
// d'empecher que la situation du 29 septembre -- des PNJ qui cessent de repondre sans que rien ne
// s'allume -- se reproduise a la prochaine piece ajoutee. Raccorder l'un d'eux, c'est retirer sa
// ligne d'ici le meme jour.
var MUETS_DECLARES = {
  'bernard_piluler':       "Directeur de l'Usine Pharmaceutique — titulaire_poste, aucune personnalite ecrite",
  'marcel_silo':           "Directeur de l'Entrepot de Luthecia — idem",
  'yvon_paletier':         "Directeur de l'Entrepot de Port-Sainte-Marie — idem",
  'norbert_charton':       "Directeur de l'Entrepot de Montrouge — idem",
  'maitre_ali_bihanbeton': "Avocat commis d'office de Port-Sainte-Marie — aucune personnalite ecrite",
  'maitre_henri_nossant':  "Avocat commis d'office de Montrouge — idem"
};
var sansProfil = [], inattendus = [];
Object.keys(noms).sort().forEach(function (nom) {
  var x = noms[nom];
  var id = __profilDe(x.p);
  if (!id || !__TOUS[id]) {
    sansProfil.push(id);
    if (!MUETS_DECLARES[id]) {
      inattendus.push(nom + '  [' + id + ']  ' + x.ville + ' ' + x.bat + '/' + x.piece);
    }
  }
});
att('aucun PNJ visible n est muet EN DEHORS des muets declares',
    inattendus.length === 0,
    inattendus.length + ' muet(s) non declare(s) :\n        ' + inattendus.join('\n        '));
var declaresDisparus = Object.keys(MUETS_DECLARES).filter(function (id) {
  return sansProfil.indexOf(id) < 0;
});
att('aucun muet declare n a ete raccorde sans qu on retire sa ligne',
    declaresDisparus.length === 0,
    'a retirer de MUETS_DECLARES : ' + declaresDisparus.join(', '));
print('      ' + sansProfil.length + ' muet(s), tous declares et en attente d un arbitrage');

print('');
print('3. LES PNJ QUE LA QUETE D ACCUEIL ET LES MECANIQUES INJECTENT');
// ILS NE SONT DANS AUCUNE PIECE DE data.js, et c'est pour cela qu'ils echappaient a tout
// inventaire : Jeremy est un EMPLOYE pose dans le groupe du joueur, Maxence une carte speciale.
// Ce sont pourtant les deux PNJ a qui un nouveau joueur parle le plus.
var INJECTES = [
  { nom: 'Jérémy',          ou: 'quete d accueil — compagnon du joueur' },
  { nom: 'Maxence Monfils', ou: 'parc botanique / serre' }
];
INJECTES.forEach(function (j) {
  var id = __profilDe({ name: j.nom });
  att('  ' + j.nom + ' a un profil serveur (' + j.ou + ')', !!__TOUS[id], 'slug ' + id);
});

// LES NEUF DEPUTES DE L'HEMICYCLE sont injectes par `appliquerDeputesAssemblee` depuis
// ASSEMBLEE_SIEGES : ils ne figurent dans aucune piece de data.js, et ils sont pourtant des
// cartes cliquables comme les autres. HUIT SUR NEUF SONT MUETS, et c'est declare : un depute PNJ
// n'a ni personnalite ecrite ni savoir propre, seulement un siege et une ville. Seul President
// Laroche en a une -- il est referent. Les raccorder suppose d'ecrire neuf caracteres, donc un
// arbitrage de game design, pas une passe technique.
var DEPUTES = ['Étienne Vauclerc', 'Sophie Maréchal', 'President Laroche', 'Yann Legall',
               'Maëlle Leroux', 'Loïc Kermeur', 'Nathalie Charron', 'Gérard Pichon',
               'Élodie Vasseur'];
var DEPUTES_MUETS_DECLARES = ['etienne_vauclerc', 'sophie_marechal', 'yann_legall',
                              'maelle_leroux', 'loic_kermeur', 'nathalie_charron',
                              'gerard_pichon', 'elodie_vasseur'];
var deputesInattendus = [], deputesRaccordes = [];
DEPUTES.forEach(function (nom) {
  var id = __profilDe({ name: nom });
  var muet = !__TOUS[id];
  var declare = DEPUTES_MUETS_DECLARES.indexOf(id) >= 0;
  if (muet && !declare) deputesInattendus.push(nom + ' [' + id + ']');
  if (!muet && declare) deputesRaccordes.push(id);
});
att('aucun depute PNJ n est muet en dehors des huit declares',
    deputesInattendus.length === 0, deputesInattendus.join(', '));
att('et aucun des huit n a ete raccorde sans qu on retire sa ligne',
    deputesRaccordes.length === 0, deputesRaccordes.join(', '));
att('President Laroche, lui, repond -- il est referent',
    !!__TOUS[__profilDe({ name: 'President Laroche' })]);

// LES DOUZE CANDIDATS DE L'AGENCE GROBRAS deviennent des employes du joueur une fois embauches,
// donc des cartes accompagnantes cliquables. Aucun n'a de personnalite ecrite : ils sont declares
// muets pour la meme raison, et l'interface ne leur propose plus de boite de question.
var CANDIDATS_GROBRAS = ['albert_hagarde', 'anatole_crocs', 'brigitte_ronde', 'firmin_poigne',
  'gerard_menvussa', 'ginette_molosse', 'josette_cadenas', 'leon_tourniquet', 'marcel_mordu',
  'rachel_barrage', 'roger_croquignol', 'sylvain_guerite'];
var grobrasRaccordes = CANDIDATS_GROBRAS.filter(function (id) { return !!__TOUS[id]; });
att('les douze candidats de Grobras sont declares muets, et le restent',
    grobrasRaccordes.length === 0, 'raccordes sans retrait de leur ligne : ' + grobrasRaccordes.join(', '));

// LES TROIS DERNIERS CHAPITRES SONT ASYNCHRONES, ET ILS DOIVENT L'ETRE. `talkToPnj` est une
// fonction `async` : lire `pnj-speech` sans l'attendre mesure l'ecran AVANT la reponse -- c'est
// exactement l'erreur qui ferait croire que les 171 PNJ restent bloques. On attend donc chaque
// tour, et le verdict est imprime dans la meme chaine de promesses.
function tour(pnj, action) {
  __vide();
  var sp = __noeud('pnj-speech');
  sp.textContent = ''; sp.innerHTML = '';
  return __talk(encodeURIComponent(JSON.stringify(pnj)), action).then(function () {
    var vu = String(sp.textContent || sp.innerHTML || '');
    return { leve: null, appels: __req().length, vu: vu,
             bloque: vu.indexOf('En train de repondre') !== -1 };
  }, function (e) {
    var vu = String(sp.textContent || sp.innerHTML || '');
    return { leve: (e && e.message) || String(e), appels: __req().length, vu: vu,
             bloque: vu.indexOf('En train de repondre') !== -1 };
  });
}

(async function () {
  print('');
  print('4. LE CHEMIN NAVIGATEUR ABOUTIT POUR CHACUN');
  var bloques = [], leves = [], muetsEcran = [];
  var listeNoms = Object.keys(noms).sort();
  for (var i = 0; i < listeNoms.length; i++) {
    var x = noms[listeNoms[i]];
    __state.currentCity = x.ville; __state.currentBuilding = x.bat; __state.currentRoom = x.piece;
    var r = await tour(x.p, 'Bonjour, qui etes-vous et que faites-vous ici ?');
    if (r.leve) leves.push(listeNoms[i] + ' : ' + r.leve);
    if (r.bloque) bloques.push(listeNoms[i]);
    if (r.appels === 0 && r.vu.length === 0) muetsEcran.push(listeNoms[i]);
  }
  att('aucun PNJ ne leve une exception dans le chemin de dialogue',
      leves.length === 0, leves.slice(0, 12).join('\n        '));
  att('aucun PNJ ne laisse le joueur bloque sur « En train de repondre... »',
      bloques.length === 0, bloques.slice(0, 12).join(', '));
  att('chaque PNJ rend soit un appel serveur, soit une reponse ecrite d avance',
      muetsEcran.length === 0, muetsEcran.slice(0, 12).join(', '));

  print('');
  print('5. CE QUI PART SUR LE RESEAU NE PORTE NI CLE NI PROMPT');
  var unPnj = noms[Object.keys(noms)[0]].p;
  __state.currentCity = 'capitale';
  var r1 = await tour(unPnj, 'Une question quelconque.');
  var corps = r1.appels ? JSON.parse(__req()[0].opts.body) : null;
  att('la requete part vers /api/chat', r1.appels === 1 && __req()[0].url === '/api/chat',
      r1.appels + ' appel(s)');
  att('elle ne porte QUE profil, lang, message et historique',
      !!corps && Object.keys(corps).sort().join(',') === 'historique,lang,message,profil',
      corps ? Object.keys(corps).sort().join(',') : '(aucun corps)');
  att('elle ne contient aucun prompt systeme et aucune cle',
      !!corps && !/DEEPSEEK|api[_-]?key|Tu joues un personnage/i.test(JSON.stringify(corps)));
  att('le jeton du joueur voyage dans l en-tete Authorization, pas dans le corps',
      r1.appels === 1 && /^Bearer /.test(__req()[0].opts.headers.Authorization));
  att('un seul appel reseau par replique -- jamais deux',
      r1.appels === 1, r1.appels + ' appel(s)');

  print('');
  print('6. UNE PANNE SE DIT, ET ELLE NE SE DEGUISE PAS EN PNJ');
  REPONSE_FETCH = { ok: false, status: 502, clone: function () { return this; },
                    json: function () { return Promise.resolve({ error: 'x' }); } };
  var r2 = await tour(unPnj, 'Une question pendant la panne.');
  REPONSE_FETCH = null;
  att('un 502 du serveur donne un message technique clair, jamais une replique de PNJ',
      r2.vu.indexOf('Discussion impossible') >= 0, JSON.stringify(r2.vu.slice(0, 70)));

  REPONSE_FETCH = { ok: false, status: 400, clone: function () { return this; },
                    json: function () { return Promise.resolve({ error: 'Profil inconnu.' }); } };
  var r3 = await tour(unPnj, 'Une question a un PNJ sans profil.');
  REPONSE_FETCH = null;
  att('un 400 ne promet PAS de reessayer -- ce PNJ n a pas de dialogue, et ca ne changera pas',
      r3.vu.indexOf('Discussion impossible') < 0 && r3.vu.length > 0,
      JSON.stringify(r3.vu.slice(0, 70)));
  att('les deux messages de panne sont DIFFERENTS', r2.vu !== r3.vu);
  att('un refus DEFINITIF retire la boite de question -- on n invite plus a ecrire pour rien',
      __noeud('pnj-zone-question').innerHTML.indexOf('ne tient pas de conversation') >= 0,
      JSON.stringify(__noeud('pnj-zone-question').innerHTML.slice(0, 60)));
  att('aucun des deux ne nomme un detail technique',
      !/HTTP|DeepSeek|400|502|profil|API|token/i.test(r2.vu + ' ' + r3.vu));
  // ET L'INVERSE, qui est la moitie qui compte : une panne PASSAGERE ne doit rien retirer, sinon
  // un reseau qui hoquette ferait disparaitre la conversation d'un PNJ qui parle tres bien.
  __noeud('pnj-zone-question').innerHTML = '<textarea id="pnj-question-libre"></textarea>';
  REPONSE_FETCH = { ok: false, status: 502, clone: function () { return this; },
                    json: function () { return Promise.resolve({ error: 'x' }); } };
  await tour(unPnj, 'Une question pendant une panne passagere.');
  REPONSE_FETCH = null;
  att('une panne PASSAGERE laisse la boite de question en place',
      __noeud('pnj-zone-question').innerHTML.indexOf('pnj-question-libre') >= 0);

  print('');
  print('7. LE MIROIR DES OBJECTIFS DE LA VISITE D ACCUEIL');
  // LE SIXIEME CANAL DONNE A JEREMY L'ETAPE DE LA VISITE, et la PHRASE de consigne est un miroir
  // de QUETE_ACCUEIL_OBJECTIFS. Deux copies d'un texte divergent toujours : celle-ci est
  // confrontee ici, clef par clef et phrase par phrase, sans evaluer les fichiers -- une
  // comparaison de texte ne peut pas etre trompee par un ordre de chargement.
  function tableObjectifs(fichier, declaration) {
    var src = lire(fichier);
    var i = src.indexOf(declaration);
    if (i < 0) return null;
    var j = src.indexOf('\n};', i);
    var bloc = src.slice(i, j);
    var table = {};
    bloc.split('\n').forEach(function (l) {
      if (/^\s*\/\//.test(l)) return;
      var m = l.match(/^\s*([a-z_]+):\s*"(.*)",?\s*$/);
      if (m) table[m[1]] = m[2];
    });
    return table;
  }
  var cote = tableObjectifs('plateau-quete-accueil.js', 'const QUETE_ACCUEIL_OBJECTIFS = {');
  var serveur = tableObjectifs('api/_pnj-profils.js', 'const QUETE_ACCUEIL_OBJECTIFS = {');
  att('les deux tables sont lisibles', !!cote && !!serveur,
      'client=' + (cote ? Object.keys(cote).length : 'nul')
      + ' serveur=' + (serveur ? Object.keys(serveur).length : 'nul'));
  if (cote && serveur) {
    var kc = Object.keys(cote).sort(), ks = Object.keys(serveur).sort();
    att('  les memes etapes, dans les deux tables', kc.join(',') === ks.join(','),
        'client ' + kc.length + ' / serveur ' + ks.length);
    var divergentes = kc.filter(function (k) { return cote[k] !== serveur[k]; });
    att('  et la MEME phrase pour chacune', divergentes.length === 0, divergentes.join(', '));
  }

  print('');
  print('8. LE SIXIEME CANAL N APPARTIENT QU A JEREMY');
  var chat = lire('api/chat.js');
  att('la porte quete_accueil_contexte est declaree sans parametre',
      /quete_accueil_contexte:\s*\(\)\s*=>\s*\(\{\}\)/.test(chat));
  att('elle n est demandee que pour le profil jeremy',
      /VISITE_D_ACCUEIL\s*=\s*'jeremy'/.test(chat)
      && /profilId === VISITE_D_ACCUEIL/.test(chat));
  att('elle part avec les autres lectures, pas en serie apres elles',
      chat.indexOf('etapeDeLaVisite(req.body.profil, utilisateur.jeton)') > 0
      && chat.indexOf('await Promise.all([') < chat.indexOf('etapeDeLaVisite(req.body.profil'));
  var profils = lire('api/_pnj-profils.js');
  att('le prompt systeme sait placer ce bloc', /\.\.\.\(vis \? \[vis, ''\] : \[\]\),/.test(profils));

  print('');
  print('9. LE PROMPT DE JEREMY EST REELLEMENT ASSEMBLE, AVEC L ETAPE');
  // C'EST LA MESURE QUI COMPTE POUR L'ONBOARDING : le prompt doit porter la personnalite portee
  // le 13 octobre ET la consigne de l'etape en cours. Le serveur ne peut pas etre interroge ici
  // -- ce banc ne touche pas au reseau -- mais l'ASSEMBLAGE, lui, est le vrai code serveur.
  var pJeremy = __prompt('jeremy', 'fr', null, null, null, null, null,
                         { ok: true, etape: 'attente_hotel', visite_en_cours: true });
  att('le prompt de Jeremy existe', typeof pJeremy === 'string' && pJeremy.length > 200);
  att('  il le nomme et dit son role de guide',
      /Jeremy/.test(pJeremy) && /faire visiter la ville/.test(pJeremy));
  att('  il impose le vouvoiement, comme le texte d origine',
      /vouvoies TOUJOURS le joueur, sans exception/.test(pJeremy));
  att('  il lui interdit de dire ou l on se trouve',
      /TU NE DIS JAMAIS OU VOUS VOUS TROUVEZ/.test(pJeremy));
  att('  il porte l ETAPE en cours et la consigne exacte de cette etape',
      /attente_hotel/.test(pJeremy)
      && pJeremy.indexOf("Rendez-vous à l'hôtel-restaurant.") >= 0);
  att('  et il lui interdit d inventer une autre destination',
      /sans inventer une autre consigne ni une autre destination/.test(pJeremy));

  var pFini = __prompt('jeremy', 'fr', null, null, null, null, null,
                       { ok: true, etape: 'carriere_terminee', visite_en_cours: false });
  att('la visite terminee est DITE, et il ne guide plus',
      /elle est terminee/.test(pFini) && !/Rendez-vous/.test(pFini));

  // AUCUN AUTRE PNJ NE RECOIT CE BLOC, meme si on le lui passait : c'est chat.js qui ne le
  // demande pas, et l'epreuve du chapitre 8 le verifie. Ici on mesure l'autre moitie -- un PNJ
  // ordinaire assemble un prompt qui ne parle pas de visite d'accueil.
  var pMarco = __prompt('marco_barman', 'fr', null, null, null, null, null, null);
  att('un PNJ ordinaire n a aucun bloc de visite d accueil',
      typeof pMarco === 'string' && !/OU EN EST LA VISITE/.test(pMarco));
  att('et Maxence porte sa consigne de brievete d origine',
      /1 A 2 PHRASES MAXIMUM/.test(__prompt('maxence_monfils', 'fr', null, null, null, null, null, null)));

  print('');
  if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
  else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
})();
