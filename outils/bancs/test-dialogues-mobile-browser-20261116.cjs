'use strict';
const assert=require('node:assert/strict');
const path=require('node:path');
const {chromium}=require('../e2e/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const fixture=`<!doctype html><html lang="fr"><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>
body{margin:0;background:#111;color:#eee} .modal-overlay{position:fixed;inset:0;display:flex;align-items:center;justify-content:center}
.modal-box{width:min(500px,calc(100vw - 16px));max-height:calc(100vh - 16px);overflow-y:auto;padding:8px;background:#151515}
.modal-header{display:flex;align-items:center;justify-content:space-between}.modal-close{cursor:pointer}.pnj-actions{display:flex;flex-direction:column;gap:6px}
</style></head><body class="plateau-body">
<div class="modal-overlay open" id="modal-pnj"><div class="modal-box">
<div class="modal-header"><div class="modal-title" id="pnj-modal-title">Praskovia</div><button class="modal-close" id="close" onclick="window.closeClicks++">×</button></div>
<div id="pnj-modal-body"><div id="pnj-identite" style="display:flex;gap:.8rem;align-items:flex-start;padding:.6rem 0;margin-bottom:.4rem">
<div id="pnj-avatar-container"><div id="portrait" style="width:56px;height:56px;border-radius:50%;border:2px solid #c9a84c"></div></div>
<div style="flex:1"><div id="pnj-role-display">Habitante de Krasnov</div><div id="pnj-trait-display">Généreuse et accueillante</div></div></div>
<div class="pnj-speech" id="pnj-speech">Bienvenue chez moi, prenez une tasse de thé.</div>
<div class="pnj-actions" id="pnj-actions">
<button class="pnj-action-btn" id="reponse" onclick="window.reponses++">Parlez-moi de Krasnov</button>
<textarea id="question" aria-label="Question"></textarea>
</div></div></div></div>
</body></html>`;
(async()=>{
 const b=await chromium.launch({headless:true});
 try{for(const width of [320,390,414,1280]){
  const p=await b.newPage({viewport:{width,height:800}});
  await p.setContent(fixture);await p.evaluate(()=>{window.reponses=0;window.closeClicks=0});
  await p.addStyleTag({path:path.join(root,'plateau-dialogues-mobile.css')});
  if(width<1024){
   const h=await p.locator('#reponse').evaluate(e=>e.getBoundingClientRect().height);
   assert.ok(h>=48,'bouton trop petit '+width+' '+h);
   const z=await p.locator('#portrait').evaluate(e=>e.getBoundingClientRect().width);
   assert.equal(z,width<=360?65:78);
   assert.ok(await p.locator('#pnj-speech').isVisible());
   const viewport=await p.evaluate(()=>({w:innerWidth,scroll:document.documentElement.scrollWidth}));
   assert.ok(viewport.scroll<=viewport.w+1,JSON.stringify(viewport));
  }else{
   const z=await p.locator('#portrait').evaluate(e=>e.getBoundingClientRect().width);
   assert.equal(z,60,'bureau doit garder le portrait 56px et ses bordures 2px');
  }
  await p.locator('#reponse').click();assert.equal(await p.evaluate(()=>window.reponses),1);
  await p.locator('#question').fill('Bonjour !');assert.equal(await p.locator('#question').inputValue(),'Bonjour !');
  await p.locator('#close').click();assert.equal(await p.evaluate(()=>window.closeClicks),1);
  console.log('OK dialogue '+width);await p.close();
 }}finally{await b.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
