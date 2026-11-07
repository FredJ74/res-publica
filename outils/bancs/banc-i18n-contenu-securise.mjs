import test from 'node:test';
import assert from 'node:assert/strict';
import { traduireContenu } from '../../api/_traduction-contenu.js';
function fixtures() {
 const calls=[];
 const deps={
  authenticate:async()=>{calls.push('auth');return {userId:'test-user',readerToken:'jwt-reader'}},
  readUnderRls:async(source,token)=>{calls.push('rls');assert.equal(token,'jwt-reader');return {text:'Salut {{name}}',language:'fr',version:'revision-1'}},
  readCache:async()=>{calls.push('cache');return null},
  reserveBudget:async()=>{calls.push('quota');return true},
  provider:async()=>{calls.push('provider');return {ok:true,texte:'Hello {{name}}',tronque:false}},
  writeCache:async()=>{calls.push('write')}
 };
 return {calls,deps};
}
const input={type:'forum_post',id:'id-1',field:'content',langueCible:'en'};
test('authentification puis RLS avant cache, quota avant DeepSeek',async()=>{
 const {calls,deps}=fixtures();const r=await traduireContenu(input,deps);
 assert.equal(r.ok,true);assert.equal(r.original,'Salut {{name}}');
 assert.deepEqual(calls,['auth','rls','cache','quota','provider','write']);
});
test('message privé interdit : aucun cache ni appel au fournisseur',async()=>{
 const {calls,deps}=fixtures();deps.readUnderRls=async()=>{calls.push('rls');return null};
 const r=await traduireContenu({type:'chat_message',id:'secret',field:'message',langueCible:'en'},deps);
 assert.equal(r.ok,false);assert.deepEqual(calls,['auth','rls']);
 assert.equal(r.original,null);
});
test('lecture depuis cache après RLS ; aucun quota et aucun appel fournisseur',async()=>{
 const {calls,deps}=fixtures();deps.readCache=async()=>{calls.push('cache');return 'Hello {{name}}'};
 const r=await traduireContenu(input,deps);
 assert.equal(r.traduit,'Hello {{name}}');assert.equal(r.fromCache,true);
 assert.deepEqual(calls,['auth','rls','cache']);
});
test('quota refusé et source non admise : aucune dépense',async()=>{
 const {calls,deps}=fixtures();deps.reserveBudget=async()=>{calls.push('quota');return false};
 const r=await traduireContenu(input,deps);assert.equal(r.raison,'quota_atteint');
 assert.deepEqual(calls,['auth','rls','cache','quota']);
 const rejected=await traduireContenu({type:'court_message',id:1,field:'texte',langueCible:'en'},deps);
 assert.equal(rejected.ok,false);assert.deepEqual(calls,['auth','rls','cache','quota']);
});
test('clé de cache dépend de la version du message et de la langue',async()=>{
 const keys=[],{deps}=fixtures();deps.readCache=async key=>{keys.push(key);return null};
 await traduireContenu(input,deps);deps.readUnderRls=async()=>({text:'Salut {{name}}',language:'fr',version:'revision-2'});
 await traduireContenu(input,deps);assert.notEqual(keys[0],keys[1]);
});

test('langue cible non prise en charge : ni lecture privée ni appel payant',async()=>{
 const {calls,deps}=fixtures();
 const r=await traduireContenu({...input,langueCible:'xx'},deps);
 assert.equal(r.ok,false);assert.deepEqual(calls,[]);
});
test('source sans colonne version : hash de contenu calculé APRÈS la lecture RLS',async()=>{
 const {calls,deps}=fixtures();const keys=[];
 deps.readUnderRls=async()=>{calls.push('rls');return {text:'Bonjour',language:'fr'}};
 deps.readCache=async key=>{calls.push('cache');keys.push(key);return null};
 const r=await traduireContenu(input,deps);
 assert.equal(r.ok,true);assert.deepEqual(calls,['auth','rls','cache','quota','provider','write']);
 assert.match(keys[0],/sha256:/);
});
test('version explicite invalide : refus avant cache et quota',async()=>{
 const {calls,deps}=fixtures();
 deps.readUnderRls=async()=>{calls.push('rls');return {text:'Bonjour',language:'fr',version:'x'.repeat(129)}};
 const r=await traduireContenu(input,deps);
 assert.equal(r.raison,'version_invalide');assert.deepEqual(calls,['auth','rls']);
});
test('origine linguistique inconnue : traduction sans inventer une langue française',async()=>{
 const {calls,deps}=fixtures();
 deps.readUnderRls=async()=>{calls.push('rls');return {text:'Hola {{name}}',language:'und'}};
 const r=await traduireContenu(input,deps);
 assert.equal(r.ok,true);assert.equal(r.langueOriginale,'und');
 assert.deepEqual(calls,['auth','rls','cache','quota','provider','write']);
});


