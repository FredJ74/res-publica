import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

function charger() {
  const ctx = vm.createContext({console, state: {country: 'soviet', currentCity: 'ville_b'}});
  vm.runInContext(fs.readFileSync(path.join(root, 'data.js'), 'utf8'), ctx);
  vm.runInContext(fs.readFileSync(path.join(root, 'plateau-rue-centrale.js'), 'utf8'), ctx);
  return ctx;
}

test('Starovka et Krasnov : chaque façade de rue ouvre un bâtiment de la ville', () => {
  const ctx = charger();
  const r = vm.runInContext(`(() => {
    const out = [];
    for (const [id, n] of Object.entries(RUE_CENTRALE_NOEUDS.soviet)) {
      const ville = id.startsWith('starovka') ? 'ville_a' : id.startsWith('krasnov') ? 'ville_b' : null;
      if (!ville) continue;
      for (const z of n.zones || []) if (z.type === 'batiment')
        out.push({ id, ville, b: z.buildingId, connu: WORLD.soviet[ville].buildings.includes(z.buildingId) });
    }
    return out;
  })()`, ctx);
  const attendus = ['starovka-rue-hotel:hotel-mineur', 'starovka-rue-terrains:terrain-a-batir-3', 'starovka-rue-stade:stade',
    'starovka-rue-mairie-marche:mairie', 'starovka-rue-lycee-commissariat:commissariat-local',
    'starovka-rue-bureaux-caserne:centre-affaires', 'krasnov-rue-terrains:terrain-a-batir-2',
    'krasnov-centre-artisanal:centre-artisanal', 'krasnov-rue-immeubles-centre-commercial:centre-commercial',
    'krasnov-rue-mairie-place:mairie', 'krasnov-rue-bureaux:centre-affaires'];
  const vus = r.map(z => z.id + ':' + z.b);
  for (const a of attendus) assert.ok(vus.includes(a), 'façade absente : ' + a);
  for (const z of r) assert.ok(z.connu, z.b + ' n\'est pas un bâtiment de ' + z.ville);
});

test('Bureaux de province : plus de location privée au guichet, demande à la mairie', () => {
  const ctx = charger();
  for (const ville of ['ville_a', 'ville_b']) {
    const fns = vm.runInContext(`['bureau_prestige','bureau_standard','open_space'].map(p =>
      ordresDeclaresDeLaPiece(BUILDINGS['centre-affaires'].rooms[p], WORLD.soviet['${ville}'].buildingContext['centre-affaires'], p).map(o => o.fn))`, ctx);
    for (const liste of fns) {
      assert.ok(!liste.includes('louer_local'), ville + ' : guichet encore ouvert');
      assert.equal(liste.filter(f => f === 'sovarka_demande_location').length, 1, ville + ' : demande de location absente ou doublée');
    }
  }
});

test('Textes de province : plus de renvoi à Montrouge, Luthécia ou Port-Sainte-Marie', () => {
  const ctx = charger();
  const fautes = vm.runInContext(`(() => {
    const re = /Montrouge|Luth[ée]cia|Port-Sainte|Procureur/;
    const out = [];
    for (const ville of ['ville_a', 'ville_b']) {
      const c = WORLD.soviet[ville];
      for (const id of c.buildings) {
        const b = BUILDINGS[id], ctx = (c.buildingContext || {})[id] || {};
        if (re.test((ctx.name || b.name) + ' ' + (ctx.desc || b.desc || ''))) out.push(ville + '/' + id);
        const rooms = Object.assign({}, b.rooms || {}, ctx.roomsExtra || {});
        for (const [rid, r] of Object.entries(rooms)) {
          const ov = (ctx.roomOverrides || {})[rid] || {};
          if (re.test((ov.name || r.name) + ' ' + (ov.desc || r.desc || ''))) out.push(ville + '/' + id + '/' + rid);
          for (const o of ordresDeclaresDeLaPiece(r, ctx, rid)) if (re.test((o.label || '') + ' ' + (o.desc || ''))) out.push(ville + '/' + id + '/' + rid + '/' + o.fn);
        }
      }
    }
    return out;
  })()`, ctx);
  assert.equal(fautes.length, 0, Array.from(fautes).join(', '));
});

test('Devise du pays dans les libellés : FR devient PSK, FRAIS reste intact', () => {
  const src = fs.readFileSync(path.join(root, 'plateau-politique.js'), 'utf8');
  const m = src.match(/function deviseDansTexte\([\s\S]*?\n\}/);
  assert.ok(m, 'deviseDansTexte absente');
  const ctx = vm.createContext({});
  vm.runInContext(m[0], ctx);
  const f = vm.runInContext('deviseDansTexte', ctx);
  assert.equal(f('75 FR. 2 PA.', 'PSK'), '75 PSK. 2 PA.');
  assert.equal(f('150 FR de FRAIS DE GREFFE', 'PSK'), '150 PSK de FRAIS DE GREFFE');
  assert.equal(f('75 FR.', 'FR'), '75 FR.');
  assert.equal(f(undefined, 'PSK'), undefined);
});
