#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Banc d'execution REEL des deux points de cloture (11 septembre 2026), dans JavaScriptCore :

  A. Routage 'voter_loi' : le bouton de la loge et celui de l'hemicycle, lus tels quels dans data.js,
     sont passes a la VRAIE fonction doOrder() (plateau-router.js) exactement comme le fait le rendu
     des pieces (plateau-politique.js : doOrder(o.fn, o.pa, o.cost, label, desc, rate)).
  B. Armurerie : les deux voies du meme ordre « Acheter une arme » (achat legal avec registre / marche
     noir sans registre), armurerie PNJ puis rachetee par un PJ, avec et sans loi en vigueur. Les
     reponses d'assemblee_verifier_vente / assemblee_achat_illegal sont les REPONSES REELLES du serveur
     (capture.json).

Usage : python3 .scratch/banc_jsc_cloture.py <capture.json>
"""
import json, os, re, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'


def lire(f):
    with open(os.path.join(RACINE, f), encoding='utf-8') as fh:
        return fh.read()


def extraire(src, nom, genre='function'):
    if genre == 'function':
        m = re.search(r'^(async )?function ' + re.escape(nom) + r'\(', src, re.M)
    else:
        m = re.search(r'^const ' + re.escape(nom) + r'\s*=', src, re.M)
    if not m:
        raise SystemExit('introuvable : ' + nom)
    fin = re.compile(r'^(async function |function |const |let |var |// =====|export )', re.M)
    suite = fin.search(src, m.end())
    return src[m.start(): suite.start() if suite else len(src)].rstrip() + '\n'


def en_expression(code):
    # Une declaration de fonction dans un bloc `with` ne capture pas la portee du with : on la
    # convertit en expression (meme technique que banc_jsc_interdictions.py).
    return re.sub(r'^(async )?function (\w+)\(', lambda m: 'var %s = %sfunction %s(' % (m.group(2), m.group(1) or '', m.group(2)), code, flags=re.M)


def ordre(data, fn, label):
    m = re.search(r"\{fn:'" + fn + r"',\s*label:'" + re.escape(label) + r"'[^\n]*\}", data)
    if not m:
        raise SystemExit('ordre introuvable : %s / %s' % (fn, label))
    return m.group(0)


ROUTER, DATA, CORE = lire('plateau-router.js'), lire('data.js'), lire('plateau-core.js')
ILL, ASS = lire('plateau-actions-illegales-rumeurs.js'), lire('plateau-assemblee.js')
capture = json.load(open(sys.argv[1], encoding='utf-8'))

SOURCES = ''.join(en_expression(x) for x in [
    extraire(ROUTER, 'doOrder'), extraire(ROUTER, 'executerOrdreGenerique'), extraire(ROUTER, 'applyEffects'),
    extraire(ROUTER, 'buildResultLabel'), extraire(ROUTER, 'buildResultMsg'),
    extraire(DATA, 'ORDER_EFFECTS', 'const'), extraire(CORE, 'ACTES_ILLEGAUX', 'const'),
    extraire(ASS, 'assembleeLoiApplicable'), extraire(ASS, 'assembleeNouvelleRequete'),
    extraire(ASS, 'assembleeControlerVenteLegale'), extraire(ASS, 'assembleeSignalerAchatIllegal'),
    extraire(ILL, 'ARMES_CATALOGUE', 'const'), extraire(ILL, 'ajouterHistoriqueEntreprise'),
    extraire(ILL, 'confirmerAchatArme'), extraire(ILL, 'confirmerAchatArmeIllegal'),
]).replace('const ', 'var ')

ORDRE_LOGE = ordre(DATA, 'deliberer_loge', 'Participer aux deliberations')
ORDRE_HEMICYCLE = ordre(DATA, 'voter_loi', 'Voter une loi')
AUCUN_AUTRE_VOTER_LOI = len(re.findall(r"fn:\s*'voter_loi'", DATA))

banc = r"""
var CAPTURE = %CAPTURE%;
var ALEA = 0.5;
Math.random = function () { return ALEA; };
var journal;
function raz() { journal = { appels: [], toasts: [], debits: [], registre: 0, renseignements: 0, charges: [], signaux: [], sauvegardes: [] }; }
var SCENARIO = 'avec_lois', MODE_ILLEGAL = 'achat_illegal_detecte';
var CHARGES = { P_couteau: '[{"stackKey":null,"type":"arme","sousType":"blanche"}]', P_revolver: '[{"stackKey":null,"type":"arme","sousType":"poing"}]' };
var norm = function (o) { return JSON.stringify((o || []).map(function (x) { return { stackKey: x.stackKey || null, type: x.type || null, sousType: x.sousType || null }; })); };
var bouchons = {
  state: null, TEST_MODE: false, COUNTRIES: { republic: { cur: 'FR' } }, BUILDINGS: {}, ORDRES_BUDGET_INSTITUTION: [],
  verdictRoleOrdre: function () { return { bloque: false }; },
  showToast: function (t, m) { journal.toasts.push(t + ' | ' + (m || '')); },
  addJournalEntry: function () {}, updateUI: function () {}, advanceTime: function () {}, checkDetection: function () { journal.appels.push('checkDetection'); },
  getFondsDisponiblesOrdinaires: function () { return 1e9; },
  debiterFondsOrdinaires: function (m) { journal.debits.push({ fonds: m }); return Promise.resolve({ ok: true }); },
  deduireCoutOrdre: function (o) { journal.debits.push(o); bouchons.state.pa -= o.pa || 0; return Promise.resolve({ ok: true }); },
  chargerArmurerieLocale: function () { return Promise.resolve(bouchons._armurerie); },
  sbSaveEntreprise: function (id, d) { journal.sauvegardes.push(id + ':' + JSON.stringify(d.stockProduits) + ':caisse=' + d.caisse); return Promise.resolve(); },
  appliquerTaxeTransaction: function (p) { return Promise.resolve({ net: p }); },
  resoudreArmeAffichage: function (a) { return a; },
  sbEnregistrerVenteArme: function () { journal.registre++; return Promise.resolve([{ id: 1 }]); },
  sbEnregistrerRenseignement: function () { journal.renseignements++; return Promise.resolve({}); },
  BONUS_CARRIERE_VOL: {}, getIndiceVille: function () { return 30; }, consommerBonusBenediction: function (t) { return t; }, INDICES_NATIONAUX: {},
  addMailNotification: function (de, sujet) { journal.appels.push('mail:' + sujet); },
  tracerActionPourRumeur: function (a) { journal.appels.push('rumeur:' + a); },
  sbSavePersonnage: function () { return Promise.resolve(); }, sauvegarderPersonnageImmediat: function () {},
  rafraichirAssembleeInterdictions: function () { return Promise.resolve(); },
  sbAssembleeVerifierVente: function (objets) {
    var k = Object.keys(CHARGES).filter(function (c) { return CHARGES[c] === norm(objets); })[0];
    journal.charges.push(k || ('INATTENDUE ' + norm(objets)));
    return k ? Promise.resolve(CAPTURE[SCENARIO][k]) : Promise.reject(new Error('charge inattendue'));
  },
  sbAssembleeAchatIllegal: function (nom, circuit, ref) {
    journal.signaux.push(circuit + '/' + ref);
    return Promise.resolve(SCENARIO === 'avec_lois' ? CAPTURE[MODE_ILLEGAL] : { ok: true, interdit: false, loi: null, acheteur: null, dis: null });
  },
  document: { getElementById: function () { return { textContent: '', innerHTML: '', classList: { add: function () {}, remove: function () {} } }; } }
};
var auto = {};
var BANC = new Set(['CAPTURE', 'ALEA', 'journal', 'raz', 'SCENARIO', 'MODE_ILLEGAL', 'CHARGES', 'norm', 'bouchons', 'auto', 'bac', 'BANC', 'resultats', 'verifier', 'Math']);
var bac = new Proxy(bouchons, {
  has: function (t, k) { return typeof k === 'string' && !(k in globalThis) && !BANC.has(k); },
  get: function (t, k) {
    if (k === Symbol.unscopables) return undefined;
    if (k in t) return t[k];
    if (!auto[k]) auto[k] = function () { journal.appels.push(k); return undefined; };
    return auto[k];
  },
  set: function (t, k, v) { t[k] = v; return true; }
});
var resultats = [];
function verifier(nom, cond, detail) { resultats.push([cond ? 'OK  ' : 'ECHEC', nom, detail || '']); }

