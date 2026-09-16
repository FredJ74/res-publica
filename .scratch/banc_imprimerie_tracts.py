#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC — IMPRIMERIE : « Imprimer des tracts electoraux » (16 septembre 2026)

Charge les VRAIS modules du jeu (plateau-communication.js, plateau-politique.js) dans JavaScriptCore
avec un DOM strict, et clique reellement sur le parcours. Prouve :
  - AVANT/APRES sur le cas reel qui a motive le chantier (candidature en phase « candidatures ») ;
  - ciblage libre (non-candidat, soi-meme, PNJ candidat), POUR comme CONTRE ;
  - nombre de lots explicite, jamais le maximum par defaut, borne par bois ET PA ET fonds ;
  - atomicite cote client : un refus serveur ne cree aucun tract ;
  - empilement (POUR/CONTRE separes, lots historiques epingles non absorbes) ;
  - distribution : un tract sans scrutin epingle reste correctement filtre par la cible.
"""
import json, subprocess, os, sys

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

HARNAIS = r"""
// ---------- DOM STRICT : un element n'existe que s'il a ete cree ----------
var ELEMENTS = {};
function creerElement(tag) {
  var el = {
    tagName: (tag || 'div').toUpperCase(), _html: '', value: '', textContent: '',
    style: { cssText: '' }, children: [],
    classList: {
      _c: {},
      add: function (c) { this._c[c] = true; },
      remove: function (c) { delete this._c[c]; },
      contains: function (c) { return !!this._c[c]; },
      toggle: function (c, f) { if (f === undefined) { if (this._c[c]) delete this._c[c]; else this._c[c] = true; } else if (f) this._c[c] = true; else delete this._c[c]; }
    }
  };
  Object.defineProperty(el, 'innerHTML', {
    get: function () { return el._html; },
    // Ecrire du HTML CREE les elements qu'il declare (id="...") -- exactement comme un navigateur.
    set: function (v) {
      el._html = String(v);
      var re = /id="([^"]+)"/g, m;
      while ((m = re.exec(el._html)) !== null) {
        if (!ELEMENTS[m[1]]) ELEMENTS[m[1]] = creerElement('div');
      }
      // Valeur par defaut d'un <select> = son option selected, sinon la PREMIERE option.
      var reSel = /<select id="([^"]+)"[\s\S]*?<\/select>/g, ms;
      while ((ms = reSel.exec(el._html)) !== null) {
        var bloc = ms[0], id = ms[1];
        var sel = /<option value="([^"]*)" selected>/.exec(bloc);
        if (!sel) sel = /<option value="([^"]*)"[^>]*\sselected/.exec(bloc);
        var prem = /<option value="([^"]*)"/.exec(bloc);
        var v = sel ? sel[1] : (prem ? prem[1] : '');
        if (ELEMENTS[id]) ELEMENTS[id].value = v;
      }
    }
  });
  return el;
}
var document = {
  getElementById: function (id) { return ELEMENTS[id] || null; },
  createElement: function (t) { return creerElement(t); },
  querySelector: function () { return null; },
  querySelectorAll: function () { return []; },
  body: creerElement('body'),
  addEventListener: function () {}
};
['postes-modal-title', 'postes-body', 'modal-postes'].forEach(function (id) { ELEMENTS[id] = creerElement('div'); });

var window = this;
var console = { log: function () {}, error: function () {}, warn: function () {} };
var localStorage = { _d: {}, getItem: function (k) { return this._d[k] === undefined ? null : this._d[k]; },
                     setItem: function (k, v) { this._d[k] = String(v); }, removeItem: function (k) { delete this._d[k]; } };
var navigator = { userAgent: 'jsc', language: 'fr-FR' };
var fetch = function () { return Promise.reject(new Error('reseau interdit dans le banc')); };
var setTimeout = function (f) { try { f(); } catch (e) {} return 0; };
var clearTimeout = function () {};
var setInterval = function () { return 0; };
var clearInterval = function () {};
var alert = function () {};
var Intl = this.Intl;

