// Mesures en fixtures uniquement : aucune position d'Arnie n'est écrite ou inventée.
'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {Joueur}=require('./luthecia.cjs');
const attendue={batiment:'office-notarial',piece:'accueil_notaire'};
function fixture(){
 const f={ui:{...attendue},serveur:{current_building:attendue.batiment,current_room:attendue.piece,protegeeSHA256:'fixture'},attentes:0,lectures:0};
 const rapport={prevolAutomatique:{position:{...attendue}},visites:[]};
 const page={locator:()=>({first:()=>({waitFor:async()=>{await f.scene?.();}})}),waitForFunction:async(fn,args)=>{
  if(args){f.attentes++;await f.attente?.();}
 }};
 const j=new Joueur(page,{nom:'Fixture',uid:'uid-fixture'},{},rapport,new AbortController().signal);
 j.identite=async()=>{if(f.identiteInvalide)throw Error('IDENTITE_CHANGE');return {...f.ui};};
 j.serveur=async()=>{f.lectures++;await f.lecture?.();return {...f.serveur};};
 return {...f,f,j,rapport};
}
test('une position restaurée pendant le chargement remplace la première mesure périmée',async()=>{
 const {f,j,rapport}=fixture();f.ui={batiment:null,piece:null};f.scene=async()=>{f.ui={...attendue};};
 await j.consulterPositionExistante();assert.equal(rapport.visites.length,1);assert.equal(f.attentes,0);
});
test('une mesure est reprise après la lecture serveur asynchrone',async()=>{
 const {f,j,rapport}=fixture();f.ui={batiment:null,piece:null};f.lecture=async()=>{f.ui={...attendue};};
 await j.consulterPositionExistante();assert.equal(rapport.visites.length,1);
});
test('restauration différée : attente locale bornée, puis deux positions fraîchement relues',async()=>{
 const {f,j,rapport}=fixture();f.ui={batiment:null,piece:null};f.attente=async()=>{f.ui={...attendue};};
 await j.consulterPositionExistante();assert.equal(f.attentes,1);assert.equal(f.lectures,2);assert.equal(rapport.visites.length,1);
});
test('un déplacement serveur depuis le prévol échoue sans attendre un éventuel retour',async()=>{
 const {f,j,rapport}=fixture();f.serveur.current_room='bureau_contrats';f.ui.piece='bureau_contrats';
 await assert.rejects(()=>j.consulterPositionExistante(),/POSITION_INITIALE_NON_CONFIRMEE/);
 assert.equal(f.attentes,0);assert.equal(rapport.visites.length,0);assert.equal(rapport.positionDiagnostic.serveur.piece,'bureau_contrats');
});
test('une interface réellement divergente reste refusée, même après le délai',async()=>{
 const {f,j,rapport}=fixture();f.ui.piece='bureau_contrats';f.attente=async()=>{throw Object.assign(Error('timeout fixture'),{name:'TimeoutError'});};
 await assert.rejects(()=>j.consulterPositionExistante(),/POSITION_INITIALE_NON_CONFIRMEE/);
 assert.equal(rapport.visites.length,0);assert.equal(rapport.positionDiagnostic.interface.piece,'bureau_contrats');
});
test('null, chaîne vide et identifiant de rue ne sont jamais rendus équivalents',async()=>{
 for(const ui of [{batiment:'rue-centrale',piece:null},{batiment:'',piece:null},{batiment:'office-notarial',piece:''}]){
  const {f,j,rapport}=fixture();f.ui=ui;f.attente=async()=>{throw Object.assign(Error('timeout fixture'),{name:'TimeoutError'});};
  await assert.rejects(()=>j.consulterPositionExistante(),/POSITION_INITIALE_NON_CONFIRMEE/);assert.equal(rapport.visites.length,0);
 }
});
test('une mutation serveur pendant l’attente n’est pas masquée par le retour de l’interface',async()=>{
 const {f,j,rapport}=fixture();f.ui={batiment:null,piece:null};f.attente=async()=>{f.ui={...attendue};f.serveur.current_room='bureau_contrats';};
 await assert.rejects(()=>j.consulterPositionExistante(),/POSITION_INITIALE_NON_CONFIRMEE/);assert.equal(rapport.visites.length,0);
});
test('un changement de personnage pendant l’attente arrête la consultation',async()=>{
 const {f,j,rapport}=fixture();f.ui={batiment:null,piece:null};f.attente=async()=>{f.identiteInvalide=true;};
 await assert.rejects(()=>j.consulterPositionExistante(),/IDENTITE_CHANGE/);assert.equal(rapport.visites.length,0);
});

