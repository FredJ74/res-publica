// Maisonnettes en bois de Krasnov (Fred, 14/11/2026 : « un habitant chacune » ; migration 20261114180000).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const MAISONS = {
  'maison-krasnov-bureaux': ['krasnov-rue-bureaux', 'Antonina Merkoulova'],
  'maison-krasnov-rouge': ['krasnov-rue-descendante', 'Matveï Rybakov'],
  'maison-krasnov-bleue': ['krasnov-rue-descendante', 'Praskovia Pakhomova'],
  'maison-krasnov-eglise': ['krasnov-rue-eglise', 'Kouzma Lapchine'],
  'maison-krasnov-terrains': ['krasnov-rue-terrains', 'Ignat Lykov']
};

test('Écran : façades cliquables, maisons listées à Krasnov, mêmes ordres que chez Stepan', () => {
  const ctx = vm.createContext({console, state: {country: 'soviet', currentCity: 'ville_b'}});
  vm.runInContext(fs.readFileSync(path.join(root, 'data.js'), 'utf8'), ctx);
  vm.runInContext(fs.readFileSync(path.join(root, 'plateau-rue-centrale.js'), 'utf8'), ctx);
  const stepan = vm.runInContext(`BUILDINGS['maison-krasnov'].rooms.piece_maison.orders.map(o => o.fn + ':' + o.pa).join()`, ctx);
  for (const [id, [noeud, habitant]] of Object.entries(MAISONS)) {
    const r = vm.runInContext(`(() => ({
      facade: (RUE_CENTRALE_NOEUDS.soviet[${JSON.stringify(noeud)}].zones || []).some(z => z.buildingId === ${JSON.stringify(id)}),
      listee: WORLD.soviet.ville_b.buildings.includes(${JSON.stringify(id)}),
      habitant: BUILDINGS[${JSON.stringify(id)}].rooms.piece_maison.persons[0].name,
      ordres: BUILDINGS[${JSON.stringify(id)}].rooms.piece_maison.orders.map(o => o.fn + ':' + o.pa).join()
    }))()`, ctx);
    assert.ok(r.facade, id + ' : façade absente de ' + noeud);
    assert.ok(r.listee, id + ' : non listée à Krasnov');
    assert.equal(r.habitant, habitant + ' (PNJ)');
    assert.equal(r.ordres, stepan);
  }
  assert.ok(vm.runInContext(`!WORLD.soviet.ville_a.buildings.includes('maison-krasnov-rouge')`, ctx), 'Starovka touchée');
});

test('Serveur et IA : chaque maison déclarée dans la migration et dans les portraits de trinquer', () => {
  const sql = fs.readFileSync(path.join(root, 'migrations/20261114180000_krasnov_maisonnettes.sql'), 'utf8');
  const ia = fs.readFileSync(path.join(root, 'api/_reaction-habitant.js'), 'utf8');
  for (const [id, [noeud, habitant]] of Object.entries(MAISONS)) {
    assert.ok(sql.includes(`('soviet', 'ville_b', '${noeud}', '${id}')`), id + ' : sortie de rue');
    assert.ok(sql.includes(`p_batiment = '${id}' THEN jsonb_build_object('id', '${id}', 'habitant', '${habitant}'`), id + ' : habitant serveur');
    assert.ok(ia.includes(`'${habitant}':`), habitant + ' : portrait IA');
  }
  assert.ok(sql.includes('sovarka_maison_interne(p.current_city,p.current_building) IS NOT NULL'), 'lit de la maison');
});
