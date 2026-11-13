'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'../..'),assets=process.env.ORDER_INFO_ASSET_DIR||root,read=p=>fs.readFileSync(path.join(assets,p),'utf8');
const base=execFileSync('git',['merge-base','origin/main','HEAD'],{cwd:root,encoding:'utf8'}).trim();
const old=p=>execFileSync('git',['show',base+':'+p],{cwd:root,encoding:'utf8',maxBuffer:8*1024*1024});
function fn(s,name){const a=s.indexOf('function '+name+'(');assert.ok(a>=0,name);return s.slice(a,s.indexOf('\n}\n',a)+3);}
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
async function setup(page,original=false){
 await page.route('**/*',r=>r.abort());
 await page.setContent('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body class="plateau-body"><button data-hg-panneau="personnage" hidden></button><button data-hg-panneau="personnes" hidden></button><button data-hg-panneau="menu" hidden></button><button id="hg-mobile-fond" hidden></button><div id="action-context-bat"></div><div id="actions-row-bat" class="actions-row"></div><div id="modal-postes" class="modal-overlay"><div class="modal-box"><div class="modal-header"><h2 class="modal-title">Écran précédent</h2><button class="modal-close" onclick="window.underlyingClosed++;this.closest(\'.modal-overlay\').classList.remove(\'open\')">Fermer</button></div><div id="postes-body"></div></div></div><div style="height:1000px"></div></body></html>');
 await page.addStyleTag({content:original?old('style.css'):read('style.css')});
 await page.addScriptTag({path:path.join(assets,'i18n/i18next.min.js')});
 await page.evaluate(()=>{
  window.RP_I18N_GAME_ENABLED=true;window.RPPlateauI18n={language:()=>i18next.language||'fr'};
  window.state={char:{name:'Fixture',country:'soviet'},country:'soviet',currentCity:'capitale',currentBuilding:'fixture',currentRoom:'salle',pa:20,arg:500};
  window.COUNTRIES={republic:{cur:'FR'},soviet:{cur:'PSK'}};window.WORLD={soviet:{capitale:{}}};window.TEST_MODE=false;
  window.calls=[];window.toasts=[];window.underlyingClosed=0;
  window.ordresDeclaresDeLaPiece=r=>r.orders;window.getMalusISN=()=>0;window.intitulePoste=(id,pays,nom)=>nom;
  window.ORDER_EFFECTS={louer_local:{hp:5,moral:2,pop:-2},sovarka_surveiller:{dis:-2},payer_fixture:{inf:3}};
  window.doOrder=(...args)=>calls.push(args);window.showToast=(...args)=>toasts.push(args);window.showPostRequired=(...args)=>toasts.push(args);
  window.fetch=()=>{throw Error('Appel réseau inattendu');};window.sbRpcVerdict=()=>{throw Error('RPC inattendue');};window.sbSavePersonnage=()=>{throw Error('Sauvegarde inattendue');};
 });
 for(const p of ['i18n/resources.js','i18n/plateau-resources.js','i18n/orders-resources.js','i18n/order-variants-resources.js','i18n/ordres.js','i18n/sovarka-infobulles-resources.js'])await page.addScriptTag({content:read(p)});
 const pol=original?old('plateau-politique.js'):read('plateau-politique.js');
 await page.addScriptTag({content:fn(pol,'deviseDansTexte')+'\n'+fn(pol,'renderRoomActions')});
 await page.addScriptTag({path:path.join(assets,'i18n/plateau-init.js')});
 await page.evaluate(()=>{
  const source='Location privative de 3 nuits';
  window.orders=[
   {fn:'louer_local',label:'Louer un appartement',desc:source,pa:1,cost:100,type:'legal',icon:'ti-home',successRate:100},
   {fn:'sovarka_surveiller',label:'Faire surveiller un citoyen',desc:'Faire suivre un citoyen pendant 4 jours',pa:1,cost:0,type:'grey',icon:'ti-eye',successRate:70},
   {fn:'consulter_fixture',label:'Consulter librement',desc:'Description "sans" gain ni risque.',pa:0,cost:0,type:'legal',icon:'ti-book',successRate:100},
   {fn:'payer_fixture',label:'Ordre payant avec un intitulé volontairement très long',desc:'Longue description. '.repeat(60),pa:2,cost:200,type:'legal',icon:'ti-coin',successRate:85},
   {fn:'bloque_fixture',label:'Ordre bientôt disponible',desc:'Description complète, conservée même pour un ordre bloqué.',bientot:'Bientôt disponible : les médicaments de la pharmacie seront définis prochainement.',pa:1,cost:25,type:'legal',icon:'ti-clock',successRate:80},
   {fn:'poste_fixture',label:'Ordre réservé',desc:'Description de l’ordre réservé.',requiresPost:'president',pa:1,cost:0,type:'legal',icon:'ti-user',successRate:100},
   {fn:'vide_fixture',label:'Sans description',pa:0,cost:0,type:'legal',icon:'ti-info-circle',successRate:100}
  ];window.room={name:'Salle',orders};
  renderRoomActions(room,'fixture','salle');
  // Ordre réellement disabled : autre retour du renderer / interface existante.
  const disabled=document.createElement('button');disabled.className='action-btn blocked';disabled.disabled=true;disabled.title='Achat impossible, vous devez libérer le terrain en gérant les intrus';disabled.textContent='Achat bloqué';disabled.onclick=()=>{throw Error('Ordre disabled exécuté');};document.getElementById('actions-row-bat').append(disabled);
  window.originalButtons=[...document.querySelectorAll('.action-btn')];
  window.snapshot=()=>JSON.stringify({state,calls,toasts,orders});
  window.buttonSnapshots=()=>[...document.querySelectorAll('.action-btn')].map(b=>({html:b.innerHTML,onclick:b.getAttribute('onclick'),title:b.title,disabled:b.disabled,classes:b.className}));
 });
 if(!original)await page.addScriptTag({content:read('plateau-ordres-info.js')});
 await page.addScriptTag({content:read('plateau-mobile.js')});
}
test('Chromium : tactile 320/390, neuf langues, ordre normal/bloqué/gratuit/payant, clavier et position conservés',async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox']});
 try{for(const width of [320,390]){
  const page=await browser.newPage({viewport:{width,height:700},hasTouch:true,isMobile:true});const errors=[];page.on('pageerror',e=>errors.push(String(e)));await setup(page);
  await page.waitForFunction(()=>document.querySelectorAll('.rp-order-info-button').length===8);
  assert.equal(await page.evaluate(()=>originalButtons.every(b=>b===document.querySelectorAll('.action-btn')[[...originalButtons].indexOf(b)])),true);
  await page.evaluate(()=>{window.outsideInfo=0;document.addEventListener('pointerdown',e=>{if(e.target.closest('.rp-order-info-button,.rp-order-info-dialog'))outsideInfo++;},true);document.addEventListener('click',e=>{if(e.target.closest('.rp-order-info-button,.rp-order-info-dialog'))outsideInfo++;});});
  const before=await page.evaluate(()=>snapshot());
  for(const lang of langs){
   await page.evaluate(l=>i18next.changeLanguage(l),lang);
   for(let i=0;i<8;i++){
    const info=page.locator('.rp-order-info-button').nth(i);await info.tap();
    const d=page.locator('dialog[open]');await d.waitFor();
    const text=await d.locator('.rp-order-info-content').textContent();assert.ok(text.trim());
    assert.equal(await d.getAttribute('dir'),lang==='ar'?'rtl':'ltr');
    const expected=await page.evaluate(i=>{
     const b=originalButtons[i],p=b.dataset.rpTip?JSON.parse(decodeURIComponent(b.dataset.rpTip)):null;
     return {title:b.title.replaceAll(' | ','\n\n'),blocage:p?.blocage||'',details:p?.details?RPSovarkaInfobullesI18n.infobulle(p.details).replaceAll(' | ','\n\n'):''};
    },i);
    assert.ok(text.includes(expected.title));if(expected.blocage)assert.ok(text.includes(expected.blocage));if(expected.details)assert.ok(text.includes(expected.details));
    if(i===2){assert.ok(text.includes('Description "sans" gain ni risque.'));assert.ok(!text.includes('Gain:')&&!text.includes('Risque:'));}
    assert.equal(await page.evaluate(()=>{const d=document.querySelector('dialog[open]'),r=d.getBoundingClientRect();return r.left>=0&&r.right<=innerWidth+1&&d.scrollWidth<=d.clientWidth+1&&document.documentElement.scrollWidth<=innerWidth;}),true,'largeur '+width+' '+lang+' '+i);
    await d.locator('button').click();assert.equal(await page.locator('dialog[open]').count(),0);assert.equal(await info.evaluate(e=>e===document.activeElement),true);
   }
  }
  assert.equal(await page.evaluate(()=>snapshot()),before,'aucun ordre, RPC, PA, paiement ni refus exécuté');
  assert.equal(await page.evaluate(()=>outsideInfo),0,'aucune fermeture globale ni lecture auxiliaire');
  // Fenêtre et brouillon sous le dialogue : ni remplacement ni fermeture.
  await page.evaluate(()=>{const m=document.getElementById('modal-postes');m.classList.add('open');document.getElementById('postes-body').innerHTML='<textarea id="draft">Brouillon intact</textarea><div class="actions-row" id="nested"></div><div style="height:900px"></div>';document.getElementById('nested').append(originalButtons[0].parentElement);m.querySelector('.modal-box').scrollTop=30;});
  await page.locator('#nested .rp-order-info-button').tap();
  const saved=await page.evaluate(()=>document.querySelector('#modal-postes .modal-box').scrollTop);
  // Le vrai gestionnaire mobile ne doit pas intercepter Tab/Échap du dialogue supérieur.

  for(const l of ['ar','ru','de','fr']){await page.evaluate(l=>i18next.changeLanguage(l),l);assert.ok((await page.locator('dialog .modal-title').textContent()).startsWith(await page.evaluate(()=>i18next.t('plateau.description'))));}
  await page.keyboard.press('Tab');assert.equal(await page.locator('dialog button').evaluate(e=>e===document.activeElement),true);
  await page.keyboard.press('Escape');assert.equal(await page.evaluate(()=>underlyingClosed),0);assert.equal(await page.locator('#draft').inputValue(),'Brouillon intact');assert.equal(await page.evaluate(()=>document.querySelector('#modal-postes .modal-box').scrollTop),saved);
  // Réouvertures et double appui sur l'information : aucun handler d'ordre.
  await page.locator('#nested .rp-order-info-button').evaluate(e=>{e.click();e.click();});await page.keyboard.press('Escape');await page.locator('#nested .rp-order-info-button').focus();await page.keyboard.press('Enter');await page.keyboard.press('Escape');
  assert.equal(await page.evaluate(()=>snapshot()),before);
  await page.evaluate(()=>document.getElementById('modal-postes').classList.remove('open'));
  // Clic principal normal : exactement un appel et les arguments d'origine.
  await page.locator('.action-btn').filter({hasText:'Consulter librement'}).tap();
  assert.deepEqual(await page.evaluate(()=>calls),[['consulter_fixture',0,0,'Consulter librement','Description "sans" gain ni risque.',100]]);
  const count=await page.locator('.rp-order-info-button').count();await page.evaluate(()=>renderRoomActions(room,'fixture','salle'));await page.waitForTimeout(20);assert.equal(await page.locator('.rp-order-info-button').count(),8);
  // Source remplacée pendant la lecture : fermer la description périmée.
  await page.locator('.rp-order-info-button').first().tap();await page.evaluate(()=>renderRoomActions(room,'fixture','salle'));await page.waitForFunction(()=>!document.querySelector('dialog[open]'));
  // Reprise suspendue : l'information ne lance pas de réconciliation serveur.
  await page.evaluate(()=>{window.resumes=0;window.loadCharacter=async()=>{resumes++;return true;};window.dispatchEvent(new Event('pagehide'));});
  await page.locator('.rp-order-info-button').first().tap();await page.locator('dialog button').click();
  assert.equal(await page.evaluate(()=>resumes),0);
  const oldCalls=await page.evaluate(()=>calls.length);await page.locator('.action-btn').filter({hasText:'Consulter librement'}).tap();
  await page.waitForFunction(()=>resumes===1);assert.equal(await page.evaluate(()=>calls.length),oldCalls,'le garde de reprise reste actif sur le bouton principal');
  assert.deepEqual(errors,[]);await page.close();
 }}finally{await browser.close();}
});
test('bureau 1280 : rendu, title, clic et absence de bouton info identiques au main initial',async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox']});
 try{
  const a=await browser.newPage({viewport:{width:1280,height:900}}),b=await browser.newPage({viewport:{width:1280,height:900}});await setup(a);await setup(b,true);
  assert.equal(await a.locator('.rp-order-info-button').count(),0);
  assert.deepEqual(await a.evaluate(()=>buttonSnapshots()),await b.evaluate(()=>buttonSnapshots()));
  for(const l of langs){await a.evaluate(l=>i18next.changeLanguage(l),l);await b.evaluate(l=>i18next.changeLanguage(l),l);assert.deepEqual(await a.evaluate(()=>buttonSnapshots()),await b.evaluate(()=>buttonSnapshots()));}
  await a.locator('.action-btn').filter({hasText:'Consulter librement'}).click();await b.locator('.action-btn').filter({hasText:'Consulter librement'}).click();assert.deepEqual(await a.evaluate(()=>calls),await b.evaluate(()=>calls));
  await a.close();await b.close();
 }finally{await browser.close();}
});
