// Authentification fictive uniquement : conservation du contrat existant, aucun compte créé.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),zlib=require('node:zlib'),crypto=require('node:crypto');
const acorn=require('../vercel/node_modules/acorn'),engineModule=require('../../i18n/i18next.min.js');
const {avecJeu,R}=require('./mobile-navigateur.cjs');
const snapshot=fs.readFileSync(path.join(__dirname,'fixtures/i18n-connexion-temoin-02319679.json.gz'));
assert.equal(crypto.createHash('sha256').update(snapshot).digest('hex'),'5a3a9efc689b997a7aabe4943951787877a81078cc1df7cc821002173c4f709d');
const ancien=JSON.parse(zlib.gunzipSync(snapshot));
const names=['connecterAvecMotDePasse','rpMessageIdentifiants','ouvrirConnexionCompte'];
const source=fs.readFileSync(path.join(R,'creation.js'),'utf8');
const code=acorn.parse(source,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&names.includes(n.id.name)).map(n=>source.slice(n.start,n.end)).join('\n');
const vieux=names.map(n=>ancien.functions[n]).join('\n');
const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
async function bac(locale,cas,old=false){
 const w={};const cat=vm.createContext({window:w});
 for(const f of ['resources.js','connection-resources.js'])vm.runInContext(fs.readFileSync(path.join(R,'i18n',f),'utf8'),cat);
 const engine=engineModule.createInstance();await engine.init({lng:locale,fallbackLng:'fr',resources:w.RP_I18N_RESOURCES,interpolation:{escapeValue:false}});
 const calls=[],storage=new Map(),timers=[],elements={};
 const element=id=>elements[id]??={value:'',textContent:'',style:{},attrs:{},setAttribute(k,v){this.attrs[k]=String(v)},removeAttribute(k){delete this.attrs[k]}};
 element('connexion-email').value=cas==='email'?'incorrect':'fixture@example.invalid';element('connexion-mdp').value=cas==='password'?'':'secret-fictif';
 const returned={char:{name:'Nom canonique <原 & اسم>',photoUrl:'fixture.webp'},country:'republic',currentCity:'ville_a',arg:0,inf:0,pop:0,dis:0};
 const c=vm.createContext({window:{location:{href:'index.html'}},i18next:engine,document:{getElementById:element},console:{warn(){}},
  localStorage:{setItem(k,v){storage.set(k,String(v))}},setTimeout(f,ms){timers.push({f,ms})},rpMarquerProprietaireCache(){calls.push(['cacheOwner'])},
  rpAuthSeConnecter:async(email,pwd)=>{calls.push(['auth',email,pwd]);return ['bad','unknown','rate','validation'].includes(cas)?{ok:false,raison:{bad:'invalid_credentials',unknown:'user_not_found',rate:'over_request_rate_limit',validation:'validation_failed'}[cas]}:{ok:true}},
  sbRpc:async(fn,args)=>{calls.push(['rpc',fn,args]);return cas==='noCharacter'?null:cas==='array'?[{mon_personnage:'Nom canonique <原 & اسم>'}]:'Nom canonique <原 & اسم>'},
  sbLoadPersonnage:async nom=>{calls.push(['load',nom]);return cas==='loadFail'?null:structuredClone(returned)}});
 if(cas==='unavailable')delete c.rpAuthSeConnecter;
 vm.runInContext(old?vieux:code,c);await c.connecterAvecMotDePasse();
 const message=elements['connexion-msg'].textContent;
 for(const t of timers)t.f();
 return {message,calls:JSON.parse(JSON.stringify(calls)),cache:[...storage],timers:timers.map(t=>t.ms),href:c.window.location.href,
  key:elements['connexion-msg'].attrs['data-i18n'],resources:w.RP_I18N_RESOURCES,button:elements['connexion-valider']?.disabled};
}
test('neuf messages complets, nom paramétré dans neuf langues',async()=>{
 const sample=await bac('fr','email');const keys=Object.keys(sample.resources.fr.translation.connectionUi);assert.equal(keys.length,9);
 for(const l of locales){const words=sample.resources[l].translation.connectionUi;assert.deepEqual(Object.keys(words),keys);for(const v of Object.values(words))assert.ok(v.trim());assert.match(words.welcome,/{{values.name}}/)}
});
for(const l of locales)test('connexion '+l+' : mêmes appels, cache, droits et redirection que main',async()=>{
 for(const cas of ['email','password','unavailable','bad','unknown','rate','validation','noCharacter','loadFail','success','array']){
  const before=await bac('fr',cas,true),after=await bac(l,cas);
  assert.deepEqual(after.calls,before.calls,cas);assert.deepEqual(after.cache,before.cache,cas);
  assert.deepEqual(after.timers,before.timers,cas);assert.equal(after.href,before.href,cas);
  assert.equal(after.button,before.button,cas);assert.doesNotMatch(after.message,/{{|connectionUi\./);
  const k=after.key.split('.')[1],text=after.resources[l].translation.connectionUi[k].replace('{{values.name}}','Nom canonique <原 & اسم>');
  assert.equal(after.message,text,cas);if(l==='fr')assert.equal(after.message,before.message,cas);
 }
 const a=await bac(l,'bad'),b=await bac(l,'unknown');assert.equal(a.message,b.message,'aucune énumération de comptes');
});
async function pageConnexion(b,o,old=false,width=360){
 const p=await b.newPage({viewport:{width,height:900}});
 await p.route('**/*',r=>{const u=new URL(r.request().url());if(u.origin!==o)return r.abort();
  if(u.pathname==='/index.html')return r.fulfill({contentType:'text/html',body:fs.readFileSync(path.join(R,'index.html'),'utf8').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'')});return r.continue()});
 await p.goto(o+'/index.html');
 for(const f of ['i18next.min.js','resources.js','connection-resources.js','i18n-init.js'])await p.addScriptTag({path:path.join(R,'i18n',f)});
 await p.evaluate(()=>changerLangueRP('fr'));await p.addScriptTag({content:old?vieux:code});await p.evaluate(()=>{ouvrirConnexionCompte();window._authCalls=0;window._rpcCalls=0;
  window.rpAuthSeConnecter=()=>{_authCalls++;return new Promise(r=>window._resolveAuth=r)};window.sbRpc=async()=>{_rpcCalls++;return 'Nom <原 & اسم>'};
  window.sbLoadPersonnage=async()=>({char:{name:'Nom <原 & اسم>'},country:'republic',currentCity:'capitale',arg:0,inf:0,pop:0,dis:0});window.rpMarquerProprietaireCache=()=>{};
 });return p;
}
test('vrai formulaire : bascule pendant requête, erreur uniforme puis succès, aucune saisie perdue',()=>avecJeu(async(b,o)=>{
 const p=await pageConnexion(b,o);await p.fill('#connexion-email','fixture@example.invalid');await p.fill('#connexion-mdp','secret-fictif');
 await p.evaluate(()=>{window._pending=connecterAvecMotDePasse()});await p.click('#lang-btn-ar');
 assert.equal(await p.locator('#connexion-msg').textContent(),await p.evaluate(()=>RP_I18N_RESOURCES.ar.translation.connectionUi.working));
 assert.equal(await p.locator('#connexion-valider').isDisabled(),true);
 await p.evaluate(()=>_resolveAuth({ok:false,raison:'user_not_found'}));await p.evaluate(()=>_pending);
 for(const l of ['de','fr','ko','ar']){await p.click('#lang-btn-'+l);assert.equal(await p.locator('#connexion-msg').textContent(),await p.evaluate(l=>RP_I18N_RESOURCES[l].translation.connectionUi.invalidCredentials,l));assert.equal(await p.inputValue('#connexion-email'),'fixture@example.invalid');assert.equal(await p.inputValue('#connexion-mdp'),'secret-fictif')}
 assert.deepEqual(await p.evaluate(()=>[_authCalls,_rpcCalls]),[1,0]);
 await p.evaluate(()=>{window._timers=[];window.setTimeout=(f,ms)=>{_timers.push(ms);return 1};window._pending=connecterAvecMotDePasse()});
 await p.evaluate(()=>_resolveAuth({ok:true}));await p.evaluate(()=>_pending);await p.click('#lang-btn-fr');
 assert.equal(await p.locator('#connexion-msg').textContent(),'Bienvenue, Nom <原 & اسم>. Chargement…');
 assert.equal(await p.locator('#connexion-msg *').count(),0,'nom serveur jamais interprété comme HTML');
 assert.deepEqual(await p.evaluate(()=>[_authCalls,_rpcCalls,_timers]),[2,1,[700]]);
 for(const width of [360,390,768]){await p.setViewportSize({width,height:900});for(const l of locales){
  await p.click('#lang-btn-'+l);assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'débordement '+l+' '+width);
  assert.equal(await p.locator('#connexion-msg *').count(),0);assert.match(await p.locator('#connexion-msg').textContent(),/Nom <原 & اسم>/);
 }}
 assert.deepEqual(await p.evaluate(()=>[_authCalls,_rpcCalls,_timers]),[2,1,[700]],'une bascule ne relance jamais la connexion');
 await p.evaluate(()=>{const m=document.getElementById('connexion-msg');m.setAttribute('data-i18n-values','{invalide');appliquerTraductionsRP()});
 assert.equal(await p.locator('#connexion-msg').textContent(),'Bienvenue, Nom <原 & اسم>. Chargement…','format invalide : français canonique');
 await p.evaluate(()=>{const m=document.getElementById('connexion-msg');m.setAttribute('data-i18n-values','{}');appliquerTraductionsRP()});
 assert.equal(await p.locator('#connexion-msg').textContent(),'Bienvenue, Nom <原 & اسم>. Chargement…','variable absente : français canonique');
 await p.close();
}));
test('message français au bureau : même rendu que main',()=>avecJeu(async(b,o)=>{
 const shots=[];for(const old of [true,false]){const p=await pageConnexion(b,o,old,1440);await p.fill('#connexion-email','invalide');await p.evaluate(()=>connecterAvecMotDePasse());shots.push(await p.locator('#connexion-panel').screenshot({animations:'disabled'}));fs.writeFileSync('/tmp/i18n-connexion-desktop-'+old+'.png',shots.at(-1));await p.close()}
 assert.equal(Buffer.compare(...shots),0);
}));
