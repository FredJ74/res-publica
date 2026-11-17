'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const {chromium}=require('../e2e/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
let html=fs.readFileSync(path.join(root,'plateau.html'),'utf8').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'');
(async()=>{const browser=await chromium.launch({headless:true});try{
for(const width of [320,390,414,896,1280]){
 const page=await browser.newPage({viewport:{width,height:844}});
 await page.route('**/*',route=>route.abort());
 await page.setContent(html,{waitUntil:'domcontentloaded'});
 for(const file of ['style.css','plateau-mobile-refonte-visible.css','plateau-mobile-prototype.css'])
   await page.addStyleTag({path:path.join(root,file)});
 const brand=page.locator('#hg-mobile-identite-20261117');
 assert.equal(await brand.count(),1);
 assert.equal(await brand.isVisible(),width<1024,'visibilité '+width);
 if(width<1024){
   assert.match(await brand.innerText(),/Personnage/);
   assert.doesNotMatch(await brand.innerText(),/NOUVELLE INTERFACE/);
   await page.addScriptTag({path:path.join(root,'plateau-mobile-identite-20261117.js')});
   await page.locator('#char-fullname-left').evaluate(e=>e.textContent='Personnage de test');
   await page.locator('#r-pa').evaluate(e=>e.textContent='15');
   await page.locator('#r-arg').evaluate(e=>e.textContent='30 590 PSK');
   await page.waitForFunction(()=>document.getElementById('hg-identite-personnage').textContent==='Personnage de test');
   assert.match(await page.locator('#hg-identite-pa').innerText(),/PA\s+15/);
   assert.match(await page.locator('#hg-identite-argent').innerText(),/30 590 PSK/);
   const a=await brand.evaluate(el=>({width:el.getBoundingClientRect().width,top:el.getBoundingClientRect().top,background:getComputedStyle(el).backgroundImage+' '+getComputedStyle(el).backgroundColor,visible:getComputedStyle(el).display}));
   assert.ok(a.top>=0&&a.top<200,'bandeau hors écran '+width);
   // Habillage uni depuis les lots mobiles du 17/11 (#1068-#1073) : un fond plein suffit, dégradé ou non.
   assert.ok(!/^none rgba\(0, 0, 0, 0\)$/.test(a.background),'ancienne présentation '+width);
   assert.ok((await page.evaluate(()=>document.documentElement.scrollWidth))<=width+2,'débordement '+width);
 }
 console.log('OK bandeau personnage mobile '+width);
 await page.close();
}
}finally{await browser.close()}})().catch(e=>{console.error(e);process.exitCode=1;});
