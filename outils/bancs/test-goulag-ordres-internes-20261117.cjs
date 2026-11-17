'use strict';
// Goulag de Sovarka — ordres internes (17/11/2026) : écran, traductions, raccords.
// Le module est exécuté dans un bac à sable : aucune RPC réelle, verdicts simulés.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');

const R = path.resolve(__dirname, '../..');
const SOURCE = fs.readFileSync(path.join(R, 'plateau-goulag-ordres.js'), 'utf8');

function charger({ pays = 'soviet', detenu = false, poste = null, langue = 'fr', appels = [], verdicts = {} } = {}) {
  const toasts = [];
  const body = { innerHTML: '', querySelector: () => null };
  const elements = {
    'postes-modal-title': { textContent: '' }, 'postes-body': body,
    'modal-postes': { classList: { add() {}, remove() {} } }
  };
  const ctx = {
    console, Object, Array, String, Number, JSON, Promise, Date, Uint8Array,
    crypto: { randomUUID: () => '00000000-0000-4000-8000-000000000999' },
    i18next: { language: langue },
    state: { country: pays, estEmprisonne: detenu ? { qhs: true } : null, char: { poste: poste ? { id: poste } : null }, inventory: [], currentCity: 'qhs' },
    WORLD: { soviet: { capitale: { name: 'Novomirsk' }, ville_a: { name: 'Starovka' }, ville_b: { name: 'Krasnov' } } },
    document: { readyState: 'complete', getElementById: id => elements[id] || null, addEventListener() {} },
    showToast: (titre, msg, ok) => toasts.push({ titre, msg, ok }),
    sbRpcVerdict: async (nom, params) => { appels.push({ nom, params }); return verdicts[nom] || { ok: true }; },
    sbLoadPersonnage: async () => null, updateUI: () => {}, fermerModalPostes: () => {},
    doOrder: function (fn) { appels.push({ nom: 'doOrder:' + fn }); }
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext(SOURCE, ctx, { filename: 'plateau-goulag-ordres.js' });
  return { ctx, toasts, appels, body };
}

const fns = liste => Array.from(liste, o => o.fn);

test('ordres proposés par pièce, détenu ou personne habilitée', () => {
  const visiteur = charger().ctx.goulagOrdresInternes.ordresDuLieu;
  assert.deepEqual(fns(visiteur('qhs-prison', 'entree_qhs', 'qhs')), ['sovarka_goulag_liste']);
  assert.deepEqual(fns(visiteur('qhs-prison', 'bureau_chef', 'qhs')), ['sovarka_goulag_registre', 'sovarka_goulag_interroger']);
  assert.deepEqual(fns(visiteur('qhs-prison', 'mirador', 'qhs')), ['sovarka_goulag_incidents']);
  assert.deepEqual(fns(visiteur('qhs-prison', 'cellules_qhs', 'qhs')), []);
  const couts = Object.fromEntries(Array.from(visiteur('qhs-prison', 'bureau_chef', 'qhs'), o => [o.fn, o.pa]));
  assert.equal(couts.sovarka_goulag_interroger, 1); assert.equal(couts.sovarka_goulag_registre, 0);
  const juge = charger({ poste: 'juge' }).ctx.goulagOrdresInternes.ordresDuLieu;
  assert.equal(Array.from(juge('qhs-prison', 'bureau_chef', 'qhs')).find(o => o.fn === 'sovarka_goulag_sanction').pa, 1);
  assert.ok(fns(juge('qhs-prison', 'bureau_chef', 'qhs')).includes('sovarka_goulag_sanction'));
  const ministre = charger({ poste: 'min_just' }).ctx.goulagOrdresInternes.ordresDuLieu;
  assert.ok(!fns(ministre('qhs-prison', 'bureau_chef', 'qhs')).includes('sovarka_goulag_sanction'));
  const detenu = charger({ detenu: true }).ctx.goulagOrdresInternes.ordresDuLieu;
  assert.deepEqual(fns(detenu('qhs-prison', 'cellules_qhs', 'qhs')), ['sovarka_goulag_dormir', 'sovarka_goulag_manger', 'sovarka_goulag_mirador']);
  assert.deepEqual(fns(detenu('qhs-prison', 'cachot_disciplinaire', 'qhs')), ['sovarka_goulag_dormir']);
  assert.deepEqual(fns(detenu('qhs-prison', 'mirador', 'qhs')), ['sovarka_goulag_corrompre', 'sovarka_goulag_dortoir', 'sovarka_goulag_entree']);
  assert.deepEqual(fns(detenu('qhs-prison', 'bureau_chef', 'qhs')), []);
  // Aucune grève de la faim ni aucun ordre du QHS républicain dans le goulag.
  for (const piece of ['entree_qhs', 'cellules_qhs', 'cachot_disciplinaire', 'bureau_chef', 'mirador']) {
    for (const f of [visiteur, detenu]) assert.ok(!fns(f('qhs-prison', piece, 'qhs')).includes('greve_faim'));
  }
});

test('aucune fuite vers le QHS de Républia ni hors du camp', () => {
  const rep = charger({ pays: 'republic', detenu: true }).ctx.goulagOrdresInternes.ordresDuLieu;
  for (const piece of ['entree_qhs', 'cellules_qhs', 'salle_interrogatoire']) assert.equal(rep('qhs-prison', piece, 'qhs').length, 0);
  const sov = charger().ctx.goulagOrdresInternes.ordresDuLieu;
  assert.equal(sov('tribunal', 'bureau_juge', 'capitale').length, 0);
  assert.equal(sov('qhs-prison', 'entree_qhs', 'capitale').length, 0);
});

test('les neuf langues portent tous les textes, noms propres en alphabet latin', () => {
  const { textes, langues } = charger().ctx.goulagOrdresInternes;
  assert.deepEqual(Array.from(langues), ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de']);
  const cles = Object.keys(textes.fr).filter(k => k !== 'r'), raisons = Object.keys(textes.fr.r);
  for (const l of langues) {
    assert.ok(textes[l], l);
    assert.deepEqual(Array.from(Object.keys(textes[l])).filter(k => k !== 'r').sort(), [...cles].sort(), l);
    assert.deepEqual(Array.from(Object.keys(textes[l].r)).sort(), [...raisons].sort(), l);
    for (const k of cles) assert.ok(String(textes[l][k]).trim().length > 0, l + ':' + k);
    assert.match(textes[l].starovka, /Starovka/); assert.match(textes[l].krasnov, /Krasnov/);
    for (const k of ['mDormi', 'mInterroSecret', 'mSanction', 'evadeLe', 'tribunalDe']) {
      const attendus = (textes.fr[k].match(/\{[a-z]+\}/g) || []).sort();
      assert.deepEqual(Array.from(textes[l][k].match(/\{[a-z]+\}/g) || []).sort(), Array.from(attendus), l + ':' + k);
    }
  }
  assert.equal(charger({ langue: 'zh-TW' }).ctx.goulagOrdresInternes.t('oDormir'), '睡覺');
  assert.equal(charger({ langue: 'pt' }).ctx.goulagOrdresInternes.t('oManger'), 'Comer');
  assert.equal(charger({ langue: 'xx' }).ctx.goulagOrdresInternes.t('oManger'), 'Manger');
});

test('doOrder est enveloppé : ordres du goulag routés, autres ordres inchangés', async () => {
  const appels = [];
  const { ctx, toasts } = charger({ detenu: true, appels, verdicts: { sovarka_goulag_dormir: { ok: true, gain: 1, jours_restants: 4, pa: 9 } } });
  ctx.doOrder('prier');
  assert.deepEqual(appels.map(a => a.nom), ['doOrder:prier']);
  ctx.doOrder('sovarka_goulag_dormir');
  await new Promise(r => setTimeout(r, 0));
  assert.equal(appels[1].nom, 'sovarka_goulag_dormir');
  assert.equal(ctx.state.pa, 9);
  assert.match(toasts[0].msg, /4/);
});

test('un refus serveur est nommé, sans effet calculé par l’écran', async () => {
  const appels = [];
  const { ctx, toasts } = charger({ detenu: true, appels, langue: 'ar', verdicts: { sovarka_goulag_manger: { ok: false, raison: 'deja_mange' } } });
  ctx.state.pa = 5;
  ctx.doOrder('sovarka_goulag_manger');
  await new Promise(r => setTimeout(r, 0));
  assert.equal(ctx.state.pa, 5);
  assert.equal(toasts[0].msg, charger().ctx.goulagOrdresInternes.textes.ar.r.deja_mange);
});

test('fenêtres : sens d’écriture automatique, aucune couleur en dur', () => {
  assert.match(SOURCE, /dir="auto"/);
  assert.doesNotMatch(SOURCE, /#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b/);
  assert.doesNotMatch(SOURCE, /Math\.random|Date\.now\(/);
  assert.doesNotMatch(SOURCE, /localStorage/);
});

test('plateau.html charge le module une seule fois, avant le routeur', () => {
  const html = fs.readFileSync(path.join(R, 'plateau.html'), 'utf8');
  const i = html.indexOf('src="plateau-goulag-ordres.js'), j = html.indexOf('src="plateau-router.js');
  assert.ok(i > 0 && j > i);
  assert.equal(html.split('src="plateau-goulag-ordres.js').length, 2);
});

test('cron de minuit : contrôle idempotent côté serveur, tolérant à un moteur absent', () => {
  const cron = fs.readFileSync(path.join(R, 'api/cron-minuit.js'), 'utf8');
  assert.match(cron, /tacheQuotidienne\('controle_goulag_sovarka', traiterControleGoulagQuotidien\)/);
  assert.match(cron, /rpc\/sovarka_goulag_controle_minuit/);
  assert.match(cron, /PGRST202/);
  assert.match(cron, /, controleGoulag \};/);
});

test('migrations : additives, verrouillées par #1020, sans écriture par la vue personnages', () => {
  const dossier = path.join(R, 'migrations');
  const lot = fs.readdirSync(dossier).filter(f => /^20261117\d+_goulag_ordres_internes_/.test(f)).sort();
  assert.equal(lot.length, 4);
  const sql = lot.map(f => fs.readFileSync(path.join(dossier, f), 'utf8')).join('\n');
  assert.match(sql, /goulag_moteur_1020_requis/);
  assert.doesNotMatch(sql, /UPDATE\s+public\.personnages\s/i);
  assert.doesNotMatch(sql, /\bDROP\s+TABLE\b/i);
  assert.doesNotMatch(sql, /sovarka_goulag_configuration\s+SET\s+active/i);
  for (const fixe of ['taux IN (80,95)', "CASE WHEN r.corruption_bonus THEN 95 ELSE 80 END", 'least(95, greatest(5, round(50 + 5 * (v_vol_i - v_vol_d))',
    'greatest(1, coalesce(d.pa,0) - 7)', 'cachot_nuits BETWEEN 0 AND 2', "('corruption_taux_base',70,",
    "payer_ordre_interne(v_nom, 'sovarka_goulag_interroger', 1, 0)", "payer_ordre_interne(v_nom, 'sovarka_goulag_sanction', 1, 0)",
    "('sovarka_goulag_interroger',1,0),('sovarka_goulag_sanction',1,0)"]) assert.ok(sql.includes(fixe), fixe);
  const miroir = fs.readFileSync(path.join(R, 'baseline/seeds/95_a-regenerer/ordres_couts.sql'), 'utf8');
  assert.match(miroir, /\('sovarka_goulag_interroger',1,0\)/); assert.match(miroir, /\('sovarka_goulag_sanction',1,0\)/);
});
