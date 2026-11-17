'use strict';
// Deux lots chargés ensemble ; serveur simulé, aucun compte ni réseau métier.
const assert=require('node:assert/strict'),fs=require('node:fs'),{execFileSync}=require('node:child_process');
const pw=require('../e2e/node_modules/playwright'),ref=process.env.GOULAG_1085_REF||'77d457ad8e67702de8df5dec372f0596fa898737';
const lecture=f=>fs.readFileSync(f,'utf8'),claude=execFileSync('git',['show',ref+':plateau-goulag-ordres.js'],{encoding:'utf8',maxBuffer:2e6});
const htmlClaude=execFileSync('git',['show',ref+':plateau.html'],{encoding:'utf8',maxBuffer:2e6});
const tag=htmlClaude.match(/<script src="plateau-goulag-ordres\.js[^>]+><\/script>/)[0];
const initial=lecture('plateau.html');
const html=initial.includes('src=\"plateau-goulag-ordres.js')?initial:initial.replace('<script src="plateau-sovarka-justice.js',tag+'\n<script src="plateau-sovarka-justice.js');
// Le verrou d'ouverture (5e module) est remplacé ici par un serveur qui confirme l'ouverture ;
// il est éprouvé à part (test-goulag-verrou-client-20261117.cjs).
const tous=[...html.matchAll(/<script src="(plateau-goulag-[^?"/]+\.js)/g)].map(m=>m[1]);
assert.equal(new Set(tous).size,5);assert.ok(tous.includes('plateau-goulag-ouverture.js'));
const modules=tous.filter(f=>f!=='plateau-goulag-ouverture.js');assert.ok(html.indexOf(tag)<html.indexOf('<script src="plateau-router.js'));
const moteur=process.env.GOULAG_BROWSER||'chromium';assert.ok(['chromium','webkit'].includes(moteur));
(async()=>{
 const b=await pw[moteur].launch(moteur==='chromium'?{executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox']}:{headless:true});let scenarios=0;
 try{for(const width of [320,390,1280]){
  const p=await b.newPage({viewport:{width,height:850}});await p.route('**/*',r=>r.abort());
  await p.setContent(html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'')+'<input id="saisie-raccord" value="Brouillon 原 اسم">');
  for(const f of ['style.css','rue-centrale.css','plateau-exploration-mobile.css','plateau-mobile-refonte-visible.css','plateau-mobile-prototype.css','plateau-interieurs-mobile.css'])await p.addStyleTag({content:lecture(f)});
  await p.evaluate(()=>{
   Object.defineProperty(document,'readyState',{value:'loading',configurable:true});
   // Goulag ouvert simulé (serveur qui confirme) : le verrou d'ouverture est éprouvé à part.
   window.goulagOuvert=()=>true;window.goulagOuvertureVerifier=async()=>true;
   window.state={country:'soviet',currentCity:'qhs',currentBuilding:'qhs-prison',currentRoom:'cellules_qhs',personnageChargeDepuisServeur:false,estEmprisonne:{qhs:true},char:{poste:{}},pa:10};
   window.BUILDINGS={'qhs-prison':{rooms:{cellules_qhs:{orders:[{fn:'greve_faim'},{fn:'tentative_evasion'}]}}}};
   window.i18next={language:'fr'};window.appels=[];window.fallback=[];window.toasts=[];
   window.showToast=(...args)=>toasts.push(args);window.updateUI=()=>{};window.sbLoadPersonnage=async()=>{};
   window.sbRpcVerdict=async(fn,args)=>{appels.push({fn,args});await new Promise(r=>setTimeout(r,20));
    return fn==='sovarka_goulag_dormir'?{ok:true,pa:11,gain:1,jours_restants:3}:{ok:false,raison:'evasion_echouee',room:'cachot_disciplinaire'};};
  });
  for(const f of modules)await p.addScriptTag({content:f==='plateau-goulag-ordres.js'?claude:lecture(f)});
  await p.evaluate(()=>{window.doOrder=(...args)=>fallback.push(args);document.dispatchEvent(new Event('DOMContentLoaded'));});
  assert.equal(await p.evaluate(()=>goulagToundraChoisirDepart===goulagOrdresInternes.choisirDepart),true);
  for(const lang of ['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de']){
   await p.evaluate(l=>{i18next.language=l;document.documentElement.dir=l==='ar'?'rtl':'ltr';state.country='soviet';state.pa=10;appels.length=0;},lang);
   const fns=await p.evaluate(()=>RP_ORDRES_DYNAMIQUES.flatMap(f=>f('qhs-prison','cellules_qhs','qhs')).filter(o=>!o.invisible).map(o=>o.fn));
   assert.ok(fns.includes('goulag_detenu_entree'));assert.ok(fns.includes('sovarka_goulag_dormir'));assert.ok(fns.includes('sovarka_goulag_manger'));assert.equal(new Set(fns).size,fns.length);
   await p.evaluate(()=>{doOrder('sovarka_goulag_dormir');doOrder('sovarka_goulag_dormir');});await p.waitForTimeout(80);
   assert.equal(await p.evaluate(()=>appels.filter(x=>x.fn==='sovarka_goulag_dormir').length),1);assert.equal(await p.evaluate(()=>state.pa),11);
   await p.evaluate(()=>{appels.length=0;goulagToundraChoisirDepart();});
   assert.equal(await p.evaluate(()=>appels.length),0);assert.equal(await p.locator('#postes-modal-title').textContent(),await p.evaluate(()=>goulagOrdresInternes.t('tDepart')));
   const box=await p.locator('.goulag-ordres').evaluate(e=>({width:e.clientWidth,scroll:e.scrollWidth}));assert.ok(box.scroll<=box.width+1);
   await p.evaluate(()=>{const bouton=document.getElementById('goulag-ordres-ok');bouton.click();bouton.click();});await p.waitForTimeout(100);
   assert.equal(await p.evaluate(()=>appels.filter(x=>x.fn==='goulag_toundra_demarrer').length),1);
   assert.equal(await p.locator('#saisie-raccord').inputValue(),'Brouillon 原 اسم');
   await p.evaluate(()=>{state.country='republic';fallback.length=0;doOrder('ordre_republicain',7,50);});
   assert.deepEqual(await p.evaluate(()=>fallback),[['ordre_republicain',7,50]]);
   assert.equal(await p.evaluate(()=>RP_ORDRES_DYNAMIQUES.flatMap(f=>f('qhs-prison','cellules_qhs','qhs')).length),0);
   scenarios++;
  }
  await p.close();
 }}finally{await b.close();}
 console.log(JSON.stringify({moteur,scenarios,largeurs:[320,390,1280],langues:9,rtl:true,ref1085:ref,modules,serveur:'simulé',personnageConnecte:false}));
})().catch(e=>{console.error(e);process.exitCode=1;});
