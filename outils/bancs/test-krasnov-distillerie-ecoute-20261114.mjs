// Krasnov : images et salles distinctes, bail de l'atelier et centre d'écoute conservés.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const root = new URL('../../', import.meta.url);
const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('data.js',root),'utf8'),ctx);
const dist = JSON.parse(JSON.stringify(vm.runInContext("BUILDINGS['distillerie-krasnov']",ctx)));
const radar = JSON.parse(JSON.stringify(vm.runInContext("BUILDINGS['station-radar-krasnov']",ctx)));
assert.deepEqual(Object.keys(dist.rooms),['salle_ventes','bureau_direction','atelier_distillerie']);
// Le local loué est la salle des ventes (migration 20261114180000) : ses deux ordres n'existent qu'ici.
// 15/11/2026 au soir : la distillerie est aussi l'usine d'État de Sovarka (vente directe, production, directeur).
assert.deepEqual(dist.rooms.salle_ventes.orders.map(o=>o.fn),['sovarka_demande_location','commerce_pj','vente_directe_usine']);
assert.deepEqual(dist.rooms.atelier_distillerie.orders.map(o=>o.fn),['produire_alcool','vendre_matiere_usine']);
assert.equal(dist.rooms.bureau_direction.orders.length,3);
assert.deepEqual(dist.rooms.bureau_direction.persons.map(p=>p.name),['Anatoli Pokhmelkine (PNJ)']);
assert.deepEqual(dist.rooms.atelier_distillerie.persons.map(p=>p.name),['Vassili Gradousov (PNJ)']);
assert.deepEqual(radar.rooms.salle_ecoute.persons.map(p=>p.name),['Colonel Gleb Voronov (PNJ)','Caporal Ilia Sorokine (PNJ)']);
assert.doesNotMatch(JSON.stringify(radar),/Sokolova/);
assert.equal(vm.runInContext("BUILDINGS['poste-vigilance-glaciale'].rooms.salle_ecoute.persons[0].name",ctx),'Sergent Oleg Sloukhov (PNJ)');
const local=fs.readFileSync(new URL('migrations/20261114180000_krasnov_distillerie_comptoir.sql',root),'utf8');
assert.match(local,/SET piece = 'salle_ventes'/);
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
