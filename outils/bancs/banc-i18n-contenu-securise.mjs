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
test('source sans version : aucun cache partagé, aucun appel payant',async()=>{
 const {calls,deps}=fixtures();deps.readUnderRls=async()=>{calls.push('rls');return {text:'Bonjour',language:'fr'}};
 const r=await traduireContenu(input,deps);
 assert.equal(r.raison,'version_absente');assert.deepEqual(calls,['auth','rls']);
});