test('Chromium local : le vrai callback de restauration de 300 ms précède la validation',async()=>{
 const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),http=require('node:http');
 const {lancerChromium}=require('../bancs/fixtures/chromium-cdp.cjs');
 const acorn=require('acorn'),source=fs.readFileSync(path.join(__dirname,'../../plateau-core.js'),'utf8');
 const noeud=acorn.parse(source,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='restaurerPositionApresChargement');assert.ok(noeud);
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'hg-position-initiale-')),requetes=[];let chrome,browser;
 const serveur=http.createServer((req,res)=>{requetes.push(req.method+' '+req.url);res.setHeader('Content-Type','text/html');res.end('<!doctype html><div id="vue-batiment" class="active"><div id="piece-image" style="width:500px;height:300px">Chargement</div></div>');});
 try{
  await new Promise(r=>serveur.listen(0,'127.0.0.1',r));const origine='http://127.0.0.1:'+serveur.address().port;
  const executable=process.env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(fs.existsSync);assert.ok(executable);
  chrome=await lancerChromium({executable,profil});browser=await require('playwright').chromium.connectOverCDP('http://127.0.0.1:'+chrome.port);
  const page=await browser.newPage();await page.goto(origine);
  await page.evaluate(origine=>{
   // Identités et contreparties fictives, strictement dans ce serveur local.
   window.state={char:{name:'Fixture'},country:'republic',currentCity:'capitale',currentBuilding:null,currentRoom:null};
   window.SUPABASE_URL=origine;window.rpAuthUid=()=> 'uid-fixture';window.appels=[];
   window.enterBuilding=(id,restauration)=>{if(restauration!==true||!window._restaurationPositionEnCours)throw Error('RESTaURATION_ATTENDUE');state.currentBuilding=id;appels.push('affichage-batiment');};
   window.enterRoom=(id,piece)=>{if(!window._restaurationPositionEnCours)throw Error('RESTaURATION_ATTENDUE');state.currentRoom=piece;document.getElementById('piece-image').textContent='Accueil';appels.push('affichage-piece');};
  },origine);
  await page.addScriptTag({content:fs.readFileSync(path.join(__dirname,'../../data.js'),'utf8')});
  await page.addScriptTag({content:source.slice(noeud.start,noeud.end)});
  // Même couple de lieux que le diagnostic distant, avec un personnage de fixture.
  const cible={batiment:'quartier-ambassades',piece:'accueil_ambassades'};
  const rapport={prevolAutomatique:{position:cible},visites:[]};
  const j=new Joueur(page,{nom:'Fixture',uid:'uid-fixture'},{autorisation:{backend:origine}},rapport,new AbortController().signal);let lectures=0;
  j.serveur=async()=>{lectures++;return {current_building:cible.batiment,current_room:cible.piece,protegeeSHA256:'fixture'};};
  await page.evaluate(cible=>restaurerPositionApresChargement({currentBuilding:cible.batiment,currentRoom:cible.piece}),cible);
  await j.consulterPositionExistante();assert.equal(rapport.visites.length,1);assert.ok(lectures>=1&&lectures<=2);
  assert.deepEqual(await page.evaluate(()=>appels),['affichage-batiment','affichage-piece']);assert.ok(requetes.every(r=>r.startsWith('GET ')&&!r.includes('/rest/')));
 }finally{
  try{await browser?.close();}finally{try{await chrome?.arreter();}finally{serveur.closeAllConnections();await new Promise(r=>serveur.close(r));fs.rmSync(profil,{recursive:true,force:true});}}
 }
});
