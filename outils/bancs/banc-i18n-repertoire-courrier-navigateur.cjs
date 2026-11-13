'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const {chromium}=require('playwright');
const root=process.env.DIRECTORY_ASSET_DIR||path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function fn(s,name){let a=s.indexOf('function '+name+'(');assert.ok(a>=0);if(s.slice(a-6,a)==='async ')a-=6;return s.slice(a,s.indexOf('\n}',a)+2);}
async function setup(page,original=false){
 await page.route('**/*',r=>r.abort());
 const privacy=read('plateau.html').split('\n').find(l=>l.includes('data-i18n="playerDirectory.privacy"'));
 await page.setContent('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body class="plateau-body"><div id="modal-postes" class="modal-overlay"><div class="modal-box"><div class="modal-header"><div id="postes-modal-title" class="modal-title"></div></div><div id="postes-body"></div></div></div><div id="modal-compose-mail" class="modal-overlay"><div class="modal-box"><input id="compose-mail-to"><input id="compose-mail-subject"><textarea id="compose-mail-body"></textarea>'+privacy+'</div></div><div id="result-toast"><div id="toast-result"></div><div id="toast-sub"></div></div></body></html>');
 await page.addStyleTag({content:read('style.css')});await page.addScriptTag({content:read('i18n/i18next.min.js')});
 await page.evaluate(()=>{
  window.state={char:{name:'Moi'},country:'republic',currentCity:'capitale',pa:20,arg:500};window.WORLD={republic:{capitale:{name:'Luthécia'}},soviet:{capitale:{name:'Novomirsk'}}};
  window.RP_I18N_GAME_ENABLED=true;window.RPPlateauI18n={language:()=>i18next.language||'fr'};window.calls=[];
  window.sbListPersonnages=()=>{calls.push('list');return new Promise(r=>window.resolveList=r);};
  window.sendMail=()=>{calls.push('send');throw Error('Envoi involontaire');};window.sbSendMail=window.sendMail;
  window.messages=[];window.journal=[];window.addJournalEntry=(...a)=>journal.push(a);window.showToast=(title,msg,success)=>{messages.push([title,msg,success]);document.getElementById('toast-result').textContent=window.RPToastI18n?.label(title)||title;document.getElementById('toast-sub').textContent=msg;};
  window.fetch=()=>{calls.push('network');throw Error('Réseau involontaire');};
  window.players=[{name:"Camille d'Essai",country:'republic',poste:{name:'Poste de test'},domicile:{city:'capitale'}}];
  window.longPlayers=[{name:'PersonnageAvecUnNomDeTestExceptionnellementLongSansEspace',country:'republic',poste:{name:'PosteAvecUnIntituléTrèsLongPourLaVérificationMobile'},domicile:{city:'capitale'}}];
  document.getElementById('compose-mail-to').value='Camille';document.getElementById('compose-mail-subject').value='Sujet conservé';document.getElementById('compose-mail-body').value='Brouillon conservé';
  window.snapshot=()=>JSON.stringify({state,calls,to:document.getElementById('compose-mail-to').value,subject:document.getElementById('compose-mail-subject').value,body:document.getElementById('compose-mail-body').value});
 });
 for(const f of ['i18n/resources.js','i18n/plateau-resources.js','i18n/inventory-ui-resources.js','i18n/player-directory-resources.js','i18n/toast-resources.js','i18n/plateau-init.js'])await page.addScriptTag({content:read(f)});
 const source=original?execFileSync('git',['show','1163bad:plateau-communication.js'],{cwd:root,encoding:'utf8',maxBuffer:4e6}):read('plateau-communication.js');
 const names=original?['ouvrirRepertoirePJ','composerMailPour','fermerComposeMail','envoyerComposeMail']:['texteRepertoireHtml','repertoireActualiserTextes','ouvrirRepertoirePJ','composerMailPour','fermerComposeMail','envoyerComposeMail'];
 await page.addScriptTag({content:names.map(n=>fn(source,n)).join('\n')});
}
test('répertoire et courrier : 320/390/1280, neuf langues, chargement/liste/vide, français et zéro effet à la bascule',async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox']});
 try{for(const width of [320,390,1280]){
  const page=await browser.newPage({viewport:{width,height:780}}),baseline=await browser.newPage({viewport:{width,height:780}}),errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await setup(page);await setup(baseline,true);
  for(const p of [page,baseline])await p.evaluate(()=>{window.opening=ouvrirRepertoirePJ();window.before=snapshot();});
  const frenchBefore=await baseline.locator('#modal-postes').textContent();assert.equal(await page.locator('#modal-postes').textContent(),frenchBefore);
  for(const l of locales){await page.evaluate(l=>i18next.changeLanguage(l),l);assert.equal(await page.evaluate(()=>snapshot()===before),true);
   assert.equal(await page.locator('[data-i18n="inventoryUi.loading"]').textContent(),await page.evaluate(()=>i18next.t('inventoryUi.loading')));
  }
  for(const p of [page,baseline])await p.evaluate(async()=>{resolveList(players);await opening;});
  await page.evaluate(()=>i18next.changeLanguage('fr'));assert.equal(await page.locator('#modal-postes').textContent(),await baseline.locator('#modal-postes').textContent());
  await page.evaluate(()=>{window.nodes=[...document.querySelectorAll('#postes-body button')];window.before=snapshot();});
  for(const l of locales){await page.evaluate(l=>i18next.changeLanguage(l),l);
   const got=await page.evaluate(()=>({same:snapshot()===before,title:document.getElementById('postes-modal-title').textContent,expected:i18next.t('playerDirectory.title'),
    body:document.getElementById('postes-body').textContent,dir:document.querySelector('[data-player-directory]').dir,privacy:document.querySelector('[data-i18n="playerDirectory.privacy"]').textContent,
    nodes:nodes.every((n,i)=>n===document.querySelectorAll('#postes-body button')[i]),overflow:document.documentElement.scrollWidth>innerWidth}));
   assert.equal(got.same,true);assert.equal(got.title,got.expected);assert.equal(got.dir,l==='ar'?'rtl':'ltr');assert.equal(got.nodes,true);assert.equal(got.overflow,false);
   assert.ok(got.body.includes("Camille d'Essai"));assert.ok(got.body.includes('Poste de test'));assert.ok(got.body.includes('Luthécia'));assert.ok(got.privacy.includes('Sovarka'));
  }
  await page.evaluate(()=>{delete i18next.getResourceBundle('de','translation').playerDirectory.home;});await page.evaluate(()=>i18next.changeLanguage('de'));assert.ok((await page.locator('#postes-body').textContent()).includes(' · Domicile : Luthécia'));
  // L'intention de composer reste le seul déclencheur de remise à zéro du brouillon.
  await page.locator('#postes-body button').click();assert.equal(await page.locator('#compose-mail-to').inputValue(),"Camille d'Essai");assert.equal(await page.locator('#compose-mail-subject').inputValue(),'');assert.deepEqual(await page.evaluate(()=>calls),['list']);
  // Liste vide, sans ajout de soi-même ; ni nouvelle liste ni envoi pendant les neuf bascules.
  await page.evaluate(()=>{state.char.name='';window.opening=ouvrirRepertoirePJ();resolveList([]);});await page.evaluate(()=>opening);await page.evaluate(()=>window.before=snapshot());
  for(const l of locales){await page.evaluate(l=>i18next.changeLanguage(l),l);assert.equal(await page.locator('[data-i18n="playerDirectory.empty"]').textContent(),await page.evaluate(()=>i18next.t('playerDirectory.empty')));assert.equal(await page.evaluate(()=>snapshot()===before),true);}
  // Noms propres longs : mêmes identifiants, aucune expansion horizontale.
  await page.evaluate(()=>{window.opening=ouvrirRepertoirePJ();resolveList(longPlayers);});await page.evaluate(()=>opening);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
  // Une autre fenêtre réutilise le conteneur : aucun ancien titre/répertoire ne doit revenir.
  await page.evaluate(()=>{document.getElementById('postes-modal-title').textContent='Autre fenêtre';document.getElementById('postes-body').innerHTML='<input id="other-draft" value="Brouillon suivant">';});
  await page.evaluate(()=>i18next.changeLanguage('ar'));assert.equal(await page.locator('#postes-modal-title').textContent(),'Autre fenêtre');assert.equal(await page.locator('#other-draft').inputValue(),'Brouillon suivant');
  // Erreurs locales : la validation et ses appels demeurent ceux de la fonction de production.
  for(const key of ['missing','required']){
   await page.evaluate(async key=>{state.char.name=key==='missing'?'':'Moi';document.getElementById('compose-mail-to').value='';await envoyerComposeMail();window.before=snapshot();},key);
   for(const l of locales){await page.evaluate(l=>i18next.changeLanguage(l),l);assert.equal(await page.locator('#toast-sub').textContent(),await page.evaluate(key=>i18next.t('playerDirectory.'+key),key));assert.equal(await page.locator('#toast-result').textContent(),await page.evaluate(key=>RPToastI18n.label(key==='missing'?'Personnage non chargé':'Champs requis'),key));assert.equal(await page.evaluate(()=>snapshot()===before),true);}
  }
  // Voie de repli simulée : un seul envoi explicite, mêmes paramètres FR et aucun nouvel appel à la bascule.
  await page.evaluate(async()=>{
   window.sendMail=undefined;window.sbSendMail=async(...args)=>{calls.push(args);return {ok:true};};
   document.getElementById('compose-mail-to').value='Destinataire Test';document.getElementById('compose-mail-subject').value='Objet "gardé"';document.getElementById('compose-mail-body').value='Corps conservé';
   await envoyerComposeMail();window.before=snapshot();
  });
  assert.deepEqual(await page.evaluate(()=>calls.at(-1)),['Moi','Destinataire Test','Objet "gardé"','Corps conservé','Jour 1']);
  for(const l of locales){await page.evaluate(l=>i18next.changeLanguage(l),l);assert.equal(await page.locator('#toast-sub').textContent(),await page.evaluate(()=>i18next.t('playerDirectory.sent',{values:{to:'Destinataire Test',subject:'Objet "gardé"'}})));assert.equal(await page.locator('#toast-result').textContent(),await page.evaluate(()=>RPToastI18n.label('Mail envoyé')));assert.equal(await page.evaluate(()=>snapshot()===before),true);}
  await page.evaluate(()=>showToast('Autre titre','Autre notification',false));await page.evaluate(()=>i18next.changeLanguage('ar'));assert.equal(await page.locator('#toast-sub').textContent(),'Autre notification');
  assert.deepEqual(errors,[]);await page.close();await baseline.close();
 }}finally{await browser.close();}
});
