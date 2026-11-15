#!/usr/bin/env node
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const src=fs.readFileSync(path.join(root,'data.js'),'utf8');
const sql=fs.readFileSync(path.join(root,'migrations/20261115192000_starovka_raffinerie_trois_salles.sql'),'utf8');
const context=vm.createContext({});
vm.runInContext(src+';globalThis.__ref={world:WORLD.soviet.ville_a.buildingContext["usine-principale"],base:BUILDINGS["usine-principale"]};',context);
const {world,base}=context.__ref;
assert.ok(world && base);
assert.equal(world.name,'Raffinerie d’État du Grand Nord'); // nom choisi par Fred le 15/11/2026 au soir
const files={
 direction_usine:'Starovka_raffinerie_bureau_directeur.webp',
 salle_ventes_raffinerie:'Starovka_raffinerie_salle_ventes.webp',
 interieur_raffinerie:'Starovka_raffinerie_interieur_usine.webp'
};
for(const [id,filename] of Object.entries(files)){
 const room=world.roomOverrides?.[id] || world.roomsExtra?.[id];
 assert.ok(room, 'Salle non raccordée: '+id);
 assert.equal(room.imageUrl,'images/Sovarka/Starovka/'+filename);
 const file=path.join(root,room.imageUrl);
 assert.ok(fs.existsSync(file),filename);
 const content=fs.readFileSync(file);
 assert.equal(content.toString('ascii',0,4),'RIFF');
 assert.equal(content.toString('ascii',8,16),'WEBPVP8 ');
 assert.ok(sql.includes(id),'Référencement serveur manquant: '+id);
}
assert.equal(world.roomOverrides.direction_usine.personsVides,true,'PNJ de Montrouge interdit par la surcharge');
// 15/11/2026 au soir : usine d'État (vente directe, vente de matières, production contre salaire).
assert.deepEqual(world.roomsExtra.salle_ventes_raffinerie.orders.map(o=>o.fn).join(),'vente_directe_usine,vendre_matiere_usine');
assert.deepEqual(world.roomsExtra.interieur_raffinerie.orders.map(o=>o.fn).join(),'produire_carburant,produire_derives_petrochimiques,vendre_matiere_usine');
assert.equal(base.rooms.direction_usine.orders.length,1,'Gabarit conservé');
console.log('Starovka : trois intérieurs VP8, noms et accès côté serveur, autres villes intactes.');
