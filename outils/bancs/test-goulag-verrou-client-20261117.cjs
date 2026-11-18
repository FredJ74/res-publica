'use strict';
// Verrou d'ouverture du client du goulag (décision de Fred du 17/11/2026).
// Preuve : sans migrations (fonction serveur absente, en erreur, injoignable ou ne rendant pas
// `true`), l'écran du goulag et le juge se comportent EXACTEMENT comme sur main :
//   - aucun ordre dynamique du goulag (pièces, centres de transport des trois villes, bureau du
//     ministre de la Justice, refuge), aucun masque : les ordres actuels des cinq pièces restent ;
//   - aucune RPC du goulag au chargement, hormis la seule lecture d'ouverture ;
//   - rue de l'école de Krasnov : mêmes flèches que main ;
//   - juge : mêmes libellés, et la condamnation passe par appliquerSentence comme sur main.
// Le comportement de main est lu dans main lui-même (git show), pas recopié.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');

const R = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');

function sourceMain(f) {
  const essais = [process.env.GOULAG_REF_MAIN, 'origin/main'].filter(Boolean);
  for (const ref of essais) {
    try { return execFileSync('git', ['show', ref + ':' + f], { cwd: R, encoding: 'utf8', maxBuffer: 1 << 28, stdio: ['ignore', 'pipe', 'ignore'] }); }
    catch (_) { /* essai suivant */ }
  }
  execFileSync('git', ['fetch', '--no-tags', '--depth=1', 'origin', 'main'], { cwd: R, stdio: 'ignore' });
  return execFileSync('git', ['show', 'FETCH_HEAD:' + f], { cwd: R, encoding: 'utf8', maxBuffer: 1 << 28 });
}

// Réponses possibles du serveur à `sovarka_goulag_ouvert`.
const SERVEURS = {
  sans_transport: null,
  fonction_absente: async () => ({ etat: 'http', raison: 'transport_indisponible', http: 404, code: 'PGRST202', envoyee: true }),
  erreur_serveur: async () => ({ etat: 'http', raison: 'transport_indisponible', http: 500, code: 'XX000', envoyee: true }),
  injoignable: async () => ({ etat: 'reseau', raison: 'reseau_indisponible', http: null, code: null, envoyee: false }),
  exception: async () => { throw new Error('panne'); },
  session_perdue: async () => ({ etat: 'session_perdue', raison: 'session_perdue' }),
  faux: async () => ({ etat: 'ok', donnees: false }),
  nul: async () => ({ etat: 'ok', donnees: null }),
  chaine_true: async () => ({ etat: 'ok', donnees: 'true' }),
  objet: async () => ({ etat: 'ok', donnees: { ok: true } }),
  tableau: async () => ({ etat: 'ok', donnees: [true] }),
  verrou_en_place: async () => ({ etat: 'ok', donnees: false })
};

const MODULES_GOULAG = ['plateau-goulag-toundra.js', 'plateau-goulag-transports.js', 'plateau-goulag-refuge.js', 'plateau-goulag-ordres.js']
  .filter(f => fs.existsSync(path.join(R, f)));

function contexte(serveur, etatJoueur) {
  const appels = [];
  const ecouteurs = [];
  const ctx = {
    console, Date, Promise, JSON, Object, Array, Number, String, Math, Set, Map, URL,
    crypto: require('node:crypto').webcrypto,
    setTimeout: (f) => { f(); return 1; }, clearTimeout() {},
    state: Object.assign({ country: 'soviet', currentCity: 'qhs', currentBuilding: 'qhs-prison', currentRoom: 'entree_qhs',
      personnageChargeDepuisServeur: true, estEmprisonne: true, char: { poste: { id: 'juge' } } }, etatJoueur || {}),
    showToast: (...a) => appels.push(['toast', a[0]]),
    updateUI: () => appels.push(['updateUI']),
    sbRpcVerdict: async (fn) => { appels.push(['rpc', fn]); return { ok: true, nuits: 0 }; },
    sbLoadPersonnage: async () => {},
    document: { addEventListener: (t, f) => ecouteurs.push([t, f]), getElementById: () => null, querySelector: () => null },
    BUILDINGS: {}
  };
  if (serveur) ctx.sbTransportRpc = async (fn, p) => { appels.push(['transport', fn]); return serveur(fn, p); };
  ctx.window = ctx;
  ctx.setInterval = (f) => { Promise.resolve().then(f); return 1; };
  ctx.clearInterval = () => {};
  vm.createContext(ctx);
  vm.runInContext(lire('data.js'), ctx);
  vm.runInContext(lire('plateau-rue-centrale.js'), ctx);
  vm.runInContext(lire('plateau-goulag-ouverture.js'), ctx);
  for (const f of MODULES_GOULAG) vm.runInContext(lire(f), ctx);
  return { ctx, appels, ecouteurs };
}

const attendre = () => new Promise(r => setImmediate(r));

