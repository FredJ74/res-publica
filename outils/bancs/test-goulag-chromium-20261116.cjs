'use strict';
// Navigateur réel, RPC simulées : aucune session ni dépense de production.
const assert=require('node:assert/strict'),fs=require('node:fs');
let chromium;try{({chromium}=require('../e2e/node_modules/playwright'));}catch(_){({chromium}=require('playwright'));}
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||(fs.existsSync('/usr/bin/chromium')?'/usr/bin/chromium':chromium.executablePath()),headless:true,args:['--no-sandbox']});
 let rendus=0;
 try{
 for(const width of [320,390,1280]){
  const page=await browser.newPage({viewport:{width,height:850}});
  await page.route('**/*',r=>r.abort());
  await page.setContent('<!doctype html><html><head><meta charset="utf-8"></head><body><input id="saisie" value="à conserver"></body></html>');
  await page.addStyleTag({content:fs.readFileSync('style.css','utf8')});
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
    for(const b of await page.locator('#goulag-toundra button').all()){const bounds=await b.boundingBox();assert.ok(bounds.width<=width && bounds.height>=44);}
    assert.equal(await page.locator('#saisie').inputValue(),'à conserver');rendus++;
   }
  }
  // Un double clic synthétique ne produit qu'un ordre, sans mise à jour optimiste des PA.
  await page.evaluate(async()=>{donnees.champignons_a_decider=false;await goulagToundraOuvrir();appels.length=0;const b=document.querySelector('[data-goulag-action="abri"]');b.click();b.click();});
  await page.waitForTimeout(100);
  assert.equal(await page.evaluate(()=>appels.filter(x=>x.fn==='goulag_toundra_agir').length),1);
  assert.equal(await page.evaluate(()=>donnees.pa),20);
  await page.close();
 }
 console.log(JSON.stringify({rendus,largeurs:[320,390,1280],langues:9,rtl:true,doubleClic:'un seul ordre',serveur:'simulé',personnageConnecte:false}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
