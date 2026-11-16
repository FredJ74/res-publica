// Essai navigateur du module de presentation; aucune connexion et aucune action serveur.
'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const { chromium } = require('../e2e/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const html=`<!doctype html><html lang="fr"><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body class="plateau-body">
<div id="topbar"><div class="logo">RES PUBLICA</div><button class="hg-mobile-acces">Personnage</button><button class="hg-mobile-acces">Présents</button><button class="hg-mobile-acces">Menu</button></div>
<div id="loc-city" hidden>Starovka</div><div id="r-pa" hidden>12</div><div id="r-arg" hidden>250 PSK</div>
<div id="main"><div id="center"><div id="vue-rue" class="vue active">
<div class="city-header"><div class="game-time-display">16/11/2026</div></div>
<div id="city-name-display" hidden></div>
<div class="rue-container"><div id="rue-image" class="rue-image">
<div id="rue-centrale-conteneur"><div class="rc-scene" id="rc-scene">
<img class="rc-image" width="900" height="650" alt="rue">
<div class="rc-zone" role="button" aria-label="Tribunal" tabindex="0" style="left:5%;width:35%;"></div>
<div class="rc-fleche" style="left:0;top:50%" onclick="window.moves++">❮</div>
</div><details class="hg-lieux-tactiles"><summary>Lieux visibles</summary><button id="lieu-test" onclick="window.places++">Tribunal</button></details></div>
<div class="rue-ambiance"><div id="rue-title" class="rue-title">Quartier administratif</div><div id="rue-desc" class="rue-desc">Tribunal et centre artisanal.</div></div></div></div>
<div id="actionbar"><div class="action-context">Dans la rue</div><div class="actions-row" id="rue-actions-row"><button class="action-btn" id="action-existante" onclick="window.orders++">Ordre existant</button></div></div>
</div></div></div>
</body></html>`;
(async()=>{
 const browser=await chromium.launch({headless:true});
 try {
   for(const width of [320,390,414,1280]){
     const page=await browser.newPage({viewport:{width,height:800},deviceScaleFactor:1});
     await page.setContent(html);
     await page.evaluate(()=>{window.places=0;window.moves=0;window.orders=0;});
     await page.addStyleTag({path:path.join(root,'plateau-exploration-mobile.css')});
     await page.addScriptTag({path:path.join(root,'plateau-exploration-mobile.js')});
     await page.waitForSelector('.hg-explore-tabs button');
     const mobile=width<1024;
     assert.equal(await page.locator('.hg-explore-tabs').isVisible(),mobile,'onglets '+width);
     if(mobile){
       assert.match(await page.locator('.hg-explore-place').innerText(),/Starovka/);
       assert.match(await page.locator('.hg-explore-stats').innerText(),/12/);
       await page.locator('#r-pa').evaluate(e=>e.textContent='9');
       await page.waitForFunction(()=>document.querySelector('.hg-explore-stats').textContent.includes('9'));
       await page.locator('[data-explore-tab="2"]').click();
       assert.equal(await page.locator('#hg-explore-info').isVisible(),true);
       assert.match(await page.locator('#hg-explore-info').innerText(),/Quartier administratif/);
       await page.locator('[data-explore-tab="0"]').click();
       assert.equal(await page.locator('.hg-lieux-tactiles').evaluate(e=>e.open),true);
       await page.locator('#lieu-test').click();
       assert.equal(await page.evaluate(()=>window.places),1);
       await page.locator('[data-explore-tab="1"]').click();
       await page.locator('#action-existante').click();
       assert.equal(await page.evaluate(()=>window.orders),1);
       assert.equal(await page.locator('.rc-zone').count(),1);
       assert.equal(await page.locator('.rc-fleche').count(),1);
       const sizes=await page.evaluate(()=>({viewport:innerWidth,doc:document.documentElement.scrollWidth,tab:document.querySelector('.hg-explore-tabs').getBoundingClientRect().width}));
       assert.ok(sizes.doc<=sizes.viewport+1,'pas de debordement '+width+': '+JSON.stringify(sizes));
     } else {
       assert.equal(await page.locator('.hg-explore-head').isVisible(),false);
     }
     console.log('OK viewport '+width);
     await page.close();
   }
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
