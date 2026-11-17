'use strict';
// Navigateur réel, RPC simulées : aucune session ni dépense de production.
const assert=require('node:assert/strict'),fs=require('node:fs');
let pw;try{pw=require('../e2e/node_modules/playwright');}catch(_){pw=require('playwright');}
const moteur=process.env.GOULAG_BROWSER||'chromium',driver=pw[moteur];
if(!['chromium','webkit'].includes(moteur))throw Error('Moteur inconnu');
(async()=>{
 const browser=await driver.launch(moteur==='chromium'?{executablePath:process.env.CHROMIUM_PATH||(fs.existsSync('/usr/bin/chromium')?'/usr/bin/chromium':driver.executablePath()),headless:true,args:['--no-sandbox']}:{headless:true});
 let rendus=0;
 try{
 for(const width of [320,390,1280]){
  const page=await browser.newPage({viewport:{width,height:850}});
  await page.route('**/*',r=>r.abort());
  await page.setContent(fs.readFileSync('plateau.html','utf8').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'')+'<input id="saisie" value="à conserver">');
  for(const fichier of ['style.css','rue-centrale.css','plateau-exploration-mobile.css','plateau-mobile-refonte-visible.css','plateau-mobile-prototype.css','plateau-interieurs-mobile.css'])await page.addStyleTag({content:fs.readFileSync(fichier,'utf8')});
  await page.evaluate(()=>{
   window.state={country:'soviet',personnageChargeDepuisServeur:false,currentCity:'qhs'};
   window.appels=[];window.donnees={ok:true,en_cours:true,destination:'krasnov',statut:'detenu',pa:20,progressions:0,bois_trouve:0};
   window.sbRpcVerdict=async(fn,p)=>{appels.push({fn,p});await new Promise(r=>setTimeout(r,30));if(fn==='goulag_toundra_lire')return {...donnees};return {ok:false,raison:'refus_fixture'};};
  });
  await page.addScriptTag({content:fs.readFileSync('plateau-goulag-toundra.js','utf8')});
  for(const lang of ['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de']){
   await page.evaluate(l=>{document.documentElement.lang=l;document.documentElement.dir=l==='ar'?'rtl':'ltr';},lang);
   for(const champignons of [false,true]){
    await page.evaluate(v=>{donnees.champignons_a_decider=v;return goulagToundraOuvrir();},champignons);
    const box=await page.locator('#goulag-toundra').evaluate(e=>({width:e.clientWidth,scroll:e.scrollWidth,dir:getComputedStyle(e).direction}));
    assert.ok(box.scroll<=box.width+1,JSON.stringify({width,lang,box}));assert.equal(box.dir,lang==='ar'?'rtl':'ltr');
    for(const b of await page.locator('#goulag-toundra button').all()){await b.scrollIntoViewIfNeeded();const bounds=await b.boundingBox();assert.ok(bounds.width<=width && bounds.height>=44 && bounds.x>=-1 && bounds.x+bounds.width<=width+1);assert.ok(await b.evaluate(e=>{const r=e.getBoundingClientRect();return e.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2));}),'bouton tactile recouvert');}
    assert.equal(await page.locator('#saisie').inputValue(),'à conserver');rendus++;
   }
  }
  // Un double clic synthétique ne produit qu'un ordre, sans mise à jour optimiste des PA.
  await page.evaluate(async()=>{donnees.champignons_a_decider=false;await goulagToundraOuvrir();appels.length=0;const b=document.querySelector('[data-goulag-action="abri"]');b.click();b.click();});
  await page.waitForTimeout(100);
  assert.equal(await page.evaluate(()=>appels.filter(x=>x.fn==='goulag_toundra_agir').length),1);
  assert.equal(await page.evaluate(()=>donnees.pa),20);
  // Reconnexion dans la maison : le serveur seul rend les commandes visibles.
  await page.evaluate(()=>{
   window.state={country:'soviet',currentCity:'ville_a',currentBuilding:'maison-starovka'};
   window.refugeFixture={ok:true,termine:false,nuits:0,bois_prochain:8};
   window.confirmations=[];window.confirm=t=>{confirmations.push(t);return true;};
   window.sbLoadPersonnage=async()=>{};window.updateUI=()=>{};
   window.sbRpcVerdict=async(fn,p)=>{appels.push({fn,p});await new Promise(r=>setTimeout(r,15));
    if(fn==='sovarka_goulag_refuge_lire')return {...refugeFixture};
    return {ok:true,bois_preleves:8,paiements:[{bois:5},{bois:3}]};};
  });
  await page.addScriptTag({content:fs.readFileSync('plateau-goulag-refuge.js','utf8')});
  assert.equal(await page.evaluate(()=>RP_ORDRES_DYNAMIQUES.at(-1)('maison-starovka','piece_maison','ville_a').length),0);
  await page.evaluate(()=>goulagRefugeLire());
  assert.equal(await page.evaluate(()=>RP_ORDRES_DYNAMIQUES.at(-1)('maison-starovka','piece_maison','ville_a').length),2);
  await page.evaluate(async()=>{appels.length=0;await Promise.all([goulagRefugeNuit(),goulagRefugeNuit()]);});
  assert.deepEqual(await page.evaluate(()=>appels.filter(x=>x.fn==='sovarka_goulag_refuge_nuit').map(x=>x.p)),[{p_max_bois:8}]);
  await page.evaluate(()=>goulagRefugeTerminer());
  assert.equal(await page.evaluate(()=>RP_ORDRES_DYNAMIQUES.at(-1)('maison-starovka','piece_maison','ville_a').length),0);
  await page.addScriptTag({content:fs.readFileSync('plateau-goulag-transports.js','utf8')});
  for(const [choix,destination] of [['1','capitale'],['2','ville_b'],['3','ville_a']]){
   await page.evaluate(async choix=>{appels.length=0;const saisies=[choix,'2'];window.prompt=()=>saisies.shift();await goulagVisiteurRetour();},choix);
   assert.deepEqual(await page.evaluate(()=>appels.map(x=>x.p)),[{p_mode:'bus',p_destination:destination}]);
  }
  await page.evaluate(async()=>{
   appels.length=0;window.prompt=()=> '1';window.sbRpcVerdict=async(fn,p)=>{appels.push({fn,p});return fn==='sovarka_goulag_visite_lire'?{ok:true,ministre:true,demandes:[{id:'autorisation-test',nom:'Visiteur',etat:'accordee'}]}:{ok:true};};
   await goulagAutorisationsGerer();
  });
  assert.deepEqual(await page.evaluate(()=>appels.at(-1)),{fn:'sovarka_goulag_visite_decider',p:{p_id:'autorisation-test',p_decision:'revoquer'}});
  assert.equal(await page.locator('#saisie').inputValue(),'à conserver');
  await page.close();
 }
 console.log(JSON.stringify({moteur,rendus,largeurs:[320,390,1280],langues:9,rtl:true,doubleClic:'un seul ordre',serveur:'simulé',personnageConnecte:false}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
