// Forêt profonde de Krasnov : s'enfoncer depuis une vue profonde, égarement, « Retrouver son chemin » (retour de Fred, 14/11/2026).
// Lancer : node --test outils/bancs/test-foret-perdu-20261114.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = f => fs.readFileSync(path.join(root, f), 'utf8');
const prov = read('plateau-sovarka-provinces.js');
const fn = name => { const a = prov.indexOf((prov.includes('async function ' + name + '(') ? 'async function ' : 'function ') + name + '('); assert.ok(a >= 0, name); return prov.slice(a, prov.indexOf('\n}', a) + 2); };

function bac(room, reponses) {
  const appels = [], toasts = [], modales = [], rendus = [];
  const ctx = { state: { currentRoom: room }, console, setTimeout: f => f(), Number, String, JSON,
    provT: (k, v) => k, provRefus: (t, v) => toasts.push(['refus', v.raison]),
    showToast: (t, m, ok) => toasts.push([t, m, ok]), provModal: (t, h) => modales.push([t, h]),
    provForetRendre: r => { rendus.push(r); ctx.state.currentRoom = r; },
    foretReprendreRencontre: async () => {},
    provActe: async (rpc, p) => { appels.push([rpc, p.p_sens]); return reponses.shift(); },
    sbRpcVerdict: async () => reponses.shift() };
  vm.createContext(ctx);
  const src = prov.slice(prov.indexOf('let foretPerduServeur'), prov.indexOf('// Fenêtre angoissante'));
  vm.runInContext(src + fn('foretFenetrePerdu') + fn('foretAller') + fn('foretRelirePerdu') +
    ';globalThis.T={foretAller,foretEstPerdu,foretRelirePerdu};', ctx);
  return { ctx, T: ctx.T, appels, toasts, modales, rendus };
}

test('données : chaque vue profonde propose couper, s’enfoncer, revenir, retrouver (1 PA)', () => {
  const d = read('data.js');
  const bloc = d.slice(d.indexOf('// FORET PROFONDE DE KRASNOV'), d.indexOf("ctx.roomsMasquees = Array.from(new Set([...(ctx.roomsMasquees || []), 'foret_vue_1'"));
  const fns = [...bloc.slice(bloc.indexOf('orders: [', bloc.indexOf('roomsExtra'))).matchAll(/fn: '(foret_[a-z]+)'[^}]*?pa: (\d+)/g)].map(m => m[1] + ':' + m[2]);
  assert.deepEqual(fns, ['foret_couper:2', 'foret_enfoncer:0', 'foret_revenir:0', 'foret_retrouver:1']);
  assert.match(read('plateau-router.js'), /fn === 'foret_retrouver'\) \{ foretAller\('retrouver'\)/);
  const pol = read('plateau-politique.js');
  assert.match(pol, /o\.fn !== 'foret_revenir' \|\| !\(typeof foretEstPerdu === 'function' && foretEstPerdu\(\)\)/);
  assert.match(pol, /o\.fn !== 'foret_retrouver' \|\| \(typeof foretEstPerdu === 'function' && foretEstPerdu\(\)\)/);
});

test('s’enfoncer depuis une vue profonde : nouvelle vue, toast, pas perdu', async () => {
  const b = bac('foret_vue_1', [{ ok: true, vue: 3, room: 'foret_vue_3', perdu: false, egare: false }]);
  await b.T.foretAller('enfoncer');
  assert.deepEqual(b.rendus, ['foret_vue_3']);
  assert.equal(b.toasts[0][0], 'tDeep');
  assert.equal(b.T.foretEstPerdu(), false);
});

test('revenir et s’égarer : fenêtre angoissante (texte selon la vue), puis « Retrouver » remplace « Revenir »', async () => {
  const b = bac('foret_vue_1', [{ ok: true, vue: 2, room: 'foret_vue_2', perdu: true, egare: true }]);
  await b.T.foretAller('revenir');
  assert.equal(b.modales.length, 1);
  assert.equal(b.modales[0][0], 'tLost');
  assert.match(b.modales[0][1], /lost_2/);
  assert.match(b.modales[0][1], /lostHint/);
  assert.equal(b.toasts.length, 0, 'plus d’infobulle « Perdu ! »');
  assert.equal(b.T.foretEstPerdu(), true);
});

test('retrouver raté : « Toujours perdu » ; réussi : sortie, plus perdu', async () => {
  const b = bac('foret_vue_2', [{ ok: true, vue: 4, room: 'foret_vue_4', perdu: true, egare: true },
    { ok: true, vue: 0, room: 'zone_recolte', perdu: false, egare: false }]);
  await b.T.foretAller('retrouver');
  assert.equal(b.modales[0][0], 'tStill');
  assert.match(b.modales[0][1], /lost_4/);
  await b.T.foretAller('retrouver');
  assert.deepEqual(b.toasts.at(-1), ['tOut', 'found', true]);
  assert.equal(b.T.foretEstPerdu(), false);
});

test('écran ignorant l’égarement (rechargement) : le refus du serveur bascule l’ordre et rouvre la fenêtre', async () => {
  const b = bac('foret_vue_3', [{ ok: false, raison: 'foret_perdu', perdu: true }]);
  await b.T.foretAller('revenir');
  assert.deepEqual(b.rendus, ['foret_vue_3'], 'actions repeintes');
  assert.equal(b.modales[0][0], 'tStill');
  assert.equal(b.T.foretEstPerdu(), true);
});

test('premier affichage d’une vue profonde : l’état est relu une seule fois au serveur', async () => {
  const b = bac('foret_vue_1', [{ ok: true, vue: 1, perdu: true }]);
  b.T.foretEstPerdu();
  await new Promise(r => setImmediate(r));
  assert.equal(b.T.foretEstPerdu(), true);
  assert.deepEqual(b.rendus, ['foret_vue_1']);
});

test('textes : neuf langues pour l’égarement, le libellé et l’infobulle de « Retrouver son chemin »', () => {
  const p = read('i18n/sovarka-provinces-resources.js');
  for (const k of ['lost_1', 'lost_2', 'lost_3', 'lost_4', 'lostHint', 'tStill', 'found', 'm_foret_pas_perdu'])
    assert.equal((p.match(new RegExp('"' + k + '":', 'g')) || []).length, 9, k);
  assert.equal((read('i18n/sovarka-ordres-resources.js').match(/"foret_retrouver":/g) || []).length, 9);
  assert.ok(read('i18n/sovarka-infobulles-resources.js').includes('["Chercher la sortie à l’instinct, entre des troncs qui se ressemblent tous (1 PA).'));
  assert.match(read('migrations/20261114120000_sovarka_foret_perdu_retrouver.sql'), /payer_ordre\(a, 'foret_retrouver', 1, 0\)/);
});
