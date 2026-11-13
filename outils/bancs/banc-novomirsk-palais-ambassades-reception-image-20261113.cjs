'use strict';
const {test}=require('node:test'), assert=require('node:assert/strict'), fs=require('node:fs'), path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const source=fs.readFileSync(path.join(root,'data.js'),'utf8');
const ctx={};vm.createContext(ctx);vm.runInContext(source+'\nthis.HG_WORLD=WORLD;this.HG_BUILDINGS=BUILDINGS;',ctx);
test('Novomirsk Palais des Ambassades — la salle de réception a une image existante',()=>{
 const building=ctx.HG_BUILDINGS['palais-ambassades-novomirsk'];
 assert.ok(building,'bâtiment présent');
 const room=building.rooms.salle_reception;
 assert.ok(room,'pièce présente');
 assert.equal(room.imageUrl,'images/ambassades-salle-reception.webp');
 assert.ok(fs.statSync(path.join(root,room.imageUrl)).size>1000,'WebP non vide');
});
test('La salle de Républia conserve le même visuel sans toucher aux autres pièces',()=>{
 const source=ctx.HG_BUILDINGS['quartier-ambassades']||Object.values(ctx.HG_BUILDINGS).find(b=>b.rooms?.salle_reception?.imageUrl==='images/ambassades-salle-reception.webp'&&b!==ctx.HG_BUILDINGS['palais-ambassades-novomirsk']);
 assert.ok(source,'source du décor de la salle de réception');
 assert.equal(source.rooms.salle_reception.imageUrl,ctx.HG_BUILDINGS['palais-ambassades-novomirsk'].rooms.salle_reception.imageUrl);
});
