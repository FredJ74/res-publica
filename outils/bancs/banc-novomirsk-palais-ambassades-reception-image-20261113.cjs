'use strict';
const {test}=require('node:test'), assert=require('node:assert/strict'), fs=require('node:fs'), path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
const ctx={};vm.createContext(ctx);vm.runInContext(source+'\nthis.HG_WORLD=WORLD;this.HG_BUILDINGS=BUILDINGS;',ctx);
test('Novomirsk : aucun doublon de salle de réception au Palais des Ambassades',()=>{
 const palais=ctx.HG_BUILDINGS['palais-ambassades-novomirsk'];
 assert.ok(palais,'Palais présent');
 assert.equal(palais.rooms.salle_reception,undefined,'la salle ne doit pas exister au Palais');
 assert.equal(Object.keys(palais.rooms).length,4,'quatre pièces seulement au Palais');
});
test('La salle de réception de Novomirsk conserve son image au Pavillon',()=>{
 const pavillon=ctx.HG_BUILDINGS['pavillon-ambassadeurs-novomirsk'];
 const room=pavillon?.rooms?.salle_reception;
 assert.ok(room,'salle présente au Pavillon');
 assert.equal(room.imageUrl,'images/Sovarka/Novomirsk/Novomirsk_pavillon_ambassadeurs_salle_reception.webp');
 assert.ok(fs.statSync(path.join(root,room.imageUrl)).size>1000,'WebP du Pavillon existant');
});
test('Luthécia conserve sa propre salle et son image',()=>{
 const room=ctx.HG_BUILDINGS['quartier-ambassades'].rooms.salle_reception;
 assert.ok(room);
 assert.equal(room.imageUrl,'images/ambassades-salle-reception.webp');
 assert.ok(fs.statSync(path.join(root,room.imageUrl)).size>1000);
});
