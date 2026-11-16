// Essai Chromium du nouvel habillage de pieces, sans navigateur authentifie.
'use strict';
const assert=require('node:assert/strict');
const path=require('node:path');
const {chromium}=require('../e2e/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const fixture=`<!doctype html><html lang="fr"><head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
body{margin:0;background:#111;color:#ddd;font-family:sans-serif}.vue{display:none}.vue.active{display:flex;flex-direction:column}
.batiment-header{display:flex;gap:6px}.pieces-tabs{display:flex;gap:5px}.piece-container{display:flex;flex-direction:column}
.piece-image{min-height:150px;position:relative;background:linear-gradient(180deg,transparent,rgba(0,0,0,.1)),url('data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22900%22 height=%22600%22%3E%3C/svg%3E') center/cover no-repeat}
.piece-ambiance{padding:12px}.actions-row{display:flex;gap:5px;flex-wrap:wrap}
</style></head><body class="plateau-body"><div id="vue-batiment" class="vue active">
<div class="batiment-header">
<button class="sortir-btn" id="sortie" onclick="window.sorties++">Sortir</button>
<div class="batiment-header-info"><div class="batiment-nom" id="bat-nom">Tribunal de Starovka</div><div class="batiment-cat">Justice</div></div>
<div class="pieces-tabs" id="pieces-tabs">
<div class="piece-tab active" id="salle-1" onclick="window.salles++">Accueil</div>
<div class="piece-tab" id="salle-2" onclick="window.salles++">Salle d'audience</div>
</div></div>
<div class="piece-container"><div class="piece-image" id="piece-image">
<div class="piece-ambiance"><div id="piece-nom" class="piece-nom">Accueil</div><div id="piece-desc" class="piece-desc">Le greffe accueille les visiteurs.</div></div>
<div class="hotzone" id="hotzone" onclick="window.zones++" style="position:absolute;top:0;right:0;width:40%;height:55%"></div>
</div><div class="persons-sidebar">Présents</div></div>
<div id="actionbar-batiment"><div id="action-context-bat">Actions disponibles</div>
<div class="actions-row" id="actions-row-bat"><button class="action-btn legal" id="ordre-legal" onclick="window.ordres++">Consulter le greffe</button>
<button class="action-btn blocked" id="ordre-bloque" onclick="window.refus++">Réservé</button></div>
</div></div></body></html>`;
(async()=>{
const browser=await chromium.launch({headless:true});
try{
  for(const width of [320,390,414,1280]){
    const page=await browser.newPage({viewport:{width,height:844}});
    await page.setContent(fixture);
    await page.evaluate(()=>{window.salles=0;window.ordres=0;window.refus=0;window.sorties=0;window.zones=0;});
    await page.addStyleTag({path:path.join(root,'plateau-interieurs-mobile.css')});
    await page.addScriptTag({path:path.join(root,'plateau-interieurs-mobile.js')});
    await page.waitForSelector('[data-room-tab="0"]',{state:'attached'});
    const small=width<=1023;
    assert.equal(await page.locator('.hg-room-tabs').isVisible(),small,'tabs '+width);
    if(small){
      await page.locator('[data-room-tab="2"]').click();
      assert.equal(await page.locator('#hg-room-info').isVisible(),true);
      assert.match(await page.locator('#hg-room-info').innerText(),/Le greffe/);
      await page.locator('#piece-desc').evaluate(el=>el.textContent='Description actualisée');
      await page.waitForFunction(()=>document.getElementById('hg-room-info').textContent.includes('Description actualisée'));
      await page.locator('[data-room-tab="0"]').click();
      await page.locator('#salle-2').click();
      assert.equal(await page.evaluate(()=>window.salles),1);
      await page.locator('[data-room-tab="1"]').click();
      await page.locator('#ordre-legal').click();
      assert.equal(await page.evaluate(()=>window.ordres),1);
      await page.locator('#sortie').click();
      assert.equal(await page.evaluate(()=>window.sorties),1);
      assert.equal(await page.locator('#hotzone').count(),1);
      const viewport=await page.evaluate(()=>({w:innerWidth,doc:document.documentElement.scrollWidth}));
      assert.ok(viewport.doc<=viewport.w+1,'débordement '+JSON.stringify(viewport));
      const buttons=await page.locator('.hg-room-tabs button').evaluateAll(nodes=>nodes.map(n=>n.getBoundingClientRect().height));
      assert.ok(buttons.every(h=>h>=48),'touches 48px');
    }
    if(!small)assert.equal(await page.locator('#hg-room-info').isVisible(),false);
    console.log('OK interieur '+width);
    await page.close();
  }
}finally{await browser.close();}
})().catch(err=>{console.error(err);process.exitCode=1;});