// Toutes les situations où un ordre du goulag pourrait apparaître.
function lieux(ctx) {
  const L = [];
  for (const piece of ['entree_qhs', 'cellules_qhs', 'cachot_disciplinaire', 'bureau_chef', 'mirador']) L.push(['qhs-prison', piece, 'qhs']);
  for (const ville of ['capitale', 'ville_a', 'ville_b']) {
    const ctxVille = vm.runInContext('WORLD.soviet[' + JSON.stringify(ville) + ']', ctx);
    const centres = Object.keys((ctxVille && ctxVille.buildingContext) || {}).filter(b => b.startsWith('centre-multinodal-'));
    assert.ok(centres.length > 0, 'centre de transport attendu à ' + ville);
    for (const b of centres) L.push([b, 'hall', ville], [b, 'quai', ville]);
  }
  L.push(['palais-gouvernement', 'bureau_min_just', 'capitale']);
  L.push(['maison-starovka', 'piece_maison', 'ville_a'], ['maison-krasnov', 'piece_maison', 'ville_b']);
  return L;
}

function ordresDynamiques(ctx) {
  const sorties = [];
  for (const [b, p, v] of lieux(ctx)) {
    for (const profil of [{ estEmprisonne: true }, { estEmprisonne: false, char: { poste: { id: 'juge' } } }, { estEmprisonne: false, char: { poste: { id: 'min_just' } } }]) {
      Object.assign(ctx.state, profil);
      for (const f of ctx.RP_ORDRES_DYNAMIQUES || []) sorties.push([b, p, v, f(b, p, v)]);
    }
  }
  return sorties;
}

for (const [nom, serveur] of Object.entries(SERVEURS)) {
  test('serveur « ' + nom + ' » : goulag fermé, aucun ordre ni masque, aucune autre RPC', async () => {
    const { ctx, appels, ecouteurs } = contexte(serveur);
    assert.equal(ctx.goulagOuvert(), false);
    assert.equal(await ctx.goulagOuvertureVerifier(), false);
    assert.equal(ctx.goulagOuvert(), false);
    assert.ok((ctx.RP_ORDRES_DYNAMIQUES || []).length >= MODULES_GOULAG.length);
    for (const [b, p, v, o] of ordresDynamiques(ctx)) assert.deepEqual(Array.from(o), [], b + '/' + p + '/' + v);
    // Reprise de session (toundra, refuge) : aucune lecture du goulag tant qu'il est fermé.
    for (const ville of ['qhs', 'ville_a', 'ville_b']) {
      ctx.state.currentCity = ville;
      for (const [t, f] of ecouteurs) if (t === 'DOMContentLoaded') f();
      for (let i = 0; i < 5; i++) await attendre();
    }
    const autres = appels.filter(a => !(a[0] === 'transport' && a[1] === 'sovarka_goulag_ouvert'));
    assert.deepEqual(autres, [], JSON.stringify(autres));
    // Rue de Krasnov : mêmes flèches qu'au chargement de main.
    assert.deepEqual(Object.keys(vm.runInContext("RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-ecole-foret'].liens", ctx)).sort(), ['arriere', 'toutDroit']);
  });
}

test('rue de l\'école de Krasnov : flèches identiques à main', () => {
  const ctx = vm.createContext({ console, state: { country: 'soviet', currentCity: 'ville_b' } });
  vm.runInContext(sourceMain('data.js'), ctx);
  vm.runInContext(sourceMain('plateau-rue-centrale.js'), ctx);
  const main = vm.runInContext("RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-ecole-foret'].liens", ctx);
  const { ctx: c2 } = contexte(SERVEURS.fonction_absente);
  assert.deepEqual(JSON.parse(JSON.stringify(vm.runInContext("RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-ecole-foret'].liens", c2))), JSON.parse(JSON.stringify(main)));
});

test('contre-épreuve : seul un `true` du serveur ouvre (boutons et flèche apparaissent)', async () => {
  const { ctx } = contexte(async () => ({ etat: 'ok', donnees: true }));
  assert.equal(await ctx.goulagOuvertureVerifier(), true);
  assert.equal(ctx.goulagOuvert(), true);
  ctx.state.estEmprisonne = true;
  const entree = (ctx.RP_ORDRES_DYNAMIQUES || []).flatMap(f => f('qhs-prison', 'entree_qhs', 'qhs'));
  assert.ok(entree.some(o => o.fn === 'goulag_depart_pied'));
  const gare = vm.runInContext("Object.keys(WORLD.soviet.ville_a.buildingContext).find(b => b.startsWith('centre-multinodal-'))", ctx);
  assert.ok((ctx.RP_ORDRES_DYNAMIQUES || []).flatMap(f => f(gare, 'hall', 'ville_a')).some(o => o.fn === 'goulag_voyager'));
  assert.equal(vm.runInContext("RUE_CENTRALE_NOEUDS.soviet['krasnov-rue-ecole-foret'].liens.droite", ctx), 'krasnov-camp-bucherons');
});

