'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const src=fs.readFileSync('data.js','utf8');
const start=src.indexOf('// STAROVKA : ENTREPOT LOGISTIQUE ET PORT INDUSTRIEL (06/11/2026');
const end=src.indexOf('// SOVARKA : DROITS D\'EXPLOITER',start);
assert.ok(start>0 && end>start,'bloc Starovka présent');
const block=src.slice(src.indexOf('\n{',start)+1,end);
const BUILDINGS={
 'entrepot-logistique-krasnov':{rooms:{salle_ventes:{name:'Ventes',orders:[{fn:'acheter'}]},bureau_direction:{name:'Bureau directeur',orders:[{fn:'gerer'}]}}},
 'port-sainte-marie':{rooms:{
  quai_principal:{name:'Quai'},entrepot:{name:'Hangars',orders:[{fn:'expedier'}]},douanes:{name:'Douanes'},
  administration_portuaire:{name:'Administration',orders:[{fn:'consulter_manifeste'},{fn:'consulter_administration_port'},{fn:'gerer_logistique_port'}]}
 }}
};
vm.runInNewContext(block,{BUILDINGS});
const warehouse=BUILDINGS['entrepot-logistique-starovka'];
const port=BUILDINGS['port-starovka'];
assert.ok(warehouse && port,'bâtiments présents');
assert.deepEqual(Object.keys(warehouse.rooms).sort(),['administration_portuaire','bureau_direction','salle_ventes'].sort());
assert.deepEqual(Object.keys(port.rooms).sort(),['douanes','entrepot','quai_principal'].sort());
const office=warehouse.rooms.administration_portuaire;
assert.equal(office.persons[0].name,'Commandant Tömör Ochirov (PNJ)');
assert.match(office.imageUrl,/Starovka_port_administration_portuaire\.webp$/);
assert.deepEqual(Array.from(office.orders,x=>x.fn),['consulter_administration_port','gerer_logistique_port']);
assert.equal(warehouse.rooms.bureau_direction.persons[0].name,'Batzorig Dorjiev (PNJ)');
assert.deepEqual(Array.from(port.rooms.entrepot.orders,x=>x.fn),['expedier']);
assert.deepEqual(Array.from(BUILDINGS['port-sainte-marie'].rooms.administration_portuaire.orders,x=>x.fn),['consulter_manifeste','consulter_administration_port','gerer_logistique_port']);
const sql=fs.readFileSync('migrations/20261117123500_starovka_bureau_commandant_entrepot.sql','utf8');
assert.match(sql,/pieces - 'administration_portuaire'/);
assert.match(sql,/entrepot-logistique-starovka/);
assert.match(sql,/port_commandant_regler\(text,jsonb\)/);
assert.match(sql,/CASE WHEN m.country = ''soviet''/);
console.log('OK : bureau du commandant dans entrepôt, directeur conservé, quai/fret conservés, règles du poste inchangées.');
