'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {chromium,webkit}=require('../e2e/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8')
 .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'');
(async()=>{
 for(const [engine,driver] of [['Chromium',chromium],['WebKit',webkit]]){
 const browser=await driver.launch({headless:true});
 try{
 for(const width of [320,390,414,896,1280]){
  const height=width===896?500:844;
  const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:1});
  await page.route('**/*',r=>r.abort());
  await page.setContent(html,{waitUntil:'domcontentloaded'});
  for(const file of ['style.css','rue-centrale.css','plateau-exploration-mobile.css','plateau-mobile-refonte-visible.css','plateau-mobile-prototype.css']){
   await page.addStyleTag({path:path.join(root,file)});
  }
  await page.evaluate(()=>{
    const image=document.getElementById('rue-image');
    image.insertAdjacentHTML('beforeend',
      '<div id="rue-centrale-conteneur"><div class="rc-scene"><img class="rc-image" width="900" height="600" alt="Décor test" src="data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22900%22 height=%22600%22%3E%3Crect width=%22900%22 height=%22600%22 fill=%22%232b4658%22/%3E%3C/svg%3E"></div></div>');
    document.getElementById('rue-title').textContent='Quartier administratif';
    document.getElementById('rue-desc').textContent='Un quartier de Starovka.';
    document.getElementById('char-fullname-left').textContent='Angie test';
    document.getElementById('char-arch-left').textContent='Citoyenne de Républia';
    document.getElementById('r-pa').textContent='15';
    document.getElementById('r-arg').textContent='30 590 PSK';
    document.getElementById('r-hp').textContent='85';
    document.getElementById('r-moral').textContent='96';
    const mockPhoto=document.createElement('img');mockPhoto.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%2260%22 height=%2260%22%3E%3Crect width=%2260%22 height=%2260%22 fill=%22%2364869f%22/%3E%3C/svg%3E';document.getElementById('char-photo-left').replaceChildren(mockPhoto);
    document.getElementById('rue-actions-row').innerHTML='<button class="action-btn" id="real-order">Ordre réel existant</button>';
  });
  await page.addScriptTag({path:path.join(root,'plateau-mobile-identite-20261117.js')});
  await page.addScriptTag({path:path.join(root,'plateau-exploration-mobile.js')});
  const data=await page.evaluate(()=>{
    const r=s=>{const e=document.querySelector(s);if(!e)return null;const b=e.getBoundingClientRect();return {top:Math.round(b.top),bottom:Math.round(b.bottom),h:Math.round(b.height),display:getComputedStyle(e).display}};
    return {
      banner:r('#hg-mobile-identite-20261117'),name:document.getElementById('hg-identite-personnage').textContent,
      portrait:!!document.querySelector('#hg-identite-portrait img'),
      hp:document.getElementById('hg-identite-sante').textContent,
      moral:document.getElementById('hg-identite-moral').textContent,
      cash:document.getElementById('hg-identite-argent').textContent,
      location:r('.hg-explore-head'),time:r('.city-header'),
      scene:r('#rue-centrale-conteneur'),tabs:r('#hg-explore-primary'),
      description:r('#rue-ambiance'),actions:r('#actionbar'),
      scrollWidth:document.documentElement.scrollWidth,width:innerWidth,
      labels:[...document.querySelectorAll('#hg-explore-primary button')].map(e=>e.textContent)
    };
  });
  console.log('PROTOTYPE '+engine+' '+width+' '+JSON.stringify(data));
  if(width<1024){
    assert.equal(data.name,'Angie test');
    assert.equal(data.portrait,true);
    assert.match(data.cash,/30 590 PSK/);
    assert.match(data.hp,/85 %/);
    assert.match(data.moral,/96 %/);
    assert.ok(data.banner.h>=55);
    assert.ok(data.location.top<data.time.top,'lieu avant date');
    assert.ok(data.time.top<data.scene.top,'date avant décor');
    assert.ok(data.scene.bottom<=data.tabs.top,'onglets APRES l’image');
    assert.ok(data.tabs.bottom<=data.description.top,'cartel APRES onglets');
    assert.ok(data.description.bottom<=data.actions.top,'ordres après description');
    assert.ok(data.actions.top-data.description.bottom<70,'pas de vide artificiel');
    assert.ok(data.scrollWidth<=width+2,'débordement '+width);
  }else{
    assert.equal(data.banner.display,'none','bureau intact');
    assert.equal(data.tabs.display,'none','navigation mobile masquée au bureau');
  }
  await page.close();
 }
 }finally{await browser.close()}
 }
})().catch(e=>{console.error(e);process.exitCode=1});