// ---- Juge de Sovarka : comparaison avec main ----
function bloc(texte, depart, fin) {
  const i = texte.indexOf(depart);
  assert.ok(i >= 0, depart);
  const j = texte.indexOf(fin, i + depart.length);
  assert.ok(j > i, fin);
  return texte.slice(i, j);
}
function juge(source, serveur) {
  const qualif = bloc(source, 'function ouvrirQualificationSentence(', '\n// LA PLAGE EST CELLE DU SERVEUR');
  const prononce = bloc(source, 'async function prononcerSentence(', '\nasync function appliquerSentence(');
  const aide = source.includes('function goulagSovarkaOuvert(') ? bloc(source, 'function goulagSovarkaOuvert(', '\nfunction ouvrirQualificationSentence(') : '';
  const trace = [];
  const elements = {};
  const el = id => (elements[id] = elements[id] || { id, textContent: '', innerHTML: '', value: '30', classList: { add: c => trace.push(['classe', id, c]) } });
  const ctx = {
    console, Promise, Number, Array, JSON, Object, String, Date,
    state: { country: 'soviet', plaintesEnCours: [{ id: 'A1', cible: 'Ivan', motif: 'vol', status: 'ouverte' }], char: { poste: { id: 'juge' } } },
    document: { getElementById: el },
    infractionsCanoniques: () => [{ id: 'vol', libelle: 'Vol', jours: 10, amende: 100 }],
    sbRpc: async (fn, p) => { trace.push(['sbRpc', fn, p]); return [{ ok: true, impose: true, jours_min: 30, jours_max: 30, jours_defaut: 30, amende_min: 0, amende_max: 0 }]; },
    sbRpcVerdict: async (fn, p) => { trace.push(['sbRpcVerdict', fn, p]); return { ok: true }; },
    appliquerSentence: async (...a) => trace.push(['appliquerSentence', a]),
    showToast: (...a) => trace.push(['toast', a]),
    sbLoadPersonnage: async () => trace.push(['relire']),
    updateUI: () => trace.push(['updateUI']),
    fermerModalPostes: () => trace.push(['fermer'])
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  if (serveur !== undefined) {
    if (serveur) ctx.sbTransportRpc = async (fn, p) => serveur(fn, p);
    vm.runInContext(lire('plateau-goulag-ouverture.js'), ctx);
  }
  vm.runInContext(aide + '\n' + qualif + '\n' + prononce + '\nthis.__q = ouvrirQualificationSentence; this.__p = prononcerSentence;', ctx);
  return { ctx, trace, elements };
}
async function scenarioJuge(source, serveur) {
  const { ctx, trace, elements } = juge(source, serveur);
  // En jeu, la lecture d'ouverture a déjà eu lieu au rendu des pièces de Sovarka.
  if (typeof ctx.goulagOuvertureVerifier === 'function') await ctx.goulagOuvertureVerifier();
  ctx.__q('A1', 'qhs', 2, 0);
  const html = elements['postes-body'].innerHTML;
  const titre = elements['postes-modal-title'].textContent;
  await ctx.__p('A1', 'qhs', 'vol', 2, 0);
  return JSON.parse(JSON.stringify({ html, titre, trace }));
}

test('juge de Sovarka, goulag fermé : même écran et même condamnation au QHS que main', async () => {
  const sourceBranche = lire('plateau-justice-economie.js');
  const sourceDeMain = sourceMain('plateau-justice-economie.js');
  const reference = await scenarioJuge(sourceDeMain, undefined);
  assert.ok(reference.html.includes('Envoi au QHS'));
  assert.ok(reference.trace.some(t => t[0] === 'appliquerSentence'));
  for (const [nom, serveur] of Object.entries(SERVEURS)) {
    const obtenu = await scenarioJuge(sourceBranche, serveur);
    assert.deepEqual(obtenu, reference, 'serveur ' + nom);
  }
  // Libellé du bouton de condamnation dans les dossiers du juge : celui de main tant que fermé.
  const ligneMain = sourceDeMain.split('\n').find(l => l.includes("ouvrirQualificationSentence(' + a + ',\\'qhs\\'"));
  const ligneBranche = sourceBranche.split('\n').find(l => l.includes("ouvrirQualificationSentence(' + a + ',\\'qhs\\'"));
  assert.ok(ligneMain && ligneBranche);
  const libelle = l => { const m = l.match(/cursor:pointer">(.*)<\/button>';$/); return m && m[1]; };
  const { ctx } = juge(sourceBranche, SERVEURS.fonction_absente);
  const evalue = vm.runInContext("'" + libelle(ligneBranche) + "'", ctx);
  assert.equal(evalue, libelle(ligneMain).includes("' + (") ? vm.runInContext("'" + libelle(ligneMain) + "'", juge(sourceDeMain, undefined).ctx) : libelle(ligneMain));
});

test('juge de Sovarka, goulag ouvert (contre-épreuve) : la RPC du goulag est appelée', async () => {
  const obtenu = await scenarioJuge(lire('plateau-justice-economie.js'), async () => ({ etat: 'ok', donnees: true }));
  assert.ok(obtenu.html.includes('Envoi au goulag'));
  assert.ok(obtenu.trace.some(t => t[0] === 'sbRpcVerdict' && t[1] === 'sovarka_goulag_juger'));
  assert.ok(!obtenu.trace.some(t => t[0] === 'appliquerSentence'));
});
