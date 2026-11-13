'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'../..'),assets=process.env.MISSIONS_ASSET_DIR||root,read=p=>fs.readFileSync(path.join(assets,p),'utf8');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const base=execFileSync('git',['merge-base','origin/main','HEAD'],{cwd:root,encoding:'utf8'}).trim();
const baseline=p=>execFileSync('git',['show',base+':'+p],{cwd:root,encoding:'utf8',maxBuffer:8*1024*1024});
const fn=(source,name)=>{const start=source.indexOf('function '+name+'(');assert.ok(start>=0,name);return source.slice(source.slice(0,start).endsWith('async ')?start-6:start,source.indexOf('\n}\n',start)+3);};
async function setup(page,original=false){
 await page.route('**/*',r=>r.abort());
 const html=read('plateau.html'),start=html.indexOf('<div id="modal-postes"');
 await page.setContent('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body>'+html.slice(start,html.indexOf('<!-- MODAL RESOLUTION',start))+'</body></html>');
 await page.addStyleTag({content:read('style.css')});
 await page.addScriptTag({path:path.join(assets,'i18n/i18next.min.js')});
 await page.evaluate(langs=>{
  window.RP_I18N_GAME_ENABLED=true;window.RP_I18N_LANGUAGES=Object.fromEntries(langs.map(l=>[l,{}]));window.RP_I18N_RESOURCES=Object.fromEntries(langs.map(l=>[l,{translation:{}}]));
  window.RPPlateauI18n={language:()=>i18next.language||'fr'};
  window.calls=[];window.toasts=[];window.entries=[];window.draws=0;
  window.contexteGroupePj=()=>state.char.name;window.contexteGroupePjValide=c=>c===state.char.name;
  window.executerOrdreJaugesServeur=async name=>{calls.push(name);return {objectifs_completes:state.objectifs_completes||[],objectifs_nouveaux:window.newGoals||[]};};
  window.showToast=(...v)=>toasts.push(v);window.addJournalEntry=(...v)=>entries.push(v);window.updateUI=()=>draws++;
  window.fetch=()=>{throw Error('Réseau inattendu');};window.sbSavePersonnage=()=>{throw Error('Sauvegarde inattendue');};window.sbRpcVerdict=()=>{throw Error('RPC inattendue');};
 },langs);
 const source=original?baseline:read;
 let s=source('plateau-politique.js');
 await page.addScriptTag({content:s.slice(s.indexOf('const OBJECTIFS_SECRETS ='),s.indexOf('async function afficherObjectifsSecrets'))+fn(s,'afficherObjectifsSecrets')+'\nlet _verifyingObjectifs=false;\n'+fn(s,'verifierObjectifs')});
 s=source('plateau-quete-accueil.js');await page.addScriptTag({content:s.slice(s.indexOf('const QUETE_ACCUEIL_OBJECTIFS ='),s.indexOf('// RAPPEL DE L\'ETAPE EN COURS'))+';window.welcomeSteps=Object.keys(QUETE_ACCUEIL_OBJECTIFS);'});
 s=source('plateau-pnj.js');await page.addScriptTag({content:fn(s,'queteCarriereObjectifActuel')});
 await page.addScriptTag({content:source('plateau-enigme-portrait.js')});
 if(!original)await page.addScriptTag({path:path.join(assets,'i18n/player-missions-resources.js')});
 await page.addScriptTag({path:path.join(assets,'i18n/plateau-init.js')});
 await page.evaluate(()=>{
  window.scenarios=[...welcomeSteps.map(etape=>({kind:'welcome',etape})),
   ...Object.entries({criminel:['a_rencontrer','colis_recu','colis_livre'],politique:['a_rencontrer','tracts_recus','tracts_termines'],entrepreneurial:['a_rencontrer','negociation_demandee','negociation_obtenue']}).flatMap(([ambition,steps])=>steps.map(etape=>({kind:'career',ambition,etape}))),
   ...Object.keys(OBJECTIFS_SECRETS).map(archetype=>({kind:'secret',archetype})),{kind:'notebook',full:false},{kind:'notebook',full:true}];
  window.openScenario=async scenario=>{
   window.newGoals=[];
   window.state={country:'republic',currentCity:'capitale',pa:23,inf:17,inventory:[{calepinEnigme1:true,imageUrl:'images/calepin-enigme-musee.webp'}],objectifs_completes:['obj_president','obj_scandales'],char:{name:'Fixture',archetype:scenario.archetype||'ambitieux',queteAccueil:{etape:'terminee'},enigme1:{etape:'declenchee',dossier:scenario.full?{mairie:true,commissariat:true,notaire:true,presse:true,ehpad_dubois:true,ehpad_chevillard:true,ehpad_chauchay:true}:{},cadresVus:scenario.full?['salle_maires','salle_criminels','salle_entrepreneurs','salle_plumes']:[]}}};
   if(scenario.kind==='welcome')state.char.queteAccueil.etape=scenario.etape;
   if(scenario.kind==='career')state.char.queteCarriere={ambition:scenario.ambition,etape:scenario.etape};
   if(scenario.kind==='notebook')enigme1AfficherCalepin(0);else await afficherObjectifsSecrets();
  };
  window.frenchSnapshot=()=>[document.getElementById('postes-modal-title').textContent,document.getElementById('postes-body').textContent];
  window.businessSnapshot=()=>JSON.stringify({state,calls,toasts,entries,draws});
 });
}
test('français intégral comparé à main ; 38 situations × 9 langues, mobile 320/390 et bureau, sans mutation métier',async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox']});
 try{
 for(const viewport of [{width:320,height:568},{width:390,height:844},{width:1280,height:900}]){
  const page=await browser.newPage({viewport}),original=await browser.newPage({viewport}),errors=[];
  page.on('pageerror',e=>errors.push(String(e)));await setup(page);await setup(original,true);
  const originals=await original.evaluate(async()=>{const out=[];for(const s of scenarios){await openScenario(s);out.push(frenchSnapshot());}return out;});
  const result=await page.evaluate(async({langs,originals})=>{
   const keys=new Set(),failures=[];let checks=0;
   const check=(ok,message)=>{if(!ok)failures.push(message);};
   for(const [index,s]of scenarios.entries()){
    await i18next.changeLanguage('fr');await openScenario(s);
    check(JSON.stringify(frenchSnapshot())===JSON.stringify(originals[index]),'fr '+index);
    const before=businessSnapshot(),node=document.querySelector('#postes-body [data-player-missions]');
    for(const l of langs){
     await i18next.changeLanguage(l);
     check(before===businessSnapshot(),'métier '+index+' '+l);
     check(document.querySelector('#postes-body [data-player-missions]')===node,'même écran '+index+' '+l);
     check(node.dir===(l==='ar'?'rtl':'ltr'),'direction '+index+' '+l);
     for(const e of document.querySelectorAll('#postes-body [data-i18n],#postes-modal-title [data-i18n]')){
      keys.add(e.dataset.i18n.slice('playerMissions.'.length));
      check(e.textContent===i18next.t(e.dataset.i18n,{values:JSON.parse(e.dataset.i18nValues||'{}')}),'texte '+e.dataset.i18n+' '+l);
      check(!e.textContent.includes('{{'),'variable '+l);
     }
     const box=document.querySelector('#modal-postes .modal-box'),r=box.getBoundingClientRect();
     check(r.left>=0&&r.right<=innerWidth+1&&box.scrollWidth<=box.clientWidth+1,'largeur '+index+' '+l);
     checks++;
    }
    await i18next.changeLanguage('fr');check(JSON.stringify(frenchSnapshot())===JSON.stringify(originals[index]),'retour fr '+index);
   }
   return {failures,keys:[...keys],checks,scenarios:scenarios.length};
  },{langs,originals});
  assert.deepEqual(result.failures,[]);assert.equal(result.scenarios,38);assert.equal(result.checks,342);assert.equal(result.keys.length,67);
  assert.deepEqual(errors,[]);await original.close();await page.close();
 }
 }finally{await browser.close();}
});
test('récompense, repli français, fenêtre remplacée et inconnus : aucune action au changement de langue',async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox']});
 try{
  const page=await browser.newPage({viewport:{width:320,height:568}});await setup(page);
  const result=await page.evaluate(async()=>{
   await openScenario({kind:'secret',archetype:'ambitieux'});
   // Une nouvelle reconnaissance serveur réelle dans le décor : un seul lot annoncé.
   state._objectifsSignatureConfirmee=null;window.newGoals=['obj_president'];await afficherObjectifsSecrets();
   const before=businessSnapshot(),inf=state.inf;
   for(const l of ['ar','de','fr','zh-TW','en'])await i18next.changeLanguage(l);
   const noReward=before===businessSnapshot()&&inf===17&&toasts.length===1&&entries.length===1;
   // Manque véritable d’une clé : le moteur commun restitue son français initial.
   delete i18next.getResourceBundle('de','translation').playerMissions.obj_president;
   await i18next.changeLanguage('de');
   const fallback=document.querySelector('[data-i18n="playerMissions.obj_president"]').textContent;
   // Écran différent : les anciens attributs de titre n’ont pas survécu.
   document.getElementById('postes-modal-title').textContent='Autre fenêtre';
   document.getElementById('postes-body').innerHTML='<div><textarea id="draft">Mon brouillon</textarea><p>Texte inconnu</p></div>';
   const draft=document.getElementById('draft');draft.focus();draft.setSelectionRange(1,4);
   await i18next.changeLanguage('ar');
   return {noReward,fallback,other:document.getElementById('postes-modal-title').textContent,unknown:document.querySelector('#postes-body p').textContent,draft:[draft.value,draft===document.activeElement,draft.selectionStart,draft.selectionEnd],sameBusiness:before===businessSnapshot()};
  });
  assert.deepEqual(result,{noReward:true,fallback:'Devenir Président de votre empire',other:'Autre fenêtre',unknown:'Texte inconnu',draft:['Mon brouillon',true,1,4],sameBusiness:true});
  await page.close();
 }finally{await browser.close();}
});
