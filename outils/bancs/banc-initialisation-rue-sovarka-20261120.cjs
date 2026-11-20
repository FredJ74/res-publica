#!/usr/bin/env node
// Banc du correctif Tom Tom : exerce le vrai corps d'initialiserRueCentrale
// sans réseau ni écriture serveur. Ne fait aucun mouvement de personnage.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('plateau-rue-centrale.js','utf8');
const debut=source.indexOf('async function initialiserRueCentrale(');
const fin=source.indexOf('\nasync function afficherNoeudRue(',debut);
assert.ok(debut>=0 && fin>debut,'Initialiseur de rue introuvable');
const code=source.slice(debut,fin);
const departs={
 republic:{capitale:'luthecia-palais-presidentiel',ville_a:'psm-centre-multimodal',ville_b:'montrouge-vue-3'},
 soviet:{capitale:'novomirsk-vue-1',ville_a:'starovka-rue-gare',ville_b:'krasnov-rue-gare'}
};
(async()=>{
 for(const [pays,villes] of Object.entries(departs)){
  for(const [ville,depart] of Object.entries(villes)){
   const appels=[],etat={char:{name:'Banc'},country:pays,currentCity:ville,currentBuilding:null,currentRoom:null};
   const contexte={
    state:etat,rueCentraleLecturePosition:0,
    contexteNavigationRue:()=>({}),
    contexteNavigationRueValide:()=>true,
    rueCentraleServeur:()=>true,
    sbRpc:async()=>({ok:true,country:pays,city:ville,building:null,street:null}),
    RUE_CENTRALE_DEPART:departs,
    RUE_CENTRALE_NOEUDS:{republic:{},soviet:{}},
    afficherNoeudRue:async(...args)=>{appels.push(args);},
    showToast:()=>{throw Error('Toast inattendu : position non initialisée');}
   };
   contexte.RUE_CENTRALE_NOEUDS[pays][depart]={image:'fixture.webp'};
   vm.createContext(contexte);
   vm.runInContext(code,contexte);
   await vm.runInContext('initialiserRueCentrale('+JSON.stringify(pays)+','+JSON.stringify(depart)+',null)',contexte);
   assert.equal(appels.length,1,pays+'/'+ville+' : aucune scène');
   assert.equal(appels[0][0],pays);
   assert.equal(appels[0][1],depart,pays+'/'+ville+' : mauvais départ');
  }
 }
 console.log('OK : départ initial affiché dans les six villes (Républia + Sovarka).');
})().catch(e=>{console.error(e);process.exitCode=1});
