const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const src=fs.readFileSync('plateau-justice-economie.js','utf8');
const debut=src.indexOf('let URBANISME_DECISION_EN_COURS=false;'),fin=src.indexOf('async function doConsulterDossiersUrbanisme',debut);
function jeu(){
 const stockage=new Map(),appels=[],effets=[];
 const c={state:{country:'republic'},contexteNavigationRue:()=>({uid:'fixture',nom:'Fixture'}),valide:true,contexteNavigationRueValide:()=>c.valide,
 crypto:require('node:crypto'),sessionStorage:{getItem:k=>stockage.get(k)||null,setItem:(k,v)=>stockage.set(k,v),removeItem:k=>stockage.delete(k)},
 showToast:()=>{},sbRpcVerdict:async(fn,p)=>{appels.push({fn,p});return c.reponse;},reponse:{ok:true},
 sbGetTerrainState:async()=>({permis:{statut:'valide'}}),commercePjActualiserPersonnage:async()=>true,
 remplacerTerrainState:()=>effets.push('terrain'),updateUI:()=>{},doTraiterDemandesPermis:()=>effets.push('liste'),document:{getElementById:()=>null}};
 vm.createContext(c);vm.runInContext(src.slice(debut,fin),c);return{c,stockage,appels,effets};
}
test('decision : une seule commande, aucun paiement ou document client',async()=>{
 const f=jeu();await f.c.traiterPermis('terrain',true,999,999);assert.equal(f.appels.length,1);assert.equal(f.appels[0].fn,'terrain_permis_decider');
 assert.equal(f.stockage.size,0);assert.deepEqual(f.effets,['terrain','liste']);assert.equal(f.appels[0].p.p_patch,undefined);
});
test('refus sans motif : aucun appel serveur',async()=>{const f=jeu();await f.c.traiterPermis('terrain',false,1,0,'court');assert.equal(f.appels.length,0);});
test('perte de reponse : intention conservee, changement refuse, reprise identique',async()=>{
 const f=jeu();f.c.reponse={ok:false,transport:{etat:'indetermine'}};await f.c.traiterPermis('terrain',true,1,0);const id=f.appels[0].p.p_requete;
 await f.c.traiterPermis('terrain',false,1,0,'Refus suffisamment motive');assert.equal(f.appels.length,1);
 f.c.reponse={ok:true,rejeu:true};await f.c.traiterPermis('terrain',true,1,0);assert.equal(f.appels[1].p.p_requete,id);assert.equal(f.stockage.size,0);
});
test('double clic : une seule commande en cours',async()=>{
 const f=jeu();let finir;f.c.sbRpcVerdict=async(fn,p)=>{f.appels.push(p);return new Promise(r=>finir=r);};
 const a=f.c.traiterPermis('terrain',true,1,0);await f.c.traiterPermis('terrain',true,1,0);assert.equal(f.appels.length,1);finir({ok:true});await a;
});
test('reponse tardive : aucun effet sur le nouveau contexte',async()=>{
 const f=jeu();let finir;f.c.sbRpcVerdict=()=>new Promise(r=>finir=r);const a=f.c.traiterPermis('terrain',true,1,0);f.c.valide=false;finir({ok:true});await a;
 assert.equal(f.effets.length,0);assert.equal(f.stockage.size,1);
});
test('relecture incomplete : aucune fausse actualisation',async()=>{
 const f=jeu();f.c.commercePjActualiserPersonnage=async()=>false;await f.c.traiterPermis('terrain',true,1,0);assert.equal(f.effets.length,0);assert.equal(f.stockage.size,1);
});
test('cron : service serveur, refus visibles, aucune ecriture REST de dossier',async()=>{
 const cron=fs.readFileSync('api/cron-minuit.js','utf8'),a=cron.indexOf('async function traiterInstructionsPermis()'),b=cron.indexOf('// VERROU DU PLAN ET LIVRAISON',a);
 const appels=[],erreurs=[],service={fixture:'serveur'},c={HEADERS_SERVICE:service,sbGet:async()=>[{id:'a'},{id:'b'},{id:'c'}],sbRpc:async(fn,p,h)=>{appels.push({fn,p,h});return p.p_terrain_id==='a'?{ok:true,accord_tacite:true,instruit:true}:p.p_terrain_id==='b'?{ok:true,rejeu:true}:null;},signalerEchec:(...a)=>erreurs.push(a)};
 vm.createContext(c);vm.runInContext(cron.slice(a,b),c);const r=await c.traiterInstructionsPermis();
 assert.equal(appels.length,3);assert(appels.every(x=>x.fn==='terrain_permis_instruction_jour'&&x.h===service));assert.equal(r.accords_tacites,1);assert.equal(r.ignores,1);assert.equal(r.echecs_archive,1);assert.equal(erreurs.length,1);
});
