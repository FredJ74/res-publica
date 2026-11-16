'use strict';
const{test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process'),{parse}=require('../audits/audit-i18n-global.cjs');
const root=path.resolve(__dirname,'../..'),assets=process.env.BUILDING_HEADER_ASSET_DIR||root,read=f=>fs.readFileSync(path.join(assets,f),'utf8'),base='5e5a21edee169606e0c331be6a8769578dac54da',old=f=>execFileSync('git',['show',base+':'+f],{cwd:root,encoding:'utf8',maxBuffer:5e6}),langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function fn(s,name){const n=parse(s).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===name);assert.ok(n,name);return s.slice(n.start,n.end)}
function resources(source){const c={RP_I18N_RESOURCES:Object.fromEntries(langs.map(l=>[l,{translation:{}}]))};c.window=c;vm.createContext(c);vm.runInContext(source,c);return JSON.parse(JSON.stringify(c.RP_I18N_RESOURCES));}
const recorded=JSON.parse(fs.readFileSync(path.join(root,'outils/audits/I18N-BUILDING-HEADER-20261116-preuve.json'))),snapshot=(commit,f)=>execFileSync('git',['show',commit+':'+f],{cwd:root,encoding:'utf8',maxBuffer:5e6});
const keys=['buildingArmoryManage','buildingArmoryTooltip','buildingCashLoading','buildingCashAmount','buildingCashUnavailable','buildingDirectorLoading','buildingDirectorName','buildingDirectorVacant','buildingDirectorUnavailable'];
test('neuf textes / 72 valeurs : français exact, neuf langues, variables et anciennes ressources conservées',()=>{
 const before=resources(old('i18n/plateau-resources.js')),after=resources(snapshot(recorded.codeCommit,'i18n/plateau-resources.js')),current=resources(read('i18n/plateau-resources.js'));
 const french=['Gérer mon armurerie','Accéder à la gestion de mon commerce','Caisse : ...','Caisse : {{values.amount}} {{values.currency}}','Caisse : indisponible','Directeur : ...','Directeur : {{values.name}}','Directeur : poste vacant','Directeur : indisponible'];
 for(const l of langs){const a=after[l].translation.plateau,b=before[l].translation.plateau;assert.deepEqual(Object.keys(a).filter(k=>!(k in b)),keys);for(const [i,k]of keys.entries()){assert.ok(current[l].translation.plateau[k].trim());assert.deepEqual(current[l].translation.plateau[k].match(/\{\{[^}]+\}\}/g)||[],french[i].match(/\{\{[^}]+\}\}/g)||[]);if(l==='fr')assert.equal(current[l].translation.plateau[k],french[i]);else assert.notEqual(current[l].translation.plateau[k],french[i]);assert.ok(a[k].trim());if(l==='fr')assert.equal(a[k],french[i]);else assert.notEqual(a[k],french[i]);assert.deepEqual(a[k].match(/\{\{[^}]+\}\}/g)||[],french[i].match(/\{\{[^}]+\}\}/g)||[]);}for(const k of keys)delete a[k];assert.deepEqual(a,b,l);}
});
test('toute la mécanique de navigation identique à main : fonctions, conditions, RPC, permissions, données et paramètres',()=>{
 const before=parse(old('plateau-navigation.js')),after=parse(snapshot(recorded.codeCommit,'plateau-navigation.js'));
 const clean=n=>JSON.parse(JSON.stringify(n,(k,v)=>['start','end','loc','raw'].includes(k)?undefined:v));
 function strip(n){if(!n||typeof n!=='object')return n;if(Array.isArray(n))return n.map(strip).filter(v=>v!==null);
  if(n.type==='FunctionDeclaration'&&n.id.name==='rpBuildingHeaderText')return null;
  if(n.type==='VariableDeclaration'&&n.declarations.every(d=>d.id.name==='rpHeaderAmount'))return null;
  if(n.type==='ExpressionStatement'){let e=n.expression;if(e.type==='ChainExpression')e=e.expression;const c=e.callee;
   if(e.type==='AssignmentExpression'&&e.left.type==='MemberExpression'&&['elCaisse','elDirecteur'].includes(e.left.object.name)&&['textContent','title'].includes(e.left.property.name))return null;
   if(e.type==='CallExpression'&&(c.name==='rpBuildingHeaderText'||(c.property?.name==='apply'&&c.object?.property?.name==='RPI18nPlateau')||c.object?.name==='elCaisse'&&['setAttribute','removeAttribute'].includes(c.property?.name)&&e.arguments[0]?.value==='data-i18n-title'))return null;
  }
  return Object.fromEntries(Object.entries(n).map(([k,v])=>[k,strip(v)]));
 }
 assert.deepEqual(strip(clean(after)),strip(clean(before)));
 const proof=JSON.parse(fs.readFileSync(path.join(root,'outils/audits/I18N-BUILDING-HEADER-20261116-preuve.json'))),changed=execFileSync('git',['diff','--name-only',base,proof.codeCommit],{cwd:root,encoding:'utf8'}).trim().split('\n');
 assert.deepEqual(changed.filter(f=>!['RELAIS.md','plateau-navigation.js','plateau.html','i18n/plateau-resources.js','i18n/packed/plateau-resources.js.br','outils/audits/I18N-CATALOGUES-TRANSPORT.json'].includes(f)),[]);
 for(const f of ['data.js','supabase.js','i18n/plateau-init.js','style.css'])assert.equal(execFileSync('git',['show',proof.codeCommit+':'+f],{cwd:root,encoding:'utf8',maxBuffer:5e6}),old(f),f);
});
test('miroir généré : lieux actuels, noms et casting conservés, aucune fonction de dialogue modifiée',()=>{
 const local=f=>fs.readFileSync(path.join(root,f),'utf8'),generator=snapshot(recorded.maintenanceCodeCommit,'outils/generateurs/generer-pnj-lieux-metiers.cjs');
 assert.equal(generator.replace('piece: r?.name || ctx?.roomsExtra?.[piece]?.name || b.rooms?.[piece]?.name || piece,','piece: r?.name || b.rooms?.[piece]?.name || piece,'),old('outils/generateurs/generer-pnj-lieux-metiers.cjs'));
 const table=s=>JSON.parse(s.slice(s.indexOf('{'),s.lastIndexOf('}')+1)),before=table(old('api/_pnj-scenes-generes.js')),after=table(snapshot(recorded.maintenanceCodeCommit,'api/_pnj-scenes-generes.js'));
 const k=(...parts)=>JSON.stringify(parts),removed=k('soviet','ville_a','centre-affaires','tribune_republia'),press=k('soviet','ville_a','presse-starovka','presse'),library=k('soviet','ville_a','universite','bibliotheque'),partis=k('soviet','ville_b','mairie','salle_partis');
 assert.deepEqual(Object.keys(before).filter(k=>!after[k]),[removed]);assert.deepEqual(Object.keys(after).filter(k=>!before[k]).sort(),[press,library].sort());
 for(const key of Object.keys(before).filter(k=>after[k]))if(key===partis){assert.deepEqual({...after[key],piece:before[key].piece},before[key]);assert.equal(before[key].piece,'salle_partis');assert.equal(after[key].piece,'Salle des partis');}else assert.deepEqual(after[key],before[key],key);
 assert.deepEqual(after[press].personnes,before[removed].personnes);assert.deepEqual(after[library].personnes,[]);
 const people=o=>Object.values(o).flatMap(s=>s.personnes).sort();assert.deepEqual(people(after),people(before),'aucun PNJ ajouté, retiré ou renommé');
 for(const f of ['api/chat.js','api/_pnj-localisation.js','api/_pnj-profils.js','api/_pnj-personnalites.js'])assert.equal(snapshot(recorded.maintenanceCodeCommit,f),old(f),f);
 assert.equal(execFileSync(process.execPath,['outils/generateurs/generer-pnj-lieux-metiers.cjs','--scenes-js'],{cwd:root,encoding:'utf8',maxBuffer:5e6}),local('api/_pnj-scenes-generes.js'));
});
test('Chromium : vrais en-têtes, neuf langues, 320/390/1280, attentes/réponses/permissions, français et commandes identiques à main',async()=>{
 const{chromium}=require('playwright'),browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox']});let switches=0;const covered=new Set();
 const cases=[
  {id:'usine-principale',city:'ville_a',name:'Angie <img src=x> « Directeur »'},
  {id:'distillerie-krasnov',city:'ville_b',name:'Kouzma Lapchine'},
  {id:'usine-principale',city:'ville_a',pnj:true},{id:'distillerie-krasnov',city:'ville_b',pnj:true},
  {id:'usine-principale',city:'ville_a',vacant:true},{id:'usine-principale',city:'ville_a',error:true},
  {id:'armurerie',owner:true},{id:'armurerie',owner:false},{id:'armurerie',error:true},
  {id:'entrepot-logistique-luthecia',country:'republic',amount:1234.5},{id:'entrepot-logistique-luthecia',error:true},
  ...['capitale','ville_a','ville_b'].map(city=>({id:city==='capitale'?'commissariat':'commissariat-local',city,authorized:true,amount:3050.25})),
  {id:'commissariat-local',authorized:false},{id:'commissariat-local',error:true},{id:'mairie'},
 ];
 try{for(const width of [320,390,1280]){const p=await browser.newPage({viewport:{width,height:800}}),errors=[],network=[];p.on('pageerror',e=>errors.push(String(e)));await p.route('**/*',r=>{network.push(r.request().url());return r.abort();});
 const html=read('plateau.html'),start=html.indexOf('<div class="batiment-header">',html.indexOf('<div id="vue-batiment"')),end=html.indexOf('\n      <!-- Image de la piece -->',start),header=html.slice(start,end);assert.ok(start>=0&&end>start);
 await p.setContent('<!doctype html><html lang="fr"><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body class="plateau-body"><main id="fixture"></main></body></html>');await p.addStyleTag({content:read('style.css')});
 await p.addScriptTag({content:read('i18n/i18next.min.js')});await p.evaluate(()=>{window.RP_I18N_GAME_ENABLED=true;window.RPPlateauI18n={language:()=>i18next.language||'fr'};window.state={country:'soviet',currentCity:'ville_a'};});await p.addScriptTag({content:read('data.js')});for(const file of ['i18n/resources.js','i18n/plateau-resources.js','i18n/plateau-init.js'])await p.addScriptTag({content:read(file)});
 await p.addScriptTag({content:fn(read('plateau-navigation.js'),'getBuildingContext')+'\n'+fn(read('plateau-navigation.js'),'rpBuildingHeaderText')+'\n'+fn(read('plateau-navigation.js'),'enterBuilding')+'\n'+fn(old('plateau-navigation.js'),'enterBuilding').replace('function enterBuilding(','function enterBuildingOriginal(')});
 await p.evaluate(header=>{
  window.realContext=getBuildingContext;window.headerTemplate=header;window.trace=[];window.pending=[];
  window.renderOngletsPieces=id=>{trace.push(['rooms',id]);return [['hall',{}]]};window.updateLocationDisplay=()=>trace.push(['location']);window.deplacerGroupeAvecPj=(...args)=>trace.push(['group',...args]);window.addJournalEntry=(...args)=>trace.push(['journal',...args]);window.enterRoom=(...args)=>trace.push(['room',...args]);window.doGererArmurerie=()=>trace.push(['manageArmory']);
  window.getBuildingIdCommissariat=city=>'commissariat-'+city;
  for(const name of ['chargerArmurerieLocale','sbGetBatimentEtat','getTitulaireActuel','lireCaisseCommissariat'])window[name]=(...args)=>{trace.push([name,...args]);return new Promise((resolve,reject)=>pending.push({name,resolve,reject}))};
  window.showToast=(...args)=>trace.push(['toast',...args]);window.fetch=(...args)=>{trace.push(['FORBIDDEN_FETCH',...args]);throw Error('fetch interdit')};
  window.headerUI=()=>Object.fromEntries(['bat-caisse','bat-directeur'].map(id=>{const n=document.getElementById(id);return[id,{text:n.textContent,title:n.title,display:n.style.display,click:n.onclick===doGererArmurerie}]}));
  window.stable=()=>JSON.stringify({state,trace,input:document.getElementById('draft').value,focus:document.activeElement.id,start:document.getElementById('draft').selectionStart,end:document.getElementById('draft').selectionEnd,scroll:document.getElementById('scroll').scrollTop});
  window.beginCase=async(c,original)=>{if(window.restorePeople){restorePeople();restorePeople=null;}window.getBuildingContext=realContext;await i18next.changeLanguage('fr');document.getElementById('fixture').innerHTML='<div id="vue-rue" class="active"></div><div id="vue-batiment" class="vue">'+headerTemplate+'</div><input id="draft" value="Brouillon intact"><div id="scroll" style="height:100px;overflow:auto"><div style="height:900px">Repère</div></div>';window.state={country:c.country||'soviet',currentCity:c.city||'ville_b',char:{name:'Fixture',country:c.country||'soviet'},pa:8,arg:900,inventory:[{id:'intact'}],progression:{stage:3},currentBuilding:null,currentRoom:null,day:2};trace.length=0;pending.length=0;
   if(c.vacant){window.getBuildingContext=()=>null;const room=BUILDINGS[c.id].rooms.bureau_direction;if(room){const people=room.persons;room.persons=[];window.restorePeople=()=>{room.persons=people}}}
   (original?enterBuildingOriginal:enterBuilding)(c.id,false);document.getElementById('draft').focus();document.getElementById('draft').setSelectionRange(2,6);document.getElementById('scroll').scrollTop=300;return {ui:headerUI(),stable:stable()};};
  window.answerCase=async c=>{for(const q of pending.splice(0)){if(c.error){q.reject(Error('panne fixture'));continue;}q.resolve(q.name==='chargerArmurerieLocale'?{proprietaire:c.owner?'Fixture':'autre'}:q.name==='getTitulaireActuel'?(c.pnj||c.vacant?null:{nom:c.name||'Damdin Mazoutov'}):q.name==='sbGetBatimentEtat'?{entrepot:{caisse:c.amount??500}}:{ok:!!c.authorized,solde:c.amount??500});}await new Promise(r=>setTimeout(r,0));return {ui:headerUI(),stable:stable()};};
 },header);
 await p.evaluate(()=>document.fonts.ready);
 for(const c of cases){const before=await p.evaluate(c=>beginCase(c,true),c),after=await p.evaluate(c=>answerCase(c),c);await p.evaluate(()=>i18next.changeLanguage('en'));assert.deepEqual(await p.evaluate(()=>headerUI()),after.ui,'main reste français malgré les ressources disponibles');const now=await p.evaluate(c=>beginCase(c,false),c);assert.deepEqual(now,before,'français et appels avant réponse : '+JSON.stringify(c));
 for(const phase of ['waiting','answered']){if(phase==='answered'){await p.evaluate(()=>i18next.changeLanguage('fr'));const got=await p.evaluate(c=>answerCase(c),c);assert.deepEqual(got,after,'français et appels après réponse : '+JSON.stringify(c));}
  const stable=await p.evaluate(()=>window.stable()),requests=network.length;
  for(const lang of langs){const result=await p.evaluate(async lang=>{await i18next.changeLanguage(lang);const nodes=['bat-caisse','bat-directeur'].map(id=>document.getElementById(id)),labels=nodes.filter(n=>n.style.display!=='none').flatMap(n=>[...n.querySelectorAll('[data-i18n]')].map(s=>({key:s.dataset.i18n,text:s.textContent,expected:i18next.t(s.dataset.i18n,{values:JSON.parse(s.dataset.i18nValues||'{}')}),dir:s.dir,inside:s.parentElement.scrollWidth<=s.parentElement.clientWidth+1})));const cash=nodes[0];return{stable:window.stable(),labels,title:cash.title,titleKey:cash.dataset.i18nTitle,expectedTitle:cash.dataset.i18nTitle?i18next.t(cash.dataset.i18nTitle):'',overflow:document.documentElement.scrollWidth>innerWidth,images:document.querySelectorAll('#bat-caisse img,#bat-directeur img').length};},lang);assert.equal(result.stable,stable);assert.equal(network.length,requests);assert.equal(result.overflow,false,JSON.stringify(c)+' '+lang+'/'+width);assert.equal(result.images,0);for(const label of result.labels){covered.add(label.key.replace('plateau.',''));assert.equal(label.text,label.expected);assert.equal(label.dir,lang==='ar'?'rtl':'');assert.equal(label.inside,true,lang+'/'+width+'/'+label.key);}if(result.titleKey){covered.add('buildingArmoryTooltip');assert.equal(result.title,result.expectedTitle);}else assert.equal(result.title,'');switches++;}
 }
 if(c.owner){await p.locator('#bat-caisse').click();assert.equal(await p.evaluate(()=>trace.at(-1)[0]),'manageArmory');}
 }
 // Une réponse arrive dans la langue courante, sans refaire la lecture.
 await p.evaluate(()=>beginCase({id:'usine-principale',city:'ville_a'},false));await p.evaluate(()=>i18next.changeLanguage('ar'));await p.evaluate(()=>answerCase({name:'Nom conservé'}));assert.match(await p.locator('#bat-directeur').textContent(),/^المدير:/);
 // Une réponse périmée ne réaffiche pas le directeur après une sortie du bâtiment.
 await p.evaluate(()=>beginCase({id:'usine-principale',city:'ville_a'},false));await p.evaluate(()=>{state.currentBuilding='mairie';document.getElementById('bat-directeur').style.display='none'});await p.evaluate(()=>answerCase({name:'Ne doit pas remplacer'}));assert.equal(await p.locator('#bat-directeur').evaluate(n=>n.style.display),'none');
 // Même élément : quitter la gestion de l’armurerie efface son ancienne infobulle.
 await p.evaluate(async()=>{await beginCase({id:'armurerie',owner:true},false);await answerCase({owner:true});await i18next.changeLanguage('en');window.sameOwnerNode=document.getElementById('bat-caisse');enterBuilding('entrepot-logistique-luthecia',true);await answerCase({amount:345});await i18next.changeLanguage('ar');});assert.equal(await p.locator('#bat-caisse').getAttribute('data-i18n-title'),null);assert.equal(await p.locator('#bat-caisse').getAttribute('title'),'');assert.equal(await p.evaluate(()=>document.getElementById('bat-caisse')===sameOwnerNode),true);
 // Repli après deux soldes différents : aucun ancien français mis en cache.
 await p.evaluate(async()=>{await beginCase({id:'entrepot-logistique-luthecia',country:'republic'},false);await answerCase({amount:1111});window.sameCashNode=document.getElementById('bat-caisse');enterBuilding('entrepot-logistique-luthecia',true);await answerCase({amount:2222});i18next.removeResourceBundle('de','translation');await i18next.changeLanguage('de');});assert.equal(await p.locator('#bat-caisse').textContent(),'Caisse : 2\u202f222 FR');assert.equal(await p.evaluate(()=>document.getElementById('bat-caisse')===sameCashNode),true);
 assert.deepEqual(errors,[]);await p.close();}}
 finally{await browser.close();}assert.deepEqual([...covered].sort(),keys.slice().sort());console.log(switches+' bascules principales, neuf clés exercées, réponses et intentions identiques à main.');
});
