const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const ctx=vm.createContext({console});vm.runInContext(fs.readFileSync('data.js','utf8')+';this.W=WORLD;this.B=BUILDINGS;',ctx);
const star=ctx.W.soviet.ville_a.buildingContext;
const p='images/Sovarka/Starovka/';
const photos=[
 [star['commissariat-local'].roomOverrides.accueil_loc,'Starovka_commissariat_accueil_loc.webp'],
 [star['commissariat-local'].roomOverrides.bureau_commissaire,'Starovka_commissariat_bureau_commissaire.webp'],
 [star['commissariat-local'].roomOverrides.geoles,'Starovka_commissariat_geoles.webp'],
 [star.universite.roomOverrides.amphi,'Starovka_lycee_amphi.webp'],
 [star.universite.roomsExtra.bibliotheque,'Starovka_lycee_bibliotheque.webp']
];
for(const [room,file] of photos){
 assert.equal(room.imageUrl,p+file);
 const bytes=fs.readFileSync(p+file);
 assert.equal(bytes.toString('ascii',0,4),'RIFF');assert.equal(bytes.toString('ascii',8,12),'WEBP');assert.ok(bytes.length>20000);
}
assert.deepEqual(Object.keys(star.universite.roomsExtra).filter(id=>id==='bibliotheque'),['bibliotheque']);
assert.deepEqual(Array.from(star.universite.roomsExtra.bibliotheque.orders),[]);
const pol=ctx.B['commissariat-local'].rooms;
assert.deepEqual(Array.from(Object.keys(pol)),['accueil_loc','geoles','bureau_commissaire']);
assert.ok(pol.accueil_loc.orders.some(o=>o.fn==='plainte_police'));
assert.ok(pol.bureau_commissaire.orders.some(o=>o.requiresPost==='commissaire'));
assert.ok(star['commissariat-local'].roomOverrides.bureau_commissaire.persons.some(x=>x.name.includes('Bato Dashiev')));
assert.ok(star.universite.roomOverrides.amphi.persons.some(x=>x.name.includes('Darima Zhambalova')));
assert.ok(ctx.B.universite.rooms.salle_reunion.orders.length>0);
for(const city of ['capitale','ville_b']){
 const cityctx=ctx.W.soviet[city].buildingContext || {};
 for(const [room,file] of photos){
  for(const k of ['accueil_loc','bureau_commissaire','geoles']){
   assert.notEqual(cityctx['commissariat-local']?.roomOverrides?.[k]?.imageUrl,p+file);
  }
  assert.notEqual(cityctx.universite?.roomOverrides?.amphi?.imageUrl,p+file);
  assert.notEqual(cityctx.universite?.roomsExtra?.bibliotheque?.imageUrl,p+file);
 }
}
assert.equal(fs.readdirSync(p).filter(x=>x.toLowerCase().endsWith('.png')).length,0);
console.log('Cinq images WebP, objets locaux, PNJ et commandes préservés : OK');
