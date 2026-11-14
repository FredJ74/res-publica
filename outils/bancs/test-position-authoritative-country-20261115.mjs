import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync(new URL('../../plateau-rue-centrale.js',import.meta.url),'utf8');
const begin=source.indexOf('async function initialiserRueCentrale(');
const end=source.indexOf('\nasync function afficherNoeudRue(',begin);
assert.ok(begin>0&&end>begin);
const soviet={ok:true,country:'soviet',city:'ville_b',building:null,room:null,street:'krasnov-rue-station-musee'};
const republic={ok:true,country:'republic',city:'capitale',building:null,room:null,street:'luthecia-palais-presidentiel'};
function simulation({country='republic',city='capitale',reply=soviet}={}){
 const events=[],toasts=[],authChar={name:'Arnie',country,currentCity:city};
 const state={char:authChar,country,currentCity:city,currentBuilding:null,currentRoom:null,_navigationServeur:false};
 const ctx={state,console,Promise,setTimeout:f=>f(),rueCentraleLecturePosition:0,
  WORLD:{republic:{capitale:{}},soviet:{ville_b:{}}},
  BUILDINGS:{'musee-novomirsk':{rooms:{hall:{}}}},
  RUE_CENTRALE_DEPART:{republic:{capitale:'luthecia-palais-presidentiel'},soviet:{ville_b:'krasnov-rue-gare'}},
  RUE_CENTRALE_NOEUDS:{republic:{'luthecia-palais-presidentiel':{}},soviet:{'krasnov-rue-station-musee':{},'krasnov-rue-gare':{}}},
  rueCentraleServeur:()=>true,
  contexteNavigationRue:()=>({actor:state.char,pays:state.country,ville:state.currentCity}),
  contexteNavigationRueValide:c=>c.actor===state.char&&c.pays===state.country&&c.ville===state.currentCity,
  sbRpc:async fn=>{events.push(fn);return reply;},
  afficherNoeudRue:async(...args)=>events.push(['render',...args]),
  forceRenderCity:ville=>events.push(['forceRenderCity',ville]),
  showToast:(...args)=>toasts.push(args)
 };
 vm.createContext(ctx);vm.runInContext(source.slice(begin,end),ctx);
 return {run:()=>ctx.initialiserRueCentrale(country,country==='republic'?'luthecia-palais-presidentiel':'krasnov-rue-gare'),state,events,toasts};
}
test('position soviétique valide : l empire republic obsolète est corrigé sans déplacer le PJ',async()=>{
 const s=simulation();await s.run();
 assert.equal(s.state.country,'soviet');
 assert.equal(s.state.currentCity,'ville_b');
 assert.equal(s.state.char.country,'soviet');
 assert.deepEqual(s.events,[ 'rue_position_lire', ['forceRenderCity','ville_b'] ]);
 assert.equal(s.toasts.length,0);
});
test('pays correct : affichage direct de la rue confirmée, sans réinit',async()=>{
 const s=simulation({country:'soviet',city:'ville_b'});await s.run();
 assert.deepEqual(s.events,[ 'rue_position_lire', ['render','soviet','krasnov-rue-station-musee',null,true] ]);
});
test('position inconnue : ne pas changer d empire',async()=>{
 const s=simulation({reply:{...soviet,street:'rue-inconnue'}});await s.run();
 assert.equal(s.state.country,'republic');
 assert.equal(s.events.length,1);
 assert.match(s.toasts[0][1],/inconnu/);
});
test('erreur d authentification : ne pas changer d empire',async()=>{
 const s=simulation({reply:{ok:false,raison:'non_authentifie'}});await s.run();
 assert.equal(s.state.country,'republic');
 assert.match(s.toasts[0][1],/Reconnectez-vous/);
});
