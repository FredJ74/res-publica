// Cache des portraits (04/11/2026, #55/#60) : un portrait ne redescend que s'il est nouveau ou change.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const src = fs.readFileSync(new URL('../../supabase.js', import.meta.url), 'utf8');
const debut = src.indexOf("const SB_PORTRAITS_CLE");
const fin = src.indexOf('\n}\n', src.indexOf('async function sbPortraitsPour')) + 3;
assert.ok(debut > 0 && fin > debut, 'bloc du cache introuvable');

function monter(serveur) {
  const lectures = [];
  const stockage = {};
  const ctx = {
    lectures, stockage,
    localStorage: { getItem: k => stockage[k] ?? null, setItem: (k, v) => { stockage[k] = v; } },
    sbRpc: async () => Object.entries(serveur).map(([name, u]) => ({ name, empreinte: 'h:' + u })),
    sbGet: async (table, q) => {
      lectures.push(q);
      const noms = decodeURIComponent(q.match(/name=in\.\(([^)]*)\)/)[1]).split(',').map(s => s.replace(/^"|"$/g, ''));
      return noms.filter(n => serveur[n]).map(n => ({ name: n, photo_url: serveur[n] }));
    },
    Date
  };
  vm.createContext(ctx);
  vm.runInContext(src.slice(debut, fin) + '\nthis.pour = sbPortraitsPour; this.raz = () => { _sbEmpreintesInstant = 0; _sbPortraits = null; };', ctx);
  return ctx;
}

test('premier appel : lit les portraits ; second : aucune lecture de portrait', async () => {
  const serveur = { 'Arnie': 'data:a', 'Angie Porcelana': 'data:b' };
  const c = monter(serveur);
  const r1 = await c.pour(['Arnie', 'Angie Porcelana', 'Sans Photo']);
  assert.deepEqual({ ...r1 }, { 'Arnie': 'data:a', 'Angie Porcelana': 'data:b', 'Sans Photo': null });
  assert.equal(c.lectures.length, 1);
  c.raz();  // nouvelle page : cache relu depuis localStorage, empreintes relues
  const r2 = await c.pour(['Arnie', 'Angie Porcelana']);
  assert.equal(r2['Arnie'], 'data:a');
  assert.equal(c.lectures.length, 1, 'aucune relecture de portrait inchange');
});

test('portrait change : seul celui-ci est relu ; portrait retire : efface', async () => {
  const serveur = { 'Arnie': 'data:a', 'Angie Porcelana': 'data:b' };
  const c = monter(serveur);
  await c.pour(['Arnie', 'Angie Porcelana']);
  serveur['Arnie'] = 'data:a2'; delete serveur['Angie Porcelana'];
  c.raz();
  const r = await c.pour(['Arnie', 'Angie Porcelana']);
  assert.equal(r['Arnie'], 'data:a2');
  assert.equal(r['Angie Porcelana'], null);
  assert.equal(c.lectures.length, 2);
  assert.match(c.lectures[1], /Arnie/);
  assert.doesNotMatch(c.lectures[1], /Angie/);
});
