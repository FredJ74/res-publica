const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const ctx=vm.createContext({console});
vm.runInContext(fs.readFileSync('data.js','utf8')+';this.W=WORLD;this.B=BUILDINGS;',ctx);
const mairie=ctx.W.soviet.ville_a.buildingContext.mairie;
const marche=ctx.W.soviet.ville_a.buildingContext.marche;
const p='images/Sovarka/Starovka/';
const mappings=[
 [marche.roomOverrides.marche_ext,'Starovka_marche_marche_ext.webp'],
 [mairie.roomOverrides.accueil_mairie,'Starovka_mairie_accueil_mairie.webp'],
 [mairie.roomOverrides.bureau_maire_local,'Starovka_mairie_bureau_maire_local.webp'],
 [mairie.roomOverrides.bureau_maire_adjoint,'Starovka_mairie_bureau_maire_adjoint.webp'],
 [mairie.roomOverrides.salle_elections,'Starovka_mairie_salle_elections.webp'],
 [mairie.roomsExtra.salle_partis,'Starovka_mairie_salle_partis.webp']
];
for(const [piece,file] of mappings){
 assert.equal(piece.imageUrl,p+file);
 const contents=fs.readFileSync(p+file);
 assert.equal(contents.toString('ascii',0,4),'RIFF');
 assert.equal(contents.toString('ascii',8,12),'WEBP');
 assert.ok(contents.length>20000);
}
assert.ok(ctx.B.mairie.rooms.accueil_mairie.orders.some(o=>o.fn==='etat_civil'));
assert.ok(ctx.B.mairie.rooms.bureau_maire_local.orders.some(o=>o.requiresPost==='maire'));
assert.ok(ctx.B.mairie.rooms.bureau_maire_adjoint.orders.some(o=>o.requiresPost==='maire_adjoint'));
assert.ok(mairie.roomsExtra.salle_elections.orders.some(o=>o.fn==='voter_election'));
assert.ok(mairie.roomsExtra.salle_partis.orders.length>0);
assert.ok(marche.persons.some(p=>p.name.includes('Tsypilma Dashieva')));
for(const city of ['capitale','ville_b']){
 const m=ctx.W.soviet[city].buildingContext?.mairie;
 const market=ctx.W.soviet[city].buildingContext?.marche;
 for(const [piece,file] of mappings){
  assert.notEqual(m?.roomOverrides?.accueil_mairie?.imageUrl,p+file);
  assert.notEqual(m?.roomOverrides?.bureau_maire_local?.imageUrl,p+file);
  assert.notEqual(m?.roomOverrides?.bureau_maire_adjoint?.imageUrl,p+file);
  assert.notEqual(m?.roomOverrides?.salle_elections?.imageUrl,p+file);
  assert.notEqual(m?.roomsExtra?.salle_partis?.imageUrl,p+file);
  assert.notEqual(market?.roomOverrides?.marche_ext?.imageUrl,p+file);
 }
}
assert.equal(fs.readdirSync(p).filter(f=>f.toLowerCase().endsWith('.png')).length,0);
console.log('Starovka : six WebP valides et uniques, PNJ et ordres inchangés');
