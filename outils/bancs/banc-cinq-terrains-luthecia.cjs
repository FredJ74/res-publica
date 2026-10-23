#!/usr/bin/env node
// Garde statique : les cinq parcelles de la Châtaigneraie partagent leurs mécaniques.
const assert=require('node:assert/strict'),fs=require('node:fs');
const src=fs.readFileSync('data.js','utf8');
const keys=[1,2,3,4,5];
const attendu={1:[2150,25800],2:[2300,27600],3:[2300,27600],4:[1850,22200],5:[2750,33000]};
const variants=[];
for(const n of keys){
  const start=src.search(new RegExp("^  'terrain-a-batir-"+n+"': \\\\{",'m'));
  assert.ok(start>=0,'terrain declare : '+n);
  const rest=src.slice(start+4);
  const end=rest.search(/^  '[^']+': \\{/m);
  const section=end>=0?rest.slice(0,end):rest;
  assert.match(section,/rooms: \\{\\s*terrain: \\{/,'piece terrain canonique '+n);
  const orders=[...section.matchAll(/fn:'([^']+)'/g)].map(x=>x[1]);
  assert.equal(new Set(orders).size,orders.length,'pas d ordre double : '+n);
  const [surface,prix]=attendu[n];
  assert.ok(section.includes(surface+' m²'),'surface preservee '+n);
  assert.match(section,new RegExp('cost:'+prix+', type:\\'legal\\', icon:\\'ti-home-plus\\''),'prix preserve '+n);
  const images=[...section.matchAll(/imageUrl: "([^"]+)"/g)].map(x=>x[1]);
  assert.equal(images.length,1,'une image terrain '+n);
  variants.push({n,orders,images});
}
for(const x of variants.slice(1)){
  assert.deepEqual(x.orders,variants[0].orders,'memes ordres et memes positions lot '+x.n);
  assert.deepEqual(x.images,variants[0].images,'meme image lot '+x.n);
}
for(const fn of ['appeler_police_terrain','negocier_squatteurs','faire_disparaitre_cadavre','signer_compromis','acheter_terrain','construire_sur_terrain','payer_versement_chantier','travailler_chantier','modifier_plan_chantier','diviser_construction','reconfigurer_lots','louer_lot_ici'])
  assert.ok(variants[0].orders.includes(fn),'ordre requis : '+fn);
console.log('OK : 5 terrains, 21 ordres identiques, image identique, pieces canoniques, superficies et prix conserves');
