'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const source=fs.readFileSync(path.join(root,'plateau-social-pnj.js'),'utf8');
const pnjSource=fs.readFileSync(path.join(root,'plateau-pnj.js'),'utf8');
const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
function testSetup({ville='ville_a',batiment='bar-des-pecheurs',salle='salle_bar',presence=true}={}){
 const noms={
  'bar-des-pecheurs|salle_bar':{name:'Jean-Lou Demer (PNJ)',role:'Vieux marin, habitué du bar',job:null,photoUrl:'images/port-sainte-marie-bar-pecheurs-jean-lou-demer.webp'},
  'capitaine-sauvage|salle_principale':{name:'Marine Leroux (PNJ)',role:'Serveuse',job:'serveur',photoUrl:'images/port-sainte-marie-pnj-marine-leroux.webp'}
 };
 const personnes=presence?[noms[batiment+'|'+salle]].filter(Boolean):[];
 const appels=[],journal=[];
 const ctx={
  state:{country:'republic',currentCity:ville,currentBuilding:batiment,currentRoom:salle,char:{name:'Arnie',stats:{genre:'H'}}},
  BUILDINGS:{[batiment]:{rooms:{[salle]:{persons:personnes}}}},
  getBuildingContext:()=>({}),
  sbPnjSocialEntrer:async()=>({ok:true,social:true,jalon:batiment==='bar-des-pecheurs'?'abordage_deuxieme_visite':'accueil_premiere_visite'}),
  encodePnjSafe:o=>encodeURIComponent(JSON.stringify(o)).replace(/'/g,'%27'),
  openPnjModal:(...a)=>appels.push(a),
  addJournalEntry:(...a)=>journal.push(a)
 };
 vm.createContext(ctx);
 vm.runInContext(source,ctx);
 return {ctx,appels,journal};
}
test('Jean-Lou : la deuxième visite ouvre directement le dialogue normal avec sa phrase et sa fiche réelle',async()=>{
 const {ctx,appels,journal}=testSetup();
 await ctx.pnjSocialEntreeZone('bar-des-pecheurs','salle_bar');
 assert.equal(appels.length,1);
 const [encoded,opts]=appels[0],pnj=JSON.parse(decodeURIComponent(encoded));
 assert.equal(pnj.name,'Jean-Lou Demer (PNJ)');
 assert.equal(pnj.job,null);
 assert.match(pnj.photoUrl,/jean-lou-demer\.webp$/);
 assert.equal(opts.initialSpeech,"Alors moussaillon, on apprécie l'endroit ? C'est la deuxième fois que je vous vois venir ici.");
 assert.equal(journal.length,1);
});
test('Marine : même dialogue interactif en première visite et prénom du joueur',async()=>{
 const {ctx,appels}=testSetup({batiment:'capitaine-sauvage',salle:'salle_principale'});
 await ctx.pnjSocialEntreeZone('capitaine-sauvage','salle_principale');
 assert.equal(appels.length,1);
 assert.equal(JSON.parse(decodeURIComponent(appels[0][0])).name,'Marine Leroux (PNJ)');
 assert.match(appels[0][1].initialSpeech,/Bonjour Monsieur Arnie/);
});
test('PNJ absent ou déplacement pendant le réseau : aucun dialogue ni faux PNJ',async()=>{
 const absent=testSetup({presence:false});
 await absent.ctx.pnjSocialEntreeZone('bar-des-pecheurs','salle_bar');
 assert.equal(absent.appels.length,0);
 const deplace=testSetup();
 deplace.ctx.sbPnjSocialEntrer=async()=>{deplace.ctx.state.currentRoom='rue';return {ok:true,social:true,jalon:'abordage_deuxieme_visite'};};
 await deplace.ctx.pnjSocialEntreeZone('bar-des-pecheurs','salle_bar');
 assert.equal(deplace.appels.length,0);
});
test('Le mode interpellation ne déclenche pas une nouvelle salutation IA et garde le champ PNJ',()=>{
 assert.match(pnjSource,/function openPnjModal\(encodedPnj, options = null\)/);
 assert.match(pnjSource,/if \(options && typeof options\.initialSpeech === 'string'\)/);
 const debut=pnjSource.indexOf("if (options && typeof options.initialSpeech");
 const suite=pnjSource.slice(debut,debut+800);
 assert.match(suite,/speechEl\.textContent = options\.initialSpeech/);
 assert.match(suite,/else if \(pnjNameClean/);
 assert.match(pnjSource,/id="pnj-zone-question"/);
 assert.match(pnjSource,/id="pnj-question-libre"/);
 assert.match(pnjSource,/onclick="envoyerQuestion\(\)"/);
 assert.match(html,/plateau-social-pnj\.js\?v=social-reponse-directe-20261104/);
 assert.match(html,/plateau-pnj\.js\?v=social-reponse-directe-20261104/);
 assert.doesNotMatch(source,/Vous pouvez lui répondre en cliquant/);
});