// ---------- TRACES ----------
var TOASTS = [], JOURNAL = [], SAUVEGARDES = 0;
function showToast(t, m, ok) { TOASTS.push({ titre: t, msg: m || '', ok: !!ok }); }
function addJournalEntry(t) { JOURNAL.push(t); }
function updateUI() {}
function renderInventory() {}
function sauvegarderPersonnageImmediat() { SAUVEGARDES++; }
function renderEmployesPanel() {}
function checkDetection() {}
function deduireCoutOrdre() { return Promise.resolve(true); }
function nomImprimeurLocal() { return 'Gustave Encre'; }

// ---------- ETAT DU JEU ----------
var TEST_MODE = false;
var COUNTRIES = { republic: { cur: 'FR' } };
var WORLD = { republic: { capitale: { name: 'Luthecia' }, montrouge: { name: 'Montrouge' }, portmarie: { name: 'Port-Sainte-Marie' } } };
var PHASES_ELECTORALES = { CANDIDATURES: 'candidatures', CAMPAGNE: 'campagne', VOTE: 'vote',
                           SECOND_TOUR: 'second_tour', VOTE2: 'vote2',
                           CAMPAGNE_3E_SIEGE: 'campagne_3e', VOTE3E_SIEGE: 'vote3e', RESULTATS: 'resultats' };
var LIEUX_PRESIDENTIELLE = ['capitale', 'montrouge', 'portmarie'];
var CYCLES_ELECTORAUX = { republic: {} };
var PHASE_COURANTE = {};                 // cle scrutin -> phase, pilote par le banc
function getCleCycle(posteId, city) { return city ? posteId + '_' + city : posteId; }
function getPhaseActuelle(country, posteId, city) { return PHASE_COURANTE[getCleCycle(posteId, city)] || 'candidatures'; }
function ajouterEffetTractLocal() {}
function getFondsDisponiblesOrdinaires() { return (state.liquide || 0) + ((state.comptesBancaires && state.comptesBancaires.nationale && state.comptesBancaires.nationale.solde) || 0); }

var state = {};
function reinitEtat() {
  state.country = 'republic'; state.currentCity = 'capitale'; state.currentBuilding = 'la-tribune';
  state.char = { name: 'Arnie Tairien' };
  state.pa = 10; state.arg = 5000; state.liquide = 5000;
  state.comptesBancaires = { nationale: { solde: 0 } };
  state.inventory = []; state.contacts = []; state.pjSimules = [];
  TOASTS = []; JOURNAL = []; SAUVEGARDES = 0;
  CYCLES_ELECTORAUX.republic = {}; PHASE_COURANTE = {};
  STOCK_BOIS = 10; RPC_REFUS = null; RPC_APPELS = [];
  ANNUAIRE = [ { name: 'Arnie Tairien', country: 'republic' },
               { name: 'Gustave Encre', country: 'republic' },
               { name: 'Olga Krasnova',  country: 'soviet' } ];
}

