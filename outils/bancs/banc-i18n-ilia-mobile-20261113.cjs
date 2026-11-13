'use strict';
// Chromium : vraie coque et CSS du jeu, moteur i18next et appels serveur simulés.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'../..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
async function setup(page){
 await page.route('**/*',r=>r.abort()); // aucune connexion réelle, notamment IA/Supabase
 const html=read('plateau.html');const start=html.indexOf('<div id="modal-postes"');
 await page.setContent('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body>'+html.slice(start,html.indexOf('<!-- MODAL RESOLUTION',start))+'</body></html>');
 await page.addStyleTag({content:read('style.css')});
 await page.addScriptTag({path:path.join(root,'i18n/i18next.min.js')});
 await page.evaluate(langs=>{
  window.calls=[];window.paid=[];window.toasts=[];
  window.RP_I18N_GAME_ENABLED=true;window.RP_I18N_LANGUAGES=Object.fromEntries(langs.map(l=>[l,{}]));
  window.RP_I18N_RESOURCES=Object.fromEntries(langs.map(l=>[l,{translation:{}}]));
  window.RPPlateauI18n={language:()=>i18next.language||'fr'};window.langueDuJeu=()=>RPPlateauI18n.language();
  window.state={country:'soviet',currentCity:'capitale',currentBuilding:'musee-novomirsk',currentRoom:'hall'};
  window.sbRpcVerdict=async name=>{calls.push(name);return name==='tresor_tsars_guide'?{ok:true}:{ok:true,salle:'novomirsk:'+state.currentRoom,ouvert:name==='guide_musee_dialogue_ouvrir',restantes:name==='guide_musee_dialogue_ouvrir'?3:0,pa:19,liquide:7,arg:7};};
  window.appliquerPaiementServeur=v=>paid.push(v);window.updateUI=()=>{};window.showToast=(...v)=>toasts.push(v);
  window.rpAuthJeton=()=> 'test';window.rpAuthAssurerSession=async()=>{};
  window.fetch=async (url,options)=>{calls.push({url,body:JSON.parse(options.body)});return new Promise(resolve=>window.answer=d=>resolve({ok:d.ok!==false,json:async()=>d}));};
 },langs);
 const veh=read('plateau-vehicules.js');
 await page.addScriptTag({content:veh.slice(veh.indexOf('function vehModal('),veh.indexOf('const vehSection'))});
 const sov=read('plateau-sovarka-droits.js');
 await page.addScriptTag({content:sov.slice(sov.indexOf('function sovModal('),sov.indexOf('let sovarkaDroitsCache'))});
 await page.addScriptTag({path:path.join(root,'plateau-guide-ilia.js')});
 await page.addScriptTag({path:path.join(root,'i18n/guide-ilia-resources.js')});
 await page.addScriptTag({content:"i18next.on('languageChanged',()=>sovarkaRerendreFenetre());"});
 await page.addScriptTag({path:path.join(root,'i18n/plateau-init.js')});
}
async function language(page,l){await page.evaluate(l=>i18next.changeLanguage(l),l);}
async function noOverflow(page){
 const result=await page.evaluate(()=>{
  const box=document.querySelector('#modal-postes .modal-box'),r=box.getBoundingClientRect();
  return {inside:r.x>=0&&r.right<=innerWidth+1,width:box.scrollWidth<=box.clientWidth+1,scroll:box.scrollHeight>=box.clientHeight};
 });assert.deepEqual(result,{inside:true,width:true,scroll:true});
}
test('mobile et bureau : 5 salles × 9 langues, brouillon, attente, compte serveur, refus, dialogue et fermeture',async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox']});
 try{
 for(const viewport of [{width:390,height:844},{width:320,height:568},{width:1280,height:900}]){
  const page=await browser.newPage({viewport});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await setup(page);
  for(const room of ['hall','salle_origines','salle_personnalites_discretes','salle_bataille_fleuve','salle_grand_incendie']){
   await page.evaluate(async room=>{state.currentRoom=room;await iliaEcouterGuide(room==='salle_origines');},room);
   const before=await page.evaluate(()=>calls.length);
   for(const l of langs){
    await language(page,l);
    assert.equal(await page.locator('[data-ilia-recit]').innerText(),await page.evaluate(()=>texteGuideIlia('f_'+state.currentRoom)));
    assert.equal(await page.locator('#postes-modal-title').textContent(),await page.evaluate(()=>texteGuideIlia('title')));
    assert.equal(await page.locator('[data-ilia-texte=q_open]').textContent(),await page.evaluate(()=>texteGuideIlia('q_open')));
    assert.equal(await page.locator('[data-ilia-salle]').getAttribute('dir'),l==='ar'?'rtl':'ltr');
    await noOverflow(page);
   }
   assert.equal(await page.evaluate(()=>calls.length),before);
  }
  assert.equal(await page.evaluate(()=>calls.filter(x=>x==='tresor_tsars_guide').length),1);
  assert.equal(await page.evaluate(()=>calls.filter(x=>x==='guide_musee_dialogue_lire').length),5);
  await page.evaluate(()=>iliaMuseeOuvrirQuestions());
  const textarea=page.locator('#ilia-musee-question');await textarea.fill('Question à conserver — 問題؟');
  await textarea.evaluate(e=>{e.focus();e.setSelectionRange(3,9);window.savedField=e;});
  const before=await page.evaluate(()=>JSON.stringify({calls,paid}));
  for(const l of langs){
   await language(page,l);
   assert.equal(await textarea.inputValue(),'Question à conserver — 問題؟');
   assert.deepEqual(await textarea.evaluate(e=>[e===savedField,e===document.activeElement,e.selectionStart,e.selectionEnd]),[true,true,3,9]);
  }
  assert.equal(await page.evaluate(()=>JSON.stringify({calls,paid})),before);
  await page.evaluate(()=>{window.pending=iliaMuseePoser();});
  await page.waitForFunction(()=>typeof answer==='function');
  const during=await page.evaluate(()=>JSON.stringify({calls,paid}));
  for(const l of langs){
   await language(page,l);
   assert.equal(await page.locator('[data-ilia-texte=q_wait]').textContent(),await page.evaluate(()=>texteGuideIlia('q_wait')));
   assert.equal(await page.locator('#ilia-musee-question + button').isDisabled(),true);
   assert.equal(await textarea.inputValue(),'Question à conserver — 問題؟');
  }
  assert.equal(await page.evaluate(()=>JSON.stringify({calls,paid})),during);
  await page.evaluate(async()=>{answer({reponse:'Réponse serveur <intacte>',restantes:2});await pending;});
  assert.equal(await page.evaluate(()=>paid.length),1);
  assert.deepEqual(await page.evaluate(()=>calls.filter(x=>typeof x==='object').map(x=>x.body)),[{profil:'veteran_ilia_krioukov',lang:'de',message:'Question à conserver — 問題؟',historique:[]}]);
  for(const l of langs){await language(page,l);assert.ok((await page.locator('.guide-musee-questions').innerText()).includes('Réponse serveur <intacte>'));assert.match(await page.locator('[data-ilia-texte=q_ask]').innerText(),/2/);}
  // Deuxième puis troisième réponse : les valeurs affichées viennent du serveur.
  for(const n of [1,0]){
   await textarea.fill('Encore ?');await page.evaluate(()=>{window.answer=null;window.pending=iliaMuseePoser();});
   await page.waitForFunction(()=>typeof answer==='function');
   await page.evaluate(async n=>{answer({reponse:'Suite',restantes:n});await pending;},n);
  }
  for(const l of langs){await language(page,l);assert.equal(await page.locator('[data-ilia-texte=q_done]').innerText(),await page.evaluate(()=>texteGuideIlia('q_done')));}
  const count=await page.evaluate(()=>calls.length);await page.evaluate(()=>iliaMuseePoser());assert.equal(await page.evaluate(()=>calls.length),count);
  // Refus d’ouverture et de réponse : aucun paiement ni message IA inventé.
  await page.evaluate(async()=>{state.currentRoom='hall';await iliaEcouterGuide();window.sbRpcVerdict=async()=>({ok:false,raison:'pa_insuffisants'});});
  for(const l of langs){await language(page,l);await page.evaluate(()=>iliaMuseeOuvrirQuestions());assert.equal(await page.evaluate(()=>toasts.at(-1)[1]),await page.evaluate(()=>texteGuideIlia('r_pa_insuffisants')));}
  await page.evaluate(async()=>{window.sbRpcVerdict=async()=>({ok:true,salle:'novomirsk:hall',restantes:3});await iliaMuseeOuvrirQuestions();});
  await textarea.fill('Refus ?');await page.evaluate(()=>{window.answer=null;window.pending=iliaMuseePoser();});await page.waitForFunction(()=>typeof answer==='function');
  await language(page,'ar');await page.evaluate(async()=>{answer({ok:false,raison:'questions_epuisees'});await pending;});
  assert.equal(await page.evaluate(()=>toasts.at(-1)[1]),await page.evaluate(()=>texteGuideIlia('r_questions_epuisees')));
  assert.equal(await page.locator('[data-ilia-texte=q_done]').count(),1);
  const closed=await page.locator('#postes-body').innerHTML();await page.evaluate(()=>document.getElementById('modal-postes').classList.remove('open'));await language(page,'en');assert.equal(await page.locator('#postes-body').innerHTML(),closed);
  await page.evaluate(()=>{state.currentBuilding='autre';});await language(page,'fr');assert.equal(await page.locator('#postes-body').innerHTML(),closed);
  assert.deepEqual(errors,[]);await page.close();
 }
 }finally{await browser.close();}
});
