'use strict';
const {chromium}=require('../e2e/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({headless:true});
 try{
   for(const width of [390,896,1280]){
    const page=await browser.newPage({viewport:{width,height:width===896?414:844}});
    const errors=[];page.on('pageerror',e=>errors.push(e.message.slice(0,180)));
    await page.route('**/*',async route=>{
      const req=route.request(),u=req.url();
      if(req.resourceType()==='script'&&!/plateau-(exploration|interieurs)-mobile\.js/.test(u))return route.abort();
      if(/googleapis|gstatic|jsdelivr/.test(u))return route.abort();
      return route.continue();
    });
    const url='https://res-publica.vercel.app/plateau.html?audit_interface_mobile=20261117';
    const resp=await page.goto(url,{waitUntil:'domcontentloaded',timeout:45000});
    await page.waitForTimeout(900);
    const result=await page.evaluate(()=>{
      const el=id=>document.getElementById(id),styles=id=>{const x=el(id);return x?{display:getComputedStyle(x).display,width:Math.round(x.getBoundingClientRect().width),height:Math.round(x.getBoundingClientRect().height)}:null};
      return {url:location.href,title:document.title,version:!!document.querySelector('link[href*="plateau-dialogues-mobile.css"]'),css:[...document.styleSheets].map(x=>x.href).filter(Boolean).filter(x=>x.includes('mobile')),tabs:document.querySelectorAll('.hg-explore-tabs button').length,roomTabs:document.querySelectorAll('.hg-room-tabs button').length,street:styles('vue-rue'),room:styles('vue-batiment'),topbar:styles('topbar'),text:document.querySelector('.hg-explore-place')?.textContent};
    });
    console.log('AUDIT '+width+' HTTP '+resp?.status()+' '+JSON.stringify(result)+' errors='+JSON.stringify(errors.slice(0,4)));
    if(!result.version||!result.css.some(x=>x.includes('plateau-exploration-mobile.css')))throw Error('Asset absent');
    if(!result.tabs||!result.roomTabs)throw Error('Modules UI non initialises: '+width);
    if(width<1024){
      const rects=await page.evaluate(()=>{
        const box=s=>{const e=document.querySelector(s);if(!e)return null;const b=e.getBoundingClientRect();return {top:b.top,bottom:b.bottom,display:getComputedStyle(e).display}};
        const streetNav=box('.hg-explore-tabs'),streetScene=box('#vue-rue .rue-container');
        const street=document.getElementById('vue-rue'),room=document.getElementById('vue-batiment');
        street?.classList.remove('active');room?.classList.add('active');
        const roomNav=box('.hg-room-tabs'),roomScene=box('#vue-batiment .piece-container');
        room?.classList.remove('active');street?.classList.add('active');
        return {streetNav,streetScene,roomNav,roomScene};
      });
      if(!(rects.streetNav?.top>=0&&rects.streetNav.top<rects.streetScene?.top))throw Error('Navigation rue invisible avant le décor '+width+': '+JSON.stringify(rects));
      if(!(rects.roomNav?.top<rects.roomScene?.top))throw Error('Navigation bâtiment après le décor '+width+': '+JSON.stringify(rects));
      console.log('ORDRE VISIBLE '+width+' '+JSON.stringify(rects));
    }

    await page.close();
   }
 }finally{await browser.close();}
})().catch(err=>{console.error(err);process.exitCode=1;});
