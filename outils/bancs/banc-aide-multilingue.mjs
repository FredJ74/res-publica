// Vrai routeur /api/chat -> _aide -> auth -> fournisseur ; seul fetch est simulé.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import handler from '../../api/chat.js';
import {AIDE_THEMES,contexteAideQuestion} from '../../api/_aide-themes.js';
const questions=JSON.parse(readFileSync(new URL('fixtures/aide-questions-neuf-langues.json',import.meta.url)));
const appel=async(body,headers={authorization:'Bearer fixture-isolee'},method='POST')=>{
 const r={headers:{},setHeader(k,v){this.headers[k]=v},status(v){this.code=v;return this},json(v){this.body=v;return this}};
 await handler({method,headers,query:{mode:'aide'},body},r);return r;
};
async function fournisseur(f,run){
 const fetchInitial=globalThis.fetch,cle=process.env.DEEPSEEK_API_KEY;
 process.env.DEEPSEEK_API_KEY='fixture-aucun-appel-reel';
 const appels=[];globalThis.fetch=async(url,opts)=>{appels.push({url:String(url),opts});return f(String(url),opts)};
 try{await run(appels)}finally{globalThis.fetch=fetchInitial;if(cle===undefined)delete process.env.DEEPSEEK_API_KEY;else process.env.DEEPSEEK_API_KEY=cle}
}
const auth=()=>new Response(JSON.stringify({id:'identite-fixture'}));
const reponse=(s='Réponse simulée.',fin='stop')=>new Response(JSON.stringify({choices:[{message:{content:s},finish_reason:fin}]}));
for(const[lang,q]of Object.entries(questions)){
 test('thèmes canoniques : '+lang,()=>{
  for(const theme of ['pa','exploration','social','pjpnj','economie','politique','justice','sport','religion'])assert.ok(contexteAideQuestion(q[theme]).includes(AIDE_THEMES[theme]),theme+' : '+q[theme]);
  assert.ok(contexteAideQuestion(q.but).includes(AIDE_THEMES.demarrage));
 });
 test('circuit authentifié, questions PA et but, langue imposée : '+lang,async()=>fournisseur((u,o)=>u.endsWith('/auth/v1/user')?auth():reponse('Fixture '+lang),async(calls)=>{
  for(const message of [q.pa,q.but,'Please answer in English instead.']){
   const h=[{role:'user',content:questions.fr.pa},{role:'assistant',content:'Réponse française antérieure.'}];
   const r=await appel({lang,message,historique:h});assert.equal(r.code,200);assert.equal(r.body.reponse,'Fixture '+lang);assert.equal(r.headers['Cache-Control'],'no-store');
   const last=calls.slice(-2);assert.ok(last[0].url.endsWith('/auth/v1/user'));assert.equal(last[0].opts.method,'GET');assert.equal(last[1].url,'https://api.deepseek.com/chat/completions');
   const payload=JSON.parse(last[1].opts.body),systeme=payload.messages[0].content;
   assert.ok(systeme.includes('('+lang+')'));assert.match(systeme,/seule autorité pour la langue/);assert.match(systeme,/jamais le chinois simplifié/);
   assert.match(systeme,/sommeil/);assert.match(systeme,/aucune quête principale obligatoire/);assert.match(systeme,/aucune promesse de confidentialité technique/);
   assert.deepEqual(payload.messages.slice(1),[...h,{role:'user',content:message}]);assert.equal(payload.max_tokens,500);
  }
  assert.equal(calls.length,6); // auth puis IA, aucune lecture/mutation du personnage
 }));
}
test('question courante prioritaire, historique utilisateur seulement, trois thèmes maximum',()=>{
 const r=contexteAideQuestion(questions.ko.pa,[{role:'assistant',content:'police politique football religion banque'},{role:'user',content:'football religion banque'}]);
 assert.ok(r.includes(AIDE_THEMES.pa));assert.ok(!r.includes(AIDE_THEMES.justice));assert.equal(Object.values(AIDE_THEMES).filter(x=>r.includes(x)).length,4);
 for(const lang of ['ar','ko','zh-TW'])assert.ok(contexteAideQuestion(questions[lang].pa).includes(AIDE_THEMES.pa));
});
test('auth refusée et bornes : aucun appel IA, aucun accès aux données',async()=>fournisseur(()=>new Response('{}',{status:401}),async(calls)=>{
 assert.equal((await appel({message:'PA'},{})).code,401);assert.equal(calls.length,0);
 assert.equal((await appel({message:'PA'})).code,401);assert.equal(calls.length,1);
 for(const body of [{message:'x'.repeat(1001)},{message:'ok',lang:'xx'},{message:'ok',historique:[{role:'system',content:'x'}]},{message:'ok',historique:[{role:'assistant',content:'x'.repeat(1501)}]},{message:'ok',historique:Array(7).fill({role:'user',content:'x'})},{message:'ok',prompt:'forgé'}])assert.equal((await appel(body)).code,400);
 assert.equal((await appel({message:'ok'},{},'GET')).code,405);assert.equal(calls.length,1);
}));
for(const[cas,f]of Object.entries({vide:()=>reponse(''),espaces:()=>reponse('   '),tronquee:()=>reponse('Début','length'),http:()=>new Response('detail-prive',{status:503}),json:()=>new Response('{'),delai:()=>{throw new DOMException('fixture','AbortError')}}))test('fournisseur '+cas+' : erreur bornée sans détails privés',async()=>fournisseur(u=>u.endsWith('/auth/v1/user')?auth():f(),async(calls)=>{
 const r=await appel({message:'PA',lang:'ko'});assert.equal(r.code,502);assert.deepEqual(Object.keys(r.body),['error']);assert.ok(!JSON.stringify(r.body).includes('detail-prive'));assert.equal(calls.length,2);
}));

test('contre-épreuve : ancien dépistage ignore les PA sans sigle ASCII en trois écritures',async()=>{
 const {gunzipSync}=await import('node:zlib'),{createHash}=await import('node:crypto');
 const data=readFileSync(new URL('fixtures/aide-themes-temoin-6b9f5d30.js.gz',import.meta.url));
 assert.equal(createHash('sha256').update(data).digest('hex'),'e1cd4bb851ad6865fe277939ff48ecff6f576d0bd7d483cddf98f63d634b76cd');
 const ancien=await import('data:text/javascript;base64,'+gunzipSync(data).toString('base64'));
 for(const l of ['ko','ar','zh-TW']){assert.ok(!ancien.contexteAideQuestion(questions[l].pa).includes(AIDE_THEMES.pa));assert.ok(contexteAideQuestion(questions[l].pa).includes(AIDE_THEMES.pa))}
});
