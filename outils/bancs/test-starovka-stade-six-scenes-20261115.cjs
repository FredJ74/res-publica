const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const s=fs.readFileSync('data.js','utf8');
const ctx={console};ctx.window=ctx;vm.createContext(ctx);
vm.runInContext(s+';this.B=BUILDINGS;this.W=WORLD;',ctx);
const star=ctx.W.soviet.ville_a.buildingContext.stade;
assert.ok(star,'stade Starovka');
const expected={
vestiaires:'vestiaires',bureau_president:'bureau_president',siege_supporters:'club_supporters',
buvette:'buvette',guichet_paris:'bookmaker'};
for(const [id,name] of Object.entries(expected)){
const room=star.roomOverrides[id];assert.ok(room,id);
const path='images/Sovarka/Starovka/Starovka_stade_'+name+'.webp';
assert.equal(room.imageUrl,path);
assert.ok(fs.existsSync(path),path);
assert.equal(fs.readFileSync(path).toString('ascii',0,4),'RIFF');
}
assert.equal(star.roomsExtra.boutique.imageUrl,'images/Sovarka/Starovka/Starovka_stade_boutique.webp');
assert.deepEqual(Array.from(star.roomsExtra.boutique.orders.map(x=>x.fn)),['choisir_accessoire_club','acheter_accessoire_personnalise']);
assert.ok(star.roomOverrides.buvette.excludeOrders.includes('choisir_accessoire_club'));
for(const city of ['capitale','ville_b']){
const context=ctx.W.soviet[city].buildingContext?.stade||{};
assert.notEqual(context.roomOverrides?.buvette?.imageUrl,star.roomOverrides.buvette.imageUrl);
}
assert.equal(ctx.B.stade.rooms.buvette.orders.length,5);
assert.equal(ctx.B.stade.rooms.guichet_paris.orders.length,2);
console.log('Six fonds vérifiés, six pièces, boutique séparée, trois villes isolées, ordres préservés');
