const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ctx=vm.createContext({console});vm.runInContext(fs.readFileSync('data.js','utf8')+';this.W=WORLD;this.B=BUILDINGS;',ctx);
const local=ctx.W.soviet.ville_a.buildingContext.universite;
assert.ok(local.roomsExclues.includes('salle_reunion'));
assert.ok(local.roomOverrides.amphi.imageUrl.endsWith('Starovka_lycee_amphi.webp'));
assert.ok(local.roomsExtra.bibliotheque.imageUrl.endsWith('Starovka_lycee_bibliotheque.webp'));
for(const ville of ['capitale','ville_b']){
 assert.ok(!ctx.W.soviet[ville].buildingContext?.universite?.roomsExclues?.includes('salle_reunion'));
}
assert.ok(ctx.B.universite.rooms.salle_reunion.orders.length>0,'Autres universités inchangées');
console.log('Starovka : salle de réunion exclue, amphi et bibliothèque maintenus');
