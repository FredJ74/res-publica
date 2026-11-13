'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {chromium}=require('playwright'),{parse,walk}=require('../audits/audit-i18n-global.cjs');
const root=process.env.FORUM_FEEDBACK_ASSET_DIR||path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function fn(s,name){let a=s.indexOf('function '+name+'(');assert.ok(a>=0,name);if(s.slice(a-6,a)==='async ')a-=6;return s.slice(a,s.indexOf('\n}',a)+2);}
function cases(){const found=new Map(),source=read('forum.js'),expression=n=>n?.expression?.type==='ChainExpression'?n.expression.expression:n?.expression;
 function collect(key,fr,title,success,crit){if(key.type==='ConditionalExpression'){collect(key.consequent,fr.consequent,title,success,crit);collect(key.alternate,fr.alternate,title,success,crit);return;}
  if(key.type==='Literal'&&key.value===null)return;assert.equal(key.type,'Literal');assert.equal(fr.type,'Literal');found.set(key.value+'|'+title,{key:key.value,fr:fr.value,title,success,crit});}
 walk(parse(source),n=>{if(n.type!=='BlockStatement')return;for(let i=1;i<n.body.length;i++){const first=expression(n.body[i-1]),next=expression(n.body[i]);if(first?.callee?.name==='showToast'&&next?.callee?.property?.name==='markToast')collect(next.arguments[0],next.arguments[1],first.arguments[0].value,first.arguments[2]?.value,first.arguments[3]?.value);}});
 assert.equal(found.size,31);return [...found.values()];
}
test('forum : 31 messages, neuf langues, 320/390/1280, titres/RTL et garde des brouillons sans RPC',async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox']});
 try{for(const width of [320,390,1280]){
  const page=await browser.newPage({viewport:{width,height:780}}),errors=[];page.on('pageerror',e=>errors.push(String(e)));await page.route('**/*',r=>r.abort());
  await page.setContent('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body class="plateau-body"><input id="draft" value="Sujet conservé"><div id="compose-body" contenteditable="true"><b>Brouillon conservé</b></div><input id="mail-to"><input id="mail-subject" value="Sujet de courrier"><input id="new-topic-title"><div id="new-topic-content" contenteditable="true">Texte</div><div id="reply-content" contenteditable="true"></div><input id="compose-canvas-title" value="Titre conservé"><div id="result-toast"><div id="toast-result" class="toast-result"></div><div id="toast-sub" class="toast-sub"></div></div></body></html>');
  await page.addStyleTag({content:read('style.css')});await page.addScriptTag({content:read('i18n/i18next.min.js')});
  await page.evaluate(()=>{
   window.RP_I18N_GAME_ENABLED=true;window.RPPlateauI18n={language:()=>i18next.language||'fr'};window.calls=[];window.incidents=[];
   window.state={char:{name:'Fixture',career:'none'},poste:null,country:'fixture',currentCity:'fixture',pa:20,arg:500,progression:{stage:2}};
   window.noterIncidentSession=(...a)=>incidents.push(a);window.hospital=false;window.hospitalisationEcritureInterdite=()=>hospital;window.sanitizeRichHtml=s=>s||'';
   window.executerOrdreJaugesServeur=(...a)=>{calls.push(['rpc',...a]);throw Error('RPC inattendue');};window.sendMail=(...a)=>{calls.push(['mail',...a]);throw Error('Envoi inattendu');};
   window.fetch=()=>{calls.push('network');throw Error('Réseau inattendu');};window.sbCreateTopic=window.fetch;window.sbCreatePost=window.fetch;
   window.currentForumId='general';window.currentTopicId=null;window.editingTopicId=null;window.editingPostId=null;
   window.rpCanvasSerializeCompose=()=>{calls.push('serialize');return {elements:[]};};window.idForumLocal=()=> 'local_fixture';
   window.snapshot=()=>JSON.stringify({state,calls,incidents,lock:_mailEnvoiEnCours,timer:window._toastTimer,draft:document.getElementById('draft').value,rich:document.getElementById('compose-body').innerHTML,focus:document.activeElement.id,start:document.getElementById('draft').selectionStart,end:document.getElementById('draft').selectionEnd});
  });
  for(const f of ['i18n/resources.js','i18n/plateau-resources.js','i18n/player-directory-resources.js','i18n/toast-resources.js','i18n/forum-feedback-resources.js','i18n/plateau-init.js'])await page.addScriptTag({content:read(f)});
  const forum=read('forum.js');await page.addScriptTag({content:'let _mailEnvoiEnCours=false;\n'+fn(read('plateau-core.js'),'showToast')+'\n'+['submitMail','submitNewTopic','submitReply','submitReplyComposed','submitComposeCanvas','forumPublierAvecJauges'].map(n=>fn(forum,n)).join('\n')});
  await page.evaluate(()=>{document.getElementById('draft').focus();document.getElementById('draft').setSelectionRange(3,8);});
  for(const example of cases()){
   await page.evaluate(async e=>{await i18next.changeLanguage('fr');showToast(e.title,e.fr,e.success,e.crit);RPI18nPlateau.markToast(e.key,e.fr,undefined,e.title);window.before=snapshot();},example);
   for(const l of locales){const got=await page.evaluate(async ({l,e})=>{await i18next.changeLanguage(l);return {body:document.getElementById('toast-sub').textContent,title:document.getElementById('toast-result').textContent,expected:i18next.t(e.key),expectedTitle:RPToastI18n.label(e.title),same:snapshot()===before,overflow:document.documentElement.scrollWidth>innerWidth,dir:document.querySelector('#toast-sub [data-i18n]')?.dir};},{l,e:example});
    assert.equal(got.body,l==='fr'?example.fr:got.expected,example.key+'/'+l);assert.equal(got.title,l==='fr'?example.title:got.expectedTitle);assert.equal(got.same,true);assert.equal(got.overflow,false,example.key+'/'+l+'/'+width);assert.equal(got.dir,l==='ar'?'rtl':'');
   }
  }
  // Chemins réels de validation : les autres scénarios ont été rendus sans rejouer de transaction.
  const guards=[['submitMail','required'],['submitMail','hospital'],['submitNewTopic','hospital'],['submitReply','hospital'],['submitReplyComposed','hospital'],['submitNewTopic','president'],['submitNewTopic','journalists'],['submitNewTopic','fields'],['submitReply','empty'],['submitComposeCanvas','emptyTopic'],['submitComposeCanvas','emptyReply'],['submitComposeCanvas','emptyEdit'],['forumPublierAvecJauges','local']];
  for(const [name,kind]of guards){
   await page.evaluate(async ({name,kind})=>{
    hospital=kind==='hospital';currentForumId=kind==='president'?'presidence':kind==='journalists'?'presse':kind==='local'?'local_stale':'general';currentTopicId=kind==='emptyReply'?1:null;editingTopicId=kind==='emptyEdit'?1:null;editingPostId=kind==='emptyEdit'?2:null;
    calls.length=0;document.getElementById('mail-to').value='';await window[name]();window.before=snapshot();
   },{name,kind});
   for(const l of locales){await page.evaluate(l=>i18next.changeLanguage(l),l);assert.equal(await page.evaluate(()=>snapshot()===before),true);}
   assert.equal(await page.evaluate(()=>calls.some(c=>Array.isArray(c)||c==='network')),false,name+'/'+kind);
  }
  // Traduction absente : français exact, et prochaine alerte non marquée sans résurrection.
  await page.evaluate(async()=>{delete i18next.getResourceBundle('de','translation').forumFeedback.imageUrl;await i18next.changeLanguage('fr');showToast('URL manquante',"Indiquez une adresse d'image.",false);RPI18nPlateau.markToast('forumFeedback.imageUrl',"Indiquez une adresse d'image.",undefined,'URL manquante');await i18next.changeLanguage('de');});
  assert.equal(await page.locator('#toast-sub').textContent(),"Indiquez une adresse d'image.");
  await page.evaluate(()=>showToast('Autre alerte','Texte non marqué',false));await page.evaluate(()=>i18next.changeLanguage('ar'));assert.equal(await page.locator('#toast-sub').textContent(),'Texte non marqué');assert.equal(await page.locator('#toast-result').textContent(),'Autre alerte');
  assert.deepEqual(errors,[]);await page.close();
 }}finally{await browser.close();}
});
