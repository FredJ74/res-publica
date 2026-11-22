'use strict';
// Santé — « Suites » (Fred, 22/11/2026 au soir), côté navigateur : les VRAIES fonctions des fichiers du jeu, extraites et
// exécutées avec de fausses réponses du serveur (aucun calcul dans le navigateur, seulement l'affichage).
//  - point 1 : « snack » n'est jamais affiché ; « en-cas » en Républia, « zakouski » en Sovarka ;
//  - point 3 : repas de l'hôpital et de la clinique : Santé du serveur dans le message ;
//  - point 7 : « se laisser faire » face à une bête : on peut rester debout (PA laissés par la robustesse) ;
//  - point 9 : don de tracts refusé, destinataire plein : la place restante est dite ;
//  - points 10 et 13 : antenne de Starovka « La Voix de Sovarka » ; nouvel objectif du criminel.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const fonction = (src, nom) => {
  const i = src.indexOf('function ' + nom + '('); assert.ok(i >= 0, nom);
  const debut = src.slice(0, i).endsWith('async ') ? i - 6 : i;
  return src.slice(debut, src.indexOf('\n}\n', i) + 3);
};
const constante = (src, nom) => { const i = src.indexOf('const ' + nom + ' ='); assert.ok(i >= 0, nom); return src.slice(i, src.indexOf('};', i) + 2); };