// ---------- SERVEUR SIMULE ----------
var STOCK_BOIS = 10, RPC_REFUS = null, RPC_APPELS = [], ANNUAIRE = [];
function sbGetBatimentEtat() { return Promise.resolve({ imprimerie: { stockBois: STOCK_BOIS } }); }
function sbBatimentMouvementCaisse() { return Promise.resolve({ ok: true }); }
function sbListPersonnages() { return Promise.resolve(ANNUAIRE.slice()); }
function sbSavePersonnage() { return Promise.resolve(true); }
function sbRpc(nom, params) {
  RPC_APPELS.push({ nom: nom, params: params });
  if (nom !== 'imprimerie_produire_tracts') return Promise.resolve(null);
  if (RPC_REFUS) return Promise.resolve([{ ok: false, raison: RPC_REFUS, stock: STOCK_BOIS, requis: params.p_lots, cout: 150 * params.p_lots }]);
  var lots = params.p_lots;
  // Le vrai serveur revalide tout : on reproduit ses trois bornes.
  if (lots * 1 > STOCK_BOIS) return Promise.resolve([{ ok: false, raison: 'bois_insuffisant', stock: STOCK_BOIS }]);
  if (lots > state.pa) return Promise.resolve([{ ok: false, raison: 'pa_insuffisants', requis: lots }]);
  if (lots * 150 > getFondsDisponiblesOrdinaires()) return Promise.resolve([{ ok: false, raison: 'fonds_insuffisants', cout: lots * 150 }]);
  STOCK_BOIS -= lots;
  var net = lots * 150 - lots * 50;
  state.pa -= lots; state.liquide -= net; state.arg -= net;
  return Promise.resolve([{ ok: true, pa: state.pa, arg: state.arg, liquide: state.liquide,
                            cout: lots * 150, salaire: lots * 50, paConsommes: lots, bois: lots }]);
}
function escapeHtmlText(s) {
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}
"""

CHARGEMENT = r"""
// Les VRAIS modules du jeu. On n'extrait que les fonctions utiles : charger le fichier entier
// entrainerait des dependances hors sujet (forum, navigation...). Le decoupage est textuel et
// verifie : si une fonction attendue manque, le banc echoue bruyamment.
function extraireFonctions(src, noms) {
  var out = '';
  noms.forEach(function (n) {
    var i = src.indexOf('\nfunction ' + n + '(');
    if (i < 0) i = src.indexOf('\nasync function ' + n + '(');
    if (i < 0) throw new Error('FONCTION ABSENTE DU SOURCE : ' + n);
    var j = src.indexOf('\n}', i);
    if (j < 0) throw new Error('FIN INTROUVABLE : ' + n);
    out += src.slice(i, j + 2) + '\n';
  });
  return out;
}
var SRC_COM = readFile('__RACINE__/plateau-communication.js');
var SRC_POL = readFile('__RACINE__/plateau-politique.js');

// Constantes du module communication, relues telles quelles dans le source (jamais recopiees).
var DECLARATIONS = '';
['PRIX_LOT_TRACTS', 'BOIS_PAR_LOT_TRACTS', 'TRACTS_PAR_LOT', 'SALAIRE_LOT_TRACTS', 'POSTES_TRACTS_ELECTORAUX'].forEach(function (c) {
  var src = (c === 'POSTES_TRACTS_ELECTORAUX') ? SRC_POL : SRC_COM;
  var m = new RegExp('\\nconst ' + c + ' = ([^;]+);').exec(src);
  if (!m) throw new Error('CONSTANTE ABSENTE : ' + c);
  DECLARATIONS += 'var ' + c + ' = ' + m[1] + ';\n';
});
eval(DECLARATIONS);   // eval au niveau global : sinon les var restent dans le scope du callback

eval(extraireFonctions(SRC_COM, ['selectTractType', 'atelierImprimerieCourant', 'stockBoisAtelier',
     'capaciteImpressionTracts', 'produireLotsTracts', 'messageStockBoisInsuffisant',
     'prixLotTractsAtelier', 'listerCiblesTractsElectoraux', 'echapperTexteTract',
     'ouvrirModalImprimerTractsElectoraux', 'confirmerImprimerTractsElectoraux']));
eval(extraireFonctions(SRC_POL, ['estDimancheParis', 'libelleScrutinTract',
     'scrutinsDistribuablesPourTract', 'tractsElectorauxDistribuablesIci',
     'listerCandidatsElectorauxActifs']));
