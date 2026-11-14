// Krasnov : images et salles distinctes, bail de l'atelier et centre d'écoute conservés.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const root = new URL('../../', import.meta.url);
const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('data.js',root),'utf8'),ctx);
const dist = vm.runInContext("BUILDINGS['distillerie-krasnov']",ctx);
const radar = vm.runInContext("BUILDINGS['station-radar-krasnov']",ctx);
assert.deepEqual(Object.keys(dist.rooms),['salle_ventes','bureau_direction','atelier_distillerie']);
assert.ok(dist.rooms.atelier_distillerie.orders.some(o=>o.fn==='sovarka_demande_location'));
assert.ok(dist.rooms.atelier_distillerie.orders.some(o=>o.fn==='commerce_pj'));
assert.ok(dist.rooms.salle_ventes.orders.some(o=>o.fn==='commerce_pj'));
assert.equal(dist.rooms.bureau_direction.orders.length,0);
assert.ok(radar.rooms.salle_ecoute.orders.some(o=>o.fn==='voler_archives_ecoute'));
assert.ok(radar.rooms.salle_ecoute.orders.some(o=>o.fn==='consulter_archives_ecoute'));
for(const path of [
 'images/Sovarka/Krasnov/Krasnov_distillerie_salle_ventes.webp',
 'images/Sovarka/Krasnov/Krasnov_distillerie_bureau_direction.webp',
 'images/Sovarka/Krasnov/Krasnov_distillerie_atelier.webp',
 'images/Sovarka/Krasnov/Krasnov_centre_ecoute_salle.webp'
]){
 const b=fs.readFileSync(new URL(path,root));
 assert.equal(b.toString('ascii',0,4),'RIFF',path);
 assert.equal(b.toString('ascii',8,12),'WEBP',path);
}
const sql=fs.readFileSync(new URL('migrations/20261114170000_krasnov_distillerie_salles.sql',root),'utf8');
assert.match(sql,/pays='soviet' AND ville='ville_b' AND batiment='distillerie-krasnov'/);
assert.match(sql,/\["salle_ventes","bureau_direction","atelier_distillerie"\]/);
console.log('Krasnov : quatre images WebP, trois salles, ordres et migration conformes');