test('point 1 : aucun « snack » affiché ; « en-cas » en Républia, « zakouski » en Sovarka', () => {
  const ctx = { console, state: { country: 'soviet' }, document: { getElementById: () => null, addEventListener() {}, querySelector: () => null }, localStorage: { getItem: () => null } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js').replace(/^const (WORLD|BUILDINGS) =/mg, 'var $1 ='), ctx);
  const vus = { soviet: new Set(), republic: new Set() };
  for (const p of Object.keys(vus)) for (const city of Object.values(ctx.WORLD[p])) for (const b of city.buildings || []) {
    const c = city.buildingContext?.[b] || {};
    for (const [r, room] of Object.entries({ ...(ctx.BUILDINGS[b]?.rooms || {}), ...(c.roomsExtra || {}) })) {
      if (c.roomsExclues?.includes(r)) continue;
      for (const o of ctx.ordresDeclaresDeLaPiece(room, c, r)) if (o && o.desc) vus[p].add(o.desc);
    }
  }
  for (const p of Object.keys(vus)) assert.deepEqual([...vus[p]].filter(d => /snack/i.test(d)), [], p);
  assert.ok([...vus.republic].some(d => /boissons et en-cas/.test(d)));
  assert.deepEqual([...vus.republic].filter(d => /zakouski/.test(d)), []);
  assert.ok([...vus.soviet].some(d => /boissons et zakouski/.test(d)));
  assert.deepEqual([...vus.soviet].filter(d => /en-cas/.test(d)), []);
});

test('point 3 : repas de l’hôpital — Santé et PA lus dans la réponse du serveur', async () => {
  const src = lire('plateau-personnage.js'), toasts = [], journal = [];
  const ctx = { state: { pa: 5, hp: 50, country: 'republic', hospitalisation: { lieu: 'hopital' } }, showToast: (...a) => toasts.push(a),
    addJournalEntry: (...a) => journal.push(a), updateUI() {}, sbFicheBaseAdopter() {}, dateCivileParisMedicale: () => '2026-11-23',
    HOSPITALISATION_REFUS: {}, globalThis: {}, sbRpcVerdict: async () => ({ ok: true, pa: 4, cout: 0, bonus_lendemain: 2, sante_gain: 4, hp: 54 }) };
  vm.createContext(ctx);
  vm.runInContext(fonction(src, 'doRepasHopital') + ';this.f = doRepasHopital;', ctx);
  await ctx.f();
  assert.equal(ctx.state.hp, 54);
  assert.equal(toasts[0][1], '-1 PA, +4 Santé. +2 PA au prochain sommeil autorisé.');
  assert.match(journal[0][0], /Repas de l’hôpital \(-1 PA, \+4 Santé, \+2 PA au prochain sommeil\)\./);
});

test('point 7 : se laisser faire — debout si le serveur laisse des PA, sinon réveil à l’hôpital', async () => {
  const src = lire('plateau-sovarka-provinces.js');
  const essai = async reponse => {
    const toasts = [], appels = [];
    const ctx = { state: { pa: 20, char: { name: 'Tom Tom' } }, showToast: (...a) => toasts.push(a), updateUI() {},
      provActe: async () => reponse, provRefus() {}, provT: (k, v) => k + (v ? ':' + JSON.stringify(v) : ''), provEchapper: s => s,
      provServeur: (t, s) => s, PROV_CREATURES: {}, provForetRendre() {}, relireHospitalisationServeur: async () => appels.push('hopital'),
      document: { getElementById: () => ({ classList: { remove() {} } }) } };
    vm.createContext(ctx);
    vm.runInContext(constante(src, 'FORET_TXT') + '\n' + fonction(src, 'foretChoisir') + ';this.f = foretChoisir;', ctx);
    await ctx.f('subir');
    return { toasts, appels, state: ctx.state };
  };
  const debout = await essai({ ok: true, choix: 'subir', nom: 'Ours brun', pa: 4, pertes: [{ nom: 'Tom Tom', pa_perdus: 16, sante_perdue: 16, pa: 4 }] });
  assert.equal(debout.toasts[0][1], 'Ours brun ne s’est pas fait prier : vous perdez 16 PA et 16 Santé, mais vous tenez encore debout.');
  assert.deepEqual(debout.appels, []); assert.equal(debout.state.pa, 4);
  const tombe = await essai({ ok: true, choix: 'subir', nom: 'Ours brun', pa: 0, pertes: [] });
  assert.match(tombe.toasts[0][1], /^eaten/); assert.deepEqual(tombe.appels, ['hopital']);
  assert.doesNotMatch(constante(src, 'FORET_TXT'), /Le groupe se réveillera à l’hôpital\.'/);
});

test('point 9 : don de tracts refusé (destinataire plein) — la place restante est dite', async () => {
  const src = lire('plateau-communication.js'), toasts = [];
  const refus = { ok: false, raison: 'destinataire_plein', place: 5, destinataire: 'Ana', demande: 10 };
  const tract = { type: 'tract', quantite: 20 };
  const ctx = { state: { inventory: [tract], _inventaireRevision: 3 }, lotsTractsDonnables: () => [tract], showToast: (...a) => toasts.push(a),
    document: { getElementById: id => (id === 'don-tract-0' ? { value: '10' } : { classList: { remove() {} } }) }, updateUI() {}, addJournalEntry() {},
    messageRefusSortieInventaire: (r, d) => d.destinataire + ' ne peut recevoir que ' + d.place + ' unité(s) de plus.',
    executerReceptionInventaire: async (fn, p, options) => { assert.equal(fn, 'tracts_donner_joueur'); assert.equal(options.surRefus(refus), true); return null; } };
  vm.createContext(ctx);
  vm.runInContext(fonction(src, 'confirmerDonTracts') + ';this.f = confirmerDonTracts;', ctx);
  await ctx.f(0, 'Ana');
  assert.deepEqual(toasts, [['Don refusé', 'Ana ne peut recevoir que 5 unité(s) de plus.', false]]);
});

test('points 10 et 13 : antenne de Starovka et objectif du criminel', () => {
  for (const f of ['plateau-communication.js', 'api/_presse-antennes.js']) {
    assert.match(lire(f), /journaliste: 'Saran Batbayar',  journal: 'La Voix de Sovarka' \}/, f);
    assert.doesNotMatch(lire(f), /journal: 'Metel'/, f);
  }
  assert.match(lire('data.js'), /name: 'Presse de Starovka — Metel'/); // la boutique garde son nom
  const src = lire('plateau-politique.js'), ctx = {}; vm.createContext(ctx);
  vm.runInContext(src.slice(src.indexOf('const OBJECTIFS_SECRETS ='), src.indexOf('async function afficherObjectifsSecrets')) + ';this.o = OBJECTIFS_SECRETS;', ctx);
  assert.equal(ctx.o.criminel.objectifs.find(o => o.id === 'obj_informateur').desc, 'Acheter 5 informations à des informateurs différents');
});
