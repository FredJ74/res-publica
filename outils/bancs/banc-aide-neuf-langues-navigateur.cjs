const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),zlib=require('node:zlib'),crypto=require('node:crypto');
const {avecJeu,page}=require('./mobile-navigateur.cjs');
const archive=fs.readFileSync(__dirname+'/fixtures/aide-temoin-6b9f5d30.js.gz');
assert.equal(crypto.createHash('sha256').update(archive).digest('hex'),'aa666f0fc930344a5315c87856cb4ed6c6a23a25351b4c4d3fa76fa0ba270456');
const ancien=zlib.gunzipSync(archive).toString();
const questions=require('./fixtures/aide-questions-neuf-langues.json');
async function ouvrir(b,o,w=390,old=false){
 const p=await page(b,o,w,950);
 await p.addScriptTag({url:o+'/i18n/i18next.min.js'});
 await p.evaluate(async()=>{
  await i18next.init({lng:'fr',fallbackLng:'fr',resources:{fr:{translation:{}}}});
  window.RPPlateauI18n={language:()=>i18next.language};
  document.querySelectorAll('.vue').forEach(e=>e.classList.remove('active'));
  document.getElementById('vue-rules').classList.add('active');
  window.rpAuthAssurerSession=async()=>null;window.rpAuthJeton=()=> 'fixture';
 });
 await p.addScriptTag(old?{content:ancien}:{url:o+'/plateau-aide.js'});
 await p.evaluate(()=>renderAideHrp());return p;
}
for(const lang of Object.keys(questions))test('Aide '+lang+' : interface 360/390, Unicode, RTL et deux suggestions',async()=>avecJeu(async(b,o)=>{
 for(const width of [360,390]){
  const p=await ouvrir(b,o,width);await p.evaluate(l=>i18next.changeLanguage(l),lang);
  assert.equal(await p.locator('#rules-content').getAttribute('dir'),lang==='ar'?'rtl':'ltr');
  const labels=await p.locator('.aide-hrp').evaluate(e=>({heading:e.querySelector('h2').textContent,placeholder:e.querySelector('textarea').placeholder,send:e.querySelector('[type=submit]').textContent,suggestions:[...e.querySelectorAll('[data-question]')].map(x=>x.textContent),largeur:e.scrollWidth<=e.clientWidth+2}));
  assert.ok(labels.heading&&labels.placeholder&&labels.send);assert.equal(labels.suggestions.length,2);assert.ok(labels.largeur);
  if(lang!=='fr')assert.notEqual(labels.send,'Envoyer');
  await p.evaluate(()=>{window.calls=[];window.fetch=async(u,opt)=>{calls.push(JSON.parse(opt.body));return {ok:true,json:async()=>({reponse:'Fixture Unicode <img src=x onerror=alert(1)> 안녕 مرحبا 繁體中文'})}}});
  for(const kind of ['pa','goal']){await p.locator('[data-question='+kind+']').click();await p.waitForFunction(n=>document.querySelectorAll('.aide-hrp-assistant').length===n,kind==='pa'?1:2)}
  const calls=await p.evaluate(()=>calls);assert.equal(calls.length,2);assert.ok(calls.every(c=>c.lang===lang));assert.deepEqual(calls.map(x=>x.message),[labels.suggestions[1],labels.suggestions[0]]);
  assert.equal(await p.locator('#aide-hrp-fil img').count(),0);assert.equal(await p.locator('.aide-hrp-assistant[dir=auto]').count(),2);
  await p.evaluate(()=>{window.fetch=()=>new Promise(r=>window.echecFin=()=>r({ok:false,status:502}))});
  await p.locator('[data-question=pa]').click();await p.waitForFunction(()=>!!window.echecFin);
  const attente=await p.locator('#aide-hrp-statut').textContent();assert.ok(attente);if(lang!=='fr')assert.notEqual(attente,'Je cherche la meilleure réponse…');
  await p.evaluate(()=>echecFin());await p.waitForFunction(()=>!document.querySelector('#aide-hrp-envoyer').disabled);
  const erreur=await p.locator('#aide-hrp-statut').textContent();assert.ok(erreur);if(lang!=='fr')assert.notEqual(erreur,'La réponse n’a pas pu être chargée. Réessaie ou consulte les rubriques ci-dessus.');

  await p.close();
 }
}));
test('bascule fr→en→ko→fr pendant auth/réponse : verrou, brouillons et historique intacts',async()=>avecJeu(async(b,o)=>{
 const p=await ouvrir(b,o);await p.evaluate(()=>{window.calls=[];window.rpAuthAssurerSession=()=>new Promise(r=>window.authFin=r);window.fetch=(u,opt)=>{calls.push(JSON.parse(opt.body));return new Promise(r=>window.reponseFin=()=>r({ok:true,json:async()=>({reponse:'Réponse française '+ 'longue '.repeat(280)})}))}});
 await p.locator('#aide-hrp-question').fill(questions.fr.pa);await p.locator('#aide-hrp-envoyer').click();
 await p.locator('#aide-hrp-question').press('Enter');await p.locator('[data-question=goal]').click();
 await p.evaluate(()=>i18next.changeLanguage('en'));await p.locator('#aide-hrp-question').fill('new draft');
 assert.equal(await p.locator('#aide-hrp-envoyer').isDisabled(),true);assert.ok(await p.locator('#aide-hrp-statut').textContent());
 await p.evaluate(()=>authFin());await p.waitForFunction(()=>calls.length===1);assert.equal((await p.evaluate(()=>calls[0])).lang,'fr');
 await p.evaluate(()=>i18next.changeLanguage('ko'));assert.equal(await p.locator('#aide-hrp-question').inputValue(),'new draft');
 await p.evaluate(()=>reponseFin());await p.locator('.aide-hrp-assistant').waitFor();assert.equal(await p.locator('#aide-hrp-question').inputValue(),'new draft');
 await p.evaluate(()=>{window.rpAuthAssurerSession=async()=>null;window.fetch=async(u,opt)=>{calls.push(JSON.parse(opt.body));return {ok:true,json:async()=>({reponse:'한국어 응답'})}}});
 await p.locator('#aide-hrp-question').fill(questions.ko.but);await p.locator('#aide-hrp-envoyer').click();await p.waitForFunction(()=>document.querySelectorAll('.aide-hrp-assistant').length===2);
 const calls=await p.evaluate(()=>calls);assert.equal(calls.length,2);assert.equal(calls[1].lang,'ko');assert.equal(calls[1].historique[1].content.length,1500);assert.equal(await p.locator('.aide-hrp-assistant').first().textContent(),'Réponse française '+ 'longue '.repeat(280));
 await p.evaluate(()=>i18next.changeLanguage('fr'));assert.equal(await p.locator('.aide-hrp-bulle').count(),4);assert.equal(await p.locator('#aide-hrp-envoyer').isDisabled(),false);await p.close();
}));
test('panne, session absente, réponse vide : erreur traduite, question conservée et brouillon non écrasé',async()=>avecJeu(async(b,o)=>{
 const p=await ouvrir(b,o);await p.evaluate(()=>{window.rpAuthJeton=()=>null});await p.locator('#aide-hrp-question').fill('Question');await p.locator('#aide-hrp-envoyer').click();await p.waitForFunction(()=>document.querySelector('#aide-hrp-statut').textContent.includes('Connecte'));
 assert.equal(await p.locator('.aide-hrp-user').count(),0);await p.evaluate(()=>i18next.changeLanguage('de'));assert.match(await p.locator('#aide-hrp-statut').textContent(),/Melde/);
 await p.evaluate(()=>{window.rpAuthJeton=()=> 'fixture';window.fetch=()=>new Promise(r=>window.fin=()=>r({ok:true,json:async()=>({reponse:' '})}))});await p.locator('#aide-hrp-envoyer').click();await p.waitForFunction(()=>!!window.fin);
 await p.locator('#aide-hrp-question').fill('Nouveau brouillon');await p.evaluate(()=>fin());await p.waitForFunction(()=>!document.querySelector('#aide-hrp-envoyer').disabled);assert.equal(await p.locator('#aide-hrp-question').inputValue(),'Nouveau brouillon');
 await p.evaluate(()=>i18next.changeLanguage('ar'));assert.equal(await p.locator('.aide-hrp-user').count(),1);assert.equal(await p.locator('#aide-hrp-question').inputValue(),'Nouveau brouillon');assert.ok(await p.locator('#aide-hrp-statut').textContent());await p.close();
}));
test('timeout authentification : libération du verrou, aucune requête, aucun effet tardif',async()=>avecJeu(async(b,o)=>{
 const p=await ouvrir(b,o);await p.evaluate(()=>{const timer=window.setTimeout;window.setTimeout=(f,n,...args)=>timer(f,n===30000?20:n,...args);window.rpAuthAssurerSession=()=>new Promise(r=>window.authFin=r);window.calls=0;window.fetch=async()=>{calls++;throw Error('interdit')}});
 await p.locator('#aide-hrp-question').fill('Question');await p.locator('#aide-hrp-envoyer').click();await p.waitForFunction(()=>!document.querySelector('#aide-hrp-envoyer').disabled);await p.evaluate(()=>authFin());assert.equal(await p.evaluate(()=>calls),0);assert.equal(await p.locator('#aide-hrp-question').inputValue(),'Question');await p.close();
}));
test('français 1440 identique au main témoin, guides historiques conservés',async()=>avecJeu(async(b,o)=>{
 const png=[];for(const old of [true,false]){const p=await ouvrir(b,o,1440,old);await p.waitForFunction(()=>document.fonts.status==='loaded',null,{timeout:5000});png.push(await p.locator('#vue-rules').screenshot({animations:'disabled'}));if(process.env.HG_AIDE_PREUVES){fs.mkdirSync(process.env.HG_AIDE_PREUVES,{recursive:true});fs.writeFileSync(process.env.HG_AIDE_PREUVES+'/fr-1440-'+(old?'avant':'apres')+'.png',png.at(-1))}assert.ok(await p.locator('[data-section=intro]').count());await p.close()}
 assert.equal(crypto.createHash('sha256').update(png[1]).digest('hex'),crypto.createHash('sha256').update(png[0]).digest('hex')); 
}));
test('contre-épreuve : ancien double envoi pendant auth reproduit, nouveau empêché',async()=>avecJeu(async(b,o)=>{
 for(const old of [true,false]){
  const p=await ouvrir(b,o,390,old);await p.evaluate(()=>{window.resolutions=[];window.calls=[];window.rpAuthAssurerSession=()=>new Promise(r=>resolutions.push(r));window.fetch=async(u,opt)=>{calls.push(JSON.parse(opt.body));return {ok:true,json:async()=>({reponse:'Fixture'})}}});
  await p.locator('#aide-hrp-question').fill('Question');await p.locator('#aide-hrp-envoyer').click();await p.locator('#aide-hrp-question').press('Enter');
  assert.equal(await p.evaluate(()=>resolutions.length),old?2:1);await p.evaluate(()=>resolutions.forEach(r=>r()));await p.waitForFunction(n=>calls.length===n,old?2:1);assert.equal((await p.evaluate(()=>calls)).length,old?2:1);await p.close();
 }
}));
test('circuit complet navigateur → rewrite → chat → auth → DeepSeek (réseau simulé uniquement)',async()=>avecJeu(async(b,o)=>{
 const {default:chat}=await import('../../api/chat.js');const config=JSON.parse(fs.readFileSync(__dirname+'/../../vercel.json'));const rewrite=config.rewrites.find(x=>x.source==='/api/aide');assert.equal(rewrite.destination,'/api/chat?mode=aide');
 const initialFetch=global.fetch,cle=process.env.DEEPSEEK_API_KEY;process.env.DEEPSEEK_API_KEY='fixture-locale';const appels=[];
 global.fetch=async(url,opt)=>{appels.push(String(url));if(String(url).endsWith('/auth/v1/user'))return new Response(JSON.stringify({id:'fixture-locale'}));assert.equal(String(url),'https://api.deepseek.com/chat/completions');const payload=JSON.parse(opt.body);assert.match(payload.messages[0].content,/LANGUE DE RÉPONSE OBLIGATOIRE/);return new Response(JSON.stringify({choices:[{message:{content:'Réponse fournisseur simulée'},finish_reason:'stop'}]}))};
 try{const p=await ouvrir(b,o);let recus=[];
  await p.route('**/api/aide',async route=>{
   const body=route.request().postDataJSON();recus.push(body);const r={headers:{},code:200,setHeader(k,v){this.headers[k]=v},status(c){this.code=c;return this},json(body){this.body=body;return this}};
   await chat({method:route.request().method(),headers:route.request().headers(),query:Object.fromEntries(new URL(rewrite.destination,'http://fixture').searchParams),body},r);await route.fulfill({status:r.code,headers:r.headers,contentType:'application/json',body:JSON.stringify(r.body)});
  });
  let n=0;for(const[l,q]of Object.entries(questions)){await p.evaluate(l=>i18next.changeLanguage(l),l);for(const question of[q.pa,q.but]){await p.locator('#aide-hrp-question').fill(question);await p.locator('#aide-hrp-envoyer').click();await p.waitForFunction(n=>document.querySelectorAll('.aide-hrp-assistant').length===n,++n);assert.equal(recus.at(-1).lang,l);assert.equal(recus.at(-1).message,question)}}
  assert.equal(recus.length,18);assert.equal(appels.length,36);for(let i=0;i<36;i+=2){assert.ok(appels[i].endsWith('/auth/v1/user'));assert.equal(appels[i+1],'https://api.deepseek.com/chat/completions')}await p.close();
 }finally{global.fetch=initialFetch;if(cle===undefined)delete process.env.DEEPSEEK_API_KEY;else process.env.DEEPSEEK_API_KEY=cle}
}));

test('saisie IME coréenne/chinoise : Entrée de composition ne soumet aucune question',async()=>avecJeu(async(b,o)=>{
 const p=await ouvrir(b,o);await p.evaluate(()=>{window.calls=0;window.fetch=async()=>{calls++;return {ok:true,json:async()=>({reponse:'Fixture'})}}});
 for(const lang of ['ko','zh-TW']){
  await p.evaluate(l=>i18next.changeLanguage(l),lang);await p.locator('#aide-hrp-question').fill(questions[lang].pa);
  await p.locator('#aide-hrp-question').dispatchEvent('keydown',{key:'Enter',isComposing:true});assert.equal(await p.evaluate(()=>calls),0);assert.equal(await p.locator('#aide-hrp-question').inputValue(),questions[lang].pa);
 }
 await p.locator('#aide-hrp-question').press('Enter');await p.waitForFunction(()=>calls===1);await p.close();
}));
