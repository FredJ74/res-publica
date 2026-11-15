const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const data=fs.readFileSync('data.js','utf8');
const ctx={console,window:{}};vm.createContext(ctx);vm.runInContext(data+';this.W=WORLD;this.B=BUILDINGS;',ctx);
const root='images/Sovarka/Starovka/';
const map=[
 ['centre-affaires','tribune_republia','Starovka_centre-affaires_tribune_republia.webp'],
 ['locaux-starovka','local_1','Starovka_locaux-starovka_local_1.webp']
];
for(const [building,room,name] of map){
 const item=building==='locaux-starovka'?ctx.B[building].rooms[room]:ctx.W.soviet.ville_a.buildingContext[building].roomOverrides[room];
 assert.equal(item.imageUrl,root+name);
 const b=fs.readFileSync(root+name);
 assert.equal(b.toString('ascii',0,4),'RIFF');assert.equal(b.toString('ascii',8,12),'WEBP');
 assert.ok(b.length>10000);
}
assert.ok(ctx.B['locaux-starovka'].rooms.local_1.orders.some(o=>o.fn==='sovarka_demande_location'));
assert.ok(ctx.B['locaux-starovka'].rooms.local_1.orders.some(o=>o.fn==='commerce_pj'));
assert.ok(ctx.B['locaux-starovka'].rooms.local_2.imageUrl===undefined);
assert.ok(ctx.W.soviet.ville_a.buildingContext['centre-affaires'].roomOverrides.tribune_republia.persons.some(x=>x.name.includes('Saran Batbayar')));
assert.notEqual(ctx.W.soviet.ville_b.buildingContext?.['centre-affaires']?.roomOverrides?.tribune_republia?.imageUrl,root+map[0][2]);
const street=fs.readFileSync('plateau-rue-centrale.js','utf8');
const block=street.slice(street.indexOf("'starovka-rue-blizzard':"),street.indexOf("'starovka-rue-mairie-marche':",street.indexOf("'starovka-rue-blizzard':")));
assert.ok(block.includes("buildingId: 'locaux-starovka'"));
assert.ok(block.includes("buildingId: 'centre-affaires'"));
assert.equal(fs.readdirSync(root).filter(x=>x.toLowerCase().endsWith('.png')).length,0);
console.log('Deux WebP, pièces, PNJ, loyers et zones de rue : OK');
