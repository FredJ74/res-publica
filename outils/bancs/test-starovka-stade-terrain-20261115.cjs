const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const source=fs.readFileSync('data.js','utf8');
const ctx={console};ctx.window=ctx;vm.createContext(ctx);
vm.runInContext(source+';this.B=BUILDINGS;this.W=WORLD;',ctx);
const chemin='images/Sovarka/Starovka/Starovka_stade_terrain.webp';
const star=ctx.W.soviet.ville_a.buildingContext.stade;
assert.equal(star.roomOverrides.terrain.imageUrl,chemin);
const blob=fs.readFileSync(chemin);
assert.equal(blob.toString('ascii',0,4),'RIFF');assert.equal(blob.toString('ascii',8,12),'WEBP');
assert.equal(fs.readdirSync('images/Sovarka/Starovka').filter(f=>f.toLowerCase().endsWith('.png')).length,0);
assert.equal(ctx.B.stade.rooms.terrain.orders.length,2);
for(const c of ['capitale','ville_b']){
assert.notEqual(ctx.W.soviet[c].buildingContext?.stade?.roomOverrides?.terrain?.imageUrl,chemin);
}
for(const c of Object.values(ctx.W.republic)){
assert.notEqual(c.buildingContext?.stade?.roomOverrides?.terrain?.imageUrl,chemin);
}
console.log('Terrain image WebP, PNG absent, ordres et isolation villes vérifiés');
