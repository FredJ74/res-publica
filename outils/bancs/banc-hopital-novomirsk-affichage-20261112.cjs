// Régression : la seconde définition de l'hôpital de Novomirsk écrasait
// silencieusement les images, les PNJ et la nouvelle pièce Chambre (12/11/2026).
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const src=fs.readFileSync(path.join(root,'data.js'),'utf8');
const scope=vm.createContext({});
vm.runInContext(src,scope);
const actual=vm.runInContext('WORLD.soviet.capitale.buildingContext["dispensaire-public"]',scope);
const source=vm.runInContext('BUILDINGS["dispensaire-public"]',scope);
assert.equal(actual.name,'Hôpital public de Novomirsk');
assert.deepEqual(Object.keys({...source.rooms,...actual.roomsExtra}),['salle_attente','ehpad_tilleuls','chambre']);
for(const [key,file] of Object.entries({
  salle_attente:'Novomirsk_hopital_acceuil.webp',
  ehpad_tilleuls:'Novomirsk_hopital_EPHAD.webp',
  chambre:'Novomirsk_hopital_chambre.webp',
})){
  const salle=actual.roomOverrides[key]||actual.roomsExtra[key];
  assert.equal(salle.imageUrl,'images/Sovarka/Novomirsk/'+file,key);
  assert.ok(fs.statSync(path.join(root,salle.imageUrl)).size>20000,key);
  assert.equal(fs.existsSync(path.join(root,salle.imageUrl.replace(/\.webp$/,'.png'))),false,key);
}
assert.equal(actual.roomOverrides.salle_attente.persons.length,2);
assert.equal(actual.roomOverrides.ehpad_tilleuls.persons.length,3);
const sovarka=actual.roomOverrides.ehpad_tilleuls.persons.map(p=>p.name);
assert.ok(sovarka.includes('Antonina Doubrova (PNJ)'));
assert.equal(vm.runInContext('WORLD.republic.capitale.buildingContext["dispensaire-public"].roomOverrides?.salle_attente?.imageUrl',scope),undefined);
const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
assert.match(html,/data\.js\?v=[^"]*hopital-novomirsk-doublon-corrige-20261112/);
console.log('OK: 3 pièces visibles dans WORLD, 3 WebP présents, 2 soignants, 3 pensionnaires, Republia inchangée.');
