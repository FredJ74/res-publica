'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const {chromium}=require('../e2e/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
let html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
html=html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'');
(async()=> {
 const browser=await chromium.launch({headless:true});
 try {
  for(const [width,height,lang] of [[320,720,'fr'],[390,844,'fr'],[414,896,'es'],[390,844,'ru'],[390,844,'ar'],[1280,800,'fr']]){
   const page=await browser.newPage({viewport:{width,height}});
   await page.route('**/*',r=>r.abort());
   await page.setContent(html,{waitUntil:'domcontentloaded'});
   for(const file of ['style.css','rue-centrale.css','plateau-exploration-mobile.css','plateau-mobile-refonte-visible.css','plateau-mobile-prototype.css'])
    await page.addStyleTag({path:path.join(root,file)});
   await page.evaluate(lang=>{
     document.documentElement.lang=lang;
     document.documentElement.dir=lang==='ar'?'rtl':'ltr';
     document.getElementById('vue-rue').classList.add('active');
     document.getElementById('rue-title').textContent='Quartier administratif';
     document.getElementById('rue-desc').textContent='Le tribunal se trouve près du centre artisanal.';
     window.clics=0;
     const list=document.getElementById('persons-list-rue');
     list.innerHTML='<div class="person-card" onclick="window.clics++"><div class="person-avatar"><i class="ti ti-user"></i></div><div class="person-name">Nina</div></div>'+
       '<div class="person-card" onclick="window.clics++"><div class="person-avatar"><img src="data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs="></div><div class="person-name">Dolgor</div></div>'+
       '<div class="person-card" onclick="window.clics++"><div class="person-avatar"></div><div class="person-name">Camille</div></div>'+
       '<div class="person-card"><div class="person-name">Arnie (Vous)</div></div>'+
       '<div class="person-card"><div class="person-name">Joueur [SIM]</div></div>';
   },lang);
   await page.addScriptTag({path:path.join(root,'plateau-exploration-mobile.js')});
   await page.addScriptTag({path:path.join(root,'plateau-presences-mobile.js')});
   const rail=page.locator('#hg-presences-mobiles');
   assert.equal(await rail.isVisible(),width<1024,'mobile only '+width);
   if(width<1024){
     assert.equal(await page.locator('.hg-presence-personne').count(),3,'3 personnes visibles');
     const total=await page.locator('.hg-presences-total').innerText();
     assert.ok(total.includes('3'),total);
     assert.equal(await page.locator('#topbar [data-hg-panneau="personnes"]').isVisible(),false,'présents masqué dans rue');
     assert.equal(await page.locator('#rue-ambiance').isVisible(),false,'description masquée hors informations');
     await page.locator('.hg-presence-personne').first().click();
     assert.equal(await page.evaluate(()=>window.clics),1,'clic d origine reutilisé');
     await page.locator('[data-explore-tab="2"]').click();
     assert.ok((await page.locator('#hg-explore-info').innerText()).includes('Le tribunal'),'informations');
     const n=await page.evaluate(()=>({wide:document.documentElement.scrollWidth,viewport:innerWidth,dir:getComputedStyle(document.querySelector('.hg-presences-rail')).direction}));
     assert.ok(n.wide<=n.viewport+2,'pas de débordement '+JSON.stringify(n));
     if(lang==='ar')assert.equal(n.dir,'rtl');
     await page.evaluate(()=>document.getElementById('persons-list-rue').replaceChildren());
     await page.waitForFunction(()=>document.querySelectorAll('.hg-presence-personne').length===0);
     assert.match(await page.locator('.hg-presences-total').innerText(),/Personne|Nobody|No hay|никого|niemand|아무|أحد|Ninguém|沒有人/);
   }
   console.log('OK',width,height,lang);
   await page.close();
  }
 } finally {await browser.close();}
})().catch(err=>{console.error(err);process.exitCode=1});
