'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('plateau-navigation.js','utf8');
const debut=source.indexOf('async function commanderNavigationInterieure('),fin=source.indexOf('\n}\n',debut)+2;
assert.ok(debut>=0&&fin>debut);
function decor(verdict){
 const compte={rpc:0,relectures:0,rendus:0,entrees:0,messages:[]};
 const state={country:'soviet',currentCity:'ville_a',currentBuilding:null,pa:20,liquide:100,char:{name:'Visiteur'}};
 const c=vm.createContext({state,contexteNavigationRue:()=>({}),contexteNavigationRueValide:()=>true,
  sbRpcVerdict:async()=>{compte.rpc++;await new Promise(r=>setTimeout(r,10));return verdict;},
  sbLoadPersonnage:async()=>{compte.relectures++;state.currentBuilding=verdict.goulag_arrestation.arrete?'qhs-prison':'hotel-mineur';},
  showToast:(_titre,message)=>compte.messages.push(message),updateUI:()=>compte.rendus++,
  enterBuilding:()=>compte.entrees++,enterRoom:()=>compte.entrees++});
 vm.runInContext('let navigationInterieureEnCours=null,navigationInterieureRendu=null;\n'+source.slice(debut,fin),c);
 return {c,compte,state};
}
for(const arrete of [true,false])test(arrete?'arrestation personnelle : position relue, aucune entrée cliente fictive':'membre arrêté : chef relu sans afficher sa propre condamnation',async()=>{
 const d=decor({ok:true,goulag_arrestation:{ok:true,arrete}});
 assert.equal(await d.c.commanderNavigationInterieure('hotel-mineur','hall_mineur'),false);
 assert.equal(d.compte.rpc,1);assert.equal(d.compte.relectures,1);assert.equal(d.compte.entrees,0);assert.equal(d.compte.rendus,1);
 assert.equal(d.state.pa,20);assert.equal(d.state.liquide,100);
 assert.match(d.compte.messages[0],arrete?/vous ont arrêté/:/membre de votre groupe/);
});
test('entrée ordinaire : même navigation, aucun rechargement ni dépense',async()=>{
 const d=decor({ok:true,building:'hotel-mineur',room:'hall_mineur',membres:['Visiteur'],positions:[{name:'Visiteur',country:'soviet',city:'ville_a',building:'hotel-mineur',room:'hall_mineur',street:null}]});
 assert.equal(await d.c.commanderNavigationInterieure('hotel-mineur','hall_mineur'),true);
 assert.equal(d.compte.rpc,1);assert.equal(d.compte.relectures,0);assert.equal(d.compte.entrees,2);assert.equal(d.state.pa,20);assert.equal(d.state.liquide,100);
});
test('double clic arrêté : une seule mutation et une seule relecture',async()=>{
 const d=decor({ok:true,goulag_arrestation:{ok:true,arrete:true}});
 await Promise.all([d.c.commanderNavigationInterieure('hotel-mineur','hall_mineur'),d.c.commanderNavigationInterieure('hotel-mineur','hall_mineur')]);
 assert.equal(d.compte.rpc,1);assert.equal(d.compte.relectures,1);
});
