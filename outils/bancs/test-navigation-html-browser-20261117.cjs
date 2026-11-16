'use strict';
const assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs');
const {chromium}=require('../e2e/node_modules/playwright');const root=path.resolve(__dirname,'../..');
(async()=>{const browser=await chromium.launch({headless:true});try{
for(const width of [320,390,414,896,1280]){
 const page=await browser.newPage({viewport:{width,height:844}});
 let html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 // Parse real HTML while blocking every other script and remote data.
 await page.route('**/*',route=>route.abort());
 await page.setContent(html,{waitUntil:'domcontentloaded'});
 await page.addStyleTag({path:path.join(root,'style.css')});
 await page.addStyleTag({path:path.join(root,'plateau-exploration-mobile.css')});
 await page.addStyleTag({path:path.join(root,'plateau-interieurs-mobile.css')});
 const mobile=width<1024;
 assert.equal(await page.locator('#hg-explore-primary').isVisible(),mobile,'street static '+width);
 assert.equal(await page.locator('#hg-room-primary').isVisible(),false,'inactive building '+width);
 if(mobile){
   const a=await page.evaluate(()=>{
     const nav=document.querySelector('#hg-explore-primary').getBoundingClientRect();
     const scene=document.querySelector('#vue-rue .rue-container').getBoundingClientRect();
     return {nav:nav.top,scene:scene.top};
   });
   assert.ok(a.nav>=0&&a.nav<a.scene,'visible before scene without JS '+JSON.stringify(a));
 }
 await page.addScriptTag({path:path.join(root,'plateau-exploration-mobile.js')});
 await page.addScriptTag({path:path.join(root,'plateau-interieurs-mobile.js')});
 assert.equal(await page.locator('#hg-explore-primary button').count(),3);
 assert.equal(await page.locator('#hg-room-primary button').count(),3);
 assert.equal(await page.locator('.hg-explore-tabs').count(),1);
 assert.equal(await page.locator('.hg-room-tabs').count(),1);
 if(mobile){
  await page.locator('#hg-explore-primary [data-explore-tab="2"]').click();
  assert.equal(await page.locator('#hg-explore-info').isVisible(),true);
  await page.locator('#vue-rue').evaluate(e=>e.classList.remove('active'));
  await page.locator('#vue-batiment').evaluate(e=>e.classList.add('active'));
  assert.equal(await page.locator('#hg-room-primary').isVisible(),true);
  const positions=await page.evaluate(()=>({nav:document.querySelector('#hg-room-primary').getBoundingClientRect().top,scene:document.querySelector('#vue-batiment .piece-container').getBoundingClientRect().top}));
  assert.ok(positions.nav<positions.scene);
 }
 console.log('OK '+width+' sans JS puis avec modules');
 await page.close();
}
}finally{await browser.close()}})().catch(e=>{console.error(e);process.exitCode=1;});
