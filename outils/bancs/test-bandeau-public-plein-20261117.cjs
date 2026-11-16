'use strict';
const assert=require('node:assert/strict');
const {chromium}=require('../e2e/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({headless:true});
 try {
  for (const width of [320,390,414,896,1280]) {
   const page=await browser.newPage({viewport:{width,height:width===896?500:844},deviceScaleFactor:1});
   const errors=[],failed=[];
   page.on('pageerror',e=>errors.push(e.message.slice(0,200)));
   page.on('requestfailed',r=>failed.push({url:r.url().slice(0,120),error:r.failure()?.errorText}));
   const url='https://res-publica.vercel.app/plateau.html?recette_plein_plateau=1711';
   const response=await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000});
   assert.equal(response?.status(),200);
   // VRAIS scripts du jeu, sans blocage artificiel des modules applicatifs.
   await page.waitForTimeout(2100);
   const result=await page.evaluate(()=>{
     const b=document.getElementById('hg-mobile-identite-20261117');
     const nav=document.getElementById('hg-explore-primary');
     const pos=e=>{if(!e)return null;const r=e.getBoundingClientRect();return {top:r.top,height:r.height,width:r.width,display:getComputedStyle(e).display}};
     return {
       url:location.href,
       version:b?.textContent?.replace(/\s+/g,' ').trim(),
       brand:pos(b),
       nav:pos(nav),
       css:[...document.querySelectorAll('link[rel="stylesheet"]')].map(e=>e.href).filter(s=>s.includes('mobile')),
       script:!!document.querySelector('script[src*="plateau-mobile-identite-20261117.js"]'),
       html:!!document.getElementById('hg-mobile-identite-20261117'),
       htmlWidth:document.documentElement.scrollWidth
     };
   });
   console.log('PLEIN_PLATEAU '+width+' '+JSON.stringify(result));
   console.log('ERRORS '+width+' '+JSON.stringify(errors.slice(0,8)));
   console.log('REQUEST_FAILURES '+width+' '+JSON.stringify(failed.slice(0,8)));
   assert.equal(result.html,true,'Le bandeau a disparu du DOM');
   assert.equal(result.script,true,'Script identité absent');
   assert.ok(result.css.some(u=>u.includes('refonte-identite-visible-r2-20261117')),'CSS ancien');
   if(width<1024){
     assert.match(result.version,/HUMAN GAMBIT/);
     assert.match(result.version,/NOUVELLE INTERFACE\s+17\.11/);
     assert.ok(result.brand.top>=0&&result.brand.top<230&&result.brand.height>=40,'Bandeau caché ou hors viewport');
     assert.equal(result.brand.display,'grid');
     assert.ok(result.htmlWidth<=width+2,'débordement horizontal');
   } else {
     assert.equal(result.brand.display,'none','le témoin ne doit pas apparaître sur bureau');
   }
   await page.close();
  }
 }finally{await browser.close()}
})().catch(err=>{console.error(err);process.exitCode=1});