"""

TESTS = r"""
var RESULTATS = [];
function verifier(nom, condition, detail) {
  RESULTATS.push({ nom: nom, ok: !!condition, detail: detail === undefined ? '' : String(detail) });
}
function corpsModal() { return ELEMENTS['postes-body'].innerHTML; }
function optionsCible() {
  var m = /<select id="tract-electoral-cible"[\s\S]*?<\/select>/.exec(corpsModal());
  if (!m) return [];
  var re = /<option value="([^"]*)"[^>]*>([^<]*)</g, o, out = [];
  while ((o = re.exec(m[0])) !== null) out.push({ value: o[1], label: o[2] });
  return out;
}
function optionsLots() {
  var m = /<select id="tract-electoral-lots"[\s\S]*?<\/select>/.exec(corpsModal());
  if (!m) return [];
  var re = /<option value="([^"]*)"/g, o, out = [];
  while ((o = re.exec(m[0])) !== null) out.push(o[1]);
  return out;
}
function poserCycle(cle, posteId, city, phase, candidats, extra) {
  var c = { posteId: posteId, city: city || null, candidats: candidats.map(function (n) { return { nom: n, voix: 0 }; }),
            votes: {}, votesPNJ: {}, resultatsTraites: false };
  if (extra) for (var k in extra) c[k] = extra[k];
  CYCLES_ELECTORAUX.republic[cle] = c;
  PHASE_COURANTE[cle] = phase;
}

