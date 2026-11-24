'use strict';
// Nationalité, domicile et élections (décisions de Fred, 18/11/2026) : écran. Le serveur est éprouvé à
// part (migrations 20261118030000 et 20261118031000, essais en transaction annulée sur Supabase).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const acorn = require('../vercel/node_modules/acorn');
const R = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');
function extraire(fichier, noms) {
  const src = lire(fichier);
  const corps = acorn.parse(src, { ecmaVersion: 'latest' }).body
    .filter(n => n.type === 'FunctionDeclaration' && noms.includes(n.id.name)).map(n => src.slice(n.start, n.end));
  assert.equal(corps.length, noms.length, fichier + ' : ' + noms.join(','));
  return corps.join('\n');
}
function ctxNat(state, langue) {
  const ctx = vm.createContext({ console, state, i18next: { language: langue || 'fr' } });
  ctx.window = ctx; ctx.globalThis = ctx;
  vm.runInContext(lire('plateau-nationalite.js'), ctx);
  return ctx;
}

test('textes : mêmes clés dans les neuf langues, aucun texte vide, variables conservées', () => {
  const ctx = ctxNat({});
  const T = ctx.RPNationaliteI18n.textes;
  const langues = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
  assert.deepEqual(Object.keys(T).sort(), langues.slice().sort());
  const cles = Object.keys(T.fr);
  for (const l of langues) {
    assert.deepEqual(Object.keys(T[l]), cles, l);
    for (const k of cles) {
      assert.ok(String(T[l][k]).trim(), l + ' ' + k);
      for (const v of (T.fr[k].match(/\{[a-z]+\}/g) || [])) assert.ok(T[l][k].includes(v), l + ' ' + k + ' ' + v);
    }
  }
  assert.equal(ctxNat({}, 'ar').texteNationalite('investirOk', { nom: 'A', ville: 'B' }).includes('A'), true);
  assert.equal(ctx.motifNationalite('investirTitre'), null, 'les libellés ne sont pas des motifs');
  assert.match(ctx.motifNationalite('investiture_requise'), /investit/);
});

test('nationalité du joueur : la fiche, jamais le pays où il se trouve', () => {
  // Dans le navigateur, `state` est un `let` global, absent de window : la fonction doit le lire quand même.
  const ctxLet = vm.createContext({ console, i18next: { language: 'fr' } }); ctxLet.window = ctxLet;
  vm.runInContext("let state = { country: 'soviet', nationalite: 'republic' };", ctxLet);
  vm.runInContext(lire('plateau-nationalite.js'), ctxLet);
  assert.equal(vm.runInContext('maNationalite()', ctxLet), 'republic', 'state déclaré par let');
  assert.equal(ctxNat({ country: 'soviet', nationalite: 'republic' }).maNationalite(), 'republic');
  assert.equal(ctxNat({ country: 'soviet' }).maNationalite(), 'soviet');
});

const CAND = extraire('plateau-politique.js', ['candidaturePossibleIci']);
test('bouton « Se porter candidat » : nationalité, présence, domicile ; pas de mairie sans investiture en Sovarka', () => {
  const essai = (state, poste, pays, ville) => {
    const ctx = ctxNat(state);
    ctx.posteEstLocal = p => p === 'maire';
    vm.runInContext(CAND, ctx);
    return ctx.candidaturePossibleIci(poste, pays, ville);
  };
  const arnie = { country: 'soviet', nationalite: 'republic', domicile: { country: 'republic', city: 'capitale' }, currentCity: 'ville_b' };
  assert.equal(essai(arnie, 'president', 'republic'), false, 'à l\'étranger');
  assert.equal(essai(arnie, 'president', 'soviet'), false, 'pays étranger');
  const chezLui = { country: 'republic', nationalite: 'republic', domicile: { country: 'republic', city: 'capitale' }, currentCity: 'capitale' };
  assert.equal(essai(chezLui, 'president', 'republic'), true);
  assert.equal(essai(chezLui, 'maire', 'republic', 'capitale'), true);
  assert.equal(essai(chezLui, 'maire', 'republic', 'ville_a'), false, 'domicile ailleurs');
  const sov = { country: 'soviet', nationalite: 'soviet', domicile: { country: 'soviet', city: 'ville_a' }, currentCity: 'ville_a' };
  assert.equal(essai(sov, 'maire', 'soviet', 'ville_a'), false, 'investiture par le parti');
  assert.equal(essai(sov, 'president', 'soviet'), true, 'le serveur vérifie ensuite le chef de parti');
  const etranger = { country: 'republic', nationalite: 'soviet', domicile: { country: 'republic', city: 'ville_a' }, currentCity: 'ville_a' };
  assert.equal(essai(etranger, 'maire', 'republic', 'ville_a'), false, 'un étranger domicilié vote mais ne se présente pas');
});

