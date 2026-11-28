'use strict';
// Chromium réel, composants et styles du dépôt ; aucun PJ connecté, aucun serveur métier.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const fn=(s,n)=>{const a=s.indexOf('function '+n+'(');return s.slice(a,s.indexOf('\n}',a)+2);};
for(const width of [320,390,1280])test('textes récents Chromium '+width+' px : 9 langues, RTL, description ouverte, saisie et état conservés',async()=>{
 const browser=await chromium.launch({executablePath:process.env.HG_CHROMIUM||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
 try{
 const page=await browser.newPage({viewport:{width,height:700},hasTouch:width<1000,isMobile:width<1000});
 await page.route('**/*',r=>r.abort());
 await page.setContent('<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><div class="cpj-dialogue"><input id="draft" class="cpj-champ" value="Brouillon inchangé"><div id="actions" class="actions-row"></div></div>');
 await page.addStyleTag({content:read('style.css')});
 await page.evaluate(()=>{
 window.RP_I18N_GAME_ENABLED=true;window.LANG='fr';window.RPPlateauI18n={language:()=>LANG};window.RPI18n={language:'fr'};
 window.state={country:'narco',currentCity:'capitale',currentRoom:'accueil',pa:14,arg:550};window.COUNTRIES={narco:{cur:'PS'},khalija:{cur:'DR'},republic:{cur:'FR'}};
 window.i18next={t:(_k,o)=>o.defaultValue};window.calls=0;window.sbRpc=window.sbRpcVerdict=window.fetch=()=>{window.calls++;throw Error('Appel métier inattendu');};
 });
 await page.addScriptTag({content:fn(read('plateau-politique.js'),'deviseDansTexte')+'\n'+fn(read('data.js'),'montantDansTexte')});
 for(const f of ['i18n/infobulles-communes-resources.js','i18n/republia-infobulles-resources.js','i18n/sovarka-infobulles-resources.js','plateau-teaser-traductions.js','plateau-criminalite.js'])await page.addScriptTag({content:read(f)});
 const fixture=await page.evaluate(()=>{
 const t=RPTeaserCapitalesI18n.tables;window.rows=t.DESCRIPTIONS;
 window.initial=JSON.stringify(state);window.draft=document.querySelector('#draft');
 const actions=document.querySelector('#actions');
 rows.forEach((d,i)=>{const b=document.createElement('button');b.className='action-btn';b.disabled=i===0;b.innerHTML='<span data-rp-order-fn="am_fixture">Ordre</span>';b.dataset.rpTip=encodeURIComponent(JSON.stringify({d:d[0],a:d[0],g:[],r:[],s:80,p:1,c:0}));b.onclick=()=>window.calls++;actions.append(b);});
 return rows.length;
 });
 assert.equal(fixture,14);
 await page.addScriptTag({content:read('plateau-ordres-info.js')});
 for(const l of langs){
 await page.evaluate(l=>{LANG=l;RPI18n.language=l;document.documentElement.lang=l;document.documentElement.dir=l==='ar'?'rtl':'ltr';for(const cb of RP_I18N_CHANGE_CALLBACKS)cb();},l);
 for(let i=0;i<fixture;i++){
 const expected=await page.evaluate(({i,l})=>{const order=['fr','en','es','de','ru','ko','ar','pt-BR','zh-TW'];return rows[i][order.indexOf(l)];},{i,l});
 const button=page.locator('.action-btn').nth(i);
 assert.ok((await button.getAttribute('title')).includes(expected),JSON.stringify({l,i,expected,actual:await button.getAttribute('title')}));
 if(width<1000){
 await page.locator('.rp-order-info-button').nth(i).click();
 const dialog=page.locator('dialog[open]');assert.equal(await dialog.count(),1);assert.ok((await dialog.textContent()).includes(expected));
 assert.equal(await dialog.getAttribute('dir'),l==='ar'?'rtl':'ltr');
 // Basculer alors que la description est ouverte, via le rappel de présentation existant.
 await page.evaluate(()=>{LANG='fr';RPI18n.language='fr';for(const cb of RP_I18N_CHANGE_CALLBACKS)cb();});
 assert.ok((await dialog.textContent()).includes(await page.evaluate(i=>rows[i][0],i)));
 await page.evaluate(l=>{LANG=l;RPI18n.language=l;for(const cb of RP_I18N_CHANGE_CALLBACKS)cb();},l);
 await page.keyboard.press('Escape');assert.equal(await page.locator('dialog[open]').count(),0);
 }
 }
 assert.equal(await page.locator('#draft').inputValue(),'Brouillon inchangé');
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'débordement horizontal');
 assert.deepEqual(await page.evaluate(()=>({state:JSON.stringify(state),initial,calls})),{state:await page.evaluate(()=>initial),initial:await page.evaluate(()=>initial),calls:0});
 }
 if(width===1280)assert.equal(await page.locator('.rp-order-info-button').count(),0);
 }finally{await browser.close();}
});
