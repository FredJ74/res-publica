const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ctx={console};ctx.window=ctx;vm.createContext(ctx);
vm.runInContext(fs.readFileSync('data.js','utf8')+';this.W=WORLD;this.B=BUILDINGS;',ctx);
const p='images/Sovarka/Starovka/';
const mapping=[
 ['capitaine-sauvage','salle_principale','Starovka_restaurant_entre_terre_mer_salle_principale.webp'],
 ['fourreur-starovka','boutique_fourreur','Starovka_fourreur_boutique_fourreur.webp']
];
for(const [building,room,name] of mapping){
 const piece=building==='fourreur-starovka' ? ctx.B[building].rooms[room] : ctx.W.soviet.ville_a.buildingContext[building].roomOverrides[room];
 assert.equal(piece.imageUrl,p+name);
 const bytes=fs.readFileSync(p+name);
 assert.equal(bytes.toString('ascii',0,4),'RIFF');
 assert.equal(bytes.toString('ascii',8,12),'WEBP');
 assert.ok(bytes.length>20000);
 for(const city of ['capitale','ville_b']){
  if(building==='fourreur-starovka') assert.ok(!ctx.W.soviet[city].buildings.includes(building));
  assert.notEqual(ctx.W.soviet[city].buildingContext?.[building]?.roomOverrides?.[room]?.imageUrl,p+name);
 }
}
const c=ctx.W.soviet.ville_a.buildingContext['capitaine-sauvage'];
assert.ok(c.roomOverrides.salle_principale.persons.some(x=>x.name.includes('Sesegma Badmaeva')));
assert.ok(ctx.B['capitaine-sauvage'].rooms.salle_principale.orders.length>0);
assert.equal(fs.readdirSync(p).filter(n=>n.endsWith('.png')).length,0);
console.log('Commerces Starovka : deux WebP valides, autres villes isolées, PNJ et ordres conservés.');
