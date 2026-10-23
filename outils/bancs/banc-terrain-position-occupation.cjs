const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('plateau-navigation.js','utf8');
const a=source.indexOf("  // L'occupation exige la position SERVEUR"),b=source.indexOf('  // Réinitialiser le cache des vrais joueurs',a);
function contexte(){
 let terminer;const appels=[],rendus=[];
 const c={state:{char:{name:'Fixture'},country:'republic',currentCity:'capitale',currentBuilding:'terrain-a-batir-5',currentRoom:'terrain'},buildingId:'terrain-a-batir-5',roomId:'terrain',positionEcriteSurLeServeur:new Promise(r=>terminer=r),rpAuthUid:()=> 'fixture',chargerPnjTerrain:async id=>{appels.push(id);return true},BUILDINGS:{'terrain-a-batir-5':{rooms:{terrain:{persons:[]}}}},sessionStorage:{getItem:()=>null},renderPersonsList:()=>rendus.push('occupant'),renderRoomActions:()=>rendus.push('ordres')};
 vm.runInNewContext(source.slice(a,b),c);return {c,appels,rendus,terminer};
}
const finir=()=>new Promise(r=>setImmediate(r));
test('occupation apres la position serveur et rafraichissement conjoint',async()=>{
 const x=contexte();assert.equal(x.appels.length,0);x.terminer();await finir();
 assert.deepEqual(x.appels,['terrain-a-batir-5']);assert.deepEqual(x.rendus,['occupant','ordres']);
});
test('navigation ou changement de compte avant sauvegarde : aucune lecture tardive',async()=>{
 for(const changer of [c=>c.state.currentBuilding='ailleurs',c=>c.state.char={name:'Autre'},c=>c.rpAuthUid=()=> 'autre',c=>c.state.currentCity='ville_a',c=>c.state.currentRoom='lot_dyn_a']){
  const x=contexte();changer(x.c);x.terminer();await finir();assert.equal(x.appels.length,0);assert.equal(x.rendus.length,0);
 }
});
