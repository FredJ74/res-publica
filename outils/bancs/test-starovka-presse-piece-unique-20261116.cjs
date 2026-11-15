const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ctx={console};ctx.window=ctx;vm.createContext(ctx);
vm.runInContext(fs.readFileSync('data.js','utf8')+';this.W=WORLD;this.B=BUILDINGS;',ctx);
const presse=ctx.B['presse-starovka'];
assert.ok(presse);
assert.deepEqual(Object.keys(presse.rooms),['presse']);
const salle=presse.rooms.presse;
assert.equal(salle.imageUrl,'images/Sovarka/Starovka/Starovka_centre-affaires_tribune_republia.webp');
assert.ok(fs.existsSync(salle.imageUrl));
const base=ctx.B['centre-affaires'].rooms.tribune_republia;
assert.deepEqual(Array.from(salle.orders.map(x=>x.fn)),Array.from(base.orders.map(x=>x.fn)),'ordres presse conservés');
assert.ok(salle.persons.some(x=>x.name.includes('Saran Batbayar')));
assert.ok(ctx.W.soviet.ville_a.buildings.includes('presse-starovka'));
assert.ok(ctx.W.soviet.ville_a.buildingContext['centre-affaires'].roomsExclues.includes('tribune_republia'));
for(const ville of ['capitale','ville_b']){
 assert.ok(!ctx.W.soviet[ville].buildings.includes('presse-starovka'));
 // Ne pas modifier les règles existantes du centre d'affaires de cette autre ville.
}
const src=fs.readFileSync('plateau-rue-centrale.js','utf8'),i=src.indexOf("'starovka-rue-blizzard':");
const part=src.slice(i,src.indexOf("'starovka-rue-mairie-marche':",i));
assert.ok(part.includes("buildingId: 'presse-starovka'"));
assert.ok(!part.includes("buildingId: 'centre-affaires'"));
console.log('Presse de Starovka : une pièce, aucun hall/bureau, image et ordres conservés');