test('un cache corrompu avec des variables changées ne peut pas être servi',async()=>{
 const {calls,deps}=fixtures();deps.readCache=async()=>{calls.push('cache');return 'Hello {{wrong}}'};
 const result=await traduireContenu(input,deps);
 assert.equal(result.ok,true);assert.equal(result.fromCache,false);
 assert.deepEqual(calls,['auth','rls','cache','quota','provider','write']);
});
test('cache invalidé lorsque le contenu change sans changement de version',async()=>{
 const keys=[],{deps}=fixtures();deps.readCache=async key=>{keys.push(key);return null};
 await traduireContenu(input,deps);
 deps.readUnderRls=async()=>({text:'Salut modifié {{name}}',language:'fr',version:'revision-1'});
 await traduireContenu(input,deps);
 assert.notEqual(keys[0],keys[1]);
});


test('caractères de contrôle : rejet après lecture RLS, avant cache et quota',async()=>{
 const {calls,deps}=fixtures();
 deps.readUnderRls=async()=>{calls.push('rls');return {text:'Bonjour\u0000',language:'fr',version:'r1'}};
 const r=await traduireContenu(input,deps);
 assert.equal(r.ok,false);
 assert.equal(r.raison,'texte_invalide');
 assert.deepEqual(calls,['auth','rls']);
});


test('cache trop long ou avec contrôle : jamais servi, fournisseur sécurisé réinterrogé',async()=>{
 for(const corrupt of ['X'.repeat(4001),'Hello {{name}}\u0001']){
  const {calls,deps}=fixtures();
  deps.readCache=async()=>{calls.push('cache');return corrupt};
  const r=await traduireContenu(input,deps);
  assert.equal(r.ok,true);
  assert.equal(r.traduit,'Hello {{name}}');
  assert.equal(r.fromCache,false);
  assert.deepEqual(calls,['auth','rls','cache','quota','provider','write']);
 }
});


test('cache partagé entre lecteurs autorisés, jamais servi à un lecteur sans RLS',async()=>{
 const cache=new Map(),calls=[];
 let userId='lecteur-A',allowed=true;
 const deps={
  authenticate:async()=>({userId,readerToken:'jeton-'+userId}),
  readUnderRls:async(source,token)=>{
   calls.push('rls:'+token);
   return allowed?{text:'Salut {{name}}',language:'fr',version:'revision-1'}:null;
  },
  readCache:async(key)=>{calls.push('cache');return cache.get(key)||null},
  writeCache:async(key,value)=>{cache.set(key,value)},
  reserveBudget:async(id)=>{calls.push('quota:'+id);return true},
  provider:async()=>{calls.push('provider');return {ok:true,texte:'Hello {{name}}',tronque:false}}
 };
 const first=await traduireContenu(input,deps);
 assert.equal(first.ok,true);assert.equal(first.fromCache,false);
 userId='lecteur-B';
 const second=await traduireContenu(input,deps);
 assert.equal(second.ok,true);assert.equal(second.fromCache,true);
 assert.equal(second.traduit,'Hello {{name}}');
 assert.equal(calls.filter(x=>x==='provider').length,1);
 assert.deepEqual(calls.filter(x=>x.startsWith('quota:')),['quota:lecteur-A']);
 const readsBefore=calls.filter(x=>x==='cache').length;
 allowed=false;userId='lecteur-C';
 const refused=await traduireContenu(input,deps);
 assert.equal(refused.ok,false);assert.equal(refused.original,null);
 assert.equal(calls.filter(x=>x==='cache').length,readsBefore,'pas de cache avant RLS');
 assert.equal(calls.filter(x=>x==='provider').length,1);
});
