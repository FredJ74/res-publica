'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('../e2e/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
let html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
html=html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'');
(async()=>{const browser=await chromium.launch({headless:true});try{
 for(const [width,height] of [[320,720],[390,844],[414,896],[896,414],[1280,800]]){
  const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:1});
  await page.route('**/*',route=>route.abort());
  await page.setContent(html,{waitUntil:'domcontentloaded'});
  for(const css of ['style.css','rue-centrale.css','plateau-exploration-mobile.css','plateau-mobile-refonte-visible.css'])
    await page.addStyleTag({path:path.join(root,css)});
  await page.evaluate(()=>{
    const rue=document.getElementById('rue-image');
    const stage=document.createElement('div');stage.id='rue-centrale-conteneur';
    stage.innerHTML='<div class="rc-scene" id="rc-scene"><img class="rc-image" alt="Rue test" src="data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22900%22 height=%22580%22%3E%3Crect width=%22900%22 height=%22580%22 fill=%22%23274258%22/%3E%3Cpath d=%22M0 490L900 350V580H0%22 fill=%22%235c7585%22/%3E%3Crect x=%22550%22 y=%22150%22 width=%22300%22 height=%22240%22 fill=%22%238ea4ae%22/%3E%3C/svg%3E"><button class="rc-fleche" style="left:10px;top:45%">‹</button></div>';
    rue.append(stage);
    document.getElementById('rue-title').textContent='Quartier administratif';
    document.getElementById('rue-desc').textContent='Le tribunal et le centre artisanal bordent cette rue.';
    const details=document.createElement('details');details.className='hg-lieux-tactiles';details.innerHTML='<summary>Lieux visibles</summary><button>Tribunal de Starovka</button>';stage.append(details);
    const row=document.getElementById('rue-actions-row');row.innerHTML='<button class="action-btn">Action disponible</button>';
  });
  await page.addScriptTag({path:path.join(root,'plateau-exploration-mobile.js')});
  const sizes=await page.evaluate(()=>{
    const pos=s=>{const e=document.querySelector(s);if(!e)return null;const r=e.getBoundingClientRect(),cs=getComputedStyle(e);return {top:Math.round(r.top),bottom:Math.round(r.bottom),height:Math.round(r.height),display:cs.display};};
    return {nav:pos('#hg-explore-primary'),scene:pos('.rc-scene'),ambiance:pos('.rue-ambiance'),actions:pos('#actionbar'),container:pos('.rue-container'),doc:document.documentElement.scrollWidth,w:innerWidth,void:pos('#vue-rue')};
  });
  assert.equal(await page.locator('#hg-explore-primary').isVisible(),width<1024);
  if(width<1024){
   assert.ok(sizes.nav.top<sizes.scene.top,'navigation avant scene');
   assert.ok(sizes.scene.bottom<=sizes.actions.top,'actions suivent decor et description '+JSON.stringify(sizes));
   assert.ok(sizes.actions.top-sizes.scene.bottom<360,'pas de grand vide avant les actions '+JSON.stringify(sizes));
   assert.ok(sizes.doc<=sizes.w+2,'pas de debordement horizontal '+JSON.stringify(sizes));
  }
  console.log('COMPOSITION '+width+'x'+height+' '+JSON.stringify(sizes));
  if(width<1024){
   fs.mkdirSync(path.join(root,'outils','captures-mobile-refonte'),{recursive:true});
   await page.screenshot({path:path.join(root,'outils','captures-mobile-refonte','rue-'+width+'.png'),fullPage:true});
  }
  await page.close();
 }
}finally{await browser.close()}})().catch(e=>{console.error(e);process.exitCode=1;});
