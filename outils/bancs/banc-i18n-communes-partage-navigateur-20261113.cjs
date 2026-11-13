'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{chromium}=require('playwright');
const repository=path.resolve(__dirname,'../..'),root=process.env.COMMON_ASSET_DIR||repository,read=f=>fs.readFileSync(path.join(root,f),'utf8');
const rows=JSON.parse(fs.readFileSync(path.join(repository,process.env.COMMON_ROWS_FILE||'outils/audits/I18N-COMMUNES-ECONOMIE-871-sources.json'),'utf8'));
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function fn(s,name){const i=s.indexOf('function '+name+'(');assert.ok(i>=0);return s.slice(i,s.indexOf('\n}\n',i)+3);}
test(rows.length+' descriptions réutilisées : neuf langues, trois pays, 320/390/1280, RTL et dialogue sans acte',async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox']});
 try{for(const width of [320,390,1280]){
  const page=await browser.newPage({viewport:{width,height:780},hasTouch:width<1280,isMobile:width<1280}),errors=[];page.on('pageerror',e=>errors.push(String(e)));await page.route('**/*',r=>r.abort());
  await page.setContent('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body class="plateau-body"><div id="action-context-bat"></div><div id="actions-row-bat" class="actions-row"></div><input id="draft" value="Question conservée"></body></html>');
  await page.addStyleTag({content:read('style.css')});await page.addScriptTag({content:read('i18n/i18next.min.js')});
  await page.evaluate(rows=>{
   window.rows=rows;window.RP_I18N_GAME_ENABLED=true;window.RPPlateauI18n={language:()=>i18next.language||'fr'};
   window.state={country:'republic',char:{name:'Fixture'},pa:20,arg:500,progression:{stage:3},currentCity:'fixture',currentBuilding:'fixture',currentRoom:'fixture'};
   window.COUNTRIES={republic:{cur:'FR'},soviet:{cur:'PSK'},fixture:{cur:'ECO'}};window.WORLD={republic:{fixture:{}},soviet:{fixture:{}},fixture:{fixture:{}}};window.TEST_MODE=false;
   window.calls=[];window.network=[];window.toasts=[];window.doOrder=(...a)=>calls.push(a);window.showToast=(...a)=>toasts.push(a);window.showPostRequired=(...a)=>toasts.push(a);
   window.fetch=window.sbRpcVerdict=(...a)=>{network.push(a);throw Error('Réseau métier interdit');};
   window.ordresDeclaresDeLaPiece=r=>r.orders;window.getMalusISN=()=>0;window.intitulePoste=(id,pays,nom)=>nom;window.ORDER_EFFECTS={};window.tarifOrdrePays=()=>null;
  },rows);
  for(const f of ['i18n/resources.js','i18n/plateau-resources.js','i18n/orders-resources.js','i18n/order-variants-resources.js','i18n/ordres.js','i18n/infobulles-communes-resources.js','i18n/republia-infobulles-resources.js','i18n/order-catalogues-config.js','i18n/sovarka-infobulles-resources.js'])await page.addScriptTag({content:read(f)});
  await page.addScriptTag({content:fn(read('plateau-politique.js'),'deviseDansTexte')+'\n'+fn(read('data.js'),'montantDansTexte')+'\n'+fn(read('plateau-politique.js'),'renderRoomActions')});await page.addScriptTag({content:read('i18n/plateau-init.js')});await page.addScriptTag({content:read('plateau-ordres-info.js')});
  for(const country of ['republic','soviet','fixture']){
   await page.evaluate(async country=>{
    state.country=country;state.char.country=country;calls=[];network=[];toasts=[];await i18next.changeLanguage('fr');
    window.orders=rows.map((r,i)=>({fn:'common_'+i,label:'Ordre '+i,desc:r[0],cost:i%2?50:0,pa:i%2?2:0,type:'legal',successRate:100,...(i===1?{requiresPost:'president'}:{})}));
    window.room={name:'Salle fixture',orders};renderRoomActions(room,'fixture','fixture');window.snapshot=()=>JSON.stringify({state,calls,network,toasts,orders,draft:document.getElementById('draft').value});window.infoIndex=0;window.before=snapshot();window.nodes=[...document.querySelectorAll('.action-btn')];
   },country);
   if(width<1280){await page.waitForFunction(count=>document.querySelectorAll('.rp-order-info-button').length===count,rows.length);await page.locator('.rp-order-info-button').first().tap();}
   for(const [column,l]of langs.entries()){
    await page.evaluate(l=>i18next.changeLanguage(l),l);
    const data=await page.evaluate(async({column,mobile})=>{
     const cur=COUNTRIES[state.country].cur,buttons=[...document.querySelectorAll('.action-btn')],expected=rows.map(r=>r[column].replace(/\bFR\b/g,cur));
     const titles=buttons.map(b=>b.title),dialogs=[];const live=!mobile||document.querySelector('dialog[open]')?.textContent.includes(expected[window.infoIndex||0]);
     if(mobile)for(let i=0;i<rows.length;i++){const previous=document.querySelector('dialog[open]');if(previous){const closed=new Promise(resolve=>previous.addEventListener('close',resolve,{once:true}));previous.close();await closed;}document.querySelectorAll('.rp-order-info-button')[i].click();window.infoIndex=i;const d=document.querySelector('dialog[open]');dialogs.push({text:d?.textContent,dir:d?.dir,overflow:d?d.scrollWidth>d.clientWidth:false});}
     return {expected,titles,dialogs,live,unchanged:snapshot()===before,nodes:nodes.every((n,i)=>n===buttons[i]),overflow:document.documentElement.scrollWidth>innerWidth};
    },{column,mobile:width<1280});
    data.expected.forEach((e,i)=>{assert.ok(data.titles[i].includes(e),JSON.stringify({country,l,i,expected:e,actual:data.titles[i]}));if(width<1280){assert.ok(data.dialogs[i].text.includes(e),JSON.stringify({country,l,i,expected:e,actual:data.dialogs[i].text}));assert.equal(data.dialogs[i].dir,l==='ar'?'rtl':'ltr');assert.equal(data.dialogs[i].overflow,false);}});
    assert.equal(data.live,true);assert.equal(data.unchanged,true);assert.equal(data.nodes,true);assert.equal(data.overflow,false);
   }
   if(width<1280){assert.ok(await page.locator('dialog[open]').count());await page.keyboard.press('Escape');for(let i=0;i<2;i++){await page.locator('.rp-order-info-button').nth(1).tap();assert.match(await page.locator('dialog[open]').textContent(),/réservée/);await page.keyboard.press('Escape');}}
   else assert.equal(await page.locator('.rp-order-info-button').count(),0);
   assert.equal(await page.evaluate(()=>snapshot()===before),true);
   await page.locator('.action-btn').first().click();assert.equal(await page.evaluate(()=>calls.length),1);assert.deepEqual(await page.evaluate(()=>calls[0].slice(0,3)),['common_0',0,0]);assert.deepEqual(await page.evaluate(()=>({pa:state.pa,arg:state.arg,network})),{pa:20,arg:500,network:[]});
  }
  assert.deepEqual(errors,[]);await page.close();
 }}finally{await browser.close();}
});