test('vote : même règle que election_voter, vérifiée avant l\'appel au serveur', () => {
  const src = extraire('plateau-politique.js', ['voterPour']);
  assert.match(src, /state\.country !== country\) \? 'hors_de_son_pays'/);
  assert.match(src, /'non_domicilie'/);
  assert.match(src, /'nationalite_requise'/);
  const ctx = ctxNat({ char: { name: 'Arnie' }, country: 'soviet', nationalite: 'republic', domicile: { country: 'republic', city: 'capitale' } });
  const toasts = [], rpc = [];
  Object.assign(ctx, { showToast: (...a) => toasts.push(a), sbRpc: async (...a) => { rpc.push(a); return { ok: true }; },
    posteEstLocal: p => p === 'maire', getCleCycle: () => 'president', CYCLES_ELECTORAUX: {}, getPhaseActuelle: () => 'VOTE', PHASES_ELECTORALES: {} });
  vm.runInContext(src, ctx);
  return ctx.voterPour('Moustafa Kheimal', 'president', 'republic', null).then(() => {
    assert.equal(rpc.length, 0); assert.match(toasts[0][1], /dans votre pays/);
  });
});

test('forums : pays de lecture (nationalité par défaut), Local de la bonne ville, national étranger en lecture seule', () => {
  const src = extraire('forum.js', ['forumEstNational', 'paysForumsPossibles', 'paysForums', 'villeForumLocal', 'forumNationalLectureSeule', 'idForumLocal']);
  const ctx = ctxNat({ country: 'soviet', nationalite: 'republic', currentCity: 'ville_b', domicile: { country: 'republic', city: 'capitale' } });
  vm.runInContext(src, ctx);
  assert.equal(ctx.paysForums(), 'republic');
  assert.equal(ctx.villeForumLocal(), 'capitale', 'Local de son domicile, vu de l\'étranger');
  assert.equal(ctx.forumNationalLectureSeule('national'), false);
  ctx.state.forumPays = 'soviet';
  assert.equal(ctx.paysForums(), 'soviet');
  assert.equal(ctx.villeForumLocal(), 'ville_b', 'Local de la ville où il se trouve');
  assert.equal(ctx.forumNationalLectureSeule('national'), true);
  ctx.state.forumPays = 'narco';
  assert.equal(ctx.paysForums(), 'republic', 'aucun autre pays');
  const pub = lire('forum.js');
  assert.match(pub, /forumNationalLectureSeule\(forumId\)/);
  assert.match(pub, /pays:paysForums\(\)/);
});

test('naturalisation et domiciliation : ouvertes, tarifs 2 PA + 50 et 1 PA + 50, décision au serveur', () => {
  const pol = lire('plateau-politique.js');
  const dem = pol.slice(pol.indexOf('const DEMARCHES_ETAT_CIVIL_PAR_BATIMENT'), pol.indexOf('};', pol.indexOf('const DEMARCHES_ETAT_CIVIL_PAR_BATIMENT')));
  assert.equal((dem.match(/fn:'demander_naturalisation', label:'Demander la naturalisation', pa:2, cost:50/g) || []).length, 2);
  assert.equal((dem.match(/fn:'changer_domicile', label:'Se domicilier ici', pa:1, cost:50/g) || []).length, 2);
  assert.doesNotMatch(dem, /bientot:'Bientôt disponible : la naturalisation/);
  assert.match(pol, /sbRpcVerdict\('naturalisation_demander'/);
  assert.doesNotMatch(lire('data.js'), /les demandes de naturalisation arriveront avec le voyage/);
  const seed = lire('baseline/seeds/95_a-regenerer/ordres_couts.sql');
  assert.match(seed, /\('changer_domicile',1,50\)/); assert.match(seed, /\('demander_naturalisation',2,50\)/);
  for (const m of ['migrations/20261118030000_nationalite_domicile_elections.sql', 'migrations/20261118031000_nationalite_forums.sql'])
    assert.ok(fs.existsSync(path.join(R, m)), m);
});

test('partis de Sovarka : ordre « Investir un candidat » et tâches de nuit', () => {
  const partis = lire('plateau-sovarka-partis.js');
  assert.match(partis, /partiCommande\('investir', m\.id, \{ nom: x\.nom, ville \}/);
  assert.match(partis, /investissables = m\.membres[^\n]*x\.nom !== m\.chef/);
  const cron = lire('api/cron-minuit.js');
  assert.match(cron, /tacheQuotidienne\('naturalisations', traiterNaturalisationsQuotidien\)/);
  assert.match(cron, /tacheQuotidienne\('sovarka_partis_presidence', traiterPartisPresidenceSovarkaQuotidien\)/);
});
