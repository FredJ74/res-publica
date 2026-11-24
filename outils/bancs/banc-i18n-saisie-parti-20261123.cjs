'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {avecJeu,page,R}=require('./mobile-navigateur.cjs');
const read=f=>fs.readFileSync(require('node:path').join(R,f),'utf8');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
for(const width of [320,390,1280])test(`parti : saisie LTR hors arabe, état intact, ${width}px`,async()=>avecJeu(async(browser,o)=>{
 const p=await page(browser,o,width,900,false,{texteMinimum:true});let metier=0;
 p.on('request',r=>{if(r.method()!=='GET'||/\/(api|rest\/v1)\//.test(r.url()))metier++;});
 await p.addScriptTag({content:`window.RP_I18N_GAME_ENABLED=true;window.state={pa:42,arg:1500,progression:{etape:3},currentRoom:'bureau'};window.appels=0;window.sbRpc=()=>{appels++;throw Error('Appel interdit');};`});
 for(const f of ['i18n/i18next.min.js','i18n/resources.js','i18n/plateau-bridge.js','i18n/plateau-init.js'])await p.addScriptTag({url:o+'/'+f});
 // Reproduction du défaut : dir=auto déduit RTL du contenu arabe même en français.
 await p.evaluate(()=>{document.getElementById('postes-body').innerHTML='<input id="orga-nom-input" dir="auto"><textarea id="orga-desc-input" dir="auto"></textarea><input id="voisin" dir="auto">';document.getElementById('orga-nom-input').value='اسم libre';});
 assert.equal(await p.locator('#orga-nom-input').evaluate(n=>getComputedStyle(n).direction),'rtl');
 await p.addScriptTag({url:o+'/i18n/organization-creation-resources.js'});
 await p.waitForFunction(()=>document.getElementById('orga-nom-input').dir==='ltr');
 for(const lang of langs){
  await p.evaluate(l=>i18next.changeLanguage(l),lang);
  // Remontage comme à l’ouverture réelle : l’observateur initialise les nouveaux champs.
  await p.evaluate(()=>{document.getElementById('postes-body').innerHTML='<input class="cpj-champ" id="orga-nom-input" dir="auto"><textarea class="cpj-champ" id="orga-desc-input" dir="auto"></textarea><input id="voisin" dir="auto">';});
  await p.waitForFunction(dir=>document.getElementById('orga-nom-input').dir===dir,lang==='ar'?'rtl':'ltr');
  for(const value of ['', 'اسم عربي', 'Nom français — русский 原 <b>']){
   await p.evaluate(v=>{for(const id of ['orga-nom-input','orga-desc-input']){const n=document.getElementById(id);n.value=v;n.oninput=()=>appels++;n.onchange=()=>appels++;}const n=document.getElementById('orga-nom-input');n.focus();n.setSelectionRange(0,Math.min(3,v.length));},value);
   const before=await p.evaluate(()=>JSON.stringify({state,appels,values:[...document.querySelectorAll('#postes-body input,#postes-body textarea')].map(n=>[n.id,n.value,n.selectionStart,n.selectionEnd]),focus:document.activeElement.id}));
   for(const next of langs){await p.evaluate(l=>i18next.changeLanguage(l),next);
    const result=await p.evaluate(()=>({snapshot:JSON.stringify({state,appels,values:[...document.querySelectorAll('#postes-body input,#postes-body textarea')].map(n=>[n.id,n.value,n.selectionStart,n.selectionEnd]),focus:document.activeElement.id}),fields:['orga-nom-input','orga-desc-input'].map(id=>{const n=document.getElementById(id);return {dir:n.dir,computed:getComputedStyle(n).direction,align:getComputedStyle(n).textAlign};}),voisin:document.getElementById('voisin').dir,overflow:document.documentElement.scrollWidth>innerWidth}));
    assert.equal(result.snapshot,before);for(const n of result.fields){assert.equal(n.dir,next==='ar'?'rtl':'ltr');assert.equal(n.computed,n.dir);assert.equal(n.align,'start');}assert.equal(result.voisin,'auto');assert.equal(result.overflow,false);
   }
  }
 }
 assert.equal(metier,0);assert.equal(await p.evaluate(()=>appels),0);await p.close();
}));
