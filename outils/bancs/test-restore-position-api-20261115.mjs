import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import vm from 'node:vm';
const code=fs.readFileSync(new URL('../../plateau-rue-centrale.js',import.meta.url),'utf8');
const debut=code.indexOf('async function initialiserRueCentrale(');
const fin=code.indexOf('\nasync function afficherNoeudRue(',debut);
assert.ok(debut>=0 && fin>debut);
function scenario(reponses,{groupe=false,auth='ok'}={}){
  const history=[],toasts=[],state={char:{name:'Arnie'},country:'soviet',currentCity:'ville_b',currentBuilding:null,currentRoom:null,_navigationServeur:groupe};
  const ctx={
    state,window:{}, console,Promise,
    rueCentraleLecturePosition:0,
    RUE_CENTRALE_NOEUDS:{soviet:{'krasnov-rue-station-musee':{}}},
    RUE_CENTRALE_DEPART:{soviet:{ville_b:'krasnov-rue-gare'}},
    rueCentraleServeur:()=>true,
    contexteNavigationRue:()=>({personnage:state.char,nom:state.char.name,pays:state.country,ville:state.currentCity,batiment:state.currentBuilding,piece:state.currentRoom,uid:auth}),
    contexteNavigationRueValide:c=>state.char===c.personnage&&state.country===c.pays&&state.currentCity===c.ville,
    sbRpc:async(fn,args)=>{history.push(fn);return reponses.shift()??null;},
    setTimeout:fn=>fn(),
    afficherNoeudRue:async(...args)=>history.push(['render',...args]),
    showToast:(...args)=>toasts.push(args)
  };
  if(groupe){
    ctx.sbGroupePjLire=async()=>null;
    ctx.sbPositionNavigationConfirmee=()=>null;
  }
  vm.createContext(ctx);
  vm.runInContext(code.slice(debut,fin),ctx);
  return {run:()=>ctx.initialiserRueCentrale('soviet','krasnov-rue-gare',null),history,toasts,state};
}
const point={ok:true,country:'soviet',city:'ville_b',building:null,room:null,street:'krasnov-rue-station-musee'};
test('échec réseau temporaire : nouvelle lecture canonique sans mutation',async()=>{
 const s=scenario([null,null,point]);
 await s.run();
 assert.equal(s.history.filter(x=>x==='rue_position_lire').length,3);
 assert.deepEqual(s.history.find(x=>Array.isArray(x)),['render','soviet','krasnov-rue-station-musee',null,true]);
 assert.equal(s.toasts.length,0);
 assert.equal(s.state.currentBuilding,null);
});
test('vue de groupe indisponible : reprise serveur directe',async()=>{
 const s=scenario([point],{groupe:true});
 await s.run();
 assert.deepEqual(s.history.find(x=>Array.isArray(x)),['render','soviet','krasnov-rue-station-musee',null,true]);
});
test('session explicitement expirée : aucun martèlement ni téléportation',async()=>{
 const s=scenario([{ok:false,raison:'non_authentifie'}]);
 await s.run();
 assert.equal(s.history.filter(x=>x==='rue_position_lire').length,1);
 assert.equal(s.history.some(x=>Array.isArray(x)),false);
 assert.match(s.toasts[0][1],/Reconnectez-vous/);
});
test('panne persistante : seulement trois lectures, aucune écriture',async()=>{
 const s=scenario([null,null,null]);
 await s.run();
 assert.equal(s.history.length,3);
 assert.equal(s.history.every(x=>x==='rue_position_lire'),true);
 assert.equal(s.toasts.length,1);
});
