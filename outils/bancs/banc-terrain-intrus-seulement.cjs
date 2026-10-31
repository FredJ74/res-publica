const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const d=fs.readFileSync('data.js','utf8'),p=fs.readFileSync('plateau-pnj.js','utf8');
const a=d.indexOf('const TERRAIN_PNJ_PROFILES ='),b=d.indexOf('// =====================\n// SYSTÈME ÉLECTORAL',a);
const catalogue=vm.runInNewContext(d.slice(a,b)+';({profils:TERRAIN_PNJ_PROFILES,police:TERRAIN_POLICE_PROFILES});');
test('quatre occupations a 25 pour cent dans les quatre pays, police hors tirage',()=>{
 for(const [pays,profils] of Object.entries(catalogue.profils)){
  assert.deepEqual(Array.from(profils,x=>x.id).sort(),['cadavre','squatter_agr','squatter_cool','vide']);
  assert.ok(profils.every(x=>x.prob===0.25));assert.equal(profils.reduce((s,x)=>s+x.prob,0),1);
  assert.ok(!profils.some(x=>x.id==='inspecteur_police'));
 }
});
test('ancien point entree : aucun tirage client ni profil supprime',()=>{
 const a=p.indexOf('function genererPnjTerrain('),b=p.indexOf('async function interagirPnjTerrain',a);
 for(const pays of Object.keys(catalogue.profils))for(const occupation of [null,'vide','agent','promoteur','gardien','inspecteur','cadavre','squatter_cool','squatter_agr']){
  const ctx={state:{country:pays},getTerrainState:()=>({pnj:occupation}),TERRAIN_PNJ_PROFILES:catalogue.profils,Math:{random(){throw Error('tirage client interdit')}}};
  const c=p.indexOf('function profilOccupationTerrain('),d=p.indexOf('function terrainOrdreDisponible',c);
  vm.createContext(ctx);vm.runInContext(p.slice(c,d)+p.slice(a,b),ctx);const v=ctx.genererPnjTerrain('terrain-a-batir-1');
  assert.equal(!!v,['cadavre','squatter_cool','squatter_agr'].includes(occupation));
  if (['squatter_cool','squatter_agr'].includes(occupation))assert.equal(v.name,'squatteurs');
 }
});
