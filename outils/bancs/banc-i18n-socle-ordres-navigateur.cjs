'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.env.SOCLE_ASSET_DIR||path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function fn(s,name){const i=s.indexOf('function '+name+'(');assert.ok(i>=0);return s.slice(i,s.indexOf('\n}\n',i)+3);}
test('troisième pays simulé : rendu réel 320/390/1280, neuf langues, RTL, détails ouverts sans métier',async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox']});
 try{for(const width of [320,390,1280]){
  const page=await browser.newPage({viewport:{width,height:780},hasTouch:width<1280,isMobile:width<1280}),errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.route('**/*',r=>r.abort());
  await page.setContent('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body class="plateau-body"><div id="action-context-bat"></div><div id="actions-row-bat" class="actions-row"></div><input id="draft" value="Question conservée"><div style="height:1000px"></div></body></html>');
  await page.addStyleTag({content:read('style.css')});
  await page.addScriptTag({content:read('i18n/i18next.min.js')});
  await page.evaluate(()=>{
   window.RP_I18N_GAME_ENABLED=true;window.RPPlateauI18n={language:()=>i18next.language||'fr'};
   window.state={country:'fixture',char:{name:'Fixture',country:'fixture'},pa:20,arg:500,currentCity:'fixture',currentBuilding:'fixture',currentRoom:'fixture'};
   window.COUNTRIES={fixture:{cur:'ECO'}};window.WORLD={fixture:{fixture:{}}};window.TEST_MODE=false;
   window.calls=[];window.network=[];window.toasts=[];window.doOrder=(...a)=>calls.push(a);window.showToast=(...a)=>toasts.push(a);window.showPostRequired=(...a)=>toasts.push(a);
   window.fetch=(...a)=>{network.push(a);throw Error('Réseau interdit');};window.sbRpcVerdict=(...a)=>{network.push(a);throw Error('RPC interdite');};
   window.ordresDeclaresDeLaPiece=r=>r.orders;window.getMalusISN=()=>0;window.intitulePoste=(id,pays,nom)=>nom;
   window.ORDER_EFFECTS={fixture_paid:{hp:5,dis:-2}};window.tarifOrdrePays=code=>code==='fixture_paid'?{cost:20,pa:2}:null;
  });
  for(const f of ['i18n/resources.js','i18n/plateau-resources.js','i18n/orders-resources.js','i18n/order-variants-resources.js','i18n/ordres.js','i18n/infobulles-communes-resources.js','i18n/republia-infobulles-resources.js','i18n/order-catalogues-config.js','i18n/sovarka-infobulles-resources.js'])await page.addScriptTag({content:read(f)});
  await page.addScriptTag({content:fn(read('plateau-politique.js'),'deviseDansTexte')+'\n'+fn(read('data.js'),'montantDansTexte')+'\n'+fn(read('plateau-politique.js'),'renderRoomActions')});
  await page.addScriptTag({content:read('i18n/plateau-init.js')});
  await page.evaluate(()=>{
   const entry={id:'orders.description.fixture.service',fr:'Payer 10 FR pour ce service.',en:'Pay 10 FR for this service.',es:'Pagar 10 FR por este servicio.','zh-TW':'為此服務支付 10 FR。',ru:'Заплатить 10 FR за эту услугу.',ko:'이 서비스에 10 FR를 지불합니다.',ar:'دفع 10 FR مقابل هذه الخدمة.','pt-BR':'Pagar 10 FR por este serviço.',de:'10 FR für diesen Dienst bezahlen.'};
   RPOrderDescriptionsI18n.registerCatalogue({id:'fixture',countries:['fixture'],entries:[entry]});
   const shared=RPOrderDescriptionsI18n.communes.find(r=>r[0]==='Voir ce qui est disponible au bar et commander.');
   window.rows={entry,shared};
   window.orders=[
    {fn:'fixture_free',label:'Consulter',desc:shared[0],descriptionKey:'orders.description.common.bar-menu',cost:0,pa:0,type:'legal',successRate:100},
    {fn:'fixture_paid',label:'Payer',desc:entry.fr,descriptionKey:entry.id,cost:10,pa:1,type:'legal',successRate:80},
    {fn:'fixture_blocked',label:'Ordre réservé',desc:entry.fr,descriptionKey:entry.id,cost:10,pa:1,type:'legal',requiresPost:'president',successRate:80},
    {fn:'fixture_unknown',label:'Ordre inédit',desc:'Texte sans traduction.',descriptionKey:'unknown',cost:0,pa:0,type:'legal',successRate:100}
   ];window.room={name:'Salle fixture',orders};renderRoomActions(room,'fixture','fixture');window.before=JSON.stringify({state,calls,network,toasts,orders});window.nodes=[...document.querySelectorAll('.action-btn')];
  });
  await page.addScriptTag({content:read('plateau-ordres-info.js')});
  if(width<1280){await page.waitForFunction(()=>document.querySelectorAll('.rp-order-info-button').length===4);await page.locator('.rp-order-info-button').nth(1).tap();}
  for(const [i,l]of langs.entries()){
   await page.evaluate(l=>i18next.changeLanguage(l),l);
   const got=await page.evaluate(i=>{
    const buttons=[...document.querySelectorAll('.action-btn')];
    return {shared:buttons[0].title,expected:rows.shared[i],paid:RPOrderDescriptionsI18n.infobulle(JSON.parse(decodeURIComponent(buttons[1].getAttribute('data-rp-tip')))),
      unknown:buttons[3].title,unchanged:before===JSON.stringify({state,calls,network,toasts,orders}),nodes:nodes.every((n,j)=>n===buttons[j]),
      overflow:document.documentElement.scrollWidth>innerWidth,draft:document.getElementById('draft').value,
      open:!!document.querySelector('dialog[open]'),dir:document.querySelector('dialog')?.dir,dialog:document.querySelector('dialog[open]')?.textContent};
   },i);
   assert.ok(got.shared.includes(got.expected),l);assert.match(got.paid,/20 ECO/);assert.ok(got.unknown.includes('Texte sans traduction.'));
   assert.equal(got.unchanged,true);assert.equal(got.nodes,true);assert.equal(got.overflow,false,l+' '+width);assert.equal(got.draft,'Question conservée');
   if(width<1280){assert.equal(got.open,true);assert.equal(got.dir,l==='ar'?'rtl':'ltr');assert.match(got.dialog,/20 ECO/);}
  }
  if(width<1280){await page.keyboard.press('Escape');for(let i=0;i<3;i++){await page.locator('.rp-order-info-button').nth(2).tap();assert.match(await page.locator('dialog[open]').textContent(),/réservée/);await page.keyboard.press('Escape');}
   assert.equal(await page.evaluate(()=>before===JSON.stringify({state,calls,network,toasts,orders})),true);
  }else assert.equal(await page.locator('.rp-order-info-button').count(),0);
  await page.locator('.action-btn').first().click();assert.deepEqual(await page.evaluate(()=>calls),[['fixture_free',0,0,'Consulter','Voir ce qui est disponible au bar et commander.',100]]);
  assert.deepEqual(errors,[]);await page.close();
 }}finally{await browser.close();}
});