with (bac) {
%SOURCES%

  var joueur = function () {
    bouchons.state = { country: 'republic', currentCity: 'capitale', char: { name: '__TEST_JSC__', country: 'republic' },
                       pa: 10, inf: 20, arg: 1e9, liquide: 1e9, dis: 40, day: 5, hour: 12,
                       inventory: [], historiqueCrimes: [], convocations: [], recherche: [] };
  };

  var routes = async function () {
    var loge = %ORDRE_LOGE%, hemi = %ORDRE_HEMICYCLE%;
    // A1. Loge : ordre generique, 2 PA, succes garanti, +3 INF, jamais le vote de l'Assemblee.
    raz(); joueur(); bouchons.state.currentBuilding = 'loge'; bouchons.state.currentRoom = 'salle_reunion_loge';
    ALEA = 0.5;
    doOrder(loge.fn, loge.pa, loge.cost, loge.label, loge.desc || '', loge.successRate);
    verifier('A1. loge « Participer aux deliberations » : n\'ouvre PAS le vote de l\'Assemblee',
      journal.appels.indexOf('ouvrirVoterLoi') < 0, 'appels=' + JSON.stringify(journal.appels));
    verifier('A1 bis. loge : comportement propre (2 PA, succes, +3 INF)',
      bouchons.state.pa === 8 && bouchons.state.inf === 23 && journal.toasts.length === 1 && /^Succes/.test(journal.toasts[0]),
      'pa=' + bouchons.state.pa + ' inf=' + bouchons.state.inf + ' toast=' + journal.toasts[0]);
    // A2. Hemicycle : le vrai vote de l'Assemblee, sans debit ni effet generique.
    raz(); joueur(); bouchons.state.currentBuilding = 'assemblee'; bouchons.state.currentRoom = 'hemicycle';
    doOrder(hemi.fn, hemi.pa, hemi.cost, hemi.label, hemi.desc || '', hemi.successRate);
    verifier('A2. hemicycle « Voter une loi » : ouvre le vote de l\'Assemblee',
      journal.appels.indexOf('ouvrirVoterLoi') >= 0 && bouchons.state.pa === 10 && bouchons.state.inf === 20 && journal.toasts.length === 0,
      'appels=' + JSON.stringify(journal.appels) + ' pa=' + bouchons.state.pa + ' inf=' + bouchons.state.inf);
  };

  var armurerie = async function () {
    for (var proprio of ['PNJ', '__PJ_PROPRIETAIRE__']) {
      var p = proprio === 'PNJ' ? 'PNJ' : 'PJ';
      var fabrique = function () { return { id: 'armurerie-republic-capitale', proprietaire: proprio, stockProduits: { couteau: 3, revolver: 3 }, parametres: { prixVente: { couteau: 100 } }, caisse: 500, historique: [] }; };

      // B1. Arme interdite + achat LEGAL -> refus avant tout debit, rien au registre.
      SCENARIO = 'avec_lois'; raz(); joueur(); bouchons._armurerie = fabrique();
      await confirmerAchatArme('couteau');
      verifier('B1 [' + p + '] couteau interdit + achat legal -> refuse',
        bouchons.state.inventory.length === 0 && journal.debits.length === 0 && bouchons._armurerie.stockProduits.couteau === 3
        && bouchons._armurerie.caisse === 500 && journal.registre === 0 && /Vente interdite/.test(journal.toasts.join()),
        'debits=' + journal.debits.length + ' stock=' + bouchons._armurerie.stockProduits.couteau + ' registre=' + journal.registre + ' toast=' + journal.toasts[0]);

      // B2/B3/B4. Arme interdite + achat ILLEGAL reussi -> achat possible, pas de registre, et UNE SEULE
      // procedure : celle, preexistante, du marche noir (non-regression du doublon du 11/09/2026 --
      // l'achat produisait aussi une trace transaction_interdite et une convocation serveur).
      for (var mode of ['achat_illegal_detecte', 'achat_illegal_non_detecte']) {
        SCENARIO = 'avec_lois'; MODE_ILLEGAL = mode; raz(); joueur(); bouchons._armurerie = fabrique(); ALEA = 0.01;
        await confirmerAchatArmeIllegal('couteau');
        var arme = bouchons.state.inventory[0];
        var det = mode === 'achat_illegal_detecte';
        verifier('B2 [' + p + '] couteau interdit + marche noir -> achat possible',
          arme && arme.legal === false && arme.sousType === 'blanche' && bouchons._armurerie.stockProduits.couteau === 2
          && journal.debits.length === 1 && journal.debits[0].cost === 300,
          'inventaire=' + (arme && arme.name) + ' legal=' + (arme && arme.legal) + ' stock=' + bouchons._armurerie.stockProduits.couteau + ' cout=' + (journal.debits[0] && journal.debits[0].cost));
        verifier('B3 [' + p + '] marche noir -> aucune inscription au registre des armes',
          journal.registre === 0 && journal.renseignements === 0, 'registre=' + journal.registre + ' renseignements=' + journal.renseignements);
        var traces = bouchons.state.historiqueCrimes.map(function (h) { return h.acte; });
        verifier('B4 [' + p + '] UN achat = UNE trace (achat_arme_illegal), aucune qualification serveur, aucune convocation' + (det ? ' (serveur pret a detecter)' : ''),
          JSON.stringify(traces) === '["achat_arme_illegal"]' && journal.signaux.length === 0
          && bouchons.state.convocations.length === 0 && bouchons.state.dis === 40
          && journal.appels.indexOf('rumeur:achat_arme_illegal') >= 0,
          'traces=' + JSON.stringify(traces) + ' convocations=' + bouchons.state.convocations.length + ' signal=' + journal.signaux.length + ' dis=' + bouchons.state.dis);
        verifier('B5 [' + p + '] marche noir : caisse du proprietaire intacte (aucune responsabilite)',
          bouchons._armurerie.caisse === 500, 'caisse=' + bouchons._armurerie.caisse);
      }

      // B4 bis. Marche noir : l'armurier refuse et denonce (mecanisme existant) -> rien vendu, rien qualifie.
      SCENARIO = 'avec_lois'; raz(); joueur(); bouchons._armurerie = fabrique(); ALEA = 0.99;
      await confirmerAchatArmeIllegal('couteau');
      verifier('B4 bis [' + p + '] marche noir refuse par l\'armurier -> denonciation existante, aucune vente',
        bouchons.state.inventory.length === 0 && journal.debits.length === 0 && journal.signaux.length === 0 && journal.registre === 0
        && JSON.stringify(bouchons.state.convocations.map(function (c) { return c.motif; })) === '["achat_arme_illegal"]'
        && bouchons.state.historiqueCrimes.length === 0,
        'convocations=' + JSON.stringify(bouchons.state.convocations.map(function (c) { return c.motif; })));

      // B6. Sans loi : achat legal inscrit au registre ; marche noir toujours sans registre.
      SCENARIO = 'sans_loi'; raz(); joueur(); bouchons._armurerie = fabrique();
      await confirmerAchatArme('couteau');
      var leg = bouchons.state.inventory[0];
      verifier('B6 [' + p + '] sans loi : achat legal vendu et inscrit au registre',
        leg && leg.legal === true && journal.registre === 1 && bouchons._armurerie.caisse === 600, 'registre=' + journal.registre + ' caisse=' + bouchons._armurerie.caisse);
      raz(); joueur(); bouchons._armurerie = fabrique(); ALEA = 0.01;
      await confirmerAchatArmeIllegal('couteau');
      verifier('B6 bis [' + p + '] sans loi : marche noir vendu, sans registre, aucune transaction interdite',
        bouchons.state.inventory.length === 1 && journal.registre === 0
        && bouchons.state.historiqueCrimes.every(function (h) { return h.acte !== 'transaction_interdite'; }), 'registre=' + journal.registre);
    }
  };
}

(async function () {
  try { await routes(); await armurerie(); }
  catch (e) { resultats.push(['ECHEC', 'exception', String(e && e.stack || e)]); }
  resultats.forEach(function (r) { print(r[0] + ' ' + r[1] + (r[2] ? '   [' + r[2] + ']' : '')); });
  print('');
  print(resultats.length + ' test(s), ' + resultats.filter(function (r) { return r[0] !== 'OK  '; }).length + ' echec(s)');
})();
"""

js = (banc.replace('%CAPTURE%', json.dumps(capture)).replace('%SOURCES%', SOURCES)
      .replace('%ORDRE_LOGE%', ORDRE_LOGE).replace('%ORDRE_HEMICYCLE%', ORDRE_HEMICYCLE))
print("Statique : fn 'voter_loi' dans data.js = %d (l'hemicycle seul attendu)" % AUCUN_AUTRE_VOTER_LOI)
with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as fh:
    fh.write(js)
out = subprocess.run([JSC, fh.name], capture_output=True, text=True, timeout=60)
print(out.stdout + out.stderr)
sys.exit(0 if AUCUN_AUTRE_VOTER_LOI == 1 and ' 0 echec(s)' in out.stdout else 1)