function lancer() {
  var chaine = Promise.resolve();

  // =========================================================================
  // 1. LE CAS REEL DU CHANTIER : candidature deposee, phase « candidatures ».
  //    AVANT : « Aucun candidat en campagne actuellement », impression impossible.
  // =========================================================================
  chaine = chaine.then(function () {
    reinitEtat();
    poserCycle('president', 'president', null, PHASES_ELECTORALES.CANDIDATURES, ['Arnie Tairien']);
    // Reproduction litterale de l'ancienne condition d'ouverture (ancien code) :
    var ancienneListe = listerCandidatsElectorauxActifs();
    verifier('1a. AVANT : l\'ancien filtre ne rend aucune cible en phase candidatures',
             ancienneListe.length === 0, 'candidats actifs = ' + ancienneListe.length);
    return ouvrirModalImprimerTractsElectoraux(1, 150);
  }).then(function () {
    verifier('1b. APRES : le modal ne dit plus « aucun candidat »',
             corpsModal().indexOf('Aucun candidat en campagne') < 0);
    var opts = optionsCible();
    verifier('1c. APRES : la cible candidate en phase candidatures est proposee',
             opts.some(function (o) { return o.value === 'Arnie Tairien'; }), JSON.stringify(opts.map(function (o) { return o.label; })));
    verifier('1d. APRES : le bouton Commander est present', corpsModal().indexOf('confirmerImprimerTractsElectoraux(') >= 0);
  });

  // =========================================================================
  // 2. CIBLAGE LIBRE
  // =========================================================================
  chaine = chaine.then(function () {
    reinitEtat();                            // aucun cycle du tout
    return ouvrirModalImprimerTractsElectoraux(1, 150);
  }).then(function () {
    var opts = optionsCible();
    verifier('2a. Sans aucune election ouverte, l\'imprimerie reste utilisable', opts.length >= 3, 'cibles = ' + opts.length);
    verifier('2b. Soi-meme est ciblable', opts.some(function (o) { return o.value === 'Arnie Tairien'; }));
    verifier('2c. Soi-meme est pre-selectionne', ELEMENTS['tract-electoral-cible'].value === 'Arnie Tairien',
             ELEMENTS['tract-electoral-cible'].value);
    verifier('2d. Un non-candidat est ciblable', opts.some(function (o) { return o.value === 'Gustave Encre'; }));
    verifier('2e. Un personnage d\'un autre empire est ciblable et signale',
             opts.some(function (o) { return o.value === 'Olga Krasnova' && o.label.indexOf('Sovarka') >= 0; }));
  });

  chaine = chaine.then(function () {
    reinitEtat();
    // Un PNJ candidat : present dans un cycle, absent de l'annuaire des PJ.
    poserCycle('maire_capitale', 'maire', 'capitale', PHASES_ELECTORALES.CAMPAGNE, ['Hubert Pommier (PNJ)']);
    return ouvrirModalImprimerTractsElectoraux(1, 150);
  }).then(function () {
    var opts = optionsCible();
    verifier('2f. NON-REGRESSION : un PNJ candidat reste ciblable',
             opts.some(function (o) { return o.value === 'Hubert Pommier (PNJ)'; }), JSON.stringify(opts.map(function (o) { return o.value; })));
    verifier('2g. La mention « en campagne » est affichee pour lui',
             opts.some(function (o) { return o.value === 'Hubert Pommier (PNJ)' && o.label.indexOf('en campagne') >= 0; }));
    verifier('2h. Elle n\'est PAS affichee pour un non-candidat',
             opts.some(function (o) { return o.value === 'Gustave Encre' && o.label.indexOf('en campagne') < 0; }));
  });

  // =========================================================================
  // 3. NOMBRE DE LOTS : explicite, jamais le maximum, trois bornes
  // =========================================================================
  chaine = chaine.then(function () {
    reinitEtat(); STOCK_BOIS = 7; state.pa = 10; state.liquide = 100000; state.arg = 100000;
    return ouvrirModalImprimerTractsElectoraux(1, 150);
  }).then(function () {
    verifier('3a. Borne par le BOIS (7 bois, 10 PA, fonds larges) -> 7 lots', optionsLots().length === 7, optionsLots().join(','));
    verifier('3b. Le defaut est 1 lot, jamais le maximum', ELEMENTS['tract-electoral-lots'].value === '1',
             ELEMENTS['tract-electoral-lots'].value);
    verifier('3c. Le facteur limitant annonce est le bois', corpsModal().indexOf('limité par le stock de bois') >= 0);
  });
  chaine = chaine.then(function () {
    reinitEtat(); STOCK_BOIS = 10; state.pa = 3; state.liquide = 100000; state.arg = 100000;
    return ouvrirModalImprimerTractsElectoraux(1, 150);
  }).then(function () {
    verifier('3d. Borne par les PA (3 PA) -> 3 lots', optionsLots().length === 3, optionsLots().join(','));
    verifier('3e. Le facteur limitant annonce est les PA', corpsModal().indexOf('limité par vos PA') >= 0);
  });
  chaine = chaine.then(function () {
    reinitEtat(); STOCK_BOIS = 10; state.pa = 10; state.liquide = 320; state.arg = 320;
    return ouvrirModalImprimerTractsElectoraux(1, 150);
  }).then(function () {
    verifier('3f. Borne par les FONDS (320 FR / 150) -> 2 lots', optionsLots().length === 2, optionsLots().join(','));
    verifier('3g. Le facteur limitant annonce est les fonds', corpsModal().indexOf('limité par vos fonds') >= 0);
  });
  chaine = chaine.then(function () {
    reinitEtat(); STOCK_BOIS = 10; state.pa = 10; state.liquide = 100; state.arg = 100;
    return ouvrirModalImprimerTractsElectoraux(1, 150);
  }).then(function () {
    verifier('3h. Fonds insuffisants pour un seul lot : commande fermee, message explicite',
             corpsModal().indexOf('confirmerImprimerTractsElectoraux(') < 0 && corpsModal().indexOf('150 FR disponibles') >= 0);
  });
  chaine = chaine.then(function () {
    reinitEtat(); STOCK_BOIS = 0;
    return ouvrirModalImprimerTractsElectoraux(1, 150);
  }).then(function () {
    verifier('3i. Bois epuise : commande fermee, message de vente de matieres',
             corpsModal().indexOf('confirmerImprimerTractsElectoraux(') < 0 && corpsModal().indexOf('matières premières') >= 0);
  });

  // =========================================================================
  // 4. PRODUCTION REELLE : economie inchangee, POUR/CONTRE, empilement
  // =========================================================================
  chaine = chaine.then(function () {
    reinitEtat(); STOCK_BOIS = 10; state.pa = 10; state.liquide = 5000; state.arg = 5000;
    return ouvrirModalImprimerTractsElectoraux(1, 150);
  }).then(function () {
    ELEMENTS['tract-electoral-cible'].value = 'Gustave Encre';
    ELEMENTS['tract-electoral-lots'].value = '3';
    selectTractType('pour');
    return confirmerImprimerTractsElectoraux(1, 150);
  }).then(function () {
    var t = state.inventory.filter(function (i) { return i.type === 'tract'; });
    verifier('4a. 3 lots -> 30 tracts dans un lot unique', t.length === 1 && t[0].quantite === 30,
             JSON.stringify(t.map(function (x) { return x.quantite; })));
    verifier('4b. Economie : 3 x 150 debites, 3 x 50 de salaire -> -300 net', state.liquide === 4700, state.liquide);
    verifier('4c. 3 PA consommes', state.pa === 7, state.pa);
    verifier('4d. 3 bois sortis du stock de l\'atelier', STOCK_BOIS === 7, STOCK_BOIS);
    verifier('4e. Le lot porte cible + orientation', t[0].cible === 'Gustave Encre' && t[0].tractType === 'pour');
    verifier('4f. Le lot n\'est PAS epingle a un scrutin',
             t[0].electionPosteId === undefined && t[0].electionCity === undefined, JSON.stringify(t[0]));
    verifier('4g. Sauvegarde immediate declenchee', SAUVEGARDES === 1, SAUVEGARDES);
    verifier('4h. Un seul appel serveur, avec le nombre de lots demande',
             RPC_APPELS.length === 1 && RPC_APPELS[0].params.p_lots === 3, JSON.stringify(RPC_APPELS));
  });

  chaine = chaine.then(function () {
    // Meme cible, orientation opposee : deux lots distincts.
    ELEMENTS['tract-electoral-cible'].value = 'Gustave Encre';
    ELEMENTS['tract-electoral-lots'].value = '1';
    selectTractType('contre');
    return confirmerImprimerTractsElectoraux(1, 150);
  }).then(function () {
    var t = state.inventory.filter(function (i) { return i.type === 'tract'; });
    verifier('4i. POUR et CONTRE la meme cible ne fusionnent pas', t.length === 2, t.length);
    var contre = t.filter(function (i) { return i.tractType === 'contre'; })[0];
    verifier('4j. Le lot CONTRE porte bien 10 tracts', contre && contre.quantite === 10);
    verifier('4k. Le nom du lot dit CONTRE', contre && contre.name.indexOf('CONTRE Gustave Encre') >= 0, contre && contre.name);
  });

  chaine = chaine.then(function () {
    // Meme cible, meme orientation : empilement.
    ELEMENTS['tract-electoral-cible'].value = 'Gustave Encre';
    ELEMENTS['tract-electoral-lots'].value = '2';
    selectTractType('pour');
    return confirmerImprimerTractsElectoraux(1, 150);
  }).then(function () {
    var pour = state.inventory.filter(function (i) { return i.type === 'tract' && i.tractType === 'pour'; });
    verifier('4l. Meme cible + meme orientation : un seul lot, 30 + 20 = 50',
             pour.length === 1 && pour[0].quantite === 50, JSON.stringify(pour.map(function (x) { return x.quantite; })));
  });

  chaine = chaine.then(function () {
    // Lot HISTORIQUE epingle a un scrutin : ne doit pas etre absorbe.
    reinitEtat(); STOCK_BOIS = 10;
    state.inventory.push({ type: 'tract', name: 'Tracts POUR Gustave Encre', icon: 'ti-file-description',
                           tractType: 'pour', cible: 'Gustave Encre', quantite: 10, legal: true,
                           electionPosteId: 'maire', electionCity: 'portmarie' });
    return ouvrirModalImprimerTractsElectoraux(1, 150);
  }).then(function () {
    ELEMENTS['tract-electoral-cible'].value = 'Gustave Encre';
    ELEMENTS['tract-electoral-lots'].value = '1';
    selectTractType('pour');
    return confirmerImprimerTractsElectoraux(1, 150);
  }).then(function () {
    var t = state.inventory.filter(function (i) { return i.type === 'tract'; });
    verifier('4m. Un lot historique epingle n\'est pas absorbe (2 lots distincts)', t.length === 2, t.length);
    var ancien = t.filter(function (i) { return i.electionPosteId === 'maire'; })[0];
    verifier('4n. Le lot historique garde sa restriction de scrutin intacte',
             ancien && ancien.quantite === 10 && ancien.electionCity === 'portmarie', JSON.stringify(ancien));
  });

  // =========================================================================
  // 5. ATOMICITE : un refus serveur ne cree aucun tract
  // =========================================================================
  chaine = chaine.then(function () {
    reinitEtat(); STOCK_BOIS = 10;
    return ouvrirModalImprimerTractsElectoraux(1, 150);
  }).then(function () {
    RPC_REFUS = 'fonds_insuffisants';
    ELEMENTS['tract-electoral-cible'].value = 'Gustave Encre';
    ELEMENTS['tract-electoral-lots'].value = '2';
    return confirmerImprimerTractsElectoraux(1, 150);
  }).then(function () {
    verifier('5a. Refus serveur : aucun tract en inventaire', state.inventory.length === 0, JSON.stringify(state.inventory));
    verifier('5b. Refus serveur : aucun PA consomme', state.pa === 10, state.pa);
    verifier('5c. Refus serveur : aucun debit', state.liquide === 5000, state.liquide);
    verifier('5d. Refus serveur : aucune sauvegarde', SAUVEGARDES === 0, SAUVEGARDES);
    verifier('5e. Refus serveur : le joueur est prevenu',
             TOASTS.some(function (t) { return t.titre.indexOf('Fonds') >= 0; }), JSON.stringify(TOASTS));
    RPC_REFUS = null;
  });
  chaine = chaine.then(function () {
    // Le serveur revalide : demander plus que le bois reel est refuse meme si le client a ete force.
    reinitEtat(); STOCK_BOIS = 2;
    return ouvrirModalImprimerTractsElectoraux(1, 150);
  }).then(function () {
    ELEMENTS['tract-electoral-cible'].value = 'Gustave Encre';
    ELEMENTS['tract-electoral-lots'].value = '9';   // client falsifie : au-dela du maximum propose
    return confirmerImprimerTractsElectoraux(1, 150);
  }).then(function () {
    verifier('5f. Client falsifie (9 lots pour 2 bois) : le serveur refuse, rien n\'est cree',
             state.inventory.length === 0 && state.pa === 10 && STOCK_BOIS === 2,
             'inv=' + state.inventory.length + ' pa=' + state.pa + ' bois=' + STOCK_BOIS);
  });

  // =========================================================================
  // 6. DISTRIBUTION : le filtrage electoral est bien la ou il doit etre
  // =========================================================================
  chaine = chaine.then(function () {
    reinitEtat();
    // Le banc ne tourne pas forcement un dimanche : on neutralise UNIQUEMENT la garde calendaire
    // (regle anterieure a ce chantier, testee ailleurs) pour que les assertions ci-dessous portent
    // reellement sur le filtrage par la CIBLE, qui est ce que ce chantier deplace.
    var vraiEstDimanche = estDimancheParis;
    estDimancheParis = function () { return true; };

    var tractLibre = { type: 'tract', tractType: 'pour', cible: 'Gustave Encre', quantite: 10, legal: true };
    state.inventory.push(tractLibre);
    // Scrutin ouvert au vote, ici meme, mais la cible n'y est PAS candidate.
    poserCycle('maire_capitale', 'maire', 'capitale', PHASES_ELECTORALES.VOTE, ['Hubert Pommier (PNJ)']);
    verifier('6a. Cible non candidate : aucun scrutin distribuable (dimanche force)',
             scrutinsDistribuablesPourTract(tractLibre).length === 0);
    verifier('6b. Ce tract n\'apparait donc pas dans les tracts utilisables ici',
             tractsElectorauxDistribuablesIci().length === 0);

    // La cible se presente : le tract imprime d'avance devient utilisable, sans rien imprimer de plus.
    CYCLES_ELECTORAUX.republic['maire_capitale'].candidats.push({ nom: 'Gustave Encre', voix: 0 });
    var scrutins2 = scrutinsDistribuablesPourTract(tractLibre);
    verifier('6c. Des que la cible se presente, le tract imprime d\'avance devient distribuable',
             scrutins2.length === 1 && scrutins2[0].posteId === 'maire' && scrutins2[0].city === 'capitale',
             JSON.stringify(scrutins2));
    verifier('6d. Il apparait alors dans les tracts utilisables ici',
             tractsElectorauxDistribuablesIci().length === 1);

    // Un lot epingle ailleurs ne doit PAS profiter de ce scrutin.
    var tractEpingle = { type: 'tract', tractType: 'pour', cible: 'Gustave Encre', quantite: 10, legal: true,
                         electionPosteId: 'maire', electionCity: 'portmarie' };
    verifier('6e. Un lot historique epingle a un autre scrutin reste exclu',
             scrutinsDistribuablesPourTract(tractEpingle).length === 0);

    // Hors de la ville du scrutin, le tract libre reste non distribuable (geographie inchangee).
    state.currentCity = 'montrouge';
    verifier('6f. Geographie inchangee : hors de la ville du scrutin, rien n\'est distribuable',
             scrutinsDistribuablesPourTract(tractLibre).length === 0);
    state.currentCity = 'capitale';

    estDimancheParis = vraiEstDimanche;
    verifier('6g. La garde calendaire reelle est bien restauree apres le test',
             estDimancheParis === vraiEstDimanche && scrutinsDistribuablesPourTract(tractLibre).length === (vraiEstDimanche() ? 1 : 0));
  });

  return chaine;
}

