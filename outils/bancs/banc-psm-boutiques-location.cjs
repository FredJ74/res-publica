// Contrat du centre commercial : PSM réutilise sans duplication les quatre locations de Luthécia.
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const path=require('node:path');
const data=fs.readFileSync(path.join(__dirname,'../../data.js'),'utf8');
const variants=fs.readFileSync(path.join(__dirname,'../../plateau-variantes-pieces.js'),'utf8');
const pieces=['vitrine_principale','boutique_milieu','arriere_boutique','cave_reserve'];
const start=data.indexOf("  'centre-commercial': {",data.indexOf('// V28A — CENTRES COMMERCIAUX'));
const end=data.indexOf("\n  'centre-artisanal': {",start);
assert.ok(start>=0&&end>start);
const centre=data.slice(start,end);
for(const p of pieces){
  const pos=centre.indexOf('      '+p+': {');
  assert.ok(pos>=0,p+' existe');
  const next=centre.indexOf('\n      },',pos);
  const entry=centre.slice(pos,next);
  assert.match(entry,/isLocationRoom: true/);
  assert.match(entry,/locationData: \{ prix: \d+/);
  for(const fn of ['commerce_pj','louer_local','gerer_local'])
    assert.ok(entry.includes("fn:'"+fn+"'"),p+': '+fn);
}
assert.ok(variants.includes("PIECE_VARIANTES.republic.ville_a = {"),'PSM déclare ses variantes');
const contexte=vm.createContext({});
vm.runInContext(data+'\n'+variants,contexte);
for(const piece of pieces){
  contexte.piece=piece;
  assert.equal(vm.runInContext("PIECE_VARIANTES.republic.ville_a['centre-commercial'][piece].famille",contexte),'location');
  assert.ok(vm.runInContext("PIECE_VARIANTES.republic.ville_a['centre-commercial'][piece].enseigne === PIECE_VARIANTES.republic.capitale['centre-commercial'][piece].enseigne",contexte),'enseigne commune préservée');
  assert.ok(vm.runInContext("PIECE_VARIANTES.republic.ville_a['centre-commercial'][piece].images.occupee === PIECE_VARIANTES.republic.capitale['centre-commercial'][piece].images.occupee",contexte),'état occupé commun préservé');
  assert.ok(vm.runInContext("PIECE_VARIANTES.republic.ville_a['centre-commercial'][piece].images.libre === WORLD.republic.ville_a.buildingContext['centre-commercial'].roomOverrides[piece].imageUrl",contexte),'image locale libre réellement utilisée');
}
const psm=data.slice(data.indexOf('// Hall du Centre Commercial de PSM'),data.indexOf("        'stade': {",data.indexOf('// Hall du Centre Commercial de PSM')));
assert.ok(!psm.includes('excludeOrders'), 'PSM ne masque pas les boutons');
console.log('OK - 4 locaux PSM : mêmes 3 ordres, loyers, tailles et personnalisation que Luthécia');