lancer().then(function () {
  print(JSON.stringify(RESULTATS));
}, function (e) {
  print(JSON.stringify([{ nom: 'BANC INTERROMPU : ' + e, ok: false, detail: String(e && e.stack || '') }]));
});
"""


def main():
    script = HARNAIS + CHARGEMENT.replace("__RACINE__", RACINE) + TESTS
    chemin = os.path.join(RACINE, ".scratch", "_banc_imprimerie.js")
    with open(chemin, "w") as f:
        f.write(script)
    proc = subprocess.run([JSC, chemin], capture_output=True, text=True)
    sortie = proc.stdout.strip()
    if proc.returncode != 0 or not sortie:
        print("ECHEC D'EXECUTION DU BANC")
        print(proc.stdout)
        print(proc.stderr)
        return 1
    ligne = [l for l in sortie.splitlines() if l.startswith("[")]
    if not ligne:
        print("SORTIE INATTENDUE :")
        print(sortie)
        return 1
    resultats = json.loads(ligne[-1])
    ok = sum(1 for r in resultats if r["ok"])
    print("=" * 78)
    print("BANC IMPRIMERIE — TRACTS ELECTORAUX")
    print("=" * 78)
    for r in resultats:
        marque = "  OK  " if r["ok"] else " ECHEC"
        detail = ("   [" + r["detail"] + "]") if (r["detail"] and not r["ok"]) else ""
        print("[" + marque + "] " + r["nom"] + detail)
    print("-" * 78)
    print("TOTAL : " + str(ok) + "/" + str(len(resultats)))
    return 0 if ok == len(resultats) else 1


if __name__ == "__main__":
    sys.exit(main())
